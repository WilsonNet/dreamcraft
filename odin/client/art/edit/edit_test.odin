#+build !js
package art_edit

import "core:math"
import "core:testing"

@(private)
make_unit_quad_mesh :: proc() -> Edit_Mesh {
	m := edit_mesh_init("quad", "Quad", .Props, false, 1.0, 1.0)
	pts := [4][3]f32{{0, 0, 1}, {1, 0, 1}, {1, 0, 0}, {0, 0, 0}}
	for p in pts {
		append(&m.verts, Edit_Vert{pos = p, bone = .Root, ao = 1.0})
	}
	append(&m.faces, Edit_Face{v = {0, 1, 2, 3}, count = 4, mat = .Steel})
	edit_mesh_rebuild_topology(&m)
	return m
}

@(private)
make_quad_strip_mesh :: proc() -> Edit_Mesh {
	m := edit_mesh_init("strip", "Strip", .Props, false, 1.0, 1.0)
	for i in 0..=2 {
		x := f32(i)
		append(&m.verts, Edit_Vert{pos = {x, 0, 0}, bone = .Root, ao = 1.0})
		append(&m.verts, Edit_Vert{pos = {x, 0, 1}, bone = .Root, ao = 1.0})
	}
	append(&m.faces, Edit_Face{v = {0, 1, 3, 2}, count = 4, mat = .Steel})
	append(&m.faces, Edit_Face{v = {2, 3, 5, 4}, count = 4, mat = .Steel})
	edit_mesh_rebuild_topology(&m)
	return m
}

@(test)
mode_switch_linked_and_edge_loop :: proc(t: ^testing.T) {
	m := make_quad_strip_mesh()
	defer edit_mesh_delete(&m)

	m.mode = .Face
	m.faces[0].selected = true
	edit_mesh_set_mode(&m, .Edge)
	v, e, f := edit_mesh_selected_counts(&m)
	testing.expect_value(t, v, 0)
	testing.expect_value(t, e, 4)
	testing.expect_value(t, f, 0)

	edit_mesh_set_mode(&m, .Vertex)
	v, e, f = edit_mesh_selected_counts(&m)
	testing.expect_value(t, v, 4)

	edit_mesh_deselect_all(&m)
	edit_mesh_select_linked(&m, 0)
	v, _, _ = edit_mesh_selected_counts(&m)
	testing.expect_value(t, v, 6)
}

@(test)
translate_rotate_scale_with_x_mirror :: proc(t: ^testing.T) {
	m := edit_mesh_init("sym", "Sym", .Units, true, 1.6, 1.0)
	defer edit_mesh_delete(&m)
	append(&m.verts, Edit_Vert{pos = {1.0, 0.5, 0.0}, ao = 1, bone = .Hand_R, selected = true})
	append(&m.verts, Edit_Vert{pos = {-1.0, 0.5, 0.0}, ao = 1, bone = .Hand_L, selected = false})

	base := edit_snapshot_positions(&m)
	defer delete(base)
	edit_translate_from_base(&m, base, {0.25, 0.40, -0.10}, .None, true)
	testing.expect(t, abs(m.verts[0].pos[0] - 1.25) < 1e-4)
	testing.expect(t, abs(m.verts[1].pos[0] + 1.25) < 1e-4)
	testing.expect(t, abs(m.verts[1].pos[1] - 0.90) < 1e-4)

	edit_rotate_from_base(&m, base, {1, 0, 0}, {0, 0, 1}, math.PI * 0.5, true)
	testing.expect(t, abs(m.verts[0].pos[0] - 0.5) < 1e-3)
	testing.expect(t, abs(m.verts[1].pos[0] + 0.5) < 1e-3)
}

@(test)
extrude_and_inset_build_manifold_quads :: proc(t: ^testing.T) {
	m := make_unit_quad_mesh()
	defer edit_mesh_delete(&m)
	m.mode = .Face
	m.faces[0].selected = true

	nrm, ok := edit_extrude(&m)
	testing.expect(t, ok)
	testing.expect(t, nrm[1] > 0.9)
	testing.expect_value(t, len(m.verts), 8)
	testing.expect_value(t, len(m.faces), 5)

	base := edit_snapshot_positions(&m)
	defer delete(base)
	edit_translate_from_base(&m, base, {0, 1, 0}, .Y, false)
	testing.expect(t, abs(m.verts[m.faces[0].v[0]].pos[1] - 1.0) < 1e-4)

	testing.expect(t, edit_inset(&m, 0.25))
	testing.expect_value(t, len(m.verts), 12)
	testing.expect_value(t, len(m.faces), 9)
}

@(test)
loop_cut_and_knife_split_cleanly :: proc(t: ^testing.T) {
	m := make_quad_strip_mesh()
	defer edit_mesh_delete(&m)

	ei, found := edit_mesh_find_edge(&m, 0, 1)
	testing.expect(t, found)
	testing.expect(t, edit_apply_loop_cut(&m, ei, 2, 0))
	testing.expect_value(t, len(m.faces), 6)
	testing.expect_value(t, len(m.verts), 12)

	// Knife split across the first quad's opposite edges.
	k := make_unit_quad_mesh()
	defer edit_mesh_delete(&k)
	e0, ok0 := edit_mesh_find_edge(&k, 0, 1)
	e1, ok1 := edit_mesh_find_edge(&k, 2, 3)
	testing.expect(t, ok0 && ok1)
	nodes := [2]Knife_Node{
		{kind = .Edge, index = u32(e0), t = 0.5},
		{kind = .Edge, index = u32(e1), t = 0.5},
	}
	testing.expect(t, edit_apply_knife(&k, nodes[:]))
	testing.expect_value(t, len(k.verts), 6)
	testing.expect(t, len(k.faces) >= 3)
}

@(test)
fill_merge_delete_dissolve_and_undo_redo :: proc(t: ^testing.T) {
	m := make_unit_quad_mesh()
	defer edit_mesh_delete(&m)
	undo := undo_init()
	defer undo_delete(&undo)

	undo_push(&undo, &m)
	m.mode = .Vertex
	m.verts[0].selected = true
	m.verts[2].selected = true
	testing.expect(t, edit_fill(&m))
	testing.expect_value(t, len(m.faces), 2)

	// Dissolve the diagonal edge back into 1 quad.
	diag, ok_d := edit_mesh_find_edge(&m, 0, 2)
	testing.expect(t, ok_d)
	edit_mesh_deselect_all(&m)
	m.mode = .Edge
	m.edges[diag].selected = true
	testing.expect(t, edit_dissolve_edges(&m))
	testing.expect_value(t, len(m.faces), 1)
	testing.expect_value(t, m.faces[0].count, u8(4))

	// Delete & undo back to diagonal split state -> undo back to initial.
	undo_push(&undo, &m)
	m.mode = .Face
	m.faces[0].selected = true
	testing.expect(t, edit_delete_faces(&m))
	testing.expect_value(t, len(m.faces), 0)
	testing.expect_value(t, len(m.verts), 0)

	testing.expect(t, undo_step(&undo, &m))
	testing.expect_value(t, len(m.faces), 1)
	testing.expect(t, redo_step(&undo, &m))
	testing.expect_value(t, len(m.faces), 0)
}

@(test)
merge_center_and_distance :: proc(t: ^testing.T) {
	m := make_quad_strip_mesh()
	defer edit_mesh_delete(&m)
	m.verts[2].selected = true
	m.verts[3].selected = true
	testing.expect(t, edit_merge_center(&m))
	testing.expect_value(t, len(m.verts), 5)
	testing.expect_value(t, len(m.faces), 2)
	for f in m.faces {
		testing.expect_value(t, f.count, u8(3))
	}
}
