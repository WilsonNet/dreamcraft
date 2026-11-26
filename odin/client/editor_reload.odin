// GPU preview rebuild, live skeletal pose evaluation, and hot-reload into the active game.
package main

import "core:c"
import "core:fmt"
import "core:os"
import rl "../gfx"
import art "./art"
import edit "./art/edit"

editor_preview_palette :: proc() -> art.Team_Palette {
	if !app.editor.mesh.skinned {
		return art.palette_for_team(false)
	}
	switch app.editor.preview_team {
	case .Hero:   return art.palette_for_unit(false, true)
	case .Player: return art.palette_for_unit(false, false)
	case .Enemy:  return art.palette_for_unit(true, false)
	}
	return art.palette_for_unit(false, true)
}

editor_rebuild_preview_gpu :: proc() {
	ed := &app.editor
	if !ed.mesh_loaded {
		return
	}
	b := art.edit_mesh_to_mesh_builder(&ed.mesh, editor_preview_palette())
	defer art.mb_delete(&b)
	unload_unit_model(&ed.preview_model)
	if !b.overflow && len(b.pos) > 0 && len(b.idx) > 0 {
		upload_builder(&b, &ed.preview_model, ed.preview_team == .Enemy)
		ed.preview_model.hero = ed.preview_team == .Hero
	}
	ed.preview_dirty_gpu = false
	editor_update_pose_matrices(0)
}

editor_update_pose_matrices :: proc(dt: f32) {
	ed := &app.editor
	enemy := ed.preview_team == .Enemy
	hero := ed.preview_team == .Hero
	if ed.pose_playing && ed.pose_kind != .Rest {
		dur := art.anim_clip_duration(.Idle, enemy, hero)
		if ed.pose_kind == .Walk { dur = art.anim_clip_duration(.Walk, enemy, hero) }
		if ed.pose_kind == .Attack { dur = art.anim_clip_duration(.Attack, enemy, hero) }
		ed.pose_phase = math_mod(ed.pose_phase + dt / max(dur, f32(0.1)), 1.0)
	}
	if !ed.mesh.skinned || ed.pose_kind == .Rest {
		for i in 0..<art.BONE_COUNT {
			ed.pose_mats[i] = rl.Matrix(1)
		}
		return
	}
	pose: art.Pose
	switch ed.pose_kind {
	case .Rest:
	case .Idle:
		art.eval_unit_idle(ed.pose_phase, enemy, hero, &pose)
	case .Walk:
		art.eval_unit_walk(ed.pose_phase, enemy, hero, &pose)
	case .Attack:
		art.eval_unit_idle(0.25, enemy, hero, &pose)
		art.eval_unit_attack(ed.pose_phase, enemy, hero, &pose)
	}
	ed.pose_mats = art.pose_matrices(&pose, rl.Matrix(1))
}

editor_posed_vert_pos :: proc(vert_idx: int) -> rl.Vector3 {
	ed := &app.editor
	p := rl.Vector3(ed.mesh.verts[vert_idx].pos)
	if !ed.mesh.skinned || ed.pose_kind == .Rest {
		return p
	}
	bi := clamp(int(ed.mesh.verts[vert_idx].bone), 0, art.BONE_COUNT - 1)
	return art.xf_point(ed.pose_mats[bi], p)
}

editor_draw_preview_mesh :: proc() {
	ed := &app.editor
	if ed.preview_dirty_gpu {
		editor_rebuild_preview_gpu()
	}
	m := &ed.preview_model
	if !m.loaded {
		return
	}
	art.skin_vertices(m.rest_pos, m.rest_nrm, m.pos, m.nrm, m.bones, ed.pose_mats)
	bytes := c.int(len(m.pos) * size_of(rl.Vector3))
	rl.UpdateMeshBuffer(m.mesh, 0, raw_data(m.pos), bytes, 0)
	rl.UpdateMeshBuffer(m.mesh, 2, raw_data(m.nrm), bytes, 0)
	rl.DrawMesh(m.mesh, m.material, rl.Matrix(1))
}

editor_ensure_picker_preview :: proc(id: string) {
	ed := &app.editor
	if ed.picker_preview_id == id && ed.picker_preview.loaded {
		return
	}
	em, ok := art.catalog_load_edit_mesh(id)
	if !ok {
		return
	}
	defer edit.edit_mesh_delete(&em)
	pal := art.palette_for_team(false)
	if em.skinned {
		pal = art.palette_for_unit(id == "mamluk_enemy", id != "mamluk_enemy")
	}
	b := art.edit_mesh_to_mesh_builder(&em, pal)
	defer art.mb_delete(&b)
	unload_unit_model(&ed.picker_preview)
	if !b.overflow && len(b.pos) > 0 && len(b.idx) > 0 {
		upload_builder(&b, &ed.picker_preview, id == "mamluk_enemy")
		ed.picker_preview_id = id
	}
}

editor_save_and_hot_reload :: proc() -> bool {
	ed := &app.editor
	if !ed.mesh_loaded {
		return false
	}
	_ = art.register_live_edit_mesh(ed.mesh.id, &ed.mesh)
	saved_disk := false
	save_note := "live memory"
	if root, ok := art.resolve_models_root(); ok {
		if dir, dir_ok := edit.edit_mesh_save_odin(&ed.mesh, root); dir_ok {
			saved_disk = true
			save_note = root
			delete(dir)
		}
	} else {
		_ = os.make_directory_all("models_override")
		if dir, dir_ok := edit.edit_mesh_save_odin(&ed.mesh, "models_override"); dir_ok {
			saved_disk = true
			save_note = "models_override"
			delete(dir)
		}
	}
	reload_live_game_models()
	ed.mesh.dirty = false
	if saved_disk {
		editor_set_status(fmt.tprintf("Saved %s/*.odin & hot-reloaded game", save_note), false, 3.8)
	} else {
		editor_set_status("Hot-reloaded in game (disk save failed)", true, 3.8)
	}
	return saved_disk
}

editor_reload_from_odin :: proc() -> bool {
	ed := &app.editor
	if !ed.mesh_loaded {
		return false
	}
	id := fmt.tprintf("%s", ed.mesh.id)
	art.clear_live_edit_mesh(id)
	return editor_open_model(id, false)
}

editor_reset_to_procedural :: proc() -> bool {
	ed := &app.editor
	if !ed.mesh_loaded {
		return false
	}
	edit.undo_push(&ed.undo, &ed.mesh)
	em, ok := art.catalog_load_edit_mesh(ed.mesh.id, true)
	if !ok {
		return false
	}
	edit.edit_mesh_delete(&ed.mesh)
	ed.mesh = em
	ed.mesh.dirty = true
	editor_rebuild_preview_gpu()
	editor_set_status("Reset mesh from procedural Odin (Save to apply)", false, 3.2)
	return true
}

reload_live_game_models :: proc() {
	for &m in app.models {
		unload_unit_model(&m)
	}
	init_warrior_assets()
	init_env_assets()
	if app.mode == .Model_Picker && app.editor.picker_idx >= 0 && app.editor.picker_idx < len(art.MODEL_CATALOG) {
		app.editor.picker_preview_id = ""
		editor_ensure_picker_preview(art.MODEL_CATALOG[app.editor.picker_idx].id)
	}
	if app.anim_ed.preview_model.loaded {
		anim_editor_rebuild_preview_model()
	}
	if app.anim_ed.picker_preview.loaded {
		unload_unit_model(&app.anim_ed.picker_preview)
		anim_editor_ensure_picker_preview(app.anim_ed.picker_idx)
	}
}
