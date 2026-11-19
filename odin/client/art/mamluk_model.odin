// Procedural heroic 5.36-head Akira Toriyama x AoE Mamluk body, armour,
// boots, pauldrons, articulated hands, Kalkan shield, and curved shamshir.
// Everything sits 1:1 with BONES in Y = 0.00..1.945 model space.
package art

import "core:math"
import rl "vendor:raylib"

build_mamluk :: proc(enemy: bool, hero: bool = false) -> Mesh_Builder {
	id := hero ? "mamluk_hero" : (enemy ? "mamluk_enemy" : "mamluk")
	if custom, ok := try_build_custom_model(id, enemy, hero); ok {
		return custom
	}
	b := mb_init(palette_for_unit(enemy, hero))
	mamluk_legs(&b)
	mamluk_skirt(&b)
	mamluk_torso(&b)
	mamluk_pauldrons(&b)
	mamluk_arms(&b)
	mamluk_head(&b)
	mamluk_cape(&b)
	return b
}

@(private)
leg_bones :: proc(side: f32) -> (thigh, shin, foot: Bone_Id) {
	if side < 0 {
		return .Thigh_L, .Shin_L, .Foot_L
	}
	return .Thigh_R, .Shin_R, .Foot_R
}

@(private)
arm_bones :: proc(side: f32) -> (upper, fore, hand: Bone_Id) {
	if side < 0 {
		return .Arm_L, .Forearm_L, .Hand_L
	}
	return .Arm_R, .Forearm_R, .Hand_R
}

// Tailored sirwal trousers, sculpted greaves, and grounded cuffed boots.
mamluk_legs :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		thigh, shin, foot := leg_bones(side)
		mb_bone(b, thigh)
		mamluk_thigh(b, side)
		mb_bone(b, shin)
		mamluk_shin(b, side)
		mb_bone(b, foot)
		mamluk_boot(b, side)
	}
}

@(private)
mamluk_thigh :: proc(b: ^Mesh_Builder, side: f32) {
	x := 0.125 * side
	trouser := [6]Loft_Ring{
		{{x, 0.500, 0.002}, 0.074, 0.074},
		{{x, 0.560, 0.002}, 0.092, 0.090},
		{{x, 0.675, 0.000}, 0.114, 0.112},
		{{0.122 * side, 0.790, 0.000}, 0.110, 0.108},
		{{0.106 * side, 0.885, 0.000}, 0.094, 0.094},
		{{0.088 * side, 0.945, 0.000}, 0.068, 0.080},
	}
	mb_loft(b, rl.Matrix(1), trouser[:], 12, .Cloth, false, true)
	cuff := [3]Loft_Ring{
		{{x, 0.495, 0.002}, 0.075, 0.075},
		{{x, 0.520, 0.002}, 0.084, 0.084},
		{{x, 0.545, 0.002}, 0.080, 0.080},
	}
	mb_loft(b, rl.Matrix(1), cuff[:], 10, .Cloth_Dark, false, false)
}

@(private)
mamluk_shin :: proc(b: ^Mesh_Builder, side: f32) {
	x := 0.128 * side
	mb_ellipsoid(b, xf_at(x, 0.495, 0.012), {0.074, 0.068, 0.078}, 10, 4, .Steel)
	mb_torus(b, xf_at(x, 0.495, 0.002), 0.072, 0.006, 10, 3, .Leather_Dark)
	mb_rivet(b, xf_at(x, 0.495, 0.089), 0.007, .Brass)
	mail := [4]Loft_Ring{
		{{x, 0.105, 0.000}, 0.050, 0.052}, {{x, 0.240, -0.002}, 0.058, 0.062},
		{{x, 0.370, -0.004}, 0.068, 0.076}, {{x, 0.485, 0.002}, 0.066, 0.068},
	}
	mb_loft(b, rl.Matrix(1), mail[:], 10, .Mail, false, false)
	greave := [5]Loft_Ring{
		{{x, 0.105, 0.000}, 0.054, 0.056}, {{x, 0.220, -0.002}, 0.062, 0.066},
		{{x, 0.370, -0.006}, 0.074, 0.082}, {{x, 0.440, -0.002}, 0.071, 0.076},
		{{x, 0.475, 0.002}, 0.068, 0.070},
	}
	mb_loft(b, rl.Matrix(1), greave[:], 12, .Iron, false, true)
	mb_torus(b, xf_at(x, 0.468, 0.000), 0.070, 0.005, 10, 3, .Brass_Dark)
	ridge := [4]rl.Vector3{{x, 0.455, 0.072}, {x, 0.370, 0.077}, {x, 0.240, 0.067}, {x, 0.155, 0.059}}
	mb_tube(b, rl.Matrix(1), ridge[:], 0.005, 4, .Brass)
}

@(private)
mamluk_boot :: proc(b: ^Mesh_Builder, side: f32) {
	x := 0.130 * side
	cuff := [4]Loft_Ring{
		{{x, 0.085, 0.002}, 0.059, 0.062}, {{x, 0.115, 0.002}, 0.066, 0.070},
		{{x, 0.145, 0.004}, 0.075, 0.079}, {{x, 0.155, 0.004}, 0.078, 0.082},
	}
	mb_loft(b, rl.Matrix(1), cuff[:], 10, .Leather, false, true)
	trim := [2]Loft_Ring{{{x, 0.138, 0.004}, 0.078, 0.082}, {{x, 0.155, 0.004}, 0.081, 0.085}}
	mb_loft(b, rl.Matrix(1), trim[:], 10, .Leather_Dark, false, true)
	foot := [7]Loft_Z_Ring{
		{{x, 0.036, -0.068}, 0.040, 0.036}, {{x, 0.048, -0.032}, 0.054, 0.052},
		{{x, 0.048, 0.020}, 0.058, 0.054}, {{x, 0.032, 0.075}, 0.062, 0.038},
		{{x, 0.024, 0.130}, 0.054, 0.028}, {{x, 0.036, 0.175}, 0.032, 0.020},
		{{x, 0.048, 0.205}, 0.014, 0.012},
	}
	mb_loft_z(b, rl.Matrix(1), foot[:], 12, .Leather, true, 0.000, true, true)
	sole := [5]Loft_Z_Ring{
		{{x, 0.008, -0.069}, 0.043, 0.010}, {{x, 0.008, 0.000}, 0.060, 0.010},
		{{x, 0.008, 0.075}, 0.064, 0.010}, {{x, 0.008, 0.132}, 0.056, 0.010},
		{{x, 0.012, 0.156}, 0.041, 0.008},
	}
	mb_loft_z(b, rl.Matrix(1), sole[:], 8, .Leather_Dark, true, 0.000, true, true)
	toe := [2]Loft_Z_Ring{{{x, 0.036, 0.171}, 0.034, 0.021}, {{x, 0.048, 0.208}, 0.011, 0.009}}
	mb_loft_z(b, rl.Matrix(1), toe[:], 8, .Brass, false, 0.000, true, true)
}

// Smooth hip seat, layered waist sash, belt, buckle, hip gear, and front sash.
mamluk_skirt :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Pelvis)
	hip := [5]Loft_Ring{
		{{0, 0.865, 0}, 0.132, 0.104}, {{0, 0.910, 0}, 0.150, 0.116},
		{{0, 0.960, 0}, 0.146, 0.114}, {{0, 1.005, 0}, 0.140, 0.110}, {{0, 1.035, 0}, 0.136, 0.106},
	}
	mb_loft(b, rl.Matrix(1), hip[:], 14, .Cloth_Dark, true, false)
	sash := [4]Loft_Ring{
		{{0, 0.960, 0}, 0.152, 0.120}, {{0, 0.985, 0}, 0.155, 0.123},
		{{0, 1.012, 0}, 0.151, 0.119}, {{0, 1.035, 0}, 0.144, 0.114},
	}
	mb_loft(b, rl.Matrix(1), sash[:], 14, .Cloth, true, true)
	belt := [2]Loft_Ring{{{0, 0.978, 0}, 0.157, 0.126}, {{0, 1.013, 0}, 0.157, 0.126}}
	mb_loft(b, rl.Matrix(1), belt[:], 14, .Leather_Dark, false, false)
	mb_box(b, xf_at(0, 0.995, 0.128), {0.062, 0.044, 0.014}, .Brass)
	mb_box(b, xf_at(0, 0.995, 0.134), {0.022, 0.022, 0.006}, .Glow)
	mamluk_hip_gear(b)
	mamluk_front_sash(b)
}

@(private)
mamluk_hip_gear :: proc(b: ^Mesh_Builder) {
	pouch := xf_trs({-0.175, 0.915, 0.055}, {0.06, 0.36, -0.18})
	mb_box(b, pouch, {0.040, 0.086, 0.062}, .Leather)
	mb_box(b, xf_mul(pouch, xf_at(0, 0.018, 0)), {0.044, 0.048, 0.066}, .Leather_Dark)
	mb_rivet(b, xf_mul(pouch, xf_at(-0.023, 0.008, 0)), 0.007, .Brass)

	can_pos := [2]rl.Vector3{{-0.125, 0.915, -0.120}, {-0.075, 0.915, -0.128}}
	for p in can_pos {
		mb_cylinder(b, xf_at(p.x, p.y - 0.028, p.z), 0.019, 0.019, 0.056, 8, .Brass)
		mb_torus(b, xf_at(p.x, p.y, p.z), 0.020, 0.004, 8, 3, .Steel_Dark)
		mb_ellipsoid(b, xf_at(p.x, p.y + 0.030, p.z), {0.012, 0.010, 0.012}, 6, 3, .Glow)
	}

	kh := xf_trs({0.178, 0.900, 0.068}, {0.18, -0.35, 0.14})
	scab := [3]Loft_Ring{
		{{0.016, -0.095, 0}, 0.009, 0.006},
		{{0.004, -0.040, 0}, 0.015, 0.009},
		{{0.000, 0.022, 0}, 0.018, 0.011},
	}
	mb_loft(b, kh, scab[:], 8, .Leather_Dark, true, true)
	mb_ellipsoid(b, xf_mul(kh, xf_at(0.018, -0.098, 0)), {0.010, 0.014, 0.008}, 6, 3, .Brass)
	mb_cylinder(b, xf_mul(kh, xf_at(0, 0.022, 0)), 0.016, 0.013, 0.056, 8, .Leather)
	mb_box(b, xf_mul(kh, xf_at(0, 0.024, 0)), {0.044, 0.011, 0.022}, .Brass)
	mb_ellipsoid(b, xf_mul(kh, xf_at(0, 0.082, 0)), {0.016, 0.014, 0.013}, 6, 3, .Brass)
}

@(private)
mamluk_front_sash :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Sash)
	mb_cloth_sheet(b, 0.960, 0.716, 0.138, 0.163, 0.068, 0.056, 0.022, 0.0045, 5, 4, .Cloth, 0.96)
	mb_cloth_sheet(b, 0.718, 0.700, 0.163, 0.165, 0.057, 0.055, 0.022, 0.005, 5, 1, .Brass_Dark, 0.96)
}

// Narrow waist aketon, anatomical V-tapered breastplate, gorget, and trim.
mamluk_torso :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Spine)
	aketon := [4]Loft_Ring{
		{{0, 1.000, 0}, 0.134, 0.104}, {{0, 1.045, 0}, 0.128, 0.100},
		{{0, 1.115, 0}, 0.124, 0.095}, {{0, 1.185, 0}, 0.120, 0.090},
	}
	mb_loft(b, rl.Matrix(1), aketon[:], 12, .Leather_Dark, false, false)
	mamluk_waist_tassets(b)
	mb_bone(b, .Chest)
	cuirass := [8]Loft_Ring{
		{{0, 1.135, 0.000}, 0.156, 0.120}, {{0, 1.175, 0.000}, 0.148, 0.114},
		{{0, 1.225, 0.003}, 0.162, 0.123}, {{0, 1.275, 0.006}, 0.178, 0.132},
		{{0, 1.320, 0.008}, 0.184, 0.136}, {{0, 1.365, 0.005}, 0.174, 0.128},
		{{0, 1.405, 0.002}, 0.140, 0.106}, {{0, 1.435, 0.000}, 0.088, 0.080},
	}
	mb_loft(b, rl.Matrix(1), cuirass[:], 16, .Steel, true, true)
	gorget := [3]Loft_Ring{
		{{0, 1.385, 0.000}, 0.145, 0.115}, {{0, 1.422, -0.002}, 0.104, 0.090}, {{0, 1.452, -0.004}, 0.078, 0.076},
	}
	mb_loft(b, rl.Matrix(1), gorget[:], 14, .Steel, false, true)
	mb_torus(b, xf_at(0, 1.452, -0.004), 0.078, 0.009, 14, 4, .Brass)
	mamluk_torso_trim(b)
}

@(private)
mamluk_waist_tassets :: proc(b: ^Mesh_Builder) {
	mb_torus(b, xf_at(0, 1.085, 0), 0.140, 0.006, 12, 3, .Brass_Dark)
	for i in 0..<6 {
		ang := -0.92 + f32(i) * 1.84 / 5.0
		px := math.sin(ang) * 0.140
		pz := math.cos(ang) * 0.108
		mb_plate(b, xf_trs({px, 1.082, pz}, {0, ang, 0}), 0.044, 0.088, 0.010, .Iron, 0.96)
		mb_rivet(b, xf_at(px * 1.07, 1.106, pz * 1.07), 0.006, .Brass)
	}
}

@(private)
mamluk_torso_trim :: proc(b: ^Mesh_Builder) {
	fauld := [2]Loft_Ring{{{0, 1.133, 0.000}, 0.160, 0.124}, {{0, 1.147, 0.000}, 0.156, 0.121}}
	mb_loft(b, rl.Matrix(1), fauld[:], 16, .Brass_Dark, true, false)
	pec := [2]Loft_Ring{{{0, 1.384, 0.003}, 0.163, 0.122}, {{0, 1.396, 0.002}, 0.152, 0.114}}
	mb_loft(b, rl.Matrix(1), pec[:], 16, .Brass_Dark, false, false)
	for side in ([2]f32{-1, 1}) {
		strap_ribbon(b, side * 0.088)
		mb_box(b, xf_trs({side * 0.088, 1.335, 0.129}, {-0.26, 0, 0}), {0.032, 0.022, 0.010}, .Brass_Dark)
		mb_rivet(b, xf_at(side * 0.142, 1.402, -0.098), 0.013, .Brass)
	}
	med := xf_mul(xf_at(0, 1.295, 0.140), rl.MatrixRotateX(math.PI * 0.5 - 0.12))
	mb_torus(b, med, 0.025, 0.0055, 12, 3, .Brass)
	mb_ellipsoid(b, med, {0.020, 0.006, 0.020}, 8, 3, .Glow)
}

@(private)
strap_ribbon :: proc(b: ^Mesh_Builder, x: f32) {
	pts := [9]rl.Vector3{
		{x, 1.142, 0.106}, {x, 1.215, 0.110}, {x, 1.295, 0.125}, {x, 1.365, 0.115},
		{x, 1.405, 0.084}, {x, 1.434, 0.000}, {x, 1.405, -0.080}, {x, 1.365, -0.105}, {x, 1.280, -0.112},
	}
	hw := f32(0.013)
	out_l, out_r, in_l, in_r: [9]rl.Vector3
	for i in 0..<9 {
		tang := v_norm(pts[min(i + 1, 8)] - pts[max(i - 1, 0)])
		nrm := v_norm(v_cross(rl.Vector3{1, 0, 0}, tang))
		out_l[i] = pts[i] + rl.Vector3{-hw, 0, 0} + nrm * 0.0075
		out_r[i] = pts[i] + rl.Vector3{hw, 0, 0} + nrm * 0.0075
		in_l[i] = pts[i] + rl.Vector3{-hw, 0, 0} - nrm * 0.001
		in_r[i] = pts[i] + rl.Vector3{hw, 0, 0} - nrm * 0.001
	}
	for i in 0..<8 {
		mb_quad(b, {out_l[i], out_r[i], out_r[i + 1], out_l[i + 1]}, .Leather)
		mb_quad(b, {out_r[i], in_r[i], in_r[i + 1], out_r[i + 1]}, .Leather_Dark)
		mb_quad(b, {in_l[i], out_l[i], out_l[i + 1], in_l[i + 1]}, .Leather_Dark)
	}
	mb_quad(b, {in_l[0], in_r[0], out_r[0], out_l[0]}, .Leather_Dark)
	mb_quad(b, {out_l[8], out_r[8], in_r[8], in_l[8]}, .Leather_Dark)
}

// Arched shoulder cop with brass rim and 2 overlapping curved lames.
mamluk_pauldrons :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		bone := Bone_Id.Shoulder_L
		if side > 0 {
			bone = .Shoulder_R
		}
		mb_bone(b, bone)
		tilt := rl.MatrixRotateZ(-side * 0.22)
		rim_xf := xf_mul(xf_at(0.222 * side, 1.394, 0), xf_mul(tilt, rl.MatrixScale(1, 1, 0.098 / 0.088)))
		mb_ellipsoid(b, xf_mul(xf_at(0.220 * side, 1.418, 0), tilt), {0.088, 0.074, 0.098}, 12, 4, .Iron)
		mb_torus(b, rim_xf, 0.084, 0.0075, 12, 3, .Brass)
		mb_rivet(b, xf_at(0.304 * side, 1.412, 0), 0.008, .Brass)
		curved_lame(b, side, 1.392, 1.352, 0.075, 0.081)
		curved_lame(b, side, 1.358, 1.318, 0.071, 0.077)
	}
}

@(private)
curved_lame :: proc(b: ^Mesh_Builder, side, y_top, y_bot, r_top, r_bot: f32) {
	out, inn: [2][6]rl.Vector3
	ys := [2]f32{y_top, y_bot}
	rs := [2]f32{r_top, r_bot}
	for row in 0..<2 {
		for c in 0..<6 {
			a := -math.PI * 0.36 + f32(c) * math.PI * 0.72 / 5.0
			ca, sa := math.cos(a), math.sin(a)
			out[row][c] = {side * (0.235 + ca * rs[row]), ys[row], sa * rs[row]}
			inn[row][c] = {side * (0.235 + ca * (rs[row] - 0.006)), ys[row], sa * (rs[row] - 0.006)}
		}
	}
	for c in 0..<5 {
		if side > 0 {
			mb_quad(b, {out[0][c], out[0][c + 1], out[1][c + 1], out[1][c]}, .Iron)
			mb_quad(b, {inn[0][c], inn[1][c], inn[1][c + 1], inn[0][c + 1]}, .Steel_Dark, 0.90)
			mb_quad(b, {out[1][c], out[1][c + 1], inn[1][c + 1], inn[1][c]}, .Brass_Dark)
		} else {
			mb_quad(b, {out[0][c], out[1][c], out[1][c + 1], out[0][c + 1]}, .Iron)
			mb_quad(b, {inn[0][c], inn[0][c + 1], inn[1][c + 1], inn[1][c]}, .Steel_Dark, 0.90)
			mb_quad(b, {out[1][c], inn[1][c], inn[1][c + 1], out[1][c + 1]}, .Brass_Dark)
		}
	}
}

// Mail sleeves, elbow couters, vambraces, articulated hands, Kalkan, shamshir.
mamluk_arms :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		upper, fore, hand := arm_bones(side)
		mb_bone(b, upper)
		sleeve := [3]Loft_Ring{
			{{0.255 * side, 1.135, 0}, 0.056, 0.056}, {{0.245 * side, 1.265, 0}, 0.062, 0.062},
			{{0.235 * side, 1.390, 0}, 0.068, 0.068},
		}
		mb_loft(b, rl.Matrix(1), sleeve[:], 10, .Mail, false, false)
		mb_torus(b, xf_at(0.244 * side, 1.280, 0), 0.063, 0.006, 10, 3, .Brass_Dark)

		mb_bone(b, fore)
		mb_ellipsoid(b, xf_at(0.255 * side, 1.135, -0.008), {0.066, 0.064, 0.068}, 10, 4, .Steel)
		mb_rivet(b, xf_at(0.255 * side, 1.135, -0.072), 0.008, .Brass)
		vamb := [3]Loft_Ring{
			{{0.265 * side, 0.890, 0}, 0.044, 0.042}, {{0.260 * side, 1.015, 0}, 0.058, 0.055},
			{{0.256 * side, 1.120, 0}, 0.064, 0.062},
		}
		mb_loft(b, rl.Matrix(1), vamb[:], 10, .Iron, false, false)
		mb_torus(b, xf_at(0.256 * side, 1.105, 0), 0.063, 0.005, 10, 3, .Brass_Dark)
		cuff := [2]Loft_Ring{{{0.265 * side, 0.880, 0}, 0.045, 0.036}, {{0.264 * side, 0.908, 0}, 0.052, 0.048}}
		mb_loft(b, rl.Matrix(1), cuff[:], 10, .Leather_Dark, false, false)

		mb_bone(b, hand)
		mamluk_hand(b, side)
	}
	mamluk_shield(b)
	mamluk_shamshir(b)
}

@(private)
mamluk_hand :: proc(b: ^Mesh_Builder, side: f32) {
	x := 0.265 * side
	palm := [3]Loft_Ring{
		{{x, 0.818, 0.002}, 0.036, 0.022}, {{x, 0.855, 0.000}, 0.044, 0.028}, {{x, 0.892, 0.000}, 0.040, 0.026},
	}
	mb_loft(b, rl.Matrix(1), palm[:], 8, .Leather, true, true)
	mb_box(b, xf_at(x, 0.852, -0.024), {0.070, 0.052, 0.012}, .Steel)
	mb_box(b, xf_at(x, 0.818, 0.022), {0.068, 0.013, 0.011}, .Steel)
	for i in 0..<4 {
		fx := x + (-0.027 + f32(i) * 0.018) * side
		p0 := rl.Vector3{fx, 0.822, 0.012}
		p1 := rl.Vector3{fx, 0.816, 0.054}
		p2 := rl.Vector3{fx, 0.842, 0.056}
		mb_capsule(b, p0, p1, 0.0085, 0.0078, 4, .Skin)
		mb_capsule(b, p1, p2, 0.0078, 0.0068, 4, .Skin)
	}
	t0 := rl.Vector3{x - 0.036 * side, 0.872, 0.016}
	t1 := rl.Vector3{x - 0.042 * side, 0.850, 0.044}
	t2 := rl.Vector3{x - 0.014 * side, 0.844, 0.062}
	mb_capsule(b, t0, t1, 0.0100, 0.0088, 4, .Skin)
	mb_capsule(b, t1, t2, 0.0088, 0.0075, 4, .Skin)
}

@(private)
mamluk_shield :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Forearm_L)
	mb_torus(b, xf_at(-0.258, 1.068, 0.000), 0.062, 0.007, 10, 3, .Leather_Dark)
	mb_torus(b, xf_at(-0.262, 0.945, 0.000), 0.051, 0.007, 10, 3, .Leather_Dark)
	mb_capsule(b, {-0.295, 1.068, 0.015}, {-0.335, 1.068, 0.035}, 0.008, 0.008, 4, .Leather_Dark)
	mb_capsule(b, {-0.295, 0.945, 0.015}, {-0.335, 0.945, 0.035}, 0.008, 0.008, 4, .Leather_Dark)

	frame := xf_mul(
		xf_at(-0.335, 1.005, 0.040),
		xf_mul(rl.MatrixRotateY(0.32), rl.MatrixRotateZ(math.PI * 0.5)),
	)
	dome := [5]rl.Vector2{{0.245, 0.000}, {0.200, 0.032}, {0.140, 0.064}, {0.070, 0.087}, {0.000, 0.095}}
	mb_lathe(b, frame, dome[:], 16, .Steel_Dark)
	back := [3]rl.Vector2{{0.000, 0.024}, {0.130, 0.010}, {0.245, 0.000}}
	mb_lathe(b, frame, back[:], 16, .Steel, false, false)
	mb_torus(b, frame, 0.244, 0.014, 16, 4, .Brass)
	mb_dome_star(b, frame, 0.125, 0.056, 0.095, 0.245, 0.006, 8, .Brass)
	mb_torus(b, xf_mul(frame, xf_at(0, 0.099, 0)), 0.036, 0.008, 12, 3, .Brass_Dark)
	mb_ellipsoid(b, xf_mul(frame, xf_at(0, 0.100, 0)), {0.033, 0.014, 0.033}, 10, 3, .Brass)
	mb_ellipsoid(b, xf_mul(frame, xf_at(0, 0.108, 0)), {0.019, 0.011, 0.019}, 8, 3, .Glow)
}

@(private)
mamluk_shamshir :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Hand_R)
	mount := xf_mul(
		xf_at(0.268, 0.835, 0.048),
		xf_mul(rl.MatrixRotateY(0.14), xf_mul(rl.MatrixRotateX(1.38), rl.MatrixRotateY(-math.PI * 0.5))),
	)
	grip := [3]Loft_Ring{{{0, -0.072, 0}, 0.016, 0.013}, {{0, 0, 0}, 0.017, 0.014}, {{0, 0.073, 0}, 0.016, 0.013}}
	mb_loft(b, mount, grip[:], 8, .Leather, true, true)
	mb_torus(b, xf_mul(mount, xf_at(0, -0.056, 0)), 0.017, 0.003, 8, 3, .Brass)
	mb_torus(b, xf_mul(mount, xf_at(0, 0.058, 0)), 0.017, 0.003, 8, 3, .Brass)
	mb_ellipsoid(b, xf_mul(mount, xf_at(-0.008, -0.088, 0)), {0.024, 0.022, 0.017}, 8, 4, .Brass)
	mb_box(b, xf_mul(mount, xf_at(0, 0.078, 0)), {0.088, 0.018, 0.030}, .Brass)

	qf := [3]rl.Vector3{{0.040, 0.078, 0}, {0.072, 0.095, 0}, {0.086, 0.122, 0}}
	qb := [3]rl.Vector3{{-0.040, 0.078, 0}, {-0.070, 0.062, 0}, {-0.082, 0.038, 0}}
	mb_tube(b, mount, qf[:], 0.007, 5, .Brass)
	mb_tube(b, mount, qb[:], 0.007, 5, .Brass)

	spine := [8]rl.Vector2{
		{-0.028, 0.086}, {-0.034, 0.190}, {-0.048, 0.295}, {-0.072, 0.400},
		{-0.104, 0.505}, {-0.144, 0.610}, {-0.192, 0.710}, {-0.246, 0.806},
	}
	width := [8]f32{0.058, 0.056, 0.053, 0.048, 0.041, 0.032, 0.020, 0.004}
	mb_blade(b, mount, spine[:], width[:], 0.0085, .Blade)

	fuller_f, fuller_b: [7]rl.Vector3
	for i in 0..<7 {
		rx := spine[i].x + width[i] * 0.34
		fuller_f[i] = {rx, spine[i].y, 0.0048}
		fuller_b[i] = {rx, spine[i].y, -0.0048}
	}
	mb_tube(b, mount, fuller_f[:], 0.0020, 4, .Glow)
	mb_tube(b, mount, fuller_b[:], 0.0020, 4, .Glow)
}
