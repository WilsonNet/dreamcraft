// Screen-space HUD, minimap panel, command buttons and pause menu.
package main

import rl "vendor:raylib"
import g "../game"

HUD_HEIGHT :: 170

draw_hud :: proc() {
	draw_bottom_bar()
	draw_status_panel()
	draw_minimap_panel()
	draw_command_buttons()
	draw_hint()
	draw_campaign_announcement()
}

draw_bottom_bar :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec(rl.Rectangle{0, height - HUD_HEIGHT, width, HUD_HEIGHT}, rl.Color{12, 18, 12, 238})
	rl.DrawLineV(rl.Vector2{0, height - HUD_HEIGHT}, rl.Vector2{width, height - HUD_HEIGHT}, rl.Color{60, 110, 60, 255})
}

draw_status_panel :: proc() {
	rl.DrawRectangleRec(rl.Rectangle{12, 12, 548, 116}, rl.Color{8, 14, 8, 210})
	rl.DrawRectangleLinesEx(rl.Rectangle{12, 12, 548, 116}, 1, rl.Color{60, 110, 60, 200})
	buffer: [256]u8
	draw_icon_centered(.Hero_Crest, 35, 31, 24)
	rl.DrawText("DREAMCRAFT RTS", 52, 22, 20, rl.Color{235, 215, 120, 255})
	draw_help_badge(help_badge_rect(), cstring("? F1"))
	rl.DrawText("Campaign: Tutorial 1 - Through the Woods", 24, 46, 14, rl.Color{180, 200, 180, 255})
	rl.DrawText("MMB/Space+Drag grip | Edge/WASD pan | F follow | M/A/P/S | F1 Help | Esc", 24, 66, 11, rl.Color{140, 170, 140, 255})

	if player_index, ok := g.game_player_index(&app.game); ok {
		pos := app.game.units.position[player_index]
		hp := app.game.units.hp[player_index]
		hp_max := app.game.units.hp_max[player_index]
		dmg := g.unit_attack_damage(&app.game.units, player_index)
		arm := g.unit_armor(&app.game.units, player_index)
		text := format_text(buffer[:], "Liiroy, the Bold (%d,%d) | HP %d/%d | ATK %d ARM %d | WP %d/%d", pos.x, pos.y, hp, hp_max, dmg, arm, app.game.waypoints.current, app.game.waypoints.count)
		rl.DrawText(text, 24, 88, 14, rl.Color{250, 226, 130, 255})
	} else {
		rl.DrawText("Liiroy, the Bold has fallen", 24, 88, 14, rl.Color{230, 80, 80, 255})
	}

	camera_mode := cstring("FOLLOW")
	if !app.camera_follow {
		camera_mode = cstring("FREE")
	}
	text := format_text(buffer[:], "FPS %d  |  Sel %d  |  Units %d  |  Fog %.1f%%  |  CAM %s", rl.GetFPS(), app.game.units.selected_count, app.game.units.alive_count, g.fog_coverage_percent(&app.game.fog), camera_mode)
	rl.DrawText(text, 24, 108, 12, rl.Color{150, 180, 150, 255})
}

draw_hint :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	if app.command_mode != .None {
		mode_text := cstring("MOVE: Left-click destination (Esc/Right-click cancel)")
		mode_col := rl.Color{120, 235, 140, 255}
		if app.command_mode == .Attack {
			mode_text = cstring("ATTACK-MOVE: Left-click target or terrain (Esc/Right-click cancel)")
			mode_col = rl.Color{255, 115, 95, 255}
		} else if app.command_mode == .Patrol {
			mode_text = cstring("PATROL: Left-click patrol point (Esc/Right-click cancel)")
			mode_col = rl.Color{105, 225, 255, 255}
		}
		mw := rl.MeasureText(mode_text, 14)
		rl.DrawText(mode_text, i32(width * 0.5) - mw / 2, i32(height - 96), 14, mode_col)
	}
	text := cstring("Bottom center reserved for control groups")
	text_width := rl.MeasureText(text, 13)
	rl.DrawText(text, i32(width * 0.5) - text_width / 2, i32(height - 32), 13, rl.Color{110, 140, 110, 255})
	if app.game.game_over {
		over := cstring("GAME OVER")
		over_width := rl.MeasureText(over, 28)
		rl.DrawText(over, i32(width * 0.5) - over_width / 2, 40, 28, rl.Color{230, 70, 70, 255})
	} else if app.game.level_complete {
		complete := cstring("LEVEL COMPLETE")
		complete_width := rl.MeasureText(complete, 28)
		rl.DrawText(complete, i32(width * 0.5) - complete_width / 2, 40, 28, rl.Color{255, 225, 80, 255})
	}
}

draw_command_buttons :: proc() {
	draw_button(app.move_button, cstring("[M] Move"), app.command_mode == .Move, .Cmd_Move)
	draw_button(app.attack_button, cstring("[A] Attack"), app.command_mode == .Attack, .Cmd_Attack)
	draw_button(app.patrol_button, cstring("[P] Patrol"), app.command_mode == .Patrol, .Cmd_Patrol)
	draw_button(app.stop_button, cstring("[S] Stop"), false, .Cmd_Stop)
}

draw_button :: proc(rect: rl.Rectangle, label: cstring, active: bool, icon := Icon_Id.None) {
	mouse := rl.GetMousePosition()
	hover := rl.CheckCollisionPointRec(mouse, rect)
	color := rl.Color{35, 55, 35, 240}
	if hover {
		color = rl.Color{55, 85, 55, 250}
	}
	if active {
		color = rl.Color{120, 95, 25, 250}
	}
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{120, 160, 120, 255})
	width := rl.MeasureText(label, 14)
	if icon != .None {
		draw_icon_centered(icon, rect.x + 16, rect.y + rect.height * 0.5, 18)
		rl.DrawText(label, i32(rect.x + 29), i32(rect.y + 9), 14, rl.WHITE)
		return
	}
	rl.DrawText(label, i32(rect.x + rect.width * 0.5) - width / 2, i32(rect.y + 9), 14, rl.WHITE)
}

draw_selection_box :: proc() {
	if !app.dragging {
		return
	}
	mouse := rl.GetMousePosition()
	rect := rl.Rectangle{
		x = min(app.drag_start.x, mouse.x),
		y = min(app.drag_start.y, mouse.y),
		width = abs(mouse.x - app.drag_start.x),
		height = abs(mouse.y - app.drag_start.y),
	}
	rl.DrawRectangleRec(rect, rl.Color{120, 200, 120, 35})
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{140, 230, 140, 220})
}

draw_pause_menu :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec(rl.Rectangle{0, 0, width, height}, rl.Color{0, 0, 0, 165})
	panel := rl.Rectangle{width * 0.5 - 220, height * 0.5 - 150, 440, 300}
	rl.DrawRectangleRec(panel, rl.Color{15, 24, 15, 245})
	rl.DrawRectangleLinesEx(panel, 2, rl.Color{90, 150, 90, 255})
	title := cstring("PAUSED")
	title_width := rl.MeasureText(title, 30)
	rl.DrawText(title, i32(width * 0.5) - title_width / 2, i32(panel.y + 24), 30, rl.Color{235, 215, 120, 255})
	subtitle := cstring("Choose an action or resume battle")
	subtitle_width := rl.MeasureText(subtitle, 14)
	rl.DrawText(subtitle, i32(width * 0.5) - subtitle_width / 2, i32(panel.y + 64), 14, rl.Color{160, 185, 160, 255})
	draw_menu_button(app.resume_button, cstring("Resume"), .Game)
	draw_menu_button(app.editor_button, cstring("Model Editor"), .Models)
	draw_menu_button(app.retry_button, cstring("Retry Level"), .Reset)
	hint := cstring("Press F1 for context shortcuts")
	hw := rl.MeasureText(hint, 12)
	rl.DrawText(hint, i32(width * 0.5) - hw / 2 - 20, i32(panel.y + 270), 12, rl.Color{150, 180, 150, 255})
	draw_help_badge(help_badge_rect(), cstring("? F1"))
}

@(private)
draw_help_badge :: proc(rect: rl.Rectangle, label: cstring) {
	hover := rl.CheckCollisionPointRec(input_mouse_pos(), rect)
	bg := app.help_open ? rl.Color{136, 102, 28, 255} : (hover ? rl.Color{55, 85, 55, 255} : rl.Color{28, 44, 30, 240})
	rl.DrawRectangleRec(rect, bg)
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{130, 180, 130, 255})
	tw := rl.MeasureText(label, 12)
	rl.DrawText(label, i32(rect.x + rect.width * 0.5) - tw / 2, i32(rect.y + (rect.height - 12) * 0.5), 12, rl.Color{240, 212, 118, 255})
}

draw_menu_button :: proc(rect: rl.Rectangle, label: cstring, icon := Icon_Id.None) {
	mouse := rl.GetMousePosition()
	color := rl.Color{40, 65, 40, 255}
	if rl.CheckCollisionPointRec(mouse, rect) {
		color = rl.Color{70, 105, 70, 255}
	}
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{130, 180, 130, 255})
	width := rl.MeasureText(label, 15)
	if icon != .None {
		draw_icon_centered(icon, rect.x + rect.width * 0.5 - f32(width) * 0.5 - 14, rect.y + rect.height * 0.5, 18)
		rl.DrawText(label, i32(rect.x + rect.width * 0.5) - width / 2 + 10, i32(rect.y + 10), 15, rl.WHITE)
		return
	}
	rl.DrawText(label, i32(rect.x + rect.width * 0.5) - width / 2, i32(rect.y + 10), 15, rl.WHITE)
}
