// Model Editor and Model Picker 3D stage rendering.
package main

import "core:math"
import rl "vendor:raylib"

PICKER_TEX_W :: 520
PICKER_TEX_H :: 440

draw_picker_frame :: proc() {
	ed := &app.editor
	dt := rl.GetFrameTime()
	ed.picker_yaw += dt * 0.55
	render_picker_turntable()

	w := i32(rl.GetScreenWidth())
	h := i32(rl.GetScreenHeight())
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{12, 18, 13, 255})
	if app.pixel.id > 0 {
		draw_pixel_output()
	}
	rl.DrawRectangle(0, 0, w, h, rl.Color{8, 12, 9, 215})
	vui_render()
	rl.EndDrawing()
}

@(private)
picker_turntable_bounds :: proc(m: ^Unit_Model) -> (center: rl.Vector3, radius: f32) {
	if !m.loaded || len(m.rest_pos) == 0 {
		return {0, 0.9, 0}, 1.2
	}
	lo := m.rest_pos[0]
	hi := m.rest_pos[0]
	for p in m.rest_pos {
		lo = {min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)}
		hi = {max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)}
	}
	center = (lo + hi) * 0.5
	radius = max(0.35, rl.Vector3Length(hi - lo) * 0.5)
	return
}

@(private)
render_picker_turntable :: proc() {
	ed := &app.editor
	if ed.picker_rect_tex.id == 0 {
		ed.picker_rect_tex = rl.LoadRenderTexture(PICKER_TEX_W, PICKER_TEX_H)
		rl.SetTextureFilter(ed.picker_rect_tex.texture, .BILINEAR)
	}
	if ed.picker_rect_tex.id == 0 {
		return
	}
	center, radius := picker_turntable_bounds(&ed.picker_preview)
	dist := max(radius * 3.1, 2.2)
	cam_pos := center + rl.Vector3{
		math.sin(ed.picker_yaw) * dist,
		radius * 0.65 + 0.35,
		math.cos(ed.picker_yaw) * dist,
	}
	cam := rl.Camera3D{
		position   = cam_pos,
		target     = center,
		up         = {0, 1, 0},
		fovy       = 36.0,
		projection = .PERSPECTIVE,
	}
	set_unit_shader_uniforms_at(f32(rl.GetTime()), cam.position)

	rl.BeginTextureMode(ed.picker_rect_tex)
	rl.ClearBackground(rl.Color{19, 27, 21, 255})
	rl.BeginMode3D(cam)
	draw_picker_pedestal()
	if ed.picker_preview.loaded {
		rl.DrawMesh(ed.picker_preview.mesh, ed.picker_preview.material, rl.Matrix(1))
	}
	rl.EndMode3D()
	rl.EndTextureMode()
}

@(private)
draw_picker_pedestal :: proc() {
	grid_col := rl.Color{46, 62, 48, 255}
	for i := -4; i <= 4; i += 1 {
		v := f32(i) * 0.25
		rl.DrawLine3D({-1.0, 0, v}, {1.0, 0, v}, grid_col)
		rl.DrawLine3D({v, 0, -1.0}, {v, 0, 1.0}, grid_col)
	}
	rl.DrawCircle3D({0, 0.002, 0}, 0.55, {1, 0, 0}, 90, rl.Color{110, 165, 102, 180})
}

draw_editor_frame :: proc() {
	ed := &app.editor
	dt := f32(rl.GetFrameTime())
	editor_update_pose_matrices(dt)
	if ed.status_timer > 0 {
		ed.status_timer = max(0, ed.status_timer - dt)
	}
	set_unit_shader_uniforms_at(f32(rl.GetTime()), ed.camera.position)

	if ed.use_watercolor && app.pixel.id > 0 {
		rl.BeginTextureMode(app.pixel)
		rl.ClearBackground(rl.Color{22, 28, 24, 255})
		rl.BeginMode3D(ed.camera)
		draw_editor_stage_3d()
		editor_draw_preview_mesh()
		rl.EndMode3D()
		rl.EndTextureMode()
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{22, 28, 24, 255})
	if ed.use_watercolor && app.pixel.id > 0 {
		draw_pixel_output()
		rl.BeginMode3D(ed.camera)
		editor_draw_overlays_3d()
		rl.EndMode3D()
	} else {
		rl.BeginMode3D(ed.camera)
		draw_editor_stage_3d()
		editor_draw_preview_mesh()
		editor_draw_overlays_3d()
		rl.EndMode3D()
	}
	editor_draw_overlays_2d()
	vui_render()
	rl.EndDrawing()
}

draw_editor_stage_3d :: proc() {
	minor := rl.Color{38, 48, 40, 160}
	major := rl.Color{56, 72, 58, 210}
	for i := -12; i <= 12; i += 1 {
		pos := f32(i) * 0.25
		is_major := (i % 4) == 0
		col := is_major ? major : minor
		if i != 0 {
			rl.DrawLine3D({-3.0, 0, pos}, {3.0, 0, pos}, col)
			rl.DrawLine3D({pos, 0, -3.0}, {pos, 0, 3.0}, col)
		}
	}
	// World axes on ground & 1x1 game tile footprint centered on origin.
	rl.DrawLine3D({-3.0, 0.001, 0}, {3.0, 0.001, 0}, rl.Color{165, 68, 68, 210})
	rl.DrawLine3D({0, 0.001, -3.0}, {0, 0.001, 3.0}, rl.Color{68, 128, 198, 210})
	rl.DrawLine3D({0, 0, 0}, {0, 2.2, 0}, rl.Color{74, 155, 84, 110})

	cell_col := rl.Color{110, 162, 98, 150}
	h := f32(0.5)
	rl.DrawLine3D({-h, 0.003, -h}, {h, 0.003, -h}, cell_col)
	rl.DrawLine3D({h, 0.003, -h}, {h, 0.003, h}, cell_col)
	rl.DrawLine3D({h, 0.003, h}, {-h, 0.003, h}, cell_col)
	rl.DrawLine3D({-h, 0.003, h}, {-h, 0.003, -h}, cell_col)

	// Show X-mirror centerline cue when symmetry is enabled.
	if app.editor.mirror_x {
		rl.DrawLine3D({0, 0.004, -2.5}, {0, 0.004, 2.5}, rl.Color{235, 195, 76, 175})
	}
}
