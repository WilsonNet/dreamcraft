// Blender-style modal operators (Grab/Rotate/Scale/Loop Cut/Knife) and hotkeys.
package main

import "core:fmt"
import "core:math"
import "core:strconv"
import rl "../gfx"
import edit "./art/edit"

handle_editor_hotkeys :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) || rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)

	if rl.IsKeyPressed(.ESCAPE) {
		if ed.confirm_exit_open {
			ed.confirm_exit_open = false
		} else if ed.delete_menu_open {
			ed.delete_menu_open = false
		} else if ed.mesh.dirty {
			ed.confirm_exit_open = true
		} else {
			editor_close_to_game()
		}
		return
	}
	if ed.confirm_exit_open { return }
	if ctrl && rl.IsKeyPressed(.S) {
		_ = editor_save_and_hot_reload()
		return
	}
	if ctrl && shift && rl.IsKeyPressed(.Z) {
		if edit.redo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu(); editor_set_status("Redo", false, 1.5) }
		return
	}
	if ctrl && rl.IsKeyPressed(.Z) {
		if edit.undo_step(&ed.undo, &ed.mesh) { editor_rebuild_preview_gpu(); editor_set_status("Undo", false, 1.5) }
		return
	}
	if ctrl && rl.IsKeyPressed(.R) {
		editor_start_loop_cut()
		return
	}
	if alt && rl.IsKeyPressed(.Z) {
		ed.xray_mode = !ed.xray_mode
		return
	}
	if alt && rl.IsKeyPressed(.M) {
		editor_exec_merge()
		return
	}
	handle_editor_plain_keys(mouse, shift, alt)
}

@(private)
handle_editor_plain_keys :: proc(mouse: rl.Vector2, shift, alt: bool) {
	ed := &app.editor
	if rl.IsKeyPressed(.ONE)   { edit.edit_mesh_set_mode(&ed.mesh, .Vertex); return }
	if rl.IsKeyPressed(.TWO)   { edit.edit_mesh_set_mode(&ed.mesh, .Edge); return }
	if rl.IsKeyPressed(.THREE) { edit.edit_mesh_set_mode(&ed.mesh, .Face); return }
	if rl.IsKeyPressed(.A) {
		if alt { edit.edit_mesh_deselect_all(&ed.mesh) } else { toggle_select_all() }
		return
	}
	if rl.IsKeyPressed(.I) && shift { edit.edit_mesh_invert_selection(&ed.mesh); return }
	if rl.IsKeyPressed(.L) {
		edit.edit_mesh_select_linked(&ed.mesh, ed.hover_vert)
		return
	}
	if rl.IsKeyPressed(.B) { ed.tool = .Box; return }
	if rl.IsKeyPressed(.G) { editor_start_transform(.Grab, .None, mouse); return }
	if rl.IsKeyPressed(.R) { editor_start_transform(.Rotate, .None, mouse); return }
	if rl.IsKeyPressed(.S) { editor_start_transform(.Scale, .None, mouse); return }
	if rl.IsKeyPressed(.E) { editor_exec_extrude(mouse); return }
	if rl.IsKeyPressed(.I) { editor_exec_inset(); return }
	if rl.IsKeyPressed(.K) { editor_start_knife(); return }
	if rl.IsKeyPressed(.F) { editor_exec_fill(); return }
	if rl.IsKeyPressed(.M) { editor_exec_merge(); return }
	if rl.IsKeyPressed(.X) || rl.IsKeyPressed(.DELETE) {
		editor_open_delete_menu(mouse)
		return
	}
	handle_editor_view_keys(shift)
}

@(private)
handle_editor_view_keys :: proc(shift: bool) {
	ed := &app.editor
	_ = shift
	if rl.IsKeyPressed(.KP_1) { editor_reset_camera(.Front) }
	if rl.IsKeyPressed(.KP_3) { editor_reset_camera(.Right) }
	if rl.IsKeyPressed(.KP_7) { editor_reset_camera(.Top) }
	if rl.IsKeyPressed(.KP_5) || rl.IsKeyPressed(.O) {
		ed.cam_ortho = !ed.cam_ortho
		editor_apply_camera()
	}
	if rl.IsKeyPressed(.PERIOD) || rl.IsKeyPressed(.KP_DECIMAL) {
		editor_frame_selection()
	}
}

@(private)
toggle_select_all :: proc() {
	ed := &app.editor
	v, e, f := edit.edit_mesh_selected_counts(&ed.mesh)
	if v + e + f > 0 {
		edit.edit_mesh_deselect_all(&ed.mesh)
	} else {
		edit.edit_mesh_select_all(&ed.mesh)
	}
}

editor_start_transform :: proc(op: Editor_Tool, lock: edit.Axis_Lock, mouse: rl.Vector2) {
	ed := &app.editor
	if !ed.mesh_loaded { return }
	pivot, ok := edit.edit_selection_center(&ed.mesh)
	if !ok {
		editor_set_status("Select vertices, edges, or faces first", true, 2.0)
		return
	}
	clear(&ed.base_pos)
	for v in ed.mesh.verts {
		append(&ed.base_pos, v.pos)
	}
	ed.pivot = pivot
	ed.tool = op
	ed.modal_active = true
	ed.modal_op = op
	ed.axis_lock = lock
	ed.modal_start_mouse = mouse
	ed.modal_delta = {}
	ed.modal_angle = 0
	ed.modal_scale = 1
	ed.num_len = 0
	ed.gizmo_drag_axis = lock == .X ? 0 : (lock == .Y ? 1 : (lock == .Z ? 2 : -1))
}

editor_start_loop_cut :: proc() {
	ed := &app.editor
	ed.tool = .Loop_Cut
	ed.modal_active = true
	ed.modal_op = .Loop_Cut
	ed.loop_cuts = clamp(ed.loop_cuts, 1, 6)
	ed.loop_slide = 0
	edit.loop_cut_preview_delete(&ed.loop_preview)
}

editor_start_knife :: proc() {
	ed := &app.editor
	ed.tool = .Knife
	ed.modal_active = true
	ed.modal_op = .Knife
	clear(&ed.knife_nodes)
}

update_active_modal :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	if rl.IsKeyPressed(.ESCAPE) || rl.IsMouseButtonPressed(.RIGHT) {
		cancel_active_modal()
		return
	}
	switch ed.modal_op {
	case .Grab, .Rotate, .Scale:
		update_transform_modal(mouse)
	case .Loop_Cut:
		update_loop_cut_modal(mouse)
	case .Knife:
		update_knife_modal(mouse)
	case .Select, .Box, .Extrude, .Inset, .Fill, .Merge:
		ed.modal_active = false
	}
}

@(private)
cancel_active_modal :: proc() {
	ed := &app.editor
	if ed.modal_op == .Grab || ed.modal_op == .Rotate || ed.modal_op == .Scale {
		for p, i in ed.base_pos {
			if i < len(ed.mesh.verts) { ed.mesh.verts[i].pos = p }
		}
		edit.edit_mesh_update_normals(&ed.mesh)
		ed.preview_dirty_gpu = true
	}
	edit.loop_cut_preview_delete(&ed.loop_preview)
	clear(&ed.knife_nodes)
	ed.modal_active = false
	ed.gizmo_drag_axis = -1
	ed.tool = .Select
}

@(private)
update_transform_modal :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	handle_axis_lock_keys()
	handle_numeric_keys()
	apply_modal_transform(mouse)

	confirm := rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) ||
		(ed.gizmo_drag_axis >= 0 ? input_left_released() : input_left_pressed())
	if confirm {
		finalize_transform_modal()
	}
}

@(private)
handle_axis_lock_keys :: proc() {
	ed := &app.editor
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if rl.IsKeyPressed(.X) {
		next := shift ? edit.Axis_Lock.YZ : edit.Axis_Lock.X
		ed.axis_lock = ed.axis_lock == next ? .None : next
	}
	if rl.IsKeyPressed(.Y) {
		next := shift ? edit.Axis_Lock.XZ : edit.Axis_Lock.Y
		ed.axis_lock = ed.axis_lock == next ? .None : next
	}
	if rl.IsKeyPressed(.Z) {
		next := shift ? edit.Axis_Lock.XY : edit.Axis_Lock.Z
		ed.axis_lock = ed.axis_lock == next ? .None : next
	}
}

@(private)
handle_numeric_keys :: proc() {
	ed := &app.editor
	for {
		ch := rl.GetCharPressed()
		if ch == 0 { break }
		valid := (ch >= '0' && ch <= '9') || ch == '.' || ch == '-'
		if valid && ed.num_len < len(ed.num_buf) - 1 {
			ed.num_buf[ed.num_len] = u8(ch)
			ed.num_len += 1
		}
	}
	if rl.IsKeyPressed(.BACKSPACE) && ed.num_len > 0 {
		ed.num_len -= 1
	}
}

@(private)
apply_modal_transform :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	num_val, has_num := parse_modal_number()
	dpx := mouse - ed.modal_start_mouse
	if ed.modal_op == .Grab {
		world := compute_grab_delta(dpx, has_num, num_val, ctrl)
		ed.modal_delta = world
		edit.edit_translate_from_base(&ed.mesh, ed.base_pos[:], world, ed.axis_lock, ed.mirror_x)
	} else if ed.modal_op == .Rotate {
		ang := has_num ? num_val * math.PI / 180.0 : dpx.x * 0.012
		if ctrl { ang = math.round(ang / (5.0 * math.PI / 180.0)) * (5.0 * math.PI / 180.0) }
		ed.modal_angle = ang
		axis := rotate_axis_vec(ed.axis_lock, ed.camera)
		edit.edit_rotate_from_base(&ed.mesh, ed.base_pos[:], ed.pivot, axis, ang, ed.mirror_x)
	} else if ed.modal_op == .Scale {
		s := has_num ? num_val : clamp(1.0 + (dpx.x - dpx.y) * 0.006, 0.05, 8.0)
		if ctrl { s = math.round(s * 10.0) * 0.1 }
		ed.modal_scale = s
		edit.edit_scale_from_base(&ed.mesh, ed.base_pos[:], ed.pivot, s, ed.axis_lock, ed.mirror_x)
	}
	ed.preview_dirty_gpu = true
}

@(private)
compute_grab_delta :: proc(dpx: rl.Vector2, has_num: bool, num_val: f32, ctrl: bool) -> [3]f32 {
	ed := &app.editor
	if has_num {
		v := num_val
		if ctrl { v = math.round(v * 20.0) * 0.05 }
		switch ed.axis_lock {
		case .Y: return {0, v, 0}
		case .Z: return {0, 0, v}
		case .None, .X, .YZ, .XZ, .XY: return {v, 0, 0}
		}
	}
	wpp := editor_world_per_px()
	fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
	right := rl.Vector3Normalize(rl.Vector3CrossProduct(fwd, {0, 1, 0}))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, fwd))
	delta := right * (dpx.x * wpp) - cam_up * (dpx.y * wpp)
	if ctrl {
		return {math.round(delta.x * 20.0) * 0.05, math.round(delta.y * 20.0) * 0.05, math.round(delta.z * 20.0) * 0.05}
	}
	return {delta.x, delta.y, delta.z}
}

@(private)
rotate_axis_vec :: proc(lock: edit.Axis_Lock, cam: rl.Camera3D) -> [3]f32 {
	switch lock {
	case .X: return {1, 0, 0}
	case .Y: return {0, 1, 0}
	case .Z: return {0, 0, 1}
	case .None, .YZ, .XZ, .XY:
		fwd := rl.Vector3Normalize(cam.target - cam.position)
		return {fwd.x, fwd.y, fwd.z}
	}
	return {0, 1, 0}
}

@(private)
parse_modal_number :: proc() -> (f32, bool) {
	ed := &app.editor
	if ed.num_len == 0 { return 0, false }
	val, ok := strconv.parse_f32(string(ed.num_buf[:ed.num_len]))
	return val, ok
}

@(private)
finalize_transform_modal :: proc() {
	ed := &app.editor
	snapshot := make([]edit.Edit_Vert, len(ed.mesh.verts), context.temp_allocator)
	copy(snapshot, ed.mesh.verts[:])
	for p, i in ed.base_pos {
		if i < len(ed.mesh.verts) { ed.mesh.verts[i].pos = p }
	}
	edit.undo_push(&ed.undo, &ed.mesh)
	copy(ed.mesh.verts[:], snapshot)
	ed.mesh.dirty = true
	edit.edit_mesh_update_normals(&ed.mesh)
	editor_rebuild_preview_gpu()
	ed.modal_active = false
	ed.gizmo_drag_axis = -1
	ed.tool = .Select
}

@(private)
update_loop_cut_modal :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	if wheel := input_wheel_y(); wheel != 0 {
		ed.loop_cuts = clamp(ed.loop_cuts + (wheel > 0 ? 1 : -1), 1, 6)
	}
	if ei, _, ok := editor_pick_edge(mouse, 14.0); ok {
		if !ed.loop_preview.valid || ed.hover_edge != ei {
			edit.loop_cut_preview_delete(&ed.loop_preview)
			ed.loop_preview = edit.edit_preview_loop_cut(&ed.mesh, ei)
		}
		ed.hover_edge = ei
		if input_left_pressed() && ed.loop_preview.valid {
			edit.undo_push(&ed.undo, &ed.mesh)
			if edit.edit_apply_loop_cut(&ed.mesh, ei, ed.loop_cuts, ed.loop_slide) {
				editor_rebuild_preview_gpu()
				editor_set_status(fmt.tprintf("Added %d loop cut(s)", ed.loop_cuts), false, 2.0)
			}
			edit.loop_cut_preview_delete(&ed.loop_preview)
			ed.modal_active = false
			ed.tool = .Select
		}
	}
}

@(private)
update_knife_modal :: proc(mouse: rl.Vector2) {
	ed := &app.editor
	ed.knife_hover, ed.knife_has_hover = editor_pick_knife_node(mouse)
	if input_left_pressed() && rl.CheckCollisionPointRec(mouse, editor_viewport_rect()) && ed.knife_has_hover {
		append(&ed.knife_nodes, ed.knife_hover)
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) || rl.IsKeyPressed(.SPACE) {
		if len(ed.knife_nodes) >= 2 {
			edit.undo_push(&ed.undo, &ed.mesh)
			if edit.edit_apply_knife(&ed.mesh, ed.knife_nodes[:]) {
				editor_rebuild_preview_gpu()
				editor_set_status("Knife cut applied", false, 2.0)
			} else {
				editor_set_status("Knife points must share faces", true, 2.4)
			}
		}
		clear(&ed.knife_nodes)
		ed.modal_active = false
		ed.tool = .Select
	}
}
