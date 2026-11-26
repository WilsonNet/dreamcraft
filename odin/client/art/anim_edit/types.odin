// Core editable keyframe clip structures and lifecycle helpers for the 3D animation pipeline.
package art_anim_edit

import "core:slice"
import "core:strings"
import spec "../spec"

BONE_COUNT :: int(spec.Bone_Id.COUNT)
MAX_ANIM_UNDO :: 64

Edit_Keyframe :: struct {
	time:        f32,
	interp:      spec.Anim_Interp,
	root_offset: [3]f32,
	rot:         [BONE_COUNT][3]f32,
	rot_in:      [BONE_COUNT][3][2]f32,
	rot_out:     [BONE_COUNT][3][2]f32,
	rot_handle:  [BONE_COUNT][3]spec.Anim_Handle,
	root_in:     [3][2]f32,
	root_out:    [3][2]f32,
	root_handle: [3]spec.Anim_Handle,
}

Edit_Clip :: struct {
	id:               string,
	title:            string,
	duration:         f32,
	loop:             bool,
	additive:         bool,
	secondary_weight: f32,
	keyframes:        [dynamic]Edit_Keyframe,
	dirty:            bool,
}

Anim_Undo_Snapshot :: struct {
	duration:         f32,
	loop:             bool,
	additive:         bool,
	secondary_weight: f32,
	keyframes:        []Edit_Keyframe,
}

Anim_Undo_Stack :: struct {
	items:  [dynamic]Anim_Undo_Snapshot,
	cursor: int,
}

edit_clip_init :: proc(
	id, title: string,
	duration: f32,
	loop, additive: bool,
	secondary_weight: f32,
) -> Edit_Clip {
	return Edit_Clip{
		id               = strings.clone(id),
		title            = strings.clone(title),
		duration         = max(duration, 0.05),
		loop             = loop,
		additive         = additive,
		secondary_weight = max(secondary_weight, 0),
		keyframes        = make([dynamic]Edit_Keyframe, 0, 16),
	}
}

edit_clip_delete :: proc(c: ^Edit_Clip) {
	if c == nil {
		return
	}
	delete(c.id)
	delete(c.title)
	delete(c.keyframes)
	c^ = {}
}

edit_clip_clone :: proc(src: ^Edit_Clip) -> Edit_Clip {
	out := edit_clip_init(
		src.id,
		src.title,
		src.duration,
		src.loop,
		src.additive,
		src.secondary_weight,
	)
	resize(&out.keyframes, len(src.keyframes))
	copy(out.keyframes[:], src.keyframes[:])
	out.dirty = src.dirty
	return out
}

edit_clip_from_def :: proc(def: spec.Anim_Clip_Def) -> Edit_Clip {
	c := edit_clip_init(
		def.id,
		def.title,
		def.duration,
		def.loop,
		def.additive,
		def.secondary_weight,
	)
	for chunk in def.keyframe_chunks {
		for kf in chunk {
			ekf := Edit_Keyframe{
				time        = clamp(kf.time, 0, 1),
				interp      = kf.interp,
				root_offset = kf.root_offset,
			}
			for br in kf.bones {
				bi := int(br.bone)
				if bi >= 0 && bi < BONE_COUNT {
					ekf.rot[bi] = br.rot
				}
			}
			for hd in kf.handles {
				ax := int(hd.axis)
				if ax < 0 || ax >= 3 { continue }
				if hd.bone == .COUNT {
					ekf.root_handle[ax] = hd.handle
					ekf.root_in[ax] = hd.in_h
					ekf.root_out[ax] = hd.out_h
				} else if int(hd.bone) < BONE_COUNT {
					bi := int(hd.bone)
					ekf.rot_handle[bi][ax] = hd.handle
					ekf.rot_in[bi][ax] = hd.in_h
					ekf.rot_out[bi][ax] = hd.out_h
				}
			}
			append(&c.keyframes, ekf)
		}
	}
	edit_clip_sort_keyframes(&c)
	recompute_clip_handles(&c)
	c.dirty = false
	return c
}

edit_clip_sort_keyframes :: proc(c: ^Edit_Clip) {
	if len(c.keyframes) <= 1 {
		return
	}
	slice.sort_by(c.keyframes[:], proc(a, b: Edit_Keyframe) -> bool {
		return a.time < b.time
	})
}

bone_mirror_pair :: proc(bone: spec.Bone_Id) -> (spec.Bone_Id, bool) {
	#partial switch bone {
	case .Shoulder_L: return .Shoulder_R, true
	case .Shoulder_R: return .Shoulder_L, true
	case .Arm_L:      return .Arm_R, true
	case .Arm_R:      return .Arm_L, true
	case .Forearm_L:  return .Forearm_R, true
	case .Forearm_R:  return .Forearm_L, true
	case .Hand_L:     return .Hand_R, true
	case .Hand_R:     return .Hand_L, true
	case .Thigh_L:    return .Thigh_R, true
	case .Thigh_R:    return .Thigh_L, true
	case .Shin_L:     return .Shin_R, true
	case .Shin_R:     return .Shin_L, true
	case .Foot_L:     return .Foot_R, true
	case .Foot_R:     return .Foot_L, true
	}
	return bone, false
}
