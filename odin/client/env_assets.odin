// GPU upload helpers and asset lifecycle for static environment models.
package main

import "core:c"
import "core:mem"
import rl "vendor:raylib"
import art "./art"

Env_Assets :: struct {
	ready:             bool,
	tree_models:       [4]rl.Model,
	rock_models:       [2]rl.Model,
	waypoint_model:    rl.Model,
	banner_model:      rl.Model,
	select_ring_model: rl.Model,
}

// Allocates a raylib-owned slice via rl.MemAlloc so UnloadMesh can RL_FREE it.
alloc_mesh_slice :: proc($T: typeid, count: int) -> []T {
	if count <= 0 {
		return nil
	}
	ptr := rl.MemAlloc(c.uint(count * size_of(T)))
	if ptr == nil {
		return nil
	}
	return mem.slice_ptr(cast(^T)ptr, count)
}

upload_static_model :: proc(b: ^art.Mesh_Builder) -> (rl.Model, bool) {
	if b.overflow || len(b.pos) == 0 || len(b.idx) == 0 {
		return {}, false
	}
	count := len(b.pos)
	pos := alloc_mesh_slice(rl.Vector3, count)
	nrm := alloc_mesh_slice(rl.Vector3, count)
	col := alloc_mesh_slice(rl.Color, count)
	uv := alloc_mesh_slice(rl.Vector2, count)
	idx := alloc_mesh_slice(u16, len(b.idx))
	if pos == nil || nrm == nil || col == nil || uv == nil || idx == nil {
		free_alloc_slices(pos, nrm, col, uv, idx)
		return {}, false
	}
	copy(pos, b.pos[:])
	copy(nrm, b.nrm[:])
	copy(col, b.col[:])
	copy(uv, b.uv[:])
	copy(idx, b.idx[:])
	mesh := rl.Mesh{
		vertexCount   = i32(count),
		triangleCount = i32(len(b.idx) / 3),
		vertices      = cast([^]f32)raw_data(pos),
		normals       = cast([^]f32)raw_data(nrm),
		colors        = cast([^]u8)raw_data(col),
		texcoords     = cast([^]f32)raw_data(uv),
		indices       = raw_data(idx),
	}
	rl.UploadMesh(&mesh, false)
	model := rl.LoadModelFromMesh(mesh)
	if model.materialCount > 0 && model.materials != nil && app.unit_shader.ready {
		model.materials[0].shader = app.unit_shader.shader
	}
	return model, model.meshCount > 0
}

@(private)
free_alloc_slices :: proc(pos, nrm: []rl.Vector3, col: []rl.Color, uv: []rl.Vector2, idx: []u16) {
	if pos != nil { rl.MemFree(raw_data(pos)) }
	if nrm != nil { rl.MemFree(raw_data(nrm)) }
	if col != nil { rl.MemFree(raw_data(col)) }
	if uv != nil { rl.MemFree(raw_data(uv)) }
	if idx != nil { rl.MemFree(raw_data(idx)) }
}

@(private)
build_and_upload :: proc(builder_fn: proc() -> art.Mesh_Builder) -> (rl.Model, bool) {
	b := builder_fn()
	defer art.mb_delete(&b)
	return upload_static_model(&b)
}

init_env_assets :: proc() {
	unload_env_assets()
	tree_builders := [4](proc() -> art.Mesh_Builder){
		art.build_pine_tall,
		art.build_pine_mid,
		art.build_oak_broad,
		art.build_oak_elder,
	}
	ok := true
	for fn, i in tree_builders {
		m, loaded := build_and_upload(fn)
		app.env.tree_models[i] = m
		ok = ok && loaded
	}
	rock_builders := [2](proc() -> art.Mesh_Builder){art.build_boulder_moss, art.build_shrub_fern}
	for fn, i in rock_builders {
		m, loaded := build_and_upload(fn)
		app.env.rock_models[i] = m
		ok = ok && loaded
	}
	wp, wp_ok := build_and_upload(art.build_waypoint_disc)
	bn, bn_ok := build_and_upload(art.build_goal_banner)
	sr, sr_ok := build_and_upload(art.build_selection_ring)
	app.env.waypoint_model = wp
	app.env.banner_model = bn
	app.env.select_ring_model = sr
	app.env.ready = ok && wp_ok && bn_ok && sr_ok
	if !app.env.ready {
		unload_env_assets()
	}
}

unload_env_assets :: proc() {
	for &m in app.env.tree_models {
		unload_static_model(&m)
	}
	for &m in app.env.rock_models {
		unload_static_model(&m)
	}
	unload_static_model(&app.env.waypoint_model)
	unload_static_model(&app.env.banner_model)
	unload_static_model(&app.env.select_ring_model)
	app.env = {}
}

@(private)
unload_static_model :: proc(m: ^rl.Model) {
	if m.meshCount > 0 {
		// Zero shared shader handle before UnloadModel so unit_shader stays alive.
		if m.materialCount > 0 && m.materials != nil {
			m.materials[0].shader = {}
		}
		rl.UnloadModel(m^)
	}
	m^ = {}
}
