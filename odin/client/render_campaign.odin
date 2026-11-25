// Campaign hero health bar, nameplates, spotted countdown, and Quickshell alert banner.
package main

import "core:fmt"
import "core:math"
import rl "../gfx"
import g "../game"

campaign_cstr :: proc(buf: []u8, format: string, args: ..any) -> cstring {
	if len(buf) == 0 {
		return ""
	}
	text := fmt.bprintf(buf[:len(buf) - 1], format, ..args)
	buf[len(text)] = 0
	return cstring(&buf[0])
}

draw_unit_campaign_rings :: proc(index: int, ground: rl.Vector3) {
	units := &app.game.units
	if units.kind[index] == .Hero {
		rl.DrawCircle3D(ground + rl.Vector3{0, 0.03, 0}, 0.56, rl.Vector3{1, 0, 0}, 90, rl.Color{245, 202, 74, 185})
		rl.DrawCircle3D(ground + rl.Vector3{0, 0.03, 0}, 0.63, rl.Vector3{1, 0, 0}, 90, rl.Color{245, 202, 74, 95})
		return
	}
	if units.team[index] == .Enemy && units.discovered[index] && units.aggro_timer[index] > 0 {
		pulse := 0.5 + 0.5 * math.sin(f32(app.game.tick) * 0.25)
		alpha := u8(140 + 95 * pulse)
		rl.DrawCircle3D(ground + rl.Vector3{0, 0.035, 0}, 0.50 + 0.08 * pulse, rl.Vector3{1, 0, 0}, 90, rl.Color{255, 176, 48, alpha})
	}
}

active_campaign_alert :: proc() -> (aggro_ticks: u16, grace_active: bool, charge_active: bool) {
	return active_campaign_alert_for(&app.game)
}

active_campaign_alert_for :: proc(game: ^g.Game) -> (aggro_ticks: u16, grace_active: bool, charge_active: bool) {
	if _, player_ok := g.game_player_index(game); !player_ok {
		return
	}
	units := &game.units
	for i in 0..<g.MAX_UNITS {
		if units.alive[i] && units.team[i] == .Enemy && units.discovered[i] && units.aggro_timer[i] > 0 {
			return units.aggro_timer[i], true, false
		}
	}
	if game.aggro_triggered_tick > 0 && game.tick >= game.aggro_triggered_tick {
		if game.tick - game.aggro_triggered_tick < 180 {
			if _, enemy_ok := g.game_enemy_index(game); enemy_ok {
				return 0, false, true
			}
		}
	}
	return
}
