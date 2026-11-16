# Isometric Coordinate System

## Grid Configuration

- Simulation grid: 80×50 cells, 32 world units per cell.
- Isometric tile: 64×32 px (2:1 ratio) in the native client.
- Web tile: 8×4 px in a 640×400 RGBA framebuffer.
- The simulation remains orthogonal; only clients project to iso space.

Continuous grid coordinates are used for projection:

- integer values are cell corners,
- cell `(gx, gy)` has its center at `(gx + 0.5, gy + 0.5)`.

## Transformations

### Grid to Screen (Isometric Projection)

```
screenX = (gridX - gridY) * (tileWidth / 2)
screenY = (gridX + gridY) * (tileHeight / 2)
```

For a cell center in the native client:

```
screenX = (gx - gy) * 32
screenY = (gx + gy + 1) * 16
```

### Screen to Grid (Inverse)

```
gridX = (screenX / (tileWidth / 2) + screenY / (tileHeight / 2)) / 2
gridY = (screenY / (tileHeight / 2) - screenX / (tileWidth / 2)) / 2
cell  = (floor(gridX), floor(gridY))
```

### Interpolated Units

`units.world` stores the orthogonal fixed-point position. The client maps it
back to continuous grid coordinates, then applies the iso projection:

```
gridX = (worldX - WORLD_MIN_X) / CELL_SIZE
gridY = (worldY - WORLD_MIN_Y) / CELL_SIZE
```

This keeps unit movement smooth while the renderer is isometric.

## Native Rendering Order

Back-to-front:

1. Ground diamond and grid lines every 4 cells.
2. Goal-zone tinted diamonds and boundary line.
3. Trees, depth-sorted by `gx + gy`.
4. Waypoint ellipses.
5. Fog diamonds for unexplored/explored cells (camera-culled).
6. Units, depth-sorted by interpolated world position.
7. Selected path lines and dots.
8. HUD, minimap, selection box, pause menu in screen space.

Units are billboard circles with a ground shadow and a ground selection
ellipse. Fog and goal overlays are flat 2:1 diamonds.

Raylib's `DrawTriangle` is back-face culled. Screen-space vertices must be
counter-clockwise (`top, bottom, right`); clockwise diamonds silently vanish.

## Camera

- `Camera2D` target is in iso space.
- Follow mode uses `iso_from_world(units.world[player])`.
- Manual pan, edge scroll and minimap click set an iso target.
- Camera clamp covers the map diamond:
  `x ∈ [-GRID_H*32 - 200, GRID_W*32 + 200]`,
  `y ∈ [-200, (GRID_W+GRID_H)*16 + 200]`.

## Web Client

- Framebuffer: 640×400; tile half extents: 4×2 px.
- Map offset: `(260, 70)`.
- Cell center pixel: `(260 + (gx-gy)*4, 70 + (gx+gy+1)*2)`.
- Mouse clicks invert the same projection before selecting or issuing orders.
- The ASCII fog map and minimap stay top-down for debugging.

## Tests

- Grid ↔ iso round trip for map corners and fractional points.
- Cell center projects back to its own cell.
- `iso_from_world(grid_to_world(cell))` equals the iso cell center.
- Screen center with a camera targeting a cell maps back to that cell.
- Web smoke test asserts framebuffer size and iso constants.
