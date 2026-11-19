// Blender basic topology operators: Extrude (E), Inset (I), and Fill (F).
package art_edit

import "core:math"
import "core:slice"
import spec "../spec"

edit_extrude :: proc(m: ^Edit_Mesh) -> (avg_nrm: [3]f32, ok: bool) {
	switch m.mode {
	case .Face:
		return extrude_faces(m)
	case .Edge:
		return extrude_edges(m)
	case .Vertex:
		return extrude_verts(m)
	}
	return {}, false
}

@(private)
extrude_faces :: proc(m: ^Edit_Mesh) -> ([3]f32, bool) {
	sel_faces := make([dynamic]int, 0, 16, context.temp_allocator)
	for &f, fi in m.faces {
		if f.selected {
			append(&sel_faces, fi)
		}
	}
	if len(sel_faces) == 0 {
		return {}, false
	}
	dup_map := make(map[u32]u32, len(sel_faces) * 4, context.temp_allocator)
	edge_count := make(map[u64]int, len(sel_faces) * 4, context.temp_allocator)
	nrm_sum: [3]f32
	for fi in sel_faces {
		f := &m.faces[fi]
		nrm_sum = v3_add(nrm_sum, f.nrm)
		c := int(f.count)
		for k in 0..<c {
			va := f.v[k]
			vb := f.v[(k + 1) % c]
			edge_count[edge_key(va, vb)] += 1
			if !(va in dup_map) {
				v := m.verts[va]
				v.selected = true
				dup_map[va] = u32(len(m.verts))
				append(&m.verts, v)
			}
		}
	}
	append_extrude_walls(m, sel_faces[:], &dup_map, &edge_count)
	for fi in sel_faces {
		f := &m.faces[fi]
		for k in 0..<int(f.count) {
			f.v[k] = dup_map[f.v[k]]
		}
	}
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return v3_norm(nrm_sum), true
}

@(private)
append_extrude_walls :: proc(
	m: ^Edit_Mesh,
	sel_faces: []int,
	dup_map: ^map[u32]u32,
	edge_count: ^map[u64]int,
) {
	for fi in sel_faces {
		f := m.faces[fi]
		c := int(f.count)
		for k in 0..<c {
			u := f.v[k]
			v := f.v[(k + 1) % c]
			if edge_count[edge_key(u, v)] != 1 {
				continue
			}
			append(&m.faces, Edit_Face{
				v        = {u, v, dup_map[v], dup_map[u]},
				count    = 4,
				mat      = f.mat,
				smooth   = false,
				group    = f.group,
				selected = false,
			})
		}
	}
}

@(private)
extrude_edges :: proc(m: ^Edit_Mesh) -> ([3]f32, bool) {
	sel_edges := make([dynamic]int, 0, 16, context.temp_allocator)
	for &e, ei in m.edges {
		if e.selected { append(&sel_edges, ei) }
	}
	if len(sel_edges) == 0 {
		return {}, false
	}
	dup_map := make(map[u32]u32, len(sel_edges) * 2, context.temp_allocator)
	nrm_sum: [3]f32
	for ei in sel_edges {
		e := m.edges[ei]
		for idx in ([2]u32{e.a, e.b}) {
			if !(idx in dup_map) {
				v := m.verts[idx]
				v.selected = true
				dup_map[idx] = u32(len(m.verts))
				append(&m.verts, v)
			}
		}
		ua, ub := oriented_edge_verts(m, &e)
		append(&m.faces, Edit_Face{
			v      = {ua, ub, dup_map[ub], dup_map[ua]},
			count  = 4,
			mat    = dominant_edge_mat(m, &e),
			smooth = false,
			group  = m.verts[ua].group,
		})
		if e.face_len > 0 {
			nrm_sum = v3_add(nrm_sum, m.faces[e.faces[0]].nrm)
		}
	}
	for &e in m.edges { e.selected = false }
	edit_mesh_rebuild_topology(m)
	select_dup_edges(m, &dup_map)
	m.dirty = true
	return v3_len_sq(nrm_sum) > 1e-6 ? v3_norm(nrm_sum) : [3]f32{0, 1, 0}, true
}

@(private)
select_dup_edges :: proc(m: ^Edit_Mesh, dup_map: ^map[u32]u32) {
	is_dup := make(map[u32]bool, len(dup_map^), context.temp_allocator)
	for _, nv in dup_map^ {
		is_dup[nv] = true
	}
	for &e in m.edges {
		e.selected = is_dup[e.a] && is_dup[e.b]
	}
}

@(private)
oriented_edge_verts :: proc(m: ^Edit_Mesh, e: ^Edit_Edge) -> (u32, u32) {
	if e.face_len > 0 {
		f := &m.faces[e.faces[0]]
		c := int(f.count)
		for k in 0..<c {
			u := f.v[k]
			v := f.v[(k + 1) % c]
			if (u == e.a && v == e.b) || (u == e.b && v == e.a) {
				return v, u
			}
		}
	}
	return e.a, e.b
}

@(private)
dominant_edge_mat :: proc(m: ^Edit_Mesh, e: ^Edit_Edge) -> spec.Mat_Kind {
	if e.face_len > 0 {
		return m.faces[e.faces[0]].mat
	}
	return .Steel
}

@(private)
extrude_verts :: proc(m: ^Edit_Mesh) -> ([3]f32, bool) {
	old_n := len(m.verts)
	moved := false
	for i in 0..<old_n {
		if !m.verts[i].selected {
			continue
		}
		m.verts[i].selected = false
		nv := m.verts[i]
		nv.selected = true
		new_idx := u32(len(m.verts))
		append(&m.verts, nv)
		append(&m.loose_edges, Loose_Edge{a = u32(i), b = new_idx})
		moved = true
	}
	if !moved {
		return {}, false
	}
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return {0, 1, 0}, true
}

edit_inset :: proc(m: ^Edit_Mesh, factor: f32) -> bool {
	t := clamp(factor, 0.02, 0.90)
	orig_len := len(m.faces)
	changed := false
	for fi in 0..<orig_len {
		f := m.faces[fi]
		if !f.selected || f.count < 3 {
			continue
		}
		c := int(f.count)
		center := edit_mesh_face_center(m, fi)
		inner: [4]u32
		for k in 0..<c {
			src := m.verts[f.v[k]]
			nv := src
			nv.pos = v3_lerp(src.pos, center, t)
			nv.selected = true
			inner[k] = u32(len(m.verts))
			append(&m.verts, nv)
		}
		for k in 0..<c {
			nxt := (k + 1) % c
			append(&m.faces, Edit_Face{
				v      = {f.v[k], f.v[nxt], inner[nxt], inner[k]},
				count  = 4,
				mat    = f.mat,
				smooth = f.smooth,
				group  = f.group,
			})
		}
		m.faces[fi].v = inner
		changed = true
	}
	if !changed {
		return false
	}
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return true
}

edit_fill :: proc(m: ^Edit_Mesh, view_dir: [3]f32 = {0, 0, 1}) -> bool {
	mask := edit_mesh_selected_verts_mask(m)
	sel := make([dynamic]u32, 0, 8, context.temp_allocator)
	for s, i in mask {
		if s { append(&sel, u32(i)) }
	}
	if len(sel) == 2 {
		return fill_two_verts(m, sel[0], sel[1])
	}
	if len(sel) == 3 || len(sel) == 4 {
		return fill_poly_verts(m, sel[:], view_dir)
	}
	return false
}

@(private)
fill_two_verts :: proc(m: ^Edit_Mesh, a, b: u32) -> bool {
	for &f, fi in m.faces {
		if f.count != 4 {
			continue
		}
		ia, ib := -1, -1
		for k in 0..<4 {
			if f.v[k] == a { ia = k }
			if f.v[k] == b { ib = k }
		}
		if ia >= 0 && ib >= 0 && ((ia + 2) % 4) == ib {
			split_quad_diagonal(m, fi, ia)
			return true
		}
	}
	if _, exists := edit_mesh_find_edge(m, a, b); exists {
		return false
	}
	append(&m.loose_edges, Loose_Edge{a = a, b = b, selected = true})
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return true
}

@(private)
split_quad_diagonal :: proc(m: ^Edit_Mesh, face_idx, corner: int) {
	f := m.faces[face_idx]
	v0 := f.v[corner]
	v1 := f.v[(corner + 1) % 4]
	v2 := f.v[(corner + 2) % 4]
	v3 := f.v[(corner + 3) % 4]
	m.faces[face_idx].v = {v0, v1, v2, 0}
	m.faces[face_idx].count = 3
	append(&m.faces, Edit_Face{
		v        = {v0, v2, v3, 0},
		count    = 3,
		mat      = f.mat,
		smooth   = f.smooth,
		group    = f.group,
		selected = f.selected,
	})
	edit_mesh_rebuild_topology(m)
	m.dirty = true
}

@(private)
fill_poly_verts :: proc(m: ^Edit_Mesh, verts_in: []u32, view_dir: [3]f32) -> bool {
	center: [3]f32
	nrm_sum: [3]f32
	for vi in verts_in {
		center = v3_add(center, m.verts[vi].pos)
		nrm_sum = v3_add(nrm_sum, m.verts[vi].nrm)
	}
	center = v3_scale(center, 1.0 / f32(len(verts_in)))
	plane_n := v3_len_sq(nrm_sum) > 1e-6 ? v3_norm(nrm_sum) : v3_norm(view_dir)
	if v3_dot(plane_n, view_dir) < 0 {
		plane_n = v3_scale(plane_n, -1)
	}
	up_ref := abs(plane_n[1]) > 0.9 ? [3]f32{1, 0, 0} : [3]f32{0, 1, 0}
	tx := v3_norm(v3_cross(up_ref, plane_n))
	ty := v3_cross(plane_n, tx)

	Angle_Item :: struct { idx: u32, ang: f32 }
	items: [4]Angle_Item
	for vi, k in verts_in {
		d := v3_sub(m.verts[vi].pos, center)
		items[k] = {vi, math.atan2(v3_dot(d, ty), v3_dot(d, tx))}
	}
	slice.sort_by(items[:len(verts_in)], proc(i, j: Angle_Item) -> bool {
		return i.ang < j.ang
	})
	face := Edit_Face{
		count    = u8(len(verts_in)),
		mat      = .Steel,
		smooth   = false,
		group    = m.verts[items[0].idx].group,
		selected = true,
	}
	for k in 0..<len(verts_in) {
		face.v[k] = items[k].idx
	}
	append(&m.faces, face)
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return true
}
