// Animation Editor right-hand inspector: bone rotation sliders, root offset, keyframe, and clip cards.
package main

import "core:fmt"
import "core:math"
import anim_edit "./art/anim_edit"
import spec "./art/spec"
import ui "vinland:vui"

RAD_TO_DEG :: f32(180.0 / math.PI)
DEG_TO_RAD :: f32(math.PI / 180.0)

compose_anim_inspector :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return
	}
	if ui.div(ui.cx("absolute top-[44px] right-0 bottom-[264px] flex w-[280px] flex-col gap-2 overflow-y-auto border-l-2 border-brass-lo p-2.5", BAR)) {
		ui.style().inset[2] = anim_side_bottom_px()
		compose_anim_bone_card()
		compose_anim_root_card()
		compose_anim_keyframe_card()
		compose_anim_clip_card()
	}
}

@(private)
arm_slider_undo :: proc() {
	ed := &app.anim_ed
	if !ed.slider_undo_armed {
		anim_edit.anim_undo_push(&ed.undo, &ed.clip)
		ed.slider_undo_armed = true
	}
}

@(private)
anim_slider_row :: proc(label: string, val: ^f32, lo, hi: f32, fmt_str: string, loc := #caller_location) -> bool {
	changed := false
	if ui.div("flex items-center gap-2", loc = loc) {
		ui.text(label, "w-[36px] shrink-0 text-[11px] font-extrabold uppercase text-silver-dim")
		if ui.slider(val, lo, hi, "relative h-2.5 grow rounded-full bg-bitumen-raised ring-1 ring-brass-lo/70", "absolute rounded-full bg-brass", "absolute size-3.5 rounded-full bg-inlay ring-1 ring-black") {
			changed = true
		}
		ui.text(fmt.tprintf(fmt_str, val^), "w-[48px] shrink-0 text-right text-[11px] font-bold tabular-nums text-silver")
	}
	return changed
}

@(private)
compose_anim_bone_card :: proc() {
	ed := &app.anim_ed
	if inspector_card(fmt.tprintf("Bone · %s", spec.BONE_NAMES[ed.selected_bone])) {
		if chip_button("Zero", false, extra = "absolute top-2.5 right-2.5 h-6") {
			handle_anim_ui_msg(.Anim_Zero_Bone, 0)
		}
		bi := int(ed.selected_bone)
		deg: [3]f32
		if len(ed.clip.keyframes) > 0 {
			kf := &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]
			deg = {kf.rot[bi][0] * RAD_TO_DEG, kf.rot[bi][1] * RAD_TO_DEG, kf.rot[bi][2] * RAD_TO_DEG}
		}
		AXES := [3]string{"X Pit", "Y Yaw", "Z Rol"}
		for ax in 0 ..< 3 {
			ui.push_id(ax)
			if anim_slider_row(AXES[ax], &deg[ax], -180, 180, "%.0f°") {
				arm_slider_undo()
				kf := anim_ensure_editable_kf()
				rot := kf.rot[bi]
				rot[ax] = deg[ax] * DEG_TO_RAD
				anim_edit.clip_set_bone_rot(kf, ed.selected_bone, rot, ed.mirror_lr)
				anim_edit.recompute_clip_handles(&ed.clip)
				ed.clip.dirty = true
			}
			ui.pop_id()
		}
	}
}

@(private)
compose_anim_root_card :: proc() {
	ed := &app.anim_ed
	if inspector_card("Root Offset") {
		if chip_button("Y=0", false, extra = "absolute top-2.5 right-2.5 h-6") {
			handle_anim_ui_msg(.Anim_Ground_Y0, 0)
		}
		root_off: [3]f32
		if len(ed.clip.keyframes) > 0 {
			root_off = ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)].root_offset
		}
		AXES := [3]string{"RootX", "RootY", "RootZ"}
		for ax in 0 ..< 3 {
			ui.push_id(ax)
			if anim_slider_row(AXES[ax], &root_off[ax], -0.5, 0.5, "%.2f") {
				arm_slider_undo()
				kf := anim_ensure_editable_kf()
				kf.root_offset[ax] = root_off[ax]
				anim_edit.recompute_clip_handles(&ed.clip)
				ed.clip.dirty = true
			}
			ui.pop_id()
		}
	}
}

@(private)
compose_anim_keyframe_card :: proc() {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	idx := clamp(ed.selected_kf, 0, max(n - 1, 0))
	t_val := n > 0 ? ed.clip.keyframes[idx].time : 0
	if inspector_card(fmt.tprintf("Keyframe %d / %d", idx + 1, n)) {
		ui.text(fmt.tprintf("t = %.3f", t_val), "absolute top-3 right-3 text-[12px] font-extrabold tabular-nums text-silver")
		cur_interp := n > 0 ? ed.clip.keyframes[idx].interp : spec.Anim_Interp.Smooth
		INTERPS := [5]string{"Smooth", "Lin", "In", "Out", "Step"}
		KINDS := [5]spec.Anim_Interp{.Smooth, .Linear, .Ease_In, .Ease_Out, .Step}
		if ui.div("flex gap-1") {
			for lbl, i in INTERPS {
				ui.push_id(i)
				if chip_button(lbl, cur_interp == KINDS[i], "", "grow justify-center px-1") {
					handle_anim_ui_msg(.Anim_Interp, i32(KINDS[i]))
				}
				ui.pop_id()
			}
		}
		if ui.div("grid grid-cols-3 gap-1") {
			if chip_button("+Key", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Add_Key, 0) }
			if chip_button("Copy", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Copy_Pose, 0) }
			if chip_button("Paste", false, "", "justify-center") { handle_anim_ui_msg(.Anim_Paste_Pose, 0) }
		}
	}
}

@(private)
compose_anim_clip_card :: proc() {
	ed := &app.anim_ed
	if inspector_card("Clip Settings") {
		dur := ed.clip.duration
		if anim_slider_row("Dur", &dur, 0.15, 6.0, "%.2fs") {
			arm_slider_undo()
			ed.clip.duration = dur
			ed.clip.dirty = true
		}
		sec := ed.clip.secondary_weight
		if anim_slider_row("Cloth", &sec, 0.0, 1.5, "%.2f") {
			arm_slider_undo()
			ed.clip.secondary_weight = sec
			ed.clip.dirty = true
		}
		if ui.div("flex gap-1.5") {
			if chip_button("Loop", ed.clip.loop, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Toggle_Loop, 0) }
			if chip_button("Additive", ed.clip.additive, "", "grow justify-center") { handle_anim_ui_msg(.Anim_Toggle_Additive, 0) }
		}
	}
}

// Dynamic bottom inset applied to right inspector and left bone rail so Tall dock resizes cleanly.
anim_side_bottom_px :: proc() -> ui.Size {
	return ui.px(anim_editor_dock_h() + ANIM_STATUS_H)
}
