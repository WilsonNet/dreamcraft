# DreamCraft RTS

A deterministic fantasy RTS — spiritual successor to StarCraft: Brood War.

The primary implementation is now **Odin + raylib** (`odin/`). It compiles in
about 1–3 seconds, uses fixed-capacity data structures, and has no garbage
collector. The original Rust/Bevy prototype remains in `src/` for reference.

## Quick Start

```bash
cd odin
./run.sh                 # build + launch native client
./run.sh --control       # launch with the HTTP control API on :7777
```

```bash
cd odin
./test.sh                # unit tests + headless script + HTTP control tests
./build.sh               # build client + headless binaries
```

## Controls

- **Right-click**: move, or attack an enemy
- **Left-click / drag**: select units
- **WASD / Arrows**: pan camera
- **Move / Patrol HUD buttons**: command modes
- **Esc**: pause menu (Retry / Resume)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Simulation | Odin, Q16.16 fixed point, fixed-timestep 60 Hz |
| Rendering | raylib 6.2 (native) |
| Units | Struct-of-arrays, generation handles, fixed pools |
| Pathfinding | Allocation-free A*, preallocated scratch |
| Fog | Two bitsets (explored / visible) |
| Testing | `core:testing`, headless scripts, HTTP control API |
| Legacy | Rust + Bevy 0.18 (`src/`) |

## Odin Layout

```
odin/
├── game/        # pure deterministic simulation (no rendering, no allocation)
├── client/      # raylib native client, HUD, minimap, input
├── control/     # JSON control API + localhost HTTP server
├── headless/    # file/script runner and --serve mode
├── tests/       # smoke scripts
├── build.sh
├── test.sh
└── run.sh
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
| `GET /state` | tick, player, enemy, fog %, hash, invariant status |
| `GET /units` | all units (position, hp, state, path, target) |
| `GET /fog` | 80×50 ASCII map (`P`, `E`, `#`, `w`, `W`, `G`, `.`) |
| `GET /screenshot` | PNG of the live client window |
| `POST /command` | execute a JSON command |

```bash
curl -s localhost:7777/state
curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"goto","x":10,"y":25}'
curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"run","ticks":140}'
```

Commands: `status`, `goto`, `patrol`, `attack`, `stop`, `run`, `reset`,
`verify`, `select`, `select_all`, `spawn`, `kill`, `set_hp`, `teleport`.

Every response includes `valid` and `validation`, so an agent can detect
simulation invariant violations immediately.

## Specs

Detailed specifications live in [`specs/`](specs/):

| Spec | Description |
|------|-------------|
| [01-overview.md](specs/01-overview.md) | Vision, features, implementation status |
| [02-units.md](specs/02-units.md) | Unit types, stats, abilities |
| [03-isometric.md](specs/03-isometric.md) | Grid rendering, coordinate systems |
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
