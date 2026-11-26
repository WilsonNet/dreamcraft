// Keyframe multiselect, box selection, multi-key drag/time-scale, and curve wheel zoom.
package main

import "core:math"
import rl "../gfx"
import anim_edit "./art/anim_edit"
import ui "vinland:vui"

anim_sync_kf_selection :: proc() {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if len(ed.selected_kfs) != n {
		resize(&ed.selected_kfs, n)
	}
	any_sel := false
	for i in 0 ..< n {
		if ed.selected_kfs[i] { any_sel = true; break }
	}
	if !any_sel && n > 0 {
		idx := clamp(ed.selected_kf, 0, n - 1)
		ed.selected_kfs[idx] = true
	}
}

anim_is_kf_selected :: proc(ki: int) -> bool {
	ed := &app.anim_ed
	if ki < 0 || ki >= len(ed.selected_kfs) {
		return ki == ed.selected_kf
	}
	return ed.selected_kfs[ki]
}

anim_selected_kf_count :: proc() -> int {
	ed := &app.anim_ed
	anim_sync_kf_selection()
	c := 0
	for s in ed.selected_kfs { if s { c += 1 } }
	return c
}

anim_select_kf_only :: proc(ki: int) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if n == 0 { return }
	idx := clamp(ki, 0, n - 1)
	if len(ed.selected_kfs) != n { resize(&ed.selected_kfs, n) }
	for i in 0 ..< n { ed.selected_kfs[i] = (i == idx) }
	ed.selected_kf = idx
}

anim_toggle_kf_select :: proc(ki: int) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if ki < 0 || ki >= n { return }
	anim_sync_kf_selection()
	cnt := anim_selected_kf_count()
	if ed.selected_kfs[ki] && cnt > 1 {
		ed.selected_kfs[ki] = false
		if ed.selected_kf == ki {
			for i in 0 ..< n {
				if ed.selected_kfs[i] { ed.selected_kf = i; break }
			}
		}
	} else {
		ed.selected_kfs[ki] = true
		ed.selected_kf = ki
	}
}

anim_select_all_kfs :: proc(toggle := true) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if n == 0 { return }
	anim_sync_kf_selection()
	all_on := true
	for i in 0 ..< n {
		if !ed.selected_kfs[i] { all_on = false; break }
	}
	if toggle && all_on {
		anim_select_kf_only(ed.selected_kf)
		return
	}
	for i in 0 ..< n { ed.selected_kfs[i] = true }
}

anim_capture_kf_drag_bases :: proc() {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	resize(&ed.curve_drag_base_times, n)
	resize(&ed.curve_drag_base_vals, n)
	for i in 0 ..< n {
		ed.curve_drag_base_times[i] = ed.clip.keyframes[i].time
		ed.curve_drag_base_vals[i] = anim_edit.channel_get_value(&ed.clip.keyframes[i], ed.curve_is_root, ed.selected_bone, ed.curve_active_axis)
	}
}

anim_curve_box_select :: proc(box: ui.Rect, r: ui.Rect, additive: bool) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if n == 0 { return }
	anim_sync_kf_selection()
	if !additive {
		for i in 0 ..< n { ed.selected_kfs[i] = false }
	}
	first := -1
	for &kf, ki in ed.clip.keyframes {
		for ax in 0 ..< 3 {
			if !ed.curve_vis[ax] { continue }
			pt := curve_to_screen(r, kf.time, anim_edit.channel_get_value(&kf, ed.curve_is_root, ed.selected_bone, ax))
			if pt.x >= box.x && pt.x <= box.x + box.w && pt.y >= box.y && pt.y <= box.y + box.h {
				ed.selected_kfs[ki] = true
				if first < 0 { first = ki }
				break
			}
		}
	}
	if first >= 0 { ed.selected_kf = first } else { anim_sync_kf_selection() }
}

anim_dopesheet_box_select :: proc(x0, x1: f32, r: rl.Rectangle, additive: bool) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if n == 0 { return }
	lo, hi := min(x0, x1), max(x0, x1)
	anim_sync_kf_selection()
	if !additive {
		for i in 0 ..< n { ed.selected_kfs[i] = false }
	}
	first := -1
	for kf, i in ed.clip.keyframes {
		kx := r.x + kf.time * r.width
		if kx >= lo && kx <= hi {
			ed.selected_kfs[i] = true
			if first < 0 { first = i }
		}
	}
	if first >= 0 { ed.selected_kf = first } else { anim_sync_kf_selection() }
}

anim_move_selected_kfs_dt :: proc(dt, dv: f32, active_ax: int, skip_val: bool) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	if len(ed.curve_drag_base_times) != n { return }
	tagged := make([]bool, n, context.temp_allocator)
	for i in 0 ..< n {
		if !anim_is_kf_selected(i) { continue }
		tagged[i] = true
		ed.clip.keyframes[i].time = clamp(ed.curve_drag_base_times[i] + dt, 0, 1)
		if !skip_val {
			lim := ed.curve_is_root ? f32(1.0) : f32(math.PI)
			new_v := clamp(ed.curve_drag_base_vals[i] + dv, -lim, lim)
			if ed.curve_is_root {
				ed.clip.keyframes[i].root_offset[active_ax] = new_v
			} else {
				rot := ed.clip.keyframes[i].rot[int(ed.selected_bone)]
				rot[active_ax] = new_v
				anim_edit.clip_set_bone_rot(&ed.clip.keyframes[i], ed.selected_bone, rot, ed.mirror_lr)
			}
		}
	}
	sort_selected_kfs_after_time_edit(tagged)
}

sort_selected_kfs_after_time_edit :: proc(tagged: []bool) {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	for i := 1; i < n; i += 1 {
		for j := i; j > 0 && ed.clip.keyframes[j - 1].time > ed.clip.keyframes[j].time; j -= 1 {
			ed.clip.keyframes[j - 1], ed.clip.keyframes[j] = ed.clip.keyframes[j], ed.clip.keyframes[j - 1]
			ed.selected_kfs[j - 1], ed.selected_kfs[j] = ed.selected_kfs[j], ed.selected_kfs[j - 1]
			ed.curve_drag_base_times[j - 1], ed.curve_drag_base_times[j] = ed.curve_drag_base_times[j], ed.curve_drag_base_times[j - 1]
			ed.curve_drag_base_vals[j - 1], ed.curve_drag_base_vals[j] = ed.curve_drag_base_vals[j], ed.curve_drag_base_vals[j - 1]
			tagged[j - 1], tagged[j] = tagged[j], tagged[j - 1]
			if ed.selected_kf == j { ed.selected_kf = j - 1 } else if ed.selected_kf == j - 1 { ed.selected_kf = j }
			if ed.drag_kf == j { ed.drag_kf = j - 1 } else if ed.drag_kf == j - 1 { ed.drag_kf = j }
			if ed.curve_drag_kf == j { ed.curve_drag_kf = j - 1 } else if ed.curve_drag_kf == j - 1 { ed.curve_drag_kf = j }
		}
	}
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
}

handle_curve_wheel_zoom :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	wheel := input_wheel_y()
	if wheel == 0 { return }
	r := ui.Rect{ed.timeline_rect.x, ed.timeline_rect.y, ed.timeline_rect.width, ed.timeline_rect.height}
	mt, mv := screen_to_curve(r, {mouse.x, mouse.y})
	factor := math.pow(f32(0.86), wheel)
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	if ctrl {
		ed.curve_t_min = clamp(mt + (ed.curve_t_min - mt) * factor, -0.25, 0.95)
		ed.curve_t_max = clamp(mt + (ed.curve_t_max - mt) * factor, ed.curve_t_min + 0.08, 1.25)
		return
	}
	span := clamp((ed.curve_y_max - ed.curve_y_min) * factor, 0.12, 12.0)
	ratio := (mv - ed.curve_y_min) / max(ed.curve_y_max - ed.curve_y_min, 1e-4)
	ed.curve_y_min = mv - ratio * span
	ed.curve_y_max = ed.curve_y_min + span
}

handle_curve_scale_modal :: proc(mouse: rl.Vector2) -> bool {
	ed := &app.anim_ed
	if rl.IsKeyPressed(.ESCAPE) || rl.IsMouseButtonPressed(.RIGHT) {
		_ = anim_edit.anim_undo_step(&ed.undo, &ed.clip)
		anim_sync_kf_selection()
		anim_clamp_selected_kf()
		ed.curve_scale_active = false
		return true
	}
	n := len(ed.clip.keyframes)
	if len(ed.curve_drag_base_times) == n && n > 0 {
		factor := clamp(1.0 + (mouse.x - ed.curve_scale_start_x) * 0.006, 0.1, 4.0)
		tagged := make([]bool, n, context.temp_allocator)
		for i in 0 ..< n {
			if !anim_is_kf_selected(i) { continue }
			tagged[i] = true
			ed.clip.keyframes[i].time = clamp(ed.playhead + (ed.curve_drag_base_times[i] - ed.playhead) * factor, 0, 1)
		}
		sort_selected_kfs_after_time_edit(tagged)
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) || input_left_pressed() {
		ed.curve_scale_active = false
	}
	return true
}

anim_editor_box_rect_2d :: proc(a, b: rl.Vector2) -> rl.Rectangle {
	return rl.Rectangle{min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y)}
}
