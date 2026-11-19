// Minimap: one 80x50 texture updated from simulation state, scaled into a clipped Quickshell card.
package main

import rl "vendor:raylib"
import g "../game"
import ui "../ui"

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

compose_minimap_island :: proc(ctx: ^ui.Context, h: f32) {
	// Outer card (216x161 at x=12, y=h-178) keeps minimap_tex strictly at {20, h-150, 200, 125}.
	cm := ui.m_blocks(ui.m_pad_edges(ui.m_gap(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), 12, h - 178), 216, 161), ui.style_island(ui.RAD_LG)), 6), ui.edges_ltrb(8, 6, 8, 8)))
	ui.open_col(ctx, ui.id("minimap_card"), cm)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_align(ui.m_h(ui.m_fill(ui.mod(), true, false), 16), .Center))
	ui.label(ctx, "MINIMAP", .Mono_Bold, 11, ui.COL_TEXT_SECONDARY)
	ui.spacer(ctx, 1)
	cam_txt: cstring = app.camera_follow ? "LOCK" : "FREE"
	ui.label(ctx, cam_txt, .Mono_Bold, 10.5, app.camera_follow ? ui.COL_TEXT_MOVE : ui.COL_TEXT_GOLD)
	ui.close(ctx)

	ui.clipped_texture(
		ctx,
		ui.id("minimap_view"),
		app.minimap,
		8,
		true,
		ui.COL_BORDER_DEFAULT,
		ui.m_blocks(ui.m_size(ui.mod(), 200, 125)),
		draw_minimap_camera_overlay,
		nil,
	)
	ui.close(ctx)
}

@(private)
draw_minimap_camera_overlay :: proc(rect: rl.Rectangle, _: rawptr) {
	draw_minimap_camera_box(rect)
}

@(private)
world_to_minimap :: proc(point: rl.Vector3, rect: rl.Rectangle) -> rl.Vector2 {
	u := (point.x + f32(g.GRID_W) * 0.5) / f32(g.GRID_W)
	v := 1.0 - (point.z + f32(g.GRID_H) * 0.5) / f32(g.GRID_H)
	return rl.Vector2{rect.x + u * rect.width, rect.y + v * rect.height}
}

@(private)
draw_minimap_camera_box :: proc(rect: rl.Rectangle) {
	w := f32(rl.GetScreenWidth())
	h := max(f32(rl.GetScreenHeight()) - HUD_HEIGHT, f32(1))
	corners := [4]rl.Vector2{{0, 0}, {w, 0}, {w, h}, {0, h}}
	pts: [4]rl.Vector2
	for sc, idx in corners {
		p, ok := screen_to_world_ground(sc)
		if !ok {
			return
		}
		pts[idx] = world_to_minimap(p, rect)
	}
	col := rl.Color{235, 240, 225, 210}
	for i in 0..<4 {
		if a, b, ok := clip_segment_rect(pts[i], pts[(i + 1) % 4], rect); ok {
			rl.DrawLineV(a, b, col)
		}
	}
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
