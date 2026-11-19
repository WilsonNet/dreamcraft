// Model catalog, procedural <-> Edit_Mesh bridge, and custom .odin runtime override cache.
package art

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import edit "./edit"
import models "./models"
import spec "./spec"

Catalog_Entry :: struct {
	id:            string,
	title:         string,
	category:      spec.Model_Category,
	skinned:       bool,
	ao_height:     f32,
	default_scale: f32,
	glow_override: f32,
	base_fallback: string,
}

MODEL_CATALOG := [12]Catalog_Entry {
	{id = "mamluk", title = "Mamluk Base", category = .Units, skinned = true, ao_height = 1.60, default_scale = 0.74},
	{id = "mamluk_hero", title = "Liiroy Hero", category = .Units, skinned = true, ao_height = 1.60, default_scale = 0.84, base_fallback = "mamluk"},
	{id = "mamluk_enemy", title = "Luk Soldier", category = .Units, skinned = true, ao_height = 1.60, default_scale = 0.74, base_fallback = "mamluk"},
	{id = "pine_tall", title = "Pine Tall", category = .Trees, ao_height = 3.20, default_scale = 1.0},
	{id = "pine_mid", title = "Pine Mid", category = .Trees, ao_height = 3.20, default_scale = 1.0},
	{id = "oak_broad", title = "Oak Broad", category = .Trees, ao_height = 3.20, default_scale = 1.0},
	{id = "oak_elder", title = "Oak Elder", category = .Trees, ao_height = 3.20, default_scale = 1.0},
	{id = "boulder_moss", title = "Mossy Boulder", category = .Props, ao_height = 0.45, default_scale = 1.0},
	{id = "shrub_fern", title = "Shrub Fern", category = .Props, ao_height = 0.45, default_scale = 1.0},
	{id = "waypoint_disc", title = "Waypoint Disc", category = .Props, ao_height = 0.15, default_scale = 1.0},
	{id = "goal_banner", title = "Goal Banner", category = .Props, ao_height = 2.80, default_scale = 1.0},
	{id = "selection_ring", title = "Selection Ring", category = .Props, ao_height = 0.10, default_scale = 1.0, glow_override = 0.35},
}

@(private)
Live_Slot :: struct {
	active: bool,
	mesh:   edit.Edit_Mesh,
}

@(private)
g_custom_cache: struct {
	mu:    sync.Mutex,
	slots: [len(MODEL_CATALOG)]Live_Slot,
}

@(private, thread_local)
g_force_procedural: bool

// Locate the client/art/models directory relative to the current working directory.
resolve_models_root :: proc() -> (string, bool) {
	for p in ([2]string{"client/art/models", "odin/client/art/models"}) {
		if os.is_dir(p) { return p, true }
	}
	return "", false
}

catalog_find :: proc(id: string) -> (Catalog_Entry, bool) {
	idx := catalog_index(id)
	return idx >= 0 ? MODEL_CATALOG[idx] : {}, idx >= 0
}

@(private)
catalog_index :: proc(id: string) -> int {
	for entry, i in MODEL_CATALOG {
		if entry.id == id { return i }
	}
	return -1
}

// Register a deep copy of em as a live runtime override for catalog id.
register_live_edit_mesh :: proc(id: string, em: ^edit.Edit_Mesh) -> bool {
	idx := catalog_index(id)
	if idx < 0 || em == nil { return false }
	sync.mutex_lock(&g_custom_cache.mu)
	defer sync.mutex_unlock(&g_custom_cache.mu)
	clear_live_slot(&g_custom_cache.slots[idx])
	g_custom_cache.slots[idx] = {active = true, mesh = edit.edit_mesh_clone(em)}
	return true
}

clear_live_edit_mesh :: proc(id: string) {
	sync.mutex_lock(&g_custom_cache.mu)
	defer sync.mutex_unlock(&g_custom_cache.mu)
	if idx := catalog_index(id); idx >= 0 { clear_live_slot(&g_custom_cache.slots[idx]) }
}

clear_all_live_edit_meshes :: proc() {
	sync.mutex_lock(&g_custom_cache.mu)
	defer sync.mutex_unlock(&g_custom_cache.mu)
	for &slot in g_custom_cache.slots { clear_live_slot(&slot) }
}

@(private)
clear_live_slot :: proc(slot: ^Live_Slot) {
	if slot.active {
		edit.edit_mesh_delete(&slot.mesh)
		slot.active = false
	}
}

// Return true if id has a live, on-disk .odin, or compiled builtin override.
catalog_has_custom_odin :: proc(id: string) -> bool {
	if idx := catalog_index(id); idx >= 0 {
		sync.mutex_lock(&g_custom_cache.mu)
		active := g_custom_cache.slots[idx].active
		sync.mutex_unlock(&g_custom_cache.mu)
		if active { return true }
	}
	if root, ok := resolve_models_root(); ok && edit.has_saved_odin_model(root, id) {
		return true
	}
	_, builtin_ok := models.find_builtin_asset(id)
	return builtin_ok
}

// Build the hardcoded procedural Mesh_Builder for id, bypassing custom overrides.
build_procedural_by_id :: proc(id: string, enemy: bool = false, hero: bool = false) -> (Mesh_Builder, bool) {
	prev := g_force_procedural
	g_force_procedural = true
	defer g_force_procedural = prev

	switch id {
	case "mamluk":         return build_mamluk(enemy, hero), true
	case "mamluk_hero":    return build_mamluk(enemy, true), true
	case "mamluk_enemy":   return build_mamluk(true, hero), true
	case "pine_tall":      return build_pine_tall(), true
	case "pine_mid":       return build_pine_mid(), true
	case "oak_broad":      return build_oak_broad(), true
	case "oak_elder":      return build_oak_elder(), true
	case "boulder_moss":   return build_boulder_moss(), true
	case "shrub_fern":     return build_shrub_fern(), true
	case "waypoint_disc":  return build_waypoint_disc(), true
	case "goal_banner":    return build_goal_banner(), true
	case "selection_ring": return build_selection_ring(), true
	}
	return {}, false
}

// Try building a custom override Mesh_Builder for id (with base_fallback support).
try_build_custom_model :: proc(id: string, enemy: bool = false, hero: bool = false) -> (Mesh_Builder, bool) {
	if g_force_procedural { return {}, false }
	entry, ok := catalog_find(id)
	if !ok { return {}, false }
	pal := entry.skinned ? palette_for_unit(enemy, hero) : palette_for_team(false)
	if b, hit := try_build_exact_custom(id, pal); hit { return b, true }
	if entry.base_fallback != "" {
		return try_build_exact_custom(entry.base_fallback, pal)
	}
	return {}, false
}

@(private)
try_build_exact_custom :: proc(id: string, pal: Team_Palette) -> (Mesh_Builder, bool) {
	if idx := catalog_index(id); idx >= 0 {
		sync.mutex_lock(&g_custom_cache.mu)
		if g_custom_cache.slots[idx].active {
			b := edit_mesh_to_mesh_builder(&g_custom_cache.slots[idx].mesh, pal)
			sync.mutex_unlock(&g_custom_cache.mu)
			return b, true
		}
		sync.mutex_unlock(&g_custom_cache.mu)
	}
	if em, ok := load_disk_or_builtin(id); ok {
		defer edit.edit_mesh_delete(&em)
		return edit_mesh_to_mesh_builder(&em, pal), true
	}
	return {}, false
}

// Load an Edit_Mesh from live/disk/builtin .odin or procedural fallback.
catalog_load_edit_mesh :: proc(id: string, force_procedural := false) -> (edit.Edit_Mesh, bool) {
	entry, ok := catalog_find(id)
	if !ok { return {}, false }
	if !force_procedural {
		if em, hit := load_exact_custom_edit_mesh(id); hit { return em, true }
		if entry.base_fallback != "" {
			if em, hit := load_exact_custom_edit_mesh(entry.base_fallback); hit {
				relabel_edit_mesh(&em, entry)
				return em, true
			}
		}
	}
	b, b_ok := build_procedural_by_id(id, id == "mamluk_enemy", id == "mamluk_hero")
	if !b_ok { return {}, false }
	defer mb_delete(&b)
	return mesh_builder_to_edit_mesh(&b, entry), true
}

@(private)
load_exact_custom_edit_mesh :: proc(id: string) -> (edit.Edit_Mesh, bool) {
	if idx := catalog_index(id); idx >= 0 {
		sync.mutex_lock(&g_custom_cache.mu)
		if g_custom_cache.slots[idx].active {
			em := edit.edit_mesh_clone(&g_custom_cache.slots[idx].mesh)
			sync.mutex_unlock(&g_custom_cache.mu)
			return em, true
		}
		sync.mutex_unlock(&g_custom_cache.mu)
	}
	return load_disk_or_builtin(id)
}

@(private)
load_disk_or_builtin :: proc(id: string) -> (edit.Edit_Mesh, bool) {
	if root, ok := resolve_models_root(); ok && edit.has_saved_odin_model(root, id) {
		dir := fmt.aprintf("%s/%s", root, id)
		defer delete(dir)
		if em, load_ok := edit.edit_mesh_load_odin_dir(dir); load_ok { return em, true }
	}
	if def, found := models.find_builtin_asset(id); found {
		return edit.edit_mesh_from_asset_def(def), true
	}
	return {}, false
}

@(private)
relabel_edit_mesh :: proc(em: ^edit.Edit_Mesh, entry: Catalog_Entry) {
	delete(em.id); delete(em.title)
	em.id, em.title = strings.clone(entry.id), strings.clone(entry.title)
	em.category, em.skinned = entry.category, entry.skinned
	em.ao_height, em.default_scale, em.glow_override = entry.ao_height, entry.default_scale, entry.glow_override
}
