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
		if issue_move_path(game, index, command.position) {
			units := &game.units
			units.patrol_active[index] = false
			units.attack_target[index] = INVALID_HANDLE
		}
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
	current := units.position[index]
	start := current
	// Re-ordering mid-segment must not snap the unit back to the cell it is
	// leaving. Plan the new path from the cell it is already walking into and
	// keep the current interpolation, so the unit continues from where it is.
	mid_segment := unit_between_cells(units, index)
	if mid_segment {
		start = cell_position(int(units.path[index][units.path_index[index]]))
	}
	if !in_bounds(destination) || grid_is_blocked(&game.grid, destination) {
		return false
	}

	out := units.path[index][:]
	length, result := find_path(&game.pathfinder, &game.grid, start, destination, out)
	if result != .Found || length <= 0 {
		return false
	}

	units.path_len[index] = u16(length)
	units.path_index[index] = 0
	units.state[index] = .Moving
	if !mid_segment {
		units.progress[index] = 0
		units.world[index] = grid_to_world(current)
	}
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
	// Keep the current path. attack_movement replans from the segment the unit
	// is already walking, so an attack order cannot snap it back to a cell
	// center. If the target is already in range it stops after this segment.
	if !unit_has_path(units, index) {
		units.state[index] = .Idle
	}
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
