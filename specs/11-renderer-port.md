# Renderer Port: raylib (OpenGL) to SDL3 GPU (Metal / Vulkan)

Status: planned. Phase 1 (HUD on VUI over raylib) is done; see `specs/09-ui-framework.md`.

## Why

- macOS runs OpenGL through a deprecated translation layer on Metal. Native Metal removes that
  layer and its driver overhead and unlocks modern GPU features.
- vinland-ui already renders through SDL3 GPU (Metal on macOS, Vulkan on Linux, D3D12 possible).
  Sharing one device, one command buffer and one swapchain removes the GL bridge entirely: the
  HUD becomes the last render pass of the game's own frame.

Raw Metal is not the target: SDL3 GPU gives Metal on macOS without a second backend for Linux
and Windows.

## Phases

1. **Done**: VUI HUD over raylib via `vinland:vui/raylib` + `vinland:vui/gl`.
2. **VUI pass API**: let VUI record into a host-provided `SDL_GPUCommandBuffer` and render pass
   (today `vui/app` owns the device and swapchain). Add `vui/app` entry points that take a device
   and a target texture, so a game can embed VUI on SDL3 GPU the way it embeds it on GL today.
3. **Game renderer on SDL3 GPU**, behind `--renderer=gpu` with raylib as the default until parity:
   ground and fog (`ground.{vs,fs}`), units and skinning (`unit.{vs,fs}`, 26-bone rig), environment
   instancing, shadows, slash and command FX, then the watercolour/pixel post pass. Shaders ship as
   MSL + SPIR-V, the same pattern as `vinland-ui/vui/app/shaders`.
4. **Window and input on SDL3**: replace raylib windowing and input (`probe.odin` keeps the same
   synthetic-input contract for agents and tests).
5. **Remove raylib** once `test.sh`, `camera_mouse_check.py`, the model sheet (`--sheet`) and the
   Model Editor match on both renderers.

## Parity gates

- Screenshot parity of `--sheet` renders and the battlefield at fixed camera (pixel diff
  thresholds, like `vinland-ui/tests/e2e`).
- Frame time at or below the raylib build at 1280x720 and 2560x1440.
- Deterministic simulation untouched (`game/` has no renderer imports).
