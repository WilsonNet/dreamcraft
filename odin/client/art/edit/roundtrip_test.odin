#+build !js
package art_edit

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import spec "../spec"

@(private)
make_synthetic_mesh :: proc(id: string, vert_count, face_count: int) -> Edit_Mesh {
	m := edit_mesh_init(id, "Heroic \"Test\" Mesh", .Units, true, 1.60, 0.74, 0.35)
	bones := [4]spec.Bone_Id{.Root, .Chest, .Head, .Hand_R}
	mats := [4]spec.Mat_Kind{.Steel, .Cloth, .Glow, .Banner_Gold}
	neg_zero := f32(-0.000001)

	for i in 0..<vert_count {
		fi := f32(i)
		px := i == 0 ? neg_zero : (fi * 0.0125 - 1.5)
		py := fi * 0.005 + 0.1
		pz := (i % 2 == 0 ? f32(-1) : f32(1)) * (0.25 + fi * 0.001)
		append(&m.verts, Edit_Vert{
			pos   = {px, py, pz},
			nrm   = {0, 1, 0},
			bone  = bones[i % len(bones)],
			ao    = 0.75 + f32(i % 5) * 0.05,
			group = u16(i % 7),
		})
	}
	for i in 0..<face_count {
		base := u32((i * 2) % max(vert_count - 4, 1))
		is_quad := i % 3 != 0
		f := Edit_Face{
			v      = {base, base + 1, base + 2, is_quad ? base + 3 : 0},
			count  = is_quad ? 4 : 3,
			mat    = mats[i % len(mats)],
			smooth = (i % 2) == 0,
			group  = u16(i % 9),
		}
		append(&m.faces, f)
	}
	edit_mesh_rebuild_topology(&m)
	return m
}

@(private)
assert_mesh_matches :: proc(t: ^testing.T, a, b: ^Edit_Mesh) {
	testing.expect_value(t, b.id, a.id)
	testing.expect_value(t, b.title, a.title)
	testing.expect_value(t, b.category, a.category)
	testing.expect_value(t, b.skinned, a.skinned)
	testing.expect(t, abs(b.ao_height - a.ao_height) < 1e-4)
	testing.expect(t, abs(b.default_scale - a.default_scale) < 1e-4)
	testing.expect(t, abs(b.glow_override - a.glow_override) < 1e-4)
	testing.expect_value(t, len(b.verts), len(a.verts))
	testing.expect_value(t, len(b.faces), len(a.faces))
	for i in 0..<len(a.verts) {
		va, vb := a.verts[i], b.verts[i]
		for k in 0..<3 {
			testing.expect(t, abs(va.pos[k] - vb.pos[k]) < 2e-4)
		}
		testing.expect_value(t, vb.bone, va.bone)
		testing.expect(t, abs(va.ao - vb.ao) < 2e-4)
		testing.expect_value(t, vb.group, va.group)
	}
	for i in 0..<len(a.faces) {
		fa, fb := a.faces[i], b.faces[i]
		testing.expect_value(t, fb.count, fa.count)
		testing.expect_value(t, fb.v, fa.v)
		testing.expect_value(t, fb.mat, fa.mat)
		testing.expect_value(t, fb.smooth, fa.smooth)
		testing.expect_value(t, fb.group, fa.group)
	}
}

@(private)
read_str_file :: proc(t: ^testing.T, path: string) -> string {
	data, err := os.read_entire_file(path, context.allocator)
	testing.expect(t, err == nil)
	return string(data)
}

@(private)
count_lines :: proc(s: string) -> int {
	n := 0
	for i in 0..<len(s) {
		if s[i] == '\n' { n += 1 }
	}
	return n
}

@(test)
odin_chunked_roundtrip_diff_and_shrink :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_odin_rt_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	m := make_synthetic_mesh("test_hero", 350, 340)
	defer edit_mesh_delete(&m)

	dir, save_ok := edit_mesh_save_odin(&m, tmp_root)
	testing.expect(t, save_ok)
	defer delete(dir)
	testing.expect(t, has_saved_odin_model(tmp_root, "test_hero"))

	v0_path := fmt.aprintf("%s/v_000.odin", dir); defer delete(v0_path)
	v1_path := fmt.aprintf("%s/v_001.odin", dir); defer delete(v1_path)
	f1_path := fmt.aprintf("%s/f_001.odin", dir); defer delete(f1_path)
	testing.expect(t, os.exists(v0_path) && os.exists(v1_path) && os.exists(f1_path))

	v0_before := read_str_file(t, v0_path); defer delete(v0_before)
	v1_before := read_str_file(t, v1_path); defer delete(v1_before)
	testing.expect(t, count_lines(v0_before) <= 340)
	testing.expect(t, !strings.contains(v0_before, "-0.0000"))

	m.verts[310].pos[1] += 0.2500
	dir2, save_ok2 := edit_mesh_save_odin(&m, tmp_root)
	testing.expect(t, save_ok2)
	delete(dir2)

	v0_after := read_str_file(t, v0_path); defer delete(v0_after)
	v1_after := read_str_file(t, v1_path); defer delete(v1_after)
	testing.expect_value(t, v0_after, v0_before)
	testing.expect(t, v1_after != v1_before)

	loaded, load_ok := edit_mesh_load_odin_dir(dir)
	testing.expect(t, load_ok)
	defer edit_mesh_delete(&loaded)
	testing.expect(t, !loaded.dirty)
	assert_mesh_matches(t, &m, &loaded)

	resize(&m.verts, 10)
	resize(&m.faces, 4)
	dir3, save_ok3 := edit_mesh_save_odin(&m, tmp_root)
	testing.expect(t, save_ok3)
	delete(dir3)
	testing.expect(t, !os.exists(v1_path) && !os.exists(f1_path))
}

@(test)
manifest_orchestrator_sorts_deterministically :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_manifest_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	mz := make_synthetic_mesh("zeta_prop", 4, 1)
	defer edit_mesh_delete(&mz)
	ma := make_synthetic_mesh("alpha_prop", 4, 1)
	defer edit_mesh_delete(&ma)

	dz, okz := edit_mesh_save_odin(&mz, tmp_root); defer delete(dz)
	da, oka := edit_mesh_save_odin(&ma, tmp_root); defer delete(da)
	testing.expect(t, okz && oka)

	m_path := fmt.aprintf("%s/manifest.odin", tmp_root); defer delete(m_path)
	manifest := read_str_file(t, m_path); defer delete(manifest)
	idx_a := strings.index(manifest, "m_alpha_prop.ASSET")
	idx_z := strings.index(manifest, "m_zeta_prop.ASSET")
	testing.expect(t, idx_a >= 0 && idx_z > idx_a)
	testing.expect(t, strings.contains(manifest, "find_builtin_asset"))
}

@(test)
odin_parser_handles_comments_and_rejects_malformed :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_parse_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	model_dir := fmt.aprintf("%s/commented", tmp_root); defer delete(model_dir)
	testing.expect(t, os.make_directory_all(model_dir) == nil)
	asset_src := "// header comment\npackage model_commented\nimport spec \"../../spec\"\nV_CHUNKS := [1][]spec.Asset_Vert{\n\tV_000[:], // ref\n}\nF_CHUNKS := [1][]spec.Asset_Face{\n\tF_000[:],\n}\nASSET := spec.Model_Asset_Def{\n\tid = \"commented\", title = \"Commented\",\n\tcategory = .Props, skinned = false,\n\tao_height = 0.45, default_scale = 1.0, glow_override = 0.0,\n\tvert_chunks = V_CHUNKS[:], face_chunks = F_CHUNKS[:],\n}\n"
	v_src := "package model_commented\nimport spec \"../../spec\"\nV_000 := [3]spec.Asset_Vert{\n\t{{-0.5, 0.0, 0.0}, .Root, 1.0, 0}, // v0\n\t{{0.5, 0.0, 0.0}, .Root, 1.0, 0},\n\t{{0.0, 1.0, 0.0}, .Head, 0.9, 2},\n}\n"
	f_src := "package model_commented\nimport spec \"../../spec\"\nF_000 := [1]spec.Asset_Face{\n\t{{0, 1, 2, 0}, 3, .Moss, true, 1},\n}\n"

	a_path := fmt.aprintf("%s/asset.odin", model_dir); defer delete(a_path)
	v_path := fmt.aprintf("%s/v_000.odin", model_dir); defer delete(v_path)
	f_path := fmt.aprintf("%s/f_000.odin", model_dir); defer delete(f_path)
	testing.expect(t, os.write_entire_file(a_path, asset_src) == nil)
	testing.expect(t, os.write_entire_file(v_path, v_src) == nil)
	testing.expect(t, os.write_entire_file(f_path, f_src) == nil)

	loaded, ok := edit_mesh_load_odin_dir(model_dir)
	testing.expect(t, ok)
	defer edit_mesh_delete(&loaded)
	testing.expect_value(t, len(loaded.verts), 3)
	testing.expect_value(t, len(loaded.faces), 1)
	testing.expect_value(t, loaded.faces[0].mat, spec.Mat_Kind.Moss)

	// Corrupt face index out of bounds -> must fail cleanly with 0 leaks.
	bad_f := "package model_commented\nimport spec \"../../spec\"\nF_000 := [1]spec.Asset_Face{\n\t{{0, 1, 99, 0}, 3, .Moss, true, 1},\n}\n"
	testing.expect(t, os.write_entire_file(f_path, bad_f) == nil)
	bad_mesh, bad_ok := edit_mesh_load_odin_dir(model_dir)
	testing.expect(t, !bad_ok)
	edit_mesh_delete(&bad_mesh)
}
