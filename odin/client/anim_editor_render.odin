// Animation Picker turntable and Animation Editor 3D viewport, skeleton, onion skin, and gizmos.
package main

import "core:math"
import rl "../gfx"
import rlgl "../gfx/rlgl"
import art "./art"

ANIM_PICKER_TEX_W :: 520
ANIM_PICKER_TEX_H :: 440
GIZMO_RING_SEGS :: 32

draw_anim_picker_frame :: proc() {
	ed := &app.anim_ed
	dt := f32(rl.GetFrameTime())
	ed.picker_yaw += dt * 0.55
	idx := clamp(ed.picker_idx, 0, len(art.ANIM_CATALOG) - 1)
	entry := art.ANIM_CATALOG[idx]
	enemy := entry.category == .Enemy
	hero := entry.category == .Hero
	dur := max(art.anim_clip_duration(entry.kind, enemy, hero), 0.1)
	ed.picker_phase = math_mod(ed.picker_phase + dt / dur, 1.0)
	render_anim_picker_turntable(entry)

	w := i32(rl.GetScreenWidth())
	h := i32(rl.GetScreenHeight())
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{12, 18, 13, 255})
	if app.pixel.id > 0 {
		draw_pixel_output()
	}
	rl.DrawRectangle(0, 0, w, h, rl.Color{8, 12, 9, 215})
	vui_render()
	rl.EndDrawing()
}

@(private)
render_anim_picker_turntable :: proc(entry: art.Anim_Catalog_Entry) {
	ed := &app.anim_ed
	if ed.picker_rect_tex.id == 0 {
		ed.picker_rect_tex = rl.LoadRenderTexture(ANIM_PICKER_TEX_W, ANIM_PICKER_TEX_H)
		rl.SetTextureFilter(ed.picker_rect_tex.texture, .BILINEAR)
	}
	if ed.picker_rect_tex.id == 0 {
		return
	}
	center, radius := picker_turntable_bounds(&ed.picker_preview)
	dist := max(radius * 3.1, 2.2)
	cam := rl.Camera3D{
		position   = center + rl.Vector3{math.sin(ed.picker_yaw) * dist, radius * 0.65 + 0.35, math.cos(ed.picker_yaw) * dist},
		target     = center,
		up         = {0, 1, 0},
		fovy       = 36.0,
		projection = .PERSPECTIVE,
	}
	set_unit_shader_uniforms_at(f32(rl.GetTime()), cam.position)
	pose := eval_picker_entry_pose(entry, ed.picker_phase)

	rl.BeginTextureMode(ed.picker_rect_tex)
	rl.ClearBackground(rl.Color{19, 27, 21, 255})
	rl.BeginMode3D(cam)
	draw_picker_pedestal()
	if ed.picker_preview.loaded {
		draw_unit_mesh(&ed.picker_preview, &pose, rl.Matrix(1))
	}
	rl.EndMode3D()
	rl.EndTextureMode()
}

@(private)
eval_picker_entry_pose :: proc(entry: art.Anim_Catalog_Entry, phase: f32) -> art.Pose {
	enemy := entry.category == .Enemy
	hero := entry.category == .Hero
	pose: art.Pose
	switch entry.kind {
	case .Idle:
		art.eval_unit_idle(phase, enemy, hero, &pose)
	case .Walk:
		art.eval_unit_walk(phase, enemy, hero, &pose)
	case .Attack:
		art.eval_unit_idle(0.25, enemy, hero, &pose)
		art.eval_unit_attack(phase, enemy, hero, &pose)
	}
	return pose
}

draw_anim_editor_frame :: proc() {
	ed := &app.anim_ed
	dt := f32(rl.GetFrameTime())
	if ed.playing && ed.clip_loaded && !ed.modal_active && !ed.scrubbing {
		dur := max(ed.clip.duration, 0.05)
		ed.playhead = math_mod(ed.playhead + dt * ed.play_speed / dur, 1.0)
	}
	if ed.status_timer > 0 {
		ed.status_timer = max(0, ed.status_timer - dt)
	}
	anim_editor_eval_preview_pose()
	set_unit_shader_uniforms_at(f32(rl.GetTime()), ed.camera.position)

	if ed.use_watercolor && app.pixel.id > 0 {
		rl.BeginTextureMode(app.pixel)
		rl.ClearBackground(rl.Color{22, 28, 24, 255})
		rl.BeginMode3D(ed.camera)
		draw_anim_scene_3d()
		rl.EndMode3D()
		rl.EndTextureMode()
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{22, 28, 24, 255})
	if ed.use_watercolor && app.pixel.id > 0 {
		draw_pixel_output()
		rl.BeginMode3D(ed.camera)
		anim_draw_overlays_3d()
		rl.EndMode3D()
	} else {
		rl.BeginMode3D(ed.camera)
		draw_anim_scene_3d()
		anim_draw_overlays_3d()
		rl.EndMode3D()
	}
	anim_draw_overlays_2d()
	vui_render()
	rl.EndDrawing()
}

@(private)
draw_anim_scene_3d :: proc() {
	ed := &app.anim_ed
	draw_editor_stage_3d()
	if ed.preview_model.loaded {
		draw_unit_mesh(&ed.preview_model, &ed.current_pose, rl.Matrix(1))
	}
	if ed.clip_loaded && ed.clip.additive && ed.show_slash && ed.playhead >= 0.28 && ed.playhead <= 0.68 && app.slash.ready {
		rlgl.DisableBackfaceCulling()
		rlgl.DisableDepthMask()
		rl.BeginBlendMode(.ALPHA)
		draw_unit_slash({0, 0, 0}, 0, (ed.playhead - 0.28) / 0.40)
		rl.EndBlendMode()
		rlgl.EnableDepthMask()
		rlgl.EnableBackfaceCulling()
	}
}

anim_bone_posed_head :: proc(mats: ^[art.BONE_COUNT]rl.Matrix, bone: art.Bone_Id) -> rl.Vector3 {
	return art.xf_point(mats[int(bone)], art.BONES[bone].head)
}

anim_bone_posed_tail :: proc(mats: ^[art.BONE_COUNT]rl.Matrix, bone: art.Bone_Id) -> rl.Vector3 {
	head := anim_bone_posed_head(mats, bone)
	#partial switch bone {
	case .Root:      return anim_bone_posed_head(mats, .Pelvis)
	case .Pelvis:    return anim_bone_posed_head(mats, .Spine)
	case .Spine:     return anim_bone_posed_head(mats, .Chest)
	case .Chest:     return anim_bone_posed_head(mats, .Neck)
	case .Neck:      return anim_bone_posed_head(mats, .Head)
	case .Head:      return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, 0.22, 0})
	case .Plume:     return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, 0.14, -0.14})
	case .Shoulder_L, .Arm_L, .Forearm_L:
		return anim_bone_posed_head(mats, art.Bone_Id(int(bone) + 1))
	case .Hand_L:    return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, -0.14, 0.08})
	case .Shoulder_R, .Arm_R, .Forearm_R:
		return anim_bone_posed_head(mats, art.Bone_Id(int(bone) + 1))
	case .Hand_R:    return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, -0.10, 0.18})
	case .Thigh_L, .Shin_L, .Thigh_R, .Shin_R:
		return anim_bone_posed_head(mats, art.Bone_Id(int(bone) + 1))
	case .Foot_L, .Foot_R:
		return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, -0.05, 0.16})
	case .Cape_1, .Cape_2:
		return anim_bone_posed_head(mats, art.Bone_Id(int(bone) + 1))
	case .Cape_3:    return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, -0.22, -0.03})
	case .Sash:      return art.xf_point(mats[int(bone)], art.BONES[bone].head + {0, -0.22, 0.04})
	}
	return head
}

@(private)
anim_draw_overlays_3d :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return
	}
	if ed.onion_skin && len(ed.clip.keyframes) > 1 {
		anim_draw_onion_skin_3d()
	}
	if ed.show_bones && ed.rig_mode != .Rig {
		anim_draw_skeleton_3d(&ed.pose_mats, false, {})
	}
	if ed.rig_mode != .Bones {
		anim_draw_rig_3d()
	}
	if anim_gizmo_uses_rig() {
		anim_draw_ctrl_gizmo_3d()
	} else {
		anim_draw_gizmo_3d()
	}
}

@(private)
anim_draw_onion_skin_3d :: proc() {
	ed := &app.anim_ed
	n := len(ed.clip.keyframes)
	cur := clamp(ed.selected_kf, 0, n - 1)
	prev_i := (cur - 1 + n) % n
	next_i := (cur + 1) % n
	if prev_i != cur {
		mats := keyframe_pose_mats(prev_i)
		anim_draw_skeleton_3d(&mats, true, rl.Color{108, 186, 255, 130})
	}
	if next_i != cur && next_i != prev_i {
		mats := keyframe_pose_mats(next_i)
		anim_draw_skeleton_3d(&mats, true, rl.Color{255, 184, 92, 130})
	}
}

@(private)
keyframe_pose_mats :: proc(kf_idx: int) -> [art.BONE_COUNT]rl.Matrix {
	ed := &app.anim_ed
	kf := &ed.clip.keyframes[kf_idx]
	pose: art.Pose
	if ed.clip.additive {
		art.eval_unit_idle(0.25, ed.preview_team == .Enemy, ed.preview_team == .Hero, &pose)
		for i in 0 ..< art.BONE_COUNT {
			pose.rot[i] += rl.Vector3(kf.rot[i])
		}
		pose.root_offset += rl.Vector3(kf.root_offset)
	} else {
		for i in 0 ..< art.BONE_COUNT {
			pose.rot[i] = rl.Vector3(kf.rot[i])
		}
		pose.root_offset = rl.Vector3(kf.root_offset)
	}
	return art.pose_matrices(&pose, rl.Matrix(1))
}

@(private)
anim_draw_skeleton_3d :: proc(mats: ^[art.BONE_COUNT]rl.Matrix, ghost: bool, ghost_col: rl.Color) {
	ed := &app.anim_ed
	if ed.xray_bones || ghost {
		rlgl.DisableDepthTest()
	}
	for i in 0 ..< art.BONE_COUNT {
		b := art.Bone_Id(i)
		head := anim_bone_posed_head(mats, b)
		if !art.BONES[b].root {
			parent_head := anim_bone_posed_head(mats, art.BONES[b].parent)
			col := ghost ? ghost_col : bone_line_color(ed, b)
			rl.DrawLine3D(parent_head, head, col)
		}
		if is_leaf_bone(b) {
			tail := anim_bone_posed_tail(mats, b)
			col := ghost ? ghost_col : bone_line_color(ed, b)
			rl.DrawLine3D(head, tail, col)
		}
		if !ghost {
			jcol := bone_joint_color(ed, b)
			sel := ed.selected_bones[i]
			rad: f32 = (b == ed.selected_bone || int(b) == ed.hover_bone) ? 0.032 : (sel ? 0.027 : 0.020)
			rl.DrawSphere(head, rad, jcol)
		}
	}
	rlgl.EnableDepthTest()
}

@(private)
is_leaf_bone :: proc(b: art.Bone_Id) -> bool {
	#partial switch b {
	case .Head, .Plume, .Hand_L, .Hand_R, .Foot_L, .Foot_R, .Cape_3, .Sash:
		return true
	}
	return false
}

@(private)
bone_line_color :: proc(ed: ^Anim_Editor_State, b: art.Bone_Id) -> rl.Color {
	if b == ed.selected_bone {
		return rl.Color{248, 206, 86, 255}
	}
	if ed.selected_bones[int(b)] {
		return rl.Color{235, 178, 62, 240}
	}
	if int(b) == ed.hover_bone {
		return rl.Color{110, 232, 255, 255}
	}
	return rl.Color{178, 166, 134, 210}
}

@(private)
bone_joint_color :: proc(ed: ^Anim_Editor_State, b: art.Bone_Id) -> rl.Color {
	if b == ed.selected_bone {
		return rl.Color{255, 218, 96, 255}
	}
	if ed.selected_bones[int(b)] {
		return rl.Color{240, 186, 68, 245}
	}
	if int(b) == ed.hover_bone {
		return rl.Color{110, 232, 255, 255}
	}
	if ed.clip_loaded && len(ed.clip.keyframes) > 0 {
		kf := &ed.clip.keyframes[clamp(ed.selected_kf, 0, len(ed.clip.keyframes) - 1)]
		r := kf.rot[int(b)]
		if abs(r[0]) + abs(r[1]) + abs(r[2]) > 0.001 {
			return rl.Color{205, 168, 92, 255}
		}
	}
	return rl.Color{150, 165, 155, 210}
}

@(private)
anim_draw_gizmo_3d :: proc() {
	ed := &app.anim_ed
	pivot := anim_bone_posed_head(&ed.pose_mats, ed.selected_bone)
	rlgl.DisableDepthTest()
	defer rlgl.EnableDepthTest()
	if ed.tool == .Move_Root {
		root_p := anim_bone_posed_head(&ed.pose_mats, .Root)
		wlen := anim_world_per_px() * 72.0
		for axis in 0 ..< 3 {
			col := gizmo_axis_color(ed, axis)
			tip := root_p + GIZMO_AXES[axis] * wlen
			rl.DrawLine3D(root_p, tip, col)
			rl.DrawCylinderEx(root_p + GIZMO_AXES[axis] * (wlen * 0.80), tip, wlen * 0.08, 0, 8, col)
		}
		return
	}
	radius := anim_world_per_px() * 54.0
	for axis in 0 ..< 3 {
		col := gizmo_axis_color(ed, axis)
		draw_gizmo_ring(pivot, axis, radius, col)
		if ed.gizmo_hover == axis || ed.gizmo_drag_axis == axis {
			draw_gizmo_ring(pivot, axis, radius * 0.96, col)
			draw_gizmo_ring(pivot, axis, radius * 1.04, col)
		}
	}
}

@(private)
gizmo_axis_color :: proc(ed: ^Anim_Editor_State, axis: int) -> rl.Color {
	if ed.gizmo_hover == axis || ed.gizmo_drag_axis == axis {
		return rl.Color{255, 235, 125, 255}
	}
	return GIZMO_COLORS[axis]
}

@(private)
draw_gizmo_ring :: proc(center: rl.Vector3, axis: int, radius: f32, col: rl.Color) {
	for s in 0 ..< GIZMO_RING_SEGS {
		a0 := f32(s) * math.TAU / f32(GIZMO_RING_SEGS)
		a1 := f32(s + 1) * math.TAU / f32(GIZMO_RING_SEGS)
		p0 := center + gizmo_ring_dir(axis, a0) * radius
		p1 := center + gizmo_ring_dir(axis, a1) * radius
		rl.DrawLine3D(p0, p1, col)
	}
}

gizmo_ring_dir :: proc(axis: int, ang: f32) -> rl.Vector3 {
	c := math.cos(ang)
	s := math.sin(ang)
	switch axis {
	case 0: return {0, c, s}
	case 1: return {c, 0, s}
	case 2: return {c, s, 0}
	}
	return {c, s, 0}
}

@(private)
anim_draw_overlays_2d :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return
	}
	vp := anim_editor_viewport_rect()
	rl.BeginScissorMode(i32(vp.x), i32(vp.y), i32(vp.width), i32(vp.height))
	defer rl.EndScissorMode()

	if anim_is_rig_active() {
		anim_draw_ctrl_overlays_2d(vp)
	}
	if ed.rig_mode != .Rig && ed.show_bones {
		for i in 0 ..< art.BONE_COUNT {
			b := art.Bone_Id(i)
			if !ed.selected_bones[i] && i != ed.hover_bone { continue }
			sp := rl.GetWorldToScreen(anim_bone_posed_head(&ed.pose_mats, b), ed.camera)
			if rl.CheckCollisionPointRec(sp, vp) {
				col := i == ed.hover_bone ? rl.Color{110, 232, 255, 220} : (b == ed.selected_bone ? rl.Color{255, 218, 96, 220} : rl.Color{235, 178, 62, 185})
				rl.DrawCircleLines(i32(sp.x), i32(sp.y), b == ed.selected_bone ? 7 : 5, col)
			}
		}
	}
	anim_draw_vp_box_2d()
}
