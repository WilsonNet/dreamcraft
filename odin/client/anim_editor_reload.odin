// Animation Editor preview pose evaluation, grounding, .odin save, hot-reload, and disk watcher.
package main

import "core:fmt"
import "core:os"
import rl "../gfx"
import art "./art"
import anim_edit "./art/anim_edit"

anim_editor_rebuild_preview_model :: proc() {
	ed := &app.anim_ed
	unload_unit_model(&ed.preview_model)
	ed.preview_model = build_unit_model(ed.preview_team == .Enemy, ed.preview_team == .Hero)
}

anim_editor_ensure_picker_preview :: proc(idx: int) {
	ed := &app.anim_ed
	i := clamp(idx, 0, len(art.ANIM_CATALOG) - 1)
	entry := art.ANIM_CATALOG[i]
	want_team: Unit_Preview_Palette = .Player
	if entry.category == .Enemy {
		want_team = .Enemy
	} else if entry.category == .Hero {
		want_team = .Hero
	}
	if ed.picker_preview.loaded && ed.picker_preview_team == want_team {
		return
	}
	unload_unit_model(&ed.picker_preview)
	ed.picker_preview = build_unit_model(want_team == .Enemy, want_team == .Hero)
	ed.picker_preview_team = want_team
}

anim_editor_eval_preview_pose :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return
	}
	rot, root_off := anim_edit.eval_edit_clip(&ed.clip, ed.playhead)
	pose: art.Pose
	if ed.clip.additive {
		enemy := ed.preview_team == .Enemy
		hero := ed.preview_team == .Hero
		art.eval_unit_idle(0.25, enemy, hero, &pose)
		for i in 0 ..< art.BONE_COUNT {
			pose.rot[i] += rl.Vector3(rot[i])
		}
		pose.root_offset += rl.Vector3(root_off)
	} else {
		for i in 0 ..< art.BONE_COUNT {
			pose.rot[i] = rl.Vector3(rot[i])
		}
		pose.root_offset = rl.Vector3(root_off)
		if ed.clip.secondary_weight > 0.001 {
			art.pose_secondary(ed.playhead, ed.clip.secondary_weight, &pose)
		}
	}
	ed.current_pose = pose
	ed.pose_mats = art.pose_matrices(&pose, rl.Matrix(1))
	if !(ed.modal_active && ed.modal_is_ctrl) && !ed.slider_undo_armed {
		anim_sync_rig_from_preview()
	}
}

anim_editor_ground_feet_y0 :: proc() {
	ed := &app.anim_ed
	if !ed.clip_loaded || !ed.preview_model.loaded {
		return
	}
	anim_editor_eval_preview_pose()
	m := &ed.preview_model
	min_foot := f32(1e9)
	found_foot := false
	min_all := f32(1e9)
	for i in 0 ..< len(m.rest_pos) {
		bi := clamp(int(m.bones[i]), 0, art.BONE_COUNT - 1)
		p := art.xf_point(ed.pose_mats[bi], m.rest_pos[i])
		min_all = min(min_all, p.y)
		b := art.Bone_Id(bi)
		if b == .Foot_L || b == .Foot_R {
			min_foot = min(min_foot, p.y)
			found_foot = true
		}
	}
	floor_y := found_foot ? min_foot : min_all
	if floor_y > 1e8 {
		return
	}
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	kf := anim_ensure_editable_kf()
	kf.root_offset[1] -= floor_y
	anim_edit.recompute_clip_handles(&ed.clip)
	ed.clip.dirty = true
	anim_editor_eval_preview_pose()
	anim_editor_set_status("Grounded feet to Y=0", false, 2.0)
}

anim_editor_save_and_hot_reload :: proc() -> bool {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return false
	}
	_ = art.register_live_clip(ed.clip.id, &ed.clip)
	saved_disk := false
	save_note := "live memory"
	if root, ok := art.resolve_anims_root(); ok {
		if dir, dir_ok := anim_edit.edit_clip_save_odin(&ed.clip, root); dir_ok {
			saved_disk = true
			save_note = root
			delete(dir)
		}
	} else {
		_ = os.make_directory_all("anims_override")
		if dir, dir_ok := anim_edit.edit_clip_save_odin(&ed.clip, "anims_override"); dir_ok {
			saved_disk = true
			save_note = "anims_override"
			delete(dir)
		}
	}
	refresh_anim_watch_mtimes()
	ed.clip.dirty = false
	if saved_disk {
		anim_editor_set_status(fmt.tprintf("Saved %s/%s/*.odin & hot-reloaded game", save_note, ed.clip.id), false, 3.8)
	} else {
		anim_editor_set_status("Hot-reloaded in game (disk save failed)", true, 3.8)
	}
	return saved_disk
}

anim_editor_reset_to_procedural :: proc() -> bool {
	ed := &app.anim_ed
	if !ed.clip_loaded {
		return false
	}
	anim_edit.anim_undo_push(&ed.undo, &ed.clip)
	c, ok := art.bake_procedural_clip(ed.clip.id)
	if !ok {
		return false
	}
	anim_edit.edit_clip_delete(&ed.clip)
	ed.clip = c
	ed.clip.dirty = true
	ed.selected_kf = clamp(ed.selected_kf, 0, max(len(ed.clip.keyframes) - 1, 0))
	anim_curves_fit_view()
	anim_editor_eval_preview_pose()
	anim_editor_set_status("Reset clip from procedural Odin (Save to apply)", false, 3.2)
	return true
}

init_anim_disk_watcher :: proc() {
	refresh_anim_watch_mtimes()
	app.anim_ed.watch_ready = true
	app.anim_ed.watch_accum = 0
}

@(private)
refresh_anim_watch_mtimes :: proc() {
	root, ok := art.resolve_anims_root()
	if !ok {
		app.anim_ed.watch_mtimes = {}
		return
	}
	for entry, i in art.ANIM_CATALOG {
		app.anim_ed.watch_mtimes[i] = read_clip_mtime(root, entry.id)
	}
}

@(private)
read_clip_mtime :: proc(root, id: string) -> i64 {
	path := fmt.tprintf("%s/%s/clip.odin", root, id)
	t, err := os.modification_time_by_path(path)
	if err != nil {
		return 0
	}
	return t._nsec
}

// Polls saved clip.odin mtimes every 0.5s so external saves hot-reload into the live game seamlessly.
poll_anim_disk_hot_reload :: proc(dt: f32) {
	ed := &app.anim_ed
	if !ed.watch_ready {
		return
	}
	ed.watch_accum += dt
	if ed.watch_accum < 0.5 {
		return
	}
	ed.watch_accum = 0
	root, ok := art.resolve_anims_root()
	if !ok {
		return
	}
	for entry, i in art.ANIM_CATALOG {
		mt := read_clip_mtime(root, entry.id)
		if mt != ed.watch_mtimes[i] {
			ed.watch_mtimes[i] = mt
			_ = art.reload_anim_clip_from_disk(entry.id)
			if app.mode == .Anim_Editor && ed.clip_loaded && ed.clip.id == entry.id && !ed.clip.dirty {
				_ = anim_editor_open_clip(entry.id, false)
			}
		}
	}
}
