// Animation Editor 3D bone/gizmo picking, timeline/curve input dispatch, and UI message handling.
package main

import "core:math"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"
import edit "./art/edit"
import spec "./art/spec"

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
	if ed.gizmo_drag_axis < 0 {
		ed.gizmo_hover = anim_gizmo_hit_test(mouse)
	}
	if b, ok := anim_pick_bone(mouse); ok {
		ed.hover_bone = int(b)
	}
}

@(private)
handle_anim_viewport_left_press :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	if axis := anim_gizmo_hit_test(mouse); axis >= 0 {
		lock := axis == 0 ? edit.Axis_Lock.X : (axis == 1 ? edit.Axis_Lock.Y : edit.Axis_Lock.Z)
		op: Anim_Tool = ed.tool == .Move_Root ? .Move_Root : .Rotate
		anim_start_modal(op, lock, mouse)
		return
	}
	if b, ok := anim_pick_bone(mouse); ok {
		ed.selected_bone = b
		ed.curve_is_root = b == .Root
		anim_curves_fit_view()
		if ed.tool == .Rotate {
			anim_start_modal(.Rotate, .None, mouse)
		}
	}
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
	if input_left_pressed() && in_tl && ed.clip_loaded {
		ed.playing = false
		if kf_idx := anim_pick_timeline_kf(mouse); kf_idx >= 0 {
			ed.selected_kf = kf_idx
			ed.drag_kf = kf_idx
			ed.drag_kf_undo = false
			ed.playhead = ed.clip.keyframes[kf_idx].time
		} else {
			ed.scrubbing = true
			ed.playhead = anim_timeline_x_to_t(ed.timeline_rect, mouse.x)
		}
		return true
	}
	if ed.drag_kf >= 0 {
		if !input_left_down() {
			ed.drag_kf = -1
			ed.drag_kf_undo = false
			return true
		}
		t := anim_timeline_x_to_t(ed.timeline_rect, mouse.x)
		if abs(t - ed.clip.keyframes[ed.drag_kf].time) > 0.002 {
			if !ed.drag_kf_undo {
				anim_edit.anim_undo_push(&ed.undo, &ed.clip)
				ed.drag_kf_undo = true
			}
			ed.drag_kf = anim_edit.clip_move_keyframe(&ed.clip, ed.drag_kf, t)
			ed.selected_kf = ed.drag_kf
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

anim_editor_update_cursor :: proc() {
	ed := &app.anim_ed
	next := rl.MouseCursor.DEFAULT
	if ed.confirm_exit_open || (ui_pointer_captured() && !rl.CheckCollisionPointRec(input_mouse_pos(), ed.timeline_rect)) {
		next = .DEFAULT
	} else if ed.cam_orbit_drag || ed.cam_pan_drag || ed.curve_drag == .Pan {
		next = .RESIZE_ALL
	} else if ed.gizmo_hover >= 0 || ed.hover_bone >= 0 || ed.hover_kf >= 0 || ed.curve_hover_kind != .None || ed.curve_drag != .None {
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

handle_anim_ui_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.anim_ed
	#partial switch msg {
	case .Anim_Play_Toggle:   ed.playing = !ed.playing
	case .Anim_Prev_Kf:       anim_jump_keyframe(-1)
	case .Anim_Next_Kf:       anim_jump_keyframe(1)
	case .Anim_Speed:
		if ed.play_speed < 0.4 { ed.play_speed = 0.5 } else if ed.play_speed < 0.8 { ed.play_speed = 1.0 } else { ed.play_speed = 0.25 }
	case .Anim_Undo:
		if anim_edit.anim_undo_step(&ed.undo, &ed.clip) { anim_clamp_selected_kf(); anim_editor_set_status("Undo", false, 1.4) }
	case .Anim_Redo:
		if anim_edit.anim_redo_step(&ed.undo, &ed.clip) { anim_clamp_selected_kf(); anim_editor_set_status("Redo", false, 1.4) }
	case .Anim_Toggle_Bones:   ed.show_bones = !ed.show_bones
	case .Anim_Toggle_XRay:    ed.xray_bones = !ed.xray_bones
	case .Anim_Toggle_Onion:   ed.onion_skin = !ed.onion_skin
	case .Anim_Toggle_Mirror:  ed.mirror_lr = !ed.mirror_lr
	case .Anim_Toggle_AutoKey: ed.auto_key = !ed.auto_key
	case .Anim_Team:
		ed.preview_team = Unit_Preview_Palette((int(ed.preview_team) + 1) % 3)
		anim_editor_rebuild_preview_model()
	case .Anim_Shader:        ed.use_watercolor = !ed.use_watercolor
	case .Anim_Clips:         anim_editor_open_picker()
	case .Anim_Models:        editor_open_picker()
	case .Anim_Reset:         _ = anim_editor_reset_to_procedural()
	case .Anim_Save:          _ = anim_editor_save_and_hot_reload()
	case .Anim_Game:
		if ed.clip.dirty { ed.confirm_exit_open = true } else { anim_editor_close_to_game() }
	case .Anim_Tool:          ed.tool = Anim_Tool(clamp(int(arg), 0, 2))
	case .Anim_Select_Bone:
		ed.selected_bone = art.Bone_Id(clamp(int(arg), 0, art.BONE_COUNT - 1))
		ed.curve_is_root = ed.selected_bone == .Root
		anim_curves_fit_view()
	case:
		handle_anim_key_and_curve_msg(msg, arg)
	}
}

@(private)
handle_anim_key_and_curve_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.anim_ed
	#partial switch msg {
	case .Anim_Zero_Bone:     anim_exec_zero_bone()
	case .Anim_Ground_Y0:     anim_editor_ground_feet_y0()
	case .Anim_Flip_LR:       anim_exec_flip_lr()
	case .Anim_Add_Key:       anim_exec_add_keyframe()
	case .Anim_Dup_Key:       anim_exec_dup_keyframe()
	case .Anim_Del_Key:       anim_exec_del_keyframe()
	case .Anim_Copy_Pose:     anim_exec_copy_pose()
	case .Anim_Paste_Pose:    anim_exec_paste_pose()
	case .Anim_Interp:        anim_exec_set_interp(spec.Anim_Interp(clamp(int(arg), 0, 4)))
	case .Anim_Toggle_Loop:
		anim_edit.anim_undo_push(&ed.undo, &ed.clip); ed.clip.loop = !ed.clip.loop
		anim_edit.recompute_clip_handles(&ed.clip); ed.clip.dirty = true
	case .Anim_Toggle_Additive:
		anim_edit.anim_undo_push(&ed.undo, &ed.clip); ed.clip.additive = !ed.clip.additive; ed.clip.dirty = true
	case .Anim_Dock_Tab:      ed.dock_tab = Anim_Dock_Tab(clamp(int(arg), 0, 1))
	case .Anim_Dock_Tall:     ed.dock_tall = !ed.dock_tall
	case .Anim_Curve_Target:
		ed.curve_is_root = arg != 0; anim_curves_fit_view()
	case .Anim_Curve_Axis:
		ax := clamp(int(arg), 0, 2)
		if ed.curve_active_axis == ax && ed.curve_vis[ax] {
			ed.curve_vis[ax] = !ed.curve_vis[ax]
			if !ed.curve_vis[0] && !ed.curve_vis[1] && !ed.curve_vis[2] { ed.curve_vis[ax] = true }
		} else {
			ed.curve_vis[ax] = true; ed.curve_active_axis = ax
		}
		anim_curves_fit_view()
	case .Anim_Curve_Handle:
		if ed.clip_loaded && len(ed.clip.keyframes) > 0 {
			anim_edit.anim_undo_push(&ed.undo, &ed.clip)
			anim_edit.set_channel_handle_type(&ed.clip, ed.selected_kf, ed.curve_is_root, ed.selected_bone, ed.curve_active_axis, spec.Anim_Handle(clamp(int(arg), 0, 4)))
		}
	case .Anim_Curve_Fit:     anim_curves_fit_view()
	case .Anim_Exit_Save:     _ = anim_editor_save_and_hot_reload(); anim_editor_close_to_game()
	case .Anim_Exit_Discard:  anim_editor_close_to_game()
	case .Anim_Exit_Cancel:   ed.confirm_exit_open = false
	}
}
