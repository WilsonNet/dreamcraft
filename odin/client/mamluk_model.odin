// Procedural Mamluk-armoured soldier: the unit model is built from code, no
// asset pipeline. Silhouette beats polygon count at this scale, so the model
// stacks recognisable shapes: wrapped turban, veiled face, lamellar cuirass,
// pointed boots, shamshir and round shield. Brass conduits and a glowing visor
// add the arcane-tech edge.
package main

import "core:math"
import rl "vendor:raylib"

build_mamluk :: proc(enemy: bool) -> Mesh_Builder {
	b := mb_init(palette_for_team(enemy))
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

// Baggy sirwal over mail leggings, plated greaves and pointed boots.
mamluk_legs :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		x := 0.115 * side
		thigh, shin, foot := leg_bones(side)

		mb_bone(b, thigh)
		cloth := [6]rl.Vector2{{0.092, -0.395}, {0.120, -0.320}, {0.152, -0.215}, {0.160, -0.120}, {0.142, -0.040}, {0.118, 0.020}}
		mb_lathe(b, xf_at(x, 0.92, 0), cloth[:], 10, .Cloth)
		mb_torus(b, xf_at(x, 0.700, 0), 0.138, 0.013, 10, 4, .Cloth_Dark)
		mb_torus(b, xf_at(x, 0.582, 0), 0.112, 0.011, 10, 4, .Cloth_Dark)
		mb_plate(b, xf_trs({x + side * 0.070, 0.760, 0.090}, {0, side * 0.5, 0}), 0.090, 0.180, 0.014, .Cloth_Dark)

		mb_bone(b, shin)
		mb_ellipsoid(b, xf_at(x, 0.500, 0.006), {0.098, 0.086, 0.098}, 10, 5, .Steel)
		mb_cylinder(b, xf_at(x, 0.15, 0.004), 0.066, 0.086, 0.36, 10, .Mail)
		mb_cylinder(b, xf_at(x, 0.20, 0.008), 0.076, 0.090, 0.26, 10, .Iron)
		mb_torus(b, xf_at(x, 0.21, 0.006), 0.084, 0.011, 10, 4, .Brass_Dark)
		mb_torus(b, xf_at(x, 0.45, 0.006), 0.090, 0.009, 10, 4, .Leather_Dark)
		mb_plate(b, xf_trs({x, 0.32, 0.096}, {0.10, 0, 0}), 0.080, 0.20, 0.020, .Iron)
		mb_box(b, xf_at(x, 0.30, 0.108), {0.012, 0.062, 0.008}, .Brass_Dark)
		mb_box(b, xf_at(x, 0.27, 0.122), {0.030, 0.072, 0.010}, .Glow)
		mb_cylinder(b, xf_at(x, 0.545, 0.002), 0.096, 0.096, 0.045, 10, .Leather_Dark)

		mb_bone(b, foot)
		mb_box(b, xf_at(x, 0.055, 0.035), {0.128, 0.100, 0.205}, .Leather)
		mb_cone(b, xf_mul(xf_at(x, 0.050, 0.140), rl.MatrixRotateX(math.PI * 0.5)), 0.060, 0.115, 6, .Leather)
		mb_box(b, xf_at(x, 0.048, 0.248), {0.066, 0.058, 0.040}, .Brass_Dark)

		mb_plate(b, xf_trs({x, 0.135, 0.105}, {0.25, 0, 0}), 0.105, 0.105, 0.012, .Steel)
		mb_box(b, xf_at(x, 0.030, -0.085), {0.110, 0.058, 0.068}, .Leather_Dark)
		mb_rivet(b, xf_at(x, 0.115, 0.150), 0.011, .Brass)

	}
}

// Belt, sash wraps, pouches, powder canisters and a khanjar at the hip.
mamluk_skirt :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Pelvis)
	mb_ellipsoid(b, xf_at(0, 0.895, 0), {0.166, 0.142, 0.138}, 12, 6, .Cloth_Dark)
	mb_torus(b, xf_at(0, 1.000, 0), 0.162, 0.028, 12, 5, .Leather_Dark)
	mb_torus(b, xf_at(0, 1.038, 0), 0.166, 0.028, 12, 5, .Cloth)
	mb_torus(b, xf_at(0, 0.966, 0), 0.172, 0.026, 12, 5, .Cloth)
	mb_box(b, xf_at(0, 1.000, 0.180), {0.085, 0.060, 0.026}, .Brass)
	mb_rivet(b, xf_at(0, 1.000, 0.198), 0.020, .Glow)
	mb_box(b, xf_trs({-0.175, 0.905, 0.075}, {0, 0.5, 0}), {0.095, 0.130, 0.070}, .Leather)
	mb_box(b, xf_trs({0.168, 0.900, -0.040}, {0, -0.4, 0}), {0.085, 0.115, 0.075}, .Leather)
	mb_rivet(b, xf_at(-0.175, 0.955, 0.118), 0.013, .Brass)
	// Arcane canisters: small brass bottles with glowing sight-glasses.
	for i in 0..<2 {
		x := -0.135 + f32(i) * 0.055
		z := -0.085 - f32(i) * 0.030
		mb_cylinder(b, xf_at(x, 0.855, z), 0.030, 0.030, 0.085, 8, .Brass)
		mb_torus(b, xf_at(x, 0.878, z), 0.031, 0.008, 8, 4, .Steel_Dark)
		mb_ellipsoid(b, xf_at(x, 0.942, z), {0.024, 0.018, 0.024}, 8, 4, .Glow)
	}

	// Hanging sash on its own joint so it swings behind the belt.
	mb_bone(b, .Sash)
	rows := [3][2]f32{{0.930, 0.820}, {0.840, 0.740}, {0.760, 0.655}}
	for i in 0..<3 {
		width := 0.150 - f32(i) * 0.014
		y := (rows[i][0] + rows[i][1]) * 0.5
		mb_plate(b, xf_trs({0, y, 0.172 + f32(i) * 0.012}, {-0.08, 0, 0}), width, 0.105, 0.012, .Cloth)
	}
	mb_plate(b, xf_trs({0, 0.625, 0.198}, {-0.08, 0, 0}), 0.110, 0.030, 0.008, .Steel_Dark)

	// Khanjar: short curved dagger opposite the canisters.
	xf := xf_trs({0.185, 0.880, 0.095}, {0.2, 0.5, 0.1})
	mb_box(b, xf, {0.036, 0.115, 0.028}, .Leather_Dark)
	mb_cylinder(b, xf_trs({0.185, 0.955, 0.100}, {0.2, 0.5, 0.1}), 0.020, 0.016, 0.060, 6, .Leather)
	mb_rivet(b, xf_at(0.185, 0.995, 0.104), 0.014, .Brass)
	spine := [4]rl.Vector2{{0.0, 0.0}, {0.010, -0.05}, {0.035, -0.10}, {0.070, -0.14}}
	width := [4]f32{0.030, 0.028, 0.020, 0.004}
	mb_blade(b, xf_trs({0.185, 0.875, 0.095}, {0, 0.5, 0}), spine[:], width[:], 0.006, .Blade)
}

// Lamellar cuirass over a quilted aketon, crossed harness and the chest core.
mamluk_torso :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Spine)
	mb_ellipsoid(b, xf_at(0, 1.100, 0), {0.162, 0.138, 0.132}, 12, 6, .Leather_Dark)

	mb_bone(b, .Chest)
	// Quilted aketon under a smooth banded cuirass: cleaner than loose scales.
	mb_ellipsoid(b, xf_at(0, 1.292, 0), {0.158, 0.196, 0.120}, 14, 7, .Leather_Dark)
	rig := rl.MatrixScale(1.0, 1.0, 0.76)
	bands := [5]struct {
		y, ring: f32,
	}{
		{1.116, 0.158},
		{1.176, 0.166},
		{1.236, 0.172},
		{1.296, 0.176},
		{1.356, 0.168},
	}
	for band in bands {
		mb_torus(b, xf_mul(xf_at(0, band.y, 0), rig), band.ring, 0.026, 16, 5, .Steel)
	}
	mb_torus(b, xf_mul(xf_at(0, 1.092, 0), rig), 0.156, 0.012, 16, 4, .Brass_Dark)
	mb_torus(b, xf_mul(xf_at(0, 1.392, 0), rig), 0.158, 0.010, 16, 4, .Brass_Dark)
	mb_plate(b, xf_trs({0, 1.300, -0.148}, {0, math.PI, 0}), 0.270, 0.270, 0.022, .Steel_Dark)
	mb_plate(b, xf_trs({0, 1.286, 0.130}, {0, 0, 0}), 0.044, 0.300, 0.010, .Steel_Dark)
	for i in 0..<4 {
		mb_rivet(b, xf_at(-0.100 + f32(i) * 0.066, 1.386, -0.168), 0.010, .Brass)
	}
	mamluk_chest_core(b)
	mamluk_harness(b)
}

@(private)
mamluk_chest_core :: proc(b: ^Mesh_Builder) {
	mb_torus(b, xf_mul(xf_at(0, 1.268, 0.170), rl.MatrixRotateX(math.PI * 0.5)), 0.040, 0.010, 12, 5, .Brass)
	mb_cylinder(b, xf_mul(xf_at(0, 1.268, 0.164), rl.MatrixRotateX(math.PI * 0.5)), 0.026, 0.026, 0.010, 12, .Glow)
	mb_torus(b, xf_mul(xf_at(0, 1.268, 0.158), rl.MatrixRotateX(math.PI * 0.5)), 0.054, 0.006, 12, 4, .Steel_Dark)
}

@(private)
mamluk_harness :: proc(b: ^Mesh_Builder) {
	// Crossed leather harness with brass buckles.
	mb_plate(b, xf_trs({-0.040, 1.280, 0.166}, {0, -0.24, 0.48}), 0.060, 0.360, 0.010, .Leather)
	mb_box(b, xf_trs({-0.082, 1.372, 0.176}, {0, 0, 0.48}), {0.046, 0.034, 0.016}, .Brass_Dark)
	// Gorget and mail collar.
	
	
	mb_torus(b, xf_at(0, 1.446, 0), 0.074, 0.009, 12, 4, .Brass_Dark)
}

// Rounded pauldron cap with a brass rim and a single lame underneath.
mamluk_pauldrons :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		bone := Bone_Id.Shoulder_L
		if side > 0 {
			bone = .Shoulder_R
		}
		mb_bone(b, bone)
		x := 0.190 * side
		mb_ellipsoid(b, xf_at(x, 1.444, 0), {0.092, 0.074, 0.102}, 12, 6, .Iron)
		mb_torus(b, xf_at(x, 1.412, 0), 0.084, 0.011, 12, 4, .Brass_Dark)
		mb_plate(b, xf_trs({x + side * 0.008, 1.382, 0.004}, {-0.10, 0, -side * 0.30}), 0.158, 0.066, 0.028, .Iron)
		mb_rivet(b, xf_at(x + side * 0.030, 1.430, 0.096), 0.009, .Brass)
	}
}

// Mail sleeves, plated vambraces, gloved fists, shield and shamshir.
mamluk_arms :: proc(b: ^Mesh_Builder) {
	for side in ([2]f32{-1, 1}) {
		upper, fore, hand := arm_bones(side)
		x := 0.300 * side
		mb_bone(b, upper)
		mb_cylinder(b, xf_at(x, 1.185, 0), 0.066, 0.082, 0.235, 10, .Mail)
		mb_torus(b, xf_at(x, 1.300, 0), 0.068, 0.011, 10, 4, .Brass)
		mb_plate(b, xf_trs({x + side * 0.070, 1.300, 0}, {0, 0, -side * 0.10}), 0.055, 0.140, 0.012, .Brass_Dark)

		mb_bone(b, fore)
		mb_ellipsoid(b, xf_at(x, 1.160, 0), {0.076, 0.072, 0.076}, 10, 5, .Steel)
		mb_cylinder(b, xf_at(x, 0.975, 0), 0.060, 0.078, 0.195, 10, .Iron)
		mb_torus(b, xf_at(x, 1.010, 0), 0.068, 0.010, 10, 4, .Brass)
		mb_torus(b, xf_at(x, 0.985, 0), 0.064, 0.009, 10, 4, .Brass_Dark)
		for i in 0..<3 {
			mb_rivet(b, xf_at(x + side * 0.058, 1.055 + f32(i) * 0.036, 0.040), 0.010, .Brass)
		}
		mb_box(b, xf_at(x + side * 0.040, 1.120, 0.055), {0.024, 0.052, 0.012}, .Brass_Dark)

		mb_bone(b, hand)
		mb_box(b, xf_at(x, 0.895, 0.010), {0.096, 0.108, 0.106}, .Leather)
		for i in 0..<4 {
			mb_box(b, xf_at(x, 0.918 - f32(i % 2) * 0.024, 0.060 + f32(i) * 0.001), {0.070, 0.020, 0.026}, .Skin)
		}
		mb_box(b, xf_at(x - side * 0.048, 0.900, 0.030), {0.026, 0.062, 0.040}, .Skin)
	}
	mamluk_shield(b)
	mamluk_shamshir(b)
}

@(private)
mamluk_shield :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Forearm_L)
	frame := xf_mul(
		xf_at(-0.400, 1.030, 0.080),
		xf_mul(rl.MatrixRotateY(1.35), rl.MatrixRotateZ(math.PI * 0.5)),
	)
	dome := [4]rl.Vector2{{0.256, 0.000}, {0.246, 0.026}, {0.178, 0.066}, {0.0, 0.094}}
	mb_lathe(b, frame, dome[:], 16, .Steel_Dark)
	inner := [3]rl.Vector2{{0.256, 0.000}, {0.112, 0.010}, {0.0, 0.026}}
	mb_lathe(b, frame, inner[:], 16, .Steel, false, false)
	mb_torus(b, frame, 0.252, 0.019, 16, 5, .Brass)
	mb_star(b, xf_mul(frame, xf_at(0, 0.082, 0)), 0.124, 0.054, 0.014, 8, .Brass)
	mb_torus(b, xf_mul(frame, xf_at(0, 0.098, 0)), 0.047, 0.011, 10, 4, .Brass_Dark)
	mb_ellipsoid(b, xf_mul(frame, xf_at(0, 0.106, 0)), {0.034, 0.022, 0.034}, 8, 4, .Glow)
	for i in 0..<4 {
		angle := f32(i) * math.TAU / 4 + math.TAU / 8
		local := xf_mul(frame, xf_at(math.cos(angle) * 0.222, 0.018, math.sin(angle) * 0.222))
		mb_rivet(b, local, 0.011, .Brass_Dark)
	}
}

@(private)
mamluk_shamshir :: proc(b: ^Mesh_Builder) {
	mb_bone(b, .Hand_R)
	mount := xf_mul(
		xf_at(0.345, 0.940, 0.075),
		xf_mul(rl.MatrixRotateX(-0.12), rl.MatrixRotateY(0.62)),
	)
	// Grip and pommel.
	mb_cylinder(b, xf_mul(mount, xf_at(0, -0.060, 0)), 0.024, 0.027, 0.235, 8, .Leather)
	for i in 0..<4 {
		mb_torus(b, xf_mul(mount, xf_at(0, -0.040 + f32(i) * 0.052, 0)), 0.028, 0.006, 8, 4, .Brass)
	}
	mb_ellipsoid(b, xf_mul(mount, xf_at(0, -0.082, 0)), {0.035, 0.030, 0.035}, 8, 4, .Brass)
	mb_rivet(b, xf_mul(mount, xf_at(0, -0.100, 0)), 0.017, .Glow)
	// Guard and quillons.
	mb_box(b, xf_mul(mount, xf_at(0, 0.180, 0)), {0.052, 0.036, 0.215}, .Brass)
	for side in ([2]f32{-1, 1}) {
		quillon := [3]rl.Vector3{
			{0, 0.185, 0.100 * side},
			{0.020, 0.160, 0.145 * side},
			{0.030, 0.115, 0.175 * side},
		}
		mb_tube(b, mount, quillon[:], 0.013, 5, .Brass)
	}
	// Curved single-edged blade with a glowing fuller.
	spine := [6]rl.Vector2{{0.000, 0.215}, {0.014, 0.360}, {0.052, 0.510}, {0.108, 0.650}, {0.180, 0.775}, {0.262, 0.875}}
	width := [6]f32{0.070, 0.068, 0.060, 0.048, 0.032, 0.007}
	mb_blade(b, mount, spine[:], width[:], 0.011, .Steel)
	runes := [6]rl.Vector3{
		{0.035, 0.230, 0.013}, {0.049, 0.372, 0.013}, {0.084, 0.522, 0.013},
		{0.138, 0.662, 0.013}, {0.204, 0.786, 0.013}, {0.272, 0.868, 0.013},
	}
	mb_tube(b, mount, runes[:], 0.0045, 4, .Glow)
	runes_back := [6]rl.Vector3{
		{0.035, 0.230, -0.013}, {0.049, 0.372, -0.013}, {0.084, 0.522, -0.013},
		{0.138, 0.662, -0.013}, {0.204, 0.786, -0.013}, {0.272, 0.868, -0.013},
	}
	mb_tube(b, mount, runes_back[:], 0.0045, 4, .Glow)
}
