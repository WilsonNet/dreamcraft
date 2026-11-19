#+build !js
package art

import "core:math"
import "core:testing"
import edit "./edit"
import spec "./spec"

@(private)
check_rt_mesh_valid :: proc(t: ^testing.T, orig, rt: ^Mesh_Builder, entry: Catalog_Entry) {
	testing.expect(t, !rt.overflow)
	testing.expect(t, len(rt.pos) > 0)
	testing.expect(t, len(rt.idx) > 0)
	testing.expect_value(t, len(rt.pos), len(rt.nrm))
	testing.expect_value(t, len(rt.pos), len(rt.col))
	testing.expect_value(t, len(rt.pos), len(rt.uv))
	testing.expect_value(t, len(rt.pos), len(rt.bone))
	testing.expect_value(t, len(rt.idx) % 3, 0)
	testing.expect_value(t, rt.is_prop, !entry.skinned)

	orig_min, orig_max := mesh_bounds(orig)
	rt_min, rt_max := mesh_bounds(rt)
	for k in 0..<3 {
		testing.expect(t, abs(orig_min[k] - rt_min[k]) < 1e-3)
		testing.expect(t, abs(orig_max[k] - rt_max[k]) < 1e-3)
	}

	bad_nrm, bad_bone := 0, 0
	for i in 0..<len(rt.pos) {
		n := rt.nrm[i]
		nlen := math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
		if math.is_nan(nlen) || abs(nlen - 1.0) > 0.02 { bad_nrm += 1 }
		if int(rt.bone[i]) >= BONE_COUNT { bad_bone += 1 }
	}
	testing.expect_value(t, bad_nrm, 0)
	testing.expect_value(t, bad_bone, 0)
}

@(private)
mesh_bounds :: proc(b: ^Mesh_Builder) -> ([3]f32, [3]f32) {
	lo := [3]f32{1e9, 1e9, 1e9}
	hi := [3]f32{-1e9, -1e9, -1e9}
	for p in b.pos {
		lo = {min(lo[0], p.x), min(lo[1], p.y), min(lo[2], p.z)}
		hi = {max(hi[0], p.x), max(hi[1], p.y), max(hi[2], p.z)}
	}
	return lo, hi
}

@(private)
make_tiny_custom_mesh :: proc(id: string, skinned: bool, quad: bool) -> edit.Edit_Mesh {
	em := edit.edit_mesh_init(id, "Custom Test", skinned ? .Units : .Trees, skinned, 1.60, 0.74)
	append(&em.verts, edit.Edit_Vert{pos = {-0.5, 0.0, 0.0}, bone = .Root, ao = 1.0})
	append(&em.verts, edit.Edit_Vert{pos = {0.5, 0.0, 0.0}, bone = .Root, ao = 1.0})
	append(&em.verts, edit.Edit_Vert{pos = {0.5, 1.0, 0.0}, bone = .Chest, ao = 1.0})
	if quad {
		append(&em.verts, edit.Edit_Vert{pos = {-0.5, 1.0, 0.0}, bone = .Chest, ao = 1.0})
		append(&em.faces, edit.Edit_Face{v = {0, 1, 2, 3}, count = 4, mat = .Cloth, smooth = false})
	} else {
		append(&em.faces, edit.Edit_Face{v = {0, 1, 2, 0}, count = 3, mat = .Leaf_Mid, smooth = false})
	}
	edit.edit_mesh_rebuild_topology(&em)
	return em
}

@(test)
all_12_catalog_models_roundtrip_cleanly :: proc(t: ^testing.T) {
	testing.expect_value(t, len(MODEL_CATALOG), 12)
	for entry in MODEL_CATALOG {
		enemy := entry.id == "mamluk_enemy"
		hero := entry.id == "mamluk_hero"
		orig, ok := build_procedural_by_id(entry.id, enemy, hero)
		testing.expect(t, ok)
		defer mb_delete(&orig)

		em := mesh_builder_to_edit_mesh(&orig, entry)
		defer edit.edit_mesh_delete(&em)
		testing.expect(t, len(em.verts) > 0 && len(em.faces) > 0)

		quad_count := 0
		for f in em.faces {
			if f.count == 4 { quad_count += 1 }
		}
		testing.expect(t, quad_count > 0)

		rt := edit_mesh_to_mesh_builder(&em, orig.palette)
		defer mb_delete(&rt)
		check_rt_mesh_valid(t, &orig, &rt, entry)

		if entry.id == "selection_ring" {
			for i in 0..<len(rt.pos) {
				testing.expect(t, abs(rt.uv[i].y - 0.35) < 0.001)
				testing.expect_value(t, rt.col[i].a, u8(255))
			}
		}
	}
}

@(test)
live_mamluk_override_and_fallback_work_and_restore :: proc(t: ^testing.T) {
	defer clear_live_edit_mesh("mamluk")

	proc_m := build_mamluk(false)
	orig_verts := mb_vertex_count(&proc_m)
	orig_tris := mb_triangle_count(&proc_m)
	mb_delete(&proc_m)

	custom_m := make_tiny_custom_mesh("mamluk", true, true)
	defer edit.edit_mesh_delete(&custom_m)
	testing.expect(t, register_live_edit_mesh("mamluk", &custom_m))
	testing.expect(t, catalog_has_custom_odin("mamluk"))
	testing.expect(t, !catalog_has_custom_odin("mamluk_hero"))

	over_m := build_mamluk(false)
	defer mb_delete(&over_m)
	testing.expect_value(t, mb_vertex_count(&over_m), 4)
	testing.expect_value(t, mb_triangle_count(&over_m), 2)

	// Hero and enemy fallback to base "mamluk" custom override while keeping their team palettes.
	over_hero := build_mamluk(false, true)
	defer mb_delete(&over_hero)
	testing.expect_value(t, mb_vertex_count(&over_hero), 4)
	testing.expect(t, over_hero.palette.hero)

	over_enemy := build_mamluk(true, false)
	defer mb_delete(&over_enemy)
	testing.expect_value(t, mb_vertex_count(&over_enemy), 4)
	testing.expect_value(t, over_enemy.col[0].r, over_enemy.palette.cloth.r)

	loaded_hero, lh_ok := catalog_load_edit_mesh("mamluk_hero")
	testing.expect(t, lh_ok)
	defer edit.edit_mesh_delete(&loaded_hero)
	testing.expect_value(t, loaded_hero.id, "mamluk_hero")
	testing.expect(t, abs(loaded_hero.default_scale - 0.84) < 1e-4)

	clear_live_edit_mesh("mamluk")
	restored_m := build_mamluk(false)
	defer mb_delete(&restored_m)
	testing.expect_value(t, mb_vertex_count(&restored_m), orig_verts)
	testing.expect_value(t, mb_triangle_count(&restored_m), orig_tris)
}

@(test)
live_tree_override_works_and_restores :: proc(t: ^testing.T) {
	defer clear_live_edit_mesh("pine_tall")
	proc_pine := build_pine_tall()
	pine_verts := mb_vertex_count(&proc_pine)
	mb_delete(&proc_pine)

	custom_pine := make_tiny_custom_mesh("pine_tall", false, false)
	defer edit.edit_mesh_delete(&custom_pine)
	testing.expect(t, register_live_edit_mesh("pine_tall", &custom_pine))
	over_pine := build_pine_tall()
	testing.expect_value(t, mb_vertex_count(&over_pine), 3)
	mb_delete(&over_pine)

	clear_live_edit_mesh("pine_tall")
	restored_pine := build_pine_tall()
	defer mb_delete(&restored_pine)
	testing.expect_value(t, mb_vertex_count(&restored_pine), pine_verts)
}

@(test)
catalog_models_root_and_procedural_load_work :: proc(t: ^testing.T) {
	root, ok := resolve_models_root()
	testing.expect(t, ok)
	testing.expect(t, len(root) > 0)

	em, load_ok := catalog_load_edit_mesh("boulder_moss", true)
	testing.expect(t, load_ok)
	defer edit.edit_mesh_delete(&em)
	testing.expect_value(t, em.id, "boulder_moss")
	testing.expect_value(t, em.category, spec.Model_Category.Props)
	testing.expect(t, !em.skinned)
	testing.expect(t, len(em.verts) > 0 && len(em.faces) > 0)
}
