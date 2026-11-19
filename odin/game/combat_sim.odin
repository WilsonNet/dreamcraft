// Combat: chase to melee range, attack on cooldown, remove dead units.
package game

ATTACK_RANGE_SQUARED :: ATTACK_RANGE * ATTACK_RANGE
LEASH_RANGE_SQUARED :: (VISION_RADIUS + 2) * (VISION_RADIUS + 2)

// Auto-acquire visible enemies for player units on Patrol or Attack-Move.
@(private)
auto_acquire_targets :: proc(game: ^Game) {
	units := &game.units
	for i in 0..<MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		if !units.patrol_active[i] && !units.attack_move_active[i] {
			continue
		}
		if target_idx, ok := unit_index(units, units.attack_target[i]); ok {
			if distance_squared(units.position[i], units.position[target_idx]) > LEASH_RANGE_SQUARED {
				units.attack_target[i] = INVALID_HANDLE
			} else {
				continue
			}
		}
		if enemy, found := find_nearest_enemy(units, i, VISION_RADIUS * VISION_RADIUS); found {
			units.attack_target[i] = enemy
		}
	}
}

@(private)
find_nearest_enemy :: proc(units: ^Units, index: int, max_dist_sq: i32) -> (Unit_Handle, bool) {
	best_dist := max_dist_sq + 1
	best_handle := INVALID_HANDLE
	found := false
	for e in 0..<MAX_UNITS {
		if !units.alive[e] || units.team[e] != .Enemy {
			continue
		}
		d := distance_squared(units.position[index], units.position[e])
		if d < best_dist {
			best_dist = d
			best_handle = unit_handle(units, e)
			found = true
		}
	}
	return best_handle, found
}

attack_movement :: proc(game: ^Game) {
	auto_acquire_targets(game)
	units := &game.units
	for index in 0..<MAX_UNITS {
		if !units.alive[index] || !handle_is_valid(units.attack_target[index]) {
			continue
		}
		target_index, ok := unit_index(units, units.attack_target[index])
		if !ok {
			units.attack_target[index] = INVALID_HANDLE
			continue
		}

		dfx := units.position[index].x - units.position[target_index].x
		dfy := units.position[index].y - units.position[target_index].y
		if dfx * dfx + dfy * dfy <= ATTACK_RANGE_SQUARED {
			unit_stop_after_segment(units, index)
			continue
		}

		destination := units.position[target_index]
		existing, has_existing := unit_path_destination(units, index)
		if !unit_has_path(units, index) || !has_existing || !cells_equal(existing, destination) {
			_ = issue_move_path(game, index, destination)
		}
	}
}

combat_tick :: proc(game: ^Game) {
	units := &game.units
	for index in 0..<MAX_UNITS {
		if !units.alive[index] {
			continue
		}
		if units.cooldown[index] > 0 {
			units.cooldown[index] -= 1
			continue
		}
		if !handle_is_valid(units.attack_target[index]) {
			continue
		}
		target_index, ok := unit_index(units, units.attack_target[index])
		if !ok || units.hp[target_index] == 0 {
			units.attack_target[index] = INVALID_HANDLE
			continue
		}

		dx := units.position[index].x - units.position[target_index].x
		dy := units.position[index].y - units.position[target_index].y
		if dx * dx + dy * dy > ATTACK_RANGE_SQUARED {
			continue
		}

		raw_damage := unit_attack_damage(units, index)
		armor := unit_armor(units, target_index)
		damage := u16(1)
		if raw_damage > armor {
			damage = raw_damage - armor
		}
		if units.hp[target_index] <= damage {
			units.hp[target_index] = 0
		} else {
			units.hp[target_index] -= damage
		}
		units.cooldown[index] = unit_attack_cooldown(units, index)
	}
}

hero_regen_tick :: proc(game: ^Game) {
	if HERO_REGEN_INTERVAL_TICKS <= 0 || game.tick % HERO_REGEN_INTERVAL_TICKS != 0 {
		return
	}
	units := &game.units
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.kind[i] == .Hero && units.hp[i] > 0 && units.hp[i] < units.hp_max[i] {
			units.hp[i] = min(units.hp_max[i], units.hp[i] + HERO_REGEN_AMOUNT)
		}
	}
}

death_check :: proc(game: ^Game) {
	dead: [MAX_UNITS]u16
	dead_count := 0
	units := &game.units
	for index in 0..<MAX_UNITS {
		if units.alive[index] && units.hp[index] == 0 {
			dead[dead_count] = u16(index)
			dead_count += 1
		}
	}
	for i := 0; i < dead_count; i += 1 {
		unit_destroy(units, int(dead[i]))
	}
	game_update_game_over(game)
}
