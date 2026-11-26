// High-level control rig synchronization and manipulation -> pure FK Edit_Keyframe writes.
package art_anim_rig

import "core:math/linalg"
import art ".."
import anim_edit "../anim_edit"
import spec "../spec"

// Syncs world-space rig control gizmo positions from the current FK keyframe/pose.
rig_sync_from_pose :: proc(rig: ^Rig_Targets, rot: ^[BONE_COUNT][3]f32, root_offset: [3]f32) {
	fk := eval_fk_matrices(rot, root_offset)
	for c in Control_Id {
		if c == .COUNT { continue }
		def := CONTROLS[c]
		head := art.BONES[def.bone].head
		rig.pos[c] = mat4_point(fk[int(def.bone)], head)
	}
	place_pole_target(rig, &fk, .Pole_Elbow_L, .Arm_L, .Forearm_L, .Hand_L, {0, 0, -1}, 0.38)
	place_pole_target(rig, &fk, .Pole_Elbow_R, .Arm_R, .Forearm_R, .Hand_R, {0, 0, -1}, 0.38)
	place_pole_target(rig, &fk, .Pole_Knee_L, .Thigh_L, .Shin_L, .Foot_L, {0, 0, 1}, 0.42)
	place_pole_target(rig, &fk, .Pole_Knee_R, .Thigh_R, .Shin_R, .Foot_R, {0, 0, 1}, 0.42)

	head_pos := mat4_point(fk[int(spec.Bone_Id.Head)], art.BONES[.Head].head)
	head_fwd := linalg.normalize(mat4_dir(fk[int(spec.Bone_Id.Head)], {0, 0, 1}))
	rig.pos[.Head_Aim] = head_pos + head_fwd * 0.55
	rig.initialized = true
}

rig_sync_from_kf :: proc(rig: ^Rig_Targets, kf: ^anim_edit.Edit_Keyframe) {
	if kf == nil { return }
	rig_sync_from_pose(rig, &kf.rot, kf.root_offset)
}

@(private)
place_pole_target :: proc(
	rig: ^Rig_Targets,
	fk: ^[BONE_COUNT]linalg.Matrix4f32,
	pole_id: Control_Id,
	upper, lower, end: spec.Bone_Id,
	fallback_dir: [3]f32,
	dist: f32,
) {
	pa := mat4_point(fk[int(upper)], art.BONES[upper].head)
	pb := mat4_point(fk[int(lower)], art.BONES[lower].head)
	pc := mat4_point(fk[int(end)], art.BONES[end].head)
	ac := pc - pa
	ac_len := linalg.length(ac)
	ac_dir := ac_len > 1e-5 ? ac / ac_len : [3]f32{0, -1, 0}
	ab := pb - pa
	bend := ab - ac_dir * linalg.dot(ab, ac_dir)
	dir := linalg.length(bend) >= 0.03 ? linalg.normalize(bend) : norm_vec(mat4_dir(fk[int(upper)], fallback_dir), fallback_dir)
	rig.pos[pole_id] = pb + dir * dist
}

@(private)
norm_vec :: proc(v, fallback: [3]f32) -> [3]f32 {
	l := linalg.length(v)
	return l > 1e-5 ? v / l : fallback
}

// Translates a motion controller (COG, IK Hand/Foot, Pole, Head Aim) and writes FK bones.
rig_apply_translate :: proc(
	rig: ^Rig_Targets,
	kf: ^anim_edit.Edit_Keyframe,
	ctrl: Control_Id,
	new_pos: [3]f32,
	mirror_lr: bool,
) {
	if ctrl == .COUNT || !CONTROLS[ctrl].can_move {
		return
	}
	old_pos := rig.pos[ctrl]
	rig.pos[ctrl] = new_pos
	solve_moved_control(rig, kf, ctrl, new_pos - old_pos)

	if mirror_lr {
		if pair, ok := ctrl_mirror_pair(ctrl); ok {
			m_pos := [3]f32{-new_pos[0], new_pos[1], new_pos[2]}
			m_old := rig.pos[pair]
			rig.pos[pair] = m_pos
			solve_moved_control(rig, kf, pair, m_pos - m_old)
		}
	}
	rig.pos[.Chest_Ctrl] = eval_fk_bone_head(&kf.rot, kf.root_offset, .Chest)
	rig.pos[.Cape_Ctrl] = eval_fk_bone_head(&kf.rot, kf.root_offset, .Cape_2)
}

@(private)
eval_fk_bone_head :: proc(rot: ^[BONE_COUNT][3]f32, root_offset: [3]f32, b: spec.Bone_Id) -> [3]f32 {
	fk := eval_fk_matrices(rot, root_offset)
	return mat4_point(fk[int(b)], art.BONES[b].head)
}

@(private)
solve_moved_control :: proc(rig: ^Rig_Targets, kf: ^anim_edit.Edit_Keyframe, ctrl: Control_Id, delta: [3]f32) {
	#partial switch ctrl {
	case .COG:
		kf.root_offset += delta
		if rig.pin_feet {
			solve_two_bone_ik(&kf.rot, kf.root_offset, .Thigh_L, .Shin_L, .Foot_L, rig.pos[.Foot_IK_L], rig.pos[.Pole_Knee_L], {0, 0, 1})
			solve_two_bone_ik(&kf.rot, kf.root_offset, .Thigh_R, .Shin_R, .Foot_R, rig.pos[.Foot_IK_R], rig.pos[.Pole_Knee_R], {0, 0, 1})
		}
	case .Foot_IK_L, .Pole_Knee_L:
		solve_two_bone_ik(&kf.rot, kf.root_offset, .Thigh_L, .Shin_L, .Foot_L, rig.pos[.Foot_IK_L], rig.pos[.Pole_Knee_L], {0, 0, 1})
	case .Foot_IK_R, .Pole_Knee_R:
		solve_two_bone_ik(&kf.rot, kf.root_offset, .Thigh_R, .Shin_R, .Foot_R, rig.pos[.Foot_IK_R], rig.pos[.Pole_Knee_R], {0, 0, 1})
	case .Hand_IK_L, .Pole_Elbow_L:
		solve_two_bone_ik(&kf.rot, kf.root_offset, .Arm_L, .Forearm_L, .Hand_L, rig.pos[.Hand_IK_L], rig.pos[.Pole_Elbow_L], {0, 0, -1})
	case .Hand_IK_R, .Pole_Elbow_R:
		solve_two_bone_ik(&kf.rot, kf.root_offset, .Arm_R, .Forearm_R, .Hand_R, rig.pos[.Hand_IK_R], rig.pos[.Pole_Elbow_R], {0, 0, -1})
	case .Head_Aim:
		solve_aim_chain(&kf.rot, kf.root_offset, rig.pos[.Head_Aim])
	}
}

// Applies Euler rotation delta on a control (e.g. Chest distributes Spine/Chest, Cape curls 1/2/3).
rig_apply_rotate_delta :: proc(
	kf: ^anim_edit.Edit_Keyframe,
	ctrl: Control_Id,
	base_rot: ^[BONE_COUNT][3]f32,
	delta: [3]f32,
	mirror_lr: bool,
) {
	if ctrl == .COUNT || !CONTROLS[ctrl].can_rotate {
		return
	}
	apply_single_ctrl_rot(kf, ctrl, base_rot, delta)
	if mirror_lr {
		if pair, ok := ctrl_mirror_pair(ctrl); ok {
			apply_single_ctrl_rot(kf, pair, base_rot, {delta[0], -delta[1], -delta[2]})
		}
	}
}

@(private)
apply_single_ctrl_rot :: proc(kf: ^anim_edit.Edit_Keyframe, ctrl: Control_Id, base_rot: ^[BONE_COUNT][3]f32, d: [3]f32) {
	#partial switch ctrl {
	case .COG:
		kf.rot[int(spec.Bone_Id.Pelvis)] = base_rot[int(spec.Bone_Id.Pelvis)] + d
	case .Chest_Ctrl:
		kf.rot[int(spec.Bone_Id.Spine)] = base_rot[int(spec.Bone_Id.Spine)] + d * 0.40
		kf.rot[int(spec.Bone_Id.Chest)] = base_rot[int(spec.Bone_Id.Chest)] + d * 0.60
	case .Head_Aim:
		kf.rot[int(spec.Bone_Id.Neck)] = base_rot[int(spec.Bone_Id.Neck)] + d * 0.35
		kf.rot[int(spec.Bone_Id.Head)] = base_rot[int(spec.Bone_Id.Head)] + d * 0.65
	case .Cape_Ctrl:
		kf.rot[int(spec.Bone_Id.Cape_1)] = base_rot[int(spec.Bone_Id.Cape_1)] + d * 0.35
		kf.rot[int(spec.Bone_Id.Cape_2)] = base_rot[int(spec.Bone_Id.Cape_2)] + d * 0.40
		kf.rot[int(spec.Bone_Id.Cape_3)] = base_rot[int(spec.Bone_Id.Cape_3)] + d * 0.45
	case .Hand_IK_L, .Hand_IK_R, .Foot_IK_L, .Foot_IK_R:
		bi := int(CONTROLS[ctrl].bone)
		kf.rot[bi] = base_rot[bi] + d
	}
}
