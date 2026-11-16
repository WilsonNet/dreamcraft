// Fixed-order simulation tick.
//
// The order is part of the deterministic contract. Do not reorder systems
// without updating the determinism test.
package game

sim_tick :: proc(game: ^Game) {
	game.tick += 1
	command_apply_queue(game)
	enemy_ai_update(game)
	attack_movement(game)
	patrol_loop(game)
	unit_movement(game)
	combat_tick(game)
	death_check(game)
	update_visibility(game)
	check_waypoints(game)
	check_goal(game)

	when VALIDATE_EACH_TICK {
		err := validate_game(game)
		assert(err == .None, validation_error_name(err))
	}
}

sim_run :: proc(game: ^Game, ticks: int) {
	for _ in 0..<ticks {
		sim_tick(game)
	}
}

// Convenience for tests and headless scripts: issue a move and run until the
// unit stops or the tick budget is exhausted.
sim_move_player :: proc(game: ^Game, destination: Grid_Pos, max_ticks := 1200) -> bool {
	player_index, ok := game_player_index(game)
	if !ok {
		return false
	}
	units := &game.units
	unit_select_only(units, player_index)
	if !game_issue_move(game, destination) {
		return false
	}
	for _ in 0..<max_ticks {
		sim_tick(game)
		player_index, ok = game_player_index(game)
		if !ok {
			return false
		}
		if !unit_has_path(units, player_index) {
			return cells_equal(units.position[player_index], destination)
		}
	}
	return false
}
