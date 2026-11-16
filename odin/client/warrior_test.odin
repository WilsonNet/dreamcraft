#+build !js
package main

import "core:testing"
import g "../game"

@(test)
warrior_angle_faces_grid_direction :: proc(t: ^testing.T) {
	origin := g.Grid_Pos{10, 10}
	cases := [5]struct {
		dx, dy: i32,
		angle:  f32,
	}{
		{0, 1, 0},    // +Z / south
		{1, 0, 90},   // +X / east
		{0, -1, 180}, // -Z / north
		{-1, 0, -90}, // -X / west
		{1, 1, 45},   // south-east
	}
	for c in cases {
		target := g.Grid_Pos{x = origin.x + c.dx, y = origin.y + c.dy}
		testing.expect(t, abs(angle_toward(target, origin, 0) - c.angle) < 0.01)
	}
}

@(test)
warrior_angle_keeps_fallback_when_idle :: proc(t: ^testing.T) {
	cell := g.Grid_Pos{4, 4}
	testing.expect_value(t, angle_toward(cell, cell, 123), f32(123))
}
