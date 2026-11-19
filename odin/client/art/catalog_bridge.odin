// Procedural Mesh_Builder <-> Edit_Mesh topology & crease-normal conversion bridge.
package art

import "core:math"
import rl "vendor:raylib"
import edit "./edit"
import spec "./spec"

@(private)
Weld_Key :: struct { qx, qy, qz: i64, bone: spec.Bone_Id }

@(private)
Temp_Tri :: struct {
	w:            [3]u32,
	gn, corner_n: [3]f32,
	mat:          spec.Mat_Kind,
	smooth:       bool,
	flat_corners: bool,
}

// Convert a Mesh_Builder into a welded, quad-paired Edit_Mesh.
mesh_builder_to_edit_mesh :: proc(b: ^Mesh_Builder, entry: Catalog_Entry) -> edit.Edit_Mesh {
	em := edit.edit_mesh_init(
		entry.id, entry.title, entry.category, entry.skinned,
		entry.ao_height, entry.default_scale, entry.glow_override,
	)
	if len(b.pos) == 0 { return em }
	src_mat := make([]spec.Mat_Kind, len(b.pos)); defer delete(src_mat)
	src_to_weld := make([]u32, len(b.pos)); defer delete(src_to_weld)
	weld_builder_verts(b, entry, &em, src_mat, src_to_weld)
	tris := extract_temp_tris(b, &em, src_mat, src_to_weld); defer delete(tris)
	emit_paired_faces(&em, tris[:])
	edit.edit_mesh_rebuild_topology(&em)
	em.dirty = false
	return em
}

@(private)
weld_builder_verts :: proc(b: ^Mesh_Builder, entry: Catalog_Entry, em: ^edit.Edit_Mesh, src_mat: []spec.Mat_Kind, src_to_weld: []u32) {
	weld_map := make(map[Weld_Key]u32, len(b.pos)); defer delete(weld_map)
	ao_acc := make([dynamic][2]f32, 0, len(b.pos)); defer delete(ao_acc)
	for i in 0..<len(b.pos) {
		p := b.pos[i]
		mat := match_mat_kind(b, b.col[i], b.uv[i], entry.glow_override)
		src_mat[i] = mat
		bone := spec.Bone_Id(clamp(int(b.bone[i]), 0, int(spec.Bone_Id.COUNT) - 1))
		ao := recover_ao_scale(b, b.col[i], p.y, mat, entry)
		key := Weld_Key{i64(math.round(p.x * 10000)), i64(math.round(p.y * 10000)), i64(math.round(p.z * 10000)), bone}
		if wi, ok := weld_map[key]; ok {
			src_to_weld[i] = wi
			ao_acc[wi][0] += ao; ao_acc[wi][1] += 1
		} else {
			wi = u32(len(em.verts))
			weld_map[key] = wi; src_to_weld[i] = wi
			append(&em.verts, edit.Edit_Vert{pos = {p.x, p.y, p.z}, nrm = {0, 1, 0}, bone = bone, ao = ao})
			append(&ao_acc, [2]f32{ao, 1})
		}
	}
	for &v, i in em.verts { v.ao = ao_acc[i][0] / ao_acc[i][1] }
}

@(private)
extract_temp_tris :: proc(b: ^Mesh_Builder, em: ^edit.Edit_Mesh, src_mat: []spec.Mat_Kind, src_to_weld: []u32) -> [dynamic]Temp_Tri {
	tris := make([dynamic]Temp_Tri, 0, len(b.idx) / 3)
	for ti := 0; ti + 2 < len(b.idx); ti += 3 {
		s0, s1, s2 := int(b.idx[ti]), int(b.idx[ti + 1]), int(b.idx[ti + 2])
		w0, w1, w2 := src_to_weld[s0], src_to_weld[s1], src_to_weld[s2]
		if w0 == w1 || w1 == w2 || w2 == w0 { continue }
		cross := edit.v3_cross(edit.v3_sub(em.verts[w1].pos, em.verts[w0].pos), edit.v3_sub(em.verts[w2].pos, em.verts[w0].pos))
		if edit.v3_len_sq(cross) < 1e-12 { continue }
		gn := edit.v3_norm(cross)
		n0, n1, n2 := ([3]f32)(b.nrm[s0]), ([3]f32)(b.nrm[s1]), ([3]f32)(b.nrm[s2])
		d_min := min(edit.v3_dot(n0, gn), min(edit.v3_dot(n1, gn), edit.v3_dot(n2, gn)))
		flat_c := edit.v3_dot(n0, n1) > 0.9995 && edit.v3_dot(n1, n2) > 0.9995
		append(&tris, Temp_Tri{
			w = {w0, w1, w2}, gn = gn, corner_n = n0,
			mat = src_mat[s0], smooth = d_min <= 0.996, flat_corners = flat_c,
		})
	}
	return tris
}

@(private)
emit_paired_faces :: proc(em: ^edit.Edit_Mesh, tris: []Temp_Tri) {
	for i := 0; i < len(tris); {
		t0 := tris[i]
		if i + 1 < len(tris) && can_pair_quad(t0, tris[i + 1]) {
			t1 := tris[i + 1]
			sm := (t0.flat_corners && t1.flat_corners && !t0.smooth) ? false : (t0.smooth && t1.smooth)
			append(&em.faces, edit.Edit_Face{v = {t0.w[0], t0.w[1], t0.w[2], t1.w[2]}, count = 4, mat = t0.mat, smooth = sm})
			i += 2
		} else {
			append(&em.faces, edit.Edit_Face{v = {t0.w[0], t0.w[1], t0.w[2], 0}, count = 3, mat = t0.mat, smooth = t0.smooth})
			i += 1
		}
	}
}

@(private)
can_pair_quad :: proc(t0, t1: Temp_Tri) -> bool {
	if t0.mat != t1.mat || t1.w[0] != t0.w[0] || t1.w[1] != t0.w[2] { return false }
	if t1.w[2] == t0.w[0] || t1.w[2] == t0.w[1] || t1.w[2] == t0.w[2] { return false }
	same_flat := t0.flat_corners && t1.flat_corners && edit.v3_dot(t0.corner_n, t1.corner_n) > 0.9995 && edit.v3_dot(t0.gn, t1.gn) > 0.98
	if t0.smooth != t1.smooth && !same_flat { return false }
	thresh := (t0.smooth && t1.smooth) ? f32(0.75) : f32(0.98)
	return edit.v3_dot(t0.gn, t1.gn) > thresh
}

@(private)
match_mat_kind :: proc(b: ^Mesh_Builder, col: rl.Color, uv: rl.Vector2, glow_override: f32) -> spec.Mat_Kind {
	best_kind := spec.Mat_Kind.Skin
	best_err := f32(1e9)
	for kind in spec.Mat_Kind {
		if kind == .COUNT { continue }
		def := mb_material(b, kind)
		dr := abs(int(col.r) - int(def.albedo.r))
		dg := abs(int(col.g) - int(def.albedo.g))
		db := abs(int(col.b) - int(def.albedo.b))
		dglow := glow_override > 0 ? f32(0) : abs(uv.y - def.glow)
		err := f32(dr + dg + db) + (abs(uv.x - def.metal) + dglow) * 200.0
		if err < best_err { best_err = err; best_kind = kind }
	}
	return best_kind
}

@(private)
recover_ao_scale :: proc(b: ^Mesh_Builder, col: rl.Color, y: f32, mat: spec.Mat_Kind, entry: Catalog_Entry) -> f32 {
	if entry.glow_override > 0 { return 1.0 }
	h_ao := entry.ao_height > 0 ? entry.ao_height : b.ao_height
	base_ao := MAT_DEFS[mat].ao * mb_height_ao(y, h_ao)
	if base_ao <= 1e-4 { return 1.0 }
	if u8(clamp(base_ao, 0, 1) * 255) == col.a { return 1.0 }
	target := col.a == 255 ? f32(1.0) : (f32(col.a) + 0.5) / 255.0
	return clamp(target / base_ao, 0.0, 2.0)
}

// Convert an Edit_Mesh back into a Mesh_Builder with crease-aware smooth/flat normals.
edit_mesh_to_mesh_builder :: proc(em: ^edit.Edit_Mesh, palette: Team_Palette) -> Mesh_Builder {
	b := mb_init(palette)
	b.is_prop = !em.skinned
	b.ao_height = em.ao_height
	if len(em.verts) == 0 || len(em.faces) == 0 { return b }

	face_nrms := make([][3]f32, len(em.faces)); defer delete(face_nrms)
	for &f, fi in em.faces { face_nrms[fi] = eval_face_nrm(em, &f) }

	offsets, adj := build_vert_face_adj(em)
	defer { delete(offsets); delete(adj) }

	for &f, fi in em.faces {
		emit_edit_face(&b, em, &f, fi, face_nrms, offsets, adj)
		if b.overflow { break }
	}
	if em.glow_override > 0 {
		for i in 0..<len(b.pos) {
			b.uv[i].y = em.glow_override
			b.col[i].a = 255
		}
	}
	return b
}

@(private)
eval_face_nrm :: proc(em: ^edit.Edit_Mesh, f: ^edit.Edit_Face) -> [3]f32 {
	if f.count < 3 { return {0, 1, 0} }
	p0, p1, p2 := em.verts[f.v[0]].pos, em.verts[f.v[1]].pos, em.verts[f.v[2]].pos
	n := edit.v3_cross(edit.v3_sub(p1, p0), edit.v3_sub(p2, p0))
	if f.count == 4 && edit.v3_len_sq(n) < 1e-10 {
		p3 := em.verts[f.v[3]].pos
		n = edit.v3_cross(edit.v3_sub(p2, p0), edit.v3_sub(p3, p0))
	}
	return edit.v3_norm(n)
}

@(private)
build_vert_face_adj :: proc(em: ^edit.Edit_Mesh) -> ([]int, []u32) {
	nv := len(em.verts)
	offsets := make([]int, nv + 1)
	for &f in em.faces {
		for c in 0..<int(f.count) { offsets[f.v[c] + 1] += 1 }
	}
	for i in 1..=nv { offsets[i] += offsets[i - 1] }
	adj := make([]u32, offsets[nv])
	cursor := make([]int, nv); defer delete(cursor)
	copy(cursor, offsets[:nv])
	for &f, fi in em.faces {
		for c in 0..<int(f.count) {
			vi := f.v[c]
			adj[cursor[vi]] = u32(fi)
			cursor[vi] += 1
		}
	}
	return offsets, adj
}

@(private)
emit_edit_face :: proc(b: ^Mesh_Builder, em: ^edit.Edit_Mesh, f: ^edit.Edit_Face, fi: int, face_nrms: [][3]f32, offsets: []int, adj: []u32) {
	if f.count < 3 { return }
	idx: [4]u16
	fn := face_nrms[fi]
	for c in 0..<int(f.count) {
		vi := f.v[c]
		v := &em.verts[vi]
		nrm := fn
		if f.smooth {
			sum := fn
			for ai in offsets[vi]..<offsets[vi + 1] {
				other := int(adj[ai])
				if other != fi && edit.v3_dot(fn, face_nrms[other]) > 0.60 {
					sum = edit.v3_add(sum, face_nrms[other])
				}
			}
			nrm = edit.v3_norm(sum)
		}
		mb_bone(b, v.bone)
		idx[c] = mb_emit(b, rl.Vector3(v.pos), rl.Vector3(nrm), f.mat, v.ao)
	}
	if b.overflow { return }
	mb_tri_raw(b, idx[0], idx[1], idx[2])
	if f.count == 4 { mb_tri_raw(b, idx[0], idx[2], idx[3]) }
}
