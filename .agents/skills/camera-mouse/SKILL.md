---
name: camera-mouse
description: Dota 2 / StarCraft 2 mouse camera movement (1:1 Camera Grip, isometric edge pan, wheel zoom, minimap scrub), macOS raylib/GLFW cursor tracking fixes, and the live mouse/OS validation workflow. Use when editing camera controls, mouse input, or validating window cursor behavior.
---

# Camera & Mouse Movement Skill

Covers DreamCraft's isometric camera movement in `odin/client/` (`camera3d.odin`, `input.odin`, `minimap.odin`, `probe.odin`) and the live validation tool in `odin/tests/camera_mouse_check.py`.

## Dota 2 & StarCraft 2 Camera Model

### 1. Camera Grip (MMB or `Space` + Left Drag)
- **Pull-the-ground 1:1 lock:** Both Dota 2 (Camera Grip) and SC2 (Normal Drag Scroll) anchor terrain under the cursor—dragging the mouse right pulls the map right (camera shifts left `-right`), dragging down pulls the map down (camera shifts forward `+forward`).
- **Formula (`screen_delta_to_world_grip`):**
  ```odin
  px_to_ortho := fovy / max(screen_height, f32(1))
  delta := (-right * delta_px.x + forward * (delta_px.y / camera_pitch_sin())) * px_to_ortho
  ```
- **Zero float/inertia:** Grip writes directly to `camera_target`, clears `camera_vel`, and stops dead on release. Show `.RESIZE_ALL` while active and suppress edge pan + box select.
- Switch `camera_follow = false` once drag distance reaches `>= 0.5 px` so accidental middle clicks don't break `CAM FOLLOW`.

### 2. Orthographic Isometric Pitch & Zoom Scaling
- `camera_offset()` is `normalize({1, 0.816, 1}) * 40` (~30° pitch -> `sin(pitch) ≈ 0.50`).
- Ground movement along `forward` is foreshortened on screen by `sin(pitch) = abs(normalize(camera_offset()).y)`.
- Always scale `forward` pan by `1 / camera_pitch_sin()` and multiply screen-space speed by `app.camera.fovy` (`screen_dir_to_world`) so vertical, horizontal, and 45° corner panning move at equal visual pixel speed across every zoom level.

### 3. Screen Edge Panning
- **24px border (`CAMERA_EDGE_ZONE = 24`), inclusive of exact border pixels `0` and `width`/`height`:** Never reject `mouse.x <= 0 || mouse.x >= width`.
- **Normalize corner vectors** so diagonal scrolling matches cardinal speed.
- **Responsive exponential damping:** `CAMERA_ACCEL_RATE = 28`, `CAMERA_DECEL_RATE = 34` (Dota `dota_camera_accelerate` feel—absorbs single-frame border grazes without floaty ice-skating). Zero `camera_vel` components pushed into map bounds (`clamp_camera_velocity`).
- **Arming & busy guards:** `edge_armed` only arms once the cursor enters the inner viewport (`zone < x < w - zone`), preventing launch-time drift; disarm on `!IsWindowFocused()`, and pause over `minimap_rect` or during grip/box-select/minimap-drag.
- **Directional cursors:** Show `.RESIZE_EW`, `.RESIZE_NS`, `.RESIZE_NWSE`, or `.RESIZE_NESW` when edge-panning outside command mode.

### 4. Wheel Zoom & Minimap Scrubbing
- Read `rl.GetMouseWheelMoveV().y` (not `GetMouseWheelMove()`, which triggers on horizontal 2-finger trackpad swipes), apply exponential `math.pow(0.88, wheel)` to `target_zoom` (`0.25..2.0`), and ease `zoom` smoothly (`CAMERA_ZOOM_RATE = 22`).
- Left-clicking and dragging across `minimap_rect` continuously scrubs `camera_target` (`minimap_dragging`), and `draw_minimap_camera_box()` clips the 4 projected viewport ground corners inside the minimap rectangle.

---

## macOS Raylib / GLFW Pitfalls

1. **`rl.IsCursorOnScreen()` stays `false` when a window spawns under the cursor:**
   - Raylib's `IsCursorOnScreen()` only updates inside GLFW's `NSTrackingArea` `mouseEntered:` / `mouseExited:` callbacks.
   - Always route window edge checks through `update_cursor_inside()` (`odin/client/probe.odin`), which accepts real mouse motion/clicks inside `[0..width] × [0..height]` while focused, and immediately clears `cursor_inside` when coordinates leave `[0..width] × [0..height]`, focus is lost, or `raw_on_screen` transitions `true -> false`.
2. **Cache `rl.SetMouseCursor()`:** Only call `rl.SetMouseCursor(next)` when `next != app.last_cursor` instead of hammering `glfwSetCursor` at 60 Hz.
3. **Synthetic macOS OS mouse automation:** Calling `CGWarpMouseCursorPosition` triggers macOS's 250 ms event suppression timer on subsequent clicks; post `.mouseMoved` events directly with `CGEventPost(.cghidEventTap, ...)` instead.

---

## Live Validation Tool (`camera_mouse_check.py`)

Never guess mouse/camera behavior from screenshots or pure math tests alone—validate against a live dev window (`:7778`, leaving user stable `:7777` untouched):

```bash
cd odin
./build.sh --dev
python3 tests/camera_mouse_check.py --launch --mode both --port 7778
```

- **`GET /camera`**: Live JSON telemetry (`target`, `vel`, `zoom`, `target_zoom`, `fovy`, `follow`, `edge_armed`, `edge_dir`, `grip_active`, `grip_moved`, `window_focused`, `cursor_on_screen`, `cursor_inside`, `screen`, `render`, `scale_dpi`, `window_pos`, `mouse`).
- **`POST /mouse`**: Deterministic probe injection (`{"action":"set","x":...,"y":...,"left":...,"middle":...,"space":...,"wheel":...,"focused":...,"on_screen":...,"steps":N}`, `"reset_camera"`, `"clear"`).
- **`--mode probe`**: Validates edge arming, exact border pixels, pitch equalization, MMB grip, `Space`+Left grip, wheel zoom, minimap drag, unfocus disarm, and PNG screenshots.
- **`--mode os`**: Compiles a temporary Swift CoreGraphics (`CGEvent`) driver into `/tmp/` and drives real macOS mouse moves, clicks, L/R/T/B edge pans, outside-window deceleration, MMB drag, and wheel zoom against the real `dreamcraft-dev` window.
