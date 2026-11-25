// Model Editor 3D overlays: selection wire/faces/verts, XYZ gizmo, Loop Cut & Knife previews.
package main

import rl "../gfx"
import rlgl "../gfx/rlgl"
import edit "./art/edit"

@(private)
GIZMO_AXES := [3]rl.Vector3{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}

@(private)
GIZMO_COLORS := [3]rl.Color{
	{235, 88, 88, 255},
	{96, 212, 112, 255},
	{86, 158, 238, 255},
}

editor_posed_selection_center :: proc() -> (rl.Vector3, bool) {
	ed := &app.editor
	if !ed.mesh_loaded { return {}, false }
	mask := edit.edit_mesh_selected_verts_mask(&ed.mesh)
	sum: rl.Vector3
	count := 0
	for sel, i in mask {
		if sel {
			sum += editor_posed_vert_pos(i)
			count += 1
		}
	}
	if count == 0 { return {}, false }
	return sum / f32(count), true
}

editor_gizmo_hit_test :: proc(mouse: rl.Vector2) -> int {
	pivot, ok := editor_posed_selection_center()
	if !ok { return -1 }
	origin_2d := rl.GetWorldToScreen(pivot, app.editor.camera)
	world_len := editor_world_per_px() * 72.0
	best := -1
	best_d2 := f32(144.0) // 12px threshold
	for axis in 0..<3 {
		tip_3d := pivot + GIZMO_AXES[axis] * world_len
		tip_2d := rl.GetWorldToScreen(tip_3d, app.editor.camera)
		d2, t := seg_dist_sq_2d(mouse, origin_2d, tip_2d)
		if t >= 0.14 && d2 < best_d2 {
			best_d2 = d2
			best = axis
		}
	}
	return best
}

editor_draw_overlays_3d :: proc() {
	ed := &app.editor
	if !ed.mesh_loaded { return }
	draw_face_selection_3d()
	if ed.wire_overlay || ed.mesh.mode != .Face {
		draw_edges_3d()
	}
	if ed.modal_active && (ed.modal_op == .Grab || ed.modal_op == .Rotate || ed.modal_op == .Scale) {
		draw_axis_constraint_guide_3d()
	}
	if ed.tool == .Loop_Cut || (ed.modal_active && ed.modal_op == .Loop_Cut) {
		draw_loop_cut_preview_3d()
	}
	if ed.tool == .Knife || (ed.modal_active && ed.modal_op == .Knife) {
		draw_knife_chain_3d()
	}
	draw_gizmo_3d()
}

@(private)
draw_face_selection_3d :: proc() {
	ed := &app.editor
	rlgl.DisableBackfaceCulling()
	if ed.xray_mode { rlgl.DisableDepthTest() }
	rlgl.Begin(rlgl.TRIANGLES)
	for &f, fi in ed.mesh.faces {
		sel := f.selected
		hov := ed.mesh.mode == .Face && fi == ed.hover_face
		if !sel && !hov { continue }
		col := sel ? rl.Color{240, 185, 58, 95} : rl.Color{230, 245, 255, 55}
		rlgl.Color4ub(col.r, col.g, col.b, col.a)
		p0 := editor_posed_vert_pos(int(f.v[0])) + rl.Vector3(f.nrm) * 0.002
		p1 := editor_posed_vert_pos(int(f.v[1])) + rl.Vector3(f.nrm) * 0.002
		p2 := editor_posed_vert_pos(int(f.v[2])) + rl.Vector3(f.nrm) * 0.002
		rlgl.Vertex3f(p0.x, p0.y, p0.z)
		rlgl.Vertex3f(p1.x, p1.y, p1.z)
		rlgl.Vertex3f(p2.x, p2.y, p2.z)
		if f.count == 4 {
			p3 := editor_posed_vert_pos(int(f.v[3])) + rl.Vector3(f.nrm) * 0.002
			rlgl.Vertex3f(p0.x, p0.y, p0.z)
			rlgl.Vertex3f(p2.x, p2.y, p2.z)
			rlgl.Vertex3f(p3.x, p3.y, p3.z)
		}
	}
	rlgl.End()
	rlgl.EnableDepthTest()
	rlgl.EnableBackfaceCulling()
}

@(private)
draw_edges_3d :: proc() {
	ed := &app.editor
	nrm_bias := rl.Vector3Normalize(ed.camera.position - ed.camera.target) * 0.0025
	if ed.xray_mode { rlgl.DisableDepthTest() }
	rlgl.Begin(rlgl.LINES)
	for &e, ei in ed.mesh.edges {
		pa := editor_posed_vert_pos(int(e.a)) + nrm_bias
		pb := editor_posed_vert_pos(int(e.b)) + nrm_bias
		col := edge_highlight_color(ed, &e, ei)
		rlgl.Color4ub(col.r, col.g, col.b, col.a)
		rlgl.Vertex3f(pa.x, pa.y, pa.z)
		rlgl.Vertex3f(pb.x, pb.y, pb.z)
	}
	rlgl.End()
	rlgl.EnableDepthTest()
}

@(private)
edge_highlight_color :: proc(ed: ^Model_Editor_State, e: ^edit.Edit_Edge, ei: int) -> rl.Color {
	if ed.mesh.mode == .Edge && e.selected {
		return rl.Color{248, 198, 72, 240}
	}
	if ed.mesh.mode == .Vertex && ed.mesh.verts[e.a].selected && ed.mesh.verts[e.b].selected {
		return rl.Color{245, 190, 68, 220}
	}
	if ed.mesh.mode == .Edge && ei == ed.hover_edge {
		return rl.Color{110, 232, 255, 255}
	}
	return ed.xray_mode ? rl.Color{135, 165, 140, 110} : rl.Color{40, 56, 44, 150}
}

@(private)
draw_axis_constraint_guide_3d :: proc() {
	ed := &app.editor
	if ed.axis_lock == .None { return }
	p := rl.Vector3(ed.pivot)
	span := f32(25.0)
	if ed.axis_lock == .X { rl.DrawLine3D(p - {span, 0, 0}, p + {span, 0, 0}, GIZMO_COLORS[0]) }
	if ed.axis_lock == .Y { rl.DrawLine3D(p - {0, span, 0}, p + {0, span, 0}, GIZMO_COLORS[1]) }
	if ed.axis_lock == .Z { rl.DrawLine3D(p - {0, 0, span}, p + {0, 0, span}, GIZMO_COLORS[2]) }
}

@(private)
draw_loop_cut_preview_3d :: proc() {
	ed := &app.editor
	if !ed.loop_preview.valid { return }
	cuts := clamp(ed.loop_cuts, 1, 6)
	bias := rl.Vector3Normalize(ed.camera.position - ed.camera.target) * 0.004
	edge_t_map := make(map[u64][2]u32, len(ed.loop_preview.edge_idxs), context.temp_allocator)
	for ei, k in ed.loop_preview.edge_idxs {
		e := ed.mesh.edges[ei]
		edge_t_map[edit.edge_key(e.a, e.b)] = {ed.loop_preview.a_verts[k], ed.loop_preview.b_verts[k]}
	}
	rlgl.DisableDepthTest()
	for c in 0..<cuts {
		t := f32(c + 1) / f32(cuts + 1)
		if cuts == 1 { t = clamp(0.5 + ed.loop_slide * 0.5, 0.05, 0.95) }
		for fi in ed.loop_preview.faces {
			f := ed.mesh.faces[fi]
			if f.count != 4 { continue }
			pts: [2]rl.Vector3
			found := 0
			for k in 0..<4 {
				u, v := f.v[k], f.v[(k + 1) % 4]
				if pair, ok := edge_t_map[edit.edge_key(u, v)]; ok && found < 2 {
					pa := editor_posed_vert_pos(int(pair[0]))
					pb := editor_posed_vert_pos(int(pair[1]))
					pts[found] = pa + (pb - pa) * t + bias
					found += 1
				}
			}
			if found == 2 {
				rl.DrawLine3D(pts[0], pts[1], rl.Color{92, 238, 255, 255})
			}
		}
	}
	rlgl.EnableDepthTest()
}

@(private)
draw_knife_chain_3d :: proc() {
	ed := &app.editor
	rlgl.DisableDepthTest()
	for i := 0; i + 1 < len(ed.knife_nodes); i += 1 {
		a := rl.Vector3(ed.knife_nodes[i].pos)
		b := rl.Vector3(ed.knife_nodes[i + 1].pos)
		rl.DrawLine3D(a, b, rl.Color{95, 255, 130, 255})
	}
	if ed.knife_has_hover && len(ed.knife_nodes) > 0 {
		last := rl.Vector3(ed.knife_nodes[len(ed.knife_nodes) - 1].pos)
		rl.DrawLine3D(last, rl.Vector3(ed.knife_hover.pos), rl.Color{160, 255, 180, 200})
	}
	rlgl.EnableDepthTest()
}

@(private)
draw_gizmo_3d :: proc() {
	ed := &app.editor
	pivot, ok := editor_posed_selection_center()
	if !ok { return }
	world_len := editor_world_per_px() * 72.0
	rlgl.DisableDepthTest()
	for axis in 0..<3 {
		col := GIZMO_COLORS[axis]
		if ed.gizmo_hover == axis || ed.gizmo_drag_axis == axis {
			col = rl.Color{255, 235, 125, 255}
		}
		tip := pivot + GIZMO_AXES[axis] * world_len
		rl.DrawLine3D(pivot, tip, col)
		rl.DrawCylinderEx(pivot + GIZMO_AXES[axis] * (world_len * 0.80), tip, world_len * 0.08, 0, 8, col)
	}
	rlgl.EnableDepthTest()
}

editor_draw_overlays_2d :: proc() {
	ed := &app.editor
	if !ed.mesh_loaded { return }
	vp := editor_viewport_rect()
	rl.BeginScissorMode(i32(vp.x), i32(vp.y), i32(vp.width), i32(vp.height))
	defer rl.EndScissorMode()

	if ed.mesh.mode == .Vertex {
		view_dir := rl.Vector3Normalize(ed.camera.position - ed.camera.target)
		for &v, vi in ed.mesh.verts {
			p := editor_posed_vert_pos(vi)
			sp := rl.GetWorldToScreen(p, ed.camera)
			if !rl.CheckCollisionPointRec(sp, vp) { continue }
			if v.selected {
				rl.DrawRectangle(i32(sp.x) - 2, i32(sp.y) - 2, 4, 4, rl.Color{255, 205, 64, 255})
			} else if vi == ed.hover_vert {
				rl.DrawCircleLines(i32(sp.x), i32(sp.y), 5, rl.Color{110, 232, 255, 255})
			} else if ed.xray_mode || rl.Vector3DotProduct(rl.Vector3(v.nrm), view_dir) > -0.05 {
				rl.DrawRectangle(i32(sp.x) - 1, i32(sp.y) - 1, 2, 2, rl.Color{160, 190, 165, 95})
			}
		}
	}
	if ed.tool == .Knife || (ed.modal_active && ed.modal_op == .Knife) {
		for node in ed.knife_nodes {
			sp := rl.GetWorldToScreen(rl.Vector3(node.pos), ed.camera)
			rl.DrawRectangle(i32(sp.x) - 3, i32(sp.y) - 3, 7, 7, rl.Color{95, 255, 130, 255})
		}
		if ed.knife_has_hover {
			sp := rl.GetWorldToScreen(rl.Vector3(ed.knife_hover.pos), ed.camera)
			rl.DrawRectangleLines(i32(sp.x) - 5, i32(sp.y) - 5, 10, 10, rl.Color{115, 255, 150, 255})
		}
	}
	if ed.box_active {
		mouse := input_mouse_pos()
		rect := rl.Rectangle{
			x = min(ed.box_start.x, mouse.x), y = min(ed.box_start.y, mouse.y),
			width = abs(mouse.x - ed.box_start.x), height = abs(mouse.y - ed.box_start.y),
		}
		rl.DrawRectangleRec(rect, rl.Color{227, 201, 138, 30})
		rl.DrawRectangleLinesEx(rect, 1, rl.Color{227, 201, 138, 230})
	}
}
