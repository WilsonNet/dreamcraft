// Towering Age of Empires x Akira Toriyama tree variants for the forest grid.
//
// Each variant uses mb_init_prop(3.2) so foliage boughs catch baked vertical AO
// and tower 1.8x-2.3x above the ~1.48u Mamluk warrior while leaving trunk bases
// and walkable lanes cleanly readable.
package art

import "core:math"
import rl "../../gfx"

@(private)
Tree_Puff :: struct {
	pos:   rl.Vector3,
	radii: rl.Vector3,
	kind:  Mat_Kind,
	ao:    f32,
}

@(private)
Pine_Tier :: struct {
	y_base: f32,
	y_top:  f32,
	r_out:  f32,
	r_top:  f32,
	offset: [2]f32,
	puffs:  int,
	phase:  f32,
	ao:     f32,
	sunlit: bool,
}

build_pine_tall :: proc() -> Mesh_Builder {
	if custom, ok := try_build_custom_model("pine_tall"); ok { return custom }
	b := mb_init_prop(3.2)
	trunk := [5]Loft_Ring{
		{{0.00, 0.00, 0.00}, 0.21, 0.21},
		{{0.00, 0.24, 0.00}, 0.14, 0.14},
		{{0.02, 0.90, 0.01}, 0.11, 0.11},
		{{0.03, 1.80, -0.01}, 0.085, 0.085},
		{{0.01, 2.75, 0.00}, 0.055, 0.055},
	}
	mb_loft(&b, rl.Matrix(1), trunk[:], 10, .Bark, true, true, 0.94)
	emit_root_buttresses(&b, 4, 0.25, 0.27, 0.34, 0.060, 0.042)
	tiers := [4]Pine_Tier{
		{0.76, 1.56, 0.72, 0.24, {0.00, 0.00}, 6, 0.15, 0.90, false},
		{1.30, 2.06, 0.60, 0.20, {0.02, 0.01}, 6, 0.68, 0.94, false},
		{1.84, 2.54, 0.46, 0.15, {0.03, -0.01}, 5, 0.32, 0.97, false},
		{2.34, 2.96, 0.32, 0.09, {0.01, 0.00}, 5, 0.90, 1.00, true},
	}
	for tier in tiers {
		emit_pine_tier(&b, tier)
	}
	emit_pine_crown(&b, {0.01, 0.00}, 2.76, 3.25, 0.20)
	return b
}

build_pine_mid :: proc() -> Mesh_Builder {
	if custom, ok := try_build_custom_model("pine_mid"); ok { return custom }
	b := mb_init_prop(3.2)
	trunk := [5]Loft_Ring{
		{{0.00, 0.00, 0.00}, 0.20, 0.20},
		{{0.02, 0.24, 0.01}, 0.135, 0.135},
		{{0.06, 0.90, 0.03}, 0.11, 0.11},
		{{0.10, 1.75, 0.04}, 0.08, 0.08},
		{{0.08, 2.40, 0.03}, 0.05, 0.05},
	}
	mb_loft(&b, rl.Matrix(1), trunk[:], 10, .Bark, true, true, 0.94)
	emit_root_buttresses(&b, 4, 0.60, 0.26, 0.32, 0.056, 0.040)
	tiers := [3]Pine_Tier{
		{0.72, 1.48, 0.78, 0.26, {0.05, 0.02}, 6, 0.40, 0.91, false},
		{1.28, 2.02, 0.63, 0.20, {0.08, 0.03}, 6, 0.95, 0.95, false},
		{1.84, 2.50, 0.45, 0.12, {0.09, 0.03}, 5, 0.22, 1.00, true},
	}
	for tier in tiers {
		emit_pine_tier(&b, tier)
	}
	emit_pine_crown(&b, {0.08, 0.03}, 2.38, 2.85, 0.23)
	return b
}

build_oak_broad :: proc() -> Mesh_Builder {
	if custom, ok := try_build_custom_model("oak_broad"); ok { return custom }
	b := mb_init_prop(3.2)
	trunk := [4]Loft_Ring{
		{{0.00, 0.00, 0.00}, 0.23, 0.23},
		{{0.00, 0.22, 0.00}, 0.16, 0.15},
		{{-0.03, 0.72, 0.02}, 0.14, 0.13},
		{{0.02, 1.24, -0.01}, 0.12, 0.12},
	}
	mb_loft(&b, rl.Matrix(1), trunk[:], 10, .Bark, true, true, 0.95)
	emit_root_buttresses(&b, 4, 0.40, 0.30, 0.36, 0.066, 0.045)
	limbs := [3]rl.Vector3{{0.40, 1.72, 0.26}, {-0.42, 1.68, 0.18}, {0.04, 1.74, -0.40}}
	for tip in limbs {
		mb_capsule(&b, rl.Vector3{0.01, 1.15, 0.00}, tip, 0.090, 0.055, 6, .Bark, 0.94)
	}
	puffs := [11]Tree_Puff{
		{{0.42, 1.62, 0.28}, {0.42, 0.30, 0.40}, .Leaf_Deep, 0.86},
		{{-0.44, 1.58, 0.20}, {0.42, 0.30, 0.38}, .Leaf_Deep, 0.86},
		{{0.04, 1.64, -0.42}, {0.42, 0.30, 0.40}, .Leaf_Deep, 0.86},
		{{0.36, 1.96, 0.22}, {0.46, 0.35, 0.44}, .Leaf_Mid, 0.96},
		{{-0.36, 1.92, 0.14}, {0.45, 0.34, 0.43}, .Leaf_Mid, 0.96},
		{{-0.04, 1.98, -0.34}, {0.46, 0.35, 0.44}, .Leaf_Mid, 0.96},
		{{0.24, 2.24, 0.22}, {0.36, 0.30, 0.34}, .Leaf_Sun, 1.00},
		{{-0.22, 2.20, -0.14}, {0.35, 0.29, 0.34}, .Leaf_Sun, 1.00},
		{{-0.08, 2.34, 0.16}, {0.32, 0.28, 0.30}, .Leaf_Sun, 1.00},
		{{0.22, 2.36, -0.08}, {0.30, 0.26, 0.30}, .Leaf_Sun, 1.00},
		{{0.04, 2.46, 0.04}, {0.32, 0.28, 0.30}, .Leaf_Sun, 1.00},
	}
	emit_foliage_puffs(&b, puffs[:], 12, 6)
	return b
}

build_oak_elder :: proc() -> Mesh_Builder {
	if custom, ok := try_build_custom_model("oak_elder"); ok { return custom }
	b := mb_init_prop(3.2)
	trunk := [4]Loft_Ring{
		{{0.00, 0.00, 0.00}, 0.24, 0.24},
		{{0.00, 0.25, 0.00}, 0.165, 0.165},
		{{0.03, 0.82, -0.02}, 0.145, 0.14},
		{{-0.02, 1.42, 0.01}, 0.125, 0.125},
	}
	mb_loft(&b, rl.Matrix(1), trunk[:], 10, .Bark, true, true, 0.95)
	emit_root_buttresses(&b, 4, 0.10, 0.31, 0.38, 0.068, 0.046)
	mb_capsule(&b, {-0.02, 1.24, 0.01}, {-0.52, 1.66, 0.26}, 0.088, 0.052, 6, .Bark, 0.94)
	mb_capsule(&b, {-0.02, 1.38, 0.01}, {-0.18, 2.18, -0.18}, 0.100, 0.058, 6, .Bark, 0.95)
	mb_capsule(&b, {-0.02, 1.38, 0.01}, {0.24, 2.24, 0.16}, 0.105, 0.060, 6, .Bark, 0.95)
	side := [3]Tree_Puff{
		{{-0.56, 1.58, 0.30}, {0.34, 0.24, 0.32}, .Leaf_Deep, 0.85},
		{{-0.52, 1.76, 0.24}, {0.36, 0.28, 0.34}, .Leaf_Mid, 0.95},
		{{-0.42, 1.88, 0.30}, {0.26, 0.22, 0.26}, .Leaf_Sun, 1.00},
	}
	main_canopy := [9]Tree_Puff{
		{{0.30, 2.04, 0.20}, {0.44, 0.30, 0.42}, .Leaf_Deep, 0.86},
		{{-0.22, 2.08, -0.24}, {0.44, 0.30, 0.42}, .Leaf_Deep, 0.86},
		{{0.28, 2.36, 0.22}, {0.46, 0.35, 0.44}, .Leaf_Mid, 0.96},
		{{-0.26, 2.38, -0.14}, {0.46, 0.35, 0.44}, .Leaf_Mid, 0.96},
		{{0.08, 2.34, -0.32}, {0.42, 0.33, 0.40}, .Leaf_Mid, 0.96},
		{{0.22, 2.66, 0.16}, {0.34, 0.29, 0.34}, .Leaf_Sun, 1.00},
		{{-0.16, 2.64, 0.12}, {0.32, 0.28, 0.32}, .Leaf_Sun, 1.00},
		{{0.04, 2.74, -0.14}, {0.30, 0.26, 0.30}, .Leaf_Sun, 1.00},
		{{0.02, 2.82, 0.04}, {0.30, 0.27, 0.30}, .Leaf_Sun, 1.00},
	}
	emit_foliage_puffs(&b, side[:], 10, 5)
	emit_foliage_puffs(&b, main_canopy[:], 12, 6)
	return b
}

@(private)
emit_root_buttresses :: proc(b: ^Mesh_Builder, count: int, phase, r_out, height, rad0, rad1: f32) {
	for i in 0..<count {
		ang := phase + f32(i) * math.TAU / f32(count)
		ca := math.cos(ang)
		sa := math.sin(ang)
		p0 := rl.Vector3{ca * r_out, 0.04, sa * r_out}
		p1 := rl.Vector3{ca * 0.10, height, sa * 0.10}
		mb_capsule(b, p0, p1, rad0, rad1, 6, .Bark_Dark, 0.88)
	}
}

@(private)
emit_pine_tier :: proc(b: ^Mesh_Builder, t: Pine_Tier) {
	xf := xf_at(t.offset[0], 0, t.offset[1])
	h := t.y_top - t.y_base
	under := [3]rl.Vector2{
		{0.08, t.y_base + 0.09},
		{t.r_out * 0.65, t.y_base + 0.02},
		{t.r_out * 0.96, t.y_base - 0.01},
	}
	mb_lathe(b, xf, under[:], 12, .Leaf_Deep, false, false, t.ao * 0.80)
	upper := [4]rl.Vector2{
		{t.r_out, t.y_base},
		{t.r_out * 0.74, t.y_base + h * 0.22},
		{t.r_out * 0.48, t.y_base + h * 0.56},
		{t.r_top, t.y_top},
	}
	body_kind: Mat_Kind = t.sunlit ? .Leaf_Pine_Sun : .Leaf_Pine
	mb_lathe(b, xf, upper[:], 12, body_kind, false, true, t.ao)
	emit_pine_rim_puffs(b, t)
}

@(private)
emit_pine_rim_puffs :: proc(b: ^Mesh_Builder, t: Pine_Tier) {
	for k in 0..<t.puffs {
		ang := t.phase + f32(k) * math.TAU / f32(t.puffs)
		ca := math.cos(ang)
		sa := math.sin(ang)
		pr := t.r_out * (0.20 + 0.03 * f32(k % 2))
		px := t.offset[0] + ca * t.r_out * 0.84
		py := t.y_base + 0.025 + 0.015 * f32(k % 2)
		pz := t.offset[1] + sa * t.r_out * 0.84
		kind: Mat_Kind = .Leaf_Pine
		if t.sunlit || ca + sa > 0.35 {
			kind = .Leaf_Pine_Sun
		} else if ca + sa < -0.55 {
			kind = .Leaf_Deep
		}
		mb_ellipsoid(b, xf_at(px, py, pz), {pr * 1.32, pr * 0.54, pr * 1.32}, 8, 4, kind, t.ao)
	}
}

@(private)
emit_pine_crown :: proc(b: ^Mesh_Builder, offset: [2]f32, y_base, y_top, r_base: f32) {
	xf := xf_at(offset[0], 0, offset[1])
	h := y_top - y_base
	under := [2]rl.Vector2{{0.05, y_base + 0.05}, {r_base * 0.95, y_base - 0.01}}
	mb_lathe(b, xf, under[:], 10, .Leaf_Deep, false, false, 0.88)
	spire := [4]rl.Vector2{
		{r_base, y_base},
		{r_base * 0.65, y_base + h * 0.38},
		{r_base * 0.30, y_base + h * 0.74},
		{0.0, y_top},
	}
	mb_lathe(b, xf, spire[:], 10, .Leaf_Pine_Sun, false, false, 1.00)
	mb_ellipsoid(b, xf_at(offset[0], y_base + h * 0.45, offset[1]), {r_base * 0.62, h * 0.34, r_base * 0.62}, 8, 4, .Leaf_Pine_Sun, 1.00)
}

@(private)
emit_foliage_puffs :: proc(b: ^Mesh_Builder, puffs: []Tree_Puff, segs, rings: int) {
	for puff in puffs {
		mb_ellipsoid(b, xf_at(puff.pos.x, puff.pos.y, puff.pos.z), puff.radii, segs, rings, puff.kind, puff.ao)
	}
}
