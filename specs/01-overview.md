# DreamCraft RTS - Game Specification

## Vision

A web-based fantasy RTS game — spiritual successor to StarCraft: Brood War. Deterministic sync, low latency networking, and high-performance WebGPU rendering.

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

### Completed Features

#### Tutorial Level 1: "Through the Woods"
- [x] Grid-based level (80x50 cells, 32px per cell)
- [x] Blue player unit (circle with "M" label) with right-click movement
- [x] Red enemy unit (circle with "M" label) at (50, 25) - hidden in fog
- [x] Team/race semantics clarified: available races are `Basic`, `Akana`, `Gorg`; Level 1 uses `Basic` for both teams; color indicates team, `M` indicates Melee type
- [x] Tree clusters (30 clusters, 132 obstacle cells)
- [x] Golden goal zone on the right side
- [x] A* pathfinding (Rust implementation using BinaryHeap)
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
- [x] Playwright MCP integration for automated validation
- [x] Level completable headlessly (goto waypoints, verify state)
- [x] Native headless mode with file-based commands (`headless_command.json`)
- [x] BRP (Bevy Remote Protocol) support for MCP tools

### Known Issues
- [ ] Waypoint 3 at (40,20) collides with tree cluster 7 — pathfinding skips it
- [ ] Camera doesn't auto-follow player (must pan manually)
- [ ] Native build broken (wasm-only extern blocks need cfg guards)

#### Waypoints for Level 1
```
(10,25) -> (20,25) -> (30,25) -> (40,20)* -> (50,25) -> (60,25) -> (70,25) -> (77,25)
Player starts at (2,25). Goal zone at x >= 77.
* (40,20) blocked by tree cluster — needs relocation
```

### Architecture

```
dreamcraft/
├── src/
│   ├── lib.rs              # Main game plugin (all ECS systems)
│   │   ├── setup_tutorial_level  — spawns entities, grid, fog, waypoints
│   │   ├── handle_input          — right-click movement via A* pathfinding
│   │   ├── read_console_commands — reads commands from localStorage
│   │   ├── unit_movement         — moves player along A* path
│   │   ├── camera_controls       — WASD/arrow panning
│   │   ├── check_goal            — level completion check
│   │   ├── update_visibility     — reveals cells around player
│   │   ├── update_fog            — fades fog cells when revealed
│   │   ├── check_waypoint_reached — advances waypoint target
│   │   ├── broadcast_minimap_data — sends minimap grid to localStorage
│   │   └── debug_console_output  — sends full debug state to localStorage
│   ├── main.rs             # Native entry point
│   └── web.rs              # WASM entry point (minimal)
├── index.html              # Trunk entry — game + React console + React minimap
├── web/                    # Legacy Bun-based React UI (not primary)
├── specs/                  # Game specifications (this folder)
└── bevy-docs/              # Bevy engine reference
```

### Controls
- **Right-Click**: Move unit to location (A* pathfinding)
- **WASD/Arrows**: Pan camera
- **Left-Click Minimap**: Center camera on clicked map position
- **Backtick (`` ` ``)**: Toggle Agent Console

### Tech Stack
- **Logic**: Rust + Bevy 0.18 ECS
- **Rendering**: Bevy 2D (Mesh2d, Circle, Rectangle, Gizmos)
- **UI Overlays**: React 19 (CDN, rendered in same page)
- **Target**: WebAssembly via Trunk (port 8080)
- **Testing**: Playwright MCP (headless browser control)
- **Interop**: localStorage bridge (Bevy <-> React)

## Upcoming Features

1. **Camera Follow Mode** - Auto-follow player with manual override
2. **Fix Waypoint 3** - Relocate from (40,20) to clear cell
3. **Isometric View** - Diagonal 2:1 grid rendering
4. **Additional Unit Types** - Gatherer, Scout, Melee, Ranged
5. **Resource System** - Gold collection
6. **Combat System** - Attack animations and damage
7. **Multiplayer** - WebTransport networking
8. **WebGPU Rendering** - High-performance shaders

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
