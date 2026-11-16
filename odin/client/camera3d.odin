// Isometric 3D camera, ground picking and grid/world conversions.
package main

import "core:math"
import rl "vendor:raylib"
import g "../game"

CAMERA_ORTHO_HEIGHT :: f32(20)
CAMERA_TARGET_HEIGHT :: f32(0)
CAMERA_DISTANCE :: f32(40)
CAMERA_PAN_SPEED :: f32(14)
CAMERA_EDGE_BASE :: f32(8)
CAMERA_EDGE_MAX :: f32(20)

camera_offset :: proc() -> rl.Vector3 {
	return rl.Vector3Normalize(rl.Vector3{1, 0.816, 1}) * CAMERA_DISTANCE
}

cell_center :: proc(cell: g.Grid_Pos) -> rl.Vector3 {
	return rl.Vector3{
		f32(cell.x) - f32(g.GRID_W) * 0.5 + 0.5,
		0,
		f32(cell.y) - f32(g.GRID_H) * 0.5 + 0.5,
	}
}

world_to_3d :: proc(world: g.Fixed_Vec) -> rl.Vector3 {
	gx := (g.fp_to_f32(world.x) - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE)
	gy := (g.fp_to_f32(world.y) - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE)
	return rl.Vector3{
		gx - f32(g.GRID_W) * 0.5,
		0,
		gy - f32(g.GRID_H) * 0.5,
	}
}

unit_ground :: proc(index: int) -> rl.Vector3 {
	return world_to_3d(app.game.units.world[index])
}

reset_camera :: proc() {
	position, ok := g.game_player_position(&app.game)
	if !ok {
		position = g.START_POS
	}
	app.camera_target = cell_center(position)
	app.camera_target.y = CAMERA_TARGET_HEIGHT
	app.camera_follow = true
	apply_camera()
}

apply_camera :: proc() {
	app.camera.target = app.camera_target
	app.camera.position = app.camera_target + camera_offset()
	app.camera.up = rl.Vector3{0, 1, 0}
	app.camera.fovy = CAMERA_ORTHO_HEIGHT
	app.camera.projection = .ORTHOGRAPHIC
}

update_camera :: proc(dt: f64) {
	if app.menu_open {
		return
	}
	delta := f32(dt)
	forward := rl.Vector3{-1, 0, -1}
	right := rl.Vector3{-1, 0, 1}
	move := rl.Vector3{0, 0, 0}
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
		move += forward
	}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		move -= forward
	}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		move -= right
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		move += right
	}
	if move.x != 0 || move.z != 0 {
		move = rl.Vector3Normalize(move)
		app.camera_target += move * CAMERA_PAN_SPEED * delta
		app.camera_follow = false
	}
	if apply_edge_scroll(delta) {
		app.camera_follow = false
	}
	if app.camera_follow {
		follow_player()
	}
	app.camera_target = clamp_camera_target(app.camera_target)
	apply_camera()
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
	forward := rl.Vector3{-1, 0, -1}
	right := rl.Vector3{-1, 0, 1}
	velocity := rl.Vector3{0, 0, 0}
	if mouse.x < ZONE {
		velocity -= right * (CAMERA_EDGE_BASE + (CAMERA_EDGE_MAX - CAMERA_EDGE_BASE) * (1 - mouse.x / ZONE))
	} else if mouse.x > width - ZONE {
		velocity += right * (CAMERA_EDGE_BASE + (CAMERA_EDGE_MAX - CAMERA_EDGE_BASE) * (1 - (width - mouse.x) / ZONE))
	}
	if mouse.y < ZONE {
		velocity += forward * (CAMERA_EDGE_BASE + (CAMERA_EDGE_MAX - CAMERA_EDGE_BASE) * (1 - mouse.y / ZONE))
	} else if mouse.y > height - ZONE {
		velocity -= forward * (CAMERA_EDGE_BASE + (CAMERA_EDGE_MAX - CAMERA_EDGE_BASE) * (1 - (height - mouse.y) / ZONE))
	}
	app.camera_target += velocity * dt
	return velocity.x != 0 || velocity.z != 0
}

follow_player :: proc() {
	index, ok := g.game_player_index(&app.game)
	if !ok {
		return
	}
	app.camera_target = unit_ground(index)
	app.camera_target.y = CAMERA_TARGET_HEIGHT
}

clamp_camera_target :: proc(target: rl.Vector3) -> rl.Vector3 {
	margin := f32(3)
	return rl.Vector3{
		clamp(target.x, -f32(g.GRID_W) * 0.5 - margin, f32(g.GRID_W) * 0.5 + margin),
		CAMERA_TARGET_HEIGHT,
		clamp(target.z, -f32(g.GRID_H) * 0.5 - margin, f32(g.GRID_H) * 0.5 + margin),
	}
}

screen_to_grid :: proc(screen: rl.Vector2) -> g.Grid_Pos {
	ray := rl.GetScreenToWorldRay(screen, app.camera)
	if abs(ray.direction.y) < 0.00001 {
		return g.START_POS
	}
	t := -ray.position.y / ray.direction.y
	if t < 0 {
		return g.START_POS
	}
	point := ray.position + ray.direction * t
	gx := i32(math.floor(f64(point.x + f32(g.GRID_W) * 0.5)))
	gy := i32(math.floor(f64(point.z + f32(g.GRID_H) * 0.5)))
	return g.Grid_Pos{
		x = clamp(gx, 0, g.GRID_W - 1),
		y = clamp(gy, 0, g.GRID_H - 1),
	}
}
