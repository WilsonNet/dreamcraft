// Allocation-free runtime evaluation of keyframe animation clips and single F-curve channels.
package art_anim_edit

import "core:math"
import spec "../spec"

apply_interp :: proc(interp: spec.Anim_Interp, f: f32) -> f32 {
	x := clamp(f, 0, 1)
	switch interp {
	case .Step:
		return 0
	case .Linear:
		return x
	case .Smooth:
		return x * x * (3.0 - 2.0 * x)
	case .Ease_In:
		return x * x
	case .Ease_Out:
		inv := 1.0 - x
		return 1.0 - inv * inv
	}
	return x
}

// Evaluates clip at normalized phase (wrapped in [0,1) when looping, clamped otherwise).
eval_edit_clip :: proc(clip: ^Edit_Clip, phase: f32) -> (rot: [BONE_COUNT][3]f32, root_offset: [3]f32) {
	if clip == nil || len(clip.keyframes) == 0 {
		return
	}
	kfs := clip.keyframes[:]
	if len(kfs) == 1 {
		return kfs[0].rot, kfs[0].root_offset
	}
	u := clip.loop ? (phase - math.floor(phase)) : clamp(phase, 0, 1)
	a_idx, b_idx, t0, t1, u_seg := find_keyframe_span(kfs, u, clip.loop)
	a := &kfs[a_idx]
	b := &kfs[b_idx]
	if a.interp == .Smooth {
		return blend_keyframes_bezier(a, b, t0, t1, u_seg)
	}
	frac := (t1 > t0 + 1e-6) ? clamp((u_seg - t0) / (t1 - t0), 0, 1) : 0
	w := apply_interp(a.interp, frac)
	return blend_keyframes_linear(a, b, w)
}

// Evaluates a single F-curve channel (bone rotation or root offset) at normalized phase.
eval_channel_at_phase :: proc(
	clip: ^Edit_Clip,
	phase: f32,
	is_root: bool,
	bone: spec.Bone_Id,
	axis: int,
) -> f32 {
	if clip == nil || len(clip.keyframes) == 0 {
		return 0
	}
	kfs := clip.keyframes[:]
	if len(kfs) == 1 {
		return channel_get_value(&kfs[0], is_root, bone, axis)
	}
	u := clip.loop ? (phase - math.floor(phase)) : clamp(phase, 0, 1)
	a_idx, b_idx, t0, t1, u_seg := find_keyframe_span(kfs, u, clip.loop)
	a := &kfs[a_idx]
	b := &kfs[b_idx]
	va := channel_get_value(a, is_root, bone, axis)
	vb := channel_get_value(b, is_root, bone, axis)
	if a.interp == .Smooth {
		_, _, a_out := channel_get_handles(a, is_root, bone, axis)
		_, b_in, _ := channel_get_handles(b, is_root, bone, axis)
		return eval_bezier_1d(t0, va, a_out, b_in, t1, vb, u_seg)
	}
	frac := (t1 > t0 + 1e-6) ? clamp((u_seg - t0) / (t1 - t0), 0, 1) : 0
	return math.lerp(va, vb, apply_interp(a.interp, frac))
}

@(private)
find_keyframe_span :: proc(kfs: []Edit_Keyframe, u: f32, loop: bool) -> (a_idx, b_idx: int, t0, t1, u_seg: f32) {
	n := len(kfs)
	if u < kfs[0].time {
		if !loop {
			return 0, 0, kfs[0].time, kfs[0].time, kfs[0].time
		}
		return n - 1, 0, kfs[n - 1].time - 1.0, kfs[0].time, u
	}
	for i in 0 ..< n - 1 {
		if u >= kfs[i].time && u <= kfs[i + 1].time {
			if kfs[i + 1].time - kfs[i].time <= 1e-6 {
				return i + 1, i + 1, kfs[i + 1].time, kfs[i + 1].time, kfs[i + 1].time
			}
			return i, i + 1, kfs[i].time, kfs[i + 1].time, u
		}
	}
	if !loop {
		return n - 1, n - 1, kfs[n - 1].time, kfs[n - 1].time, kfs[n - 1].time
	}
	return n - 1, 0, kfs[n - 1].time, kfs[0].time + 1.0, u
}

@(private)
blend_keyframes_bezier :: proc(a, b: ^Edit_Keyframe, t0, t1, u: f32) -> (rot: [BONE_COUNT][3]f32, root_offset: [3]f32) {
	for i in 0 ..< BONE_COUNT {
		for ax in 0 ..< 3 {
			rot[i][ax] = eval_bezier_1d(t0, a.rot[i][ax], a.rot_out[i][ax], b.rot_in[i][ax], t1, b.rot[i][ax], u)
		}
	}
	for ax in 0 ..< 3 {
		root_offset[ax] = eval_bezier_1d(t0, a.root_offset[ax], a.root_out[ax], b.root_in[ax], t1, b.root_offset[ax], u)
	}
	return
}

@(private)
blend_keyframes_linear :: proc(a, b: ^Edit_Keyframe, w: f32) -> (rot: [BONE_COUNT][3]f32, root_offset: [3]f32) {
	for i in 0 ..< BONE_COUNT {
		rot[i] = {
			math.lerp(a.rot[i][0], b.rot[i][0], w),
			math.lerp(a.rot[i][1], b.rot[i][1], w),
			math.lerp(a.rot[i][2], b.rot[i][2], w),
		}
	}
	root_offset = {
		math.lerp(a.root_offset[0], b.root_offset[0], w),
		math.lerp(a.root_offset[1], b.root_offset[1], w),
		math.lerp(a.root_offset[2], b.root_offset[2], w),
	}
	return
}
