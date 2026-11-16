// Minimap: one 80x50 texture updated from simulation state, scaled into the HUD.
package main

import rl "vendor:raylib"
import g "../game"

update_minimap_pixels :: proc() {
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			cell := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			app.minimap_pixels[gy * g.GRID_W + gx] = minimap_terrain_color(cell)
		}
	}
	for i in 0..<app.game.waypoints.count {
		cell := app.game.waypoints.points[i]
		color := rl.Color{95, 80, 20, 255}
		if i == app.game.waypoints.current {
			color = rl.Color{220, 185, 45, 255}
		}
		set_minimap_pixel(cell, color)
	}
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] {
			continue
		}
		if units.team[i] == .Enemy && !g.enemy_is_visible(&app.game, i) {
			continue
		}
		color := rl.Color{70, 125, 235, 255}
		if units.team[i] == .Enemy {
			color = rl.Color{225, 70, 70, 255}
		}
		set_minimap_pixel(units.position[i], color)
	}
	rl.UpdateTexture(app.minimap, raw_data(app.minimap_pixels[:]))
}

minimap_terrain_color :: proc(cell: g.Grid_Pos) -> rl.Color {
	state := g.fog_state(&app.game.fog, cell)
	if state == 0 {
		return rl.Color{4, 6, 4, 255}
	}
	index, _ := g.cell_index(cell)
	if g.bit_grid_test(&app.game.grid.obstacles, index) {
		if state == 2 {
			return rl.Color{20, 78, 32, 255}
		}
		return rl.Color{10, 42, 18, 255}
	}
	if cell.x >= g.GOAL_X && cell.x < g.GRID_W - 1 && state == 2 {
		return rl.Color{80, 68, 20, 255}
	}
	if state == 2 {
		return rl.Color{42, 92, 46, 255}
	}
	return rl.Color{22, 48, 24, 255}
}

set_minimap_pixel :: proc(cell: g.Grid_Pos, color: rl.Color) {
	if !g.in_bounds(cell) {
		return
	}
	app.minimap_pixels[int(cell.y) * g.GRID_W + int(cell.x)] = color
}

draw_minimap_panel :: proc() {
	rect := app.minimap_rect
	rl.DrawRectangleRec(rl.Rectangle{rect.x - 5, rect.y - 5, rect.width + 10, rect.height + 10}, rl.Color{8, 14, 8, 230})
	source := rl.Rectangle{0, 0, g.GRID_W, -g.GRID_H}
	rl.DrawTexturePro(app.minimap, source, rect, rl.Vector2{0, 0}, 0, rl.WHITE)
	rl.DrawRectangleLinesEx(rl.Rectangle{rect.x - 5, rect.y - 5, rect.width + 10, rect.height + 10}, 2, rl.Color{90, 150, 90, 255})
	rl.DrawText("MINIMAP", i32(rect.x), i32(rect.y - 24), 12, rl.Color{170, 200, 170, 230})
}
