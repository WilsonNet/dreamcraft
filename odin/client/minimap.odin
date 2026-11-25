// Minimap: one 80x50 texture updated from simulation state, scaled into a clipped Quickshell card.
package main

import rl "../gfx"
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
		return rl.Color{30, 25, 18, 255} // unexplored: dark ink on the basin's bitumen
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

@(private)
world_to_minimap :: proc(point: rl.Vector3, rect: rl.Rectangle) -> rl.Vector2 {
	u := (point.x + f32(g.GRID_W) * 0.5) / f32(g.GRID_W)
	v := 1.0 - (point.z + f32(g.GRID_H) * 0.5) / f32(g.GRID_H)
	return rl.Vector2{rect.x + u * rect.width, rect.y + v * rect.height}
}

@(private)
clip_segment_rect :: proc(p0, p1: rl.Vector2, rect: rl.Rectangle) -> (a, b: rl.Vector2, ok: bool) {
	t0, t1 := f32(0), f32(1)
	d := p1 - p0
	edges := [4][2]f32{
		{-d.x, p0.x - rect.x},
		{d.x, rect.x + rect.width - p0.x},
		{-d.y, p0.y - rect.y},
		{d.y, rect.y + rect.height - p0.y},
	}
	for edge in edges {
		p, q := edge[0], edge[1]
		if p == 0 {
			if q < 0 {
				return {}, {}, false
			}
			continue
		}
		r := q / p
		if p < 0 {
			t0 = max(t0, r)
		} else {
			t1 = min(t1, r)
		}
		if t0 > t1 {
			return {}, {}, false
		}
	}
	return p0 + d * t0, p0 + d * t1, true
}
