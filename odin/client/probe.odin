// Camera & mouse telemetry and synthetic input probe for live validation.
package main

import "core:encoding/json"
import rl "vendor:raylib"

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
		steps := clamp(cmd.steps, 0, 600)
		for _ in 0..<steps {
			probe_begin_frame()
			update_layout()
			handle_input()
			update_camera(1.0 / 60.0)
			update_cursor()
			probe_end_frame()
		}
		return capture_camera_snapshot(nil)
	}
	return nil, false
}
