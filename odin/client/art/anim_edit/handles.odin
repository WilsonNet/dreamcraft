// Blender-style F-curve Bezier handle computation, interactive dragging, and 1D curve evaluation.
package art_anim_edit

import "core:math"
import spec "../spec"

// Evaluates a 1D cubic Bezier segment over [t0, t1] at u in [t0, t1] (zero allocations).
eval_bezier_1d :: proc(t0, v0: f32, out_h, in_h: [2]f32, t1, v1, u: f32) -> f32 {
	span := t1 - t0
	if span <= 1e-6 {
		return v0
	}
	target_x := clamp((u - t0) / span, 0, 1)
	if target_x <= 0 { return v0 }
	if target_x >= 1 { return v1 }

	x1 := clamp(out_h[0] / span, 0, 1)
	x2 := clamp(1.0 + in_h[0] / span, 0, 1)
	y0 := v0
	y1 := v0 + out_h[1]
	y2 := v1 + in_h[1]
	y3 := v1

	s := solve_cubic_x(x1, x2, target_x)
	inv := 1.0 - s
	b0 := inv * inv * inv
	b1 := 3.0 * inv * inv * s
	b2 := 3.0 * inv * s * s
	b3 := s * s * s
	return b0 * y0 + b1 * y1 + b2 * y2 + b3 * y3
}

@(private)
solve_cubic_x :: proc(x1, x2, target_x: f32) -> f32 {
	lo := f32(0)
	hi := f32(1)
	s := target_x
	for _ in 0 ..< 6 {
		inv := 1.0 - s
		bx := 3.0 * inv * inv * s * x1 + 3.0 * inv * s * s * x2 + s * s * s
		err := bx - target_x
		if abs(err) < 1e-5 {
			return s
		}
		if err < 0 { lo = s } else { hi = s }
		dbx := 3.0 * inv * inv * x1 + 6.0 * inv * s * (x2 - x1) + 3.0 * s * s * (1.0 - x2)
		if dbx > 1e-5 {
			next := s - err / dbx
			if next > lo && next < hi {
				s = next
				continue
			}
		}
		s = 0.5 * (lo + hi)
	}
	return s
}

channel_get_value :: proc(kf: ^Edit_Keyframe, is_root: bool, bone: spec.Bone_Id, axis: int) -> f32 {
	ax := clamp(axis, 0, 2)
	if is_root {
		return kf.root_offset[ax]
	}
	return kf.rot[int(bone)][ax]
}

channel_set_value :: proc(kf: ^Edit_Keyframe, is_root: bool, bone: spec.Bone_Id, axis: int, val: f32) {
	ax := clamp(axis, 0, 2)
	if is_root {
		kf.root_offset[ax] = val
		return
	}
	kf.rot[int(bone)][ax] = val
}

channel_get_handles :: proc(
	kf: ^Edit_Keyframe,
	is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
) -> (kind: spec.Anim_Handle, in_h, out_h: [2]f32) {
	ax := clamp(axis, 0, 2)
	if is_root {
		return kf.root_handle[ax], kf.root_in[ax], kf.root_out[ax]
	}
	bi := int(bone)
	return kf.rot_handle[bi][ax], kf.rot_in[bi][ax], kf.rot_out[bi][ax]
}

@(private)
channel_handle_ptrs :: proc(
	kf: ^Edit_Keyframe,
	is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
) -> (kind: ^spec.Anim_Handle, in_h, out_h: ^[2]f32) {
	ax := clamp(axis, 0, 2)
	if is_root {
		return &kf.root_handle[ax], &kf.root_in[ax], &kf.root_out[ax]
	}
	bi := int(bone)
	return &kf.rot_handle[bi][ax], &kf.rot_in[bi][ax], &kf.rot_out[bi][ax]
}

// Recomputes automatic Bezier handles (.Auto_Clamped, .Auto, .Vector); preserves .Aligned/.Free.
recompute_clip_handles :: proc(c: ^Edit_Clip) {
	if c == nil || len(c.keyframes) == 0 {
		return
	}
	for i in 0 ..< len(c.keyframes) {
		for bi in 0 ..< BONE_COUNT {
			b := spec.Bone_Id(bi)
			for ax in 0 ..< 3 {
				recompute_single_channel(c, i, false, b, ax)
			}
		}
		for ax in 0 ..< 3 {
			recompute_single_channel(c, i, true, .COUNT, ax)
		}
	}
}

@(private)
recompute_single_channel :: proc(c: ^Edit_Clip, idx: int, is_root: bool, bone: spec.Bone_Id, axis: int) {
	kfs := c.keyframes[:]
	n := len(kfs)
	kind, in_h, out_h := channel_handle_ptrs(&kfs[idx], is_root, bone, axis)
	if kind^ == .Aligned || kind^ == .Free {
		return
	}
	if n <= 1 {
		in_h^ = {-0.08, 0}
		out_h^ = {0.08, 0}
		return
	}
	t_cur := kfs[idx].time
	v_cur := channel_get_value(&kfs[idx], is_root, bone, axis)
	has_prev, t_prev, v_prev, has_next, t_next, v_next := channel_neighbors(kfs, idx, c.loop, is_root, bone, axis)

	dt_in := has_prev ? max(t_cur - t_prev, 1e-4) : (has_next ? max(t_next - t_cur, 1e-4) : f32(0.1))
	dt_out := has_next ? max(t_next - t_cur, 1e-4) : (has_prev ? max(t_cur - t_prev, 1e-4) : f32(0.1))
	h_in := dt_in / 3.0
	h_out := dt_out / 3.0

	if kind^ == .Vector {
		in_h^ = {-h_in, has_prev ? (v_prev - v_cur) / 3.0 : 0}
		out_h^ = {h_out, has_next ? (v_next - v_cur) / 3.0 : 0}
		return
	}
	slope := compute_auto_slope(kind^, has_prev, has_next, t_prev, v_prev, t_cur, v_cur, t_next, v_next)
	in_h^ = {-h_in, -slope * h_in}
	out_h^ = {h_out, slope * h_out}
}

@(private)
compute_auto_slope :: proc(
	kind: spec.Anim_Handle,
	has_prev, has_next: bool,
	t_prev, v_prev, t_cur, v_cur, t_next, v_next: f32,
) -> f32 {
	if !has_prev || !has_next {
		return 0
	}
	d0 := (v_cur - v_prev) / max(t_cur - t_prev, 1e-4)
	d1 := (v_next - v_cur) / max(t_next - t_cur, 1e-4)
	if kind == .Auto_Clamped {
		if d0 * d1 <= 0 {
			return 0
		}
		return (2.0 * d0 * d1) / (d0 + d1)
	}
	return (v_next - v_prev) / max(t_next - t_prev, 1e-4)
}

@(private)
channel_neighbors :: proc(
	kfs: []Edit_Keyframe,
	idx: int,
	loop, is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
) -> (has_prev: bool, tp, vp: f32, has_next: bool, tn, vn: f32) {
	n := len(kfs)
	seam_dup := loop && n >= 3 && kfs[0].time <= 0.001 && kfs[n - 1].time >= 0.999
	if idx > 0 {
		has_prev = true
		tp = kfs[idx - 1].time
		vp = channel_get_value(&kfs[idx - 1], is_root, bone, axis)
	} else if loop && n >= 2 {
		p := seam_dup ? n - 2 : n - 1
		has_prev = true
		tp = kfs[p].time - 1.0
		vp = channel_get_value(&kfs[p], is_root, bone, axis)
	}
	if idx + 1 < n {
		has_next = true
		tn = kfs[idx + 1].time
		vn = channel_get_value(&kfs[idx + 1], is_root, bone, axis)
	} else if loop && n >= 2 {
		nx := seam_dup ? 1 : 0
		has_next = true
		tn = kfs[nx].time + 1.0
		vn = channel_get_value(&kfs[nx], is_root, bone, axis)
	}
	return
}

set_channel_handle_type :: proc(
	c: ^Edit_Clip,
	kf_idx: int,
	is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
	next_kind: spec.Anim_Handle,
) {
	if c == nil || kf_idx < 0 || kf_idx >= len(c.keyframes) {
		return
	}
	kind, _, _ := channel_handle_ptrs(&c.keyframes[kf_idx], is_root, bone, axis)
	kind^ = next_kind
	recompute_clip_handles(c)
	c.dirty = true
}

drag_channel_handle :: proc(
	c: ^Edit_Clip,
	kf_idx: int,
	is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
	is_out: bool,
	rel: [2]f32,
	break_free: bool,
) {
	if c == nil || kf_idx < 0 || kf_idx >= len(c.keyframes) {
		return
	}
	kind, in_h, out_h := channel_handle_ptrs(&c.keyframes[kf_idx], is_root, bone, axis)
	if break_free {
		kind^ = .Free
	} else if kind^ != .Free {
		kind^ = .Aligned
	}
	clamped := rel
	if is_out {
		clamped[0] = max(rel[0], 0.002)
		out_h^ = clamped
		if kind^ == .Aligned {
			align_opposite_handle(clamped, in_h)
		}
	} else {
		clamped[0] = min(rel[0], -0.002)
		in_h^ = clamped
		if kind^ == .Aligned {
			align_opposite_handle(clamped, out_h)
		}
	}
	c.dirty = true
}

@(private)
align_opposite_handle :: proc(moved: [2]f32, opp: ^[2]f32) {
	mlen := math.hypot(moved[0], moved[1])
	olen := max(math.hypot(opp[0], opp[1]), 0.02)
	if mlen < 1e-5 {
		return
	}
	opp^ = {-moved[0] / mlen * olen, -moved[1] / mlen * olen}
}
