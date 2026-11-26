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
	Pause_Anim_Editor,
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
	Ed_Anims,
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
	Anim_Picker_Tab,
	Anim_Picker_Row,
	Anim_Picker_Back,
	Anim_Picker_Edit_Proc,
	Anim_Picker_Edit_Clip,
	Anim_Play_Toggle,
	Anim_Prev_Kf,
	Anim_Next_Kf,
	Anim_Speed,
	Anim_Undo,
	Anim_Redo,
	Anim_Toggle_Bones,
	Anim_Toggle_XRay,
	Anim_Toggle_Onion,
	Anim_Toggle_Mirror,
	Anim_Toggle_AutoKey,
	Anim_Team,
	Anim_Shader,
	Anim_Models,
	Anim_Clips,
	Anim_Reset,
	Anim_Save,
	Anim_Game,
	Anim_Tool,
	Anim_Select_Bone,
	Anim_Zero_Bone,
	Anim_Ground_Y0,
	Anim_Flip_LR,
	Anim_Add_Key,
	Anim_Dup_Key,
	Anim_Del_Key,
	Anim_Copy_Pose,
	Anim_Paste_Pose,
	Anim_Interp,
	Anim_Toggle_Loop,
	Anim_Toggle_Additive,
	Anim_Dock_Tab,
	Anim_Dock_Tall,
	Anim_Curve_Target,
	Anim_Curve_Axis,
	Anim_Curve_Handle,
	Anim_Curve_Fit,
	Anim_Rig_Mode,
	Anim_Pin_Feet,
	Anim_Select_Ctrl,
	Anim_Select_Preset,
	Anim_Select_All_Kfs,
	Anim_Exit_Save,
	Anim_Exit_Discard,
	Anim_Exit_Cancel,
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
	case .Pause_Anim_Editor:
		anim_editor_open_picker()
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
