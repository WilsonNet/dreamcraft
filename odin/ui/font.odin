// Exact 2x-supersampled (4x SSAA), sRGB-gamma-corrected, pure-white-RGB font engine with embedded SIL-OFL fonts & shaders.
package ui

import "core:c"
import "core:math"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

CHRONICLE_TTF :: #load("../assets/fonts/ChronicleSerif-Bold.ttf", []u8)
LATO_TTF      :: #load("../assets/fonts/Lato-Regular.ttf", []u8)
MONO_REG_TTF  :: #load("../assets/fonts/SourceCodePro-Regular.ttf", []u8)
MONO_BOLD_TTF :: #load("../assets/fonts/SourceCodePro-Bold.ttf", []u8)

UI_SDF_VS_EMBED  :: #load("../assets/shaders/ui_sdf.vs", cstring)
UI_SDF_FS_EMBED  :: #load("../assets/shaders/ui_sdf.fs", cstring)
UI_CLIP_FS_EMBED :: #load("../assets/shaders/ui_clip_tex.fs", cstring)

FONT_ATLAS_PAD :: 3
FONT_OVERSAMPLE :: 2
FONT_STEP_PX := [FONT_SIZE_STEPS]i32{11, 12, 13, 14, 16, 18, 24}

font_init :: proc(fp: ^Font_Pack, use_shaders: bool) {
	_ = use_shaders
	fp^ = {}
	dpi := f32(1.0)
	if rl.IsWindowReady() {
		dpi = clamp(math.round(rl.GetWindowScaleDPI().x), 1.0, 2.0)
	}
	fp.dpi_scale = dpi
	for step in 0..<FONT_SIZE_STEPS {
		// Bake at exact 2x physical resolution so DrawTextEx at FONT_STEP_PX[step] performs
		// a phase-locked 2:1 (4x SSAA) hardware bilinear resolve with 0.5px metric precision.
		px := c.int(math.round(f32(FONT_STEP_PX[step] * FONT_OVERSAMPLE) * dpi))
		fp.baked[.Display_Serif][step] = build_smooth_font(CHRONICLE_TTF, px, 0.72, false)
		fp.baked[.Sans_Regular][step]  = build_smooth_font(LATO_TTF, px, 0.70, false)
		fp.baked[.Sans_Bold][step]     = build_smooth_font(LATO_TTF, px, 0.62, true)
		fp.baked[.Mono_Regular][step]  = build_smooth_font(MONO_REG_TTF, px, 0.72, false)
		fp.baked[.Mono_Bold][step]     = build_smooth_font(MONO_BOLD_TTF, px, 0.68, false)
	}
	fp.fonts_ready = rl.IsFontValid(fp.baked[.Sans_Regular][0])
}

font_unload :: proc(fp: ^Font_Pack) {
	for idx in Font_Atlas_Idx {
		for step in 0..<FONT_SIZE_STEPS {
			if rl.IsFontValid(fp.baked[idx][step]) {
				rl.UnloadFont(fp.baked[idx][step])
			}
		}
	}
	fp^ = {}
}

@(private)
build_smooth_font :: proc(data: []u8, px: c.int, gamma: f32, bolden: bool) -> rl.Font {
	if len(data) == 0 || px <= 0 {
		return {}
	}
	glyph_count: c.int = 0
	glyphs := rl.LoadFontData(raw_data(data), c.int(len(data)), px, nil, 95, .DEFAULT, &glyph_count)
	if glyphs == nil || glyph_count <= 0 {
		return {}
	}
	f := rl.Font{
		baseSize     = px,
		glyphCount   = glyph_count,
		glyphPadding = FONT_ATLAS_PAD,
		glyphs       = glyphs,
	}
	atlas := rl.GenImageFontAtlas(f.glyphs, &f.recs, f.glyphCount, f.baseSize, f.glyphPadding, 0)
	smooth_atlas_pixels(&atlas, f.recs, int(f.glyphCount), gamma, bolden)
	unpad_atlas_recs(&f)
	f.texture = rl.LoadTextureFromImage(atlas)
	rl.UnloadImage(atlas)
	if rl.IsTextureValid(f.texture) {
		rl.SetTextureFilter(f.texture, .BILINEAR)
		rl.SetTextureWrap(f.texture, .CLAMP)
	}
	return f
}

@(private)
unpad_atlas_recs :: proc(f: ^rl.Font) {
	pad := f32(f.glyphPadding)
	for i in 0..<int(f.glyphCount) {
		rl.UnloadImage(f.glyphs[i].image)
		f.glyphs[i].image = {}
		f.recs[i].x += pad
		f.recs[i].y += pad
		f.recs[i].width -= 2.0 * pad
		f.recs[i].height -= 2.0 * pad
	}
}

@(private)
smooth_atlas_pixels :: proc(atlas: ^rl.Image, recs: [^]rl.Rectangle, count: int, gamma: f32, bolden: bool) {
	rl.ImageFormat(atlas, .UNCOMPRESSED_R8G8B8A8)
	w := int(atlas.width)
	h := int(atlas.height)
	if w <= 0 || h <= 0 || atlas.data == nil {
		return
	}
	pixels := (cast([^]u8)atlas.data)[:w * h * 4]
	orig := make([]u8, w * h, context.temp_allocator)
	for i in 0..<(w * h) {
		orig[i] = pixels[i * 4 + 3]
		pixels[i * 4 + 0] = 255
		pixels[i * 4 + 1] = 255
		pixels[i * 4 + 2] = 255
	}
	if recs == nil {
		return
	}
	for g in 0..<count {
		smooth_glyph_rect(pixels, orig, w, h, recs[g], gamma, bolden)
	}
}

@(private)
smooth_glyph_rect :: proc(pixels, orig: []u8, w, h: int, r: rl.Rectangle, gamma: f32, bolden: bool) {
	x0 := clamp(int(r.x), 0, w)
	y0 := clamp(int(r.y), 0, h)
	x1 := clamp(int(r.x + r.width), 0, w)
	y1 := clamp(int(r.y + r.height), 0, h)
	for y in y0..<y1 {
		for x in x0..<x1 {
			c := f32(orig[y * w + x]) / 255.0
			val := c
			if bolden && x > x0 {
				l := f32(orig[y * w + x - 1]) / 255.0
				val = max(c, c * 0.58 + l * 0.42)
			}
			if val > 0.0 {
				out_a := clamp(math.pow(val, gamma), 0.0, 1.0)
				pixels[(y * w + x) * 4 + 3] = u8(math.round(out_a * 255.0))
			}
		}
	}
}

@(private)
role_atlas :: proc(role: Font_Role) -> Font_Atlas_Idx {
	switch role {
	case .Heading:
		return .Display_Serif
	case .Medium, .Bold:
		return .Sans_Bold
	case .Mono:
		return .Mono_Regular
	case .Mono_Bold:
		return .Mono_Bold
	case .Body, .Label:
		return .Sans_Regular
	}
	return .Sans_Regular
}

@(private)
nearest_size_step :: proc(size: f32) -> (step: int, snapped_size: f32) {
	best_idx := 0
	best_diff := abs(size - f32(FONT_STEP_PX[0]))
	for i in 1..<FONT_SIZE_STEPS {
		diff := abs(size - f32(FONT_STEP_PX[i]))
		if diff < best_diff {
			best_diff = diff
			best_idx = i
		}
	}
	return best_idx, f32(FONT_STEP_PX[best_idx])
}

@(private)
role_spacing :: proc(role: Font_Role, snapped_size: f32) -> f32 {
	if role == .Heading {
		return snapped_size >= 18.0 ? 1.5 : 1.0
	}
	if role == .Mono || role == .Mono_Bold {
		return 0.5
	}
	return 0.5
}

@(private)
select_font :: proc(fp: ^Font_Pack, role: Font_Role, size: f32) -> (rl.Font, f32, f32) {
	step, snapped := nearest_size_step(size)
	sp := role_spacing(role, snapped)
	if !fp.fonts_ready {
		return rl.GetFontDefault(), snapped, sp
	}
	slot := role_atlas(role)
	f := fp.baked[slot][step]
	if rl.IsFontValid(f) {
		return f, snapped, sp
	}
	return fp.baked[.Sans_Regular][step], snapped, sp
}

measure_font_text :: proc(fp: ^Font_Pack, text: cstring, role: Font_Role, size: f32) -> [2]f32 {
	if len(text) == 0 {
		return {0, size}
	}
	f, snapped, sp := select_font(fp, role, size)
	v := rl.MeasureTextEx(f, text, snapped, sp)
	return {math.ceil(v.x), math.ceil(max(v.y, snapped))}
}

draw_font_text :: proc(fp: ^Font_Pack, text: cstring, pos: rl.Vector2, role: Font_Role, size: f32, col: rl.Color) {
	if len(text) == 0 || col.a == 0 {
		return
	}
	f, snapped, sp := select_font(fp, role, size)
	dpi := max(fp.dpi_scale, 1.0)
	sx := math.round(pos.x * dpi) / dpi
	sy := math.round(pos.y * dpi) / dpi
	if col.a >= 140 {
		sh_a := u8(int(col.a) * 110 / 255)
		rl.DrawTextEx(f, text, {sx, sy + 1.0}, snapped, sp, rl.Color{6, 4, 3, sh_a})
	}
	rl.DrawTextEx(f, text, {sx, sy}, snapped, sp, col)
}

load_shader_file :: proc(vs_name, fs_name: string) -> (rl.Shader, bool) {
	prefixes := [4]string{"assets/shaders/", "odin/assets/shaders/", "../assets/shaders/", "../../assets/shaders/"}
	for prefix in prefixes {
		fs_path := strings.concatenate({prefix, fs_name}, context.temp_allocator)
		if !os.exists(fs_path) {
			continue
		}
		vs_cstr: cstring = nil
		if len(vs_name) > 0 {
			vs_path := strings.concatenate({prefix, vs_name}, context.temp_allocator)
			if !os.exists(vs_path) {
				continue
			}
			vs_cstr = strings.clone_to_cstring(vs_path, context.temp_allocator)
		}
		fs_cstr := strings.clone_to_cstring(fs_path, context.temp_allocator)
		sh := rl.LoadShader(vs_cstr, fs_cstr)
		if rl.IsShaderValid(sh) {
			return sh, true
		}
	}
	return load_embedded_shader(vs_name, fs_name)
}

@(private)
load_embedded_shader :: proc(vs_name, fs_name: string) -> (rl.Shader, bool) {
	if fs_name == "ui_sdf.fs" && vs_name == "ui_sdf.vs" {
		sh := rl.LoadShaderFromMemory(UI_SDF_VS_EMBED, UI_SDF_FS_EMBED)
		return sh, rl.IsShaderValid(sh)
	}
	if fs_name == "ui_clip_tex.fs" {
		sh := rl.LoadShaderFromMemory(nil, UI_CLIP_FS_EMBED)
		return sh, rl.IsShaderValid(sh)
	}
	return {}, false
}
