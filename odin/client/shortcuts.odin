// View-conditional F1 Shortcut Window data, input handling, and keycap renderer.
package main

import "core:fmt"
import rl "vendor:raylib"

Help_View :: enum u8 {
	Battlefield,
	Pause_Menu,
	Model_Picker,
	Editor_Mesh,
	Editor_Modal,
}

Shortcut_Item :: struct {
	keys: cstring,
	desc: cstring,
}

Shortcut_Group :: struct {
	title: cstring,
	items: []Shortcut_Item,
}

Shortcut_Sheet :: struct {
	view:    Help_View,
	heading: cstring,
	badge:   cstring,
	icon:    Icon_Id,
	groups:  []Shortcut_Group,
}

@(private)
BATTLEFIELD_ORDERS := [?]Shortcut_Item{
	{"LMB / Shift+LMB", "Select unit / toggle add to selection"},
	{"Left Drag", "Box select friendly units"},
	{"Right Click", "Move to ground or attack spotted enemy"},
	{"M + Click", "Move order with ground confirmation FX"},
	{"A + Click", "StarCraft Attack-Move (auto-engages foes)"},
	{"P + Click", "1-click Patrol loop (current <-> target)"},
	{"S", "Stop unit and clear current orders"},
}

@(private)
BATTLEFIELD_CAMERA := [?]Shortcut_Item{
	{"MMB / Space+Drag", "1:1 Camera Grip terrain drag"},
	{"WASD / Arrows", "Pan isometric camera"},
	{"Screen Edge", "Edge pan along viewport borders"},
	{"Mouse Wheel", "Smooth camera zoom"},
	{"F", "Toggle Camera Follow / Free"},
	{"Minimap Click/Drag", "Jump or scrub main camera across map"},
	{"Esc / F1", "Cancel command or Pause / Toggle this help"},
}

@(private)
BATTLEFIELD_GROUPS := [2]Shortcut_Group{
	{title = "UNITS & ORDERS", items = BATTLEFIELD_ORDERS[:]},
	{title = "CAMERA & SYSTEM", items = BATTLEFIELD_CAMERA[:]},
}

@(private)
PAUSE_MENU_ITEMS := [?]Shortcut_Item{
	{"Esc / Resume", "Close pause overlay and resume battle"},
	{"Model Editor", "Open 12-asset 3D Model Picker & Editor"},
	{"Retry Level", "Reset Tutorial Level 1 to initial state"},
	{"F1", "Close or open this shortcut window"},
}

@(private)
PAUSE_GROUPS := [1]Shortcut_Group{
	{title = "PAUSE MENU CONTROLS", items = PAUSE_MENU_ITEMS[:]},
}

@(private)
PICKER_ITEMS := [?]Shortcut_Item{
	{"Up / Down", "Select previous or next catalog model"},
	{"All/Units/Trees/Props", "Filter models by asset category"},
	{"Enter / Edit Model", "Edit saved .odin override or base model"},
	{"Edit Procedural", "Open untouched procedural Odin geometry"},
	{"Esc / Back", "Return to battlefield"},
}

@(private)
PICKER_GROUPS := [1]Shortcut_Group{
	{title = "MODEL PICKER NAVIGATION", items = PICKER_ITEMS[:]},
}

@(private)
EDITOR_SELECT_ITEMS := [?]Shortcut_Item{
	{"1 / 2 / 3", "Vertex / Edge / Face select mode"},
	{"LMB / Shift+LMB", "Pick element or toggle additive selection"},
	{"Drag / B", "Box marquee select inside viewport"},
	{"Alt + LMB", "Select full edge loop (Edge mode)"},
	{"L / A / Alt+A / +I", "Linked / All / None / Shift+I Invert"},
}

@(private)
EDITOR_TRANSFORM_ITEMS := [?]Shortcut_Item{
	{"G / R / S", "Grab / Rotate / Scale selection"},
	{"Drag Gizmo X/Y/Z", "Lock translation along RGB world axis"},
	{"X / Y / Z (in modal)", "Constrain single axis during G/R/S"},
	{"Shift + X/Y/Z", "Lock plane (YZ / XZ / XY)"},
	{"0-9 / - / .", "Type exact distance, degrees, or scale"},
	{"Ctrl (hold in modal)", "Snap distance, 5 deg angle, or 0.1 scale"},
}

@(private)
EDITOR_MODEL_ITEMS := [?]Shortcut_Item{
	{"E / I", "Extrude selection / Inset faces (22%)"},
	{"Ctrl+R (+ Wheel)", "Loop cut (scroll 1..6 cuts, LMB apply)"},
	{"K (+ Enter/Space)", "Knife click points across vert/edge/face"},
	{"F / M (Alt+M)", "Fill 3-4 verts into face / Merge at center"},
	{"X / Del -> V/E/F/D", "Delete verts/edges/faces or dissolve edges"},
	{"Inspector Right", "Paint Mat_Kind swatches & assign Bone_Id"},
}

@(private)
EDITOR_VIEW_ITEMS := [?]Shortcut_Item{
	{"MMB / Alt+LMB / RMB", "Orbit 3D studio camera"},
	{"Shift + MMB", "Pan camera target"},
	{"Wheel / . (Num .)", "Zoom / Frame selected geometry"},
	{"Numpad 1 / 3 / 7", "Front / Right / Top aligned views"},
	{"Numpad 5 / O / Alt+Z", "Ortho-Persp toggle / X-Ray overlay"},
	{"Ctrl+Z / Ctrl+Shift+Z", "Undo / Redo edit step"},
	{"Ctrl+S / Esc", "Save .odin chunks & hot-reload / Exit"},
}

@(private)
EDITOR_MESH_GROUPS := [4]Shortcut_Group{
	{title = "SELECTION & MODES", items = EDITOR_SELECT_ITEMS[:]},
	{title = "TRANSFORM & GIZMO", items = EDITOR_TRANSFORM_ITEMS[:]},
	{title = "MODELING & RIGGING", items = EDITOR_MODEL_ITEMS[:]},
	{title = "VIEWPORT & FILE", items = EDITOR_VIEW_ITEMS[:]},
}

@(private)
MODAL_TRANSFORM_ITEMS := [?]Shortcut_Item{
	{"Mouse / 0-9 / - / .", "Move interactively or type exact value"},
	{"X / Y / Z", "Toggle single-axis lock"},
	{"Shift + X/Y/Z", "Toggle plane lock (YZ / XZ / XY)"},
	{"Ctrl (hold)", "Snap to 0.05m / 5 deg / 0.1x increments"},
	{"LMB / Enter", "Commit transform (or release Gizmo drag)"},
	{"RMB / Esc", "Cancel transform and restore original verts"},
}

@(private)
MODAL_LOOP_ITEMS := [?]Shortcut_Item{
	{"Hover Edge", "Preview edge ring cuts live"},
	{"Mouse Wheel", "Adjust number of loop cuts (1..6)"},
	{"LMB", "Apply loop cuts to mesh"},
	{"RMB / Esc", "Cancel loop cut tool"},
}

@(private)
MODAL_KNIFE_ITEMS := [?]Shortcut_Item{
	{"LMB in Viewport", "Place cut node on Vertex, Edge, or Face"},
	{"Enter / Space", "Slice faces along placed knife chain"},
	{"RMB / Esc", "Cancel and clear knife chain"},
}

@(private)
MODAL_OTHER_ITEMS := [?]Shortcut_Item{
	{"LMB / Enter", "Confirm active tool"},
	{"RMB / Esc", "Cancel active modal tool"},
}

@(private)
MODAL_TRANS_GROUPS := [1]Shortcut_Group{{title = "ACTIVE TRANSFORM SHORTCUTS", items = MODAL_TRANSFORM_ITEMS[:]} }
@(private)
MODAL_LOOP_GROUPS := [1]Shortcut_Group{{title = "ACTIVE LOOP CUT SHORTCUTS", items = MODAL_LOOP_ITEMS[:]} }
@(private)
MODAL_KNIFE_GROUPS := [1]Shortcut_Group{{title = "ACTIVE KNIFE TOOL SHORTCUTS", items = MODAL_KNIFE_ITEMS[:]} }
@(private)
MODAL_OTHER_GROUPS := [1]Shortcut_Group{{title = "ACTIVE TOOL", items = MODAL_OTHER_ITEMS[:]} }

active_help_view :: proc() -> Help_View {
	if app.mode == .Model_Picker { return .Model_Picker }
	if app.mode == .Model_Editor {
		return app.editor.modal_active ? .Editor_Modal : .Editor_Mesh
	}
	if app.menu_open || app.mode == .Pause_Menu { return .Pause_Menu }
	return .Battlefield
}

help_sheet_for_view :: proc(view: Help_View) -> Shortcut_Sheet {
	switch view {
	case .Battlefield:
		badge: cstring = app.command_mode != .None ? "CMD TARGETING ACTIVE" : "TUTORIAL LEVEL 1"
		return Shortcut_Sheet{.Battlefield, "BATTLEFIELD SHORTCUTS", badge, .Hero_Crest, BATTLEFIELD_GROUPS[:]}
	case .Pause_Menu:
		return Shortcut_Sheet{.Pause_Menu, "PAUSE MENU SHORTCUTS", "PAUSED OVERLAY", .Models, PAUSE_GROUPS[:]}
	case .Model_Picker:
		return Shortcut_Sheet{.Model_Picker, "MODEL PICKER SHORTCUTS", "12 CATALOG ASSETS", .Models, PICKER_GROUPS[:]}
	case .Editor_Mesh:
		return Shortcut_Sheet{.Editor_Mesh, "MODEL EDITOR SHORTCUTS", editor_mode_tag(), .Mode_Face, EDITOR_MESH_GROUPS[:]}
	case .Editor_Modal:
		return editor_modal_sheet()
	}
	return Shortcut_Sheet{.Battlefield, "BATTLEFIELD SHORTCUTS", "TUTORIAL LEVEL 1", .Hero_Crest, BATTLEFIELD_GROUPS[:]}
}

@(private)
editor_mode_tag :: proc() -> cstring {
	switch app.editor.mesh.mode {
	case .Vertex: return "VERTEX EDIT MODE"
	case .Edge:   return "EDGE EDIT MODE"
	case .Face:   return "FACE EDIT MODE"
	}
	return "EDIT MODE"
}

@(private)
editor_modal_sheet :: proc() -> Shortcut_Sheet {
	switch app.editor.modal_op {
	case .Grab:     return Shortcut_Sheet{.Editor_Modal, "GRAB TRANSFORM", "ACTIVE MODAL", .Tool_Grab, MODAL_TRANS_GROUPS[:]}
	case .Rotate:   return Shortcut_Sheet{.Editor_Modal, "ROTATE TRANSFORM", "ACTIVE MODAL", .Tool_Rotate, MODAL_TRANS_GROUPS[:]}
	case .Scale:    return Shortcut_Sheet{.Editor_Modal, "SCALE TRANSFORM", "ACTIVE MODAL", .Tool_Scale, MODAL_TRANS_GROUPS[:]}
	case .Loop_Cut: return Shortcut_Sheet{.Editor_Modal, "LOOP CUT TOOL", "ACTIVE MODAL", .Tool_Loop_Cut, MODAL_LOOP_GROUPS[:]}
	case .Knife:    return Shortcut_Sheet{.Editor_Modal, "KNIFE CUT TOOL", "ACTIVE MODAL", .Tool_Knife, MODAL_KNIFE_GROUPS[:]}
	case .Select, .Box, .Extrude, .Inset, .Fill, .Merge:
	}
	return Shortcut_Sheet{.Editor_Modal, "MODAL TOOL", "ACTIVE MODAL", .Tool_Select, MODAL_OTHER_GROUPS[:]}
}

help_badge_rect :: proc() -> rl.Rectangle {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	switch active_help_view() {
	case .Battlefield:
		return {496, 18, 56, 22}
	case .Pause_Menu:
		return {w * 0.5 + 150, h * 0.5 + 116, 58, 22}
	case .Model_Picker:
		pl := picker_layout()
		return {pl.panel.x + pl.panel.width - 96, pl.panel.y + 16, 76, 26}
	case .Editor_Mesh, .Editor_Modal:
		return editor_topbar_rects().help
	}
	return {0, 0, 0, 0}
}

@(private)
help_window_layout :: proc(sheet: Shortcut_Sheet) -> (panel, close_btn: rl.Rectangle, cols: int) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())
	cols = len(sheet.groups) >= 2 ? 2 : 1
	rows_max := 0
	for i := 0; i < len(sheet.groups); i += cols {
		r := len(sheet.groups[i].items)
		if cols == 2 && i + 1 < len(sheet.groups) {
			r = max(r, len(sheet.groups[i + 1].items))
		}
		rows_max += r + 2
	}
	pw := min(cols == 2 ? f32(900) : f32(640), w - 36)
	ph := clamp(f32(106 + rows_max * 24), 240, h - 44)
	panel = {(w - pw) * 0.5, (h - ph) * 0.5, pw, ph}
	close_btn = {panel.x + pw - 118, panel.y + 14, 100, 26}
	return
}

handle_help_input :: proc() -> bool {
	if rl.IsKeyPressed(.F1) {
		app.help_open = !app.help_open
		return true
	}
	mouse := input_mouse_pos()
	if app.help_open {
		if rl.IsKeyPressed(.ESCAPE) {
			app.help_open = false
			return true
		}
		if input_left_pressed() {
			sheet := help_sheet_for_view(active_help_view())
			panel, close_btn, _ := help_window_layout(sheet)
			if rl.CheckCollisionPointRec(mouse, close_btn) || !rl.CheckCollisionPointRec(mouse, panel) {
				app.help_open = false
			}
		}
		return true
	}
	if input_left_pressed() && rl.CheckCollisionPointRec(mouse, help_badge_rect()) {
		app.help_open = true
		return true
	}
	return false
}

draw_help_window :: proc() {
	if !app.help_open { return }
	sheet := help_sheet_for_view(active_help_view())
	panel, close_btn, cols := help_window_layout(sheet)
	w, h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
	rl.DrawRectangleRec({0, 0, w, h}, rl.Color{0, 0, 0, 155})
	rl.DrawRectangleRec(panel, COL_CHROME_BG)
	rl.DrawRectangleLinesEx(panel, 2, COL_TEXT_GOLD)

	draw_icon_centered(sheet.icon, panel.x + 28, panel.y + 27, 22)
	rl.DrawText(sheet.heading, i32(panel.x + 48), i32(panel.y + 18), 18, COL_TEXT_GOLD)
	bw := rl.MeasureText(sheet.badge, 11)
	bx := i32(panel.x + panel.width - 134) - bw
	rl.DrawRectangle(bx - 8, i32(panel.y + 17), bw + 16, 20, rl.Color{32, 48, 35, 255})
	rl.DrawRectangleLines(bx - 8, i32(panel.y + 17), bw + 16, 20, COL_CHROME_LINE)
	rl.DrawText(sheet.badge, bx, i32(panel.y + 22), 11, rl.Color{165, 215, 170, 255})
	draw_ui_button(close_btn, "Esc / F1", false)
	rl.DrawLineV({panel.x + 16, panel.y + 52}, {panel.x + panel.width - 16, panel.y + 52}, COL_CHROME_LINE)

	draw_help_groups(panel, sheet.groups, cols)
	footer := cstring_t(fmt.tprintf("Conditional shortcuts for %s | Press F1 anytime", sheet.badge))
	rl.DrawText(footer, i32(panel.x + 18), i32(panel.y + panel.height - 24), 11, COL_TEXT_DIM)
}

@(private)
draw_help_groups :: proc(panel: rl.Rectangle, groups: []Shortcut_Group, cols: int) {
	col_w := (panel.width - 36 - f32(cols - 1) * 18) / f32(cols)
	y := panel.y + 64
	for i := 0; i < len(groups); i += cols {
		max_rows := 0
		for c in 0..<cols {
			gi := i + c
			if gi >= len(groups) { break }
			gx := panel.x + 18 + f32(c) * (col_w + 18)
			draw_single_help_group(gx, y, col_w, groups[gi])
			max_rows = max(max_rows, len(groups[gi].items))
		}
		y += f32(max_rows * 24 + 34)
	}
}

@(private)
draw_single_help_group :: proc(x, y, w: f32, grp: Shortcut_Group) {
	rl.DrawText(grp.title, i32(x), i32(y), 12, COL_TEXT_GOLD)
	key_w := min(f32(158), w * 0.40)
	for it in grp.items {
		key_w = max(key_w, f32(rl.MeasureText(it.keys, 11) + 16))
	}
	key_w = min(key_w, w * 0.42)
	ry := y + 22
	for it in grp.items {
		box := rl.Rectangle{x, ry, key_w, 20}
		rl.DrawRectangleRec(box, rl.Color{28, 42, 31, 255})
		rl.DrawRectangleLinesEx(box, 1, rl.Color{66, 102, 70, 220})
		rl.DrawText(it.keys, i32(box.x + 6), i32(box.y + 4), 11, COL_TEXT_GOLD)
		rl.DrawText(it.desc, i32(x + key_w + 10), i32(ry + 4), 12, rl.Color{224, 232, 224, 255})
		ry += 24
	}
}
