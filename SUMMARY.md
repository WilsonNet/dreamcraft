# DreamCraft RTS - Project Summary

## Goal

Build a fantasy RTS called **DreamCraft** with:
- Odin for deterministic game logic (Rust/Bevy prototype is legacy)
- A* pathfinding for unit navigation
- Tutorial "Through the Woods" level: navigate trees and fog to the goal
- Long-term web/WebGPU target; native raylib is the current renderer

## Instructions

- Primary work goes in `odin/`
- Use `./run.sh`, `./build.sh`, `./test.sh`
- Use Odin control API instead of Bevy BRP MCP:
  - `bin/dreamcraft --control=7777`
  - `bin/headless --serve=7777`
  - `GET /state`, `/units`, `/fog`, `/screenshot`; `POST /command`
- Use Herdr tabs/panes (`--no-focus`) for long-running processes
- Max 3 attempts before searching online docs
- Bevy docs at `bevy-docs/` are legacy reference only

## Discoveries

1. **Bevy error B0001** - Query conflict in `attack_system`; fixed with `ParamSet`.
2. **Trunk WASM** requires `rlib` crate-type and unique bin/lib names.
3. **Odin fixed pools** - struct-of-arrays + generation handles remove the
   need for an ECS entity allocator.
4. **Odin A*** - one entry per cell with `heap_pos`, stamp arrays, and a
   caller-provided path slice gives allocation-free deterministic paths.
5. **Edge-scroll drift** - check `IsWindowFocused()` and `IsCursorOnScreen()`;
   otherwise an unfocused window scrolls the camera to its clamp.
6. **Odin JSON tests** - free both the dynamic array and string fields after
   `json.unmarshal` to satisfy leak tracking.

## Accomplished (Odin)

- Deterministic 60 Hz Q16.16 simulation
- 80x50 grid, 30 tree clusters, 132 obstacle cells
- 8-way A*, fog of war, waypoints, goal
- 256-slot SoA unit pool with generation handles
- Melee combat, enemy chase AI, patrol loops
- Native raylib full 3D isometric client with Age of Empires × Toriyama world scale and watercolour post shader
- Procedural 26-bone Mamluk warrior & forest props in `odin/client/art/`, kinetic-chain idle/walk/attack animations, and double-crescent slash VFX
- Two-lane build: stable `bin/dreamcraft` on `:7777`, dev binaries on `:7778`
- Browser WASM/canvas client with DOM HUD and `window.dreamcraft` API
- Headless JSONL scripts, HTTP control server, hash-verified replays
- Curve/state validation after every tick
- 88 native unit tests + web WASM/headless/replay/HTTP smoke: invariants,
  allocations, determinism, HTTP round trip, browser API
- Bevy BRP MCP removed; control API replaces it

## Relevant files / directories

```
odin/
├── game/       # pure simulation
├── client/     # raylib renderer/input/HUD/minimap/VFX/shaders
│   └── art/    # procedural Mamluk model, 26-bone rig, anims, trees, props
├── control/    # JSON API + localhost HTTP server
├── headless/   # scripts, polling, --serve, record/replay
├── web/        # js_wasm32 2:1 canvas client + DOM HUD
├── assets/
│   └── shaders/# ground.{vs,fs}, unit.{vs,fs}, watercolor.fs
├── tests/      # smoke, replay, control tests
├── build.sh       # stable lane
├── test.sh        # tests + dev lane
├── run.sh
├── run-dev.sh
└── restart-build.sh
legacy/            # rust/, web-console/, warrior-glb/, reference.jpg
specs/
└── 08-odin-port.md
```

## Current Status

Tutorial Level 1 is playable and testable:
- Right-click move/attack, left-click/drag selection
- Move re-orders keep mid-cell interpolation (no teleport/rollback)
- Fog reveal, waypoint progression, goal completion
- Enemy combat and patrol commands
- Headless and live HTTP control for agents
- Client screenshot endpoint
