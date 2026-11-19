#+build !js
package art

import "core:math"
import "core:testing"
import rl "vendor:raylib"

@(private)
build_proc_mamluk :: proc(t: ^testing.T, enemy: bool, hero: bool = false) -> Mesh_Builder {
	b, ok := build_procedural_by_id("mamluk", enemy, hero)
	testing.expect(t, ok)
	return b
}

@(test)
mamluk_mesh_builds :: proc(t: ^testing.T) {
	b := build_mamluk(false)
	defer mb_delete(&b)
	testing.expect(t, !b.overflow)
	testing.expect(t, len(b.pos) > 500)
	testing.expect(t, len(b.idx) > 900)
	testing.expect_value(t, len(b.pos), len(b.nrm))
	testing.expect_value(t, len(b.pos), len(b.col))
	testing.expect_value(t, len(b.pos), len(b.uv))
	testing.expect_value(t, len(b.pos), len(b.bone))
	testing.expect_value(t, len(b.idx) % 3, 0)
}

@(test)
mamluk_mesh_is_finite_and_in_range :: proc(t: ^testing.T) {
	for enemy in ([2]bool{false, true}) {
		b := build_proc_mamluk(t, enemy)
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
mamluk_feet_sit_grounded_and_height_is_heroic :: proc(t: ^testing.T) {
	b := build_proc_mamluk(t, false)
	defer mb_delete(&b)
	testing.expect(t, !b.overflow)
	min_y := f32(100)
	max_y := f32(-100)
	for p in b.pos {
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	}
	height := max_y - min_y
	testing.expect(t, min_y >= -0.01 && min_y <= 0.02)
	testing.expect(t, height >= 1.85 && height <= 2.02)
}

@(test)
walk_pose_keeps_feet_grounded_and_rises_at_passing :: proc(t: ^testing.T) {
	b := build_proc_mamluk(t, false)
	defer mb_delete(&b)
	for step in 0..<32 {
		phase := f32(step) / 32.0
		pose: Pose
		pose_walk(phase, &pose)
		matrices := pose_matrices(&pose, rl.Matrix(1))
		min_foot_y := f32(100)
		for i in 0..<len(b.pos) {
			bone := Bone_Id(b.bone[i])
			if bone != .Foot_L && bone != .Foot_R {
				continue
			}
			moved := xf_point(matrices[int(bone)], b.pos[i])
			min_foot_y = min(min_foot_y, moved.y)
		}
		testing.expect(t, min_foot_y >= -0.02 && min_foot_y <= 0.03)
	}
	contact, down, pass, up: Pose
	pose_walk(0.00, &contact)
	pose_walk(0.12, &down)
	pose_walk(0.25, &pass)
	pose_walk(0.40, &up)
	testing.expect(t, down.root_offset.y < contact.root_offset.y)
	testing.expect(t, pass.root_offset.y > contact.root_offset.y)
	testing.expect(t, up.root_offset.y > pass.root_offset.y)
}

@(test)
idle_pose_keeps_feet_grounded_across_cycle :: proc(t: ^testing.T) {
	b := build_proc_mamluk(t, false)
	defer mb_delete(&b)
	for step in 0..<16 {
		phase := f32(step) / 16.0
		pose: Pose
		pose_idle(phase, &pose)
		matrices := pose_matrices(&pose, rl.Matrix(1))
		min_foot_y := f32(100)
		for i in 0..<len(b.pos) {
			bone := Bone_Id(b.bone[i])
			if bone != .Foot_L && bone != .Foot_R {
				continue
			}
			moved := xf_point(matrices[int(bone)], b.pos[i])
			min_foot_y = min(min_foot_y, moved.y)
		}
		testing.expect(t, min_foot_y >= -0.01 && min_foot_y <= 0.025)
	}
}

@(test)
bone_rotation_moves_children_only :: proc(t: ^testing.T) {
	b := build_proc_mamluk(t, false)
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
		testing.expect(t, !math.is_nan(pose.root_offset.y) && abs(pose.root_offset.y) < 0.2)
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
	windup := base
	pose_attack(0.28, &windup)
	testing.expect(t, windup.rot[int(Bone_Id.Chest)].y > base.rot[int(Bone_Id.Chest)].y)
}

@(test)
face_geometry_sits_below_the_brow :: proc(t: ^testing.T) {
	b := build_proc_mamluk(t, false)
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
		if abs(p.z - 0.09) < 0.02 && p.y > 1.65 && p.y < 1.80 {
			eye_count += 1
			eye_top = max(eye_top, p.y)
		}
	}
	testing.expect(t, eye_count > 0)
	testing.expect(t, eye_top < 1.86)
}
