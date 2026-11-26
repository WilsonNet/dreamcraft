// Animation Picker navigation and Animation Editor studio orbital camera.
package main

import "core:math"
import rl "../gfx"
import art "./art"

anim_picker_filtered_indices :: proc(cat: int) -> ([]int, int) {
	out := make([]int, len(art.ANIM_CATALOG), context.temp_allocator)
	n := 0
	for entry, i in art.ANIM_CATALOG {
		match := cat == 0 ||
			(cat == 1 && entry.category == .Base) ||
			(cat == 2 && entry.category == .Hero) ||
			(cat == 3 && entry.category == .Enemy)
		if match {
			out[n] = i
			n += 1
		}
	}
	return out[:n], n
}

handle_anim_picker_input :: proc() {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.ESCAPE) {
		anim_editor_close_to_game()
		return
	}
	rows, count := anim_picker_filtered_indices(ed.picker_cat)
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
		idx := clamp(ed.picker_idx, 0, len(art.ANIM_CATALOG) - 1)
		_ = anim_editor_open_clip(art.ANIM_CATALOG[idx].id, false)
		return
	}
	if count == 0 {
		return
	}
	cur := 0
	for r, i in rows {
		if r == ed.picker_idx { cur = i; break }
	}
	if rl.IsKeyPressed(.DOWN) { cur = (cur + 1) % count }
	if rl.IsKeyPressed(.UP) { cur = (cur - 1 + count) % count }
	if rows[cur] != ed.picker_idx {
		ed.picker_idx = rows[cur]
		anim_editor_ensure_picker_preview(ed.picker_idx)
	}
}

handle_anim_picker_ui_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.anim_ed
	#partial switch msg {
	case .Anim_Picker_Tab:
		ed.picker_cat = int(arg)
		rows, count := anim_picker_filtered_indices(ed.picker_cat)
		if count > 0 {
			ed.picker_idx = rows[0]
			anim_editor_ensure_picker_preview(ed.picker_idx)
		}
	case .Anim_Picker_Row:
		ed.picker_idx = clamp(int(arg), 0, len(art.ANIM_CATALOG) - 1)
		anim_editor_ensure_picker_preview(ed.picker_idx)
	case .Anim_Picker_Back:
		anim_editor_close_to_game()
	case .Anim_Picker_Edit_Proc:
		idx := clamp(ed.picker_idx, 0, len(art.ANIM_CATALOG) - 1)
		_ = anim_editor_open_clip(art.ANIM_CATALOG[idx].id, true)
	case .Anim_Picker_Edit_Clip:
		idx := clamp(ed.picker_idx, 0, len(art.ANIM_CATALOG) - 1)
		_ = anim_editor_open_clip(art.ANIM_CATALOG[idx].id, false)
	}
}

anim_reset_camera :: proc(preset: Editor_View_Preset) {
	ed := &app.anim_ed
	ed.cam_target = {0, 0.88, 0}
	ed.cam_dist = 5.0
	ed.cam_fovy = 3.25
	switch preset {
	case .Iso:
		ed.cam_yaw = math.PI * 0.25
		ed.cam_pitch = 0.40
	case .Front:
		ed.cam_yaw = 0.0
		ed.cam_pitch = 0.02
	case .Right:
		ed.cam_yaw = math.PI * 0.5
		ed.cam_pitch = 0.02
	case .Top:
		ed.cam_yaw = 0.0
		ed.cam_pitch = 1.48
	}
	anim_apply_camera()
}

anim_apply_camera :: proc() {
	ed := &app.anim_ed
	cp := math.cos(ed.cam_pitch)
	sp := math.sin(ed.cam_pitch)
	cy := math.cos(ed.cam_yaw)
	sy := math.sin(ed.cam_yaw)
	dir := rl.Vector3{cp * sy, sp, cp * cy}
	tgt := rl.Vector3(ed.cam_target)
	ed.camera = rl.Camera3D{
		position   = tgt + dir * ed.cam_dist,
		target     = tgt,
		up         = {0, 1, 0},
		fovy       = ed.cam_ortho ? clamp(ed.cam_fovy, 0.25, 16.0) : 38.0,
		projection = ed.cam_ortho ? .ORTHOGRAPHIC : .PERSPECTIVE,
	}
	if !ed.cam_ortho {
		ed.cam_dist = clamp(ed.cam_fovy * 1.85, 0.8, 30.0)
		ed.camera.position = tgt + dir * ed.cam_dist
	}
}

anim_world_per_px :: proc() -> f32 {
	ed := &app.anim_ed
	h := max(f32(rl.GetScreenHeight()), f32(1))
	if ed.cam_ortho {
		return ed.cam_fovy / h
	}
	return 2.0 * ed.cam_dist * math.tan(ed.camera.fovy * 0.5 * math.PI / 180.0) / h
}

anim_update_camera_input :: proc(mouse: rl.Vector2, in_viewport: bool) {
	ed := &app.anim_ed
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	mmb_down := input_middle_down()
	alt_lmb := alt && input_left_down()
	rmb_orbit := rl.IsMouseButtonDown(.RIGHT) && !ed.modal_active

	if !ed.cam_orbit_drag && !ed.cam_pan_drag {
		if in_viewport && (mmb_down || alt_lmb || (rmb_orbit && rl.Vector2Distance(mouse, ed.rmb_down_pos) > 5)) {
			if shift && (mmb_down || alt_lmb) {
				ed.cam_pan_drag = true
			} else if mmb_down || alt_lmb || rmb_orbit {
				ed.cam_orbit_drag = true
				if rmb_orbit { ed.rmb_moved = true }
			}
			ed.cam_last_mouse = mouse
		}
	}
	if ed.cam_orbit_drag || ed.cam_pan_drag {
		if !(mmb_down || alt_lmb || rl.IsMouseButtonDown(.RIGHT)) {
			ed.cam_orbit_drag = false
			ed.cam_pan_drag = false
		} else {
			delta := mouse - ed.cam_last_mouse
			ed.cam_last_mouse = mouse
			if ed.cam_pan_drag {
				pan_anim_camera(delta)
			} else {
				ed.cam_yaw -= delta.x * 0.0085
				ed.cam_pitch = clamp(ed.cam_pitch + delta.y * 0.0085, -1.48, 1.48)
			}
		}
	}
	if in_viewport && !ed.modal_active {
		if wheel := input_wheel_y(); wheel != 0 {
			ed.cam_fovy = clamp(ed.cam_fovy * math.pow(f32(0.88), wheel), 0.28, 14.0)
		}
	}
	anim_apply_camera()
}

@(private)
pan_anim_camera :: proc(delta_px: rl.Vector2) {
	ed := &app.anim_ed
	h := max(f32(rl.GetScreenHeight()), f32(1))
	scale := ed.cam_fovy / h
	fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
	right := rl.Vector3Normalize(rl.Vector3CrossProduct(fwd, {0, 1, 0}))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, fwd))
	shift := -right * (delta_px.x * scale) + cam_up * (delta_px.y * scale)
	ed.cam_target = {ed.cam_target[0] + shift.x, ed.cam_target[1] + shift.y, ed.cam_target[2] + shift.z}
}
