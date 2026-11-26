// Animation Editor 3D bone/gizmo picking, timeline/curve input dispatch, and UI message handling.
package main

import "core:math"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import edit "./art/edit"

handle_anim_editor_input :: proc() {
	ed := &app.anim_ed
	mouse := input_mouse_pos()
	if rl.IsMouseButtonPressed(.RIGHT) {
		ed.rmb_down_pos = mouse
		ed.rmb_moved = false
	}
	vp := anim_editor_viewport_rect()
	in_tl := !ed.confirm_exit_open && rl.CheckCollisionPointRec(mouse, ed.timeline_rect)
	in_vp := !ed.confirm_exit_open && !in_tl && !ui_pointer_captured() && rl.CheckCollisionPointRec(mouse, vp)
	if !ed.modal_active && !ed.scrubbing && ed.drag_kf < 0 && ed.curve_drag == .None {
		anim_update_camera_input(mouse, in_vp)
	}
	update_anim_hover(mouse, in_vp, in_tl)

	if ed.confirm_exit_open {
		handle_anim_editor_hotkeys()
		return
	}
	if ed.modal_active {
		update_anim_active_modal(mouse)
		return
	}
	if ed.vp_box_pending || ed.vp_box_active {
		if update_anim_vp_box(mouse) { return }
	}
	if ed.dock_tab == .Curves {
		if handle_anim_curves_input(mouse, in_tl) { return }
	} else {
		if handle_anim_timeline_input(mouse, in_tl) { return }
	}
	if input_left_pressed() && in_vp {
		handle_anim_viewport_left_press(mouse)
	}
	if !input_left_down() {
		ed.slider_undo_armed = false
	}
	handle_anim_editor_hotkeys()
}

@(private)
update_anim_hover :: proc(mouse: rl.Vector2, in_vp, in_tl: bool) {
	ed := &app.anim_ed
	ed.gizmo_hover = -1
	ed.hover_ctrl = -1
	ed.hover_bone = -1
	ed.hover_kf = -1
	ed.curve_hover_kind = .None
	ed.curve_hover_kf = -1
	if in_tl && ed.clip_loaded {
		if ed.dock_tab == .Curves {
			update_anim_curves_hover(mouse)
		} else {
			ed.hover_kf = anim_pick_timeline_kf(mouse)
		}
		return
	}
	if !in_vp || !ed.clip_loaded || ed.cam_orbit_drag || ed.cam_pan_drag {
		return
	}
	if anim_is_rig_active() {
		if ed.gizmo_drag_axis < 0 {
			ed.gizmo_hover, _ = anim_ctrl_gizmo_hit_test(mouse)
		}
		if c, ok := anim_pick_ctrl(mouse); ok {
			ed.hover_ctrl = int(c)
		}
	} else if ed.gizmo_drag_axis < 0 {
		ed.gizmo_hover = anim_gizmo_hit_test(mouse)
	}
	if ed.rig_mode != .Rig && ed.hover_ctrl < 0 {
		if b, ok := anim_pick_bone(mouse); ok {
			ed.hover_bone = int(b)
		}
	}
}

@(private)
update_anim_vp_box :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.anim_ed
	if !input_left_down() {
		if ed.vp_box_active {
			anim_vp_box_select(anim_editor_box_rect_2d(ed.vp_box_start, mouse), ed.vp_box_shift)
		}
		ed.vp_box_pending = false
		ed.vp_box_active = false
		return true
	}
	d := mouse - ed.vp_box_start
	if !ed.vp_box_active && (d.x * d.x + d.y * d.y) > 25.0 {
		ed.vp_box_active = true
	}
	return true
}

@(private)
handle_anim_viewport_left_press :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if anim_is_rig_active() {
		if ax, is_rot := anim_ctrl_gizmo_hit_test(mouse); ax >= 0 {
			lock := ax == 0 ? edit.Axis_Lock.X : (ax == 1 ? edit.Axis_Lock.Y : edit.Axis_Lock.Z)
			anim_start_ctrl_modal(is_rot ? .Rotate : .Move_Root, lock, mouse)
			return
		}
		if c, ok := anim_pick_ctrl(mouse); ok {
			if shift { anim_toggle_ctrl_select(c) } else { anim_select_ctrl_only(c) }
			def := art_rig.CONTROLS[c]
			if ed.tool == .Rotate && def.can_rotate {
				anim_start_ctrl_modal(.Rotate, .None, mouse)
			} else if ed.tool == .Move_Root && def.can_move {
				anim_start_ctrl_modal(.Move_Root, .None, mouse)
			}
			return
		}
	} else if ax := anim_gizmo_hit_test(mouse); ax >= 0 {
		lock := ax == 0 ? edit.Axis_Lock.X : (ax == 1 ? edit.Axis_Lock.Y : edit.Axis_Lock.Z)
		op: Anim_Tool = ed.tool == .Move_Root ? .Move_Root : .Rotate
		anim_start_modal(op, lock, mouse)
		return
	}
	if ed.rig_mode != .Rig {
		if b, ok := anim_pick_bone(mouse); ok {
			if shift { anim_toggle_bone_select(b) } else { anim_select_bone_only(b) }
			if ed.tool == .Rotate { anim_start_modal(.Rotate, .None, mouse) }
			return
		}
	}
	ed.vp_box_pending = true
	ed.vp_box_start = mouse
	ed.vp_box_shift = shift
}

anim_gizmo_hit_test :: proc(mouse: rl.Vector2) -> int {
	ed := &app.anim_ed
	if ed.tool == .Move_Root {
		root_p := anim_bone_posed_head(&ed.pose_mats, .Root)
		o2d := rl.GetWorldToScreen(root_p, ed.camera)
		wlen := anim_world_per_px() * 72.0
		best := -1
		best_d2 := f32(144.0)
		for axis in 0 ..< 3 {
			t2d := rl.GetWorldToScreen(root_p + GIZMO_AXES[axis] * wlen, ed.camera)
			d2, t := seg_dist_sq_2d(mouse, o2d, t2d)
			if t >= 0.14 && d2 < best_d2 {
				best_d2 = d2
				best = axis
			}
		}
		return best
	}
	pivot := anim_bone_posed_head(&ed.pose_mats, ed.selected_bone)
	radius := anim_world_per_px() * 54.0
	best := -1
	best_d2 := f32(100.0)
	for axis in 0 ..< 3 {
		for s in 0 ..< GIZMO_RING_SEGS {
			a0 := f32(s) * math.TAU / f32(GIZMO_RING_SEGS)
			a1 := f32(s + 1) * math.TAU / f32(GIZMO_RING_SEGS)
			s0 := rl.GetWorldToScreen(pivot + gizmo_ring_dir(axis, a0) * radius, ed.camera)
			s1 := rl.GetWorldToScreen(pivot + gizmo_ring_dir(axis, a1) * radius, ed.camera)
			d2, _ := seg_dist_sq_2d(mouse, s0, s1)
			if d2 < best_d2 {
				best_d2 = d2
				best = axis
			}
		}
	}
	return best
}

anim_pick_bone :: proc(mouse: rl.Vector2) -> (art.Bone_Id, bool) {
	ed := &app.anim_ed
	best := -1
	best_d2 := f32(196.0)
	for i in 0 ..< art.BONE_COUNT {
		b := art.Bone_Id(i)
		sp := rl.GetWorldToScreen(anim_bone_posed_head(&ed.pose_mats, b), ed.camera)
		d := sp - mouse
		d2 := d.x * d.x + d.y * d.y
		if d2 < best_d2 {
			best_d2 = d2
			best = i
		}
		if !art.BONES[b].root {
			ps := rl.GetWorldToScreen(anim_bone_posed_head(&ed.pose_mats, art.BONES[b].parent), ed.camera)
			sd2, _ := seg_dist_sq_2d(mouse, ps, sp)
			if sd2 < min(best_d2, 100.0) {
				best_d2 = sd2
				best = i
			}
		}
	}
	if best < 0 {
		return .Root, false
	}
	return art.Bone_Id(best), true
}

@(private)
anim_timeline_x_to_t :: proc(r: rl.Rectangle, x: f32) -> f32 {
	if r.width <= 1 { return 0 }
	return clamp((x - r.x) / r.width, 0, 1)
}

@(private)
anim_pick_timeline_kf :: proc(mouse: rl.Vector2) -> int {
	ed := &app.anim_ed
	r := ed.timeline_rect
	if r.width <= 1 || len(ed.clip.keyframes) == 0 {
		return -1
	}
	best := -1
	best_dx := f32(10.0)
	for kf, i in ed.clip.keyframes {
		dx := abs(mouse.x - (r.x + kf.time * r.width))
		if dx < best_dx {
			best_dx = dx
			best = i
		}
	}
	return best
}

@(private)
handle_anim_timeline_input :: proc(mouse: rl.Vector2, in_tl: bool) -> bool {
	ed := &app.anim_ed
	if ed.curve_scale_active { return handle_curve_scale_modal(mouse) }
	if ed.curve_box_active {
		if !input_left_down() {
			anim_dopesheet_box_select(ed.curve_box_start.x, mouse.x, ed.timeline_rect, ed.curve_box_shift)
			ed.curve_box_active = false
		}
		return true
	}
	if input_left_pressed() && in_tl && ed.clip_loaded {
		return start_dopesheet_press(mouse)
	}
	if ed.drag_kf >= 0 {
		if !input_left_down() { ed.drag_kf = -1; ed.drag_kf_undo = false; return true }
		t := anim_timeline_x_to_t(ed.timeline_rect, mouse.x)
		dt := t - ed.curve_drag_base_t
		if abs(t - ed.clip.keyframes[ed.drag_kf].time) > 0.002 {
			if !ed.drag_kf_undo {
				anim_edit.anim_undo_push(&ed.undo, &ed.clip)
				ed.drag_kf_undo = true
			}
			anim_move_selected_kfs_dt(dt, 0, ed.curve_active_axis, true)
			ed.playhead = ed.clip.keyframes[ed.drag_kf].time
		}
		return true
	}
	if ed.scrubbing {
		if !input_left_down() { ed.scrubbing = false; return true }
		ed.playhead = anim_timeline_x_to_t(ed.timeline_rect, mouse.x)
		return true
	}
	return false
}

@(private)
start_dopesheet_press :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.anim_ed
	ed.playing = false
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if kf_idx := anim_pick_timeline_kf(mouse); kf_idx >= 0 {
		if shift { anim_toggle_kf_select(kf_idx); return true }
		if !anim_is_kf_selected(kf_idx) { anim_select_kf_only(kf_idx) }
		ed.selected_kf = kf_idx
		ed.drag_kf = kf_idx
		ed.drag_kf_undo = false
		ed.curve_drag_base_t = ed.clip.keyframes[kf_idx].time
		anim_capture_kf_drag_bases()
		ed.playhead = ed.clip.keyframes[kf_idx].time
	} else if mouse.y <= ed.timeline_rect.y + 20 {
		ed.scrubbing = true
		ed.playhead = anim_timeline_x_to_t(ed.timeline_rect, mouse.x)
	} else {
		ed.curve_box_active = true
		ed.curve_box_start = mouse
		ed.curve_box_shift = shift
	}
	return true
}

anim_editor_update_cursor :: proc() {
	ed := &app.anim_ed
	next := rl.MouseCursor.DEFAULT
	if ed.confirm_exit_open || (ui_pointer_captured() && !rl.CheckCollisionPointRec(input_mouse_pos(), ed.timeline_rect)) {
		next = .DEFAULT
	} else if ed.cam_orbit_drag || ed.cam_pan_drag || ed.curve_drag == .Pan {
		next = .RESIZE_ALL
	} else if ed.gizmo_hover >= 0 || ed.hover_ctrl >= 0 || ed.hover_bone >= 0 || ed.hover_kf >= 0 || ed.curve_hover_kind != .None || ed.curve_drag != .None {
		next = .POINTING_HAND
	}
	if !app.cursor_initialized || next != app.last_cursor {
		rl.SetMouseCursor(next)
		app.last_cursor = next
		app.cursor_initialized = true
	}
}

anim_ensure_editable_kf :: proc() -> ^anim_edit.Edit_Keyframe {
	ed := &app.anim_ed
	if len(ed.clip.keyframes) == 0 {
		rot, root_off := anim_edit.eval_edit_clip(&ed.clip, ed.playhead)
		ed.selected_kf = anim_edit.clip_insert_or_update_keyframe(&ed.clip, ed.playhead, rot, root_off, .Smooth)
		return &ed.clip.keyframes[ed.selected_kf]
	}
	if idx, ok := anim_edit.clip_find_keyframe_near(&ed.clip, ed.playhead); ok {
		ed.selected_kf = idx
		return &ed.clip.keyframes[idx]
	}
	if ed.auto_key {
		rot, root_off := anim_edit.eval_edit_clip(&ed.clip, ed.playhead)
		idx := anim_edit.clip_insert_or_update_keyframe(&ed.clip, ed.playhead, rot, root_off, .Smooth)
		ed.selected_kf = idx
		return &ed.clip.keyframes[idx]
	}
	ed.selected_kf = clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
	return &ed.clip.keyframes[ed.selected_kf]
}
