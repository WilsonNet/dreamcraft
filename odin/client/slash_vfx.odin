// Curved double-crescent slash VFX for melee attacks.
//
// Preallocates one dynamic ribbon mesh (76 vertices, 72 triangles) and updates
// its world-space positions and vertex colors for each unit inside the active
// cleave window t in [0.28, 0.68].
package main

import "core:c"
import "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import g "../game"
import art "./art"

SLASH_SEGS :: 18
SLASH_ARC_VERTS :: (SLASH_SEGS + 1) * 2
SLASH_VERTS :: SLASH_ARC_VERTS * 2
SLASH_TRIS :: SLASH_SEGS * 2 * 2
SLASH_INDICES :: SLASH_TRIS * 3

Slash_Vfx :: struct {
	ready:    bool,
	mesh:     rl.Mesh,
	material: rl.Material,
	pos:      []rl.Vector3,
	col:      []rl.Color,
}

init_slash_vfx :: proc() {
	unload_slash_vfx()
	pos := alloc_mesh_slice(rl.Vector3, SLASH_VERTS)
	col := alloc_mesh_slice(rl.Color, SLASH_VERTS)
	uv := alloc_mesh_slice(rl.Vector2, SLASH_VERTS)
	idx := alloc_mesh_slice(u16, SLASH_INDICES)
	if pos == nil || col == nil || uv == nil || idx == nil {
		if pos != nil { rl.MemFree(raw_data(pos)) }
		if col != nil { rl.MemFree(raw_data(col)) }
		if uv != nil { rl.MemFree(raw_data(uv)) }
		if idx != nil { rl.MemFree(raw_data(idx)) }
		return
	}
	fill_slash_indices(idx)
	mesh := rl.Mesh{
		vertexCount   = SLASH_VERTS,
		triangleCount = SLASH_TRIS,
		vertices      = cast([^]f32)raw_data(pos),
		colors        = cast([^]u8)raw_data(col),
		texcoords     = cast([^]f32)raw_data(uv),
		indices       = raw_data(idx),
	}
	rl.UploadMesh(&mesh, true)
	app.slash = Slash_Vfx{
		ready    = true,
		mesh     = mesh,
		material = rl.LoadMaterialDefault(),
		pos      = pos,
		col      = col,
	}
}

@(private)
fill_slash_indices :: proc(idx: []u16) {
	w := 0
	for arc in 0..<2 {
		base := u16(arc * SLASH_ARC_VERTS)
		for s in 0..<SLASH_SEGS {
			v0 := base + u16(s * 2)
			v1 := v0 + 1
			v2 := v0 + 2
			v3 := v0 + 3
			idx[w] = v0; idx[w + 1] = v1; idx[w + 2] = v3
			idx[w + 3] = v0; idx[w + 4] = v3; idx[w + 5] = v2
			w += 6
		}
	}
}

unload_slash_vfx :: proc() {
	if app.slash.ready {
		rl.UnloadMesh(app.slash.mesh)
		app.slash.material.shader = {}
		rl.UnloadMaterial(app.slash.material)
	}
	app.slash = {}
}

draw_slashes_3d :: proc() {
	if !app.slash.ready {
		return
	}
	units := &app.game.units
	active := false
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		visual := &app.visuals[i]
		if visual.attack <= 0 {
			continue
		}
		t := 1.0 - visual.attack / art.ANIM_ATTACK_SECONDS
		if t < 0.28 || t > 0.68 {
			continue
		}
		if !active {
			rlgl.DisableBackfaceCulling()
			rlgl.DisableDepthMask()
			rl.BeginBlendMode(.ALPHA)
			active = true
		}
		draw_unit_slash(unit_ground(i), visual.angle, (t - 0.28) / 0.40)
	}
	if active {
		rl.EndBlendMode()
		rlgl.EnableDepthMask()
		rlgl.EnableBackfaceCulling()
	}
}

@(private)
draw_unit_slash :: proc(ground: rl.Vector3, angle_deg, u: f32) {
	p := clamp(u, 0, 1)
	fade := math.sin(p * math.PI)
	ease := 1.0 - (1.0 - p) * (1.0 - p)
	head := math.lerp(f32(1.05), f32(-1.35), ease)
	span := math.lerp(f32(1.85), f32(0.85), p)
	rad := angle_deg * math.PI / 180.0
	center := ground + rl.Vector3{0, 0.88, 0}
	build_slash_arc(0, center, rad, head, span, 1.04, 0.19, 0.00, fade, {255, 206, 118, 255}, {255, 248, 224, 255})
	build_slash_arc(1, center, rad, head + 0.18, span * 0.86, 0.84, 0.13, 0.08, fade * 0.82, {255, 130, 48, 255}, {255, 182, 82, 255})
	s := &app.slash
	rl.UpdateMeshBuffer(s.mesh, 0, raw_data(s.pos), c.int(len(s.pos) * size_of(rl.Vector3)), 0)
	rl.UpdateMeshBuffer(s.mesh, 3, raw_data(s.col), c.int(len(s.col) * size_of(rl.Color)), 0)
	rl.DrawMesh(s.mesh, s.material, rl.Matrix(1))
}

@(private)
build_slash_arc :: proc(
	arc: int,
	center: rl.Vector3,
	unit_rad, head, span, radius, max_half_w, y_off, fade: f32,
	inner_col, outer_col: rl.Color,
) {
	fwd := rl.Vector3{math.sin(unit_rad), 0, math.cos(unit_rad)}
	side := rl.Vector3{math.cos(unit_rad), 0, -math.sin(unit_rad)}
	tail := head + span
	base := arc * SLASH_ARC_VERTS
	for seg in 0..=SLASH_SEGS {
		frac := f32(seg) / f32(SLASH_SEGS)
		ang := math.lerp(tail, head, frac)
		taper := math.sin(frac * math.PI) * (0.45 + 0.75 * frac)
		hw := max_half_w * taper
		dir := side * math.sin(ang) + fwd * math.cos(ang)
		tilt_y := y_off + ang * 0.22
		v := base + seg * 2
		app.slash.pos[v] = center + dir * (radius - hw * 0.45) + rl.Vector3{0, tilt_y + 0.03, 0}
		app.slash.pos[v + 1] = center + dir * (radius + hw * 0.95) + rl.Vector3{0, tilt_y, 0}
		alpha := clamp(fade * (0.18 + 0.82 * frac), 0, 1)
		ic := inner_col
		oc := outer_col
		ic.a = u8(f32(inner_col.a) * alpha * 0.45)
		oc.a = u8(f32(outer_col.a) * alpha)
		app.slash.col[v] = ic
		app.slash.col[v + 1] = oc
	}
}
