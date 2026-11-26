#+build !js
package game

import "core:testing"

@(test)
hero_has_buffed_armor_speed_and_stats :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)

	player, ok_p := game_player_index(game)
	enemy, ok_e := game_enemy_index(game)
	testing.expect(t, ok_p && ok_e)

	testing.expect_value(t, game.units.hp_max[player], u16(HERO_MAX_HP))
	testing.expect_value(t, unit_attack_damage(&game.units, player), u16(HERO_ATTACK_DAMAGE))
	testing.expect_value(t, unit_attack_cooldown(&game.units, player), u16(HERO_ATTACK_COOLDOWN_TICKS))
	testing.expect_value(t, unit_armor(&game.units, player), u16(HERO_ARMOR))
	testing.expect_value(t, game.units.speed[player], fp_from_int(HERO_SPEED))

	testing.expect_value(t, game.units.hp_max[enemy], u16(MAX_HP))
	testing.expect_value(t, unit_attack_damage(&game.units, enemy), u16(ATTACK_DAMAGE))
	testing.expect_value(t, unit_armor(&game.units, enemy), u16(BASE_ARMOR))
	testing.expect_value(t, game.units.speed[enemy], fp_from_int(BASE_SPEED))
}

@(test)
hero_armor_reduces_damage_and_passive_regen_heals :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)

	destroy_all_team(game, .Enemy)
	player, _ := game_player_index(game)

	eh, spawned := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{3, 25})
	testing.expect(t, spawned)
	ei, _ := unit_index(&game.units, eh)
	game.units.discovered[ei] = true
	game.units.aggro_timer[ei] = 0
	game.units.attack_target[ei] = unit_handle(&game.units, player)

	// One enemy swing deals ATTACK_DAMAGE - HERO_ARMOR (15 - 5 = 10) instead of 15.
	sim_tick(game)
	expected_hit := u16(HERO_MAX_HP) - (u16(ATTACK_DAMAGE) - u16(HERO_ARMOR))
	testing.expect_value(t, game.units.hp[player], expected_hit)

	unit_destroy(&game.units, ei)
	sim_run(game, HERO_REGEN_INTERVAL_TICKS - 2)
	testing.expect_value(t, game.units.hp[player], expected_hit)
	sim_tick(game)
	testing.expect_value(t, game.units.hp[player], expected_hit + HERO_REGEN_AMOUNT)

	// Never exceeds hp_max.
	sim_run(game, HERO_REGEN_INTERVAL_TICKS * 20)
	testing.expect_value(t, game.units.hp[player], u16(HERO_MAX_HP))

	// Lethal hit still sets game_over instead of regenerating from 0.
	eh2, spawned2 := unit_spawn(&game.units, &game.grid, .Enemy, Grid_Pos{3, 25})
	testing.expect(t, spawned2)
	ei2, _ := unit_index(&game.units, eh2)
	game.units.discovered[ei2] = true
	game.units.aggro_timer[ei2] = 0
	game.units.attack_target[ei2] = unit_handle(&game.units, player)
	game.units.hp[player] = 5
	game.tick = HERO_REGEN_INTERVAL_TICKS - 1
	sim_tick(game)
	testing.expect(t, game.game_over)
	testing.expect_value(t, validate_game(game), Validation_Error.None)
}
