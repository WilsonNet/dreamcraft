// Selection conversion (1/2/3), All/Invert, Linked (L), Bone, and Edge Loop (Alt+Click).
package art_edit

import spec "../spec"

edit_mesh_set_mode :: proc(m: ^Edit_Mesh, next: Select_Mode) {
	if m.mode == next {
		return
	}
	mask := edit_mesh_selected_verts_mask(m)
	if m.mode == .Vertex && next == .Edge {
		select_edges_from_verts(m, mask, true)
	} else if m.mode == .Vertex && next == .Face {
		select_faces_from_verts(m, mask, true)
	} else if m.mode == .Edge && next == .Face {
		select_faces_from_edges(m)
	} else if next == .Vertex {
		apply_vert_mask(m, mask)
	} else if m.mode == .Face && next == .Edge {
		select_edges_from_faces(m)
	}
	m.mode = next
}

@(private)
apply_vert_mask :: proc(m: ^Edit_Mesh, mask: []bool) {
	for &v, i in m.verts {
		v.selected = mask[i]
	}
	for &e in m.edges {
		e.selected = false
	}
	for &f in m.faces {
		f.selected = false
	}
}

@(private)
select_edges_from_verts :: proc(m: ^Edit_Mesh, mask: []bool, both: bool) {
	for &e in m.edges {
		a_ok := mask[e.a]
		b_ok := mask[e.b]
		e.selected = both ? (a_ok && b_ok) : (a_ok || b_ok)
	}
	for &v in m.verts { v.selected = false }
	for &f in m.faces { f.selected = false }
}

@(private)
select_faces_from_verts :: proc(m: ^Edit_Mesh, mask: []bool, all_corners: bool) {
	for &f in m.faces {
		hit := all_corners
		c := int(f.count)
		for i in 0..<c {
			sel := mask[f.v[i]]
			if all_corners && !sel {
				hit = false
				break
			}
			if !all_corners && sel {
				hit = true
				break
			}
		}
		f.selected = hit
	}
	for &v in m.verts { v.selected = false }
	for &e in m.edges { e.selected = false }
}

@(private)
select_faces_from_edges :: proc(m: ^Edit_Mesh) {
	edge_sel := make(map[u64]bool, len(m.edges), context.temp_allocator)
	for &e in m.edges {
		if e.selected {
			edge_sel[edge_key(e.a, e.b)] = true
		}
	}
	for &f in m.faces {
		all_sel := true
		c := int(f.count)
		for i in 0..<c {
			if !edge_sel[edge_key(f.v[i], f.v[(i + 1) % c])] {
				all_sel = false
				break
			}
		}
		f.selected = all_sel
	}
	for &e in m.edges { e.selected = false }
	for &v in m.verts { v.selected = false }
}

@(private)
select_edges_from_faces :: proc(m: ^Edit_Mesh) {
	edge_sel := make(map[u64]bool, len(m.faces) * 4, context.temp_allocator)
	for &f in m.faces {
		if !f.selected {
			continue
		}
		c := int(f.count)
		for i in 0..<c {
			edge_sel[edge_key(f.v[i], f.v[(i + 1) % c])] = true
		}
		f.selected = false
	}
	for &e in m.edges {
		e.selected = edge_sel[edge_key(e.a, e.b)]
	}
	for &v in m.verts { v.selected = false }
}

edit_mesh_deselect_all :: proc(m: ^Edit_Mesh) {
	for &v in m.verts { v.selected = false }
	for &e in m.edges { e.selected = false }
	for &f in m.faces { f.selected = false }
	for &le in m.loose_edges { le.selected = false }
}

edit_mesh_select_all :: proc(m: ^Edit_Mesh) {
	edit_mesh_deselect_all(m)
	switch m.mode {
	case .Vertex:
		for &v in m.verts { v.selected = true }
	case .Edge:
		for &e in m.edges { e.selected = true }
	case .Face:
		for &f in m.faces { f.selected = true }
	}
}

edit_mesh_invert_selection :: proc(m: ^Edit_Mesh) {
	switch m.mode {
	case .Vertex:
		for &v in m.verts { v.selected = !v.selected }
	case .Edge:
		for &e in m.edges { e.selected = !e.selected }
	case .Face:
		for &f in m.faces { f.selected = !f.selected }
	}
}

edit_mesh_selected_verts_mask :: proc(m: ^Edit_Mesh, allocator := context.temp_allocator) -> []bool {
	mask := make([]bool, len(m.verts), allocator)
	for &v, i in m.verts {
		if v.selected {
			mask[i] = true
		}
	}
	for &e in m.edges {
		if e.selected {
			if int(e.a) < len(mask) { mask[e.a] = true }
			if int(e.b) < len(mask) { mask[e.b] = true }
		}
	}
	for &f in m.faces {
		if f.selected {
			for i in 0..<int(f.count) {
				vi := int(f.v[i])
				if vi >= 0 && vi < len(mask) { mask[vi] = true }
			}
		}
	}
	return mask
}

edit_mesh_selected_counts :: proc(m: ^Edit_Mesh) -> (verts, edges, faces: int) {
	for &v in m.verts { if v.selected { verts += 1 } }
	for &e in m.edges { if e.selected { edges += 1 } }
	for &f in m.faces { if f.selected { faces += 1 } }
	return
}

edit_mesh_select_same_bone :: proc(m: ^Edit_Mesh, bone: spec.Bone_Id) {
	mask := make([]bool, len(m.verts), context.temp_allocator)
	for &v, i in m.verts {
		if v.bone == bone {
			mask[i] = true
		}
	}
	switch m.mode {
	case .Vertex:
		apply_vert_mask(m, mask)
	case .Edge:
		select_edges_from_verts(m, mask, true)
	case .Face:
		select_faces_from_verts(m, mask, true)
	}
}

edit_mesh_select_linked :: proc(m: ^Edit_Mesh, seed_vert: int = -1) {
	n := len(m.verts)
	if n == 0 {
		return
	}
	visited := make([]bool, n, context.temp_allocator)
	queue := make([dynamic]u32, 0, 128, context.temp_allocator)
	if seed_vert >= 0 && seed_vert < n {
		visited[seed_vert] = true
		append(&queue, u32(seed_vert))
	} else {
		mask := edit_mesh_selected_verts_mask(m)
		for sel, i in mask {
			if sel {
				visited[i] = true
				append(&queue, u32(i))
			}
		}
	}
	if len(queue) == 0 {
		return
	}
	adj := build_vert_edge_adj(m)
	head := 0
	for head < len(queue) {
		cur := queue[head]
		head += 1
		for ei in adj[cur] {
			e := &m.edges[ei]
			other := e.a == cur ? e.b : e.a
			if !visited[other] {
				visited[other] = true
				append(&queue, other)
			}
		}
	}
	switch m.mode {
	case .Vertex:
		apply_vert_mask(m, visited)
	case .Edge:
		select_edges_from_verts(m, visited, true)
	case .Face:
		select_faces_from_verts(m, visited, false)
	}
}

@(private)
build_vert_edge_adj :: proc(m: ^Edit_Mesh) -> [][dynamic]u32 {
	adj := make([][dynamic]u32, len(m.verts), context.temp_allocator)
	for &list in adj {
		list = make([dynamic]u32, 0, 4, context.temp_allocator)
	}
	for &e, ei in m.edges {
		append(&adj[e.a], u32(ei))
		append(&adj[e.b], u32(ei))
	}
	return adj
}

// Blender Alt+Click edge loop: walks continuation edges across 4-edge poles.
edit_mesh_select_edge_loop :: proc(m: ^Edit_Mesh, edge_idx: int, additive: bool) {
	if edge_idx < 0 || edge_idx >= len(m.edges) {
		return
	}
	if !additive {
		edit_mesh_deselect_all(m)
	}
	edge := m.edges[edge_idx]
	adj := build_vert_edge_adj(m)
	m.edges[edge_idx].selected = true
	walk_edge_loop_dir(m, adj, u32(edge_idx), edge.b)
	walk_edge_loop_dir(m, adj, u32(edge_idx), edge.a)
}

@(private)
walk_edge_loop_dir :: proc(m: ^Edit_Mesh, adj: [][dynamic]u32, start_edge, start_vert: u32) {
	cur_edge := start_edge
	cur_vert := start_vert
	for _ in 0..<len(m.edges) {
		next_edge, ok := next_loop_edge(m, adj[cur_vert][:], cur_edge)
		if !ok || m.edges[next_edge].selected {
			return
		}
		m.edges[next_edge].selected = true
		e := m.edges[next_edge]
		cur_vert = e.a == cur_vert ? e.b : e.a
		cur_edge = next_edge
	}
}

@(private)
next_loop_edge :: proc(m: ^Edit_Mesh, vert_edges: []u32, incoming_idx: u32) -> (u32, bool) {
	if len(vert_edges) != 4 {
		return 0, false
	}
	inc := m.edges[incoming_idx]
	for cand_idx in vert_edges {
		if cand_idx == incoming_idx {
			continue
		}
		cand := m.edges[cand_idx]
		if !edges_share_face(&inc, &cand) {
			return cand_idx, true
		}
	}
	return 0, false
}

@(private)
edges_share_face :: proc(a, b: ^Edit_Edge) -> bool {
	for i in 0..<int(a.face_len) {
		for j in 0..<int(b.face_len) {
			if a.faces[i] == b.faces[j] {
				return true
			}
		}
	}
	return false
}
