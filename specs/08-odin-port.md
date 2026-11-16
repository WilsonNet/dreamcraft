# Odin Port Specification

## Goal

Replace the Rust/Bevy implementation with Odin for fast iteration and strict
memory control. The Odin port is the primary codebase; Rust remains as a
reference prototype.

Measured on this machine (Apple Silicon):

| Build | Time |
|-------|------|
| Odin client + headless, `-o:speed` | ~2.8 s total |
| Bevy client, incremental | tens of seconds to minutes |
| Odin unit tests (77 tests) | < 30 ms runtime |

## Why Odin for an RTS

- Fast compiler (seconds, not minutes).
- Explicit allocators and no GC.
- Fixed-capacity arrays and slices; no hidden `Vec` growth.
- Struct-of-arrays and bitsets are straightforward.
- `core:testing` has leak tracking and a parallel test runner.
- Easy C ABI/foreign calls (raylib).
- Deterministic integer math; no hidden float behavior.

## Package Layout

```
odin/
├── game/        # pure simulation, imports no rendering libraries
├── client/      # raylib native client
├── control/     # JSON command model + localhost HTTP server
├── headless/    # JSONL scripts, file polling, --serve, replay
├── web/         # js_wasm32 build, canvas renderer, DOM HUD
└── tests/       # shell/JSONL smoke tests
```

`game` is the only package that defines simulation rules. `client` and
`control` are adapters. Tests import `game` directly.

## Build Lanes

Two binaries stay separate so manual play never interrupts development:

| Lane | Binary | Control port | Purpose |
|------|--------|--------------|---------|
| Stable | `bin/dreamcraft` | `:7777` | user play session, tmux `dreamcraft:game` |
| Dev | `bin/dreamcraft-dev` | `:7778` | agent reproduction and visual checks |
| Dev headless | `bin/headless-dev` | `:7778` | deterministic `run`/`tick` stepping |

- The dev client window title is always `DEV - DreamCraft RTS ...`.
  `build.sh --dev` defines `DREAMCRAFT_DEV=true`; the client also checks its
  executable name, so `bin/dreamcraft-dev` keeps the prefix when built by hand.
- `./build.sh --dev` builds only the dev lane.
- `./test.sh` builds dev binaries and never overwrites the stable lane.
- `./build.sh` builds the stable lane plus the web build.
- `./restart-build.sh` restarts the stable tmux session.
- Close-out order: tests → stable build → restart → update docs/specs.
- `GET /units` returns `world` (float world position), `progress` (cells
  between `position` and `next`) and `next` (current path cell). These make
  position jumps measurable through the control API.

## Data Model

### Constants

| Constant | Value |
|----------|-------|
| `GRID_W`, `GRID_H` | 80, 50 |
| `GRID_CELLS` | 4000 |
| `CELL_SIZE` | 32 world units |
| `MAX_UNITS` | 256 |
| `MAX_PATH` | 512 cells per unit |
| `MAX_COMMANDS` | 128 queued commands |
| `TICK_RATE` | 60 Hz |
| `VISION_RADIUS` | 6 cells |
| `MAX_HP` | 100 |
| `ATTACK_DAMAGE` | 15 |
| `ATTACK_RANGE` | 3 cells |
| `ATTACK_COOLDOWN_TICKS` | 60 |

### `Game`

`Game` is one value type with no pointers:

```
Game {
    tick: u64,
    grid: Grid,
    fog: Fog,
    units: Units,
    pathfinder: Pathfinder,
    commands: Command_Queue,
    waypoints: Waypoints,
    level_complete: bool,
}
```

No component map, no entity allocator, no dynamic arrays. It can be copied,
hashed, and reset deterministically.

### `Units` (struct-of-arrays)

```
Units {
    alive: [MAX_UNITS]bool,
    generation: [MAX_UNITS]u32,
    team/race/kind: [MAX_UNITS]enum,
    position: [MAX_UNITS]Grid_Pos,
    world: [MAX_UNITS]Fixed_Vec,
    hp/hp_max: [MAX_UNITS]u16,
    state: [MAX_UNITS]Unit_State,
    path: [MAX_UNITS][MAX_PATH]u16,
    path_len/path_index: [MAX_UNITS]u16,
    progress: [MAX_UNITS]Fp,
    patrol_*: [MAX_UNITS]...,
    attack_target: [MAX_UNITS]Unit_Handle,
    cooldown: [MAX_UNITS]u16,
    selected: [MAX_UNITS]bool,
    free_slots: [MAX_UNITS]u16,
    counters,
}
```

Handles are `{index: u16, generation: u32}`.

- `unit_spawn` pops a free slot and increments generation.
- `unit_destroy` marks dead, bumps generation, pushes the slot.
- `unit_index` rejects dead slots and generation mismatches.
- Stale handles can never address a recycled unit.
- 256 units × 512 path cells = 256 KiB of path storage, allocated once.

### Grid and fog

- `Bit_Grid` is `[63]u64` for 4000 cells.
- Obstacles are one bitset; `obstacle_count` is cached and validated.
- Fog is two bitsets: `explored` and `visible`.
- Fog state: 0 unexplored, 1 explored, 2 visible.
- `fog_begin_tick` clears only `visible`; `explored` persists.
- No `[][]bool`, no per-cell entity, no per-frame allocation.

### Pathfinding

`Pathfinder` owns:

- `g_score`, `h_score`, `f_score`
- `parent`
- `seen_stamp`, `closed_stamp` (avoid clearing arrays every search)
- binary heap (`heap`, `heap_pos`) with one entry per cell

Properties:

- 8-neighbor A*, octile heuristic, step costs 10/14.
- Deterministic tie-break: `f`, then `h`, then cell index.
- Diagonal movement is allowed unless both side-adjacent cells are blocked.
- Writes into a caller-provided `[]u16`; returns `Path_Result`.
- No allocation, no recursion.
- `path_is_valid` checks start, bounds, obstacles, adjacency, and goal.

### Movement

- Q16.16 fixed point (`Fp = i32`, 16 fractional bits).
- Speed 150 world units/s = 5120 Q16.16 units/tick.
- Cell centers are fixed world positions.
- Each tick moves along the path with progress in cells; diagonal segments
  use `FP_SQRT2` (92682).
- No float normalization, no per-frame `Vec`.

### Commands

`Command_Queue` is a fixed ring buffer.

```
Command {
    kind: Move | Attack | Patrol | Stop,
    actor: Unit_Handle,
    position, point_b: Grid_Pos,
    target: Unit_Handle,
}
```

- Validated on push: actor alive, destination walkable, target enemy.
- Revalidated on execution.
- Full queue rejects the command and increments `rejected`.
- A command without an actor applies to selected player units; if none are
  selected, it applies to all player units (preserves tutorial behavior).

### Combat

- Attack range is Euclidean squared (`dx² + dy² <= 9`).
- Damage 15, cooldown 60 ticks.
- `attack_movement` repaths only when the destination cell changed.
- `death_check` collects dead indices first, then destroys them.
- Destroying a unit clears all attack targets that reference its handle.

## Determinism Contract

`sim_tick` order is fixed:

1. increment tick
2. apply command queue
3. enemy AI target selection
4. attack movement
5. patrol leg continuation
6. unit movement
7. combat tick
8. death check
9. fog update
10. waypoint progress
11. goal check
12. invariant validation

Rules:

- No floating point in `game`.
- No allocation in `game` hot paths.
- No randomness.
- No wall-clock time; one tick is one update.
- Same initial state + same command sequence = same `game_hash`.
- Tests run the same script on two `Game` values and compare hashes.

## Movement Continuity

A move order must never teleport the unit.

- `position` is the last reached cell; `world` is the interpolated render
  position.
- When a move order arrives mid-segment, the new path is planned from
  `path[path_index]` (the cell being entered) and `progress`/`world` are kept.
  The unit keeps walking forward; it does not snap back to `position`.
- Attack orders keep the current path; `attack_movement` replans from the
  segment being walked. An in-range unit finishes the current segment before
  stopping (`unit_stop_after_segment`).
- Destination validation happens before any path or world field changes.
  An order to a blocked cell is rejected and the current path continues.
- The validator allows `path[0] != position` only while `progress > 0`, which
  is exactly the preserved mid-segment state.
- Regression tests cover straight re-orders, blocked clicks, and re-orders
  while routing past tree clusters.

## Validation Matrix

`validate_game` checks:

| Area | Checks |
|------|--------|
| Grid | obstacle count matches bitset |
| Fog | visible is a subset of explored |
| Counters | alive/selected/free counts match slots |
| Free list | no duplicates, no live slots |
| Handles | generation nonzero, attack targets resolve |
| Units | bounds, world bounds, health, cooldown |
| Paths | length, index, bounds, obstacles, adjacency, detached path |
| State | `Moving` implies a path; `Patrol` implies active patrol |
| Target | no stale handle, no friendly fire, no self-target |
| Selection | only player units selected |
| Waypoints | count, bounds, walkable, current index |
| Commands | count and ring indices |
| Player | at least one player unit exists |

`level_validate` additionally proves:

- start and enemy spawn are walkable,
- all waypoints are walkable,
- all waypoints are reachable sequentially from the start,
- the goal cell is walkable.

Validator branches are tested by deliberately corrupting state.

## Allocation Policy

- Simulation, pathfinding, fog, commands, combat: **zero allocations**.
- Tests set `context.allocator` to a probe that counts and rejects allocations;
  `game_init` + 1000 ticks + hash must report `calls == 0`.
- Client/control/headless may allocate for JSON, strings, HTTP, and PNG
  screenshots. Those are outside the simulation tick.
- Fixed pools only inside `game`: units, paths, commands, A* scratch.
- No package manager; Odin core/vendor only.

## Control API (replaces Bevy BRP MCP)

Bevy BRP MCP was removed:

- deleted `bevy_brp` from `.opencode/opencode.json`
- removed `bevy_remote` feature and `bevy_brp_extras` from `Cargo.toml`
- removed `RemotePlugin` and `BrpExtrasPlugin` from `src/main.rs`

Replacement endpoints (`control/http.odin`):

| Method | Path | Response |
|--------|------|----------|
| GET | `/health` | `{"ok":true}` |
| GET | `/state` | tick, player/enemy, fog %, hash, valid, validation |
| GET | `/units` | array of units with team/pos/hp/state/path/target |
| GET | `/fog` | ASCII 80×50 map (`P E # w W G .`) |
| GET | `/screenshot` | PNG of the live client (501 in headless) |
| POST | `/command` | execute a command, return result |

Commands:

| Command | Fields | Purpose |
|---------|--------|---------|
| `status`/`state` | — | snapshot |
| `goto`/`move` | `x,y` | move selected/all player units |
| `patrol` | `x,y,x2,y2` | A↔B patrol loop |
| `attack` | `x,y` | attack enemy at cell |
| `stop` | — | clear path/attack/patrol |
| `run`/`tick` | `ticks` | advance fixed ticks |
| `reset` | — | reset level |
| `verify` | `verify.type` | player_at, level_complete, enemy_dead, path_clear, valid, fog_visible, blocked, hash |
| `select` | `x,y` | select player at cell |
| `select_all` | — | select all player units |
| `spawn` | `team,x,y,value?` | test hook: spawn unit |
| `kill` | `x,y` | test hook: destroy unit |
| `set_hp` | `x,y,value` | test hook: set HP |
| `teleport` | `x,y` | test hook: move player |

Every result includes:

```
ok, msg, tick, player_grid, player_alive, enemy_alive,
level_complete, waypoint, fog_percent, alive_units,
selected, command_rejected, hash, valid, validation
```

The server is single-threaded and polled from the main loop. It listens on
IPv4 loopback only, with a 250 ms receive timeout and a 16 KiB request limit.
Start the headless server with `--paused` for deterministic API testing: only
`run`/`tick` commands advance the simulation.

## Test Strategy

Layers:

1. **Unit tests** (`odin test game`): fixed math, bitsets, fog, A*, unit pool,
   commands, movement, combat, patrol, waypoints, goal, validation branches,
   reset, determinism, zero allocation.
2. **Control tests** (`odin test control`): command execution, snapshots,
   unit/fog encoding, HTTP parser, HTTP round trip on localhost.
3. **Headless JSONL** (`tests/smoke.jsonl`): status, move, verify, kill, spawn,
   attack, reset, invariant checks.
4. **HTTP smoke** (`tests/control_smoke.sh`): start `--serve`, curl all
   endpoints, run a move command, verify position, verify invariants.
5. **Visual smoke**: `--control`, `GET /screenshot`, inspect PNG.

`./test.sh` runs all of the above.

## Odin Best Practices Applied

- Prefer fixed arrays and slices; avoid `[dynamic]` in hot paths.
- Pass explicit allocators when allocation is required; never rely on the
  global allocator in simulation code.
- Use `context.allocator` / `context.temp_allocator` deliberately in tools.
- Use `#partial switch` only with an intentional default.
- Compile with `-vet -strict-style` and fix warnings.
- Keep procedures under 50 lines and files under 420 lines.
- Use `core:testing` with leak tracking; free JSON strings and slices.
- Use `defer` for file/socket/temp-memory cleanup.
- Keep the simulation package free of renderer imports.
- Represent entity references with generation handles, not pointers.
- Pack booleans into bitsets when iterated heavily (fog/obstacles).
- Reuse scratch buffers instead of allocating per query.
- Keep tick order explicit and documented; determinism depends on it.

## Web Build

`odin/web/` compiles the same `game` package to `js_wasm32`:

```bash
cd odin/web
./build.sh
./serve.sh 8080
```

- No Emscripten and no raylib web library.
- Odin owns a 640×400 RGBA framebuffer (8×4 pixel iso tiles).
- JS uploads it with `ImageData` and scales it to 960×600.
- The world view is 2:1 isometric; the minimap and ASCII fog map stay top-down.
- HUD, buttons, validation status and ASCII fog map are DOM.
- `window.dreamcraft` mirrors the HTTP command API.
- `web/test_wasm.mjs` loads the wasm in Node and checks movement, goal,
  game-over, spawn/kill and fog output.
- Test files carry `#+build !js` so `core:testing`/`core:os` are not pulled
  into the wasm build.

## Replay Files

`headless` records and replays deterministic command logs:

```bash
./bin/headless --script tests/smoke.jsonl --record replay.jsonl
./bin/headless --replay replay.jsonl
```

- Header: `# dreamcraft-replay v1`
- One JSON command per line.
- Final line: `# hash <u64>`.
- `--replay` applies commands and verifies the final `game_hash`.
- `tests/replay.jsonl` is a committed hash-verified replay.

## Camera Follow

Native client:

- Follow mode is on by default.
- Follow uses the unit's exact interpolated world position, not its grid cell.
- Camera update runs after `sim_tick`, so rendering has no one-frame lag.
- No smoothing: the unit remains screen-centered while moving; no catch-up
  drift or rollback when it stops.
- Manual WASD/arrow/edge-scroll or minimap click switches to FREE.
- `F` toggles FOLLOW.
- HUD shows `CAM FOLLOW` or `CAM FREE`.

## Known Constraints

- HTTP control server is single-threaded and handles up to 8 requests per
  frame. Back-to-back keep-alive requests are supported with a 250 ms idle
  timeout.
- Web build uses a fixed full-map isometric view (no web camera zoom/pan).
- Web HUD is DOM; unit labels and health bars are simplified to pixel marks.
- Rust/Bevy files remain as a legacy reference and are not built or tested.
