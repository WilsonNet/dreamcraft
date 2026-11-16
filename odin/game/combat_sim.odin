// Combat: chase to melee range, attack on cooldown, remove dead units.
package game

ATTACK_RANGE_SQUARED :: ATTACK_RANGE * ATTACK_RANGE

attack_movement :: proc(game: ^Game) {
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

		damage := u16(ATTACK_DAMAGE)
		if units.hp[target_index] <= damage {
			units.hp[target_index] = 0
		} else {
			units.hp[target_index] -= damage
		}
		units.cooldown[index] = ATTACK_COOLDOWN_TICKS
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
