#+build !js
package main

import "core:testing"
import rl "vendor:raylib"
import g "../game"

@(test)
iso_grid_round_trip :: proc(t: ^testing.T) {
	points := [3][2]f32{{0, 0}, {80, 50}, {37.25, 12.75}}
	for point in points {
		iso := iso_from_grid(point[0], point[1])
		gx, gy := grid_from_iso(iso)
		testing.expect(t, abs(gx - point[0]) < 0.001)
		testing.expect(t, abs(gy - point[1]) < 0.001)
	}
}

@(test)
iso_cell_center_floors_to_its_cell :: proc(t: ^testing.T) {
	cells := [4]g.Grid_Pos{{0, 0}, {2, 25}, {40, 20}, {79, 49}}
	for cell in cells {
		gx, gy := grid_from_iso(iso_cell_center(cell))
		testing.expect_value(t, i32(gx), cell.x)
		testing.expect_value(t, i32(gy), cell.y)
	}
}

@(test)
iso_from_world_matches_cell_center :: proc(t: ^testing.T) {
	cells := [3]g.Grid_Pos{{0, 0}, {2, 25}, {79, 49}}
	for cell in cells {
		from_world := iso_from_world(g.grid_to_world(cell))
		center := iso_cell_center(cell)
		testing.expect(t, abs(from_world.x - center.x) < 0.001)
		testing.expect(t, abs(from_world.y - center.y) < 0.001)
	}
}

@(test)
iso_camera_clamp_keeps_map_visible :: proc(t: ^testing.T) {
	inside := rl.Vector2{0, 100}
	testing.expect_value(t, clamp_camera(inside), inside)
	outside := clamp_camera(rl.Vector2{-99999, 99999})
	testing.expect(t, outside.x > -99999)
	testing.expect(t, outside.y < 99999)
}

@(test)
iso_screen_center_maps_to_player_cell :: proc(t: ^testing.T) {
	cell := g.Grid_Pos{2, 25}
	camera := rl.Camera2D{
		offset = rl.Vector2{640, 360},
		target = iso_cell_center(cell),
		zoom = 1,
	}
	testing.expect_value(t, iso_screen_to_grid(rl.Vector2{640, 360}, camera), cell)
}
