package gfx

import "core:c"
import "core:fmt"
import "core:mem"
import sdl "vendor:sdl3"

// Meshes, materials and models. Vertex data lives in four streams (position, texcoord,
// normal, colour) so UpdateMeshBuffer can replace one stream at a time like raylib's VBOs.
// Missing streams are filled with raylib's defaults (zero UVs, up normals, white colour).

MAX_MATERIAL_MAPS :: 12

@(private)
Dyn_Stream :: struct {
	epoch: u64,
	off:   u32,
}

@(private)
Mesh_Gpu :: struct {
	bufs:   [4]^sdl.GPUBuffer,
	sizes:  [4]u32,
	index:  ^sdl.GPUBuffer,
	vcount: u32,
	icount: u32,
	dyn:    [4]Dyn_Stream,
	alive:  bool,
}

@(private)
STREAM_STRIDE := [4]int{12, 8, 12, 4}

@(private)
mesh_release :: proc(m: ^Mesh_Gpu) {
	if !m.alive {
		return
	}
	for b in m.bufs {
		if b != nil {
			sdl.ReleaseGPUBuffer(G.dev, b)
		}
	}
	if m.index != nil {
		sdl.ReleaseGPUBuffer(G.dev, m.index)
	}
	m^ = {}
}

UploadMesh :: proc(mesh: ^Mesh, dynamic_: bool) {
	if G.dev == nil || mesh.vertices == nil || mesh.vertexCount <= 0 {
		return
	}
	n := int(mesh.vertexCount)
	streams: [4][]u8
	streams[0] = mem.byte_slice(mesh.vertices, n * 12)
	if mesh.texcoords != nil {
		streams[1] = mem.byte_slice(mesh.texcoords, n * 8)
	} else {
		streams[1] = make([]u8, n * 8, context.temp_allocator)
	}
	if mesh.normals != nil {
		streams[2] = mem.byte_slice(mesh.normals, n * 12)
	} else {
		nrm := make([]Vector3, n, context.temp_allocator)
		for &v in nrm {
			v = {0, 1, 0}
		}
		streams[2] = mem.slice_to_bytes(nrm)
	}
	if mesh.colors != nil {
		streams[3] = mem.byte_slice(mesh.colors, n * 4)
	} else {
		col := make([]u8, n * 4, context.temp_allocator)
		mem.set(raw_data(col), 255, len(col))
		streams[3] = col
	}
	indices: []u8
	icount := 0
	if mesh.indices != nil && mesh.triangleCount > 0 {
		icount = int(mesh.triangleCount) * 3
		indices = mem.byte_slice(mesh.indices, icount * 2)
	}
	m := Mesh_Gpu{vcount = u32(n), icount = u32(icount), alive = true}
	total := 0
	for s in streams {
		total += align16(len(s))
	}
	total += align16(len(indices))
	xfer := sdl.CreateGPUTransferBuffer(G.dev, {usage = .UPLOAD, size = u32(total)})
	if xfer == nil {
		return
	}
	defer sdl.ReleaseGPUTransferBuffer(G.dev, xfer)
	dst := cast([^]u8)sdl.MapGPUTransferBuffer(G.dev, xfer, false)
	if dst == nil {
		return
	}
	offs: [5]int
	o := 0
	for s, i in streams {
		offs[i] = o
		mem.copy(&dst[o], raw_data(s), len(s))
		o += align16(len(s))
	}
	offs[4] = o
	if len(indices) > 0 {
		mem.copy(&dst[o], raw_data(indices), len(indices))
	}
	sdl.UnmapGPUTransferBuffer(G.dev, xfer)
	cmd := sdl.AcquireGPUCommandBuffer(G.dev)
	cp := sdl.BeginGPUCopyPass(cmd)
	for s, i in streams {
		m.sizes[i] = u32(len(s))
		m.bufs[i] = sdl.CreateGPUBuffer(G.dev, {usage = {.VERTEX}, size = u32(len(s))})
		sdl.UploadToGPUBuffer(cp, {transfer_buffer = xfer, offset = u32(offs[i])}, {buffer = m.bufs[i], size = u32(len(s))}, false)
	}
	if len(indices) > 0 {
		m.index = sdl.CreateGPUBuffer(G.dev, {usage = {.INDEX}, size = u32(len(indices))})
		sdl.UploadToGPUBuffer(cp, {transfer_buffer = xfer, offset = u32(offs[4])}, {buffer = m.index, size = u32(len(indices))}, false)
	}
	sdl.EndGPUCopyPass(cp)
	_ = sdl.SubmitGPUCommandBuffer(cmd)
	append(&G.meshes, m)
	mesh.vaoId = u32(len(G.meshes) - 1)
}

@(private)
mesh_entry :: proc(mesh: Mesh) -> ^Mesh_Gpu {
	id := int(mesh.vaoId)
	if id <= 0 || id >= len(G.meshes) || !G.meshes[id].alive {
		return nil
	}
	return &G.meshes[id]
}

// raylib buffer index: 0 positions, 1 texcoords, 2 normals, 3 colours.
UpdateMeshBuffer :: proc(mesh: Mesh, index: c.int, data: rawptr, dataSize: c.int, offset: c.int) {
	m := mesh_entry(mesh)
	if m == nil || index < 0 || index > 3 || data == nil || dataSize <= 0 {
		return
	}
	if offset != 0 {
		@(static) warned: bool
		if !warned {
			fmt.eprintln("gfx: UpdateMeshBuffer with an offset is not supported")
			warned = true
		}
		return
	}
	size := min(int(dataSize), int(m.sizes[index]))
	off := stage(data, size)
	m.dyn[index] = {epoch = G.epoch, off = off}
	append(&G.persist, Persist{buf = m.bufs[index], off = off, size = u32(size)})
}

UnloadMesh :: proc(mesh: Mesh) {
	if m := mesh_entry(mesh); m != nil {
		_ = sdl.WaitForGPUIdle(G.dev)
		mesh_release(m)
	}
	MemFree(mesh.vertices)
	MemFree(mesh.texcoords)
	MemFree(mesh.texcoords2)
	MemFree(mesh.normals)
	MemFree(mesh.tangents)
	MemFree(mesh.colors)
	MemFree(mesh.indices)
	MemFree(mesh.animVertices)
	MemFree(mesh.animNormals)
	MemFree(mesh.boneWeights)
	MemFree(mesh.boneIndices)
}

DrawMesh :: proc(mesh: Mesh, material: Material, transform: Matrix) {
	m := mesh_entry(mesh)
	if m == nil || G.pass < 0 {
		return
	}
	prog := u32(material.shader.id)
	if prog == 0 || int(prog) >= len(G.programs) {
		prog = DEFAULT_SHADER
	}
	col := WHITE
	tex: [2]u32
	if material.maps != nil {
		col = material.maps[0].color
		tex = {u32(material.maps[0].texture.id), u32(material.maps[1].texture.id)}
	}
	d := Draw{
		kind = .Mesh,
		key = current_key(prog, 0, false),
		index = m.index,
		count = m.index != nil ? m.icount : m.vcount,
		tex = tex,
		scissor_on = G.scissor_on,
		scissor = G.scissor,
	}
	for s in 0 ..< 4 {
		if m.dyn[s].epoch == G.epoch && m.dyn[s].epoch != 0 {
			d.streams[s] = {off = m.dyn[s].off, arena = true}
		} else {
			d.streams[s] = {buf = m.bufs[s]}
		}
	}
	d.uni_off, d.uni_size = push_uniforms(build_block(prog, transform, col))
	record(d)
	G.imm_end = -1
}

// ------------------------------------------------------------------ materials

LoadMaterialDefault :: proc() -> Material {
	m: Material
	m.shader = Shader{id = DEFAULT_SHADER}
	m.maps = cast([^]MaterialMap)MemAlloc(c.uint(MAX_MATERIAL_MAPS * size_of(MaterialMap)))
	m.maps[0].texture = Texture{id = c.uint(G.white), width = 1, height = 1, mipmaps = 1, format = .UNCOMPRESSED_R8G8B8A8}
	m.maps[0].color = WHITE
	m.maps[1].color = WHITE
	return m
}

UnloadMaterial :: proc(material: Material) {
	if material.shader.id != 0 && material.shader.id != DEFAULT_SHADER {
		UnloadShader(material.shader)
	}
	if material.maps != nil {
		for i in 0 ..< MAX_MATERIAL_MAPS {
			t := material.maps[i].texture
			if t.id != 0 && u32(t.id) != G.white {
				UnloadTexture(t)
			}
		}
		MemFree(material.maps)
	}
}

SetMaterialTexture :: proc(material: ^Material, mapType: MaterialMapIndex, texture: Texture2D) {
	if material.maps != nil {
		material.maps[mapType].texture = texture
	}
}

// ------------------------------------------------------------------ models

LoadModelFromMesh :: proc(mesh: Mesh) -> Model {
	model: Model
	model.transform = Matrix(1)
	model.meshCount = 1
	model.meshes = cast([^]Mesh)MemAlloc(size_of(Mesh))
	model.meshes[0] = mesh
	model.materialCount = 1
	model.materials = cast([^]Material)MemAlloc(size_of(Material))
	model.materials[0] = LoadMaterialDefault()
	model.meshMaterial = cast([^]c.int)MemAlloc(size_of(c.int))
	return model
}

IsModelValid :: proc(model: Model) -> bool {
	return model.meshes != nil && model.meshCount > 0 && mesh_entry(model.meshes[0]) != nil
}

UnloadModel :: proc(model: Model) {
	for i in 0 ..< int(model.meshCount) {
		UnloadMesh(model.meshes[i])
	}
	for i in 0 ..< int(model.materialCount) {
		UnloadMaterial(model.materials[i])
	}
	MemFree(model.meshes)
	MemFree(model.materials)
	MemFree(model.meshMaterial)
}

DrawModel :: proc(model: Model, position: Vector3, scale: f32, tint: Color) {
	DrawModelEx(model, position, {0, 1, 0}, 0, {scale, scale, scale}, tint)
}

DrawModelEx :: proc(model: Model, position: Vector3, rotationAxis: Vector3, rotationAngle: f32, scale: Vector3, tint: Color) {
	xf := MatrixTranslate(position.x, position.y, position.z) * MatrixRotate(rotationAxis, rotationAngle * DEG2RAD) * MatrixScale(scale.x, scale.y, scale.z) * model.transform
	for i in 0 ..< int(model.meshCount) {
		mi := model.meshMaterial != nil ? int(model.meshMaterial[i]) : 0
		mat := model.materials[mi]
		saved := mat.maps[0].color
		mat.maps[0].color = Color{
			u8(int(saved.r) * int(tint.r) / 255),
			u8(int(saved.g) * int(tint.g) / 255),
			u8(int(saved.b) * int(tint.b) / 255),
			u8(int(saved.a) * int(tint.a) / 255),
		}
		DrawMesh(model.meshes[i], mat, xf)
		mat.maps[0].color = saved
	}
}

GenMeshPlane :: proc(width, length: f32, resX, resZ: c.int) -> Mesh {
	rx := int(resX) + 1
	rz := int(resZ) + 1
	count := rx * rz
	faces := (rx - 1) * (rz - 1)
	mesh: Mesh
	mesh.vertexCount = c.int(count)
	mesh.triangleCount = c.int(faces * 2)
	mesh.vertices = cast([^]f32)MemAlloc(c.uint(count * 12))
	mesh.normals = cast([^]f32)MemAlloc(c.uint(count * 12))
	mesh.texcoords = cast([^]f32)MemAlloc(c.uint(count * 8))
	mesh.indices = cast([^]u16)MemAlloc(c.uint(faces * 6 * 2))
	for z in 0 ..< rz {
		zp := (f32(z) / f32(rz - 1) - 0.5) * length
		for x in 0 ..< rx {
			xp := (f32(x) / f32(rx - 1) - 0.5) * width
			i := x + z * rx
			mesh.vertices[i * 3 + 0] = xp
			mesh.vertices[i * 3 + 1] = 0
			mesh.vertices[i * 3 + 2] = zp
			mesh.normals[i * 3 + 1] = 1
			mesh.texcoords[i * 2 + 0] = f32(x) / f32(rx - 1)
			mesh.texcoords[i * 2 + 1] = f32(z) / f32(rz - 1)
		}
	}
	t := 0
	for face in 0 ..< faces {
		i := face + face / (rx - 1)
		idx := [6]int{i + rx, i + 1, i, i + rx, i + rx + 1, i + 1}
		for k in idx {
			mesh.indices[t] = u16(k)
			t += 1
		}
	}
	UploadMesh(&mesh, false)
	return mesh
}
