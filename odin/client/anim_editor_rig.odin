// Editor-only 3D Motion Control Rig rendering, picking, gizmos, and IK/COG modal transforms.
package main

import "core:math"
import rl "../gfx"
import rlgl "../gfx/rlgl"
import art "./art"
import anim_edit "./art/anim_edit"
import art_rig "./art/anim_rig"
import edit "./art/edit"

anim_sync_rig_from_preview :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	rot: [art.BONE_COUNT][3]f32
	for i in 0 ..< art.BONE_COUNT {
		r := ed.current_pose.rot[i]
		rot[i] = {r.x, r.y, r.z}
	}
	ro := ed.current_pose.root_offset
	off := [3]f32{ro.x, ro.y, ro.z}
	art_rig.rig_sync_from_pose(&ed.rig, &rot, off)
}

anim_draw_rig_3d :: proc() {
	ed := &app.anim_ed
	if !ed.rig.initialized {
		anim_sync_rig_from_preview()
	}
	if ed.xray_bones {
		rlgl.DisableDepthTest()
	}
	defer rlgl.EnableDepthTest()

	draw_pole_guideline(ed, .Pole_Elbow_L, .Forearm_L)
	draw_pole_guideline(ed, .Pole_Elbow_R, .Forearm_R)
	draw_pole_guideline(ed, .Pole_Knee_L, .Shin_L)
	draw_pole_guideline(ed, .Pole_Knee_R, .Shin_R)

	head_p := anim_bone_posed_head(&ed.pose_mats, .Head)
	rl.DrawLine3D(head_p, rl.Vector3(ed.rig.pos[.Head_Aim]), rl.Color{165, 224, 245, 165})
	hand_r := anim_bone_posed_head(&ed.pose_mats, .Hand_R)
	rl.DrawLine3D(hand_r, rl.Vector3(ed.rig.pos[.Sword_Tip]), rl.Color{235, 226, 170, 185})

	for i in 0 ..< art_rig.CTRL_COUNT {
		c := art_rig.Control_Id(i)
		p := rl.Vector3(ed.rig.pos[c])
		col := ctrl_color(ed, c)
		sel := ed.selected_ctrls[i]
		draw_ctrl_shape(art_rig.CONTROLS[c].shape, p, col, sel)
	}
}

@(private)
draw_pole_guideline :: proc(ed: ^Anim_Editor_State, pole_c: art_rig.Control_Id, joint: art.Bone_Id) {
	jp := anim_bone_posed_head(&ed.pose_mats, joint)
	pp := rl.Vector3(ed.rig.pos[pole_c])
	rl.DrawLine3D(jp, pp, rl.Color{210, 195, 140, 110})
}

@(private)
ctrl_color :: proc(ed: ^Anim_Editor_State, c: art_rig.Control_Id) -> rl.Color {
	ci := int(c)
	if ci == ed.hover_ctrl {
		return rl.Color{110, 232, 255, 255}
	}
	if ed.selected_ctrls[ci] {
		return c == ed.selected_ctrl ? rl.Color{255, 224, 96, 255} : rl.Color{242, 186, 68, 235}
	}
	if c == .Sword_Tip { return rl.Color{235, 226, 170, 245} }
	side := art_rig.CONTROLS[c].side
	if side < 0 { return rl.Color{92, 168, 255, 225} }
	if side > 0 { return rl.Color{240, 108, 92, 225} }
	return rl.Color{228, 198, 86, 230}
}

@(private)
draw_ctrl_shape :: proc(shape: art_rig.Control_Shape, center: rl.Vector3, col: rl.Color, sel: bool) {
	switch shape {
	case .Ring_Y:
		rad: f32 = sel ? 0.24 : 0.21
		draw_gizmo_ring(center, 1, rad, col)
		if sel { draw_gizmo_ring(center + {0, 0.01, 0}, 1, rad * 0.92, col) }
	case .Foot_Box:
		draw_wire_box(center, {0.10, 0.035, 0.16}, col)
	case .Wrist_Cube:
		draw_wire_box(center, {0.065, 0.065, 0.065}, col)
	case .Pole_Diamond:
		draw_wire_octa(center, sel ? 0.075 : 0.06, col)
	case .Aim_Cross:
		s: f32 = sel ? 0.085 : 0.07
		rl.DrawLine3D(center - {s, 0, 0}, center + {s, 0, 0}, col)
		rl.DrawLine3D(center - {0, s, 0}, center + {0, s, 0}, col)
		draw_gizmo_ring(center, 2, s * 0.85, col)
	}
}

@(private)
draw_wire_box :: proc(c, ext: rl.Vector3, col: rl.Color) {
	v := [8]rl.Vector3{
		c + {-ext.x, -ext.y, -ext.z}, c + {ext.x, -ext.y, -ext.z},
		c + {ext.x, ext.y, -ext.z}, c + {-ext.x, ext.y, -ext.z},
		c + {-ext.x, -ext.y, ext.z}, c + {ext.x, -ext.y, ext.z},
		c + {ext.x, ext.y, ext.z}, c + {-ext.x, ext.y, ext.z},
	}
	edges := [12][2]int{{0,1},{1,2},{2,3},{3,0},{4,5},{5,6},{6,7},{7,4},{0,4},{1,5},{2,6},{3,7}}
	for e in edges {
		rl.DrawLine3D(v[e[0]], v[e[1]], col)
	}
}

@(private)
draw_wire_octa :: proc(c: rl.Vector3, r: f32, col: rl.Color) {
	top, bot := c + {0, r, 0}, c - {0, r, 0}
	ring := [4]rl.Vector3{c + {r, 0, 0}, c + {0, 0, r}, c - {r, 0, 0}, c - {0, 0, r}}
	for i in 0 ..< 4 {
		n := (i + 1) % 4
		rl.DrawLine3D(ring[i], ring[n], col)
		rl.DrawLine3D(top, ring[i], col)
		rl.DrawLine3D(bot, ring[i], col)
	}
}

anim_draw_ctrl_gizmo_3d :: proc() {
	ed := &app.anim_ed
	if ed.selected_ctrl == .COUNT { return }
	def := art_rig.CONTROLS[ed.selected_ctrl]
	pivot := rl.Vector3(ed.rig.pos[ed.selected_ctrl])
	rlgl.DisableDepthTest()
	defer rlgl.EnableDepthTest()

	show_rot := def.can_rotate && (ed.tool == .Rotate || !def.can_move)
	if !show_rot {
		wlen := anim_world_per_px() * 68.0
		for axis in 0 ..< 3 {
			col := gizmo_axis_color(ed, axis)
			tip := pivot + GIZMO_AXES[axis] * wlen
			rl.DrawLine3D(pivot, tip, col)
			rl.DrawCylinderEx(pivot + GIZMO_AXES[axis] * (wlen * 0.80), tip, wlen * 0.08, 0, 8, col)
		}
		return
	}
	rad := anim_world_per_px() * 52.0
	for axis in 0 ..< 3 {
		col := gizmo_axis_color(ed, axis)
		draw_gizmo_ring(pivot, axis, rad, col)
		if ed.gizmo_hover == axis || ed.gizmo_drag_axis == axis {
			draw_gizmo_ring(pivot, axis, rad * 0.96, col)
			draw_gizmo_ring(pivot, axis, rad * 1.04, col)
		}
	}
}

anim_pick_ctrl :: proc(mouse: rl.Vector2) -> (art_rig.Control_Id, bool) {
	ed := &app.anim_ed
	if !ed.rig.initialized { anim_sync_rig_from_preview() }
	best := -1
	best_d2 := f32(256.0)
	for i in 0 ..< art_rig.CTRL_COUNT {
		sp := rl.GetWorldToScreen(rl.Vector3(ed.rig.pos[art_rig.Control_Id(i)]), ed.camera)
		d := sp - mouse
		d2 := d.x * d.x + d.y * d.y
		if d2 < best_d2 {
			best_d2 = d2
			best = i
		}
	}
	if best < 0 { return .COUNT, false }
	return art_rig.Control_Id(best), true
}

anim_ctrl_gizmo_hit_test :: proc(mouse: rl.Vector2) -> (axis: int, is_rot: bool) {
	ed := &app.anim_ed
	if ed.selected_ctrl == .COUNT { return -1, false }
	def := art_rig.CONTROLS[ed.selected_ctrl]
	pivot := rl.Vector3(ed.rig.pos[ed.selected_ctrl])
	show_rot := def.can_rotate && (ed.tool == .Rotate || !def.can_move)
	if !show_rot {
		o2d := rl.GetWorldToScreen(pivot, ed.camera)
		wlen := anim_world_per_px() * 68.0
		best, best_d2 := -1, f32(256.0)
		for ax in 0 ..< 3 {
			t2d := rl.GetWorldToScreen(pivot + GIZMO_AXES[ax] * wlen, ed.camera)
			d2, t := seg_dist_sq_2d(mouse, o2d, t2d)
			if t >= 0.14 && d2 < best_d2 {
				best_d2 = d2
				best = ax
			}
		}
		return best, false
	}
	rad := anim_world_per_px() * 52.0
	best, best_d2 := -1, f32(256.0)
	for ax in 0 ..< 3 {
		for s in 0 ..< GIZMO_RING_SEGS {
			a0 := f32(s) * math.TAU / f32(GIZMO_RING_SEGS)
			a1 := f32(s + 1) * math.TAU / f32(GIZMO_RING_SEGS)
			s0 := rl.GetWorldToScreen(pivot + gizmo_ring_dir(ax, a0) * rad, ed.camera)
			s1 := rl.GetWorldToScreen(pivot + gizmo_ring_dir(ax, a1) * rad, ed.camera)
			d2, _ := seg_dist_sq_2d(mouse, s0, s1)
			if d2 < best_d2 {
				best_d2 = d2
				best = ax
			}
		}
	}
	return best, true
}

anim_start_ctrl_modal :: proc(op: Anim_Tool, lock: edit.Axis_Lock, mouse: rl.Vector2) {
	ed := &app.anim_ed
	if !ed.clip_loaded { return }
	ed.playing = false
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	if !ed.rig.initialized { anim_sync_rig_from_preview() }
	ed.modal_is_ctrl = true
	ed.modal_base_all_rot = kf.rot
	ed.modal_base_root = kf.root_offset
	for i in 0 ..< art_rig.CTRL_COUNT {
		ed.modal_base_ctrl_pos[i] = ed.rig.pos[art_rig.Control_Id(i)]
	}
	ed.modal_restore_tool = ed.tool
	ed.tool = op
	ed.modal_active = true
	ed.modal_op = op
	ed.axis_lock = lock
	ed.modal_start_mouse = mouse
	ed.modal_angle = 0
	ed.modal_delta = {}
	ed.num_len = 0
	ed.gizmo_drag_axis = lock == .X ? 0 : (lock == .Y ? 1 : (lock == .Z ? 2 : -1))
}

apply_anim_ctrl_modal :: proc(mouse: rl.Vector2) {
	ed := &app.anim_ed
	ctrl := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	num_val, has_num := parse_anim_modal_number()
	dpx := mouse - ed.modal_start_mouse
	kf := &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]

	if ed.modal_op == .Rotate {
		axis_idx := ed.axis_lock == .Y ? 1 : (ed.axis_lock == .Z ? 2 : 0)
		ci := ed.selected_ctrl != .COUNT ? int(ed.selected_ctrl) : 0
		ang := compute_anim_rotate_angle(rl.Vector3(ed.modal_base_ctrl_pos[ci]), axis_idx, mouse, has_num, num_val, ctrl)
		ed.modal_angle = ang
		drot := [3]f32{}
		drot[axis_idx] = ang
		kf.rot = ed.modal_base_all_rot
		for i in 0 ..< art_rig.CTRL_COUNT {
			if !ed.selected_ctrls[i] { continue }
			art_rig.rig_apply_rotate_delta(kf, art_rig.Control_Id(i), &ed.modal_base_all_rot, drot, ed.mirror_lr)
		}
		anim_edit.recompute_clip_handles(&ed.clip)
		ed.clip.dirty = true
		return
	}

	delta := compute_anim_root_delta(dpx, has_num, num_val, ctrl)
	ed.modal_delta = delta
	kf.rot = ed.modal_base_all_rot
	kf.root_offset = ed.modal_base_root
	for i in 0 ..< art_rig.CTRL_COUNT {
		ed.rig.pos[art_rig.Control_Id(i)] = ed.modal_base_ctrl_pos[i]
	}
	for i in 0 ..< art_rig.CTRL_COUNT {
		if !ed.selected_ctrls[i] { continue }
		c := art_rig.Control_Id(i)
		if !art_rig.CONTROLS[c].can_move { continue }
		anim_apply_rig_translate_clip(kf, c, ed.modal_base_ctrl_pos[i] + delta)
	}
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
}

anim_apply_rig_translate_clip :: proc(kf: ^anim_edit.Edit_Keyframe, ctrl: art_rig.Control_Id, target_pos: [3]f32) {
	ed := &app.anim_ed
	if !ed.clip.additive {
		art_rig.rig_apply_translate(&ed.rig, kf, ctrl, target_pos, ed.mirror_lr)
		return
	}
	base: art.Pose
	art.eval_unit_idle(0.25, ed.preview_team == .Enemy, ed.preview_team == .Hero, &base)
	tmp := kf^
	for i in 0 ..< art.BONE_COUNT {
		r := base.rot[i]
		tmp.rot[i] += {r.x, r.y, r.z}
	}
	ro := base.root_offset
	tmp.root_offset += {ro.x, ro.y, ro.z}
	art_rig.rig_apply_translate(&ed.rig, &tmp, ctrl, target_pos, ed.mirror_lr)
	for i in 0 ..< art.BONE_COUNT {
		r := base.rot[i]
		kf.rot[i] = tmp.rot[i] - {r.x, r.y, r.z}
	}
	kf.root_offset = tmp.root_offset - {ro.x, ro.y, ro.z}
}

anim_draw_vp_box_2d :: proc() {
	ed := &app.anim_ed
	if !ed.vp_box_active { return }
	r := anim_editor_box_rect_2d(ed.vp_box_start, input_mouse_pos())
	rl.DrawRectangleRec(r, rl.Color{236, 217, 166, 36})
	rl.DrawRectangleLinesEx(r, 1.5, rl.Color{236, 217, 166, 220})
}

anim_draw_ctrl_overlays_2d :: proc(vp: rl.Rectangle) {
	ed := &app.anim_ed
	if !ed.rig.initialized { return }
	for i in 0 ..< art_rig.CTRL_COUNT {
		c := art_rig.Control_Id(i)
		if !ed.selected_ctrls[i] && i != ed.hover_ctrl { continue }
		sp := rl.GetWorldToScreen(rl.Vector3(ed.rig.pos[c]), ed.camera)
		if !rl.CheckCollisionPointRec(sp, vp) { continue }
		col := i == ed.hover_ctrl ? rl.Color{110, 232, 255, 230} : (c == ed.selected_ctrl ? rl.Color{255, 224, 96, 235} : rl.Color{240, 182, 68, 210})
		rad: f32 = c == ed.selected_ctrl ? 8 : 6
		rl.DrawCircleLines(i32(sp.x), i32(sp.y), rad, col)
	}
}
