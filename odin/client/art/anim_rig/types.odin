// Editor-only motion control rig definitions (never imported by in-game runtime).
package art_anim_rig

import spec "../spec"

Control_Id :: enum u8 {
	COG,
	Chest_Ctrl,
	Head_Aim,
	Cape_Ctrl,
	Hand_IK_L,
	Hand_IK_R,
	Pole_Elbow_L,
	Pole_Elbow_R,
	Foot_IK_L,
	Foot_IK_R,
	Pole_Knee_L,
	Pole_Knee_R,
	COUNT,
}

CTRL_COUNT :: int(Control_Id.COUNT)

Control_Shape :: enum u8 {
	Ring_Y,
	Foot_Box,
	Wrist_Cube,
	Pole_Diamond,
	Aim_Cross,
}

Control_Def :: struct {
	id:         Control_Id,
	name:       string,
	bone:       spec.Bone_Id,
	shape:      Control_Shape,
	can_move:   bool,
	can_rotate: bool,
	side:       i8, // -1 = L, 0 = Center, +1 = R
}

CONTROLS := [Control_Id]Control_Def {
	.COG          = {id = .COG, name = "COG", bone = .Pelvis, shape = .Ring_Y, can_move = true, can_rotate = true, side = 0},
	.Chest_Ctrl   = {id = .Chest_Ctrl, name = "Chest", bone = .Chest, shape = .Ring_Y, can_move = false, can_rotate = true, side = 0},
	.Head_Aim     = {id = .Head_Aim, name = "Head Aim", bone = .Head, shape = .Aim_Cross, can_move = true, can_rotate = true, side = 0},
	.Cape_Ctrl    = {id = .Cape_Ctrl, name = "Cape", bone = .Cape_2, shape = .Ring_Y, can_move = false, can_rotate = true, side = 0},
	.Hand_IK_L    = {id = .Hand_IK_L, name = "Hand L", bone = .Hand_L, shape = .Wrist_Cube, can_move = true, can_rotate = true, side = -1},
	.Hand_IK_R    = {id = .Hand_IK_R, name = "Hand R", bone = .Hand_R, shape = .Wrist_Cube, can_move = true, can_rotate = true, side = 1},
	.Pole_Elbow_L = {id = .Pole_Elbow_L, name = "Elbow L", bone = .Forearm_L, shape = .Pole_Diamond, can_move = true, can_rotate = false, side = -1},
	.Pole_Elbow_R = {id = .Pole_Elbow_R, name = "Elbow R", bone = .Forearm_R, shape = .Pole_Diamond, can_move = true, can_rotate = false, side = 1},
	.Foot_IK_L    = {id = .Foot_IK_L, name = "Foot L", bone = .Foot_L, shape = .Foot_Box, can_move = true, can_rotate = true, side = -1},
	.Foot_IK_R    = {id = .Foot_IK_R, name = "Foot R", bone = .Foot_R, shape = .Foot_Box, can_move = true, can_rotate = true, side = 1},
	.Pole_Knee_L  = {id = .Pole_Knee_L, name = "Knee L", bone = .Shin_L, shape = .Pole_Diamond, can_move = true, can_rotate = false, side = -1},
	.Pole_Knee_R  = {id = .Pole_Knee_R, name = "Knee R", bone = .Shin_R, shape = .Pole_Diamond, can_move = true, can_rotate = false, side = 1},
	.COUNT        = {},
}

Rig_Targets :: struct {
	pos:         [Control_Id][3]f32,
	pin_feet:    bool,
	initialized: bool,
}

ctrl_mirror_pair :: proc(id: Control_Id) -> (Control_Id, bool) {
	#partial switch id {
	case .Hand_IK_L:    return .Hand_IK_R, true
	case .Hand_IK_R:    return .Hand_IK_L, true
	case .Pole_Elbow_L: return .Pole_Elbow_R, true
	case .Pole_Elbow_R: return .Pole_Elbow_L, true
	case .Foot_IK_L:    return .Foot_IK_R, true
	case .Foot_IK_R:    return .Foot_IK_L, true
	case .Pole_Knee_L:  return .Pole_Knee_R, true
	case .Pole_Knee_R:  return .Pole_Knee_L, true
	}
	return id, false
}
