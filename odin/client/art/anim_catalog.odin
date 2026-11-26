// Animation clip catalog, procedural baking, live runtime cache, and zero-alloc evaluators.
package art

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import rl "../../gfx"
import anim_edit "./anim_edit"
import anims "./anims"
import spec "./spec"

Anim_Catalog_Entry :: struct {
	id:               string,
	title:            string,
	category:         spec.Anim_Category,
	kind:             spec.Anim_Kind,
	duration:         f32,
	loop:             bool,
	additive:         bool,
	secondary_weight: f32,
	base_fallback:    string,
}

ANIM_CATALOG := [9]Anim_Catalog_Entry {
	{id = "idle", title = "Mamluk Idle", category = .Base, kind = .Idle, duration = ANIM_IDLE_SECONDS, loop = true, additive = false, secondary_weight = 0.16},
	{id = "walk", title = "Mamluk Walk", category = .Base, kind = .Walk, duration = ANIM_WALK_SECONDS * 2.0, loop = true, additive = false, secondary_weight = 1.00},
	{id = "attack", title = "Mamluk Attack", category = .Base, kind = .Attack, duration = ANIM_ATTACK_SECONDS, loop = false, additive = true, secondary_weight = 0.00},
	{id = "hero_idle", title = "Liiroy Idle", category = .Hero, kind = .Idle, duration = ANIM_IDLE_SECONDS, loop = true, additive = false, secondary_weight = 0.16, base_fallback = "idle"},
	{id = "hero_walk", title = "Liiroy Walk", category = .Hero, kind = .Walk, duration = ANIM_WALK_SECONDS * 2.0, loop = true, additive = false, secondary_weight = 1.00, base_fallback = "walk"},
	{id = "hero_attack", title = "Liiroy Attack", category = .Hero, kind = .Attack, duration = ANIM_ATTACK_SECONDS, loop = false, additive = true, secondary_weight = 0.00, base_fallback = "attack"},
	{id = "enemy_idle", title = "Luk Soldier Idle", category = .Enemy, kind = .Idle, duration = ANIM_IDLE_SECONDS, loop = true, additive = false, secondary_weight = 0.16, base_fallback = "idle"},
	{id = "enemy_walk", title = "Luk Soldier Walk", category = .Enemy, kind = .Walk, duration = ANIM_WALK_SECONDS * 2.0, loop = true, additive = false, secondary_weight = 1.00, base_fallback = "walk"},
	{id = "enemy_attack", title = "Luk Soldier Attack", category = .Enemy, kind = .Attack, duration = ANIM_ATTACK_SECONDS, loop = false, additive = true, secondary_weight = 0.00, base_fallback = "attack"},
}

@(private)
Live_Anim_Slot :: struct {
	active: bool,
	clip:   anim_edit.Edit_Clip,
}

@(private)
g_anim_cache: struct {
	mu:    sync.Mutex,
	slots: [len(ANIM_CATALOG)]Live_Anim_Slot,
}

// Locate the client/art/anims directory relative to the current working directory.
resolve_anims_root :: proc() -> (string, bool) {
	for p in ([2]string{"client/art/anims", "odin/client/art/anims"}) {
		if os.is_dir(p) { return p, true }
	}
	return "", false
}

anim_catalog_find :: proc(id: string) -> (Anim_Catalog_Entry, bool) {
	idx := anim_catalog_index(id)
	return idx >= 0 ? ANIM_CATALOG[idx] : {}, idx >= 0
}

@(private)
anim_catalog_index :: proc(id: string) -> int {
	for entry, i in ANIM_CATALOG {
		if entry.id == id { return i }
	}
	return -1
}

register_live_clip :: proc(id: string, clip: ^anim_edit.Edit_Clip) -> bool {
	idx := anim_catalog_index(id)
	if idx < 0 || clip == nil { return false }
	sync.mutex_lock(&g_anim_cache.mu)
	defer sync.mutex_unlock(&g_anim_cache.mu)
	clear_live_anim_slot(&g_anim_cache.slots[idx])
	g_anim_cache.slots[idx] = {active = true, clip = anim_edit.edit_clip_clone(clip)}
	return true
}

clear_live_clip :: proc(id: string) {
	sync.mutex_lock(&g_anim_cache.mu)
	defer sync.mutex_unlock(&g_anim_cache.mu)
	if idx := anim_catalog_index(id); idx >= 0 {
		clear_live_anim_slot(&g_anim_cache.slots[idx])
	}
}

clear_all_live_clips :: proc() {
	sync.mutex_lock(&g_anim_cache.mu)
	defer sync.mutex_unlock(&g_anim_cache.mu)
	for &slot in g_anim_cache.slots {
		clear_live_anim_slot(&slot)
	}
}

@(private)
clear_live_anim_slot :: proc(slot: ^Live_Anim_Slot) {
	if slot.active {
		anim_edit.edit_clip_delete(&slot.clip)
		slot.active = false
	}
}

anim_catalog_has_custom_odin :: proc(id: string) -> bool {
	if idx := anim_catalog_index(id); idx >= 0 {
		sync.mutex_lock(&g_anim_cache.mu)
		active := g_anim_cache.slots[idx].active
		sync.mutex_unlock(&g_anim_cache.mu)
		if active { return true }
	}
	if root, ok := resolve_anims_root(); ok && anim_edit.has_saved_odin_clip(root, id) {
		return true
	}
	_, builtin_ok := anims.find_builtin_clip(id)
	return builtin_ok
}

reload_anim_clip_from_disk :: proc(id: string) -> bool {
	idx := anim_catalog_index(id)
	if idx < 0 { return false }
	if c, ok := load_anim_disk_or_builtin(id); ok {
		defer anim_edit.edit_clip_delete(&c)
		return register_live_clip(id, &c)
	}
	clear_live_clip(id)
	return false
}

reload_all_anim_clips_from_disk :: proc() {
	for entry in ANIM_CATALOG {
		_ = reload_anim_clip_from_disk(entry.id)
	}
}

bake_procedural_clip :: proc(id: string) -> (anim_edit.Edit_Clip, bool) {
	entry, ok := anim_catalog_find(id)
	if !ok { return {}, false }
	c := anim_edit.edit_clip_init(
		entry.id, entry.title, entry.duration,
		entry.loop, entry.additive, entry.secondary_weight,
	)
	times: [9]f32
	switch entry.kind {
	case .Idle:   times = {0.000, 0.125, 0.250, 0.375, 0.500, 0.625, 0.750, 0.875, 1.000}
	case .Walk:   times = {0.00, 0.12, 0.25, 0.38, 0.50, 0.62, 0.75, 0.88, 1.00}
	case .Attack: times = {0.00, 0.14, 0.24, 0.32, 0.42, 0.52, 0.66, 0.84, 1.00}
	}
	for t in times {
		pose: Pose
		switch entry.kind {
		case .Idle:   pose_idle(t, &pose)
		case .Walk:   pose_walk(t, &pose)
		case .Attack: pose_attack(t, &pose)
		}
		ekf := anim_edit.Edit_Keyframe{
			time        = t,
			interp      = .Smooth,
			root_offset = {pose.root_offset.x, pose.root_offset.y, pose.root_offset.z},
		}
		for bi in 0 ..< BONE_COUNT {
			ekf.rot[bi] = {pose.rot[bi].x, pose.rot[bi].y, pose.rot[bi].z}
		}
		append(&c.keyframes, ekf)
	}
	anim_edit.recompute_clip_handles(&c)
	c.dirty = false
	return c, true
}

anim_catalog_load_edit_clip :: proc(id: string, force_procedural := false) -> (anim_edit.Edit_Clip, bool) {
	entry, ok := anim_catalog_find(id)
	if !ok { return {}, false }
	if !force_procedural {
		if c, hit := load_exact_custom_clip(id); hit { return c, true }
		if entry.base_fallback != "" {
			if c, hit := load_exact_custom_clip(entry.base_fallback); hit {
				relabel_edit_clip(&c, entry)
				return c, true
			}
		}
	}
	return bake_procedural_clip(id)
}

@(private)
load_exact_custom_clip :: proc(id: string) -> (anim_edit.Edit_Clip, bool) {
	if idx := anim_catalog_index(id); idx >= 0 {
		sync.mutex_lock(&g_anim_cache.mu)
		if g_anim_cache.slots[idx].active {
			c := anim_edit.edit_clip_clone(&g_anim_cache.slots[idx].clip)
			sync.mutex_unlock(&g_anim_cache.mu)
			return c, true
		}
		sync.mutex_unlock(&g_anim_cache.mu)
	}
	return load_anim_disk_or_builtin(id)
}

@(private)
load_anim_disk_or_builtin :: proc(id: string) -> (anim_edit.Edit_Clip, bool) {
	if root, ok := resolve_anims_root(); ok && anim_edit.has_saved_odin_clip(root, id) {
		dir := fmt.aprintf("%s/%s", root, id)
		defer delete(dir)
		if c, load_ok := anim_edit.edit_clip_load_odin_dir(dir); load_ok {
			return c, true
		}
	}
	if def, found := anims.find_builtin_clip(id); found {
		return anim_edit.edit_clip_from_def(def), true
	}
	return {}, false
}

@(private)
relabel_edit_clip :: proc(c: ^anim_edit.Edit_Clip, entry: Anim_Catalog_Entry) {
	delete(c.id)
	delete(c.title)
	c.id = strings.clone(entry.id)
	c.title = strings.clone(entry.title)
}

@(private)
unit_anim_ids :: proc(kind: spec.Anim_Kind, enemy, hero: bool) -> (specific, base: string) {
	switch kind {
	case .Idle:   base = "idle";   specific = enemy ? "enemy_idle" : (hero ? "hero_idle" : "idle")
	case .Walk:   base = "walk";   specific = enemy ? "enemy_walk" : (hero ? "hero_walk" : "walk")
	case .Attack: base = "attack"; specific = enemy ? "enemy_attack" : (hero ? "hero_attack" : "attack")
	}
	return
}

@(private)
eval_cached_clip :: proc(
	kind: spec.Anim_Kind,
	phase: f32,
	enemy, hero: bool,
) -> (rot: [BONE_COUNT][3]f32, root_offset: [3]f32, additive: bool, sec_w: f32, ok: bool) {
	spec_id, base_id := unit_anim_ids(kind, enemy, hero)
	spec_idx := anim_catalog_index(spec_id)
	base_idx := anim_catalog_index(base_id)
	sync.mutex_lock(&g_anim_cache.mu)
	defer sync.mutex_unlock(&g_anim_cache.mu)
	slot_idx := -1
	if spec_idx >= 0 && g_anim_cache.slots[spec_idx].active {
		slot_idx = spec_idx
	} else if base_idx >= 0 && g_anim_cache.slots[base_idx].active {
		slot_idx = base_idx
	}
	if slot_idx < 0 {
		return
	}
	c := &g_anim_cache.slots[slot_idx].clip
	rot, root_offset = anim_edit.eval_edit_clip(c, phase)
	return rot, root_offset, c.additive, c.secondary_weight, true
}

anim_clip_duration :: proc(kind: spec.Anim_Kind, enemy: bool = false, hero: bool = false) -> f32 {
	spec_id, base_id := unit_anim_ids(kind, enemy, hero)
	spec_idx := anim_catalog_index(spec_id)
	base_idx := anim_catalog_index(base_id)
	sync.mutex_lock(&g_anim_cache.mu)
	defer sync.mutex_unlock(&g_anim_cache.mu)
	if spec_idx >= 0 && g_anim_cache.slots[spec_idx].active {
		return max(g_anim_cache.slots[spec_idx].clip.duration, 0.05)
	}
	if base_idx >= 0 && g_anim_cache.slots[base_idx].active {
		return max(g_anim_cache.slots[base_idx].clip.duration, 0.05)
	}
	switch kind {
	case .Idle:   return ANIM_IDLE_SECONDS
	case .Walk:   return ANIM_WALK_SECONDS * 2.0
	case .Attack: return ANIM_ATTACK_SECONDS
	}
	return 1.0
}

eval_unit_idle :: proc(phase: f32, enemy, hero: bool, pose: ^Pose) {
	if rot, root_off, _, sec_w, ok := eval_cached_clip(.Idle, phase, enemy, hero); ok {
		apply_clip_to_pose(pose, rot, root_off, false)
		if sec_w > 0.001 {
			pose_secondary(phase, sec_w, pose)
		}
		return
	}
	pose_idle(phase, pose)
	pose_secondary(phase, 0.16, pose)
}

eval_unit_walk :: proc(phase: f32, enemy, hero: bool, pose: ^Pose) {
	if rot, root_off, _, sec_w, ok := eval_cached_clip(.Walk, phase, enemy, hero); ok {
		apply_clip_to_pose(pose, rot, root_off, false)
		if sec_w > 0.001 {
			pose_secondary(phase, sec_w, pose)
		}
		return
	}
	pose_walk(phase, pose)
	pose_secondary(phase, 1.0, pose)
}

eval_unit_attack :: proc(t: f32, enemy, hero: bool, pose: ^Pose) {
	if rot, root_off, additive, sec_w, ok := eval_cached_clip(.Attack, t, enemy, hero); ok {
		apply_clip_to_pose(pose, rot, root_off, additive)
		if !additive && sec_w > 0.001 {
			pose_secondary(t, sec_w, pose)
		}
		return
	}
	pose_attack(t, pose)
}

@(private)
apply_clip_to_pose :: proc(pose: ^Pose, rot: [BONE_COUNT][3]f32, root_off: [3]f32, additive: bool) {
	if additive {
		for i in 0 ..< BONE_COUNT {
			pose.rot[i] += rl.Vector3(rot[i])
		}
		pose.root_offset += rl.Vector3(root_off)
		return
	}
	pose^ = {}
	for i in 0 ..< BONE_COUNT {
		pose.rot[i] = rl.Vector3(rot[i])
	}
	pose.root_offset = rl.Vector3(root_off)
}
