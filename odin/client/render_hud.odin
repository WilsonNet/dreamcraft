// Screen-space Quickshell floating HUD islands, command card, pause modal, and marquee box.
package main

import "core:fmt"
import rl "vendor:raylib"
import g "../game"
import ui "../ui"

HUD_HEIGHT :: 170

compose_battlefield_hud :: proc(ctx: ^ui.Context, w, h: f32) {
	compose_status_island(ctx)
	compose_minimap_island(ctx, h)
	compose_bottom_center_dock(ctx, w, h)
	compose_command_card(ctx, w, h)
	compose_campaign_banner(ctx, w)
	compose_outcome_banner(ctx, w)
}

@(private)
compose_status_island :: proc(ctx: ^ui.Context) {
	card_m := ui.m_blocks(ui.m_pad_xy(ui.m_gap(ui.m_surface(ui.m_at(ui.m_w(ui.mod(), 468), 14, 14), ui.style_island(ui.RAD_LG)), 7), 14, 11))
	ui.open_col(ctx, ui.id("status_island"), card_m)

	compose_status_header(ctx)
	compose_hero_stats_row(ctx)
	compose_status_telemetry(ctx)
	ui.close(ctx)
}

@(private)
compose_status_header :: proc(ctx: ^ui.Context) {
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 9))
	ui.icon(ctx, icon_texture(.Hero_Crest), 22)
	ui.open_col(ctx, ui.INVALID_ID, ui.m_gap(ui.mod(), 1))
	ui.label(ctx, "DREAMCRAFT RTS", .Heading, 16, ui.COL_TEXT_GOLD)
	ui.label(ctx, "Tutorial 1: Through the Woods", .Body, 12, ui.COL_TEXT_SECONDARY)
	ui.close(ctx)
	ui.spacer(ctx, 1)
	compose_help_badge_widget(ctx, 0)
	ui.close(ctx)
}

@(private)
compose_hero_stats_row :: proc(ctx: ^ui.Context) {
	if idx, ok := g.game_player_index(&app.game); ok {
		pos := app.game.units.position[idx]
		hp := app.game.units.hp[idx]
		hp_max := app.game.units.hp_max[idx]
		dmg := g.unit_attack_damage(&app.game.units, idx)
		arm := g.unit_armor(&app.game.units, idx)
		pct := f32(hp) / f32(max(hp_max, 1))
		bar_col := pct <= 0.25 ? ui.COL_TEXT_ATTACK : (pct <= 0.5 ? ui.COL_TEXT_GOLD : ui.COL_TEXT_MOVE)

		ui.open_col(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 4))
		ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 8))
		ui.label(ctx, ui_cstr(fmt.tprintf("Liiroy, the Bold  (%d,%d)", pos.x, pos.y)), .Medium, 13, ui.COL_TEXT_PRIMARY)
		ui.spacer(ctx, 1)
		ui.label(ctx, ui_cstr(fmt.tprintf("%d / %d HP", hp, hp_max)), .Mono_Bold, 11.5, bar_col)
		ui.close(ctx)
		ui.progress_bar(ctx, ui.id("hero_hud_hp"), pct, bar_col, ui.m_h(ui.m_fill(ui.mod(), true, false), 6))
		ui.label(ctx, ui_cstr(fmt.tprintf("ATK %d   ARM %d   Waypoint %d / %d", dmg, arm, app.game.waypoints.current, app.game.waypoints.count)), .Mono, 11, ui.COL_TEXT_SECONDARY)
		ui.close(ctx)
	} else {
		ui.badge(ctx, ui.INVALID_ID, "Liiroy, the Bold has fallen", .Crimson)
	}
}

@(private)
compose_status_telemetry :: proc(ctx: ^ui.Context) {
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 8))
	info := fmt.tprintf("FPS %d   Sel %d   Units %d   Fog %.1f%%", rl.GetFPS(), app.game.units.selected_count, app.game.units.alive_count, g.fog_coverage_percent(&app.game.fog))
	ui.label(ctx, ui_cstr(info), .Mono, 11, ui.COL_TEXT_MUTED)
	ui.spacer(ctx, 1)
	cam_label: cstring = app.camera_follow ? "CAM FOLLOW" : "CAM FREE"
	tone: ui.Badge_Tone = app.camera_follow ? .Emerald : .Amber
	ui.badge(ctx, ui.id("cam_follow_chip"), cam_label, tone, ui.m_pad_xy(ui.mod(), 8, 3), u32(UI_Msg.Hud_Toggle_Follow))
	ui.close(ctx)
}

@(private)
compose_bottom_center_dock :: proc(ctx: ^ui.Context, w, h: f32) {
	center_max := max(w - 492, 260)
	if app.command_mode != .None {
		msg, tone := command_prompt_data()
		pm := ui.m_blocks(ui.m_pad_xy(ui.m_surface(ui.mod(), ui.style_island(ui.RAD_LG)), 14, 7))
		pm.max_w = center_max
		dock_w := min(center_max, f32(len(msg)) * 6.9 + 52)
		ui.open_row(ctx, ui.id("cmd_prompt_pill"), ui.m_at(pm, (w - dock_w) * 0.5, h - 98))
		ui.badge(ctx, ui.INVALID_ID, tone == .Attack ? "ATK" : (tone == .Patrol ? "PTR" : "MOV"), ui_prompt_tone(tone))
		ui.gap_box(ctx, 8, 1)
		ui.label(ctx, msg, .Medium, 12.5, ui.COL_TEXT_PRIMARY)
		ui.close(ctx)
	}

	dock_m := ui.m_blocks(ui.m_pad_xy(ui.m_gap(ui.m_surface(ui.m_h(ui.mod(), 34), ui.style_island(ui.RAD_LG)), 6), 10, 5))
	dock_m.align = .Center
	dock_w := min(center_max, f32(276))
	dock_m.width = dock_w
	ui.open_row(ctx, ui.id("ctrl_dock"), ui.m_at(dock_m, (w - dock_w) * 0.5, h - 50))
	hero_sel := app.game.units.selected_count > 0
	ui.badge(ctx, ui.id("grp_1"), "1: Hero", hero_sel ? .Gold : .Neutral, ui.m_pad_xy(ui.mod(), 8, 3), u32(UI_Msg.Hud_Select_Hero))
	ui.spacer(ctx, 1)
	ui.label(ctx, "Esc Pause  |  MMB Grip", .Mono, 11.5, ui.COL_TEXT_MUTED)
	ui.close(ctx)
}

@(private)
command_prompt_data :: proc() -> (cstring, Command_Mode) {
	if app.command_mode == .Attack {
		return "Click enemy or ground (Esc/RMB cancel)", .Attack
	}
	if app.command_mode == .Patrol {
		return "Click patrol endpoint (Esc/RMB cancel)", .Patrol
	}
	return "Click destination (Esc/RMB cancel)", .Move
}

@(private)
ui_prompt_tone :: proc(m: Command_Mode) -> ui.Badge_Tone {
	if m == .Attack { return .Crimson }
	if m == .Patrol { return .Cyan }
	return .Emerald
}

@(private)
compose_command_card :: proc(ctx: ^ui.Context, w, h: f32) {
	card_w := f32(246)
	card_h := f32(104)
	cm := ui.m_blocks(ui.m_pad(ui.m_gap(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), w - card_w - 14, h - card_h - 14), card_w, card_h), ui.style_island(ui.RAD_LG)), 8), 10))
	ui.open_col(ctx, ui.id("cmd_card"), cm)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 8))
	ui.button(ctx, ui.id("cmd_move"), ui.Button_Opts{label = "Move", keycap = "M", icon_tex = icon_texture(.Cmd_Move), active = app.command_mode == .Move, msg_tag = u32(UI_Msg.Hud_Move)}, ui.m_h(ui.m_weight(ui.mod(), 1), 38))
	ui.button(ctx, ui.id("cmd_attack"), ui.Button_Opts{label = "Attack", keycap = "A", icon_tex = icon_texture(.Cmd_Attack), active = app.command_mode == .Attack, msg_tag = u32(UI_Msg.Hud_Attack)}, ui.m_h(ui.m_weight(ui.mod(), 1), 38))
	ui.close(ctx)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 8))
	ui.button(ctx, ui.id("cmd_patrol"), ui.Button_Opts{label = "Patrol", keycap = "P", icon_tex = icon_texture(.Cmd_Patrol), active = app.command_mode == .Patrol, msg_tag = u32(UI_Msg.Hud_Patrol)}, ui.m_h(ui.m_weight(ui.mod(), 1), 38))
	ui.button(ctx, ui.id("cmd_stop"), ui.Button_Opts{label = "Stop", keycap = "S", icon_tex = icon_texture(.Cmd_Stop), msg_tag = u32(UI_Msg.Hud_Stop)}, ui.m_h(ui.m_weight(ui.mod(), 1), 38))
	ui.close(ctx)

	ui.close(ctx)
}

@(private)
compose_outcome_banner :: proc(ctx: ^ui.Context, w: f32) {
	if !app.game.game_over && !app.game.level_complete {
		return
	}
	title: cstring = app.game.level_complete ? "LEVEL COMPLETE" : "GAME OVER"
	border := app.game.level_complete ? ui.COL_BORDER_GOLD : ui.COL_BORDER_DANGER
	fg := app.game.level_complete ? ui.COL_TEXT_GOLD : ui.COL_TEXT_DANGER
	bw := f32(290)
	by := w >= 1140 ? f32(18) : f32(138)
	bm := ui.m_blocks(ui.m_align(ui.m_justify(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), (w - bw) * 0.5, by), bw, 46), ui.style_modal(999, border)), .Center), .Center))
	ui.open_row(ctx, ui.id("outcome_banner"), bm)
	ui.label(ctx, title, .Heading, 20, fg)
	ui.close(ctx)
}

compose_pause_menu :: proc(ctx: ^ui.Context) {
	pm := ui.m_align(ui.m_gap(ui.m_pad(ui.m_w(ui.mod(), 380), 24), 10), .Center)
	ui.open_scrim_modal(ctx, ui.id("pause_modal"), 2, u32(UI_Msg.Pause_Resume), pm)
	ui.label(ctx, "PAUSED", .Heading, 24, ui.COL_TEXT_GOLD)
	ui.label(ctx, "Choose an action or resume battle", .Body, 13, ui.COL_TEXT_SECONDARY)
	ui.ornament_divider(ctx)

	ui.button(ctx, ui.id("pause_resume"), ui.Button_Opts{label = "Resume Battle", keycap = "Esc", icon_tex = icon_texture(.Game), variant = .Primary, msg_tag = u32(UI_Msg.Pause_Resume)}, ui.m_h(ui.m_fill(ui.mod(), true, false), 42))
	ui.button(ctx, ui.id("pause_editor"), ui.Button_Opts{label = "Model Editor", icon_tex = icon_texture(.Models), variant = .Tonal, msg_tag = u32(UI_Msg.Pause_Editor)}, ui.m_h(ui.m_fill(ui.mod(), true, false), 42))
	ui.button(ctx, ui.id("pause_retry"), ui.Button_Opts{label = "Retry Level", icon_tex = icon_texture(.Reset), variant = .Danger, msg_tag = u32(UI_Msg.Pause_Retry)}, ui.m_h(ui.m_fill(ui.mod(), true, false), 42))

	ui.gap_box(ctx, 1, 4)
	ui.open_row(ctx, ui.INVALID_ID, ui.m_align(ui.m_fill(ui.mod(), true, false), .Center))
	ui.label(ctx, "Press F1 for context shortcuts", .Body, 11.5, ui.COL_TEXT_MUTED)
	ui.spacer(ctx, 1)
	compose_help_badge_widget(ctx, 2)
	ui.close(ctx)
	ui.close_scrim_modal(ctx)
}

@(private)
compose_help_badge_widget :: proc(ctx: ^ui.Context, layer: u8) {
	ui.button(
		ctx,
		ui.id("help_badge"),
		ui.Button_Opts{label = "? F1", variant = .Compact, active = app.help_open, font_size = 11.5, msg_tag = u32(UI_Msg.Help_Toggle)},
		ui.m_h(ui.m_layer(ui.m_pad_xy(ui.mod(), 9, 4), layer), 24),
	)
}

draw_selection_box :: proc() {
	if !app.dragging {
		return
	}
	mouse := input_mouse_pos()
	rect := rl.Rectangle{
		x      = min(app.drag_start.x, mouse.x),
		y      = min(app.drag_start.y, mouse.y),
		width  = abs(mouse.x - app.drag_start.x),
		height = abs(mouse.y - app.drag_start.y),
	}
	ui.draw_raw_pill(&app.ui_ctx.renderer, rect, rl.Color{96, 198, 116, 36}, rl.Color{74, 168, 92, 24}, rl.Color{136, 232, 146, 230}, 5, 0.20)
}
