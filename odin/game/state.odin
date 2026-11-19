// Top-level deterministic game state.
//
// Game is a single value type with no pointers. It can be copied, hashed and
// compared in tests without touching the allocator.
package game

Waypoints :: struct {
	points: [WAYPOINT_COUNT]Grid_Pos,
	count: int,
	current: int,
}

waypoints_reset :: proc(waypoints: ^Waypoints) {
	waypoints.points = WAYPOINT_START
	waypoints.count = WAYPOINT_COUNT
	waypoints.current = 0
}

waypoint_current :: proc(waypoints: ^Waypoints) -> (Grid_Pos, bool) {
	if waypoints.current < 0 || waypoints.current >= waypoints.count {
		return {}, false
	}
	return waypoints.points[waypoints.current], true
}

Command_Kind :: enum u8 {
	Move,
	Attack,
	Patrol,
	Stop,
	Attack_Move,
}

Command :: struct {
	kind: Command_Kind,
	actor: Unit_Handle,
	position: Grid_Pos,
	point_b: Grid_Pos,
	target: Unit_Handle,
	from_current: bool,
}

Command_Queue :: struct {
	entries: [MAX_COMMANDS]Command,
	head: int,
	tail: int,
	count: int,
	rejected: u32,
}

command_queue_reset :: proc(queue: ^Command_Queue) {
	queue^ = {}
}

command_push :: proc(
	queue: ^Command_Queue,
	command: Command,
	units: ^Units,
	grid: ^Grid,
) -> bool {
	if queue.count >= MAX_COMMANDS {
		queue.rejected += 1
		return false
	}
	if !command_is_valid(command, units, grid) {
		queue.rejected += 1
		return false
	}
	queue.entries[queue.tail] = command
	queue.tail = (queue.tail + 1) % MAX_COMMANDS
	queue.count += 1
	return true
}

command_pop :: proc(queue: ^Command_Queue) -> (command: Command, ok: bool) {
	if queue.count == 0 {
		return {}, false
	}
	command = queue.entries[queue.head]
	queue.head = (queue.head + 1) % MAX_COMMANDS
	queue.count -= 1
	return command, true
}

command_is_valid :: proc(command: Command, units: ^Units, grid: ^Grid) -> bool {
	if handle_is_valid(command.actor) {
		if _, ok := unit_index(units, command.actor); !ok {
			return false
		}
	}
	switch command.kind {
	case .Move:
		return grid_is_walkable(grid, command.position)
	case .Attack:
		index, ok := unit_index(units, command.target)
		return ok && units.team[index] == .Enemy
	case .Patrol:
		if command.from_current {
			return grid_is_walkable(grid, command.point_b)
		}
		return grid_is_walkable(grid, command.position) &&
			grid_is_walkable(grid, command.point_b)
	case .Attack_Move:
		return grid_is_walkable(grid, command.position)
	case .Stop:
		return true
	}
	return false
}

Game :: struct {
	tick: u64,
	grid: Grid,
	fog: Fog,
	units: Units,
	pathfinder: Pathfinder,
	commands: Command_Queue,
	waypoints: Waypoints,
	level_complete: bool,
	game_over: bool,
	discovery_announced: bool,
	discovery_tick: u64,
	aggro_triggered_tick: u64,
}

game_init :: proc(game: ^Game) {
	game_reset(game)
}

game_reset :: proc(game: ^Game) {
	game^ = {}
	grid_init_level(&game.grid)
	fog_reset(&game.fog)
	units_reset(&game.units)
	pathfinder_reset(&game.pathfinder)
	command_queue_reset(&game.commands)
	waypoints_reset(&game.waypoints)

	player, ok := unit_spawn(&game.units, &game.grid, .Player, START_POS, .Hero)
	assert(ok, "failed to spawn player hero")
	_ = player
	enemy, ok_enemy := unit_spawn(&game.units, &game.grid, .Enemy, ENEMY_START_POS, .Melee)
	assert(ok_enemy, "failed to spawn enemy")
	_ = enemy

	fog_begin_tick(&game.fog)
	fog_reveal(&game.fog, START_POS, VISION_RADIUS)
	game.tick = 0
	game.game_over = false
}

game_update_game_over :: proc(game: ^Game) {
	_, ok := game_player_index(game)
	game.game_over = !ok
}

game_player_index :: proc(game: ^Game) -> (index: int, ok: bool) {
	for i in 0..<MAX_UNITS {
		if game.units.alive[i] && game.units.team[i] == .Player {
			return i, true
		}
	}
	return 0, false
}

game_player_position :: proc(game: ^Game) -> (Grid_Pos, bool) {
	index, ok := game_player_index(game)
	if !ok {
		return {}, false
	}
	return game.units.position[index], true
}

game_player_handle :: proc(game: ^Game) -> (Unit_Handle, bool) {
	index, ok := game_player_index(game)
	if !ok {
		return INVALID_HANDLE, false
	}
	return unit_handle(&game.units, index), true
}

game_enemy_index :: proc(game: ^Game) -> (index: int, ok: bool) {
	for i in 0..<MAX_UNITS {
		if game.units.alive[i] && game.units.team[i] == .Enemy {
			return i, true
		}
	}
	return 0, false
}

game_issue_move :: proc(game: ^Game, position: Grid_Pos) -> bool {
	command := Command{kind = .Move, position = position}
	return command_push(&game.commands, command, &game.units, &game.grid)
}

game_issue_attack :: proc(game: ^Game, target: Unit_Handle) -> bool {
	command := Command{kind = .Attack, target = target}
	return command_push(&game.commands, command, &game.units, &game.grid)
}

game_issue_patrol :: proc(game: ^Game, a, b: Grid_Pos) -> bool {
	command := Command{kind = .Patrol, position = a, point_b = b}
	return command_push(&game.commands, command, &game.units, &game.grid)
}

game_issue_patrol_to :: proc(game: ^Game, destination: Grid_Pos) -> bool {
	command := Command{kind = .Patrol, point_b = destination, from_current = true}
	return command_push(&game.commands, command, &game.units, &game.grid)
}

game_issue_attack_move :: proc(game: ^Game, destination: Grid_Pos) -> bool {
	command := Command{kind = .Attack_Move, position = destination}
	return command_push(&game.commands, command, &game.units, &game.grid)
}

game_issue_stop :: proc(game: ^Game) -> bool {
	command := Command{kind = .Stop}
	return command_push(&game.commands, command, &game.units, &game.grid)
}
