// Mouse, keyboard and camera input for the native client.
package main

import rl "vendor:raylib"
import g "../game"

handle_input :: proc() {
	mouse := rl.GetMousePosition()

	if rl.IsMouseButtonPressed(.LEFT) {
		handle_left_press(mouse)
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		handle_left_release(mouse)
	}
	if rl.IsMouseButtonPressed(.RIGHT) && !app.menu_open {
		handle_right_click(mouse)
	}
	handle_keyboard()
	update_cursor()
}

handle_keyboard :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {
		app.menu_open = !app.menu_open
		app.command_mode = .None
		app.dragging = false
	}
	if rl.IsKeyPressed(.F) {
		app.camera_follow = !app.camera_follow
	}
}

update_cursor :: proc() {
	if app.menu_open {
		rl.SetMouseCursor(.DEFAULT)
	} else {
		switch app.command_mode {
		case .None:
			rl.SetMouseCursor(.DEFAULT)
		case .Move, .Patrol:
			rl.SetMouseCursor(.CROSSHAIR)
		}
	}
}

handle_left_press :: proc(mouse: rl.Vector2) {
	if app.menu_open {
		if rl.CheckCollisionPointRec(mouse, app.retry_button) {
			retry_level()
		} else if rl.CheckCollisionPointRec(mouse, app.resume_button) {
			app.menu_open = false
		}
		return
	}
	if rl.CheckCollisionPointRec(mouse, app.minimap_rect) {
		handle_minimap_click(mouse)
		return
	}
	if rl.CheckCollisionPointRec(mouse, app.move_button) {
		app.command_mode = .Move
		app.dragging = false
		return
	}
	if rl.CheckCollisionPointRec(mouse, app.patrol_button) {
		app.command_mode = .Patrol
		app.patrol_first = g.Grid_Pos{x = -1, y = -1}
		app.dragging = false
		return
	}
	if mouse.y >= f32(rl.GetScreenHeight()) - HUD_HEIGHT {
		return
	}

	switch app.command_mode {
	case .Move:
		issue_move(screen_to_grid(mouse))
		app.command_mode = .None
	case .Patrol:
		handle_patrol_click(screen_to_grid(mouse))
	case .None:
		app.dragging = true
		app.drag_start = mouse
	}
}

handle_patrol_click :: proc(cell: g.Grid_Pos) {
	if !g.grid_is_walkable(&app.game.grid, cell) {
		return
	}
	if !g.in_bounds(app.patrol_first) {
		app.patrol_first = cell
		return
	}
	if g.game_issue_patrol(&app.game, app.patrol_first, cell) {
		app.command_mode = .None
	}
}

handle_left_release :: proc(mouse: rl.Vector2) {
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
	if mouse.y >= f32(rl.GetScreenHeight()) - HUD_HEIGHT {
		return
	}
	if rl.CheckCollisionPointRec(mouse, app.minimap_rect) {
		return
	}
	app.command_mode = .None
	cell := screen_to_grid(mouse)
	if index, ok := g.unit_at(&app.game.units, cell, .Enemy); ok {
		if g.enemy_is_visible(&app.game, index) {
			handle := g.unit_handle(&app.game.units, index)
			_ = g.game_issue_attack(&app.game, handle)
			return
		}
	}
	issue_move(cell)
}

issue_move :: proc(cell: g.Grid_Pos) {
	_ = g.game_issue_move(&app.game, cell)
}

select_click :: proc(mouse: rl.Vector2) {
	cell := screen_to_grid(mouse)
	additive := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if index, ok := g.unit_at(&app.game.units, cell, .Player); ok {
		if additive {
			g.unit_select(&app.game.units, index, true)
		} else {
			g.unit_select_only(&app.game.units, index)
		}
	} else if !additive {
		g.unit_clear_selection(&app.game.units)
	}
}

select_box :: proc(start, finish: rl.Vector2) {
	a := rl.GetScreenToWorld2D(start, app.camera)
	b := rl.GetScreenToWorld2D(finish, app.camera)
	min_x := min(a.x, b.x)
	max_x := max(a.x, b.x)
	min_y := min(a.y, b.y)
	max_y := max(a.y, b.y)
	additive := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if !additive {
		g.unit_clear_selection(&app.game.units)
	}
	for i in 0..<g.MAX_UNITS {
		units := &app.game.units
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		x := g.fp_to_f32(units.world[i].x)
		y := g.fp_to_f32(units.world[i].y)
		if x >= min_x && x <= max_x && y >= min_y && y <= max_y {
			g.unit_select(units, i, true)
		}
	}
}

update_camera :: proc(dt: f64) {
	if app.menu_open {
		return
	}
	delta := f32(dt)
	speed := f32(400)
	move := rl.Vector2{0, 0}
	manual := false
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
		move.y += speed
		manual = true
	}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		move.y -= speed
		manual = true
	}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		move.x -= speed
		manual = true
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		move.x += speed
		manual = true
	}
	if move.x != 0 || move.y != 0 {
		app.camera_pos.x += move.x * delta
		app.camera_pos.y += move.y * delta
		app.camera_follow = false
	}
	if apply_edge_scroll(delta) {
		app.camera_follow = false
	}
	if app.camera_follow {
		follow_player(delta)
	}
	app.camera_pos = clamp_camera(app.camera_pos)
	app.camera.target = app.camera_pos
}

apply_edge_scroll :: proc(dt: f32) -> bool {
	if !rl.IsWindowFocused() || !rl.IsCursorOnScreen() {
		return false
	}
	mouse := rl.GetMousePosition()
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	if mouse.x <= 0 || mouse.x >= width || mouse.y <= 0 || mouse.y >= height {
		return false
	}
	ZONE :: f32(20)
	BASE :: f32(200)
	MAX :: f32(600)
	velocity := rl.Vector2{0, 0}
	if mouse.x < ZONE {
		velocity.x -= BASE + (MAX - BASE) * (1 - mouse.x / ZONE)
	} else if mouse.x > width - ZONE {
		velocity.x += BASE + (MAX - BASE) * (1 - (width - mouse.x) / ZONE)
	}
	if mouse.y < ZONE {
		velocity.y += BASE + (MAX - BASE) * (1 - mouse.y / ZONE)
	} else if mouse.y > height - ZONE {
		velocity.y -= BASE + (MAX - BASE) * (1 - (height - mouse.y) / ZONE)
	}
	app.camera_pos.x += velocity.x * dt
	app.camera_pos.y += velocity.y * dt
	return velocity.x != 0 || velocity.y != 0
}

follow_player :: proc(_: f32) {
	index, ok := g.game_player_index(&app.game)
	if !ok {
		return
	}
	world := app.game.units.world[index]
	app.camera_pos = rl.Vector2{g.fp_to_f32(world.x), g.fp_to_f32(world.y)}
}

handle_minimap_click :: proc(mouse: rl.Vector2) {
	rect := app.minimap_rect
	u := clamp((mouse.x - rect.x) / rect.width, 0, 0.999)
	v := clamp((mouse.y - rect.y) / rect.height, 0, 0.999)
	cell := g.Grid_Pos{x = i32(u * f32(g.GRID_W)), y = i32((1 - v) * f32(g.GRID_H))}
	world := g.grid_to_world(cell)
	app.camera_pos = clamp_camera(rl.Vector2{g.fp_to_f32(world.x), g.fp_to_f32(world.y)})
	app.camera.target = app.camera_pos
	app.camera_follow = false
}

retry_level :: proc() {
	g.game_reset(&app.game)
	app.accumulator = 0
	app.menu_open = false
	app.command_mode = .None
	app.dragging = false
	reset_camera()
}
