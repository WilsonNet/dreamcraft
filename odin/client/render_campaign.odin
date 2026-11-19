package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import g "../game"

campaign_cstr :: proc(buf: []u8, format: string, args: ..any) -> cstring {
	if len(buf) == 0 {
		return ""
	}
	text := fmt.bprintf(buf[:len(buf) - 1], format, ..args)
	buf[len(text)] = 0
	return cstring(&buf[0])
}

draw_centered_shadow_text :: proc(text: cstring, cx, y, size: i32, color: rl.Color) {
	width := rl.MeasureText(text, size)
	x := cx - width / 2
	rl.DrawText(text, x + 1, y + 1, size, rl.Color{8, 8, 10, 220})
	rl.DrawText(text, x, y, size, color)
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

draw_hero_health_bar :: proc(position: rl.Vector2, hp, max_hp: u16) {
	percent := clamp(f32(hp) / f32(max_hp), 0, 1)
	x := position.x - 18
	y := position.y - 26
	rl.DrawRectangleRec(rl.Rectangle{x - 1, y - 1, 38, 7}, rl.Color{242, 200, 84, 235})
	rl.DrawRectangleRec(rl.Rectangle{x, y, 36, 5}, rl.Color{22, 24, 30, 235})
	color := rl.Color{64, 165, 245, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 60, 60, 255}
	} else if percent <= 0.5 {
		color = rl.Color{235, 190, 50, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{x, y, 36 * percent, 5}, color)
}

draw_unit_campaign_label :: proc(index: int, screen: rl.Vector2) {
	units := &app.game.units
	cx := i32(screen.x)
	base_y := i32(screen.y) - 18
	if units.kind[index] == .Hero {
		draw_centered_shadow_text("Liiroy, the Bold", cx, base_y, 12, rl.Color{250, 224, 122, 255})
		return
	}
	draw_centered_shadow_text("Luk Soldier", cx, base_y, 11, rl.Color{225, 195, 185, 245})
	if units.team[index] == .Enemy && units.discovered[index] && units.aggro_timer[index] > 0 {
		buf: [48]u8
		secs := f32(units.aggro_timer[index]) / f32(g.TICKS_PER_SECOND)
		tag := campaign_cstr(buf[:], "! SPOTTED %.1fs", secs)
		draw_centered_shadow_text(tag, cx, base_y - 24, 12, rl.Color{255, 196, 64, 255})
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
	for i in 0 ..< g.MAX_UNITS {
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

draw_campaign_announcement :: proc() {
	if app.menu_open || app.game.game_over || app.game.level_complete {
		return
	}
	aggro_ticks, grace_active, charge_active := active_campaign_alert()
	if !grace_active && !charge_active {
		return
	}
	draw_announcement_banner(aggro_ticks, grace_active)
}

draw_announcement_banner :: proc(aggro_ticks: u16, grace_active: bool) {
	screen_w := i32(rl.GetScreenWidth())
	banner_w := i32(min(screen_w - 40, 680))
	banner_h := i32(82)
	bx := (screen_w - banner_w) / 2
	by := i32(138)
	border := rl.Color{235, 190, 75, 240}
	if !grace_active {
		border = rl.Color{225, 85, 70, 240}
	}
	rl.DrawRectangleRec(rl.Rectangle{f32(bx), f32(by), f32(banner_w), f32(banner_h)}, rl.Color{14, 14, 18, 224})
	rl.DrawRectangleLinesEx(rl.Rectangle{f32(bx), f32(by), f32(banner_w), f32(banner_h)}, 2, border)
	draw_icon_centered(.Enemy_Alert, f32(bx + 26), f32(by + 36), 24)
	draw_icon_centered(.Enemy_Alert, f32(bx + banner_w - 26), f32(by + 36), 24)
	draw_announcement_copy(bx + banner_w / 2, bx + 20, by, banner_w - 40, aggro_ticks, grace_active)
}

draw_announcement_copy :: proc(cx, bar_x, by, bar_w: i32, aggro_ticks: u16, grace_active: bool) {
	buf: [160]u8
	if grace_active {
		draw_centered_shadow_text("HARK! AN ENEMY LUK SOLDIER SPOTTED!", cx, by + 10, 18, rl.Color{250, 214, 96, 255})
		draw_centered_shadow_text("Strike first while they hesitate - press [A] or right-click them to attack!", cx, by + 34, 13, rl.Color{235, 230, 210, 255})
		secs := f32(aggro_ticks) / f32(g.TICKS_PER_SECOND)
		sub := campaign_cstr(buf[:], "Enemy charges in %.1fs", secs)
		draw_centered_shadow_text(sub, cx, by + 54, 12, rl.Color{255, 182, 72, 255})
		ratio := clamp(f32(aggro_ticks) / f32(g.ENEMY_AGGRO_DELAY_TICKS), 0, 1)
		rl.DrawRectangle(bar_x, by + 71, bar_w, 4, rl.Color{45, 36, 20, 220})
		rl.DrawRectangle(bar_x, by + 71, i32(f32(bar_w) * ratio), 4, rl.Color{245, 185, 65, 255})
		return
	}
	draw_centered_shadow_text("TO ARMS! THE LUK SOLDIER CHARGES!", cx, by + 14, 18, rl.Color{245, 110, 95, 255})
	draw_centered_shadow_text("Stand fast - Liiroy, the Bold meets the foe in battle!", cx, by + 42, 14, rl.Color{240, 232, 218, 255})
}
