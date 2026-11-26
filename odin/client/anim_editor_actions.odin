// Animation Editor UI dispatch, multi-bone/rig zeroing, and multi-keyframe actions.
package main

import "core:fmt"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import spec "./art/spec"

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
	anim_select_kf_only(ed.selected_kf)
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
}

anim_exec_zero_bone :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	if anim_is_rig_active() {
		for i in 0 ..< art_rig.CTRL_COUNT {
			if ed.selected_ctrls[i] {
				zero_ctrl_driven_bones(kf, art_rig.Control_Id(i), ed.mirror_lr)
			}
		}
		anim_editor_set_status("Zeroed selected motion controls", false, 1.6)
	} else {
		for bi in 0 ..< art.BONE_COUNT {
			if ed.selected_bones[bi] {
				anim_edit.clip_zero_bone(kf, art.Bone_Id(bi), ed.mirror_lr)
			}
		}
		anim_editor_set_status(fmt.tprintf("Zeroed %d bone(s)", anim_selected_bone_count()), false, 1.6)
	}
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
}

@(private)
zero_ctrl_driven_bones :: proc(kf: ^anim_edit.Edit_Keyframe, ctrl: art_rig.Control_Id, mirror: bool) {
	zero_pair :: proc(kf: ^anim_edit.Edit_Keyframe, bones: []art.Bone_Id, mirror: bool) {
		for b in bones { anim_edit.clip_zero_bone(kf, b, mirror) }
	}
	switch ctrl {
	case .COG:
		kf.root_offset = {}
		anim_edit.clip_zero_bone(kf, .Pelvis, false)
	case .Chest_Ctrl:   zero_pair(kf, {.Spine, .Chest}, false)
	case .Head_Aim:     zero_pair(kf, {.Neck, .Head}, false)
	case .Cape_Ctrl:    zero_pair(kf, {.Cape_1, .Cape_2, .Cape_3}, false)
	case .Hand_IK_L, .Pole_Elbow_L: zero_pair(kf, {.Arm_L, .Forearm_L, .Hand_L}, mirror)
	case .Hand_IK_R, .Pole_Elbow_R: zero_pair(kf, {.Arm_R, .Forearm_R, .Hand_R}, mirror)
	case .Foot_IK_L, .Pole_Knee_L:  zero_pair(kf, {.Thigh_L, .Shin_L, .Foot_L}, mirror)
	case .Foot_IK_R, .Pole_Knee_R:  zero_pair(kf, {.Thigh_R, .Shin_R, .Foot_R}, mirror)
	case .COUNT:
	}
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
	anim_select_kf_only(ed.selected_kf)
	anim_editor_set_status(fmt.tprintf("Keyframed t=%.2f", ed.playhead), false, 1.6)
}

anim_exec_dup_keyframe :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	src_t := ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)].time
	new_t := clamp(src_t + 0.08 <= 1.0 ? src_t + 0.08 : src_t - 0.08, 0, 1)
	ed.selected_kf = anim_edit.clip_duplicate_keyframe(&ed.clip, ed.selected_kf, new_t)
	anim_select_kf_only(ed.selected_kf)
	ed.playhead = ed.clip.keyframes[ed.selected_kf].time
	anim_editor_set_status("Duplicated keyframe", false, 1.6)
}

anim_exec_del_keyframe :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) <= 1 {
		anim_editor_set_status("Clip must keep at least 1 keyframe", true, 2.0)
		return
	}
	anim_sync_kf_selection()
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	deleted := 0
	for i := len(ed.clip.keyframes) - 1; i >= 0; i -= 1 {
		if len(ed.clip.keyframes) <= 1 { break }
		if ed.selected_kfs[i] && anim_edit.clip_delete_keyframe(&ed.clip, i) {
			deleted += 1
		}
	}
	if deleted > 0 {
		anim_clamp_selected_kf()
		anim_select_kf_only(ed.selected_kf)
		anim_editor_set_status(fmt.tprintf("Deleted %d keyframe(s)", deleted), false, 1.6)
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
	anim_sync_kf_selection()
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	for i in 0 ..< len(ed.clip.keyframes) {
		if ed.selected_kfs[i] {
			ed.clip.keyframes[i].interp = interp
		}
	}
	ed.clip.dirty = true
}

anim_cycle_handle_type :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 { return }
	ki := clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
	cur, _, _ := anim_edit.channel_get_handles(&ed.clip.keyframes[ki], ed.curve_is_root, ed.selected_bone, ed.curve_active_axis)
	next := spec.Anim_Handle((int(cur) + 1) % 5)
	anim_sync_kf_selection()
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	for i in 0 ..< len(ed.clip.keyframes) {
		if ed.selected_kfs[i] {
			anim_edit.set_channel_handle_type(&ed.clip, i, ed.curve_is_root, ed.selected_bone, ed.curve_active_axis, next)
		}
	}
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

handle_anim_ui_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.anim_ed
	#partial switch msg {
	case .Anim_Play_Toggle:   ed.playing = !ed.playing
	case .Anim_Prev_Kf:       anim_jump_keyframe(-1)
	case .Anim_Next_Kf:       anim_jump_keyframe(1)
	case .Anim_Speed:
		if ed.play_speed < 0.4 { ed.play_speed = 0.5 } else if ed.play_speed < 0.8 { ed.play_speed = 1.0 } else { ed.play_speed = 0.25 }
	case .Anim_Undo:
		if anim_edit.anim_undo_step(&ed.undo, &ed.clip) { anim_sync_kf_selection(); anim_clamp_selected_kf(); anim_editor_set_status("Undo", false, 1.4) }
	case .Anim_Redo:
		if anim_edit.anim_redo_step(&ed.undo, &ed.clip) { anim_sync_kf_selection(); anim_clamp_selected_kf(); anim_editor_set_status("Redo", false, 1.4) }
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
		b := art.Bone_Id(clamp(int(arg), 0, art.BONE_COUNT - 1))
		if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) { anim_toggle_bone_select(b) } else { anim_select_bone_only(b) }
	case .Anim_Rig_Mode:      ed.rig_mode = Rig_Display_Mode((int(ed.rig_mode) + 1) % 3)
	case .Anim_Pin_Feet:      ed.rig.pin_feet = !ed.rig.pin_feet
	case .Anim_Select_Ctrl:
		c := art_rig.Control_Id(clamp(int(arg), 0, art_rig.CTRL_COUNT - 1))
		if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) { anim_toggle_ctrl_select(c) } else { anim_select_ctrl_only(c) }
	case .Anim_Select_Preset:
		shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
		if arg == 6 {
			if anim_is_rig_active() { anim_select_all_ctrls() } else { anim_select_all_bones() }
		} else if arg == 7 {
			anim_select_bone_chain(ed.selected_bone, shift)
		} else {
			anim_apply_selection_preset(int(arg), shift)
		}
	case .Anim_Select_All_Kfs: anim_select_all_kfs(true)
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
			anim_sync_kf_selection()
			anim_edit.anim_undo_push(&ed.undo, &ed.clip)
			h := spec.Anim_Handle(clamp(int(arg), 0, 4))
			for i in 0 ..< len(ed.clip.keyframes) {
				if ed.selected_kfs[i] {
					anim_edit.set_channel_handle_type(&ed.clip, i, ed.curve_is_root, ed.selected_bone, ed.curve_active_axis, h)
				}
			}
		}
	case .Anim_Curve_Fit:     anim_curves_fit_view()
	case .Anim_Exit_Save:     _ = anim_editor_save_and_hot_reload(); anim_editor_close_to_game()
	case .Anim_Exit_Discard:  anim_editor_close_to_game()
	case .Anim_Exit_Cancel:   ed.confirm_exit_open = false
	}
}
