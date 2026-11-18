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
}

draw_bottom_bar :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec(rl.Rectangle{0, height - HUD_HEIGHT, width, HUD_HEIGHT}, rl.Color{12, 18, 12, 238})
	rl.DrawLineV(rl.Vector2{0, height - HUD_HEIGHT}, rl.Vector2{width, height - HUD_HEIGHT}, rl.Color{60, 110, 60, 255})
}

draw_status_panel :: proc() {
	rl.DrawRectangleRec(rl.Rectangle{12, 12, 468, 116}, rl.Color{8, 14, 8, 210})
	rl.DrawRectangleLinesEx(rl.Rectangle{12, 12, 468, 116}, 1, rl.Color{60, 110, 60, 200})
	buffer: [256]u8
	rl.DrawText("DREAMCRAFT RTS", 24, 22, 20, rl.Color{235, 215, 120, 255})
	rl.DrawText("Tutorial Level 1 - Through the Woods", 24, 46, 14, rl.Color{180, 200, 180, 255})
	rl.DrawText("WASD/Edge pan | F follow | M Move | A Attack | P Patrol | S Stop | Esc", 24, 66, 11, rl.Color{140, 170, 140, 255})

	position, ok := g.game_player_position(&app.game)
	if ok {
		text := format_text(buffer[:], "Player (%d, %d)  |  Waypoint %d/%d  |  Selected %d", position.x, position.y, app.game.waypoints.current, app.game.waypoints.count, app.game.units.selected_count)
		rl.DrawText(text, 24, 88, 14, rl.WHITE)
	} else {
		rl.DrawText("Player is dead", 24, 88, 14, rl.Color{230, 80, 80, 255})
	}

	camera_mode := cstring("FOLLOW")
	if !app.camera_follow {
		camera_mode = cstring("FREE")
	}
	text := format_text(buffer[:], "FPS %d  |  Units %d  |  Fog %.1f%%  |  Tick %d  |  CAM %s", rl.GetFPS(), app.game.units.alive_count, g.fog_coverage_percent(&app.game.fog), app.game.tick, camera_mode)
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
	draw_button(app.move_button, cstring("[M] Move"), app.command_mode == .Move)
	draw_button(app.attack_button, cstring("[A] Attack"), app.command_mode == .Attack)
	draw_button(app.patrol_button, cstring("[P] Patrol"), app.command_mode == .Patrol)
	draw_button(app.stop_button, cstring("[S] Stop"), false)
}

draw_button :: proc(rect: rl.Rectangle, label: cstring, active: bool) {
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
	panel := rl.Rectangle{width * 0.5 - 210, height * 0.5 - 130, 420, 260}
	rl.DrawRectangleRec(panel, rl.Color{15, 24, 15, 245})
	rl.DrawRectangleLinesEx(panel, 2, rl.Color{90, 150, 90, 255})
	title := cstring("PAUSED")
	title_width := rl.MeasureText(title, 30)
	rl.DrawText(title, i32(width * 0.5) - title_width / 2, i32(panel.y + 30), 30, rl.Color{235, 215, 120, 255})
	subtitle := cstring("Simulation keeps running")
	subtitle_width := rl.MeasureText(subtitle, 14)
	rl.DrawText(subtitle, i32(width * 0.5) - subtitle_width / 2, i32(panel.y + 74), 14, rl.Color{160, 185, 160, 255})
	draw_menu_button(app.retry_button, cstring("Retry Level"))
	draw_menu_button(app.resume_button, cstring("Resume"))
}

draw_menu_button :: proc(rect: rl.Rectangle, label: cstring) {
	mouse := rl.GetMousePosition()
	color := rl.Color{40, 65, 40, 255}
	if rl.CheckCollisionPointRec(mouse, rect) {
		color = rl.Color{70, 105, 70, 255}
	}
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{130, 180, 130, 255})
	width := rl.MeasureText(label, 15)
	rl.DrawText(label, i32(rect.x + rect.width * 0.5) - width / 2, i32(rect.y + 10), 15, rl.WHITE)
}
