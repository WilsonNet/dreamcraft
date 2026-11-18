// Pure procedural environment props: boulders, ferns, waypoints, goal banners, selection rings.
package art

import "core:math"
import rl "vendor:raylib"

build_boulder_moss :: proc() -> Mesh_Builder {
	b := mb_init_prop(0.45)
	mb_ellipsoid(&b, xf_trs({0.00, 0.14, 0.00}, {0.10, 0.45, -0.08}), {0.24, 0.18, 0.21}, 10, 6, .Stone, 0.96)
	mb_ellipsoid(&b, xf_trs({-0.16, 0.09, 0.12}, {-0.08, 1.10, 0.12}), {0.14, 0.11, 0.13}, 8, 5, .Stone_Dark, 0.88)
	mb_ellipsoid(&b, xf_trs({0.17, 0.08, -0.09}, {0.12, -0.40, 0.06}), {0.12, 0.09, 0.11}, 8, 5, .Stone, 0.94)
	mb_ellipsoid(&b, xf_trs({0.01, 0.295, 0.02}, {0.06, 0.30, -0.06}), {0.17, 0.085, 0.15}, 10, 5, .Moss, 1.00)
	mb_ellipsoid(&b, xf_at(-0.15, 0.185, 0.11), {0.09, 0.045, 0.08}, 8, 4, .Moss, 0.96)
	return b
}

build_shrub_fern :: proc() -> Mesh_Builder {
	b := mb_init_prop(0.45)
	mb_ellipsoid(&b, xf_at(0, 0.06, 0), {0.085, 0.065, 0.085}, 8, 4, .Leaf_Deep, 0.84)
	for i in 0..<7 {
		ang := f32(i) * math.TAU / 7.0
		xf := xf_mul(rl.MatrixRotateY(ang), xf_mul(xf_at(0, 0.05, 0.04), xf_mul(rl.MatrixRotateX(0.92), xf_at(0, 0.14, 0))))
		mb_plate(&b, xf, 0.090, 0.28, 0.018, i % 2 == 0 ? .Leaf_Mid : .Leaf_Deep, 0.92)
	}
	for i in 0..<5 {
		ang := 0.32 + f32(i) * math.TAU / 5.0
		xf := xf_mul(rl.MatrixRotateY(ang), xf_mul(xf_at(0, 0.07, 0.03), xf_mul(rl.MatrixRotateX(0.46), xf_at(0, 0.16, 0))))
		mb_plate(&b, xf, 0.080, 0.32, 0.015, i % 2 == 0 ? .Leaf_Sun : .Leaf_Mid, 1.00)
	}
	buds := [3][3]f32{{0.08, 0.39, 0.04}, {-0.07, 0.36, 0.06}, {0.01, 0.38, -0.08}}
	for pt in buds {
		mb_capsule(&b, {0, 0.09, 0}, {pt[0], pt[1] - 0.02, pt[2]}, 0.012, 0.009, 5, .Leaf_Mid, 0.95)
		mb_ellipsoid(&b, xf_at(pt[0], pt[1], pt[2]), {0.025, 0.030, 0.025}, 6, 4, .Banner_Gold, 1.00)
	}
	return b
}

build_waypoint_disc :: proc() -> Mesh_Builder {
	b := mb_init_prop(0.15)
	outer := [4]rl.Vector2{{0.48, 0.000}, {0.48, 0.018}, {0.44, 0.034}, {0.00, 0.034}}
	mb_lathe(&b, rl.Matrix(1), outer[:], 8, .Stone_Dark, true, false, 0.90)
	inner := [3]rl.Vector2{{0.39, 0.030}, {0.37, 0.042}, {0.00, 0.042}}
	mb_lathe(&b, rl.Matrix(1), inner[:], 8, .Stone, false, false, 0.98)
	mb_torus(&b, xf_at(0, 0.038, 0), 0.30, 0.010, 16, 5, .Brass, 1.00)
	for i in 0..<4 {
		ang := f32(i) * math.TAU / 4.0
		mb_rivet(&b, xf_at(math.cos(ang) * 0.41, 0.036, math.sin(ang) * 0.41), 0.012, .Brass, 1.00)
	}
	mb_star(&b, xf_at(0, 0.043, 0), 0.17, 0.06, 0.005, 4, .Glow, 1.00)
	return b
}

build_goal_banner :: proc() -> Mesh_Builder {
	b := mb_init_prop(2.8)
	plinth := [4]rl.Vector2{{0.34, 0.00}, {0.34, 0.12}, {0.30, 0.16}, {0.00, 0.16}}
	mb_lathe(&b, rl.Matrix(1), plinth[:], 8, .Stone_Dark, true, false, 0.90)
	dais := [4]rl.Vector2{{0.24, 0.14}, {0.22, 0.30}, {0.16, 0.35}, {0.00, 0.35}}
	mb_lathe(&b, rl.Matrix(1), dais[:], 8, .Stone, false, false, 0.96)
	mb_cylinder(&b, xf_at(0, 0.34, 0), 0.11, 0.08, 0.08, 8, .Brass_Dark, true, 0.95)
	mb_cylinder(&b, xf_at(0, 0.36, 0), 0.042, 0.032, 2.00, 10, .Iron, true, 0.96)
	for y in ([3]f32{0.90, 1.56, 2.18}) {
		mb_torus(&b, xf_at(0, y, 0), 0.048, 0.013, 10, 4, .Brass, 1.00)
	}
	cross_xf := xf_mul(xf_at(-0.42, 2.18, 0), rl.MatrixRotateZ(-math.PI * 0.5))
	mb_cylinder(&b, cross_xf, 0.024, 0.024, 0.84, 8, .Brass, true, 1.00)
	for side in ([2]f32{-1, 1}) {
		mb_ellipsoid(&b, xf_at(side * 0.44, 2.18, 0), {0.040, 0.036, 0.036}, 8, 4, .Banner_Gold, 1.00)
	}
	emit_banner_cloth(&b)
	mb_torus(&b, xf_at(0, 2.38, 0), 0.065, 0.016, 10, 4, .Brass, 1.00)
	mb_ellipsoid(&b, xf_at(0, 2.49, 0), {0.095, 0.105, 0.095}, 10, 5, .Glow, 1.00)
	mb_cone(&b, xf_at(0, 2.58, 0), 0.032, 0.07, 8, .Banner_Gold, 1.00)
	return b
}

@(private)
emit_banner_cloth :: proc(b: ^Mesh_Builder) {
	mb_cloth_sheet(b, 2.16, 1.12, 0.03, 0.11, 0.34, 0.27, 0.06, 0.010, 6, 4, .Banner_Cloth, 0.98)
	mb_box(b, xf_at(0, 2.13, 0.035), {0.70, 0.05, 0.032}, .Banner_Gold, 1.00)
	emblem_xf := xf_mul(xf_at(0, 1.68, 0.145), rl.MatrixRotateX(math.PI * 0.5))
	mb_star(b, emblem_xf, 0.13, 0.055, 0.012, 4, .Banner_Gold, 1.00)
	mb_tri(b, {{-0.27, 1.12, 0.12}, {-0.14, 0.90, 0.14}, {0.00, 1.12, 0.18}}, .Banner_Gold, 0.98)
	mb_tri(b, {{0.00, 1.12, 0.18}, {0.14, 0.90, 0.14}, {0.27, 1.12, 0.12}}, .Banner_Gold, 0.98)
	mb_tri(b, {{0.00, 1.12, 0.16}, {-0.14, 0.90, 0.12}, {-0.27, 1.12, 0.10}}, .Banner_Gold, 0.92)
	mb_tri(b, {{0.27, 1.12, 0.10}, {0.14, 0.90, 0.12}, {0.00, 1.12, 0.16}}, .Banner_Gold, 0.92)
}

build_selection_ring :: proc() -> Mesh_Builder {
	b := mb_init_prop(0.10)
	emit_flat_annulus(&b, 0.45, 0.51, 0.032, 32, .Banner_Gold, 0.35)
	emit_flat_annulus(&b, 0.385, 0.415, 0.032, 32, .Banner_Gold, 0.35)
	return b
}

@(private)
emit_flat_annulus :: proc(b: ^Mesh_Builder, r_in, r_out, y: f32, segs: int, kind: Mat_Kind, glow: f32) {
	start := len(b.pos)
	up := [4]rl.Vector3{{0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}
	for s in 0..<segs {
		a0 := f32(s) * math.TAU / f32(segs)
		a1 := f32(s + 1) * math.TAU / f32(segs)
		p := [4]rl.Vector3{
			{math.cos(a0) * r_in, y, math.sin(a0) * r_in},
			{math.cos(a1) * r_in, y, math.sin(a1) * r_in},
			{math.cos(a1) * r_out, y, math.sin(a1) * r_out},
			{math.cos(a0) * r_out, y, math.sin(a0) * r_out},
		}
		mb_quad_n(b, p, up, kind, 1.0)
	}
	for i in start..<len(b.pos) {
		b.uv[i].y = glow
		b.col[i].a = 255
	}
}
