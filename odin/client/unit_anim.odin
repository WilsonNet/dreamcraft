// Procedural animation clips: idle, walk and attack are analytic functions of
// a normalised phase, so there are no keyframe tables and no asset loads.
package main

import "core:math"

ANIM_IDLE_SECONDS :: 2.40
ANIM_WALK_SECONDS :: 0.72
ANIM_ATTACK_SECONDS :: 0.46

@(private)
ease_seg :: proc(t, a, b: f32) -> f32 {
	if b <= a {
		return 0
	}
	x := clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
}

// Combat guard: shield braced forward, shamshir low and ready.
@(private)
pose_stance :: proc(pose: ^Pose) {
	pose_rot(pose, .Spine, 0.050, 0, 0)
	pose_rot(pose, .Chest, 0.020, 0, 0)
	pose_rot(pose, .Neck, -0.030, 0, 0)
	pose_rot(pose, .Head, -0.030, 0, 0)
	pose_rot(pose, .Shoulder_L, -0.080, 0.10, -0.060)
	pose_rot(pose, .Arm_L, -0.300, 0.10, -0.120)
	pose_rot(pose, .Forearm_L, -0.620, 0, 0)
	pose_rot(pose, .Hand_L, 0.120, 0, 0)
	pose_rot(pose, .Shoulder_R, -0.040, 0, 0.050)
	pose_rot(pose, .Arm_R, -0.260, 0.10, 0.300)
	pose_rot(pose, .Forearm_R, -0.500, 0.15, 0)
	pose_rot(pose, .Hand_R, 0.060, 0, 0)
	pose_rot(pose, .Thigh_L, -0.050, 0, 0.060)
	pose_rot(pose, .Thigh_R, 0.030, 0, -0.060)
	pose_rot(pose, .Shin_L, 0.090, 0, 0)
	pose_rot(pose, .Shin_R, 0.110, 0, 0)
	pose_rot(pose, .Foot_L, -0.050, 0, 0)
	pose_rot(pose, .Foot_R, -0.090, 0, 0)
}

pose_idle :: proc(phase: f32, pose: ^Pose) {
	pose_stance(pose)
	t := phase * math.TAU
	breath := math.sin(t)
	pose_add(pose, .Chest, 0.026 * breath, 0.030 * math.sin(t + 0.9), 0)
	pose_add(pose, .Head, -0.020 * breath, 0.075 * math.sin(t + 1.7), 0)
	pose_add(pose, .Arm_L, 0.030 * breath, 0, 0.018 * breath)
	pose_add(pose, .Arm_R, 0.024 * math.sin(t + 0.4), 0, 0)
	pose_add(pose, .Forearm_R, 0.030 * breath, 0, 0)
	pose_add(pose, .Pelvis, 0, 0, 0.014 * math.sin(t + 0.6))
	pose.root_offset.y = 0.006 * breath
}

pose_walk :: proc(phase: f32, pose: ^Pose) {
	pose_stance(pose)
	t := phase * math.TAU
	swing := math.sin(t)
	lift_l := max(0, -swing)
	lift_r := max(0, swing)
	pose_add(pose, .Thigh_L, 0.540 * swing, 0, 0)
	pose_add(pose, .Thigh_R, -0.540 * swing, 0, 0)
	pose_add(pose, .Shin_L, 0.640 * lift_l, 0, 0)
	pose_add(pose, .Shin_R, 0.640 * lift_r, 0, 0)
	pose_add(pose, .Foot_L, -0.320 * lift_l, 0, 0)
	pose_add(pose, .Foot_R, -0.320 * lift_r, 0, 0)
	pose_add(pose, .Arm_L, -0.300 * swing, 0, 0)
	pose_add(pose, .Arm_R, 0.170 * swing, 0, 0)
	pose_add(pose, .Pelvis, 0, 0.060 * swing, 0.035 * swing)
	pose_add(pose, .Chest, 0.030, -0.110 * swing, 0)
	pose_add(pose, .Head, 0, 0.050 * swing, 0)
	pose.root_offset.y = 0.030 * abs(swing) - 0.014
	pose.root_offset.z = 0.010 * math.cos(t)
}

// Additive over the current guard pose so the clip always lands back in idle.
pose_attack :: proc(t: f32, pose: ^Pose) {
	wind := ease_seg(t, 0.00, 0.30)
	strike := ease_seg(t, 0.30, 0.48)
	recover := ease_seg(t, 0.56, 1.00)
	arm_x := 1.550 * wind - 2.150 * strike + 0.600 * recover
	arm_z := 0.520 * wind - 1.020 * strike + 0.500 * recover
	pose_add(pose, .Shoulder_R, 0.240 * wind - 0.360 * strike + 0.120 * recover, 0, 0)
	pose_add(pose, .Arm_R, arm_x, 0.180 * wind - 0.360 * strike + 0.180 * recover, arm_z)
	pose_add(pose, .Forearm_R, -0.520 * wind + 0.420 * strike + 0.100 * recover, 0, 0)
	pose_add(pose, .Chest, 0.120 * wind - 0.260 * strike + 0.140 * recover, -0.360 * wind + 0.700 * strike - 0.340 * recover, 0)
	pose_add(pose, .Spine, 0.080 * wind - 0.140 * strike + 0.060 * recover, -0.140 * wind + 0.280 * strike - 0.140 * recover, 0)
	pose_add(pose, .Head, -0.080 * wind + 0.120 * strike - 0.040 * recover, 0.240 * wind - 0.360 * strike + 0.120 * recover, 0)
	pose_add(pose, .Arm_L, -0.140 * wind + 0.320 * strike - 0.180 * recover, 0, 0)
	pose_add(pose, .Forearm_L, 0.120 * wind - 0.240 * strike + 0.120 * recover, 0, 0)
	pose_add(pose, .Thigh_L, 0.100 * wind - 0.220 * strike + 0.120 * recover, 0, 0)
	pose_add(pose, .Thigh_R, -0.080 * wind + 0.180 * strike - 0.100 * recover, 0, 0)
	pose.root_offset.z += 0.030 * wind - 0.120 * strike + 0.090 * recover
	pose.root_offset.y += 0.020 * wind - 0.040 * strike + 0.020 * recover
}

// Cape, sash and turban tail lag behind the body, loosely driven by speed.
pose_secondary :: proc(phase: f32, move: f32, pose: ^Pose) {
	t := phase * math.TAU
	cape := [3]Bone_Id{.Cape_1, .Cape_2, .Cape_3}
	for bone, i in cape {
		f := f32(i)
		sway := math.sin(t + f * 0.85)
		pose_add(pose, bone, 0.070 + 0.240 * move + 0.045 * sway, 0.030 * sway, 0.055 * sway)
	}
	sash := math.sin(t + 1.1)
	pose_add(pose, .Sash, 0.040 + 0.150 * move + 0.060 * sash, 0.020 * sash, 0.045 * sash)
	tail := math.sin(t + 2.0)
	pose_add(pose, .Plume, 0.030 + 0.130 * move + 0.050 * tail, 0.030 * tail, 0.040 * tail)
}
