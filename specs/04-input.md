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
| Left Click on Minimap | Center main camera to clicked map location |
| Right Click on Enemy | Attack (move into melee range and deal damage) with red target lock FX |
| Right Click on Ground | Move directly to location with SC2/AoE converging chevron confirmation FX |
| Shift + Click | Add to selection |
| Escape | Cancel active command mode first, or toggle pause menu when idle |

## Selection Box
- Start drag from top-left
- End drag at bottom-right
- Units within box are selected
- Minimum 5px drag distance = box select

## Camera

### WASD / Arrow Keys
- WASD or arrow keys pan the camera at 400 px/sec
- Camera is clamped to grid bounds (+200px margin)

### Mouse Wheel Zoom
- Wheel zooms the orthographic camera between `0.25x` and `2.0x` (`--zoom` clamp `0.08`..`2.0`)
- Default zoom is `0.55`
- `--zoom=<n>` sets the initial zoom for dev runs
- Picking uses the live camera, so selection and commands stay accurate

### Screen Edge Scrolling (RTS Standard)
- When mouse cursor enters the 20px zone at any screen edge, camera scrolls
- Scroll speed is progressive: faster the closer the cursor is to the edge
- Speed ramps from 200 px/sec (at 20px from edge) to 600 px/sec (at 0px from edge)
- X and Y axes scroll independently
- Works alongside keyboard camera controls
- Camera is clamped to grid bounds

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
- Left-click inside minimap recenters the main camera
- Click position is mapped from minimap normalized coordinates to grid coordinates
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
- Keyboard WASD/arrows and screen-edge scroll derive `forward` and `right` from
  `camera_pan_axes()` (`cross(forward, up)`) so left/right match isometric screen axes.
- Camera follow is on by default. It tracks the unit's interpolated world
  position exactly (no smoothing) and runs after the simulation tick, so the
  unit stays screen-centered without catch-up drift or rollback.
- WASD/arrow/edge-scroll/minimap click switches to FREE. `F` toggles FOLLOW.
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
- Commands are queued as fixed-size `Command` values; input never mutates
  simulation state directly.
