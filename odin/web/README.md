# DreamCraft Web (Odin → WebAssembly)

Native-first Odin simulation compiled to `js_wasm32`, rendered into an HTML
canvas. No Emscripten and no raylib web build required.

## Build

```bash
cd odin/web
./build.sh          # main.wasm
./serve.sh 8080     # http://localhost:8080/
```

`build.sh` adds `wasm-ld` to `PATH` automatically when installed via
Homebrew (`lld@22`) or standard LLVM locations.

## Test

```bash
cd odin/web
./test.sh           # build + Node WASM smoke test
```

The Node test loads `main.wasm` directly, then verifies:

- initial state is valid,
- `web_move` + `web_run` moves the player,
- killing the enemy then teleporting to the goal completes the level,
- killing the player produces `game_over` with valid invariants,
- spawn/set_hp/kill hooks work,
- fog text has the correct size and contains the player.

For browser testing, serve the directory and use Playwright:

```js
await page.goto("http://127.0.0.1:8080/");
await page.evaluate(() => dreamcraft.command({cmd:"goto", x:10, y:25}));
await page.evaluate(() => dreamcraft.command({cmd:"run", ticks:140}));
const state = await page.evaluate(() => dreamcraft.state());
```

## Rendering

- The simulation owns a `640×400` RGBA framebuffer with 2:1 isometric tiles
  (`8×4` pixels per cell).
- JS uploads the framebuffer with `ImageData` and scales it to `960×600`
  (`image-rendering: pixelated`).
- World view is isometric; the ASCII fog map stays top-down.
- HUD, buttons, status, validation and ASCII fog map are HTML/DOM.
- No per-frame WASM↔JS draw calls; one pixel buffer per frame.

## Browser API

`window.dreamcraft`:

- `state()` — same fields as `GET /state` (`game_over`, `hash`, `valid`, ...)
- `units()`
- `fog()` — 80×50 ASCII map
- `command(obj)` — same command set as the HTTP control API:
  `status`, `goto`, `patrol`, `attack`, `stop`, `run`, `reset`, `verify`,
  `select`, `select_all`, `spawn`, `kill`, `set_hp`, `teleport`
- `reset()`

`dreamcraft.command` returns a result object with `ok`, `msg`, and the current
state. The `hash` is a string because JavaScript numbers cannot represent all
64-bit values exactly.

## Input

- Left click: select or execute Move/Patrol mode
- Right click: attack visible enemy, otherwise move
- Shift+click: add selection
- Esc: cancel command mode
- F: select all player units
- HUD buttons: Move, Patrol, Stop, Select All, Reset

## Known Limits

- Fixed full-map view; no web camera zoom/pan.
- No audio.
- ASCII fog panel is for debugging.
- Native raylib client remains the primary visual target.
