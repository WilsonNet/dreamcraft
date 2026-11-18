// Procedural animation clips: idle, walk and attack are analytic functions of
// a normalised phase, so there are no keyframe tables and no asset loads.
package art

import "core:math"
import rl "vendor:raylib"

ANIM_IDLE_SECONDS :: 3.60
ANIM_WALK_SECONDS :: 0.40
ANIM_ATTACK_SECONDS :: 0.50

@(private)
math_mod_01 :: proc(x: f32) -> f32 {
	return x - math.floor(x)
}

@(private)
gait_bump :: proc(u, c, w: f32) -> f32 {
	d := u - c
	d -= math.round(d)
	if abs(d) >= w {
		return 0
	}
	return 0.5 * (1.0 + math.cos(math.PI * d / w))
}

@(private)
smooth_seg :: proc(t, a, b: f32) -> f32 {
	if b <= a {
		return 0
	}
	x := clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
}

// Fast ease-out into windup hold so anticipation snaps cleanly to peak coil.
@(private)
wind_ease :: proc(t, end_t: f32) -> f32 {
	if end_t <= 0 {
		return 1
	}
	x := clamp(t / end_t, 0, 1)
	inv := 1.0 - x
	return 1.0 - inv * inv * inv
}

// C1 pulse starting at 0, coiling to -1 at fire, whipping to +(1+overshoot) at
// fire+strike_len, decaying smoothly through follow-through, and returning to 0.
@(private)
attack_pulse :: proc(t, fire, strike_len, overshoot: f32) -> f32 {
	peak := fire + strike_len
	w := wind_ease(t, fire)
	s := smooth_seg(t, fire, peak)
	follow := smooth_seg(t, peak, peak + 0.14)
	recover := smooth_seg(t, 0.56, 0.94)
	settle := smooth_seg(t, 0.78, 0.88) * (1.0 - smooth_seg(t, 0.88, 0.99))
	return -w + (2.0 + overshoot) * s - overshoot * follow - recover - 0.05 * settle
}

// Heroic contrapposto guard: open angled stance, braced Kalkan, poised shamshir.
@(private)
pose_stance :: proc(pose: ^Pose) {
	pose_rot(pose, .Pelvis, 0.02, 0.14, -0.02)
	pose_rot(pose, .Spine, 0.04, -0.04, 0.02)
	pose_rot(pose, .Chest, 0.04, -0.04, 0.02)
	pose_rot(pose, .Neck, -0.04, -0.03, -0.01)
	pose_rot(pose, .Head, -0.04, -0.03, -0.01)
	pose_rot(pose, .Shoulder_L, -0.08, 0.10, -0.04)
	pose_rot(pose, .Arm_L, -0.28, 0.14, -0.16)
	pose_rot(pose, .Forearm_L, -0.70, -0.16, 0)
	pose_rot(pose, .Hand_L, 0.14, 0, 0)
	pose_rot(pose, .Shoulder_R, -0.03, -0.04, 0.04)
	pose_rot(pose, .Arm_R, 0.08, -0.12, 0.28)
	pose_rot(pose, .Forearm_R, -0.64, 0.10, 0)
	pose_rot(pose, .Hand_R, 0.48, 0.06, -0.10)
	pose_rot(pose, .Thigh_L, -0.12, -0.04, -0.04)
	pose_rot(pose, .Shin_L, 0.22, 0, 0)
	pose_rot(pose, .Foot_L, -0.12, 0, 0)
	pose_rot(pose, .Thigh_R, 0.06, 0.05, 0.04)
	pose_rot(pose, .Shin_R, 0.10, 0, 0)
	pose_rot(pose, .Foot_R, -0.18, 0, 0)
}

pose_idle :: proc(phase: f32, pose: ^Pose) {
	pose^ = {}
	pose_stance(pose)
	t := math_mod_01(phase) * math.TAU
	bt := math_mod_01(phase * 2.0) * math.TAU
	breath := 0.55 * math.sin(bt) - 0.18 * math.sin(2.0 * bt) + 0.12 * math.cos(bt)
	shift := math.sin(t)
	pose_idle_upper(t, bt, breath, shift, pose)
	l_soft := 0.5 * (1.0 + shift)
	r_soft := 0.5 * (1.0 - shift)
	pose_add(pose, .Thigh_L, -0.025 * l_soft, 0, 0)
	pose_add(pose, .Shin_L, 0.050 * l_soft, 0, 0)
	pose_add(pose, .Foot_L, -0.025 * l_soft, 0, 0)
	pose_add(pose, .Thigh_R, -0.025 * r_soft, 0, 0)
	pose_add(pose, .Shin_R, 0.050 * r_soft, 0, 0)
	pose_add(pose, .Foot_R, -0.025 * r_soft, 0, 0)
	pz := pose.rot[int(Bone_Id.Pelvis)].z
	ml := foot_ground_y(0.02, pz, pose.rot[int(Bone_Id.Thigh_L)].x, pose.rot[int(Bone_Id.Shin_L)].x, pose.rot[int(Bone_Id.Foot_L)].x, -1)
	mr := foot_ground_y(0.02, pz, pose.rot[int(Bone_Id.Thigh_R)].x, pose.rot[int(Bone_Id.Shin_R)].x, pose.rot[int(Bone_Id.Foot_R)].x, 1)
	pose.root_offset = rl.Vector3{0.016 * shift, -smin_feet(ml, mr), 0}
}

@(private)
pose_idle_upper :: proc(t, bt, breath, shift: f32, pose: ^Pose) {
	pose_add(pose, .Pelvis, 0.008 * breath, 0.032 * math.cos(t), -0.024 * shift)
	pose_add(pose, .Spine, 0.012 * breath, -0.016 * math.cos(t), 0.014 * shift)
	pose_add(pose, .Chest, -0.028 * breath, 0.035 * math.sin(t + 0.4), 0.012 * math.cos(t - 0.5))
	pose_add(pose, .Neck, 0.014 * breath, 0.030 * math.sin(t + 0.65), -0.008 * shift)
	pose_add(pose, .Head, 0.016 * breath, 0.085 * math.sin(t + 0.90) + 0.025 * math.sin(2.0 * t), 0.015 * math.cos(t))
	pose_add(pose, .Shoulder_L, -0.018 * math.sin(bt - 0.25), 0, -0.022 * math.sin(bt - 0.25))
	pose_add(pose, .Shoulder_R, -0.018 * math.sin(bt - 0.25), 0, 0.022 * math.sin(bt - 0.25))
	pose_add(pose, .Arm_L, 0.028 * math.sin(bt - 0.45), 0.015 * math.cos(t - 0.45), -0.018 * math.sin(bt - 0.45))
	pose_add(pose, .Forearm_L, -0.030 * math.sin(bt - 0.70), 0, 0)
	pose_add(pose, .Arm_R, 0.026 * math.sin(bt - 0.45), 0.018 * math.cos(t - 0.45), 0.018 * math.sin(bt - 0.45))
	pose_add(pose, .Forearm_R, 0.032 * math.sin(bt - 0.70), 0, 0)
	pose_add(pose, .Hand_R, 0.036 * math.sin(bt - 1.05), 0, 0.020 * math.cos(t - 1.0))
}

@(private)
walk_leg_angles :: proc(u, pelvis_x: f32) -> (thigh_x, shin_x, foot_x: f32) {
	// 2nd harmonic skews ~58% stance / ~42% swing with passing knee lead & terminal reach.
	th := u * math.TAU
	thigh_x = -0.37 * math.cos(th + 0.02) + 0.075 * math.sin(2.0 * th - 0.30) - 0.03 - 0.14 * gait_bump(u, 0.80, 0.18)
	shin_x = 0.05 + 0.52 * gait_bump(u, 0.12, 0.12) + 0.96 * gait_bump(u, 0.72, 0.23)
	world_pitch :=
		-0.27 * gait_bump(u, 0.99, 0.08) +
		0.38 * gait_bump(u, 0.41, 0.14) +
		0.62 * gait_bump(u, 0.56, 0.15) +
		0.58 * gait_bump(u, 0.71, 0.15)
	foot_x = world_pitch - (pelvis_x + thigh_x + shin_x)
	return
}

@(private)
foot_ground_y :: proc(pelvis_x, pelvis_z, thigh_x, shin_x, foot_x, side: f32) -> f32 {
	L_THIGH :: f32(0.425)
	L_SHIN :: f32(0.400)
	ANKLE_Y :: f32(0.095)
	HIP_HALF_W :: f32(0.125)
	a1 := pelvis_x + thigh_x
	a2 := a1 + shin_x
	a3 := a2 + foot_x
	hip_dy := side * HIP_HALF_W * math.sin(pelvis_z)
	y_ankle := ANKLE_Y + hip_dy + L_THIGH * (1.0 - math.cos(a1)) + L_SHIN * (1.0 - math.cos(a2))
	ca3 := math.cos(a3)
	sa3 := math.sin(a3)
	y_heel := y_ankle - 0.095 * ca3 + 0.055 * sa3
	y_ball := y_ankle - 0.095 * ca3 - 0.125 * sa3
	return min(y_heel, y_ball)
}

@(private)
smin_feet :: proc(a, b: f32) -> f32 {
	diff := a - b
	return 0.5 * (a + b - math.sqrt(diff * diff + 1.6e-5))
}

@(private)
walk_upper_body :: proc(t: f32, pose: ^Pose) {
	// Kinetic chain with progressive phase lag: Spine 0.22 -> Chest 0.42 -> Head 0.70.
	pose_rot(pose, .Spine, 0.075 + 0.022 * math.cos(2.0 * t - 0.45), -0.085 * math.cos(t - 0.22), 0.032 * math.sin(t - 0.65))
	pose_rot(pose, .Chest, 0.065 + 0.028 * math.cos(2.0 * t - 0.70), -0.130 * math.cos(t - 0.42), 0.038 * math.sin(t - 0.80))
	pose_rot(pose, .Neck, -0.055 - 0.018 * math.cos(2.0 * t - 0.85), 0.045 * math.cos(t - 0.55), -0.015 * math.sin(t - 0.80))
	pose_rot(pose, .Head, -0.062 - 0.020 * math.cos(2.0 * t - 1.00), 0.045 * math.cos(t - 0.70), -0.020 * math.sin(t - 0.92))

	// Shield arm (clavicle 0.35 -> upper 0.55 -> forearm 0.95 -> hand 1.30).
	pose_rot(pose, .Shoulder_L, -0.06 + 0.055 * math.cos(t - 0.35), 0.08 + 0.040 * math.cos(t - 0.35), -0.05 - 0.020 * math.sin(t - 0.35))
	pose_rot(pose, .Arm_L, -0.26 + 0.23 * math.cos(t - 0.55), 0.10 + 0.045 * math.sin(t - 0.55), -0.18 - 0.030 * math.cos(t - 0.55))
	pose_rot(pose, .Forearm_L, -0.64 + 0.15 * math.cos(t - 0.95), -0.14, 0)
	pose_rot(pose, .Hand_L, 0.10 + 0.10 * math.cos(t - 1.30), 0, 0)

	// Sword arm (clavicle 0.35 -> upper 0.52 -> forearm 0.95 -> wrist whip 1.35).
	pose_rot(pose, .Shoulder_R, -0.04 - 0.075 * math.cos(t - 0.35), -0.05 * math.cos(t - 0.35), 0.05 + 0.030 * math.sin(t - 0.35))
	pose_rot(pose, .Arm_R, -0.08 - 0.42 * math.cos(t - 0.52) + 0.05 * math.sin(2.0 * t - 0.52), -0.08, 0.26 + 0.040 * math.sin(t - 0.52))
	pose_rot(pose, .Forearm_R, -0.56 - 0.25 * math.cos(t - 0.95), 0.10, 0)
	pose_rot(pose, .Hand_R, 0.54 - 0.20 * math.cos(t - 1.35), 0.04, -0.08 - 0.060 * math.sin(t - 1.35))
}

pose_walk :: proc(phase: f32, pose: ^Pose) {
	pose^ = {}
	u_l := math_mod_01(phase)
	u_r := math_mod_01(phase + 0.5)
	t := u_l * math.TAU
	pelvis_x := 0.045 + 0.020 * math.cos(2.0 * t - 0.35)
	pelvis_y := 0.140 * math.cos(t - 0.08)
	pelvis_z := -0.058 * math.sin(t - 0.45)
	pose_rot(pose, .Pelvis, pelvis_x, pelvis_y, pelvis_z)

	tl_x, sl_x, fl_x := walk_leg_angles(u_l, pelvis_x)
	tr_x, sr_x, fr_x := walk_leg_angles(u_r, pelvis_x)
	hip_sway := 0.048 * math.sin(t - 0.45)
	pose_rot(pose, .Thigh_L, tl_x, -0.035 * math.sin(u_l * math.TAU), -0.030 + hip_sway)
	pose_rot(pose, .Shin_L, sl_x, 0, 0)
	pose_rot(pose, .Foot_L, fl_x, 0, 0)
	pose_rot(pose, .Thigh_R, tr_x, 0.035 * math.sin(u_r * math.TAU), 0.030 + hip_sway)
	pose_rot(pose, .Shin_R, sr_x, 0, 0)
	pose_rot(pose, .Foot_R, fr_x, 0, 0)

	walk_upper_body(t, pose)
	ml := foot_ground_y(pelvis_x, pelvis_z, tl_x, sl_x, fl_x, -1)
	mr := foot_ground_y(pelvis_x, pelvis_z, tr_x, sr_x, fr_x, 1)
	pose.root_offset = rl.Vector3{
		-0.038 * math.sin(t - 0.25),
		-smin_feet(ml, mr),
		0.018 * math.cos(2.0 * t - 0.60),
	}
}

// Staggered kinetic-chain cleave synced to slash_vfx (t in [0.28, 0.68]).
pose_attack :: proc(t: f32, pose: ^Pose) {
	p_hip := attack_pulse(t, 0.20, 0.14, 0.10)
	p_spn := attack_pulse(t, 0.23, 0.14, 0.12)
	p_chs := attack_pulse(t, 0.265, 0.15, 0.14)
	p_arm := attack_pulse(t, 0.28, 0.15, 0.16)
	p_elb := attack_pulse(t, 0.305, 0.15, 0.20)
	p_wrs := attack_pulse(t, 0.33, 0.15, 0.24)
	pose_add(pose, .Pelvis, 0.05 * p_hip, -0.22 * p_hip, -0.04 * p_hip)
	pose_add(pose, .Spine, 0.10 * p_spn, -0.24 * p_spn, -0.03 * p_spn)
	pose_add(pose, .Chest, 0.16 * p_chs, -0.52 * p_chs, -0.05 * p_chs)
	pose_add(pose, .Neck, -0.06 * p_chs, 0.20 * p_chs, 0)
	pose_add(pose, .Head, -0.09 * p_chs, 0.44 * p_chs, 0.04 * p_chs)
	pose_add(pose, .Shoulder_R, -0.28 * p_arm, 0.14 * p_arm, -0.22 * p_arm)
	pose_add(pose, .Arm_R, -0.38 * p_arm, 0.56 * p_arm, -0.80 * p_arm)
	pose_add(pose, .Forearm_R, 0.64 * p_elb, -0.08 * p_elb, 0)
	pose_add(pose, .Hand_R, 0.56 * p_wrs, 0.10 * p_wrs, -0.14 * p_wrs)
	pose_add(pose, .Arm_L, 0.30 * p_chs, -0.20 * p_chs, -0.06 * p_chs)
	pose_add(pose, .Forearm_L, 0.24 * p_chs, 0, 0)
	pose_attack_legs(p_hip, p_elb, pose)
}

@(private)
pose_attack_legs :: proc(p_hip, p_elb: f32, pose: ^Pose) {
	lunge := max(f32(0), p_hip)
	coil := max(f32(0), -p_hip)
	pose_add(pose, .Thigh_L, -0.32 * lunge + 0.08 * coil, 0, -0.03 * lunge)
	pose_add(pose, .Shin_L, 0.34 * lunge - 0.04 * coil, 0, 0)
	pose_add(pose, .Foot_L, -0.02 * lunge, 0, 0)
	pose_add(pose, .Thigh_R, 0.28 * lunge - 0.06 * coil, 0, 0.03 * lunge)
	pose_add(pose, .Shin_R, 0.12 * lunge + 0.08 * coil, 0, 0)
	pose_add(pose, .Foot_R, -0.40 * lunge, 0, 0)
	pose_add(pose, .Cape_1, 0.14 * lunge + 0.05 * coil, -0.12 * p_elb, 0)
	pose_add(pose, .Cape_2, 0.18 * lunge - 0.08 * p_elb, -0.16 * p_elb, 0)
	pose_add(pose, .Cape_3, 0.20 * lunge - 0.12 * p_elb, -0.18 * p_elb, 0)
	pose_add(pose, .Plume, 0.12 * lunge + 0.08 * p_elb, -0.22 * p_elb, 0)
	pose.root_offset.z += 0.14 * lunge - 0.03 * coil
	pose.root_offset.y += -0.058 * lunge + 0.015 * coil
}

// Traveling S-wave down Cape_1/2/3, thigh-cleared front sash, lagged plume.
pose_secondary :: proc(phase: f32, move: f32, pose: ^Pose) {
	t := math_mod_01(phase) * math.TAU
	cape := [3]Bone_Id{.Cape_1, .Cape_2, .Cape_3}
	base := [3]f32{0.060, 0.030, 0.015}
	lift := [3]f32{0.140, 0.050, 0.020}
	amp := [3]f32{0.055, 0.100, 0.145}
	cum_x := f32(0)
	for bone, i in cape {
		lag := f32(i) * 1.15
		wave2 := math.sin(2.0 * t - lag)
		sway1 := math.sin(t - lag * 0.70)
		rx := base[i] + lift[i] * move + (0.022 + amp[i] * move) * wave2
		if i < 2 && cum_x + rx < 0.035 {
			rx = 0.035 - cum_x
		}
		cum_x += rx
		pose_add(pose, bone, rx, (0.018 + 0.055 * move) * sway1, (0.022 + 0.065 * move) * sway1)
	}
	sash_kick := 0.5 + 0.5 * math.cos(2.0 * t - 0.45)
	sash_x := -(0.040 + 0.200 * move + 0.180 * move * sash_kick)
	sash_sway := math.sin(t - 0.5)
	pose_add(pose, .Sash, sash_x, (0.020 + 0.055 * move) * sash_sway, (0.015 + 0.040 * move) * sash_sway)

	plume_wave := math.sin(2.0 * t - 1.15)
	plume_sway := math.sin(t - 0.90)
	pose_add(
		pose,
		.Plume,
		0.030 + 0.110 * move + (0.024 + 0.085 * move) * plume_wave,
		(0.020 + 0.045 * move) * plume_sway,
		(0.020 + 0.055 * move) * plume_sway,
	)
}

pose_lerp :: proc(a, b: ^Pose, t: f32) -> Pose {
	u := clamp(t, 0, 1)
	out: Pose
	for i in 0..<BONE_COUNT {
		out.rot[i] = rl.Vector3{
			math.lerp(a.rot[i].x, b.rot[i].x, u),
			math.lerp(a.rot[i].y, b.rot[i].y, u),
			math.lerp(a.rot[i].z, b.rot[i].z, u),
		}
	}
	out.root_offset = rl.Vector3{
		math.lerp(a.root_offset.x, b.root_offset.x, u),
		math.lerp(a.root_offset.y, b.root_offset.y, u),
		math.lerp(a.root_offset.z, b.root_offset.z, u),
	}
	return out
}
