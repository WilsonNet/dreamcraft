// Model Picker and Model Editor chrome in the Basin world, built with vinland-ui. The editor is
// an Operate surface: dense, steady, standard controls; the world shows in the bitumen bars,
// brass edges, bevelled chips and gold inlay on the armed tool. Blender shortcuts are handled
// by editor_input.odin and are unchanged.
package main

import "core:fmt"
import art "./art"
import edit "./art/edit"
import spec "./art/spec"
import ui "vinland:vui"

// ---------------------------------------------------------------------------
// Model Picker
// ---------------------------------------------------------------------------

compose_model_picker :: proc(w, h: f32) {
	ed := &app.editor
	if ui.div("absolute inset-0 flex items-center justify-center bg-black/55 p-4 pointer-events-auto") {
		if basin_panel("flex h-full max-h-[640px] w-full max-w-[1000px]", "flex min-h-0 grow flex-col gap-4 p-5") {
			// header
			if ui.div("flex items-center gap-3") {
				ui.el(ui.cx("size-6 bg-brass-hi", icon_tex(.Models)))
				ui.text("Model Editor", "font-display text-[22px] font-bold text-brass-hi")
				ui.text("Pick an asset to edit", "grow text-[13px] font-bold uppercase tracking-[0.12em] text-silver-dim")
				ui.text(fmt.tprintf("%d assets", len(art.MODEL_CATALOG)), "text-[13px] font-bold tabular-nums text-silver-dim")
			}
			ui.el("h-2 shrink-0 bg-brass/50 bg-tex-interlace bg-tile-8")
			if ui.div("flex min-h-0 grow gap-5") {
				// left: category tabs + list
				if ui.div("flex w-[42%] min-w-[300px] flex-col gap-3") {
					if ui.div("flex gap-1 rounded-[6px] bg-bitumen-deep p-1 ring-1 ring-brass-lo") {
						TABS := [4]string{"All", "Units", "Trees", "Props"}
						TAB_IC := [4]Icon_Id{.Models, .Cat_Units, .Cat_Trees, .Cat_Props}
						for t, i in TABS {
							ui.push_id(i)
							if chip_button(t, ed.picker_cat == i, icon_tex(TAB_IC[i]), "grow justify-center") {
								handle_picker_ui_msg(.Picker_Tab, i32(i))
							}
							ui.pop_id()
						}
					}
					if ui.div("flex min-h-0 grow flex-col gap-1 overflow-y-auto rounded-[8px] bg-bitumen-deep p-2 ring-1 ring-brass-lo/70") {
						rows, count := picker_filtered_indices(ed.picker_cat)
						for r in rows[:count] {
							ui.push_id(r)
							entry := art.MODEL_CATALOG[r]
							sel := r == ed.picker_idx
							row_cls := sel ? "flex h-10 shrink-0 items-center gap-3 rounded-[5px] corner-bevel bg-linear-to-r from-brass-lo/70 to-bitumen-raised px-3 ring-1 ring-brass-hi" : "flex h-10 shrink-0 items-center gap-3 rounded-[5px] corner-bevel px-3 ring-1 ring-transparent hover:bg-bitumen-raised hover:ring-brass-lo"
							if ui.button_box(row_cls) {
								ui.text(entry.title, sel ? "grow text-[14px] font-extrabold text-inlay" : "grow text-[14px] font-bold text-silver-dim")
								tag, tag_cls := picker_source_tag(entry)
								ui.text(tag, tag_cls)
								if ui.clicked() {
									handle_picker_ui_msg(.Picker_Row, i32(r))
								}
							}
							ui.pop_id()
						}
					}
				}
				// right: turntable plate and facts
				idx := clamp(ed.picker_idx, 0, len(art.MODEL_CATALOG) - 1)
				e := art.MODEL_CATALOG[idx]
				if ui.div("flex min-w-0 grow flex-col gap-3") {
					if ui.div(ui.cx("relative min-h-0 grow rounded-[14px] corner-scoop p-[4px]", BRASS_RIM)) {
						if ui.div("size-full overflow-hidden rounded-[11px] corner-scoop bg-[#16201a]") {
							ui.image(vh.picker_img, "size-full object-cover")
						}
					}
					if ui.div("flex items-baseline gap-3") {
						ui.text(e.title, "font-display text-[20px] font-bold text-brass-hi")
						ui.text(e.id, "rounded-sm bg-bitumen-deep px-1.5 text-[12px] font-bold text-silver-dim ring-1 ring-brass-lo")
						ui.el("grow")
						ui.text(fmt.tprintf("%d tris", ed.picker_preview.tri_count), VALUE)
					}
					ui.text(fmt.tprintf("%s · Scale %.2f · AO %.2f", e.skinned ? "Skinned 26-bone rig" : "Static prop or foliage", e.default_scale, e.ao_height), "text-[13px] font-bold tabular-nums text-silver")
					ui.text(e.base_fallback != "" ? fmt.tprintf("Forks on save: inherits %s until customised.", e.base_fallback) : "Direct asset in odin/client/art/models/.", "text-[13px] font-bold text-silver-dim")
				}
			}
			// footer
			if ui.div("flex items-center gap-3") {
				if plaque_button("Back to battle", .Brass, "Esc", icon_tex(.Game)) {
					handle_picker_ui_msg(.Picker_Back, 0)
				}
				ui.el("grow")
				if plaque_button("Edit procedural", .Lapis, "", icon_tex(.Reset)) {
					handle_picker_ui_msg(.Picker_Edit_Proc, 0)
				}
				if plaque_button("Edit model", .Inlay, "Enter", icon_tex(.Mode_Face)) {
					handle_picker_ui_msg(.Picker_Edit_Model, 0)
				}
			}
		}
	}
}

@(private)
picker_source_tag :: proc(entry: art.Catalog_Entry) -> (string, string) {
	BASE :: "rounded-sm px-1.5 text-[11px] font-extrabold uppercase tracking-wider ring-1 "
	if art.catalog_has_custom_odin(entry.id) {
		return "Custom", BASE + "bg-brass-lo/40 text-brass-hi ring-brass"
	}
	if entry.base_fallback != "" && art.catalog_has_custom_odin(entry.base_fallback) {
		return "Shared*", BASE + "bg-amber-alert/15 text-amber-alert ring-amber-alert/60"
	}
	if entry.base_fallback != "" {
		return "Shared", BASE + "bg-lapis-lo text-silver ring-lapis-hi"
	}
	return "Proc", BASE + "bg-bitumen-deep text-silver-dim ring-brass-lo"
}

// ---------------------------------------------------------------------------
// Model Editor
// ---------------------------------------------------------------------------

compose_model_editor :: proc(w, h: f32) {
	compose_editor_topbar(w)
	compose_editor_tool_rail(h)
	compose_editor_inspector(w, h)
	compose_editor_statusbar(w)
	if app.editor.delete_menu_open {
		compose_editor_delete_popup()
	}
	if app.editor.confirm_exit_open {
		compose_editor_exit_dialog()
	}
}

@(private)
BAR :: "bg-linear-to-b from-bitumen-raised to-bitumen pointer-events-auto"

@(private)
compose_editor_topbar :: proc(w: f32) {
	ed := &app.editor
	compact := w < 1400
	if ui.div(ui.cx("absolute inset-x-0 top-0 flex h-[44px] items-center gap-1.5 border-b-2 border-brass-lo px-2.5", BAR)) {
		ui.text(fmt.tprintf("%s%s", ed.mesh.id, ed.mesh.dirty ? "*" : ""), ed.mesh.dirty ? "max-w-[140px] shrink-0 truncate rounded-sm bg-brass-lo/50 px-2 py-0.5 text-[13px] font-extrabold text-brass-hi ring-1 ring-brass" : "max-w-[140px] shrink-0 truncate rounded-sm bg-bitumen-deep px-2 py-0.5 text-[13px] font-bold text-silver ring-1 ring-brass-lo")
		divider()
		MODES := [3]string{"1 Vert", "2 Edge", "3 Face"}
		MODE_IC := [3]Icon_Id{.Mode_Vert, .Mode_Edge, .Mode_Face}
		if ui.div("flex gap-0.5 rounded-[5px] bg-bitumen-deep p-0.5 ring-1 ring-brass-lo") {
			for m, i in MODES {
				ui.push_id(i)
				if chip_button(m, int(ed.mesh.mode) == i, icon_tex(MODE_IC[i])) {
					handle_editor_ui_msg(.Ed_Mode, i32(i), {})
				}
				ui.pop_id()
			}
		}
		divider()
		if chip_button("", false, icon_tex(.Undo)) {
			handle_editor_ui_msg(.Ed_Undo, 0, {})
		}
		if chip_button("", false, icon_tex(.Redo)) {
			handle_editor_ui_msg(.Ed_Redo, 0, {})
		}
		divider()
		if chip_button("Mirror", ed.mirror_x, icon_tex(.Mirror_X)) {
			handle_editor_ui_msg(.Ed_Mirror, 0, {})
		}
		if chip_button("Wire", ed.wire_overlay, icon_tex(.Wireframe)) {
			handle_editor_ui_msg(.Ed_Wire, 0, {})
		}
		if chip_button("X-Ray", ed.xray_mode, icon_tex(.XRay)) {
			handle_editor_ui_msg(.Ed_XRay, 0, {})
		}
		if chip_button("Y=0", false, icon_tex(.Floor_Y)) {
			handle_editor_ui_msg(.Ed_Floor_Y, 0, {})
		}
		if ed.mesh.skinned {
			if chip_button(compact ? "" : string(editor_pose_short_label(ed.pose_kind, compact)), ed.pose_kind != .Rest, icon_tex(.Pose)) {
				handle_editor_ui_msg(.Ed_Pose, 0, {})
			}
			if chip_button(string(editor_team_label(ed.preview_team)), false, icon_tex(.Team_Palette)) {
				handle_editor_ui_msg(.Ed_Team, 0, {})
			}
		}
		if chip_button(ed.use_watercolor ? "Paint" : "Lit", ed.use_watercolor, icon_tex(.Shader_WC)) {
			handle_editor_ui_msg(.Ed_Shader, 0, {})
		}
		ui.el("grow")
		if chip_button("Help", app.help_open) {
			handle_hud_ui_msg(.Help_Toggle)
		}
		if chip_button(compact ? "" : "Models", false, icon_tex(.Models)) {
			handle_editor_ui_msg(.Ed_Models, 0, {})
		}
		if chip_button(compact ? "" : "Anims", false, icon_tex(.Pose)) {
			handle_editor_ui_msg(.Ed_Anims, 0, {})
		}
		if chip_button(compact ? "" : "Reset", false, icon_tex(.Reset)) {
			handle_editor_ui_msg(.Ed_Reset, 0, {})
		}
		if plaque_button(ed.mesh.dirty ? "Save*" : "Save", .Inlay, "", icon_tex(.Save), "h-8 px-3") {
			handle_editor_ui_msg(.Ed_Save, 0, {})
		}
		if plaque_button("Game", .Lapis, "", icon_tex(.Game), "h-8 px-3") {
			handle_editor_ui_msg(.Ed_Game, 0, {})
		}
	}
}

@(private)
divider :: proc(loc := #caller_location) {
	ui.el("mx-1 h-6 w-px shrink-0 bg-brass-lo", loc = loc)
}

@(private)
compose_editor_tool_rail :: proc(h: f32) {
	ed := &app.editor
	if ui.div(ui.cx("absolute top-[44px] bottom-[28px] left-0 flex w-[88px] flex-col gap-1 overflow-y-auto border-r-2 border-brass-lo p-1.5", BAR)) {
		LABELS := [12]string{"Select", "Box", "Grab", "Rotate", "Scale", "Extrude", "Inset", "Loop", "Knife", "Fill", "Merge", "Delete"}
		KEYS := [12]string{"", "B", "G", "R", "S", "E", "I", "^R", "K", "F", "M", "X"}
		ICONS := [12]Icon_Id{.Tool_Select, .Tool_Box, .Tool_Grab, .Tool_Rotate, .Tool_Scale, .Tool_Extrude, .Tool_Inset, .Tool_Loop_Cut, .Tool_Knife, .Tool_Fill, .Tool_Merge, .Tool_Delete}
		for i in 0 ..< 12 {
			ui.push_id(i)
			active := (i < 11 && int(ed.tool) == i) || (i == 11 && ed.delete_menu_open)
			cls := active ? "relative flex min-h-[44px] grow flex-col items-center justify-center gap-0.5 rounded-[6px] corner-bevel bg-radial from-inlay via-brass-hi to-[#7c5d2a] ring-1 ring-silver" : "relative flex min-h-[44px] grow flex-col items-center justify-center gap-0.5 rounded-[6px] corner-bevel bg-linear-to-b from-bitumen-raised to-bitumen-deep ring-1 ring-brass-lo hover:ring-brass-hi"
			if ui.button_box(cls) {
				ui.el(ui.cx("size-[18px]", active ? "bg-[#2a1a08]" : "bg-silver", icon_tex(ICONS[i])))
				ui.text(LABELS[i], active ? "text-[11px] font-extrabold uppercase tracking-wide text-[#2a1a08]" : "text-[11px] font-bold uppercase tracking-wide text-silver")
				if KEYS[i] != "" {
					ui.text(KEYS[i], active ? "absolute top-0.5 right-1 text-[10px] font-extrabold text-[#2a1a08]/70" : "absolute top-0.5 right-1 text-[10px] font-extrabold text-brass-hi/80")
				}
				if ui.clicked() {
					handle_editor_ui_msg(.Ed_Tool, i32(i), input_mouse_pos())
				}
			}
			ui.pop_id()
		}
	}
}

@(private)
compose_editor_inspector :: proc(w, h: f32) {
	ed := &app.editor
	if ui.div(ui.cx("absolute top-[44px] right-0 bottom-[28px] flex w-[272px] flex-col gap-2.5 overflow-y-auto border-l-2 border-brass-lo p-2.5", BAR)) {
		// telemetry
		if inspector_card("Mesh") {
			if chip_button("Smooth", false, extra = "absolute top-2.5 right-2.5 h-6") {
				handle_editor_ui_msg(.Ed_Smooth, 0, {})
			}
			sv, se, sf := edit.edit_mesh_selected_counts(&ed.mesh)
			if ui.div("grid grid-cols-3 gap-1.5") {
				tele_cell("Verts", len(ed.mesh.verts), sv)
				tele_cell("Edges", len(ed.mesh.edges), se)
				tele_cell("Faces", len(ed.mesh.faces), sf)
			}
			if c, ok := edit.edit_selection_center(&ed.mesh); ok {
				ui.text(fmt.tprintf("Centre  %.2f  %.2f  %.2f", c[0], c[1], c[2]), "text-[12px] font-bold tabular-nums text-silver-dim")
			} else {
				ui.text("Nothing selected", "text-[12px] font-bold text-silver-dim")
			}
		}
		// materials
		if inspector_card("Material") {
			ui.text(spec.MAT_NAMES[ed.active_mat], "absolute top-3 right-3 text-[12px] font-extrabold uppercase tracking-wider text-brass-hi")
			if ui.div("grid grid-cols-8 gap-1") {
				for m in 0 ..< int(art.Mat_Kind.COUNT) {
					ui.push_id(m)
					kind := art.Mat_Kind(m)
					sel := kind == ed.active_mat
					if ui.button_box(sel ? "h-[22px] rounded-[3px] ring-2 ring-inlay" : "h-[22px] rounded-[3px] ring-1 ring-black/60 hover:ring-brass-hi") {
						c := art.MAT_DEFS[kind].albedo
						ui.style().bg = ui.Color{f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255, 1}
						if ui.clicked() {
							handle_editor_ui_msg(.Ed_Mat, i32(m), {})
						}
					}
					ui.pop_id()
				}
			}
		}
		// bones
		if ed.mesh.skinned {
			if inspector_card("Bone", "min-h-0 grow") {
				if chip_button("Select", false, extra = "absolute top-2.5 right-2.5 h-6") {
					handle_editor_ui_msg(.Ed_Bone_Sel, 0, {})
				}
				if ui.div("grid min-h-0 grid-cols-3 gap-1 overflow-y-auto") {
					for b in 0 ..< int(art.Bone_Id.COUNT) {
						ui.push_id(b)
						bone := art.Bone_Id(b)
						sel := bone == ed.active_bone
						if ui.button_box(sel ? "flex h-[22px] min-w-0 items-center justify-center rounded-[4px] corner-bevel bg-linear-to-b from-brass-hi to-[#7c5d2a] px-1 ring-1 ring-silver" : "flex h-[22px] min-w-0 items-center justify-center rounded-[4px] corner-bevel bg-bitumen-deep px-1 ring-1 ring-brass-lo/70 hover:ring-brass") {
							ui.text(spec.BONE_NAMES[bone], sel ? "truncate text-[11px] font-extrabold text-[#2a1a08]" : "truncate text-[11px] font-bold text-silver")
							if ui.clicked() {
								handle_editor_ui_msg(.Ed_Bone, i32(b), {})
							}
						}
						ui.pop_id()
					}
				}
			}
		}
	}
}

@(deferred_none = ui.close)
inspector_card :: proc(title: string, extra := "", loc := #caller_location) -> bool {
	ui.open(ui.cx("relative flex shrink-0 flex-col gap-2.5 rounded-[8px] corner-bevel bg-bitumen-deep p-3 ring-1 ring-brass-lo/80", extra), loc = loc)
	ui.text(title, "font-display text-[15px] font-bold text-brass-hi")
	return true
}

@(private)
tele_cell :: proc(label: string, total, sel: int, loc := #caller_location) {
	if ui.div("flex flex-col rounded-[4px] bg-bitumen-raised px-2 py-1 ring-1 ring-brass-lo/50", loc = loc) {
		ui.text(label, "text-[11px] font-bold uppercase tracking-wider text-silver-dim")
		ui.text(fmt.tprintf("%d", total), "text-[14px] font-extrabold tabular-nums text-silver")
		ui.text(fmt.tprintf("%d sel", sel), sel > 0 ? "text-[11px] font-extrabold tabular-nums text-brass-hi" : "text-[11px] font-bold tabular-nums text-silver-dim")
	}
}

@(private)
compose_editor_statusbar :: proc(w: f32) {
	ed := &app.editor
	if ui.div(ui.cx("absolute inset-x-0 bottom-0 flex h-[28px] items-center gap-4 border-t-2 border-brass-lo px-3", BAR)) {
		msg := string(editor_modal_status_text())
		cls := "text-[12px] font-extrabold text-lapis-hi"
		if len(msg) == 0 {
			msg = string(editor_status_cstr())
			cls = ed.status_is_error ? "text-[12px] font-extrabold text-carnelian-hi" : "text-[12px] font-extrabold text-brass-hi"
		}
		ui.text(msg, ui.cx("grow truncate", cls))
		if w >= 1120 {
			HINTS := [7][2]string{{"F1", "Help"}, {"G R S", "+ X Y Z"}, {"E", "Extrude"}, {"I", "Inset"}, {"^R", "Loop"}, {"K", "Knife"}, {"X", "Delete"}}
			for hnt, i in HINTS {
				ui.push_id(i)
				if ui.div("flex items-center gap-1") {
					ui.text(hnt[0], "text-[11px] font-extrabold text-brass-hi")
					ui.text(hnt[1], "text-[11px] font-bold text-silver-dim")
				}
				ui.pop_id()
			}
		}
	}
}

@(private)
compose_editor_delete_popup :: proc() {
	pos := app.editor.delete_menu_pos
	if ui.button_box("absolute inset-0 cursor-default pointer-events-auto") {
		if ui.clicked_self() {
			handle_editor_ui_msg(.Ed_Delete_Choice, -1, {})
		}
		if ui.div("absolute w-[200px]") {
			ui.style().inset = {ui.px(pos.y), {}, {}, ui.px(pos.x)}
			if basin_panel("", "flex flex-col gap-1 p-2") {
				ui.text("Delete", "px-1 pb-1 font-display text-[15px] font-bold text-brass-hi")
				LABELS := [4]string{"Vertices", "Edges", "Faces", "Dissolve edges"}
				KEYS := [4]string{"V", "E", "F", "D"}
				for l, i in LABELS {
					ui.push_id(i)
					if ui.button_box("flex h-8 items-center gap-2 rounded-[4px] corner-bevel px-2 hover:bg-carnelian/60") {
						ui.text(l, "grow text-[13px] font-bold text-silver")
						keycap(KEYS[i])
						if ui.clicked() {
							handle_editor_ui_msg(.Ed_Delete_Choice, i32(i), {})
						}
					}
					ui.pop_id()
				}
			}
		}
	}
}

@(private)
compose_editor_exit_dialog :: proc() {
	if ui.button_box("absolute inset-0 flex items-center justify-center bg-black/60 cursor-default pointer-events-auto") {
		if ui.clicked_self() {
			handle_editor_ui_msg(.Ed_Exit_Cancel, 0, {})
		}
		if basin_panel("w-[440px]", "flex flex-col gap-3 p-6") {
			ui.text("Unsaved mesh changes", "font-display text-[20px] font-bold text-brass-hi")
			ui.text(fmt.tprintf("Save your edits to %s/*.odin before leaving the editor?", app.editor.mesh.id), "text-[14px] font-bold text-silver")
			if ui.div("mt-2 flex gap-2") {
				if plaque_button("Cancel", .Brass, "", "", "grow") {
					handle_editor_ui_msg(.Ed_Exit_Cancel, 0, {})
				}
				if plaque_button("Discard", .Carnelian, "", "", "grow") {
					handle_editor_ui_msg(.Ed_Exit_Discard, 0, {})
				}
				if plaque_button("Save & exit", .Inlay, "", "", "grow") {
					handle_editor_ui_msg(.Ed_Exit_Save, 0, {})
				}
			}
		}
	}
}
