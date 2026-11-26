// View-conditional F1 Shortcut Window data, keyboard handling, and Quickshell modal layout.
package main

import rl "../gfx"

Help_View :: enum u8 {
	Battlefield,
	Pause_Menu,
	Model_Picker,
	Editor_Mesh,
	Editor_Modal,
	Anim_Picker,
	Anim_Editor,
	Anim_Modal,
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
	{title = "Units & orders", items = BATTLEFIELD_ORDERS[:]},
	{title = "Camera & system", items = BATTLEFIELD_CAMERA[:]},
}

@(private)
PAUSE_MENU_ITEMS := [?]Shortcut_Item{
	{"Esc", "Resume the battle"},
	{"LMB", "Model Editor: pick one of 12 assets to edit"},
	{"LMB", "Retry Level: restart Tutorial Level 1"},
	{"F1", "Open or close this window"},
}

@(private)
PAUSE_GROUPS := [1]Shortcut_Group{
	{title = "Pause menu controls", items = PAUSE_MENU_ITEMS[:]},
}

@(private)
PICKER_ITEMS := [?]Shortcut_Item{
	{"Up / Down", "Select previous or next catalog model"},
	{"LMB tab", "Filter: All, Units, Trees or Props"},
	{"Enter", "Edit model: saved .odin override or base"},
	{"LMB", "Edit procedural: untouched Odin geometry"},
	{"Esc", "Back to the battlefield"},
}

@(private)
PICKER_GROUPS := [1]Shortcut_Group{
	{title = "Model picker navigation", items = PICKER_ITEMS[:]},
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
	{"LMB drag gizmo", "Move along the red, green or blue axis"},
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
	{"LMB swatch / bone", "Paint material or assign bone (inspector)"},
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
	{title = "Selection & modes", items = EDITOR_SELECT_ITEMS[:]},
	{title = "Transform & gizmo", items = EDITOR_TRANSFORM_ITEMS[:]},
	{title = "Modeling & rigging", items = EDITOR_MODEL_ITEMS[:]},
	{title = "Viewport & file", items = EDITOR_VIEW_ITEMS[:]},
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
	{"Mouse over edge", "Preview edge ring cuts live"},
	{"Mouse Wheel", "Adjust number of loop cuts (1..6)"},
	{"LMB", "Apply loop cuts to mesh"},
	{"RMB / Esc", "Cancel loop cut tool"},
}

@(private)
MODAL_KNIFE_ITEMS := [?]Shortcut_Item{
	{"LMB", "Place a cut node on a vertex, edge or face"},
	{"Enter / Space", "Slice faces along placed knife chain"},
	{"RMB / Esc", "Cancel and clear knife chain"},
}

@(private)
MODAL_OTHER_ITEMS := [?]Shortcut_Item{
	{"LMB / Enter", "Confirm active tool"},
	{"RMB / Esc", "Cancel active modal tool"},
}

@(private)
MODAL_TRANS_GROUPS := [1]Shortcut_Group{{title = "Active transform shortcuts", items = MODAL_TRANSFORM_ITEMS[:]}}
@(private)
MODAL_LOOP_GROUPS := [1]Shortcut_Group{{title = "Active loop cut shortcuts", items = MODAL_LOOP_ITEMS[:]}}
@(private)
MODAL_KNIFE_GROUPS := [1]Shortcut_Group{{title = "Active knife tool shortcuts", items = MODAL_KNIFE_ITEMS[:]}}
@(private)
MODAL_OTHER_GROUPS := [1]Shortcut_Group{{title = "Active tool", items = MODAL_OTHER_ITEMS[:]}}

@(private)
ANIM_PICKER_ITEMS := [?]Shortcut_Item{
	{"Up / Down", "Select previous or next animation clip"},
	{"LMB tab", "Filter: All, Base, Hero or Enemy"},
	{"Enter", "Edit clip: saved .odin override or baked procedural"},
	{"LMB", "Edit procedural: fresh bake from Odin pose math"},
	{"Esc", "Back to the battlefield"},
}
@(private)
ANIM_PICKER_GROUPS := [1]Shortcut_Group{{title = "Animation picker navigation", items = ANIM_PICKER_ITEMS[:]}}

@(private)
ANIM_EDIT_ITEMS := [?]Shortcut_Item{
	{"LMB bone / tree", "Select 25-bone rig joint in 3D or hierarchy"},
	{"R / Gizmo ring", "Modal rotate bone (X/Y/Z axis, numeric deg, Ctrl 5d)"},
	{"G / Root arrows", "Modal move root offset (Y=0 grounds feet)"},
	{"Drag Curves/Handles", "Move F-curve key (Shift=Y lock) or Bezier handle (Alt=Free)"},
	{"V / T / Home", "Cycle handle mode / Cycle interp / Fit graph view"},
	{"Wheel / MMB Graph", "Zoom Y (Ctrl+Wheel X) / Pan F-curve graph"},
	{"Space / I / X / Ctrl+S", "Play / +Key / -Key / Save .odin & hot-reload live"},
}
@(private)
ANIM_EDIT_GROUPS := [1]Shortcut_Group{{title = "Animation editor shortcuts", items = ANIM_EDIT_ITEMS[:]}}

@(private)
ANIM_MODAL_ITEMS := [?]Shortcut_Item{
	{"Mouse / 0-9 / - / .", "Rotate or move interactively or type exact value"},
	{"X / Y / Z", "Lock X, Y or Z axis"},
	{"Ctrl (hold)", "Snap 5 deg rotation / 0.02m root offset"},
	{"LMB / Enter", "Confirm pose edit"},
	{"RMB / Esc", "Cancel and restore previous pose"},
}
@(private)
ANIM_MODAL_GROUPS := [1]Shortcut_Group{{title = "Active pose transform", items = ANIM_MODAL_ITEMS[:]}}

active_help_view :: proc() -> Help_View {
	if app.mode == .Model_Picker { return .Model_Picker }
	if app.mode == .Model_Editor {
		return app.editor.modal_active ? .Editor_Modal : .Editor_Mesh
	}
	if app.mode == .Anim_Picker { return .Anim_Picker }
	if app.mode == .Anim_Editor {
		return app.anim_ed.modal_active ? .Anim_Modal : .Anim_Editor
	}
	if app.menu_open || app.mode == .Pause_Menu { return .Pause_Menu }
	return .Battlefield
}

help_sheet_for_view :: proc(view: Help_View) -> Shortcut_Sheet {
	switch view {
	case .Battlefield:
		badge: cstring = app.command_mode != .None ? "Targeting an order" : "Tutorial level 1"
		return Shortcut_Sheet{.Battlefield, "Battlefield", badge, .Hero_Crest, BATTLEFIELD_GROUPS[:]}
	case .Pause_Menu:
		return Shortcut_Sheet{.Pause_Menu, "Pause Menu", "Paused", .Game, PAUSE_GROUPS[:]}
	case .Model_Picker:
		return Shortcut_Sheet{.Model_Picker, "Model Picker", "12 assets", .Models, PICKER_GROUPS[:]}
	case .Editor_Mesh:
		return Shortcut_Sheet{.Editor_Mesh, "Model Editor", editor_mode_tag(), .Mode_Face, EDITOR_MESH_GROUPS[:]}
	case .Editor_Modal:
		return editor_modal_sheet()
	case .Anim_Picker:
		return Shortcut_Sheet{.Anim_Picker, "Animation Picker", "9 clips", .Pose, ANIM_PICKER_GROUPS[:]}
	case .Anim_Editor:
		return Shortcut_Sheet{.Anim_Editor, "Animation Editor", "25-bone rig", .Pose, ANIM_EDIT_GROUPS[:]}
	case .Anim_Modal:
		return Shortcut_Sheet{.Anim_Modal, "POSE TRANSFORM", "ACTIVE MODAL", .Tool_Rotate, ANIM_MODAL_GROUPS[:]}
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
