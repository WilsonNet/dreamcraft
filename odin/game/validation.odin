package game

Validation_Error :: enum u8 {
	None,
	ObstacleCountMismatch,
	FogVisibleNotExplored,
	AliveCountMismatch,
	SelectedCountMismatch,
	FreeCountMismatch,
	FreeSlotInvalid,
	UnitGenerationZero,
	UnitPositionInvalid,
	UnitOnObstacle,
	UnitWorldOutOfBounds,
	UnitHealthInvalid,
	UnitPathTooLong,
	UnitPathIndexInvalid,
	UnitPathCellInvalid,
	UnitPathBlocked,
	UnitPathNotAdjacent,
	UnitPathDetached,
	UnitStateInvalid,
	UnitPatrolInvalid,
	UnitAttackMoveInvalid,
	AttackTargetInvalid,
	AttackTargetFriendly,
	AttackTargetSelf,
	CooldownInvalid,
	UnitAggroInvalid,
	SelectedNotPlayer,
	WaypointCountInvalid,
	WaypointPositionInvalid,
	WaypointBlocked,
	WaypointCurrentInvalid,
	CommandCountInvalid,
	CommandIndicesInvalid,
	PlayerMissing,
	UnitWorldMismatch,
	UnitPathStartInvalid,
}

validate_game :: proc(game: ^Game) -> Validation_Error {
	if err := validate_grid(&game.grid); err != .None {
		return err
	}
	if err := validate_fog(&game.fog); err != .None {
		return err
	}
	if err := validate_units(&game.units, &game.grid); err != .None {
		return err
	}
	if err := validate_waypoints(&game.waypoints, &game.grid); err != .None {
		return err
	}
	if err := validate_commands(&game.commands); err != .None {
		return err
	}
	if _, ok := game_player_index(game); !ok && !game.game_over {
		return .PlayerMissing
	}
	return .None
}

validate_grid :: proc(grid: ^Grid) -> Validation_Error {
	if int(grid.obstacle_count) != bit_grid_count(&grid.obstacles) {
		return .ObstacleCountMismatch
	}
	return .None
}

validate_fog :: proc(fog: ^Fog) -> Validation_Error {
	for i in 0..<BIT_WORDS {
		if fog.visible.words[i] &~ fog.explored.words[i] != 0 {
			return .FogVisibleNotExplored
		}
	}
	return .None
}

validate_units :: proc(units: ^Units, grid: ^Grid) -> Validation_Error {
	alive := 0
	selected := 0
	for index in 0..<MAX_UNITS {
		if units.alive[index] {
			alive += 1
			if units.selected[index] {
				selected += 1
			}
			if err := validate_unit(units, grid, index); err != .None {
				return err
			}
		}
	}
	if alive != units.alive_count {
		return .AliveCountMismatch
	}
	if selected != units.selected_count {
		return .SelectedCountMismatch
	}
	if units.free_count + alive != MAX_UNITS {
		return .FreeCountMismatch
	}
	return validate_free_slots(units)
}

validate_unit :: proc(units: ^Units, grid: ^Grid, index: int) -> Validation_Error {
	if units.generation[index] == 0 {
		return .UnitGenerationZero
	}
	if !in_bounds(units.position[index]) {
		return .UnitPositionInvalid
	}
	world := units.world[index]
	if world.x < fp_from_int(WORLD_MIN_X) || world.x > fp_from_int(WORLD_MAX_X) ||
	   world.y < fp_from_int(WORLD_MIN_Y) || world.y > fp_from_int(WORLD_MAX_Y) {
		return .UnitWorldOutOfBounds
	}
	if units.hp[index] == 0 || units.hp_max[index] == 0 ||
	   units.hp[index] > units.hp_max[index] {
		return .UnitHealthInvalid
	}
	if units.path_len[index] > MAX_PATH || units.path_index[index] > units.path_len[index] {
		return .UnitPathIndexInvalid
	}
	if err := validate_unit_path(units, grid, index); err != .None {
		return err
	}
	if err := validate_unit_world(units, index); err != .None {
		return err
	}
	return validate_unit_orders(units, grid, index)
}

@(private)
validate_unit_orders :: proc(units: ^Units, grid: ^Grid, index: int) -> Validation_Error {
	if units.state[index] == .Moving && !unit_has_path(units, index) {
		return .UnitStateInvalid
	}
	if units.patrol_active[index] {
		if units.state[index] != .Patrol || units.attack_move_active[index] {
			return .UnitPatrolInvalid
		}
	}
	if units.attack_move_active[index] {
		if units.state[index] != .Attack_Move || units.patrol_active[index] || !grid_is_walkable(grid, units.attack_move_dest[index]) {
			return .UnitAttackMoveInvalid
		}
	} else if units.state[index] == .Attack_Move {
		return .UnitAttackMoveInvalid
	}
	if units.cooldown[index] > unit_attack_cooldown(units, index) {
		return .CooldownInvalid
	}
	if units.aggro_timer[index] > ENEMY_AGGRO_DELAY_TICKS || (!units.discovered[index] && units.aggro_timer[index] != 0) {
		return .UnitAggroInvalid
	}
	if units.selected[index] && units.team[index] != .Player {
		return .SelectedNotPlayer
	}
	return validate_attack_target(units, index)
}

validate_unit_path :: proc(units: ^Units, grid: ^Grid, index: int) -> Validation_Error {
	if units.path_len[index] > MAX_PATH {
		return .UnitPathTooLong
	}
	if units.path_len[index] > 0 && units.path_index[index] == 0 &&
	   units.progress[index] == 0 &&
	   !cells_equal(cell_position(int(units.path[index][0])), units.position[index]) {
		return .UnitPathStartInvalid
	}
	previous := units.position[index]
	for i in 0..<int(units.path_len[index]) {
		cell := cell_position(int(units.path[index][i]))
		if !in_bounds(cell) {
			return .UnitPathCellInvalid
		}
		if grid_is_blocked(grid, cell) {
			return .UnitPathBlocked
		}
		if i > 0 && !cells_adjacent(cell_position(int(units.path[index][i - 1])), cell) {
			return .UnitPathNotAdjacent
		}
		if i >= int(units.path_index[index]) && !cells_adjacent(previous, cell) &&
		   !cells_equal(previous, cell) {
			return .UnitPathDetached
		}
		previous = cell
	}
	if units.progress[index] < 0 || units.progress[index] > FP_SQRT2 {
		return .UnitPathCellInvalid
	}
	return .None
}

validate_unit_world :: proc(units: ^Units, index: int) -> Validation_Error {
	expected := grid_to_world(units.position[index])
	if units.path_index[index] < units.path_len[index] {
		next_cell := cell_position(int(units.path[index][units.path_index[index]]))
		if !cells_equal(next_cell, units.position[index]) {
			length := world_center_distance(units.position[index], next_cell)
			t := fp_div(units.progress[index], length)
			expected = fixed_vec_lerp(grid_to_world(units.position[index]), grid_to_world(next_cell), t)
		}
	}
	if abs(units.world[index].x - expected.x) > 2 || abs(units.world[index].y - expected.y) > 2 {
		return .UnitWorldMismatch
	}
	return .None
}

validate_attack_target :: proc(units: ^Units, index: int) -> Validation_Error {
	target := units.attack_target[index]
	if !handle_is_valid(target) {
		return .None
	}
	target_index, ok := unit_index(units, target)
	if !ok {
		return .AttackTargetInvalid
	}
	if target_index == index {
		return .AttackTargetSelf
	}
	if units.team[target_index] == units.team[index] {
		return .AttackTargetFriendly
	}
	return .None
}

validate_free_slots :: proc(units: ^Units) -> Validation_Error {
	seen: [MAX_UNITS]bool
	for i := 0; i < units.free_count; i += 1 {
		index := int(units.free_slots[i])
		if index < 0 || index >= MAX_UNITS || units.alive[index] || seen[index] {
			return .FreeSlotInvalid
		}
		seen[index] = true
	}
	return .None
}

validate_waypoints :: proc(waypoints: ^Waypoints, grid: ^Grid) -> Validation_Error {
	if waypoints.count != WAYPOINT_COUNT {
		return .WaypointCountInvalid
	}
	if waypoints.current < 0 || waypoints.current > waypoints.count {
		return .WaypointCurrentInvalid
	}
	for i in 0..<waypoints.count {
		point := waypoints.points[i]
		if !in_bounds(point) {
			return .WaypointPositionInvalid
		}
		if grid_is_blocked(grid, point) {
			return .WaypointBlocked
		}
	}
	return .None
}

validate_commands :: proc(queue: ^Command_Queue) -> Validation_Error {
	if queue.count < 0 || queue.count > MAX_COMMANDS {
		return .CommandCountInvalid
	}
	if queue.head < 0 || queue.head >= MAX_COMMANDS ||
	   queue.tail < 0 || queue.tail >= MAX_COMMANDS {
		return .CommandIndicesInvalid
	}
	return .None
}

level_validate :: proc(grid: ^Grid, pf: ^Pathfinder) -> Validation_Error {
	if start_blocked(grid) {
		return .UnitOnObstacle
	}
	waypoints: Waypoints
	waypoints_reset(&waypoints)
	if err := validate_waypoints(&waypoints, grid); err != .None {
		return err
	}
	if grid_is_blocked(grid, ENEMY_START_POS) {
		return .UnitOnObstacle
	}
	if grid_is_blocked(grid, Grid_Pos{GOAL_X + 1, GRID_H / 2}) {
		return .WaypointBlocked
	}

	previous := START_POS
	scratch: [MAX_PATH]u16
	for point in WAYPOINT_START {
		length, result := find_path(pf, grid, previous, point, scratch[:])
		if result != .Found || length == 0 {
			return .WaypointBlocked
		}
		previous = point
	}
	return .None
}

@(private)
start_blocked :: proc(grid: ^Grid) -> bool {
	return grid_is_blocked(grid, START_POS)
}

validation_error_name :: proc(err: Validation_Error) -> string {
	return validation_error_name_a(err)
}

@(private)
validation_error_name_a :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .None:
		return "none"
	case .ObstacleCountMismatch:
		return "obstacle count mismatch"
	case .FogVisibleNotExplored:
		return "fog: visible cell is not explored"
	case .AliveCountMismatch:
		return "alive count mismatch"
	case .SelectedCountMismatch:
		return "selected count mismatch"
	case .FreeCountMismatch:
		return "free slot count mismatch"
	case .FreeSlotInvalid:
		return "invalid free slot"
	case .UnitGenerationZero:
		return "unit generation is zero"
	case .UnitPositionInvalid:
		return "unit position out of bounds"
	case .UnitOnObstacle:
		return "unit stands on an obstacle"
	case .UnitWorldOutOfBounds:
		return "unit world position out of bounds"
	case .UnitHealthInvalid:
		return "unit health invalid"
	case:
		return validation_error_name_b(err)
	}
}

@(private)
validation_error_name_b :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .UnitPathTooLong:
		return "unit path too long"
	case .UnitPathIndexInvalid:
		return "unit path index invalid"
	case .UnitPathCellInvalid:
		return "unit path cell invalid"
	case .UnitPathBlocked:
		return "unit path crosses an obstacle"
	case .UnitPathNotAdjacent:
		return "unit path has non-adjacent cells"
	case .UnitPathDetached:
		return "unit path is detached from unit position"
	case .UnitStateInvalid:
		return "unit state inconsistent with path"
	case .UnitPatrolInvalid:
		return "unit patrol state invalid"
	case .UnitAttackMoveInvalid:
		return "unit attack-move state invalid"
	case .AttackTargetInvalid:
		return "attack target handle is stale"
	case .AttackTargetFriendly:
		return "attack target is friendly"
	case .AttackTargetSelf:
		return "unit targets itself"
	case .CooldownInvalid:
		return "attack cooldown out of range"
	case .UnitAggroInvalid:
		return "unit aggro timer state invalid"
	case:
		return validation_error_name_c(err)
	}
}

@(private)
validation_error_name_c :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .SelectedNotPlayer:
		return "enemy unit is selected"
	case .WaypointCountInvalid:
		return "waypoint count invalid"
	case .WaypointPositionInvalid:
		return "waypoint position invalid"
	case .WaypointBlocked:
		return "waypoint is blocked"
	case .WaypointCurrentInvalid:
		return "current waypoint index invalid"
	case .CommandCountInvalid:
		return "command count invalid"
	case .CommandIndicesInvalid:
		return "command queue indices invalid"
	case .PlayerMissing:
		return "player unit is missing"
	case .UnitWorldMismatch:
		return "unit world position does not match path state"
	case .UnitPathStartInvalid:
		return "unit path does not start at unit position"
	case:
		return "unknown validation error"
	}
}
