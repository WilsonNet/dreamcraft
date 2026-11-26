#+build !js
package art_anim_rig

import "core:math/linalg"
import "core:testing"
import rl "../../../gfx"
import art ".."
import anim_edit "../anim_edit"
import spec "../spec"

@(test)
eval_fk_matrices_matches_art_pose_matrices :: proc(t: ^testing.T) {
	pose: art.Pose
	art.pose_walk(0.25, &pose)
	want := art.pose_matrices(&pose, rl.Matrix(1))

	rot: [BONE_COUNT][3]f32
	for i in 0 ..< BONE_COUNT {
		rot[i] = {pose.rot[i].x, pose.rot[i].y, pose.rot[i].z}
	}
	got := eval_fk_matrices(&rot, {pose.root_offset.x, pose.root_offset.y, pose.root_offset.z})

	for i in 0 ..< BONE_COUNT {
		h := art.BONES[spec.Bone_Id(i)].head
		wp := art.xf_point(want[i], rl.Vector3(h))
		gp := mat4_point(got[i], h)
		testing.expect(t, linalg.length([3]f32{wp.x - gp[0], wp.y - gp[1], wp.z - gp[2]}) < 1e-4)
	}
}

@(test)
hand_ik_reaches_target_within_3mm :: proc(t: ^testing.T) {
	kf := anim_edit.Edit_Keyframe{time = 0}
	rig := Rig_Targets{pin_feet = true}
	rig_sync_from_kf(&rig, &kf)

	targets := [3][3]f32{
		{0.35, 1.35, 0.35},
		{0.18, 1.55, 0.28},
		{0.42, 1.05, 0.22},
	}
	for tgt in targets {
		rig_apply_translate(&rig, &kf, .Hand_IK_R, tgt, false)
		fk := eval_fk_matrices(&kf.rot, kf.root_offset)
		hand_p := mat4_point(fk[int(spec.Bone_Id.Hand_R)], art.BONES[.Hand_R].head)
		err := linalg.length(hand_p - tgt)
		testing.expect(t, err < 0.003)
	}
}

@(test)
cog_drop_with_pin_feet_keeps_feet_planted_and_bends_knees :: proc(t: ^testing.T) {
	kf := anim_edit.Edit_Keyframe{time = 0}
	rig := Rig_Targets{pin_feet = true}
	rig_sync_from_kf(&rig, &kf)

	foot_l0 := rig.pos[.Foot_IK_L]
	foot_r0 := rig.pos[.Foot_IK_R]
	cog0 := rig.pos[.COG]

	rig_apply_translate(&rig, &kf, .COG, cog0 + {0, -0.18, 0}, false)
	testing.expect(t, abs(kf.root_offset[1] + 0.18) < 1e-4)

	fk := eval_fk_matrices(&kf.rot, kf.root_offset)
	foot_l1 := mat4_point(fk[int(spec.Bone_Id.Foot_L)], art.BONES[.Foot_L].head)
	foot_r1 := mat4_point(fk[int(spec.Bone_Id.Foot_R)], art.BONES[.Foot_R].head)
	testing.expect(t, linalg.length(foot_l1 - foot_l0) < 0.004)
	testing.expect(t, linalg.length(foot_r1 - foot_r0) < 0.004)
	knee_l := mat4_point(fk[int(spec.Bone_Id.Shin_L)], art.BONES[.Shin_L].head)
	knee_r := mat4_point(fk[int(spec.Bone_Id.Shin_R)], art.BONES[.Shin_R].head)
	testing.expect(t, knee_l[2] > 0.20)
	testing.expect(t, knee_r[2] > 0.20)
	testing.expectf(t, kf.rot[int(spec.Bone_Id.Shin_L)][0] > 0.25, "thigh_l=%v shin_l=%v", kf.rot[int(spec.Bone_Id.Thigh_L)], kf.rot[int(spec.Bone_Id.Shin_L)])
	testing.expectf(t, kf.rot[int(spec.Bone_Id.Shin_R)][0] > 0.25, "thigh_r=%v shin_r=%v", kf.rot[int(spec.Bone_Id.Thigh_R)], kf.rot[int(spec.Bone_Id.Shin_R)])
}

@(test)
head_aim_and_chest_cape_controls_distribute_rotations :: proc(t: ^testing.T) {
	kf := anim_edit.Edit_Keyframe{time = 0}
	rig := Rig_Targets{pin_feet = true}
	rig_sync_from_kf(&rig, &kf)

	rig_apply_translate(&rig, &kf, .Head_Aim, {0.35, 1.75, 0.40}, false)
	testing.expect(t, kf.rot[int(spec.Bone_Id.Head)][1] > 0.25)
	testing.expect(t, kf.rot[int(spec.Bone_Id.Neck)][1] > 0.10)

	base := kf.rot
	rig_apply_rotate_delta(&kf, .Chest_Ctrl, &base, {0.5, 0.2, 0}, false)
	testing.expect(t, abs(kf.rot[int(spec.Bone_Id.Spine)][0] - (base[int(spec.Bone_Id.Spine)][0] + 0.20)) < 1e-4)
	testing.expect(t, abs(kf.rot[int(spec.Bone_Id.Chest)][0] - (base[int(spec.Bone_Id.Chest)][0] + 0.30)) < 1e-4)

	base2 := kf.rot
	rig_apply_rotate_delta(&kf, .Cape_Ctrl, &base2, {0.4, 0, 0}, false)
	testing.expect(t, abs(kf.rot[int(spec.Bone_Id.Cape_3)][0] - 0.18) < 1e-4)
}

@(test)
sword_tip_aims_blade_and_follows_arm_ik :: proc(t: ^testing.T) {
	kf := anim_edit.Edit_Keyframe{time = 0}
	rig := Rig_Targets{pin_feet = true}
	rig_sync_from_kf(&rig, &kf)

	tgt := [3]f32{0.15, 1.38, 1.02}
	rig_apply_translate(&rig, &kf, .Sword_Tip, tgt, false)

	fk := eval_fk_matrices(&kf.rot, kf.root_offset)
	tip := mat4_point(fk[int(spec.Bone_Id.Hand_R)], sword_tip_rest_pos())
	err := linalg.length(tip - tgt)
	testing.expectf(t, err < 0.005, "tip=%v tgt=%v rest=%v err=%v", tip, tgt, sword_tip_rest_pos(), err)
}
