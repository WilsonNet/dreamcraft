// Model Editor Quickshell UI chrome: Topbar, Tool Rail, Inspector cards, Statusbar, and Popups.
package main

import "core:fmt"
import "core:strings"
import art "./art"
import edit "./art/edit"
import spec "./art/spec"
import ui "../ui"

compose_model_editor :: proc(ctx: ^ui.Context, w, h: f32) {
	compose_editor_topbar(ctx, w)
	compose_editor_tool_rail(ctx, h)
	compose_editor_inspector(ctx, w, h)
	compose_editor_statusbar(ctx, w, h)
	if app.editor.delete_menu_open {
		compose_editor_delete_popup(ctx)
	}
	if app.editor.confirm_exit_open {
		compose_editor_exit_dialog(ctx)
	}
}

@(private)
compose_editor_topbar :: proc(ctx: ^ui.Context, w: f32) {
	compact := w < 1180
	tm := ui.m_blocks(ui.m_pad_xy(ui.m_gap(ui.m_align(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), 0, 0), w, EDITOR_TOPBAR_H), ui.style_bar()), .Center), compact ? 4 : 6), 10, 6))
	tm.layer = 1
	ui.open_row(ctx, ui.id("ed_topbar"), tm)
	compose_topbar_left(ctx, compact)
	ui.spacer(ctx, 1)
	compose_topbar_right(ctx, compact)
	ui.close(ctx)
}

@(private)
compose_topbar_left :: proc(ctx: ^ui.Context, compact: bool) {
	ed := &app.editor
	star := ed.mesh.dirty ? "*" : ""
	id_txt := compact && len(ed.mesh.id) > 10 ? fmt.tprintf("%s..%s", ed.mesh.id[:8], star) : fmt.tprintf("%s%s", ed.mesh.id, star)
	ui.badge(ctx, ui.id("ed_model_badge"), ui_cstr(id_txt), ed.mesh.dirty ? .Gold : .Neutral, ui.m_pad_xy(ui.mod(), 8, 4))

	mode_m := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_h(ui.mod(), 30), ui.style_pill_track()), 2), 3)
	ui.open_row(ctx, ui.id("ed_mode_track"), mode_m)
	modes := [3]cstring{"1:V", "2:E", "3:F"}
	m_icons := [3]Icon_Id{.Mode_Vert, .Mode_Edge, .Mode_Face}
	for i in 0..<3 {
		ui.segmented_tab(ctx, ui.id_idx("ed_mode", i), modes[i], icon_texture(m_icons[i]), int(ed.mesh.mode) == i, u32(UI_Msg.Ed_Mode), i32(i), ui.m_pad_xy(ui.m_h(ui.mod(), 24), compact ? 5 : 7, 2))
	}
	ui.close(ctx)

	ui.button(ctx, ui.id("ed_undo"), ui.Button_Opts{icon_tex = icon_texture(.Undo), icon_size = 16, variant = .Compact, msg_tag = u32(UI_Msg.Ed_Undo)}, ui.m_size(ui.m_pad(ui.mod(), 4), 28, 28))
	ui.button(ctx, ui.id("ed_redo"), ui.Button_Opts{icon_tex = icon_texture(.Redo), icon_size = 16, variant = .Compact, msg_tag = u32(UI_Msg.Ed_Redo)}, ui.m_size(ui.m_pad(ui.mod(), 4), 28, 28))

	compose_topbar_toggles(ctx, compact)
}

@(private)
compose_topbar_toggles :: proc(ctx: ^ui.Context, compact: bool) {
	ed := &app.editor
	bm := ui.m_h(ui.m_pad_xy(ui.mod(), compact ? 6 : 8, 3), 28)
	ui.button(ctx, ui.id("ed_mir"), ui.Button_Opts{label = "Mir", icon_tex = icon_texture(.Mirror_X), variant = .Compact, active = ed.mirror_x, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Mirror)}, bm)
	ui.button(ctx, ui.id("ed_wire"), ui.Button_Opts{label = compact ? "Wir" : "Wire", icon_tex = icon_texture(.Wireframe), variant = .Compact, active = ed.wire_overlay, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Wire)}, bm)
	ui.button(ctx, ui.id("ed_xray"), ui.Button_Opts{label = compact ? "XR" : "XRay", icon_tex = icon_texture(.XRay), variant = .Compact, active = ed.xray_mode, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_XRay)}, bm)
	ui.button(ctx, ui.id("ed_floory"), ui.Button_Opts{label = "Y=0", icon_tex = icon_texture(.Floor_Y), variant = .Compact, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Floor_Y)}, bm)
	if ed.mesh.skinned {
		ui.button(ctx, ui.id("ed_pose"), ui.Button_Opts{label = editor_pose_short_label(ed.pose_kind, compact), icon_tex = icon_texture(.Pose), variant = .Compact, active = ed.pose_kind != .Rest, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Pose)}, bm)
		ui.button(ctx, ui.id("ed_team"), ui.Button_Opts{label = editor_team_label(ed.preview_team), icon_tex = icon_texture(.Team_Palette), variant = .Compact, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Team)}, bm)
	}
	ui.button(ctx, ui.id("ed_shader"), ui.Button_Opts{label = ed.use_watercolor ? "WC" : "Lit", icon_tex = icon_texture(.Shader_WC), variant = .Compact, active = ed.use_watercolor, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Shader)}, bm)
}

@(private)
compose_topbar_right :: proc(ctx: ^ui.Context, compact: bool) {
	ed := &app.editor
	bm := ui.m_h(ui.m_pad_xy(ui.mod(), compact ? 7 : 9, 3), 28)
	compose_help_badge_widget(ctx, 1)
	ui.button(ctx, ui.id("ed_models"), ui.Button_Opts{label = compact ? "List" : "Models", icon_tex = icon_texture(.Models), variant = .Tonal, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Models)}, bm)
	ui.button(ctx, ui.id("ed_reset"), ui.Button_Opts{label = compact ? "Rst" : "Reset", icon_tex = icon_texture(.Reset), variant = .Compact, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Reset)}, bm)
	ui.button(ctx, ui.id("ed_save"), ui.Button_Opts{label = ed.mesh.dirty ? "Save*" : "Save", icon_tex = icon_texture(.Save), variant = .Primary, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Save)}, bm)
	ui.button(ctx, ui.id("ed_game"), ui.Button_Opts{label = "Game", icon_tex = icon_texture(.Game), variant = .Tonal, font_size = 11.5, msg_tag = u32(UI_Msg.Ed_Game)}, bm)
}

@(private)
compose_editor_tool_rail :: proc(ctx: ^ui.Context, h: f32) {
	ed := &app.editor
	rm := ui.m_blocks(ui.m_pad(ui.m_gap(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), 0, EDITOR_TOPBAR_H), EDITOR_LEFT_W, h - EDITOR_TOPBAR_H - EDITOR_STATUS_H), ui.style_bar()), 4), 6))
	rm.layer = 1
	ui.open_col(ctx, ui.id("ed_rail"), rm)
	labels := [12]cstring{"Sel", "Box", "Grab", "Rot", "Scl", "Extr", "Ins", "Loop", "Knf", "Fill", "Mrg", "Del"}
	icons := [12]Icon_Id{
		.Tool_Select, .Tool_Box, .Tool_Grab, .Tool_Rotate, .Tool_Scale, .Tool_Extrude,
		.Tool_Inset, .Tool_Loop_Cut, .Tool_Knife, .Tool_Fill, .Tool_Merge, .Tool_Delete,
	}
	for i in 0..<12 {
		active := (i < 11 && int(ed.tool) == i) || (i == 11 && ed.delete_menu_open)
		tm := ui.m_pad_xy(ui.m_fill(ui.m_weight(ui.mod(), 1), true, false), 8, 2)
		tm.max_h = 38
		ui.button(ctx, ui.id_idx("ed_tool", i), ui.Button_Opts{label = labels[i], icon_tex = icon_texture(icons[i]), icon_size = 15, variant = .Tool, active = active, font_size = 12, msg_tag = u32(UI_Msg.Ed_Tool), msg_arg = i32(i)}, tm)
	}
	ui.close(ctx)
}

@(private)
compose_editor_inspector :: proc(ctx: ^ui.Context, w, h: f32) {
	ed := &app.editor
	ih := h - EDITOR_TOPBAR_H - EDITOR_STATUS_H
	im := ui.m_blocks(ui.m_pad(ui.m_gap(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), w - EDITOR_RIGHT_W, EDITOR_TOPBAR_H), EDITOR_RIGHT_W, ih), ui.style_bar()), 8), 8))
	im.layer = 1
	ui.open_col(ctx, ui.id("ed_inspector"), im)

	compose_telemetry_card(ctx)
	compose_materials_card(ctx)
	if ed.mesh.skinned {
		compose_bones_card(ctx)
	}
	ui.close(ctx)
}

@(private)
compose_telemetry_card :: proc(ctx: ^ui.Context) {
	ed := &app.editor
	sv, se, sf := edit.edit_mesh_selected_counts(&ed.mesh)
	cm := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_fill(ui.mod(), true, false), ui.style_card(ui.RAD_MD)), 4), 10)
	ui.open_col(ctx, ui.id("ed_tele_card"), cm)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_align(ui.m_fill(ui.mod(), true, false), .Center))
	ui.label(ctx, "MESH TELEMETRY", .Mono_Bold, 11, ui.COL_TEXT_GOLD)
	ui.spacer(ctx, 1)
	ui.button(ctx, ui.id("ed_smooth"), ui.Button_Opts{label = "Smooth", variant = .Compact, font_size = 11, msg_tag = u32(UI_Msg.Ed_Smooth)}, ui.m_h(ui.m_pad_xy(ui.mod(), 8, 2), 22))
	ui.close(ctx)

	ui.label(ctx, ui_cstr(fmt.tprintf("V %d   E %d   F %d", len(ed.mesh.verts), len(ed.mesh.edges), len(ed.mesh.faces))), .Mono, 12, ui.COL_TEXT_PRIMARY)
	ui.label(ctx, ui_cstr(fmt.tprintf("Sel V:%d  E:%d  F:%d", sv, se, sf)), .Mono, 11, ui.COL_TEXT_SECONDARY)
	if c, ok := edit.edit_selection_center(&ed.mesh); ok {
		ui.label(ctx, ui_cstr(fmt.tprintf("Ctr %.2f %.2f %.2f", c[0], c[1], c[2])), .Mono, 11, ui.COL_TEXT_MUTED)
	} else {
		ui.label(ctx, "Ctr (no selection)", .Mono, 11, ui.COL_TEXT_MUTED)
	}
	ui.close(ctx)
}

@(private)
compose_materials_card :: proc(ctx: ^ui.Context) {
	ed := &app.editor
	cm := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_fill(ui.mod(), true, false), ui.style_card(ui.RAD_MD)), 5), 10)
	ui.open_col(ctx, ui.id("ed_mat_card"), cm)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_align(ui.m_fill(ui.mod(), true, false), .Center))
	ui.label(ctx, "MATERIAL", .Mono_Bold, 11, ui.COL_TEXT_GOLD)
	ui.spacer(ctx, 1)
	ui.badge(ctx, ui.INVALID_ID, ui_cstr(spec.MAT_NAMES[ed.active_mat]), .Neutral, ui.m_pad_xy(ui.mod(), 7, 2))
	ui.close(ctx)

	mat_count := int(art.Mat_Kind.COUNT)
	for row := 0; row * 8 < mat_count; row += 1 {
		ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 4))
		for col in 0..<8 {
			m := row * 8 + col
			if m < mat_count {
				kind := art.Mat_Kind(m)
				ui.swatch(ctx, ui.id_idx("ed_mat", m), art.MAT_DEFS[kind].albedo, kind == ed.active_mat, u32(UI_Msg.Ed_Mat), i32(m), ui.m_h(ui.m_weight(ui.mod(), 1), 22))
			} else {
				ui.spacer(ctx, 1)
			}
		}
		ui.close(ctx)
	}
	ui.close(ctx)
}

@(private)
compose_bones_card :: proc(ctx: ^ui.Context) {
	ed := &app.editor
	cm := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_fill(ui.m_weight(ui.mod(), 1), true, true), ui.style_card(ui.RAD_MD)), 4), 10)
	ui.open_col(ctx, ui.id("ed_bone_card"), cm)

	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 6))
	ui.label(ctx, "BONE", .Mono_Bold, 11, ui.COL_TEXT_GOLD)
	ui.badge(ctx, ui.INVALID_ID, ui_cstr(spec.BONE_NAMES[ed.active_bone]), .Gold, ui.m_pad_xy(ui.mod(), 7, 2))
	ui.spacer(ctx, 1)
	ui.button(ctx, ui.id("ed_sel_bone"), ui.Button_Opts{label = "Sel", variant = .Compact, font_size = 11, msg_tag = u32(UI_Msg.Ed_Bone_Sel)}, ui.m_h(ui.m_pad_xy(ui.mod(), 7, 2), 20))
	ui.close(ctx)

	bone_count := int(art.Bone_Id.COUNT)
	for row := 0; row * 2 < bone_count; row += 1 {
		ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.m_weight(ui.mod(), 1), true, false), 4))
		for col in 0..<2 {
			b := row * 2 + col
			if b < bone_count {
				bone := art.Bone_Id(b)
				bm := ui.m_pad_xy(ui.m_fill(ui.m_weight(ui.mod(), 1), false, true), 6, 1)
				bm.max_h = 22
				ui.button(ctx, ui.id_idx("ed_bone", b), ui.Button_Opts{label = ui_cstr(spec.BONE_NAMES[bone]), variant = .Bone, active = bone == ed.active_bone, center_text = true, font_size = 10.5, msg_tag = u32(UI_Msg.Ed_Bone), msg_arg = i32(b)}, bm)
			} else {
				ui.spacer(ctx, 1)
			}
		}
		ui.close(ctx)
	}
	ui.close(ctx)
}

@(private)
compose_editor_statusbar :: proc(ctx: ^ui.Context, w, h: f32) {
	ed := &app.editor
	sm := ui.m_blocks(ui.m_pad_xy(ui.m_gap(ui.m_align(ui.m_surface(ui.m_size(ui.m_at(ui.mod(), 0, h - EDITOR_STATUS_H), w, EDITOR_STATUS_H), ui.style_bar()), .Center), 10), 12, 4))
	sm.layer = 1
	ui.open_row(ctx, ui.id("ed_statusbar"), sm)

	msg := editor_modal_status_text()
	col := ed.status_is_error ? ui.COL_TEXT_DANGER : ui.COL_TEXT_GOLD
	if len(msg) == 0 {
		msg = editor_status_cstr()
	} else {
		col = ui.COL_TEXT_PATROL
	}
	if len(msg) > 0 {
		ui.label(ctx, msg, .Mono_Bold, 11.5, col)
	}
	ui.spacer(ctx, 1)
	if w >= 1120 {
		ui.label(ctx, "F1 Help  |  G/R/S+XYZ  |  E Extrude  |  I Inset  |  ^R Loop  |  K Knife  |  X Del  |  MMB/RMB Orbit", .Mono, 10.5, ui.COL_TEXT_MUTED)
	}
	ui.close(ctx)
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
	case .Inset:    return cstring_t("Inset face | Move mouse / LMB confirm")
	case .Loop_Cut: return cstring_t(fmt.tprintf("Loop Cut (%d cuts) | Wheel cuts, LMB apply, Esc cancel", ed.loop_cuts))
	case .Knife:    return cstring_t(fmt.tprintf("Knife (%d nodes) | LMB point, Enter/Space cut, Esc cancel", len(ed.knife_nodes)))
	case .Select, .Box, .Extrude, .Fill, .Merge:
	}
	return ""
}

@(private)
compose_editor_delete_popup :: proc(ctx: ^ui.Context) {
	pos := app.editor.delete_menu_pos
	catch_m := ui.m_click(ui.m_layer(ui.m_fill(ui.mod()), 2), u32(UI_Msg.Ed_Delete_Choice), -1, true)
	ui.open_box(ctx, ui.id("ed_del_catch"), catch_m)

	pm := ui.m_blocks(ui.m_pad(ui.m_gap(ui.m_surface(ui.m_w(ui.m_at(ui.mod(), pos.x, pos.y), 182), ui.style_modal(ui.RAD_MD)), 5), 10))
	pm.layer = 2
	ui.open_col(ctx, ui.id("ed_del_menu"), pm)
	ui.label(ctx, "DELETE ELEMENT", .Mono_Bold, 11, ui.COL_TEXT_GOLD)
	labels := [4]cstring{"Vertices", "Edges", "Faces", "Dissolve Edges"}
	keys := [4]cstring{"V", "E", "F", "D"}
	for i in 0..<4 {
		ui.button(ctx, ui.id_idx("ed_del_item", i), ui.Button_Opts{label = labels[i], keycap = keys[i], variant = .Compact, msg_tag = u32(UI_Msg.Ed_Delete_Choice), msg_arg = i32(i)}, ui.m_h(ui.m_fill(ui.mod(), true, false), 26))
	}
	ui.close(ctx)
	ui.close(ctx)
}

@(private)
compose_editor_exit_dialog :: proc(ctx: ^ui.Context) {
	pm := ui.m_pad(ui.m_gap(ui.m_w(ui.mod(), 400), 12), 20)
	ui.open_scrim_modal(ctx, ui.id("ed_exit_modal"), 2, u32(UI_Msg.Ed_Exit_Cancel), pm)
	ui.label(ctx, "UNSAVED MESH CHANGES", .Heading, 17, ui.COL_TEXT_GOLD)
	ui.label(ctx, ui_cstr(fmt.tprintf("Save edits to %s/*.odin before leaving?", app.editor.mesh.id)), .Body, 13.5, ui.COL_TEXT_PRIMARY)
	ui.gap_box(ctx, 1, 4)
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 8))
	ui.button(ctx, ui.id("ed_exit_cancel"), ui.Button_Opts{label = "Cancel", variant = .Secondary, center_text = true, msg_tag = u32(UI_Msg.Ed_Exit_Cancel)}, ui.m_h(ui.m_weight(ui.mod(), 1), 34))
	ui.button(ctx, ui.id("ed_exit_discard"), ui.Button_Opts{label = "Discard", variant = .Danger, center_text = true, msg_tag = u32(UI_Msg.Ed_Exit_Discard)}, ui.m_h(ui.m_weight(ui.mod(), 1), 34))
	ui.button(ctx, ui.id("ed_exit_save"), ui.Button_Opts{label = "Save & Exit", variant = .Primary, center_text = true, msg_tag = u32(UI_Msg.Ed_Exit_Save)}, ui.m_h(ui.m_weight(ui.mod(), 1.25), 34))
	ui.close(ctx)
	ui.close_scrim_modal(ctx)
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
