package control

import "core:encoding/json"
import "core:net"
import "core:strings"
import "core:testing"
import "core:time"
import g "../game"

@(test)
control_status_reports_valid_state :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	result := execute(game, Command{cmd = "status"})
	testing.expect(t, result.ok)
	testing.expect(t, result.valid)
	testing.expect_value(t, result.validation, "ok")
	testing.expect_value(t, result.tick, u64(0))
	testing.expect_value(t, result.player_grid, [2]i32{2, 25})
}

@(test)
control_goto_run_verify_flow :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	result := execute(game, Command{cmd = "goto", x = 10, y = 25})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "run", ticks = 200})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "verify", verify = Verify{type = "player_at", x = 10, y = 25}})
	testing.expect(t, result.ok)
	testing.expect(t, result.valid)
}

@(test)
control_spawn_attack_and_kill :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	testing.expect(t, execute(game, Command{cmd = "clear_enemies"}).ok)

	result := execute(game, Command{cmd = "spawn", team = "enemy", x = 5, y = 25, value = 30})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "select_all"})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "attack", x = 5, y = 25})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "run", ticks = 130})
	testing.expect(t, result.ok)
	result = execute(game, Command{cmd = "verify", verify = Verify{type = "enemy_dead"}})
	testing.expect(t, result.ok)
	testing.expect(t, result.valid)
}

@(test)
control_teleport_and_set_hp :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	result := execute(game, Command{cmd = "teleport", x = 28, y = 21})
	testing.expect(t, result.ok)
	testing.expect_value(t, result.player_grid, [2]i32{28, 21})
	result = execute(game, Command{cmd = "set_hp", x = 28, y = 21, value = 42})
	testing.expect(t, result.ok)
	player, _ := g.game_player_index(game)
	testing.expect_value(t, game.units.hp[player], u16(42))
	testing.expect(t, result.valid)
}

@(test)
control_invalid_commands_do_not_corrupt_state :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	result := execute(game, Command{cmd = "goto", x = 1000, y = -3})
	testing.expect(t, !result.ok)
	result = execute(game, Command{cmd = "teleport", x = 14, y = 20})
	testing.expect(t, !result.ok)
	result = execute(game, Command{cmd = "nonsense"})
	testing.expect(t, !result.ok)
	testing.expect(t, result.valid)
}

@(test)
control_snapshot_and_units_encode :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	snapshot := make_snapshot(game)
	testing.expect(t, snapshot.ok)
	testing.expect(t, snapshot.valid)
	testing.expect_value(t, snapshot.alive_units, g.INITIAL_UNIT_COUNT)
	testing.expect_value(t, snapshot.player_units, 1)
	testing.expect_value(t, snapshot.neutral_units, len(g.ALLY_RESCUE_SPAWNS))
	testing.expect_value(t, snapshot.enemy_units, len(g.ENEMY_SQUAD_SPAWNS))

	data, err := encode_units(game)
	testing.expect(t, err == nil)
	defer delete(data)
	infos: []Unit_Info
	unmarshal_err := json.unmarshal(data, &infos)
	defer if infos != nil {
		for info in infos {
			delete(info.name)
			delete(info.team)
			delete(info.state)
		}
		delete(infos)
	}
	testing.expect(t, unmarshal_err == nil)
	testing.expect_value(t, len(infos), g.INITIAL_UNIT_COUNT)
	testing.expect_value(t, infos[0].team, "player")
	testing.expect_value(t, infos[0].name, "Liiroy, the Bold")
	testing.expect(t, infos[0].hero)
	testing.expect_value(t, infos[0].hp_max, u16(g.HERO_MAX_HP))
	testing.expect_value(t, infos[0].damage, u16(g.HERO_ATTACK_DAMAGE))
	testing.expect_value(t, infos[0].armor, u16(g.HERO_ARMOR))
	last := infos[len(infos) - 1]
	testing.expect_value(t, last.team, "enemy")
	testing.expect_value(t, last.name, "Luk Soldier")
	testing.expect(t, !last.hero)
	testing.expect_value(t, last.damage, u16(g.ATTACK_DAMAGE))
	testing.expect_value(t, last.armor, u16(g.BASE_ARMOR))
}

@(test)
control_fog_text_contains_player_and_size :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	g.fog_mark_explored(&game.fog, g.Grid_Pos{14, 20}, 0)
	buffer: [g.GRID_CELLS + g.GRID_H]u8
	length := fog_text(game, buffer[:])
	testing.expect_value(t, length, g.GRID_CELLS + g.GRID_H)
	text := string(buffer[:length])
	testing.expect(t, strings.contains(text, "P"))
	testing.expect(t, strings.contains(text, "#"))
}

@(test)
control_http_parser :: proc(t: ^testing.T) {
	request := "POST /command HTTP/1.1\r\nHost: x\r\nContent-Length: 7\r\n\r\n{\"a\":1}"
	header_end := strings.index(request, "\r\n\r\n") + 4
	content_length := parse_content_length(transmute([]byte)request[:header_end])
	testing.expect_value(t, content_length, 7)
	method, path, body := parse_http_request(transmute([]byte)request, header_end, content_length)
	testing.expect_value(t, method, "POST")
	testing.expect_value(t, path, "/command")
	testing.expect_value(t, body, `{"a":1}`)
}

@(test)
control_http_server_round_trip :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	server: Server
	port := 17977
	if !server_start(&server, game, port) {
		testing.expect(t, false, "could not bind control test port")
		return
	}
	defer server_close(&server)

	client, err := net.dial_tcp(net.Endpoint{address = net.IP4_Loopback, port = port})
	testing.expect(t, err == nil)
	defer net.close(client)
	_ = net.set_option(client, .Receive_Timeout, 1 * time.Second)
	request := "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
	written, send_err := net.send_tcp(client, transmute([]byte)request)
	testing.expect(t, send_err == .None)
	testing.expect_value(t, written, len(request))

	server_poll(&server)

	response: [1024]u8
	length := 0
	for length < len(response) {
		read, recv_err := net.recv_tcp(client, response[length:])
		if recv_err != .None || read == 0 {
			break
		}
		length += read
	}
	text := string(response[:length])
	testing.expect(t, strings.contains(text, "HTTP/1.1 200 OK"))
	testing.expect(t, strings.contains(text, `{"ok":true}`))
}

@(test)
control_player_death_is_valid_game_over :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	result := execute(game, Command{cmd = "kill", x = 2, y = 25})
	testing.expect(t, result.ok)
	testing.expect(t, result.game_over)
	testing.expect(t, result.valid)
	testing.expect_value(t, result.validation, "ok")
}

@(test)
control_http_keep_alive_parser :: proc(t: ^testing.T) {
	keep := "GET /state HTTP/1.1\r\nHost: x\r\n\r\n"
	testing.expect(t, request_keep_alive(transmute([]byte)keep))
	close := "GET /state HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
	testing.expect(t, !request_keep_alive(transmute([]byte)close))
	old := "GET /state HTTP/1.0\r\nHost: x\r\n\r\n"
	testing.expect(t, !request_keep_alive(transmute([]byte)old))
}

@(test)
control_attack_move_and_patrol_to :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	testing.expect(t, execute(game, Command{cmd = "clear_enemies"}).ok)

	testing.expect(t, execute(game, Command{cmd = "spawn", team = "enemy", x = 6, y = 26, value = 30}).ok)
	res := execute(game, Command{cmd = "attack_move", x = 14, y = 25})
	testing.expect(t, res.ok)
	_ = execute(game, Command{cmd = "run", ticks = 350})
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "enemy_dead"}}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "player_at", x = 14, y = 25}}).ok)

	res = execute(game, Command{cmd = "patrol_to", x = 20, y = 25})
	testing.expect(t, res.ok)
	_ = execute(game, Command{cmd = "run", ticks = 220})
	player, _ := g.game_player_index(game)
	testing.expect(t, game.units.patrol_active[player])
	testing.expect(t, res.valid)
}

@(test)
control_reports_campaign_discovery_and_aggro_delay :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)
	testing.expect(t, execute(game, Command{cmd = "clear_enemies"}).ok)
	testing.expect(t, execute(game, Command{cmd = "spawn", team = "enemy", x = 7, y = 25}).ok)

	res := execute(game, Command{cmd = "run", ticks = 1})
	testing.expect(t, res.discovery_announced)
	testing.expect_value(t, res.enemy_aggro_ticks, u16(g.ENEMY_AGGRO_DELAY_TICKS))
	testing.expect(t, res.valid)
}

@(test)
control_group_ops_and_rescue_flow :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_init(game)

	testing.expect(t, execute(game, Command{cmd = "goto", x = 20, y = 25}).ok)
	res := execute(game, Command{cmd = "run", ticks = 350})
	testing.expect_value(t, res.rescued_count, 3)
	testing.expect_value(t, res.player_units, 4)

	testing.expect(t, execute(game, Command{cmd = "select_all"}).ok)
	testing.expect(t, execute(game, Command{cmd = "group_assign", value = 0}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "group_count", x = 0, value = 4}}).ok)
	testing.expect(t, execute(game, Command{cmd = "deselect"}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "selected_count", value = 0}}).ok)
	testing.expect(t, execute(game, Command{cmd = "group_select", value = 0}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "selected_count", value = 4}}).ok)
	testing.expect(t, execute(game, Command{cmd = "select", x = 19, y = 23}).ok)
	testing.expect(t, execute(game, Command{cmd = "group_steal", value = 1}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "group_count", x = 0, value = 3}}).ok)
	testing.expect(t, execute(game, Command{cmd = "verify", verify = Verify{type = "group_count", x = 1, value = 1}}).ok)
	testing.expect(t, res.valid)
}
