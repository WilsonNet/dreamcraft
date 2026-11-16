# DreamCraft - Fantasy RTS (Odin)

Spiritual successor to StarCraft: Brood War. Primary implementation:
**Odin + raylib** in `odin/`. The Rust/Bevy prototype in `src/` is legacy
reference only.

## ⚠️ CRITICAL: Specs Files (Read First!)

**BEFORE implementing ANY feature, ALWAYS check:**
1. `specs/` for existing specifications
2. `.opencode/skills/specs/SKILL.md` for update guidelines

**AFTER completing ANY feature, ALWAYS:**
1. Update relevant spec files in `specs/`
2. Mark features as `[x]` in `specs/01-overview.md`
3. Update unit specs, input specs, or other relevant docs

**Spec files:**
| File | Purpose |
|------|---------|
| `specs/01-overview.md` | Vision, features, status, architecture |
| `specs/02-units.md` | Unit types, stats, abilities |
| `specs/03-isometric.md` | Grid rendering, coordinate systems |
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
./build.sh                  # build bin/dreamcraft + bin/headless
./test.sh                   # unit tests + headless smoke + HTTP smoke

odin test game -vet -strict-style
odin test control -vet -strict-style
odin build client -out:bin/dreamcraft -o:speed
odin build headless -out:bin/headless -o:speed
```

Headless file protocol (agent-friendly):

```bash
echo '{"cmd":"status"}' > headless_command.json    # write, then read result
./bin/headless --script tests/smoke.jsonl          # deterministic script
./bin/headless --ticks 600                         # run fixed ticks
./bin/headless --serve=7777                        # HTTP control API
```

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
├── client/      # raylib rendering, input, HUD, minimap
├── control/     # JSON commands + localhost HTTP server
├── headless/    # script runner, file polling, --serve
└── tests/       # smoke scripts
```

## Architecture Rules

### Determinism
- Simulation is integer-only: `Fp` Q16.16 fixed point, never `f32`.
- Fixed 60 Hz tick, fixed system order in `game/sim.odin`.
- No randomness in the simulation.
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
  - `GET /state`, `GET /units`, `GET /fog`, `GET /screenshot`
  - `POST /command` with `goto`, `patrol`, `attack`, `run`, `reset`, `verify`,
    `select`, `spawn`, `kill`, `set_hp`, `teleport`
- HTTP server is single-threaded and polled from the main loop. Commands
  mutate the same `Game` as rendering.
- `bin/headless --script` is the CI path; `--serve` is the interactive path.
- Client screenshot endpoint works in `--control` mode.

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
- Player melee unit at (2,25), enemy at (50,25)
- 132 tree obstacle cells across 30 clusters
- A* 8-direction movement, no corner cutting through two blocked sides
- 3-state fog: unexplored / explored / visible
- 8 waypoints; waypoint 3 moved to (40,23) because (40,20) is a tree
- Goal at grid x ≥ 77
- Melee: 15 damage, range 3 cells, 1.0 s cooldown, 100 HP
- Enemy chases within 6-cell vision and attacks on cooldown
- Patrol loops A↔B until a move/stop command

## Skills Map

Skills live in `.opencode/skills/` and `.claude/skills/`:

| Skill | Purpose |
|-------|---------|
| **odin** | Odin patterns, allocators, testing, raylib, control server |
| **bevy** | Legacy Bevy reference only |
| **tmux** | Long-running process management |
| **specs** | Keeping `specs/` updated |

### Skill Update Rule
After a task, update a skill if you discovered a new pattern, fixed an error,
or found information that would have helped. Add concise, actionable notes.

## Legacy Rust/Bevy Path

`src/` and `Cargo.toml` remain for reference. The Rust build is slow (Bevy).
Do not use it for new features. `bevy_remote` and `bevy_brp_extras` were
removed. Use `odin/` for all current work.

Today's date: Mon Nov 16 2026
