// Low-resolution 3D target plus the watercolour post-process shader.
package main

import "core:os"
import rl "../gfx"

PIXEL_MIN_WIDTH :: 640
PIXEL_MIN_HEIGHT :: 360

@(private = "file")
pixel_locs: struct {
	sat, tint, void, hud, dpi: i32,
}

// World half of the shared grade (the HUD half is vh.ctx.grade = GRADE_PAINTED).
WORLD_SATURATION :: f32(0.84)
WORLD_TINT :: rl.Vector3{1.0, 0.96, 0.88}
WORLD_VOID :: rl.Vector3{0.075, 0.062, 0.048}

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
		pixel_locs = {
			sat  = rl.GetShaderLocation(app.pixel_shader, "uSat"),
			tint = rl.GetShaderLocation(app.pixel_shader, "uTint"),
			void = rl.GetShaderLocation(app.pixel_shader, "uVoid"),
			hud  = rl.GetShaderLocation(app.pixel_shader, "uHudPx"),
			dpi  = rl.GetShaderLocation(app.pixel_shader, "uDpi"),
		}
	}
	ensure_pixel_target(PIXEL_MIN_WIDTH * 2, PIXEL_MIN_HEIGHT * 2)
}

load_pixel_shader :: proc() -> rl.Shader {
	// embedded GPU program (gfx/shaders/watercolor.*)
	shader := rl.LoadShader(nil, "watercolor.fs")
	return rl.IsShaderValid(shader) ? shader : {}
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
		sat := WORLD_SATURATION
		tint := WORLD_TINT
		void := WORLD_VOID
		dpi := rl.GetWindowScaleDPI().y
		if dpi <= 0 {
			dpi = 1
		}
		hud := (app.mode == .Game || app.mode == .Pause_Menu) ? HUD_HEIGHT * dpi : 0
		rl.SetShaderValue(app.pixel_shader, pixel_locs.sat, &sat, .FLOAT)
		rl.SetShaderValue(app.pixel_shader, pixel_locs.tint, &tint, .VEC3)
		rl.SetShaderValue(app.pixel_shader, pixel_locs.void, &void, .VEC3)
		rl.SetShaderValue(app.pixel_shader, pixel_locs.hud, &hud, .FLOAT)
		rl.SetShaderValue(app.pixel_shader, pixel_locs.dpi, &dpi, .FLOAT)
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
