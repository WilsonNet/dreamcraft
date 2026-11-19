package main

import "core:testing"
import g "../game"

@(test)
campaign_alert_transitions_from_grace_to_charge :: proc(t: ^testing.T) {
	game := new(g.Game)
	defer free(game)
	g.game_reset(game)

	_, grace, charge := active_campaign_alert_for(game)
	testing.expect(t, !grace)
	testing.expect(t, !charge)

	enemy, ok := g.game_enemy_index(game)
	testing.expect(t, ok)
	game.units.discovered[enemy] = true
	game.units.aggro_timer[enemy] = 90
	game.discovery_announced = true
	ticks, grace2, charge2 := active_campaign_alert_for(game)
	testing.expect_value(t, ticks, u16(90))
	testing.expect(t, grace2)
	testing.expect(t, !charge2)

	game.units.aggro_timer[enemy] = 0
	game.aggro_triggered_tick = 100
	game.tick = 150
	_, grace3, charge3 := active_campaign_alert_for(game)
	testing.expect(t, !grace3)
	testing.expect(t, charge3)

	game.tick = 300
	_, grace4, charge4 := active_campaign_alert_for(game)
	testing.expect(t, !grace4)
	testing.expect(t, !charge4)
}
