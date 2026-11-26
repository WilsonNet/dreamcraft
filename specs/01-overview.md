# DreamCraft RTS - Game Specification

## Vision

A fantasy RTS — spiritual successor to StarCraft: Brood War. Current renderer is native SDL3 GPU (Metal / Vulkan, `specs/11-renderer-port.md`); long-term targets are web/WebGPU, deterministic sync, and low-latency networking.

## Core Features

1. **Top-Down 2D Grid** - Large maps with fog of war (StarCraft-style)
2. **Unit Types** (planned):
   - **Gatherer** (Gold) - Resource collection
   - **Scout** (Blue) - Fast movement, large vision
   - **Melee** (Red) - Close combat
   - **Ranged** (Green) - Projectile attacks
3. **Deterministic Logic** - Fixed-point math for perfect sync
4. **Multiplayer** - WebTransport + WebRTC

## Technical Requirements

- 60 FPS fixed timestep
- Integer-based movement / fixed-point math
- A* pathfinding on grid
- Box selection + right-click commands

## Implementation Status

### Odin Port (Primary)

The Odin implementation in `odin/` is the active codebase. It compiles in
roughly 1–3 seconds, uses no GC, and keeps all simulation state in fixed
capacity arrays.

- [x] Deterministic Q16.16 fixed-point simulation at 60 Hz
- [x] Struct-of-arrays unit pool with generation handles (256 slots)
- [x] Allocation-free A* with preallocated scratch (no per-call heap)
- [x] Obstacle and fog bitsets
- [x] Fixed command queue (128 entries) validated on push and execute
- [x] Runtime invariant checker (`validate_game`) after every tick
- [x] State hash for deterministic replay tests
- [x] Native client: world, fog, units, paths, HUD, minimap (raylib 6.2 originally, SDL3 GPU since the renderer port)
- [x] Renderer port to SDL3 GPU (`specs/11-renderer-port.md`): Metal on macOS, Vulkan on Linux, raylib removed
- [x] Native full 3D isometric renderer + watercolour post shader
- [x] Procedural Mamluk melee unit modelled, rigged and skinned in Odin (`odin/client/art/`)
- [x] Kinetic-chain idle/walk/attack clips with S-wave cape/sash/plume, turn banking, and stop-settle cushion
- [x] Age of Empires × Toriyama world proportions: towering procedural pines & oaks, mossy boulders, stone waypoints, double-crescent slash VFX
- [x] Painterly terrain (`1280×800`), obstacle-aware Catmull-Rom trail, bilinear mist fog, and full-res watercolour post-process (no GLB assets)
- [x] Web client keeps the lightweight 2:1 canvas view
- [x] Camera follow mode with manual override (`F`), Dota/SC2 Camera Grip (`MMB` / `Space+Drag`), fixed pitch-compensated edge scroll, smooth wheel zoom, and minimap drag + viewport frame
- [x] Move/attack re-orders keep mid-cell position (no teleport/rollback)
- [x] Browser build: Odin `js_wasm32` + HTML canvas + DOM HUD
- [x] Headless runner: file polling, JSONL scripts, `--ticks`
- [x] Replay files: `--record`, `--replay`, hash verification
- [x] StarCraft-style `Attack_Move` (`A` / Attack button) and fixed 1-click `Patrol` (`P` / Patrol button) with enemy auto-acquisition along the route and automatic leg resumption after combat
- [x] Campaign hero **`Liiroy, the Bold`** (`Unit_Kind.Hero`: `500 HP`, `5` armor, `35` dmg, `40`-tick cooldown, `180` speed, `+4 HP/s` regen, `HERO_SCALE = 0.84`, royal-cobalt & gilded trim, gold aura ring & health bar) replaces the regular player **Luk Soldier** (`Unit_Kind.Melee`) in campaign mode
- [x] Event-based campaign discovery aggro delay (`ENEMY_AGGRO_DELAY_TICKS = 240` / `4.0 s`): newly spotted enemy Luk Soldiers pause and show a flavored warning banner & `! SPOTTED` countdown ring until the timer expires or they take damage
- [x] StarCraft 2 / Age of Empires 3D ground command FX (`command_fx.odin`): inward-converging chevrons, pulse rings, target lock rings, live cursor preview, and state-colored paths
- [x] HTTP control API replacing Bevy BRP MCP
  - [x] `GET /state`, `/units`, `/fog`, `/screenshot`, `/camera`, `/health`
  - [x] `POST /command`: move, patrol, patrol_to, attack, attack_move, stop, run, reset, verify,
        select, spawn, kill, set_hp, teleport, reload_models, open_picker, open_editor, close_editor, reload_anims, open_anim_picker, open_anim_editor, close_anim_editor, pause_menu, toggle_help, open_help, close_help
  - [x] `POST /mouse` + `odin/tests/camera_mouse_check.py` live mouse & OS camera validation tool
  - [x] Every response carries `valid` + `validation`
- [x] In-game 3D Model Picker & Model Editor (`Esc -> Model Editor` or `--editor[=<model>]`):
  - [x] Edit all 12 catalog models (`mamluk`, `mamluk_hero`, `mamluk_enemy`, 4 trees, 5 props) with `base_fallback` fork-on-save
  - [x] Blender Edit Mode workflow (`1/2/3`, `G/R/S` + XYZ gizmo + numeric input, `E` Extrude, `I` Inset, `Ctrl+R` Loop Cut, `K` Knife, `F` Fill, `M`/`Alt+M` Merge, `X` Delete/Dissolve, `B` Box, `L` Linked, `Alt+Click` Loop, `Alt+Z` X-Ray, X-Mirror, `Ctrl+Z/Shift+Z`)
  - [x] `Mat_Kind` swatch painter, 26-bone `Bone_Id` rigging, Rest/Idle/Walk/Attack pose & Hero/Unit/Enemy palette preview, Watercolour toggle
  - [x] Two-way Git-friendly `.odin` chunk persistence (`client/art/models/<id>/{v_NNN,f_NNN,asset}.odin` + `manifest.odin`) & `Ctrl+S` live hot-reload back into game
- [x] In-game 3D Animation Picker & Blender-style Graph Editor (`Esc -> Animation Editor` or `--anim-editor[=<clip>]`):
  - [x] Edit all 9 catalog clips (`idle`, `walk`, `attack`, `hero_*`, `enemy_*`) with `base_fallback` fork-on-save
  - [x] Editor-only **Motion Control Rig** (`client/art/anim_rig/` — zero in-game runtime overhead): 12 controls (`COG`, `Chest`, `Head Aim`, `Cape`, `Hand IK L/R`, `Foot IK L/R`, `Elbow/Knee Pole L/R`) with custom 3D wire shapes, analytic 2-bone IK + foot pinning + aim solver writing straight to FK `Edit_Keyframe` poses (`Rig | Bones | Both` view modes, `Pin Feet` toggle, `Ctrl` inspector sliders)
  - [x] Maya/Blender **multiselect** across 3D controls/bones (`Shift+Click`, empty-drag marquee box `B`, `L` descendant chain, `A`/`Alt+A` all/single, 8 selection-set presets: `Spine`, `L/R Arm`, `L/R Leg`, `Cape`, `All`, `Chain`, multi-bone/control `R` & sliders) and Graph/Dopesheet keyframes (`Shift+Click`, marquee box drag below ruler, `S` time-scale around playhead, multi-key drag/`V`/`T`/`X`)
  - [x] Blender-style **F-Curve Graph Editor** + **Dopesheet** dock (`Curves`/`Dopesheet` tabs, `Tall` expand, RGB X/Y/Z cubic Bezier splines, `Clamp`/`Auto`/`Align`/`Free`/`Vec` handles, direct node & handle dragging, `V`/`T`/`Home` hotkeys, Wheel/MMB zoom & pan)
  - [x] 3D 25-bone rig skeleton & XYZ rotation ring gizmo (`R` modal rotate, `G` IK/COG/root move, `Y=0` foot grounding, L↔R mirror/flip, onion skinning, live slash VFX preview)
  - [x] Two-way Git-friendly `.odin` chunk persistence (`client/art/anims/<id>/{k_NNN,clip}.odin` + `manifest.odin`) + `Ctrl+S` immediate live hot-reload & 0.5s external disk watcher
- [x] Playwright-style Cooperative Mesh CLI (`odin/tools/mesh_cli/` -> `bin/dreamcraft-mesh`): `list`, `extract`, `info`, positive/negative `assert` (`!`, `--expect-fail`), `do`/`edit` inline ops & `--notify=<port>` hot-reload without saved script files
- [x] Pure-Odin Vector SVG Renderer & Icon Atlas (`client/svg/`, `assets/icons/*.svg`, `client/icons.odin`): `<path>`/`<rect>`/`<circle>`/`<ellipse>`/`<line>`/`<poly*>` + `<g>`/transform + 4x4 SSAA fills & smooth strokes for HUD command card, Pause Menu, hero crests, & Model Editor toolbars
- [x] vinland-ui HUD (`specs/09-ui-framework.md`): battlefield bottom console in the "Saint Louis Basin" world (hammered brass, bitumen, silver interlace, lapis medallions with gold-inlay armed state), pause and defeat arches, F1 window, world nameplates, Model Picker and Model Editor chrome, embedded over raylib via `vinland:vui/raylib` (replaced the in-tree `odin/ui/` framework)
- [x] Agent UI loop: `ui_tree`, `ui_click`, `ui_stats` control commands; `/camera` exposes the live minimap rect
- [ ] Renderer port to SDL3 GPU (Metal / Vulkan) sharing VUI's device (`specs/11-renderer-port.md`)
- [x] View-conditional **F1 Shortcut Window** (`client/shortcuts.odin`) with clickable `? F1` badges across Battlefield, Pause Menu, Model Picker, Model Editor, Animation Picker, and Animation Editor (plus active modal sheets)
- [x] 139 unit/integration tests (69 game, 13 control, 20 art, 9 art/edit, 5 art/anim_edit, 5 svg, 6 mesh_cli, 12 client)
- [x] Web WASM smoke test in Node
- [x] Game-over state is valid and explicit (`game_over`)
- [x] Zero-allocation simulation test under a failing allocator
- [x] Waypoint 3 relocated from (40,20) to (40,23)

### Completed Features (original Rust/Bevy prototype)

#### Tutorial Level 1: "Through the Woods"
- [x] Grid-based level (80x50 cells, 32px per cell)
- [x] Blue player unit (circle with "M" label) with right-click movement
- [x] Red enemy unit (circle with "M" label) at (50, 25) - hidden in fog
- [x] Team/race semantics clarified: available races are `Basic`, `Akana`, `Gorg`; Level 1 uses `Basic` for both teams; color indicates team, `M` indicates Melee type
- [x] Tree clusters (30 clusters, 132 obstacle cells)
- [x] Golden goal zone on the right side
- [x] A* pathfinding (Rust BinaryHeap prototype; Odin allocation-free version is primary)
- [x] Path visualization with gizmos
- [x] WASD/Arrow camera controls (speed: 400)
- [x] Tutorial UI overlay (HUD)
- [x] Level complete detection (player reaches grid_x >= 77)
- [x] Context menu suppressed (right-click doesn't open browser menu)
- [x] Fog of War system (StarCraft-style, 3-state)
  - [x] Unexplored (black) - never seen by player
  - [x] Explored (dark) - was visible, now out of vision range
  - [x] Visible (bright) - currently within player vision radius
  - [x] Player vision radius (6 cells, circular)
  - [x] Dynamic fog update every frame
  - [x] Fog entities fade when area becomes visible
- [x] Waypoint system
  - [x] 8 waypoints guiding player through fog
  - [x] Golden waypoint markers for current target
  - [x] Faded markers for future/reached waypoints
  - [x] Large area reveal (10-cell radius) when reaching waypoint

#### Minimap (StarCraft-style, bottom-left)
- [x] Native Bevy UI implementation (no React)
- [x] Fixed screen position: left: 20px, bottom: 30px (CSS-like)
- [x] 200x125 pixel size
- [x] Shows terrain with 3-state fog colors
- [x] Player position indicator (blue dot, real-time updates)
- [x] Waypoint markers (yellow = current, dim = others)
- [x] Goal marker (gold circle)
- [x] Border (green)
- [x] Independent of camera movement (screen-space rendering)
- [x] Left-click on minimap re-centers main camera to clicked map location
- [x] Minimap draws above bottom HUD layer (always visible over HUD background)

#### RTS Command HUD (bottom bar)
- [x] Bottom-screen RTS HUD bar placeholder
- [x] HUD height increased to exceed minimap top edge by ~10px (170px HUD vs minimap top at 159px)
- [x] Clickable Move command button (`Mo` placeholder), small size, anchored bottom-right
- [x] Clickable Patrol command button (`Pt` placeholder), stacked above Move
- [x] Move command mode cursor feedback (changes to move cursor)
- [x] Patrol mode supports two-point selection (A then B) and loops unit between points
- [x] Patrol loop breaks on explicit move commands (right-click move or Move button order)
- [x] Left-click world to issue move order, then cursor resets to default
- [x] Ordered unit enters `Moving` state while following command path
- [x] Bottom center reserved for future control group UI

#### Agent Console (React overlay)
- [ ] Toggle with backtick (`` ` ``) key
- [ ] Connected status indicator (green/red)
- [ ] Live status bar: position, waypoint, fog %, selection, movement, completion
- [ ] Commands: status, fog, waypoints, goto, next, autoplay, reset, watch, help, clear
- [ ] Bidirectional Bevy<->React communication via localStorage
- [ ] Automatic diagnostics/warnings:
  - [ ] Player visibility check (camera viewport)
  - [ ] Fog coverage check
  - [ ] Camera-player distance check
  - [ ] Selection state check
- [ ] Warning banner (red) when issues detected
- [ ] Headless API (`window.dreamcraftConsole`) for Playwright testing

#### Headless/Agentic Testing
- [x] Full game state observable via `dreamcraft_debug_state` localStorage key
- [x] Commands injectable via `dreamcraft_command` localStorage key
- [x] Playwright MCP integration for automated validation (Rust prototype)
- [x] Level completable headlessly (goto waypoints, verify state)
- [x] Native headless mode with file-based commands (`headless_command.json`)
- [x] Odin headless JSONL scripts (`odin/bin/headless --script`)
- [x] Odin HTTP control API replaces BRP/MCP
- [x] Bevy BRP MCP config and `bevy_remote`/`bevy_brp_extras` dependencies removed

#### Combat System
- [x] Melee combat with damage and health
- [x] Right-click enemy to attack
- [x] Enemy AI chases and attacks player on sight
- [x] Attack cooldown (1 second between attacks)
- [x] Death system (units despawn at 0 HP)

#### Screen Edge Scrolling & Camera Grip
- [x] Dota 2 / StarCraft 2 Camera Grip (`Middle Mouse` or `Space + Left Drag`): 1:1 ground locking with zero float
- [x] 16px edge pan activation zone (including exact `0` / `width` / `height` border pixels) with directional cursor feedback
- [x] Pitch-compensated (`1 / sin(pitch)`), zoom-scaled screen speed with normalized corners and crisp exponential accel/decel
- [x] Works alongside WASD camera controls and minimap click/drag scrubbing

#### Escape Menu
- [x] Press Esc to open/close pause overlay
- [x] Semi-transparent dark overlay with centered panel
- [x] "Retry Level" button — resets level (respawning all entities at start)
- [x] "Resume" button — closes menu
- [x] Game simulation continues while paused (overlay only)
- [x] Clicking Retry hides menu automatically

#### Health Bar Updates
- [x] Health bar fills resize/change color reactively when health changes
- [x] Uses `Changed<Health>` query for efficient updates
- [x] Color thresholds: green (>50%), yellow (25-50%), red (<25%)

### Known Issues
- [x] Waypoint 3 at (40,20) collided with a tree — fixed to (40,23) in Odin
- [x] Camera auto-follow with manual override
- [x] Odin web/WASM build (canvas renderer, no Emscripten)

### Controls
- **Right-Click**: Move unit to location; right-click on enemy = attack
- **Middle-Mouse / Space+Drag**: Dota 2 / SC2 Camera Grip (1:1 terrain drag)
- **WASD/Arrows**: Pan camera
- **Screen Edge Scroll**: Mouse at screen edge pans camera (Dota/SC2 pitch-compensated)
- **Mouse Wheel**: Smooth zoom
- **Left-Click / Drag Minimap**: Center and scrub camera across map
- **Backtick (`` ` ``)**: Toggle Agent Console
- **Escape**: Toggle pause menu (Retry / Resume)

#### Waypoints for Level 1
```
(10,25) -> (20,25) -> (30,25) -> (40,23) -> (50,25) -> (60,25) -> (70,25) -> (77,25)
Player starts at (2,25). Goal zone at x >= 77.
(40,20) is a tree; Odin uses (40,23).
```

### Architecture

Primary implementation:

```
odin/
├── game/           # pure deterministic simulation (no renderer, no allocation)
│   ├── config.odin     # constants and fixed-capacity limits
│   ├── fixed.odin      # Q16.16 fixed point
│   ├── grid.odin       # obstacles + fog bitsets
│   ├── pathfinding.odin# allocation-free A*
│   ├── units.odin      # struct-of-arrays + generation handles
│   ├── commands.odin   # validated command queue
│   ├── movement.odin   # fixed-tick path movement
│   ├── ai.odin         # enemy chase, fog, waypoints, goal
│   ├── combat_sim.odin # attacks, cooldowns, death
│   ├── sim.odin        # fixed system order
│   ├── validation.odin # runtime invariants
│   └── hash.odin       # deterministic state hash
├── gfx/             # raylib-compatible API on SDL3 GPU, game shaders
├── client/          # native rendering, input, HUD, minimap, VFX, in-game Model Editor
│   ├── art/         # procedural Mamluk/trees/props + spec/, edit/, models/ two-way .odin pipeline
│   └── svg/         # zero-dependency SVG parser + 4x4 SSAA anti-aliased rasterizer (icons.odin)
├── tools/
│   └── mesh_cli/    # Playwright-style Cooperative Mesh CLI (bin/dreamcraft-mesh)
├── control/         # JSON command API + localhost HTTP server
├── headless/        # JSONL scripts, file polling, --serve
├── web/             # js_wasm32 2:1 canvas build
├── assets/
│   ├── icons/       # 37 vector UI/HUD/editor .svg icons
│   └── shaders/     # ground.{vs,fs}, unit.{vs,fs}, watercolor.fs
└── tests/           # smoke scripts
```

Legacy archive (not built):

```
legacy/
├── rust/            # Rust + Bevy 0.18 ECS prototype (src, Cargo.*, tests, Trunk.toml)
├── web-console/     # Early Bun/React UI prototype
├── warrior-glb/     # Retired Blender warrior pipeline and GLB outputs
└── reference.jpg    # Visual style reference
bevy-docs/           # Bevy engine reference (gitignored)
```

### Tech Stack
- **Simulation**: Odin (Q16.16 fixed point, fixed 60 Hz tick)
- **Rendering**: SDL3 GPU (Metal / Vulkan) native 3D + procedural meshes + watercolour shaders
- **Layer split**: pure `game` package, `client` renderer, `control` API
- **Testing**: `core:testing`, allocation guard, headless JSONL, HTTP smoke
- **Interactive testing**: `bin/dreamcraft --control` (live screenshot + commands)
- **Legacy**: Rust + Bevy 0.18 + Trunk/WASM (reference only)

## Upcoming Features

1. **Additional Unit Types** - Gatherer, Scout, Melee, Ranged
2. **Resource System** - Gold collection
3. **Multiplayer** - WebTransport networking
4. **WebGPU renderer** - replace the web canvas with a GPU pipeline

## Level Design Principles

1. Start area always visible (player has initial vision radius)
2. Waypoints reveal progressively larger areas (10-cell radius)
3. Goal zone reachable via pathfinding from any waypoint
4. A* ensures path exists — waypoints must NOT be on obstacle cells
5. Obstacles create navigation challenges without blocking progress
6. Minimap provides strategic overview in fog of war
7. Agent Console enables automated testing of level completability

## Resource Definitions

### Tree Clusters (30 total, 132 obstacle cells)
Clusters are distributed across the 80x50 grid to create:
- Navigation obstacles requiring pathfinding
- Visual variety (low-poly trunk + leaf cones)
- Strategic chokepoints
- Entries with (0,0) coordinates are padding (skipped)
