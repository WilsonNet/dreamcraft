// Playwright-style positive/negative assertions and mesh inspection stats.
package mesh_cli

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import edit "../../client/art/edit"
import spec "../../client/art/spec"

Assert_Result :: struct {
	expr:          string,
	expected_pass: bool,
	actual_pass:   bool,
	passed:        bool,
	detail:        string,
}

Mesh_Stats :: struct {
	verts, edges, faces, quads, tris: int,
	min_p, max_p:                     [3]f32,
	max_r, radius:                    f32,
	bones:                            [spec.Bone_Id.COUNT]bool,
	mats:                             [spec.Mat_Kind.COUNT]bool,
	groups:                           [dynamic]u16,
}

parse_mat_name :: proc(raw: string) -> (spec.Mat_Kind, bool) {
	clean := strings.trim_prefix(strings.trim_space(raw), ".")
	return spec.mat_from_name(clean)
}

parse_bone_name :: proc(raw: string) -> (spec.Bone_Id, bool) {
	clean := strings.trim_prefix(strings.trim_space(raw), ".")
	return spec.bone_from_name(clean)
}

parse_f32_exact :: proc(s: string) -> (f32, bool) {
	v, ok := strconv.parse_f32(strings.trim_space(s))
	if !ok || !is_finite_f32(v) { return 0, false }
	return v, true
}

json_write_str :: proc(sb: ^strings.Builder, s: string) {
	strings.write_byte(sb, '"')
	for i in 0..<len(s) {
		ch := s[i]
		switch ch {
		case '"':  strings.write_string(sb, `\"`)
		case '\\': strings.write_string(sb, `\\`)
		case '\n': strings.write_string(sb, `\n`)
		case '\r': strings.write_string(sb, `\r`)
		case '\t': strings.write_string(sb, `\t`)
		case:      strings.write_byte(sb, ch)
		}
	}
	strings.write_byte(sb, '"')
}

assert_result_delete :: proc(r: ^Assert_Result) {
	delete(r.expr)
	delete(r.detail)
	r^ = {}
}

assert_results_delete :: proc(list: ^[dynamic]Assert_Result) {
	for &r in list^ { assert_result_delete(&r) }
	delete(list^)
	list^ = nil
}

mesh_stats_delete :: proc(s: ^Mesh_Stats) {
	delete(s.groups)
	s^ = {}
}

compute_mesh_stats :: proc(em: ^edit.Edit_Mesh) -> Mesh_Stats {
	s := Mesh_Stats{
		verts = len(em.verts),
		edges = len(em.edges),
		faces = len(em.faces),
	}
	if len(em.verts) == 0 { return s }
	seen := make(map[u16]bool, 16, context.temp_allocator)
	s.min_p = {1e9, 1e9, 1e9}
	s.max_p = {-1e9, -1e9, -1e9}
	for v in em.verts {
		for k in 0..<3 {
			s.min_p[k] = min(s.min_p[k], v.pos[k])
			s.max_p[k] = max(s.max_p[k], v.pos[k])
		}
		s.max_r = max(s.max_r, math.sqrt(v.pos[0] * v.pos[0] + v.pos[2] * v.pos[2]))
		if int(v.bone) < int(spec.Bone_Id.COUNT) { s.bones[v.bone] = true }
		if !(v.group in seen) { seen[v.group] = true; append(&s.groups, v.group) }
	}
	center := edit.v3_scale(edit.v3_add(s.min_p, s.max_p), 0.5)
	for v in em.verts { s.radius = max(s.radius, edit.v3_len(edit.v3_sub(v.pos, center))) }
	for f in em.faces {
		if f.count == 4 { s.quads += 1 } else if f.count == 3 { s.tris += 1 }
		if int(f.mat) < int(spec.Mat_Kind.COUNT) { s.mats[f.mat] = true }
		if !(f.group in seen) { seen[f.group] = true; append(&s.groups, f.group) }
	}
	slice.sort(s.groups[:])
	return s
}

eval_assert :: proc(em: ^edit.Edit_Mesh, raw_expr: string) -> Assert_Result {
	trimmed := strings.trim_space(raw_expr)
	expected_pass := true
	inner := trimmed
	if strings.has_prefix(trimmed, "!") {
		expected_pass = false
		inner = strings.trim_space(trimmed[1:])
	}
	if len(inner) == 0 {
		return Assert_Result{
			expr = strings.clone(trimmed), expected_pass = expected_pass,
			detail = strings.clone("empty assertion expression"),
		}
	}
	actual, parse_ok, detail := eval_predicate(em, inner)
	return Assert_Result{
		expr          = strings.clone(trimmed),
		expected_pass = expected_pass,
		actual_pass   = actual,
		passed        = parse_ok && (actual == expected_pass),
		detail        = detail,
	}
}

@(private)
eval_predicate :: proc(em: ^edit.Edit_Mesh, expr: string) -> (actual: bool, parse_ok: bool, detail: string) {
	if expr == "manifold" {
		ok, msg := check_manifold(em)
		return ok, true, msg
	}
	if expr == "odin_valid" {
		ok, msg := check_odin_valid(em)
		return ok, true, msg
	}
	stats := compute_mesh_stats(em)
	defer mesh_stats_delete(&stats)
	if op_idx, op := find_cmp_op(expr); op_idx >= 0 {
		return eval_cmp_pred(em, &stats, expr[:op_idx], op, expr[op_idx + len(op):])
	}
	if eq_idx := strings.index_byte(expr, '='); eq_idx > 0 {
		return eval_eq_pred(em, &stats, expr[:eq_idx], expr[eq_idx + 1:])
	}
	return false, false, fmt.aprintf("unknown assertion '%s'", expr)
}

@(private)
find_cmp_op :: proc(s: string) -> (int, string) {
	for op in ([3]string{">=", "<=", "=="}) {
		if idx := strings.index(s, op); idx > 0 { return idx, op }
	}
	return -1, ""
}

@(private)
eval_cmp_pred :: proc(
	em: ^edit.Edit_Mesh,
	s: ^Mesh_Stats,
	lhs, op, rhs: string,
) -> (bool, bool, string) {
	if lhs == "verts" || lhs == "faces" || lhs == "quads" {
		target, ok := strconv.parse_int(strings.trim_space(rhs), 10)
		if !ok { return false, false, fmt.aprintf("invalid int '%s'", rhs) }
		val := lhs == "verts" ? s.verts : (lhs == "faces" ? s.faces : s.quads)
		pass := op == ">=" ? val >= target : (op == "<=" ? val <= target : val == target)
		return pass, true, fmt.aprintf("%s=%d (%s %d)", lhs, val, op, target)
	}
	if op == "==" { return false, false, fmt.aprintf("unsupported '==' on float metric '%s'", lhs) }
	target, f_ok := parse_f32_exact(rhs)
	if !f_ok { return false, false, fmt.aprintf("invalid float '%s'", rhs) }
	if len(em.verts) == 0 { return false, true, strings.clone("mesh has 0 verts") }
	val: f32
	switch lhs {
	case "min_y":  val = s.min_p[1]
	case "max_y":  val = s.max_p[1]
	case "height": val = s.max_p[1] - s.min_p[1]
	case "max_r":  val = s.max_r
	case:          return false, false, fmt.aprintf("unknown metric '%s'", lhs)
	}
	pass := op == ">=" ? val >= target : val <= target
	return pass, true, fmt.aprintf("%s=%.4f (%s %.4f)", lhs, val, op, target)
}

@(private)
eval_eq_pred :: proc(em: ^edit.Edit_Mesh, s: ^Mesh_Stats, lhs, rhs: string) -> (bool, bool, string) {
	switch lhs {
	case "has_bone":
		b, ok := parse_bone_name(rhs)
		if !ok { return false, false, fmt.aprintf("unknown bone '%s'", rhs) }
		return s.bones[b], true, fmt.aprintf("bone %s present=%v", spec.BONE_NAMES[b], s.bones[b])
	case "has_mat":
		m, ok := parse_mat_name(rhs)
		if !ok { return false, false, fmt.aprintf("unknown mat '%s'", rhs) }
		return s.mats[m], true, fmt.aprintf("mat %s present=%v", spec.MAT_NAMES[m], s.mats[m])
	case "not_has_mat":
		m, ok := parse_mat_name(rhs)
		if !ok { return false, false, fmt.aprintf("unknown mat '%s'", rhs) }
		return !s.mats[m], true, fmt.aprintf("mat %s absent=%v", spec.MAT_NAMES[m], !s.mats[m])
	case "mat_min_y", "mat_max_y":
		return eval_mat_y_pred(em, rhs, lhs == "mat_min_y")
	case "bone_min_y", "bone_max_y":
		return eval_bone_y_pred(em, rhs, lhs == "bone_min_y")
	}
	return false, false, fmt.aprintf("unknown predicate '%s'", lhs)
}

@(private)
eval_mat_y_pred :: proc(em: ^edit.Edit_Mesh, rhs: string, is_min: bool) -> (bool, bool, string) {
	colon := strings.index_byte(rhs, ':')
	if colon <= 0 { return false, false, fmt.aprintf("expected Mat:F, got '%s'", rhs) }
	mat, m_ok := parse_mat_name(rhs[:colon])
	thresh, f_ok := parse_f32_exact(rhs[colon + 1:])
	if !m_ok { return false, false, fmt.aprintf("unknown mat '%s'", rhs[:colon]) }
	if !f_ok { return false, false, fmt.aprintf("invalid float '%s'", rhs[colon + 1:]) }
	lo, hi, found := f32(1e9), f32(-1e9), false
	for &f in em.faces {
		if f.mat != mat { continue }
		for k in 0..<int(f.count) {
			y := em.verts[f.v[k]].pos[1]
			lo, hi, found = min(lo, y), max(hi, y), true
		}
	}
	if !found { return false, true, fmt.aprintf("mat %s not present", spec.MAT_NAMES[mat]) }
	val := is_min ? lo : hi
	pass := is_min ? (val >= thresh) : (val <= thresh)
	return pass, true, fmt.aprintf("%s %s=%.4f (thresh %.4f)", spec.MAT_NAMES[mat], is_min ? "min_y" : "max_y", val, thresh)
}

@(private)
eval_bone_y_pred :: proc(em: ^edit.Edit_Mesh, rhs: string, is_min: bool) -> (bool, bool, string) {
	colon := strings.index_byte(rhs, ':')
	if colon <= 0 { return false, false, fmt.aprintf("expected Bone:F, got '%s'", rhs) }
	bone, b_ok := parse_bone_name(rhs[:colon])
	thresh, f_ok := parse_f32_exact(rhs[colon + 1:])
	if !b_ok { return false, false, fmt.aprintf("unknown bone '%s'", rhs[:colon]) }
	if !f_ok { return false, false, fmt.aprintf("invalid float '%s'", rhs[colon + 1:]) }
	lo, hi, found := f32(1e9), f32(-1e9), false
	for &v in em.verts {
		if v.bone != bone { continue }
		lo, hi, found = min(lo, v.pos[1]), max(hi, v.pos[1]), true
	}
	if !found { return false, true, fmt.aprintf("bone %s not present", spec.BONE_NAMES[bone]) }
	val := is_min ? lo : hi
	pass := is_min ? (val >= thresh) : (val <= thresh)
	return pass, true, fmt.aprintf("%s %s=%.4f (thresh %.4f)", spec.BONE_NAMES[bone], is_min ? "min_y" : "max_y", val, thresh)
}

@(private)
check_manifold :: proc(em: ^edit.Edit_Mesh) -> (bool, string) {
	if em == nil || len(em.verts) == 0 || len(em.faces) == 0 {
		return false, strings.clone("empty mesh")
	}
	for &v, vi in em.verts {
		if !is_finite_v3(v.pos) || !is_finite_v3(v.nrm) || !is_finite_f32(v.ao) {
			return false, fmt.aprintf("vert %d has non-finite float", vi)
		}
		if int(v.bone) >= int(spec.Bone_Id.COUNT) {
			return false, fmt.aprintf("vert %d has invalid bone", vi)
		}
	}
	for &f, fi in em.faces {
		if ok, err := check_face_valid(em, &f, fi); !ok { return false, err }
	}
	return true, fmt.aprintf("manifold ok (%d verts, %d faces)", len(em.verts), len(em.faces))
}

@(private)
check_face_valid :: proc(em: ^edit.Edit_Mesh, f: ^edit.Edit_Face, fi: int) -> (bool, string) {
	c := int(f.count)
	if c != 3 && c != 4 { return false, fmt.aprintf("face %d invalid count %d", fi, c) }
	if int(f.mat) >= int(spec.Mat_Kind.COUNT) { return false, fmt.aprintf("face %d invalid mat", fi) }
	for a in 0..<c {
		if int(f.v[a]) >= len(em.verts) { return false, fmt.aprintf("face %d vert out of bounds", fi) }
		for b in a + 1..<c {
			if f.v[a] == f.v[b] { return false, fmt.aprintf("face %d duplicate vert", fi) }
		}
	}
	p0, p1, p2 := em.verts[f.v[0]].pos, em.verts[f.v[1]].pos, em.verts[f.v[2]].pos
	area_sq := edit.v3_len_sq(edit.v3_cross(edit.v3_sub(p1, p0), edit.v3_sub(p2, p0)))
	if c == 4 {
		p3 := em.verts[f.v[3]].pos
		area_sq += edit.v3_len_sq(edit.v3_cross(edit.v3_sub(p2, p0), edit.v3_sub(p3, p0)))
	}
	if area_sq <= 1e-13 { return false, fmt.aprintf("face %d zero area", fi) }
	return true, ""
}

@(private)
check_odin_valid :: proc(em: ^edit.Edit_Mesh) -> (bool, string) {
	if em == nil || len(em.id) == 0 { return false, strings.clone("empty model id") }
	tmp, tmp_err := os.make_directory_temp("", "mesh_cli_odin_", context.allocator)
	if tmp_err != nil { return false, strings.clone("temp dir creation failed") }
	defer { _ = os.remove_all(tmp); delete(tmp) }
	dir, save_ok := edit.edit_mesh_save_odin(em, tmp)
	if !save_ok { return false, strings.clone("edit_mesh_save_odin failed") }
	defer delete(dir)
	rt, load_ok := edit.edit_mesh_load_odin_dir(dir)
	if !load_ok { return false, strings.clone("edit_mesh_load_odin_dir failed") }
	defer edit.edit_mesh_delete(&rt)
	if len(rt.verts) != len(em.verts) || len(rt.faces) != len(em.faces) {
		return false, fmt.aprintf("roundtrip count mismatch (%d/%d vs %d/%d)", len(rt.verts), len(rt.faces), len(em.verts), len(em.faces))
	}
	return true, fmt.aprintf("odin_valid ok (%d verts, %d faces)", len(rt.verts), len(rt.faces))
}

write_assert_results_json :: proc(sb: ^strings.Builder, results: []Assert_Result) {
	strings.write_byte(sb, '[')
	for r, i in results {
		if i > 0 { strings.write_byte(sb, ',') }
		strings.write_string(sb, `{"expr":`)
		json_write_str(sb, r.expr)
		fmt.sbprintf(sb, `,"expected_pass":%v,"actual_pass":%v,"passed":%v,"detail":`, r.expected_pass, r.actual_pass, r.passed)
		json_write_str(sb, r.detail)
		strings.write_byte(sb, '}')
	}
	strings.write_byte(sb, ']')
}

print_assert_results_text :: proc(results: []Assert_Result) {
	for r in results {
		tag := r.passed ? "PASS" : "FAIL"
		fmt.printfln("  [%s] %s (expected=%v actual=%v) - %s", tag, r.expr, r.expected_pass, r.actual_pass, r.detail)
	}
}

print_active_bones :: proc(s: ^Mesh_Stats) {
	fmt.print("bones:")
	for present, i in s.bones { if present { fmt.printf(" %s", spec.BONE_NAMES[spec.Bone_Id(i)]) } }
	fmt.println("")
}

print_active_mats :: proc(s: ^Mesh_Stats) {
	fmt.print("mats:")
	for present, i in s.mats { if present { fmt.printf(" %s", spec.MAT_NAMES[spec.Mat_Kind(i)]) } }
	fmt.println("")
}

build_info_json :: proc(sb: ^strings.Builder, em: ^edit.Edit_Mesh, s: ^Mesh_Stats) {
	fmt.sbprintf(sb, `{{"id":"%s","verts":%d,"edges":%d,"faces":%d,"quads":%d,"tris":%d,"min":[%.4f,%.4f,%.4f],"max":[%.4f,%.4f,%.4f],"max_r":%.4f,"radius":%.4f,"groups":[`,
		em.id, s.verts, s.edges, s.faces, s.quads, s.tris, s.min_p[0], s.min_p[1], s.min_p[2], s.max_p[0], s.max_p[1], s.max_p[2], s.max_r, s.radius)
	for g, i in s.groups { if i > 0 { strings.write_byte(sb, ',') }; fmt.sbprintf(sb, "%d", g) }
	strings.write_string(sb, `],"bones":[`)
	first := true
	for p, i in s.bones {
		if !p { continue }
		if !first { strings.write_byte(sb, ',') }; first = false
		json_write_str(sb, spec.BONE_NAMES[spec.Bone_Id(i)])
	}
	strings.write_string(sb, `],"mats":[`)
	first = true
	for p, i in s.mats {
		if !p { continue }
		if !first { strings.write_byte(sb, ',') }; first = false
		json_write_str(sb, spec.MAT_NAMES[spec.Mat_Kind(i)])
	}
	strings.write_string(sb, "]}")
}

print_info_json :: proc(em: ^edit.Edit_Mesh, s: ^Mesh_Stats) {
	sb := strings.builder_make(); defer strings.builder_destroy(&sb)
	build_info_json(&sb, em, s)
	fmt.println(strings.to_string(sb))
}
