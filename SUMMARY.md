# DreamCraft RTS - Project Summary

## Goal

Build a fantasy RTS called **DreamCraft** with:
- Odin for deterministic game logic (Rust/Bevy prototype is legacy)
- A* pathfinding for unit navigation
- Tutorial "Through the Woods" level: navigate trees and fog to the goal
- Long-term web/WebGPU target; native raylib is the current renderer

## Instructions

- Primary work goes in `odin/`
- Always work on the `DEV` lane (`./build.sh --dev`, `./run-dev.sh --control=7778`, `DEV - ` window title prefix); after finishing a task, trigger `./test.sh`, `./build.sh`, and `./restart-build.sh` to update the playable `:7777` build
- Use `./run.sh`, `./build.sh`, `./test.sh`
- Use Odin control API instead of Bevy BRP MCP:
  - `bin/dreamcraft --control=7777` (stable) / `bin/dreamcraft-dev --control=7778` (dev)
  - `bin/headless --serve=7777` / `bin/headless-dev --serve=7778`
  - `GET /state`, `/units`, `/fog`, `/screenshot`, `/camera`; `POST /command`, `/mouse`
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
5. **Edge-scroll drift & macOS `IsCursorOnScreen()`** - check `IsWindowFocused()` and track live `GetMousePosition()` bounds (`update_cursor_inside()`) because macOS GLFW `IsCursorOnScreen()` stays `false` when a window spawns under the cursor.
6. **Odin JSON tests** - free both the dynamic array and string fields after
   `json.unmarshal` to satisfy leak tracking.

## Accomplished (Odin)

- Deterministic 60 Hz Q16.16 simulation
- 80x50 grid, 30 tree clusters, 132 obstacle cells
- 8-way A*, fog of war, waypoints, goal
- 256-slot SoA unit pool with generation handles
- Melee combat (`Luk Soldier` 100 HP / 15 dmg), campaign hero **`Liiroy, the Bold`** (500 HP / 5 armor / 35 dmg / 40-tick cooldown / 180 speed / +4 HP/s regen, royal cobalt & gold rig), event-based 4.0s enemy discovery aggro grace + flavored warning banner, enemy chase AI, patrol loops
- Native raylib full 3D isometric client with Age of Empires × Toriyama world scale and watercolour post shader
- Procedural 26-bone Mamluk warrior & forest props in `odin/client/art/`, kinetic-chain idle/walk/attack animations, and double-crescent slash VFX
- Two-lane build: always develop on `dev` binaries (`DEV - ` window prefix on `:7778`), then trigger `./build.sh` + `./restart-build.sh` after finishing a task for playable `bin/dreamcraft` on `:7777`
- Dota 2 / SC2 camera movement (`MMB` / `Space`+Drag 1:1 Camera Grip, isometric pitch-compensated edge scroll, smooth vertical wheel zoom, minimap drag scrubbing + viewport frame) + `tests/camera_mouse_check.py` live probe & macOS OS mouse validator
- Browser WASM/canvas client with DOM HUD and `window.dreamcraft` API
- Headless JSONL scripts, HTTP control server, hash-verified replays
- Curve/state validation after every tick
- Pure-Odin Vector SVG Renderer (`odin/client/svg/`), 37 vector UI/HUD/editor `.svg` icons (`odin/assets/icons/`), and HiDPI raylib texture atlas (`client/icons.odin`)
- Standalone Native-Odin Declarative Reactive UI Framework (`odin/ui/`, `specs/09-ui-framework.md`, `DESIGN.md`) & Al-Dor Lore (`specs/10-lore.md`): Compose builders & value `Mod`, Flutter single-pass `BoxConstraints` & `Display_List`, Elm `UI_Msg` dispatch (`client/ui_app.odin`), `[512]Widget_Slot` springs/ripples, Arab/European medieval tokens & filigree `ui_sdf.{vs,fs}` + `ui_clip_tex.fs`, exact 2x-supersampled (4x SSAA) sRGB-gamma-corrected font engine (`assets/fonts/`), and `.WINDOW_HIGHDPI`
- In-game 3D Model Picker & Blender-shortcut Model Editor (`Esc -> Model Editor` or `--editor[=<model>]`), view-conditional `F1` Shortcut Window (`client/shortcuts.odin` + `? F1` UI badges), two-way chunked `.odin` asset persistence (`client/art/{spec,edit,models}/`), `Ctrl+S` live hot-reload, and Playwright-style Cooperative Mesh CLI (`odin/tools/mesh_cli/` -> `bin/dreamcraft-mesh`) for zero-script Human <-> AI art authoring
- 138 native unit tests (69 game, 13 control, 17 art, 9 art/edit, 5 svg, 7 ui, 6 mesh_cli, 12 client) + web WASM/headless/replay/HTTP/mouse smoke: invariants,
  allocations, determinism, HTTP round trip, `.odin` round trip, live OS mouse camera validation, browser API
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
