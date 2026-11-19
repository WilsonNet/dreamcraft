// Cooperative mesh editing tokenizer and operator dispatcher.
package mesh_cli

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"
import edit "../../client/art/edit"
import spec "../../client/art/spec"

split_op_batch :: proc(script: string, allocator := context.allocator) -> [dynamic]string {
	out := make([dynamic]string, allocator)
	lines := strings.split_multi(script, {"\n", "\r", ";"})
	defer delete(lines)
	for raw in lines {
		t := strings.trim_space(raw)
		if len(t) == 0 || strings.has_prefix(t, "#") { continue }
		append(&out, normalize_op_line(t, allocator))
	}
	return out
}

@(private)
normalize_op_line :: proc(line: string, allocator := context.allocator) -> string {
	fields := strings.fields(line)
	defer delete(fields)
	if len(fields) <= 1 { return strings.clone(line, allocator) }
	if fields[0] == "expect" || fields[0] == "assert" {
		rest := strings.join(fields[1:], " ")
		defer delete(rest)
		return fmt.aprintf("%s:%s", fields[0], rest, allocator = allocator)
	}
	return strings.join(fields[:], ":", allocator)
}

run_cli_ops :: proc(
	em: ^edit.Edit_Mesh,
	tokens: []string,
	report: ^[dynamic]Assert_Result = nil,
) -> (changed: bool, err: string) {
	if em == nil { return false, strings.clone("nil mesh") }
	for i := 0; i < len(tokens); i += 1 {
		tok := strings.trim_space(tokens[i])
		if (tok == "assert" || tok == "expect") && i + 1 < len(tokens) {
			if e := exec_inline_assert(em, tokens[i + 1], report); e != "" { return changed, e }
			i += 1
			continue
		}
		expanded := split_op_batch(tok)
		defer { for s in expanded { delete(s) }; delete(expanded) }
		for op in expanded {
			op_chg, op_err := exec_single_op(em, op, report)
			if op_chg { changed = true }
			if op_err != "" { return changed, op_err }
		}
	}
	return changed, ""
}

@(private)
exec_inline_assert :: proc(em: ^edit.Edit_Mesh, expr: string, report: ^[dynamic]Assert_Result) -> string {
	res := eval_assert(em, expr)
	msg := res.passed ? "" : fmt.aprintf("assertion '%s' failed: %s", res.expr, res.detail)
	if report != nil { append(report, res) } else { assert_result_delete(&res) }
	return msg
}

@(private)
exec_single_op :: proc(em: ^edit.Edit_Mesh, tok: string, report: ^[dynamic]Assert_Result) -> (bool, string) {
	op, rest := tok, ""
	if colon := strings.index_byte(tok, ':'); colon >= 0 { op, rest = tok[:colon], tok[colon + 1:] }
	if op == "expect" || op == "assert" {
		if rest == "" { return false, strings.clone("empty assertion in expect") }
		return false, exec_inline_assert(em, rest, report)
	}
	if strings.has_prefix(op, "select-") { return false, exec_select_op(em, op, rest) }
	if strings.has_prefix(op, "add-") { return exec_add_op(em, op, rest) }
	if op == "translate" || op == "rotate" || op == "scale" || op == "snap-ground" || strings.has_prefix(op, "set-") {
		return exec_xform_paint_op(em, op, rest)
	}
	return exec_topo_op(em, op, rest)
}

parse_f32_list :: proc(s: string, out: []f32) -> bool {
	parts := strings.split(s, ",")
	defer delete(parts)
	if len(parts) != len(out) { return false }
	for p, i in parts {
		v, ok := parse_f32_exact(p)
		if !ok { return false }
		out[i] = v
	}
	return true
}

parse_bool_val :: proc(s: string) -> (bool, bool) {
	switch strings.trim_space(s) {
	case "true", "1", "yes":  return true, true
	case "false", "0", "no":  return false, true
	}
	return false, false
}

@(private)
parse_axis_lock :: proc(s: string) -> (edit.Axis_Lock, bool) {
	switch strings.trim_space(s) {
	case "X", "x":   return .X, true
	case "Y", "y":   return .Y, true
	case "Z", "z":   return .Z, true
	case "XY", "xy": return .XY, true
	case "XZ", "xz": return .XZ, true
	case "YZ", "yz": return .YZ, true
	}
	return .None, false
}

@(private)
exec_select_op :: proc(em: ^edit.Edit_Mesh, op, rest: string) -> string {
	switch op {
	case "select-all":    edit.edit_mesh_select_all(em); return ""
	case "select-none":   edit.edit_mesh_deselect_all(em); return ""
	case "select-invert": edit.edit_mesh_invert_selection(em); return ""
	case "select-mode":
		mode: edit.Select_Mode
		switch strings.trim_space(rest) {
		case "Vertex", "vertex", "vert": mode = .Vertex
		case "Edge", "edge":             mode = .Edge
		case "Face", "face":             mode = .Face
		case: return fmt.aprintf("invalid select-mode '%s'", rest)
		}
		edit.edit_mesh_set_mode(em, mode)
		return ""
	case "select-bone":
		b, ok := parse_bone_name(rest)
		if !ok { return fmt.aprintf("unknown bone '%s'", rest) }
		edit.edit_mesh_select_same_bone(em, b)
		return ""
	case "select-linked":
		seed := -1
		if rest != "" {
			v, ok := strconv.parse_int(rest, 10)
			if !ok || v < 0 || v >= len(em.verts) { return fmt.aprintf("invalid vert_idx '%s'", rest) }
			seed = v
		}
		edit.edit_mesh_select_linked(em, seed)
		return ""
	}
	return exec_select_filter(em, op, rest)
}

@(private)
exec_select_filter :: proc(em: ^edit.Edit_Mesh, op, rest: string) -> string {
	switch op {
	case "select-mat":
		m, ok := parse_mat_name(rest)
		if !ok { return fmt.aprintf("unknown mat '%s'", rest) }
		select_by_mat(em, m); return ""
	case "select-group":
		g, ok := strconv.parse_int(rest, 10)
		if !ok || g < 0 || g > 65535 { return fmt.aprintf("invalid group '%s'", rest) }
		select_by_group(em, u16(g)); return ""
	case "select-above", "select-below":
		y, ok := parse_f32_exact(rest)
		if !ok { return fmt.aprintf("invalid y '%s'", rest) }
		lo := op == "select-above" ? [3]f32{-1e9, y, -1e9} : [3]f32{-1e9, -1e9, -1e9}
		hi := op == "select-above" ? [3]f32{1e9, 1e9, 1e9} : [3]f32{1e9, y, 1e9}
		select_in_box(em, lo, hi); return ""
	case "select-box":
		c: [6]f32
		if !parse_f32_list(rest, c[:]) { return fmt.aprintf("expected 6 floats in select-box, got '%s'", rest) }
		select_in_box(em, {min(c[0], c[3]), min(c[1], c[4]), min(c[2], c[5])}, {max(c[0], c[3]), max(c[1], c[4]), max(c[2], c[5])})
		return ""
	}
	return fmt.aprintf("unknown select op '%s'", op)
}

@(private)
select_by_mat :: proc(em: ^edit.Edit_Mesh, mat: spec.Mat_Kind) {
	edit.edit_mesh_deselect_all(em)
	switch em.mode {
	case .Face: for &f in em.faces { f.selected = (f.mat == mat) }
	case .Vertex:
		for &f in em.faces {
			if f.mat != mat { continue }
			for k in 0..<int(f.count) { em.verts[f.v[k]].selected = true }
		}
	case .Edge:
		for &e in em.edges {
			for k in 0..<int(e.face_len) { if em.faces[e.faces[k]].mat == mat { e.selected = true; break } }
		}
	}
}

@(private)
select_by_group :: proc(em: ^edit.Edit_Mesh, grp: u16) {
	edit.edit_mesh_deselect_all(em)
	switch em.mode {
	case .Vertex: for &v in em.verts { v.selected = (v.group == grp) }
	case .Face:   for &f in em.faces { f.selected = (f.group == grp) }
	case .Edge:   for &e in em.edges { e.selected = (em.verts[e.a].group == grp && em.verts[e.b].group == grp) }
	}
}

@(private)
select_in_box :: proc(em: ^edit.Edit_Mesh, lo, hi: [3]f32) {
	in_box :: proc(p, lo, hi: [3]f32) -> bool {
		return p[0] >= lo[0] && p[0] <= hi[0] && p[1] >= lo[1] && p[1] <= hi[1] && p[2] >= lo[2] && p[2] <= hi[2]
	}
	edit.edit_mesh_deselect_all(em)
	switch em.mode {
	case .Vertex: for &v in em.verts { v.selected = in_box(v.pos, lo, hi) }
	case .Face:   for &f, fi in em.faces { f.selected = in_box(edit.edit_mesh_face_center(em, fi), lo, hi) }
	case .Edge:   for &e in em.edges { e.selected = in_box(edit.v3_scale(edit.v3_add(em.verts[e.a].pos, em.verts[e.b].pos), 0.5), lo, hi) }
	}
}

@(private)
exec_xform_paint_op :: proc(em: ^edit.Edit_Mesh, op, rest: string) -> (bool, string) {
	switch op {
	case "translate":   return exec_translate(em, rest)
	case "rotate":      return exec_rotate(em, rest)
	case "scale":       return exec_scale(em, rest)
	case "snap-ground": return edit.edit_snap_to_ground(em), ""
	case "set-mat":
		m, ok := parse_mat_name(rest); if !ok { return false, fmt.aprintf("unknown mat '%s'", rest) }
		return edit.edit_set_selected_mat(em, m), ""
	case "set-bone":
		b, ok := parse_bone_name(rest); if !ok { return false, fmt.aprintf("unknown bone '%s'", rest) }
		return edit.edit_set_selected_bone(em, b), ""
	case "set-smooth":
		sm, ok := parse_bool_val(rest); if !ok { return false, fmt.aprintf("invalid bool '%s'", rest) }
		return edit.edit_set_selected_smooth(em, sm), ""
	case "set-group":
		g, ok := strconv.parse_int(rest, 10); if !ok || g < 0 || g > 65535 { return false, fmt.aprintf("invalid group '%s'", rest) }
		return apply_set_group(em, u16(g)), ""
	}
	return false, fmt.aprintf("unknown op '%s'", op)
}

@(private)
apply_set_group :: proc(em: ^edit.Edit_Mesh, grp: u16) -> bool {
	mask := edit.edit_mesh_selected_verts_mask(em)
	changed := false
	for sel, i in mask { if sel { em.verts[i].group = grp; changed = true } }
	for &f in em.faces {
		all_in := em.mode == .Face ? f.selected : true
		if em.mode != .Face { for k in 0..<int(f.count) { if !mask[f.v[k]] { all_in = false; break } } }
		if all_in { f.group = grp; changed = true }
	}
	if changed { em.dirty = true }
	return changed
}

@(private)
parse_xform_tail :: proc(opts: []string, pivot: ^[3]f32, lock: ^edit.Axis_Lock, mirror: ^bool, allow_axis, allow_pivot: bool) -> string {
	for p in opts {
		if p == "mirror" || p == "mirror=true" {
			mirror^ = true
		} else if allow_pivot && strings.has_prefix(p, "pivot=") {
			if !parse_f32_list(p[6:], pivot[:]) { return fmt.aprintf("invalid pivot '%s'", p) }
		} else if allow_axis && strings.has_prefix(p, "axis=") {
			ok: bool
			if lock^, ok = parse_axis_lock(p[5:]); !ok { return fmt.aprintf("invalid axis '%s'", p) }
		} else {
			return fmt.aprintf("unknown transform option '%s'", p)
		}
	}
	return ""
}

@(private)
exec_translate :: proc(em: ^edit.Edit_Mesh, rest: string) -> (bool, string) {
	parts := strings.split(rest, ":"); defer delete(parts)
	if len(parts) < 1 || parts[0] == "" { return false, strings.clone("translate requires dx,dy,dz") }
	delta, unused_pv: [3]f32; unused_lk: edit.Axis_Lock; mirror := false
	if !parse_f32_list(parts[0], delta[:]) { return false, fmt.aprintf("invalid delta '%s'", parts[0]) }
	if err := parse_xform_tail(parts[1:], &unused_pv, &unused_lk, &mirror, false, false); err != "" { return false, err }
	base := edit.edit_snapshot_positions(em); defer delete(base)
	edit.edit_translate_from_base(em, base, delta, .None, mirror)
	return true, ""
}

@(private)
exec_rotate :: proc(em: ^edit.Edit_Mesh, rest: string) -> (bool, string) {
	parts := strings.split(rest, ":"); defer delete(parts)
	if len(parts) < 2 { return false, strings.clone("rotate requires axis:deg") }
	axis: [3]f32
	switch parts[0] {
	case "X", "x": axis = {1, 0, 0}
	case "Y", "y": axis = {0, 1, 0}
	case "Z", "z": axis = {0, 0, 1}
	case: if !parse_f32_list(parts[0], axis[:]) || edit.v3_len_sq(axis) < 1e-8 { return false, fmt.aprintf("invalid axis '%s'", parts[0]) }
	}
	deg, d_ok := parse_f32_exact(parts[1])
	if !d_ok { return false, fmt.aprintf("invalid angle '%s'", parts[1]) }
	pivot, _ := edit.edit_selection_center(em); unused_lk: edit.Axis_Lock; mirror := false
	if err := parse_xform_tail(parts[2:], &pivot, &unused_lk, &mirror, false, true); err != "" { return false, err }
	base := edit.edit_snapshot_positions(em); defer delete(base)
	edit.edit_rotate_from_base(em, base, pivot, axis, deg * math.PI / 180.0, mirror)
	return true, ""
}

@(private)
exec_scale :: proc(em: ^edit.Edit_Mesh, rest: string) -> (bool, string) {
	parts := strings.split(rest, ":"); defer delete(parts)
	if len(parts) < 1 || parts[0] == "" { return false, strings.clone("scale requires factor") }
	factor, ok := parse_f32_exact(parts[0])
	if !ok { return false, fmt.aprintf("invalid scale factor '%s'", parts[0]) }
	pivot, _ := edit.edit_selection_center(em); lock := edit.Axis_Lock.None; mirror := false
	if err := parse_xform_tail(parts[1:], &pivot, &lock, &mirror, true, true); err != "" { return false, err }
	base := edit.edit_snapshot_positions(em); defer delete(base)
	edit.edit_scale_from_base(em, base, pivot, factor, lock, mirror)
	return true, ""
}

@(private)
exec_topo_op :: proc(em: ^edit.Edit_Mesh, op, rest: string) -> (bool, string) {
	switch op {
	case "extrude":
		dist := f32(0)
		if rest != "" { ok: bool; if dist, ok = parse_f32_exact(rest); !ok { return false, fmt.aprintf("invalid extrude dist '%s'", rest) } }
		nrm, ok := edit.edit_extrude(em); if !ok { return false, strings.clone("extrude failed: nothing selected") }
		if abs(dist) > 1e-7 {
			base := edit.edit_snapshot_positions(em); defer delete(base)
			edit.edit_translate_from_base(em, base, edit.v3_scale(nrm, dist), .None, false)
		}
		return true, ""
	case "inset":
		factor := f32(0.25)
		if rest != "" { ok: bool; if factor, ok = parse_f32_exact(rest); !ok { return false, fmt.aprintf("invalid inset factor '%s'", rest) } }
		if !edit.edit_inset(em, factor) { return false, strings.clone("inset failed: no faces selected") }
		return true, ""
	case "fill":
		if !edit.edit_fill(em) { return false, strings.clone("fill failed: select 2, 3, or 4 vertices") }
		return true, ""
	case "loop-cut": return exec_loop_cut(em, rest)
	case "merge":
		if rest == "center" {
			if !edit.edit_merge_center(em) { return false, strings.clone("merge center failed: select >=2 verts") }
			return true, ""
		}
		dist := f32(0.002)
		if rest != "" { ok: bool; if dist, ok = parse_f32_exact(rest); !ok || dist < 0 { return false, fmt.aprintf("invalid merge dist '%s'", rest) } }
		return edit.edit_merge_by_distance(em, dist) > 0, ""
	case "delete":
		if rest != "verts" && rest != "edges" && rest != "faces" { return false, fmt.aprintf("invalid delete target '%s'", rest) }
		ok := rest == "verts" ? edit.edit_delete_verts(em) : (rest == "edges" ? edit.edit_delete_edges(em) : edit.edit_delete_faces(em))
		if !ok { return false, fmt.aprintf("delete %s failed: nothing selected", rest) }
		return true, ""
	}
	return false, fmt.aprintf("unknown op '%s'", op)
}

@(private)
exec_loop_cut :: proc(em: ^edit.Edit_Mesh, rest: string) -> (bool, string) {
	parts := strings.split(rest, ":"); defer delete(parts)
	if len(parts) < 1 || parts[0] == "" { return false, strings.clone("loop-cut requires edge_idx") }
	edge_idx, ok := strconv.parse_int(parts[0], 10)
	if !ok || edge_idx < 0 || edge_idx >= len(em.edges) { return false, fmt.aprintf("invalid edge_idx '%s'", parts[0]) }
	cuts, slide := 1, f32(0)
	for p, pi in parts[1:] {
		if strings.has_prefix(p, "cuts=") {
			if v, c_ok := strconv.parse_int(p[5:], 10); c_ok { cuts = v } else { return false, fmt.aprintf("invalid cuts '%s'", p) }
		} else if strings.has_prefix(p, "slide=") {
			if v, s_ok := parse_f32_exact(p[6:]); s_ok { slide = v } else { return false, fmt.aprintf("invalid slide '%s'", p) }
		} else if pi == 0 {
			if v, c_ok := strconv.parse_int(p, 10); c_ok { cuts = v } else { return false, fmt.aprintf("invalid cuts '%s'", p) }
		} else if pi == 1 {
			if v, s_ok := parse_f32_exact(p); s_ok { slide = v } else { return false, fmt.aprintf("invalid slide '%s'", p) }
		} else { return false, fmt.aprintf("unexpected loop-cut arg '%s'", p) }
	}
	if !edit.edit_apply_loop_cut(em, edge_idx, cuts, slide) { return false, strings.clone("loop-cut failed") }
	return true, ""
}
