// Unit visuals: one procedurally built Mamluk mesh per unit, skinned on the
// CPU every frame. Replaces the old Blender/GLB pipeline entirely.
package main

import "core:c"
import "core:math"
import "core:mem"
import rl "vendor:raylib"
import g "../game"

WARRIOR_SCALE :: f32(0.94)

Unit_Visual :: struct {
	handle:        g.Unit_Handle,
	angle:         f32,
	clock:         f32,
	attack:        f32,
	prev_cooldown: u16,
}

Unit_Model :: struct {
	loaded:   bool,
	enemy:    bool,
	mesh:     rl.Mesh,
	material: rl.Material,
	rest_pos: []rl.Vector3,
	rest_nrm: []rl.Vector3,
	bones:    []u8,
	pos:      []rl.Vector3,
	nrm:      []rl.Vector3,
	tri_count: int,
}

init_warrior_assets :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if units.alive[i] {
			ensure_unit_model(i)
		}
	}
}

unload_warrior_assets :: proc() {
	for &unit_model in app.models {
		unload_unit_model(&unit_model)
	}
}

reset_warrior_visuals :: proc() {
	for &visual in app.visuals {
		visual = {}
	}
	app.last_tick = 0
}

// Mesh arrays owned by raylib so UnloadMesh can release them safely.
@(private)
mesh_array :: proc($T: typeid, count: int) -> []T {
	if count <= 0 {
		return nil
	}
	ptr := rl.MemAlloc(c.uint(count * size_of(T)))
	if ptr == nil {
		return nil
	}
	return mem.slice_ptr(cast(^T)ptr, count)
}

@(private)
unload_unit_model :: proc(m: ^Unit_Model) {
	if m.loaded {
		rl.UnloadMesh(m.mesh)
		// Every unit shares one shader; UnloadMaterial would free it.
		m.material.shader = {}
		rl.UnloadMaterial(m.material)
	}
	delete(m.rest_pos)
	delete(m.rest_nrm)
	delete(m.bones)
	m^ = {}
}

ensure_unit_model :: proc(index: int) {
	m := &app.models[index]
	enemy := app.game.units.team[index] == .Enemy
	if m.loaded && m.enemy == enemy {
		return
	}
	unload_unit_model(m)
	m^ = build_unit_model(enemy)
}

// Builds and uploads one model. The caller owns the GPU buffers.
build_unit_model :: proc(enemy: bool) -> Unit_Model {
	m: Unit_Model
	b := build_mamluk(enemy)
	defer mb_delete(&b)
	if b.overflow || len(b.pos) == 0 || len(b.idx) == 0 {
		return m
	}
	upload_builder(&b, &m, enemy)
	return m
}

// Copies the builder into raylib-owned buffers and uploads the mesh once.
@(private)
upload_builder :: proc(b: ^Mesh_Builder, m: ^Unit_Model, enemy: bool) {
	count := len(b.pos)
	triangles := len(b.idx)
	m.rest_pos = make([]rl.Vector3, count)
	m.rest_nrm = make([]rl.Vector3, count)
	m.bones = make([]u8, count)
	m.pos = mesh_array(rl.Vector3, count)
	m.nrm = mesh_array(rl.Vector3, count)
	colors := mesh_array(rl.Color, count)
	uvs := mesh_array(rl.Vector2, count)
	indices := mesh_array(u16, triangles)
	if m.pos == nil || m.nrm == nil || colors == nil || uvs == nil || indices == nil {
		return
	}
	copy(m.rest_pos, b.pos[:])
	copy(m.rest_nrm, b.nrm[:])
	copy(m.bones, b.bone[:])
	copy(m.pos, b.pos[:])
	copy(m.nrm, b.nrm[:])
	copy(colors, b.col[:])
	copy(uvs, b.uv[:])
	copy(indices, b.idx[:])

	m.mesh.vertexCount = i32(count)
	m.mesh.triangleCount = i32(triangles / 3)
	m.mesh.vertices = cast([^]f32)&m.pos[0]
	m.mesh.normals = cast([^]f32)&m.nrm[0]
	m.mesh.colors = cast([^]u8)&colors[0]
	m.mesh.texcoords = cast([^]f32)&uvs[0]
	m.mesh.indices = &indices[0]
	rl.UploadMesh(&m.mesh, true)

	m.material = rl.LoadMaterialDefault()
	if app.unit_shader.ready {
		m.material.shader = app.unit_shader.shader
	}
	m.tri_count = triangles / 3
	m.enemy = enemy
	m.loaded = true
}

update_warrior_visuals :: proc(dt: f32) {
	units := &app.game.units
	if app.game.tick < app.last_tick {
		reset_warrior_visuals()
	}
	app.last_tick = app.game.tick
	for i in 0..<g.MAX_UNITS {
		visual := &app.visuals[i]
		if !units.alive[i] {
			visual^ = {}
			continue
		}
		ensure_unit_model(i)
		handle := g.unit_handle(units, i)
		if visual.handle != handle {
			visual^ = Unit_Visual {
				handle        = handle,
				angle         = visual.angle,
				prev_cooldown = units.cooldown[i],
			}
		}
		visual.clock += dt
		if units.cooldown[i] > visual.prev_cooldown {
			visual.attack = ANIM_ATTACK_SECONDS
		}
		visual.prev_cooldown = units.cooldown[i]
		if visual.attack > 0 {
			visual.attack = max(0, visual.attack - dt)
			if target, ok := g.unit_index(units, units.attack_target[i]); ok {
				visual.angle = angle_toward(units.position[target], units.position[i], visual.angle)
			}
		} else if g.unit_has_path(units, i) {
			visual.angle = path_angle(units, i, visual.angle)
		}
	}
}

path_angle :: proc(units: ^g.Units, index: int, fallback: f32) -> f32 {
	for p in int(units.path_index[index])..<int(units.path_len[index]) {
		cell := g.cell_position(int(units.path[index][p]))
		if g.cells_equal(cell, units.position[index]) {
			continue
		}
		return angle_toward(cell, units.position[index], fallback)
	}
	return fallback
}

// Models face +Z at zero degrees; grid +Y maps to +Z and grid +X to +X.
angle_toward :: proc(target, origin: g.Grid_Pos, fallback: f32) -> f32 {
	dx := target.x - origin.x
	dy := target.y - origin.y
	if dx == 0 && dy == 0 {
		return fallback
	}
	return math.atan2(f32(dx), f32(dy)) * 180.0 / math.PI
}

@(private)
unit_pose :: proc(index: int) -> Pose {
	pose: Pose
	visual := &app.visuals[index]
	offset := f32(index) * 0.37
	if visual.attack > 0 {
		t := 1 - visual.attack / ANIM_ATTACK_SECONDS
		pose_idle(math_mod(visual.clock + offset, ANIM_IDLE_SECONDS) / ANIM_IDLE_SECONDS, &pose)
		pose_attack(t, &pose)
		pose_secondary(visual.clock * 0.9, 0.20, &pose)
		return pose
	}
	if g.unit_has_path(&app.game.units, index) {
		phase := math_mod(visual.clock + offset, ANIM_WALK_SECONDS) / ANIM_WALK_SECONDS
		pose_walk(phase, &pose)
		pose_secondary(phase, 1.0, &pose)
		return pose
	}
	phase := math_mod(visual.clock + offset, ANIM_IDLE_SECONDS) / ANIM_IDLE_SECONDS
	pose_idle(phase, &pose)
	pose_secondary(phase, 0.18, &pose)
	return pose
}

// Skin into the mesh buffers and draw. Positions are world-space already.
draw_unit_mesh :: proc(m: ^Unit_Model, pose: ^Pose, unit: rl.Matrix) {
	matrices := pose_matrices(pose, unit)
	skin_vertices(m.rest_pos, m.rest_nrm, m.pos, m.nrm, m.bones, matrices)
	bytes := c.int(len(m.pos) * size_of(rl.Vector3))
	rl.UpdateMeshBuffer(m.mesh, 0, raw_data(m.pos), bytes, 0)
	rl.UpdateMeshBuffer(m.mesh, 2, raw_data(m.nrm), bytes, 0)
	rl.DrawMesh(m.mesh, m.material, rl.Matrix(1))
}

@(private)
math_mod :: proc(x, m: f32) -> f32 {
	return x - m * math.floor(x / m)
}

draw_warrior_model :: proc(index: int, ground: rl.Vector3) -> bool {
	m := &app.models[index]
	if !m.loaded {
		return false
	}
	visual := &app.visuals[index]
	pose := unit_pose(index)
	radians := visual.angle * math.PI / 180
	unit := xf_mul(
		xf_mul(rl.MatrixTranslate(ground.x, ground.y, ground.z), rl.MatrixRotateY(radians)),
		rl.MatrixScale(WARRIOR_SCALE, WARRIOR_SCALE, WARRIOR_SCALE),
	)
	draw_unit_mesh(m, &pose, unit)
	return true
}
