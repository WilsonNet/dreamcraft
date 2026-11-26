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
			apply_or_queue_unit(game, index, command)
		}
		return
	}

	actors: [MAX_UNITS]u16
	actor_count := collect_command_actors(&game.units, actors[:])
	if actor_count == 0 {
		return
	}
	if actor_count == 1 || command.kind == .Attack || command.kind == .Stop {
		for i in 0..<actor_count {
			apply_or_queue_unit(game, int(actors[i]), command)
		}
		return
	}
	apply_formation_command(game, actors[:actor_count], command)
}

@(private)
collect_command_actors :: proc(units: ^Units, out: []u16) -> int {
	has_selected_player := unit_selected_player_count(units) > 0
	count := 0
	for index in 0..<MAX_UNITS {
		if !units.alive[index] || units.team[index] != .Player {
			continue
		}
		if has_selected_player && !units.selected[index] {
			continue
		}
		out[count] = u16(index)
		count += 1
	}
	return count
}

@(private)
apply_formation_command :: proc(game: ^Game, actors: []u16, command: Command) {
	origin := command.kind == .Patrol ? command.point_b : command.position
	sort_actors_by_distance(&game.units, actors, origin)
	claimed: [MAX_UNITS]Grid_Pos
	claimed_count := 0
	for actor in actors {
		index := int(actor)
		dest := find_formation_cell(&game.grid, origin, claimed[:claimed_count])
		claimed[claimed_count] = dest
		claimed_count += 1
		unit_cmd := command
		if command.kind == .Patrol {
			unit_cmd.point_b = dest
		} else {
			unit_cmd.position = dest
		}
		apply_or_queue_unit(game, index, unit_cmd)
	}
}

@(private)
sort_actors_by_distance :: proc(units: ^Units, actors: []u16, target: Grid_Pos) {
	for i := 1; i < len(actors); i += 1 {
		key := actors[i]
		key_d := distance_squared(units.position[key], target)
		j := i - 1
		for j >= 0 && distance_squared(units.position[actors[j]], target) > key_d {
			actors[j + 1] = actors[j]
			j -= 1
		}
		actors[j + 1] = key
	}
}

@(private)
find_formation_cell :: proc(grid: ^Grid, origin: Grid_Pos, claimed: []Grid_Pos) -> Grid_Pos {
	for r := i32(0); r <= 6; r += 1 {
		for dy := -r; dy <= r; dy += 1 {
			for dx := -r; dx <= r; dx += 1 {
				if max(abs(dx), abs(dy)) != r {
					continue
				}
				cand := Grid_Pos{x = origin.x + dx, y = origin.y + dy}
				if !grid_is_walkable(grid, cand) || is_cell_claimed(claimed, cand) {
					continue
				}
				return cand
			}
		}
	}
	return origin
}

@(private)
is_cell_claimed :: proc(claimed: []Grid_Pos, p: Grid_Pos) -> bool {
	for c in claimed {
		if cells_equal(c, p) {
			return true
		}
	}
	return false
}

@(private)
apply_or_queue_unit :: proc(game: ^Game, index: int, command: Command) {
	units := &game.units
	if !command.queued || command.kind == .Stop {
		unit_clear_orders(units, index)
		apply_to_unit(game, index, command)
		return
	}
	if unit_is_idle_for_queue(units, index) {
		apply_to_unit(game, index, command)
		return
	}
	_ = unit_push_order(units, index, Unit_Order{
		kind     = command.kind,
		position = command.position,
		point_b  = command.point_b,
		target   = command.target,
	})
}

dequeue_next_order :: proc(game: ^Game, index: int) -> bool {
	units := &game.units
	for units.order_count[index] > 0 {
		ord, ok := unit_pop_order(units, index)
		if !ok {
			return false
		}
		cmd := Command{
			kind         = ord.kind,
			position     = ord.position,
			point_b      = ord.point_b,
			target       = ord.target,
			from_current = true,
		}
		if ord.kind == .Attack {
			if target_idx, tok := unit_index(units, ord.target); !tok || units.team[target_idx] != .Enemy {
				continue
			}
		}
		apply_to_unit(game, index, cmd)
		return true
	}
	return false
}

@(private)
apply_to_unit :: proc(game: ^Game, index: int, command: Command) {
	switch command.kind {
	case .Move:
		if issue_move_path(game, index, command.position) {
			units := &game.units
			units.patrol_active[index] = false
			units.attack_move_active[index] = false
			units.attack_target[index] = INVALID_HANDLE
			units.state[index] = .Moving
		}
	case .Attack:
		apply_attack(game, index, command.target)
	case .Patrol:
		apply_patrol(game, index, command)
	case .Attack_Move:
		apply_attack_move(game, index, command.position)
	case .Stop:
		units := &game.units
		unit_clear_path(units, index)
		units.attack_target[index] = INVALID_HANDLE
		units.patrol_active[index] = false
		units.attack_move_active[index] = false
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
	units.state[index] = unit_move_state(units, index)
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
	units.attack_move_active[index] = false
	// Keep the current path. attack_movement replans from the segment the unit
	// is already walking, so an attack order cannot snap it back to a cell
	// center. If the target is already in range it stops after this segment.
	units.state[index] = unit_has_path(units, index) ? .Moving : .Idle
}

@(private)
apply_patrol :: proc(game: ^Game, index: int, command: Command) {
	units := &game.units
	a := command.from_current ? units.position[index] : command.position
	b := command.point_b
	at_a := !unit_between_cells(units, index) && cells_equal(units.position[index], a)
	dest := at_a ? b : a
	to_b := at_a
	if !unit_between_cells(units, index) && cells_equal(units.position[index], dest) {
		unit_clear_path(units, index)
	} else if !issue_move_path(game, index, dest) {
		return
	}
	units.attack_target[index] = INVALID_HANDLE
	units.attack_move_active[index] = false
	units.patrol_active[index] = true
	units.patrol_a[index] = a
	units.patrol_b[index] = b
	units.patrol_to_b[index] = to_b
	units.state[index] = .Patrol
}

@(private)
apply_attack_move :: proc(game: ^Game, index: int, dest: Grid_Pos) {
	units := &game.units
	if !unit_between_cells(units, index) && cells_equal(units.position[index], dest) {
		unit_clear_path(units, index)
	} else if !issue_move_path(game, index, dest) {
		return
	}
	units.attack_target[index] = INVALID_HANDLE
	units.patrol_active[index] = false
	units.attack_move_active[index] = true
	units.attack_move_dest[index] = dest
	units.state[index] = .Attack_Move
}
