// View-conditional F1 Shortcut Window data, keyboard handling, and Quickshell modal layout.
package main

import "core:fmt"
import rl "vendor:raylib"
import ui "../ui"

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
	{"LMB / Shift+LMB", "Select unit / toggle selection"},
	{"Left Drag", "Box select friendly units"},
	{"Right Click", "Move to ground or attack enemy"},
	{"M + Click", "Move order with ground FX"},
	{"A + Click", "Attack-Move (auto-engages foes)"},
	{"P + Click", "1-click Patrol loop"},
	{"S", "Stop unit & clear current orders"},
}

@(private)
BATTLEFIELD_CAMERA := [?]Shortcut_Item{
	{"MMB / Space+Drag", "1:1 Camera Grip terrain drag"},
	{"WASD / Arrows", "Pan isometric camera"},
	{"Screen Edge", "Edge pan along viewport borders"},
	{"Mouse Wheel", "Smooth camera zoom"},
	{"F", "Toggle Camera Follow / Free"},
	{"Minimap Drag", "Jump or scrub main camera"},
	{"Esc / F1", "Pause menu / Toggle help"},
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
	{"LMB / Shift+LMB", "Pick element or toggle additive"},
	{"Drag / B", "Box marquee select in viewport"},
	{"Alt + LMB", "Select full edge loop (Edge mode)"},
	{"L / A / Alt+A", "Linked / All / None / Shift+I Invert"},
}

@(private)
EDITOR_TRANSFORM_ITEMS := [?]Shortcut_Item{
	{"G / R / S", "Grab / Rotate / Scale selection"},
	{"Drag Gizmo X/Y/Z", "Lock translation along RGB axis"},
	{"X / Y / Z", "Constrain axis during modal op"},
	{"Shift + X/Y/Z", "Lock plane (YZ / XZ / XY)"},
	{"0-9 / - / .", "Type exact distance, deg, or scale"},
	{"Ctrl (modal)", "Snap 0.05m / 5 deg / 0.1x scale"},
}

@(private)
EDITOR_MODEL_ITEMS := [?]Shortcut_Item{
	{"E / I", "Extrude selection / Inset faces"},
	{"Ctrl+R (+ Wheel)", "Loop cut (scroll 1..6, LMB apply)"},
	{"K (+ Enter)", "Knife cut points across mesh"},
	{"F / M (Alt+M)", "Fill 3-4 verts / Merge at center"},
	{"X -> V/E/F/D", "Delete or dissolve selected elems"},
	{"Inspector Right", "Paint Mat_Kind & assign Bone_Id"},
}

@(private)
EDITOR_VIEW_ITEMS := [?]Shortcut_Item{
	{"MMB / Alt+LMB", "Orbit 3D studio camera (or RMB)"},
	{"Shift + MMB", "Pan camera target"},
	{"Wheel / Num .", "Zoom / Frame selected geometry"},
	{"Numpad 1 / 3 / 7", "Front / Right / Top aligned views"},
	{"Numpad 5 / Alt+Z", "Ortho-Persp / X-Ray overlay"},
	{"Ctrl+Z / +Shift+Z", "Undo / Redo edit step"},
	{"Ctrl+S / Esc", "Save .odin & hot-reload / Exit"},
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
MODAL_TRANS_GROUPS := [1]Shortcut_Group{{title = "ACTIVE TRANSFORM SHORTCUTS", items = MODAL_TRANSFORM_ITEMS[:]}}
@(private)
MODAL_LOOP_GROUPS := [1]Shortcut_Group{{title = "ACTIVE LOOP CUT SHORTCUTS", items = MODAL_LOOP_ITEMS[:]}}
@(private)
MODAL_KNIFE_GROUPS := [1]Shortcut_Group{{title = "ACTIVE KNIFE TOOL SHORTCUTS", items = MODAL_KNIFE_ITEMS[:]}}
@(private)
MODAL_OTHER_GROUPS := [1]Shortcut_Group{{title = "ACTIVE TOOL", items = MODAL_OTHER_ITEMS[:]}}

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
	if r, ok := ui.get_rect(&app.ui_ctx, ui.id("help_badge")); ok && r.width > 0 {
		return r
	}
	return {496, 18, 56, 22}
}

handle_help_input :: proc() -> bool {
	if rl.IsKeyPressed(.F1) {
		app.help_open = !app.help_open
		return true
	}
	if app.help_open {
		if rl.IsKeyPressed(.ESCAPE) {
			app.help_open = false
		}
		return true
	}
	return false
}

compose_help_window :: proc(ctx: ^ui.Context, w, h: f32) {
	sheet := help_sheet_for_view(active_help_view())
	cols := len(sheet.groups) >= 2 ? 2 : 1
	pw := min(cols == 2 ? f32(920) : f32(620), w - 28)
	pm := ui.m_pad(ui.m_gap(ui.m_w(ui.mod(), pw), 12), 20)
	pm.max_h = h - 32
	ui.open_scrim_modal(ctx, ui.id("help_modal"), 3, u32(UI_Msg.Help_Close), pm)

	compose_help_header(ctx, sheet)
	ui.ornament_divider(ctx)
	compose_help_groups(ctx, sheet.groups, cols)
	ui.label(ctx, ui_cstr(fmt.tprintf("Conditional shortcuts for %s  |  Press F1 anytime", sheet.badge)), .Body, 12, ui.COL_TEXT_MUTED)
	ui.close_scrim_modal(ctx)
}

@(private)
compose_help_header :: proc(ctx: ^ui.Context, sheet: Shortcut_Sheet) {
	ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 10))
	ui.icon(ctx, icon_texture(sheet.icon), 24)
	ui.label(ctx, sheet.heading, .Heading, 18, ui.COL_TEXT_GOLD)
	ui.spacer(ctx, 1)
	ui.badge(ctx, ui.INVALID_ID, sheet.badge, .Emerald)
	ui.button(ctx, ui.id("help_close_btn"), ui.Button_Opts{label = "Close", keycap = "Esc", variant = .Compact, msg_tag = u32(UI_Msg.Help_Close)}, ui.m_h(ui.m_pad_xy(ui.mod(), 10, 4), 28))
	ui.close(ctx)
}

@(private)
compose_help_groups :: proc(ctx: ^ui.Context, groups: []Shortcut_Group, cols: int) {
	for i := 0; i < len(groups); i += cols {
		ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_fill(ui.mod(), true, false), 14))
		for c in 0..<cols {
			gi := i + c
			if gi >= len(groups) {
				ui.spacer(ctx, 1)
				break
			}
			compose_single_help_group(ctx, groups[gi], gi)
		}
		ui.close(ctx)
	}
}

@(private)
compose_single_help_group :: proc(ctx: ^ui.Context, grp: Shortcut_Group, idx: int) {
	cm := ui.m_pad(ui.m_gap(ui.m_surface(ui.m_weight(ui.mod(), 1), ui.style_card(ui.RAD_MD)), 5), 12)
	ui.open_col(ctx, ui.id_idx("help_grp", idx), cm)
	ui.label(ctx, grp.title, .Mono_Bold, 11.5, ui.COL_TEXT_GOLD)
	ui.gap_box(ctx, 1, 2)
	for it in grp.items {
		ui.open_row(ctx, ui.INVALID_ID, ui.m_gap(ui.m_align(ui.m_fill(ui.mod(), true, false), .Center), 9))
		ui.keycap(ctx, it.keys, .Gold, ui.mod(), 11)
		ui.label(ctx, it.desc, .Body, 12, ui.COL_TEXT_PRIMARY)
		ui.close(ctx)
	}
	ui.close(ctx)
}
