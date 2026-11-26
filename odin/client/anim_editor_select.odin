// Maya/Blender-style multiselect for 3D bones, motion controls, and selection presets.
package main

import rl "../gfx"
import art "./art"
import art_rig "./art/anim_rig"

ANIM_PRESET_NAMES := [6]string{"Spine", "L Arm", "R Arm", "L Leg", "R Leg", "Cape"}

anim_is_rig_active :: proc() -> bool {
	return app.anim_ed.rig_mode != .Bones
}

anim_select_bone_only :: proc(b: art.Bone_Id) {
	ed := &app.anim_ed
	ed.selected_bones = {}
	ed.selected_bones[int(b)] = true
	ed.selected_bone = b
	ed.curve_is_root = b == .Root
	anim_curves_fit_view()
}

anim_toggle_bone_select :: proc(b: art.Bone_Id) {
	ed := &app.anim_ed
	bi := int(b)
	was := ed.selected_bones[bi]
	if was && anim_selected_bone_count() > 1 {
		ed.selected_bones[bi] = false
		if ed.selected_bone == b {
			for i in 0 ..< art.BONE_COUNT {
				if ed.selected_bones[i] {
					ed.selected_bone = art.Bone_Id(i)
					break
				}
			}
		}
	} else {
		ed.selected_bones[bi] = true
		ed.selected_bone = b
	}
	ed.curve_is_root = ed.selected_bone == .Root
	anim_curves_fit_view()
}

anim_select_bone_chain :: proc(root_b: art.Bone_Id, additive: bool) {
	ed := &app.anim_ed
	if !additive {
		ed.selected_bones = {}
	}
	for i in 0 ..< art.BONE_COUNT {
		cur := art.Bone_Id(i)
		steps := 0
		for steps < art.BONE_COUNT {
			if cur == root_b {
				ed.selected_bones[i] = true
				break
			}
			if art.BONES[cur].root {
				break
			}
			cur = art.BONES[cur].parent
			steps += 1
		}
	}
	ed.selected_bone = root_b
	ed.curve_is_root = root_b == .Root
	anim_curves_fit_view()
}

anim_selected_bone_count :: proc() -> int {
	n := 0
	for s in app.anim_ed.selected_bones {
		if s { n += 1 }
	}
	return n
}

anim_select_all_bones :: proc() {
	ed := &app.anim_ed
	any_unselected := false
	for s in ed.selected_bones {
		if !s {
			any_unselected = true
			break
		}
	}
	if any_unselected {
		for i in 0 ..< art.BONE_COUNT {
			ed.selected_bones[i] = true
		}
	} else {
		anim_select_bone_only(ed.selected_bone)
	}
}

anim_select_ctrl_only :: proc(c: art_rig.Control_Id) {
	ed := &app.anim_ed
	ed.selected_ctrls = {}
	if c != .COUNT {
		ed.selected_ctrls[int(c)] = true
		ed.selected_ctrl = c
		ed.selected_bone = art_rig.CONTROLS[c].bone
		ed.curve_is_root = c == .COG
		anim_curves_fit_view()
	}
}

anim_toggle_ctrl_select :: proc(c: art_rig.Control_Id) {
	ed := &app.anim_ed
	if c == .COUNT { return }
	ci := int(c)
	was := ed.selected_ctrls[ci]
	if was && anim_selected_ctrl_count() > 1 {
		ed.selected_ctrls[ci] = false
		if ed.selected_ctrl == c {
			for i in 0 ..< art_rig.CTRL_COUNT {
				if ed.selected_ctrls[i] {
					ed.selected_ctrl = art_rig.Control_Id(i)
					break
				}
			}
		}
	} else {
		ed.selected_ctrls[ci] = true
		ed.selected_ctrl = c
	}
	ed.selected_bone = art_rig.CONTROLS[ed.selected_ctrl].bone
	ed.curve_is_root = ed.selected_ctrl == .COG
	anim_curves_fit_view()
}

anim_selected_ctrl_count :: proc() -> int {
	n := 0
	for s in app.anim_ed.selected_ctrls {
		if s { n += 1 }
	}
	return n
}

anim_select_all_ctrls :: proc() {
	ed := &app.anim_ed
	any_unselected := false
	for i in 0 ..< art_rig.CTRL_COUNT {
		if !ed.selected_ctrls[i] {
			any_unselected = true
			break
		}
	}
	if any_unselected {
		for i in 0 ..< art_rig.CTRL_COUNT {
			ed.selected_ctrls[i] = true
		}
	} else {
		anim_select_ctrl_only(ed.selected_ctrl)
	}
}

anim_apply_selection_preset :: proc(preset_idx: int, additive: bool) {
	ed := &app.anim_ed
	if !additive {
		ed.selected_bones = {}
		ed.selected_ctrls = {}
	}
	SPINE := [?]art.Bone_Id{.Pelvis, .Spine, .Chest, .Neck, .Head}
	L_ARM := [?]art.Bone_Id{.Shoulder_L, .Arm_L, .Forearm_L, .Hand_L}
	R_ARM := [?]art.Bone_Id{.Shoulder_R, .Arm_R, .Forearm_R, .Hand_R}
	L_LEG := [?]art.Bone_Id{.Thigh_L, .Shin_L, .Foot_L}
	R_LEG := [?]art.Bone_Id{.Thigh_R, .Shin_R, .Foot_R}
	CAPE  := [?]art.Bone_Id{.Cape_1, .Cape_2, .Cape_3, .Sash}

	bones: []art.Bone_Id
	ctrls: []art_rig.Control_Id
	C_SPINE := [?]art_rig.Control_Id{.COG, .Chest_Ctrl, .Head_Aim}
	C_LARM  := [?]art_rig.Control_Id{.Hand_IK_L, .Pole_Elbow_L}
	C_RARM  := [?]art_rig.Control_Id{.Hand_IK_R, .Pole_Elbow_R}
	C_LLEG  := [?]art_rig.Control_Id{.Foot_IK_L, .Pole_Knee_L}
	C_RLEG  := [?]art_rig.Control_Id{.Foot_IK_R, .Pole_Knee_R}
	C_CAPE  := [?]art_rig.Control_Id{.Cape_Ctrl}
	switch preset_idx {
	case 0: bones, ctrls = SPINE[:], C_SPINE[:]
	case 1: bones, ctrls = L_ARM[:], C_LARM[:]
	case 2: bones, ctrls = R_ARM[:], C_RARM[:]
	case 3: bones, ctrls = L_LEG[:], C_LLEG[:]
	case 4: bones, ctrls = R_LEG[:], C_RLEG[:]
	case 5: bones, ctrls = CAPE[:], C_CAPE[:]
	}
	for b in bones { ed.selected_bones[int(b)] = true }
	for c in ctrls { ed.selected_ctrls[int(c)] = true }
	if len(bones) > 0 { ed.selected_bone = bones[0] }
	if len(ctrls) > 0 { ed.selected_ctrl = ctrls[0] }
	ed.curve_is_root = ed.selected_bone == .Root || (anim_is_rig_active() && ed.selected_ctrl == .COG)
	anim_curves_fit_view()
}

anim_vp_box_select :: proc(r: rl.Rectangle, additive: bool) {
	ed := &app.anim_ed
	if anim_is_rig_active() {
		if !additive { ed.selected_ctrls = {} }
		first := art_rig.Control_Id.COUNT
		for i in 0 ..< art_rig.CTRL_COUNT {
			c := art_rig.Control_Id(i)
			sp := rl.GetWorldToScreen(rl.Vector3(ed.rig.pos[c]), ed.camera)
			if rl.CheckCollisionPointRec(sp, r) {
				ed.selected_ctrls[i] = true
				if first == .COUNT { first = c }
			}
		}
		if first != .COUNT {
			ed.selected_ctrl = first
			ed.selected_bone = art_rig.CONTROLS[first].bone
			ed.curve_is_root = first == .COG
			anim_curves_fit_view()
		}
		if ed.rig_mode == .Rig { return }
	}
	if !additive { ed.selected_bones = {} }
	first_b := -1
	for i in 0 ..< art.BONE_COUNT {
		b := art.Bone_Id(i)
		sp := rl.GetWorldToScreen(anim_bone_posed_head(&ed.pose_mats, b), ed.camera)
		if rl.CheckCollisionPointRec(sp, r) {
			ed.selected_bones[i] = true
			if first_b < 0 { first_b = i }
		}
	}
	if first_b >= 0 {
		ed.selected_bone = art.Bone_Id(first_b)
		ed.curve_is_root = ed.selected_bone == .Root
		anim_curves_fit_view()
	}
}
