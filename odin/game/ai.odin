// Enemy AI, neutral ally rescue, fog updates, waypoint progress and goal detection.
package game

enemy_ai_update :: proc(game: ^Game) {
	_, player_ok := game_player_index(game)
	units := &game.units

	for index in 0..<MAX_UNITS {
		if !units.alive[index] || units.team[index] != .Enemy {
			continue
		}
		if !player_ok {
			units.attack_target[index] = INVALID_HANDLE
			continue
		}
		update_single_enemy_ai(game, index)
	}
}

@(private)
update_single_enemy_ai :: proc(game: ^Game, index: int) {
	units := &game.units
	if units.discovered[index] && units.aggro_timer[index] > 0 && units.hp[index] < units.hp_max[index] {
		units.aggro_timer[index] = 0
		alert_enemy_squad(units, units.position[index], false)
	}
	target, in_sight := find_nearest_player(units, units.position[index], VISION_RADIUS * VISION_RADIUS)
	if !units.discovered[index] {
		if !in_sight {
			return
		}
		units.discovered[index] = true
		units.aggro_timer[index] = ENEMY_AGGRO_DELAY_TICKS
		alert_enemy_squad(units, units.position[index], true)
		if !game.discovery_announced {
			game.discovery_announced = true
			game.discovery_tick = game.tick
		}
		return
	}
	if units.aggro_timer[index] > 0 {
		units.aggro_timer[index] -= 1
		return
	}
	assign_enemy_target(game, index, target, in_sight)
}

@(private)
assign_enemy_target :: proc(game: ^Game, index: int, nearest_sight: Unit_Handle, in_sight: bool) {
	units := &game.units
	if in_sight {
		units.attack_target[index] = nearest_sight
		if game.aggro_triggered_tick == 0 {
			game.aggro_triggered_tick = game.tick
		}
		return
	}
	if cur_idx, ok := unit_index(units, units.attack_target[index]); ok {
		if distance_squared(units.position[index], units.position[cur_idx]) <= LEASH_RANGE_SQUARED {
			return
		}
	}
	units.attack_target[index] = INVALID_HANDLE
	unit_clear_path(units, index)
	if units.state[index] != .Patrol {
		units.state[index] = .Idle
	}
}

@(private)
alert_enemy_squad :: proc(units: ^Units, center: Grid_Pos, set_delay: bool) {
	r2 := i32(SQUAD_ALERT_RADIUS * SQUAD_ALERT_RADIUS)
	for i in 0..<MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Enemy {
			continue
		}
		if distance_squared(units.position[i], center) > r2 {
			continue
		}
		if set_delay {
			if !units.discovered[i] {
				units.discovered[i] = true
				units.aggro_timer[i] = ENEMY_AGGRO_DELAY_TICKS
			}
		} else if units.discovered[i] {
			units.aggro_timer[i] = 0
		}
	}
}

@(private)
find_nearest_player :: proc(units: ^Units, origin: Grid_Pos, max_dist_sq: i32) -> (Unit_Handle, bool) {
	best_dist := max_dist_sq + 1
	best := INVALID_HANDLE
	found := false
	for i in 0..<MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		d := distance_squared(origin, units.position[i])
		if d < best_dist {
			best_dist = d
			best = unit_handle(units, i)
			found = true
		}
	}
	return best, found
}

rescue_allies_update :: proc(game: ^Game) {
	units := &game.units
	joined: [MAX_UNITS]bool
	batch := u16(0)
	r2 := i32(RESCUE_RADIUS * RESCUE_RADIUS)
	for n in 0..<MAX_UNITS {
		if !units.alive[n] || units.team[n] != .Neutral {
			continue
		}
		if _, near := find_nearest_player(units, units.position[n], r2); near {
			units.team[n] = .Player
			joined[n] = true
			batch += 1
		}
	}
	if batch == 0 {
		return
	}
	batch += chain_rescue_allies(units, &joined)
	game.rescued_count += batch
	game.last_rescue_tick = game.tick
	game.last_rescue_batch = batch
}

@(private)
chain_rescue_allies :: proc(units: ^Units, joined: ^[MAX_UNITS]bool) -> u16 {
	chain_r2 := i32(RESCUE_CHAIN_RADIUS * RESCUE_CHAIN_RADIUS)
	extra := u16(0)
	for {
		changed := false
		for n in 0..<MAX_UNITS {
			if !units.alive[n] || units.team[n] != .Neutral {
				continue
			}
			for j in 0..<MAX_UNITS {
				if !joined[j] {
					continue
				}
				if distance_squared(units.position[n], units.position[j]) <= chain_r2 {
					units.team[n] = .Player
					joined[n] = true
					extra += 1
					changed = true
					break
				}
			}
		}
		if !changed {
			break
		}
	}
	return extra
}

update_visibility :: proc(game: ^Game) {
	fog_begin_tick(&game.fog)
	units := &game.units
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player {
			fog_reveal(&game.fog, units.position[i], VISION_RADIUS)
		}
	}
}

check_waypoints :: proc(game: ^Game) {
	current, has_current := waypoint_current(&game.waypoints)
	if !has_current {
		return
	}
	reached := false
	units := &game.units
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player {
			if manhattan(units.position[i], current) <= WAYPOINT_REACH_RADIUS {
				reached = true
				break
			}
		}
	}
	if !reached {
		return
	}
	game.waypoints.current += 1
	next, has_next := waypoint_current(&game.waypoints)
	if has_next {
		fog_mark_explored(&game.fog, next, WAYPOINT_REVEAL_RADIUS)
	}
}

check_goal :: proc(game: ^Game) {
	if game.level_complete {
		return
	}
	units := &game.units
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && units.position[i].x >= GOAL_X {
			game.level_complete = true
			return
		}
	}
}

enemy_is_visible :: proc(game: ^Game, index: int) -> bool {
	if !game.units.alive[index] {
		return false
	}
	if game.units.team[index] == .Player {
		return true
	}
	return fog_is_visible(&game.fog, game.units.position[index])
}
