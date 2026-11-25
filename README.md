# DreamCraft RTS

A deterministic fantasy RTS — spiritual successor to StarCraft: Brood War,
rendered in full 3D isometric on native (SDL3 GPU: Metal / Vulkan) with a pixel-art post shader;
the browser build keeps a lightweight 2:1 canvas view.

The primary implementation is **Odin** (`odin/`): native SDL3 GPU client plus a
browser WASM/canvas build. It compiles in seconds, uses fixed-capacity data
structures, and has no garbage collector. Deprecated prototypes (`rust/`,
`web-console/`, `warrior-glb/`, `reference.jpg`) are archived under `legacy/`.

## Quick Start

```bash
cd odin
./run.sh                 # build + launch native client
./run.sh --control       # launch with the HTTP control API on :7777
```

```bash
cd odin/web
./build.sh && ./serve.sh 8080   # browser build at http://localhost:8080
```

```bash
cd odin
./test.sh                # unit + headless + replay + web + HTTP tests
./build.sh               # stable build: client + headless + web
```

Two-lane development (always develop on `DEV`, then trigger a stable build after finishing a task):

```bash
cd odin
./build.sh --dev                            # dev binaries (window title prefixed "DEV - ")
./run-dev.sh --control=7778                 # interactive dev client on :7778
./bin/headless-dev --serve=7778 --paused    # deterministic agent lane
./build.sh && ./restart-build.sh            # post-task: build & restart playable game on :7777
```

## Controls

- **Right-click**: move, or attack an enemy (with 3D ground confirmation FX)
- **Left-click / drag**: select units (Shift+click adds)
- **Middle-mouse / `Space` + Left drag**: Dota 2 / SC2 Camera Grip (1:1 ground drag)
- **WASD / Arrows / Screen edges**: isometric pan (switches to FREE)
- **Mouse wheel**: smooth orthographic zoom
- **Minimap click / drag**: recenter and scrub camera across map
- **M / A / P / S (or HUD card)**: Move, Attack-Move (StarCraft-style), 1-click Patrol, Stop
- **F**: toggle camera FOLLOW / FREE
- **Esc**: cancel command mode, or open pause menu (Retry / Resume)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Simulation | Odin, Q16.16 fixed point, fixed-timestep 60 Hz |
| Rendering | SDL3 GPU (Metal / Vulkan) via `odin/gfx` + procedural art + watercolour & terrain shaders (native) / HTML canvas (web) |
| Units | Struct-of-arrays, generation handles, fixed pools |
| Pathfinding | Allocation-free A*, preallocated scratch |
| Fog | Two bitsets (explored / visible) |
| Testing | `core:testing`, headless scripts, HTTP control API, Node WASM smoke |
| Legacy | Rust + Bevy 0.18, early web console, GLB pipeline (`legacy/`) |

## Repository & Odin Layout

```
odin/
├── game/          # pure deterministic simulation (no rendering, no allocation)
├── gfx/           # raylib-compatible API on SDL3 GPU, game shaders (MSL + SPIR-V)
├── client/        # native client, HUD, minimap, input, VFX
│   └── art/       # procedural Mamluk mesh, 26-bone rig, anims, trees, props
├── control/       # JSON control API + localhost HTTP server
├── headless/      # file/script runner, --serve, --record/--replay
├── web/           # js_wasm32 build, 2:1 canvas renderer, DOM HUD
├── assets/
│   └── shaders/   # ground.{vs,fs}, unit.{vs,fs}, watercolor.fs
├── tests/         # smoke and replay scripts
├── build.sh
├── test.sh
├── run.sh
├── run-dev.sh
└── restart-build.sh

legacy/            # archived prototypes (not built or tested)
├── rust/          # Rust/Bevy 0.18 prototype
├── web-console/   # early Bun/React UI
├── warrior-glb/   # retired Blender pipeline + GLB outputs
└── reference.jpg  # early art reference
```

## Control API (replaces Bevy BRP MCP)

The Bevy Remote Protocol MCP integration was removed. The replacement is a
localhost JSON API available in both binaries.

```bash
# Headless simulation server
./odin/bin/headless --serve=7777
./odin/bin/headless --serve=7777 --paused   # API only; run/tick advances

# Live game (renders + accepts control requests)
./odin/bin/dreamcraft --control=7777
```

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | liveness |
| `GET /state` | tick, player, enemy, fog %, game_over, hash, invariant status |
| `GET /units` | all units (position, hp, state, path, target) |
| `GET /fog` | 80×50 ASCII map (`P`, `E`, `#`, `w`, `W`, `G`, `.`) |
| `GET /screenshot` | PNG of the live client window |
| `GET /camera` | live camera, zoom, focus, cursor & grip state (client) |
| `POST /command` | execute a JSON command |
| `POST /mouse` | inject client mouse/wheel/focus probe frames (client) |

```bash
curl -s localhost:7777/state
curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"goto","x":10,"y":25}'
curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"run","ticks":140}'
```

Commands: `status`, `goto`, `patrol`, `patrol_to`, `attack`, `attack_move`,
`stop`, `run`, `reset`, `verify`, `select`, `select_all`, `spawn`, `kill`,
`set_hp`, `teleport`.

Every response includes `valid` and `validation`, so an agent can detect
simulation invariant violations immediately.

## Specs

Detailed specifications live in [`specs/`](specs/):

| Spec | Description |
|------|-------------|
| [01-overview.md](specs/01-overview.md) | Vision, features, implementation status |
| [02-units.md](specs/02-units.md) | Unit types, stats, abilities |
| [03-isometric.md](specs/03-isometric.md) | 3D isometric renderer, picking, pixel shader |
| [04-input.md](specs/04-input.md) | Control schemes, input handling |
| [05-networking.md](specs/05-networking.md) | Multiplayer architecture |
| [06-agent-console.md](specs/06-agent-console.md) | Agent diagnostics and control |
| [07-minimap.md](specs/07-minimap.md) | Minimap implementation |
| [08-odin-port.md](specs/08-odin-port.md) | Odin architecture, allocation model, control API |

## Current State: Tutorial Level 1

"Through the Woods" — navigate a melee unit through fog to the goal zone.

- 80×50 grid, 132 tree obstacle cells
- Deterministic A* with 8-direction movement
- 3-state fog of war, 8 waypoints
- Melee combat, enemy chase AI, patrol loops
- StarCraft-style minimap and RTS HUD
- Headless and live HTTP control for automated testing
