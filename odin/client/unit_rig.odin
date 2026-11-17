// Unit skeleton: joint hierarchy, pose evaluation and CPU skinning.
//
// Bones are joint points in model space (feet on Y=0, facing +Z). A pose is a
// rotation per joint around its own head, accumulated down the hierarchy. Each
// mesh part follows exactly one joint, which keeps the animation crisp at
// sprite scale and the skinning cost trivial.
package main

import rl "vendor:raylib"

Bone_Id :: enum u8 {
	Root,
	Pelvis,
	Spine,
	Chest,
	Neck,
	Head,
	Plume,
	Shoulder_L,
	Arm_L,
	Forearm_L,
	Hand_L,
	Shoulder_R,
	Arm_R,
	Forearm_R,
	Hand_R,
	Thigh_L,
	Shin_L,
	Foot_L,
	Thigh_R,
	Shin_R,
	Foot_R,
	Cape_1,
	Cape_2,
	Cape_3,
	Sash,
	COUNT,
}

BONE_COUNT :: int(Bone_Id.COUNT)

Bone_Def :: struct {
	head:   rl.Vector3,
	parent: Bone_Id,
	root:   bool,
}

// Parents always appear before their children so a single forward pass can
// evaluate the whole rig.
BONES := #partial [Bone_Id]Bone_Def {
	.Root       = {head = {0, 0, 0}, root = true},
	.Pelvis     = {head = {0, 0.92, 0}, parent = .Root},
	.Spine      = {head = {0, 1.00, 0}, parent = .Pelvis},
	.Chest      = {head = {0, 1.18, 0}, parent = .Spine},
	.Neck       = {head = {0, 1.46, 0}, parent = .Chest},
	.Head       = {head = {0, 1.52, 0}, parent = .Neck},
	.Plume      = {head = {0, 1.90, -0.06}, parent = .Head},
	.Shoulder_L = {head = {-0.16, 1.42, 0}, parent = .Chest},
	.Arm_L      = {head = {-0.28, 1.40, 0}, parent = .Shoulder_L},
	.Forearm_L  = {head = {-0.31, 1.16, 0}, parent = .Arm_L},
	.Hand_L     = {head = {-0.32, 0.94, 0}, parent = .Forearm_L},
	.Shoulder_R = {head = {0.16, 1.42, 0}, parent = .Chest},
	.Arm_R      = {head = {0.28, 1.40, 0}, parent = .Shoulder_R},
	.Forearm_R  = {head = {0.31, 1.16, 0}, parent = .Arm_R},
	.Hand_R     = {head = {0.32, 0.94, 0}, parent = .Forearm_R},
	.Thigh_L    = {head = {-0.115, 0.88, 0}, parent = .Pelvis},
	.Shin_L     = {head = {-0.12, 0.50, 0}, parent = .Thigh_L},
	.Foot_L     = {head = {-0.12, 0.10, 0.02}, parent = .Shin_L},
	.Thigh_R    = {head = {0.115, 0.88, 0}, parent = .Pelvis},
	.Shin_R     = {head = {0.12, 0.50, 0}, parent = .Thigh_R},
	.Foot_R     = {head = {0.12, 0.10, 0.02}, parent = .Shin_R},
	.Cape_1     = {head = {0, 1.34, -0.13}, parent = .Chest},
	.Cape_2     = {head = {0, 1.10, -0.17}, parent = .Cape_1},
	.Cape_3     = {head = {0, 0.86, -0.19}, parent = .Cape_2},
	.Sash       = {head = {0, 0.94, 0.15}, parent = .Pelvis},
}

Pose :: struct {
	rot:         [BONE_COUNT]rl.Vector3,
	root_offset: rl.Vector3,
}

pose_rot :: proc(pose: ^Pose, bone: Bone_Id, x, y, z: f32) {
	pose.rot[int(bone)] = rl.Vector3{x, y, z}
}

pose_add :: proc(pose: ^Pose, bone: Bone_Id, x, y, z: f32) {
	pose.rot[int(bone)] += rl.Vector3{x, y, z}
}

// Rotate around a joint head in model space.
@(private)
bone_matrix :: proc(bone: Bone_Id, rot: rl.Vector3) -> rl.Matrix {
	head := body_point(BONES[bone].head)
	return xf_mul(
		xf_mul(rl.MatrixTranslate(head.x, head.y, head.z), rl.MatrixRotateXYZ(rot)),
		rl.MatrixTranslate(-head.x, -head.y, -head.z),
	)
}

// Model-space transform per joint, composed with the unit placement.
pose_matrices :: proc(pose: ^Pose, unit: rl.Matrix) -> [BONE_COUNT]rl.Matrix {
	result: [BONE_COUNT]rl.Matrix
	model: [BONE_COUNT]rl.Matrix
	for index in 0..<BONE_COUNT {
		bone := Bone_Id(index)
		local := bone_matrix(bone, pose.rot[int(bone)])
		if BONES[bone].root {
			local = xf_mul(
				rl.MatrixTranslate(pose.root_offset.x, pose.root_offset.y, pose.root_offset.z),
				local,
			)
			model[int(bone)] = local
		} else {
			model[int(bone)] = xf_mul(model[int(BONES[bone].parent)], local)
		}
	}
	for index in 0..<BONE_COUNT {
		result[index] = xf_mul(unit, model[index])
	}
	return result
}

// Rigid skinning: every vertex follows exactly one joint.
skin_vertices :: proc(
	rest_pos: []rl.Vector3,
	rest_nrm: []rl.Vector3,
	out_pos: []rl.Vector3,
	out_nrm: []rl.Vector3,
	bones: []u8,
	matrices: [BONE_COUNT]rl.Matrix,
) {
	for i in 0..<len(rest_pos) {
		m := matrices[int(bones[i])]
		out_pos[i] = xf_point(m, rest_pos[i])
		out_nrm[i] = v_norm(xf_dir(m, rest_nrm[i]))
	}
}
