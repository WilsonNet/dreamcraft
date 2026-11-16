// World rendering. All draws happen inside the 2D camera.
package main

import rl "vendor:raylib"
import g "../game"

draw_frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{5, 10, 5, 255})
	rl.BeginMode2D(app.camera)
	draw_ground()
	draw_goal_zone()
	draw_trees()
	draw_waypoints()
	draw_fog()
	draw_units()
	draw_selected_paths()
	rl.EndMode2D()
	draw_hud()
	draw_selection_box()
	if app.menu_open {
		draw_pause_menu()
	}
	rl.EndDrawing()
}

draw_ground :: proc() {
	rl.DrawRectangle(g.WORLD_MIN_X, g.WORLD_MIN_Y, g.WORLD_MAX_X - g.WORLD_MIN_X, g.WORLD_MAX_Y - g.WORLD_MIN_Y, rl.Color{30, 54, 30, 255})
	grid_color := rl.Color{42, 70, 42, 255}
	for gx in 0..=g.GRID_W {
		x := f32(g.WORLD_MIN_X + gx * g.CELL_SIZE)
		if gx % 4 == 0 {
			rl.DrawLineV(rl.Vector2{x, f32(g.WORLD_MIN_Y)}, rl.Vector2{x, f32(g.WORLD_MAX_Y)}, grid_color)
		}
	}
	for gy in 0..=g.GRID_H {
		y := f32(g.WORLD_MIN_Y + gy * g.CELL_SIZE)
		if gy % 4 == 0 {
			rl.DrawLineV(rl.Vector2{f32(g.WORLD_MIN_X), y}, rl.Vector2{f32(g.WORLD_MAX_X), y}, grid_color)
		}
	}
}

draw_goal_zone :: proc() {
	x := f32(g.WORLD_MIN_X + g.GOAL_X * g.CELL_SIZE)
	rect := rl.Rectangle{x = x, y = f32(g.WORLD_MIN_Y), width = f32(3 * g.CELL_SIZE), height = f32(g.WORLD_MAX_Y - g.WORLD_MIN_Y)}
	rl.DrawRectangleRec(rect, rl.Color{210, 180, 40, 44})
	rl.DrawRectangleLinesEx(rect, 2, rl.Color{230, 200, 60, 190})
}

draw_trees :: proc() {
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			center := world_vector(cell)
			rl.DrawRectangle(i32(center.x) - 6, i32(center.y) - 15, 12, 20, rl.Color{95, 60, 25, 255})
			rl.DrawCircleV(rl.Vector2{center.x, center.y + 10}, 18, rl.Color{20, 110, 45, 255})
			rl.DrawCircleV(rl.Vector2{center.x - 5, center.y + 6}, 8, rl.Color{30, 135, 55, 255})
		}
	}
}

draw_waypoints :: proc() {
	for i in 1..<app.game.waypoints.count {
		point := app.game.waypoints.points[i]
		if g.fog_state(&app.game.fog, point) == 0 {
			continue
		}
		center := world_vector(point)
		color := rl.Color{120, 100, 25, 120}
		if i < app.game.waypoints.current {
			color = rl.Color{70, 180, 70, 120}
		} else if i == app.game.waypoints.current {
			color = rl.Color{255, 220, 60, 230}
		}
		rl.DrawRing(center, 13, 18, 0, 360, 32, color)
	}
}

draw_fog :: proc() {
	camera := app.camera
	half_width := f32(rl.GetScreenWidth()) * 0.5
	half_height := f32(rl.GetScreenHeight()) * 0.5
	min_x := camera.target.x - half_width
	max_x := camera.target.x + half_width
	min_y := camera.target.y - half_height
	max_y := camera.target.y + half_height

	gx0 := max(0, i32((min_x - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE)) - 1)
	gx1 := min(g.GRID_W - 1, i32((max_x - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE)) + 1)
	gy0 := max(0, i32((min_y - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE)) - 1)
	gy1 := min(g.GRID_H - 1, i32((max_y - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE)) + 1)

	for gy := gy0; gy <= gy1; gy += 1 {
		for gx := gx0; gx <= gx1; gx += 1 {
			cell := g.Grid_Pos{x = gx, y = gy}
			state := g.fog_state(&app.game.fog, cell)
			if state == 2 {
				continue
			}
			color := rl.Color{2, 3, 2, 242}
			if state == 1 {
				color = rl.Color{2, 3, 2, 122}
			}
			rl.DrawRectangleRec(cell_rect(cell), color)
		}
	}
}

draw_units :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] {
			continue
		}
		if !g.enemy_is_visible(&app.game, i) {
			continue
		}
		position := rl.Vector2{g.fp_to_f32(units.world[i].x), g.fp_to_f32(units.world[i].y)}
		color := rl.Color{70, 120, 230, 255}
		if units.team[i] == .Enemy {
			color = rl.Color{225, 70, 70, 255}
		}
		rl.DrawCircleV(position, 13, color)
		rl.DrawCircleLinesV(position, 13, rl.Color{15, 20, 15, 230})
		if units.selected[i] {
			rl.DrawCircleLinesV(position, 18, rl.Color{255, 225, 80, 235})
		}
		draw_unit_label(position)
		draw_health_bar(position, units.hp[i], units.hp_max[i])
	}
}

draw_unit_label :: proc(position: rl.Vector2) {
	rl.DrawText("M", i32(position.x) - 5, i32(position.y) - 7, 16, rl.WHITE)
}

draw_health_bar :: proc(position: rl.Vector2, hp, max_hp: u16) {
	percent := f32(hp) / f32(max_hp)
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 27, 24, 4}, rl.Color{25, 25, 25, 220})
	color := rl.Color{50, 205, 50, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 50, 50, 255}
	} else if percent <= 0.5 {
		color = rl.Color{230, 180, 25, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 27, 24 * percent, 4}, color)
}

draw_selected_paths :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !units.selected[i] {
			continue
		}
		if !g.unit_has_path(units, i) {
			continue
		}
		previous := rl.Vector2{g.fp_to_f32(units.world[i].x), g.fp_to_f32(units.world[i].y)}
		drawn := 0
		for p := int(units.path_index[i]); p < int(units.path_len[i]) && drawn < 24; p += 1 {
			cell := g.cell_position(int(units.path[i][p]))
			point := world_vector(cell)
			rl.DrawLineV(previous, point, rl.Color{90, 200, 120, 120})
			rl.DrawCircleV(point, 3, rl.Color{120, 230, 140, 170})
			previous = point
			drawn += 1
		}
	}
}
