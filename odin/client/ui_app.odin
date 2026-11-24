// Elm-style UI message dispatcher and root UI tree coordinator for DreamCraft.
package main

import edit "./art/edit"
import g "../game"

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
