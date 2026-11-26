// Blender-style Graph Editor (F-Curves): cubic Bezier curves, interactive handles, zoom/pan, and scrubbing.
package main

import "core:math"
import rl "../gfx"
import anim_edit "./art/anim_edit"
import spec "./art/spec"
import ui "vinland:vui"

CURVE_RULER_H :: f32(20)
CURVE_SAMPLES :: 96

@(private)
CURVE_AXIS_HEX := [3]u32{0xe85a5a, 0x5cd674, 0x58a0f0}

anim_curves_fit_view :: proc() {
	ed := &app.anim_ed
	ed.curve_t_min = -0.03
	ed.curve_t_max = 1.03
	if !ed.clip_loaded || len(ed.clip.keyframes) == 0 {
		ed.curve_y_min = -1.2
		ed.curve_y_max = 1.2
		return
	}
	lo := f32(1e9)
	hi := f32(-1e9)
	for &kf in ed.clip.keyframes {
		for ax in 0 ..< 3 {
			if !ed.curve_vis[ax] { continue }
			v := anim_edit.channel_get_value(&kf, ed.curve_is_root, ed.selected_bone, ax)
			_, in_h, out_h := anim_edit.channel_get_handles(&kf, ed.curve_is_root, ed.selected_bone, ax)
			lo = min(lo, min(v, min(v + in_h[1], v + out_h[1])))
			hi = max(hi, max(v, max(v + in_h[1], v + out_h[1])))
		}
	}
	if lo > hi {
		lo, hi = -0.5, 0.5
	}
	min_span := ed.curve_is_root ? f32(0.24) : f32(0.65)
	span := max(hi - lo, min_span)
	mid := 0.5 * (lo + hi)
	half := span * 0.62
	ed.curve_y_min = mid - half
	ed.curve_y_max = mid + half
}

@(private)
curve_to_screen :: proc(r: ui.Rect, t, val: f32) -> [2]f32 {
	ed := &app.anim_ed
	dt := max(ed.curve_t_max - ed.curve_t_min, 1e-4)
	dy := max(ed.curve_y_max - ed.curve_y_min, 1e-4)
	gh := max(r.h - CURVE_RULER_H, 1)
	x := r.x + ((t - ed.curve_t_min) / dt) * r.w
	y := r.y + CURVE_RULER_H + (1.0 - (val - ed.curve_y_min) / dy) * gh
	return {x, y}
}

@(private)
screen_to_curve :: proc(r: ui.Rect, p: [2]f32) -> (t, val: f32) {
	ed := &app.anim_ed
	dt := max(ed.curve_t_max - ed.curve_t_min, 1e-4)
	dy := max(ed.curve_y_max - ed.curve_y_min, 1e-4)
	gh := max(r.h - CURVE_RULER_H, 1)
	u := (p.x - r.x) / max(r.w, 1)
	v := 1.0 - (p.y - (r.y + CURVE_RULER_H)) / gh
	return ed.curve_t_min + u * dt, ed.curve_y_min + v * dy
}

draw_anim_curves_canvas :: proc(ctx: ^ui.Context, r: ui.Rect, _: rawptr) {
	ed := &app.anim_ed
	if r.w <= 8 || r.h <= CURVE_RULER_H + 8 {
		return
	}
	draw_curve_grid(ctx, r)
	if !ed.clip_loaded {
		return
	}
	for ax in 0 ..< 3 {
		if ax != ed.curve_active_axis && ed.curve_vis[ax] {
			draw_curve_spline(ctx, r, ax, false)
			draw_curve_keys(ctx, r, ax, false)
		}
	}
	if ed.curve_vis[ed.curve_active_axis] {
		draw_curve_spline(ctx, r, ed.curve_active_axis, true)
		draw_curve_keys(ctx, r, ed.curve_active_axis, true)
	}
	draw_curve_playhead(ctx, r)
	if ed.curve_box_active {
		box := anim_editor_box_rect_2d(ed.curve_box_start, input_mouse_pos())
		ui.draw_rect(ctx, {box.x, box.y, box.width, box.height}, ui.rgb(0xecd9a6, 0.14))
	}
}

@(private)
draw_curve_grid :: proc(ctx: ^ui.Context, r: ui.Rect) {
	ed := &app.anim_ed
	ui.draw_rect(ctx, {r.x, r.y, r.w, CURVE_RULER_H}, ui.rgb(0x1b1611, 1))
	ui.draw_line(ctx, {r.x, r.y + CURVE_RULER_H}, {r.x + r.w, r.y + CURVE_RULER_H}, ui.rgb(0x584222, 1), 1)
	for i in 0 ..= 8 {
		t := f32(i) / 8.0
		sx := curve_to_screen(r, t, 0).x
		if sx < r.x || sx > r.x + r.w { continue }
		major := (i % 2) == 0
		ui.draw_line(ctx, {sx, r.y + (major ? 4 : 11)}, {sx, r.y + r.h}, major ? ui.rgb(0x584222, 0.50) : ui.rgb(0x3a2c18, 0.30), 1)
	}
	step := ed.curve_is_root ? f32(0.10) : f32(30.0 * math.PI / 180.0)
	if (ed.curve_y_max - ed.curve_y_min) / step > 10 {
		step *= 2.0
	}
	lo_k := int(math.floor(ed.curve_y_min / step))
	hi_k := int(math.ceil(ed.curve_y_max / step))
	for k := lo_k; k <= hi_k; k += 1 {
		v := f32(k) * step
		sy := curve_to_screen(r, 0, v).y
		if sy < r.y + CURVE_RULER_H || sy > r.y + r.h { continue }
		col := k == 0 ? ui.rgb(0x8a8d8f, 0.55) : ui.rgb(0x3a2c18, 0.45)
		ui.draw_line(ctx, {r.x, sy}, {r.x + r.w, sy}, col, k == 0 ? 1.5 : 1)
	}
}

@(private)
draw_curve_spline :: proc(ctx: ^ui.Context, r: ui.Rect, ax: int, active: bool) {
	ed := &app.anim_ed
	pts: [CURVE_SAMPLES + 1][2]f32
	t0 := clamp(ed.curve_t_min, 0, 1)
	t1 := clamp(ed.curve_t_max, 0, 1)
	if t1 <= t0 + 1e-4 {
		t0, t1 = 0, 1
	}
	for i in 0 ..= CURVE_SAMPLES {
		t := math.lerp(t0, t1, f32(i) / f32(CURVE_SAMPLES))
		v := anim_edit.eval_channel_at_phase(&ed.clip, t, ed.curve_is_root, ed.selected_bone, ax)
		pts[i] = curve_to_screen(r, t, v)
	}
	col := ui.rgb(CURVE_AXIS_HEX[ax], active ? 0.96 : 0.48)
	ui.draw_polyline(ctx, pts[:], col, active ? 2.4 : 1.4)
}

@(private)
draw_curve_keys :: proc(ctx: ^ui.Context, r: ui.Rect, ax: int, active: bool) {
	ed := &app.anim_ed
	col := ui.rgb(CURVE_AXIS_HEX[ax], active ? 1.0 : 0.65)
	for &kf, ki in ed.clip.keyframes {
		val := anim_edit.channel_get_value(&kf, ed.curve_is_root, ed.selected_bone, ax)
		pt := curve_to_screen(r, kf.time, val)
		if pt.x < r.x - 16 || pt.x > r.x + r.w + 16 { continue }
		is_sel := anim_is_kf_selected(ki)
		is_primary := active && ki == ed.selected_kf
		is_hov := ed.curve_hover_kind == .Key && ed.curve_hover_kf == ki && ed.curve_hover_axis == ax
		if is_primary && kf.interp == .Smooth && len(ed.clip.keyframes) > 1 {
			draw_selected_handles(ctx, r, &kf, ki, ax, pt)
		}
		rad: f32 = is_primary ? 5.2 : (is_sel ? 4.8 : (is_hov ? 4.8 : 3.6))
		ui.draw_circle(ctx, pt, rad + 1.4, ui.rgb(0x0c0a08, 0.95))
		ui.draw_circle(ctx, pt, rad, is_sel ? ui.rgb(0xecd9a6, 1) : (is_hov ? ui.rgb(0x6ee8ff, 1) : col))
	}
}

@(private)
draw_selected_handles :: proc(ctx: ^ui.Context, r: ui.Rect, kf: ^anim_edit.Edit_Keyframe, ki, ax: int, pt: [2]f32) {
	ed := &app.anim_ed
	val := anim_edit.channel_get_value(kf, ed.curve_is_root, ed.selected_bone, ax)
	kind, in_h, out_h := anim_edit.channel_get_handles(kf, ed.curve_is_root, ed.selected_bone, ax)
	hcol := handle_kind_color(kind)
	pi := curve_to_screen(r, kf.time + in_h[0], val + in_h[1])
	po := curve_to_screen(r, kf.time + out_h[0], val + out_h[1])
	ui.draw_line(ctx, pt, pi, ui.fade(hcol, 0.85), 1.5)
	ui.draw_line(ctx, pt, po, ui.fade(hcol, 0.85), 1.5)

	hov_in := (ed.curve_hover_kind == .Handle_In && ed.curve_hover_kf == ki && ed.curve_hover_axis == ax) ||
		(ed.curve_drag == .Handle_In && ed.curve_drag_kf == ki && ed.curve_drag_axis == ax)
	hov_out := (ed.curve_hover_kind == .Handle_Out && ed.curve_hover_kf == ki && ed.curve_hover_axis == ax) ||
		(ed.curve_drag == .Handle_Out && ed.curve_drag_kf == ki && ed.curve_drag_axis == ax)
	ui.draw_circle(ctx, pi, hov_in ? 5.5 : 4.2, hov_in ? ui.rgb(0xffffff, 1) : hcol)
	ui.draw_circle(ctx, po, hov_out ? 5.5 : 4.2, hov_out ? ui.rgb(0xffffff, 1) : hcol)
}

@(private)
handle_kind_color :: proc(kind: spec.Anim_Handle) -> ui.Color {
	switch kind {
	case .Auto_Clamped, .Auto: return ui.rgb(0xecd9a6, 1)
	case .Aligned:             return ui.rgb(0xf0a448, 1)
	case .Free:                return ui.rgb(0xe868a8, 1)
	case .Vector:              return ui.rgb(0x66d8f2, 1)
	}
	return ui.rgb(0xecd9a6, 1)
}

@(private)
draw_curve_playhead :: proc(ctx: ^ui.Context, r: ui.Rect) {
	ed := &app.anim_ed
	px := curve_to_screen(r, clamp(ed.playhead, 0, 1), 0).x
	if px < r.x || px > r.x + r.w {
		return
	}
	ui.draw_line(ctx, {px, r.y}, {px, r.y + r.h}, ui.rgb(0xecd9a6, 0.92), 1.8)
	ui.draw_rect(ctx, {px - 5, r.y + 1, 10, 10}, ui.rgb(0xecd9a6, 1), 2)
	for ax in 0 ..< 3 {
		if !ed.curve_vis[ax] { continue }
		v := anim_edit.eval_channel_at_phase(&ed.clip, ed.playhead, ed.curve_is_root, ed.selected_bone, ax)
		pt := curve_to_screen(r, ed.playhead, v)
		ui.draw_circle(ctx, pt, 3.5, ui.rgb(CURVE_AXIS_HEX[ax], 1))
	}
}

update_anim_curves_hover :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	ed.curve_hover_kind, ed.curve_hover_kf, ed.curve_hover_axis = anim_curves_hit_test(mouse)
}

@(private)
anim_curves_hit_test :: proc(mouse: rl.Vector2) -> (kind: Curve_Drag_Kind, kf_idx, axis: int) {
	ed := &app.anim_ed
	r := ui.Rect{ed.timeline_rect.x, ed.timeline_rect.y, ed.timeline_rect.width, ed.timeline_rect.height}
	if !ed.clip_loaded || r.w <= 8 {
		return .None, -1, 0
	}
	ax_act := ed.curve_active_axis
	if ed.curve_vis[ax_act] && ed.selected_kf >= 0 && ed.selected_kf < len(ed.clip.keyframes) {
		kf := &ed.clip.keyframes[ed.selected_kf]
		if kf.interp == .Smooth && len(ed.clip.keyframes) > 1 {
			val := anim_edit.channel_get_value(kf, ed.curve_is_root, ed.selected_bone, ax_act)
			_, in_h, out_h := anim_edit.channel_get_handles(kf, ed.curve_is_root, ed.selected_bone, ax_act)
			if dist2_pt(mouse, curve_to_screen(r, kf.time + in_h[0], val + in_h[1])) <= 100 {
				return .Handle_In, ed.selected_kf, ax_act
			}
			if dist2_pt(mouse, curve_to_screen(r, kf.time + out_h[0], val + out_h[1])) <= 100 {
				return .Handle_Out, ed.selected_kf, ax_act
			}
		}
	}
	best_d2 := f32(81.0)
	best_kf, best_ax := -1, 0
	for &kf, ki in ed.clip.keyframes {
		for ax in 0 ..< 3 {
			if !ed.curve_vis[ax] { continue }
			val := anim_edit.channel_get_value(&kf, ed.curve_is_root, ed.selected_bone, ax)
			d2 := dist2_pt(mouse, curve_to_screen(r, kf.time, val))
			bias := ax == ax_act ? f32(0.65) : f32(1.0)
			if d2 * bias < best_d2 {
				best_d2 = d2 * bias
				best_kf = ki
				best_ax = ax
			}
		}
	}
	if best_kf >= 0 {
		return .Key, best_kf, best_ax
	}
	return .None, -1, 0
}

@(private)
dist2_pt :: proc(a: rl.Vector2, b: [2]f32) -> f32 {
	dx := a.x - b[0]
	dy := a.y - b[1]
	return dx * dx + dy * dy
}

handle_anim_curves_input :: proc(mouse: rl.Vector2, in_tl: bool) -> bool {
	ed := &app.anim_ed
	if ed.curve_scale_active {
		return handle_curve_scale_modal(mouse)
	}
	if ed.curve_box_active {
		if !input_left_down() {
			r := ui.Rect{ed.timeline_rect.x, ed.timeline_rect.y, ed.timeline_rect.width, ed.timeline_rect.height}
			b := anim_editor_box_rect_2d(ed.curve_box_start, mouse)
			anim_curve_box_select({b.x, b.y, b.width, b.height}, r, ed.curve_box_shift)
			ed.curve_box_active = false
		}
		return true
	}
	if ed.curve_drag == .None {
		if in_tl && ed.clip_loaded {
			handle_curve_wheel_zoom(mouse)
		}
		if in_tl && ed.clip_loaded && input_middle_pressed() {
			ed.curve_drag = .Pan
			ed.curve_drag_start_mouse = mouse
			ed.curve_drag_base_ymin = ed.curve_y_min
			ed.curve_drag_base_ymax = ed.curve_y_max
			return true
		}
		if in_tl && ed.clip_loaded && input_left_pressed() {
			start_curve_left_drag(mouse)
			return true
		}
		return false
	}
	still := ed.curve_drag == .Pan ? input_middle_down() : input_left_down()
	if !still {
		ed.curve_drag = .None
		ed.curve_drag_undo = false
		return true
	}
	apply_curve_drag(mouse)
	return true
}

@(private)
start_curve_left_drag :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	ed.playing = false
	kind, ki, ax := anim_curves_hit_test(mouse)
	if kind == .Handle_In || kind == .Handle_Out {
		ed.curve_drag = kind
		ed.curve_drag_kf = ki
		ed.curve_drag_axis = ax
		ed.curve_drag_undo = false
		return
	}
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if kind == .Key {
		if shift {
			anim_toggle_kf_select(ki)
			return
		}
		if !anim_is_kf_selected(ki) {
			anim_select_kf_only(ki)
		}
		ed.selected_kf = ki
		ed.curve_active_axis = ax
		ed.curve_drag = .Key
		ed.curve_drag_kf = ki
		ed.curve_drag_axis = ax
		ed.curve_drag_undo = false
		ed.curve_drag_start_mouse = mouse
		ed.curve_drag_base_t = ed.clip.keyframes[ki].time
		ed.curve_drag_base_v = anim_edit.channel_get_value(&ed.clip.keyframes[ki], ed.curve_is_root, ed.selected_bone, ax)
		anim_capture_kf_drag_bases()
		ed.playhead = ed.clip.keyframes[ki].time
		return
	}
	r := ui.Rect{ed.timeline_rect.x, ed.timeline_rect.y, ed.timeline_rect.width, ed.timeline_rect.height}
	if mouse.y <= r.y + CURVE_RULER_H {
		ed.curve_drag = .Scrub
		t, _ := screen_to_curve(r, {mouse.x, mouse.y})
		ed.playhead = clamp(t, 0, 1)
		return
	}
	ed.curve_box_active = true
	ed.curve_box_start = mouse
	ed.curve_box_shift = shift
}

@(private)
apply_curve_drag :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	r := ui.Rect{ed.timeline_rect.x, ed.timeline_rect.y, ed.timeline_rect.width, ed.timeline_rect.height}
	mt, mv := screen_to_curve(r, {mouse.x, mouse.y})
	if ed.curve_drag == .Scrub {
		ed.playhead = clamp(mt, 0, 1)
		return
	}
	if ed.curve_drag == .Pan {
		dy_px := mouse.y - ed.curve_drag_start_mouse.y
		gh := max(r.h - CURVE_RULER_H, 1)
		dv := dy_px / gh * (ed.curve_drag_base_ymax - ed.curve_drag_base_ymin)
		ed.curve_y_min = ed.curve_drag_base_ymin + dv
		ed.curve_y_max = ed.curve_drag_base_ymax + dv
		return
	}
	if !ed.curve_drag_undo {
		anim_edit.anim_undo_push(&ed.undo, &ed.clip)
		ed.curve_drag_undo = true
	}
	ki := clamp(ed.curve_drag_kf, 0, len(ed.clip.keyframes) - 1)
	ax := ed.curve_drag_axis
	if ed.curve_drag == .Handle_In || ed.curve_drag == .Handle_Out {
		kf := &ed.clip.keyframes[ki]
		val := anim_edit.channel_get_value(kf, ed.curve_is_root, ed.selected_bone, ax)
		alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
		anim_edit.drag_channel_handle(&ed.clip, ki, ed.curve_is_root, ed.selected_bone, ax, ed.curve_drag == .Handle_Out, {mt - kf.time, mv - val}, alt)
		return
	}
	apply_curve_key_drag(ki, ax, mt, mv)
}

@(private)
apply_curve_key_drag :: proc(ki, ax: int, mt, mv: f32) {
	ed := &app.anim_ed
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	new_t := shift ? ed.curve_drag_base_t : clamp(mt, 0, 1)
	lim := ed.curve_is_root ? f32(1.0) : f32(math.PI)
	new_v := clamp(mv, -lim, lim)
	if ctrl {
		if !shift { new_t = math.round(new_t * 40.0) * 0.025 }
		step := ed.curve_is_root ? f32(0.05) : f32(5.0 * math.PI / 180.0)
		new_v = math.round(new_v / step) * step
	}
	if anim_selected_kf_count() > 1 {
		anim_move_selected_kfs_dt(new_t - ed.curve_drag_base_t, new_v - ed.curve_drag_base_v, ax, false)
		ed.playhead = ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)].time
		return
	}
	kf := &ed.clip.keyframes[ki]
	if ed.curve_is_root {
		kf.root_offset[ax] = new_v
	} else {
		rot := kf.rot[int(ed.selected_bone)]
		rot[ax] = new_v
		anim_edit.clip_set_bone_rot(kf, ed.selected_bone, rot, ed.mirror_lr)
	}
	new_ki := anim_edit.clip_move_keyframe(&ed.clip, ki, new_t)
	ed.curve_drag_kf = new_ki
	ed.selected_kf = new_ki
	ed.playhead = ed.clip.keyframes[new_ki].time
}
