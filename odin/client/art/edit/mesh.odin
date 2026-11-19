// Editable mesh lifecycle, asset loading, topology rebuilding, and normal evaluation.
package art_edit

import "core:strings"
import spec "../spec"

edit_mesh_init :: proc(
	id, title: string,
	category: spec.Model_Category,
	skinned: bool,
	ao_height, default_scale: f32,
	glow_override: f32 = 0,
) -> Edit_Mesh {
	return Edit_Mesh{
		id            = strings.clone(id),
		title         = strings.clone(title),
		category      = category,
		skinned       = skinned,
		ao_height     = ao_height,
		default_scale = default_scale,
		glow_override = glow_override,
		mode          = .Vertex,
	}
}

edit_mesh_delete :: proc(m: ^Edit_Mesh) {
	delete(m.id)
	delete(m.title)
	delete(m.verts)
	delete(m.faces)
	delete(m.edges)
	delete(m.loose_edges)
	m^ = {}
}

edit_mesh_clone :: proc(src: ^Edit_Mesh) -> Edit_Mesh {
	dst := edit_mesh_init(
		src.id,
		src.title,
		src.category,
		src.skinned,
		src.ao_height,
		src.default_scale,
		src.glow_override,
	)
	dst.mode = src.mode
	dst.dirty = src.dirty
	resize(&dst.verts, len(src.verts))
	copy(dst.verts[:], src.verts[:])
	resize(&dst.faces, len(src.faces))
	copy(dst.faces[:], src.faces[:])
	resize(&dst.edges, len(src.edges))
	copy(dst.edges[:], src.edges[:])
	resize(&dst.loose_edges, len(src.loose_edges))
	copy(dst.loose_edges[:], src.loose_edges[:])
	return dst
}

edit_mesh_from_asset_def :: proc(def: spec.Model_Asset_Def) -> Edit_Mesh {
	m := edit_mesh_init(
		def.id,
		def.title,
		def.category,
		def.skinned,
		def.ao_height,
		def.default_scale,
		def.glow_override,
	)
	for chunk in def.vert_chunks {
		for v in chunk {
			append(&m.verts, Edit_Vert{
				pos   = v.pos,
				nrm   = {0, 1, 0},
				bone  = v.bone,
				ao    = v.ao,
				group = v.group,
			})
		}
	}
	for chunk in def.face_chunks {
		for f in chunk {
			append(&m.faces, Edit_Face{
				v      = f.v,
				count  = f.count,
				mat    = f.mat,
				smooth = f.smooth,
				group  = f.group,
			})
		}
	}
	edit_mesh_rebuild_topology(&m)
	return m
}

edit_mesh_face_center :: proc(m: ^Edit_Mesh, face_idx: int) -> [3]f32 {
	if face_idx < 0 || face_idx >= len(m.faces) {
		return {}
	}
	f := &m.faces[face_idx]
	c := int(f.count)
	if c <= 0 {
		return {}
	}
	sum: [3]f32
	for i in 0..<c {
		vi := int(f.v[i])
		if vi >= 0 && vi < len(m.verts) {
			sum = v3_add(sum, m.verts[vi].pos)
		}
	}
	return v3_scale(sum, 1.0 / f32(c))
}

@(private)
compute_face_normal :: proc(m: ^Edit_Mesh, f: ^Edit_Face) -> [3]f32 {
	c := int(f.count)
	if c < 3 {
		return {0, 1, 0}
	}
	p0 := m.verts[f.v[0]].pos
	p1 := m.verts[f.v[1]].pos
	p2 := m.verts[f.v[2]].pos
	n := v3_cross(v3_sub(p1, p0), v3_sub(p2, p0))
	if c == 4 && v3_len_sq(n) < 1e-10 {
		p3 := m.verts[f.v[3]].pos
		n = v3_cross(v3_sub(p2, p0), v3_sub(p3, p0))
	}
	return v3_norm(n)
}

edit_mesh_update_normals :: proc(m: ^Edit_Mesh) {
	accum := make([][3]f32, len(m.verts), context.temp_allocator)
	for &f in m.faces {
		f.nrm = compute_face_normal(m, &f)
		c := int(f.count)
		for i in 0..<c {
			vi := int(f.v[i])
			if vi >= 0 && vi < len(accum) {
				accum[vi] = v3_add(accum[vi], f.nrm)
			}
		}
	}
	for &v, i in m.verts {
		if v3_len_sq(accum[i]) > 1e-10 {
			v.nrm = v3_norm(accum[i])
		} else {
			v.nrm = {0, 1, 0}
		}
	}
}

@(private)
insert_edge_ref :: proc(
	m: ^Edit_Mesh,
	edge_map: ^map[u64]int,
	selected_keys: ^map[u64]bool,
	a, b: u32,
	face_idx: i32,
	is_loose: bool,
) {
	if a == b || int(a) >= len(m.verts) || int(b) >= len(m.verts) {
		return
	}
	key := edge_key(a, b)
	if idx, found := edge_map[key]; found {
		edge := &m.edges[idx]
		if face_idx >= 0 && int(edge.face_len) < len(edge.faces) {
			edge.faces[edge.face_len] = u32(face_idx)
			edge.face_len += 1
		}
		edge.loose = edge.loose || is_loose
		return
	}
	idx := len(m.edges)
	edge := Edit_Edge{
		a        = min(a, b),
		b        = max(a, b),
		loose    = is_loose,
		selected = selected_keys[key],
	}
	if face_idx >= 0 {
		edge.faces[0] = u32(face_idx)
		edge.face_len = 1
	}
	append(&m.edges, edge)
	edge_map[key] = idx
}

edit_mesh_rebuild_topology :: proc(m: ^Edit_Mesh) {
	selected_keys := make(map[u64]bool, len(m.edges), context.temp_allocator)
	for &e in m.edges {
		if e.selected {
			selected_keys[edge_key(e.a, e.b)] = true
		}
	}
	clear(&m.edges)
	edge_map := make(map[u64]int, len(m.faces) * 2 + len(m.loose_edges), context.temp_allocator)
	for &f, fi in m.faces {
		c := int(f.count)
		for i in 0..<c {
			va := f.v[i]
			vb := f.v[(i + 1) % c]
			insert_edge_ref(m, &edge_map, &selected_keys, va, vb, i32(fi), false)
		}
	}
	for &le in m.loose_edges {
		insert_edge_ref(m, &edge_map, &selected_keys, le.a, le.b, -1, true)
		if le.selected {
			if idx, ok := edge_map[edge_key(le.a, le.b)]; ok {
				m.edges[idx].selected = true
			}
		}
	}
	edit_mesh_update_normals(m)
}

edit_mesh_find_edge :: proc(m: ^Edit_Mesh, a, b: u32) -> (int, bool) {
	key := edge_key(a, b)
	for &e, idx in m.edges {
		if edge_key(e.a, e.b) == key {
			return idx, true
		}
	}
	return -1, false
}
