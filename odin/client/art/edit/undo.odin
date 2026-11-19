// Undo/Redo snapshot ring buffer for Edit_Mesh topology and selection edits.
package art_edit

undo_init :: proc() -> Undo_Stack {
	return Undo_Stack{}
}

undo_delete :: proc(u: ^Undo_Stack) {
	for &snap in u.items {
		delete(snap.verts)
		delete(snap.faces)
		delete(snap.loose_edges)
	}
	delete(u.items)
	u^ = {}
}

undo_clear :: proc(u: ^Undo_Stack) {
	for &snap in u.items {
		delete(snap.verts)
		delete(snap.faces)
		delete(snap.loose_edges)
	}
	clear(&u.items)
	u.cursor = 0
}

@(private)
make_snapshot :: proc(m: ^Edit_Mesh) -> Undo_Snapshot {
	verts := make([]Edit_Vert, len(m.verts))
	copy(verts, m.verts[:])
	faces := make([]Edit_Face, len(m.faces))
	copy(faces, m.faces[:])
	loose := make([]Loose_Edge, len(m.loose_edges))
	copy(loose, m.loose_edges[:])
	return Undo_Snapshot{
		verts       = verts,
		faces       = faces,
		loose_edges = loose,
		mode        = m.mode,
	}
}

@(private)
apply_snapshot :: proc(snap: ^Undo_Snapshot, m: ^Edit_Mesh) {
	resize(&m.verts, len(snap.verts))
	copy(m.verts[:], snap.verts)
	resize(&m.faces, len(snap.faces))
	copy(m.faces[:], snap.faces)
	resize(&m.loose_edges, len(snap.loose_edges))
	copy(m.loose_edges[:], snap.loose_edges)
	m.mode = snap.mode
	clear(&m.edges)
	edit_mesh_rebuild_topology(m)
	m.dirty = true
}

undo_push :: proc(u: ^Undo_Stack, m: ^Edit_Mesh) {
	for i := len(u.items) - 1; i >= u.cursor; i -= 1 {
		delete(u.items[i].verts)
		delete(u.items[i].faces)
		delete(u.items[i].loose_edges)
		ordered_remove(&u.items, i)
	}
	if len(u.items) >= MAX_UNDO_SNAPSHOTS {
		delete(u.items[0].verts)
		delete(u.items[0].faces)
		delete(u.items[0].loose_edges)
		ordered_remove(&u.items, 0)
	}
	append(&u.items, make_snapshot(m))
	u.cursor = len(u.items)
}

// Restores previous state; appends current tail snapshot once at head so Redo works.
undo_step :: proc(u: ^Undo_Stack, m: ^Edit_Mesh) -> bool {
	if u.cursor <= 0 {
		return false
	}
	if u.cursor == len(u.items) {
		append(&u.items, make_snapshot(m))
	}
	u.cursor -= 1
	apply_snapshot(&u.items[u.cursor], m)
	return true
}

redo_step :: proc(u: ^Undo_Stack, m: ^Edit_Mesh) -> bool {
	if u.cursor + 1 >= len(u.items) {
		return false
	}
	u.cursor += 1
	apply_snapshot(&u.items[u.cursor], m)
	return true
}
