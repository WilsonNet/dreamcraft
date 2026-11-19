// Elm-style UI message dispatcher and root UI tree coordinator for DreamCraft.
package main

import "core:fmt"
import "core:hash"
import rl "vendor:raylib"
import edit "./art/edit"
import g "../game"
import ui "../ui"

UI_Msg :: enum u32 {
	None = 0,
	Hud_Move,
	Hud_Attack,
	Hud_Patrol,
	Hud_Stop,
	Hud_Toggle_Follow,
	Hud_Select_Hero,
	Pause_Resume,
	Pause_Editor,
	Pause_Retry,
	Help_Toggle,
	Help_Close,
	Picker_Tab,
	Picker_Row,
	Picker_Back,
	Picker_Edit_Proc,
	Picker_Edit_Model,
	Ed_Mode,
	Ed_Undo,
	Ed_Redo,
	Ed_Mirror,
	Ed_Wire,
	Ed_XRay,
	Ed_Floor_Y,
	Ed_Pose,
	Ed_Team,
	Ed_Shader,
	Ed_Models,
	Ed_Reset,
	Ed_Save,
	Ed_Game,
	Ed_Tool,
	Ed_Smooth,
	Ed_Mat,
	Ed_Bone_Sel,
	Ed_Bone,
	Ed_Delete_Choice,
	Ed_Exit_Save,
	Ed_Exit_Discard,
	Ed_Exit_Cancel,
}

ui_gather_input :: proc(dt: f32) -> ui.UI_Input {
	return ui.UI_Input{
		mouse         = input_mouse_pos(),
		left_down     = input_left_down(),
		left_pressed  = input_left_pressed(),
		left_released = input_left_released(),
		right_pressed = rl.IsMouseButtonPressed(.RIGHT),
		wheel_y       = input_wheel_y(),
		dt            = dt,
	}
}

ui_state_signature :: proc() -> u64 {
	sw := rl.GetScreenWidth()
	sh := rl.GetScreenHeight()
	summary := fmt.tprintf(
		"%d:%d:%d:%v:%v:%v:%v:%d:%s:%d:%v",
		sw, sh, int(app.mode), app.menu_open, app.help_open,
		app.editor.delete_menu_open, app.editor.confirm_exit_open,
		app.editor.picker_cat, app.editor.mesh.id, int(app.command_mode),
		app.editor.mesh.skinned,
	)
	return hash.fnv64a(transmute([]u8)summary)
}

ui_build_active :: proc(dt: f32) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	ui.begin(&app.ui_ctx, w, h, dt)
	switch app.mode {
	case .Game, .Pause_Menu:
		compose_battlefield_hud(&app.ui_ctx, w, h)
		if app.menu_open || app.mode == .Pause_Menu {
			compose_pause_menu(&app.ui_ctx)
		}
	case .Model_Picker:
		compose_model_picker(&app.ui_ctx, w, h)
	case .Model_Editor:
		compose_model_editor(&app.ui_ctx, w, h)
	}
	if app.help_open {
		compose_help_window(&app.ui_ctx, w, h)
	}
	ui.finish_layout(&app.ui_ctx)
	ui_sync_legacy_rects()
	app.ui_last_sig = ui_state_signature()
}

@(private)
ui_sync_legacy_rects :: proc() {
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("cmd_move")); ok { app.move_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("cmd_attack")); ok { app.attack_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("cmd_patrol")); ok { app.patrol_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("cmd_stop")); ok { app.stop_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("pause_resume")); ok { app.resume_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("pause_editor")); ok { app.editor_button = r }
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("pause_retry")); ok { app.retry_button = r }
}

ui_dispatch_events :: proc() {
	for ev in ui.events(&app.ui_ctx) {
		msg := UI_Msg(ev.tag)
		switch msg {
		case .None:
		case .Hud_Move, .Hud_Attack, .Hud_Patrol, .Hud_Stop, .Hud_Toggle_Follow, .Hud_Select_Hero,
		     .Pause_Resume, .Pause_Editor, .Pause_Retry, .Help_Toggle, .Help_Close:
			handle_hud_ui_msg(msg)
		case .Picker_Tab, .Picker_Row, .Picker_Back, .Picker_Edit_Proc, .Picker_Edit_Model:
			handle_picker_ui_msg(msg, ev.arg)
		case .Ed_Mode, .Ed_Undo, .Ed_Redo, .Ed_Mirror, .Ed_Wire, .Ed_XRay, .Ed_Floor_Y,
		     .Ed_Pose, .Ed_Team, .Ed_Shader, .Ed_Models, .Ed_Reset, .Ed_Save, .Ed_Game,
		     .Ed_Tool, .Ed_Smooth, .Ed_Mat, .Ed_Bone_Sel, .Ed_Bone,
		     .Ed_Delete_Choice, .Ed_Exit_Save, .Ed_Exit_Discard, .Ed_Exit_Cancel:
			handle_editor_ui_msg(msg, ev.arg, ev.mouse)
		}
	}
}

@(private)
handle_hud_ui_msg :: proc(msg: UI_Msg) {
	#partial switch msg {
	case .Hud_Move:
		app.command_mode = app.command_mode == .Move ? .None : .Move
		app.dragging = false
	case .Hud_Attack:
		app.command_mode = app.command_mode == .Attack ? .None : .Attack
		app.dragging = false
	case .Hud_Patrol:
		app.command_mode = app.command_mode == .Patrol ? .None : .Patrol
		app.dragging = false
	case .Hud_Stop:
		_ = g.game_issue_stop(&app.game)
		app.command_mode = .None
		app.dragging = false
	case .Hud_Toggle_Follow:
		app.camera_follow = !app.camera_follow
		app.camera_vel = {}
	case .Hud_Select_Hero:
		if idx, ok := g.game_player_index(&app.game); ok {
			g.unit_select_only(&app.game.units, idx)
		}
	case .Pause_Resume:
		app.menu_open = false
	case .Pause_Editor:
		editor_open_picker()
	case .Pause_Retry:
		retry_level()
	case .Help_Toggle:
		app.help_open = !app.help_open
	case .Help_Close:
		app.help_open = false
	}
}

ui_step_and_dispatch :: proc(dt: f32) {
	if app.ui_ctx.prev_hit_count == 0 || ui_state_signature() != app.ui_last_sig {
		ui_build_active(0)
	}
	ui.process_input(&app.ui_ctx, ui_gather_input(dt))
	ui_dispatch_events()
}

@(private)
ui_cstr :: proc(s: string) -> cstring {
	return cstring_t(s)
}

@(private)
editor_pose_short_label :: proc(p: Pose_Preview_Kind, compact: bool) -> cstring {
	if !compact {
		return editor_pose_label(p)
	}
	switch p {
	case .Rest:   return "Rest"
	case .Idle:   return "Idle"
	case .Walk:   return "Walk"
	case .Attack: return "Atk"
	}
	return "Rest"
}

@(private)
compose_editor_delete_choice :: proc(idx: int) {
	ed := &app.editor
	ed.delete_menu_open = false
	edit.undo_push(&ed.undo, &ed.mesh)
	ok := false
	switch idx {
	case 0: ok = edit.edit_delete_verts(&ed.mesh)
	case 1: ok = edit.edit_delete_edges(&ed.mesh)
	case 2: ok = edit.edit_delete_faces(&ed.mesh)
	case 3: ok = edit.edit_dissolve_edges(&ed.mesh)
	}
	if ok { editor_rebuild_preview_gpu() } else { editor_set_status("Nothing deleted", true, 1.8) }
}
