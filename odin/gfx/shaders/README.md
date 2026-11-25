# Game shaders (SDL3 GPU)

Each program ships twice: MSL for Metal (`*.metal`, compiled by the driver at startup) and
SPIR-V for Vulkan (`*.vert` / `*.frag` GLSL 450, compiled with `glslc` to the committed
`*.spv`). `gfx/shader.odin` embeds both and picks by device. Keep the two in step.

| Program | Files | Used for |
|---------|-------|----------|
| default | `default.*` | raylib's default shader: `texture0 * colDiffuse * vertex colour` (immediate shapes, default-material meshes, 2D quads) |
| ground | `ground.*` | terrain: `1280×800` painted albedo + `80×50` fog state texture, FBM mist edges, goal shimmer, world-border fade |
| unit | `unit.*` | painterly units and props (`u_tint`, `u_fog_vis`); vertex colour = albedo + baked AO, UV = `(metalness, glow)` |
| watercolor | `watercolor.*` (+ `default.vert`) | full-resolution post pass: edge pooling, paper grain, bloom, split tone, shared grade with the HUD, contact shadow under the console, vignette |

Uniform block shared by every program (`std140`, one buffer pushed to both stages):

```
0   mat4 mvp        64  mat4 matModel    128 vec4 colDiffuse
144 vec4 fb         target width, height (px), 1 when rendering into a render texture
160 vec4 slot[i]    the program's own uniforms in declaration order (scalars in .x, vec3 in .xyz)
```

Rebuild SPIR-V after editing the GLSL:

```bash
cd odin/gfx/shaders
for f in *.vert *.frag; do glslc -fshader-stage=${f##*.} $f -o $f.spv; done
```

`gl_FragCoord` is bottom-up in GL; the MSL/Vulkan versions reconstruct it as
`(x, fb.y - y)` where the effect depends on it (watercolor grain and contact shadow).
Run the client with `--no-shader` to bypass the post pass.
