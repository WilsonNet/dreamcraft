// Unit movement along fixed paths. Integer-only, tick-based.
package game

unit_movement :: proc(game: ^Game) {
	for index in 0..<MAX_UNITS {
		units := &game.units
		if !units.alive[index] {
			continue
		}
		if !unit_has_path(units, index) {
			if units.state[index] == .Moving {
				units.state[index] = .Idle
			}
			continue
		}
		advance_unit(game, index, MOVE_STEP_PER_TICK)
	}
}

@(private)
advance_unit :: proc(game: ^Game, index: int, distance: Fp) {
	units := &game.units
	remaining := distance

	for remaining > 0 && units.path_index[index] < units.path_len[index] {
		target_cell := cell_position(int(units.path[index][units.path_index[index]]))
		if cells_equal(units.position[index], target_cell) {
			units.path_index[index] += 1
			units.progress[index] = 0
			continue
		}

		segment_length := world_center_distance(units.position[index], target_cell)
		remaining_on_segment := segment_length - units.progress[index]
		if remaining_on_segment < 0 {
			remaining_on_segment = 0
		}

		if remaining >= remaining_on_segment {
			remaining -= remaining_on_segment
			units.position[index] = target_cell
			units.world[index] = grid_to_world(target_cell)
			units.progress[index] = 0
			units.path_index[index] += 1
			continue
		}

		units.progress[index] += remaining
		from := grid_to_world(units.position[index])
		to := grid_to_world(target_cell)
		t := fp_div(units.progress[index], segment_length)
		units.world[index] = fixed_vec_lerp(from, to, t)
		remaining = 0
	}

	if units.path_index[index] >= units.path_len[index] {
		complete_unit_path(units, index)
	}
}

@(private)
complete_unit_path :: proc(units: ^Units, index: int) {
	units.path_index[index] = units.path_len[index]
	units.progress[index] = 0
	units.world[index] = grid_to_world(units.position[index])
	if units.patrol_active[index] && units.state[index] == .Patrol {
		return
	}
	if units.attack_move_active[index] && units.state[index] == .Attack_Move {
		if !handle_is_valid(units.attack_target[index]) && cells_equal(units.position[index], units.attack_move_dest[index]) {
			units.attack_move_active[index] = false
			units.state[index] = .Idle
		}
		return
	}
	units.state[index] = .Idle
}

patrol_loop :: proc(game: ^Game) {
	units := &game.units
	for index in 0..<MAX_UNITS {
		if !units.alive[index] {
			continue
		}
		if units.patrol_active[index] {
			step_patrol_unit(game, index)
		} else if units.attack_move_active[index] {
			step_attack_move_unit(game, index)
		}
	}
}

@(private)
step_patrol_unit :: proc(game: ^Game, index: int) {
	units := &game.units
	if handle_is_valid(units.attack_target[index]) || unit_has_path(units, index) {
		return
	}
	dest := units.patrol_to_b[index] ? units.patrol_b[index] : units.patrol_a[index]
	if cells_equal(units.position[index], dest) {
		units.patrol_to_b[index] = !units.patrol_to_b[index]
		dest = units.patrol_to_b[index] ? units.patrol_b[index] : units.patrol_a[index]
		if cells_equal(units.position[index], dest) {
			return
		}
	}
	if !issue_move_path(game, index, dest) {
		units.patrol_active[index] = false
		units.state[index] = .Idle
		return
	}
	units.state[index] = .Patrol
}

@(private)
step_attack_move_unit :: proc(game: ^Game, index: int) {
	units := &game.units
	if handle_is_valid(units.attack_target[index]) || unit_has_path(units, index) {
		return
	}
	dest := units.attack_move_dest[index]
	if cells_equal(units.position[index], dest) && !unit_between_cells(units, index) {
		units.attack_move_active[index] = false
		units.state[index] = .Idle
		return
	}
	if !issue_move_path(game, index, dest) {
		units.attack_move_active[index] = false
		units.state[index] = .Idle
		return
	}
	units.state[index] = .Attack_Move
}
