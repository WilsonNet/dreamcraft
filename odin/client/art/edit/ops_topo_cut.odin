// Blender topology cutting tools: Ctrl+R Loop Cut and K Knife Tool.
package art_edit

import "core:math"

@(private)
Edge_Cut_Entry :: struct {
	a:     u32,
	b:     u32,
	verts: []u32,
}

loop_cut_preview_delete :: proc(p: ^Loop_Cut_Preview) {
	delete(p.edge_idxs)
	delete(p.faces)
	delete(p.a_verts)
	delete(p.b_verts)
	p^ = {}
}

@(private)
find_quad_opposite_edge :: proc(f: ^Edit_Face, a, b: u32) -> (oa, ob: u32, ok: bool) {
	if f.count != 4 {
		return 0, 0, false
	}
	for k in 0..<4 {
		u := f.v[k]
		v := f.v[(k + 1) % 4]
		if u == a && v == b {
			return f.v[(k + 3) % 4], f.v[(k + 2) % 4], true
		}
		if u == b && v == a {
			return f.v[(k + 2) % 4], f.v[(k + 3) % 4], true
		}
	}
	return 0, 0, false
}

@(private)
append_ring_edge :: proc(p: ^Loop_Cut_Preview, edge_idx: int, a, b: u32) {
	append(&p.edge_idxs, u32(edge_idx))
	append(&p.a_verts, a)
	append(&p.b_verts, b)
}

@(private)
walk_loop_ring_side :: proc(
	m: ^Edit_Mesh,
	p: ^Loop_Cut_Preview,
	start_face: u32,
	va, vb: u32,
	visited_e, visited_f: []bool,
) {
	cur_f, cur_a, cur_b := start_face, va, vb
	for {
		if int(cur_f) >= len(m.faces) || visited_f[cur_f] || m.faces[cur_f].count != 4 {
			return
		}
		visited_f[cur_f] = true
		append(&p.faces, cur_f)
		oa, ob, ok := find_quad_opposite_edge(&m.faces[cur_f], cur_a, cur_b)
		if !ok { return }
		next_ei, found := edit_mesh_find_edge(m, oa, ob)
		if !found || visited_e[next_ei] { return }
		visited_e[next_ei] = true
		append_ring_edge(p, next_ei, oa, ob)
		ne := &m.edges[next_ei]
		if ne.face_len != 2 { return }
		cur_f = ne.faces[0] == cur_f ? ne.faces[1] : ne.faces[0]
		cur_a, cur_b = oa, ob
	}
}

edit_preview_loop_cut :: proc(m: ^Edit_Mesh, edge_idx: int) -> Loop_Cut_Preview {
	p: Loop_Cut_Preview
	if edge_idx < 0 || edge_idx >= len(m.edges) || m.edges[edge_idx].face_len == 0 {
		return p
	}
	e := &m.edges[edge_idx]
	visited_e := make([]bool, len(m.edges), context.temp_allocator)
	visited_f := make([]bool, len(m.faces), context.temp_allocator)
	visited_e[edge_idx] = true
	append_ring_edge(&p, edge_idx, e.a, e.b)
	for side in 0..<int(e.face_len) {
		fi := e.faces[side]
		if int(fi) < len(m.faces) && m.faces[fi].count == 4 && !visited_f[fi] {
			walk_loop_ring_side(m, &p, fi, e.a, e.b, visited_e, visited_f)
		}
	}
	p.valid = len(p.faces) > 0 && len(p.edge_idxs) > 0
	return p
}

edit_apply_loop_cut :: proc(m: ^Edit_Mesh, edge_idx: int, cuts: int = 1, slide: f32 = 0.0) -> bool {
	p := edit_preview_loop_cut(m, edge_idx)
	defer loop_cut_preview_delete(&p)
	if !p.valid {
		return false
	}
	n_cuts := clamp(cuts, 1, 6)
	edge_cuts := make(map[u64]Edge_Cut_Entry, len(p.edge_idxs), context.temp_allocator)
	for ei, k in p.edge_idxs {
		e := m.edges[ei]
		va, vb := p.a_verts[k], p.b_verts[k]
		verts := spawn_edge_cut_verts(m, va, vb, n_cuts, slide)
		edge_cuts[edge_key(e.a, e.b)] = Edge_Cut_Entry{a = va, b = vb, verts = verts}
	}
	split_faces_for_loop_cut(m, &p, &edge_cuts, n_cuts)
	edit_mesh_deselect_all(m)
	mark_loop_cut_selection(m, &p, &edge_cuts, n_cuts)
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return true
}

@(private)
spawn_edge_cut_verts :: proc(m: ^Edit_Mesh, va, vb: u32, n_cuts: int, slide: f32) -> []u32 {
	out := make([]u32, n_cuts, context.temp_allocator)
	src_a := m.verts[va]
	src_b := m.verts[vb]
	for c in 0..<n_cuts {
		t := f32(c + 1) / f32(n_cuts + 1)
		if n_cuts == 1 {
			t = clamp(0.5 + slide * 0.5, 0.05, 0.95)
		}
		nv := src_a
		nv.pos = v3_lerp(src_a.pos, src_b.pos, t)
		nv.ao = math.lerp(src_a.ao, src_b.ao, t)
		nv.selected = true
		out[c] = u32(len(m.verts))
		append(&m.verts, nv)
	}
	return out
}

@(private)
split_faces_for_loop_cut :: proc(m: ^Edit_Mesh, p: ^Loop_Cut_Preview, edge_cuts: ^map[u64]Edge_Cut_Entry, n_cuts: int) {
	in_ring := make([]bool, len(m.faces), context.temp_allocator)
	for fi in p.faces { in_ring[fi] = true }
	next_faces := make([dynamic]Edit_Face, 0, len(m.faces) + len(p.faces) * n_cuts, context.temp_allocator)
	for f, fi in m.faces {
		if in_ring[fi] {
			emit_split_ring_quad(&next_faces, f, edge_cuts, n_cuts)
		} else if !emit_split_cap_tri(&next_faces, f, edge_cuts, n_cuts) {
			append(&next_faces, f)
		}
	}
	clear(&m.faces)
	for f in next_faces { append(&m.faces, f) }
}

@(private)
ordered_cuts_along :: proc(entry: Edge_Cut_Entry, va: u32, buf: []u32) -> []u32 {
	n := len(entry.verts)
	if n == 0 || n > len(buf) { return nil }
	if entry.a == va {
		for i in 0..<n { buf[i] = entry.verts[i] }
	} else {
		for i in 0..<n { buf[i] = entry.verts[n - 1 - i] }
	}
	return buf[:n]
}

@(private)
emit_split_ring_quad :: proc(out: ^[dynamic]Edit_Face, f: Edit_Face, edge_cuts: ^map[u64]Edge_Cut_Entry, n_cuts: int) {
	side_k := -1
	for k in 0..<int(f.count) {
		if edge_key(f.v[k], f.v[(k + 1) % int(f.count)]) in edge_cuts^ {
			side_k = k
			break
		}
	}
	if f.count != 4 || side_k < 0 { append(out, f); return }
	a0, b0 := f.v[side_k], f.v[(side_k + 1) % 4]
	b1, a1 := f.v[(side_k + 2) % 4], f.v[(side_k + 3) % 4]
	e0, ok0 := edge_cuts[edge_key(a0, b0)]
	e1, ok1 := edge_cuts[edge_key(a1, b1)]
	if !ok0 || !ok1 { append(out, f); return }
	buf0, buf1: [6]u32
	c0 := ordered_cuts_along(e0, a0, buf0[:])
	c1 := ordered_cuts_along(e1, a1, buf1[:])
	prev_0, prev_1 := a0, a1
	for c in 0..<n_cuts {
		append(out, Edit_Face{v = {prev_0, c0[c], c1[c], prev_1}, count = 4, mat = f.mat, smooth = f.smooth, group = f.group})
		prev_0, prev_1 = c0[c], c1[c]
	}
	append(out, Edit_Face{v = {prev_0, b0, b1, prev_1}, count = 4, mat = f.mat, smooth = f.smooth, group = f.group})
}

@(private)
emit_split_cap_tri :: proc(out: ^[dynamic]Edit_Face, f: Edit_Face, edge_cuts: ^map[u64]Edge_Cut_Entry, n_cuts: int) -> bool {
	if f.count != 3 {
		return false
	}
	for k in 0..<3 {
		a := f.v[k]
		b := f.v[(k + 1) % 3]
		if entry, ok := edge_cuts[edge_key(a, b)]; ok {
			apex := f.v[(k + 2) % 3]
			buf: [6]u32
			cuts := ordered_cuts_along(entry, a, buf[:])
			prev := a
			for c in 0..<n_cuts {
				append(out, Edit_Face{v = {prev, cuts[c], apex, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
				prev = cuts[c]
			}
			append(out, Edit_Face{v = {prev, b, apex, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
			return true
		}
	}
	return false
}

@(private)
mark_loop_cut_selection :: proc(m: ^Edit_Mesh, p: ^Loop_Cut_Preview, edge_cuts: ^map[u64]Edge_Cut_Entry, n_cuts: int) {
	_ = edge_cuts
	if m.mode == .Vertex {
		return
	}
	cut_set := make(map[u64]bool, len(p.faces) * n_cuts, context.temp_allocator)
	for fi in p.faces {
		f := m.faces[fi]
		if f.count != 4 { continue }
		_ = f
	}
	// Mark cut verts in vertex mode, or cut interior loop edges in Edge mode via rebuild_topology + vertex check.
	edit_mesh_rebuild_topology(m)
	for &e in m.edges {
		if m.verts[e.a].selected && m.verts[e.b].selected && !cut_set[edge_key(e.a, e.b)] {
			e.selected = true
		}
	}
	if m.mode != .Vertex {
		for &v in m.verts { v.selected = false }
	}
}

// Blender K Knife Tool: splits edges/faces cleanly along clicked Vert/Edge/Face nodes.
edit_apply_knife :: proc(m: ^Edit_Mesh, nodes: []Knife_Node) -> bool {
	if len(nodes) < 2 {
		return false
	}
	edit_mesh_deselect_all(m)
	resolved := resolve_knife_nodes(m, nodes)
	if len(resolved) < 2 {
		return false
	}
	changed := false
	for i in 0..<len(resolved) - 1 {
		va := resolved[i]
		vb := resolved[i + 1]
		if va == vb { continue }
		if split_shared_face_between(m, va, vb) {
			changed = true
		} else {
			if _, exists := edit_mesh_find_edge(m, va, vb); !exists {
				append(&m.loose_edges, Loose_Edge{a = va, b = vb, selected = true})
				changed = true
			}
		}
	}
	if !changed { return false }
	edit_mesh_rebuild_topology(m)
	for i in resolved {
		if int(i) < len(m.verts) { m.verts[i].selected = true }
	}
	m.dirty = true
	return true
}

@(private)
resolve_knife_nodes :: proc(m: ^Edit_Mesh, nodes: []Knife_Node) -> []u32 {
	out := make([dynamic]u32, 0, len(nodes), context.temp_allocator)
	edge_cache := make(map[u64]u32, len(nodes), context.temp_allocator)
	edge_pairs := make([][2]u32, len(nodes), context.temp_allocator)
	has_edge := make([]bool, len(nodes), context.temp_allocator)
	for n, i in nodes {
		if n.kind == .Edge && int(n.index) < len(m.edges) {
			e := m.edges[n.index]
			edge_pairs[i] = {e.a, e.b}
			has_edge[i] = true
		}
	}
	for n, i in nodes {
		switch n.kind {
		case .Vert:
			if int(n.index) < len(m.verts) { append(&out, n.index) }
		case .Edge:
			if has_edge[i] {
				if vi, ok := knife_split_edge_node(m, edge_pairs[i][0], edge_pairs[i][1], n.t, &edge_cache); ok {
					append(&out, vi)
				}
			}
		case .Face:
			if vi, ok := knife_split_face_node(m, n); ok {
				append(&out, vi)
			}
		}
	}
	return out[:]
}

@(private)
knife_split_edge_node :: proc(m: ^Edit_Mesh, ea, eb: u32, raw_t: f32, cache: ^map[u64]u32) -> (u32, bool) {
	key := edge_key(ea, eb)
	if cached, ok := cache[key]; ok { return cached, true }
	t := clamp(raw_t, 0.0, 1.0)
	if t <= 0.02 { return ea, true }
	if t >= 0.98 { return eb, true }
	sa := m.verts[ea]
	nv := sa
	nv.pos = v3_lerp(sa.pos, m.verts[eb].pos, t)
	nv.ao = math.lerp(sa.ao, m.verts[eb].ao, t)
	nv.selected = true
	vi := u32(len(m.verts))
	append(&m.verts, nv)
	cache[key] = vi
	insert_vert_into_edge_faces(m, ea, eb, vi)
	edit_mesh_rebuild_topology(m)
	return vi, true
}

@(private)
insert_vert_into_edge_faces :: proc(m: ^Edit_Mesh, ea, eb, nv: u32) {
	next_faces := make([dynamic]Edit_Face, 0, len(m.faces) + 4, context.temp_allocator)
	for f in m.faces {
		edge_pos := -1
		c := int(f.count)
		for k in 0..<c {
			u, v := f.v[k], f.v[(k + 1) % c]
			if (u == ea && v == eb) || (u == eb && v == ea) {
				edge_pos = k
				break
			}
		}
		if edge_pos < 0 { append(&next_faces, f); continue }
		if c == 3 {
			v0, v1, v2 := f.v[edge_pos], f.v[(edge_pos + 1) % 3], f.v[(edge_pos + 2) % 3]
			append(&next_faces, Edit_Face{v = {v0, nv, v2, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
			append(&next_faces, Edit_Face{v = {nv, v1, v2, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
		} else {
			v0, v1, v2, v3 := f.v[edge_pos], f.v[(edge_pos + 1) % 4], f.v[(edge_pos + 2) % 4], f.v[(edge_pos + 3) % 4]
			append(&next_faces, Edit_Face{v = {v0, nv, v3, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
			append(&next_faces, Edit_Face{v = {nv, v1, v2, v3}, count = 4, mat = f.mat, smooth = f.smooth, group = f.group})
		}
	}
	clear(&m.faces)
	for f in next_faces { append(&m.faces, f) }
}

@(private)
knife_split_face_node :: proc(m: ^Edit_Mesh, n: Knife_Node) -> (u32, bool) {
	fi := int(n.index)
	if fi < 0 || fi >= len(m.faces) { return 0, false }
	f := m.faces[fi]
	c := int(f.count)
	nv := m.verts[f.v[0]]
	nv.pos = n.pos
	nv.selected = true
	vi := u32(len(m.verts))
	append(&m.verts, nv)
	m.faces[fi] = Edit_Face{v = {f.v[0], f.v[1], vi, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group}
	for k in 1..<c {
		append(&m.faces, Edit_Face{v = {f.v[k], f.v[(k + 1) % c], vi, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
	}
	edit_mesh_rebuild_topology(m)
	return vi, true
}

@(private)
split_shared_face_between :: proc(m: ^Edit_Mesh, va, vb: u32) -> bool {
	for f, fi in m.faces {
		if f.count != 4 { continue }
		ia, ib := -1, -1
		for k in 0..<4 {
			if f.v[k] == va { ia = k }
			if f.v[k] == vb { ib = k }
		}
		if ia >= 0 && ib >= 0 && ((ia + 2) % 4) == ib {
			v0, v1, v2, v3 := f.v[ia], f.v[(ia + 1) % 4], f.v[(ia + 2) % 4], f.v[(ia + 3) % 4]
			m.faces[fi] = Edit_Face{v = {v0, v1, v2, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group}
			append(&m.faces, Edit_Face{v = {v0, v2, v3, 0}, count = 3, mat = f.mat, smooth = f.smooth, group = f.group})
			return true
		}
	}
	return false
}
