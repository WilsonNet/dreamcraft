#+build !js
package main

import "core:math"
import "core:testing"
import rl "vendor:raylib"
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
