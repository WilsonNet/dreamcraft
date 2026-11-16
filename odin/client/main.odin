// DreamCraft RTS - Odin + raylib native client.
package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import control "../control"
import g "../game"

Command_Mode :: enum {
	None,
	Move,
	Patrol,
}

App :: struct {
	game: g.Game,
	camera: rl.Camera2D,
	camera_pos: rl.Vector2,
	accumulator: f64,
	menu_open: bool,
	command_mode: Command_Mode,
	patrol_first: g.Grid_Pos,
	dragging: bool,
	drag_start: rl.Vector2,
	minimap: rl.Texture2D,
	minimap_pixels: [g.GRID_CELLS]rl.Color,
	move_button: rl.Rectangle,
	patrol_button: rl.Rectangle,
	minimap_rect: rl.Rectangle,
	retry_button: rl.Rectangle,
	resume_button: rl.Rectangle,
	last_fps: int,
	camera_follow: bool,
	server: control.Server,
	serving: bool,
}

app: App

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "DreamCraft RTS - Tutorial Level 1 (Odin)")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(800, 600)
	rl.SetTargetFPS(60)
	rl.SetExitKey(.KEY_NULL)

	g.game_init(&app.game)
	if port, ok := find_control_port(os.args); ok {
		app.serving = control.server_start(&app.server, &app.game, port, capture_screenshot)
	}
	defer if app.serving {
		control.server_close(&app.server)
	}
	init_minimap_texture()
	app.camera_follow = true
	reset_camera()
	update_layout()

	for !rl.WindowShouldClose() {
		dt := f64(rl.GetFrameTime())
		update_layout()
		handle_input()
		update_simulation(dt)
		update_camera(dt)
		update_minimap_pixels()
		draw_frame()
		if app.serving {
			control.server_poll(&app.server)
		}
		free_all(context.temp_allocator)
	}
	rl.UnloadTexture(app.minimap)
}

init_minimap_texture :: proc() {
	image := rl.GenImageColor(g.GRID_W, g.GRID_H, rl.BLACK)
	app.minimap = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	rl.SetTextureFilter(app.minimap, .POINT)
}

reset_camera :: proc() {
	position, ok := g.game_player_position(&app.game)
	if !ok {
		position = g.START_POS
	}
	world := g.grid_to_world(position)
	app.camera_pos = rl.Vector2{g.fp_to_f32(world.x), g.fp_to_f32(world.y)}
	app.camera_follow = true
	app.camera = rl.Camera2D{
		offset = rl.Vector2{0, 0},
		target = app.camera_pos,
		rotation = 0,
		zoom = 1,
	}
}

update_layout :: proc() {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	app.camera.offset = rl.Vector2{width * 0.5, height * 0.5}
	app.minimap_rect = rl.Rectangle{20, height - 150, 200, 125}
	app.move_button = rl.Rectangle{width - 104, height - 52, 84, 32}
	app.patrol_button = rl.Rectangle{width - 104, height - 92, 84, 32}
	app.retry_button = rl.Rectangle{width * 0.5 - 150, height * 0.5 + 20, 140, 36}
	app.resume_button = rl.Rectangle{width * 0.5 + 10, height * 0.5 + 20, 140, 36}
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

screen_to_grid :: proc(screen: rl.Vector2) -> g.Grid_Pos {
	world := rl.GetScreenToWorld2D(screen, app.camera)
	gx := i32(math.floor(f64((world.x - f32(g.WORLD_MIN_X)) / f32(g.CELL_SIZE))))
	gy := i32(math.floor(f64((world.y - f32(g.WORLD_MIN_Y)) / f32(g.CELL_SIZE))))
	return g.Grid_Pos{x = clamp(gx, 0, g.GRID_W - 1), y = clamp(gy, 0, g.GRID_H - 1)}
}

world_vector :: proc(position: g.Grid_Pos) -> rl.Vector2 {
	world := g.grid_to_world(position)
	return rl.Vector2{g.fp_to_f32(world.x), g.fp_to_f32(world.y)}
}

cell_rect :: proc(position: g.Grid_Pos) -> rl.Rectangle {
	return rl.Rectangle{
		x = f32(g.WORLD_MIN_X + int(position.x) * g.CELL_SIZE),
		y = f32(g.WORLD_MIN_Y + int(position.y) * g.CELL_SIZE),
		width = f32(g.CELL_SIZE),
		height = f32(g.CELL_SIZE),
	}
}

clamp_camera :: proc(position: rl.Vector2) -> rl.Vector2 {
	half_width := f32(g.WORLD_MAX_X + 200)
	half_height := f32(g.WORLD_MAX_Y + 200)
	return rl.Vector2{clamp(position.x, -half_width, half_width), clamp(position.y, -half_height, half_height)}
}

format_text :: proc(buffer: []u8, format: string, args: ..any) -> cstring {
	assert(len(buffer) > 0)
	text := fmt.bprintf(buffer[:len(buffer) - 1], format, ..args)
	buffer[len(text)] = 0
	return cast(cstring)raw_data(buffer)
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
