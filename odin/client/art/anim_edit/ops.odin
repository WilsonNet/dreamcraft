// Keyframe editing, pose mirroring, and undo/redo operations for Edit_Clip.
package art_anim_edit

import spec "../spec"

clip_find_keyframe_near :: proc(c: ^Edit_Clip, t: f32, tol: f32 = 0.015) -> (int, bool) {
	if c == nil || len(c.keyframes) == 0 {
		return -1, false
	}
	best := -1
	best_d := tol
	for kf, i in c.keyframes {
		d := abs(kf.time - t)
		if d <= best_d {
			best_d = d
			best = i
		}
	}
	return best, best >= 0
}

clip_insert_or_update_keyframe :: proc(
	c: ^Edit_Clip,
	t: f32,
	rot: [BONE_COUNT][3]f32,
	root_offset: [3]f32,
	interp: spec.Anim_Interp = .Smooth,
) -> int {
	clamped_t := clamp(t, 0, 1)
	if idx, ok := clip_find_keyframe_near(c, clamped_t); ok {
		c.keyframes[idx].rot = rot
		c.keyframes[idx].root_offset = root_offset
		c.keyframes[idx].interp = interp
		recompute_clip_handles(c)
		c.dirty = true
		return idx
	}
	append(&c.keyframes, Edit_Keyframe{
		time        = clamped_t,
		interp      = interp,
		root_offset = root_offset,
		rot         = rot,
	})
	c.dirty = true
	res := sort_and_track_keyframe(c, len(c.keyframes) - 1)
	recompute_clip_handles(c)
	return res
}

clip_delete_keyframe :: proc(c: ^Edit_Clip, idx: int) -> bool {
	if c == nil || len(c.keyframes) <= 1 || idx < 0 || idx >= len(c.keyframes) {
		return false
	}
	ordered_remove(&c.keyframes, idx)
	recompute_clip_handles(c)
	c.dirty = true
	return true
}

clip_move_keyframe :: proc(c: ^Edit_Clip, idx: int, new_time: f32) -> int {
	if c == nil || idx < 0 || idx >= len(c.keyframes) {
		return idx
	}
	c.keyframes[idx].time = clamp(new_time, 0, 1)
	c.dirty = true
	res := sort_and_track_keyframe(c, idx)
	recompute_clip_handles(c)
	return res
}

clip_duplicate_keyframe :: proc(c: ^Edit_Clip, idx: int, new_time: f32) -> int {
	if c == nil || idx < 0 || idx >= len(c.keyframes) {
		return -1
	}
	src := c.keyframes[idx]
	src.time = clamp(new_time, 0, 1)
	append(&c.keyframes, src)
	c.dirty = true
	res := sort_and_track_keyframe(c, len(c.keyframes) - 1)
	recompute_clip_handles(c)
	return res
}

@(private)
sort_and_track_keyframe :: proc(c: ^Edit_Clip, target_idx: int) -> int {
	// Insertion sort preserves relative order and tracks target_idx cleanly.
	cur := target_idx
	for cur > 0 && c.keyframes[cur].time < c.keyframes[cur - 1].time {
		c.keyframes[cur], c.keyframes[cur - 1] = c.keyframes[cur - 1], c.keyframes[cur]
		cur -= 1
	}
	for cur + 1 < len(c.keyframes) && c.keyframes[cur].time > c.keyframes[cur + 1].time {
		c.keyframes[cur], c.keyframes[cur + 1] = c.keyframes[cur + 1], c.keyframes[cur]
		cur += 1
	}
	return cur
}

clip_set_bone_rot :: proc(kf: ^Edit_Keyframe, bone: spec.Bone_Id, rot: [3]f32, mirror_lr: bool) {
	bi := int(bone)
	if bi < 0 || bi >= BONE_COUNT {
		return
	}
	kf.rot[bi] = rot
	if mirror_lr {
		if m_bone, ok := bone_mirror_pair(bone); ok {
			kf.rot[int(m_bone)] = {rot[0], -rot[1], -rot[2]}
		}
	}
}

clip_zero_bone :: proc(kf: ^Edit_Keyframe, bone: spec.Bone_Id, mirror_lr: bool) {
	clip_set_bone_rot(kf, bone, {0, 0, 0}, mirror_lr)
}

clip_flip_pose_lr :: proc(kf: ^Edit_Keyframe) {
	orig := kf.rot
	for i in 0 ..< BONE_COUNT {
		b := spec.Bone_Id(i)
		if pair, is_lr := bone_mirror_pair(b); is_lr {
			r := orig[int(pair)]
			kf.rot[i] = {r[0], -r[1], -r[2]}
		} else {
			r := orig[i]
			kf.rot[i] = {r[0], -r[1], -r[2]}
		}
	}
	kf.root_offset[0] = -kf.root_offset[0]
}

anim_undo_delete :: proc(u: ^Anim_Undo_Stack) {
	for &snap in u.items {
		delete(snap.keyframes)
	}
	delete(u.items)
	u^ = {}
}

anim_undo_clear :: proc(u: ^Anim_Undo_Stack) {
	for &snap in u.items {
		delete(snap.keyframes)
	}
	clear(&u.items)
	u.cursor = 0
}

@(private)
make_anim_snapshot :: proc(c: ^Edit_Clip) -> Anim_Undo_Snapshot {
	kfs := make([]Edit_Keyframe, len(c.keyframes))
	copy(kfs, c.keyframes[:])
	return Anim_Undo_Snapshot{
		duration         = c.duration,
		loop             = c.loop,
		additive         = c.additive,
		secondary_weight = c.secondary_weight,
		keyframes        = kfs,
	}
}

@(private)
apply_anim_snapshot :: proc(snap: ^Anim_Undo_Snapshot, c: ^Edit_Clip) {
	c.duration = snap.duration
	c.loop = snap.loop
	c.additive = snap.additive
	c.secondary_weight = snap.secondary_weight
	resize(&c.keyframes, len(snap.keyframes))
	copy(c.keyframes[:], snap.keyframes)
	c.dirty = true
}

anim_undo_push :: proc(u: ^Anim_Undo_Stack, c: ^Edit_Clip) {
	for i := len(u.items) - 1; i >= u.cursor; i -= 1 {
		delete(u.items[i].keyframes)
		ordered_remove(&u.items, i)
	}
	if len(u.items) >= MAX_ANIM_UNDO {
		delete(u.items[0].keyframes)
		ordered_remove(&u.items, 0)
	}
	append(&u.items, make_anim_snapshot(c))
	u.cursor = len(u.items)
}

anim_undo_step :: proc(u: ^Anim_Undo_Stack, c: ^Edit_Clip) -> bool {
	if u.cursor <= 0 {
		return false
	}
	if u.cursor == len(u.items) {
		append(&u.items, make_anim_snapshot(c))
	}
	u.cursor -= 1
	apply_anim_snapshot(&u.items[u.cursor], c)
	return true
}

anim_redo_step :: proc(u: ^Anim_Undo_Stack, c: ^Edit_Clip) -> bool {
	if u.cursor + 1 >= len(u.items) {
		return false
	}
	u.cursor += 1
	apply_anim_snapshot(&u.items[u.cursor], c)
	return true
}
