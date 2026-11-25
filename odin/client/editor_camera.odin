// Model Editor orbital camera, preset views (Numpad 1/3/7/5), and 3D ray picking.
package main

import "core:math"
import rl "../gfx"
import edit "./art/edit"

editor_mesh_bounds :: proc() -> (center: [3]f32, radius: f32) {
	ed := &app.editor
	if !ed.mesh_loaded || len(ed.mesh.verts) == 0 {
		return {0, 0.9, 0}, 1.2
	}
	lo := [3]f32{1e9, 1e9, 1e9}
	hi := [3]f32{-1e9, -1e9, -1e9}
	for v in ed.mesh.verts {
		lo = {min(lo[0], v.pos[0]), min(lo[1], v.pos[1]), min(lo[2], v.pos[2])}
		hi = {max(hi[0], v.pos[0]), max(hi[1], v.pos[1]), max(hi[2], v.pos[2])}
	}
	center = {0.5 * (lo[0] + hi[0]), 0.5 * (lo[1] + hi[1]), 0.5 * (lo[2] + hi[2])}
	dx := hi[0] - lo[0]
	dy := hi[1] - lo[1]
	dz := hi[2] - lo[2]
	radius = max(0.35, 0.5 * math.sqrt(dx * dx + dy * dy + dz * dz))
	return
}

editor_reset_camera :: proc(preset: Editor_View_Preset) {
	ed := &app.editor
	center, radius := editor_mesh_bounds()
	ed.cam_target = center
	ed.cam_dist = max(radius * 4.2, 4.0)
	ed.cam_fovy = clamp(radius * 2.55, 0.65, 6.5)
	switch preset {
	case .Iso:
		ed.cam_yaw = math.PI * 0.25
		ed.cam_pitch = 0.42
	case .Front:
		ed.cam_yaw = 0.0
		ed.cam_pitch = 0.02
	case .Right:
		ed.cam_yaw = math.PI * 0.5
		ed.cam_pitch = 0.02
	case .Top:
		ed.cam_yaw = 0.0
		ed.cam_pitch = 1.48
	}
	editor_apply_camera()
}

editor_frame_selection :: proc() {
	ed := &app.editor
	if !ed.mesh_loaded { return }
	if c, ok := edit.edit_selection_center(&ed.mesh); ok {
		ed.cam_target = c
	} else {
		center, radius := editor_mesh_bounds()
		ed.cam_target = center
		ed.cam_fovy = clamp(radius * 2.55, 0.65, 6.5)
	}
	editor_apply_camera()
}

editor_apply_camera :: proc() {
	ed := &app.editor
	cp := math.cos(ed.cam_pitch)
	sp := math.sin(ed.cam_pitch)
	cy := math.cos(ed.cam_yaw)
	sy := math.sin(ed.cam_yaw)
	dir := rl.Vector3{cp * sy, sp, cp * cy}
	tgt := rl.Vector3(ed.cam_target)
	ed.camera = rl.Camera3D{
		position   = tgt + dir * ed.cam_dist,
		target     = tgt,
		up         = rl.Vector3{0, 1, 0},
		fovy       = ed.cam_ortho ? clamp(ed.cam_fovy, 0.25, 16.0) : 38.0,
		projection = ed.cam_ortho ? .ORTHOGRAPHIC : .PERSPECTIVE,
	}
	if !ed.cam_ortho {
		ed.cam_dist = clamp(ed.cam_fovy * 1.85, 0.8, 30.0)
		ed.camera.position = tgt + dir * ed.cam_dist
	}
}

editor_update_camera_input :: proc(mouse: rl.Vector2, in_viewport: bool) {
	ed := &app.editor
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	mmb_down := input_middle_down()
	alt_lmb := alt && input_left_down()
	rmb_orbit := rl.IsMouseButtonDown(.RIGHT) && !ed.modal_active && !ed.delete_menu_open

	if !ed.cam_orbit_drag && !ed.cam_pan_drag {
		if in_viewport && (mmb_down || alt_lmb || (rmb_orbit && rl.Vector2Distance(mouse, ed.rmb_down_pos) > 5)) {
			if shift && (mmb_down || alt_lmb) {
				ed.cam_pan_drag = true
			} else if mmb_down || alt_lmb || rmb_orbit {
				ed.cam_orbit_drag = true
				if rmb_orbit { ed.rmb_moved = true }
			}
			ed.cam_last_mouse = mouse
		}
	}

	if ed.cam_orbit_drag || ed.cam_pan_drag {
		still := mmb_down || alt_lmb || rl.IsMouseButtonDown(.RIGHT)
		if !still {
			ed.cam_orbit_drag = false
			ed.cam_pan_drag = false
		} else {
			delta := mouse - ed.cam_last_mouse
			ed.cam_last_mouse = mouse
			if ed.cam_pan_drag {
				pan_editor_camera(delta)
			} else {
				ed.cam_yaw -= delta.x * 0.0085
				ed.cam_pitch = clamp(ed.cam_pitch + delta.y * 0.0085, -1.48, 1.48)
			}
		}
	}

	if in_viewport && !ed.modal_active {
		if wheel := input_wheel_y(); wheel != 0 {
			ed.cam_fovy = clamp(ed.cam_fovy * math.pow(f32(0.88), wheel), 0.28, 14.0)
		}
	}
	editor_apply_camera()
}

@(private)
pan_editor_camera :: proc(delta_px: rl.Vector2) {
	ed := &app.editor
	h := max(f32(rl.GetScreenHeight()), f32(1))
	scale := ed.cam_fovy / h
	fwd := rl.Vector3Normalize(ed.camera.target - ed.camera.position)
	right := rl.Vector3Normalize(rl.Vector3CrossProduct(fwd, {0, 1, 0}))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, fwd))
	shift := -right * (delta_px.x * scale) + cam_up * (delta_px.y * scale)
	ed.cam_target = {ed.cam_target[0] + shift.x, ed.cam_target[1] + shift.y, ed.cam_target[2] + shift.z}
}

editor_world_per_px :: proc() -> f32 {
	ed := &app.editor
	h := max(f32(rl.GetScreenHeight()), f32(1))
	if ed.cam_ortho {
		return ed.cam_fovy / h
	}
	return 2.0 * ed.cam_dist * math.tan(ed.camera.fovy * 0.5 * math.PI / 180.0) / h
}

editor_ray_mesh_hit :: proc(ray: rl.Ray) -> (face_idx: int, dist: f32, point: rl.Vector3, ok: bool) {
	ed := &app.editor
	best_d := f32(1e9)
	best_f := -1
	best_p: rl.Vector3
	for &f, fi in ed.mesh.faces {
		c := int(f.count)
		if c < 3 { continue }
		p0 := editor_posed_vert_pos(int(f.v[0]))
		p1 := editor_posed_vert_pos(int(f.v[1]))
		p2 := editor_posed_vert_pos(int(f.v[2]))
		hit := rl.GetRayCollisionTriangle(ray, p0, p1, p2)
		if hit.hit && hit.distance > 0.001 && hit.distance < best_d {
			best_d, best_f, best_p = hit.distance, fi, hit.point
		}
		if c == 4 {
			p3 := editor_posed_vert_pos(int(f.v[3]))
			hit2 := rl.GetRayCollisionTriangle(ray, p0, p2, p3)
			if hit2.hit && hit2.distance > 0.001 && hit2.distance < best_d {
				best_d, best_f, best_p = hit2.distance, fi, hit2.point
			}
		}
	}
	return best_f, best_d, best_p, best_f >= 0
}

@(private)
point_occluded :: proc(sp: rl.Vector2, p: rl.Vector3) -> bool {
	if app.editor.xray_mode {
		return false
	}
	ray := rl.GetScreenToWorldRay(sp, app.editor.camera)
	_, hit_d, _, hit_ok := editor_ray_mesh_hit(ray)
	if !hit_ok {
		return false
	}
	cam_depth := rl.Vector3DotProduct(p - ray.position, rl.Vector3Normalize(ray.direction))
	return hit_d < cam_depth - 0.045
}

editor_pick_vert :: proc(mouse: rl.Vector2, max_px: f32 = 13.0) -> (int, bool) {
	ed := &app.editor
	best := -1
	best_score := max_px * max_px
	for _, vi in ed.mesh.verts {
		p := editor_posed_vert_pos(vi)
		sp := rl.GetWorldToScreen(p, ed.camera)
		dx := sp.x - mouse.x
		dy := sp.y - mouse.y
		d2 := dx * dx + dy * dy
		if d2 <= best_score && !point_occluded(sp, p) {
			best_score = d2
			best = vi
		}
	}
	return best, best >= 0
}

@(private)
seg_dist_sq_2d :: proc(pt, a, b: rl.Vector2) -> (f32, f32) {
	ab := b - a
	len2 := ab.x * ab.x + ab.y * ab.y
	if len2 < 1e-6 {
		d := pt - a
		return d.x * d.x + d.y * d.y, 0.0
	}
	t := clamp(((pt.x - a.x) * ab.x + (pt.y - a.y) * ab.y) / len2, 0.0, 1.0)
	proj := a + ab * t
	d := pt - proj
	return d.x * d.x + d.y * d.y, t
}

editor_pick_edge :: proc(mouse: rl.Vector2, max_px: f32 = 10.0) -> (int, f32, bool) {
	ed := &app.editor
	best := -1
	best_d2 := max_px * max_px
	best_t := f32(0.5)
	for &e, ei in ed.mesh.edges {
		pa := editor_posed_vert_pos(int(e.a))
		pb := editor_posed_vert_pos(int(e.b))
		sa := rl.GetWorldToScreen(pa, ed.camera)
		sb := rl.GetWorldToScreen(pb, ed.camera)
		d2, t := seg_dist_sq_2d(mouse, sa, sb)
		if d2 <= best_d2 {
			pm := pa + (pb - pa) * t
			sm := rl.GetWorldToScreen(pm, ed.camera)
			if !point_occluded(sm, pm) {
				best_d2, best, best_t = d2, ei, t
			}
		}
	}
	return best, best_t, best >= 0
}

editor_pick_face :: proc(mouse: rl.Vector2) -> (int, bool) {
	ray := rl.GetScreenToWorldRay(mouse, app.editor.camera)
	fi, _, _, ok := editor_ray_mesh_hit(ray)
	return fi, ok
}

editor_pick_knife_node :: proc(mouse: rl.Vector2) -> (edit.Knife_Node, bool) {
	if vi, ok := editor_pick_vert(mouse, 13.0); ok {
		p := editor_posed_vert_pos(vi)
		return edit.Knife_Node{kind = .Vert, index = u32(vi), pos = {p.x, p.y, p.z}}, true
	}
	if ei, t, ok := editor_pick_edge(mouse, 10.0); ok {
		e := app.editor.mesh.edges[ei]
		pa := editor_posed_vert_pos(int(e.a))
		pb := editor_posed_vert_pos(int(e.b))
		pm := pa + (pb - pa) * t
		return edit.Knife_Node{kind = .Edge, index = u32(ei), t = t, pos = {pm.x, pm.y, pm.z}}, true
	}
	ray := rl.GetScreenToWorldRay(mouse, app.editor.camera)
	if fi, _, pt, ok := editor_ray_mesh_hit(ray); ok {
		return edit.Knife_Node{kind = .Face, index = u32(fi), pos = {pt.x, pt.y, pt.z}}, true
	}
	return {}, false
}
