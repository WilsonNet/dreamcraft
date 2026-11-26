// In-game 3D Animation Editor state, mode lifecycle, and layout constants.
package main

import "core:fmt"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import edit "./art/edit"

ANIM_TOPBAR_H :: f32(44)
ANIM_LEFT_W :: f32(176)
ANIM_RIGHT_W :: f32(280)
ANIM_DOCK_NORMAL_H :: f32(236)
ANIM_DOCK_TALL_H :: f32(330)
ANIM_STATUS_H :: f32(28)

Anim_Tool :: enum u8 {
	Select,
	Rotate,
	Move_Root,
}

Anim_Dock_Tab :: enum u8 {
	Curves,
	Dopesheet,
}

Rig_Display_Mode :: enum u8 {
	Rig,
	Bones,
	Both,
}

Curve_Drag_Kind :: enum u8 {
	None,
	Scrub,
	Key,
	Handle_In,
	Handle_Out,
	Pan,
}

Anim_Editor_State :: struct {
	clip:                   anim_edit.Edit_Clip,
	clip_loaded:            bool,
	undo:                   anim_edit.Anim_Undo_Stack,
	selected_bone:          art.Bone_Id,
	selected_bones:         [art.BONE_COUNT]bool,
	hover_bone:             int,
	rig_mode:               Rig_Display_Mode,
	rig:                    art_rig.Rig_Targets,
	selected_ctrl:          art_rig.Control_Id,
	selected_ctrls:         [art_rig.CTRL_COUNT]bool,
	hover_ctrl:             int,
	vp_box_pending:         bool,
	vp_box_active:          bool,
	vp_box_start:           rl.Vector2,
	vp_box_shift:           bool,
	selected_kf:            int,
	selected_kfs:           [dynamic]bool,
	hover_kf:               int,
	drag_kf:                int,
	drag_kf_undo:           bool,
	playhead:               f32,
	playing:                bool,
	play_speed:             f32,
	tool:                   Anim_Tool,
	modal_restore_tool:     Anim_Tool,
	gizmo_on_bone:          bool,
	modal_active:           bool,
	modal_is_ctrl:          bool,
	modal_op:               Anim_Tool,
	axis_lock:              edit.Axis_Lock,
	gizmo_hover:            int,
	gizmo_drag_axis:        int,
	modal_start_mouse:      rl.Vector2,
	modal_base_rot:         [3]f32,
	modal_base_all_rot:     [art.BONE_COUNT][3]f32,
	modal_base_ctrl_pos:    [art_rig.CTRL_COUNT][3]f32,
	modal_base_root:        [3]f32,
	modal_angle:            f32,
	modal_delta:            [3]f32,
	num_buf:                [24]u8,
	num_len:                int,
	show_bones:             bool,
	xray_bones:             bool,
	onion_skin:             bool,
	mirror_lr:              bool,
	auto_key:               bool,
	show_slash:             bool,
	use_watercolor:         bool,
	slider_undo_armed:      bool,
	preview_team:           Unit_Preview_Palette,
	preview_model:          Unit_Model,
	current_pose:           art.Pose,
	pose_mats:              [art.BONE_COUNT]rl.Matrix,
	has_copied_pose:        bool,
	copied_pose:            anim_edit.Edit_Keyframe,
	confirm_exit_open:      bool,
	status_buf:             [160]u8,
	status_len:             int,
	status_timer:           f32,
	status_is_error:        bool,
	timeline_rect:          rl.Rectangle,
	scrubbing:              bool,

	dock_tab:               Anim_Dock_Tab,
	dock_tall:              bool,
	curve_is_root:          bool,
	curve_vis:              [3]bool,
	curve_active_axis:      int,
	curve_y_min:            f32,
	curve_y_max:            f32,
	curve_t_min:            f32,
	curve_t_max:            f32,
	curve_drag:             Curve_Drag_Kind,
	curve_drag_kf:          int,
	curve_drag_axis:        int,
	curve_drag_undo:        bool,
	curve_drag_start_mouse: rl.Vector2,
	curve_drag_base_t:      f32,
	curve_drag_base_v:      f32,
	curve_drag_base_ymin:   f32,
	curve_drag_base_ymax:   f32,
	curve_drag_base_times:  [dynamic]f32,
	curve_drag_base_vals:   [dynamic]f32,
	curve_box_active:       bool,
	curve_box_start:        rl.Vector2,
	curve_box_shift:        bool,
	curve_scale_active:     bool,
	curve_scale_start_x:    f32,
	curve_hover_kind:       Curve_Drag_Kind,
	curve_hover_kf:         int,
	curve_hover_axis:       int,

	picker_cat:             int,
	picker_idx:             int,
	picker_yaw:             f32,
	picker_phase:           f32,
	picker_preview:         Unit_Model,
	picker_preview_team:    Unit_Preview_Palette,
	picker_rect_tex:        rl.RenderTexture2D,

	cam_target:             [3]f32,
	cam_yaw:                f32,
	cam_pitch:              f32,
	cam_dist:               f32,
	cam_fovy:               f32,
	cam_ortho:              bool,
	camera:                 rl.Camera3D,
	cam_orbit_drag:         bool,
	cam_pan_drag:           bool,
	cam_last_mouse:         rl.Vector2,
	rmb_down_pos:           rl.Vector2,
	rmb_moved:              bool,

	watch_mtimes:           [len(art.ANIM_CATALOG)]i64,
	watch_accum:            f32,
	watch_ready:            bool,
}

anim_editor_dock_h :: proc() -> f32 {
	return app.anim_ed.dock_tall ? ANIM_DOCK_TALL_H : ANIM_DOCK_NORMAL_H
}

anim_gizmo_uses_rig :: proc() -> bool {
	ed := &app.anim_ed
	return anim_is_rig_active() && !(ed.rig_mode == .Both && ed.gizmo_on_bone)
}

anim_editor_viewport_rect :: proc() -> rl.Rectangle {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	return rl.Rectangle{
		x      = ANIM_LEFT_W,
		y      = ANIM_TOPBAR_H,
		width  = max(w - ANIM_LEFT_W - ANIM_RIGHT_W, 120),
		height = max(h - ANIM_TOPBAR_H - anim_editor_dock_h() - ANIM_STATUS_H, 120),
	}
}

anim_editor_set_status :: proc(msg: string, is_err := false, secs: f32 = 3.2) {
	ed := &app.anim_ed
	n := min(len(msg), len(ed.status_buf) - 1)
	copy(ed.status_buf[:n], msg[:n])
	ed.status_buf[n] = 0
	ed.status_len = n
	ed.status_is_error = is_err
	ed.status_timer = secs
}

anim_editor_status_cstr :: proc() -> cstring {
	ed := &app.anim_ed
	if ed.status_timer <= 0 || ed.status_len <= 0 {
		return ""
	}
	ed.status_buf[ed.status_len] = 0
	return cstring(&ed.status_buf[0])
}

anim_editor_init_defaults :: proc() {
	ed := &app.anim_ed
	ed.show_bones = true
	ed.xray_bones = true
	ed.auto_key = true
	ed.show_slash = true
	ed.cam_ortho = true
	ed.play_speed = 1.0
	ed.selected_bone = .Chest
	ed.selected_bones = {}
	ed.selected_bones[int(art.Bone_Id.Chest)] = true
	ed.hover_bone = -1
	ed.rig_mode = .Rig
	ed.rig.pin_feet = true
	ed.selected_ctrl = .COG
	ed.selected_ctrls = {}
	ed.selected_ctrls[int(art_rig.Control_Id.COG)] = true
	ed.hover_ctrl = -1
	ed.hover_kf = -1
	ed.drag_kf = -1
	ed.gizmo_hover = -1
	ed.gizmo_drag_axis = -1
	ed.dock_tab = .Curves
	ed.curve_vis = {true, true, true}
	ed.curve_t_min = -0.03
	ed.curve_t_max = 1.03
	ed.curve_y_min = -1.2
	ed.curve_y_max = 1.2
	ed.curve_hover_kf = -1
	for i in 0 ..< art.BONE_COUNT {
		ed.pose_mats[i] = rl.Matrix(1)
	}
}

anim_editor_cleanup :: proc() {
	ed := &app.anim_ed
	delete(ed.selected_kfs)
	delete(ed.curve_drag_base_times)
	delete(ed.curve_drag_base_vals)
	anim_edit.anim_undo_delete(&ed.undo)
	if ed.clip_loaded {
		anim_edit.edit_clip_delete(&ed.clip)
		ed.clip_loaded = false
	}
	unload_unit_model(&ed.preview_model)
	unload_unit_model(&ed.picker_preview)
	if ed.picker_rect_tex.id > 0 {
		rl.UnloadRenderTexture(ed.picker_rect_tex)
		ed.picker_rect_tex = {}
	}
}

anim_editor_open_picker :: proc() {
	ed := &app.anim_ed
	if ed.cam_dist == 0 {
		anim_editor_init_defaults()
	}
	if ed.picker_idx < 0 || ed.picker_idx >= len(art.ANIM_CATALOG) {
		ed.picker_idx = 0
	}
	anim_editor_ensure_picker_preview(ed.picker_idx)
	app.mode = .Anim_Picker
	app.menu_open = false
}

anim_editor_open_clip :: proc(id: string, force_procedural := false) -> bool {
	ed := &app.anim_ed
	if ed.cam_dist == 0 {
		anim_editor_init_defaults()
	}
	c, ok := art.anim_catalog_load_edit_clip(id, force_procedural)
	if !ok {
		anim_editor_set_status(fmt.tprintf("Failed to load clip: %s", id), true)
		return false
	}
	if ed.clip_loaded {
		anim_edit.edit_clip_delete(&ed.clip)
	}
	ed.clip = c
	ed.clip_loaded = true
	reset_anim_clip_session_state(id)
	return true
}

@(private)
reset_anim_clip_session_state :: proc(id: string) {
	ed := &app.anim_ed
	anim_edit.anim_undo_clear(&ed.undo)
	ed.selected_kf = 0
	anim_sync_kf_selection()
	anim_select_kf_only(0)
	ed.playhead = len(ed.clip.keyframes) > 0 ? ed.clip.keyframes[0].time : 0
	ed.playing, ed.modal_active, ed.modal_is_ctrl = false, false, false
	ed.vp_box_pending, ed.vp_box_active = false, false
	ed.curve_box_active, ed.curve_scale_active = false, false
	ed.rig.initialized, ed.scrubbing = false, false
	ed.tool, ed.axis_lock, ed.drag_kf, ed.curve_drag = .Select, .None, -1, .None
	ed.confirm_exit_open = false

	entry, _ := art.anim_catalog_find(id)
	ed.preview_team = entry.category == .Enemy ? .Enemy : (entry.category == .Hero ? .Hero : .Player)
	anim_editor_rebuild_preview_model()
	anim_reset_camera(.Iso)
	anim_curves_fit_view()
	anim_editor_eval_preview_pose()
	app.mode = .Anim_Editor
	app.menu_open = false
	label := art.anim_catalog_has_custom_odin(id) ? "Odin Custom" : "Procedural Bake"
	anim_editor_set_status(fmt.tprintf("Loaded %s (%s)", id, label), false, 2.5)
}

anim_editor_close_to_game :: proc() {
	ed := &app.anim_ed
	ed.modal_active = false
	ed.vp_box_pending = false
	ed.vp_box_active = false
	ed.curve_box_active = false
	ed.curve_scale_active = false
	ed.confirm_exit_open = false
	ed.scrubbing = false
	ed.drag_kf = -1
	ed.curve_drag = .None
	app.mode = .Game
	app.menu_open = false
}
