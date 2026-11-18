// Low-resolution 3D target plus the watercolour post-process shader.
package main

import "core:os"
import "core:strings"
import rl "vendor:raylib"

PIXEL_MIN_WIDTH :: 640
PIXEL_MIN_HEIGHT :: 360

init_pixel_pipeline :: proc() {
	app.pixel_shader = load_pixel_shader()
	app.shader_ready = rl.IsShaderValid(app.pixel_shader)
	for arg in os.args {
		if arg == "--no-shader" {
			app.shader_ready = false
		}
	}
	if app.shader_ready {
		app.shader_tex_size = rl.GetShaderLocation(app.pixel_shader, "texSize")
	}
	ensure_pixel_target(PIXEL_MIN_WIDTH * 2, PIXEL_MIN_HEIGHT * 2)
}

load_pixel_shader :: proc() -> rl.Shader {
	paths := [2]string{"assets/shaders/watercolor.fs", "odin/assets/shaders/watercolor.fs"}
	for path in paths {
		if !os.exists(path) {
			continue
		}
		cpath := strings.clone_to_cstring(path, context.temp_allocator)
		shader := rl.LoadShader(nil, cpath)
		if rl.IsShaderValid(shader) {
			return shader
		}
	}
	return {}
}

ensure_pixel_target :: proc(width, height: int) {
	w := max(PIXEL_MIN_WIDTH, width)
	h := max(PIXEL_MIN_HEIGHT, height)
	if app.pixel.id > 0 && app.pixel_width == w && app.pixel_height == h {
		return
	}
	if app.pixel.id > 0 {
		rl.UnloadRenderTexture(app.pixel)
	}
		app.pixel = rl.LoadRenderTexture(i32(w), i32(h))
	rl.SetTextureFilter(app.pixel.texture, .BILINEAR)
	app.pixel_width = w
	app.pixel_height = h
}

draw_pixel_output :: proc() {
	if app.pixel.id == 0 {
		return
	}
	size := rl.Vector2{f32(app.pixel_width), f32(app.pixel_height)}
	if app.shader_ready {
		rl.SetShaderValue(app.pixel_shader, app.shader_tex_size, &size, .VEC2)
		rl.BeginShaderMode(app.pixel_shader)
	}
	source := rl.Rectangle{0, 0, f32(app.pixel_width), -f32(app.pixel_height)}
	dest := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	rl.DrawTexturePro(app.pixel.texture, source, dest, rl.Vector2{0, 0}, 0, rl.WHITE)
	if app.shader_ready {
		rl.EndShaderMode()
	}
}

unload_pixel_pipeline :: proc() {
	if app.pixel.id > 0 {
		rl.UnloadRenderTexture(app.pixel)
		app.pixel = {}
	}
	if app.shader_ready {
		rl.UnloadShader(app.pixel_shader)
		app.shader_ready = false
	}
}
