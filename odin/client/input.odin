// Mouse, keyboard and camera input for the native client.
package main

import rl "vendor:raylib"
import g "../game"

handle_input :: proc() {
	if handle_help_input() {
		return
	}
	if app.mode == .Model_Picker {
		handle_picker_input()
		return
	}
	if app.mode == .Model_Editor {
		handle_editor_input()
		return
	}
	mouse := input_mouse_pos()

	if input_left_pressed() {
		handle_left_press(mouse)
	}
	if input_left_released() {
		handle_left_release(mouse)
	}
	if input_middle_pressed() && !app.menu_open {
		handle_middle_press(mouse)
	}
	if rl.IsMouseButtonPressed(.RIGHT) && !app.menu_open {
		handle_right_click(mouse)
	}
	if app.minimap_dragging {
		if !app.menu_open && input_left_down() {
			handle_minimap_click(mouse)
		} else {
			app.minimap_dragging = false
		}
	}
	handle_keyboard()
}

handle_keyboard :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {
		if app.command_mode != .None {
			app.command_mode = .None
			app.dragging = false
		} else {
			app.menu_open = !app.menu_open
			app.dragging = false
			app.minimap_dragging = false
			end_camera_grip()
		}
	}
	if app.menu_open {
		return
	}
	if rl.IsKeyPressed(.F) {
		app.camera_follow = !app.camera_follow
		app.camera_vel = {}
	}
	if rl.IsKeyPressed(.M) {
		app.command_mode = .Move
		app.dragging = false
	}
	if rl.IsKeyPressed(.A) {
		app.command_mode = .Attack
		app.dragging = false
	}
	if rl.IsKeyPressed(.P) {
		app.command_mode = .Patrol
		app.dragging = false
	}
	if rl.IsKeyPressed(.S) {
		_ = g.game_issue_stop(&app.game)
		app.command_mode = .None
		app.dragging = false
	}
}

update_cursor :: proc() {
	if app.help_open || app.mode == .Model_Picker {
		if !app.cursor_initialized || app.last_cursor != .DEFAULT {
			rl.SetMouseCursor(.DEFAULT)
			app.last_cursor = .DEFAULT
			app.cursor_initialized = true
		}
		return
	}
	if app.mode == .Model_Editor {
		editor_update_cursor()
		return
	}
	next := rl.MouseCursor.DEFAULT
	if app.menu_open {
		next = .DEFAULT
	} else if app.grip_active {
		next = .RESIZE_ALL
	} else if app.command_mode != .None {
		next = .CROSSHAIR
	} else {
		next = edge_cursor(app.edge_dir)
	}
	if !app.cursor_initialized || next != app.last_cursor {
		rl.SetMouseCursor(next)
		app.last_cursor = next
		app.cursor_initialized = true
	}
}

@(private)
edge_cursor :: proc(dir: rl.Vector2) -> rl.MouseCursor {
	if dir.x == 0 && dir.y == 0 {
		return .DEFAULT
	}
	if dir.x != 0 && dir.y == 0 {
		return .RESIZE_EW
	}
	if dir.x == 0 && dir.y != 0 {
		return .RESIZE_NS
	}
	if (dir.x < 0 && dir.y > 0) || (dir.x > 0 && dir.y < 0) {
		return .RESIZE_NWSE
	}
	return .RESIZE_NESW
}

handle_left_press :: proc(mouse: rl.Vector2) {
	if app.menu_open {
		return
	}
	if rl.CheckCollisionPointRec(mouse, app.minimap_rect) {
		handle_minimap_click(mouse)
		return
	}
	if ui_pointer_captured() {
		return
	}

	switch app.command_mode {
	case .Move:
		issue_move_at(mouse)
		app.command_mode = .None
	case .Attack:
		issue_attack_or_move_at(mouse)
		app.command_mode = .None
	case .Patrol:
		issue_patrol_at(mouse)
		app.command_mode = .None
	case .None:
		if input_space_down() {
			start_camera_grip(mouse, true)
			return
		}
		app.dragging = true
		app.drag_start = mouse
	}
}

@(private)
handle_middle_press :: proc(mouse: rl.Vector2) {
	if rl.CheckCollisionPointRec(mouse, app.minimap_rect) || ui_pointer_captured() {
		return
	}
	app.dragging = false
	start_camera_grip(mouse, false)
}

@(private)
click_world_point :: proc(mouse: rl.Vector2, cell: g.Grid_Pos) -> rl.Vector3 {
	if p, ok := screen_to_world_ground(mouse); ok {
		return p
	}
	return cell_center(cell)
}

@(private)
issue_attack_or_move_at :: proc(mouse: rl.Vector2) {
	if index, ok := unit_at_screen(mouse, .Enemy); ok && g.enemy_is_visible(&app.game, index) {
		handle := g.unit_handle(&app.game.units, index)
		if g.game_issue_attack(&app.game, handle) {
			spawn_target_fx(handle, unit_ground(index))
		}
		return
	}
	cell := screen_to_grid(mouse)
	if g.game_issue_attack_move(&app.game, cell) {
		spawn_ground_fx(.Attack, click_world_point(mouse, cell))
	}
}

@(private)
issue_patrol_at :: proc(mouse: rl.Vector2) {
	cell := screen_to_grid(mouse)
	if g.game_issue_patrol_to(&app.game, cell) {
		spawn_ground_fx(.Patrol, click_world_point(mouse, cell))
	}
}

handle_left_release :: proc(mouse: rl.Vector2) {
	app.minimap_dragging = false
	if app.grip_active && app.grip_via_space {
		end_camera_grip()
	}
	if !app.dragging {
		return
	}
	app.dragging = false
	if app.menu_open {
		return
	}
	delta := rl.Vector2{mouse.x - app.drag_start.x, mouse.y - app.drag_start.y}
	if rl.Vector2Length(delta) >= 5 {
		select_box(app.drag_start, mouse)
	} else {
		select_click(mouse)
	}
}

handle_right_click :: proc(mouse: rl.Vector2) {
	if rl.CheckCollisionPointRec(mouse, app.minimap_rect) || ui_pointer_captured() {
		return
	}
	app.command_mode = .None
	if index, ok := unit_at_screen(mouse, .Enemy); ok {
		if g.enemy_is_visible(&app.game, index) {
			handle := g.unit_handle(&app.game.units, index)
			if g.game_issue_attack(&app.game, handle) {
				spawn_target_fx(handle, unit_ground(index))
			}
			return
		}
	}
	issue_move_at(mouse)
}

issue_move_at :: proc(mouse: rl.Vector2) {
	cell := screen_to_grid(mouse)
	if g.game_issue_move(&app.game, cell) {
		spawn_ground_fx(.Move, click_world_point(mouse, cell))
	}
}

select_click :: proc(mouse: rl.Vector2) {
	additive := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if index, ok := unit_at_screen(mouse, .Player); ok {
		if additive {
			g.unit_select(&app.game.units, index, true)
		} else {
			g.unit_select_only(&app.game.units, index)
		}
	} else if !additive {
		g.unit_clear_selection(&app.game.units)
	}
}

unit_at_screen :: proc(mouse: rl.Vector2, team: g.Team) -> (index: int, ok: bool) {
	best := f32(26)
	for i in 0..<g.MAX_UNITS {
		units := &app.game.units
		if !units.alive[i] || units.team[i] != team {
			continue
		}
		point := rl.GetWorldToScreen(unit_ground(i) + rl.Vector3{0, 1.0, 0}, app.camera)
		distance := rl.Vector2Distance(point, mouse)
		if distance < best {
			best = distance
			index = i
			ok = true
		}
	}
	return
}

select_box :: proc(start, finish: rl.Vector2) {
	min_x := min(start.x, finish.x)
	max_x := max(start.x, finish.x)
	min_y := min(start.y, finish.y)
	max_y := max(start.y, finish.y)
	additive := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if !additive {
		g.unit_clear_selection(&app.game.units)
	}
	for i in 0..<g.MAX_UNITS {
		units := &app.game.units
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		point := rl.GetWorldToScreen(unit_ground(i) + rl.Vector3{0, 0.9, 0}, app.camera)
		if point.x >= min_x && point.x <= max_x && point.y >= min_y && point.y <= max_y {
			g.unit_select(units, i, true)
		}
	}
}

handle_minimap_click :: proc(mouse: rl.Vector2) {
	rect := app.minimap_rect
	u := clamp((mouse.x - rect.x) / rect.width, 0, 0.999)
	v := clamp((mouse.y - rect.y) / rect.height, 0, 0.999)
	cell := g.Grid_Pos{x = i32(u * f32(g.GRID_W)), y = i32((1 - v) * f32(g.GRID_H))}
	app.camera_target = clamp_camera_target(cell_center(cell))
	app.camera_follow = false
	app.camera_vel = {}
	app.minimap_dragging = true
	apply_camera()
}

retry_level :: proc() {
	g.game_reset(&app.game)
	reset_warrior_visuals()
	app.accumulator = 0
	app.menu_open = false
	app.command_mode = .None
	app.dragging = false
	reset_camera()
}
