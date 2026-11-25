# Renderer Port: raylib (OpenGL) to SDL3 GPU (Metal / Vulkan)

Status: **done** (2026-11). The native client renders with SDL3 GPU: Metal on macOS, Vulkan
on Linux. raylib is no longer linked. The last raylib build is commit `c3da052`.

## Why

- macOS runs OpenGL through a deprecated translation layer on Metal. Native Metal removes
  that layer and its driver overhead.
- vinland-ui already renders through SDL3 GPU. Sharing one device and one command buffer
  removes the GL bridge: the HUD is the last draw of the game's own frame.

Raw Metal was not the target: SDL3 GPU gives Metal on macOS and Vulkan on Linux from one code
path.

## Design: a raylib-compatible layer (`odin/gfx`)

The client used about 120 raylib procedures across 43 files. Instead of rewriting each call
site, `odin/gfx` implements that subset with raylib's names, types and semantics on SDL3.
Client files `import rl "../gfx"` (and `rlgl "../gfx/rlgl"`). Game code did not change.

| File | Role |
|------|------|
| `gfx/window.odin` | SDL3 window, events, keyboard/mouse state (GLFW key codes), time, FPS cap |
| `gfx/device.odin` | GPU device, frame recorder, replay, pipeline cache, render targets |
| `gfx/draw.odin` | `Begin/EndDrawing`, texture/3D/blend/shader/scissor modes, immediate batch, raylib shapes |
| `gfx/model.odin` | meshes (four vertex streams), materials, models, `GenMeshPlane` |
| `gfx/image.odin` | CPU images, textures, render textures, readback, PNG export (stb) |
| `gfx/shader.odin` | shader programs and the shared uniform block |
| `gfx/camera.odin` | world/screen projection, picking rays, collisions |
| `gfx/raymath.odin`, `gfx/types.odin` | copied from Odin's `vendor:raylib` bindings (zlib) |
| `gfx/device_darwin.odin`, `gfx/device_other.odin` | Metal vs Vulkan device, macOS app activation and layer colour space |
| `gfx/shaders/` | default, ground, unit, watercolor programs as MSL and SPIR-V (`README.md` there) |

### Frame model

Draws are recorded during the frame and replayed in one command buffer at `EndDrawing`:

1. One copy pass uploads the frame arena: immediate-mode vertices, dynamic mesh streams
   (`UpdateMeshBuffer`) and texture updates (`UpdateTexture`).
2. Embedded renderers prepare their own uploads (vinland-ui through `record_callback`).
3. One render pass per target, in recording order: render textures (world, hero portrait,
   picker turntable), then the backbuffer (post pass + HUD).
4. Dynamic mesh streams are copied into their persistent buffers.
5. The backbuffer is blitted to the swapchain.

Details that keep raylib semantics:

- `UpdateMeshBuffer` can run several times per frame on one mesh (slash VFX draws one mesh
  per attacking unit). Each call writes a new version into the arena, and each draw binds
  the version current when it was recorded.
- Render textures keep GL's bottom-up rows. The projection flips Y in render-texture passes
  and the winding flips with it, so negative source heights and VUI's `flip_y` still work.
- Clip space is converted to Metal/Vulkan conventions (z in [0, 1]) in one matrix (`clip_fix`).
- Readback (`LoadImageFromTexture`, `LoadImageFromScreen`) flushes recorded work first.
- Pipelines are created lazily per state key: program, primitive, blend, depth test and
  write, culling, winding, vertex layout.

### Input on macOS

- macOS 26+ often leaves apps launched from a terminal inactive, so no mouse-moved or key
  events arrive. `gfx` activates the app at launch (`activateIgnoringOtherApps`, like GLFW)
  and raises the window.
- The cursor is sampled from the OS every frame (`SDL_GetGlobalMouseState`), like GLFW,
  because events posted with `CGEventPost` do not reach SDL as motion events. A position is
  only reported once the cursor really moves, so a window opening under a resting cursor
  does not arm edge scrolling. Buttons count only for presses that start inside the window.

### Colour on macOS

SDL tags its `CAMetalLayer` with `kCGColorSpaceSRGB` (`SDL_gpu_metal.m`), so Core Animation
colour-matches the frame to the display profile; OpenGL surfaces are not colour-matched. The
palette was tuned under OpenGL, so on a display whose profile is not sRGB the Metal frame
read about 11% darker. `gfx` tags the layer with the screen's own profile (and again when the
window changes display), which leaves about 3.5% on the measured LG UltraWide. `colorspace =
nil`, Apple's documented opt-out, behaves like sRGB here.

## vinland-ui

`vinland:vui/sdlgpu` draws a VUI draw list inside a render pass the host owns (`init` with
the pass formats, `prepare` before any render pass, `draw` inside it). `vui/app` uses the same
package for its own window, so there is one SDL GPU implementation of the VUI renderer.
External images can ask for unfiltered sampling (`nearest`, used by the minimap).

## Parity results (macOS, Apple M4, 1280x720, same commands on both builds)

Screenshot diff, pixels whose largest channel differs by more than 24:

| Scene | Differing pixels | Notes |
|-------|------------------|-------|
| Opening battlefield | 0.36% | FPS digits, idle animation phase |
| Battlefield near trees | 0.44% | animation phase |
| Pause | 0.17% | |
| F1 help | 0.12% | |
| Model Picker | 0.06% | turntable angle |
| Model Editor | 0.01% | |

`--sheet` renders all 12 reference views correctly (upright, lit, shaded).

Tests: `./test.sh` passes, and `tests/camera_mouse_check.py --mode both` passes (synthetic
probe and real macOS mouse).

At 60 fps (vsync), CPU use is about 5.3% vs 6.8% for raylib, and resident memory is 81 MB vs
100 MB.

## Known issues

- **Uncapped frame pacing.** With `--bench=1500` (no vsync, no FPS cap) the GPU build runs at
  11.8 ms per frame (85 fps) against raylib's 2.2 ms. The time is spent in
  `SDL_WaitAndAcquireGPUSwapchainTexture`: replay CPU work is about 0.1 to 0.5 ms, and the
  present mode is `IMMEDIATE`. Rendering is not the bottleneck; swapchain pacing is. This
  fails the "frame time at or below raylib" gate until it is resolved, although normal play
  is vsynced at 60 fps. Next step: check SDL's frames-in-flight setting
  (`SDL_SetGPUAllowedFramesInFlight`) and `CAMetalLayer.maximumDrawableCount` against SDL's
  source, rather than tuning blindly.
- **Colour residual.** About 3.5% darker than the OpenGL build on a non-sRGB display (see
  above).
- **Vulkan untested.** The Linux/Vulkan path (SPIR-V shaders, `device_other.odin`) compiles
  but has not been run. Verify `./test.sh` and the parity scenes on Linux.

## Tools

- `--bench=<frames>`: uncapped frame-time statistics in the opening scene (avg, p50, p95, p99).
- `-define:GFX_TRACE=true`: prints the present mode, and in `--bench` the per-phase replay
  timings (`gfx.last_replay`) and the macOS app/window activation state.
- Rebuild SPIR-V after editing GLSL: see `odin/gfx/shaders/README.md`.
