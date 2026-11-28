#+build !js
package game

import "core:testing"

@(test)
level_validate_passes :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	pf: Pathfinder
	pathfinder_reset(&pf)
	testing.expect_value(t, level_validate(&grid, &pf), Validation_Error.None)
}

@(test)
validator_catches_health_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	game.units.hp[index] = game.units.hp_max[index] + 1
	testing.expect_value(t, validate_game(game), Validation_Error.UnitHealthInvalid)
}

@(test)
validator_catches_bad_path :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	current, _ := cell_index(game.units.position[index])
	far, _ := cell_index(GOAL_POS)
	game.units.path_len[index] = 2
	game.units.path_index[index] = 0
	game.units.path[index][0] = u16(current)
	game.units.path[index][1] = u16(far)
	testing.expect_value(t, validate_game(game), Validation_Error.UnitPathNotAdjacent)
}

@(test)
validator_catches_blocked_path_cell :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	start, _ := cell_index(game.units.position[index])
	tree_index, _ := cell_index(Grid_Pos{14, 20})
	game.units.path_len[index] = 2
	game.units.path_index[index] = 0
	game.units.path[index][0] = u16(start)
	game.units.path[index][1] = u16(tree_index)
	testing.expect_value(t, validate_game(game), Validation_Error.UnitPathBlocked)
}

@(test)
validator_catches_fog_inconsistency :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	bit_grid_set(&game.fog.visible, 0)
	bit_grid_clear_cell(&game.fog.explored, 0)
	testing.expect_value(t, validate_game(game), Validation_Error.FogVisibleNotExplored)
}

@(test)
validator_catches_enemy_selection :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy, _ := game_enemy_index(game)
	game.units.selected[enemy] = true
	game.units.selected_count += 1
	testing.expect_value(t, validate_game(game), Validation_Error.SelectedNotPlayer)
}

@(test)
validator_catches_stale_attack_target :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, _ := game_player_index(game)
	game.units.attack_target[player] = Unit_Handle{index = 200, generation = 999}
	testing.expect_value(t, validate_game(game), Validation_Error.AttackTargetInvalid)
}

@(test)
validator_catches_bad_waypoint :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	game.waypoints.current = game.waypoints.count + 1
	testing.expect_value(t, validate_game(game), Validation_Error.WaypointCurrentInvalid)
}

@(test)
validator_catches_missing_player :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, _ := game_player_index(game)
	unit_destroy(&game.units, player)
	testing.expect_value(t, validate_game(game), Validation_Error.PlayerMissing)
}

@(test)
validator_catches_command_index_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	game.commands.head = MAX_COMMANDS + 4
	testing.expect_value(t, validate_game(game), Validation_Error.CommandIndicesInvalid)
}

@(test)
validator_catches_world_mismatch :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	game.units.world[index].x += fp_from_int(50)
	testing.expect_value(t, validate_game(game), Validation_Error.UnitWorldMismatch)
}

@(test)
validator_catches_path_start_mismatch :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	wrong, _ := cell_index(Grid_Pos{3, 25})
	game.units.path_len[index] = 1
	game.units.path_index[index] = 0
	game.units.path[index][0] = u16(wrong)
	testing.expect_value(t, validate_game(game), Validation_Error.UnitPathStartInvalid)
}

@(test)
validator_catches_attack_move_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	index, _ := game_player_index(game)
	game.units.attack_move_active[index] = true
	testing.expect_value(t, validate_game(game), Validation_Error.UnitAttackMoveInvalid)
}

@(test)
validator_catches_aggro_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy, _ := game_enemy_index(game)
	game.units.aggro_timer[enemy] = 10
	testing.expect_value(t, validate_game(game), Validation_Error.UnitAggroInvalid)
}

@(test)
validator_catches_group_mask_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	enemy, _ := game_enemy_index(game)
	game.units.group_mask[enemy] = 1
	testing.expect_value(t, validate_game(game), Validation_Error.UnitGroupMaskInvalid)
}

@(test)
validator_catches_order_queue_corruption :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	player, _ := game_player_index(game)
	game.units.order_count[player] = MAX_UNIT_ORDERS + 1
	testing.expect_value(t, validate_game(game), Validation_Error.UnitOrderQueueInvalid)
}
