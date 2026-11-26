// Analytic 2-bone IK and aim-chain solvers matching art.BONES and Euler XYZ skinning.
package art_anim_rig

import "core:math"
import "core:math/linalg"
import art ".."
import spec "../spec"

BONE_COUNT :: art.BONE_COUNT

// Evaluates pure FK model-space transforms matching art.pose_matrices(pose, Matrix(1)).
eval_fk_matrices :: proc(rot: ^[BONE_COUNT][3]f32, root_offset: [3]f32) -> [BONE_COUNT]linalg.Matrix4f32 {
	model: [BONE_COUNT]linalg.Matrix4f32
	for index in 0 ..< BONE_COUNT {
		b := spec.Bone_Id(index)
		h := art.BONES[b].head
		t_pos := linalg.matrix4_translate_f32({h.x, h.y, h.z})
		t_neg := linalg.matrix4_translate_f32({-h.x, -h.y, -h.z})
		r := rot[index]
		rm := linalg.matrix4_from_euler_angles_xyz(r[0], r[1], r[2])
		local := t_pos * rm * t_neg
		if art.BONES[b].root {
			root_t := linalg.matrix4_translate_f32(root_offset)
			model[index] = root_t * local
		} else {
			model[index] = model[int(art.BONES[b].parent)] * local
		}
	}
	return model
}

mat4_point :: proc(m: linalg.Matrix4f32, p: [3]f32) -> [3]f32 {
	r := m * linalg.Vector4f32{p[0], p[1], p[2], 1}
	return {r[0], r[1], r[2]}
}

mat4_dir :: proc(m: linalg.Matrix4f32, d: [3]f32) -> [3]f32 {
	r := m * linalg.Vector4f32{d[0], d[1], d[2], 0}
	return {r[0], r[1], r[2]}
}

@(private)
norm_or :: proc(v, fallback: [3]f32) -> [3]f32 {
	l := linalg.length(v)
	return l > 1e-6 ? v / l : fallback
}

@(private)
build_orthonormal_basis :: proc(fwd_in, hint_in: [3]f32) -> linalg.Matrix3f32 {
	x := norm_or(fwd_in, {0, -1, 0})
	perp := hint_in - x * linalg.dot(hint_in, x)
	if linalg.length2(perp) < 1e-8 {
		alt := abs(x[2]) < 0.9 ? [3]f32{0, 0, 1} : [3]f32{1, 0, 0}
		perp = alt - x * linalg.dot(alt, x)
	}
	z := norm_or(perp, {0, 0, 1})
	y := norm_or(linalg.cross(z, x), {0, 1, 0})
	z = linalg.cross(x, y)
	return linalg.Matrix3f32{
		x[0], y[0], z[0],
		x[1], y[1], z[1],
		x[2], y[2], z[2],
	}
}

@(private)
rot_between_dirs :: proc(from_dir, to_dir: [3]f32) -> linalg.Matrix3f32 {
	a := norm_or(from_dir, {0, -1, 0})
	b := norm_or(to_dir, {0, -1, 0})
	d := clamp(linalg.dot(a, b), -1.0, 1.0)
	if d > 0.9999 {
		return linalg.MATRIX3F32_IDENTITY
	}
	if d < -0.9999 {
		ortho := abs(a[0]) < 0.9 ? [3]f32{1, 0, 0} : [3]f32{0, 1, 0}
		axis := norm_or(linalg.cross(a, ortho), {1, 0, 0})
		return linalg.matrix3_from_quaternion(linalg.quaternion_angle_axis(f32(math.PI), axis))
	}
	axis := norm_or(linalg.cross(a, b), {1, 0, 0})
	ang := math.acos(d)
	return linalg.matrix3_from_quaternion(linalg.quaternion_angle_axis(ang, axis))
}

// Solves 2-bone IK directly into Euler XYZ rotations of upper and lower bones.
solve_two_bone_ik :: proc(
	rot: ^[BONE_COUNT][3]f32,
	root_offset: [3]f32,
	upper, lower, end: spec.Bone_Id,
	target_world, pole_world, rest_bend_dir: [3]f32,
) {
	fk := eval_fk_matrices(rot, root_offset)
	parent_mat := art.BONES[upper].root ? linalg.MATRIX4F32_IDENTITY : fk[int(art.BONES[upper].parent)]
	inv_parent := linalg.inverse(parent_mat)

	a_rest := art.BONES[upper].head
	b_rest := art.BONES[lower].head
	c_rest := art.BONES[end].head
	tgt := mat4_point(inv_parent, target_world)
	pole := mat4_point(inv_parent, pole_world)

	u_rest := b_rest - a_rest
	l_rest := c_rest - b_rest
	l1 := linalg.length(u_rest)
	l2 := linalg.length(l_rest)
	if l1 < 1e-4 || l2 < 1e-4 {
		return
	}

	bend_dir, b_sol, c_sol := solve_triangle_ik(a_rest, tgt, pole, rest_bend_dir, l1, l2)
	m_rest := build_orthonormal_basis(u_rest, rest_bend_dir)
	m_sol := build_orthonormal_basis(b_sol - a_rest, bend_dir)
	r_upper := m_sol * linalg.transpose(m_rest)
	rx, ry, rz := linalg.euler_angles_xyz_from_matrix3(r_upper)
	rot[int(upper)] = {rx, ry, rz}

	l_want := linalg.transpose(r_upper) * (c_sol - b_sol)
	r_lower := rot_between_dirs(l_rest, l_want)
	lx, ly, lz := linalg.euler_angles_xyz_from_matrix3(r_lower)
	rot[int(lower)] = {lx, ly, lz}
}

@(private)
solve_triangle_ik :: proc(a, tgt, pole, rest_bend: [3]f32, l1, l2: f32) -> (bend, b_sol, c_sol: [3]f32) {
	to_t := tgt - a
	raw_d := linalg.length(to_t)
	dir_t := raw_d > 1e-5 ? to_t / raw_d : [3]f32{0, -1, 0}
	d := clamp(raw_d, abs(l1 - l2) + 0.002, l1 + l2 - 0.002)
	c_sol = a + dir_t * d

	bend = (pole - a) - dir_t * linalg.dot(pole - a, dir_t)
	if linalg.length2(bend) < 1e-7 {
		bend = rest_bend - dir_t * linalg.dot(rest_bend, dir_t)
	}
	bend = norm_or(bend, rest_bend)
	cos_a := clamp((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	sin_a := math.sqrt(max(f32(0), 1.0 - cos_a * cos_a))
	b_sol = a + dir_t * (l1 * cos_a) + bend * (l1 * sin_a)
	return
}

// Aims Neck (35%) and Head (65%) toward target_world using shortest-arc rotation.
solve_aim_chain :: proc(rot: ^[BONE_COUNT][3]f32, root_offset: [3]f32, target_world: [3]f32) {
	fk := eval_fk_matrices(rot, root_offset)
	chest_mat := fk[int(spec.Bone_Id.Chest)]
	head_local := art.BONES[.Head].head
	head_in_chest := head_local
	tgt_in_chest := mat4_point(linalg.inverse(chest_mat), target_world)
	dir := norm_or(tgt_in_chest - head_in_chest, {0, 0, 1})

	yaw := clamp(math.atan2(dir[0], dir[2]), -1.15, 1.15)
	pitch := clamp(-math.asin(clamp(dir[1], -0.95, 0.95)), -0.78, 0.78)
	rot[int(spec.Bone_Id.Neck)] = {pitch * 0.35, yaw * 0.35, 0}
	rot[int(spec.Bone_Id.Head)] = {pitch * 0.65, yaw * 0.65, 0}
}
