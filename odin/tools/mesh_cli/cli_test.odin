#+build !js
package mesh_cli

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import art "../../client/art"
import edit "../../client/art/edit"
import spec "../../client/art/spec"

@(private)
check_assert_ok :: proc(t: ^testing.T, em: ^edit.Edit_Mesh, expr: string) {
	r := eval_assert(em, expr)
	defer assert_result_delete(&r)
	testing.expect(t, r.passed, r.detail)
}

@(test)
primitives_build_manifold_and_select_new_parts :: proc(t: ^testing.T) {
	em := edit.edit_mesh_init("prim_test", "Prim Test", .Props, false, 1.0, 1.0)
	defer edit.edit_mesh_delete(&em)

	testing.expect(t, add_box(&em, {0, 0.5, 0}, {1, 1, 1}, .Steel, .Root, 1))
	testing.expect_value(t, len(em.verts), 8)
	testing.expect_value(t, len(em.faces), 6)
	v_sel, _, f_sel := edit.edit_mesh_selected_counts(&em)
	testing.expect_value(t, v_sel, 8)
	testing.expect_value(t, f_sel, 6)

	testing.expect(t, add_cone(&em, {0, 1.0, 0}, 0.4, 0.8, 8, .Banner_Cloth, .Head, 2))
	testing.expect(t, add_cylinder(&em, {0, 0.0, 0}, 0.5, 0.4, 0.3, 8, .Banner_Gold, .Head, 3))
	testing.expect(t, add_ellipsoid(&em, {2, 1.0, 0}, {0.3, 0.4, 0.3}, 8, 4, .Cloth, .Chest, 4))
	testing.expect(t, add_torus(&em, {-2, 1.0, 0}, 0.4, 0.1, 8, 4, .Brass, .Chest, 5))
	rings := [3][2]f32{{0.2, 0.0}, {0.3, 0.4}, {0.1, 0.8}}
	testing.expect(t, add_lathe(&em, {0, 2.0, 0}, rings[:], 8, .Leather, .Root, 6))

	v_sel, _, f_sel = edit.edit_mesh_selected_counts(&em)
	testing.expect(t, v_sel > 0 && v_sel < len(em.verts))
	testing.expect(t, f_sel > 0 && f_sel < len(em.faces))
	check_assert_ok(t, &em, "manifold")
	check_assert_ok(t, &em, "odin_valid")
	check_assert_ok(t, &em, "has_mat=Banner_Cloth")
	check_assert_ok(t, &em, "has_mat=Banner_Gold")
}

@(test)
cooperative_mamluk_hat_workflow_roundtrip :: proc(t: ^testing.T) {
	tmp, err := os.make_directory_temp("", "mesh_cli_hat_", context.allocator)
	testing.expect(t, err == nil)
	defer { _ = os.remove_all(tmp); delete(tmp) }
	root_flag := fmt.aprintf("--root=%s", tmp)
	defer delete(root_flag)

	testing.expect_value(t, run_cli({root_flag, "--force-procedural", "extract", "mamluk"}), 0)
	testing.expect(t, edit.has_saved_odin_model(tmp, "mamluk"))

	// AI adds a 2-piece medieval hat on Head using Banner_Gold brim + Banner_Cloth steeple.
	code := run_cli({
		root_flag,
		"do", "mamluk",
		"add-cylinder:pos=0,1.76,0:r0=0.28:r1=0.26:h=0.05:segs=12:mat=.Banner_Gold:bone=Head:group=7",
		"add-cone:pos=0,1.81,0:r=0.17:h=0.36:segs=12:mat=.Banner_Cloth:bone=.Head:group=7",
		"expect:manifold",
		"expect:has_mat=Banner_Cloth",
		"expect:has_mat=Banner_Gold",
		"expect:mat_min_y=Banner_Cloth:1.70",
		"expect:max_y>=2.10",
		"expect:odin_valid",
	})
	testing.expect_value(t, code, 0)

	dir := fmt.aprintf("%s/mamluk", tmp)
	defer delete(dir)
	reloaded, load_ok := edit.edit_mesh_load_odin_dir(dir)
	testing.expect(t, load_ok)
	defer edit.edit_mesh_delete(&reloaded)

	check_assert_ok(t, &reloaded, "manifold")
	check_assert_ok(t, &reloaded, "has_mat=Banner_Cloth")
	check_assert_ok(t, &reloaded, "has_mat=Banner_Gold")
	check_assert_ok(t, &reloaded, "mat_min_y=Banner_Cloth:1.70")
	check_assert_ok(t, &reloaded, "max_y>=2.10")
	check_assert_ok(t, &reloaded, "bone_min_y=Head:1.50")
}

@(test)
negative_enum_error_leaves_disk_untouched :: proc(t: ^testing.T) {
	tmp, err := os.make_directory_temp("", "mesh_cli_neg_", context.allocator)
	testing.expect(t, err == nil)
	defer { _ = os.remove_all(tmp); delete(tmp) }
	root_flag := fmt.aprintf("--root=%s", tmp)
	defer delete(root_flag)

	testing.expect_value(t, run_cli({root_flag, "--force-procedural", "extract", "mamluk"}), 0)
	dir := fmt.aprintf("%s/mamluk", tmp)
	defer delete(dir)
	before, b_ok := edit.edit_mesh_load_odin_dir(dir)
	testing.expect(t, b_ok)
	before_verts, before_faces := len(before.verts), len(before.faces)
	edit.edit_mesh_delete(&before)

	// Invalid enum .InvalidBone must fail op & not save partial changes.
	code := run_cli({
		root_flag,
		"do", "mamluk",
		"add-box:pos=0,1.9,0:size=0.2,0.2,0.2:mat=Cloth:bone=.Head",
		"add-cone:pos=0,2.0,0:r=0.1:h=0.2:mat=Cloth:bone=.InvalidBone",
	})
	testing.expect_value(t, code, 1)

	// With --expect-fail, invalid op returns exit 0 cleanly and still leaves disk untouched.
	code_ef := run_cli({
		root_flag, "--expect-fail",
		"do", "mamluk",
		"set-bone:.InvalidBone",
	})
	testing.expect_value(t, code_ef, 0)

	after, a_ok := edit.edit_mesh_load_odin_dir(dir)
	testing.expect(t, a_ok)
	defer edit.edit_mesh_delete(&after)
	testing.expect_value(t, len(after.verts), before_verts)
	testing.expect_value(t, len(after.faces), before_faces)
}

@(test)
playwright_positive_and_negative_assertions :: proc(t: ^testing.T) {
	em, ok := art.catalog_load_edit_mesh("mamluk", true)
	testing.expect(t, ok)
	defer edit.edit_mesh_delete(&em)

	fail_res := eval_assert(&em, "max_y<=1.50")
	defer assert_result_delete(&fail_res)
	testing.expect(t, fail_res.expected_pass)
	testing.expect(t, !fail_res.actual_pass)
	testing.expect(t, !fail_res.passed)

	neg_res := eval_assert(&em, "!max_y<=1.50")
	defer assert_result_delete(&neg_res)
	testing.expect(t, !neg_res.expected_pass)
	testing.expect(t, !neg_res.actual_pass)
	testing.expect(t, neg_res.passed)

	bad_syntax := eval_assert(&em, "!unknown_metric>=1.0")
	defer assert_result_delete(&bad_syntax)
	testing.expect(t, !bad_syntax.passed)

	check_assert_ok(t, &em, "not_has_mat=Banner_Cloth")
	check_assert_ok(t, &em, "has_bone=Head")
	check_assert_ok(t, &em, "min_y>=-0.05")
	check_assert_ok(t, &em, "height>=1.80")
	check_assert_ok(t, &em, "max_r<=1.20")

	testing.expect_value(t, run_cli({"--force-procedural", "assert", "mamluk", "max_y<=1.50"}), 1)
	testing.expect_value(t, run_cli({"--force-procedural", "--expect-fail", "assert", "mamluk", "max_y<=1.50"}), 0)
	testing.expect_value(t, run_cli({"--force-procedural", "assert", "mamluk", "!max_y<=1.50", "manifold"}), 0)
}

@(test)
selection_transform_topology_and_batch_ops :: proc(t: ^testing.T) {
	em := edit.edit_mesh_init("box_ops", "Box Ops", .Props, false, 1.0, 1.0)
	defer edit.edit_mesh_delete(&em)

	script := `
		# Build a box, select top, extrude, inset, and verify
		add-box pos=0,0.5,0 size=1,1,1 mat=Steel bone=Root group=2
		select-mode:Face
		select-above:0.9
		extrude:0.5
		inset:0.25
		set-mat:Banner_Gold
		set-group:4
		set-smooth:false
		select-all
		snap-ground
		expect height>=1.49
		expect min_y<=0.001
		expect has_mat=Banner_Gold
		expect manifold
	`
	batch := split_op_batch(script)
	defer { for s in batch { delete(s) }; delete(batch) }
	report := make([dynamic]Assert_Result)
	defer assert_results_delete(&report)

	changed, err := run_cli_ops(&em, batch[:], &report)
	defer if err != "" { delete(err) }
	testing.expect(t, changed)
	testing.expect_value(t, err, "")
	testing.expect_value(t, len(report), 4)

	// Test rotate, scale, translate, loop-cut, select filters, delete, and fill.
	ops := [?]string{
		"select-none", "select-all", "select-invert",
		"select-group:4", "translate:0.1,0,0", "rotate:Y:45:pivot=0,0,0", "scale:1.1:axis=XZ",
		"select-below:0.5", "select-box:-2,-2,-2,2,2,2", "select-mat:Banner_Gold",
		"select-mode:Edge", "loop-cut:0:1:0.0",
		"select-mode:Vertex", "select-linked:0", "merge:0.001",
	}
	chg2, err2 := run_cli_ops(&em, ops[:], nil)
	defer if err2 != "" { delete(err2) }
	testing.expect(t, chg2)
	testing.expect_value(t, err2, "")
	check_assert_ok(t, &em, "manifold")
}

@(test)
info_stats_json_and_notify_failsoft :: proc(t: ^testing.T) {
	em, ok := art.catalog_load_edit_mesh("mamluk", true)
	testing.expect(t, ok)
	defer edit.edit_mesh_delete(&em)

	s := compute_mesh_stats(&em)
	defer mesh_stats_delete(&s)
	testing.expect(t, s.verts > 500 && s.faces > 400 && s.quads > 0)
	testing.expect(t, s.bones[spec.Bone_Id.Head])
	testing.expect(t, s.mats[spec.Mat_Kind.Steel])

	opts := Cli_Opts{}
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	build_list_json(&sb, &opts)
	p1: json.Value
	testing.expect(t, json.unmarshal(transmute([]byte)strings.to_string(sb), &p1) == nil)
	json.destroy_value(p1)

	strings.builder_reset(&sb)
	build_info_json(&sb, &em, &s)
	p2: json.Value
	testing.expect(t, json.unmarshal(transmute([]byte)strings.to_string(sb), &p2) == nil)
	json.destroy_value(p2)

	r := eval_assert(&em, "verts>=500")
	defer assert_result_delete(&r)
	strings.builder_reset(&sb)
	write_assert_results_json(&sb, {r})
	p3: json.Value
	testing.expect(t, json.unmarshal(transmute([]byte)strings.to_string(sb), &p3) == nil)
	json.destroy_value(p3)

	// CLI info, list, dry-run, and unreachable --notify port all succeed fail-soft.
	testing.expect_value(t, run_cli({"list", "--json"}), 0)
	testing.expect_value(t, run_cli({"--force-procedural", "--json", "info", "boulder_moss", "--bounds", "--mats"}), 0)
	testing.expect_value(t, run_cli({"--force-procedural", "--dry-run", "--notify=59999", "do", "boulder_moss", "translate:0,0.1,0", "expect:manifold"}), 0)
}
