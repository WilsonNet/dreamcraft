// Software framebuffer in 2:1 isometric projection: 640x400 RGBA.
//
// The simulation stays on the orthogonal grid. Tiles are 8x4 pixel diamonds
// with the whole map centered in the framebuffer.
package main

import g "../game"

HALF_TILE_W :: 4
HALF_TILE_H :: 2
PIXEL_W :: 640
PIXEL_H :: 400
MAP_OFFSET_X :: 260
MAP_OFFSET_Y :: 70

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

@(export)
web_iso_offset_x :: proc() -> i32 {
	return MAP_OFFSET_X
}

@(export)
web_iso_offset_y :: proc() -> i32 {
	return MAP_OFFSET_Y
}

@(export)
web_iso_half_w :: proc() -> i32 {
	return HALF_TILE_W
}

@(export)
web_iso_half_h :: proc() -> i32 {
	return HALF_TILE_H
}

web_render :: proc() {
	clear(rgba(5, 10, 5))
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			render_cell(g.Grid_Pos{x = i32(gx), y = i32(gy)})
		}
	}
	render_trees()
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
	fill_diamond(iso_center(cell), base)
}

@(private)
render_trees :: proc() {
	// Back-to-front along iso depth.
	for depth in 0..<(g.GRID_W + g.GRID_H - 1) {
		for gx in 0..<g.GRID_W {
			gy := depth - gx
			if gy < 0 || gy >= g.GRID_H {
				continue
			}
			cell := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			if g.fog_state(&Game_State.fog, cell) == 0 {
				continue
			}
			if !g.grid_is_blocked(&Game_State.grid, cell) {
				continue
			}
			center := iso_center(cell)
			fill_rect(center.x - 1, center.y - 5, 3, 4, rgba(30, 120, 50))
			set_pixel(center.x, center.y - 1, rgba(95, 60, 25))
		}
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
		center := iso_center(cell)
		draw_diamond_lines(center, 3, 2, color)
	}
}

@(private)
render_units :: proc() {
	units := &Game_State.units
	order: [g.MAX_UNITS]int
	count := 0
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&Game_State, i) {
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

@(private)
unit_depth_less :: proc(a, b: int) -> bool {
	units := &Game_State.units
	da := units.world[a].x + units.world[a].y
	db := units.world[b].x + units.world[b].y
	if da != db {
		return da < db
	}
	return a < b
}

@(private)
draw_unit :: proc(index: int) {
	units := &Game_State.units
	center := iso_world_center(units.world[index])
	color := rgba(70, 125, 235)
	if units.team[index] == .Enemy {
		color = rgba(225, 70, 70)
	}
	fill_rect(center.x - 2, center.y - 6, 4, 5, color)
	if units.selected[index] {
		draw_diamond_lines(center, 5, 3, rgba(255, 225, 80))
	}
	render_health(center, units.hp[index], units.hp_max[index])
}

@(private)
render_health :: proc(center: rl_pixel, hp, hp_max: u16) {
	if hp >= hp_max {
		return
	}
	y := center.y - 8
	percent := f32(hp) / f32(hp_max)
	width := 6
	fill_rect(center.x - 3, y, width, 1, rgba(40, 40, 40))
	color := rgba(60, 210, 60)
	if percent <= 0.25 {
		color = rgba(230, 50, 50)
	} else if percent <= 0.5 {
		color = rgba(230, 180, 25)
	}
	fill_rect(center.x - 3, y, max(1, int(percent * f32(width))), 1, color)
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
			center := iso_center(cell)
			fill_rect(center.x - 1, center.y - 1, 2, 2, rgba(100, 220, 130))
		}
	}
}

// rl_pixel matches the x/y layout used by the framebuffer helpers.
rl_pixel :: struct {
	x, y: int,
}

@(private)
iso_center :: proc(cell: g.Grid_Pos) -> rl_pixel {
	return rl_pixel{
		x = MAP_OFFSET_X + (int(cell.x) - int(cell.y)) * HALF_TILE_W,
		y = MAP_OFFSET_Y + (int(cell.x) + int(cell.y) + 1) * HALF_TILE_H,
	}
}

@(private)
iso_world_center :: proc(world: g.Fixed_Vec) -> rl_pixel {
	fx := (g.fp_to_f32(world.x) - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE)
	fy := (g.fp_to_f32(world.y) - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE)
	return rl_pixel{
		x = MAP_OFFSET_X + int((fx - fy) * f32(HALF_TILE_W)),
		y = MAP_OFFSET_Y + int((fx + fy) * f32(HALF_TILE_H)),
	}
}

@(private)
fill_diamond :: proc(center: rl_pixel, color: u32) {
	for py in -HALF_TILE_H..=HALF_TILE_H {
		for px in -HALF_TILE_W..=HALF_TILE_W {
			if abs(f32(px)) / f32(HALF_TILE_W) + abs(f32(py)) / f32(HALF_TILE_H) <= 1.0 {
				set_pixel(center.x + px, center.y + py, color)
			}
		}
	}
}

@(private)
draw_diamond_lines :: proc(center: rl_pixel, half_w, half_h: int, color: u32) {
	for i in 0..=half_w {
		y := i * half_h / half_w
		set_pixel(center.x + i, center.y + y, color)
		set_pixel(center.x - i, center.y + y, color)
		set_pixel(center.x + i, center.y - y, color)
		set_pixel(center.x - i, center.y - y, color)
	}
}

@(private)
fill_rect :: proc(x, y, width, height: int, color: u32) {
	for py in 0..<height {
		for px in 0..<width {
			set_pixel(x + px, y + py, color)
		}
	}
}

@(private)
clear :: proc(color: u32) {
	for &pixel in Pixels {
		pixel = color
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
