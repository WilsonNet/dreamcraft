// DreamCraft web client: deterministic simulation compiled to js_wasm32.
//
// JS owns the canvas and DOM. Odin owns simulation, input commands, state
// snapshots and a 320x200 RGBA framebuffer.
package main

import g "../game"

Game_State: g.Game
Accumulator: f64

main :: proc() {
	g.game_init(&Game_State)
	web_render()
	web_refresh_state()
	web_refresh_units()
	web_refresh_fog()
}

@(export)
web_update :: proc(dt: f64) {
	STEP :: 1.0 / 60.0
	Accumulator += clamp(dt, 0, 0.25)
	steps := 0
	for Accumulator >= STEP && steps < 5 {
		g.sim_tick(&Game_State)
		Accumulator -= STEP
		steps += 1
	}
	web_render()
}

@(export)
web_run :: proc(ticks: i32) {
	count := clamp(int(ticks), 0, 100_000)
	g.sim_run(&Game_State, count)
	Accumulator = 0
	web_render()
}

@(export)
web_reset :: proc() -> i32 {
	g.game_reset(&Game_State)
	Accumulator = 0
	web_render()
	return 1
}

@(export)
web_move :: proc(x, y: i32) -> i32 {
	if g.game_issue_move(&Game_State, position(x, y)) {
		return 1
	}
	return 0
}

@(export)
web_attack :: proc(x, y: i32) -> i32 {
	index, ok := g.unit_at(&Game_State.units, position(x, y), .Enemy)
	if !ok || !g.enemy_is_visible(&Game_State, index) {
		return 0
	}
	handle := g.unit_handle(&Game_State.units, index)
	if g.game_issue_attack(&Game_State, handle) {
		return 1
	}
	return 0
}

@(export)
web_patrol :: proc(x, y, x2, y2: i32) -> i32 {
	if g.game_issue_patrol(&Game_State, position(x, y), position(x2, y2)) {
		return 1
	}
	return 0
}

@(export)
web_patrol_to :: proc(x, y: i32) -> i32 {
	if g.game_issue_patrol_to(&Game_State, position(x, y)) {
		return 1
	}
	return 0
}

@(export)
web_attack_move :: proc(x, y: i32) -> i32 {
	if g.game_issue_attack_move(&Game_State, position(x, y)) {
		return 1
	}
	return 0
}

@(export)
web_stop :: proc() -> i32 {
	if g.game_issue_stop(&Game_State) {
		return 1
	}
	return 0
}

@(export)
web_select :: proc(x, y, additive: i32) -> i32 {
	index, ok := g.unit_at(&Game_State.units, position(x, y), .Player)
	if !ok {
		if additive == 0 {
			g.unit_clear_selection(&Game_State.units)
		}
		return i32(Game_State.units.selected_count)
	}
	if additive != 0 {
		g.unit_select(&Game_State.units, index, true)
	} else {
		g.unit_select_only(&Game_State.units, index)
	}
	return i32(Game_State.units.selected_count)
}

@(export)
web_select_all :: proc() -> i32 {
	for i in 0..<g.MAX_UNITS {
		if Game_State.units.alive[i] && Game_State.units.team[i] == .Player {
			g.unit_select(&Game_State.units, i, true)
		}
	}
	return i32(Game_State.units.selected_count)
}

@(export)
web_spawn :: proc(team: i32, x, y, hp: i32) -> i32 {
	kind := g.Team.Enemy
	if team == 0 {
		kind = .Player
	} else if team == 2 {
		kind = .Neutral
	}
	handle, ok := g.unit_spawn(&Game_State.units, &Game_State.grid, kind, position(x, y))
	if !ok {
		return 0
	}
	index, _ := g.unit_index(&Game_State.units, handle)
	if hp > 0 && hp <= i32(Game_State.units.hp_max[index]) {
		Game_State.units.hp[index] = u16(hp)
	}
	return 1
}

@(export)
web_kill :: proc(x, y: i32) -> i32 {
	target := position(x, y)
	for i in 0..<g.MAX_UNITS {
		if Game_State.units.alive[i] && g.cells_equal(Game_State.units.position[i], target) {
			g.unit_destroy(&Game_State.units, i)
			g.game_update_game_over(&Game_State)
			return 1
		}
	}
	return 0
}

@(export)
web_set_hp :: proc(x, y, hp: i32) -> i32 {
	target := position(x, y)
	for i in 0..<g.MAX_UNITS {
		if Game_State.units.alive[i] && g.cells_equal(Game_State.units.position[i], target) {
			Game_State.units.hp[i] = u16(clamp(hp, 0, i32(Game_State.units.hp_max[i])))
			return 1
		}
	}
	return 0
}

@(export)
web_teleport :: proc(x, y: i32) -> i32 {
	player, ok := g.game_player_index(&Game_State)
	if !ok {
		return 0
	}
	target := position(x, y)
	if !g.grid_is_walkable(&Game_State.grid, target) {
		return 0
	}
	Game_State.units.position[player] = target
	Game_State.units.world[player] = g.grid_to_world(target)
	g.unit_clear_path(&Game_State.units, player)
	Game_State.units.state[player] = .Idle
	return 1
}

@(export)
web_group_op :: proc(slot, op: i32) -> i32 {
	if op < 0 || op > i32(g.Group_Op.Recall) {
		return 0
	}
	return i32(g.group_apply(&Game_State.units, int(slot), g.Group_Op(op)))
}

@(export)
web_fog_state :: proc(x, y: i32) -> i32 {
	return i32(g.fog_state(&Game_State.fog, position(x, y)))
}

@(export)
web_is_blocked :: proc(x, y: i32) -> i32 {
	if g.grid_is_blocked(&Game_State.grid, position(x, y)) {
		return 1
	}
	return 0
}

@(private)
position :: proc(x, y: i32) -> g.Grid_Pos {
	return g.Grid_Pos{x = x, y = y}
}
