// Full 3D world rendering coordinator.
package main

import rl "vendor:raylib"
import g "../game"

draw_frame :: proc() {
	update_fog_texture()
	set_unit_shader_uniforms(f32(rl.GetTime()))
	rl.BeginTextureMode(app.pixel)
	rl.ClearBackground(rl.Color{8, 13, 13, 255})
	rl.BeginMode3D(app.camera)
	draw_world_3d()
	rl.EndMode3D()
	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_pixel_output()
	draw_unit_health_bars()
	draw_hud()
	draw_selection_box()
	if app.menu_open {
		draw_pause_menu()
	}
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
		if g.unit_has_path(units, i) {
			previous := unit_ground(i) + rl.Vector3{0, 0.06, 0}
			drawn := 0
			for p := int(units.path_index[i]); p < int(units.path_len[i]) && drawn < 24; p += 1 {
				cell := g.cell_position(int(units.path[i][p]))
				point := cell_center(cell) + rl.Vector3{0, 0.06, 0}
				rl.DrawLine3D(previous, point, line_col)
				rl.DrawSphere(point, 0.055, dot_col)
				previous = point
				drawn += 1
			}
		}
		if units.patrol_active[i] {
			a := cell_center(units.patrol_a[i]) + rl.Vector3{0, 0.04, 0}
			b := cell_center(units.patrol_b[i]) + rl.Vector3{0, 0.04, 0}
			rl.DrawCircle3D(a, 0.28, {1, 0, 0}, 90, rl.Color{90, 215, 250, 180})
			rl.DrawCircle3D(b, 0.28, {1, 0, 0}, 90, rl.Color{255, 212, 92, 220})
		}
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

draw_unit_health_bars :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		head_height := f32(1.85)
		if units.kind[i] == .Hero {
			head_height = 2.08
		}
		head := unit_ground(i) + rl.Vector3{0, head_height, 0}
		screen := rl.GetWorldToScreen(head, app.camera)
		if screen.x < 0 || screen.x > f32(rl.GetScreenWidth()) ||
		   screen.y < 0 || screen.y > f32(rl.GetScreenHeight()) - HUD_HEIGHT {
			continue
		}
		bar_pos := rl.Vector2{screen.x, screen.y + 18}
		if units.kind[i] == .Hero {
			draw_hero_health_bar(bar_pos, units.hp[i], units.hp_max[i])
		} else {
			draw_health_bar(bar_pos, units.hp[i], units.hp_max[i])
		}
		draw_unit_campaign_label(i, bar_pos)
	}
}

draw_health_bar :: proc(position: rl.Vector2, hp, max_hp: u16) {
	percent := f32(hp) / f32(max_hp)
	rl.DrawRectangleRec(rl.Rectangle{position.x - 13, position.y - 26, 26, 6}, rl.Color{12, 12, 16, 225})
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24, 4}, rl.Color{25, 25, 25, 220})
	color := rl.Color{50, 205, 50, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 50, 50, 255}
	} else if percent <= 0.5 {
		color = rl.Color{230, 180, 25, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24 * percent, 4}, color)
}
