// Read-only diagnostics snapshot used by the headless runner and tests.
package game

State_View :: struct {
	tick: u64,
	player_alive: bool,
	player_pos: Grid_Pos,
	enemy_alive: bool,
	enemy_pos: Grid_Pos,
	selected: int,
	alive_units: int,
	level_complete: bool,
	game_over: bool,
	discovery_announced: bool,
	enemy_aggro_ticks: u16,
	waypoint_current: int,
	waypoint_total: int,
	fog_percent: f32,
	command_count: int,
	command_rejected: u32,
	state_hash: State_Hash,
}

state_view :: proc(game: ^Game) -> State_View {
	view := State_View{
		tick = game.tick,
		selected = game.units.selected_count,
		alive_units = game.units.alive_count,
		level_complete = game.level_complete,
		game_over = game.game_over,
		discovery_announced = game.discovery_announced,
		waypoint_current = game.waypoints.current,
		waypoint_total = game.waypoints.count,
		fog_percent = fog_coverage_percent(&game.fog),
		command_count = game.commands.count,
		command_rejected = game.commands.rejected,
		state_hash = game_hash(game),
	}
	if player, ok := game_player_position(game); ok {
		view.player_alive = true
		view.player_pos = player
	}
	if enemy, ok := game_enemy_index(game); ok {
		view.enemy_alive = true
		view.enemy_pos = game.units.position[enemy]
	}
	for i in 0 ..< MAX_UNITS {
		if game.units.alive[i] && game.units.team[i] == .Enemy && game.units.aggro_timer[i] > view.enemy_aggro_ticks {
			view.enemy_aggro_ticks = game.units.aggro_timer[i]
		}
	}
	return view
}

state_view_hash :: proc(view: ^State_View) -> State_Hash {
	h := hash_init()
	hash_u64(&h, view.tick)
	hash_bool(&h, view.player_alive)
	hash_i32(&h, view.player_pos.x)
	hash_i32(&h, view.player_pos.y)
	hash_bool(&h, view.enemy_alive)
	hash_i32(&h, view.enemy_pos.x)
	hash_i32(&h, view.enemy_pos.y)
	hash_u32(&h, u32(view.selected))
	hash_u32(&h, u32(view.alive_units))
	hash_bool(&h, view.level_complete)
	hash_bool(&h, view.game_over)
	hash_bool(&h, view.discovery_announced)
	hash_u16(&h, view.enemy_aggro_ticks)
	hash_u32(&h, u32(view.waypoint_current))
	hash_u32(&h, view.command_rejected)
	hash_u64(&h, u64(view.state_hash))
	return State_Hash(h.value)
}
