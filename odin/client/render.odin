// Full 3D world rendering into a low-resolution target.
package main

import "core:math"
import rl "vendor:raylib"
import g "../game"

GROUND_TEX_SCALE :: 4
GROUND_TEX_W :: g.GRID_W * GROUND_TEX_SCALE
GROUND_TEX_H :: g.GRID_H * GROUND_TEX_SCALE

ground_pixels: [GROUND_TEX_W * GROUND_TEX_H]rl.Color

draw_frame :: proc() {
	update_ground_texture()
	set_unit_shader_uniforms(f32(rl.GetTime()))
	rl.BeginTextureMode(app.pixel)
	rl.ClearBackground(rl.Color{5, 10, 5, 255})
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

init_ground :: proc() {
	image := rl.GenImageColor(GROUND_TEX_W, GROUND_TEX_H, rl.BLACK)
	app.ground_texture = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	rl.SetTextureFilter(app.ground_texture, .POINT)
	mesh := rl.GenMeshPlane(f32(g.GRID_W), f32(g.GRID_H), 1, 1)
	app.ground_model = rl.LoadModelFromMesh(mesh)
	rl.SetMaterialTexture(&app.ground_model.materials[0], .ALBEDO, app.ground_texture)
}

unload_ground :: proc() {
	// UnloadModel releases the material's diffuse texture, so drop the handle
	// instead of unloading it twice.
	if app.ground_model.meshCount > 0 {
		rl.UnloadModel(app.ground_model)
		app.ground_model = {}
	}
	app.ground_texture = {}
}

update_ground_texture :: proc() {
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			cell := g.Grid_Pos{x = i32(gx), y = i32(gy)}
			state := g.fog_state(&app.game.fog, cell)
			base := ground_tint(0, gx, gy)
			if state == 1 {
				base = ground_tint(1, gx, gy)
			} else if state == 2 {
				base = ground_tint(2, gx, gy)
				if gx >= g.GOAL_X && gx < g.GRID_W - 1 {
					base = rl.Color{
						u8(clamp(f32(base.r) + 54, 0, 255)),
						u8(clamp(f32(base.g) + 20, 0, 255)),
						u8(clamp(f32(base.b) - 18, 0, 255)),
						255,
					}
				}
			}
			shade := ground_fog_shade(cell, int(state))
			base.r = u8(clamp(f32(base.r) * shade, 0, 255))
			base.g = u8(clamp(f32(base.g) * shade, 0, 255))
			base.b = u8(clamp(f32(base.b) * shade, 0, 255))
			for py in 0..<GROUND_TEX_SCALE {
				for px in 0..<GROUND_TEX_SCALE {
					// Fine per-pixel drift keeps the wash organic, not tiled.
					// Fog stays clean so unexplored space reads as void.
					drift := f32(0)
					if state > 0 {
						drift = (ground_hash(gx * 4 + px + 7, gy * 4 + py + 13) - 0.5) * 7
					}
					color := base
					color.r = u8(clamp(f32(base.r) + drift, 0, 255))
					color.g = u8(clamp(f32(base.g) + drift, 0, 255))
					color.b = u8(clamp(f32(base.b) + drift * 0.7, 0, 255))
					// A single soft tiling line keeps the grid readable without boxing tiles.
					if state > 0 && gx % 4 == 0 && px == 0 {
						color = rl.Color{
							u8(clamp(f32(base.r) * 0.80, 0, 255)),
							u8(clamp(f32(base.g) * 0.80, 0, 255)),
							u8(clamp(f32(base.b) * 0.80, 0, 255)),
							255,
						}
					}
					index := (gy * GROUND_TEX_SCALE + py) * GROUND_TEX_W + gx * GROUND_TEX_SCALE + px
					ground_pixels[index] = color
				}
			}
		}
	}
	rl.UpdateTexture(app.ground_texture, raw_data(ground_pixels[:]))
}

draw_world_3d :: proc() {
	rl.DrawModel(app.ground_model, rl.Vector3{0, 0, 0}, 1, rl.WHITE)
	draw_goal_3d()
	draw_tree_shadows_3d()
	draw_trees_3d()
	draw_unit_shadows_3d()
	draw_waypoints_3d()
	draw_paths_3d()
	draw_units_3d()
}

draw_goal_3d :: proc() {
	x := f32(g.GOAL_X) - f32(g.GRID_W) * 0.5
	for gy in 0..<g.GRID_H {
		cell := g.Grid_Pos{x = g.GOAL_X, y = i32(gy)}
		if g.fog_state(&app.game.fog, cell) == 0 {
			continue
		}
		z := f32(gy) - f32(g.GRID_H) * 0.5
		a := rl.Vector3{x, 0.04, z}
		b := rl.Vector3{x, 0.04, z + 1}
		rl.DrawLine3D(a, b, rl.Color{230, 200, 60, 210})
	}
}

draw_trees_3d :: proc() {
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			state := g.fog_state(&app.game.fog, cell)
			if state == 0 {
				continue
			}
			pos := cell_center(cell)
			scale := 0.9 + f32((int(cell.x) * 7 + int(cell.y) * 13) % 4) * 0.07
			tint := ground_hash(int(cell.x) + 91, int(cell.y) + 47) - 0.5
			trunk := rl.Color{72, 48, 28, 255}
			leaf := rl.Color{26, 62, 34, 255}
			leaf_light := rl.Color{38, 82, 42, 255}
			if state == 1 {
				trunk = rl.Color{34, 24, 16, 255}
				leaf = rl.Color{12, 30, 18, 255}
				leaf_light = rl.Color{17, 40, 22, 255}
			}
			shift := i32(tint * 12)
			leaf.r = u8(clamp(f32(leaf.r) + f32(shift), 0, 255))
			leaf.g = u8(clamp(f32(leaf.g) + f32(shift), 0, 255))
			leaf_light.r = u8(clamp(f32(leaf_light.r) + f32(shift), 0, 255))
			leaf_light.g = u8(clamp(f32(leaf_light.g) + f32(shift), 0, 255))
			rl.DrawCylinder(pos + rl.Vector3{0, 0.04, 0}, 0.055, 0.085, 0.55 * scale, 6, trunk)
			rl.DrawCylinder(pos + rl.Vector3{0, 0.42 * scale, 0}, 0.0, 0.33, 0.72 * scale, 8, leaf)
			rl.DrawCylinder(pos + rl.Vector3{0, 0.78 * scale, 0}, 0.0, 0.26, 0.62 * scale, 8, leaf)
			rl.DrawCylinder(pos + rl.Vector3{0, 1.08 * scale, 0}, 0.0, 0.19, 0.52 * scale, 8, leaf_light)
		}
	}
}

draw_waypoints_3d :: proc() {
	for i in 1..<app.game.waypoints.count {
		cell := app.game.waypoints.points[i]
		if g.fog_state(&app.game.fog, cell) == 0 {
			continue
		}
		color := rl.Color{120, 100, 25, 160}
		if i < app.game.waypoints.current {
			color = rl.Color{70, 180, 70, 170}
		} else if i == app.game.waypoints.current {
			color = rl.Color{255, 220, 60, 235}
		}
		center := cell_center(cell) + rl.Vector3{0, 0.03, 0}
		rl.DrawCircle3D(center, 0.55, rl.Vector3{1, 0, 0}, 90, color)
	}
}

draw_paths_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !units.selected[i] || !g.unit_has_path(units, i) {
			continue
		}
		previous := unit_ground(i) + rl.Vector3{0, 0.06, 0}
		drawn := 0
		for p := int(units.path_index[i]); p < int(units.path_len[i]) && drawn < 24; p += 1 {
			cell := g.cell_position(int(units.path[i][p]))
			point := cell_center(cell) + rl.Vector3{0, 0.06, 0}
			rl.DrawLine3D(previous, point, rl.Color{90, 200, 120, 120})
			rl.DrawSphere(point, 0.055, rl.Color{120, 230, 140, 170})
			previous = point
			drawn += 1
		}
	}
}

draw_unit_shadows_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		draw_unit_shadow(unit_ground(i), 0.80, 105)
	}
}

draw_tree_shadows_3d :: proc() {
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			if g.fog_state(&app.game.fog, cell) == 0 {
				continue
			}
			draw_unit_shadow(cell_center(cell), 1.05, 80)
		}
	}
}

draw_units_3d :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		ground := unit_ground(i)
		color := rl.Color{70, 120, 230, 255}
		if units.team[i] == .Enemy {
			color = rl.Color{225, 70, 70, 255}
		}
		if units.selected[i] {
			rl.DrawCircle3D(ground + rl.Vector3{0, 0.04, 0}, 0.72, rl.Vector3{1, 0, 0}, 90, rl.Color{255, 225, 80, 235})
		}
		if draw_warrior_model(i, ground) {
			draw_attack_effect(i, ground)
			continue
		}
		rl.DrawCylinder(ground, 0.32, 0.38, 1.3, 8, color)
		rl.DrawSphere(ground + rl.Vector3{0, 1.55, 0}, 0.26, color)
	}
}

draw_attack_effect :: proc(index: int, ground: rl.Vector3) {
	visual := &app.visuals[index]
	if visual.attack <= 0 {
		return
	}
	elapsed := ANIM_ATTACK_SECONDS - visual.attack
	if elapsed < 0.08 || elapsed > 0.34 {
		return
	}
	radians := visual.angle * math.PI / 180
	forward := rl.Vector3{math.sin(radians), 0, math.cos(radians)}
	right := rl.Vector3{math.cos(radians), 0, -math.sin(radians)}
	center := ground + rl.Vector3{0, 1.1, 0} + forward * 0.75
	for k in 0..<3 {
		offset := f32(k-1) * 0.18
		a := center - right * 0.55 + forward * offset
		b := center + right * 0.55 + forward * offset
		rl.DrawLine3D(a, b, rl.Color{255, 245, 180, 220})
	}
}

draw_unit_health_bars :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		head := unit_ground(i) + rl.Vector3{0, 2.45, 0}
		screen := rl.GetWorldToScreen(head, app.camera)
		if screen.x < 0 || screen.x > f32(rl.GetScreenWidth()) ||
		   screen.y < 0 || screen.y > f32(rl.GetScreenHeight()) - HUD_HEIGHT {
			continue
		}
		draw_health_bar(rl.Vector2{screen.x, screen.y + 18}, units.hp[i], units.hp_max[i])
	}
}

draw_health_bar :: proc(position: rl.Vector2, hp, max_hp: u16) {
	percent := f32(hp) / f32(max_hp)
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24, 4}, rl.Color{25, 25, 25, 220})
	color := rl.Color{50, 205, 50, 255}
	if percent <= 0.25 {
		color = rl.Color{230, 50, 50, 255}
	} else if percent <= 0.5 {
		color = rl.Color{230, 180, 25, 255}
	}
	rl.DrawRectangleRec(rl.Rectangle{position.x - 12, position.y - 25, 24 * percent, 4}, color)
}
