// Model Editor viewport picking, Elm UI message handler, and cursor state.
package main

import rl "../gfx"
import art "./art"
import edit "./art/edit"

handle_editor_input :: proc() {
	ed := &app.editor
	mouse := input_mouse_pos()
	if rl.IsMouseButtonPressed(.RIGHT) {
		ed.rmb_down_pos = mouse
		ed.rmb_moved = false
	}
	vp := editor_viewport_rect()
	in_vp := !ed.confirm_exit_open && !ed.delete_menu_open && !ui_pointer_captured() && rl.CheckCollisionPointRec(mouse, vp)
	if !ed.modal_active && !ed.box_active {
		editor_update_camera_input(mouse, in_vp)
	}
	update_editor_hover(mouse, in_vp)

	if ed.confirm_exit_open {
		handle_editor_hotkeys(mouse)
		return
	}
	if ed.delete_menu_open {
		handle_delete_popup_keys()
		return
	}
	if ed.modal_active {
		update_active_modal(mouse)
		return
	}
	if input_left_pressed() && in_vp {
		handle_editor_left_press(mouse)
	}
	if input_left_released() && ed.box_active {
		finish_box_or_click(mouse)
	}
	handle_editor_hotkeys(mouse)
}

@(private)
update_editor_hover :: proc(mouse: rl.Vector2, in_vp: bool) {
	ed := &app.editor
	ed.gizmo_hover = -1
	ed.hover_vert = -1
	ed.hover_edge = -1
	ed.hover_face = -1
	if !in_vp || !ed.mesh_loaded || ed.cam_orbit_drag || ed.cam_pan_drag {
		return
	}
	if ed.gizmo_drag_axis < 0 {
		ed.gizmo_hover = editor_gizmo_hit_test(mouse)
	}
	switch ed.mesh.mode {
	case .Vertex:
		if vi, ok := editor_pick_vert(mouse); ok { ed.hover_vert = vi }
	case .Edge:
		if ei, _, ok := editor_pick_edge(mouse); ok { ed.hover_edge = ei }
	case .Face:
		if fi, ok := editor_pick_face(mouse); ok { ed.hover_face = fi }
	}
}

@(private)
handle_editor_left_press :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	if axis := editor_gizmo_hit_test(mouse); axis >= 0 {
		lock := axis == 0 ? edit.Axis_Lock.X : (axis == 1 ? edit.Axis_Lock.Y : edit.Axis_Lock.Z)
		editor_start_transform(.Grab, lock, mouse)
		return
	}
	if ed.tool == .Knife {
		editor_start_knife()
		update_knife_modal(mouse)
		return
	}
	if ed.tool == .Loop_Cut {
		editor_start_loop_cut()
		update_loop_cut_modal(mouse)
		return
	}
	ed.box_active = true
	ed.box_start = mouse
}

@(private)
finish_box_or_click :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	ed.box_active = false
	additive := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	dist := rl.Vector2Distance(ed.box_start, mouse)
	if dist >= 6.0 {
		select_elements_in_box(ed.box_start, mouse, additive)
	} else {
		select_element_at_mouse(mouse, additive, alt)
	}
	if ed.tool == .Box { ed.tool = .Select }
}

@(private)
select_element_at_mouse :: proc(mouse: rl.Vector2, additive, alt: bool) {
	ed := &app.editor
	switch ed.mesh.mode {
	case .Vertex:
		vi, ok := editor_pick_vert(mouse)
		if !additive { edit.edit_mesh_deselect_all(&ed.mesh) }
		if ok { ed.mesh.verts[vi].selected = additive ? !ed.mesh.verts[vi].selected : true }
	case .Edge:
		ei, _, ok := editor_pick_edge(mouse)
		if alt && ok {
			edit.edit_mesh_select_edge_loop(&ed.mesh, ei, additive)
			return
		}
		if !additive { edit.edit_mesh_deselect_all(&ed.mesh) }
		if ok { ed.mesh.edges[ei].selected = additive ? !ed.mesh.edges[ei].selected : true }
	case .Face:
		fi, ok := editor_pick_face(mouse)
		if !additive { edit.edit_mesh_deselect_all(&ed.mesh) }
		if ok { ed.mesh.faces[fi].selected = additive ? !ed.mesh.faces[fi].selected : true }
	}
}

@(private)
select_elements_in_box :: proc(start, finish: rl.Vector2, additive: bool) {
	ed := &app.editor
	rect := rl.Rectangle{
		x = min(start.x, finish.x), y = min(start.y, finish.y),
		width = abs(finish.x - start.x), height = abs(finish.y - start.y),
	}
	if !additive { edit.edit_mesh_deselect_all(&ed.mesh) }
	switch ed.mesh.mode {
	case .Vertex:
		for _, vi in ed.mesh.verts {
			sp := rl.GetWorldToScreen(editor_posed_vert_pos(vi), ed.camera)
			if rl.CheckCollisionPointRec(sp, rect) { ed.mesh.verts[vi].selected = true }
		}
	case .Edge:
		for &e, ei in ed.mesh.edges {
			mid := (editor_posed_vert_pos(int(e.a)) + editor_posed_vert_pos(int(e.b))) * 0.5
			if rl.CheckCollisionPointRec(rl.GetWorldToScreen(mid, ed.camera), rect) { ed.mesh.edges[ei].selected = true }
		}
	case .Face:
		for &f, fi in ed.mesh.faces {
			c := rl.Vector3{}
			for k in 0..<int(f.count) { c += editor_posed_vert_pos(int(f.v[k])) }
			c /= f32(max(int(f.count), 1))
			if rl.CheckCollisionPointRec(rl.GetWorldToScreen(c, ed.camera), rect) { ed.mesh.faces[fi].selected = true }
		}
	}
}

handle_editor_ui_msg :: proc(msg: UI_Msg, arg: i32, mouse: rl.Vector2) {
	ed := &app.editor
	#partial switch msg {
	case .Ed_Mode, .Ed_Undo, .Ed_Redo, .Ed_Mirror, .Ed_Wire, .Ed_XRay, .Ed_Floor_Y,
	     .Ed_Pose, .Ed_Team, .Ed_Shader, .Ed_Models, .Ed_Anims, .Ed_Reset, .Ed_Save, .Ed_Game:
		handle_editor_topbar_msg(msg, arg)
	case .Ed_Tool:
		handle_editor_tool_msg(int(arg), mouse)
	case .Ed_Smooth:
		edit.undo_push(&ed.undo, &ed.mesh)
		if edit.edit_set_selected_smooth(&ed.mesh, true) { editor_rebuild_preview_gpu(); editor_set_status("Marked selection smooth", false, 1.8) }
	case .Ed_Mat:
		ed.active_mat = art.Mat_Kind(arg)
		edit.undo_push(&ed.undo, &ed.mesh)
		if edit.edit_set_selected_mat(&ed.mesh, ed.active_mat) { editor_rebuild_preview_gpu() }
	case .Ed_Bone_Sel:
		if ed.mesh.skinned { edit.edit_mesh_select_same_bone(&ed.mesh, ed.active_bone) }
	case .Ed_Bone:
		if ed.mesh.skinned {
			ed.active_bone = art.Bone_Id(arg)
			edit.undo_push(&ed.undo, &ed.mesh)
			_ = edit.edit_set_selected_bone(&ed.mesh, ed.active_bone)
		}
	case .Ed_Delete_Choice:
		if arg < 0 { ed.delete_menu_open = false } else { compose_editor_delete_choice(int(arg)) }
	case .Ed_Exit_Save:
		_ = editor_save_and_hot_reload()
		editor_close_to_game()
	case .Ed_Exit_Discard:
		editor_close_to_game()
	case .Ed_Exit_Cancel:
		ed.confirm_exit_open = false
	}
}

@(private)
handle_editor_topbar_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.editor
	#partial switch msg {
	case .Ed_Mode:
		modes := [3]edit.Select_Mode{.Vertex, .Edge, .Face}
		edit.edit_mesh_set_mode(&ed.mesh, modes[clamp(int(arg), 0, 2)])
	case .Ed_Undo:
		if edit.undo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu() }
	case .Ed_Redo:
		if edit.redo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu() }
	case .Ed_Mirror: ed.mirror_x = !ed.mirror_x
	case .Ed_Wire:   ed.wire_overlay = !ed.wire_overlay
	case .Ed_XRay:   ed.xray_mode = !ed.xray_mode
	case .Ed_Floor_Y:
		edit.undo_push(&ed.undo, &ed.mesh)
		if edit.edit_snap_to_ground(&ed.mesh) { editor_rebuild_preview_gpu(); editor_set_status("Snapped min Y to ground (Y=0)", false, 2.0) }
	case .Ed_Pose:
		ed.pose_kind = Pose_Preview_Kind((int(ed.pose_kind) + 1) % 4)
		ed.pose_phase = 0
	case .Ed_Team:
		ed.preview_team = Unit_Preview_Palette((int(ed.preview_team) + 1) % 3)
		editor_rebuild_preview_gpu()
	case .Ed_Shader: ed.use_watercolor = !ed.use_watercolor
	case .Ed_Models: editor_open_picker()
	case .Ed_Anims:  anim_editor_open_picker()
	case .Ed_Reset:  _ = editor_reset_to_procedural()
	case .Ed_Save:   _ = editor_save_and_hot_reload()
	case .Ed_Game:
		if ed.mesh.dirty { ed.confirm_exit_open = true } else { editor_close_to_game() }
	}
}

@(private)
handle_editor_tool_msg :: proc(idx: int, mouse: rl.Vector2) {
	ed := &app.editor
	switch idx {
	case 0:  ed.tool = .Select
	case 1:  ed.tool = .Box
	case 2:  editor_start_transform(.Grab, .None, mouse)
	case 3:  editor_start_transform(.Rotate, .None, mouse)
	case 4:  editor_start_transform(.Scale, .None, mouse)
	case 5:  editor_exec_extrude(mouse)
	case 6:  editor_exec_inset()
	case 7:  editor_start_loop_cut()
	case 8:  editor_start_knife()
	case 9:  editor_exec_fill()
	case 10: editor_exec_merge()
	case 11: editor_open_delete_menu(mouse)
	}
}

@(private)
handle_delete_popup_keys :: proc() {
	ed := &app.editor
	if rl.IsKeyPressed(.ESCAPE) { ed.delete_menu_open = false; return }
	choice := -1
	if rl.IsKeyPressed(.V) { choice = 0 }
	if rl.IsKeyPressed(.E) { choice = 1 }
	if rl.IsKeyPressed(.F) { choice = 2 }
	if rl.IsKeyPressed(.D) { choice = 3 }
	if choice >= 0 {
		compose_editor_delete_choice(choice)
	}
}

editor_open_delete_menu :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	vp := editor_viewport_rect()
	ed.delete_menu_pos = {
		clamp(mouse.x, vp.x + 8, vp.x + vp.width - 190),
		clamp(mouse.y, vp.y + 8, vp.y + vp.height - 156),
	}
	ed.delete_menu_open = true
}

editor_exec_extrude :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	edit.undo_push(&ed.undo, &ed.mesh)
	if _, ok := edit.edit_extrude(&ed.mesh); ok {
		editor_rebuild_preview_gpu()
		editor_start_transform(.Grab, .None, mouse)
	} else {
		editor_set_status("Select face(s) or vertex to extrude", true, 2.2)
	}
}

editor_exec_inset :: proc() {
	ed := &app.editor
	edit.undo_push(&ed.undo, &ed.mesh)
	if edit.edit_inset(&ed.mesh, 0.22) {
		editor_rebuild_preview_gpu()
		editor_set_status("Inset faces (22%)", false, 2.0)
	} else {
		editor_set_status("Select face(s) to inset", true, 2.2)
	}
}

editor_exec_fill :: proc() {
	ed := &app.editor
	fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
	edit.undo_push(&ed.undo, &ed.mesh)
	if edit.edit_fill(&ed.mesh, {fwd.x, fwd.y, fwd.z}) {
		editor_rebuild_preview_gpu()
		editor_set_status("Filled face", false, 1.8)
	} else {
		editor_set_status("Select 3 or 4 vertices to fill", true, 2.2)
	}
}

editor_exec_merge :: proc() {
	ed := &app.editor
	edit.undo_push(&ed.undo, &ed.mesh)
	if edit.edit_merge_center(&ed.mesh) {
		editor_rebuild_preview_gpu()
		editor_set_status("Merged selection at center", false, 2.0)
	} else {
		editor_set_status("Select 2+ vertices to merge", true, 2.2)
	}
}

editor_update_cursor :: proc() {
	ed := &app.editor
	next := rl.MouseCursor.DEFAULT
	if ed.confirm_exit_open || ed.delete_menu_open || ui_pointer_captured() {
		next = .DEFAULT
	} else if ed.cam_orbit_drag || ed.cam_pan_drag {
		next = .RESIZE_ALL
	} else if ed.modal_active && (ed.modal_op == .Knife || ed.modal_op == .Loop_Cut) {
		next = .CROSSHAIR
	} else if ed.tool == .Knife || ed.tool == .Box {
		next = .CROSSHAIR
	} else if ed.gizmo_hover >= 0 {
		next = .POINTING_HAND
	}
	if !app.cursor_initialized || next != app.last_cursor {
		rl.SetMouseCursor(next)
		app.last_cursor = next
		app.cursor_initialized = true
	}
}
