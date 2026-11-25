package gfx

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl3"

COLOR_FORMAT :: sdl.GPUTextureFormat.R8G8B8A8_UNORM

// GL's default rasterizer state is CCW front faces in a y-up window. The flag below is the
// SDL front_face that reproduces it in an unflipped pass; render-texture passes flip Y (to
// keep GL's bottom-up render-target convention) and therefore flip winding too.
@(private)
FRONT_CCW_UNFLIPPED :: true

GFX_TRACE :: #config(GFX_TRACE, false)

// CPU time of the last replay, split by phase (ms): recording upload, passes, swapchain wait, submit.
Replay_Stats :: struct {
	upload, passes, acquire, submit: f64,
	draws, passes_n: int,
}
last_replay: Replay_Stats

@(private)
Tex :: struct {
	tex:    ^sdl.GPUTexture,
	w, h:   int,
	levels: u32,
	filter: TextureFilter,
	wrap:   TextureWrap,
	rt:     bool,
	alive:  bool,
}

@(private)
Target :: struct {
	color: u32, // texture id
	depth: ^sdl.GPUTexture,
	w, h:  int,
	alive: bool,
}

@(private)
Stream_Ref :: struct {
	buf:   ^sdl.GPUBuffer,
	off:   u32,
	arena: bool,
}

@(private)
Draw_Kind :: enum u8 {
	Mesh,
	Imm,
	Callback,
}

@(private)
Pipe_Key :: struct {
	prog:        u16,
	prim:        u8, // 0 triangles, 1 lines
	blend:       u8,
	depth_test:  bool,
	depth_write: bool,
	cull:        bool,
	front_ccw:   bool,
	interleaved: bool,
}

Callback_Prepare :: #type proc(cmd: ^sdl.GPUCommandBuffer, data: rawptr)
Callback_Draw :: #type proc(cmd: ^sdl.GPUCommandBuffer, pass: ^sdl.GPURenderPass, w, h: i32, data: rawptr)

@(private)
Draw :: struct {
	kind:       Draw_Kind,
	key:        Pipe_Key,
	streams:    [4]Stream_Ref,
	index:      ^sdl.GPUBuffer,
	count:      u32,
	first:      u32,
	uni_off:    u32,
	uni_size:   u32,
	tex:        [2]u32,
	scissor_on: bool,
	scissor:    [4]i32,
	prepare:    Callback_Prepare,
	draw:       Callback_Draw,
	data:       rawptr,
}

@(private)
Pass :: struct {
	target:      int,
	clear:       bool,
	clear_color: [4]f32,
	first:       int,
	count:       int,
	flip:        bool,
}

@(private)
Tex_Upload :: struct {
	tex:    u32,
	off:    u32,
	x, y:   u32,
	w, h:   u32,
	whole:  bool,
}

@(private)
Persist :: struct {
	buf:  ^sdl.GPUBuffer,
	off:  u32,
	size: u32,
}

@(private)
Raster :: struct {
	depth_test:  bool,
	depth_write: bool,
	cull:        bool,
	blend:       BlendMode,
}

@(private)
Gpu :: struct {
	dev:          ^sdl.GPUDevice,
	window:       ^sdl.Window,
	depth_format: sdl.GPUTextureFormat,
	textures:     [dynamic]Tex,
	targets:      [dynamic]Target,
	meshes:       [dynamic]Mesh_Gpu,
	programs:     [dynamic]Program,
	pipelines:    map[Pipe_Key]^sdl.GPUGraphicsPipeline,
	samplers:     map[u32]^sdl.GPUSampler,
	white:        u32,
	// recording
	staging:      [dynamic]u8,
	uniforms:     [dynamic]u8,
	tex_uploads:  [dynamic]Tex_Upload,
	persist:      [dynamic]Persist,
	passes:       [dynamic]Pass,
	draws:        [dynamic]Draw,
	epoch:        u64,
	arena:        ^sdl.GPUBuffer,
	arena_cap:    int,
	xfer:         ^sdl.GPUTransferBuffer,
	xfer_cap:     int,
	// state
	pass:         int, // index into passes, -1 = none
	drawing:      bool,
	tex_mode:     int, // target index while in texture mode, -1 otherwise
	mode3d:       bool,
	proj:         Matrix,
	view:         Matrix,
	raster:       Raster,
	shader_mode:  u32,
	scissor_on:   bool,
	scissor:      [4]i32,
	imm_end:      int, // staging offset right after the last immediate draw's vertices
	vsync:        bool,
}

@(private)
G: Gpu

// ------------------------------------------------------------------ init

@(private)
device_init :: proc(window: ^sdl.Window, vsync: bool) -> bool {
	G.window = window
	G.pass = -1
	G.tex_mode = -1
	G.vsync = vsync
	G.epoch = 1
	G.raster = {depth_test = false, depth_write = true, cull = true, blend = .ALPHA}
	G.dev = create_device()
	if G.dev == nil {
		return false
	}
	if !sdl.ClaimWindowForGPUDevice(G.dev, window) {
		fmt.eprintln("gfx: claim window failed:", sdl.GetError())
		return false
	}
	mode: sdl.GPUPresentMode = .VSYNC
	if !vsync {
		// uncapped: IMMEDIATE where supported, else MAILBOX (never blocks on vblank)
		if sdl.WindowSupportsGPUPresentMode(G.dev, window, .IMMEDIATE) {
			mode = .IMMEDIATE
		} else if sdl.WindowSupportsGPUPresentMode(G.dev, window, .MAILBOX) {
			mode = .MAILBOX
		}
	}
	if !sdl.SetGPUSwapchainParameters(G.dev, window, .SDR, mode) {
		fmt.eprintln("gfx: swapchain parameters rejected:", sdl.GetError())
	}
	platform_after_claim(window) // after the swapchain is configured: SDL sets layer state there
	when GFX_TRACE {
		fmt.eprintln("gfx: driver", sdl.GetGPUDeviceDriver(G.dev), "present mode", mode)
	}
	G.depth_format = .D32_FLOAT
	if !sdl.GPUTextureSupportsFormat(G.dev, .D32_FLOAT, .D2, {.DEPTH_STENCIL_TARGET}) {
		G.depth_format = .D24_UNORM
	}
	append(&G.textures, Tex{}) // id 0 = none
	append(&G.targets, Target{}) // index 0 = backbuffer
	append(&G.meshes, Mesh_Gpu{})
	programs_init()
	white := [4]u8{255, 255, 255, 255}
	G.white = texture_create(1, 1, white[:], false)
	return true
}

@(private)
device_shutdown :: proc() {
	if G.dev == nil {
		return
	}
	_ = sdl.WaitForGPUIdle(G.dev)
	for &t in G.textures {
		if t.alive && t.tex != nil {
			sdl.ReleaseGPUTexture(G.dev, t.tex)
		}
	}
	for &t in G.targets {
		if t.depth != nil {
			sdl.ReleaseGPUTexture(G.dev, t.depth)
		}
	}
	for &m in G.meshes {
		mesh_release(&m)
	}
	for _, p in G.pipelines {
		sdl.ReleaseGPUGraphicsPipeline(G.dev, p)
	}
	for _, s in G.samplers {
		sdl.ReleaseGPUSampler(G.dev, s)
	}
	programs_release()
	if G.arena != nil {
		sdl.ReleaseGPUBuffer(G.dev, G.arena)
	}
	if G.xfer != nil {
		sdl.ReleaseGPUTransferBuffer(G.dev, G.xfer)
	}
	sdl.ReleaseWindowFromGPUDevice(G.dev, G.window)
	sdl.DestroyGPUDevice(G.dev)
	G.dev = nil
}

// The SDL GPU device, for embedding other renderers (vinland-ui) in the same frame.
device :: proc() -> ^sdl.GPUDevice {
	return G.dev
}

color_format :: proc() -> sdl.GPUTextureFormat {
	return COLOR_FORMAT
}

depth_format :: proc() -> sdl.GPUTextureFormat {
	return G.depth_format
}

driver_name :: proc() -> string {
	if G.dev == nil {
		return ""
	}
	return string(sdl.GetGPUDeviceDriver(G.dev))
}

// GPU texture handle (SDL_GPUTexture*) of a texture, for vinland-ui external images.
texture_handle :: proc(t: Texture) -> u64 {
	if int(t.id) <= 0 || int(t.id) >= len(G.textures) || !G.textures[t.id].alive {
		return 0
	}
	return u64(uintptr(G.textures[t.id].tex))
}

// ------------------------------------------------------------------ textures

@(private)
make_gpu_texture :: proc(w, h: int, format: sdl.GPUTextureFormat, usage: sdl.GPUTextureUsageFlags, levels: u32 = 1) -> ^sdl.GPUTexture {
	return sdl.CreateGPUTexture(G.dev, sdl.GPUTextureCreateInfo{
		type = .D2,
		format = format,
		usage = usage,
		width = u32(w),
		height = u32(h),
		layer_count_or_depth = 1,
		num_levels = levels,
	})
}

@(private)
texture_create :: proc(w, h: int, pixels: []u8, rt: bool) -> u32 {
	usage: sdl.GPUTextureUsageFlags = {.SAMPLER}
	if rt {
		usage += {.COLOR_TARGET}
	}
	tex := make_gpu_texture(w, h, COLOR_FORMAT, usage)
	if tex == nil {
		fmt.eprintln("gfx: texture creation failed:", sdl.GetError())
		return 0
	}
	append(&G.textures, Tex{tex = tex, w = w, h = h, levels = 1, filter = .POINT, wrap = .REPEAT, rt = rt, alive = true})
	id := u32(len(G.textures) - 1)
	if len(pixels) >= w * h * 4 {
		upload_now(tex, pixels, 0, 0, w, h)
	}
	return id
}

// Synchronous upload in its own command buffer: queue order puts it before the frame's work.
@(private)
upload_now :: proc(tex: ^sdl.GPUTexture, pixels: []u8, x, y, w, h: int) {
	size := w * h * 4
	xfer := sdl.CreateGPUTransferBuffer(G.dev, {usage = .UPLOAD, size = u32(size)})
	if xfer == nil {
		return
	}
	defer sdl.ReleaseGPUTransferBuffer(G.dev, xfer)
	dst := sdl.MapGPUTransferBuffer(G.dev, xfer, false)
	if dst == nil {
		return
	}
	mem.copy(dst, raw_data(pixels), size)
	sdl.UnmapGPUTransferBuffer(G.dev, xfer)
	cmd := sdl.AcquireGPUCommandBuffer(G.dev)
	cp := sdl.BeginGPUCopyPass(cmd)
	sdl.UploadToGPUTexture(cp, {transfer_buffer = xfer, pixels_per_row = u32(w), rows_per_layer = u32(h)}, {texture = tex, x = u32(x), y = u32(y), w = u32(w), h = u32(h), d = 1}, false)
	sdl.EndGPUCopyPass(cp)
	_ = sdl.SubmitGPUCommandBuffer(cmd)
}

@(private)
sampler_for :: proc(t: ^Tex) -> ^sdl.GPUSampler {
	key := u32(t.filter) | u32(t.wrap) << 8 | (t.levels > 1 ? 1 << 16 : 0)
	if s, ok := G.samplers[key]; ok {
		return s
	}
	info := sdl.GPUSamplerCreateInfo{
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
		mipmap_mode = .NEAREST,
		max_lod = 0,
	}
	#partial switch t.filter {
	case .POINT:
		info.min_filter = .NEAREST
		info.mag_filter = .NEAREST
	case .TRILINEAR:
		info.mipmap_mode = .LINEAR
		info.max_lod = 1000
	case .ANISOTROPIC_4X, .ANISOTROPIC_8X, .ANISOTROPIC_16X:
		info.mipmap_mode = .LINEAR
		info.max_lod = 1000
		info.enable_anisotropy = true
		info.max_anisotropy = t.filter == .ANISOTROPIC_4X ? 4 : t.filter == .ANISOTROPIC_8X ? 8 : 16
	}
	if t.levels > 1 && t.filter == .BILINEAR {
		// raylib/GL: BILINEAR on a mipmapped texture still samples level 0 only
		info.max_lod = 0
	}
	mode: sdl.GPUSamplerAddressMode = .REPEAT
	#partial switch t.wrap {
	case .CLAMP:
		mode = .CLAMP_TO_EDGE
	case .MIRROR_REPEAT, .MIRROR_CLAMP:
		mode = .MIRRORED_REPEAT
	}
	info.address_mode_u = mode
	info.address_mode_v = mode
	info.address_mode_w = mode
	s := sdl.CreateGPUSampler(G.dev, info)
	G.samplers[key] = s
	return s
}

@(private)
tex_entry :: proc(id: u32) -> ^Tex {
	if int(id) <= 0 || int(id) >= len(G.textures) || !G.textures[id].alive {
		return &G.textures[G.white]
	}
	return &G.textures[id]
}

// ------------------------------------------------------------------ targets

@(private)
target_ensure :: proc(index: int, w, h: int) {
	t := &G.targets[index]
	if t.alive && t.w == w && t.h == h {
		return
	}
	if t.alive {
		_ = sdl.WaitForGPUIdle(G.dev)
		if t.color != 0 {
			sdl.ReleaseGPUTexture(G.dev, G.textures[t.color].tex)
			G.textures[t.color] = {}
		}
		if t.depth != nil {
			sdl.ReleaseGPUTexture(G.dev, t.depth)
		}
	}
	color := make_gpu_texture(w, h, COLOR_FORMAT, {.SAMPLER, .COLOR_TARGET})
	append(&G.textures, Tex{tex = color, w = w, h = h, levels = 1, filter = .BILINEAR, wrap = .CLAMP, rt = true, alive = color != nil})
	t.color = u32(len(G.textures) - 1)
	t.depth = make_gpu_texture(w, h, G.depth_format, {.DEPTH_STENCIL_TARGET})
	t.w = w
	t.h = h
	t.alive = color != nil && t.depth != nil
}

// ------------------------------------------------------------------ recording

@(private)
align16 :: proc(n: int) -> int {
	return (n + 15) &~ 15
}

// Appends bytes to the frame's upload arena; returns their offset.
@(private)
stage :: proc(data: rawptr, size: int) -> u32 {
	off := align16(len(G.staging))
	resize(&G.staging, off + size)
	if data != nil && size > 0 {
		mem.copy(&G.staging[off], data, size)
	}
	return u32(off)
}

@(private)
push_uniforms :: proc(block: []u8) -> (off, size: u32) {
	o := align16(len(G.uniforms))
	resize(&G.uniforms, o + len(block))
	copy(G.uniforms[o:], block)
	return u32(o), u32(len(block))
}

@(private)
pass_begin :: proc(target: int, clear: bool, clear_color: [4]f32) {
	append(&G.passes, Pass{target = target, clear = clear, clear_color = clear_color, first = len(G.draws), flip = target != 0})
	G.pass = len(G.passes) - 1
	G.imm_end = -1
}

@(private)
pass_end :: proc() {
	if G.pass >= 0 {
		p := &G.passes[G.pass]
		p.count = len(G.draws) - p.first
	}
	G.pass = -1
	G.imm_end = -1
}

@(private)
current_target_size :: proc() -> (w, h: int) {
	if G.pass < 0 {
		return 1, 1
	}
	t := &G.targets[G.passes[G.pass].target]
	return t.w, t.h
}

@(private)
pass_flipped :: proc() -> bool {
	return G.pass >= 0 && G.passes[G.pass].flip
}

// Metal/Vulkan clip space: z in [0, 1]; render targets keep GL's bottom-up rows.
@(private)
clip_fix :: proc() -> Matrix {
	fy: f32 = pass_flipped() ? -1 : 1
	return Matrix{
		1, 0, 0, 0,
		0, fy, 0, 0,
		0, 0, 0.5, 0.5,
		0, 0, 0, 1,
	}
}

@(private)
record :: proc(d: Draw) {
	if G.pass < 0 {
		return
	}
	append(&G.draws, d)
	G.passes[G.pass].count = len(G.draws) - G.passes[G.pass].first
}

// Embeds an external renderer (vinland-ui) at this point of the current pass. `prepare`
// runs before any render pass of the frame (copy passes allowed), `draw` inside this pass.
record_callback :: proc(prepare: Callback_Prepare, draw: Callback_Draw, data: rawptr) {
	record(Draw{kind = .Callback, prepare = prepare, draw = draw, data = data})
	G.imm_end = -1
}

// ------------------------------------------------------------------ replay

@(private)
ensure_upload_buffers :: proc(n: int) -> bool {
	if G.arena == nil || G.arena_cap < n {
		if G.arena != nil {
			sdl.ReleaseGPUBuffer(G.dev, G.arena)
		}
		G.arena_cap = max(n + n / 2, 1 << 20)
		G.arena = sdl.CreateGPUBuffer(G.dev, {usage = {.VERTEX, .INDEX}, size = u32(G.arena_cap)})
	}
	if G.xfer == nil || G.xfer_cap < n {
		if G.xfer != nil {
			sdl.ReleaseGPUTransferBuffer(G.dev, G.xfer)
		}
		G.xfer_cap = max(n + n / 2, 1 << 20)
		G.xfer = sdl.CreateGPUTransferBuffer(G.dev, {usage = .UPLOAD, size = u32(G.xfer_cap)})
	}
	return G.arena != nil && G.xfer != nil
}

@(private)
replay :: proc(present: bool) {
	if G.dev == nil {
		return
	}
	if G.pass >= 0 {
		pass_end()
	}
	t0 := sdl.GetTicksNS()
	stats := Replay_Stats{draws = len(G.draws), passes_n = len(G.passes)}
	cmd := sdl.AcquireGPUCommandBuffer(G.dev)
	if cmd == nil {
		clear_recording()
		return
	}
	n := len(G.staging)
	if n > 0 && ensure_upload_buffers(n) {
		if dst := sdl.MapGPUTransferBuffer(G.dev, G.xfer, true); dst != nil {
			mem.copy(dst, raw_data(G.staging), n)
			sdl.UnmapGPUTransferBuffer(G.dev, G.xfer)
			cp := sdl.BeginGPUCopyPass(cmd)
			sdl.UploadToGPUBuffer(cp, {transfer_buffer = G.xfer}, {buffer = G.arena, size = u32(n)}, true)
			for u in G.tex_uploads {
				t := &G.textures[u.tex]
				if !t.alive {
					continue
				}
				sdl.UploadToGPUTexture(cp, {transfer_buffer = G.xfer, offset = u.off, pixels_per_row = u.w, rows_per_layer = u.h}, {texture = t.tex, x = u.x, y = u.y, w = u.w, h = u.h, d = 1}, u.whole)
			}
			sdl.EndGPUCopyPass(cp)
		}
	}
	t1 := sdl.GetTicksNS()
	stats.upload = f64(t1 - t0) / 1e6
	for &d in G.draws {
		if d.kind == .Callback && d.prepare != nil {
			d.prepare(cmd, d.data)
		}
	}
	for &p in G.passes {
		replay_pass(cmd, &p)
	}
	if len(G.persist) > 0 {
		cp := sdl.BeginGPUCopyPass(cmd)
		for p in G.persist {
			sdl.CopyGPUBufferToBuffer(cp, {buffer = G.arena, offset = p.off}, {buffer = p.buf}, p.size, true)
		}
		sdl.EndGPUCopyPass(cp)
	}
	t2 := sdl.GetTicksNS()
	stats.passes = f64(t2 - t1) / 1e6
	if present {
		swap: ^sdl.GPUTexture
		sw, sh: u32
		back := &G.targets[0]
		if sdl.WaitAndAcquireGPUSwapchainTexture(cmd, G.window, &swap, &sw, &sh) && swap != nil && back.alive {
			sdl.BlitGPUTexture(cmd, sdl.GPUBlitInfo{
				source = {texture = G.textures[back.color].tex, w = u32(back.w), h = u32(back.h)},
				destination = {texture = swap, w = sw, h = sh},
				load_op = .DONT_CARE,
				filter = .NEAREST,
			})
		}
	}
	t3 := sdl.GetTicksNS()
	stats.acquire = f64(t3 - t2) / 1e6
	_ = sdl.SubmitGPUCommandBuffer(cmd)
	stats.submit = f64(sdl.GetTicksNS() - t3) / 1e6
	last_replay = stats
	clear_recording()
}

@(private)
clear_recording :: proc() {
	clear(&G.staging)
	clear(&G.uniforms)
	clear(&G.tex_uploads)
	clear(&G.persist)
	clear(&G.passes)
	clear(&G.draws)
	G.pass = -1
	G.imm_end = -1
	G.epoch += 1
}

@(private)
replay_pass :: proc(cmd: ^sdl.GPUCommandBuffer, p: ^Pass) {
	t := &G.targets[p.target]
	if !t.alive {
		return
	}
	color := sdl.GPUColorTargetInfo{
		texture = G.textures[t.color].tex,
		clear_color = sdl.FColor{p.clear_color[0], p.clear_color[1], p.clear_color[2], p.clear_color[3]},
		load_op = p.clear ? .CLEAR : .LOAD,
		store_op = .STORE,
	}
	depth := sdl.GPUDepthStencilTargetInfo{
		texture = t.depth,
		clear_depth = 1,
		load_op = p.clear ? .CLEAR : .LOAD,
		store_op = .STORE,
		stencil_load_op = .DONT_CARE,
		stencil_store_op = .DONT_CARE,
	}
	rp := sdl.BeginGPURenderPass(cmd, &color, 1, &depth)
	if rp == nil {
		return
	}
	full := sdl.Rect{0, 0, i32(t.w), i32(t.h)}
	bound: ^sdl.GPUGraphicsPipeline
	for i in p.first ..< p.first + p.count {
		d := &G.draws[i]
		if d.kind == .Callback {
			if d.draw != nil {
				d.draw(cmd, rp, i32(t.w), i32(t.h), d.data)
			}
			bound = nil
			sdl.SetGPUScissor(rp, full)
			continue
		}
		pipe := pipeline_get(d.key)
		if pipe == nil || d.count == 0 {
			continue
		}
		if pipe != bound {
			sdl.BindGPUGraphicsPipeline(rp, pipe)
			bound = pipe
		}
		if d.scissor_on {
			sdl.SetGPUScissor(rp, sdl.Rect{d.scissor[0], d.scissor[1], d.scissor[2], d.scissor[3]})
		} else {
			sdl.SetGPUScissor(rp, full)
		}
		prog := &G.programs[d.key.prog]
		if d.kind == .Imm {
			b := sdl.GPUBufferBinding{buffer = G.arena, offset = d.streams[0].off}
			sdl.BindGPUVertexBuffers(rp, 0, &b, 1)
		} else {
			binds: [4]sdl.GPUBufferBinding
			for s in 0 ..< 4 {
				r := d.streams[s]
				binds[s] = {buffer = r.arena ? G.arena : r.buf, offset = r.off}
			}
			sdl.BindGPUVertexBuffers(rp, 0, &binds[0], 4)
		}
		if prog.samplers > 0 {
			sb: [2]sdl.GPUTextureSamplerBinding
			for s in 0 ..< prog.samplers {
				te := tex_entry(d.tex[s])
				sb[s] = {texture = te.tex, sampler = sampler_for(te)}
			}
			sdl.BindGPUFragmentSamplers(rp, 0, &sb[0], u32(prog.samplers))
		}
		if d.uni_size > 0 {
			ptr := &G.uniforms[d.uni_off]
			sdl.PushGPUVertexUniformData(cmd, 0, ptr, d.uni_size)
			sdl.PushGPUFragmentUniformData(cmd, 0, ptr, d.uni_size)
		}
		if d.index != nil {
			sdl.BindGPUIndexBuffer(rp, {buffer = d.index}, ._16BIT)
			sdl.DrawGPUIndexedPrimitives(rp, d.count, 1, 0, 0, 0)
		} else {
			sdl.DrawGPUPrimitives(rp, d.count, 1, d.first, 0)
		}
	}
	sdl.EndGPURenderPass(rp)
}

// Executes everything recorded so far (no present), then waits for the GPU.
@(private)
flush :: proc() {
	resume := G.pass >= 0
	target := resume ? G.passes[G.pass].target : 0
	if len(G.passes) > 0 || len(G.tex_uploads) > 0 {
		replay(false)
	}
	_ = sdl.WaitForGPUIdle(G.dev)
	if resume {
		pass_begin(target, false, {})
	}
}

// ------------------------------------------------------------------ pipelines

@(private)
pipeline_get :: proc(key: Pipe_Key) -> ^sdl.GPUGraphicsPipeline {
	if p, ok := G.pipelines[key]; ok {
		return p
	}
	prog := &G.programs[key.prog]
	if prog.vs == nil || prog.fs == nil {
		G.pipelines[key] = nil
		return nil
	}
	attrs: [4]sdl.GPUVertexAttribute
	na := 0
	bufs: [4]sdl.GPUVertexBufferDescription
	nb := 0
	if key.interleaved {
		bufs[0] = {slot = 0, pitch = size_of(Imm_Vertex), input_rate = .VERTEX}
		nb = 1
		if .Pos in prog.attrs {
			attrs[na] = {location = 0, buffer_slot = 0, format = .FLOAT3, offset = 0}
			na += 1
		}
		if .UV in prog.attrs {
			attrs[na] = {location = 1, buffer_slot = 0, format = .FLOAT2, offset = 12}
			na += 1
		}
		if .Color in prog.attrs {
			attrs[na] = {location = 3, buffer_slot = 0, format = .UBYTE4_NORM, offset = 20}
			na += 1
		}
	} else {
		// one buffer per stream; Metal rejects layouts no attribute reads, so declare only
		// the streams this program uses (draws bind all four, extra bindings are harmless)
		STREAMS := [4]struct {
			attr:   Attr,
			pitch:  u32,
			format: sdl.GPUVertexElementFormat,
		}{{.Pos, 12, .FLOAT3}, {.UV, 8, .FLOAT2}, {.Normal, 12, .FLOAT3}, {.Color, 4, .UBYTE4_NORM}}
		for st, i in STREAMS {
			if st.attr in prog.attrs {
				bufs[nb] = {slot = u32(i), pitch = st.pitch, input_rate = .VERTEX}
				nb += 1
				attrs[na] = {location = u32(i), buffer_slot = u32(i), format = st.format}
				na += 1
			}
		}
	}
	blend := sdl.GPUColorTargetBlendState{enable_blend = true, color_blend_op = .ADD, alpha_blend_op = .ADD}
	switch BlendMode(key.blend) {
	case .ADDITIVE:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .SRC_ALPHA, .ONE
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .SRC_ALPHA, .ONE
	case .MULTIPLIED:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .DST_COLOR, .ONE_MINUS_SRC_ALPHA
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .DST_COLOR, .ONE_MINUS_SRC_ALPHA
	case .ADD_COLORS:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .ONE, .ONE
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .ONE, .ONE
	case .SUBTRACT_COLORS:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .ONE, .ONE
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .ONE, .ONE
		blend.color_blend_op, blend.alpha_blend_op = .SUBTRACT, .SUBTRACT
	case .ALPHA_PREMULTIPLY:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .ONE, .ONE_MINUS_SRC_ALPHA
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .ONE, .ONE_MINUS_SRC_ALPHA
	case .ALPHA, .CUSTOM, .CUSTOM_SEPARATE:
		blend.src_color_blendfactor, blend.dst_color_blendfactor = .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA
		blend.src_alpha_blendfactor, blend.dst_alpha_blendfactor = .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA
	}
	ctd := sdl.GPUColorTargetDescription{format = COLOR_FORMAT, blend_state = blend}
	info := sdl.GPUGraphicsPipelineCreateInfo{
		vertex_shader = prog.vs,
		fragment_shader = prog.fs,
		vertex_input_state = {
			vertex_buffer_descriptions = &bufs[0],
			num_vertex_buffers = u32(nb),
			vertex_attributes = &attrs[0],
			num_vertex_attributes = u32(na),
		},
		primitive_type = key.prim == 1 ? .LINELIST : .TRIANGLELIST,
		rasterizer_state = {
			fill_mode = .FILL,
			cull_mode = key.cull ? .BACK : .NONE,
			front_face = key.front_ccw ? .COUNTER_CLOCKWISE : .CLOCKWISE,
		},
		depth_stencil_state = {
			compare_op = .LESS_OR_EQUAL,
			enable_depth_test = key.depth_test,
			enable_depth_write = key.depth_test && key.depth_write,
		},
		target_info = {
			color_target_descriptions = &ctd,
			num_color_targets = 1,
			depth_stencil_format = G.depth_format,
			has_depth_stencil_target = true,
		},
	}
	p := sdl.CreateGPUGraphicsPipeline(G.dev, info)
	if p == nil {
		fmt.eprintln("gfx: pipeline creation failed:", prog.name, sdl.GetError())
	}
	G.pipelines[key] = p
	return p
}

@(private)
current_key :: proc(prog: u32, prim: u8, interleaved: bool) -> Pipe_Key {
	flipped := pass_flipped()
	return Pipe_Key{
		prog = u16(prog),
		prim = prim,
		blend = u8(G.raster.blend),
		depth_test = G.raster.depth_test,
		depth_write = G.raster.depth_write,
		cull = G.raster.cull,
		front_ccw = flipped ? !FRONT_CCW_UNFLIPPED : FRONT_CCW_UNFLIPPED,
		interleaved = interleaved,
	}
}

