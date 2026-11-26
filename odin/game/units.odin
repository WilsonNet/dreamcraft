// Fixed-capacity struct-of-arrays unit storage with generation handles.
//
// A handle is {slot, generation}. Destruction bumps the generation, so stale
// handles can never hit a recycled slot.
package game

Unit_Order :: struct {
	kind:     Command_Kind,
	position: Grid_Pos,
	point_b:  Grid_Pos,
	target:   Unit_Handle,
}

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

	attack_move_active: [MAX_UNITS]bool,
	attack_move_dest: [MAX_UNITS]Grid_Pos,

	attack_target: [MAX_UNITS]Unit_Handle,
	cooldown: [MAX_UNITS]u16,
	discovered: [MAX_UNITS]bool,
	aggro_timer: [MAX_UNITS]u16,
	selected: [MAX_UNITS]bool,
	group_mask: [MAX_UNITS]u16,
	order_queue: [MAX_UNITS][MAX_UNIT_ORDERS]Unit_Order,
	order_count: [MAX_UNITS]u8,

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

unit_default_hp_max :: proc(kind: Unit_Kind) -> u16 {
	switch kind {
	case .Melee:
		return MAX_HP
	case .Hero:
		return HERO_MAX_HP
	}
	return MAX_HP
}

unit_attack_damage :: proc(units: ^Units, index: int) -> u16 {
	switch units.kind[index] {
	case .Melee:
		return ATTACK_DAMAGE
	case .Hero:
		return HERO_ATTACK_DAMAGE
	}
	return ATTACK_DAMAGE
}

unit_attack_cooldown :: proc(units: ^Units, index: int) -> u16 {
	switch units.kind[index] {
	case .Melee:
		return ATTACK_COOLDOWN_TICKS
	case .Hero:
		return HERO_ATTACK_COOLDOWN_TICKS
	}
	return ATTACK_COOLDOWN_TICKS
}

unit_default_speed :: proc(kind: Unit_Kind) -> i32 {
	switch kind {
	case .Melee:
		return BASE_SPEED
	case .Hero:
		return HERO_SPEED
	}
	return BASE_SPEED
}

unit_armor :: proc(units: ^Units, index: int) -> u16 {
	switch units.kind[index] {
	case .Melee:
		return BASE_ARMOR
	case .Hero:
		return HERO_ARMOR
	}
	return BASE_ARMOR
}

unit_move_step :: proc(units: ^Units, index: int) -> Fp {
	switch units.kind[index] {
	case .Melee:
		return MOVE_STEP_PER_TICK
	case .Hero:
		return HERO_STEP_PER_TICK
	}
	return MOVE_STEP_PER_TICK
}

unit_spawn :: proc(
	units: ^Units,
	grid: ^Grid,
	team: Team,
	position: Grid_Pos,
	kind: Unit_Kind = .Melee,
) -> (handle: Unit_Handle, ok: bool) {
	if units.free_count <= 0 || !in_bounds(position) || grid_is_blocked(grid, position) {
		return INVALID_HANDLE, false
	}
	index := int(units.free_slots[units.free_count - 1])
	units.free_count -= 1
	assert(!units.alive[index], "free slot is alive")

	units.generation[index] += 1
	if units.generation[index] == 0 {
		units.generation[index] = 1
	}
	unit_init_slot(units, index, team, position, kind)
	units.alive_count += 1
	return Unit_Handle{index = u16(index), generation = units.generation[index]}, true
}

@(private)
unit_init_slot :: proc(units: ^Units, index: int, team: Team, position: Grid_Pos, kind: Unit_Kind) {
	hp_max := unit_default_hp_max(kind)
	units.alive[index] = true
	units.team[index] = team
	units.race[index] = .Basic
	units.kind[index] = kind
	units.position[index] = position
	units.world[index] = grid_to_world(position)
	units.speed[index] = fp_from_int(unit_default_speed(kind))
	units.hp[index] = hp_max
	units.hp_max[index] = hp_max
	units.state[index] = .Idle
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.patrol_active[index] = false
	units.patrol_a[index] = position
	units.patrol_b[index] = position
	units.patrol_to_b[index] = false
	units.attack_move_active[index] = false
	units.attack_move_dest[index] = position
	units.attack_target[index] = INVALID_HANDLE
	units.cooldown[index] = 0
	units.discovered[index] = false
	units.aggro_timer[index] = 0
	units.selected[index] = false
	units.group_mask[index] = 0
	units.order_count[index] = 0
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
	units.group_mask[index] = 0
	units.order_count[index] = 0
	units.path_len[index] = 0
	units.path_index[index] = 0
	units.progress[index] = 0
	units.attack_target[index] = INVALID_HANDLE
	units.patrol_active[index] = false
	units.attack_move_active[index] = false
	units.cooldown[index] = 0
	units.discovered[index] = false
	units.aggro_timer[index] = 0
	units.alive_count -= 1

	clear_target_references(units, handle)

	units.free_slots[units.free_count] = u16(index)
	units.free_count += 1
}

@(private)
clear_target_references :: proc(units: ^Units, handle: Unit_Handle) {
	for i in 0..<MAX_UNITS {
		if !units.alive[i] {
			continue
		}
		if units.attack_target[i] == handle {
			units.attack_target[i] = INVALID_HANDLE
		}
		count := int(units.order_count[i])
		write := 0
		for q in 0..<count {
			ord := units.order_queue[i][q]
			if ord.kind == .Attack && ord.target == handle {
				continue
			}
			units.order_queue[i][write] = ord
			write += 1
		}
		units.order_count[i] = u8(write)
	}
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

unit_move_state :: proc(units: ^Units, index: int) -> Unit_State {
	if units.patrol_active[index] {
		return .Patrol
	}
	if units.attack_move_active[index] {
		return .Attack_Move
	}
	return .Moving
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

// Stop without teleporting: a unit between cells finishes the current segment
// and then becomes idle. At a cell center it stops immediately.
unit_stop_after_segment :: proc(units: ^Units, index: int) {
	if unit_between_cells(units, index) {
		units.path_len[index] = units.path_index[index] + 1
		units.state[index] = unit_move_state(units, index)
		return
	}
	unit_clear_path(units, index)
	if units.patrol_active[index] {
		units.state[index] = .Patrol
	} else if units.attack_move_active[index] {
		units.state[index] = .Attack_Move
	} else {
		units.state[index] = .Idle
	}
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
