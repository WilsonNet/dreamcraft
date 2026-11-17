---
name: odin
description: Odin language patterns, allocators, testing, raylib client, HTTP control server, compile speed
---

# Odin Skill

Use when working in `odin/`. The Rust/Bevy code is legacy.

## Build / Test

```bash
cd odin
odin test game -vet -strict-style
odin test control -vet -strict-style
odin build client -out:bin/dreamcraft -o:speed
odin build headless -out:bin/headless -o:speed
./test.sh
```

- `-o:speed` builds are still ~1–3 s.
- `-vet -strict-style` catches shadowing and unused imports.
- Odin includes `core:*` and `vendor:*`; no package manager.

## Two-Lane Workflow

- Stable lane: `bin/dreamcraft` in tmux `dreamcraft:game`, control `:7777`.
  The user plays this. Do not rebuild or restart it mid-task.
- Dev lane: `./build.sh --dev` -> `bin/dreamcraft-dev`, `bin/headless-dev`.
  Use `--control=7778` or `bin/headless-dev --serve=7778 --paused`.
- Dev client title always starts with `DEV - `:
  `-define:DREAMCRAFT_DEV=true` plus an executable-name check.
- `./test.sh` builds dev binaries only; it must not overwrite the stable lane.
- Close-out: `./test.sh` -> `./build.sh` -> `./restart-build.sh` -> docs.
- `GET /units` exposes `world`, `progress` and `next` for jump diagnosis.

## Memory Rules

- Simulation (`game/`) must not allocate.
- Use fixed arrays for bounded data:
  `[MAX_UNITS]T`, `[MAX_PATH]u16`, `[MAX_COMMANDS]Command`.
- Use generation handles for entity slots:
  `Unit_Handle{index: u16, generation: u32}`.
  Destroying a unit bumps the generation; stale handles fail lookup.
- Reuse scratch arrays (A* heap, stamps, scores) instead of per-query `make`.
- Bitsets for fog/obstacles: `[63]u64` for an 80×50 grid.
- Tools/UI may allocate, but pass `context.temp_allocator` for per-frame or
  per-request strings; reset with `free_all(context.temp_allocator)` at the end
  of the frame/request loop.
- JSON parsing in long-running servers: parse into `context.temp_allocator` and
  reset after the response. Otherwise request strings leak.
- Tests can set `context.allocator` to a probe that counts/rejects allocations.

## Testing Patterns

```odin
@(test)
my_test :: proc(t: ^testing.T) {
    testing.expect_value(t, got, want)
}
```

- Run `odin test <package>`.
- Leak tracking is on by default. Free dynamic arrays **and string fields**
  allocated by `json.unmarshal`.
- Corrupt state deliberately and assert each validator branch.
- Determinism: run the same command script on two `Game` values and compare
  `game_hash`.
- Allocation guard: run 1000 ticks under an allocator that returns
  `.Out_Of_Memory` and assert zero calls.

## Raylib Gotchas

- Bindings use `cstring`: string literals convert automatically, runtime
  strings do not. Keep a fixed buffer, `fmt.bprintf`, append `\0`, then
  `cast(cstring)raw_data(buffer)`.
- Draw calls must be inside `BeginDrawing`/`EndDrawing`; 2D world inside
  `BeginMode2D(camera)`.
- `Camera2D.offset` is screen center; `target` is world position.
- Edge scrolling needs `IsWindowFocused()` **and** `IsCursorOnScreen()`,
  otherwise an unfocused window can scroll the camera to its clamp.
- Screenshot: `LoadImageFromScreen()` then `ExportImage` to `.png`; serve the
  file bytes from the control server.
- Minimap: one 80×50 texture, scale to 200×125, negative source height flips Y.

## 3D Rendering

- Native client is full 3D; simulation stays orthogonal.
- `Camera3D` orthographic:
  - position = target + `normalize({1,0.816,1})*40`,
  - `up = {0,1,0}`, `fovy = 20`, `projection = .ORTHOGRAPHIC`.
- Grid center mapping: `x = gx + .5 - GRID_W/2`, `z = gy + .5 - GRID_H/2`.
- Picking: `GetScreenToWorldRay` then intersect `y=0`.
- Selection/health bars: `GetWorldToScreen`.
- Ground: one textured `GenMeshPlane`; 4 texels per cell, point filtered,
  fog/goal colors updated with `UpdateTexture`.
- Trees: low-poly `DrawCylinder` cones; units: animated GLB models.
- Render scene to a half-size `RenderTexture2D`, upscale nearest, then apply
  `assets/shaders/pixelart.fs` (posterize + dither + outline).
- HUD and health bars draw after the pixel pass at full resolution.
- Minimap and ASCII fog stay top-down.

## Warrior Model Pipeline

- `odin/tools/warrior/build.sh` runs Blender headless; no MCP needed.
- Blender 5.3, Workbench preview, GLB export with `export_animation_mode='ACTIONS'`.
- Actions: idle 33 frames, walk 17, attack 11 at 24 fps.
- Raylib: `LoadModel`, `LoadModelAnimations`, `UpdateModelAnimation`,
  `DrawModelEx`.
- One model instance per unit; a shared model cannot show two animations.
- Model faces +Z at 0 degrees; yaw = `atan2(dx, dy)` in grid space.
- Trigger attack when `units.cooldown[i]` increases (simulation reset it).
- Move the preview ground plane `hide_render = True` or every transparent
  frame gets an opaque ground.

## Web / WASM

```bash
cd odin/web
./build.sh      # main.wasm
./serve.sh 8080
node test_wasm.mjs
```

- Target: `odin build . -target:js_wasm32`.
- `wasm-ld` comes from `lld`; add `/opt/homebrew/opt/lld@22/bin` to PATH.
- Browser loader needs `odin_env.write` and `odin_env.rand_bytes` stubs.
- Export `@(export)` procs; JS can call them directly.
- JS reads wasm memory with `new Uint8Array(ex.memory.buffer, ptr, len)`.
- Test files in the simulation package must start with `#+build !js`, otherwise
  `core:testing` pulls `core:os` and the wasm build fails.
- Odin `fmt` treats `{}` as Python-style formatting; JSON format strings must
  escape literal braces as `{{` and `}}`.
- u64 hashes should cross the JS boundary as strings (JS numbers lose
  precision above 2^53).
- No Emscripten or raylib web lib needed; render into an RGBA framebuffer.

## Replay

```bash
./bin/headless --script tests/smoke.jsonl --record replay.jsonl
./bin/headless --replay replay.jsonl
```

- `# dreamcraft-replay v1` header.
- JSON command per line.
- `# hash <u64>` final line; replay verifies `game_hash`.
- Live recording is only deterministic with `--serve --paused`.

## Game Over

- `game_over` is an explicit valid state.
- Death check calls `game_update_game_over`.
- Validator allows a missing player only when `game_over` is true.
- Test hooks that destroy/spawn players must call `game_update_game_over`.

## Movement Continuity

- `world` is interpolated; `position` is the last reached cell.
- Re-issuing a move mid-segment must keep `progress` and `world` and plan from
  `path[path_index]` (the cell being entered), not from `position`.
- Validate the destination before mutating path or world fields. A rejected
  move must leave the current path intact.
- Attack orders keep the path; `attack_movement` replans from the current
  segment. In-range units finish the segment (`unit_stop_after_segment`).
- Validator: `path[0] != position` is legal only while `progress > 0`.
- Regression: re-order while moving, click a tree cell, re-order while routing
  past an obstacle. `world` must advance monotonically.

## Control HTTP Server

- `core:net` only; parse requests manually.
- Listener is non-blocking; accepted sockets are blocking with a 250 ms
  receive timeout.
- Cap request size (16 KiB), parse `Content-Length`, always send
  `Connection: close`.
- Poll the server from the main thread so commands mutate the same `Game` as
  rendering. Do not spawn a mutating thread.
- Bind IPv4 loopback only.
- Keep-alive: parse `Connection` and HTTP/1.0 vs 1.1; loop requests on the same
  socket with a short receive timeout.
- Return screenshots from `ExportImageToMemory`, not a temp file.

## Odin Syntax / Compiler Gotchas

- No `const` inside procedures; use `NAME :: value`.
- Shift counts must be unsigned: `value >> u32(shift * 8)`.
- `defer` runs at the end of the **scope**. A `defer` inside an `if` block runs
  when that block ends, not at function exit. Put server cleanup at function
  scope.
- Enum `switch` is exhaustive; use `#partial switch` when a default is intended.
- A zeroed struct handle is not automatically invalid. `handle_is_valid` must
  reject `generation == 0` (generations start at 1).
- Large structs on the stack emit "may cause stack overflow" warnings; prefer
  globals or heap allocation in tests/tools.
- `json:"name"` tags use backticks in Odin.
- `os.read_entire_file(path)` needs an allocator argument; use
  `os.read_entire_file(path, context.allocator)`.
- `net.listen_tcp` returns `Network_Error` (union) → compare to `nil`.
  Recv/accept/send errors are enums → compare to `.None`.

## Project Rules

- Keep `game` free of raylib/HTTP imports.
- Fixed tick order in `game/sim.odin`; determinism depends on it.
- Validate after every tick (`VALIDATE_EACH_TICK`).
- Functions ≤ 50 lines, files ≤ 420 lines.
- Update `specs/` and this skill after a task.

## Procedural Models And Custom Shaders (raylib 6)

- `rl.Matrix` here is `#row_major matrix[4,4]f32`, not the C struct: read
  translation as `m[0][3]`, identity as `rl.Matrix(1)`. `MatrixMultiply` is
  deprecated; compose with `a * b` (wrap it in `xf_mul` for intent).
- `rl.Color` is `distinct [4]u8`: `.r/.g/.b/.a` swizzle, literal
  `rl.Color{10,20,30,255}`. `Vector3` is `[3]f32` with `.x/.y/.z`.
- `UnloadMesh` frees mesh arrays with `RL_FREE`. If you hand it slices you
  allocated, allocate them with `rl.MemAlloc` or you will crash.
- A custom shader gets `mvp`, `matModel`, `matView`, `matProjection` and the
  default attributes (`vertexPosition`, `vertexNormal`, `vertexColor`,
  `vertexTexCoord`) resolved by name. Use `gl_Position = mvp * vec4(pos,1)`.
- Pack per-vertex material data: `vertexColor.a` = baked AO,
  `texcoord.xy` = (metalness, glow). One draw call per character.
- `UpdateMeshBuffer(mesh, 0, ...)` = positions, `2` = normals, `1` = UVs,
  `3` = colours. Upload indices once at build time.
- CPU skinning in `main` package: rigid parts, one bone per vertex, rewrite
  positions/normals per frame. Far cheaper than it looks for a few units and
  avoids GLB/skinning-shader plumbing.
- `package main` cannot be imported. For dev tools (model sheets, turntables)
  add a flag inside the client (`--sheet`) and early-return before the game
  loop; grab the render target with `LoadImageFromTexture` + `ImageFlipVertical`.
