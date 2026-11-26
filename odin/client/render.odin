// Full 3D world rendering coordinator.
package main

import rl "../gfx"
import g "../game"

draw_frame :: proc() {
	if app.mode == .Model_Picker {
		draw_picker_frame()
		return
	}
	if app.mode == .Model_Editor {
		draw_editor_frame()
		return
	}
	if app.mode == .Anim_Picker {
		draw_anim_picker_frame()
		return
	}
	if app.mode == .Anim_Editor {
		draw_anim_editor_frame()
		return
	}
	update_fog_texture()
	set_unit_shader_uniforms(f32(rl.GetTime()))
	rl.BeginTextureMode(app.pixel)
	rl.ClearBackground(rl.Color{8, 13, 13, 255})
	rl.BeginMode3D(app.camera)
	draw_world_3d()
	rl.EndMode3D()
	rl.EndTextureMode()
	render_hero_portrait()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_pixel_output()
	vui_render()
	rl.EndDrawing()
}

draw_world_3d :: proc() {
	draw_ground_3d()
	draw_waypoints_3d()
	draw_paths_3d()
	draw_command_fx_3d()
	draw_tree_shadows_3d()
	draw_unit_shadows_3d()
	draw_trees_3d()
	draw_goal_3d()
	set_unit_tint(rl.Vector3{1, 1, 1}, 1.0)
	draw_units_3d()
	draw_slashes_3d()
}

draw_paths_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !units.selected[i] {
			continue
		}
		line_col, dot_col := path_colors(units, i)
		tail := unit_ground(i) + rl.Vector3{0, 0.06, 0}
		if g.unit_has_path(units, i) {
			drawn := 0
			for p := int(units.path_index[i]); p < int(units.path_len[i]) && drawn < 24; p += 1 {
				cell := g.cell_position(int(units.path[i][p]))
				point := cell_center(cell) + rl.Vector3{0, 0.06, 0}
				rl.DrawLine3D(tail, point, line_col)
				rl.DrawSphere(point, 0.055, dot_col)
				tail = point
				drawn += 1
			}
		}
		draw_queued_orders_3d(units, i, tail)
		if units.patrol_active[i] {
			a := cell_center(units.patrol_a[i]) + rl.Vector3{0, 0.04, 0}
			b := cell_center(units.patrol_b[i]) + rl.Vector3{0, 0.04, 0}
			rl.DrawCircle3D(a, 0.28, {1, 0, 0}, 90, rl.Color{90, 215, 250, 180})
			rl.DrawCircle3D(b, 0.28, {1, 0, 0}, 90, rl.Color{255, 212, 92, 220})
		}
	}
}

@(private)
draw_queued_orders_3d :: proc(units: ^g.Units, index: int, start_pos: rl.Vector3) {
	count := int(units.order_count[index])
	if count <= 0 {
		return
	}
	prev := start_pos
	for q in 0..<count {
		ord := units.order_queue[index][q]
		target_cell := ord.kind == .Patrol ? ord.point_b : ord.position
		if ord.kind == .Attack {
			if t_idx, ok := g.unit_index(units, ord.target); ok {
				target_cell = units.position[t_idx]
			} else {
				continue
			}
		}
		pt := cell_center(target_cell) + rl.Vector3{0, 0.07, 0}
		col := rl.Color{110, 235, 145, 190}
		if ord.kind == .Attack || ord.kind == .Attack_Move {
			col = rl.Color{245, 110, 85, 195}
		} else if ord.kind == .Patrol {
			col = rl.Color{95, 215, 250, 195}
		}
		rl.DrawLine3D(prev, pt, col)
		rl.DrawSphere(pt, 0.09, col)
		prev = pt
	}
}

@(private)
path_colors :: proc(units: ^g.Units, index: int) -> (line_col, dot_col: rl.Color) {
	if units.patrol_active[index] {
		return rl.Color{90, 215, 250, 145}, rl.Color{135, 235, 255, 190}
	}
	if units.attack_move_active[index] || g.handle_is_valid(units.attack_target[index]) {
		return rl.Color{245, 95, 75, 145}, rl.Color{255, 130, 100, 190}
	}
	return rl.Color{90, 200, 120, 120}, rl.Color{120, 230, 140, 170}
}

draw_unit_shadows_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		draw_ground_shadow(unit_ground(i), 0.92, 125, rl.Vector3{-0.04, 0, -0.04})
	}
}

draw_units_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		ground := unit_ground(i)
		draw_unit_campaign_rings(i, ground)
		if units.selected[i] {
			if app.env.ready {
				rl.DrawModelEx(app.env.select_ring_model, ground, {0, 1, 0}, 0, {1, 1, 1}, rl.WHITE)
			} else {
				rl.DrawCircle3D(ground + rl.Vector3{0, 0.04, 0}, 0.48, rl.Vector3{1, 0, 0}, 90, rl.Color{255, 225, 80, 235})
			}
		}
		if draw_warrior_model(i, ground) {
			continue
		}
		color := rl.Color{70, 120, 230, 255}
		if units.team[i] == .Enemy {
			color = rl.Color{225, 70, 70, 255}
		}
		rl.DrawCylinder(ground, 0.32, 0.38, 1.3, 8, color)
		rl.DrawSphere(ground + rl.Vector3{0, 1.55, 0}, 0.26, color)
	}
}
