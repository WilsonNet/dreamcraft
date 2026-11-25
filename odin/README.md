# DreamCraft RTS — Odin

Deterministic RTS prototype. Native full 3D isometric client on SDL3 GPU (Metal / Vulkan) with a
pixel-art post shader, plus a lightweight browser canvas build. No GC, fixed
pools, Q16.16 fixed point.

## Build & Run

```bash
./build.sh                 # stable: bin/dreamcraft + bin/headless + web, ~3 s
./run.sh                   # build + launch client
./run.sh --control         # launch with HTTP control API on :7777
./run.sh --control=7780    # custom port
```

Two lanes while developing (always work on `DEV`, then build & restart `Build` when done):

```bash
./build.sh --dev           # bin/dreamcraft-dev + bin/headless-dev, stable untouched
./run-dev.sh --control=7778
./bin/headless-dev --serve=7778 --paused   # deterministic agent lane
./build.sh && ./restart-build.sh           # post-task: build & restart stable game on :7777
```

Always work and test on the `dev` version (`bin/dreamcraft-dev`, `bin/headless-dev`), keeping the
user's stable build in the Herdr `game` pane (`:7777`) untouched mid-task. After finishing any
task, run `./test.sh`, trigger `./build.sh`, and run `./restart-build.sh` so the playable
build version is up to date.

The dev client window title always starts with `DEV - `. `./build.sh --dev` and `./run-dev.sh`
pass `-define:DREAMCRAFT_DEV=true`, and `bin/dreamcraft-dev` is also detected by executable
name, so the `DEV - ` prefix stays even for a manual dev build.

Retired Blender warrior assets & script are archived in `../legacy/warrior-glb/`
and are not part of the build; units are built procedurally in `client/art/`.

Web:

```bash
cd web
./build.sh                 # main.wasm
./serve.sh 8080            # http://localhost:8080/
```

Requirements:

- Odin `dev-2026-11` or newer
- SDL3 (Odin's `vendor:sdl3` bindings link the system library): macOS `brew install sdl3`, Linux your distro's `sdl3` package
- vinland-ui checked out next to this repository (`VINLAND_UI=/path` to override)
- macOS: `brew install odin` (Odin + LLVM)

## Test

```bash
./test.sh
```

Runs (against dev binaries; the stable build is not touched):

1. `odin test game` — simulation unit tests
2. `odin test control` — command/HTTP tests
3. `odin test client/art` — Mamluk mesh, gait weight-wave, catalog override & tree/prop geometry tests
4. `odin test client/art/edit` — Edit_Mesh topology, Blender operators & chunked `.odin` round-trip tests
5. `odin test client/svg` — pure-Odin SVG parser & 4x4 SSAA rasterizer tests across all 37 `assets/icons/*.svg` files
6. `odin test tools/mesh_cli` — Playwright-style positive/negative CLI & cooperative workflow tests
7. `odin test client` — isometric camera, mouse/cursor recovery, command FX, facing/turn & hash tests
8. headless JSONL smoke script
9. replay hash verification
10. web wasm smoke test (Node)
11. HTTP control smoke test
12. `python3 tests/camera_mouse_check.py --launch --mode both --port 7778` — live probe + real macOS OS mouse/camera validation

Individual:

```bash
odin test game -vet -strict-style
odin test control -vet -strict-style
odin test client/art -vet -strict-style
odin test client -vet -strict-style -collection:vinland="${VINLAND_UI:-../../vinland-ui}"
./bin/headless --script tests/smoke.jsonl
./tests/control_smoke.sh
```

## Headless Modes

```bash
./bin/headless --ticks 600             # run 600 ticks, print state
./bin/headless --script tests/smoke.jsonl
./bin/headless --serve=7777            # JSON HTTP API + live simulation
./bin/headless --serve=7777 --paused   # API only; advance with run/tick
./bin/headless                         # poll headless_command.json
./bin/headless --script tests/smoke.jsonl --record replay.jsonl
./bin/headless --replay replay.jsonl   # verifies final hash
```

File protocol:

```bash
echo '{"cmd":"goto","x":10,"y":25}' > headless_command.json
cat headless_result.json
```

## Control API

Available in:

```bash
./bin/headless --serve=7777       # simulation only
./bin/dreamcraft --control=7777   # live game + rendering
```

Endpoints:

| Method | Path | Result |
|--------|------|--------|
| GET | `/health` | `{"ok":true}` |
| GET | `/state` | tick, positions, fog %, hash, validation |
| GET | `/units` | unit list |
| GET | `/fog` | 80×50 ASCII map |
| GET | `/screenshot` | PNG (client only) |
| GET | `/camera` | live camera, zoom, focus, cursor & grip state (client only) |
| POST | `/command` | execute JSON command |
| POST | `/mouse` | inject deterministic mouse/wheel/focus probe frames (client only) |

```bash
curl -s localhost:7777/state
curl -s localhost:7777/units
curl -s localhost:7777/fog

curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"goto","x":10,"y":25}'

curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"run","ticks":140}'

curl -s -X POST localhost:7777/command \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"verify","verify":{"type":"player_at","x":10,"y":25}}'

curl -s localhost:7777/screenshot -o screenshot.png
```

### Commands

Simulation:

- `status`, `state`, `snapshot`
- `goto`/`move`: `x`, `y`
- `patrol`: `x`, `y`, `x2`, `y2`
- `patrol_to`: `x`, `y`
- `attack`: `x`, `y`
- `attack_move`: `x`, `y`
- `stop`
- `run`/`tick`: `ticks`
- `reset`
- `verify`: `verify.type` = `player_at`, `level_complete`, `enemy_dead`,
  `path_clear`, `valid`, `fog_visible`, `blocked`, `hash`

Test hooks:

- `select`: `x`, `y`
- `select_all`
- `spawn`: `team` (`player`/`enemy`), `x`, `y`, optional `value` = HP
- `kill`: `x`, `y`
- `set_hp`: `x`, `y`, `value`
- `teleport`: `x`, `y` (player)

Every response includes:

```json
{
  "ok": true,
  "msg": "Player at expected position",
  "tick": 140,
  "player_grid": [10, 25],
  "valid": true,
  "validation": "ok",
  "hash": 12345
}
```

## Data Model

```
Game {
  tick: u64,
  grid: Grid,            // obstacle bitset
  fog: Fog,              // explored + visible bitsets
  units: Units,          // struct-of-arrays, 256 slots
  pathfinder: Pathfinder,// A* scratch, no allocation
  commands: Command_Queue, // fixed ring, 128 entries
  waypoints: Waypoints,  // fixed array, 8 points
  level_complete: bool,
}
```

Unit references use `{index, generation}` handles:

- destruction bumps the generation
- stale handles fail `unit_index`
- slots are reused via a fixed free list

### Limits

| Limit | Value |
|-------|-------|
| Grid | 80 × 50 |
| Units | 256 |
| Path length | 512 cells |
| Commands queued | 128 |
| Sim rate | 60 Hz |
| Fog vision | 6 cells |
| Unit HP | 100 (`Luk Soldier`), 500 + 5 armor + 4 HP/s regen (`Liiroy, the Bold`) |
| Attack | 15 dmg / 60 ticks (`Luk Soldier`), 35 dmg / 40 ticks (`Liiroy`), 3 cells |
| Move speed | 150 (`Luk Soldier`), 180 (`Liiroy, the Bold`) |
| Campaign aggro delay | 240 ticks (4.0 s grace + discovery banner, instant on hit) |

## Determinism

- Q16.16 integer math only in `game`.
- Fixed 60 Hz tick.
- Fixed system order (`game/sim.odin`).
- No randomness, no wall-clock time in simulation.
- Same state + commands ⇒ same `game_hash`.
- A* tie-break is `f`, then `h`, then cell index.

## Allocation Rules

`game` never allocates during simulation, pathfinding, commands, combat, fog,
or hashing. Tests run under an allocator that counts and rejects allocations,
then assert zero calls after 1000 ticks.

Allowed allocations outside hot paths:

- JSON marshalling/parsing
- HTTP request/response buffers
- screenshot PNG
- headless strings

## Rendering

`client/` renders through `gfx/` (raylib-compatible API on SDL3 GPU, see `specs/11-renderer-port.md`):

- 1280×720 window, resizable (min 800×600), orthographic 3D camera
- ground, grid lines, goal zone, trees, waypoints
- 3-state fog overlay
- units with team color, label, health bars, selection ring
- path gizmo for selected units
- HUD: status, minimap, `[M] Move` / `[A] Attack` / `[P] Patrol` / `[S] Stop` card, pause menu
- minimap: 80×50 RGBA texture scaled to 200×125 with click/drag scrub and clipped isometric camera frame

Screenshot endpoint returns PNG bytes directly from memory via `ExportImageToMemory` (no temp file).

## Architecture Rules

- `game` imports no rendering or HTTP code.
- `client` and `control` are adapters over `Game`.
- Simulation functions ≤ 50 lines; files ≤ 420 lines.
- `-vet -strict-style` clean.
- Use fixed arrays/slices in hot paths.
- No Bevy BRP MCP; the control API replaces it.
