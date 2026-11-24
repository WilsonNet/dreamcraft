# UI Framework: vinland-ui embedded in the game

DreamCraft's HUD, menus, Model Picker, Model Editor chrome and world-anchored overlays are built
with **vinland-ui (VUI)**, the sibling repository `../vinland-ui` (Odin, utility classes, one
instanced draw per texture batch). The previous in-tree framework (`odin/ui/`) was removed when
the UI moved to VUI.

## 1. Who owns what

The game owns the window, the GL context and the frame loop. VUI is a library inside it.

| Layer | Where | Responsibility |
|-------|-------|----------------|
| VUI core | `vinland:vui` | Layout (flex, grid, absolute), Tailwind-style classes, text, hit testing, animation, draw list |
| VUI game additions | `vinland:vui` | `corner-{bevel,scoop,notch,arch}` geometry, `bg-tex-<name>` / `bg-tile-<px>` textured fills, external textures (`image_register_external`), `pointer_over_ui(ctx, mouse)` |
| Materials, fonts, icons | `vinland:vui/materials`, `vinland:vui/fonts/game`, `vinland:vui/icons/game` | Procedural tileable reliefs and inlay masks, Cinzel Decorative + Alegreya Sans, filled game icons |
| GL renderer | `vinland:vui/gl` | Draws a VUI draw list into the bound framebuffer, restores GL state; shader bodies shared with VUI's GL/Vulkan/Metal/WebGL targets |
| raylib bridge | `vinland:vui/raylib` | `init`, `input`, `begin`/`end`, `render` (flushes rlgl first), `pointer_over_ui`, `texture_image` |
| Game host | `odin/client/vui_host.odin` | Basin colour tokens, icon registration (the game's SVG atlas as named textures), probe-aware input, agent commands |
| Screens | `odin/client/hud_basin.odin`, `odin/client/editor_vui.odin` | Battlefield HUD, pause, F1 window, overlays; Model Picker and Model Editor chrome |

The generic bridge lives in VUI so any raylib game can reuse it. Only game-specific pieces stay in
`vui_host.odin`.

## 2. Frame order

```
probe_begin_frame()
handle_input()        // world clicks only when !ui_pointer_captured() (hit test of last layout)
update_simulation()   // fixed 60 Hz
update_camera()
update_cursor()
vui_frame(dt)         // build HUD *after* the camera: nameplates never trail the world
probe_end_frame()
draw_frame()          // world -> pixel pass -> vui_render() (one GL submit)
control.server_poll() // agent commands see the tree of the frame just drawn
```

UI buttons act immediately when they are built (immediate mode). The existing message handlers
(`handle_hud_ui_msg`, `handle_picker_ui_msg`, `handle_editor_ui_msg`) are called directly from
the click sites, so game logic did not change.

## 3. Input rules

- World clicks are routed by `ui_pointer_captured()`, which hit-tests the last laid-out frame at
  the current (real or synthetic) mouse position. A press that started on UI stays captured.
- VUI receives mouse and wheel only; keyboard stays with the game, so Space (camera grip) and
  M/A/P/S/F never activate a focused button. Blender shortcuts in the editor are untouched.
- Full-screen layers are `pointer-events-none`; panels opt back in with `pointer-events-auto`.
  Decorative absolute overlays (patterns, friezes) must stay `pointer-events-none`: positioned
  elements paint and hit-test above in-flow siblings.

## 4. Performance budget

Measured on the dev build (Apple M4, 1280x720, `-o:speed`), reported live by `ui_stats`:

| Screen | Nodes | Instances | Batches | Build (CPU) | GL submit (CPU) |
|--------|-------|-----------|---------|-------------|-----------------|
| Battlefield HUD | 92 | 290 | 18 | 0.24 ms | 0.06 ms |
| Model Editor | 228 | 593 | 57 | 0.38 ms | 0.11 ms |

Rules: no per-frame class strings for moving geometry (set `ui.style()` / `ui.last_style()`
fields instead, so the class cache stays bounded); textures through named images; batches split
only on texture changes. Known follow-up: pack the game's SVG icons into one atlas to bring the
editor to a handful of batches.

## 5. Agent feedback loop

All through the existing control API (`POST /command`), see `specs/06-agent-console.md`:

- `{"cmd":"ui_tree","value":<depth>}`: flat element list (kind, class, text, rect).
- `{"cmd":"ui_click","text":"Resume Battle"}`: clicks the first visible element containing the text
  through the synthetic mouse (same path as `/mouse`), then parks the pointer off-screen.
- `{"cmd":"ui_stats"}`: nodes, instances, batches, build and render ms, pointer capture.
- `GET /camera` includes `minimap` (the live HUD rect), used by `tests/camera_mouse_check.py`.

## 6. Building

The client needs the vinland-ui checkout next to this repository (or `VINLAND_UI=/path`):

```bash
odin build client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -out:bin/dreamcraft-dev
```

`build.sh`, `run.sh`, `run-dev.sh` and `test.sh` pass the collection already.

The renderer port to SDL3 GPU (Metal / Vulkan) is planned in `specs/11-renderer-port.md`.
