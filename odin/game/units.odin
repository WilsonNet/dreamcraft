// Fixed-capacity struct-of-arrays unit storage with generation handles.
//
// A handle is {slot, generation}. Destruction bumps the generation, so stale
// handles can never hit a recycled slot.
package game

Units :: struct {
	alive: [MAX_UNITS]bool,
	generation: [MAX_UNITS]u32,
	team: [MAX_UNITS]Team,
	race: [MAX_UNITS]Race,
	kind: [MAX_UNITS]Unit_Kind,

	position: [MAX_UNITS]Grid_Pos,
	world: [MAX_UNITS]Fixed_Vec,
	speed: [MAX_UNITS]Fp,
	hp: [MAX_UNITS]u16,
	hp_max: [MAX_UNITS]u16,
	state: [MAX_UNITS]Unit_State,

	path: [MAX_UNITS][MAX_PATH]u16,
	path_len: [MAX_UNITS]u16,
	path_index: [MAX_UNITS]u16,
	progress: [MAX_UNITS]Fp,

	patrol_active: [MAX_UNITS]bool,
	patrol_a: [MAX_UNITS]Grid_Pos,
	patrol_b: [MAX_UNITS]Grid_Pos,
	patrol_to_b: [MAX_UNITS]bool,

	attack_target: [MAX_UNITS]Unit_Handle,
	cooldown: [MAX_UNITS]u16,
	selected: [MAX_UNITS]bool,

	free_slots: [MAX_UNITS]u16,
	free_count: int,
	alive_count: int,
	selected_count: int,
}

units_reset :: proc(units: ^Units) {
	units^ = {}
	for i in 0..<MAX_UNITS {
		units.free_slots[i] = u16(MAX_UNITS - 1 - i)
	}
	units.free_count = MAX_UNITS
}

unit_index :: proc(units: ^Units, handle: Unit_Handle) -> (index: int, ok: bool) {
	if handle.index == 0xFFFF || int(handle.index) >= MAX_UNITS {
		return 0, false
	}
	index = int(handle.index)
	if !units.alive[index] || units.generation[index] != handle.generation {
		return 0, false
	}
	return index, true
}

unit_handle :: proc(units: ^Units, index: int) -> Unit_Handle {
	assert(units.alive[index], "unit_handle on dead unit")
	return Unit_Handle{index = u16(index), generation = units.generation[index]}
}

unit_spawn :: proc(
	units: ^Units,
	grid: ^Grid,
	team: Team,
	position: Grid_Pos,
) -> (handle: Unit_Handle, ok: bool) {
	if units.free_count <= 0 {
		return INVALID_HANDLE, false
	}
	if !in_bounds(position) || grid_is_blocked(grid, position) {
		return INVALID_HANDLE, false
	}

	index := int(units.free_slots[units.free_count - 1])
	units.free_count -= 1
	assert(!units.alive[index], "free slot is alive")

	units.generation[index] += 1
	if units.generation[index] == 0 {
		units.generation[index] = 1
	}
	units.alive[index] = true
	units.team[index] = team
	units.race[index] = .Basic
	units.kind[index] = .Melee
	units.position[index] = position
	units.world[index] = grid_to_world(position)
	units.speed[index] = fp_from_int(BASE_SPEED)
	units.hp[index] = MAX_HP
	units.hp_max[index] = MAX_HP
	units.state[index] = .Idle
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.patrol_active[index] = false
	units.patrol_a[index] = position
	units.patrol_b[index] = position
	units.patrol_to_b[index] = false
	units.attack_target[index] = INVALID_HANDLE
	units.cooldown[index] = 0
	units.selected[index] = false
	units.alive_count += 1

	return Unit_Handle{index = u16(index), generation = units.generation[index]}, true
}

unit_destroy :: proc(units: ^Units, index: int) {
	assert(units.alive[index], "destroying dead unit")
	handle := unit_handle(units, index)

	units.alive[index] = false
	units.generation[index] += 1
	if units.generation[index] == 0 {
		units.generation[index] = 1
	}
	if units.selected[index] {
		units.selected_count -= 1
	}
	units.selected[index] = false
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.attack_target[index] = INVALID_HANDLE
	units.patrol_active[index] = false
	units.cooldown[index] = 0
	units.alive_count -= 1

	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.attack_target[i] == handle {
			units.attack_target[i] = INVALID_HANDLE
		}
	}

	units.free_slots[units.free_count] = u16(index)
	units.free_count += 1
}

unit_is_player :: proc(units: ^Units, index: int) -> bool {
	return units.alive[index] && units.team[index] == .Player
}

unit_is_enemy :: proc(units: ^Units, index: int) -> bool {
	return units.alive[index] && units.team[index] == .Enemy
}

unit_at :: proc(units: ^Units, position: Grid_Pos, team: Team) -> (index: int, found: bool) {
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == team && cells_equal(units.position[i], position) {
			return i, true
		}
	}
	return 0, false
}

unit_team_count :: proc(units: ^Units, team: Team) -> int {
	count := 0
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == team {
			count += 1
		}
	}
	return count
}

unit_set_path :: proc(units: ^Units, index: int, path: []u16, state: Unit_State) -> bool {
	if len(path) == 0 || len(path) > MAX_PATH {
		return false
	}
	copy(units.path[index][:], path)
	units.path_len[index] = u16(len(path))
	units.path_index[index] = 0
	units.progress[index] = 0
	units.world[index] = grid_to_world(units.position[index])
	units.state[index] = state
	return true
}

unit_clear_path :: proc(units: ^Units, index: int) {
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.world[index] = grid_to_world(units.position[index])
	if units.state[index] == .Moving {
		units.state[index] = .Idle
	}
}

unit_path :: proc(units: ^Units, index: int) -> []u16 {
	return units.path[index][:units.path_len[index]]
}

unit_has_path :: proc(units: ^Units, index: int) -> bool {
	return units.path_index[index] < units.path_len[index]
}

// True when the unit is visibly between two cells: it has leftover progress
// toward a path cell that is not its current grid position.
unit_between_cells :: proc(units: ^Units, index: int) -> bool {
	if units.progress[index] <= 0 || units.path_index[index] >= units.path_len[index] {
		return false
	}
	next := cell_position(int(units.path[index][units.path_index[index]]))
	return !cells_equal(next, units.position[index])
}

unit_path_destination :: proc(units: ^Units, index: int) -> (Grid_Pos, bool) {
	if units.path_len[index] == 0 {
		return {}, false
	}
	return cell_position(int(units.path[index][units.path_len[index] - 1])), true
}

unit_clear_selection :: proc(units: ^Units) {
	for i in 0..<MAX_UNITS {
		units.selected[i] = false
	}
	units.selected_count = 0
}

unit_select :: proc(units: ^Units, index: int, additive: bool) {
	assert(units.alive[index], "selecting dead unit")
	if !units.selected[index] {
		if !additive {
			unit_clear_selection(units)
		}
		units.selected[index] = true
		units.selected_count += 1
	}
}

unit_select_only :: proc(units: ^Units, index: int) {
	unit_clear_selection(units)
	units.selected[index] = true
	units.selected_count = 1
}

unit_any_selected :: proc(units: ^Units) -> bool {
	return units.selected_count > 0
}

unit_selected_player_count :: proc(units: ^Units) -> int {
	count := 0
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.selected[i] && units.team[i] == .Player {
			count += 1
		}
	}
	return count
}
