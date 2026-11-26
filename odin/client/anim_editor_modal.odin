// Animation Editor Blender-style modal bone rotation, root offset move, keyframe actions, and hotkeys.
package main

import "core:fmt"
import "core:math"
import "core:strconv"
import rl "../gfx"
import anim_edit "./art/anim_edit"
import edit "./art/edit"
import spec "./art/spec"

anim_editor_modal_status_text :: proc() -> cstring {
	ed := &app.anim_ed
	if !ed.modal_active {
		return ""
	}
	num := ed.num_len > 0 ? string(ed.num_buf[:ed.num_len]) : ""
	axis := ed.axis_lock != .None ? fmt.tprintf(" [%v]", ed.axis_lock) : ""
	if ed.modal_op == .Rotate {
		bname := spec.BONE_NAMES[ed.selected_bone]
		return cstring_t(fmt.tprintf("Rotate %s%s %.1f deg %s | X/Y/Z axis, LMB/Enter confirm, RMB/Esc cancel", bname, axis, ed.modal_angle * 57.2958, num))
	}
	return cstring_t(fmt.tprintf("Move Root%s (%.3f %.3f %.3f) %s | X/Y/Z axis, LMB/Enter confirm, RMB/Esc cancel", axis, ed.modal_delta[0], ed.modal_delta[1], ed.modal_delta[2], num))
}

handle_anim_editor_hotkeys :: proc() {
	ed := &app.anim_ed
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) || rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)

	if rl.IsKeyPressed(.ESCAPE) {
		if ed.confirm_exit_open {
			ed.confirm_exit_open = false
		} else if ed.clip.dirty {
			ed.confirm_exit_open = true
		} else {
			anim_editor_close_to_game()
		}
		return
	}
	if ed.confirm_exit_open {
		return
	}
	if ctrl && rl.IsKeyPressed(.S) {
		_ = anim_editor_save_and_hot_reload()
		return
	}
	if ctrl && shift && rl.IsKeyPressed(.Z) {
		if anim_edit.anim_redo_step(&ed.undo, &ed.clip) {
			anim_clamp_selected_kf()
			anim_editor_set_status("Redo", false, 1.4)
		}
		return
	}
	if ctrl && rl.IsKeyPressed(.Z) {
		if anim_edit.anim_undo_step(&ed.undo, &ed.clip) {
			anim_clamp_selected_kf()
			anim_editor_set_status("Undo", false, 1.4)
		}
		return
	}
	if alt && rl.IsKeyPressed(.R) {
		anim_exec_zero_bone()
		return
	}
	handle_anim_plain_keys(input_mouse_pos())
}

@(private)
handle_anim_plain_keys :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.SPACE) { ed.playing = !ed.playing; return }
	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.COMMA) { anim_jump_keyframe(-1); return }
	if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.PERIOD) { anim_jump_keyframe(1); return }
	if rl.IsKeyPressed(.I) { anim_exec_add_keyframe(); return }
	if rl.IsKeyPressed(.X) || rl.IsKeyPressed(.DELETE) { anim_exec_del_keyframe(); return }
	if rl.IsKeyPressed(.R) { anim_start_modal(.Rotate, .None, mouse); return }
	if rl.IsKeyPressed(.G) { anim_start_modal(.Move_Root, .None, mouse); return }
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
	ed.modal_base_rot = kf.rot[int(ed.selected_bone)]
	ed.modal_base_root = kf.root_offset
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
	apply_anim_modal_edit(mouse)

	confirm := rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) ||
		(ed.gizmo_drag_axis >= 0 ? input_left_released() : input_left_pressed())
	if confirm {
		ed.modal_active = false
		ed.gizmo_drag_axis = -1
		ed.tool = .Select
		ed.clip.dirty = true
	}
}

@(private)
cancel_anim_modal :: proc() {
	ed := &app.anim_ed
	_ = anim_edit.anim_undo_step(&ed.undo, &ed.clip)
	anim_clamp_selected_kf()
	ed.modal_active = false
	ed.gizmo_drag_axis = -1
	ed.tool = .Select
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
		ang := has_num ? num_val * math.PI / 180.0 : dpx.x * 0.012
		if ctrl { ang = math.round(ang / (5.0 * math.PI / 180.0)) * (5.0 * math.PI / 180.0) }
		ed.modal_angle = ang
		axis_idx := ed.axis_lock == .Y ? 1 : (ed.axis_lock == .Z ? 2 : 0)
		rot := ed.modal_base_rot
		rot[axis_idx] = clamp(rot[axis_idx] + ang, -math.PI, math.PI)
		anim_edit.clip_set_bone_rot(kf, ed.selected_bone, rot, ed.mirror_lr)
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

anim_clamp_selected_kf :: proc() {
	ed := &app.anim_ed
	if len(ed.clip.keyframes) == 0 {
		ed.selected_kf = 0
		return
	}
	ed.selected_kf = clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
}

anim_jump_keyframe :: proc(dir: int) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if n == 0 { return }
	ed.playing = false
	ed.selected_kf = (ed.selected_kf + dir + n) % n
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
}

anim_exec_zero_bone :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	anim_edit.clip_zero_bone(kf, ed.selected_bone, ed.mirror_lr)
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
	anim_editor_set_status(fmt.tprintf("Zeroed %s", spec.BONE_NAMES[ed.selected_bone]), false, 1.6)
}

anim_exec_flip_lr :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	anim_edit.clip_flip_pose_lr(kf)
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
	anim_editor_set_status("Flipped pose L <-> R", false, 1.8)
}

anim_exec_add_keyframe :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	rot, root_off := anim_edit.eval_edit_clip(&ed.clip, ed.playhead)
	interp := len(ed.clip.keyframes) > 0 ? ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)].interp : spec.Anim_Interp.Smooth
	ed.selected_kf = anim_edit.clip_insert_or_update_keyframe(&ed.clip, ed.playhead, rot, root_off, interp)
	anim_editor_set_status(fmt.tprintf("Keyframed t=%.2f", ed.playhead), false, 1.6)
}

anim_exec_dup_keyframe :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	src_t := ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)].time
	new_t := clamp(src_t + 0.08 <= 1.0 ? src_t + 0.08 : src_t - 0.08, 0, 1)
	ed.selected_kf = anim_edit.clip_duplicate_keyframe(&ed.clip, ed.selected_kf, new_t)
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
	anim_editor_set_status("Duplicated keyframe", false, 1.6)
}

anim_exec_del_keyframe :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) <= 1 {
		anim_editor_set_status("Clip must keep at least 1 keyframe", true, 2.0)
		return
	}
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	if anim_edit.clip_delete_keyframe(&ed.clip, ed.selected_kf) {
		anim_clamp_selected_kf()
		anim_editor_set_status("Deleted keyframe", false, 1.6)
	}
}

anim_exec_copy_pose :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	ed.copied_pose = ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]
	ed.has_copied_pose = true
	anim_editor_set_status("Copied keyframe pose", false, 1.5)
}

anim_exec_paste_pose :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || !ed.has_copied_pose {
		anim_editor_set_status("Copy a pose first", true, 1.8)
		return
	}
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	kf.rot = ed.copied_pose.rot
	kf.root_offset = ed.copied_pose.root_offset
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
	anim_editor_set_status("Pasted pose", false, 1.5)
}

anim_exec_set_interp :: proc(interp: spec.Anim_Interp) {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]
	kf.interp = interp
	ed.clip.dirty = true
}

anim_cycle_handle_type :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	ki := clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
	cur, _, _ := anim_edit.channel_get_handles(&ed.clip.keyframes[ki], ed.curve_is_root, ed.selected_bone, ed.curve_active_axis)
	next := spec.Anim_Handle((int(cur) + 1) % 5)
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	anim_edit.set_channel_handle_type(&ed.clip, ki, ed.curve_is_root, ed.selected_bone, ed.curve_active_axis, next)
	anim_editor_set_status(fmt.tprintf("Handle: %s", spec.HANDLE_NAMES[next]), false, 1.5)
}

anim_cycle_interp :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	ki := clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
	order := [5]spec.Anim_Interp{.Smooth, .Linear, .Step, .Ease_In, .Ease_Out}
	cur := ed.clip.keyframes[ki].interp
	idx := 0
	for o, i in order {
		if o == cur { idx = (i + 1) % 5; break }
	}
	anim_exec_set_interp(order[idx])
	anim_editor_set_status(fmt.tprintf("Interp: %s", spec.INTERP_NAMES[order[idx]]), false, 1.5)
}
