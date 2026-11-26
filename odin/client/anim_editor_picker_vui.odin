// Animation Picker Basin UI chrome: split catalog list, source badges, and animated turntable card.
package main

import "core:fmt"
import art "./art"
import ui "vinland:vui"

compose_anim_picker :: proc(w, h: f32) {
	if ui.div("absolute inset-0 flex items-center justify-center bg-black/55 p-4 pointer-events-auto") {
		if basin_panel("flex h-full max-h-[640px] w-full max-w-[1000px]", "flex min-h-0 grow flex-col gap-4 p-5") {
			compose_anim_picker_header()
			ui.el("h-2 shrink-0 bg-brass/50 bg-tex-interlace bg-tile-8")
			if ui.div("flex min-h-0 grow gap-5") {
				compose_anim_picker_list()
				compose_anim_picker_preview()
			}
			compose_anim_picker_footer()
		}
	}
}

@(private)
compose_anim_picker_header :: proc() {
	if ui.div("flex items-center gap-3") {
		ui.el(ui.cx("size-6 bg-brass-hi", icon_tex(.Pose)))
		ui.text("Animation Editor", "font-display text-[22px] font-bold text-brass-hi")
		ui.text("Pick a clip to animate", "grow text-[13px] font-bold uppercase tracking-[0.12em] text-silver-dim")
		ui.text(fmt.tprintf("%d clips", len(art.ANIM_CATALOG)), "text-[13px] font-bold tabular-nums text-silver-dim")
	}
}

@(private)
compose_anim_picker_list :: proc() {
	ed := &app.anim_ed
	if ui.div("flex w-[42%] min-w-[300px] flex-col gap-3") {
		if ui.div("flex gap-1 rounded-[6px] bg-bitumen-deep p-1 ring-1 ring-brass-lo") {
			TABS := [4]string{"All", "Base", "Hero", "Enemy"}
			for t, i in TABS {
				ui.push_id(i)
				if chip_button(t, ed.picker_cat == i, "", "grow justify-center") {
					handle_anim_picker_ui_msg(.Anim_Picker_Tab, i32(i))
				}
				ui.pop_id()
			}
		}
		if ui.div("flex min-h-0 grow flex-col gap-1 overflow-y-auto rounded-[8px] bg-bitumen-deep p-2 ring-1 ring-brass-lo/70") {
			rows, count := anim_picker_filtered_indices(ed.picker_cat)
			for r in rows[:count] {
				ui.push_id(r)
				entry := art.ANIM_CATALOG[r]
				sel := r == ed.picker_idx
				row_cls := sel ? "flex h-10 shrink-0 items-center gap-3 rounded-[5px] corner-bevel bg-linear-to-r from-brass-lo/70 to-bitumen-raised px-3 ring-1 ring-brass-hi" : "flex h-10 shrink-0 items-center gap-3 rounded-[5px] corner-bevel px-3 ring-1 ring-transparent hover:bg-bitumen-raised hover:ring-brass-lo"
				if ui.button_box(row_cls) {
					ui.text(entry.title, sel ? "grow text-[14px] font-extrabold text-inlay" : "grow text-[14px] font-bold text-silver-dim")
					tag, tag_cls := anim_picker_source_tag(entry)
					ui.text(tag, tag_cls)
					if ui.clicked() {
						handle_anim_picker_ui_msg(.Anim_Picker_Row, i32(r))
					}
				}
				ui.pop_id()
			}
		}
	}
}

@(private)
compose_anim_picker_preview :: proc() {
	ed := &app.anim_ed
	idx := clamp(ed.picker_idx, 0, len(art.ANIM_CATALOG) - 1)
	e := art.ANIM_CATALOG[idx]
	dur := art.anim_clip_duration(e.kind, e.category == .Enemy, e.category == .Hero)
	if ui.div("flex min-w-0 grow flex-col gap-3") {
		if ui.div(ui.cx("relative min-h-0 grow rounded-[14px] corner-scoop p-[4px]", BRASS_RIM)) {
			if ui.div("size-full overflow-hidden rounded-[11px] corner-scoop bg-[#16201a]") {
				ui.image(vh.anim_picker_img, "size-full object-cover")
			}
		}
		if ui.div("flex items-baseline gap-3") {
			ui.text(e.title, "font-display text-[20px] font-bold text-brass-hi")
			ui.text(e.id, "rounded-sm bg-bitumen-deep px-1.5 text-[12px] font-bold text-silver-dim ring-1 ring-brass-lo")
			ui.el("grow")
			ui.text(fmt.tprintf("%.2fs", dur), VALUE)
		}
		mode_str := e.additive ? "Additive combat cleave" : (e.loop ? "Looping cycle" : "One-shot clip")
		ui.text(fmt.tprintf("%s · 25-bone rig · Cloth flutter %.2f", mode_str, e.secondary_weight), "text-[13px] font-bold tabular-nums text-silver")
		ui.text(e.base_fallback != "" ? fmt.tprintf("Forks on save: inherits %s until customised.", e.base_fallback) : "Direct asset in odin/client/art/anims/.", "text-[13px] font-bold text-silver-dim")
	}
}

@(private)
compose_anim_picker_footer :: proc() {
	if ui.div("flex items-center gap-3") {
		if plaque_button("Back to battle", .Brass, "Esc", icon_tex(.Game)) {
			handle_anim_picker_ui_msg(.Anim_Picker_Back, 0)
		}
		ui.el("grow")
		if plaque_button("Edit procedural", .Lapis, "", icon_tex(.Reset)) {
			handle_anim_picker_ui_msg(.Anim_Picker_Edit_Proc, 0)
		}
		if plaque_button("Edit clip", .Inlay, "Enter", icon_tex(.Pose)) {
			handle_anim_picker_ui_msg(.Anim_Picker_Edit_Clip, 0)
		}
	}
}

@(private)
anim_picker_source_tag :: proc(entry: art.Anim_Catalog_Entry) -> (string, string) {
	BASE :: "rounded-sm px-1.5 text-[11px] font-extrabold uppercase tracking-wider ring-1 "
	if art.anim_catalog_has_custom_odin(entry.id) {
		return "Custom", BASE + "bg-brass-lo/40 text-brass-hi ring-brass"
	}
	if entry.base_fallback != "" && art.anim_catalog_has_custom_odin(entry.base_fallback) {
		return "Shared*", BASE + "bg-amber-alert/15 text-amber-alert ring-amber-alert/60"
	}
	if entry.base_fallback != "" {
		return "Shared", BASE + "bg-lapis-lo text-silver ring-lapis-hi"
	}
	return "Proc", BASE + "bg-bitumen-deep text-silver-dim ring-brass-lo"
}
