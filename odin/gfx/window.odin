// gfx: the subset of raylib DreamCraft uses, implemented on SDL3 (window, input) and the
// SDL3 GPU API (Metal on macOS, Vulkan on Linux). Client code keeps raylib's names and
// semantics, so `import rl "../gfx"` replaces `import rl "vendor:raylib"`.
//
// Frame model: draws are recorded during the frame and replayed in one command buffer at
// EndDrawing (copy pass for dynamic data, then one render pass per target, then present).
// Reading pixels back (LoadImageFromTexture) flushes the recorded work first.
package gfx

import "core:c"
import "core:fmt"
import sdl "vendor:sdl3"

MAX_KEYS :: 512
MAX_BUTTONS :: 8
CHAR_QUEUE :: 32

@(private)
Input_State :: struct {
	keys:          [MAX_KEYS]bool,
	keys_prev:     [MAX_KEYS]bool,
	keys_repeat:   [MAX_KEYS]bool,
	buttons:       [MAX_BUTTONS]bool,
	buttons_prev:  [MAX_BUTTONS]bool,
	mouse:         Vector2,
	wheel:         Vector2,
	chars:         [CHAR_QUEUE]rune,
	char_head:     int,
	char_count:    int,
	on_screen:     bool,
	focused:       bool,
	exit_key:      KeyboardKey,
	os_cursor:     Vector2, // last sampled global cursor position
	os_sampled:    bool,
}

@(private)
Window_State :: struct {
	window:       ^sdl.Window,
	flags:        ConfigFlags,
	should_close: bool,
	start_ns:     u64,
	frame_start:  u64,
	frame_time:   f32,
	target_fps:   int,
	fps_frames:   int,
	fps_accum:    f64,
	fps:          int,
	cursor:       MouseCursor,
	cursors:      [MouseCursor]^sdl.Cursor,
	input:        Input_State,
}

@(private)
W: Window_State

SetConfigFlags :: proc(flags: ConfigFlags) {
	W.flags = flags
}

InitWindow :: proc(width, height: c.int, title: cstring) {
	if !sdl.Init({.VIDEO, .EVENTS}) {
		fmt.eprintln("gfx: SDL_Init failed:", sdl.GetError())
		return
	}
	flags: sdl.WindowFlags = {.HIGH_PIXEL_DENSITY}
	if .WINDOW_RESIZABLE in W.flags {
		flags += {.RESIZABLE}
	}
	if .WINDOW_HIDDEN in W.flags {
		flags += {.HIDDEN}
	}
	W.window = sdl.CreateWindow(title, width, height, flags)
	if W.window == nil {
		fmt.eprintln("gfx: SDL_CreateWindow failed:", sdl.GetError())
		return
	}
	W.input.exit_key = .ESCAPE
	W.input.on_screen = false
	W.input.focused = true
	W.start_ns = sdl.GetTicksNS()
	W.frame_start = W.start_ns
	W.frame_time = 1.0 / 60.0
	if !device_init(W.window, .VSYNC_HINT in W.flags) {
		fmt.eprintln("gfx: GPU device initialisation failed:", sdl.GetError())
	}
	platform_activate()
	_ = sdl.RaiseWindow(W.window)
	_ = sdl.StartTextInput(W.window)
	// first event pump so the cursor position and focus are known before frame one
	poll_events()
}

CloseWindow :: proc() {
	device_shutdown()
	for cur in W.cursors {
		if cur != nil {
			sdl.DestroyCursor(cur)
		}
	}
	if W.window != nil {
		sdl.DestroyWindow(W.window)
		W.window = nil
	}
	sdl.Quit()
}

WindowShouldClose :: proc() -> bool {
	return W.should_close
}

IsWindowReady :: proc() -> bool {
	return W.window != nil && G.dev != nil
}

SetWindowMinSize :: proc(width, height: c.int) {
	_ = sdl.SetWindowMinimumSize(W.window, width, height)
}

SetWindowSize :: proc(width, height: c.int) {
	_ = sdl.SetWindowSize(W.window, width, height)
}

SetWindowTitle :: proc(title: cstring) {
	_ = sdl.SetWindowTitle(W.window, title)
}

SetTargetFPS :: proc(fps: c.int) {
	W.target_fps = int(fps)
}

SetExitKey :: proc(key: KeyboardKey) {
	W.input.exit_key = key
}

// Logical window size (points), like raylib with FLAG_WINDOW_HIGHDPI.
GetScreenWidth :: proc() -> c.int {
	w, h: c.int
	_ = sdl.GetWindowSize(W.window, &w, &h)
	return w
}

GetScreenHeight :: proc() -> c.int {
	w, h: c.int
	_ = sdl.GetWindowSize(W.window, &w, &h)
	return h
}

// Framebuffer size in physical pixels.
GetRenderWidth :: proc() -> c.int {
	w, h: c.int
	_ = sdl.GetWindowSizeInPixels(W.window, &w, &h)
	return w
}

GetRenderHeight :: proc() -> c.int {
	w, h: c.int
	_ = sdl.GetWindowSizeInPixels(W.window, &w, &h)
	return h
}

GetWindowScaleDPI :: proc() -> Vector2 {
	d := sdl.GetWindowPixelDensity(W.window)
	if d <= 0 {
		d = 1
	}
	return {d, d}
}

GetWindowPosition :: proc() -> Vector2 {
	x, y: c.int
	_ = sdl.GetWindowPosition(W.window, &x, &y)
	return {f32(x), f32(y)}
}

IsWindowFocused :: proc() -> bool {
	return .INPUT_FOCUS in sdl.GetWindowFlags(W.window)
}

IsCursorOnScreen :: proc() -> bool {
	return W.input.on_screen
}

GetTime :: proc() -> f64 {
	return f64(sdl.GetTicksNS() - W.start_ns) / 1e9
}

GetFrameTime :: proc() -> f32 {
	return W.frame_time
}

GetFPS :: proc() -> c.int {
	return c.int(W.fps)
}

// ------------------------------------------------------------------ keyboard

IsKeyPressed :: proc(key: KeyboardKey) -> bool {
	k := int(key)
	return k > 0 && k < MAX_KEYS && W.input.keys[k] && !W.input.keys_prev[k]
}

IsKeyPressedRepeat :: proc(key: KeyboardKey) -> bool {
	k := int(key)
	return k > 0 && k < MAX_KEYS && W.input.keys_repeat[k]
}

IsKeyDown :: proc(key: KeyboardKey) -> bool {
	k := int(key)
	return k > 0 && k < MAX_KEYS && W.input.keys[k]
}

IsKeyReleased :: proc(key: KeyboardKey) -> bool {
	k := int(key)
	return k > 0 && k < MAX_KEYS && !W.input.keys[k] && W.input.keys_prev[k]
}

IsKeyUp :: proc(key: KeyboardKey) -> bool {
	return !IsKeyDown(key)
}

GetCharPressed :: proc() -> rune {
	in_ := &W.input
	if in_.char_count == 0 {
		return 0
	}
	r := in_.chars[in_.char_head]
	in_.char_head = (in_.char_head + 1) % CHAR_QUEUE
	in_.char_count -= 1
	return r
}

// ------------------------------------------------------------------ mouse

@(private)
button_index :: proc(b: MouseButton) -> int {
	return clamp(int(b), 0, MAX_BUTTONS - 1)
}

IsMouseButtonPressed :: proc(button: MouseButton) -> bool {
	i := button_index(button)
	return W.input.buttons[i] && !W.input.buttons_prev[i]
}

IsMouseButtonDown :: proc(button: MouseButton) -> bool {
	return W.input.buttons[button_index(button)]
}

IsMouseButtonReleased :: proc(button: MouseButton) -> bool {
	i := button_index(button)
	return !W.input.buttons[i] && W.input.buttons_prev[i]
}

IsMouseButtonUp :: proc(button: MouseButton) -> bool {
	return !IsMouseButtonDown(button)
}

GetMousePosition :: proc() -> Vector2 {
	return W.input.mouse
}

GetMouseX :: proc() -> c.int {
	return c.int(W.input.mouse.x)
}

GetMouseY :: proc() -> c.int {
	return c.int(W.input.mouse.y)
}

GetMouseWheelMove :: proc() -> f32 {
	w := W.input.wheel
	return abs(w.x) > abs(w.y) ? w.x : w.y
}

GetMouseWheelMoveV :: proc() -> Vector2 {
	return W.input.wheel
}

SetMouseCursor :: proc(cursor: MouseCursor) {
	if W.cursor == cursor && W.cursors[cursor] != nil {
		return
	}
	W.cursor = cursor
	if W.cursors[cursor] == nil {
		W.cursors[cursor] = sdl.CreateSystemCursor(system_cursor(cursor))
	}
	_ = sdl.SetCursor(W.cursors[cursor])
}

@(private)
system_cursor :: proc(cursor: MouseCursor) -> sdl.SystemCursor {
	#partial switch cursor {
	case .IBEAM:
		return .TEXT
	case .CROSSHAIR:
		return .CROSSHAIR
	case .POINTING_HAND:
		return .POINTER
	case .RESIZE_EW:
		return .EW_RESIZE
	case .RESIZE_NS:
		return .NS_RESIZE
	case .RESIZE_NWSE:
		return .NWSE_RESIZE
	case .RESIZE_NESW:
		return .NESW_RESIZE
	case .RESIZE_ALL:
		return .MOVE
	case .NOT_ALLOWED:
		return .NOT_ALLOWED
	}
	return .DEFAULT
}

ShowCursor :: proc() {
	_ = sdl.ShowCursor()
}

HideCursor :: proc() {
	_ = sdl.HideCursor()
}

// ------------------------------------------------------------------ events

// raylib order: EndDrawing presents, then polls input for the next frame, then paces.
@(private)
end_frame_timing :: proc() {
	poll_events()
	now := sdl.GetTicksNS()
	if W.target_fps > 0 {
		budget := u64(1e9) / u64(W.target_fps)
		elapsed := now - W.frame_start
		// vsync usually paces already; this only caps faster displays and occluded windows
		if elapsed + 500_000 < budget {
			sdl.DelayPrecise(budget - elapsed)
			now = sdl.GetTicksNS()
		}
	}
	W.frame_time = f32(f64(now - W.frame_start) / 1e9)
	W.frame_start = now
	W.fps_frames += 1
	W.fps_accum += f64(W.frame_time)
	if W.fps_accum >= 0.5 {
		W.fps = int(f64(W.fps_frames) / W.fps_accum + 0.5)
		W.fps_frames = 0
		W.fps_accum = 0
	}
}

PollInputEvents :: proc() {
	poll_events()
}

@(private)
poll_events :: proc() {
	in_ := &W.input
	in_.keys_prev = in_.keys
	in_.buttons_prev = in_.buttons
	in_.keys_repeat = {}
	in_.wheel = {}
	e: sdl.Event
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .QUIT, .WINDOW_CLOSE_REQUESTED:
			W.should_close = true
		case .WINDOW_MOUSE_ENTER:
			in_.on_screen = true
		case .WINDOW_MOUSE_LEAVE:
			in_.on_screen = false
		case .WINDOW_DISPLAY_CHANGED:
			platform_after_claim(W.window) // new display, new profile
		case .WINDOW_FOCUS_GAINED:
			in_.focused = true
		case .WINDOW_FOCUS_LOST:
			in_.focused = false
		case .MOUSE_MOTION:
			in_.mouse = {e.motion.x, e.motion.y}
			in_.on_screen = true
		case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
			in_.mouse = {e.button.x, e.button.y}
			b := -1
			switch e.button.button {
			case 1:
				b = int(MouseButton.LEFT)
			case 2:
				b = int(MouseButton.MIDDLE)
			case 3:
				b = int(MouseButton.RIGHT)
			case 4:
				b = int(MouseButton.SIDE)
			case 5:
				b = int(MouseButton.EXTRA)
			}
			if b >= 0 && b < MAX_BUTTONS {
				in_.buttons[b] = e.button.down
			}
		case .MOUSE_WHEEL:
			in_.wheel += {e.wheel.x, e.wheel.y}
		case .KEY_DOWN, .KEY_UP:
			k := int(scancode_to_key(e.key.scancode))
			if k > 0 && k < MAX_KEYS {
				in_.keys[k] = e.key.down
				if e.key.down && e.key.repeat {
					in_.keys_repeat[k] = true
				}
			}
			if e.key.down && !e.key.repeat && in_.exit_key != .KEY_NULL && KeyboardKey(k) == in_.exit_key {
				W.should_close = true
			}
		case .TEXT_INPUT:
			for r in string(e.text.text) {
				if in_.char_count < CHAR_QUEUE {
					in_.chars[(in_.char_head + in_.char_count) % CHAR_QUEUE] = r
					in_.char_count += 1
				}
			}
		}
	}
	sample_os_cursor()
}

// GLFW (raylib) reads the cursor from the OS every frame instead of relying on motion
// events; SDL only reports what its event stream saw, and events posted with CGEventPost
// (the camera/mouse OS test, automation tools) reach the window without SDL motion events.
// Sample the global cursor the same way so position, enter/leave and buttons match raylib.
@(private)
sample_os_cursor :: proc() {
	in_ := &W.input
	gx, gy: f32
	flags := sdl.GetGlobalMouseState(&gx, &gy)
	wx, wy, ww, wh: c.int
	_ = sdl.GetWindowPosition(W.window, &wx, &wy)
	_ = sdl.GetWindowSize(W.window, &ww, &wh)
	local := Vector2{gx - f32(wx), gy - f32(wy)}
	inside := local.x >= 0 && local.y >= 0 && local.x < f32(ww) && local.y < f32(wh)
	// like GLFW, only actual movement reports a position (a window opening under a resting
	// cursor does not count as the user moving into it)
	if !in_.os_sampled {
		in_.os_sampled = true
	} else if gx != in_.os_cursor.x || gy != in_.os_cursor.y {
		in_.mouse = local
		in_.on_screen = inside
	}
	in_.os_cursor = {gx, gy}
	if .INPUT_FOCUS not_in sdl.GetWindowFlags(W.window) {
		return
	}
	// a press counts only when it starts inside the window; a held button stays down when
	// the cursor leaves (drags), like GLFW
	MAP := [3]struct {
		f: sdl.MouseButtonFlag,
		b: MouseButton,
	}{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}
	for m in MAP {
		i := int(m.b)
		in_.buttons[i] = m.f in flags && (inside || in_.buttons_prev[i])
	}
}

// SDL scancodes (USB HID usage page 7) to raylib/GLFW key codes (US layout positions).
@(private)
scancode_to_key :: proc(sc: sdl.Scancode) -> KeyboardKey {
	s := int(sc)
	switch {
	case s >= 4 && s <= 29:
		return KeyboardKey(65 + s - 4) // A..Z
	case s >= 30 && s <= 38:
		return KeyboardKey(49 + s - 30) // 1..9
	case s == 39:
		return .ZERO
	case s >= 58 && s <= 69:
		return KeyboardKey(290 + s - 58) // F1..F12
	case s >= 89 && s <= 97:
		return KeyboardKey(321 + s - 89) // KP_1..KP_9
	}
	switch s {
	case 40:
		return .ENTER
	case 41:
		return .ESCAPE
	case 42:
		return .BACKSPACE
	case 43:
		return .TAB
	case 44:
		return .SPACE
	case 45:
		return .MINUS
	case 46:
		return .EQUAL
	case 47:
		return .LEFT_BRACKET
	case 48:
		return .RIGHT_BRACKET
	case 49:
		return .BACKSLASH
	case 51:
		return .SEMICOLON
	case 52:
		return .APOSTROPHE
	case 53:
		return .GRAVE
	case 54:
		return .COMMA
	case 55:
		return .PERIOD
	case 56:
		return .SLASH
	case 57:
		return .CAPS_LOCK
	case 73:
		return .INSERT
	case 74:
		return .HOME
	case 75:
		return .PAGE_UP
	case 76:
		return .DELETE
	case 77:
		return .END
	case 78:
		return .PAGE_DOWN
	case 79:
		return .RIGHT
	case 80:
		return .LEFT
	case 81:
		return .DOWN
	case 82:
		return .UP
	case 84:
		return .KP_DIVIDE
	case 85:
		return .KP_MULTIPLY
	case 86:
		return .KP_SUBTRACT
	case 87:
		return .KP_ADD
	case 88:
		return .KP_ENTER
	case 98:
		return .KP_0
	case 99:
		return .KP_DECIMAL
	case 224:
		return .LEFT_CONTROL
	case 225:
		return .LEFT_SHIFT
	case 226:
		return .LEFT_ALT
	case 227:
		return .LEFT_SUPER
	case 228:
		return .RIGHT_CONTROL
	case 229:
		return .RIGHT_SHIFT
	case 230:
		return .RIGHT_ALT
	case 231:
		return .RIGHT_SUPER
	}
	return .KEY_NULL
}

// ------------------------------------------------------------------ memory (raylib MemAlloc/MemFree)

foreign import libc "system:c"

@(private, default_calling_convention = "c")
foreign libc {
	calloc :: proc(n, size: c.size_t) -> rawptr ---
	free :: proc(p: rawptr) ---
}

MemAlloc :: proc(size: c.uint) -> rawptr {
	return calloc(1, c.size_t(size))
}

MemFree :: proc(ptr: rawptr) {
	if ptr != nil {
		free(ptr)
	}
}
