// Software framebuffer: 4x4 pixels per grid cell, 320x200 RGBA.
package main

import g "../game"

PIXEL_SCALE :: 4
PIXEL_W :: g.GRID_W * PIXEL_SCALE
PIXEL_H :: g.GRID_H * PIXEL_SCALE
Pixels: [PIXEL_W * PIXEL_H]u32

@(export)
web_pixels_ptr :: proc() -> rawptr {
	return raw_data(Pixels[:])
}

@(export)
web_pixels_width :: proc() -> i32 {
	return PIXEL_W
}

@(export)
web_pixels_height :: proc() -> i32 {
	return PIXEL_H
}

web_render :: proc() {
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			render_cell(g.Grid_Pos{x = i32(gx), y = i32(gy)})
		}
	}
	render_waypoints()
	render_units()
	render_selected_paths()
}

@(private)
render_cell :: proc(cell: g.Grid_Pos) {
	state := g.fog_state(&Game_State.fog, cell)
	base: u32
	if state == 0 {
		base = rgba(4, 6, 4)
	} else if state == 1 {
		base = rgba(20, 44, 22)
	} else {
		base = rgba(42, 92, 46)
	}
	if state > 0 {
		if g.grid_is_blocked(&Game_State.grid, cell) {
			if state == 2 {
				base = rgba(18, 74, 30)
			} else {
				base = rgba(10, 40, 16)
			}
		} else if cell.x >= g.GOAL_X && cell.x < g.GRID_W - 1 {
			if state == 2 {
				base = rgba(135, 112, 30)
			} else {
				base = rgba(75, 62, 18)
			}
		}
	}
	fill_cell(cell, base)
	if state > 0 && g.grid_is_blocked(&Game_State.grid, cell) {
		blend_center(cell, rgba(30, 120, 50))
	}
}

@(private)
render_waypoints :: proc() {
	for i in 0..<Game_State.waypoints.count {
		cell := Game_State.waypoints.points[i]
		if g.fog_state(&Game_State.fog, cell) == 0 {
			continue
		}
		color := rgba(120, 100, 25)
		if i < Game_State.waypoints.current {
			color = rgba(60, 170, 60)
		} else if i == Game_State.waypoints.current {
			color = rgba(235, 200, 50)
		}
		set_pixel(int(cell.x) * PIXEL_SCALE + 1, int(cell.y) * PIXEL_SCALE + 1, color)
		set_pixel(int(cell.x) * PIXEL_SCALE + 2, int(cell.y) * PIXEL_SCALE + 1, color)
		set_pixel(int(cell.x) * PIXEL_SCALE + 1, int(cell.y) * PIXEL_SCALE + 2, color)
		set_pixel(int(cell.x) * PIXEL_SCALE + 2, int(cell.y) * PIXEL_SCALE + 2, color)
	}
}

@(private)
render_units :: proc() {
	for i in 0..<g.MAX_UNITS {
		units := &Game_State.units
		if !units.alive[i] || !g.enemy_is_visible(&Game_State, i) {
			continue
		}
		cell := units.position[i]
		color := rgba(70, 125, 235)
		if units.team[i] == .Enemy {
			color = rgba(225, 70, 70)
		}
		fill_block(cell, color)
		render_health(cell, units.hp[i], units.hp_max[i])
		if units.selected[i] {
			outline_block(cell, rgba(255, 225, 80))
		}
	}
}

@(private)
render_health :: proc(cell: g.Grid_Pos, hp, hp_max: u16) {
	if hp >= hp_max {
		return
	}
	x := int(cell.x) * PIXEL_SCALE
	y := int(cell.y) * PIXEL_SCALE - 1
	percent := f32(hp) / f32(hp_max)
	width := int(percent * PIXEL_SCALE)
	for px in 0..<PIXEL_SCALE {
		color := rgba(40, 40, 40)
		if px < width {
			color = rgba(60, 210, 60)
			if percent <= 0.25 {
				color = rgba(230, 50, 50)
			} else if percent <= 0.5 {
				color = rgba(230, 180, 25)
			}
		}
		set_pixel(x + px, y, color)
	}
}

@(private)
render_selected_paths :: proc() {
	for i in 0..<g.MAX_UNITS {
		units := &Game_State.units
		if !units.alive[i] || !units.selected[i] || !g.unit_has_path(units, i) {
			continue
		}
		limit := min(int(units.path_len[i]), int(units.path_index[i]) + 64)
		for p in int(units.path_index[i])..<limit {
			cell := g.cell_position(int(units.path[i][p]))
			set_pixel(int(cell.x) * PIXEL_SCALE + 1, int(cell.y) * PIXEL_SCALE + 1, rgba(100, 220, 130))
			set_pixel(int(cell.x) * PIXEL_SCALE + 2, int(cell.y) * PIXEL_SCALE + 2, rgba(100, 220, 130))
		}
	}
}

@(private)
fill_cell :: proc(cell: g.Grid_Pos, color: u32) {
	base_x := int(cell.x) * PIXEL_SCALE
	base_y := int(cell.y) * PIXEL_SCALE
	border := rgba(16, 26, 16)
	for py in 0..<PIXEL_SCALE {
		for px in 0..<PIXEL_SCALE {
			c := color
			if px == PIXEL_SCALE - 1 || py == PIXEL_SCALE - 1 {
				c = border
			}
			set_pixel(base_x + px, base_y + py, c)
		}
	}
}

@(private)
fill_block :: proc(cell: g.Grid_Pos, color: u32) {
	base_x := int(cell.x) * PIXEL_SCALE
	base_y := int(cell.y) * PIXEL_SCALE
	for py in 0..<PIXEL_SCALE {
		for px in 0..<PIXEL_SCALE {
			set_pixel(base_x + px, base_y + py, color)
		}
	}
}

@(private)
blend_center :: proc(cell: g.Grid_Pos, color: u32) {
	base_x := int(cell.x) * PIXEL_SCALE
	base_y := int(cell.y) * PIXEL_SCALE
	set_pixel(base_x + 1, base_y + 1, color)
	set_pixel(base_x + 2, base_y + 1, color)
	set_pixel(base_x + 1, base_y + 2, color)
	set_pixel(base_x + 2, base_y + 2, color)
}

@(private)
outline_block :: proc(cell: g.Grid_Pos, color: u32) {
	base_x := int(cell.x) * PIXEL_SCALE
	base_y := int(cell.y) * PIXEL_SCALE
	for p in -1..=PIXEL_SCALE {
		set_pixel(base_x + p, base_y - 1, color)
		set_pixel(base_x + p, base_y + PIXEL_SCALE, color)
		set_pixel(base_x - 1, base_y + p, color)
		set_pixel(base_x + PIXEL_SCALE, base_y + p, color)
	}
}

@(private)
set_pixel :: proc(x, y: int, color: u32) {
	if x < 0 || x >= PIXEL_W || y < 0 || y >= PIXEL_H {
		return
	}
	Pixels[y * PIXEL_W + x] = color
}

@(private)
rgba :: proc(r, g, b: u8, a: u8 = 255) -> u32 {
	return u32(r) | u32(g) << 8 | u32(b) << 16 | u32(a) << 24
}
