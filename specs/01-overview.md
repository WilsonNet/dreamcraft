# DreamCraft RTS - Game Specification

## Vision

A fantasy RTS — spiritual successor to StarCraft: Brood War. Current renderer is native raylib; long-term targets are web/WebGPU, deterministic sync, and low-latency networking.

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

### Odin Port (Primary, native)

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
- [x] Native raylib 6.2 client: world, fog, units, paths, HUD, minimap
- [x] Headless runner: file polling, JSONL scripts, `--ticks`
- [x] HTTP control API replacing Bevy BRP MCP
  - [x] `GET /state`, `/units`, `/fog`, `/screenshot`, `/health`
  - [x] `POST /command`: move, patrol, attack, stop, run, reset, verify,
        select, spawn, kill, set_hp, teleport
  - [x] Every response carries `valid` + `validation`
- [x] 65 unit/integration tests (game + control)
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

#### Screen Edge Scrolling
- [x] Progressive scroll speed (faster closer to edge)
- [x] 20px activation zone from screen edges
- [x] Speed ramps from 200 to 600 px/sec
- [x] Works alongside WASD camera controls

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
- [ ] Camera doesn't auto-follow player (must pan manually)
- [ ] Odin web/WASM build not started (native raylib only)

### Controls
- **Right-Click**: Move unit to location; right-click on enemy = attack
- **WASD/Arrows**: Pan camera
- **Screen Edge Scroll**: Mouse at screen edge pans camera (progressive speed)
- **Left-Click Minimap**: Center camera on clicked map position
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
├── game/           # pure deterministic simulation (no raylib, no allocation)
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
├── client/          # raylib native rendering, input, HUD, minimap
├── control/         # JSON command API + localhost HTTP server
├── headless/        # JSONL scripts, file polling, --serve
└── tests/           # smoke scripts
```

Legacy prototype:

```
src/                 # Rust + Bevy 0.18 ECS
index.html           # Trunk/React prototype entry
web/                 # Legacy Bun React UI
bevy-docs/           # Bevy engine reference
```

### Tech Stack
- **Simulation**: Odin (Q16.16 fixed point, fixed 60 Hz tick)
- **Rendering**: raylib 6.2 native
- **Layer split**: pure `game` package, `client` renderer, `control` API
- **Testing**: `core:testing`, allocation guard, headless JSONL, HTTP smoke
- **Interactive testing**: `bin/dreamcraft --control` (live screenshot + commands)
- **Legacy**: Rust + Bevy 0.18 + Trunk/WASM (reference only)

## Upcoming Features

1. **Camera Follow Mode** - Auto-follow player with manual override
2. **Isometric View** - Diagonal 2:1 grid rendering
3. **Additional Unit Types** - Gatherer, Scout, Melee, Ranged
4. **Resource System** - Gold collection
5. **Multiplayer** - WebTransport networking
6. **Web/WASM Odin build** - raylib web backend or WebGPU
7. **Replay files** - command log + state hash verification

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
- Visual variety (trunk + leaves sprites)
- Strategic chokepoints
- Entries with (0,0) coordinates are padding (skipped)
