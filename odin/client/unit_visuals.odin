// Unit visuals: one procedurally built Mamluk mesh per unit, skinned on the
// CPU every frame. Replaces the old Blender/GLB pipeline entirely.
package main

import "core:c"
import "core:math"
import "core:mem"
import rl "vendor:raylib"
import g "../game"
import art "./art"

WARRIOR_SCALE :: f32(0.74)
STRIDE_DISTANCE :: f32(1.85)

Unit_Visual :: struct {
	handle:        g.Unit_Handle,
	angle:         f32,
	clock:         f32,
	attack:        f32,
	prev_cooldown: u16,
	prev_ground:   rl.Vector3,
	walk_phase:    f32,
	move_blend:    f32,
	speed_smooth:  f32,
	accel_lean:    f32,
	turn_rate:     f32,
	heading_err:   f32,
	stop_settle:   f32,
	has_ground:    bool,
	was_moving:    bool,
}

Unit_Model :: struct {
	loaded:    bool,
	enemy:     bool,
	mesh:      rl.Mesh,
	material:  rl.Material,
	rest_pos:  []rl.Vector3,
	rest_nrm:  []rl.Vector3,
	bones:     []u8,
	pos:       []rl.Vector3,
	nrm:       []rl.Vector3,
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
	b := art.build_mamluk(enemy)
	defer art.mb_delete(&b)
	if b.overflow || len(b.pos) == 0 || len(b.idx) == 0 {
		return m
	}
	upload_builder(&b, &m, enemy)
	return m
}

// Copies the builder into raylib-owned buffers and uploads the mesh once.
@(private)
upload_builder :: proc(b: ^art.Mesh_Builder, m: ^Unit_Model, enemy: bool) {
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
		if !units.alive[i] {
			app.visuals[i] = {}
			continue
		}
		update_unit_visual(i, dt)
	}
}

@(private)
update_unit_visual :: proc(index: int, dt: f32) {
	units := &app.game.units
	visual := &app.visuals[index]
	ensure_unit_model(index)
	handle := g.unit_handle(units, index)
	if visual.handle != handle {
		visual^ = Unit_Visual {
			handle        = handle,
			prev_cooldown = units.cooldown[index],
		}
	}
	visual.clock += dt
	if units.cooldown[index] > visual.prev_cooldown {
		visual.attack = art.ANIM_ATTACK_SECONDS
	}
	visual.prev_cooldown = units.cooldown[index]
	if visual.attack > 0 {
		visual.attack = max(0, visual.attack - dt)
	}
	ground := unit_ground(index)
	target_angle, moving, dist := update_visual_motion(visual, units, index, ground)
	update_visual_dynamics(visual, dt, target_angle, moving, dist)
}

@(private)
update_visual_motion :: proc(
	visual: ^Unit_Visual,
	units: ^g.Units,
	index: int,
	ground: rl.Vector3,
) -> (target_angle: f32, moving: bool, dist: f32) {
	target_angle = visual.angle
	dx := ground.x - visual.prev_ground.x
	dz := ground.z - visual.prev_ground.z
	dist = visual.has_ground ? math.hypot(dx, dz) : f32(0)
	visual.prev_ground = ground
	if dist > 1e-5 {
		visual.walk_phase = math_mod(visual.walk_phase + dist / STRIDE_DISTANCE, 1.0)
	}
	if visual.attack > 0 {
		if target, ok := g.unit_index(units, units.attack_target[index]); ok {
			target_angle = angle_toward(units.position[target], units.position[index], visual.angle)
		}
		return target_angle, false, dist
	}
	if g.unit_has_path(units, index) {
		target_angle = path_angle(units, index, visual.angle)
		moving = true
	} else if dist > 1e-4 {
		target_angle = math.atan2(dx, dz) * 180.0 / math.PI
		moving = true
	}
	return target_angle, moving, dist
}

@(private)
update_visual_dynamics :: proc(visual: ^Unit_Visual, dt, target_angle: f32, moving: bool, dist: f32) {
	dt_safe := max(dt, 1e-4)
	if !visual.has_ground {
		visual.angle = target_angle
		visual.has_ground = true
	} else {
		prev_angle := visual.angle
		visual.angle = turn_toward(visual.angle, target_angle, 660.0 * dt)
		step_deg := math_mod(visual.angle - prev_angle + 180.0, 360.0) - 180.0
		inst_turn := (step_deg * math.PI / 180.0) / dt_safe
		visual.turn_rate = math.lerp(visual.turn_rate, inst_turn, 1.0 - math.exp(-14.0 * max(dt, 0)))
		visual.heading_err = math_mod(target_angle - visual.angle + 180.0, 360.0) - 180.0
	}
	rate := moving ? f32(14.0) : f32(9.0)
	target_move: f32 = moving ? 1.0 : 0.0
	visual.move_blend = math.lerp(visual.move_blend, target_move, 1.0 - math.exp(-rate * max(dt, 0)))
	if !moving && visual.move_blend > 0.03 {
		// Coast gently toward nearest foot-plant phase instead of freezing mid-air.
		nearest := math.round(visual.walk_phase * 2.0) * 0.5
		step := clamp(nearest - visual.walk_phase, -2.4 * visual.move_blend * dt, 2.4 * visual.move_blend * dt)
		visual.walk_phase = math_mod(visual.walk_phase + step, 1.0)
	}
	inst_speed := dist / dt_safe
	accel_diff := inst_speed - visual.speed_smooth
	visual.speed_smooth = math.lerp(visual.speed_smooth, inst_speed, 1.0 - math.exp(-10.0 * max(dt, 0)))
	target_lean := moving ? clamp(0.025 + accel_diff * 0.022, -0.04, 0.10) : clamp(accel_diff * 0.015, -0.04, 0.04)
	visual.accel_lean = math.lerp(visual.accel_lean, target_lean, 1.0 - math.exp(-12.0 * max(dt, 0)))
	if visual.was_moving && !moving {
		visual.stop_settle = 1.0
	}
	visual.stop_settle = max(0, visual.stop_settle - dt / 0.34)
	visual.was_moving = moving
}

@(private)
turn_toward :: proc(current, target, max_step: f32) -> f32 {
	delta := math_mod(target - current + 180.0, 360.0) - 180.0
	if abs(delta) <= max_step {
		return target
	}
	step := delta > 0 ? max_step : -max_step
	return math_mod(current + step + 180.0, 360.0) - 180.0
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
unit_pose :: proc(index: int) -> art.Pose {
	visual := &app.visuals[index]
	offset := f32(index) * 0.37
	idle_phase := math_mod(visual.clock + offset, art.ANIM_IDLE_SECONDS) / art.ANIM_IDLE_SECONDS
	idle_pose: art.Pose
	art.pose_idle(idle_phase, &idle_pose)
	art.pose_secondary(idle_phase, 0.16, &idle_pose)

	pose := idle_pose
	if visual.move_blend > 0.001 {
		b := visual.move_blend * visual.move_blend * (3.0 - 2.0 * visual.move_blend)
		walk_pose: art.Pose
		art.pose_walk(visual.walk_phase, &walk_pose)
		art.pose_secondary(visual.walk_phase, 1.0, &walk_pose)
		pose = art.pose_lerp(&idle_pose, &walk_pose, b)
	}
	apply_visual_dynamics(visual, &pose)
	if visual.attack > 0 {
		t := 1.0 - visual.attack / art.ANIM_ATTACK_SECONDS
		art.pose_attack(t, &pose)
	}
	return pose
}

// Applies acceleration lean, turn banking/look-ahead, and stop settle cushion.
@(private)
apply_visual_dynamics :: proc(visual: ^Unit_Visual, pose: ^art.Pose) {
	look := clamp(visual.heading_err * math.PI / 180.0, -0.75, 0.75)
	bank := -clamp(visual.turn_rate * 0.015 * (0.35 + 0.65 * visual.move_blend), -0.14, 0.14)
	art.pose_add(pose, .Pelvis, 0, 0, 0.50 * bank)
	art.pose_add(pose, .Spine, 0.40 * visual.accel_lean, 0.08 * look, 0.35 * bank)
	art.pose_add(pose, .Chest, 0.60 * visual.accel_lean, 0.20 * look, 0.15 * bank)
	art.pose_add(pose, .Neck, -0.20 * visual.accel_lean, 0.18 * look, -0.20 * bank)
	art.pose_add(pose, .Head, -0.30 * visual.accel_lean, 0.42 * look, -0.35 * bank)
	if visual.stop_settle > 0.001 {
		s := visual.stop_settle
		bounce := (s * s) * math.sin((1.0 - s) * 1.4 * math.TAU)
		pose.root_offset.y -= 0.022 * abs(bounce)
		art.pose_add(pose, .Shin_L, 0.08 * bounce, 0, 0)
		art.pose_add(pose, .Shin_R, 0.08 * bounce, 0, 0)
		art.pose_add(pose, .Chest, 0.09 * bounce, 0, 0)
		art.pose_add(pose, .Arm_R, 0.13 * bounce, 0, 0)
		art.pose_add(pose, .Hand_R, 0.12 * bounce, 0, 0)
		art.pose_add(pose, .Plume, 0.18 * bounce, 0, 0)
		art.pose_add(pose, .Cape_1, 0.13 * bounce, 0, 0)
		art.pose_add(pose, .Cape_2, 0.11 * bounce, 0, 0)
	}
}

// Skin into the mesh buffers and draw. Positions are world-space already.
draw_unit_mesh :: proc(m: ^Unit_Model, pose: ^art.Pose, unit: rl.Matrix) {
	matrices := art.pose_matrices(pose, unit)
	art.skin_vertices(m.rest_pos, m.rest_nrm, m.pos, m.nrm, m.bones, matrices)
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
	unit := art.xf_mul(
		art.xf_mul(rl.MatrixTranslate(ground.x, ground.y, ground.z), rl.MatrixRotateY(radians)),
		rl.MatrixScale(WARRIOR_SCALE, WARRIOR_SCALE, WARRIOR_SCALE),
	)
	draw_unit_mesh(m, &pose, unit)
	return true
}
