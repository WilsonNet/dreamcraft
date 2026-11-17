#+build !js
package main

import "core:math"
import "core:testing"
import rl "vendor:raylib"

@(test)
mamluk_mesh_builds :: proc(t: ^testing.T) {
	b := build_mamluk(false)
	defer mb_delete(&b)
	testing.expect(t, !b.overflow)
	testing.expect(t, len(b.pos) > 2000)
	testing.expect(t, len(b.idx) > 3000)
	testing.expect_value(t, len(b.pos), len(b.nrm))
	testing.expect_value(t, len(b.pos), len(b.col))
	testing.expect_value(t, len(b.pos), len(b.uv))
	testing.expect_value(t, len(b.pos), len(b.bone))
	testing.expect_value(t, len(b.idx) % 3, 0)
}

@(test)
mamluk_mesh_is_finite_and_in_range :: proc(t: ^testing.T) {
	for enemy in ([2]bool{false, true}) {
		b := build_mamluk(enemy)
		defer mb_delete(&b)
		bad_bone := 0
		bad_normal := 0
		bad_bounds := 0
		for i in 0..<len(b.pos) {
			p := b.pos[i]
			n := b.nrm[i]
			length := math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
			if abs(length - 1.0) > 0.02 {
				bad_normal += 1
			}
			if p.y < -0.05 || p.y > 2.3 || abs(p.x) > 1.1 || abs(p.z) > 1.1 {
				bad_bounds += 1
			}
			if int(b.bone[i]) >= BONE_COUNT {
				bad_bone += 1
			}
		}
		testing.expect_value(t, bad_normal, 0)
		testing.expect_value(t, bad_bounds, 0)
		testing.expect_value(t, bad_bone, 0)
	}
}

@(test)
body_point_lengthens_legs_and_keeps_feet_grounded :: proc(t: ^testing.T) {
	testing.expect_value(t, body_point(rl.Vector3{0, 0, 0}).y, 0)
	testing.expect(t, body_point(rl.Vector3{0, 1.0, 0}).y > 1.10)
	testing.expect(t, body_point(rl.Vector3{0, 1.8, 0}).y > 1.90)
}

@(test)
bone_rotation_moves_children_only :: proc(t: ^testing.T) {
	b := build_mamluk(false)
	defer mb_delete(&b)

	pose: Pose
	pose_rot(&pose, .Forearm_R, -1.2, 0, 0)
	matrices := pose_matrices(&pose, rl.Matrix(1))

	hand_moved := false
	foot_still := true
	for i in 0..<len(b.pos) {
		bone := Bone_Id(b.bone[i])
		if bone != .Hand_R && bone != .Foot_L && bone != .Foot_R {
			continue
		}
		p := b.pos[i]
		moved := xf_point(matrices[int(bone)], p)
		distance := abs(moved.x - p.x) + abs(moved.y - p.y) + abs(moved.z - p.z)
		if bone == .Hand_R {
			hand_moved = hand_moved || distance > 0.01
		} else {
			foot_still = foot_still && distance < 0.0001
		}
	}
	testing.expect(t, hand_moved)
	testing.expect(t, foot_still)
}

@(test)
animation_clips_stay_finite_and_loop :: proc(t: ^testing.T) {
	for step in 0..<32 {
		phase := f32(step) / 32
		pose: Pose
		pose_walk(phase, &pose)
		pose_secondary(phase, 1.0, &pose)
		for rot in pose.rot {
			testing.expect(t, !math.is_nan(rot.x) && !math.is_nan(rot.y) && !math.is_nan(rot.z))
			testing.expect(t, abs(rot.x) < 4 && abs(rot.y) < 4 && abs(rot.z) < 4)
		}
	}
}

@(test)
attack_clip_returns_to_guard_pose :: proc(t: ^testing.T) {
	base: Pose
	pose_idle(0.2, &base)
	finished := base
	pose_attack(1.0, &finished)
	for rot, i in base.rot {
		testing.expect(t, abs(finished.rot[i].x - rot.x) < 0.001)
		testing.expect(t, abs(finished.rot[i].y - rot.y) < 0.001)
		testing.expect(t, abs(finished.rot[i].z - rot.z) < 0.001)
	}
}

@(test)
face_geometry_sits_below_the_brow :: proc(t: ^testing.T) {
	b := build_mamluk(false)
	defer mb_delete(&b)
	// Eyes are skinned to the head joint; they must stay inside the turban rim
	// and above the collar so the face is never buried.
	eye_top: f32 = 0
	eye_count := 0
	for i in 0..<len(b.pos) {
		if Bone_Id(b.bone[i]) != .Head {
			continue
		}
		p := b.pos[i]
		if abs(p.z - 0.09) < 0.02 && p.y > 1.70 && p.y < 1.80 {
			eye_count += 1
			eye_top = max(eye_top, p.y)
		}
	}
	testing.expect(t, eye_count > 0)
	testing.expect(t, eye_top < 1.86)
}
