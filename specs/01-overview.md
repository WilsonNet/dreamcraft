# DreamCraft RTS - Game Specification

## Vision

A web-based fantasy RTS game with deterministic sync, low latency networking, and high-performance WebGPU rendering.

## Core Features

1. **Isometric 2:1 Grid** - StarCraft-style top-down diagonal view
2. **Unit Types**:
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
- [x] Grid-based level (40x30 cells, 32px per cell)
- [x] Blue player unit (circle) with movement
- [x] Tree clusters (12 clusters, 54 tree cells)
- [x] Golden goal zone on the right side
- [x] A* pathfinding (Rust implementation)
- [x] Path visualization with gizmos
- [x] WASD/Arrow camera controls
- [x] Tutorial UI overlay
- [x] Level complete detection
- [x] Fog of War system
  - [x] Dark fog overlay covering unexplored areas
  - [x] Player vision radius (5 cells)
  - [x] Progressive fog reveal
- [x] Waypoint system
  - [x] Intermediate waypoints guiding player through fog
  - [x] Golden waypoint markers for current target
  - [x] Faded markers for future waypoints
  - [x] Reveal large area when reaching waypoint

#### Waypoints for Level 1
```
Waypoint Path:
(8, 15) -> (15, 15) -> (22, 15) -> (28, 12) -> (34, 15) -> (37, 15)
```

### Architecture

```
dreamcraft/
├── src/
│   ├── lib.rs              # Main game plugin
│   │   ├── A* pathfinding
│   │   ├── Fog of War system
│   │   ├── Waypoint system
│   │   └── Level setup
│   ├── main.rs             # Native entry point
│   └── web.rs              # WASM entry point
├── web/
│   ├── test.html           # Headless pathfinding tests
│   └── index.html          # Main game HTML
├── specs/                   # Game specifications
└── bevy-docs/              # Bevy engine reference
```

### Controls
- **Right-Click**: Move unit to location (triggers A* pathfinding)
- **WASD/Arrows**: Pan camera

### Tech Stack
- **Logic**: Rust + Bevy ECS
- **Rendering**: Bevy 2D (Mesh2d)
- **Target**: WebAssembly via Trunk
- **Testing**: Playwright MCP

## Upcoming Features

1. **Isometric View** - Diagonal 2:1 grid rendering
2. **Additional Unit Types** - Gatherer, Scout, Melee, Ranged
3. **Resource System** - Gold collection
4. **Combat System** - Attack animations and damage
5. **Multiplayer** - WebTransport networking
6. **WebGPU Rendering** - High-performance shaders

## Level Design Principles

1. Start area always visible (player has initial vision)
2. Waypoints reveal progressively larger areas
3. Goal zone always visible from the last waypoint
4. A* ensures path exists from start to goal through all waypoints
5. Obstacles create interesting navigation challenges without blocking progress
