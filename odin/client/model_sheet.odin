// Dev-only model turntable.
//
//   ./bin/dreamcraft-dev --sheet
//
// Renders reference views of the procedural Mamluk to build/sheet/*.png with
// the full watercolour pipeline, so art passes can be checked without hunting
// for a unit on the map.
package main

import "core:fmt"
import "core:os"
import "core:strings"
import rl "../gfx"
import art "./art"

SHEET_SIZE :: 900

Sheet_Clip :: enum {
	Idle,
	Walk,
	Attack,
}

Sheet_Cam :: enum {
	Eye,
	Iso,
	Side,
}

Sheet_Shot :: struct {
	name:   string,
	angle:  f32,
	clip:   Sheet_Clip,
	phase:  f32,
	fovy:   f32,
	target: f32,
	cam:    Sheet_Cam,
}

run_model_sheet :: proc() {
	os.make_directory("build")
	os.make_directory("build/sheet")
	ensure_pixel_target(SHEET_SIZE, SHEET_SIZE)

	model := build_unit_model(false)
	defer unload_unit_model(&model)
	if !model.loaded {
		fmt.println("sheet: model build failed")
		return
	}
	fmt.printf("sheet: %d verts, %d tris\n", len(model.pos), model.tri_count)

	shots := [10]Sheet_Shot{
		{"01_idle_front", 0, .Idle, 0.20, 2.25, 0.98, .Eye},
		{"02_idle_threequarter", 42, .Idle, 0.20, 2.25, 0.98, .Eye},
		{"03_idle_side", 92, .Idle, 0.20, 2.25, 0.98, .Iso},
		{"04_idle_back", 180, .Idle, 0.20, 2.25, 0.98, .Iso},
		{"05_walk", 42, .Walk, 0.75, 2.25, 0.98, .Eye},
		{"06_attack", 42, .Attack, 0.46, 2.25, 0.98, .Eye},
		{"07_head", 0, .Idle, 0.20, 0.58, 1.66, .Eye},
		{"08_helm_side", 90, .Idle, 0.20, 0.58, 1.66, .Side},
		{"11_walk_side", 90, .Walk, 0.00, 2.25, 0.98, .Side},
		{"12_walk_pass", 90, .Walk, 0.25, 2.25, 0.98, .Side},
	}
	for shot in shots {
		render_sheet_shot(&model, shot)
	}
	enemy := build_unit_model(true)
	defer unload_unit_model(&enemy)
	if enemy.loaded {
		for shot in ([2]Sheet_Shot{
			{"09_enemy_front", 18, .Idle, 0.20, 2.25, 0.98, .Eye},
			{"10_enemy_head", 0, .Idle, 0.20, 0.58, 1.66, .Eye},
		}) {
			render_sheet_shot(&enemy, shot)
		}
	}
	fmt.println("sheet: wrote build/sheet/*.png")
}

@(private)
render_sheet_shot :: proc(m: ^Unit_Model, shot: Sheet_Shot) {
	pose: art.Pose
	switch shot.clip {
	case .Walk:
		art.pose_walk(shot.phase, &pose)
		art.pose_secondary(shot.phase, 1.0, &pose)
	case .Attack:
		art.pose_idle(0.30, &pose)
		art.pose_attack(shot.phase, &pose)
		art.pose_secondary(0.30, 0.20, &pose)
	case .Idle:
		art.pose_idle(shot.phase, &pose)
		art.pose_secondary(shot.phase, 0.15, &pose)
	}
	app.camera = sheet_camera(shot.fovy, shot.target, shot.cam)
	set_unit_shader_uniforms(0.6)
	draw_sheet_frame(m, shot.angle, &pose)
	path := fmt.tprintf("build/sheet/%s.png", shot.name)
	save_pixel_target(strings.clone_to_cstring(path, context.temp_allocator))
}

@(private)
save_pixel_target :: proc(path: cstring) {
	image := rl.LoadImageFromTexture(app.pixel.texture)
	defer rl.UnloadImage(image)
	rl.ImageFlipVertical(&image)
	rl.ExportImage(image, path)
}

@(private)
sheet_camera :: proc(fovy, target_y: f32, cam: Sheet_Cam) -> rl.Camera3D {
	target := rl.Vector3{0, target_y, 0}
	dir := rl.Vector3{1, 0.816, 1}
	switch cam {
	case .Eye:
		dir = rl.Vector3{0.22, 0.16, 1.0}
	case .Iso:
		dir = rl.Vector3{1, 0.816, 1}
	case .Side:
		dir = rl.Vector3{0.06, 0.08, 1.0}
	}
	return rl.Camera3D{
		position = target + rl.Vector3Normalize(dir) * 6.0,
		target = target,
		up = rl.Vector3{0, 1, 0},
		fovy = fovy,
		projection = .ORTHOGRAPHIC,
	}
}

@(private)
draw_sheet_frame :: proc(m: ^Unit_Model, angle_deg: f32, pose: ^art.Pose) {
	unit := rl.MatrixRotateY(angle_deg * 3.14159265 / 180.0)
	rl.BeginTextureMode(app.pixel)
	rl.ClearBackground(rl.Color{26, 34, 27, 255})
	rl.BeginMode3D(app.camera)
	rl.DrawPlane(rl.Vector3{0, -0.01, 0}, rl.Vector2{6, 6}, rl.Color{52, 74, 50, 255})
	draw_unit_mesh(m, pose, unit)
	rl.EndMode3D()
	rl.EndTextureMode()
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_pixel_output()
	rl.EndDrawing()
}
