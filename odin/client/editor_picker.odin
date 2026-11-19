// In-game Model Picker overlay: filtered 12-asset list, turntable card, and input handling.
package main

import "core:fmt"
import rl "vendor:raylib"
import art "./art"

Picker_Layout :: struct {
	panel:    rl.Rectangle,
	tabs:     [4]rl.Rectangle,
	list_box: rl.Rectangle,
	prev_box: rl.Rectangle,
	edit_btn: rl.Rectangle,
	proc_btn: rl.Rectangle,
	back_btn: rl.Rectangle,
}

picker_layout :: proc() -> Picker_Layout {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	pw := min(f32(980), w - 48)
	ph := min(f32(620), h - 48)
	px := (w - pw) * 0.5
	py := (h - ph) * 0.5
	tabs: [4]rl.Rectangle
	for i in 0..<4 {
		tabs[i] = {px + 20 + f32(i) * 94, py + 58, 88, 26}
	}
	list_w := min(f32(390), pw * 0.43)
	return Picker_Layout{
		panel    = {px, py, pw, ph},
		tabs     = tabs,
		list_box = {px + 20, py + 94, list_w, ph - 162},
		prev_box = {px + 34 + list_w, py + 58, pw - list_w - 54, ph - 126},
		edit_btn = {px + pw - 210, py + ph - 52, 190, 34},
		proc_btn = {px + pw - 396, py + ph - 52, 176, 34},
		back_btn = {px + 20, py + ph - 52, 140, 34},
	}
}

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

picker_row_rect :: proc(pl: Picker_Layout, row: int) -> rl.Rectangle {
	row_h := clamp((pl.list_box.height - 12.0) / 12.0, 26.0, 38.0)
	return rl.Rectangle{pl.list_box.x + 6, pl.list_box.y + 6 + f32(row) * row_h, pl.list_box.width - 12, row_h - 4}
}

draw_model_picker_ui :: proc() {
	ed := &app.editor
	pl := picker_layout()
	rl.DrawRectangleRec(pl.panel, COL_CHROME_BG)
	rl.DrawRectangleLinesEx(pl.panel, 2, COL_CHROME_LINE)
	rl.DrawText("MODEL EDITOR - PICK ASSET", i32(pl.panel.x + 20), i32(pl.panel.y + 18), 20, COL_TEXT_GOLD)
	draw_ui_button(help_badge_rect(), "? F1", app.help_open)

	tab_labels := [4]cstring{"All", "Units", "Trees", "Props"}
	tab_icons := [4]Icon_Id{.Models, .Cat_Units, .Cat_Trees, .Cat_Props}
	for i in 0..<4 {
		draw_ui_button(pl.tabs[i], tab_labels[i], ed.picker_cat == i, false, tab_icons[i])
	}
	draw_picker_model_list(pl)
	draw_picker_preview_card(pl)
	draw_ui_button(pl.back_btn, "Back [Esc]", false, false, .Game)
	draw_ui_button(pl.proc_btn, "Edit Procedural", false, false, .Reset)
	draw_ui_button(pl.edit_btn, "Edit Model [Enter]", true, true, .Mode_Face)
}

@(private)
draw_picker_model_list :: proc(pl: Picker_Layout) {
	ed := &app.editor
	rl.DrawRectangleRec(pl.list_box, rl.Color{11, 16, 12, 240})
	rl.DrawRectangleLinesEx(pl.list_box, 1, COL_CHROME_LINE)
	rows, count := picker_filtered_indices(ed.picker_cat)
	mouse := input_mouse_pos()
	for i in 0..<count {
		cat_idx := rows[i]
		entry := art.MODEL_CATALOG[cat_idx]
		rect := picker_row_rect(pl, i)
		if rect.y + rect.height > pl.list_box.y + pl.list_box.height - 4 { break }
		selected := cat_idx == ed.picker_idx
		hover := rl.CheckCollisionPointRec(mouse, rect)
		bg := selected ? COL_BTN_ACTIVE : (hover ? COL_BTN_HOVER : COL_BTN_BG)
		rl.DrawRectangleRec(rect, bg)
		rl.DrawRectangleLinesEx(rect, 1, selected ? COL_TEXT_GOLD : rl.Color{52, 74, 55, 255})
		rl.DrawText(cstring_t(entry.title), i32(rect.x + 10), i32(rect.y + 6), 13, rl.WHITE)

		badge := picker_source_badge(entry)
		b_col := art.catalog_has_custom_odin(entry.id) ? COL_TEXT_GOLD : COL_TEXT_DIM
		bw := rl.MeasureText(badge, 11)
		rl.DrawText(badge, i32(rect.x + rect.width - 10) - bw, i32(rect.y + 11), 11, b_col)
	}
}

@(private)
picker_source_badge :: proc(entry: art.Catalog_Entry) -> cstring {
	if art.catalog_has_custom_odin(entry.id) { return "CUSTOM" }
	if entry.base_fallback != "" && art.catalog_has_custom_odin(entry.base_fallback) { return "SHARED*" }
	if entry.base_fallback != "" { return "SHARED" }
	return "PROC"
}

@(private)
draw_picker_preview_card :: proc(pl: Picker_Layout) {
	ed := &app.editor
	box := pl.prev_box
	rl.DrawRectangleRec(box, rl.Color{14, 20, 16, 250})
	rl.DrawRectangleLinesEx(box, 1, COL_CHROME_LINE)
	if ed.picker_rect_tex.id > 0 {
		src := rl.Rectangle{0, 0, f32(ed.picker_rect_tex.texture.width), -f32(ed.picker_rect_tex.texture.height)}
		dst := rl.Rectangle{box.x + 6, box.y + 6, box.width - 12, box.height - 86}
		rl.DrawTexturePro(ed.picker_rect_tex.texture, src, dst, {0, 0}, 0, rl.WHITE)
	}
	idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
	e := art.MODEL_CATALOG[idx]
	info_y := i32(box.y + box.height - 72)
	rl.DrawText(cstring_t(fmt.tprintf("%s  (%s)", e.title, e.id)), i32(box.x + 14), info_y, 16, COL_TEXT_GOLD)
	skin_txt := e.skinned ? "Skinned 26-bone rig" : "Static prop/foliage"
	rl.DrawText(cstring_t(fmt.tprintf("%s | Scale %.2f | AO %.2f | %d tris", skin_txt, e.default_scale, e.ao_height, ed.picker_preview.tri_count)), i32(box.x + 14), info_y + 24, 12, COL_TEXT_DIM)
	note := e.base_fallback != "" ? fmt.tprintf("Forks on save (inherits %s unless customized)", e.base_fallback) : "Direct asset: odin/client/art/models/"
	rl.DrawText(cstring_t(note), i32(box.x + 14), info_y + 44, 11, rl.Color{132, 162, 136, 255})
}

handle_picker_input :: proc() {
	ed := &app.editor
	mouse := input_mouse_pos()
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
	if input_left_pressed() {
		handle_picker_click(mouse, rows, count)
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

@(private)
handle_picker_click :: proc(mouse: rl.Vector2, rows: []int, count: int) {
	ed := &app.editor
	pl := picker_layout()
	for i in 0..<4 {
		if rl.CheckCollisionPointRec(mouse, pl.tabs[i]) {
			ed.picker_cat = i
			_, next_count := picker_filtered_indices(i)
			if next_count > 0 {
				next_rows, _ := picker_filtered_indices(i)
				ed.picker_idx = next_rows[0]
				editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
			}
			return
		}
	}
	for i in 0..<count {
		if rl.CheckCollisionPointRec(mouse, picker_row_rect(pl, i)) {
			ed.picker_idx = rows[i]
			editor_ensure_picker_preview(art.MODEL_CATALOG[ed.picker_idx].id)
			return
		}
	}
	idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
	id := art.MODEL_CATALOG[idx].id
	if rl.CheckCollisionPointRec(mouse, pl.back_btn) { editor_close_to_game(); return }
	if rl.CheckCollisionPointRec(mouse, pl.edit_btn) { _ = editor_open_model(id, false); return }
	if rl.CheckCollisionPointRec(mouse, pl.proc_btn) { _ = editor_open_model(id, true); return }
}
