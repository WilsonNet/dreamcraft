// Web API snapshots: compact JSON state, unit list, ASCII fog map.
package main

import "core:fmt"
import g "../game"

State_Buffer: [4096]u8
State_Length: int
Units_Buffer: [65536 + 1]u8
Units_Length: int
Fog_Buffer: [g.GRID_CELLS + g.GRID_H + 1]u8
Fog_Length: int

@(export)
web_refresh_state :: proc() -> i32 {
	view := g.state_view(&Game_State)
	err := g.validate_game(&Game_State)
	validation := "ok"
	if err != .None {
		validation = g.validation_error_name(err)
	}
	text := fmt.bprintf(
		State_Buffer[:len(State_Buffer) - 1],
		`{{"ok":true,"tick":%d,"player_grid":[%d,%d],"player_alive":%t,"enemy_grid":[%d,%d],"enemy_alive":%t,"level_complete":%t,"game_over":%t,"waypoint":%d,"waypoints_total":%d,"fog_percent":%.1f,"alive_units":%d,"selected":%d,"command_count":%d,"command_rejected":%d,"hash":"%d","valid":%t,"validation":"%s"}}`,
		view.tick,
		view.player_pos.x,
		view.player_pos.y,
		view.player_alive,
		view.enemy_pos.x,
		view.enemy_pos.y,
		view.enemy_alive,
		view.level_complete,
		view.game_over,
		view.waypoint_current,
		view.waypoint_total,
		view.fog_percent,
		view.alive_units,
		view.selected,
		view.command_count,
		view.command_rejected,
		view.state_hash,
		err == .None,
		validation,
	)
	State_Length = len(text)
	State_Buffer[State_Length] = 0
	return 1
}

@(export)
web_state_ptr :: proc() -> rawptr {
	return raw_data(State_Buffer[:])
}

@(export)
web_state_len :: proc() -> i32 {
	return i32(State_Length)
}

@(export)
web_refresh_units :: proc() -> i32 {
	offset := 0
	Units_Buffer[offset] = '['
	offset += 1
	first := true
	for i in 0..<g.MAX_UNITS {
		units := &Game_State.units
		if !units.alive[i] {
			continue
		}
		if !first {
			Units_Buffer[offset] = ','
			offset += 1
		}
		first = false
		team := "enemy"
		if units.team[i] == .Player {
			team = "player"
		}
		state := "idle"
		switch units.state[i] {
		case .Idle:
			state = "idle"
		case .Moving:
			state = "moving"
		case .Patrol:
			state = "patrol"
		}
		target := -1
		if g.handle_is_valid(units.attack_target[i]) {
			target = int(units.attack_target[i].index)
		}
		next := [2]i32{-1, -1}
		if units.path_index[i] < units.path_len[i] {
			cell := g.cell_position(int(units.path[i][units.path_index[i]]))
			next = [2]i32{cell.x, cell.y}
		}
		text := fmt.bprintf(
			Units_Buffer[offset:len(Units_Buffer) - 8],
			`{{"index":%d,"team":"%s","position":[%d,%d],"world":[%.2f,%.2f],"progress":%.3f,"next":[%d,%d],"hp":%d,"hp_max":%d,"state":"%s","path_len":%d,"path_index":%d,"selected":%t,"patrol":%t,"attack_target":%d,"visible":%t}}`,
			i,
			team,
			units.position[i].x,
			units.position[i].y,
			g.fp_to_f32(units.world[i].x),
			g.fp_to_f32(units.world[i].y),
			f32(units.progress[i]) / f32(g.FP_ONE),
			next[0],
			next[1],
			units.hp[i],
			units.hp_max[i],
			state,
			units.path_len[i],
			units.path_index[i],
			units.selected[i],
			units.patrol_active[i],
			target,
			g.enemy_is_visible(&Game_State, i),
		)
		offset += len(text)
	}
	Units_Buffer[offset] = ']'
	offset += 1
	Units_Length = offset
	Units_Buffer[Units_Length] = 0
	return 1
}

@(export)
web_units_ptr :: proc() -> rawptr {
	return raw_data(Units_Buffer[:])
}

@(export)
web_units_len :: proc() -> i32 {
	return i32(Units_Length)
}

@(export)
web_refresh_fog :: proc() -> i32 {
	offset := 0
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			position := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			ch: u8 = ' '
			state := g.fog_state(&Game_State.fog, position)
			if state == 0 {
				ch = '.'
			} else if g.grid_is_blocked(&Game_State.grid, position) {
				ch = '#'
			}
			if gx >= int(g.GOAL_X) {
				ch = 'G'
			}
			for i in 0..<Game_State.waypoints.count {
				if g.cells_equal(Game_State.waypoints.points[i], position) {
					ch = 'w'
					if i == Game_State.waypoints.current {
						ch = 'W'
					}
				}
			}
			for i in 0..<g.MAX_UNITS {
				units := &Game_State.units
				if !units.alive[i] || !g.cells_equal(units.position[i], position) {
					continue
				}
				if units.team[i] == .Player {
					ch = 'P'
				} else if g.enemy_is_visible(&Game_State, i) {
					ch = 'E'
				}
			}
			Fog_Buffer[offset] = ch
			offset += 1
		}
		Fog_Buffer[offset] = '\n'
		offset += 1
	}
	Fog_Length = offset
	Fog_Buffer[Fog_Length] = 0
	return 1
}

@(export)
web_fog_ptr :: proc() -> rawptr {
	return raw_data(Fog_Buffer[:])
}

@(export)
web_fog_len :: proc() -> i32 {
	return i32(Fog_Length)
}
