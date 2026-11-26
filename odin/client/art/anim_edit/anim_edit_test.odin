#+build !js
package art_anim_edit

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import spec "../spec"

@(private)
make_synthetic_clip :: proc(id: string, kf_count: int, loop := true) -> Edit_Clip {
	c := edit_clip_init(id, "Test \"Hero\" Clip", 1.25, loop, !loop, 0.35)
	for i in 0 ..< kf_count {
		t := kf_count <= 1 ? f32(0) : f32(i) / f32(kf_count - 1)
		kf := Edit_Keyframe{
			time        = t,
			interp      = spec.Anim_Interp(i % 5),
			root_offset = {0.0, f32(i) * 0.01, -0.02},
		}
		kf.rot[int(spec.Bone_Id.Chest)] = {0.10 * f32(i + 1), -0.05, 0.02}
		kf.rot[int(spec.Bone_Id.Arm_R)] = {-0.20, 0.30, 0.0}
		append(&c.keyframes, kf)
	}
	return c
}

@(private)
read_str_file :: proc(t: ^testing.T, path: string) -> string {
	data, err := os.read_entire_file(path, context.allocator)
	testing.expect(t, err == nil)
	return string(data)
}

@(private)
assert_clip_matches :: proc(t: ^testing.T, a, b: ^Edit_Clip) {
	testing.expect_value(t, b.id, a.id)
	testing.expect_value(t, b.title, a.title)
	testing.expect(t, abs(b.duration - a.duration) < 1e-4)
	testing.expect_value(t, b.loop, a.loop)
	testing.expect_value(t, b.additive, a.additive)
	testing.expect(t, abs(b.secondary_weight - a.secondary_weight) < 1e-4)
	testing.expect_value(t, len(b.keyframes), len(a.keyframes))
	for i in 0 ..< len(a.keyframes) {
		ka, kb := &a.keyframes[i], &b.keyframes[i]
		testing.expect(t, abs(ka.time - kb.time) < 2e-4)
		testing.expect_value(t, kb.interp, ka.interp)
		for k in 0 ..< 3 {
			testing.expect(t, abs(ka.root_offset[k] - kb.root_offset[k]) < 2e-4)
		}
		for bi in 0 ..< BONE_COUNT {
			for k in 0 ..< 3 {
				testing.expect(t, abs(ka.rot[bi][k] - kb.rot[bi][k]) < 2e-4)
			}
		}
	}
}

@(test)
eval_interpolation_and_loop_seam_wrap :: proc(t: ^testing.T) {
	c := edit_clip_init("loop_test", "Loop", 1.0, true, false, 0)
	defer edit_clip_delete(&c)

	k0 := Edit_Keyframe{time = 0.20, interp = .Linear}
	k0.rot[int(spec.Bone_Id.Head)] = {1.0, 0, 0}
	k1 := Edit_Keyframe{time = 0.80, interp = .Linear}
	k1.rot[int(spec.Bone_Id.Head)] = {0.0, 0, 0}
	append(&c.keyframes, k0, k1)

	rot_mid, _ := eval_edit_clip(&c, 0.50)
	testing.expect(t, abs(rot_mid[int(spec.Bone_Id.Head)][0] - 0.5) < 1e-4)

	// Seam wrap across t=1.0 -> t=0.0 (span 0.40: 0.80..1.20). At 0.00, halfway across wrap.
	rot_seam, _ := eval_edit_clip(&c, 0.00)
	testing.expect(t, abs(rot_seam[int(spec.Bone_Id.Head)][0] - 0.5) < 1e-4)

	// Step holds start value until next keyframe.
	c.keyframes[0].interp = .Step
	rot_step, _ := eval_edit_clip(&c, 0.79)
	testing.expect(t, abs(rot_step[int(spec.Bone_Id.Head)][0] - 1.0) < 1e-4)
}

@(test)
ops_mirror_flip_move_delete_and_undo_redo :: proc(t: ^testing.T) {
	c := make_synthetic_clip("ops", 3, true)
	defer edit_clip_delete(&c)
	u: Anim_Undo_Stack
	defer anim_undo_delete(&u)

	anim_undo_push(&u, &c)
	clip_set_bone_rot(&c.keyframes[0], .Arm_L, {0.4, 0.2, -0.3}, true)
	testing.expect(t, abs(c.keyframes[0].rot[int(spec.Bone_Id.Arm_R)][1] + 0.2) < 1e-5)
	testing.expect(t, abs(c.keyframes[0].rot[int(spec.Bone_Id.Arm_R)][2] - 0.3) < 1e-5)

	idx := clip_move_keyframe(&c, 0, 0.75)
	testing.expect_value(t, idx, 1)
	testing.expect(t, clip_delete_keyframe(&c, idx))
	testing.expect_value(t, len(c.keyframes), 2)

	testing.expect(t, anim_undo_step(&u, &c))
	testing.expect_value(t, len(c.keyframes), 3)
	testing.expect(t, anim_redo_step(&u, &c))
	testing.expect_value(t, len(c.keyframes), 2)

	clip_flip_pose_lr(&c.keyframes[0])
	testing.expect(t, abs(c.keyframes[0].rot[int(spec.Bone_Id.Arm_L)][1] + 0.30) < 1e-5)
}

@(test)
odin_chunked_anim_roundtrip_diff_and_shrink :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_anim_rt_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	c := make_synthetic_clip("hero_walk", 14, true)
	defer edit_clip_delete(&c)

	dir, save_ok := edit_clip_save_odin(&c, tmp_root)
	testing.expect(t, save_ok)
	defer delete(dir)
	testing.expect(t, has_saved_odin_clip(tmp_root, "hero_walk"))

	k0_path := fmt.aprintf("%s/k_000.odin", dir); defer delete(k0_path)
	k1_path := fmt.aprintf("%s/k_001.odin", dir); defer delete(k1_path)
	testing.expect(t, os.exists(k0_path) && os.exists(k1_path))

	k0_before := read_str_file(t, k0_path); defer delete(k0_before)
	k1_before := read_str_file(t, k1_path); defer delete(k1_before)

	c.keyframes[11].rot[int(spec.Bone_Id.Head)][1] += 0.40
	dir2, save_ok2 := edit_clip_save_odin(&c, tmp_root)
	testing.expect(t, save_ok2)
	delete(dir2)

	k0_after := read_str_file(t, k0_path); defer delete(k0_after)
	k1_after := read_str_file(t, k1_path); defer delete(k1_after)
	testing.expect_value(t, k0_after, k0_before)
	testing.expect(t, k1_after != k1_before)

	loaded, load_ok := edit_clip_load_odin_dir(dir)
	testing.expect(t, load_ok)
	defer edit_clip_delete(&loaded)
	testing.expect(t, !loaded.dirty)
	assert_clip_matches(t, &c, &loaded)

	resize(&c.keyframes, 4)
	dir3, save_ok3 := edit_clip_save_odin(&c, tmp_root)
	testing.expect(t, save_ok3)
	delete(dir3)
	testing.expect(t, !os.exists(k1_path))
}

@(test)
anim_manifest_sorts_deterministically_and_rejects_malformed :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_anim_mf_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	cz := make_synthetic_clip("zeta_clip", 2)
	defer edit_clip_delete(&cz)
	ca := make_synthetic_clip("alpha_clip", 2)
	defer edit_clip_delete(&ca)

	dz, okz := edit_clip_save_odin(&cz, tmp_root); defer delete(dz)
	da, oka := edit_clip_save_odin(&ca, tmp_root); defer delete(da)
	testing.expect(t, okz && oka)

	m_path := fmt.aprintf("%s/manifest.odin", tmp_root); defer delete(m_path)
	manifest := read_str_file(t, m_path); defer delete(manifest)
	idx_a := strings.index(manifest, "a_alpha_clip.CLIP")
	idx_z := strings.index(manifest, "a_zeta_clip.CLIP")
	testing.expect(t, idx_a >= 0 && idx_z > idx_a)
	testing.expect(t, strings.contains(manifest, "find_builtin_clip"))

	// Malformed bone name must fail cleanly with 0 leaks.
	k0_path := fmt.aprintf("%s/k_000.odin", da); defer delete(k0_path)
	bad_k := "package anim_alpha_clip\nimport spec \"../../spec\"\nK_000 := [1]spec.Anim_Keyframe_Def{\n\t{time = 0.0, interp = .Smooth, root_offset = {0,0,0}, bones = {{.BadBone, {1,0,0}}}},\n}\n"
	testing.expect(t, os.write_entire_file(k0_path, bad_k) == nil)
	bad_clip, bad_ok := edit_clip_load_odin_dir(da)
	testing.expect(t, !bad_ok)
	edit_clip_delete(&bad_clip)
}

@(test)
bezier_handles_auto_clamp_align_free_and_roundtrip :: proc(t: ^testing.T) {
	tmp_root, tmp_err := os.make_directory_temp("", "dreamcraft_anim_bz_", context.allocator)
	testing.expect(t, tmp_err == nil)
	defer { _ = os.remove_all(tmp_root); delete(tmp_root) }

	c := edit_clip_init("bezier_test", "Bezier", 1.0, false, false, 0)
	defer edit_clip_delete(&c)

	k0 := Edit_Keyframe{time = 0.0, interp = .Smooth}
	k1 := Edit_Keyframe{time = 0.5, interp = .Smooth}
	k2 := Edit_Keyframe{time = 1.0, interp = .Smooth}
	k1.rot[int(spec.Bone_Id.Arm_R)][0] = 1.0
	k1.root_offset[1] = 0.25
	append(&c.keyframes, k0, k1, k2)
	recompute_clip_handles(&c)

	// Auto_Clamped peak at k1 must have zero slope (no overshoot above 1.0).
	for s in 1 ..< 20 {
		u := f32(s) / 20.0
		v := eval_channel_at_phase(&c, u, false, .Arm_R, 0)
		testing.expect(t, v >= -1e-4 && v <= 1.0001)
	}

	// Aligned drag mirrors opposite handle direction while keeping its length.
	drag_channel_handle(&c, 1, false, .Arm_R, 0, true, {0.10, 0.20}, false)
	testing.expect_value(t, c.keyframes[1].rot_handle[int(spec.Bone_Id.Arm_R)][0], spec.Anim_Handle.Aligned)
	in_h := c.keyframes[1].rot_in[int(spec.Bone_Id.Arm_R)][0]
	testing.expect(t, in_h[0] < 0 && in_h[1] < 0)

	// Free drag on root channel breaks collinearity.
	drag_channel_handle(&c, 1, true, .COUNT, 1, false, {-0.12, 0.08}, true)
	testing.expect_value(t, c.keyframes[1].root_handle[1], spec.Anim_Handle.Free)

	dir, save_ok := edit_clip_save_odin(&c, tmp_root)
	testing.expect(t, save_ok)
	defer delete(dir)

	loaded, load_ok := edit_clip_load_odin_dir(dir)
	testing.expect(t, load_ok)
	defer edit_clip_delete(&loaded)
	testing.expect_value(t, loaded.keyframes[1].rot_handle[int(spec.Bone_Id.Arm_R)][0], spec.Anim_Handle.Aligned)
	testing.expect_value(t, loaded.keyframes[1].root_handle[1], spec.Anim_Handle.Free)
	testing.expect(t, abs(loaded.keyframes[1].rot_out[int(spec.Bone_Id.Arm_R)][0][1] - 0.20) < 2e-4)
	testing.expect(t, abs(loaded.keyframes[1].root_in[1][1] - 0.08) < 2e-4)
}
