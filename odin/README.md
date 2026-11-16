# DreamCraft RTS — Odin

Deterministic RTS prototype. Odin native raylib client + browser WASM/canvas
build. No GC, fixed pools, Q16.16 fixed point.

## Build & Run

```bash
./build.sh                 # bin/dreamcraft + bin/headless, ~3 s
./run.sh                   # build + launch client
./run.sh --control         # launch with HTTP control API on :7777
./run.sh --control=7780    # custom port
```

Web:

```bash
cd web
./build.sh                 # main.wasm
./serve.sh 8080            # http://localhost:8080/
```

Requirements:

- Odin `dev-2026-11` or newer
- raylib vendor bindings (included with Odin)
- macOS: `brew install odin` (installs raylib + LLVM)

## Test

```bash
./test.sh
```

Runs:

1. `odin test game` — simulation unit tests
2. `odin test control` — command/HTTP tests
3. headless JSONL smoke script
4. replay hash verification
5. web wasm smoke test (Node)
6. HTTP control smoke test

Individual:

```bash
odin test game -vet -strict-style
odin test control -vet -strict-style
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
| POST | `/command` | execute JSON command |

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
- `attack`: `x`, `y`
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
| Unit HP | 100 |
| Attack | 15 damage, 3 cells, 60 ticks |

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

`client/` uses raylib:

- 1280×720 window, 2D camera
- ground, grid lines, goal zone, trees, waypoints
- 3-state fog overlay
- units with team color, label, health bars, selection ring
- path gizmo for selected units
- HUD: status, minimap, Move/Patrol buttons, pause menu
- minimap: 80×50 RGBA texture scaled to 200×125

Screenshot endpoint captures the current window to
`control_screenshot.png` and serves it as PNG.

## Architecture Rules

- `game` imports no rendering or HTTP code.
- `client` and `control` are adapters over `Game`.
- Simulation functions ≤ 50 lines; files ≤ 420 lines.
- `-vet -strict-style` clean.
- Use fixed arrays/slices in hot paths.
- No Bevy BRP MCP; the control API replaces it.
