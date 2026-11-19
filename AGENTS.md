# DreamCraft - Fantasy RTS (Odin)

Spiritual successor to StarCraft: Brood War. Primary implementation: **Odin + raylib** in `odin/`. Deprecated prototypes
(`rust/`, `web-console/`, `warrior-glb/`, `reference.jpg`) live in `legacy/`.

## ⚠️ CRITICAL: Specs Files (Read First!)

**BEFORE implementing ANY feature, ALWAYS check:**
1. `specs/` for existing specifications
2. `.agents/skills/specs/SKILL.md` for update guidelines

**AFTER completing ANY feature, ALWAYS:**
1. Update relevant spec files in `specs/`
2. Mark features as `[x]` in `specs/01-overview.md`
3. Update unit specs, input specs, or other relevant docs

**Spec files:**
| File | Purpose |
|------|---------|
| `specs/01-overview.md` | Vision, features, status, architecture |
| `specs/02-units.md` | Unit types, stats, abilities |
| `specs/03-isometric.md` | 3D isometric renderer, picking, pixel shader |
| `specs/04-input.md` | Control schemes, input handling |
| `specs/05-networking.md` | Multiplayer architecture |
| `specs/06-agent-console.md` | Diagnostics, control API, headless testing |
| `specs/07-minimap.md` | Minimap implementation |
| `specs/08-odin-port.md` | Odin data layout, allocation rules, control server |

---

## Development Commands

```bash
cd odin

./run.sh                    # build + run native client
./run.sh --control          # client + HTTP control API on :7777
./build.sh                  # stable build: bin/dreamcraft + bin/headless + web
./build.sh --dev            # dev build: bin/dreamcraft-dev + bin/headless-dev
./test.sh                   # tests + dev build only (stable lane untouched)
./restart-build.sh          # restart the stable herdr game pane on :7777
cd web && ./build.sh && ./serve.sh 8080   # browser build

odin test game -vet -strict-style
odin test control -vet -strict-style
odin test client/art -vet -strict-style
odin test client -vet -strict-style
odin build client -out:bin/dreamcraft -o:speed
odin build headless -out:bin/headless -o:speed
```

Model reference renders (no map hunting):

```bash
./bin/dreamcraft-dev --sheet        # -> build/sheet/*.png
```

Headless file protocol (agent-friendly):

```bash
echo '{"cmd":"status"}' > headless_command.json    # write, then read result
./bin/headless --script tests/smoke.jsonl          # deterministic script
./bin/headless --ticks 600                         # run fixed ticks
./bin/headless --serve=7777                        # HTTP control API
./bin/headless --script tests/smoke.jsonl --record replay.jsonl
./bin/headless --replay replay.jsonl               # verifies final hash
```

## Build / Dev Workflow (two lanes)

Always work on the **Dev** version (`DEV - ` window prefix) while developing and validating, and always trigger a **Build** (`./build.sh` + `./restart-build.sh`) once a task is done so the playable build version stays current:

| Lane | Binary | Port | Owner |
|------|--------|------|-------|
| Build | `bin/dreamcraft` | `:7777` | user plays |
| Dev | `bin/dreamcraft-dev`, `bin/headless-dev` | `:7778` | agent |

- **Always develop on Dev:** Edit, test, and run checks using `./build.sh --dev`,
  `./run-dev.sh --control=7778`, `./bin/dreamcraft-dev --control=7778`, or
  `./bin/headless-dev --serve=7778 --paused`.
- **Mandatory `DEV - ` title prefix:** The dev client window title always starts
  with `DEV - `. `./build.sh --dev` and `./run-dev.sh` pass `-define:DREAMCRAFT_DEV=true`,
  and the executable name (`dreamcraft-dev`) is also checked at runtime so manual
  dev builds keep the `DEV - ` prefix.
- **Never overwrite or restart the Build lane mid-task:** The stable build runs
  in a dedicated Herdr `game` pane (`HERDR_WORKSPACE_ID`). `./test.sh` builds dev
  binaries only.
- **Post-task Build trigger (close-out in order):**
  1. `./test.sh` (plus `python3 tests/camera_mouse_check.py --launch --mode both --port 7778` when touching camera/input)
  2. `./build.sh` (builds stable `bin/dreamcraft`, `bin/headless`, and `web`)
  3. `./restart-build.sh` (restarts the playable `:7777` build in Herdr)
  4. update `specs/` and the relevant markdown docs.
- `GET /units` exposes `world`, `progress` and `next`; use them to measure
  position jumps through the control API instead of guessing from screenshots.

## Odin Project Structure

```
odin/
├── game/        # pure simulation: no raylib, no allocation
│   ├── config.odin      # constants, fixed grid positions
│   ├── fixed.odin       # Q16.16 math
│   ├── grid.odin        # obstacle + fog bitsets
│   ├── pathfinding.odin # allocation-free A*
│   ├── units.odin       # SoA unit pool + generation handles
│   ├── commands.odin    # command queue execution
│   ├── movement.odin    # tick-based path movement
│   ├── ai.odin          # enemy chase, fog, waypoints, goal
│   ├── combat_sim.odin  # attacks, cooldowns, death
│   ├── sim.odin         # fixed tick order
│   ├── validation.odin  # runtime invariant checker
│   ├── hash.odin        # deterministic state hash
│   └── *_test.odin      # unit tests
├── client/      # raylib 3D renderer, input, HUD, minimap, VFX, shaders
│   └── art/     # procedural Mamluk mesh, 26-bone rig, anims, trees, props
├── control/     # JSON commands + localhost HTTP server
├── headless/    # script runner, polling, --serve, record/replay
├── web/         # js_wasm32 2:1 canvas client + DOM HUD
├── assets/shaders/ # ground.{vs,fs}, unit.{vs,fs}, watercolor.fs
└── tests/       # smoke and replay scripts

legacy/          # archived prototypes (not built or tested)
├── rust/        # original Rust/Bevy 0.18 prototype
├── web-console/ # early Bun/React debug console prototype
└── warrior-glb/ # retired Blender Mamluk pipeline & GLB assets
```

## Architecture Rules

### Determinism
- Simulation is integer-only: `Fp` Q16.16 fixed point, never `f32`.
- Fixed 60 Hz tick, fixed system order in `game/sim.odin`.
- No randomness in the simulation.
- `game_over` is an explicit valid state; player death must not trip the
  invariant checker.
- Same command log must produce the same `game_hash`. Covered by tests.

### Memory
- No allocation inside `sim_tick`, pathfinding, commands, combat, or fog.
- All simulation arrays are fixed-capacity (`MAX_UNITS`, `MAX_PATH`,
  `MAX_COMMANDS`, `GRID_CELLS`).
- Units are struct-of-arrays with `{index, generation}` handles. Destruction
  bumps the generation; stale handles cannot hit recycled slots.
- Obstacles and fog are bitsets, not `[][]bool`.
- A* reuses preallocated scratch arrays. No `BinaryHeap` and no per-call `Vec`.
- Tests run 1000 ticks under a failing allocator and assert zero allocations.

### Validation
- `validate_game()` checks counters, handles, paths, fog, waypoints, commands.
- `VALIDATE_EACH_TICK` is on by default. Release builds may pass
  `-define:VALIDATE_EACH_TICK=false`.
- Every control API response includes `valid` and `validation`.
- `level_validate()` proves every waypoint is reachable before play.
- Corrupt-state tests assert each validator branch fires.

### Controls and Testing
- Bevy BRP MCP was removed. Do not re-add `bevy_remote`, `bevy_brp_extras`,
  or `bevy_brp` MCP config.
- Use the Odin control API instead:
  - `GET /state`, `GET /units`, `GET /fog`, `GET /screenshot`, `GET /camera`
  - `POST /command` with `goto`, `patrol`, `patrol_to`, `attack`, `attack_move`,
  `run`, `reset`, `verify`, `select`, `spawn`, `kill`, `set_hp`, `teleport`
  - `POST /mouse` (client probe) + `cd odin && python3 tests/camera_mouse_check.py --launch --mode both --port 7778` for live mouse & macOS OS camera validation (see **camera-mouse** skill)
- HTTP server is single-threaded and polled from the main loop. Commands
  mutate the same `Game` as rendering.
- `bin/headless --script` is the CI path; `--serve` is the interactive path.
- `--record` / `--replay` produce hash-verified deterministic command logs.
- Client screenshot endpoint works in `--control` mode and returns PNG bytes
  from memory (no temp file).
- Web build exposes `window.dreamcraft`: `state()`, `units()`, `fog()`,
  `command(obj)`, `reset()`.
- Web test files must carry `#+build !js` so `core:testing`/`core:os` do not
  enter the wasm build.

## Code Style Rules

### Function Length Limit
**Functions MUST NOT exceed 50 lines.** Extract logical sub-tasks into private
procedures. Keep the original as a coordinator.

### File Size Limit
**Files MUST NOT exceed 420 lines.** Extract modules by domain. Prefer one
responsibility per file (`snapshot.odin`, `http.odin`, `input.odin`, etc.).

### Odin Style
- Explicit allocators; simulation uses none.
- Prefer fixed arrays and slices over `[dynamic]` inside hot paths.
- `#partial switch` only when a default is intentional.
- Use `-vet -strict-style`; fix warnings rather than ignoring them.
- Public names are package-visible by default; use `@(private)` for internals.

## Core Gameplay (Tutorial Level 1)

- 80×50 grid, 32 world units per cell
- Campaign hero **Liiroy, the Bold** (`Unit_Kind.Hero`) at (2,25), enemy **Luk Soldier** (`Unit_Kind.Melee`) at (50,25)
- 132 tree obstacle cells across 30 clusters
- A* 8-direction movement, no corner cutting through two blocked sides
- 3-state fog: unexplored / explored / visible
- 8 waypoints; waypoint 3 moved to (40,23) because (40,20) is a tree
- Goal at grid x ≥ 77
- Stats: `Luk Soldier` 100 HP / 15 dmg / 0 armor / 60-tick cooldown / 150 speed; `Liiroy, the Bold` 500 HP / 35 dmg / 5 armor / 40-tick cooldown / 180 speed / +4 HP/s regen / range 3 cells
- Campaign event aggro: newly discovered enemies wait `ENEMY_AGGRO_DELAY_TICKS` (240 ticks / 4.0 s) with a flavored discovery announcement before charging, unless attacked first (`hp < hp_max`), then chase within 6-cell vision and attack on cooldown
- Patrol (`P` / 1-click) loops A↔B cleanly and engages enemies within 6-cell vision before resuming the patrol leg
- Attack-Move (`A`) marches to destination while auto-acquiring enemies within 6-cell vision, resuming to destination once clear
- SC2/AoE-style 3D ground command confirmation chevrons & pulse rings on right-click / command orders
- Camera follow by default; manual pan switches to FREE (`F` toggles); Dota/SC2 Camera Grip (`MMB` / `Space`+Left drag), pitch-compensated edge scroll, smooth wheel zoom, and minimap drag + viewport frame (see **camera-mouse** skill)
- Native full 3D orthographic isometric renderer + watercolour post shader
- Procedural Mamluk unit (`client/art/`): 5.36-head heroic rig (26 joints),
  kinetic-chain idle/walk/attack clips, turn banking & stop-settle cushion
- Painterly shading (`unit.{vs,fs}`, `ground.{vs,fs}`, `watercolor.fs`), no GLB assets
- Minimap stays top-down; browser build keeps the 2:1 canvas view

## Skills Map

Skills live in `.agents/skills/` (symlinked from `.opencode/skills/` and
`.claude/skills/`):

| Skill | Purpose |
|-------|---------|
| **odin** | Odin patterns, allocators, testing, raylib, control server |
| **camera-mouse** | Dota/SC2 camera grip & edge pan, macOS raylib cursor gotchas, live mouse probe |
| **art-direction** | Toriyama/DQ character look, palette, watercolour shading |
| **bevy** | Legacy Bevy reference only |
| **herdr** | Herdr workspace, tab, pane, and background session management |
| **specs** | Keeping `specs/` updated |

### Skill Update Rule
After a task, update a skill if you discovered a new pattern, fixed an error,
or found information that would have helped. Add concise, actionable notes.

## Legacy Rust/Bevy Path

`legacy/` holds the deprecated Rust/Bevy prototype (`legacy/rust/`), early
Bun web UI (`legacy/web-console/`), and retired Blender GLB pipeline
(`legacy/warrior-glb/`). Use `odin/` for all current work.
