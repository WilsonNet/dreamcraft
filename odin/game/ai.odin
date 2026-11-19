// Enemy AI, fog updates, waypoint progress and goal detection.
package game

enemy_ai_update :: proc(game: ^Game) {
	player_index, player_ok := game_player_index(game)
	units := &game.units

	for index in 0..<MAX_UNITS {
		if !units.alive[index] || units.team[index] != .Enemy {
			continue
		}
		if !player_ok {
			units.attack_target[index] = INVALID_HANDLE
			continue
		}
		update_single_enemy_ai(game, index, player_index)
	}
}

@(private)
update_single_enemy_ai :: proc(game: ^Game, index, player_index: int) {
	units := &game.units
	in_sight := distance_squared(units.position[index], units.position[player_index]) <= VISION_RADIUS * VISION_RADIUS
	if !units.discovered[index] {
		if !in_sight {
			return
		}
		units.discovered[index] = true
		units.aggro_timer[index] = ENEMY_AGGRO_DELAY_TICKS
		if !game.discovery_announced {
			game.discovery_announced = true
			game.discovery_tick = game.tick
		}
		return
	}
	if units.aggro_timer[index] > 0 {
		// Retaliate immediately if struck first; otherwise count down the grace delay.
		if units.hp[index] < units.hp_max[index] {
			units.aggro_timer[index] = 0
		} else {
			units.aggro_timer[index] -= 1
			return
		}
	}
	if in_sight {
		units.attack_target[index] = unit_handle(units, player_index)
		if game.aggro_triggered_tick == 0 {
			game.aggro_triggered_tick = game.tick
		}
		return
	}
	units.attack_target[index] = INVALID_HANDLE
	unit_clear_path(units, index)
	if units.state[index] != .Patrol {
		units.state[index] = .Idle
	}
}

update_visibility :: proc(game: ^Game) {
	fog_begin_tick(&game.fog)
	player_index, ok := game_player_index(game)
	if !ok {
		return
	}
	fog_reveal(&game.fog, game.units.position[player_index], VISION_RADIUS)
}

check_waypoints :: proc(game: ^Game) {
	player_index, ok := game_player_index(game)
	if !ok {
		return
	}
	current, has_current := waypoint_current(&game.waypoints)
	if !has_current {
		return
	}
	if manhattan(game.units.position[player_index], current) > WAYPOINT_REACH_RADIUS {
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
	player_index, ok := game_player_index(game)
	if !ok {
		return
	}
	if game.units.position[player_index].x >= GOAL_X {
		game.level_complete = true
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
