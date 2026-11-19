// Model Picker and Model Editor 2D workshop UI chrome and shared layout rectangles.
package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import art "./art"
import edit "./art/edit"
import spec "./art/spec"

@(private)
COL_CHROME_BG :: rl.Color{16, 23, 18, 244}
@(private)
COL_CHROME_LINE :: rl.Color{66, 98, 70, 230}
@(private)
COL_BTN_BG :: rl.Color{32, 46, 35, 255}
@(private)
COL_BTN_HOVER :: rl.Color{50, 72, 54, 255}
@(private)
COL_BTN_ACTIVE :: rl.Color{136, 102, 28, 255}
@(private)
COL_BTN_PRIMARY :: rl.Color{56, 104, 58, 255}
@(private)
COL_TEXT_DIM :: rl.Color{162, 182, 165, 255}
@(private)
COL_TEXT_GOLD :: rl.Color{240, 212, 118, 255}

Topbar_Rects :: struct {
	modes:   [3]rl.Rectangle,
	undo:    rl.Rectangle,
	redo:    rl.Rectangle,
	mirror:  rl.Rectangle,
	wire:    rl.Rectangle,
	xray:    rl.Rectangle,
	floor_y: rl.Rectangle,
	pose:    rl.Rectangle,
	team:    rl.Rectangle,
	shader:  rl.Rectangle,
	help:    rl.Rectangle,
	models:  rl.Rectangle,
	reset:   rl.Rectangle,
	save:    rl.Rectangle,
	game:    rl.Rectangle,
}

Inspector_Layout :: struct {
	panel:        rl.Rectangle,
	smooth_btn:   rl.Rectangle,
	mat_origin:   [2]f32,
	mat_cell:     f32,
	mat_cols:     int,
	bone_sel_btn: rl.Rectangle,
	bone_origin:  [2]f32,
	bone_w:       f32,
	bone_h:       f32,
}

editor_topbar_rects :: proc() -> Topbar_Rects {
	w := f32(rl.GetScreenWidth())
	r: Topbar_Rects
	x := f32(116)
	for i in 0..<3 {
		r.modes[i] = {x, 8, 42, 28}
		x += 44
	}
	x += 8
	r.undo = {x, 8, 30, 28}; x += 32
	r.redo = {x, 8, 30, 28}; x += 38
	r.mirror = {x, 8, 52, 28}; x += 54
	r.wire = {x, 8, 52, 28}; x += 54
	r.xray = {x, 8, 52, 28}; x += 54
	r.floor_y = {x, 8, 48, 28}; x += 54
	r.pose = {x, 8, 86, 28}; x += 88
	r.team = {x, 8, 64, 28}; x += 66
	r.shader = {x, 8, 50, 28}

	rx := w - 8
	r.game = {rx - 70, 8, 70, 28}; rx -= 76
	r.save = {rx - 72, 8, 72, 28}; rx -= 78
	r.reset = {rx - 68, 8, 68, 28}; rx -= 74
	r.models = {rx - 76, 8, 76, 28}; rx -= 82
	r.help = {rx - 44, 8, 44, 28}
	return r
}

editor_rail_button_rect :: proc(idx: int) -> rl.Rectangle {
	h := f32(rl.GetScreenHeight())
	avail := max(h - EDITOR_TOPBAR_H - EDITOR_STATUS_H - 12, 360)
	step := clamp(avail / 12.0, 30.0, 38.0)
	return rl.Rectangle{6, EDITOR_TOPBAR_H + 8 + f32(idx) * step, EDITOR_LEFT_W - 12, step - 4}
}

editor_inspector_layout :: proc() -> Inspector_Layout {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	px := w - EDITOR_RIGHT_W
	py := EDITOR_TOPBAR_H
	bone_top := f32(280)
	bone_avail := max(h - py - EDITOR_STATUS_H - bone_top - 8, 180)
	bone_h := clamp(bone_avail / 13.0, 16.0, 22.0)
	return Inspector_Layout{
		panel        = {px, py, EDITOR_RIGHT_W, h - EDITOR_TOPBAR_H - EDITOR_STATUS_H},
		smooth_btn   = {px + EDITOR_RIGHT_W - 96, py + 72, 84, 22},
		mat_origin   = {px + 12, py + 122},
		mat_cell     = 28,
		mat_cols     = 8,
		bone_sel_btn = {px + EDITOR_RIGHT_W - 92, py + 252, 80, 20},
		bone_origin  = {px + 12, py + bone_top},
		bone_w       = 121,
		bone_h       = bone_h,
	}
}

editor_mat_swatch_rect :: proc(lay: Inspector_Layout, mat_idx: int) -> rl.Rectangle {
	col := mat_idx % lay.mat_cols
	row := mat_idx / lay.mat_cols
	return {lay.mat_origin.x + f32(col) * 31, lay.mat_origin.y + f32(row) * lay.mat_cell, 27, lay.mat_cell - 4}
}

editor_bone_row_rect :: proc(lay: Inspector_Layout, bone_idx: int) -> rl.Rectangle {
	col := bone_idx % 2
	row := bone_idx / 2
	return {lay.bone_origin.x + f32(col) * 125, lay.bone_origin.y + f32(row) * lay.bone_h, lay.bone_w, lay.bone_h - 2}
}

editor_delete_item_rect :: proc(idx: int) -> rl.Rectangle {
	pos := app.editor.delete_menu_pos
	return {pos.x + 6, pos.y + 24 + f32(idx) * 26, 148, 22}
}

editor_exit_dialog_rects :: proc() -> (panel, save_btn, discard_btn, cancel_btn: rl.Rectangle) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	panel = {w * 0.5 - 190, h * 0.5 - 75, 380, 150}
	save_btn = {panel.x + 18, panel.y + 98, 120, 32}
	discard_btn = {panel.x + 148, panel.y + 98, 102, 32}
	cancel_btn = {panel.x + 260, panel.y + 98, 102, 32}
	return
}

draw_editor_ui :: proc() {
	draw_editor_topbar()
	draw_editor_tool_rail()
	draw_editor_inspector()
	draw_editor_statusbar()
	if app.editor.delete_menu_open {
		draw_editor_delete_popup()
	}
	if app.editor.confirm_exit_open {
		draw_editor_exit_dialog()
	}
}

@(private)
draw_editor_topbar :: proc() {
	ed := &app.editor
	w := f32(rl.GetScreenWidth())
	rl.DrawRectangleRec({0, 0, w, EDITOR_TOPBAR_H}, COL_CHROME_BG)
	rl.DrawLineV({0, EDITOR_TOPBAR_H}, {w, EDITOR_TOPBAR_H}, COL_CHROME_LINE)
	star := ed.mesh.dirty ? "*" : ""
	rl.DrawText(cstring_t(fmt.tprintf("%s%s", ed.mesh.id, star)), 12, 13, 15, COL_TEXT_GOLD)

	tb := editor_topbar_rects()
	draw_ui_button(tb.modes[0], "1:V", ed.mesh.mode == .Vertex, false, .Mode_Vert)
	draw_ui_button(tb.modes[1], "2:E", ed.mesh.mode == .Edge, false, .Mode_Edge)
	draw_ui_button(tb.modes[2], "3:F", ed.mesh.mode == .Face, false, .Mode_Face)
	draw_ui_button(tb.undo, "", false, false, .Undo)
	draw_ui_button(tb.redo, "", false, false, .Redo)
	draw_ui_button(tb.mirror, "Mir", ed.mirror_x, false, .Mirror_X)
	draw_ui_button(tb.wire, "Wire", ed.wire_overlay, false, .Wireframe)
	draw_ui_button(tb.xray, "XRay", ed.xray_mode, false, .XRay)
	draw_ui_button(tb.floor_y, "Y=0", false, false, .Floor_Y)
	draw_ui_button(tb.pose, editor_pose_label(ed.pose_kind), ed.pose_kind != .Rest, false, .Pose)
	draw_ui_button(tb.team, editor_team_label(ed.preview_team), false, false, .Team_Palette)
	draw_ui_button(tb.shader, ed.use_watercolor ? "WC" : "Lit", ed.use_watercolor, false, .Shader_WC)
	draw_ui_button(tb.help, "? F1", app.help_open)
	draw_ui_button(tb.models, "Models", false, false, .Models)
	draw_ui_button(tb.reset, "Reset", false, false, .Reset)
	draw_ui_button(tb.save, ed.mesh.dirty ? "Save*" : "Save", false, true, .Save)
	draw_ui_button(tb.game, "Game", false, false, .Game)
}

@(private)
draw_editor_tool_rail :: proc() {
	ed := &app.editor
	h := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec({0, EDITOR_TOPBAR_H, EDITOR_LEFT_W, h - EDITOR_TOPBAR_H - EDITOR_STATUS_H}, COL_CHROME_BG)
	rl.DrawLineV({EDITOR_LEFT_W, EDITOR_TOPBAR_H}, {EDITOR_LEFT_W, h - EDITOR_STATUS_H}, COL_CHROME_LINE)
	labels := [12]cstring{"Sel", "Box", "Grab", "Rot", "Scl", "Extr", "Ins", "Loop", "Knf", "Fill", "Mrg", "Del"}
	icons := [12]Icon_Id{
		.Tool_Select, .Tool_Box, .Tool_Grab, .Tool_Rotate, .Tool_Scale, .Tool_Extrude,
		.Tool_Inset, .Tool_Loop_Cut, .Tool_Knife, .Tool_Fill, .Tool_Merge, .Tool_Delete,
	}
	for i in 0..<12 {
		active := (i < 11 && int(ed.tool) == i) || (i == 11 && ed.delete_menu_open)
		draw_ui_button(editor_rail_button_rect(i), labels[i], active, false, icons[i])
	}
}

@(private)
draw_editor_inspector :: proc() {
	ed := &app.editor
	lay := editor_inspector_layout()
	rl.DrawRectangleRec(lay.panel, COL_CHROME_BG)
	rl.DrawLineV({lay.panel.x, lay.panel.y}, {lay.panel.x, lay.panel.y + lay.panel.height}, COL_CHROME_LINE)
	sv, se, sf := edit.edit_mesh_selected_counts(&ed.mesh)
	x := i32(lay.panel.x + 12)
	y := i32(lay.panel.y + 10)
	rl.DrawText("MESH TELEMETRY", x, y, 12, COL_TEXT_GOLD)
	rl.DrawText(cstring_t(fmt.tprintf("V %d  E %d  F %d", len(ed.mesh.verts), len(ed.mesh.edges), len(ed.mesh.faces))), x, y + 18, 12, rl.WHITE)
	rl.DrawText(cstring_t(fmt.tprintf("Sel V:%d E:%d F:%d", sv, se, sf)), x, y + 36, 12, COL_TEXT_DIM)
	if c, ok := edit.edit_selection_center(&ed.mesh); ok {
		rl.DrawText(cstring_t(fmt.tprintf("Ctr %.2f %.2f %.2f", c[0], c[1], c[2])), x, y + 54, 11, COL_TEXT_DIM)
	} else {
		rl.DrawText("Ctr (no selection)", x, y + 54, 11, COL_TEXT_DIM)
	}
	draw_ui_button(lay.smooth_btn, "Smooth", false)

	rl.DrawText(cstring_t(fmt.tprintf("MATERIAL: %s", spec.MAT_NAMES[ed.active_mat])), x, i32(lay.mat_origin.y - 18), 12, COL_TEXT_GOLD)
	draw_mat_swatches(lay)
	if ed.mesh.skinned {
		rl.DrawText(cstring_t(fmt.tprintf("BONE: %s", spec.BONE_NAMES[ed.active_bone])), x, i32(lay.bone_sel_btn.y + 3), 12, COL_TEXT_GOLD)
		draw_ui_button(lay.bone_sel_btn, "Sel Bone", false)
		draw_bone_buttons(lay)
	}
}

@(private)
draw_mat_swatches :: proc(lay: Inspector_Layout) {
	ed := &app.editor
	mouse := input_mouse_pos()
	mat_count := int(art.Mat_Kind.COUNT)
	for m in 0..<mat_count {
		rect := editor_mat_swatch_rect(lay, m)
		kind := art.Mat_Kind(m)
		col := art.MAT_DEFS[kind].albedo
		rl.DrawRectangleRec(rect, col)
		border := kind == ed.active_mat ? rl.Color{255, 224, 96, 255} : rl.Color{40, 48, 42, 255}
		if rl.CheckCollisionPointRec(mouse, rect) { border = rl.WHITE }
		rl.DrawRectangleLinesEx(rect, kind == ed.active_mat ? 2 : 1, border)
	}
}

@(private)
draw_bone_buttons :: proc(lay: Inspector_Layout) {
	ed := &app.editor
	bone_count := int(art.Bone_Id.COUNT)
	for b in 0..<bone_count {
		bone := art.Bone_Id(b)
		draw_ui_button(editor_bone_row_rect(lay, b), cstring_t(spec.BONE_NAMES[bone]), bone == ed.active_bone)
	}
}

@(private)
draw_editor_statusbar :: proc() {
	ed := &app.editor
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	y := h - EDITOR_STATUS_H
	rl.DrawRectangleRec({0, y, w, EDITOR_STATUS_H}, rl.Color{11, 16, 12, 248})
	rl.DrawLineV({0, y}, {w, y}, COL_CHROME_LINE)
	msg := editor_modal_status_text()
	col := ed.status_is_error ? rl.Color{245, 98, 86, 255} : COL_TEXT_GOLD
	if len(msg) == 0 {
		msg = editor_status_cstr()
	} else {
		col = rl.Color{135, 232, 255, 255}
	}
	if len(msg) > 0 {
		rl.DrawText(msg, 12, i32(y + 7), 12, col)
	}
	hints := cstring("F1 Help | G/R/S+X/Y/Z | E Extrude | I Inset | ^R Loop | K Knife | M Merge | X Del | Alt+Click Loop | MMB/RMB Orbit | . Frame")
	hw := rl.MeasureText(hints, 11)
	if w > 900 {
		rl.DrawText(hints, i32(w) - hw - 12, i32(y + 8), 11, COL_TEXT_DIM)
	}
}

@(private)
editor_modal_status_text :: proc() -> cstring {
	ed := &app.editor
	if !ed.modal_active { return "" }
	num := ed.num_len > 0 ? string(ed.num_buf[:ed.num_len]) : ""
	axis := ed.axis_lock != .None ? fmt.tprintf(" [%v]", ed.axis_lock) : ""
	switch ed.modal_op {
	case .Grab:     return cstring_t(fmt.tprintf("Grab%s (%.3f %.3f %.3f) %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_delta[0], ed.modal_delta[1], ed.modal_delta[2], num))
	case .Rotate:   return cstring_t(fmt.tprintf("Rotate%s %.1f deg %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_angle * 57.2958, num))
	case .Scale:    return cstring_t(fmt.tprintf("Scale%s %.3fx %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_scale, num))
	case .Inset:    return cstring_t(fmt.tprintf("Inset face | Move mouse / LMB confirm"))
	case .Loop_Cut: return cstring_t(fmt.tprintf("Loop Cut (%d cuts) | Wheel cuts, LMB apply, Esc cancel", ed.loop_cuts))
	case .Knife:    return cstring_t(fmt.tprintf("Knife (%d nodes) | LMB point, Enter/Space cut, Esc cancel", len(ed.knife_nodes)))
	case .Select, .Box, .Extrude, .Fill, .Merge:
	}
	return ""
}

@(private)
draw_editor_delete_popup :: proc() {
	pos := app.editor.delete_menu_pos
	box := rl.Rectangle{pos.x, pos.y, 160, 134}
	rl.DrawRectangleRec(box, COL_CHROME_BG)
	rl.DrawRectangleLinesEx(box, 1, COL_TEXT_GOLD)
	rl.DrawText("DELETE", i32(box.x + 8), i32(box.y + 6), 11, COL_TEXT_GOLD)
	labels := [4]cstring{"[V] Vertices", "[E] Edges", "[F] Faces", "[D] Dissolve Edges"}
	for i in 0..<4 {
		draw_ui_button(editor_delete_item_rect(i), labels[i], false)
	}
}

@(private)
draw_editor_exit_dialog :: proc() {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	rl.DrawRectangleRec({0, 0, w, h}, rl.Color{0, 0, 0, 155})
	panel, save_btn, discard_btn, cancel_btn := editor_exit_dialog_rects()
	rl.DrawRectangleRec(panel, COL_CHROME_BG)
	rl.DrawRectangleLinesEx(panel, 2, COL_TEXT_GOLD)
	rl.DrawText("UNSAVED MESH CHANGES", i32(panel.x + 20), i32(panel.y + 20), 16, COL_TEXT_GOLD)
	rl.DrawText(cstring_t(fmt.tprintf("Save edits to %s/*.odin before leaving?", app.editor.mesh.id)), i32(panel.x + 20), i32(panel.y + 52), 13, rl.WHITE)
	draw_ui_button(save_btn, "Save & Exit", false, true)
	draw_ui_button(discard_btn, "Discard", false)
	draw_ui_button(cancel_btn, "Cancel", false)
}

@(private)
draw_ui_button :: proc(rect: rl.Rectangle, label: cstring, active: bool, primary := false, icon := Icon_Id.None) {
	hover := rl.CheckCollisionPointRec(input_mouse_pos(), rect)
	col := primary ? COL_BTN_PRIMARY : COL_BTN_BG
	if hover { col = COL_BTN_HOVER }
	if active { col = COL_BTN_ACTIVE }
	rl.DrawRectangleRec(rect, col)
	rl.DrawRectangleLinesEx(rect, 1, active ? COL_TEXT_GOLD : COL_CHROME_LINE)
	fs := i32(rect.height >= 30 ? 13 : 11)
	if len(label) == 0 && icon != .None {
		isz := min(rect.width - 8, rect.height - 6)
		draw_icon_centered(icon, rect.x + rect.width * 0.5, rect.y + rect.height * 0.5, isz)
		return
	}
	if icon != .None {
		isz := min(f32(16), rect.height - 8)
		ix := rect.x + 6 + isz * 0.5
		draw_icon_centered(icon, ix, rect.y + rect.height * 0.5, isz)
		tw := rl.MeasureText(label, fs)
		tx := max(i32(rect.x + 8 + isz), i32(rect.x + isz + (rect.width - isz) * 0.5) - tw / 2)
		rl.DrawText(label, tx, i32(rect.y + (rect.height - f32(fs)) * 0.5), fs, rl.WHITE)
		return
	}
	tw := rl.MeasureText(label, fs)
	rl.DrawText(label, i32(rect.x + rect.width * 0.5) - tw / 2, i32(rect.y + (rect.height - f32(fs)) * 0.5), fs, rl.WHITE)
}

@(private)
editor_pose_label :: proc(p: Pose_Preview_Kind) -> cstring {
	switch p {
	case .Rest:   return "Pose:Rest"
	case .Idle:   return "Pose:Idle"
	case .Walk:   return "Pose:Walk"
	case .Attack: return "Pose:Atk"
	}
	return "Pose:Rest"
}

@(private)
editor_team_label :: proc(t: Unit_Preview_Palette) -> cstring {
	switch t {
	case .Hero:   return "Hero"
	case .Player: return "Unit"
	case .Enemy:  return "Enemy"
	}
	return "Hero"
}

@(private)
cstring_t :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}
