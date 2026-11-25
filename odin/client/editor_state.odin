// In-game 3D Model Editor state, mode lifecycle, and tool definitions.
package main

import "core:fmt"
import rl "../gfx"
import art "./art"
import edit "./art/edit"

App_Mode :: enum u8 {
	Game,
	Pause_Menu,
	Model_Picker,
	Model_Editor,
}

Editor_Tool :: enum u8 {
	Select,
	Box,
	Grab,
	Rotate,
	Scale,
	Extrude,
	Inset,
	Loop_Cut,
	Knife,
	Fill,
	Merge,
}

Pose_Preview_Kind :: enum u8 {
	Rest,
	Idle,
	Walk,
	Attack,
}

Unit_Preview_Palette :: enum u8 {
	Hero,
	Player,
	Enemy,
}

Editor_View_Preset :: enum u8 {
	Iso,
	Front,
	Right,
	Top,
}

EDITOR_TOPBAR_H :: f32(44)
EDITOR_LEFT_W :: f32(88)
EDITOR_RIGHT_W :: f32(272)
EDITOR_STATUS_H :: f32(28)

Model_Editor_State :: struct {
	mesh:              edit.Edit_Mesh,
	mesh_loaded:       bool,
	undo:              edit.Undo_Stack,
	tool:              Editor_Tool,
	modal_active:      bool,
	modal_op:          Editor_Tool,
	axis_lock:         edit.Axis_Lock,
	mirror_x:          bool,
	xray_mode:         bool,
	wire_overlay:      bool,
	use_watercolor:    bool,
	pose_kind:         Pose_Preview_Kind,
	pose_phase:        f32,
	pose_playing:      bool,
	pose_mats:         [art.BONE_COUNT]rl.Matrix,
	preview_team:      Unit_Preview_Palette,
	preview_model:     Unit_Model,
	preview_dirty_gpu: bool,
	active_mat:        art.Mat_Kind,
	active_bone:       art.Bone_Id,
	mat_scroll:        int,
	bone_scroll:       int,
	base_pos:          [dynamic][3]f32,
	pivot:             [3]f32,
	modal_start_mouse: rl.Vector2,
	modal_delta:       [3]f32,
	modal_angle:       f32,
	modal_scale:       f32,
	num_buf:           [24]u8,
	num_len:           int,
	box_active:        bool,
	box_start:         rl.Vector2,
	gizmo_hover:       int,
	gizmo_drag_axis:   int,
	hover_vert:        int,
	hover_edge:        int,
	hover_face:        int,
	loop_cuts:         int,
	loop_slide:        f32,
	loop_preview:      edit.Loop_Cut_Preview,
	knife_nodes:       [dynamic]edit.Knife_Node,
	knife_hover:       edit.Knife_Node,
	knife_has_hover:   bool,
	delete_menu_open:  bool,
	delete_menu_pos:   rl.Vector2,
	confirm_exit_open: bool,
	status_buf:        [160]u8,
	status_len:        int,
	status_timer:      f32,
	status_is_error:   bool,

	// Model picker & orbital viewport camera
	picker_cat:        int, // 0=All, 1=Units, 2=Trees, 3=Props
	picker_idx:        int,
	picker_yaw:        f32,
	picker_preview:    Unit_Model,
	picker_preview_id: string,
	picker_rect_tex:   rl.RenderTexture2D,
	cam_target:        [3]f32,
	cam_yaw:           f32,
	cam_pitch:         f32,
	cam_dist:          f32,
	cam_fovy:          f32,
	cam_ortho:         bool,
	camera:            rl.Camera3D,
	cam_orbit_drag:    bool,
	cam_pan_drag:      bool,
	cam_last_mouse:    rl.Vector2,
	rmb_down_pos:      rl.Vector2,
	rmb_moved:         bool,
}

editor_viewport_rect :: proc() -> rl.Rectangle {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	return rl.Rectangle{
		x      = EDITOR_LEFT_W,
		y      = EDITOR_TOPBAR_H,
		width  = max(w - EDITOR_LEFT_W - EDITOR_RIGHT_W, 120),
		height = max(h - EDITOR_TOPBAR_H - EDITOR_STATUS_H, 120),
	}
}

editor_set_status :: proc(msg: string, is_err := false, secs: f32 = 3.2) {
	n := min(len(msg), len(app.editor.status_buf) - 1)
	copy(app.editor.status_buf[:n], msg[:n])
	app.editor.status_buf[n] = 0
	app.editor.status_len = n
	app.editor.status_is_error = is_err
	app.editor.status_timer = secs
}

editor_status_cstr :: proc() -> cstring {
	if app.editor.status_timer <= 0 || app.editor.status_len <= 0 {
		return ""
	}
	app.editor.status_buf[app.editor.status_len] = 0
	return cstring(&app.editor.status_buf[0])
}

editor_init_defaults :: proc() {
	ed := &app.editor
	ed.wire_overlay = true
	ed.cam_ortho = true
	ed.loop_cuts = 1
	ed.active_mat = .Cloth
	ed.active_bone = .Chest
	ed.pose_playing = true
	for i in 0..<art.BONE_COUNT {
		ed.pose_mats[i] = rl.Matrix(1)
	}
}

editor_cleanup :: proc() {
	ed := &app.editor
	edit.loop_cut_preview_delete(&ed.loop_preview)
	delete(ed.base_pos)
	delete(ed.knife_nodes)
	edit.undo_delete(&ed.undo)
	if ed.mesh_loaded {
		edit.edit_mesh_delete(&ed.mesh)
		ed.mesh_loaded = false
	}
	unload_unit_model(&ed.preview_model)
	unload_unit_model(&ed.picker_preview)
	if ed.picker_rect_tex.id > 0 {
		rl.UnloadRenderTexture(ed.picker_rect_tex)
		ed.picker_rect_tex = {}
	}
}

editor_open_picker :: proc() {
	ed := &app.editor
	if ed.wire_overlay == false && ed.cam_dist == 0 {
		editor_init_defaults()
	}
	if ed.picker_idx < 0 || ed.picker_idx >= len(art.MODEL_CATALOG) {
		ed.picker_idx = 0
	}
	editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
	app.mode = .Model_Picker
	app.menu_open = false
}

editor_open_model :: proc(id: string, force_procedural := false) -> bool {
	ed := &app.editor
	if ed.cam_dist == 0 {
		editor_init_defaults()
	}
	em, ok := art.catalog_load_edit_mesh(id, force_procedural)
	if !ok {
		editor_set_status(fmt.tprintf("Failed to load model: %s", id), true)
		return false
	}
	if ed.mesh_loaded {
		edit.edit_mesh_delete(&ed.mesh)
	}
	ed.mesh = em
	ed.mesh_loaded = true
	ed.mesh.mode = .Vertex
	edit.undo_clear(&ed.undo)
	ed.tool = .Select
	ed.modal_active = false
	ed.axis_lock = .None
	ed.loop_cuts = 1
	ed.loop_slide = 0
	ed.delete_menu_open = false
	ed.confirm_exit_open = false
	clear(&ed.knife_nodes)
	ed.pose_kind = .Rest
	if id == "mamluk_enemy" {
		ed.preview_team = .Enemy
	} else if id == "mamluk_hero" {
		ed.preview_team = .Hero
	} else {
		ed.preview_team = .Hero
	}
	editor_reset_camera(.Iso)
	editor_rebuild_preview_gpu()
	app.mode = .Model_Editor
	app.menu_open = false
	label := art.catalog_has_custom_odin(id) ? "Odin Custom" : "Procedural Odin"
	editor_set_status(fmt.tprintf("Loaded %s (%s)", id, label), false, 2.5)
	return true
}

editor_close_to_game :: proc() {
	app.editor.modal_active = false
	app.editor.delete_menu_open = false
	app.editor.confirm_exit_open = false
	app.mode = .Game
	app.menu_open = false
}
