// Animation Editor Blender-style modal bone rotation, root offset move, keyframe actions, and hotkeys.
package main

import "core:fmt"
import "core:math"
import "core:strconv"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import edit "./art/edit"
import spec "./art/spec"

anim_editor_modal_status_text :: proc() -> cstring {
	ed := &app.anim_ed
	if !ed.modal_active {
		return ""
	}
	num := ed.num_len > 0 ? string(ed.num_buf[:ed.num_len]) : ""
	axis := ed.axis_lock != .None ? fmt.tprintf(" [%v]", ed.axis_lock) : ""
	if ed.modal_is_ctrl {
		cname := ed.selected_ctrl != .COUNT ? art_rig.CONTROLS[ed.selected_ctrl].name : "Ctrl"
		cnt := anim_selected_ctrl_count()
		extra := cnt > 1 ? fmt.tprintf(" (+%d)", cnt - 1) : ""
		if ed.modal_op == .Rotate {
			return cstring_t(fmt.tprintf("Rotate %s%s%s %.1f deg %s | X/Y/Z, LMB/Enter, RMB/Esc", cname, extra, axis, ed.modal_angle * 57.2958, num))
		}
		return cstring_t(fmt.tprintf("Move %s%s%s (%.2f %.2f %.2f) %s | X/Y/Z, LMB/Enter, RMB/Esc", cname, extra, axis, ed.modal_delta[0], ed.modal_delta[1], ed.modal_delta[2], num))
	}
	if ed.modal_op == .Rotate {
		bname := spec.BONE_NAMES[ed.selected_bone]
		cnt := anim_selected_bone_count()
		extra := cnt > 1 ? fmt.tprintf(" (+%d)", cnt - 1) : ""
		return cstring_t(fmt.tprintf("Rotate %s%s%s %.1f deg %s | X/Y/Z axis, LMB/Enter confirm, RMB/Esc cancel", bname, extra, axis, ed.modal_angle * 57.2958, num))
	}
	return cstring_t(fmt.tprintf("Move Root%s (%.3f %.3f %.3f) %s | X/Y/Z axis, LMB/Enter confirm, RMB/Esc cancel", axis, ed.modal_delta[0], ed.modal_delta[1], ed.modal_delta[2], num))
}

handle_anim_editor_hotkeys :: proc() {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.ESCAPE) {
		if ed.confirm_exit_open { ed.confirm_exit_open = false } else if ed.clip.dirty { ed.confirm_exit_open = true } else { anim_editor_close_to_game() }
		return
	}
	if ed.confirm_exit_open { return }
	if handle_anim_mod_hotkeys() { return }
	handle_anim_plain_keys(input_mouse_pos())
}

@(private)
handle_anim_mod_hotkeys :: proc() -> bool {
	ed := &app.anim_ed
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) || rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	if ctrl && rl.IsKeyPressed(.S) { _ = anim_editor_save_and_hot_reload(); return true }
	if ctrl && shift && rl.IsKeyPressed(.Z) {
		if anim_edit.anim_redo_step(&ed.undo, &ed.clip) { anim_sync_kf_selection(); anim_clamp_selected_kf(); anim_editor_set_status("Redo", false, 1.4) }
		return true
	}
	if ctrl && rl.IsKeyPressed(.Z) {
		if anim_edit.anim_undo_step(&ed.undo, &ed.clip) { anim_sync_kf_selection(); anim_clamp_selected_kf(); anim_editor_set_status("Undo", false, 1.4) }
		return true
	}
	if alt && rl.IsKeyPressed(.A) {
		if rl.CheckCollisionPointRec(input_mouse_pos(), ed.timeline_rect) { anim_select_kf_only(ed.selected_kf) } else if anim_is_rig_active() { anim_select_ctrl_only(ed.selected_ctrl) } else { anim_select_bone_only(ed.selected_bone) }
		return true
	}
	if alt && rl.IsKeyPressed(.R) { anim_exec_zero_bone(); return true }
	return false
}

@(private)
anim_ctrl_has_rotatable :: proc() -> bool {
	ed := &app.anim_ed
	for i in 0 ..< art_rig.CTRL_COUNT {
		if ed.selected_ctrls[i] && art_rig.CONTROLS[art_rig.Control_Id(i)].can_rotate { return true }
	}
	return false
}

@(private)
anim_ctrl_has_movable :: proc() -> bool {
	ed := &app.anim_ed
	for i in 0 ..< art_rig.CTRL_COUNT {
		if ed.selected_ctrls[i] && art_rig.CONTROLS[art_rig.Control_Id(i)].can_move { return true }
	}
	return false
}

@(private)
handle_anim_plain_keys :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	in_tl := rl.CheckCollisionPointRec(mouse, ed.timeline_rect)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if rl.IsKeyPressed(.SPACE) { ed.playing = !ed.playing; return }
	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.COMMA) { anim_jump_keyframe(-1); return }
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.PERIOD) { anim_jump_keyframe(1); return }
	if rl.IsKeyPressed(.A) {
		if in_tl { anim_select_all_kfs(true) } else if anim_is_rig_active() { anim_select_all_ctrls() } else { anim_select_all_bones() }
		return
	}
	if rl.IsKeyPressed(.L) {
		if ed.rig_mode == .Rig { ed.rig_mode = .Both }
		anim_select_bone_chain(ed.selected_bone, shift)
		return
	}
	if rl.IsKeyPressed(.I) { anim_exec_add_keyframe(); return }
	if rl.IsKeyPressed(.X) || rl.IsKeyPressed(.DELETE) { anim_exec_del_keyframe(); return }
	if rl.IsKeyPressed(.R) {
		if anim_is_rig_active() && anim_ctrl_has_rotatable() { anim_start_ctrl_modal(.Rotate, .None, mouse) } else { anim_start_modal(.Rotate, .None, mouse) }
		return
	}
	if rl.IsKeyPressed(.G) {
		if anim_is_rig_active() && anim_ctrl_has_movable() { anim_start_ctrl_modal(.Move_Root, .None, mouse) } else { anim_start_modal(.Move_Root, .None, mouse) }
		return
	}
	if rl.IsKeyPressed(.S) && in_tl && ed.clip_loaded && len(ed.clip.keyframes) > 0 {
		ed.curve_scale_active = true
		ed.curve_scale_start_x = mouse.x
		anim_capture_kf_drag_bases()
		anim_edit.anim_undo_push(&ed.undo, &ed.clip)
		return
	}
	if rl.IsKeyPressed(.V) { anim_cycle_handle_type(); return }
	if rl.IsKeyPressed(.T) { anim_cycle_interp(); return }
	if rl.IsKeyPressed(.HOME) { anim_curves_fit_view(); return }
	if rl.IsKeyPressed(.KP_1) { anim_reset_camera(.Front) }
	if rl.IsKeyPressed(.KP_3) { anim_reset_camera(.Right) }
	if rl.IsKeyPressed(.KP_7) { anim_reset_camera(.Top) }
	if rl.IsKeyPressed(.KP_5) || rl.IsKeyPressed(.O) {
		ed.cam_ortho = !ed.cam_ortho
		anim_apply_camera()
	}
}

anim_start_modal :: proc(op: Anim_Tool, lock: edit.Axis_Lock, mouse: rl.Vector2) {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return
	}
	ed.playing = false
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	ed.modal_is_ctrl = false
	ed.modal_base_rot = kf.rot[int(ed.selected_bone)]
	ed.modal_base_all_rot = kf.rot
	ed.modal_base_root = kf.root_offset
	ed.modal_restore_tool = ed.tool
	ed.tool = op
	ed.modal_active = true
	ed.modal_op = op
	ed.axis_lock = lock
	ed.modal_start_mouse = mouse
	ed.modal_angle = 0
	ed.modal_delta = {}
	ed.num_len = 0
	ed.gizmo_drag_axis = lock == .X ? 0 : (lock == .Y ? 1 : (lock == .Z ? 2 : -1))
}

update_anim_active_modal :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.ESCAPE) || rl.IsMouseButtonPressed(.RIGHT) {
		cancel_anim_modal()
		return
	}
	handle_anim_axis_keys()
	handle_anim_numeric_keys()
	if ed.modal_is_ctrl {
		apply_anim_ctrl_modal(mouse)
	} else {
		apply_anim_modal_edit(mouse)
	}

	confirm := rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) ||
		(ed.gizmo_drag_axis >= 0 ? input_left_released() : input_left_pressed())
	if confirm {
		ed.modal_active = false
		ed.modal_is_ctrl = false
		ed.gizmo_drag_axis = -1
		ed.tool = ed.modal_restore_tool
		ed.clip.dirty = true
	}
}

@(private)
cancel_anim_modal :: proc() {
	ed := &app.anim_ed
	_ = anim_edit.anim_undo_step(&ed.undo, &ed.clip)
	anim_sync_kf_selection()
	anim_clamp_selected_kf()
	ed.modal_active = false
	ed.modal_is_ctrl = false
	ed.gizmo_drag_axis = -1
	ed.tool = ed.modal_restore_tool
}

@(private)
handle_anim_axis_keys :: proc() {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.X) { ed.axis_lock = ed.axis_lock == .X ? .None : .X }
	if rl.IsKeyPressed(.Y) { ed.axis_lock = ed.axis_lock == .Y ? .None : .Y }
	if rl.IsKeyPressed(.Z) { ed.axis_lock = ed.axis_lock == .Z ? .None : .Z }
}

@(private)
handle_anim_numeric_keys :: proc() {
	ed := &app.anim_ed
	for {
		ch := rl.GetCharPressed()
		if ch == 0 { break }
		valid := (ch >= '0' && ch <= '9') || ch == '.' || ch == '-'
		if valid && ed.num_len < len(ed.num_buf) - 1 {
			ed.num_buf[ed.num_len] = u8(ch)
			ed.num_len += 1
		}
	}
	if rl.IsKeyPressed(.BACKSPACE) && ed.num_len > 0 {
		ed.num_len -= 1
	}
}

@(private)
apply_anim_modal_edit :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	num_val, has_num := parse_anim_modal_number()
	dpx := mouse - ed.modal_start_mouse
	kf := &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]

	if ed.modal_op == .Rotate {
		axis_idx := ed.axis_lock == .Y ? 1 : (ed.axis_lock == .Z ? 2 : 0)
		pivot := anim_bone_posed_head(&ed.pose_mats, ed.selected_bone)
		ang := compute_anim_rotate_angle(pivot, axis_idx, mouse, has_num, num_val, ctrl)
		ed.modal_angle = ang
		for bi in 0 ..< art.BONE_COUNT {
			if !ed.selected_bones[bi] { continue }
			rot := ed.modal_base_all_rot[bi]
			rot[axis_idx] = clamp(rot[axis_idx] + ang, -math.PI, math.PI)
			anim_edit.clip_set_bone_rot(kf, art.Bone_Id(bi), rot, ed.mirror_lr)
		}
		anim_edit.recompute_clip_handles(&ed.clip)
		ed.clip.dirty = true
		return
	}
	delta := compute_anim_root_delta(dpx, has_num, num_val, ctrl)
	ed.modal_delta = delta
	kf.root_offset = {
		clamp(ed.modal_base_root[0] + delta[0], -1.0, 1.0),
		clamp(ed.modal_base_root[1] + delta[1], -1.0, 1.0),
		clamp(ed.modal_base_root[2] + delta[2], -1.0, 1.0),
	}
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
}

// Computes signed rotation angle from ring circular drag, edge-on tangent drag, or numeric deg.
compute_anim_rotate_angle :: proc(pivot: rl.Vector3, axis_idx: int, mouse: rl.Vector2, has_num: bool, num_val: f32, ctrl: bool) -> f32 {
	ed := &app.anim_ed
	ang: f32
	if has_num {
		ang = num_val * math.PI / 180.0
	} else if ed.gizmo_drag_axis >= 0 {
		p2 := rl.GetWorldToScreen(pivot, ed.camera)
		cam_fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
		axis_v := GIZMO_AXES[axis_idx]
		facing := rl.Vector3DotProduct(axis_v, cam_fwd)
		v0 := ed.modal_start_mouse - p2
		v1 := mouse - p2
		if abs(facing) > 0.28 && (v0.x * v0.x + v0.y * v0.y) > 64.0 && (v1.x * v1.x + v1.y * v1.y) > 64.0 {
			raw := math.atan2(v0.x * v1.y - v0.y * v1.x, v0.x * v1.x + v0.y * v1.y)
			ang = facing < 0 ? -raw : raw
		} else {
			a2 := rl.GetWorldToScreen(pivot + axis_v * 0.25, ed.camera) - p2
			alen := math.sqrt(a2.x * a2.x + a2.y * a2.y)
			t2 := alen > 1e-3 ? rl.Vector2{-a2.y / alen, a2.x / alen} : rl.Vector2{1, 0}
			d := mouse - ed.modal_start_mouse
			ang = (d.x * t2.x + d.y * t2.y) * 0.015
		}
	} else {
		ang = (mouse.x - ed.modal_start_mouse.x) * 0.012
	}
	if ctrl { ang = math.round(ang / (5.0 * math.PI / 180.0)) * (5.0 * math.PI / 180.0) }
	return ang
}

@(private)
compute_anim_root_delta :: proc(dpx: rl.Vector2, has_num: bool, num_val: f32, ctrl: bool) -> [3]f32 {
	ed := &app.anim_ed
	if has_num {
		v := ctrl ? math.round(num_val * 50.0) * 0.02 : num_val
		#partial switch ed.axis_lock {
		case .Y: return {0, v, 0}
		case .Z: return {0, 0, v}
		case:    return {v, 0, 0}
		}
	}
	wpp := anim_world_per_px()
	fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
	right := rl.Vector3Normalize(rl.Vector3CrossProduct(fwd, {0, 1, 0}))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, fwd))
	d := right * (dpx.x * wpp) - cam_up * (dpx.y * wpp)
	out := [3]f32{d.x, d.y, d.z}
	if ed.axis_lock == .X { out = {d.x, 0, 0} }
	if ed.axis_lock == .Y { out = {0, d.y, 0} }
	if ed.axis_lock == .Z { out = {0, 0, d.z} }
	if ctrl {
		out = {math.round(out[0] * 50.0) * 0.02, math.round(out[1] * 50.0) * 0.02, math.round(out[2] * 50.0) * 0.02}
	}
	return out
}

@(private)
parse_anim_modal_number :: proc() -> (f32, bool) {
	ed := &app.anim_ed
	if ed.num_len == 0 { return 0, false }
	val, ok := strconv.parse_f32(string(ed.num_buf[:ed.num_len]))
	return val, ok
}
