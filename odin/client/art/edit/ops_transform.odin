// Transform operators (Grab/Rotate/Scale + axis locks + X-mirror) and attribute painting.
package art_edit

import "core:math"
import spec "../spec"

edit_apply_axis_lock :: proc(delta: [3]f32, lock: Axis_Lock) -> [3]f32 {
	switch lock {
	case .None: return delta
	case .X:    return {delta[0], 0, 0}
	case .Y:    return {0, delta[1], 0}
	case .Z:    return {0, 0, delta[2]}
	case .YZ:   return {0, delta[1], delta[2]}
	case .XZ:   return {delta[0], 0, delta[2]}
	case .XY:   return {delta[0], delta[1], 0}
	}
	return delta
}

edit_selection_center :: proc(m: ^Edit_Mesh) -> ([3]f32, bool) {
	mask := edit_mesh_selected_verts_mask(m)
	sum: [3]f32
	count := 0
	for sel, i in mask {
		if sel {
			sum = v3_add(sum, m.verts[i].pos)
			count += 1
		}
	}
	if count == 0 {
		return {}, false
	}
	return v3_scale(sum, 1.0 / f32(count)), true
}

edit_snapshot_positions :: proc(m: ^Edit_Mesh, allocator := context.allocator) -> [][3]f32 {
	out := make([][3]f32, len(m.verts), allocator)
	for &v, i in m.verts {
		out[i] = v.pos
	}
	return out
}

mirror_partner_index :: proc(base_pos: [][3]f32, idx: int, tol: f32 = 0.008) -> (int, bool) {
	if idx < 0 || idx >= len(base_pos) {
		return -1, false
	}
	p := base_pos[idx]
	if abs(p[0]) <= 0.004 {
		return -1, false
	}
	target := [3]f32{-p[0], p[1], p[2]}
	best := -1
	best_d2 := tol * tol
	for cand, i in base_pos {
		if i == idx {
			continue
		}
		d2 := v3_len_sq(v3_sub(cand, target))
		if d2 <= best_d2 {
			best_d2 = d2
			best = i
		}
	}
	return best, best >= 0
}

edit_translate_from_base :: proc(
	m: ^Edit_Mesh,
	base_pos: [][3]f32,
	delta: [3]f32,
	lock: Axis_Lock,
	mirror_x: bool,
) {
	d := edit_apply_axis_lock(delta, lock)
	mask := edit_mesh_selected_verts_mask(m)
	n := min(len(m.verts), len(base_pos))
	for i in 0..<n {
		m.verts[i].pos = base_pos[i]
	}
	for i in 0..<n {
		if !mask[i] {
			continue
		}
		if mirror_x && abs(base_pos[i][0]) <= 0.004 {
			m.verts[i].pos = v3_add(base_pos[i], {0, d[1], d[2]})
		} else {
			m.verts[i].pos = v3_add(base_pos[i], d)
		}
		if mirror_x {
			if p_idx, ok := mirror_partner_index(base_pos[:n], i); ok && !mask[p_idx] {
				m.verts[p_idx].pos = v3_add(base_pos[p_idx], {-d[0], d[1], d[2]})
			}
		}
	}
	m.dirty = true
	edit_mesh_update_normals(m)
}

@(private)
rodrigues_rotate :: proc(p, pivot, axis: [3]f32, angle_rad: f32) -> [3]f32 {
	k := v3_norm(axis)
	v := v3_sub(p, pivot)
	c := math.cos(angle_rad)
	s := math.sin(angle_rad)
	dot := v3_dot(k, v)
	term := v3_add(v3_scale(v, c), v3_scale(v3_cross(k, v), s))
	rotated := v3_add(term, v3_scale(k, dot * (1.0 - c)))
	return v3_add(pivot, rotated)
}

edit_rotate_from_base :: proc(
	m: ^Edit_Mesh,
	base_pos: [][3]f32,
	pivot, axis: [3]f32,
	angle_rad: f32,
	mirror_x: bool,
) {
	mask := edit_mesh_selected_verts_mask(m)
	n := min(len(m.verts), len(base_pos))
	for i in 0..<n {
		m.verts[i].pos = base_pos[i]
	}
	m_pivot := [3]f32{-pivot[0], pivot[1], pivot[2]}
	m_axis := [3]f32{-axis[0], axis[1], axis[2]}
	for i in 0..<n {
		if !mask[i] {
			continue
		}
		m.verts[i].pos = rodrigues_rotate(base_pos[i], pivot, axis, angle_rad)
		if mirror_x {
			if p_idx, ok := mirror_partner_index(base_pos[:n], i); ok && !mask[p_idx] {
				m.verts[p_idx].pos = rodrigues_rotate(base_pos[p_idx], m_pivot, m_axis, -angle_rad)
			}
		}
	}
	m.dirty = true
	edit_mesh_update_normals(m)
}

@(private)
scale_point :: proc(p, pivot: [3]f32, factor: f32, lock: Axis_Lock) -> [3]f32 {
	sv := edit_apply_axis_lock({factor - 1, factor - 1, factor - 1}, lock)
	d := v3_sub(p, pivot)
	return v3_add(pivot, {d[0] * (1 + sv[0]), d[1] * (1 + sv[1]), d[2] * (1 + sv[2])})
}

edit_scale_from_base :: proc(
	m: ^Edit_Mesh,
	base_pos: [][3]f32,
	pivot: [3]f32,
	factor: f32,
	lock: Axis_Lock,
	mirror_x: bool,
) {
	mask := edit_mesh_selected_verts_mask(m)
	n := min(len(m.verts), len(base_pos))
	for i in 0..<n {
		m.verts[i].pos = base_pos[i]
	}
	m_pivot := [3]f32{-pivot[0], pivot[1], pivot[2]}
	for i in 0..<n {
		if !mask[i] {
			continue
		}
		m.verts[i].pos = scale_point(base_pos[i], pivot, factor, lock)
		if mirror_x {
			if p_idx, ok := mirror_partner_index(base_pos[:n], i); ok && !mask[p_idx] {
				m.verts[p_idx].pos = scale_point(base_pos[p_idx], m_pivot, factor, lock)
			}
		}
	}
	m.dirty = true
	edit_mesh_update_normals(m)
}

edit_snap_to_ground :: proc(m: ^Edit_Mesh) -> bool {
	if len(m.verts) == 0 {
		return false
	}
	mask := edit_mesh_selected_verts_mask(m)
	any_sel := false
	for s in mask {
		if s { any_sel = true; break }
	}
	min_y := f32(1e9)
	for &v, i in m.verts {
		if !any_sel || mask[i] {
			min_y = min(min_y, v.pos[1])
		}
	}
	if abs(min_y) < 1e-6 {
		return false
	}
	for &v, i in m.verts {
		if !any_sel || mask[i] {
			v.pos[1] -= min_y
		}
	}
	m.dirty = true
	edit_mesh_update_normals(m)
	return true
}

edit_set_selected_mat :: proc(m: ^Edit_Mesh, mat: spec.Mat_Kind) -> bool {
	changed := false
	if m.mode == .Face {
		for &f in m.faces {
			if f.selected {
				f.mat = mat
				changed = true
			}
		}
		if changed { m.dirty = true }
		return changed
	}
	mask := edit_mesh_selected_verts_mask(m)
	for &f in m.faces {
		all_in := true
		for k in 0..<int(f.count) {
			if !mask[f.v[k]] { all_in = false; break }
		}
		if all_in {
			f.mat = mat
			changed = true
		}
	}
	if changed { m.dirty = true }
	return changed
}

edit_set_selected_bone :: proc(m: ^Edit_Mesh, bone: spec.Bone_Id) -> bool {
	mask := edit_mesh_selected_verts_mask(m)
	changed := false
	for sel, i in mask {
		if sel {
			m.verts[i].bone = bone
			changed = true
		}
	}
	if changed { m.dirty = true }
	return changed
}

edit_set_selected_smooth :: proc(m: ^Edit_Mesh, smooth: bool) -> bool {
	changed := false
	if m.mode == .Face {
		for &f in m.faces {
			if f.selected { f.smooth = smooth; changed = true }
		}
		if changed { m.dirty = true }
		return changed
	}
	mask := edit_mesh_selected_verts_mask(m)
	for &f in m.faces {
		for k in 0..<int(f.count) {
			if mask[f.v[k]] {
				f.smooth = smooth
				changed = true
				break
			}
		}
	}
	if changed { m.dirty = true }
	return changed
}
