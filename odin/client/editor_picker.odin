// In-game Model Picker overlay: Compose split panel, category segmented control, and rounded turntable card.
package main

import rl "../gfx"
import art "./art"

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
