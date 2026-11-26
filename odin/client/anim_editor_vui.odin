// Animation Editor Basin UI chrome: topbar, bone tree, Curves/Dopesheet dock, statusbar, dialogs.
package main

import "core:fmt"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import spec "./art/spec"
import ui "vinland:vui"

compose_anim_editor :: proc(w, h: f32) {
	compose_anim_topbar(w)
	compose_anim_bone_rail()
	compose_anim_inspector()
	compose_anim_timeline(w)
	compose_anim_statusbar(w)
	if app.anim_ed.confirm_exit_open {
		compose_anim_exit_dialog()
	}
}

@(private)
compose_anim_topbar :: proc(w: f32) {
	ed := &app.anim_ed
	compact := w < 1380
	if ui.div(ui.cx("absolute inset-x-0 top-0 flex h-[44px] items-center gap-1.5 border-b-2 border-brass-lo px-2.5", BAR)) {
		ui.text(fmt.tprintf("%s%s", ed.clip.id, ed.clip.dirty ? "*" : ""), ed.clip.dirty ? "max-w-[130px] shrink-0 truncate rounded-sm bg-brass-lo/50 px-2 py-0.5 text-[13px] font-extrabold text-brass-hi ring-1 ring-brass" : "max-w-[130px] shrink-0 truncate rounded-sm bg-bitumen-deep px-2 py-0.5 text-[13px] font-bold text-silver ring-1 ring-brass-lo")
		divider()
		if chip_button(ed.playing ? "Pause" : "Play", ed.playing) { handle_anim_ui_msg(.Anim_Play_Toggle, 0) }
		if chip_button("|<", false) { handle_anim_ui_msg(.Anim_Prev_Kf, 0) }
		if chip_button(">|", false) { handle_anim_ui_msg(.Anim_Next_Kf, 0) }
		if chip_button(fmt.tprintf("%.2gx", ed.play_speed), ed.play_speed != 1.0) { handle_anim_ui_msg(.Anim_Speed, 0) }
		divider()
		if chip_button("", false, icon_tex(.Undo)) { handle_anim_ui_msg(.Anim_Undo, 0) }
		if chip_button("", false, icon_tex(.Redo)) { handle_anim_ui_msg(.Anim_Redo, 0) }
		divider()
		rig_lbl := ed.rig_mode == .Rig ? "Rig" : (ed.rig_mode == .Bones ? "Bones" : "Both")
		if chip_button(rig_lbl, ed.rig_mode != .Bones, icon_tex(.Pose)) { handle_anim_ui_msg(.Anim_Rig_Mode, 0) }
		if chip_button(compact ? "Pin" : "Pin Feet", ed.rig.pin_feet) { handle_anim_ui_msg(.Anim_Pin_Feet, 0) }
		if chip_button("X-Ray", ed.xray_bones, icon_tex(.XRay)) { handle_anim_ui_msg(.Anim_Toggle_XRay, 0) }
		if chip_button("Onion", ed.onion_skin) { handle_anim_ui_msg(.Anim_Toggle_Onion, 0) }
		if chip_button("Mirror", ed.mirror_lr, icon_tex(.Mirror_X)) { handle_anim_ui_msg(.Anim_Toggle_Mirror, 0) }
		if chip_button(compact ? "Auto" : "AutoKey", ed.auto_key) { handle_anim_ui_msg(.Anim_Toggle_AutoKey, 0) }
		if chip_button(string(editor_team_label(ed.preview_team)), false, icon_tex(.Team_Palette)) { handle_anim_ui_msg(.Anim_Team, 0) }
		if chip_button(ed.use_watercolor ? "Paint" : "Lit", ed.use_watercolor, icon_tex(.Shader_WC)) { handle_anim_ui_msg(.Anim_Shader, 0) }
		ui.el("grow")
		if chip_button("Help", app.help_open) { handle_hud_ui_msg(.Help_Toggle) }
		if chip_button(compact ? "" : "Models", false, icon_tex(.Models)) { handle_anim_ui_msg(.Anim_Models, 0) }
		if chip_button(compact ? "" : "Clips", false, icon_tex(.Pose)) { handle_anim_ui_msg(.Anim_Clips, 0) }
		if chip_button(compact ? "" : "Reset", false, icon_tex(.Reset)) { handle_anim_ui_msg(.Anim_Reset, 0) }
		if plaque_button(ed.clip.dirty ? "Save*" : "Save", .Inlay, "", icon_tex(.Save), "h-8 px-3") { handle_anim_ui_msg(.Anim_Save, 0) }
		if plaque_button("Game", .Lapis, "", icon_tex(.Game), "h-8 px-3") { handle_anim_ui_msg(.Anim_Game, 0) }
	}
}

@(private)
bone_tree_depth :: proc(b: art.Bone_Id) -> int {
	depth := 0
	cur := b
	for !art.BONES[cur].root && depth < 12 {
		cur = art.BONES[cur].parent
		depth += 1
	}
	return depth
}

@(private)
compose_anim_bone_rail :: proc() {
	ed := &app.anim_ed
	if ui.div(ui.cx("absolute top-[44px] bottom-[264px] left-0 flex w-[176px] flex-col gap-1.5 border-r-2 border-brass-lo p-2", BAR)) {
		ui.style().inset[2] = anim_side_bottom_px()
		if ui.div("grid grid-cols-2 gap-1") {
			if chip_button("Rotate", ed.tool == .Rotate, icon_tex(.Tool_Rotate), "justify-center") { handle_anim_ui_msg(.Anim_Tool, 1) }
			if chip_button(anim_is_rig_active() ? "Move" : "Root", ed.tool == .Move_Root, icon_tex(.Tool_Grab), "justify-center") { handle_anim_ui_msg(.Anim_Tool, 2) }
			if chip_button("Zero", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Zero_Bone, 0) }
			if chip_button("Y=0", false, icon_tex(.Floor_Y), "justify-center") { handle_anim_ui_msg(.Anim_Ground_Y0, 0) }
			if chip_button("Flip L/R", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Flip_LR, 0) }
			if chip_button("+Key", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Add_Key, 0) }
		}
		compose_selection_presets()
		if ed.rig_mode != .Bones {
			ui.text("Motion Ctrls (12)", "text-[11px] font-bold uppercase tracking-wider text-brass-hi")
			if ui.div("flex min-h-0 grow flex-col gap-0.5 overflow-y-auto rounded-[6px] bg-bitumen-deep p-1 ring-1 ring-brass-lo/70") {
				compose_ctrl_list_rows()
			}
		}
		if ed.rig_mode != .Rig {
			ui.text("Skeleton (25)", "text-[11px] font-bold uppercase tracking-wider text-brass-hi")
			if ui.div("flex min-h-0 grow flex-col gap-0.5 overflow-y-auto rounded-[6px] bg-bitumen-deep p-1 ring-1 ring-brass-lo/70") {
				compose_bone_tree_rows()
			}
		}
	}
}

@(private)
compose_selection_presets :: proc() {
	PRESETS := [8]string{"Spine", "L Arm", "R Arm", "L Leg", "R Leg", "Cape", "All", "Chain"}
	if ui.div("grid grid-cols-4 gap-0.5") {
		for lbl, i in PRESETS {
			ui.push_id(i)
			if chip_button(lbl, false, "", "h-5 justify-center px-1 text-[10px]") {
				handle_anim_ui_msg(.Anim_Select_Preset, i32(i))
			}
			ui.pop_id()
		}
	}
}

@(private)
compose_ctrl_list_rows :: proc() {
	ed := &app.anim_ed
	for ci in 0 ..< art_rig.CTRL_COUNT {
		ui.push_id(ci)
		c := art_rig.Control_Id(ci)
		def := art_rig.CONTROLS[c]
		prim := c == ed.selected_ctrl
		sel := ed.selected_ctrls[ci]
		cls := prim ? "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] bg-linear-to-r from-brass-hi to-[#7c5d2a] px-1.5 ring-1 ring-silver" : (sel ? "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] bg-brass-lo/45 px-1.5 ring-1 ring-brass" : "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] px-1.5 hover:bg-bitumen-raised")
		dot := def.side < 0 ? "size-2 shrink-0 rounded-full bg-[#5ca8ff]" : (def.side > 0 ? "size-2 shrink-0 rounded-full bg-[#f06c5c]" : "size-2 shrink-0 rounded-full bg-brass-hi")
		if ui.button_box(cls) {
			ui.el(dot)
			ui.text(def.name, prim ? "truncate text-[11px] font-extrabold text-[#2a1a08]" : "truncate text-[11px] font-bold text-silver")
			if ui.clicked() { handle_anim_ui_msg(.Anim_Select_Ctrl, i32(ci)) }
		}
		ui.pop_id()
	}
}

@(private)
compose_bone_tree_rows :: proc() {
	ed := &app.anim_ed
	has_kf := ed.clip_loaded && len(ed.clip.keyframes) > 0
	kf := has_kf ? &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)] : nil
	for bi in 0 ..< art.BONE_COUNT {
		ui.push_id(bi)
		bone := art.Bone_Id(bi)
		prim := bone == ed.selected_bone
		sel := ed.selected_bones[bi]
		depth := min(bone_tree_depth(bone), 5)
		keyed := false
		if kf != nil {
			r := kf.rot[bi]
			keyed = abs(r[0]) + abs(r[1]) + abs(r[2]) > 0.001
		}
		cls := prim ? "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] bg-linear-to-r from-brass-hi to-[#7c5d2a] px-1.5 ring-1 ring-silver" : (sel ? "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] bg-brass-lo/45 px-1.5 ring-1 ring-brass" : "flex h-6 shrink-0 items-center gap-1.5 rounded-[4px] px-1.5 hover:bg-bitumen-raised")
		if ui.button_box(cls) {
			ui.style().padding = {0, 6, 0, f32(6 + depth * 7)}
			ui.el(keyed ? "size-1.5 shrink-0 rounded-full bg-brass-hi" : "size-1.5 shrink-0 rounded-full bg-silver-dim/30")
			ui.text(spec.BONE_NAMES[bone], prim ? "truncate text-[11px] font-extrabold text-[#2a1a08]" : "truncate text-[11px] font-bold text-silver")
			if ui.clicked() {
				handle_anim_ui_msg(.Anim_Select_Bone, i32(bi))
			}
		}
		ui.pop_id()
	}
}

@(private)
compose_anim_timeline :: proc(w: f32) {
	ed := &app.anim_ed
	if ui.div(ui.cx("absolute inset-x-0 bottom-[28px] flex h-[236px] gap-2 border-t-2 border-brass-lo px-2.5 py-2", BAR)) {
		ui.style().height = ui.px(anim_editor_dock_h())
		compose_dock_transport()
		if ui.div("flex min-w-0 grow flex-col gap-1") {
			compose_dock_header(w)
			if ui.div("relative min-h-0 grow overflow-hidden rounded-[6px] bg-bitumen-deep ring-1 ring-brass-lo/80") {
				vh.anim_timeline_id = ui.current_id()
				if ed.dock_tab == .Curves {
					ui.canvas("size-full", draw_anim_curves_canvas)
					compose_curve_y_labels()
				} else {
					ui.canvas("size-full", draw_anim_timeline_canvas)
				}
			}
		}
	}
}

@(private)
compose_dock_transport :: proc() {
	ed := &app.anim_ed
	if ui.div("flex w-[166px] shrink-0 flex-col justify-between rounded-[6px] bg-bitumen-deep p-2 ring-1 ring-brass-lo/70") {
		dur := ed.clip_loaded ? ed.clip.duration : 1.0
		ui.text(fmt.tprintf("%.2fs / %.2fs", ed.playhead * dur, dur), "text-[12px] font-extrabold tabular-nums text-brass-hi")
		ui.text(fmt.tprintf("Phase %.3f  ·  KF %d/%d", ed.playhead, ed.selected_kf + 1, len(ed.clip.keyframes)), "text-[11px] font-bold tabular-nums text-silver-dim")
		if ui.div("flex gap-1") {
			if chip_button(ed.playing ? "Pause" : "Play", ed.playing, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Play_Toggle, 0) }
			if chip_button("|<", false) { handle_anim_ui_msg(.Anim_Prev_Kf, 0) }
			if chip_button(">|", false) { handle_anim_ui_msg(.Anim_Next_Kf, 0) }
		}
		if ui.div("flex gap-1") {
			if chip_button("+Key", false, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Add_Key, 0) }
			if chip_button("Dup", false, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Dup_Key, 0) }
			if chip_button("-Key", false, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Del_Key, 0) }
		}
	}
}

@(private)
compose_dock_header :: proc(w: f32) {
	ed := &app.anim_ed
	if ui.div("flex flex-wrap items-center gap-1.5") {
		if chip_button("Curves", ed.dock_tab == .Curves) { handle_anim_ui_msg(.Anim_Dock_Tab, 0) }
		if chip_button("Dopesheet", ed.dock_tab == .Dopesheet) { handle_anim_ui_msg(.Anim_Dock_Tab, 1) }
		if ed.dock_tab == .Curves {
			divider()
			if chip_button(ed.curve_is_root ? "Root" : spec.BONE_NAMES[ed.selected_bone], false) {
				handle_anim_ui_msg(.Anim_Curve_Target, ed.curve_is_root ? 0 : 1)
			}
			compose_curve_axis_chips()
			if w >= 1180 {
				divider()
				compose_curve_handle_chips()
			}
		}
		ui.el("grow")
		sc := anim_selected_kf_count()
		if sc > 1 {
			ui.text(fmt.tprintf("%d KFs", sc), "rounded-sm bg-brass-lo/50 px-1.5 py-0.5 text-[11px] font-extrabold text-brass-hi")
		}
		if chip_button("All", len(ed.clip.keyframes) > 0 && sc == len(ed.clip.keyframes)) { handle_anim_ui_msg(.Anim_Select_All_Kfs, 0) }
		if ed.dock_tab == .Curves {
			if chip_button("Fit", false) { handle_anim_ui_msg(.Anim_Curve_Fit, 0) }
		}
		if chip_button(ed.dock_tall ? "Compact" : "Tall", ed.dock_tall) { handle_anim_ui_msg(.Anim_Dock_Tall, 0) }
	}
}

@(private)
compose_curve_axis_chips :: proc() {
	ed := &app.anim_ed
	LABELS := [3]string{"X", "Y", "Z"}
	DOTS := [3]string{"bg-[#e85a5a]", "bg-[#5cd674]", "bg-[#58a0f0]"}
	for ax in 0 ..< 3 {
		ui.push_id(ax)
		vis := ed.curve_vis[ax]
		act := ed.curve_active_axis == ax && vis
		cls := act ? "flex h-7 items-center gap-1 rounded-[4px] corner-bevel bg-bitumen-raised px-2 ring-1 ring-brass-hi" : (vis ? "flex h-7 items-center gap-1 rounded-[4px] corner-bevel bg-bitumen-deep px-2 ring-1 ring-brass-lo" : "flex h-7 items-center gap-1 rounded-[4px] corner-bevel bg-bitumen-deep px-2 opacity-45 ring-1 ring-brass-lo/40")
		if ui.button_box(cls) {
			ui.el(ui.cx("size-2 rounded-full", DOTS[ax]))
			ui.text(LABELS[ax], act ? "text-[11px] font-extrabold text-brass-hi" : "text-[11px] font-bold text-silver")
			if ui.clicked() { handle_anim_ui_msg(.Anim_Curve_Axis, i32(ax)) }
		}
		ui.pop_id()
	}
}

@(private)
compose_curve_handle_chips :: proc() {
	ed := &app.anim_ed
	cur_h := spec.Anim_Handle.Auto_Clamped
	if ed.clip_loaded && len(ed.clip.keyframes) > 0 {
		ki := clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)
		cur_h, _, _ = anim_edit.channel_get_handles(&ed.clip.keyframes[ki], ed.curve_is_root, ed.selected_bone, ed.curve_active_axis)
	}
	HNAMES := [5]string{"Clamp", "Auto", "Align", "Free", "Vec"}
	for lbl, i in HNAMES {
		ui.push_id(i)
		if chip_button(lbl, int(cur_h) == i, "", "px-1.5") {
			handle_anim_ui_msg(.Anim_Curve_Handle, i32(i))
		}
		ui.pop_id()
	}
}

@(private)
compose_curve_y_labels :: proc() {
	ed := &app.anim_ed
	hi := ed.curve_is_root ? fmt.tprintf("%+.2fm", ed.curve_y_max) : fmt.tprintf("%+.0f°", ed.curve_y_max * RAD_TO_DEG)
	lo := ed.curve_is_root ? fmt.tprintf("%+.2fm", ed.curve_y_min) : fmt.tprintf("%+.0f°", ed.curve_y_min * RAD_TO_DEG)
	ui.text(hi, "pointer-events-none absolute top-[22px] left-1.5 rounded-sm bg-bitumen/80 px-1 text-[10px] font-bold tabular-nums text-silver-dim")
	ui.text(lo, "pointer-events-none absolute bottom-1 left-1.5 rounded-sm bg-bitumen/80 px-1 text-[10px] font-bold tabular-nums text-silver-dim")
}

@(private)
draw_anim_timeline_canvas :: proc(ctx: ^ui.Context, r: ui.Rect, _: rawptr) {
	ed := &app.anim_ed
	if r.w <= 4 || r.h <= 4 {
		return
	}
	ruler_h := f32(20)
	ui.draw_rect(ctx, {r.x, r.y, r.w, ruler_h}, ui.rgb(0x1b1611, 1))
	ui.draw_line(ctx, {r.x, r.y + ruler_h}, {r.x + r.w, r.y + ruler_h}, ui.rgb(0x584222, 1), 1)
	for i in 0 ..= 8 {
		tx := r.x + r.w * (f32(i) / 8.0)
		major := (i % 2) == 0
		ui.draw_line(ctx, {tx, r.y + (major ? 4 : 11)}, {tx, r.y + r.h}, major ? ui.rgb(0x584222, 0.55) : ui.rgb(0x3a2c18, 0.35), 1)
	}
	lane1_y := r.y + ruler_h + (r.h - ruler_h) * 0.33
	lane2_y := r.y + ruler_h + (r.h - ruler_h) * 0.72
	ui.draw_line(ctx, {r.x, lane1_y}, {r.x + r.w, lane1_y}, ui.rgb(0x3a2c18, 0.6), 1)
	ui.draw_line(ctx, {r.x, lane2_y}, {r.x + r.w, lane2_y}, ui.rgb(0x3a2c18, 0.6), 1)

	if ed.clip_loaded {
		bi := int(ed.selected_bone)
		for kf, i in ed.clip.keyframes {
			kx := r.x + kf.time * r.w
			sel := anim_is_kf_selected(i)
			hov := i == ed.hover_kf
			col := sel ? ui.rgb(0xecd9a6, 1) : (hov ? ui.rgb(0x6ee8ff, 1) : ui.rgb(0xcdb37c, 0.9))
			draw_diamond(ctx, {kx, lane1_y}, i == ed.selected_kf ? 6.5 : (sel ? 5.8 : 5.0), col)
			rot := kf.rot[bi]
			bone_keyed := abs(rot[0]) + abs(rot[1]) + abs(rot[2]) > 0.001
			if bone_keyed || sel {
				bcol := sel ? ui.rgb(0xecd9a6, 1) : ui.rgb(0x7ca2e0, 0.95)
				draw_diamond(ctx, {kx, lane2_y}, sel ? 5.5 : 4.2, bcol)
			}
		}
	}
	if ed.curve_box_active {
		mx := input_mouse_pos().x
		lo := clamp(min(ed.curve_box_start.x, mx), r.x, r.x + r.w)
		hi := clamp(max(ed.curve_box_start.x, mx), r.x, r.x + r.w)
		ui.draw_rect(ctx, {lo, r.y + ruler_h, hi - lo, r.h - ruler_h}, ui.rgb(0xecd9a6, 0.16))
	}
	px := r.x + clamp(ed.playhead, 0, 1) * r.w
	ui.draw_line(ctx, {px, r.y}, {px, r.y + r.h}, ui.rgb(0xecd9a6, 0.95), 2)
	ui.draw_rect(ctx, {px - 5, r.y + 1, 10, 10}, ui.rgb(0xecd9a6, 1), 2)
}

@(private)
draw_diamond :: proc(ctx: ^ui.Context, c: [2]f32, rad: f32, col: ui.Color) {
	pts := [5][2]f32{
		{c.x, c.y - rad},
		{c.x + rad, c.y},
		{c.x, c.y + rad},
		{c.x - rad, c.y},
		{c.x, c.y - rad},
	}
	ui.draw_rect(ctx, {c.x - rad * 0.55, c.y - rad * 0.55, rad * 1.1, rad * 1.1}, col, 1)
	ui.draw_polyline(ctx, pts[:], col, 1.5)
}

@(private)
compose_anim_statusbar :: proc(w: f32) {
	ed := &app.anim_ed
	if ui.div(ui.cx("absolute inset-x-0 bottom-0 flex h-[28px] items-center gap-4 border-t-2 border-brass-lo px-3", BAR)) {
		msg := string(anim_editor_modal_status_text())
		cls := "text-[12px] font-extrabold text-lapis-hi"
		if len(msg) == 0 {
			msg = string(anim_editor_status_cstr())
			cls = ed.status_is_error ? "text-[12px] font-extrabold text-carnelian-hi" : "text-[12px] font-extrabold text-brass-hi"
		}
		ui.text(msg, ui.cx("grow truncate", cls))
		if w >= 1120 {
			HINTS := [7][2]string{{"F1", "Help"}, {"Space", "Play"}, {"R", "Rotate"}, {"V", "Handle"}, {"T", "Interp"}, {"Home", "Fit"}, {"Ctrl+S", "Save"}}
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
compose_anim_exit_dialog :: proc() {
	if ui.button_box("absolute inset-0 flex items-center justify-center bg-black/60 cursor-default pointer-events-auto") {
		if ui.clicked_self() {
			handle_anim_ui_msg(.Anim_Exit_Cancel, 0)
		}
		if basin_panel("w-[440px]", "flex flex-col gap-3 p-6") {
			ui.text("Unsaved animation changes", "font-display text-[20px] font-bold text-brass-hi")
			ui.text(fmt.tprintf("Save your edits to %s/*.odin before leaving the editor?", app.anim_ed.clip.id), "text-[14px] font-bold text-silver")
			if ui.div("mt-2 flex gap-2") {
				if plaque_button("Cancel", .Brass, "", "", "grow") { handle_anim_ui_msg(.Anim_Exit_Cancel, 0) }
				if plaque_button("Discard", .Carnelian, "", "", "grow") { handle_anim_ui_msg(.Anim_Exit_Discard, 0) }
				if plaque_button("Save & exit", .Inlay, "", "", "grow") { handle_anim_ui_msg(.Anim_Exit_Save, 0) }
			}
		}
	}
}
