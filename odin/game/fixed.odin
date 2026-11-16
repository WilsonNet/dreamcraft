// Integer-only Q16.16 fixed point.
//
// The simulation never uses floating point. Rendering converts once per frame.
package game

Fp :: i32

FP_SHIFT :: 16
FP_ONE :: Fp(1 << FP_SHIFT)
FP_HALF :: Fp(1 << (FP_SHIFT - 1))
FP_MASK :: Fp(FP_ONE - 1)

// sqrt(2) in Q16.16, rounded.
FP_SQRT2 :: Fp(92682)

fp_from_int :: proc(value: i32) -> Fp {
	return Fp(value << FP_SHIFT)
}

fp_to_f32 :: proc(value: Fp) -> f32 {
	return f32(value) / f32(FP_ONE)
}

fp_from_f32 :: proc(value: f32) -> Fp {
	return Fp(value * f32(FP_ONE))
}

fp_floor :: proc(value: Fp) -> i32 {
	return value >> FP_SHIFT
}

fp_add :: proc(a, b: Fp) -> Fp {
	return a + b
}

fp_sub :: proc(a, b: Fp) -> Fp {
	return a - b
}

fp_mul :: proc(a, b: Fp) -> Fp {
	product := i64(a) * i64(b)
	return Fp(product >> FP_SHIFT)
}

fp_div :: proc(a, b: Fp) -> Fp {
	assert(b != 0, "fixed point division by zero")
	return Fp((i64(a) << FP_SHIFT) / i64(b))
}

fp_lerp :: proc(a, b, t: Fp) -> Fp {
	return a + fp_mul(b - a, t)
}

fixed_vec :: proc(x, y: Fp) -> Fixed_Vec {
	return Fixed_Vec{x = x, y = y}
}

fixed_vec_add :: proc(a, b: Fixed_Vec) -> Fixed_Vec {
	return Fixed_Vec{x = a.x + b.x, y = a.y + b.y}
}

fixed_vec_lerp :: proc(a, b: Fixed_Vec, t: Fp) -> Fixed_Vec {
	return Fixed_Vec{x = fp_lerp(a.x, b.x, t), y = fp_lerp(a.y, b.y, t)}
}

grid_to_world :: proc(p: Grid_Pos) -> Fixed_Vec {
	assert(in_bounds(p), "grid_to_world out of bounds")
	x := i32(WORLD_MIN_X + int(p.x)*CELL_SIZE + CELL_SIZE / 2)
	y := i32(WORLD_MIN_Y + int(p.y)*CELL_SIZE + CELL_SIZE / 2)
	return Fixed_Vec{x = fp_from_int(x), y = fp_from_int(y)}
}

// Rounds down, matching the Rust game's world_to_grid behavior.
world_to_grid :: proc(world: Fixed_Vec) -> Grid_Pos {
	x := fp_floor(world.x - fp_from_int(WORLD_MIN_X))
	y := fp_floor(world.y - fp_from_int(WORLD_MIN_Y))
	gx := i32(x / CELL_SIZE)
	gy := i32(y / CELL_SIZE)
	return Grid_Pos{
		x = clamp(gx, 0, GRID_W - 1),
		y = clamp(gy, 0, GRID_H - 1),
	}
}

// Distance a unit travels in one tick, in cells.
MOVE_STEP_PER_TICK :: Fp((BASE_SPEED * FP_ONE) / (CELL_SIZE * TICK_RATE))

world_center_distance :: proc(a, b: Grid_Pos) -> Fp {
	if a.x != b.x && a.y != b.y {
		return FP_SQRT2
	}
	return FP_ONE
}
