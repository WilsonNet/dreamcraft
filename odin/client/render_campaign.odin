// Campaign hero health bar, nameplates, spotted countdown, and Quickshell alert banner.
package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import g "../game"
import ui "../ui"

campaign_cstr :: proc(buf: []u8, format: string, args: ..any) -> cstring {
	if len(buf) == 0 {
		return ""
	}
	text := fmt.bprintf(buf[:len(buf) - 1], format, ..args)
	buf[len(text)] = 0
	return cstring(&buf[0])
}

draw_centered_shadow_text :: proc(text: cstring, cx, y, size: i32, color: rl.Color) {
	m := ui.measure_ctx_text(&app.ui_ctx, text, .Medium, f32(size))
	x := f32(cx) - m[0] * 0.5
	ui.draw_text(&app.ui_ctx, text, {x + 1, f32(y + 1)}, .Medium, f32(size), rl.Color{6, 8, 8, 220})
	ui.draw_text(&app.ui_ctx, text, {x, f32(y)}, .Medium, f32(size), color)
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
	color := rl.Color{64, 165, 245, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 60, 60, 255}
	} else if percent <= 0.5 {
		color = rl.Color{235, 190, 50, 255}
	}
	bar := rl.Rectangle{position.x - 21, position.y - 26, 42, 7}
	ui.draw_raw_bar(&app.ui_ctx.renderer, bar, percent, color, ui.COL_BORDER_GOLD)
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
		draw_centered_shadow_text(tag, cx, base_y - 22, 12, rl.Color{255, 196, 64, 255})
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

compose_campaign_banner :: proc(ctx: ^ui.Context, w: f32) {
	if app.menu_open || app.game.game_over || app.game.level_complete {
		return
	}
	aggro_ticks, grace_active, charge_active := active_campaign_alert()
	if !grace_active && !charge_active {
		return
	}
	bw := min(w - 40, f32(580))
	border := grace_active ? ui.COL_BORDER_GOLD : ui.COL_BORDER_DANGER
	bm := ui.m_blocks(ui.m_pad_xy(ui.m_gap(ui.m_surface(ui.m_w(ui.m_at(ui.mod(), (w - bw) * 0.5, 142), bw), ui.style_modal(ui.RAD_LG, border)), 6), 16, 12))
	bm.layer = 1
	ui.open_col(ctx, ui.id("campaign_banner"), bm)
	compose_campaign_header(ctx, grace_active, aggro_ticks)
	compose_campaign_body(ctx, grace_active, aggro_ticks)
	ui.close(ctx)
}

@(private)
compose_campaign_header :: proc(ctx: ^ui.Context, grace_active: bool, aggro_ticks: u16) {
	title: cstring = grace_active ? "HARK! AN ENEMY LUK SOLDIER SPOTTED!" : "TO ARMS! THE LUK SOLDIER CHARGES!"
	title_col := grace_active ? ui.COL_TEXT_GOLD : ui.COL_TEXT_DANGER
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 10))
	ui.icon(ctx, icon_texture(.Enemy_Alert), 22)
	ui.label(ctx, title, .Bold, 16, title_col)
	ui.spacer(ctx, 1)
	if grace_active {
		secs := f32(aggro_ticks) / f32(g.TICKS_PER_SECOND)
		ui.badge(ctx, ui.INVALID_ID, ui_cstr(fmt.tprintf("%.1fs", secs)), .Amber)
	}
	ui.close(ctx)
}

@(private)
compose_campaign_body :: proc(ctx: ^ui.Context, grace_active: bool, aggro_ticks: u16) {
	if grace_active {
		ui.label(ctx, "Strike first while they hesitate - press [A] or right-click to attack!", .Body, 13, ui.COL_TEXT_PRIMARY)
		ratio := clamp(f32(aggro_ticks) / f32(g.ENEMY_AGGRO_DELAY_TICKS), 0, 1)
		ui.progress_bar(ctx, ui.id("campaign_timer"), ratio, rl.Color{245, 185, 65, 255}, ui.m_h(ui.m_fill(ui.mod(), true, false), 6))
		return
	}
	ui.label(ctx, "Stand fast - Liiroy, the Bold meets the foe in battle!", .Body, 13, ui.COL_TEXT_PRIMARY)
}
