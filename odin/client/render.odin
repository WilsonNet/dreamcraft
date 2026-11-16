// World rendering in 2:1 isometric projection. All draws happen inside the
// 2D camera; the simulation grid stays orthogonal.
package main

import rl "vendor:raylib"
import g "../game"

MAX_TREE_CELLS :: 30 * 6

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
	base := rl.Color{30, 54, 30, 255}
	p0 := iso_from_grid(0, 0)
	p1 := iso_from_grid(f32(g.GRID_W), 0)
	p2 := iso_from_grid(f32(g.GRID_W), f32(g.GRID_H))
	p3 := iso_from_grid(0, f32(g.GRID_H))
	rl.DrawTriangle(p0, p2, p1, base)
	rl.DrawTriangle(p0, p3, p2, base)

	grid_color := rl.Color{42, 70, 42, 255}
	for gx := 0; gx <= g.GRID_W; gx += 4 {
		rl.DrawLineV(
			iso_from_grid(f32(gx), 0),
			iso_from_grid(f32(gx), f32(g.GRID_H)),
			grid_color,
		)
	}
	for gy := 0; gy <= g.GRID_H; gy += 4 {
		rl.DrawLineV(
			iso_from_grid(0, f32(gy)),
			iso_from_grid(f32(g.GRID_W), f32(gy)),
			grid_color,
		)
	}
}

draw_goal_zone :: proc() {
	for gy in 0..<g.GRID_H {
		for gx in g.GOAL_X..<g.GRID_W {
			cell := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			state := g.fog_state(&app.game.fog, cell)
			if state == 0 {
				continue
			}
			color := rl.Color{210, 180, 40, 24}
			if state == 2 {
				color = rl.Color{230, 200, 70, 150}
			}
			draw_diamond(iso_cell_center(cell), color)
		}
	}
	rl.DrawLineV(
		iso_from_grid(f32(g.GOAL_X), 0),
		iso_from_grid(f32(g.GOAL_X), f32(g.GRID_H)),
		rl.Color{230, 200, 60, 210},
	)
}

draw_trees :: proc() {
	cells: [MAX_TREE_CELLS]g.Grid_Pos
	count := 0
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			cells[count] = cell
			count += 1
		}
	}
	for i in 1..<count {
		cell := cells[i]
		j := i - 1
		for j >= 0 && tree_depth_less(cell, cells[j]) {
			cells[j + 1] = cells[j]
			j -= 1
		}
		cells[j + 1] = cell
	}
	for i in 0..<count {
		draw_tree(cells[i])
	}
}

tree_depth_less :: proc(a, b: g.Grid_Pos) -> bool {
	da := a.x + a.y
	db := b.x + b.y
	if da != db {
		return da < db
	}
	return a.x < b.x
}

draw_tree :: proc(cell: g.Grid_Pos) {
	center := iso_cell_center(cell)
	rl.DrawEllipseV(rl.Vector2{center.x, center.y + 2}, 15, 6, rl.Color{10, 30, 12, 120})
	rl.DrawRectangle(i32(center.x) - 2, i32(center.y) - 14, 4, 16, rl.Color{95, 60, 25, 255})
	rl.DrawCircleV(rl.Vector2{center.x, center.y - 20}, 16, rl.Color{20, 110, 45, 255})
	rl.DrawCircleV(rl.Vector2{center.x - 5, center.y - 24}, 9, rl.Color{30, 135, 55, 255})
}

draw_waypoints :: proc() {
	for i in 1..<app.game.waypoints.count {
		point := app.game.waypoints.points[i]
		if g.fog_state(&app.game.fog, point) == 0 {
			continue
		}
		center := iso_cell_center(point)
		color := rl.Color{120, 100, 25, 120}
		if i < app.game.waypoints.current {
			color = rl.Color{70, 180, 70, 120}
		} else if i == app.game.waypoints.current {
			color = rl.Color{255, 220, 60, 230}
		}
		rl.DrawEllipseLinesV(center, 18, 9, color)
	}
}

draw_fog :: proc() {
	half_width := f32(rl.GetScreenWidth()) * 0.5
	half_height := f32(rl.GetScreenHeight()) * 0.5
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			cell := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			state := g.fog_state(&app.game.fog, cell)
			if state == 2 {
				continue
			}
			center := iso_cell_center(cell)
			if abs(center.x - app.camera.target.x) > half_width + f32(HALF_TILE_W) ||
			   abs(center.y - app.camera.target.y) > half_height + f32(HALF_TILE_H) {
				continue
			}
			color := rl.Color{2, 3, 2, 242}
			if state == 1 {
				color = rl.Color{2, 3, 2, 122}
			}
			draw_diamond(center, color)
		}
	}
}

draw_units :: proc() {
	order: [g.MAX_UNITS]int
	count := 0
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		order[count] = i
		count += 1
	}
	for i := 1; i < count; i += 1 {
		index := order[i]
		j := i - 1
		for j >= 0 && unit_depth_less(index, order[j]) {
			order[j + 1] = order[j]
			j -= 1
		}
		order[j + 1] = index
	}
	for i in 0..<count {
		draw_unit(order[i])
	}
}

unit_depth_less :: proc(a, b: int) -> bool {
	units := &app.game.units
	da := units.world[a].x + units.world[a].y
	db := units.world[b].x + units.world[b].y
	if da != db {
		return da < db
	}
	return a < b
}

draw_unit :: proc(index: int) {
	units := &app.game.units
	ground := iso_from_world(units.world[index])
	body := rl.Vector2{ground.x, ground.y - 9}
	color := rl.Color{70, 120, 230, 255}
	if units.team[index] == .Enemy {
		color = rl.Color{225, 70, 70, 255}
	}
	rl.DrawEllipseV(rl.Vector2{ground.x, ground.y + 2}, 12, 5, rl.Color{8, 20, 8, 130})
	if units.selected[index] {
		rl.DrawEllipseLinesV(ground, 19, 9, rl.Color{255, 225, 80, 235})
	}
	rl.DrawCircleV(body, 12, color)
	rl.DrawCircleLinesV(body, 12, rl.Color{15, 20, 15, 230})
	draw_unit_label(body)
	draw_health_bar(body, units.hp[index], units.hp_max[index])
}

draw_unit_label :: proc(position: rl.Vector2) {
	rl.DrawText("M", i32(position.x) - 5, i32(position.y) - 7, 16, rl.WHITE)
}

draw_health_bar :: proc(position: rl.Vector2, hp, max_hp: u16) {
	percent := f32(hp) / f32(max_hp)
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24, 4}, rl.Color{25, 25, 25, 220})
	color := rl.Color{50, 205, 50, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 50, 50, 255}
	} else if percent <= 0.5 {
		color = rl.Color{230, 180, 25, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24 * percent, 4}, color)
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
		previous := iso_from_world(units.world[i])
		drawn := 0
		for p := int(units.path_index[i]); p < int(units.path_len[i]) && drawn < 24; p += 1 {
			cell := g.cell_position(int(units.path[i][p]))
			point := iso_cell_center(cell)
			rl.DrawLineV(previous, point, rl.Color{90, 200, 120, 120})
			rl.DrawCircleV(point, 3, rl.Color{120, 230, 140, 170})
			previous = point
			drawn += 1
		}
	}
}

// Flat iso tile: a 2:1 diamond. Used by fog and goal overlays.
draw_diamond :: proc(center: rl.Vector2, color: rl.Color) {
	top := rl.Vector2{center.x, center.y - f32(HALF_TILE_H)}
	right := rl.Vector2{center.x + f32(HALF_TILE_W), center.y}
	bottom := rl.Vector2{center.x, center.y + f32(HALF_TILE_H)}
	left := rl.Vector2{center.x - f32(HALF_TILE_W), center.y}
	rl.DrawTriangle(top, bottom, right, color)
	rl.DrawTriangle(top, left, bottom, color)
}
