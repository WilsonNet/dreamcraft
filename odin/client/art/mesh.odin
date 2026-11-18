// Procedural mesh builder for unit models.
//
// Every vertex carries position, normal, an albedo colour with baked ambient
// occlusion in the alpha channel, and a (metal, glow) pair in the UV channel.
// Flat quads keep armour plates crisp, smooth rings keep curved metal painterly.
// Nothing here touches the GPU; the client uploads the result once per unit and
// then rewrites positions/normals while animating on the CPU.
package art

import "core:math"
import rl "vendor:raylib"

MAX_MODEL_VERTS :: 24000
MAX_MODEL_INDICES :: 72000

Mesh_Builder :: struct {
	pos:       [dynamic]rl.Vector3,
	nrm:       [dynamic]rl.Vector3,
	col:       [dynamic]rl.Color,
	uv:        [dynamic]rl.Vector2,
	idx:       [dynamic]u16,
	bone:      [dynamic]u8,
	palette:   Team_Palette,
	bone_id:   u8,
	base_xf:   rl.Matrix,
	ao_height: f32,
	is_prop:   bool,
	overflow:  bool,
}

mb_init :: proc(palette: Team_Palette) -> Mesh_Builder {
	b := Mesh_Builder {
		palette = palette,
		base_xf = rl.Matrix(1),
	}
	b.pos = make([dynamic]rl.Vector3, 0, 6000)
	b.nrm = make([dynamic]rl.Vector3, 0, 6000)
	b.col = make([dynamic]rl.Color, 0, 6000)
	b.uv = make([dynamic]rl.Vector2, 0, 6000)
	b.idx = make([dynamic]u16, 0, 18000)
	b.bone = make([dynamic]u8, 0, 6000)
	return b
}

mb_init_prop :: proc(ao_height: f32) -> Mesh_Builder {
	b := mb_init(palette_for_team(false))
	b.is_prop = true
	b.ao_height = ao_height
	return b
}

mb_delete :: proc(b: ^Mesh_Builder) {
	delete(b.pos)
	delete(b.nrm)
	delete(b.col)
	delete(b.uv)
	delete(b.idx)
	delete(b.bone)
}

mb_vertex_count :: proc(b: ^Mesh_Builder) -> int {
	return len(b.pos)
}

mb_triangle_count :: proc(b: ^Mesh_Builder) -> int {
	return len(b.idx) / 3
}

mb_bone :: proc(b: ^Mesh_Builder, bone: Bone_Id) {
	b.bone_id = u8(bone)
}

// Temporary build-space transform (used to scale sub-assemblies in place).
mb_base :: proc(b: ^Mesh_Builder, xf: rl.Matrix) {
	b.base_xf = xf
}

// Baked vertical ambient occlusion keeps the feet heavy and the shoulders lit,
// the way pre-rendered sprites were darkened toward the ground.
@(private)
mb_height_ao :: proc(y, height: f32) -> f32 {
	denom := height > 0 ? height : f32(1.60)
	return 0.56 + 0.44 * clamp((y + 0.05) / denom, 0, 1)
}

@(private)
// Identity bind remap: model geometry and bone pivots now sit 1:1 in model space.
body_point :: proc(p: rl.Vector3) -> rl.Vector3 {
	return p
}

mb_emit :: proc(b: ^Mesh_Builder, p, n: rl.Vector3, kind: Mat_Kind, ao_scale: f32) -> u16 {
	index := u16(len(b.pos))
	if b.overflow || len(b.pos) >= MAX_MODEL_VERTS {
		b.overflow = true
		return 0
	}
	world := xf_point(b.base_xf, p)
	if !b.is_prop {
		world = body_point(world)
	}
	normal := xf_dir(b.base_xf, n)
	def := mb_material(b, kind)
	col := def.albedo
	ao := def.ao * ao_scale * mb_height_ao(world.y, b.ao_height)
	col.a = u8(clamp(ao, 0, 1) * 255)
	append(&b.pos, world)
	append(&b.nrm, v_norm(normal))
	append(&b.col, col)
	append(&b.uv, rl.Vector2{def.metal, def.glow})
	append(&b.bone, b.bone_id)
	return index
}

@(private)
mb_tri_raw :: proc(b: ^Mesh_Builder, a, c, d: u16) {
	if b.overflow || len(b.idx) + 3 > MAX_MODEL_INDICES {
		b.overflow = true
		return
	}
	append(&b.idx, a, c, d)
}

mb_tri :: proc(b: ^Mesh_Builder, p: [3]rl.Vector3, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	n := v_cross(p[1] - p[0], p[2] - p[0])
	i0 := mb_emit(b, p[0], n, kind, ao_scale)
	i1 := mb_emit(b, p[1], n, kind, ao_scale)
	i2 := mb_emit(b, p[2], n, kind, ao_scale)
	if b.overflow {
		return
	}
	mb_tri_raw(b, i0, i1, i2)
}

// Flat quad, corners in counter-clockwise order as seen from the front.
mb_quad :: proc(b: ^Mesh_Builder, p: [4]rl.Vector3, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	n := v_cross(p[1] - p[0], p[2] - p[0])
	i0 := mb_emit(b, p[0], n, kind, ao_scale)
	i1 := mb_emit(b, p[1], n, kind, ao_scale)
	i2 := mb_emit(b, p[2], n, kind, ao_scale)
	i3 := mb_emit(b, p[3], n, kind, ao_scale)
	if b.overflow {
		return
	}
	mb_tri_raw(b, i0, i1, i2)
	mb_tri_raw(b, i0, i2, i3)
}

mb_tri_n :: proc(b: ^Mesh_Builder, p: [3]rl.Vector3, n: rl.Vector3, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	i0 := mb_emit(b, p[0], n, kind, ao_scale)
	i1 := mb_emit(b, p[1], n, kind, ao_scale)
	i2 := mb_emit(b, p[2], n, kind, ao_scale)
	if b.overflow {
		return
	}
	mb_tri_raw(b, i0, i1, i2)
}

// Smooth quad: one explicit normal per corner.
mb_quad_n :: proc(b: ^Mesh_Builder, p: [4]rl.Vector3, n: [4]rl.Vector3, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	i0 := mb_emit(b, p[0], n[0], kind, ao_scale)
	i1 := mb_emit(b, p[1], n[1], kind, ao_scale)
	i2 := mb_emit(b, p[2], n[2], kind, ao_scale)
	i3 := mb_emit(b, p[3], n[3], kind, ao_scale)
	if b.overflow {
		return
	}
	mb_tri_raw(b, i0, i1, i2)
	mb_tri_raw(b, i0, i2, i3)
}

mb_box :: proc(b: ^Mesh_Builder, xf: rl.Matrix, size: rl.Vector3, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	h := size * 0.5
	local := [8]rl.Vector3{
		{-h.x, -h.y, h.z}, {h.x, -h.y, h.z}, {h.x, h.y, h.z}, {-h.x, h.y, h.z},
		{-h.x, -h.y, -h.z}, {h.x, -h.y, -h.z}, {h.x, h.y, -h.z}, {-h.x, h.y, -h.z},
	}
	faces := [6][4]int{
		{0, 1, 2, 3},
		{5, 4, 7, 6},
		{1, 5, 6, 2},
		{4, 0, 3, 7},
		{3, 2, 6, 7},
		{4, 5, 1, 0},
	}
	for face in faces {
		q: [4]rl.Vector3
		for corner, i in face {
			q[i] = xf_point(xf, local[corner])
		}
		mb_quad(b, q, kind, ao_scale)
	}
}

// Thin armour plate with a slight dome, used for lamellar rows and lames.
mb_plate :: proc(b: ^Mesh_Builder, xf: rl.Matrix, w, h, bulge: f32, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	ring := [8]rl.Vector2{
		{-0.5, -0.5}, {0.0, -0.5}, {0.5, -0.5}, {0.5, 0.0},
		{0.5, 0.5}, {0.0, 0.5}, {-0.5, 0.5}, {-0.5, 0.0},
	}
	center := xf_point(xf, rl.Vector3{0, 0, bulge})
	edge: [8]rl.Vector3
	for p, i in ring {
		edge[i] = xf_point(xf, rl.Vector3{p.x * w, p.y * h, 0})
	}
	// One normal for the whole face keeps the brims reading as beaten plate
	// instead of a fan of jagged triangles.
	front := xf_dir(xf, rl.Vector3{0, 0, 1})
	for i in 0..<8 {
		a := edge[i]
		c := edge[(i + 1) % 8]
		mb_tri_n(b, {a, c, center}, front, kind, ao_scale)
	}
	back := [4]rl.Vector3{
		xf_point(xf, rl.Vector3{-w * 0.5, -h * 0.5, -bulge}),
		xf_point(xf, rl.Vector3{w * 0.5, -h * 0.5, -bulge}),
		xf_point(xf, rl.Vector3{w * 0.5, h * 0.5, -bulge}),
		xf_point(xf, rl.Vector3{-w * 0.5, h * 0.5, -bulge}),
	}
	mb_quad(b, {back[3], back[2], back[1], back[0]}, kind, ao_scale)
}

// Faceted stud: six verts, eight triangles, reads as a rivet at sprite scale.
mb_rivet :: proc(b: ^Mesh_Builder, xf: rl.Matrix, size: f32, kind: Mat_Kind = .Brass, ao_scale: f32 = 1) {
	if b.overflow {
		return
	}
	p := [6]rl.Vector3{
		xf_point(xf, {size, 0, 0}), xf_point(xf, {-size, 0, 0}),
		xf_point(xf, {0, size, 0}), xf_point(xf, {0, -size, 0}),
		xf_point(xf, {0, 0, size}), xf_point(xf, {0, 0, -size}),
	}
	faces := [8][3]int{
		{0, 2, 4}, {4, 2, 1}, {1, 2, 5}, {5, 2, 0},
		{4, 3, 0}, {1, 3, 4}, {5, 3, 1}, {0, 3, 5},
	}
	for face in faces {
		mb_tri(b, {p[face[0]], p[face[1]], p[face[2]]}, kind, ao_scale)
	}
}

// Extruded star disc (shield boss, gear teeth, rosettes).
mb_star :: proc(b: ^Mesh_Builder, xf: rl.Matrix, outer, inner, depth: f32, points: int, kind: Mat_Kind, ao_scale: f32 = 1) {
	if b.overflow || points < 3 {
		return
	}
	count := points * 2
	front_center := xf_point(xf, rl.Vector3{0, depth, 0})
	back_center := xf_point(xf, rl.Vector3{0, -depth, 0})
	front: [32]rl.Vector3
	back: [32]rl.Vector3
	for i in 0..<count {
		angle := f32(i) * math.PI / f32(points)
		radius := inner
		if i % 2 == 0 {
			radius = outer
		}
		x := math.cos(angle) * radius
		z := math.sin(angle) * radius
		front[i] = xf_point(xf, rl.Vector3{x, depth, z})
		back[i] = xf_point(xf, rl.Vector3{x, -depth, z})
	}
	for i in 0..<count {
		j := (i + 1) % count
		mb_tri(b, {front[i], front_center, front[j]}, kind, ao_scale)
		mb_tri(b, {back[j], back_center, back[i]}, kind, ao_scale)
		mb_quad(b, {front[j], front[i], back[i], back[j]}, kind, ao_scale)
	}
}

// Axis helpers used by every part.
// Matrix multiply that reads as a transform compose.
xf_mul :: proc(a, b: rl.Matrix) -> rl.Matrix {
	return a * b
}

xf_at :: proc(x, y, z: f32) -> rl.Matrix {
	return rl.MatrixTranslate(x, y, z)
}

xf_trs :: proc(pos, euler: rl.Vector3) -> rl.Matrix {
	return xf_mul(rl.MatrixTranslate(pos.x, pos.y, pos.z), rl.MatrixRotateZYX(euler))
}

xf_point :: proc(m: rl.Matrix, p: rl.Vector3) -> rl.Vector3 {
	return rl.Vector3{
		m[0][0] * p.x + m[0][1] * p.y + m[0][2] * p.z + m[0][3],
		m[1][0] * p.x + m[1][1] * p.y + m[1][2] * p.z + m[1][3],
		m[2][0] * p.x + m[2][1] * p.y + m[2][2] * p.z + m[2][3],
	}
}

xf_dir :: proc(m: rl.Matrix, d: rl.Vector3) -> rl.Vector3 {
	return rl.Vector3{
		m[0][0] * d.x + m[0][1] * d.y + m[0][2] * d.z,
		m[1][0] * d.x + m[1][1] * d.y + m[1][2] * d.z,
		m[2][0] * d.x + m[2][1] * d.y + m[2][2] * d.z,
	}
}

v_dot :: proc(a, b: rl.Vector3) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

v_cross :: proc(a, b: rl.Vector3) -> rl.Vector3 {
	return rl.Vector3{a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}
}

v_norm :: proc(a: rl.Vector3) -> rl.Vector3 {
	length := math.sqrt(v_dot(a, a))
	if length < 1e-6 {
		return rl.Vector3{0, 1, 0}
	}
	return a / length
}
