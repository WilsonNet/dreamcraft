// Isometric 3D camera, ground picking and grid/world conversions.
package main

import "core:math"
import rl "../gfx"
import g "../game"

CAMERA_ORTHO_HEIGHT :: f32(20)
DEFAULT_ZOOM :: f32(0.55)
CAMERA_ZOOM_MIN :: f32(0.25)
CAMERA_ZOOM_MAX :: f32(2.0)
CAMERA_TARGET_HEIGHT :: f32(0)
CAMERA_DISTANCE :: f32(40)
CAMERA_MARGIN :: f32(3)
CAMERA_EDGE_ZONE :: f32(24)
CAMERA_KEY_SCREEN_SPEED :: f32(1.25)
CAMERA_EDGE_SCREEN_SPEED :: f32(1.35)
CAMERA_ACCEL_RATE :: f32(28)
CAMERA_DECEL_RATE :: f32(34)
CAMERA_ZOOM_RATE :: f32(22)

Edge_Input :: struct {
	mouse:     rl.Vector2,
	width:     f32,
	height:    f32,
	minimap:   rl.Rectangle,
	focused:   bool,
	on_screen: bool,
	armed:     bool,
	busy:      bool,
}

camera_offset :: proc() -> rl.Vector3 {
	return rl.Vector3Normalize(rl.Vector3{1, 0.816, 1}) * CAMERA_DISTANCE
}

// Normalized horizontal screen-space pan axes derived from the camera offset.
camera_pan_axes :: proc() -> (forward, right: rl.Vector3) {
	off := camera_offset()
	forward = rl.Vector3Normalize(rl.Vector3{-off.x, 0, -off.z})
	right = rl.Vector3Normalize(rl.Vector3CrossProduct(forward, rl.Vector3{0, 1, 0}))
	return
}

camera_pitch_sin :: proc() -> f32 {
	off := rl.Vector3Normalize(camera_offset())
	return max(abs(off.y), f32(0.001))
}

// Converts a normalized screen-space direction into ground velocity that moves
// horizontally and vertically across the isometric viewport at equal pixel speed.
screen_dir_to_world :: proc(screen_dir: rl.Vector2, fovy, speed_factor: f32) -> rl.Vector3 {
	if screen_dir.x == 0 && screen_dir.y == 0 {
		return {}
	}
	forward, right := camera_pan_axes()
	speed := fovy * speed_factor
	return (right * screen_dir.x + forward * (screen_dir.y / camera_pitch_sin())) * speed
}

// Exact 1:1 ground-plane pull delta for Dota 2 / SC2 style Camera Grip.
screen_delta_to_world_grip :: proc(delta_px: rl.Vector2, fovy, screen_height: f32) -> rl.Vector3 {
	if delta_px.x == 0 && delta_px.y == 0 {
		return {}
	}
	forward, right := camera_pan_axes()
	px_to_ortho := fovy / max(screen_height, f32(1))
	return (-right * delta_px.x + forward * (delta_px.y / camera_pitch_sin())) * px_to_ortho
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
	app.camera_vel = {}
	app.edge_dir = {}
	app.grip_active = false
	app.grip_via_space = false
	app.grip_moved = false
	app.minimap_dragging = false
	apply_camera()
}

apply_camera :: proc() {
	app.camera.target = app.camera_target
	app.camera.position = app.camera_target + camera_offset()
	app.camera.up = rl.Vector3{0, 1, 0}
	app.camera.fovy = CAMERA_ORTHO_HEIGHT * clamp(app.zoom, 0.08, 2.0)
	app.camera.projection = .ORTHOGRAPHIC
}

update_camera :: proc(dt: f64) {
	if app.menu_open {
		app.camera_vel = {}
		app.edge_dir = {}
		end_camera_grip()
		return
	}
	delta := f32(dt)
	update_zoom(delta)
	update_camera_grip()
	update_camera_pan(delta)
	if app.camera_follow && !app.grip_active {
		follow_player()
	}
	clamped := clamp_camera_target(app.camera_target)
	clamp_camera_velocity(app.camera_target, clamped)
	app.camera_target = clamped
	apply_camera()
}

@(private)
update_zoom :: proc(dt: f32) {
	if wheel := input_wheel_y(); wheel != 0 {
		app.target_zoom = clamp(app.target_zoom * math.pow(f32(0.88), wheel), CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	}
	if abs(app.target_zoom - app.zoom) < 0.0005 {
		app.zoom = app.target_zoom
		return
	}
	blend := 1 - math.exp(-CAMERA_ZOOM_RATE * dt)
	app.zoom += (app.target_zoom - app.zoom) * blend
}

@(private)
update_camera_pan :: proc(dt: f32) {
	key_dir := keyboard_pan_direction()
	mouse := input_mouse_pos()
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	focused := input_window_focused()
	on_screen := update_cursor_inside(mouse, width, height, focused, input_cursor_on_screen())
	edge_input := Edge_Input{
		mouse     = mouse,
		width     = width,
		height    = height,
		minimap   = app.minimap_rect,
		focused   = focused,
		on_screen = on_screen,
		armed     = app.edge_armed,
		busy      = app.grip_active || app.minimap_dragging || app.dragging,
	}
	edge_dir, next_armed := compute_edge_direction(edge_input)
	app.edge_armed = next_armed
	app.edge_dir = edge_dir
	if app.grip_active {
		app.camera_vel = {}
		return
	}
	target_vel := resolve_pan_velocity(key_dir, edge_dir)
	if key_dir.x != 0 || key_dir.y != 0 || edge_dir.x != 0 || edge_dir.y != 0 {
		app.camera_follow = false
	}
	apply_damped_pan(target_vel, dt)
}

@(private)
resolve_pan_velocity :: proc(key_dir, edge_dir: rl.Vector2) -> rl.Vector3 {
	combined := key_dir + edge_dir
	if combined.x == 0 && combined.y == 0 {
		return {}
	}
	speed := CAMERA_EDGE_SCREEN_SPEED
	if edge_dir.x == 0 && edge_dir.y == 0 {
		speed = CAMERA_KEY_SCREEN_SPEED
	}
	return screen_dir_to_world(rl.Vector2Normalize(combined), app.camera.fovy, speed)
}

@(private)
apply_damped_pan :: proc(target_vel: rl.Vector3, dt: f32) {
	accelerating := target_vel.x != 0 || target_vel.z != 0
	rate := accelerating ? CAMERA_ACCEL_RATE : CAMERA_DECEL_RATE
	blend := 1 - math.exp(-rate * dt)
	app.camera_vel += (target_vel - app.camera_vel) * blend
	if !accelerating && rl.Vector3Length(app.camera_vel) < 0.01 {
		app.camera_vel = {}
	}
	app.camera_target += app.camera_vel * dt
}

@(private)
keyboard_pan_direction :: proc() -> rl.Vector2 {
	dir := rl.Vector2{0, 0}
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
		dir.y += 1
	}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		dir.y -= 1
	}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		dir.x -= 1
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		dir.x += 1
	}
	if dir.x != 0 || dir.y != 0 {
		dir = rl.Vector2Normalize(dir)
	}
	return dir
}

compute_edge_direction :: proc(in_state: Edge_Input) -> (dir: rl.Vector2, next_armed: bool) {
	if !in_state.focused || in_state.width <= 0 || in_state.height <= 0 {
		return {}, false
	}
	if !in_state.on_screen {
		return {}, in_state.armed
	}
	zone := CAMERA_EDGE_ZONE
	if !in_state.armed {
		inner := in_state.mouse.x > zone && in_state.mouse.x < in_state.width - zone &&
			in_state.mouse.y > zone && in_state.mouse.y < in_state.height - zone
		return {}, inner
	}
	if in_state.busy || rl.CheckCollisionPointRec(in_state.mouse, in_state.minimap) {
		return {}, true
	}
	if in_state.mouse.x <= zone {
		dir.x -= 1
	} else if in_state.mouse.x >= in_state.width - zone {
		dir.x += 1
	}
	if in_state.mouse.y <= zone {
		dir.y += 1
	} else if in_state.mouse.y >= in_state.height - zone {
		dir.y -= 1
	}
	if dir.x != 0 || dir.y != 0 {
		dir = rl.Vector2Normalize(dir)
	}
	return dir, true
}

start_camera_grip :: proc(mouse: rl.Vector2, via_space: bool) {
	app.grip_active = true
	app.grip_via_space = via_space
	app.grip_moved = false
	app.grip_last_mouse = mouse
	app.camera_vel = {}
}

end_camera_grip :: proc() {
	app.grip_active = false
	app.grip_via_space = false
	app.grip_moved = false
}

@(private)
update_camera_grip :: proc() {
	if !app.grip_active {
		return
	}
	still_held := input_middle_down()
	if app.grip_via_space {
		still_held = input_left_down() && input_space_down()
	}
	if !input_window_focused() || app.menu_open || !still_held {
		end_camera_grip()
		return
	}
	mouse := input_mouse_pos()
	delta_px := mouse - app.grip_last_mouse
	app.grip_last_mouse = mouse
	if rl.Vector2Length(delta_px) >= 0.5 {
		app.grip_moved = true
		app.camera_follow = false
	}
	app.camera_target += screen_delta_to_world_grip(delta_px, app.camera.fovy, f32(rl.GetScreenHeight()))
	app.camera_vel = {}
}

follow_player :: proc() {
	if app.game.units.selected_count > 0 {
		if c, ok := g.selection_centroid(&app.game.units); ok {
			app.camera_target = world_to_3d(c)
			app.camera_target.y = CAMERA_TARGET_HEIGHT
			return
		}
	}
	index, ok := g.game_player_index(&app.game)
	if !ok {
		return
	}
	app.camera_target = unit_ground(index)
	app.camera_target.y = CAMERA_TARGET_HEIGHT
}

clamp_camera_target :: proc(target: rl.Vector3) -> rl.Vector3 {
	return rl.Vector3{
		clamp(target.x, -f32(g.GRID_W) * 0.5 - CAMERA_MARGIN, f32(g.GRID_W) * 0.5 + CAMERA_MARGIN),
		CAMERA_TARGET_HEIGHT,
		clamp(target.z, -f32(g.GRID_H) * 0.5 - CAMERA_MARGIN, f32(g.GRID_H) * 0.5 + CAMERA_MARGIN),
	}
}

@(private)
clamp_camera_velocity :: proc(unclamped, clamped: rl.Vector3) {
	if clamped.x != unclamped.x {
		app.camera_vel.x = 0
	}
	if clamped.z != unclamped.z {
		app.camera_vel.z = 0
	}
}

screen_to_world_ground :: proc(screen: rl.Vector2) -> (rl.Vector3, bool) {
	ray := rl.GetScreenToWorldRay(screen, app.camera)
	if abs(ray.direction.y) < 0.00001 {
		return {}, false
	}
	t := -ray.position.y / ray.direction.y
	if t < 0 {
		return {}, false
	}
	return ray.position + ray.direction * t, true
}

world_to_grid_clamped :: proc(point: rl.Vector3) -> g.Grid_Pos {
	gx := i32(math.floor(f64(point.x + f32(g.GRID_W) * 0.5)))
	gy := i32(math.floor(f64(point.z + f32(g.GRID_H) * 0.5)))
	return g.Grid_Pos{
		x = clamp(gx, 0, g.GRID_W - 1),
		y = clamp(gy, 0, g.GRID_H - 1),
	}
}

screen_to_grid :: proc(screen: rl.Vector2) -> g.Grid_Pos {
	point, ok := screen_to_world_ground(screen)
	if !ok {
		return g.START_POS
	}
	return world_to_grid_clamped(point)
}
