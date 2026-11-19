// DreamCraft RTS - Odin + raylib native client.
package main

import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import control "../control"
import g "../game"

Command_Mode :: enum {
	None,
	Move,
	Attack,
	Patrol,
}

WINDOW_TITLE :: "DreamCraft RTS - Tutorial Level 1 (Odin)"
DEV_WINDOW_TITLE :: "DEV - DreamCraft RTS - Tutorial Level 1 (Odin)"
DEV_BUILD :: #config(DREAMCRAFT_DEV, false)

App :: struct {
	game: g.Game,
	camera: rl.Camera3D,
	camera_target: rl.Vector3,
	pixel: rl.RenderTexture2D,
	pixel_width: int,
	pixel_height: int,
	pixel_shader: rl.Shader,
	shader_ready: bool,
	shader_tex_size: i32,
	unit_shader: Unit_Shader,
	ground_texture: rl.Texture2D,
	fog_texture: rl.Texture2D,
	ground_shader: rl.Shader,
	ground_time: i32,
	ground_ready: bool,
	ground_model: rl.Model,
	fog_pixels: [g.GRID_CELLS]rl.Color,
	fog_last_tick: u64,
	fog_dirty: bool,
	shadow_texture: rl.Texture2D,
	shadow_model: rl.Model,
	shadow_ready: bool,
	env: Env_Assets,
	slash: Slash_Vfx,
	accumulator: f64,
	menu_open: bool,
	command_mode: Command_Mode,
	dragging: bool,
	drag_start: rl.Vector2,
	minimap: rl.Texture2D,
	minimap_pixels: [g.GRID_CELLS]rl.Color,
	move_button: rl.Rectangle,
	attack_button: rl.Rectangle,
	patrol_button: rl.Rectangle,
	stop_button: rl.Rectangle,
	cmd_fx: [MAX_CMD_FX]Cmd_Fx,
	cmd_fx_next: int,
	minimap_rect: rl.Rectangle,
	icons: Icon_Atlas,
	mode: App_Mode,
	editor_button: rl.Rectangle,
	retry_button: rl.Rectangle,
	resume_button: rl.Rectangle,
	editor: Model_Editor_State,
	last_fps: int,
	camera_follow: bool,
	edge_armed: bool,
	cursor_inside: bool,
	prev_raw_on_screen: bool,
	prev_raw_mouse: rl.Vector2,
	last_cursor: rl.MouseCursor,
	cursor_initialized: bool,
	zoom: f32,
	target_zoom: f32,
	camera_vel: rl.Vector3,
	edge_dir: rl.Vector2,
	grip_active: bool,
	grip_via_space: bool,
	grip_moved: bool,
	grip_last_mouse: rl.Vector2,
	minimap_dragging: bool,
	probe: Mouse_Probe,
	models: [g.MAX_UNITS]Unit_Model,
	visuals: [g.MAX_UNITS]Unit_Visual,
	last_tick: u64,
	server: control.Server,
	serving: bool,
}

app: App

main :: proc() {
	sheet := has_arg(os.args, "--sheet")
	open_window(sheet)
	defer rl.CloseWindow()

	g.game_init(&app.game)
	if port, ok := find_control_port(os.args); ok {
		app.serving = control.server_start(&app.server, &app.game, port, capture_screenshot)
		if app.serving {
			app.server.camera_state = capture_camera_snapshot
			app.server.mouse_input = handle_mouse_probe
			app.server.client_command = handle_client_command
		}
	}
	defer if app.serving {
		control.server_close(&app.server)
	}
	init_minimap_texture()
	init_pixel_pipeline()
	init_unit_shader()
	if sheet {
		run_model_sheet()
		return
	}
	init_world_assets()
	if edit_id, ok := find_editor_arg(os.args); ok {
		if edit_id == "" {
			editor_open_picker()
		} else {
			_ = editor_open_model(edit_id, false)
		}
	}
	for !rl.WindowShouldClose() {
		step_client_frame()
	}
	unload_world_assets()
}

@(private)
open_window :: proc(sheet: bool) {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	dev := DEV_BUILD || is_dev_executable()
	window_title: cstring = WINDOW_TITLE
	if dev {
		window_title = DEV_WINDOW_TITLE
	}
	width := sheet ? SHEET_SIZE : 1280
	height := sheet ? SHEET_SIZE : 720
	rl.InitWindow(i32(width), i32(height), window_title)
	if dev {
		fmt.println("DEV build window:", window_title)
	}
	rl.SetWindowMinSize(800, 600)
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)
}

@(private)
step_client_frame :: proc() {
	dt := f64(rl.GetFrameTime())
	probe_begin_frame()
	update_layout()
	handle_input()
	if app.mode == .Game || app.mode == .Pause_Menu {
		update_simulation(dt)
		update_camera(dt)
	}
	update_cursor()
	probe_end_frame()
	if app.mode == .Game || app.mode == .Pause_Menu {
		update_warrior_visuals(f32(dt))
		update_command_fx(f32(dt))
		update_minimap_pixels()
	}
	draw_frame()
	if app.serving {
		control.server_poll(&app.server)
	}
	free_all(context.temp_allocator)
}

@(private)
init_world_assets :: proc() {
	init_icons()
	init_ground()
	init_shadow_assets()
	init_env_assets()
	init_slash_vfx()
	init_warrior_assets()
	reset_warrior_visuals()
	app.camera_follow = true
	app.zoom = DEFAULT_ZOOM
	if zoom, ok := find_zoom(os.args); ok {
		app.zoom = zoom
	}
	app.target_zoom = app.zoom
	reset_camera()
	update_layout()
}

@(private)
unload_world_assets :: proc() {
	editor_cleanup()
	unload_icons()
	unload_warrior_assets()
	unload_slash_vfx()
	unload_env_assets()
	unload_shadow_assets()
	unload_ground()
	unload_pixel_pipeline()
	unload_unit_shader()
	rl.UnloadTexture(app.minimap)
}

init_minimap_texture :: proc() {
	image := rl.GenImageColor(g.GRID_W, g.GRID_H, rl.BLACK)
	app.minimap = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	rl.SetTextureFilter(app.minimap, .POINT)
}

update_layout :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	ensure_pixel_target(int(width), int(height))
	app.minimap_rect = rl.Rectangle{20, height - 150, 200, 125}
	app.move_button = rl.Rectangle{width - 236, height - 100, 108, 34}
	app.attack_button = rl.Rectangle{width - 120, height - 100, 108, 34}
	app.patrol_button = rl.Rectangle{width - 236, height - 58, 108, 34}
	app.stop_button = rl.Rectangle{width - 120, height - 58, 108, 34}
	app.resume_button = rl.Rectangle{width * 0.5 - 130, height * 0.5 - 46, 260, 38}
	app.editor_button = rl.Rectangle{width * 0.5 - 130, height * 0.5 + 4, 260, 38}
	app.retry_button = rl.Rectangle{width * 0.5 - 130, height * 0.5 + 54, 260, 38}
}

update_simulation :: proc(dt: f64) {
	STEP :: 1.0 / 60.0
	app.accumulator += min(dt, 0.25)
	steps := 0
	for app.accumulator >= STEP && steps < 5 {
		g.sim_tick(&app.game)
		app.accumulator -= STEP
		steps += 1
	}
}

// The dev binary must always be identifiable, even when built without
// -define:DREAMCRAFT_DEV. `bin/dreamcraft-dev` keeps the DEV prefix.
is_dev_executable :: proc() -> bool {
	if len(os.args) == 0 {
		return false
	}
	name := os.args[0]
	base := name
	for i := len(name) - 1; i >= 0; i -= 1 {
		if name[i] == '/' || name[i] == '\\' {
			base = name[i + 1:]
			break
		}
	}
	return strings.contains(base, "dev")
}


has_arg :: proc(args: []string, flag: string) -> bool {
	for arg in args {
		if arg == flag {
			return true
		}
	}
	return false
}

format_text :: proc(buffer: []u8, format: string, args: ..any) -> cstring {
	assert(len(buffer) > 0)
	text := fmt.bprintf(buffer[:len(buffer) - 1], format, ..args)
	buffer[len(text)] = 0
	return cast(cstring)raw_data(buffer)
}


// --zoom=<n> is a dev aid for inspecting models up close.
find_zoom :: proc(args: []string) -> (zoom: f32, ok: bool) {
	for arg in args {
		if !strings.has_prefix(arg, "--zoom=") {
			continue
		}
		value := arg[len("--zoom="):]
		parsed: f32 = 0
		seen := false
		for ch in value {
			if ch == '.' || (ch >= '0' && ch <= '9') {
				seen = true
			} else {
				return 0, false
			}
		}
		if !seen {
			return 0, false
		}
		parsed = f32(parse_decimal(value))
		if parsed <= 0 {
			return 0, false
		}
		return parsed, true
	}
	return 0, false
}

@(private)
parse_decimal :: proc(text: string) -> f64 {
	whole: f64 = 0
	fraction: f64 = 0
	scale: f64 = 0.1
	after_point := false
	for ch in text {
		if ch == '.' {
			after_point = true
			continue
		}
		digit := f64(ch - '0')
		if after_point {
			fraction += digit * scale
			scale *= 0.1
		} else {
			whole = whole * 10 + digit
		}
	}
	return whole + fraction
}

find_editor_arg :: proc(args: []string) -> (id: string, ok: bool) {
	for arg in args {
		if arg == "--editor" || arg == "--model-editor" {
			return "", true
		}
		if strings.has_prefix(arg, "--editor=") {
			return arg[len("--editor="):], true
		}
	}
	return "", false
}

find_control_port :: proc(args: []string) -> (port: int, ok: bool) {
	for arg in args {
		if arg == "--control" {
			return 7777, true
		}
		if strings.has_prefix(arg, "--control=") {
			value := arg[len("--control="):]
			parsed := 0
			if len(value) == 0 {
				return 0, false
			}
			for ch in value {
				if ch < '0' || ch > '9' {
					return 0, false
				}
				parsed = parsed * 10 + int(ch - '0')
			}
			return parsed, true
		}
	}
	return 0, false
}

capture_screenshot :: proc(_: rawptr) -> ([]byte, bool) {
	image := rl.LoadImageFromScreen()
	defer rl.UnloadImage(image)
	size: c.int
	raw := rl.ExportImageToMemory(image, ".png", &size)
	if raw == nil || size <= 0 {
		return nil, false
	}
	defer rl.MemFree(raw)
	source := mem.slice_ptr(cast(^u8)raw, int(size))
	data := make([]byte, len(source))
	copy(data, source)
	return data, true
}
