# Input System

## Controls

| Input | Action |
|-------|--------|
| Left Click | Select single unit |
| Left Drag | Box select |
| Right Click | Move selected units / Attack enemy |
| Left Click on `[M] Move` button (or press `M`) | Enter Move command mode |
| Left Click on terrain (while Move mode active) | Issue move order with green ground confirmation FX |
| Left Click on `[A] Attack` button (or press `A`) | Enter StarCraft Attack-Move targeting mode |
| Left Click on enemy / terrain (while Attack mode active) | Attack targeted enemy or Attack-Move to terrain with red confirmation FX |
| Left Click on `[P] Patrol` button (or press `P`) | Enter 1-click Patrol targeting mode |
| Left Click on terrain (while Patrol mode active) | Start `current <-> clicked` patrol with cyan/amber loop FX |
| Left Click on `[S] Stop` button (or press `S`) | Stop unit and clear Move/Attack/Patrol orders |
| Left Click / Drag on Minimap | Center and scrub main camera across map |
| Middle Mouse Drag (or `Space` + Left Drag) | Dota 2 / SC2 Camera Grip: pull ground 1:1 under cursor |
| Right Click on Enemy | Attack (move into melee range and deal damage) with red target lock FX |
| Right Click on Ground | Move directly to location with SC2/AoE converging chevron confirmation FX |
| Shift + Click | Add to selection |
| F1 (or `? F1` UI badge) | Toggle view-conditional Shortcut Window (Battlefield, Pause Menu, Model Picker, Model Editor, or Active Modal tool) |
| Escape | Close open Shortcut Window first, cancel active command mode, or toggle pause menu when idle |

## Selection Box
- Start drag from top-left
- End drag at bottom-right
- Units within box are selected
- Minimum 5px drag distance = box select

## Camera

### Middle-Mouse Camera Grip / Drag Scroll (Dota 2 & SC2 Standard)
- Holding Middle Mouse Button (or `Space` + Left Drag on trackpads) in the world viewport grips the terrain under the cursor and pulls it 1:1 (`screen_delta_to_world_grip`)
- Movement stops immediately on button release with zero float/inertia, and changes the cursor to `.RESIZE_ALL` while held
- Dragging >= 0.5px switches from `CAM FOLLOW` to `CAM FREE`; edge pan and box selection pause while gripping

### WASD / Arrow Keys
- WASD or arrow keys pan along screen-corrected isometric axes (`CAMERA_KEY_SCREEN_SPEED = 1.25 * fovy/s`), keeping vertical and horizontal screen speeds equal across all zoom levels
- Uses responsive exponential acceleration/deceleration (`CAMERA_ACCEL_RATE = 28`, `CAMERA_DECEL_RATE = 34`) with zero ice-skating drift
- Camera is clamped to grid bounds (+3 cells margin)

### Mouse Wheel Zoom
- Vertical wheel (`GetMouseWheelMoveV().y`) smoothly eases `zoom` between `0.25x` and `2.0x` (`--zoom` clamp `0.08`..`2.0`), ignoring horizontal trackpad swipes
- Default zoom is `0.55`
- `--zoom=<n>` sets the initial zoom for dev runs
- Picking uses the live camera, so selection and commands stay accurate

### Screen Edge Scrolling (Dota 2 & SC2 Standard)
- When focused and armed inside the inner viewport, moving the cursor into the 16px border at any screen edge (including exact border pixels `0` and `width`/`height`) pans the camera smoothly
- Screen-space speed is constant and zoom-scaled (`CAMERA_EDGE_SCREEN_SPEED = 1.35 * fovy/s`), pitch-compensated so up/down matches left/right, and normalized in corners for uniform 45° diagonal motion
- Responsive Dota-style accel/decel prevents single-frame border jitter while stopping crisply when leaving the edge
- Shows directional resize arrows (`.RESIZE_EW`, `.RESIZE_NS`, `.RESIZE_NWSE`, `.RESIZE_NESW`) when edge-panning outside command mode
- Pauses cleanly over the minimap, during box select, during Camera Grip, or when the cursor leaves the window/focus
- Camera is clamped to grid bounds (+3 cells margin)

## Movement
- Right-click sets target position
- Right-click on an enemy unit issues an attack command instead
- `Mo` command mode allows left-click movement orders from the lower RTS HUD
- A* pathfinding calculates route
- Pathfinding supports 8-direction movement (including diagonals)
- Units follow path waypoints
- Stop at destination
- Unit state becomes `Moving` while traversing an active path

## Patrol & Attack-Move
- `[P]` Patrol / `Patrol` button uses single-click StarCraft/AoE targeting: clicking destination `B` starts an immediate `current_pos <-> B` patrol loop (`x, y, x2, y2` explicit endpoints remain supported via the control API).
- Patrolling and Attack-Moving units scan within `VISION_RADIUS` (`6` cells), engage enemies, and automatically resume their patrol leg or remaining attack-move destination once targets die or leave leash range (`8` cells).
- Any explicit `Move` (Right-click or `[M] Move`) or `[S] Stop` cancels `Patrol` and `Attack_Move`.

## Ground Confirmation FX & Command Cursor
- Pressing `M`, `A`, or `P` switches to a crosshair cursor and renders a pulsing 3D cell reticle under the cursor (`command_fx.odin`).
- Right-clicking ground or confirming `Move`/`Attack-Move`/`Patrol` plays SC2/AoE inward-converging 3D chevrons + expanding pulse ring (`Move` green/gold, `Attack` red, `Patrol` cyan/amber); targeting an enemy plays a pulsing red target lock ring.

## HUD Layout Notes
- Lower HUD is taller than minimap top edge by about 10px
- Minimap remains visually above HUD background layer
- Command button area is anchored to bottom-right
- Bottom-center command card region is reserved for future control groups

## Minimap Camera Navigation
- Left-click or drag inside minimap scrubs the main camera across the map
- Click/drag position is mapped from minimap normalized coordinates to grid coordinates
- Y-axis is inverted from UI space so minimap top maps to high grid Y
- Camera position is clamped to world camera bounds after recentering

---

## Odin Client Notes

- The native window is resizable (minimum 800×600). HUD, minimap,
  buttons and camera offset relayout from the current framebuffer size.
- The Odin client implements the same RTS controls with raylib:
  left-click/drag selection, right-click move/attack, 2×2 command card
  (`[M] Move`, `[A] Attack`, `[P] Patrol`, `[S] Stop`) and hotkeys,
  WASD/arrow pan, edge scroll, Escape (cancels active command mode before
  toggling the Pause menu), minimap click.
- Losing window focus while the cursor is outside the window no longer causes
  edge-scroll drift: edge scroll requires `IsWindowFocused()`, `IsCursorOnScreen()`,
  and `edge_armed` (arming only after cursor activity inside the inner viewport).
- Keyboard WASD/arrows, screen-edge scroll, and Camera Grip derive `forward` and `right` from
  `camera_pan_axes()` (`cross(forward, up)`) and compensate vertical ground distance by
  `1 / camera_pitch_sin()`, so up/down, left/right, and corners pan at identical screen speeds.
- Camera follow is on by default. It tracks the unit's interpolated world
  position exactly (no smoothing) and runs after the simulation tick, so the
  unit stays screen-centered without catch-up drift or rollback.
- Middle-mouse/Space+drag grip, WASD/arrow/edge-scroll, and minimap click/drag switch to FREE. `F` toggles FOLLOW.
  HUD shows `CAM FOLLOW`/`CAM FREE`.
- Right-click re-orders use the current interpolation: a second click while the
  unit is between cells plans from `next` and keeps `progress`/`world`, so the
  unit never snaps back to the previous cell center. Clicks on blocked cells
  are rejected without changing the current order.
- Mouse picking in the 3D client casts a ray from the camera and intersects
  the ground plane (`screen_to_world_ground` / `screen_to_grid`); selection
  boxes project unit positions with `GetWorldToScreen`.
- Ground clicks and confirmed commands spawn 3D inward chevrons, expanding
  rings, and center diamonds (`command_fx.odin`), targeted enemies show a
  pulsing red reticle, and active command modes draw a live cursor reticle.
- Web client: left click select/command, right click move/attack, shift+click
  add selection, Esc cancel mode, F select all, `M`/`A`/`P`/`S` hotkeys.
  Buttons: Move, Attack, Patrol (single-click from current position), Stop,
  Select All, Reset.
- **Hover / Focus**: Active game camera/unit input pauses cleanly while in `Model_Picker` or `Model_Editor`.
- **UI Event Routing & Pointer Blocking (`vui_host.odin`, `hud_basin.odin`, `editor_vui.odin`)**:
  HUD, minimap, pause, F1 window, Model Picker and Model Editor chrome are vinland-ui elements; buttons act when built (immediate mode) and call the existing `handle_*_ui_msg` handlers. `ui_pointer_captured()` hit-tests the last laid-out frame and gates world clicks, right-clicks, hover reticles and the selection marquee (`command_fx.odin`, `input.odin`).
- Commands are queued as fixed-size `Command` values; input never mutates
  simulation state directly.

## Model Editor (Blender Edit Mode Shortcuts)

Entered via `Esc -> Model Editor` (or `--editor[=<model>]`):

| Input | Action |
|-------|--------|
| `1` / `2` / `3` | Vertex / Edge / Face select mode |
| `LMB` / `Shift+LMB` / Drag / `B` | Pick element / additive toggle / Marquee Box select |
| `Alt+Click` (Edge mode) / `L` / `A` / `Alt+A` / `Shift+I` | Edge Loop / Linked verts / All-None / Invert selection |
| `G` / `R` / `S` (+ `X`/`Y`/`Z`, `Shift+X/Y/Z`, numeric input, `Ctrl` snap) | Grab / Rotate / Scale selection or drag 3D XYZ Gizmo |
| `E` / `I` / `Ctrl+R` (+ Wheel) / `K` (+ `Enter`/`Space`) | Extrude / Inset (22%) / Loop Cut (1..6 cuts) / Knife |
| `F` / `M` (`Alt+M`) / `X` (`Del`) -> `V/E/F/D` | Fill quad/tri / Merge center / Delete or Dissolve popup |
| `Alt+Z` / `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+S` | X-Ray toggle / Undo / Redo / Save `.odin` & hot-reload game |
| `MMB` / `Alt+LMB` / `RMB` drag, `Shift+MMB`, Wheel | Orbit camera / Pan / Zoom |
| `F1` (or `? F1` topbar button) | Toggle conditional Model Editor or active Modal (`Grab`/`Rotate`/`Scale`/`Loop Cut`/`Knife`) Shortcut Window |
| `Numpad 1/3/7`, `Numpad 5` (`O`), `.` (`Numpad .`), `Esc` | Front/Right/Top view, Ortho/Persp, Frame selection, Back/Confirm Exit |
