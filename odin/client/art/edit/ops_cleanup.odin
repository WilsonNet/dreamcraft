// Merge (M), Delete (X), and Dissolve topology cleanup operators.
package art_edit

edit_merge_center :: proc(m: ^Edit_Mesh) -> bool {
	mask := edit_mesh_selected_verts_mask(m)
	sum: [3]f32
	keep := -1
	count := 0
	for sel, i in mask {
		if !sel { continue }
		if keep < 0 { keep = i }
		sum = v3_add(sum, m.verts[i].pos)
		count += 1
	}
	if count < 2 || keep < 0 {
		return false
	}
	m.verts[keep].pos = v3_scale(sum, 1.0 / f32(count))
	remap := make([]i32, len(m.verts), context.temp_allocator)
	for i in 0..<len(m.verts) {
		remap[i] = mask[i] ? i32(keep) : i32(i)
	}
	apply_vertex_remap_and_compact(m, remap)
	if m.mode == .Vertex && keep < len(m.verts) {
		m.verts[keep].selected = true
	}
	return true
}

edit_merge_by_distance :: proc(m: ^Edit_Mesh, threshold: f32 = 0.002) -> int {
	n := len(m.verts)
	if n < 2 {
		return 0
	}
	mask := edit_mesh_selected_verts_mask(m)
	any_sel := false
	for s in mask { if s { any_sel = true; break } }
	t2 := threshold * threshold
	remap := make([]i32, n, context.temp_allocator)
	for i in 0..<n { remap[i] = i32(i) }
	removed := 0
	for i in 0..<n {
		if any_sel && !mask[i] { continue }
		if remap[i] != i32(i) { continue }
		for j := i + 1; j < n; j += 1 {
			if any_sel && !mask[j] { continue }
			if remap[j] != i32(j) { continue }
			if v3_len_sq(v3_sub(m.verts[i].pos, m.verts[j].pos)) <= t2 {
				remap[j] = i32(i)
				removed += 1
			}
		}
	}
	if removed == 0 {
		return 0
	}
	apply_vertex_remap_and_compact(m, remap)
	return removed
}

edit_delete_verts :: proc(m: ^Edit_Mesh) -> bool {
	mask := edit_mesh_selected_verts_mask(m)
	any_sel := false
	for s in mask { if s { any_sel = true; break } }
	if !any_sel {
		return false
	}
	remap := make([]i32, len(m.verts), context.temp_allocator)
	for i in 0..<len(m.verts) {
		remap[i] = mask[i] ? -1 : i32(i)
	}
	apply_vertex_remap_and_compact(m, remap)
	edit_mesh_deselect_all(m)
	return true
}

edit_delete_edges :: proc(m: ^Edit_Mesh) -> bool {
	sel_edges := make(map[u64]bool, len(m.edges), context.temp_allocator)
	for &e in m.edges {
		if e.selected { sel_edges[edge_key(e.a, e.b)] = true }
	}
	if len(sel_edges) == 0 {
		return false
	}
	keep_faces := make([dynamic]Edit_Face, 0, len(m.faces), context.temp_allocator)
	for &f in m.faces {
		if !face_uses_edge_set(&f, &sel_edges) {
			append(&keep_faces, f)
		}
	}
	clear(&m.faces)
	for f in keep_faces { append(&m.faces, f) }
	keep_loose := make([dynamic]Loose_Edge, 0, len(m.loose_edges), context.temp_allocator)
	for le in m.loose_edges {
		if !sel_edges[edge_key(le.a, le.b)] {
			append(&keep_loose, le)
		}
	}
	clear(&m.loose_edges)
	for le in keep_loose { append(&m.loose_edges, le) }
	compact_unused_verts(m)
	edit_mesh_rebuild_topology(m)
	edit_mesh_deselect_all(m)
	m.dirty = true
	return true
}

edit_delete_faces :: proc(m: ^Edit_Mesh) -> bool {
	keep := make([dynamic]Edit_Face, 0, len(m.faces), context.temp_allocator)
	removed := 0
	for f in m.faces {
		if f.selected {
			removed += 1
		} else {
			append(&keep, f)
		}
	}
	if removed == 0 {
		return false
	}
	clear(&m.faces)
	for f in keep { append(&m.faces, f) }
	compact_unused_verts(m)
	edit_mesh_rebuild_topology(m)
	edit_mesh_deselect_all(m)
	m.dirty = true
	return true
}

// Merge adjacent tri/quad pairs sharing selected manifold edges into one valid face (<=4 verts).
edit_dissolve_edges :: proc(m: ^Edit_Mesh) -> bool {
	changed := false
	for &e in m.edges {
		if !e.selected || e.face_len != 2 {
			continue
		}
		fa := int(e.faces[0])
		fb := int(e.faces[1])
		if fa == fb || fa >= len(m.faces) || fb >= len(m.faces) {
			continue
		}
		if merged, ok := try_merge_two_faces(&m.faces[fa], &m.faces[fb], e.a, e.b); ok {
			m.faces[fa] = merged
			m.faces[fb].count = 0
			changed = true
		}
	}
	if !changed {
		return false
	}
	prune_zero_faces(m)
	compact_unused_verts(m)
	edit_mesh_rebuild_topology(m)
	m.dirty = true
	return true
}

@(private)
try_merge_two_faces :: proc(fa, fb: ^Edit_Face, ea, eb: u32) -> (Edit_Face, bool) {
	if fa.count < 3 || fb.count < 3 {
		return {}, false
	}
	combined := int(fa.count) + int(fb.count) - 2
	if combined < 3 || combined > 4 {
		return {}, false
	}
	loop: [4]u32
	n := 0
	ca := int(fa.count)
	start := -1
	for k in 0..<ca {
		u := fa.v[k]
		v := fa.v[(k + 1) % ca]
		if (u == ea && v == eb) || (u == eb && v == ea) {
			start = k
			break
		}
	}
	if start < 0 { return {}, false }
	u := fa.v[start]
	v := fa.v[(start + 1) % ca]
	// Walk fa from v around to u (omitting edge u->v).
	for step in 1..<ca {
		loop[n] = fa.v[(start + step) % ca]
		n += 1
	}
	// Walk fb from u around to v (omitting v since Loop 1 started at v).
	cb := int(fb.count)
	sb := -1
	for k in 0..<cb {
		if fb.v[k] == u { sb = k; break }
	}
	if sb < 0 { return {}, false }
	if fb.v[(sb + cb - 1) % cb] != v {
		return {}, false
	}
	for step in 0..<cb - 1 {
		pt := fb.v[(sb + step) % cb]
		if n < 4 {
			loop[n] = pt
			n += 1
		}
	}
	if n != combined {
		return {}, false
	}
	return Edit_Face{v = loop, count = u8(n), mat = fa.mat, smooth = fa.smooth, group = fa.group}, true
}

@(private)
face_uses_edge_set :: proc(f: ^Edit_Face, set: ^map[u64]bool) -> bool {
	c := int(f.count)
	for k in 0..<c {
		if set[edge_key(f.v[k], f.v[(k + 1) % c])] {
			return true
		}
	}
	return false
}

@(private)
prune_zero_faces :: proc(m: ^Edit_Mesh) {
	keep := make([dynamic]Edit_Face, 0, len(m.faces), context.temp_allocator)
	for f in m.faces {
		if f.count >= 3 { append(&keep, f) }
	}
	clear(&m.faces)
	for f in keep { append(&m.faces, f) }
}

@(private)
apply_vertex_remap_and_compact :: proc(m: ^Edit_Mesh, remap: []i32) {
	keep_faces := make([dynamic]Edit_Face, 0, len(m.faces), context.temp_allocator)
	for f in m.faces {
		if remapped, ok := remap_face(f, remap); ok {
			append(&keep_faces, remapped)
		}
	}
	clear(&m.faces)
	for f in keep_faces { append(&m.faces, f) }

	keep_loose := make([dynamic]Loose_Edge, 0, len(m.loose_edges), context.temp_allocator)
	for le in m.loose_edges {
		ra := int(le.a) < len(remap) ? remap[le.a] : i32(-1)
		rb := int(le.b) < len(remap) ? remap[le.b] : i32(-1)
		if ra >= 0 && rb >= 0 && ra != rb {
			append(&keep_loose, Loose_Edge{a = u32(ra), b = u32(rb), selected = le.selected})
		}
	}
	clear(&m.loose_edges)
	for le in keep_loose { append(&m.loose_edges, le) }

	compact_unused_verts(m)
	edit_mesh_rebuild_topology(m)
	m.dirty = true
}

@(private)
remap_face :: proc(f: Edit_Face, remap: []i32) -> (Edit_Face, bool) {
	out: [4]u32
	n := 0
	for k in 0..<int(f.count) {
		old := int(f.v[k])
		if old < 0 || old >= len(remap) || remap[old] < 0 {
			return {}, false
		}
		nv := u32(remap[old])
		if n > 0 && out[n - 1] == nv {
			continue
		}
		out[n] = nv
		n += 1
	}
	if n > 1 && out[0] == out[n - 1] {
		n -= 1
	}
	if n < 3 {
		return {}, false
	}
	res := f
	res.v = out
	res.count = u8(n)
	return res, true
}

@(private)
compact_unused_verts :: proc(m: ^Edit_Mesh) {
	used := make([]bool, len(m.verts), context.temp_allocator)
	for &f in m.faces {
		for k in 0..<int(f.count) { used[f.v[k]] = true }
	}
	for &le in m.loose_edges {
		used[le.a] = true
		used[le.b] = true
	}
	new_idx := make([]u32, len(m.verts), context.temp_allocator)
	write := 0
	for i in 0..<len(m.verts) {
		if used[i] {
			new_idx[i] = u32(write)
			m.verts[write] = m.verts[i]
			write += 1
		}
	}
	resize(&m.verts, write)
	for &f in m.faces {
		for k in 0..<int(f.count) { f.v[k] = new_idx[f.v[k]] }
	}
	for &le in m.loose_edges {
		le.a = new_idx[le.a]
		le.b = new_idx[le.b]
	}
}
