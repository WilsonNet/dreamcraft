package gfx

import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

// Shader programs. raylib loads GLSL from files; here LoadShader maps the requested
// fragment file (ground.fs, unit.fs, watercolor.fs) to an embedded MSL / SPIR-V program
// with the same uniforms. Every program shares one uniform block layout:
//
//   0   float4x4 mvp       raylib's built-in uniforms
//   64  float4x4 matModel
//   128 float4   colDiffuse
//   144 float4   fb        target width, height (px), 1 if the pass is a render texture
//   160 float4   slot[i]   the program's own uniforms, in declaration order
//
// Locations returned by GetShaderLocation are byte offsets into that block.

@(private)
Attr :: enum u8 {
	Pos,
	UV,
	Normal,
	Color,
}

@(private)
HEADER_SIZE :: 160

@(private)
MAX_BLOCK :: 512

@(private)
Program :: struct {
	name:     string,
	attrs:    bit_set[Attr],
	samplers: int,
	uniforms: []string,
	size:     int,
	block:    [MAX_BLOCK]u8,
	vs, fs:   ^sdl.GPUShader,
}

@(private)
Program_Def :: struct {
	name:     string,
	file:     string, // fragment shader file name raylib code loads
	attrs:    bit_set[Attr],
	samplers: int,
	uniforms: []string,
	msl:      []u8,
	spv_vs:   []u8,
	spv_fs:   []u8,
}

@(private)
PROGRAMS := [?]Program_Def{
	{
		name = "default", file = "", attrs = {.Pos, .UV, .Color}, samplers = 1, uniforms = {},
		msl = #load("shaders/default.metal"), spv_vs = #load("shaders/default.vert.spv"), spv_fs = #load("shaders/default.frag.spv"),
	},
	{
		name = "ground", file = "ground.fs", attrs = {.Pos, .UV}, samplers = 2, uniforms = {"u_time"},
		msl = #load("shaders/ground.metal"), spv_vs = #load("shaders/ground.vert.spv"), spv_fs = #load("shaders/ground.frag.spv"),
	},
	{
		name = "unit", file = "unit.fs", attrs = {.Pos, .UV, .Normal, .Color}, samplers = 0,
		uniforms = {"u_camera", "u_key_dir", "u_time", "u_tint", "u_fog_vis"},
		msl = #load("shaders/unit.metal"), spv_vs = #load("shaders/unit.vert.spv"), spv_fs = #load("shaders/unit.frag.spv"),
	},
	{
		name = "watercolor", file = "watercolor.fs", attrs = {.Pos, .UV, .Color}, samplers = 1,
		uniforms = {"texSize", "uSat", "uTint", "uVoid", "uHudPx", "uDpi"},
		msl = #load("shaders/watercolor.metal"), spv_vs = #load("shaders/default.vert.spv"), spv_fs = #load("shaders/watercolor.frag.spv"),
	},
}

@(private)
DEFAULT_SHADER :: 1

@(private)
programs_init :: proc() {
	append(&G.programs, Program{}) // id 0 = none
	program_create(&PROGRAMS[0])
}

@(private)
programs_release :: proc() {
	for &p in G.programs {
		if p.vs != nil {
			sdl.ReleaseGPUShader(G.dev, p.vs)
		}
		if p.fs != nil {
			sdl.ReleaseGPUShader(G.dev, p.fs)
		}
	}
}

@(private)
make_shader :: proc(code: []u8, entry: cstring, format: sdl.GPUShaderFormatFlag, stage: sdl.GPUShaderStage, samplers: int) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(G.dev, sdl.GPUShaderCreateInfo{
		code_size = uint(len(code)),
		code = raw_data(code),
		entrypoint = entry,
		format = {format},
		stage = stage,
		num_samplers = u32(samplers),
		num_uniform_buffers = 1,
	})
}

@(private)
program_create :: proc(def: ^Program_Def) -> u32 {
	p := Program{name = def.name, attrs = def.attrs, samplers = def.samplers, uniforms = def.uniforms}
	p.size = HEADER_SIZE + 16 * len(def.uniforms)
	formats := sdl.GetGPUShaderFormats(G.dev)
	if .MSL in formats {
		p.vs = make_shader(def.msl, "vs_main", .MSL, .VERTEX, 0)
		p.fs = make_shader(def.msl, "fs_main", .MSL, .FRAGMENT, def.samplers)
	} else if .SPIRV in formats {
		p.vs = make_shader(def.spv_vs, "main", .SPIRV, .VERTEX, 0)
		p.fs = make_shader(def.spv_fs, "main", .SPIRV, .FRAGMENT, def.samplers)
	}
	if p.vs == nil || p.fs == nil {
		fmt.eprintln("gfx: shader program failed:", def.name, sdl.GetError())
	}
	white := [4]f32{1, 1, 1, 1}
	mem.copy(&p.block[128], &white, 16)
	append(&G.programs, p)
	return u32(len(G.programs) - 1)
}

LoadShader :: proc(vsFileName, fsFileName: cstring) -> Shader {
	name := string(fsFileName != nil ? fsFileName : vsFileName)
	if i := strings.last_index_any(name, "/\\"); i >= 0 {
		name = name[i + 1:]
	}
	for &def in PROGRAMS {
		if def.file != "" && def.file == name {
			return Shader{id = c.uint(program_create(&def))}
		}
	}
	fmt.eprintln("gfx: no GPU program for shader", name)
	return {}
}

IsShaderValid :: proc(shader: Shader) -> bool {
	id := int(shader.id)
	return id > 0 && id < len(G.programs) && G.programs[id].vs != nil && G.programs[id].fs != nil
}

UnloadShader :: proc(shader: Shader) {
	// programs are tiny and pipelines are cached by program id: keep them until shutdown
}

GetShaderLocation :: proc(shader: Shader, uniformName: cstring) -> c.int {
	id := int(shader.id)
	if id <= 0 || id >= len(G.programs) {
		return -1
	}
	name := string(uniformName)
	switch name {
	case "mvp":
		return 0
	case "matModel":
		return 64
	case "colDiffuse":
		return 128
	}
	for u, i in G.programs[id].uniforms {
		if u == name {
			return c.int(HEADER_SIZE + 16 * i)
		}
	}
	return -1
}

SetShaderValue :: proc(shader: Shader, locIndex: c.int, value: rawptr, uniformType: ShaderUniformDataType) {
	id := int(shader.id)
	if id <= 0 || id >= len(G.programs) || locIndex < 0 || value == nil {
		return
	}
	size := 4
	#partial switch uniformType {
	case .VEC2, .IVEC2:
		size = 8
	case .VEC3, .IVEC3:
		size = 12
	case .VEC4, .IVEC4:
		size = 16
	}
	p := &G.programs[id]
	if int(locIndex) + size > p.size {
		return
	}
	mem.copy(&p.block[locIndex], value, size)
}

SetShaderValueMatrix :: proc(shader: Shader, locIndex: c.int, mat: Matrix) {
	id := int(shader.id)
	if id <= 0 || id >= len(G.programs) || locIndex < 0 {
		return
	}
	p := &G.programs[id]
	if int(locIndex) + 64 > p.size {
		return
	}
	m := MatrixToFloatV(mat)
	mem.copy(&p.block[locIndex], &m, 64)
}

// Snapshot of a program's uniform block with the built-ins filled for one draw.
@(private)
build_block :: proc(prog: u32, model: Matrix, col: Color) -> []u8 {
	p := &G.programs[prog]
	b := p.block[:p.size]
	mvp := clip_fix() * G.proj * G.view * model
	m0 := MatrixToFloatV(mvp)
	m1 := MatrixToFloatV(model)
	mem.copy(&b[0], &m0, 64)
	mem.copy(&b[64], &m1, 64)
	cd := [4]f32{f32(col.r) / 255, f32(col.g) / 255, f32(col.b) / 255, f32(col.a) / 255}
	mem.copy(&b[128], &cd, 16)
	w, h := current_target_size()
	fb := [4]f32{f32(w), f32(h), pass_flipped() ? 1 : 0, 0}
	mem.copy(&b[144], &fb, 16)
	return b
}
