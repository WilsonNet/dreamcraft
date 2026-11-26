#+build !js
package game

import "core:testing"

@(test)
game_initializes_valid :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
	testing.expect_value(t, game.units.alive_count, 2)
	testing.expect_value(t, game.units.selected_count, 0)
	testing.expect_value(t, game.waypoints.current, 0)
	testing.expect(t, !game.level_complete)
}

@(test)
game_ticks_without_invariant_break :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	sim_run(game, 1000)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
	testing.expect_value(t, game.tick, u64(1000))
}

@(test)
move_command_moves_player_to_exact_cell :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	handle, _ := game_player_handle(game)
	command_push(&game.commands, Command{kind = .Move, actor = handle, position = {5, 25}}, &game.units, &game.grid)
	sim_run(game, 200)

	position, _ := game_player_position(game)
	testing.expect_value(t, position, Grid_Pos{5, 25})
	index, _ := game_player_index(game)
	testing.expect_value(t, game.units.state[index], Unit_State.Idle)
	testing.expect(t, !unit_has_path(&game.units, index))
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
move_command_rejects_wall_and_capacity :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	testing.expect(t, !game_issue_move(game, Grid_Pos{8, 20}), "tree cell must be rejected")
	testing.expect(t, !game_issue_move(game, Grid_Pos{-1, 0}), "out of bounds must be rejected")
	testing.expect(t, !game_issue_move(game, Grid_Pos{GOAL_X, GRID_H}), "out of bounds must be rejected")
	testing.expect_value(t, game.commands.count, 0)
	testing.expect(t, game.commands.rejected >= 3)
}

@(test)
command_queue_is_bounded :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	handle, _ := game_player_handle(game)
	for i in 0..<MAX_COMMANDS {
		cmd := Command{kind = .Move, actor = handle, position = Grid_Pos{2 + i32(i % 3), 25}}
		testing.expect(t, command_push(&game.commands, cmd, &game.units, &game.grid))
	}
	cmd := Command{kind = .Move, actor = handle, position = Grid_Pos{5, 25}}
	testing.expect(t, !command_push(&game.commands, cmd, &game.units, &game.grid))
	testing.expect_value(t, game.commands.count, MAX_COMMANDS)
	testing.expect_value(t, validate_commands(&game.commands), Validation_Error.None)
}

@(test)
attack_command_kills_adjacent_enemy :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_index, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_index)
	enemy, ok := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{5, 25})
	testing.expect(t, ok)
	game.units.hp[enemy_index] = 60

	player, _ := game_player_handle(game)
	command_push(
		&game.commands,
		Command{kind = .Attack, actor = player, target = enemy},
		&game.units,
		&game.grid,
	)
	sim_run(game, 130)

	_, alive := unit_index(&game.units, enemy)
	testing.expect(t, !alive, "enemy should be dead")
	player_index, _ := game_player_index(game)
	testing.expect_value(t, game.units.attack_target[player_index], INVALID_HANDLE)
	testing.expect(t, game.units.hp[player_index] < game.units.hp_max[player_index], "enemy should have hit back")
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
patrol_loops_between_two_points :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_index, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_index)
	player, _ := game_player_handle(game)

	a := Grid_Pos{4, 25}
	b := Grid_Pos{7, 25}
	command_push(
		&game.commands,
		Command{kind = .Patrol, actor = player, position = a, point_b = b},
		&game.units,
		&game.grid,
	)

	seen_a := false
	seen_b := false
	index, _ := game_player_index(game)
	for _ in 0..<400 {
		sim_tick(game)
		if cells_equal(game.units.position[index], a) {
			seen_a = true
		}
		if cells_equal(game.units.position[index], b) {
			seen_b = true
		}
	}
	testing.expect(t, seen_a, "patrol never reached A")
	testing.expect(t, seen_b, "patrol never reached B")
	testing.expect(t, game.units.patrol_active[index], "patrol should still be active")
	testing.expect_value(t, game.units.state[index], Unit_State.Patrol)
}

@(test)
player_reaches_goal_and_completes_level :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_index, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_index)
	testing.expect(t, sim_move_player(game, Grid_Pos{77, 25}, 3000))
	testing.expect(t, game.level_complete)
	position, _ := game_player_position(game)
	testing.expect_value(t, position, Grid_Pos{77, 25})
}

@(test)
waypoints_advance_when_reached :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_index, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_index)
	for i in 0..<3 {
		point := WAYPOINT_START[i]
		testing.expectf(t, sim_move_player(game, point, 1000), "failed to reach waypoint %d", i)
		testing.expect_value(t, game.waypoints.current, i + 1)
	}
}

@(test)
game_reset_restores_initial_state :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	initial_hash := game_hash(game)
	handle, _ := game_player_handle(game)
	command_push(&game.commands, Command{kind = .Move, actor = handle, position = {20, 25}}, &game.units, &game.grid)
	sim_run(game, 200)
	testing.expect(t, game_hash(game) != initial_hash)
	game_reset(game)
	testing.expect_value(t, game_hash(game), initial_hash)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
same_inputs_produce_same_state_hash :: proc(t: ^testing.T) {
	run_script :: proc(game: ^Game) -> State_Hash {
		game_init(game)
		player, _ := game_player_handle(game)
		push := proc(game: ^Game, command: Command) {
			command_push(&game.commands, command, &game.units, &game.grid)
		}
		push(game, Command{kind = .Move, actor = player, position = {20, 25}})
		sim_run(game, 300)
		push(game, Command{kind = .Patrol, actor = player, position = {30, 23}, point_b = {40, 23}})
		sim_run(game, 400)
		push(game, Command{kind = .Stop, actor = player})
		sim_run(game, 100)
		return game_hash(game)
	}

	a := new(Game)
	defer free(a)
	b := new(Game)
	defer free(b)
	hash_a := run_script(a)
	hash_b := run_script(b)
	testing.expect_value(t, hash_a, hash_b)
}

@(test)
player_death_sets_game_over_and_stays_valid :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, _ := game_player_index(game)
	game.units.hp[player] = 0
	sim_tick(game)
	testing.expect(t, game.game_over)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
	_, alive := game_player_index(game)
	testing.expect(t, !alive)
}

@(test)
reorder_move_preserves_mid_segment_position :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, ok := game_player_index(game)
	testing.expect(t, ok)

	testing.expect(t, game_issue_move(game, Grid_Pos{12, 25}))
	sim_run(game, 6)
	testing.expect(t, unit_between_cells(&game.units, player))
	before := game.units.world[player]

	testing.expect(t, game_issue_move(game, Grid_Pos{20, 25}))
	sim_tick(game)
	after := game.units.world[player]

	// Exactly one tick of forward travel, not a reset to the cell center.
	testing.expect_value(t, after.x - before.x, unit_move_step(&game.units, player) * CELL_SIZE)
	testing.expect_value(t, after.y, before.y)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
blocked_move_click_does_not_stop_or_snap_unit :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, ok := game_player_index(game)
	testing.expect(t, ok)

	testing.expect(t, game_issue_move(game, Grid_Pos{12, 25}))
	sim_run(game, 6)
	game.units.patrol_active[player] = true
	game.units.state[player] = .Patrol
	before := game.units.world[player]

	// Tree cell: the order is rejected and must not disturb the current order.
	testing.expect(t, !game_issue_move(game, Grid_Pos{8, 20}))
	testing.expect_value(t, game.commands.rejected, u32(1))
	sim_tick(game)
	after := game.units.world[player]
	testing.expect_value(t, after.x - before.x, unit_move_step(&game.units, player) * CELL_SIZE)
	testing.expect(t, game.units.patrol_active[player])
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
reordering_past_obstacles_never_jumps :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, ok := game_player_index(game)
	testing.expect(t, ok)

	testing.expect(t, game_issue_move(game, Grid_Pos{12, 22}))
	previous := game.units.world[player]
	max_step := Fp(0)
	reorders := 0
	destinations := [3]Grid_Pos{{16, 26}, {20, 22}, {24, 26}}
	for _ in 0..<400 {
		if reorders < len(destinations) && unit_between_cells(&game.units, player) {
			testing.expect(t, game_issue_move(game, destinations[reorders]))
			reorders += 1
		}
		sim_tick(game)
		current := game.units.world[player]
		step := abs(current.x - previous.x) + abs(current.y - previous.y)
		max_step = max(max_step, step)
		previous = current
		testing.expect_value(t, validate_game(game), Validation_Error.None)
	}
	testing.expect_value(t, reorders, 3)
	// A diagonal tick moves at most one step on each axis.
	testing.expect(t, max_step <= unit_move_step(&game.units, player) * CELL_SIZE * 2)
}

@(test)
attack_order_keeps_move_interpolation :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, ok := game_player_index(game)
	testing.expect(t, ok)
	enemy, spawned := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{8, 25})
	testing.expect(t, spawned)

	testing.expect(t, game_issue_move(game, Grid_Pos{12, 25}))
	sim_run(game, 6)
	before := game.units.world[player]

	testing.expect(t, game_issue_attack(game, enemy))
	sim_tick(game)
	after := game.units.world[player]
	testing.expect_value(t, after.x - before.x, unit_move_step(&game.units, player) * CELL_SIZE)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
attack_move_engages_enemy_and_resumes_to_destination :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_idx, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_idx)
	eh, spawned := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{9, 27})
	testing.expect(t, spawned)
	if ei, ok := unit_index(&game.units, eh); ok {
		game.units.hp[ei] = 30
	}

	dest := Grid_Pos{18, 25}
	testing.expect(t, game_issue_attack_move(game, dest))
	sim_run(game, 500)

	testing.expect_value(t, unit_team_count(&game.units, .Enemy), 0)
	player, ok := game_player_index(game)
	testing.expect(t, ok)
	testing.expect_value(t, game.units.position[player], dest)
	testing.expect_value(t, game.units.state[player], Unit_State.Idle)
	testing.expect(t, !game.units.attack_move_active[player])
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
patrol_to_engages_enemy_and_resumes_loop :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_idx, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_idx)
	eh, spawned := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{7, 27})
	testing.expect(t, spawned)
	if ei, ok := unit_index(&game.units, eh); ok {
		game.units.hp[ei] = 30
	}

	dest := Grid_Pos{12, 25}
	testing.expect(t, game_issue_patrol_to(game, dest))
	seen_b := false
	seen_back_a := false
	player, _ := game_player_index(game)
	for _ in 0..<600 {
		sim_tick(game)
		if cells_equal(game.units.position[player], dest) {
			seen_b = true
		}
		if seen_b && cells_equal(game.units.position[player], START_POS) {
			seen_back_a = true
		}
		testing.expect_value(t, validate_game(game), Validation_Error.None)
	}
	testing.expect_value(t, unit_team_count(&game.units, .Enemy), 0)
	testing.expect(t, seen_b, "patrol never reached B")
	testing.expect(t, seen_back_a, "patrol never looped back to A")
	testing.expect(t, game.units.patrol_active[player])
	testing.expect_value(t, game.units.state[player], Unit_State.Patrol)
}

@(test)
campaign_spawns_hero_liiroy_and_luk_soldier :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, ok_p := game_player_index(game)
	enemy, ok_e := game_enemy_index(game)
	testing.expect(t, ok_p && ok_e)
	testing.expect_value(t, game.units.kind[player], Unit_Kind.Hero)
	testing.expect_value(t, game.units.hp[player], u16(HERO_MAX_HP))
	testing.expect_value(t, unit_attack_damage(&game.units, player), u16(HERO_ATTACK_DAMAGE))
	testing.expect_value(t, unit_kind_name(game.units.kind[player]), "Liiroy, the Bold")
	testing.expect_value(t, game.units.kind[enemy], Unit_Kind.Melee)
	testing.expect_value(t, game.units.hp[enemy], u16(MAX_HP))
	testing.expect_value(t, unit_kind_name(game.units.kind[enemy]), "Luk Soldier")
}

@(test)
discovered_enemy_waits_before_aggro_and_announces :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy_idx, _ := game_enemy_index(game)
	unit_destroy(&game.units, enemy_idx)
	eh, spawned := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{7, 25})
	testing.expect(t, spawned)
	ei, _ := unit_index(&game.units, eh)

	sim_tick(game)
	testing.expect(t, game.discovery_announced)
	testing.expect(t, game.units.discovered[ei])
	testing.expect_value(t, game.units.aggro_timer[ei], u16(ENEMY_AGGRO_DELAY_TICKS))
	testing.expect_value(t, game.units.attack_target[ei], INVALID_HANDLE)

	// Enemy waits during the grace period and only aggros after delay expires.
	sim_run(game, ENEMY_AGGRO_DELAY_TICKS - 1)
	testing.expect_value(t, game.units.attack_target[ei], INVALID_HANDLE)
	sim_run(game, 2)
	testing.expect(t, handle_is_valid(game.units.attack_target[ei]))
	testing.expect(t, game.aggro_triggered_tick > 0)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}
