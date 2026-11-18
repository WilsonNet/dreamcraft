# 3D Isometric Renderer

## World Mapping

The simulation stays on the orthogonal 80×50 grid. The native client maps it
to a 3D world with Y up:

```
x = grid_x + 0.5 - GRID_W / 2
z = grid_y + 0.5 - GRID_H / 2
y = 0                       // ground
```

Interpolated unit positions use the same conversion from `units.world`
(orthogonal fixed-point pixels) through `CELL_SIZE`.

## Camera

- `Camera3D`, orthographic, up `{0,1,0}`.
- Offset: `normalize({1, 0.816, 1}) * 40` (45° yaw, ~30° pitch).
- Ortho height: `fovy = 20 * zoom`; default `zoom = 0.55` (≈11 world units
  visible vertically, towering trees 1.8–2.3× infantry height).
- Mouse wheel zooms between `0.08` and `2.0`; `--zoom=<n>` sets it for dev runs.
- Target: player ground position (Y=0); units stand above the screen center.
- Follow is exact; WASD/edge scroll/minimap click switch to FREE.
- Clamp target to the grid footprint plus 3 cells of margin.

## Picking

`screen_to_grid` casts a ray from the camera (`GetScreenToWorldRay`) and
intersects `y = 0`:

```
t = -ray.position.y / ray.direction.y
point = ray.position + ray.direction * t
grid = floor(point.xz + GRID/2)
```

Selection boxes project each unit with `GetWorldToScreen` and test screen
rectangles. Health bars use the same projection above the model head.

## 3D World

- Ground (`ground_tex.odin`, `ground.vs`/`ground.fs`): `1280×800` procedural
  painterly albedo texture with grass washes, mossy understory around obstacles,
  obstacle-aware 75-segment Catmull-Rom dirt trail connecting start → waypoints →
  goal, sandstone goal mosaic, and wildflowers, paired with an `80×50` fog state
  texture sampled via bilinear FBM mist and world-edge fade.
- Contact shadows (`ground_shadow.odin`): elliptical soft shadow model drawn on
  ground for units and trees.
- Forest & props (`art/trees.odin`, `art/props.odin`, `env_assets.odin`, `env_render.odin`):
  four deterministic AoE-scale procedural tree variants (~2.65–3.45 world units:
  three pines with flattened bough tiers and scalloped rim puffs, plus multi-blob
  oak canopies), mossy boulders, ferns, octagon stone waypoint medallions, and
  goal banners. Unexplored clusters are skipped; explored clusters dim smoothly.
- Paths: `DrawLine3D` plus small spheres for selected units.
- Units: procedurally generated, CPU-skinned Mamluk models (`WARRIOR_SCALE = 0.74`)
  with soft contact shadows, custom bevelled selection ring, and curved
  double-crescent `slash_vfx.odin` combat ribbons.
- Depth comes from the GPU Z-buffer; no manual painter's ordering.

## Watercolour Pipeline

1. Render the 3D scene to a full-resolution `RenderTexture2D` (`BILINEAR` filter,
   minimum `640×360`, via `pixel.odin`).
2. Draw that texture to the window with `assets/shaders/watercolor.fs`:
   - small wet-bleed wobble plus a five-tap wash,
   - pigment pooling on luminance edges (darken + saturate),
   - screen-space paper granulation,
   - cheap bloom for visor/rune glow,
   - warm/cool split tone and a soft vignette.
3. Draw the HUD, minimap, health bars and selection box at full resolution.

The old `pixelart.fs` (hard outline + 12-level posterize + Bayer dither) is
gone: it made the scene read as voxel art. `--no-shader` still bypasses the
post pass.

## Unit Material Shader

`assets/shaders/unit.vs` / `unit.fs` render units and environment props (`u_tint`,
`u_fog_vis`), using:

- vertex colour `rgb` = albedo, `a` = baked ambient occlusion,
- `texcoord.xy` = (metalness, glow),
- warm key light, cool fill, wrapped diffuse,
- crisp 4-tone wash steps with a soft wobbled terminator,
- Beer–Lambert pigment compositing (`paper * pigment^density`) so shadows get
  heavier, cooler pigment instead of turning grey,
- narrow metal specular, silhouette pigment pooling, warm rim light,
- emissive term for the visor, chest disc and blade runes.

## Procedural Unit Model

- Assembled from code at spawn (`odin/client/art/`): `build_mamluk(enemy) -> Mesh_Builder`.
- Heroic 5.36-head proportions built directly in rest coordinates (`body_point` is
  identity; joints align 1:1 with `BONES` in `Y = 0..1.945`).
- 26 joints; rigid skinning; kinetic-chain analytic clips plus traveling S-wave
  cape/sash/plume secondary motion and turn/stop dynamics (`unit_visuals.odin`).
- Meshes are uploaded once per unit (raylib-owned arrays) and only positions
  and normals are rewritten per frame.
- `./bin/dreamcraft-dev --sheet` renders 12 reference views through the full
  pipeline to `build/sheet/`.

## Web Client

The browser build keeps the previous lightweight 2:1 software canvas
renderer. The native client is the full 3D target.

## Tests

- `odin test client/art`: Mamluk mesh counts/bounds/normals/grounding (`min_y` at `Y=0`,
  heroic height), Richard Williams walk weight arc (`down < contact < pass < up`) and
  32-phase foot grounding, 16-phase idle grounding, joint child isolation, attack windup/return,
  face clearance, and tree/prop mesh validity (12 tests).
- `odin test client`: deterministic cell hashes, `angle_toward` (`0° +Z`, `90° +X`),
  and shortest-arc `turn_toward` (3 tests).
