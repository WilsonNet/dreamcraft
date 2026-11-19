// In-game Model Picker overlay: Compose split panel, category segmented control, and rounded turntable card.
package main

import "core:fmt"
import rl "vendor:raylib"
import art "./art"
import ui "../ui"

picker_filtered_indices :: proc(cat: int) -> ([]int, int) {
	out := make([]int, len(art.MODEL_CATALOG), context.temp_allocator)
	n := 0
	for entry, i in art.MODEL_CATALOG {
		match := cat == 0 ||
			(cat == 1 && entry.category == .Units) ||
			(cat == 2 && entry.category == .Trees) ||
			(cat == 3 && entry.category == .Props)
		if match {
			out[n] = i
			n += 1
		}
	}
	return out[:n], n
}

compose_model_picker :: proc(ctx: ^ui.Context, w, h: f32) {
	pw := min(f32(980), w - 36)
	ph := min(f32(620), h - 36)
	pm := ui.m_pad(ui.m_gap(ui.m_size(ui.mod(), pw, ph), 14), 20)
	ui.open_scrim_modal(ctx, ui.id("picker_modal"), 1, 0, pm)

	compose_picker_header(ctx)
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.m_weight(ui.mod(), 1), true, true), 16))
	compose_picker_left_col(ctx)
	compose_picker_preview_col(ctx)
	ui.close(ctx)
	compose_picker_footer(ctx)
	ui.close_scrim_modal(ctx)
}

@(private)
compose_picker_header :: proc(ctx: ^ui.Context) {
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 10))
	ui.icon(ctx, icon_texture(.Models), 22)
	ui.label(ctx, "MODEL EDITOR - PICK ASSET", .Heading, 18, ui.COL_TEXT_GOLD)
	ui.badge(ctx, ui.INVALID_ID, "12 ASSETS", .Neutral)
	ui.spacer(ctx, 1)
	compose_help_badge_widget(ctx, 1)
	ui.close(ctx)
}

@(private)
compose_picker_left_col :: proc(ctx: ^ui.Context) {
	ed := &app.editor
	ui.open_col(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.m_weight(ui.mod(), 0.43), false, true), 10))

	track_m := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_h(ui.m_fill(ui.mod(), true, false), 36), ui.style_pill_track()), 4), 4)
	ui.open_row(ctx, ui.id("picker_tabs"), track_m)
	tab_labels := [4]cstring{"All", "Units", "Trees", "Props"}
	tab_icons := [4]Icon_Id{.Models, .Cat_Units, .Cat_Trees, .Cat_Props}
	for i in 0..<4 {
		ui.segmented_tab(ctx, ui.id_idx("picker_tab", i), tab_labels[i], icon_texture(tab_icons[i]), ed.picker_cat == i, u32(UI_Msg.Picker_Tab), i32(i), ui.m_fill(ui.m_weight(ui.mod(), 1), false, true))
	}
	ui.close(ctx)

	well_m := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_fill(ui.m_weight(ui.mod(), 1), true, true), ui.style_well(ui.RAD_MD)), 4), 7)
	ui.open_col(ctx, ui.id("picker_list"), well_m)
	rows, count := picker_filtered_indices(ed.picker_cat)
	for i in 0..<count {
		cat_idx := rows[i]
		compose_picker_list_row(ctx, cat_idx, cat_idx == ed.picker_idx)
	}
	if count < 10 {
		ui.spacer(ctx, f32(10 - count))
	}
	ui.close(ctx)
	ui.close(ctx)
}

@(private)
compose_picker_list_row :: proc(ctx: ^ui.Context, cat_idx: int, selected: bool) {
	entry := art.MODEL_CATALOG[cat_idx]
	rm := ui.m_click(ui.m_pad_xy(ui.m_gap(ui.m_align(ui.m_fill(ui.m_weight(ui.mod(), 1), true, false), .Center), 8), 10, 4), u32(UI_Msg.Picker_Row), i32(cat_idx))
	rm.max_h = 38
	rm.active = selected
	rm = ui.m_surface(rm, ui.style_button(.Compact))
	ui.open_row(ctx, ui.id_idx("picker_row", cat_idx), rm)
	ui.label(ctx, ui_cstr(entry.title), selected ? .Medium : .Body, 13, selected ? ui.COL_TEXT_ACTIVE : ui.COL_TEXT_PRIMARY)
	ui.spacer(ctx, 1)
	b_txt, b_tone := picker_source_badge(entry)
	ui.badge(ctx, ui.INVALID_ID, b_txt, b_tone, ui.m_pad_xy(ui.mod(), 7, 2))
	ui.close(ctx)
}

@(private)
picker_source_badge :: proc(entry: art.Catalog_Entry) -> (cstring, ui.Badge_Tone) {
	if art.catalog_has_custom_odin(entry.id) { return "CUSTOM", .Gold }
	if entry.base_fallback != "" && art.catalog_has_custom_odin(entry.base_fallback) { return "SHARED*", .Amber }
	if entry.base_fallback != "" { return "SHARED", .Cyan }
	return "PROC", .Neutral
}

@(private)
compose_picker_preview_col :: proc(ctx: ^ui.Context) {
	ed := &app.editor
	cm := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_fill(ui.m_weight(ui.mod(), 0.57), false, true), ui.style_card(ui.RAD_MD)), 10), 12)
	ui.open_col(ctx, ui.id("picker_preview_card"), cm)

	ui.clipped_texture(
		ctx,
		ui.id("picker_turntable"),
		ed.picker_rect_tex.texture,
		10,
		true,
		ui.COL_BORDER_SUBTLE,
		ui.m_fill(ui.m_weight(ui.mod(), 1), true, true),
	)

	idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
	e := art.MODEL_CATALOG[idx]
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 8))
	ui.label(ctx, ui_cstr(e.title), .Bold, 16, ui.COL_TEXT_GOLD)
	ui.badge(ctx, ui.INVALID_ID, ui_cstr(e.id), .Neutral)
	ui.spacer(ctx, 1)
	ui.label(ctx, ui_cstr(fmt.tprintf("%d tris", ed.picker_preview.tri_count)), .Mono_Bold, 12, ui.COL_TEXT_SECONDARY)
	ui.close(ctx)

	skin_txt := e.skinned ? "Skinned 26-bone rig" : "Static prop / foliage"
	ui.label(ctx, ui_cstr(fmt.tprintf("%s  |  Scale %.2f  |  AO %.2f", skin_txt, e.default_scale, e.ao_height)), .Mono, 11.5, ui.COL_TEXT_SECONDARY)
	note := e.base_fallback != "" ? fmt.tprintf("Forks on save (inherits %s unless customized)", e.base_fallback) : "Direct asset: odin/client/art/models/"
	ui.label(ctx, ui_cstr(note), .Body, 11.5, ui.COL_TEXT_MUTED)
	ui.close(ctx)
}

@(private)
compose_picker_footer :: proc(ctx: ^ui.Context) {
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 10))
	ui.button(ctx, ui.id("picker_back"), ui.Button_Opts{label = "Back", keycap = "Esc", icon_tex = icon_texture(.Game), variant = .Secondary, msg_tag = u32(UI_Msg.Picker_Back)}, ui.m_h(ui.mod(), 36))
	ui.spacer(ctx, 1)
	ui.button(ctx, ui.id("picker_proc"), ui.Button_Opts{label = "Edit Procedural", icon_tex = icon_texture(.Reset), variant = .Tonal, msg_tag = u32(UI_Msg.Picker_Edit_Proc)}, ui.m_h(ui.mod(), 36))
	ui.button(ctx, ui.id("picker_edit"), ui.Button_Opts{label = "Edit Model", keycap = "Enter", icon_tex = icon_texture(.Mode_Face), variant = .Primary, msg_tag = u32(UI_Msg.Picker_Edit_Model)}, ui.m_h(ui.mod(), 36))
	ui.close(ctx)
}

handle_picker_input :: proc() {
	ed := &app.editor
	if rl.IsKeyPressed(.ESCAPE) {
		editor_close_to_game()
		return
	}
	rows, count := picker_filtered_indices(ed.picker_cat)
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
		idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
		_ = editor_open_model(art.MODEL_CATALOG[idx].id, false)
		return
	}
	handle_picker_arrows(rows, count)
}

handle_picker_ui_msg :: proc(msg: UI_Msg, arg: i32) {
	ed := &app.editor
	#partial switch msg {
	case .Picker_Tab:
		ed.picker_cat = int(arg)
		next_rows, next_count := picker_filtered_indices(ed.picker_cat)
		if next_count > 0 {
			ed.picker_idx = next_rows[0]
			editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
		}
	case .Picker_Row:
		ed.picker_idx = clamp(int(arg), 0, len(art.MODEL_CATALOG) - 1)
		editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
	case .Picker_Back:
		editor_close_to_game()
	case .Picker_Edit_Proc:
		idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
		_ = editor_open_model(art.MODEL_CATALOG[idx].id, true)
	case .Picker_Edit_Model:
		idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
		_ = editor_open_model(art.MODEL_CATALOG[idx].id, false)
	}
}

@(private)
handle_picker_arrows :: proc(rows: []int, count: int) {
	ed := &app.editor
	if count == 0 { return }
	cur := 0
	for r, i in rows {
		if r == ed.picker_idx { cur = i; break }
	}
	if rl.IsKeyPressed(.DOWN) { cur = (cur + 1) % count }
	if rl.IsKeyPressed(.UP) { cur = (cur - 1 + count) % count }
	if rows[cur] != ed.picker_idx {
		ed.picker_idx = rows[cur]
		editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
	}
}
