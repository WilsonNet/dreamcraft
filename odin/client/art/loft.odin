// Sculpted loft, curved cloth, dome-projected star, and capsule primitives.
//
// Builds smooth organic forms (cuirass, tailored trousers, boots, tree canopies,
// draped cloth) with continuous normals so Toriyama silhouettes read cleanly.
package art

import "core:math"
import rl "vendor:raylib"

Loft_Ring :: struct {
	center: rl.Vector3,
	rx:     f32,
	rz:     f32,
}

Loft_Z_Ring :: struct {
	center: rl.Vector3,
	rx:     f32,
	ry:     f32,
}

@(private)
loft_point :: proc(xf: rl.Matrix, ring: Loft_Ring, angle: f32) -> rl.Vector3 {
	return xf_point(xf, rl.Vector3{
		ring.center.x + math.cos(angle) * ring.rx,
		ring.center.y,
		ring.center.z + math.sin(angle) * ring.rz,
	})
}

@(private)
loft_z_point :: proc(xf: rl.Matrix, ring: Loft_Z_Ring, angle, min_y: f32, clamp_y: bool) -> rl.Vector3 {
	y := ring.center.y + math.sin(angle) * ring.ry
	if clamp_y && y < min_y {
		y = min_y
	}
	return xf_point(xf, rl.Vector3{
		ring.center.x + math.cos(angle) * ring.rx,
		y,
		ring.center.z,
	})
}

// Surface lofted along stacked XZ-ellipse rings (normally ascending in Y).
mb_loft :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	rings: []Loft_Ring,
	segments: int,
	kind: Mat_Kind,
	cap_bottom := false,
	cap_top := false,
	ao_scale: f32 = 1,
) {
	if b.overflow || len(rings) < 2 || segments < 3 {
		return
	}
	for row in 0..<len(rings) - 1 {
		emit_loft_band(b, xf, rings, row, segments, kind, ao_scale)
	}
	if cap_bottom && rings[0].rx > 1e-4 && rings[0].rz > 1e-4 {
		emit_loft_cap(b, xf, rings[0], segments, kind, false, ao_scale)
	}
	last := rings[len(rings) - 1]
	if cap_top && last.rx > 1e-4 && last.rz > 1e-4 {
		emit_loft_cap(b, xf, last, segments, kind, true, ao_scale)
	}
}

@(private)
emit_loft_band :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	rings: []Loft_Ring,
	row, segments: int,
	kind: Mat_Kind,
	ao_scale: f32,
) {
	for s in 0..<segments {
		a0 := f32(s) * math.TAU / f32(segments)
		a1 := f32(s + 1) * math.TAU / f32(segments)
		p := [4]rl.Vector3{
			loft_point(xf, rings[row], a0),
			loft_point(xf, rings[row + 1], a0),
			loft_point(xf, rings[row + 1], a1),
			loft_point(xf, rings[row], a1),
		}
		n := [4]rl.Vector3{
			loft_normal(xf, rings, row, a0),
			loft_normal(xf, rings, row + 1, a0),
			loft_normal(xf, rings, row + 1, a1),
			loft_normal(xf, rings, row, a1),
		}
		mb_quad_n(b, p, n, kind, ao_scale)
	}
}

@(private)
loft_normal :: proc(xf: rl.Matrix, rings: []Loft_Ring, row: int, angle: f32) -> rl.Vector3 {
	prev := max(row - 1, 0)
	next := min(row + 1, len(rings) - 1)
	dp := loft_point(rl.Matrix(1), rings[next], angle) - loft_point(rl.Matrix(1), rings[prev], angle)
	r := rings[row]
	tang := rl.Vector3{-math.sin(angle) * max(r.rx, 1e-4), 0, math.cos(angle) * max(r.rz, 1e-4)}
	n := v_cross(dp, tang)
	if v_dot(n, n) < 1e-10 {
		n = rl.Vector3{math.cos(angle), 0, math.sin(angle)}
	}
	return v_norm(xf_dir(xf, n))
}

@(private)
emit_loft_cap :: proc(b: ^Mesh_Builder, xf: rl.Matrix, ring: Loft_Ring, segments: int, kind: Mat_Kind, up: bool, ao_scale: f32) {
	center := xf_point(xf, ring.center)
	for s in 0..<segments {
		a0 := f32(s) * math.TAU / f32(segments)
		a1 := f32(s + 1) * math.TAU / f32(segments)
		p0 := loft_point(xf, ring, a0)
		p1 := loft_point(xf, ring, a1)
		if up {
			mb_tri(b, {center, p1, p0}, kind, ao_scale)
		} else {
			mb_tri(b, {center, p0, p1}, kind, ao_scale)
		}
	}
}

// Surface lofted along XY-ellipse rings along +Z, with optional flat-sole Y clamp.
mb_loft_z :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	rings: []Loft_Z_Ring,
	segments: int,
	kind: Mat_Kind,
	clamp_y := false,
	min_y: f32 = 0,
	cap_back := false,
	cap_front := false,
	ao_scale: f32 = 1,
) {
	if b.overflow || len(rings) < 2 || segments < 3 {
		return
	}
	for row in 0..<len(rings) - 1 {
		emit_loft_z_band(b, xf, rings, row, segments, kind, clamp_y, min_y, ao_scale)
	}
	if cap_back && rings[0].rx > 1e-4 && rings[0].ry > 1e-4 {
		emit_loft_z_cap(b, xf, rings[0], segments, kind, clamp_y, min_y, false, ao_scale)
	}
	last := rings[len(rings) - 1]
	if cap_front && last.rx > 1e-4 && last.ry > 1e-4 {
		emit_loft_z_cap(b, xf, last, segments, kind, clamp_y, min_y, true, ao_scale)
	}
}

@(private)
emit_loft_z_band :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	rings: []Loft_Z_Ring,
	row, segments: int,
	kind: Mat_Kind,
	clamp_y: bool,
	min_y, ao_scale: f32,
) {
	for s in 0..<segments {
		a0 := f32(s) * math.TAU / f32(segments)
		a1 := f32(s + 1) * math.TAU / f32(segments)
		p := [4]rl.Vector3{
			loft_z_point(xf, rings[row], a0, min_y, clamp_y),
			loft_z_point(xf, rings[row], a1, min_y, clamp_y),
			loft_z_point(xf, rings[row + 1], a1, min_y, clamp_y),
			loft_z_point(xf, rings[row + 1], a0, min_y, clamp_y),
		}
		n := [4]rl.Vector3{
			loft_z_normal(xf, rings, row, a0, clamp_y, min_y),
			loft_z_normal(xf, rings, row, a1, clamp_y, min_y),
			loft_z_normal(xf, rings, row + 1, a1, clamp_y, min_y),
			loft_z_normal(xf, rings, row + 1, a0, clamp_y, min_y),
		}
		mb_quad_n(b, p, n, kind, ao_scale)
	}
}

@(private)
loft_z_normal :: proc(xf: rl.Matrix, rings: []Loft_Z_Ring, row: int, angle: f32, clamp_y: bool, min_y: f32) -> rl.Vector3 {
	prev := max(row - 1, 0)
	next := min(row + 1, len(rings) - 1)
	dp := loft_z_point(rl.Matrix(1), rings[next], angle, min_y, clamp_y) - loft_z_point(rl.Matrix(1), rings[prev], angle, min_y, clamp_y)
	r := rings[row]
	tang := rl.Vector3{-math.sin(angle) * max(r.rx, 1e-4), math.cos(angle) * max(r.ry, 1e-4), 0}
	if clamp_y && r.center.y + math.sin(angle) * r.ry <= min_y + 1e-4 {
		return v_norm(xf_dir(xf, rl.Vector3{0, -1, 0}))
	}
	n := v_cross(tang, dp)
	if v_dot(n, n) < 1e-10 {
		n = rl.Vector3{math.cos(angle), math.sin(angle), 0}
	}
	return v_norm(xf_dir(xf, n))
}

@(private)
emit_loft_z_cap :: proc(b: ^Mesh_Builder, xf: rl.Matrix, ring: Loft_Z_Ring, segments: int, kind: Mat_Kind, clamp_y: bool, min_y: f32, front: bool, ao_scale: f32) {
	center_y := ring.center.y
	if clamp_y && center_y < min_y {
		center_y = min_y
	}
	center := xf_point(xf, rl.Vector3{ring.center.x, center_y, ring.center.z})
	for s in 0..<segments {
		a0 := f32(s) * math.TAU / f32(segments)
		a1 := f32(s + 1) * math.TAU / f32(segments)
		p0 := loft_z_point(xf, ring, a0, min_y, clamp_y)
		p1 := loft_z_point(xf, ring, a1, min_y, clamp_y)
		if front {
			mb_tri(b, {center, p0, p1}, kind, ao_scale)
		} else {
			mb_tri(b, {center, p1, p0}, kind, ao_scale)
		}
	}
}

// Double-sided curved cloth sheet between top and bottom row specs.
// Center bows toward -Z when curve < 0 (rear cape) or +Z when curve > 0 (front sash).
mb_cloth_sheet :: proc(
	b: ^Mesh_Builder,
	y_top, y_bot, z_top, z_bot, half_top, half_bot, curve, thick: f32,
	cols, rows: int,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || cols < 2 || rows < 1 || cols > 9 || rows > 6 {
		return
	}
	pts: [7][10]rl.Vector3
	for r in 0..=rows {
		v := f32(r) / f32(rows)
		y := math.lerp(y_top, y_bot, v)
		z := math.lerp(z_top, z_bot, v)
		hw := math.lerp(half_top, half_bot, v)
		for c in 0..=cols {
			u := -1 + 2 * f32(c) / f32(cols)
			bow := curve * (1 - u * u)
			pts[r][c] = rl.Vector3{u * hw, y, z + bow}
		}
	}
	off := rl.Vector3{0, 0, thick}
	for r in 0..<rows {
		for c in 0..<cols {
			p00, p10 := pts[r][c], pts[r][c + 1]
			p11, p01 := pts[r + 1][c + 1], pts[r + 1][c]
			mb_quad(b, {p00 + off, p10 + off, p11 + off, p01 + off}, kind, ao_scale)
			mb_quad(b, {p10 - off, p00 - off, p01 - off, p11 - off}, kind, ao_scale * 0.94)
		}
	}
}

// Star medallion whose vertices hug a parabolic shield dome profile y(r) = h*(1-(r/R)^2).
mb_dome_star :: proc(
	b: ^Mesh_Builder,
	xf: rl.Matrix,
	outer, inner, dome_h, dome_r, lift: f32,
	points: int,
	kind: Mat_Kind,
	ao_scale: f32 = 1,
) {
	if b.overflow || points < 3 || points > 12 {
		return
	}
	count := points * 2
	top: [24]rl.Vector3
	bot: [24]rl.Vector3
	center := xf_point(xf, rl.Vector3{0, dome_h + lift, 0})
	for i in 0..<count {
		ang := f32(i) * math.PI / f32(points)
		r := inner
		if i % 2 == 0 {
			r = outer
		}
		t := clamp(r / max(dome_r, 1e-4), 0, 1)
		y := dome_h * (1 - t * t)
		x := math.cos(ang) * r
		z := math.sin(ang) * r
		top[i] = xf_point(xf, rl.Vector3{x, y + lift, z})
		bot[i] = xf_point(xf, rl.Vector3{x, y - 0.002, z})
	}
	for i in 0..<count {
		j := (i + 1) % count
		mb_tri(b, {top[i], center, top[j]}, kind, ao_scale)
		mb_quad(b, {top[j], top[i], bot[i], bot[j]}, kind, ao_scale)
	}
}

// Smooth capsule between p0 and p1 with end caps.
mb_capsule :: proc(b: ^Mesh_Builder, p0, p1: rl.Vector3, r0, r1: f32, segs: int, kind: Mat_Kind, ao_scale: f32 = 1) {
	d := p1 - p0
	length := math.sqrt(v_dot(d, d))
	if length < 1e-5 {
		mb_ellipsoid(b, xf_at(p0.x, p0.y, p0.z), {r0, r0, r0}, segs, 4, kind, ao_scale)
		return
	}
	dir := d / length
	up := rl.Vector3{0, 1, 0}
	if abs(v_dot(dir, up)) > 0.94 {
		up = rl.Vector3{1, 0, 0}
	}
	right := v_norm(v_cross(up, dir))
	fwd := v_norm(v_cross(dir, right))
	rot := rl.Matrix{
		right.x, dir.x, fwd.x, p0.x,
		right.y, dir.y, fwd.y, p0.y,
		right.z, dir.z, fwd.z, p0.z,
		0, 0, 0, 1,
	}
	rings := [4]Loft_Ring{
		{{0, -r0 * 0.5, 0}, r0 * 0.45, r0 * 0.45},
		{{0, 0, 0}, r0, r0},
		{{0, length, 0}, r1, r1},
		{{0, length + r1 * 0.5, 0}, r1 * 0.45, r1 * 0.45},
	}
	mb_loft(b, rot, rings[:], segs, kind, true, true, ao_scale)
}
