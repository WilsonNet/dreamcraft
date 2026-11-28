#+build !js
package game

import "base:runtime"
import "core:testing"

@(test)
rescue_allies_converts_squad_and_reveals_fog :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)

	testing.expect_value(t, unit_team_count(&game.units, .Player), 1)
	testing.expect_value(t, unit_team_count(&game.units, .Neutral), len(ALLY_RESCUE_SPAWNS))
	testing.expect_value(t, unit_team_count(&game.units, .Enemy), len(ENEMY_SQUAD_SPAWNS))

	// Move Liiroy to Waypoint 1 (20, 25) to rescue Squad 1 (3 Luk Soldiers).
	testing.expect(t, sim_move_player(game, Grid_Pos{20, 25}, 1000))
	testing.expect_value(t, game.rescued_count, u16(3))
	testing.expect_value(t, game.last_rescue_batch, u16(3))
	testing.expect(t, game.last_rescue_tick > 0)
	testing.expect_value(t, unit_team_count(&game.units, .Player), 4)
	testing.expect_value(t, unit_team_count(&game.units, .Neutral), 2)

	// Rescued soldiers also reveal fog around their cells.
	testing.expect(t, fog_is_visible(&game.fog, Grid_Pos{21, 25}))
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
group_move_spreads_formation_without_stacking :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	destroy_all_team(game, .Enemy)

	testing.expect(t, sim_move_player(game, Grid_Pos{20, 25}, 1000))
	testing.expect_value(t, unit_select_all_player(&game.units), 4)
	testing.expect(t, game_issue_move(game, Grid_Pos{28, 21}))
	sim_run(game, 500)

	positions: [4]Grid_Pos
	count := 0
	for i in 0..<MAX_UNITS {
		if game.units.alive[i] && game.units.team[i] == .Player {
			positions[count] = game.units.position[i]
			count += 1
			testing.expect_value(t, game.units.state[i], Unit_State.Idle)
		}
	}
	testing.expect_value(t, count, 4)
	for a in 0..<count {
		for b in (a + 1)..<count {
			testing.expect(t, !cells_equal(positions[a], positions[b]), "group units must occupy distinct cells")
		}
	}
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
group_combat_4v2_and_squad_aggro :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)

	// Rescue Squad 1 (3 soldiers -> 4 player units total).
	testing.expect(t, sim_move_player(game, Grid_Pos{20, 25}, 1000))
	testing.expect_value(t, unit_select_all_player(&game.units), 4)

	// Attack-move along the road through Enemy Group 1 (2 scouts in the northern glade) to (59, 24).
	testing.expect(t, game_issue_attack_move(game, Grid_Pos{59, 24}))
	sim_run(game, 2400)

	// Enemy Group 1 should be defeated (13 -> 11 enemies) while all 4 player units survive or fight.
	testing.expect_value(t, unit_team_count(&game.units, .Enemy), len(ENEMY_SQUAD_SPAWNS) - 2)
	testing.expect(t, unit_team_count(&game.units, .Player) >= 3)
	testing.expect(t, game.discovery_announced)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
control_groups_assign_add_steal_and_recall :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	testing.expect(t, sim_move_player(game, Grid_Pos{20, 25}, 1000))

	hero, _ := game_player_index(game)
	soldiers: [3]int
	sc := 0
	for i in 0..<MAX_UNITS {
		if game.units.alive[i] && game.units.team[i] == .Player && game.units.kind[i] == .Melee {
			soldiers[sc] = i
			sc += 1
		}
	}
	testing.expect_value(t, sc, 3)

	// Ctrl+1 binds hero to group 0.
	unit_select_only(&game.units, hero)
	testing.expect_value(t, group_apply(&game.units, 0, .Assign), 1)
	testing.expect_value(t, group_member_count(&game.units, 0), 1)

	// Shift+1 adds soldiers[0] to group 0.
	unit_select_only(&game.units, soldiers[0])
	testing.expect_value(t, group_apply(&game.units, 0, .Add), 2)

	// Alt+2 steals soldiers[0] into group 1 (removes it from group 0).
	testing.expect_value(t, group_apply(&game.units, 1, .Steal_Assign), 1)
	testing.expect_value(t, group_member_count(&game.units, 0), 1)
	testing.expect_value(t, group_member_count(&game.units, 1), 1)

	// Alt+Shift+2 steals soldiers[1] into group 1 while keeping soldiers[0].
	unit_select_only(&game.units, soldiers[1])
	testing.expect_value(t, group_apply(&game.units, 1, .Steal_Add), 2)
	testing.expect_value(t, group_member_count(&game.units, 1), 2)

	// Recall group 1 selects both soldiers.
	unit_clear_selection(&game.units)
	testing.expect_value(t, group_apply(&game.units, 1, .Recall), 2)
	testing.expect_value(t, game.units.selected_count, 2)

	// Destroying a group member clears its membership cleanly.
	unit_destroy(&game.units, soldiers[0])
	testing.expect_value(t, group_member_count(&game.units, 1), 1)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
shift_queued_orders_execute_in_sequence :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	destroy_all_team(game, .Enemy)

	player, _ := game_player_index(game)
	unit_select_only(&game.units, player)
	testing.expect(t, game_issue_move(game, Grid_Pos{6, 25}, false))
	testing.expect(t, game_issue_move(game, Grid_Pos{6, 28}, true))
	testing.expect(t, game_issue_attack_move(game, Grid_Pos{10, 28}, true))
	sim_tick(game)
	testing.expect_value(t, game.units.order_count[player], u8(2))

	sim_run(game, 500)
	testing.expect_value(t, game.units.position[player], Grid_Pos{10, 28})
	testing.expect_value(t, game.units.order_count[player], u8(0))
	testing.expect_value(t, game.units.state[player], Unit_State.Idle)

	// Unqueued move clears pending queued orders.
	testing.expect(t, game_issue_move(game, Grid_Pos{13, 28}, false))
	testing.expect(t, game_issue_move(game, Grid_Pos{15, 28}, true))
	sim_tick(game)
	testing.expect_value(t, game.units.order_count[player], u8(1))
	testing.expect(t, game_issue_move(game, Grid_Pos{8, 28}, false))
	sim_tick(game)
	testing.expect_value(t, game.units.order_count[player], u8(0))
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}

@(test)
multi_unit_simulation_zero_allocations :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)

	probe: Alloc_Probe
	old_context := context
	context.allocator = runtime.Allocator{procedure = probe_alloc, data = &probe}
	defer context = old_context

	game_init(game)
	_ = game_issue_move(game, Grid_Pos{20, 25}, false)
	_ = game_issue_attack_move(game, Grid_Pos{37, 25}, true)
	sim_run(game, 1000)
	_ = unit_select_all_player(&game.units)
	_ = group_apply(&game.units, 0, .Assign)
	_ = group_apply(&game.units, 0, .Recall)
	_ = game_issue_patrol_to(game, Grid_Pos{38, 25}, false)
	sim_run(game, 300)
	_ = game_hash(game)

	testing.expect_value(t, probe.calls, 0)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}
