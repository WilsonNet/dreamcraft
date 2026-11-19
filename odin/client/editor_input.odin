// Model Picker & Model Editor mouse/UI click handling, selection picking, and cursors.
package main

import rl "vendor:raylib"
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
	in_vp := !ed.confirm_exit_open && !ed.delete_menu_open && rl.CheckCollisionPointRec(mouse, vp)
	if !ed.modal_active && !ed.box_active {
		editor_update_camera_input(mouse, in_vp)
	}
	update_editor_hover(mouse, in_vp)

	if ed.confirm_exit_open {
		handle_exit_dialog_click(mouse)
		handle_editor_hotkeys(mouse)
		return
	}
	if ed.delete_menu_open {
		handle_delete_popup_input(mouse)
		return
	}
	if ed.modal_active {
		update_active_modal(mouse)
		return
	}
	if input_left_pressed() {
		handle_editor_left_press(mouse, in_vp)
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
handle_editor_left_press :: proc(mouse: rl.Vector2, in_vp: bool) {
	ed := &app.editor
	if handle_topbar_click(mouse) { return }
	if handle_rail_click(mouse) { return }
	if handle_inspector_click(mouse) { return }
	if !in_vp { return }

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

@(private)
handle_topbar_click :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.editor
	tb := editor_topbar_rects()
	modes := [3]edit.Select_Mode{.Vertex, .Edge, .Face}
	for i in 0..<3 {
		if rl.CheckCollisionPointRec(mouse, tb.modes[i]) { edit.edit_mesh_set_mode(&ed.mesh, modes[i]); return true }
	}
	if rl.CheckCollisionPointRec(mouse, tb.undo) {
		if edit.undo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu() }
		return true
	}
	if rl.CheckCollisionPointRec(mouse, tb.redo) {
		if edit.redo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu() }
		return true
	}
	if rl.CheckCollisionPointRec(mouse, tb.mirror) { ed.mirror_x = !ed.mirror_x; return true }
	if rl.CheckCollisionPointRec(mouse, tb.wire) { ed.wire_overlay = !ed.wire_overlay; return true }
	if rl.CheckCollisionPointRec(mouse, tb.xray) { ed.xray_mode = !ed.xray_mode; return true }
	if rl.CheckCollisionPointRec(mouse, tb.floor_y) {
		edit.undo_push(&ed.undo, &ed.mesh)
		if edit.edit_snap_to_ground(&ed.mesh) { editor_rebuild_preview_gpu(); editor_set_status("Snapped min Y to ground (Y=0)", false, 2.0) }
		return true
	}
	if rl.CheckCollisionPointRec(mouse, tb.pose) {
		ed.pose_kind = Pose_Preview_Kind((int(ed.pose_kind) + 1) % 4)
		ed.pose_phase = 0
		return true
	}
	if rl.CheckCollisionPointRec(mouse, tb.team) {
		ed.preview_team = Unit_Preview_Palette((int(ed.preview_team) + 1) % 3)
		editor_rebuild_preview_gpu()
		return true
	}
	if rl.CheckCollisionPointRec(mouse, tb.shader) { ed.use_watercolor = !ed.use_watercolor; return true }
	if rl.CheckCollisionPointRec(mouse, tb.models) { editor_open_picker(); return true }
	if rl.CheckCollisionPointRec(mouse, tb.reset) { _ = editor_reset_to_procedural(); return true }
	if rl.CheckCollisionPointRec(mouse, tb.save) { _ = editor_save_and_hot_reload(); return true }
	if rl.CheckCollisionPointRec(mouse, tb.game) {
		if ed.mesh.dirty { ed.confirm_exit_open = true } else { editor_close_to_game() }
		return true
	}
	return false
}

@(private)
handle_rail_click :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.editor
	for i in 0..<12 {
		if !rl.CheckCollisionPointRec(mouse, editor_rail_button_rect(i)) { continue }
		switch i {
		case 0: ed.tool = .Select
		case 1: ed.tool = .Box
		case 2: editor_start_transform(.Grab, .None, mouse)
		case 3: editor_start_transform(.Rotate, .None, mouse)
		case 4: editor_start_transform(.Scale, .None, mouse)
		case 5: editor_exec_extrude(mouse)
		case 6: editor_exec_inset()
		case 7: editor_start_loop_cut()
		case 8: editor_start_knife()
		case 9: editor_exec_fill()
		case 10: editor_exec_merge()
		case 11: editor_open_delete_menu(mouse)
		}
		return true
	}
	return false
}

@(private)
handle_inspector_click :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.editor
	lay := editor_inspector_layout()
	if !rl.CheckCollisionPointRec(mouse, lay.panel) { return false }
	if rl.CheckCollisionPointRec(mouse, lay.smooth_btn) {
		edit.undo_push(&ed.undo, &ed.mesh)
		if edit.edit_set_selected_smooth(&ed.mesh, true) { editor_rebuild_preview_gpu(); editor_set_status("Marked selection smooth", false, 1.8) }
		return true
	}
	for m in 0..<int(art.Mat_Kind.COUNT) {
		if rl.CheckCollisionPointRec(mouse, editor_mat_swatch_rect(lay, m)) {
			ed.active_mat = art.Mat_Kind(m)
			edit.undo_push(&ed.undo, &ed.mesh)
			if edit.edit_set_selected_mat(&ed.mesh, ed.active_mat) { editor_rebuild_preview_gpu() }
			return true
		}
	}
	if ed.mesh.skinned {
		if rl.CheckCollisionPointRec(mouse, lay.bone_sel_btn) {
			edit.edit_mesh_select_same_bone(&ed.mesh, ed.active_bone)
			return true
		}
		for b in 0..<int(art.Bone_Id.COUNT) {
			if rl.CheckCollisionPointRec(mouse, editor_bone_row_rect(lay, b)) {
				ed.active_bone = art.Bone_Id(b)
				edit.undo_push(&ed.undo, &ed.mesh)
				_ = edit.edit_set_selected_bone(&ed.mesh, ed.active_bone)
				return true
			}
		}
	}
	return true
}

@(private)
handle_delete_popup_input :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	choice := -1
	if rl.IsKeyPressed(.ESCAPE) { ed.delete_menu_open = false; return }
	if rl.IsKeyPressed(.V) { choice = 0 }
	if rl.IsKeyPressed(.E) { choice = 1 }
	if rl.IsKeyPressed(.F) { choice = 2 }
	if rl.IsKeyPressed(.D) { choice = 3 }
	if choice < 0 && input_left_pressed() {
		for i in 0..<4 {
			if rl.CheckCollisionPointRec(mouse, editor_delete_item_rect(i)) { choice = i; break }
		}
		if choice < 0 { ed.delete_menu_open = false; return }
	}
	if choice < 0 { return }
	ed.delete_menu_open = false
	edit.undo_push(&ed.undo, &ed.mesh)
	ok := false
	switch choice {
	case 0: ok = edit.edit_delete_verts(&ed.mesh)
	case 1: ok = edit.edit_delete_edges(&ed.mesh)
	case 2: ok = edit.edit_delete_faces(&ed.mesh)
	case 3: ok = edit.edit_dissolve_edges(&ed.mesh)
	}
	if ok { editor_rebuild_preview_gpu() } else { editor_set_status("Nothing deleted", true, 1.8) }
}

@(private)
handle_exit_dialog_click :: proc(mouse: rl.Vector2) {
	if !input_left_pressed() { return }
	_, save_btn, discard_btn, cancel_btn := editor_exit_dialog_rects()
	if rl.CheckCollisionPointRec(mouse, save_btn) {
		_ = editor_save_and_hot_reload()
		editor_close_to_game()
	} else if rl.CheckCollisionPointRec(mouse, discard_btn) {
		editor_close_to_game()
	} else if rl.CheckCollisionPointRec(mouse, cancel_btn) {
		app.editor.confirm_exit_open = false
	}
}

editor_open_delete_menu :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	vp := editor_viewport_rect()
	ed.delete_menu_pos = {
		clamp(mouse.x, vp.x + 8, vp.x + vp.width - 168),
		clamp(mouse.y, vp.y + 8, vp.y + vp.height - 142),
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
	if ed.cam_orbit_drag || ed.cam_pan_drag {
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
