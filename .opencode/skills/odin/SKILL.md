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

## Control HTTP Server

- `core:net` only; parse requests manually.
- Listener is non-blocking; accepted sockets are blocking with a 250 ms
  receive timeout.
- Cap request size (16 KiB), parse `Content-Length`, always send
  `Connection: close`.
- Poll the server from the main thread so commands mutate the same `Game` as
  rendering. Do not spawn a mutating thread.
- Bind IPv4 loopback only.

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
