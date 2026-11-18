// Snapshot, JSON encoding and ASCII fog map helpers.
package control

import "core:encoding/json"
import g "../game"

Snapshot :: struct {
	ok: bool `json:"ok"`,
	tick: u64 `json:"tick"`,
	player_grid: [2]i32 `json:"player_grid"`,
	player_alive: bool `json:"player_alive"`,
	enemy_grid: [2]i32 `json:"enemy_grid"`,
	enemy_alive: bool `json:"enemy_alive"`,
	level_complete: bool `json:"level_complete"`,
	game_over: bool `json:"game_over"`,
	waypoint: int `json:"waypoint"`,
	waypoints_total: int `json:"waypoints_total"`,
	fog_percent: f32 `json:"fog_percent"`,
	alive_units: int `json:"alive_units"`,
	selected: int `json:"selected"`,
	command_count: int `json:"command_count"`,
	command_rejected: u32 `json:"command_rejected"`,
	hash: u64 `json:"hash"`,
	valid: bool `json:"valid"`,
	validation: string `json:"validation"`,
}

Unit_Info :: struct {
	index: int `json:"index"`,
	team: string `json:"team"`,
	position: [2]i32 `json:"position"`,
	world: [2]f32 `json:"world"`,
	progress: f32 `json:"progress"`,
	next: [2]i32 `json:"next"`,
	hp: u16 `json:"hp"`,
	hp_max: u16 `json:"hp_max"`,
	state: string `json:"state"`,
	path_len: int `json:"path_len"`,
	path_index: int `json:"path_index"`,
	selected: bool `json:"selected"`,
	patrol: bool `json:"patrol"`,
	attack_move: bool `json:"attack_move"`,
	attack_target: int `json:"attack_target"`,
}

make_result :: proc(game: ^g.Game, ok: bool, msg: string) -> Result {
	view := g.state_view(game)
	err := g.validate_game(game)
	validation := "ok"
	if err != .None {
		validation = g.validation_error_name(err)
	}
	return Result{
		ok = ok,
		msg = msg,
		tick = view.tick,
		player_grid = [2]i32{view.player_pos.x, view.player_pos.y},
		player_alive = view.player_alive,
		enemy_alive = view.enemy_alive,
		level_complete = view.level_complete,
		game_over = view.game_over,
		waypoint = view.waypoint_current,
		waypoints_total = view.waypoint_total,
		fog_percent = view.fog_percent,
		alive_units = view.alive_units,
		selected = view.selected,
		command_rejected = view.command_rejected,
		hash = view.state_hash,
		valid = err == .None,
		validation = validation,
	}
}

make_snapshot :: proc(game: ^g.Game) -> Snapshot {
	view := g.state_view(game)
	err := g.validate_game(game)
	validation := "ok"
	if err != .None {
		validation = g.validation_error_name(err)
	}
	snapshot := Snapshot{
		ok = true,
		tick = view.tick,
		player_grid = [2]i32{view.player_pos.x, view.player_pos.y},
		player_alive = view.player_alive,
		level_complete = view.level_complete,
		game_over = view.game_over,
		waypoint = view.waypoint_current,
		waypoints_total = view.waypoint_total,
		fog_percent = view.fog_percent,
		alive_units = view.alive_units,
		selected = view.selected,
		command_count = view.command_count,
		command_rejected = view.command_rejected,
		hash = view.state_hash,
		valid = err == .None,
		validation = validation,
	}
	if enemy, ok := g.game_enemy_index(game); ok {
		snapshot.enemy_alive = true
		snapshot.enemy_grid = [2]i32{game.units.position[enemy].x, game.units.position[enemy].y}
	}
	return snapshot
}

encode_snapshot :: proc(game: ^g.Game) -> (data: []byte, err: json.Marshal_Error) {
	snapshot := make_snapshot(game)
	return json.marshal(snapshot)
}

@(private)
unit_state_string :: proc(s: g.Unit_State) -> string {
	switch s {
	case .Idle:
		return "idle"
	case .Moving:
		return "moving"
	case .Patrol:
		return "patrol"
	case .Attack_Move:
		return "attack_move"
	}
	return "idle"
}

encode_units :: proc(game: ^g.Game) -> (data: []byte, err: json.Marshal_Error) {
	infos: [g.MAX_UNITS]Unit_Info
	count := 0
	for i in 0..<g.MAX_UNITS {
		units := &game.units
		if !units.alive[i] {
			continue
		}
		team := "enemy"
		if units.team[i] == .Player {
			team = "player"
		}
		state := unit_state_string(units.state[i])
		target := -1
		if g.handle_is_valid(units.attack_target[i]) {
			target = int(units.attack_target[i].index)
		}
		next := [2]i32{-1, -1}
		if units.path_index[i] < units.path_len[i] {
			cell := g.cell_position(int(units.path[i][units.path_index[i]]))
			next = [2]i32{cell.x, cell.y}
		}
		infos[count] = Unit_Info{
			index = i,
			team = team,
			position = [2]i32{units.position[i].x, units.position[i].y},
			world = [2]f32{g.fp_to_f32(units.world[i].x), g.fp_to_f32(units.world[i].y)},
			progress = f32(units.progress[i]) / f32(g.FP_ONE),
			next = next,
			hp = units.hp[i],
			hp_max = units.hp_max[i],
			state = state,
			path_len = int(units.path_len[i]),
			path_index = int(units.path_index[i]),
			selected = units.selected[i],
			patrol = units.patrol_active[i],
			attack_move = units.attack_move_active[i],
			attack_target = target,
		}
		count += 1
	}
	return json.marshal(infos[:count])
}

// ASCII map used by agents for quick spatial reasoning.
fog_text :: proc(game: ^g.Game, buffer: []byte) -> int {
	offset := 0
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			position := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			ch: u8 = ' '
			state := g.fog_state(&game.fog, position)
			if state == 0 {
				ch = '.'
			} else if g.grid_is_blocked(&game.grid, position) {
				ch = '#'
			}
			if gx >= int(g.GOAL_X) {
				ch = 'G'
			}
			for i in 0..<game.waypoints.count {
				if g.cells_equal(game.waypoints.points[i], position) {
					ch = 'w'
					if i == game.waypoints.current {
						ch = 'W'
					}
				}
			}
			for i in 0..<g.MAX_UNITS {
				units := &game.units
				if !units.alive[i] || !g.cells_equal(units.position[i], position) {
					continue
				}
				if units.team[i] == .Player {
					ch = 'P'
				} else if g.enemy_is_visible(game, i) {
					ch = 'E'
				}
			}
			if offset < len(buffer) {
				buffer[offset] = ch
				offset += 1
			}
		}
		if offset < len(buffer) {
			buffer[offset] = '\n'
			offset += 1
		}
	}
	return offset
}
