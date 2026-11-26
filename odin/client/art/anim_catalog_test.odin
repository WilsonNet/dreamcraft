#+build !js
package art

import "core:math"
import "core:testing"
import anim_edit "./anim_edit"
import spec "./spec"

@(test)
all_9_anim_clips_bake_cleanly_from_procedural :: proc(t: ^testing.T) {
	testing.expect_value(t, len(ANIM_CATALOG), 9)
	for entry in ANIM_CATALOG {
		c, ok := bake_procedural_clip(entry.id)
		testing.expect(t, ok)
		defer anim_edit.edit_clip_delete(&c)
		testing.expect_value(t, c.id, entry.id)
		testing.expect_value(t, len(c.keyframes), 9)
		testing.expect(t, c.duration > 0.1)
	}
}

@(test)
live_clip_override_and_fallback_work_and_restore :: proc(t: ^testing.T) {
	defer clear_all_live_clips()

	testing.expect(t, abs(anim_clip_duration(.Attack, false, true) - ANIM_ATTACK_SECONDS) < 1e-4)

	c := anim_edit.edit_clip_init("attack", "Custom Attack", 0.90, false, true, 0)
	defer anim_edit.edit_clip_delete(&c)
	kf := anim_edit.Edit_Keyframe{time = 0.5, interp = .Linear}
	kf.rot[int(Bone_Id.Arm_R)] = {0.8, 0.0, 0.0}
	append(&c.keyframes, kf)

	testing.expect(t, register_live_clip("attack", &c))
	testing.expect(t, anim_catalog_has_custom_odin("attack"))
	testing.expect(t, !anim_catalog_has_custom_odin("hero_attack"))
	testing.expect(t, abs(anim_clip_duration(.Attack, false, true) - 0.90) < 1e-4)

	base_pose, hero_pose, enemy_pose: Pose
	eval_unit_attack(0.5, false, false, &base_pose)
	eval_unit_attack(0.5, false, true, &hero_pose)
	eval_unit_attack(0.5, true, false, &enemy_pose)
	testing.expect(t, abs(base_pose.rot[int(Bone_Id.Arm_R)].x - 0.8) < 1e-4)
	testing.expect(t, abs(hero_pose.rot[int(Bone_Id.Arm_R)].x - 0.8) < 1e-4)
	testing.expect(t, abs(enemy_pose.rot[int(Bone_Id.Arm_R)].x - 0.8) < 1e-4)

	// Relabeled fallback load for hero_attack.
	loaded_hero, lh_ok := anim_catalog_load_edit_clip("hero_attack")
	testing.expect(t, lh_ok)
	defer anim_edit.edit_clip_delete(&loaded_hero)
	testing.expect_value(t, loaded_hero.id, "hero_attack")

	clear_live_clip("attack")
	testing.expect(t, abs(anim_clip_duration(.Attack, false, true) - ANIM_ATTACK_SECONDS) < 1e-4)

	restored: Pose
	eval_unit_attack(0.5, false, false, &restored)
	proc_pose: Pose
	pose_attack(0.5, &proc_pose)
	testing.expect(t, abs(restored.rot[int(Bone_Id.Arm_R)].x - proc_pose.rot[int(Bone_Id.Arm_R)].x) < 1e-5)
	testing.expect(t, !math.is_nan(restored.rot[int(Bone_Id.Arm_R)].x))
}

@(test)
anims_root_resolves :: proc(t: ^testing.T) {
	root, ok := resolve_anims_root()
	testing.expect(t, ok)
	testing.expect(t, len(root) > 0)
	_ = spec.Anim_Kind.Idle
}
