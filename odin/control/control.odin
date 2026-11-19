// JSON control API shared by the HTTP server and the headless runner.
//
// This replaces the Bevy Remote Protocol MCP interface. Every operation is a
// plain JSON command and every response contains a full validation status.
package control

import "core:fmt"
import g "../game"

Command :: struct {
	cmd: string `json:"cmd"`,
	x: int `json:"x"`,
	y: int `json:"y"`,
	x2: int `json:"x2"`,
	y2: int `json:"y2"`,
	value: int `json:"value"`,
	ticks: int `json:"ticks"`,
	team: string `json:"team"`,
	verify: Verify `json:"verify"`,
}

Verify :: struct {
	type: string `json:"type"`,
	x: int `json:"x"`,
	y: int `json:"y"`,
	value: int `json:"value"`,
}

Result :: struct {
	ok: bool `json:"ok"`,
	msg: string `json:"msg"`,
	tick: u64 `json:"tick"`,
	player_grid: [2]i32 `json:"player_grid"`,
	player_alive: bool `json:"player_alive"`,
	enemy_alive: bool `json:"enemy_alive"`,
	level_complete: bool `json:"level_complete"`,
	game_over: bool `json:"game_over"`,
	discovery_announced: bool `json:"discovery_announced"`,
	enemy_aggro_ticks: u16 `json:"enemy_aggro_ticks"`,
	waypoint: int `json:"waypoint"`,
	waypoints_total: int `json:"waypoints_total"`,
	fog_percent: f32 `json:"fog_percent"`,
	alive_units: int `json:"alive_units"`,
	selected: int `json:"selected"`,
	command_rejected: u32 `json:"command_rejected"`,
	hash: u64 `json:"hash"`,
	valid: bool `json:"valid"`,
	validation: string `json:"validation"`,
}

execute :: proc(game: ^g.Game, command: Command) -> Result {
	switch command.cmd {
	case "status", "state", "snapshot":
		return make_result(game, true, "Status")
	case "goto", "move", "patrol", "patrol_to", "attack", "attack_move", "stop":
		return execute_unit_command(game, command)
	case "run", "tick":
		ticks := clamp(command.ticks <= 0 ? 1 : command.ticks, 1, 100_000)
		if command.ticks > 100_000 {
			return make_result(game, false, "Tick count too large")
		}
		g.sim_run(game, ticks)
		return make_result(game, true, fmt.tprintf("Ran %d ticks", ticks))
	case "reset":
		g.game_reset(game)
		return make_result(game, true, "Level reset")
	case "verify":
		return verify(game, command.verify)
	case "select":
		return select_unit(game, command)
	case "select_all":
		for i in 0..<g.MAX_UNITS {
			if game.units.alive[i] && game.units.team[i] == .Player {
				g.unit_select(&game.units, i, true)
			}
		}
		return make_result(game, true, "Selected all player units")
	case "spawn":
		return spawn_unit(game, command)
	case "kill":
		return kill_unit(game, command)
	case "set_hp":
		return set_hp(game, command)
	case "teleport":
		return teleport_player(game, command)
	case:
		return make_result(game, false, fmt.tprintf("Unknown command: %s", command.cmd))
	}
}

@(private)
execute_unit_command :: proc(game: ^g.Game, command: Command) -> Result {
	switch command.cmd {
	case "goto", "move":
		if g.game_issue_move(game, cell(command.x, command.y)) {
			return make_result(game, true, fmt.tprintf("Moving to (%d,%d)", command.x, command.y))
		}
		return make_result(game, false, "No path or invalid destination")
	case "patrol":
		if g.game_issue_patrol(game, cell(command.x, command.y), cell(command.x2, command.y2)) {
			return make_result(game, true, "Patrol started")
		}
		return make_result(game, false, "Invalid patrol points")
	case "patrol_to":
		if g.game_issue_patrol_to(game, cell(command.x, command.y)) {
			return make_result(game, true, fmt.tprintf("Patrol to (%d,%d)", command.x, command.y))
		}
		return make_result(game, false, "Invalid patrol destination")
	case "attack":
		if index, ok := g.unit_at(&game.units, cell(command.x, command.y), .Enemy); ok {
			if g.game_issue_attack(game, g.unit_handle(&game.units, index)) {
				return make_result(game, true, "Attack ordered")
			}
		}
		return make_result(game, false, "No enemy at target")
	case "attack_move":
		if g.game_issue_attack_move(game, cell(command.x, command.y)) {
			return make_result(game, true, fmt.tprintf("Attack-move to (%d,%d)", command.x, command.y))
		}
		return make_result(game, false, "Invalid attack-move destination")
	case "stop":
		if g.game_issue_stop(game) {
			return make_result(game, true, "Stopped")
		}
		return make_result(game, false, "Stop rejected")
	}
	return make_result(game, false, "Unknown unit command")
}

cell :: proc(x, y: int) -> g.Grid_Pos {
	return g.Grid_Pos{x = i32(x), y = i32(y)}
}

select_unit :: proc(game: ^g.Game, command: Command) -> Result {
	position := cell(command.x, command.y)
	if index, ok := g.unit_at(&game.units, position, .Player); ok {
		g.unit_select_only(&game.units, index)
		return make_result(game, true, fmt.tprintf("Selected player at (%d,%d)", command.x, command.y))
	}
	return make_result(game, false, "No player unit at target")
}

spawn_unit :: proc(game: ^g.Game, command: Command) -> Result {
	team := g.Team.Enemy
	if command.team == "player" {
		team = .Player
	}
	handle, ok := g.unit_spawn(&game.units, &game.grid, team, cell(command.x, command.y))
	if !ok {
		return make_result(game, false, "Spawn rejected (blocked, occupied, or capacity)")
	}
	index, _ := g.unit_index(&game.units, handle)
	if command.value > 0 && command.value <= int(game.units.hp_max[index]) {
		game.units.hp[index] = u16(command.value)
	}
	return make_result(game, true, fmt.tprintf("Spawned %s at (%d,%d)", command.team, command.x, command.y))
}

kill_unit :: proc(game: ^g.Game, command: Command) -> Result {
	position := cell(command.x, command.y)
	for i in 0..<g.MAX_UNITS {
		if game.units.alive[i] && g.cells_equal(game.units.position[i], position) {
			g.unit_destroy(&game.units, i)
			g.game_update_game_over(game)
			return make_result(game, true, fmt.tprintf("Killed unit at (%d,%d)", command.x, command.y))
		}
	}
	return make_result(game, false, "No unit at target")
}

set_hp :: proc(game: ^g.Game, command: Command) -> Result {
	position := cell(command.x, command.y)
	for i in 0..<g.MAX_UNITS {
		if game.units.alive[i] && g.cells_equal(game.units.position[i], position) {
			hp := clamp(command.value, 0, int(game.units.hp_max[i]))
			game.units.hp[i] = u16(hp)
			return make_result(game, true, fmt.tprintf("Set hp to %d", hp))
		}
	}
	return make_result(game, false, "No unit at target")
}

teleport_player :: proc(game: ^g.Game, command: Command) -> Result {
	player, ok := g.game_player_index(game)
	if !ok {
		return make_result(game, false, "Player is dead")
	}
	position := cell(command.x, command.y)
	if !g.grid_is_walkable(&game.grid, position) {
		return make_result(game, false, "Teleport target is blocked")
	}
	units := &game.units
	units.position[player] = position
	units.world[player] = g.grid_to_world(position)
	g.unit_clear_path(units, player)
	units.state[player] = .Idle
	return make_result(game, true, fmt.tprintf("Teleported player to (%d,%d)", command.x, command.y))
}

verify :: proc(game: ^g.Game, spec: Verify) -> Result {
	switch spec.type {
	case "player_at":
		position, ok := g.game_player_position(game)
		if !ok {
			return make_result(game, false, "Player is dead")
		}
		expected := cell(spec.x, spec.y)
		if g.cells_equal(position, expected) {
			return make_result(game, true, "Player at expected position")
		}
		return make_result(
			game,
			false,
			fmt.tprintf("Player at (%d,%d), expected (%d,%d)", position.x, position.y, expected.x, expected.y),
		)
	case "level_complete":
		if game.level_complete {
			return make_result(game, true, "Level complete")
		}
		return make_result(game, false, "Level not complete")
	case "enemy_dead":
		if _, ok := g.game_enemy_index(game); ok {
			return make_result(game, false, "Enemy alive")
		}
		return make_result(game, true, "Enemy dead")
	case "path_clear":
		if player, ok := g.game_player_index(game); ok && g.unit_has_path(&game.units, player) {
			return make_result(game, false, "Player still moving")
		}
		return make_result(game, true, "Player stopped")
	case "valid":
		return validate_result(game)
	case "fog_visible":
		if g.fog_is_visible(&game.fog, cell(spec.x, spec.y)) {
			return make_result(game, true, "Cell is visible")
		}
		return make_result(game, false, "Cell is not visible")
	case "blocked":
		if g.grid_is_blocked(&game.grid, cell(spec.x, spec.y)) {
			return make_result(game, true, "Cell is blocked")
		}
		return make_result(game, false, "Cell is walkable")
	case "hash":
		view := g.state_view(game)
		if spec.value != 0 {
			if u64(spec.value) == u64(view.state_hash) {
				return make_result(game, true, "Hash matches")
			}
			return make_result(game, false, fmt.tprintf("Hash %d, expected %d", view.state_hash, spec.value))
		}
		return make_result(game, true, fmt.tprintf("Hash %d", view.state_hash))
	case:
		return make_result(game, false, fmt.tprintf("Unknown verify type: %s", spec.type))
	}
}

validate_result :: proc(game: ^g.Game) -> Result {
	err := g.validate_game(game)
	if err == .None {
		return make_result(game, true, "State is valid")
	}
	return make_result(game, false, fmt.tprintf("State invalid: %s", g.validation_error_name(err)))
}
