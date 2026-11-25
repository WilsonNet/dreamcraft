// Deterministic placement and rendering of trees, boulders, waypoints, and goal banners.
package main

import "core:math"
import rl "../gfx"
import g "../game"

cell_hash_u32 :: proc(x, y, salt: i32) -> u32 {
	n := u32(x) * 374761393 + u32(y) * 668265263 + u32(salt) * 1442695041
	n = (n ~ (n >> 13)) * 1274126177
	return n ~ (n >> 16)
}

cell_hash01 :: proc(x, y, salt: i32) -> f32 {
	return f32(cell_hash_u32(x, y, salt) & 0xffff) / 65535.0
}

@(private)
tree_cell_placement :: proc(cell: g.Grid_Pos) -> (pos: rl.Vector3, h: u32, scale, yaw: f32) {
	h = cell_hash_u32(cell.x, cell.y, 17)
	scale = 0.94 + cell_hash01(cell.x, cell.y, 23) * 0.14
	yaw = cell_hash01(cell.x, cell.y, 31) * 360.0
	jx := (cell_hash01(cell.x, cell.y, 41) - 0.5) * 0.24
	jz := (cell_hash01(cell.x, cell.y, 47) - 0.5) * 0.24
	pos = cell_center(cell) + rl.Vector3{jx, 0, jz}
	return
}

draw_tree_shadows_3d :: proc() {
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			state := g.fog_state(&app.game.fog, cell)
			if state == 0 {
				continue
			}
			pos, h, scale, _ := tree_cell_placement(cell)
			variant := int(h % 4)
			base_diam := f32(variant >= 2 ? 2.08 : 1.85) + cell_hash01(cell.x, cell.y, 53) * 0.17
			alpha := u8(state == 2 ? 115 : 55)
			draw_ground_shadow(pos, base_diam * scale, alpha, rl.Vector3{-0.12, 0, -0.12})
		}
	}
}

draw_trees_3d :: proc() {
	if !app.env.ready {
		return
	}
	for cluster in g.TREE_CLUSTERS {
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			state := g.fog_state(&app.game.fog, cell)
			if state == 0 {
				continue
			}
			draw_tree_cell(cell, int(state))
		}
	}
}

@(private)
draw_tree_cell :: proc(cell: g.Grid_Pos, state: int) {
	pos, h, scale, yaw := tree_cell_placement(cell)
	variant := int(h % 4)
	fog_vis: f32 = state == 2 ? 1.0 : 0.36
	tint := rl.Vector3{
		1.0 + (cell_hash01(cell.x, cell.y, 61) - 0.5) * 0.14,
		1.0 + (cell_hash01(cell.x, cell.y, 67) - 0.5) * 0.12,
		1.0 + (cell_hash01(cell.x, cell.y, 71) - 0.5) * 0.12,
	}
	set_unit_tint(tint, fog_vis)
	rl.DrawModelEx(app.env.tree_models[variant], pos, {0, 1, 0}, yaw, {scale, scale, scale}, rl.WHITE)
	if cell_hash01(cell.x, cell.y, 83) < 0.45 {
		ang := cell_hash01(cell.x, cell.y, 97) * math.TAU
		rock_pos := cell_center(cell) + rl.Vector3{math.cos(ang) * 0.32, 0, math.sin(ang) * 0.32}
		rock_yaw := cell_hash01(cell.x, cell.y, 101) * 360.0
		rock_scale := f32(0.88) + cell_hash01(cell.x, cell.y, 107) * 0.24
		set_unit_tint({1, 1, 1}, fog_vis)
		rl.DrawModelEx(app.env.rock_models[int(h % 2)], rock_pos, {0, 1, 0}, rock_yaw, {rock_scale, rock_scale, rock_scale}, rl.WHITE)
	}
}

draw_waypoints_3d :: proc() {
	if !app.env.ready {
		return
	}
	for i in 0..<app.game.waypoints.count {
		cell := app.game.waypoints.points[i]
		state := g.fog_state(&app.game.fog, cell)
		if state == 0 {
			continue
		}
		tint := rl.Vector3{0.74, 0.68, 0.56}
		if i < app.game.waypoints.current {
			tint = rl.Vector3{0.55, 1.15, 0.72}
		} else if i == app.game.waypoints.current {
			tint = rl.Vector3{1.24, 1.06, 0.52}
		}
		fog_vis: f32 = state == 2 ? 1.0 : 0.45
		set_unit_tint(tint, fog_vis)
		rl.DrawModelEx(app.env.waypoint_model, cell_center(cell), {0, 1, 0}, 0, {1, 1, 1}, rl.WHITE)
	}
}

draw_goal_3d :: proc() {
	if !app.env.ready {
		return
	}
	x := f32(g.GOAL_X) - f32(g.GRID_W) * 0.5 + 0.65
	ys := [6]f32{8.5, 15.5, 22.5, 28.5, 35.5, 42.5}
	for gy in ys {
		cell := g.Grid_Pos{x = g.GOAL_X, y = i32(gy)}
		state := g.fog_state(&app.game.fog, cell)
		if state == 0 {
			continue
		}
		fog_vis: f32 = state == 2 ? 1.0 : 0.45
		pos := rl.Vector3{x, 0, gy - f32(g.GRID_H) * 0.5}
		set_unit_tint({1, 1, 1}, fog_vis)
		rl.DrawModelEx(app.env.banner_model, pos, {0, 1, 0}, 45, {1, 1, 1}, rl.WHITE)
	}
}
