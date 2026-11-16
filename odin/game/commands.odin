// Command execution. Commands are queued by input/headless and applied at the
// start of a tick, in order, so a tick is reproducible from a command log.
package game

command_apply_queue :: proc(game: ^Game) -> int {
	applied := 0
	for {
		command, ok := command_pop(&game.commands)
		if !ok {
			break
		}
		command_apply(game, command)
		applied += 1
	}
	return applied
}

command_apply :: proc(game: ^Game, command: Command) {
	if handle_is_valid(command.actor) {
		if index, ok := unit_index(&game.units, command.actor); ok {
			apply_to_unit(game, index, command)
		}
		return
	}

	has_selected_player := unit_selected_player_count(&game.units) > 0
	for index in 0..<MAX_UNITS {
		units := &game.units
		if !units.alive[index] || units.team[index] != .Player {
			continue
		}
		if has_selected_player && !units.selected[index] {
			continue
		}
		apply_to_unit(game, index, command)
	}
}

@(private)
apply_to_unit :: proc(game: ^Game, index: int, command: Command) {
	switch command.kind {
	case .Move:
		units := &game.units
		units.patrol_active[index] = false
		units.attack_target[index] = INVALID_HANDLE
		issue_move_path(game, index, command.position)
	case .Attack:
		apply_attack(game, index, command.target)
	case .Patrol:
		apply_patrol(game, index, command.position, command.point_b)
	case .Stop:
		units := &game.units
		unit_clear_path(units, index)
		units.attack_target[index] = INVALID_HANDLE
		units.patrol_active[index] = false
		units.state[index] = .Idle
	}
}

@(private)
issue_move_path :: proc(game: ^Game, index: int, destination: Grid_Pos) -> bool {
	units := &game.units
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.world[index] = grid_to_world(units.position[index])

	if cells_equal(units.position[index], destination) {
		units.state[index] = .Idle
		return true
	}

	out := units.path[index][:]
	length, result := find_path(
		&game.pathfinder,
		&game.grid,
		units.position[index],
		destination,
		out,
	)
	if result != .Found || length <= 0 {
		units.state[index] = .Idle
		return false
	}
	units.path_len[index] = u16(length)
	units.state[index] = .Moving
	return true
}

@(private)
apply_attack :: proc(game: ^Game, index: int, target: Unit_Handle) {
	target_index, ok := unit_index(&game.units, target)
	if !ok || game.units.team[target_index] != .Enemy {
		return
	}
	units := &game.units
	units.attack_target[index] = target
	units.patrol_active[index] = false
	unit_clear_path(units, index)
	units.state[index] = .Idle
}

@(private)
apply_patrol :: proc(game: ^Game, index: int, a, b: Grid_Pos) {
	units := &game.units
	units.attack_target[index] = INVALID_HANDLE
	units.patrol_active[index] = true
	units.patrol_a[index] = a
	units.patrol_b[index] = b
	units.patrol_to_b[index] = true
	if !issue_move_path(game, index, a) {
		units.patrol_active[index] = false
		units.state[index] = .Idle
		return
	}
	units.state[index] = .Patrol
}
