// Editable quad/tri primitive additions directly into Edit_Mesh and add-* CLI ops.
package mesh_cli

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"
import edit "../../client/art/edit"
import spec "../../client/art/spec"

is_finite_f32 :: proc(v: f32) -> bool { return !math.is_nan(v) && !math.is_inf(v) }
is_finite_v3 :: proc(v: [3]f32) -> bool { return is_finite_f32(v[0]) && is_finite_f32(v[1]) && is_finite_f32(v[2]) }

@(private)
append_prim_vert :: proc(em: ^edit.Edit_Mesh, pos: [3]f32, bone: spec.Bone_Id, group: u16) -> u32 {
	idx := u32(len(em.verts))
	append(&em.verts, edit.Edit_Vert{pos = pos, nrm = {0, 1, 0}, bone = bone, ao = 1.0, group = group, selected = true})
	return idx
}

@(private)
append_prim_tri :: proc(em: ^edit.Edit_Mesh, a, b, c: u32, mat: spec.Mat_Kind, smooth: bool, group: u16) {
	append(&em.faces, edit.Edit_Face{v = {a, b, c, 0}, count = 3, mat = mat, smooth = smooth, group = group, selected = true})
}

@(private)
append_prim_quad :: proc(em: ^edit.Edit_Mesh, a, b, c, d: u32, mat: spec.Mat_Kind, smooth: bool, group: u16) {
	append(&em.faces, edit.Edit_Face{v = {a, b, c, d}, count = 4, mat = mat, smooth = smooth, group = group, selected = true})
}

@(private)
finish_prim_add :: proc(em: ^edit.Edit_Mesh, start_v: int) {
	edit.edit_mesh_rebuild_topology(em)
	if em.mode == .Edge {
		for &e in em.edges { if int(e.a) >= start_v && int(e.b) >= start_v { e.selected = true } }
	}
	em.dirty = true
}

add_box :: proc(em: ^edit.Edit_Mesh, center, size: [3]f32, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0) -> bool {
	if em == nil || !is_finite_v3(center) || !is_finite_v3(size) { return false }
	if size[0] <= 1e-5 || size[1] <= 1e-5 || size[2] <= 1e-5 { return false }
	edit.edit_mesh_deselect_all(em)
	start_v := len(em.verts)
	h := edit.v3_scale(size, 0.5)
	corners := [8][3]f32 {
		{-h[0], -h[1], h[2]}, {h[0], -h[1], h[2]}, {h[0], h[1], h[2]}, {-h[0], h[1], h[2]},
		{-h[0], -h[1], -h[2]}, {h[0], -h[1], -h[2]}, {h[0], h[1], -h[2]}, {-h[0], h[1], -h[2]},
	}
	vidx: [8]u32
	for c, i in corners { vidx[i] = append_prim_vert(em, edit.v3_add(center, c), bone, group) }
	quads := [6][4]int{{0, 1, 2, 3}, {5, 4, 7, 6}, {1, 5, 6, 2}, {4, 0, 3, 7}, {3, 2, 6, 7}, {4, 5, 1, 0}}
	for q in quads { append_prim_quad(em, vidx[q[0]], vidx[q[1]], vidx[q[2]], vidx[q[3]], mat, false, group) }
	finish_prim_add(em, start_v)
	return true
}

@(private)
Lathe_Ring_Ref :: struct { base: u32, is_pole: bool }

@(private)
emit_lathe_rings :: proc(em: ^edit.Edit_Mesh, center: [3]f32, rings: [][2]f32, segs: int, bone: spec.Bone_Id, group: u16) -> []Lathe_Ring_Ref {
	refs := make([]Lathe_Ring_Ref, len(rings), context.temp_allocator)
	for r, ri in rings {
		y := center[1] + r[1]
		if r[0] <= 1e-5 {
			refs[ri] = {base = append_prim_vert(em, {center[0], y, center[2]}, bone, group), is_pole = true}
			continue
		}
		base := u32(len(em.verts))
		for s in 0..<segs {
			a := f32(s) * math.TAU / f32(segs)
			_ = append_prim_vert(em, {center[0] + math.cos(a) * r[0], y, center[2] + math.sin(a) * r[0]}, bone, group)
		}
		refs[ri] = {base = base, is_pole = false}
	}
	return refs
}

@(private)
emit_lathe_band :: proc(em: ^edit.Edit_Mesh, r0, r1: Lathe_Ring_Ref, segs: int, mat: spec.Mat_Kind, smooth: bool, group: u16) {
	if r0.is_pole && r1.is_pole { return }
	for s in 0..<segs {
		s1 := (s + 1) % segs
		if r0.is_pole {
			append_prim_tri(em, r0.base, r1.base + u32(s), r1.base + u32(s1), mat, smooth, group)
		} else if r1.is_pole {
			append_prim_tri(em, r0.base + u32(s), r1.base, r0.base + u32(s1), mat, smooth, group)
		} else {
			append_prim_quad(em, r0.base + u32(s), r1.base + u32(s), r1.base + u32(s1), r0.base + u32(s1), mat, smooth, group)
		}
	}
}

@(private)
emit_lathe_cap :: proc(em: ^edit.Edit_Mesh, center: [3]f32, ring: [2]f32, ref: Lathe_Ring_Ref, segs: int, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16, up: bool) {
	if ref.is_pole { return }
	c_idx := append_prim_vert(em, {center[0], center[1] + ring[1], center[2]}, bone, group)
	for s in 0..<segs {
		s1 := (s + 1) % segs
		v0, v1 := ref.base + u32(s), ref.base + u32(s1)
		append_prim_tri(em, c_idx, up ? v1 : v0, up ? v0 : v1, mat, false, group)
	}
}

add_lathe :: proc(
	em: ^edit.Edit_Mesh, center: [3]f32, rings: [][2]f32, segs: int,
	mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0,
	cap_bot := true, cap_top := true, smooth := true,
) -> bool {
	if em == nil || len(rings) < 2 || segs < 3 || !is_finite_v3(center) { return false }
	for r in rings { if !is_finite_f32(r[0]) || !is_finite_f32(r[1]) || r[0] < 0 { return false } }
	edit.edit_mesh_deselect_all(em)
	start_v, start_f := len(em.verts), len(em.faces)
	refs := emit_lathe_rings(em, center, rings, segs, bone, group)
	for i in 0..<len(rings) - 1 {
		dr, dy := rings[i + 1][0] - rings[i][0], rings[i + 1][1] - rings[i][1]
		if dr * dr + dy * dy > 1e-10 { emit_lathe_band(em, refs[i], refs[i + 1], segs, mat, smooth, group) }
	}
	if cap_bot { emit_lathe_cap(em, center, rings[0], refs[0], segs, mat, bone, group, false) }
	if cap_top {
		last := len(rings) - 1
		emit_lathe_cap(em, center, rings[last], refs[last], segs, mat, bone, group, true)
	}
	if len(em.faces) == start_f { resize(&em.verts, start_v); return false }
	finish_prim_add(em, start_v)
	return true
}

add_cone :: proc(em: ^edit.Edit_Mesh, center: [3]f32, radius, height: f32, segs: int, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0) -> bool {
	if radius <= 1e-5 || height <= 1e-5 { return false }
	rings := [2][2]f32{{radius, 0}, {0, height}}
	return add_lathe(em, center, rings[:], segs, mat, bone, group, true, false, true)
}

add_cylinder :: proc(em: ^edit.Edit_Mesh, center: [3]f32, r0, r1, height: f32, segs: int, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0) -> bool {
	if r0 < 0 || r1 < 0 || (r0 <= 1e-5 && r1 <= 1e-5) || height <= 1e-5 { return false }
	rings := [2][2]f32{{r0, 0}, {r1, height}}
	return add_lathe(em, center, rings[:], segs, mat, bone, group, r0 > 1e-5, r1 > 1e-5, true)
}

add_ellipsoid :: proc(em: ^edit.Edit_Mesh, center, radii: [3]f32, segs, rings: int, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0) -> bool {
	if em == nil || segs < 3 || rings < 2 || !is_finite_v3(center) || !is_finite_v3(radii) { return false }
	if radii[0] <= 1e-5 || radii[1] <= 1e-5 || radii[2] <= 1e-5 { return false }
	profile := make([][2]f32, rings + 1, context.temp_allocator)
	for r in 0..=rings {
		v := -math.PI * 0.5 + f32(r) * math.PI / f32(rings)
		profile[r] = {max(f32(0), math.cos(v)), radii[1] * math.sin(v)}
	}
	start_v := len(em.verts)
	if !add_lathe(em, center, profile, segs, mat, bone, group, false, false, true) { return false }
	for i in start_v..<len(em.verts) {
		em.verts[i].pos[0] = center[0] + (em.verts[i].pos[0] - center[0]) * radii[0]
		em.verts[i].pos[2] = center[2] + (em.verts[i].pos[2] - center[2]) * radii[2]
	}
	edit.edit_mesh_update_normals(em)
	return true
}

add_torus :: proc(em: ^edit.Edit_Mesh, center: [3]f32, ring_r, tube_r: f32, segs, tube_segs: int, mat: spec.Mat_Kind, bone: spec.Bone_Id, group: u16 = 0) -> bool {
	if em == nil || segs < 3 || tube_segs < 3 || !is_finite_v3(center) { return false }
	if !is_finite_f32(ring_r) || !is_finite_f32(tube_r) || ring_r <= 1e-5 || tube_r <= 1e-5 { return false }
	edit.edit_mesh_deselect_all(em)
	start_v := len(em.verts)
	for s in 0..<segs {
		u := f32(s) * math.TAU / f32(segs); cu, su := math.cos(u), math.sin(u)
		for t in 0..<tube_segs {
			v := f32(t) * math.TAU / f32(tube_segs)
			rad := ring_r + tube_r * math.cos(v)
			_ = append_prim_vert(em, {center[0] + rad * cu, center[1] + tube_r * math.sin(v), center[2] + rad * su}, bone, group)
		}
	}
	for s in 0..<segs {
		s1 := (s + 1) % segs
		for t in 0..<tube_segs {
			t1 := (t + 1) % tube_segs
			a, b := u32(start_v + s * tube_segs + t), u32(start_v + s * tube_segs + t1)
			c, d := u32(start_v + s1 * tube_segs + t1), u32(start_v + s1 * tube_segs + t)
			append_prim_quad(em, a, b, c, d, mat, true, group)
		}
	}
	finish_prim_add(em, start_v)
	return true
}

@(private)
Add_Params :: struct {
	pos, size, radii:       [3]f32,
	r, r0, r1, h, ring, tb: f32,
	segs, tube_segs, rings: int,
	mat:                    spec.Mat_Kind,
	bone:                   spec.Bone_Id,
	group:                  u16,
	cap_bot, cap_top, sm:   bool,
	pts:                    [dynamic][2]f32,
	has_size, has_radii:    bool,
	has_r, has_r0, has_r1:  bool,
	has_h, has_ring, has_tb: bool,
}

@(private)
parse_lathe_pts :: proc(raw: string, out: ^[dynamic][2]f32) -> bool {
	clear(out)
	items := strings.split(raw, ",")
	defer delete(items)
	for it in items {
		slash := strings.index_byte(it, '/')
		if slash <= 0 { return false }
		r, r_ok := parse_f32_exact(it[:slash])
		y, y_ok := parse_f32_exact(it[slash + 1:])
		if !r_ok || !y_ok { return false }
		append(out, [2]f32{r, y})
	}
	return len(out) >= 2
}

@(private)
parse_add_kv :: proc(k, v: string, p: ^Add_Params) -> string {
	switch k {
	case "pos":       if !parse_f32_list(v, p.pos[:]) { return fmt.aprintf("invalid pos '%s'", v) }
	case "size":      p.has_size = parse_f32_list(v, p.size[:]); if !p.has_size { return fmt.aprintf("invalid size '%s'", v) }
	case "r":
		if strings.contains(v, ",") {
			p.has_radii = parse_f32_list(v, p.radii[:]); if !p.has_radii { return fmt.aprintf("invalid radii '%s'", v) }
		} else {
			ok: bool; p.r, ok = parse_f32_exact(v); p.has_r = ok; if !ok { return fmt.aprintf("invalid r '%s'", v) }
		}
	case "r0":        ok: bool; p.r0, ok = parse_f32_exact(v); p.has_r0 = ok; if !ok { return fmt.aprintf("invalid r0 '%s'", v) }
	case "r1":        ok: bool; p.r1, ok = parse_f32_exact(v); p.has_r1 = ok; if !ok { return fmt.aprintf("invalid r1 '%s'", v) }
	case "h":         ok: bool; p.h, ok = parse_f32_exact(v); p.has_h = ok; if !ok { return fmt.aprintf("invalid h '%s'", v) }
	case "ring":      ok: bool; p.ring, ok = parse_f32_exact(v); p.has_ring = ok; if !ok { return fmt.aprintf("invalid ring '%s'", v) }
	case "tube":      ok: bool; p.tb, ok = parse_f32_exact(v); p.has_tb = ok; if !ok { return fmt.aprintf("invalid tube '%s'", v) }
	case "segs":      ok: bool; p.segs, ok = strconv.parse_int(v, 10); if !ok { return fmt.aprintf("invalid segs '%s'", v) }
	case "rings":     ok: bool; p.rings, ok = strconv.parse_int(v, 10); if !ok { return fmt.aprintf("invalid rings '%s'", v) }
	case "tube_segs": ok: bool; p.tube_segs, ok = strconv.parse_int(v, 10); if !ok { return fmt.aprintf("invalid tube_segs '%s'", v) }
	case "mat":       ok: bool; p.mat, ok = parse_mat_name(v); if !ok { return fmt.aprintf("invalid mat '%s'", v) }
	case "bone":      ok: bool; p.bone, ok = parse_bone_name(v); if !ok { return fmt.aprintf("invalid bone '%s'", v) }
	case "group":     g, ok := strconv.parse_int(v, 10); if !ok || g < 0 || g > 65535 { return fmt.aprintf("invalid group '%s'", v) }; p.group = u16(g)
	case "cap_bot":   ok: bool; p.cap_bot, ok = parse_bool_val(v); if !ok { return fmt.aprintf("invalid cap_bot '%s'", v) }
	case "cap_top":   ok: bool; p.cap_top, ok = parse_bool_val(v); if !ok { return fmt.aprintf("invalid cap_top '%s'", v) }
	case "smooth":    ok: bool; p.sm, ok = parse_bool_val(v); if !ok { return fmt.aprintf("invalid smooth '%s'", v) }
	case "pts":       if !parse_lathe_pts(v, &p.pts) { return fmt.aprintf("invalid pts '%s'", v) }
	case:             return fmt.aprintf("unknown add param '%s'", k)
	}
	return ""
}

exec_add_op :: proc(em: ^edit.Edit_Mesh, op, rest: string) -> (bool, string) {
	p := Add_Params{
		segs = op == "add-lathe" ? 14 : (op == "add-ellipsoid" ? 10 : 12),
		rings = 5, tube_segs = 4, mat = .Steel, bone = .Root, cap_bot = true, cap_top = true, sm = true,
	}
	defer delete(p.pts)
	parts := strings.split(rest, ":")
	defer delete(parts)
	for raw in parts {
		if raw == "" { continue }
		eq := strings.index_byte(raw, '=')
		if eq <= 0 { return false, fmt.aprintf("expected key=value, got '%s'", raw) }
		if err := parse_add_kv(raw[:eq], raw[eq + 1:], &p); err != "" { return false, err }
	}
	ok := false
	switch op {
	case "add-box":       ok = p.has_size && add_box(em, p.pos, p.size, p.mat, p.bone, p.group)
	case "add-cone":      ok = p.has_r && p.has_h && add_cone(em, p.pos, p.r, p.h, p.segs, p.mat, p.bone, p.group)
	case "add-cylinder":
		if p.has_r && !p.has_r0 && !p.has_r1 { p.r0, p.r1, p.has_r0, p.has_r1 = p.r, p.r, true, true }
		ok = p.has_r0 && p.has_r1 && p.has_h && add_cylinder(em, p.pos, p.r0, p.r1, p.h, p.segs, p.mat, p.bone, p.group)
	case "add-lathe":     ok = len(p.pts) >= 2 && add_lathe(em, p.pos, p.pts[:], p.segs, p.mat, p.bone, p.group, p.cap_bot, p.cap_top, p.sm)
	case "add-ellipsoid": ok = p.has_radii && add_ellipsoid(em, p.pos, p.radii, p.segs, p.rings, p.mat, p.bone, p.group)
	case "add-torus":     ok = p.has_ring && p.has_tb && add_torus(em, p.pos, p.ring, p.tb, p.segs, p.tube_segs, p.mat, p.bone, p.group)
	case:                 return false, fmt.aprintf("unknown add op '%s'", op)
	}
	if !ok { return false, fmt.aprintf("%s failed: missing or invalid dimensions", op) }
	return true, ""
}
