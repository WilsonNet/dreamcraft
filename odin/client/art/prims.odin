// Curved primitives: lathes, ellipsoids, tori, swept tubes and blades.
//
// These emit smooth per-vertex normals so curved armour catches a broad
// painterly highlight instead of reading as faceted blocks.
package art

import "core:math"
import rl "../../gfx"

LATHE_SEGMENTS :: 12

@(private)
mb_ring :: proc(xf: rl.Matrix, radius: f32, y: f32, angle: f32) -> rl.Vector3 {
	return xf_point(xf, rl.Vector3{math.cos(angle) * radius, y, math.sin(angle) * radius})
}

@(private)
lathe_profile_normals :: proc(profile: []rl.Vector2) -> [24][2]f32 {
	normals: [24][2]f32
	for i in 0..<min(len(profile), 24) {
		prev := profile[max(i - 1, 0)]
		next := profile[min(i + 1, len(profile) - 1)]
		dr := next.x - prev.x
		dy := next.y - prev.y
		length := math.sqrt(dr * dr + dy * dy)
		normals[i] = length < 1e-6 ? {0, 1} : {dy / length, -dr / length}
	}
	return normals
}

// Surface of revolution around local +Y. Profile points are (radius, height).
mb_lathe :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	profile: []rl.Vector2,
	segments: int,
	kind: Mat_Kind,
	cap_bottom := false,
	cap_top := false,
	ao_scale: f32 = 1,
) {
	if b.overflow || len(profile) < 2 || segments < 3 {
		return
	}
	seg := segments
	normals := lathe_profile_normals(profile)
	for row in 0..<len(profile) - 1 {
		for s in 0..<seg {
			a0 := f32(s) * math.TAU / f32(seg)
			a1 := f32(s + 1) * math.TAU / f32(seg)
			p: [4]rl.Vector3 = {
				mb_ring(xf, profile[row].x, profile[row].y, a0),
				mb_ring(xf, profile[row + 1].x, profile[row + 1].y, a0),
				mb_ring(xf, profile[row + 1].x, profile[row + 1].y, a1),
				mb_ring(xf, profile[row].x, profile[row].y, a1),
			}
			n: [4]rl.Vector3 = {
				xf_dir(xf, rl.Vector3{math.cos(a0) * normals[row].x, normals[row].y, math.sin(a0) * normals[row].x}),
				xf_dir(xf, rl.Vector3{math.cos(a0) * normals[row + 1].x, normals[row + 1].y, math.sin(a0) * normals[row + 1].x}),
				xf_dir(xf, rl.Vector3{math.cos(a1) * normals[row + 1].x, normals[row + 1].y, math.sin(a1) * normals[row + 1].x}),
				xf_dir(xf, rl.Vector3{math.cos(a1) * normals[row].x, normals[row].y, math.sin(a1) * normals[row].x}),
			}
			mb_quad_n(b, p, n, kind, ao_scale)
		}
	}
	if cap_bottom && profile[0].x > 1e-4 {
		mb_cap(b, xf, profile[0].x, profile[0].y, seg, kind, false, ao_scale)
	}
	if cap_top && profile[len(profile) - 1].x > 1e-4 {
		mb_cap(b, xf, profile[len(profile) - 1].x, profile[len(profile) - 1].y, seg, kind, true, ao_scale)
	}
}

@(private)
mb_cap :: proc(b: ^Mesh_Builder, xf: rl.Matrix, radius, y: f32, segments: int, kind: Mat_Kind, up: bool, ao_scale: f32) {
	n := rl.Vector3{0, 1, 0}
	if !up {
		n = rl.Vector3{0, -1, 0}
	}
	center := xf_point(xf, rl.Vector3{0, y, 0})
	for s in 0..<segments {
		a0 := f32(s) * math.TAU / f32(segments)
		a1 := f32(s + 1) * math.TAU / f32(segments)
		p0 := mb_ring(xf, radius, y, a0)
		p1 := mb_ring(xf, radius, y, a1)
		if up {
			mb_tri(b, {center, p1, p0}, kind, ao_scale)
		} else {
			mb_tri(b, {center, p0, p1}, kind, ao_scale)
		}
	}
}

mb_cylinder :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	r0, r1, height: f32,
	segments: int,
	kind: Mat_Kind,
	caps := true,
	ao_scale: f32 = 1,
) {
	profile := [2]rl.Vector2{{r0, 0}, {r1, height}}
	mb_lathe(b, xf, profile[:], segments, kind, caps && r0 > 1e-4, caps && r1 > 1e-4, ao_scale)
}

mb_cone :: proc(b: ^Mesh_Builder, xf: rl.Matrix, radius, height: f32, segments: int, kind: Mat_Kind, ao_scale: f32 = 1) {
	profile := [2]rl.Vector2{{radius, 0}, {0, height}}
	mb_lathe(b, xf, profile[:], segments, kind, true, false, ao_scale)
}

mb_ellipsoid :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	radii: rl.Vector3,
	segments: int,
	rings: int,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || segments < 3 || rings < 2 {
		return
	}
	point :: proc(xf: rl.Matrix, radii: rl.Vector3, u, v: f32) -> rl.Vector3 {
		cosv := math.cos(v)
		return xf_point(xf, rl.Vector3{
			radii.x * cosv * math.cos(u),
			radii.y * math.sin(v),
			radii.z * cosv * math.sin(u),
		})
	}
	normal :: proc(xf: rl.Matrix, radii: rl.Vector3, u, v: f32) -> rl.Vector3 {
		cosv := math.cos(v)
		return xf_dir(xf, v_norm(rl.Vector3{
			cosv * math.cos(u) / max(radii.x, 1e-4),
			math.sin(v) / max(radii.y, 1e-4),
			cosv * math.sin(u) / max(radii.z, 1e-4),
		}))
	}
	for r in 0..<rings {
		v0 := -math.PI * 0.5 + f32(r) * math.PI / f32(rings)
		v1 := -math.PI * 0.5 + f32(r + 1) * math.PI / f32(rings)
		for s in 0..<segments {
			u0 := f32(s) * math.TAU / f32(segments)
			u1 := f32(s + 1) * math.TAU / f32(segments)
			p: [4]rl.Vector3
			n: [4]rl.Vector3
			p[0] = point(xf, radii, u0, v0)
			p[1] = point(xf, radii, u0, v1)
			p[2] = point(xf, radii, u1, v1)
			p[3] = point(xf, radii, u1, v0)
			n[0] = normal(xf, radii, u0, v0)
			n[1] = normal(xf, radii, u0, v1)
			n[2] = normal(xf, radii, u1, v1)
			n[3] = normal(xf, radii, u1, v0)
			mb_quad_n(b, p, n, kind, ao_scale)
		}
	}
}

mb_torus :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	ring_radius, tube_radius: f32,
	segments, tube_segments: int,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || segments < 3 || tube_segments < 3 {
		return
	}
	for s in 0..<segments {
		u0 := f32(s) * math.TAU / f32(segments)
		u1 := f32(s + 1) * math.TAU / f32(segments)
		for t in 0..<tube_segments {
			v0 := f32(t) * math.TAU / f32(tube_segments)
			v1 := f32(t + 1) * math.TAU / f32(tube_segments)
			p: [4]rl.Vector3
			n: [4]rl.Vector3
			params := [4][2]f32{{u0, v0}, {u0, v1}, {u1, v1}, {u1, v0}}
			for param, i in params {
				cosu := math.cos(param[0])
				sinu := math.sin(param[0])
				cosv := math.cos(param[1])
				sinv := math.sin(param[1])
				radius := ring_radius + tube_radius * cosv
				p[i] = xf_point(xf, rl.Vector3{radius * cosu, tube_radius * sinv, radius * sinu})
				n[i] = xf_dir(xf, rl.Vector3{cosv * cosu, sinv, cosv * sinu})
			}
			mb_quad_n(b, p, n, kind, ao_scale)
		}
	}
}

// Swept tube through a polyline, used for cables, quillons and trim wire.
mb_tube :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	points: []rl.Vector3,
	radius: f32,
	sides: int,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || len(points) < 2 || sides < 3 {
		return
	}
	up := rl.Vector3{0, 1, 0}
	prev_right := rl.Vector3{1, 0, 0}
	for i in 0..<len(points) - 1 {
		p0 := points[i]
		p1 := points[i + 1]
		tangent := v_norm(p1 - p0)
		if abs(v_dot(tangent, up)) > 0.92 {
			up = rl.Vector3{1, 0, 0}
		}
		right := v_norm(v_cross(tangent, up))
		up = v_norm(v_cross(right, tangent))
		if i > 0 {
			right = prev_right
		}
		prev_right = right
		for s in 0..<sides {
			a0 := f32(s) * math.TAU / f32(sides)
			a1 := f32(s + 1) * math.TAU / f32(sides)
			p: [4]rl.Vector3
			n: [4]rl.Vector3
			p[0] = xf_point(xf, p0 + (right * math.cos(a0) + up * math.sin(a0)) * radius)
			p[1] = xf_point(xf, p1 + (right * math.cos(a0) + up * math.sin(a0)) * radius)
			p[2] = xf_point(xf, p1 + (right * math.cos(a1) + up * math.sin(a1)) * radius)
			p[3] = xf_point(xf, p0 + (right * math.cos(a1) + up * math.sin(a1)) * radius)
			n[0] = xf_dir(xf, right * math.cos(a0) + up * math.sin(a0))
			n[1] = n[0]
			n[2] = xf_dir(xf, right * math.cos(a1) + up * math.sin(a1))
			n[3] = n[2]
			mb_quad_n(b, p, n, kind, ao_scale)
		}
	}
}

// Curved single-edged blade. Points are (x, y) in the local blade plane and
// width tapers along the sweep; the cross-section is a flat lens with a spine.
mb_blade :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	spine: []rl.Vector2,
	width: []f32,
	thickness: f32,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || len(spine) < 2 || len(width) != len(spine) {
		return
	}
	// Each station: spine point, edge point, front ridge and back ridge.
	for i in 0..<len(spine) - 1 {
		j := i + 1
		edge0 := rl.Vector2{spine[i].x + width[i], spine[i].y}
		edge1 := rl.Vector2{spine[j].x + width[j], spine[j].y}
		mid0 := rl.Vector2{(spine[i].x + edge0.x) * 0.5, spine[i].y}
		mid1 := rl.Vector2{(spine[j].x + edge1.x) * 0.5, spine[j].y}
		s0 := xf_point(xf, rl.Vector3{spine[i].x, spine[i].y, 0})
		s1 := xf_point(xf, rl.Vector3{spine[j].x, spine[j].y, 0})
		m0 := xf_point(xf, rl.Vector3{mid0.x, mid0.y, thickness})
		m1 := xf_point(xf, rl.Vector3{mid1.x, mid1.y, thickness})
		e0 := xf_point(xf, rl.Vector3{edge0.x, edge0.y, 0})
		e1 := xf_point(xf, rl.Vector3{edge1.x, edge1.y, 0})
		m0b := xf_point(xf, rl.Vector3{mid0.x, mid0.y, -thickness})
		m1b := xf_point(xf, rl.Vector3{mid1.x, mid1.y, -thickness})
		mb_quad(b, {s0, s1, m1, m0}, kind, ao_scale)
		mb_quad(b, {m0, m1, e1, e0}, kind, ao_scale)
		mb_quad(b, {m0b, e0, e1, m1b}, kind, ao_scale)
		mb_quad(b, {s1, s0, m0b, m1b}, kind, ao_scale)
	}
}
