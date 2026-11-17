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
- Ortho height: `fovy = 20 * zoom`; default `zoom = 0.65` (≈13 world units
  visible vertically, unit ≈15 % of screen height).
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

- Ground: one textured plane. The texture is 4×4 texels per cell
  (`320×200`), updated from fog/goal state each frame; point filtered.
  Per-cell and per-texel drift give it a painted wash instead of flat tiles.
  One soft line every 4 cells keeps the grid readable. Cells next to fog are
  dimmed so the play area fades out instead of ending on a hard tile border.
- Contact shadows: one radial-gradient texture drawn as a horizontal quad for
  units and trees.
- Trees: three stacked cone tiers with per-tree tint variation. Unexplored
  trees are skipped; explored trees are darkened.
- Waypoints: `DrawCircle3D` rings on the ground.
- Paths: `DrawLine3D` plus small spheres for selected units.
- Units: procedurally generated, CPU-skinned Mamluk models with a soft contact
  shadow and a gold selection ring.
- Goal: gold ground tiles plus a segmented boundary line.
- Depth comes from the GPU Z-buffer; no manual painter's ordering.

## Watercolour Pipeline

1. Render the 3D scene to a `RenderTexture2D` at half the window resolution
   (minimum `320×180`).
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

`assets/shaders/unit.vs` / `unit.fs` render units, and any mesh drawn with the
same material, using:

- vertex colour `rgb` = albedo, `a` = baked ambient occlusion,
- `texcoord.xy` = (metalness, glow),
- warm key light, cool fill, wrapped diffuse,
- six soft tone washes with a noise-wobbled terminator,
- Beer–Lambert pigment compositing (`paper * pigment^density`) so shadows get
  heavier, cooler pigment instead of turning grey,
- narrow metal specular, silhouette pigment pooling, warm rim light,
- emissive term for the visor, chest disc and blade runes.

## Procedural Unit Model

- Assembled from code at spawn: `build_mamluk(enemy) -> Mesh_Builder`.
- `body_point` remaps the bind pose (longer legs and torso, narrower frame);
  joint heads go through the same function so animation pivots stay attached.
- 25 joints; rigid skinning; three analytic clips plus secondary cape/sash/
  plume motion.
- Meshes are uploaded once per unit (raylib-owned arrays) and only positions
  and normals are rewritten per frame.
- `./bin/dreamcraft-dev --sheet` renders reference views through the full
  pipeline to `build/sheet/`.

## Web Client

The browser build keeps the previous lightweight 2:1 software canvas
renderer. The native client is the full 3D target.

## Tests

- `angle_toward` maps grid steps to model yaw (0° +Z, 90° +X).
- Mesh build size, finite normals, bounds and bone indices.
- Bind remap keeps the feet grounded and stretches the legs.
- Rotating a joint moves only its children.
- Animation clips stay finite; the attack clip returns to the guard pose.
- Face geometry stays below the turban rim.
