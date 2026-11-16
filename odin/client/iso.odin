// Isometric projection helpers.
//
// The simulation stays on the orthogonal grid. Only the client projects grid
// and interpolated world positions into 2:1 isometric screen space.
package main

import "core:math"
import rl "vendor:raylib"
import g "../game"

TILE_W :: 64
TILE_H :: 32
HALF_TILE_W :: TILE_W / 2
HALF_TILE_H :: TILE_H / 2
CAMERA_MARGIN :: f32(200)

// Continuous grid coordinates: integer values are cell corners.
iso_from_grid :: proc(gx, gy: f32) -> rl.Vector2 {
	return rl.Vector2{(gx - gy) * f32(HALF_TILE_W), (gx + gy) * f32(HALF_TILE_H)}
}

iso_cell_center :: proc(cell: g.Grid_Pos) -> rl.Vector2 {
	return iso_from_grid(f32(cell.x) + 0.5, f32(cell.y) + 0.5)
}

// Orthogonal fixed-point world position (units.world) to iso space.
iso_from_world :: proc(world: g.Fixed_Vec) -> rl.Vector2 {
	fx := (g.fp_to_f32(world.x) - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE)
	fy := (g.fp_to_f32(world.y) - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE)
	return iso_from_grid(fx, fy)
}

grid_from_iso :: proc(point: rl.Vector2) -> (gx, gy: f32) {
	hx := point.x / f32(HALF_TILE_W)
	hy := point.y / f32(HALF_TILE_H)
	return (hx + hy) * 0.5, (hy - hx) * 0.5
}

iso_screen_to_grid :: proc(screen: rl.Vector2, camera: rl.Camera2D) -> g.Grid_Pos {
	point := rl.GetScreenToWorld2D(screen, camera)
	gx, gy := grid_from_iso(point)
	return g.Grid_Pos{
		x = clamp(i32(math.floor(f64(gx))), 0, g.GRID_W - 1),
		y = clamp(i32(math.floor(f64(gy))), 0, g.GRID_H - 1),
	}
}

clamp_camera :: proc(position: rl.Vector2) -> rl.Vector2 {
	min_x := -f32(g.GRID_H * HALF_TILE_W) - CAMERA_MARGIN
	max_x := f32(g.GRID_W * HALF_TILE_W) + CAMERA_MARGIN
	min_y := -CAMERA_MARGIN
	max_y := f32((g.GRID_W + g.GRID_H) * HALF_TILE_H) + CAMERA_MARGIN
	return rl.Vector2{clamp(position.x, min_x, max_x), clamp(position.y, min_y, max_y)}
}
