// Painterly model shader: loading and per-frame uniforms.
package main

import "core:os"
import "core:strings"
import rl "vendor:raylib"

Unit_Shader :: struct {
	shader:  rl.Shader,
	ready:   bool,
	camera:  i32,
	time:    i32,
	key_dir: i32,
}

// Light comes from the upper-left of the screen, a little toward the camera.
KEY_LIGHT_DIR :: rl.Vector3{0.46, 0.78, 0.48}

init_unit_shader :: proc() {
	loaded, ok := load_unit_shader()
	if !ok {
		return
	}
	app.unit_shader = loaded
	app.unit_shader.ready = true
	app.unit_shader.camera = rl.GetShaderLocation(loaded.shader, "u_camera")
	app.unit_shader.time = rl.GetShaderLocation(loaded.shader, "u_time")
	app.unit_shader.key_dir = rl.GetShaderLocation(loaded.shader, "u_key_dir")
}

@(private)
load_unit_shader :: proc() -> (Unit_Shader, bool) {
	prefixes := [2]string{"assets/shaders/", "odin/assets/shaders/"}
	for prefix in prefixes {
		vs := strings.concatenate({prefix, "unit.vs"}, context.temp_allocator)
		fs := strings.concatenate({prefix, "unit.fs"}, context.temp_allocator)
		if !os.exists(vs) || !os.exists(fs) {
			continue
		}
		shader := rl.LoadShader(
			strings.clone_to_cstring(vs, context.temp_allocator),
			strings.clone_to_cstring(fs, context.temp_allocator),
		)
		if rl.IsShaderValid(shader) {
			return Unit_Shader{shader = shader}, true
		}
	}
	return {}, false
}

set_unit_shader_uniforms :: proc(time: f32) {
	if !app.unit_shader.ready {
		return
	}
	camera := app.camera.position
	direction := rl.Vector3Normalize(KEY_LIGHT_DIR)
	clock := time
	rl.SetShaderValue(app.unit_shader.shader, app.unit_shader.camera, &camera, .VEC3)
	rl.SetShaderValue(app.unit_shader.shader, app.unit_shader.time, &clock, .FLOAT)
	rl.SetShaderValue(app.unit_shader.shader, app.unit_shader.key_dir, &direction, .VEC3)
}

unload_unit_shader :: proc() {
	if app.unit_shader.ready {
		rl.UnloadShader(app.unit_shader.shader)
		app.unit_shader = {}
	}
}
