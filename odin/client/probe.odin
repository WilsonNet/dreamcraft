// Camera & mouse telemetry and synthetic input probe for live validation.
package main

import "core:encoding/json"
import "core:fmt"
import rl "../gfx"
import control "../control"
import art "./art"

Mouse_Probe :: struct {
	active:      bool,
	mouse:       rl.Vector2,
	focused:     bool,
	on_screen:   bool,
	left:        bool,
	middle:      bool,
	space:       bool,
	wheel_y:     f32,
	prev_left:   bool,
	prev_middle: bool,
	just_left_down:   bool,
	just_left_up:     bool,
	just_middle_down: bool,
}

Mouse_Command :: struct {
	action:    string `json:"action"`,
	x:         f32    `json:"x"`,
	y:         f32    `json:"y"`,
	wheel:     f32    `json:"wheel"`,
	focused:   bool   `json:"focused"`,
	on_screen: bool   `json:"on_screen"`,
	left:      bool   `json:"left"`,
	middle:    bool   `json:"middle"`,
	space:     bool   `json:"space"`,
	steps:     int    `json:"steps"`,
}

Camera_Snapshot :: struct {
	ok:               bool    `json:"ok"`,
	target:           [3]f32  `json:"target"`,
	vel:              [3]f32  `json:"vel"`,
	zoom:             f32     `json:"zoom"`,
	target_zoom:      f32     `json:"target_zoom"`,
	fovy:             f32     `json:"fovy"`,
	follow:           bool    `json:"follow"`,
	edge_armed:       bool    `json:"edge_armed"`,
	edge_dir:         [2]f32  `json:"edge_dir"`,
	grip_active:      bool    `json:"grip_active"`,
	grip_moved:       bool    `json:"grip_moved"`,
	minimap_dragging: bool    `json:"minimap_dragging"`,
	dragging:         bool    `json:"dragging"`,
	menu_open:        bool    `json:"menu_open"`,
	window_focused:   bool    `json:"window_focused"`,
	cursor_on_screen: bool    `json:"cursor_on_screen"`,
	cursor_inside:    bool    `json:"cursor_inside"`,
	screen:           [2]f32  `json:"screen"`,
	render:           [2]f32  `json:"render"`,
	scale_dpi:        [2]f32  `json:"scale_dpi"`,
	window_pos:       [2]f32  `json:"window_pos"`,
	mouse:            [2]f32  `json:"mouse"`,
	probe_active:     bool    `json:"probe_active"`,
	app_mode:         string  `json:"app_mode"`,
	editor_model:     string  `json:"editor_model"`,
	help_open:        bool    `json:"help_open"`,
	minimap:          [4]f32  `json:"minimap"`, // live HUD rect: x, y, w, h (logical px)
}

input_mouse_pos :: proc() -> rl.Vector2 {
	if app.probe.active {
		return app.probe.mouse
	}
	return rl.GetMousePosition()
}

input_window_focused :: proc() -> bool {
	if app.probe.active {
		return app.probe.focused
	}
	return rl.IsWindowFocused()
}

input_cursor_on_screen :: proc() -> bool {
	if app.probe.active {
		return app.probe.on_screen
	}
	return rl.IsCursorOnScreen()
}

input_wheel_y :: proc() -> f32 {
	if app.probe.active {
		return app.probe.wheel_y
	}
	return rl.GetMouseWheelMoveV().y
}

input_left_pressed :: proc() -> bool {
	if app.probe.active {
		return app.probe.just_left_down
	}
	return rl.IsMouseButtonPressed(.LEFT)
}

input_left_released :: proc() -> bool {
	if app.probe.active {
		return app.probe.just_left_up
	}
	return rl.IsMouseButtonReleased(.LEFT)
}

input_left_down :: proc() -> bool {
	if app.probe.active {
		return app.probe.left
	}
	return rl.IsMouseButtonDown(.LEFT)
}

input_middle_pressed :: proc() -> bool {
	if app.probe.active {
		return app.probe.just_middle_down
	}
	return rl.IsMouseButtonPressed(.MIDDLE)
}

input_middle_down :: proc() -> bool {
	if app.probe.active {
		return app.probe.middle
	}
	return rl.IsMouseButtonDown(.MIDDLE)
}

input_space_down :: proc() -> bool {
	if app.probe.active {
		return app.probe.space
	}
	return rl.IsKeyDown(.SPACE)
}

probe_begin_frame :: proc() {
	if !app.probe.active {
		return
	}
	app.probe.just_left_down = app.probe.left && !app.probe.prev_left
	app.probe.just_left_up = !app.probe.left && app.probe.prev_left
	app.probe.just_middle_down = app.probe.middle && !app.probe.prev_middle
	app.probe.prev_left = app.probe.left
	app.probe.prev_middle = app.probe.middle
}

probe_end_frame :: proc() {
	if !app.probe.active {
		return
	}
	app.probe.wheel_y = 0
	app.probe.just_left_down = false
	app.probe.just_left_up = false
	app.probe.just_middle_down = false
}

// macOS GLFW IsCursorOnScreen() only updates on NSTrackingArea enter/exit and stays
// false when the window spawns under the cursor; track live cursor coordinates too.
update_cursor_inside :: proc(mouse: rl.Vector2, width, height: f32, focused, raw_on_screen: bool) -> bool {
	if !focused || width <= 0 || height <= 0 {
		app.cursor_inside = false
		app.prev_raw_on_screen = raw_on_screen
		app.prev_raw_mouse = mouse
		return false
	}
	if app.probe.active {
		app.cursor_inside = raw_on_screen
		return raw_on_screen
	}
	in_rect := mouse.x >= 0 && mouse.x <= width && mouse.y >= 0 && mouse.y <= height
	if raw_on_screen {
		app.cursor_inside = in_rect
	} else if (app.prev_raw_on_screen && !raw_on_screen) || !in_rect {
		app.cursor_inside = false
	} else if mouse.x != app.prev_raw_mouse.x || mouse.y != app.prev_raw_mouse.y ||
	          rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.MIDDLE) || rl.IsMouseButtonPressed(.RIGHT) {
		app.cursor_inside = true
	}
	app.prev_raw_on_screen = raw_on_screen
	app.prev_raw_mouse = mouse
	return app.cursor_inside
}

capture_camera_snapshot :: proc(_: rawptr) -> ([]byte, bool) {
	win_pos := rl.GetWindowPosition()
	dpi := rl.GetWindowScaleDPI()
	mouse := input_mouse_pos()
	snap := Camera_Snapshot{
		ok               = true,
		target           = [3]f32{app.camera_target.x, app.camera_target.y, app.camera_target.z},
		vel              = [3]f32{app.camera_vel.x, app.camera_vel.y, app.camera_vel.z},
		zoom             = app.zoom,
		target_zoom      = app.target_zoom,
		fovy             = app.camera.fovy,
		follow           = app.camera_follow,
		edge_armed       = app.edge_armed,
		edge_dir         = [2]f32{app.edge_dir.x, app.edge_dir.y},
		grip_active      = app.grip_active,
		grip_moved       = app.grip_moved,
		minimap_dragging = app.minimap_dragging,
		dragging         = app.dragging,
		menu_open        = app.menu_open,
		window_focused   = input_window_focused(),
		cursor_on_screen = input_cursor_on_screen(),
		cursor_inside    = app.cursor_inside,
		screen           = [2]f32{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		render           = [2]f32{f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())},
		scale_dpi        = [2]f32{dpi.x, dpi.y},
		window_pos       = [2]f32{win_pos.x, win_pos.y},
		mouse            = [2]f32{mouse.x, mouse.y},
		probe_active     = app.probe.active,
		app_mode         = app_mode_name(app.mode),
		editor_model     = app.editor.mesh_loaded ? app.editor.mesh.id : "",
		help_open        = app.help_open,
		minimap          = {app.minimap_rect.x, app.minimap_rect.y, app.minimap_rect.width, app.minimap_rect.height},
	}
	data, err := json.marshal(snap)
	if err != nil {
		return nil, false
	}
	return data, true
}

handle_mouse_probe :: proc(_: rawptr, body: string) -> ([]byte, bool) {
	cmd := Mouse_Command{focused = true, on_screen = true, steps = 1}
	if err := json.unmarshal_string(body, &cmd, allocator = context.temp_allocator); err != nil {
		return nil, false
	}
	switch cmd.action {
	case "clear":
		app.probe = {}
		return capture_camera_snapshot(nil)
	case "reset_camera":
		app.probe = {}
		app.zoom = DEFAULT_ZOOM
		app.target_zoom = DEFAULT_ZOOM
		reset_camera()
		return capture_camera_snapshot(nil)
	case "set", "step":
		if cmd.action == "set" {
			app.probe.active = true
			app.probe.mouse = rl.Vector2{cmd.x, cmd.y}
			app.probe.focused = cmd.focused
			app.probe.on_screen = cmd.on_screen
			app.probe.left = cmd.left
			app.probe.middle = cmd.middle
			app.probe.space = cmd.space
			app.probe.wheel_y = cmd.wheel
		}
		probe_run(clamp(cmd.steps, 0, 600))
		return capture_camera_snapshot(nil)
	}
	return nil, false
}

// Advances the client frame (input, camera, HUD) without the simulation, driven by the probe.
probe_run :: proc(steps: int) {
	for _ in 0 ..< steps {
		probe_begin_frame()
		update_layout()
		handle_input()
		if app.mode == .Game || app.mode == .Pause_Menu {
			update_camera(1.0 / 60.0)
		}
		update_cursor()
		vui_frame(1.0 / 60.0)
		probe_end_frame()
		free_all(context.temp_allocator)
	}
}

// Synthetic left click at a logical point through the same path as /mouse.
probe_click_at :: proc(p: [2]f32) {
	prev := app.probe
	app.probe.active = true
	app.probe.mouse = rl.Vector2{p.x, p.y}
	app.probe.focused = true
	app.probe.on_screen = true
	app.probe.left = false
	probe_run(1)
	app.probe.left = true
	probe_run(1)
	app.probe.left = false
	probe_run(1)
	if prev.active {
		app.probe = prev
		return
	}
	// leave the synthetic pointer off-screen for a frame so edge pan / hover state do not
	// inherit its position when the real mouse takes over again
	app.probe.on_screen = false
	probe_run(1)
	app.probe = {}
}

@(private)
app_mode_name :: proc(m: App_Mode) -> string {
	switch m {
	case .Game:         return "Game"
	case .Pause_Menu:   return "Pause_Menu"
	case .Model_Picker: return "Model_Picker"
	case .Model_Editor: return "Model_Editor"
	}
	return "Game"
}

handle_client_command :: proc(_: rawptr, cmd: control.Command) -> (msg: string, ok: bool, handled: bool) {
	switch cmd.cmd {
	case "reload_models":
		art.clear_all_live_edit_meshes()
		reload_live_game_models()
		if app.mode == .Model_Editor && app.editor.mesh_loaded && !app.editor.mesh.dirty {
			_ = editor_reload_from_odin()
		}
		return "Reloaded custom .odin models", true, true
	case "open_picker":
		editor_open_picker()
		return "Opened Model Picker", true, true
	case "open_editor":
		id := cmd.model != "" ? cmd.model : "mamluk"
		loaded := editor_open_model(id, false)
		return loaded ? fmt.tprintf("Opened Model Editor: %s", id) : fmt.tprintf("Unknown model: %s", id), loaded, true
	case "close_editor":
		editor_close_to_game()
		return "Closed Model Editor", true, true
	case "pause_menu":
		editor_close_to_game()
		app.menu_open = true
		return "Opened Pause Menu", true, true
	case "toggle_help":
		app.help_open = !app.help_open
		return app.help_open ? "Opened shortcut window" : "Closed shortcut window", true, true
	case "open_help":
		app.help_open = true
		return "Opened shortcut window", true, true
	case "close_help":
		app.help_open = false
		return "Closed shortcut window", true, true
	case "ui_tree":
		return vui_tree_json(cmd.value), true, true
	case "ui_stats":
		return vui_stats_json(), true, true
	case "ui_click":
		text := cmd.text != "" ? cmd.text : cmd.model
		msg, ok = vui_click_text(text, max(cmd.value, 0))
		return msg, ok, true
	}
	return "", false, false
}
