#+build !js
package main

import "core:math"
import "core:testing"
import rl "../gfx"
import g "../game"

@(test)
cell_hashes_are_deterministic_and_bounded :: proc(t: ^testing.T) {
	a := cell_hash_u32(38, 21, 17)
	b := cell_hash_u32(38, 21, 17)
	testing.expect_value(t, a, b)
	for y in i32(0)..<50 {
		for x in i32(0)..<80 {
			v := cell_hash01(x, y, 23)
			testing.expect(t, v >= 0 && v <= 1)
		}
	}
}

@(test)
angle_toward_matches_model_plus_z_forward :: proc(t: ^testing.T) {
	origin := g.Grid_Pos{10, 10}
	testing.expect_value(t, angle_toward(g.Grid_Pos{10, 11}, origin, 99), f32(0))
	testing.expect_value(t, angle_toward(g.Grid_Pos{11, 10}, origin, 99), f32(90))
	testing.expect_value(t, angle_toward(g.Grid_Pos{10, 9}, origin, 99), f32(180))
	testing.expect_value(t, angle_toward(g.Grid_Pos{9, 10}, origin, 99), f32(-90))
	testing.expect_value(t, angle_toward(origin, origin, 42), f32(42))
}

@(test)
turn_toward_takes_shortest_arc :: proc(t: ^testing.T) {
	a := turn_toward(170, -170, 5)
	testing.expect(t, abs(a - 175) < 0.001 || abs(a + 185) < 0.001)
	b := turn_toward(-170, 170, 15)
	testing.expect(t, abs(b - 175) < 0.001 || abs(b + 185) < 0.001)
	testing.expect_value(t, turn_toward(10, 14, 10), f32(14))
}

@(test)
camera_pan_axes_match_isometric_screen_directions :: proc(t: ^testing.T) {
	forward, right := camera_pan_axes()
	back := rl.Vector3Normalize(camera_offset())
	cam_right := rl.Vector3Normalize(rl.Vector3CrossProduct(rl.Vector3{0, 1, 0}, back))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(back, cam_right))
	testing.expect(t, abs(rl.Vector3Length(forward) - 1.0) < 0.001)
	testing.expect(t, abs(rl.Vector3Length(right) - 1.0) < 0.001)
	testing.expect(t, abs(rl.Vector3DotProduct(forward, right)) < 0.001)
	testing.expect(t, rl.Vector3DotProduct(right, cam_right) > 0.99)
	testing.expect(t, rl.Vector3DotProduct(forward, cam_up) > 0.49)
	// Orthographic projection keeps cam_up aligned with -X/-Z and cam_right along +X/-Z.
	testing.expect(t, right.x > 0 && right.z < 0)
	testing.expect(t, math.abs(right.x + right.z) < 0.001)
}

@(test)
command_fx_ring_buffer_updates_and_expires :: proc(t: ^testing.T) {
	app.cmd_fx = {}
	app.cmd_fx_next = 0
	for _ in 0..<(MAX_CMD_FX + 2) {
		spawn_ground_fx(.Move, rl.Vector3{1, 0, 2})
	}
	testing.expect_value(t, app.cmd_fx_next, 2)
	spawn_target_fx(g.Unit_Handle{index = 1, generation = 1}, rl.Vector3{4, 0, 5})
	update_command_fx(0.30)
	active_count := 0
	for &fx in app.cmd_fx {
		if fx.active {
			active_count += 1
		}
	}
	testing.expect_value(t, active_count, MAX_CMD_FX)
	update_command_fx(1.00)
	for &fx in app.cmd_fx {
		testing.expect(t, !fx.active)
	}
}

@(test)
screen_dir_to_world_equalizes_isometric_horizontal_and_vertical_speeds :: proc(t: ^testing.T) {
	back := rl.Vector3Normalize(camera_offset())
	cam_right := rl.Vector3Normalize(rl.Vector3CrossProduct(rl.Vector3{0, 1, 0}, back))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(back, cam_right))

	fovy := f32(11.0)
	vx := screen_dir_to_world(rl.Vector2{1, 0}, fovy, 1.0)
	vy := screen_dir_to_world(rl.Vector2{0, 1}, fovy, 1.0)
	vd := screen_dir_to_world(rl.Vector2Normalize(rl.Vector2{1, 1}), fovy, 1.0)

	sx_x := rl.Vector3DotProduct(vx, cam_right)
	sy_y := rl.Vector3DotProduct(vy, cam_up)
	testing.expect(t, abs(sx_x - fovy) < 0.01)
	testing.expect(t, abs(sy_y - fovy) < 0.01)
	testing.expect(t, abs(rl.Vector3DotProduct(vx, cam_up)) < 0.001)
	testing.expect(t, abs(rl.Vector3DotProduct(vy, cam_right)) < 0.001)

	// Diagonal screen direction must project equally onto cam_right and cam_up (45 deg).
	sd_x := rl.Vector3DotProduct(vd, cam_right)
	sd_y := rl.Vector3DotProduct(vd, cam_up)
	testing.expect(t, abs(sd_x - sd_y) < 0.01)
}

@(test)
camera_grip_delta_locks_ground_point_one_to_one :: proc(t: ^testing.T) {
	back := rl.Vector3Normalize(camera_offset())
	cam_right := rl.Vector3Normalize(rl.Vector3CrossProduct(rl.Vector3{0, 1, 0}, back))
	cam_up := rl.Vector3Normalize(rl.Vector3CrossProduct(back, cam_right))

	fovy := f32(11.0)
	screen_h := f32(720.0)
	px_delta := rl.Vector2{72, -36}
	cam_shift := screen_delta_to_world_grip(px_delta, fovy, screen_h)

	// Pulling the map by cam_shift moves world features on screen by +px_delta.
	screen_shift_x := -rl.Vector3DotProduct(cam_shift, cam_right) * (screen_h / fovy)
	screen_shift_y := rl.Vector3DotProduct(cam_shift, cam_up) * (screen_h / fovy)
	testing.expect(t, abs(screen_shift_x - px_delta.x) < 0.05)
	testing.expect(t, abs(screen_shift_y - px_delta.y) < 0.05)
}

@(test)
edge_pan_arms_inside_and_scrolls_on_exact_border_pixels :: proc(t: ^testing.T) {
	minimap := rl.Rectangle{20, 570, 200, 125}
	base := Edge_Input{
		width     = 1280,
		height    = 720,
		minimap   = minimap,
		focused   = true,
		on_screen = true,
		armed     = false,
		busy      = false,
	}

	edge_start := base
	edge_start.mouse = rl.Vector2{0, 360}
	d0, armed0 := compute_edge_direction(edge_start)
	testing.expect(t, !armed0 && d0.x == 0 && d0.y == 0)

	inner := base
	inner.mouse = rl.Vector2{640, 360}
	d1, armed1 := compute_edge_direction(inner)
	testing.expect(t, armed1 && d1.x == 0 && d1.y == 0)

	top_left := base
	top_left.armed = true
	top_left.mouse = rl.Vector2{0, 0}
	d2, armed2 := compute_edge_direction(top_left)
	testing.expect(t, armed2 && abs(d2.x + 0.7071) < 0.01 && abs(d2.y - 0.7071) < 0.01)

	bot_right := base
	bot_right.armed = true
	bot_right.mouse = rl.Vector2{1280, 720}
	d3, armed3 := compute_edge_direction(bot_right)
	testing.expect(t, armed3 && abs(d3.x - 0.7071) < 0.01 && abs(d3.y + 0.7071) < 0.01)
}

@(test)
edge_pan_disarms_on_unfocus_and_pauses_when_busy :: proc(t: ^testing.T) {
	top_left := Edge_Input{
		mouse     = rl.Vector2{0, 0},
		width     = 1280,
		height    = 720,
		minimap   = rl.Rectangle{20, 570, 200, 125},
		focused   = true,
		on_screen = true,
		armed     = true,
		busy      = false,
	}

	unfocused := top_left
	unfocused.focused = false
	d0, armed0 := compute_edge_direction(unfocused)
	testing.expect(t, !armed0 && d0.x == 0 && d0.y == 0)

	on_minimap := top_left
	on_minimap.mouse = rl.Vector2{25, 650}
	d1, armed1 := compute_edge_direction(on_minimap)
	testing.expect(t, armed1 && d1.x == 0 && d1.y == 0)

	busy := top_left
	busy.busy = true
	d2, armed2 := compute_edge_direction(busy)
	testing.expect(t, armed2 && d2.x == 0 && d2.y == 0)
}

@(test)
cursor_inside_recovers_from_false_macos_on_screen_on_mouse_move :: proc(t: ^testing.T) {
	app = {}
	app.prev_raw_mouse = rl.Vector2{640, 360}
	// Stationary cursor when raw IsCursorOnScreen() starts false waits for an event inside.
	testing.expect(t, !update_cursor_inside(rl.Vector2{640, 360}, 1280, 720, true, false))
	// Any cursor movement inside [0..w] x [0..h] marks cursor_inside true.
	testing.expect(t, update_cursor_inside(rl.Vector2{642, 360}, 1280, 720, true, false))
	// Remains true when parked at exact border pixel (0, 360).
	testing.expect(t, update_cursor_inside(rl.Vector2{0, 360}, 1280, 720, true, false))
	// Leaving bounds clears cursor_inside immediately.
	testing.expect(t, !update_cursor_inside(rl.Vector2{-1, 360}, 1280, 720, true, false))
}

@(test)
shortcut_help_is_conditional_per_view :: proc(t: ^testing.T) {
	app = {}
	app.mode = .Game
	testing.expect_value(t, active_help_view(), Help_View.Battlefield)
	s0 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, len(s0.groups), 2)

	app.menu_open = true
	testing.expect_value(t, active_help_view(), Help_View.Pause_Menu)
	s1 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, len(s1.groups), 1)
	app.menu_open = false

	app.mode = .Model_Picker
	testing.expect_value(t, active_help_view(), Help_View.Model_Picker)
	s2 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, len(s2.groups), 1)

	app.mode = .Model_Editor
	app.editor.modal_active = false
	testing.expect_value(t, active_help_view(), Help_View.Editor_Mesh)
	s3 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, len(s3.groups), 4)

	app.editor.modal_active = true
	app.editor.modal_op = .Loop_Cut
	testing.expect_value(t, active_help_view(), Help_View.Editor_Modal)
	s4 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, s4.icon, Icon_Id.Tool_Loop_Cut)

	app.mode = .Anim_Picker
	testing.expect_value(t, active_help_view(), Help_View.Anim_Picker)
	s5 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, s5.icon, Icon_Id.Pose)

	app.mode = .Anim_Editor
	app.anim_ed.modal_active = false
	testing.expect_value(t, active_help_view(), Help_View.Anim_Editor)
	s6 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, len(s6.groups), 1)

	app.anim_ed.modal_active = true
	testing.expect_value(t, active_help_view(), Help_View.Anim_Modal)
	s7 := help_sheet_for_view(active_help_view())
	testing.expect_value(t, s7.icon, Icon_Id.Tool_Rotate)
}
