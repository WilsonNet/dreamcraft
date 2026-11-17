// Turban helm, readable human face, arcane visor and the swinging cape.
//
// The face is open: brow band above the eyes, cheek guards at the temples and
// a mail collar under the jaw. At sprite scale the eyes get extra contrast so
// the character still reads as a person from the isometric camera.
package main

import "core:math"
import rl "vendor:raylib"

HEAD_PIVOT :: f32(1.500)
HEAD_SCALE :: f32(0.80)

mamluk_head :: proc(b: ^Mesh_Builder) {
	head_scale := xf_mul(
		xf_at(0, HEAD_PIVOT, 0),
		xf_mul(rl.MatrixScale(HEAD_SCALE, HEAD_SCALE, HEAD_SCALE), xf_at(0, -HEAD_PIVOT, 0)),
	)
	mb_base(b, head_scale)
	defer mb_base(b, rl.Matrix(1))

	mb_bone(b, .Neck)
	mb_cylinder(b, xf_at(0, 1.406, 0), 0.056, 0.050, 0.080, 10, .Mail)
	mb_torus(b, xf_at(0, 1.486, 0), 0.054, 0.008, 10, 4, .Mail)

	mb_bone(b, .Head)
	mb_ellipsoid(b, xf_at(0, 1.652, 0.004), {0.094, 0.120, 0.100}, 14, 8, .Skin)
	face(b)
	helmet(b)
	turban(b)
	plume(b)
}

@(private)
face :: proc(b: ^Mesh_Builder) {
	// Clean Toriyama face: almond eyes, small nose, thin mouth, neat goatee.
	mb_ellipsoid(b, xf_at(0, 1.594, 0.072), {0.030, 0.024, 0.026}, 8, 4, .Hair)
	for side in ([2]f32{-1, 1}) {
		mb_ellipsoid(b, xf_at(0.034 * side, 1.676, 0.099), {0.026, 0.019, 0.012}, 10, 5, .Eye)
		mb_ellipsoid(b, xf_at(0.031 * side, 1.675, 0.109), {0.011, 0.012, 0.006}, 8, 4, .Jet)
		mb_box(b, xf_trs({0.034 * side, 1.690, 0.102}, {0.10, side * 0.18, side * 0.18}), {0.048, 0.005, 0.011}, .Jet)
		mb_box(b, xf_trs({0.036 * side, 1.702, 0.098}, {0.10, side * 0.18, side * 0.18}), {0.050, 0.008, 0.016}, .Hair)
	}
	mb_ellipsoid(b, xf_at(0, 1.652, 0.102), {0.015, 0.024, 0.022}, 8, 5, .Skin)
	mb_box(b, xf_at(0, 1.636, 0.108), {0.020, 0.005, 0.008}, .Leather_Dark)
	mb_box(b, xf_at(0, 1.620, 0.102), {0.034, 0.005, 0.006}, .Jet)
}

@(private)
helmet :: proc(b: ^Mesh_Builder) {
	dome := [6]rl.Vector2{{0.150, 1.722}, {0.148, 1.756}, {0.132, 1.794}, {0.104, 1.824}, {0.062, 1.846}, {0.0, 1.858}}
	mb_lathe(b, xf_at(0, 0, 0), dome[:], 14, .Steel)
	mb_torus(b, xf_at(0, 1.712, 0), 0.159, 0.007, 14, 4, .Brass_Dark)

	// Cheek guards at the temples leave the whole face open.
	for side in ([2]f32{-1, 1}) {
		mb_plate(b, xf_trs({0.100 * side, 1.628, 0.020}, {0.08, side * 1.22, 0}), 0.036, 0.108, 0.010, .Steel_Dark)
		
	}
	for i in 0..<3 {
		mb_box(b, xf_at(-0.112, 1.644 - f32(i) * 0.013, 0.068), {0.024, 0.005, 0.011}, .Jet)
	}

	// Nasal bar between the eyes, oculus lens on the brow band.
	mb_box(b, xf_at(0, 1.688, 0.136), {0.020, 0.056, 0.020}, .Brass)
	ring := xf_mul(xf_at(0.080, 1.716, 0.124), rl.MatrixRotateX(math.PI * 0.5))
	mb_torus(b, ring, 0.024, 0.008, 10, 4, .Brass_Dark)
	mb_cylinder(b, ring, 0.014, 0.014, 0.006, 10, .Glow)

	// Finial spike with a glowing tip.
	mb_cone(b, xf_at(0, 1.862, 0), 0.022, 0.046, 8, .Brass)
	mb_ellipsoid(b, xf_at(0, 1.920, 0), {0.010, 0.014, 0.010}, 8, 4, .Brass)
}

@(private)
turban :: proc(b: ^Mesh_Builder) {
	dome := [9]rl.Vector2{
		{0.160, 1.714}, {0.166, 1.740}, {0.160, 1.764}, {0.148, 1.788},
		{0.128, 1.810}, {0.100, 1.830}, {0.062, 1.846}, {0.026, 1.858}, {0.0, 1.864},
	}
	mb_lathe(b, xf_at(0, 0, 0), dome[:], 14, .Cream)
	folds := [2]struct {
		y, ring, tube, tilt: f32,
	}{
		{1.766, 0.160, 0.010, 0.06},
		{1.800, 0.144, 0.009, -0.08},
	}
	for fold in folds {
		xf := xf_mul(xf_at(0, fold.y, 0), rl.MatrixRotateX(fold.tilt))
		mb_torus(b, xf, fold.ring, fold.tube, 14, 4, .Cream_Dark)
	}
	mb_torus(b, xf_mul(xf_at(0, 1.726, 0), rl.MatrixRotateX(0.10)), 0.161, 0.012, 14, 4, .Cloth)
	mb_ellipsoid(b, xf_at(0, 1.760, -0.142), {0.042, 0.046, 0.036}, 10, 5, .Cream)
	mb_rivet(b, xf_at(0, 1.760, -0.176), 0.012, .Brass)
}

@(private)
plume :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Plume)
	// Turban tail hangs down the back so it never reads as a sliver from the front.
	rows := [2][2]f32{{1.700, 1.596}, {1.610, 1.500}}
	for i in 0..<2 {
		y := (rows[i][0] + rows[i][1]) * 0.5
		width := 0.086 + f32(i) * 0.014
		mb_plate(b, xf_trs({0.010 * f32(i), y, -0.196 - f32(i) * 0.014}, {0.10, 0.16, 0.04}), width, 0.100, 0.009, .Cream)
	}
	mb_plate(b, xf_trs({0.024, 1.492, -0.212}, {0.12, 0.16, 0.04}), 0.092, 0.026, 0.007, .Cloth)
}

// Cloth cape built from three jointed strips so it trails behind the walk.
mamluk_cape :: proc(b: ^Mesh_Builder) {
	cape_strip(b, .Cape_1, 1.418, 1.128, -0.128, -0.150, 0.196, 0.222, .Cloth_Dark)
	cape_strip(b, .Cape_2, 1.128, 0.892, -0.150, -0.172, 0.222, 0.244, .Cloth_Dark)
	cape_strip(b, .Cape_3, 0.892, 0.680, -0.172, -0.186, 0.244, 0.256, .Cloth_Dark)
	mb_bone(b, .Cape_3)
	// One straight hem instead of a row of teeth.
	mb_plate(b, xf_trs({0, 0.694, -0.186}, {0.05, 0, 0}), 0.500, 0.048, 0.010, .Cloth_Dark, 0.94)
}

@(private)
cape_strip :: proc(b: ^Mesh_Builder, bone: Bone_Id, y_top, y_bot, z_top, z_bot, half_top, half_bot: f32, kind: Mat_Kind) {
	mb_bone(b, bone)
	cols := 5
	top: [5]rl.Vector3
	bot: [5]rl.Vector3
	for i in 0..<cols {
		u := -1 + f32(i) * 2 / f32(cols - 1)
		curve := (1 - u * u)
		top[i] = rl.Vector3{u * half_top, y_top, z_top + curve * 0.030}
		bot[i] = rl.Vector3{u * half_bot, y_bot, z_bot + curve * 0.034}
	}
	for i in 0..<cols - 1 {
		mb_quad(b, {top[i], top[i + 1], bot[i + 1], bot[i]}, kind, 0.92)
	}
}
