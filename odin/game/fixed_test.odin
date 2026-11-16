#+build !js
package game

import "core:testing"

@(test)
fixed_conversions_round_trip :: proc(t: ^testing.T) {
	testing.expect_value(t, fp_from_int(0), Fp(0))
	testing.expect_value(t, fp_from_int(1), FP_ONE)
	testing.expect_value(t, fp_from_int(-3), Fp(-3 * FP_ONE))
	testing.expect_value(t, fp_floor(fp_from_int(42)), i32(42))
	testing.expect_value(t, fp_floor(FP_ONE + FP_HALF), i32(1))
}

@(test)
fixed_mul_div :: proc(t: ^testing.T) {
	half := FP_ONE / 2
	testing.expect_value(t, fp_mul(half, half), FP_ONE / 4)
	testing.expect_value(t, fp_div(FP_ONE, half), FP_ONE * 2)
	testing.expect_value(t, fp_mul(fp_from_int(3), fp_from_int(4)), fp_from_int(12))
}

@(test)
fixed_lerp_endpoints :: proc(t: ^testing.T) {
	a := fp_from_int(-10)
	b := fp_from_int(30)
	testing.expect_value(t, fp_lerp(a, b, 0), a)
	testing.expect_value(t, fp_lerp(a, b, FP_ONE), b)
	testing.expect_value(t, fp_lerp(a, b, FP_ONE / 2), fp_from_int(10))
}

@(test)
grid_world_center_round_trip :: proc(t: ^testing.T) {
	for p in ([4]Grid_Pos{{0, 0}, {2, 25}, {79, 49}, {40, 23}}) {
		world := grid_to_world(p)
		testing.expect_value(t, world_to_grid(world), p)
	}
}

@(test)
move_step_is_exact :: proc(t: ^testing.T) {
	// 150 world units/sec, 32 units per cell, 60 ticks/sec.
	testing.expect_value(t, MOVE_STEP_PER_TICK, Fp(5120))
	testing.expect_value(t, MOVE_STEP_PER_TICK * 60, Fp(307200))
}
