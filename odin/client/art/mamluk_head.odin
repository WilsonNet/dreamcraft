// Heroic 5.36-head Akira Toriyama x AoE Mamluk head, spangenhelm-turban & cape.
//
// Everything sits 1:1 with BONES in Y = 0.00..1.945 model space: no HEAD_SCALE
// shrink, no floating head, no mushroom wrap over the eyes, and a 3-segment
// backward-bowing cape with overlapping joints.
package art

import "core:math"
import rl "../../gfx"

mamluk_head :: proc(b: ^Mesh_Builder) {
	neck_collar(b)
	mb_bone(b, .Head)
	head_skull(b)
	face(b)
	helmet(b)
	helmet_guards(b)
	turban(b)
	plume(b)
}

@(private)
xf_rot_xyz :: proc(pos: rl.Vector3, rx, ry, rz: f32) -> rl.Matrix {
	rot := xf_mul(rl.MatrixRotateY(ry), xf_mul(rl.MatrixRotateZ(rz), rl.MatrixRotateX(rx)))
	return xf_mul(xf_at(pos.x, pos.y, pos.z), rot)
}

@(private)
neck_collar :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Neck)
	// Skin throat overlaps cleanly inside both the gorget (1.452) and jaw (1.510).
	throat := [3]Loft_Ring{
		{{0, 1.410, -0.006}, 0.062, 0.060},
		{{0, 1.485, -0.006}, 0.060, 0.058},
		{{0, 1.565, -0.006}, 0.058, 0.056},
	}
	mb_loft(b, rl.Matrix(1), throat[:], 12, .Skin, true, true)

	mail := [3]Loft_Ring{
		{{0, 1.430, -0.004}, 0.070, 0.068},
		{{0, 1.472, -0.004}, 0.067, 0.065},
		{{0, 1.512, -0.004}, 0.064, 0.062},
	}
	mb_loft(b, rl.Matrix(1), mail[:], 12, .Mail)
	mb_torus(b, xf_at(0, 1.510, -0.004), 0.064, 0.0065, 10, 3, .Mail)
}

@(private)
head_skull :: proc(b: ^Mesh_Builder) {
	rings := [8]Loft_Ring{
		{{0, 1.525, 0.022}, 0.032, 0.034},
		{{0, 1.552, 0.012}, 0.066, 0.074},
		{{0, 1.588, 0.005}, 0.089, 0.094},
		{{0, 1.628, 0.002}, 0.097, 0.100},
		{{0, 1.668, 0.000}, 0.099, 0.101},
		{{0, 1.702, -0.002}, 0.096, 0.100},
		{{0, 1.750, -0.006}, 0.088, 0.092},
		{{0, 1.788, -0.008}, 0.052, 0.056},
	}
	mb_loft(b, rl.Matrix(1), rings[:], 16, .Skin, true, true)
}

@(private)
face :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		face_eye(b, side)
	}
	mb_ellipsoid(b, xf_rot_xyz({0, 1.620, 0.105}, -0.18, 0, 0), {0.011, 0.016, 0.014}, 6, 3, .Skin)
	mb_box(b, xf_at(0, 1.582, 0.096), {0.025, 0.004, 0.006}, .Leather_Dark)
	mb_ellipsoid(b, xf_at(0, 1.548, 0.068), {0.020, 0.018, 0.018}, 6, 3, .Hair)
}

@(private)
face_eye :: proc(b: ^Mesh_Builder, side: f32) {
	x := 0.036 * side
	mb_ellipsoid(b, xf_rot_xyz({x, 1.656, 0.092}, 0, side * 0.20, 0), {0.021, 0.015, 0.011}, 8, 4, .Eye)
	mb_ellipsoid(b, xf_rot_xyz({x, 1.656, 0.100}, 0, side * 0.18, 0), {0.010, 0.011, 0.005}, 6, 3, .Iris)
	mb_ellipsoid(b, xf_rot_xyz({x, 1.656, 0.104}, 0, side * 0.16, 0), {0.0055, 0.0065, 0.003}, 6, 2, .Jet)
	mb_box(b, xf_at(x - 0.004, 1.661, 0.1065), {0.0042, 0.0042, 0.003}, .Eye)
	mb_box(b, xf_rot_xyz({x, 1.672, 0.097}, 0.06, side * 0.20, side * 0.08), {0.044, 0.0048, 0.010}, .Jet)
	mb_box(b, xf_rot_xyz({0.037 * side, 1.686, 0.097}, 0.06, side * 0.18, side * 0.20), {0.046, 0.0072, 0.013}, .Hair)
}

@(private)
helmet :: proc(b: ^Mesh_Builder) {
	dome := [6]rl.Vector2{
		{0.114, 1.712}, {0.114, 1.746}, {0.104, 1.788},
		{0.084, 1.824}, {0.050, 1.848}, {0.000, 1.858},
	}
	mb_lathe(b, rl.Matrix(1), dome[:], 16, .Steel)
	mb_torus(b, xf_at(0, 1.714, 0), 0.115, 0.007, 16, 3, .Brass)

	rib := [6]rl.Vector3{
		{0, 1.716, 0.116}, {0, 1.750, 0.115}, {0, 1.790, 0.106},
		{0, 1.825, 0.086}, {0, 1.849, 0.052}, {0, 1.856, 0.012},
	}
	for k in 0..<4 {
		mb_tube(b, rl.MatrixRotateY(f32(k) * math.PI * 0.5), rib[:], 0.0055, 4, .Brass)
	}
	nasal := [2]Loft_Ring{{{0, 1.648, 0.116}, 0.005, 0.005}, {{0, 1.716, 0.116}, 0.010, 0.006}}
	mb_loft(b, rl.Matrix(1), nasal[:], 6, .Brass, true, true)

	oc := xf_mul(xf_at(0.068, 1.726, 0.106), xf_mul(rl.MatrixRotateY(0.57), rl.MatrixRotateX(math.PI * 0.5)))
	mb_torus(b, oc, 0.018, 0.0055, 10, 3, .Brass)
	mb_cylinder(b, oc, 0.012, 0.012, 0.005, 8, .Glow)

	finial := [5]rl.Vector2{{0.028, 1.855}, {0.016, 1.868}, {0.021, 1.882}, {0.012, 1.896}, {0.002, 1.925}}
	mb_lathe(b, rl.Matrix(1), finial[:], 10, .Brass, false, true)
}

@(private)
helmet_guards :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		cheek_guard(b, side)
	}
	rear_aventail(b)
}

@(private)
cheek_guard :: proc(b: ^Mesh_Builder, side: f32) {
	ys := [4]f32{1.712, 1.674, 1.634, 1.594}
	xr := [4]f32{0.099, 0.097, 0.091, 0.080}
	zf := [4]f32{0.048, 0.044, 0.035, 0.022}
	zb := [4]f32{-0.032, -0.028, -0.020, -0.008}
	out: [4][4]rl.Vector3
	inn: [4][4]rl.Vector3
	for r in 0..<4 {
		for c in 0..<4 {
			u := f32(c) / 3.0
			z := math.lerp(zb[r], zf[r], u)
			bow := 0.010 * math.sin(u * math.PI)
			x := side * (xr[r] + bow)
			out[r][c] = rl.Vector3{x + side * 0.003, ys[r], z}
			inn[r][c] = rl.Vector3{x - side * 0.003, ys[r], z}
		}
	}
	for r in 0..<3 {
		for c in 0..<3 {
			if side > 0 {
				mb_quad(b, {out[r][c], out[r][c + 1], out[r + 1][c + 1], out[r + 1][c]}, .Steel_Dark)
				mb_quad(b, {inn[r][c + 1], inn[r][c], inn[r + 1][c], inn[r + 1][c + 1]}, .Steel_Dark, 0.90)
			} else {
				mb_quad(b, {out[r][c + 1], out[r][c], out[r + 1][c], out[r + 1][c + 1]}, .Steel_Dark)
				mb_quad(b, {inn[r][c], inn[r][c + 1], inn[r + 1][c + 1], inn[r + 1][c]}, .Steel_Dark, 0.90)
			}
		}
	}
	mb_rivet(b, xf_at(side * 0.104, 1.696, 0.016), 0.007, .Brass_Dark)
}

@(private)
rear_aventail :: proc(b: ^Mesh_Builder) {
	ys := [3]f32{1.712, 1.632, 1.552}
	rs := [3]f32{0.111, 0.114, 0.098}
	out: [3][9]rl.Vector3
	inn: [3][9]rl.Vector3
	for r in 0..<3 {
		for c in 0..<9 {
			a := math.PI - 0.22 + f32(c) * (math.PI + 0.44) / 8.0
			ca, sa := math.cos(a), math.sin(a)
			out[r][c] = rl.Vector3{ca * (rs[r] + 0.003), ys[r], sa * (rs[r] + 0.003)}
			inn[r][c] = rl.Vector3{ca * (rs[r] - 0.003), ys[r], sa * (rs[r] - 0.003)}
		}
	}
	for r in 0..<2 {
		for c in 0..<8 {
			mb_quad(b, {out[r][c], out[r][c + 1], out[r + 1][c + 1], out[r + 1][c]}, .Mail, 0.94)
			mb_quad(b, {inn[r][c + 1], inn[r][c], inn[r + 1][c], inn[r + 1][c + 1]}, .Mail, 0.88)
		}
	}
}

@(private)
turban :: proc(b: ^Mesh_Builder) {
	tilt := xf_mul(xf_at(0, 1.755, 0), xf_mul(rl.MatrixRotateX(-0.09), xf_at(0, -1.755, 0)))
	wrap := [5]Loft_Ring{
		{{0, 1.722, 0}, 0.108, 0.108},
		{{0, 1.734, 0}, 0.136, 0.138},
		{{0, 1.756, 0}, 0.144, 0.144},
		{{0, 1.778, 0}, 0.132, 0.132},
		{{0, 1.792, 0}, 0.094, 0.094},
	}
	mb_loft(b, tilt, wrap[:], 14, .Cream)
	mb_torus(b, xf_mul(tilt, xf_at(0, 1.732, 0)), 0.134, 0.009, 14, 3, .Cloth)
	mb_torus(b, xf_mul(tilt, xf_mul(xf_at(0, 1.753, 0), rl.MatrixRotateZ(0.08))), 0.141, 0.008, 14, 3, .Cream_Dark)
	mb_torus(b, xf_mul(tilt, xf_mul(xf_at(0, 1.775, 0), rl.MatrixRotateZ(-0.07))), 0.132, 0.0075, 14, 3, .Cream_Dark)
	mb_ellipsoid(b, xf_at(0, 1.745, -0.138), {0.034, 0.036, 0.028}, 8, 4, .Cream)
	mb_rivet(b, xf_at(0, 1.745, -0.165), 0.010, .Brass)
}

@(private)
plume :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Plume)
	mb_cloth_sheet(b, 1.725, 1.500, -0.148, -0.183, 0.032, 0.046, -0.015, 0.004, 5, 4, .Cream, 0.98)
	mb_cloth_sheet(b, 1.503, 1.480, -0.182, -0.185, 0.045, 0.048, -0.015, 0.0045, 5, 1, .Cloth, 0.98)
}

// Gapless 3-segment cape bowing backward (-Z) so the cuirass back stays clear.
mamluk_cape :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Cape_1)
	mb_cloth_sheet(b, 1.425, 1.105, -0.138, -0.170, 0.174, 0.210, -0.032, 0.005, 7, 4, .Cloth_Dark, 0.94)
	mb_bone(b, .Cape_2)
	mb_cloth_sheet(b, 1.130, 0.815, -0.164, -0.194, 0.208, 0.242, -0.032, 0.005, 7, 4, .Cloth_Dark, 0.93)
	mb_bone(b, .Cape_3)
	mb_cloth_sheet(b, 0.840, 0.535, -0.188, -0.216, 0.238, 0.268, -0.032, 0.005, 7, 4, .Cloth_Dark, 0.92)
	mb_cloth_sheet(b, 0.542, 0.520, -0.215, -0.218, 0.267, 0.270, -0.032, 0.006, 7, 1, .Brass_Dark, 0.96)
}
