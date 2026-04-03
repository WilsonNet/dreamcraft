# Minimap Specification

## Design Reference

StarCraft: Brood War style minimap — bottom-left corner, always visible.

## Implementation

### Technology
- **Rendering**: Native Bevy UI nodes (absolute-positioned `Node` components)
- **Update Rate**: Player marker updates every 5 frames
- **Size**: 200x125 pixels (scaled cells for 80x50 grid)
- **Position**: Fixed screen-space at `left: 20px, bottom: 30px`

### Why Bevy UI (not React or Camera)

**Previous approaches and why they changed:**

1. **React Canvas (WASM)**: Required browser target, added complexity
2. **Second Bevy Camera**: In Bevy 0.18, a second Camera2d with `order > 0`:
   - Clears the entire screen with default clear color
   - `bevy::render::camera::Viewport` is private — cannot restrict render area
   - Result: minimap camera overwrites the main camera, making the player invisible

**Current solution - Bevy UI:**
- Uses `Node` components with `PositionType::Absolute`
- Screen-space positioning independent of camera
- Fixed position like CSS `position: fixed`
- No GPU overhead from extra camera passes
- Works on both native and WASM targets
- Pure Bevy, no HTML/React dependencies

### Data Structure

Minimap is spawned as a Bevy UI hierarchy:

```rust
Node {
    position_type: PositionType::Absolute,
    left: Val::Px(20.0),
    bottom: Val::Px(30.0),
    width: Val::Px(200.0),
    height: Val::Px(125.0),
    ..default()
}
```

Child nodes for each element:
- **Background**: Dark semi-transparent rectangle
- **Border**: Green border around minimap
- **Cell nodes**: 4000 absolute-positioned cells (80x50 grid)
  - Each cell: `left`, `bottom`, `width`, `height` in pixels
- **Waypoint markers**: Small circles at waypoint positions
- **Goal marker**: Yellow circle at right edge
- **Player marker**: Blue circle, updated every 5 frames

### Visual Mapping

| Element | Color |
|---------|-------|
| Background | `rgba(0.1, 0.1, 0.1, 0.9)` |
| Border | `rgb(0.3, 0.5, 0.3)` (green) |
| Tree/Obstacle | `rgba(0.2, 0.6, 0.2, 1.0)` (bright green) |
| Fog (unrevealed) | `rgba(0.05, 0.08, 0.05, 1.0)` (dark) |
| Ground (revealed) | `rgba(0.25, 0.4, 0.25, 1.0)` (medium green) |
| Player | `rgb(0.3, 0.6, 0.9)` (blue) |
| Current waypoint | `rgba(1.0, 0.9, 0.2, 1.0)` (yellow) |
| Other waypoints | `rgba(0.8, 0.7, 0.1, 0.7)` (dim gold) |
| Goal | `rgba(0.9, 0.8, 0.2, 1.0)` (gold) |

### Player Marker Update

System `update_native_minimap` runs every 5 frames:
```rust
fn update_native_minimap(
    grid: Res<GridConfig>,
    player_query: Query<&Unit, With<PlayerUnit>>,
    mut player_marker_query: Query<&mut Node, With<PlayerMinimapMarker>>,
    minimap_config: Res<MinimapConfig>,
) {
    let unit = player_query.single().unwrap();
    let cell_width = minimap_config.width / grid.grid_width as f32;
    let cell_height = minimap_config.height / grid.grid_height as f32;
    
    let player_left = unit.grid_x as f32 * cell_width;
    let player_bottom = unit.grid_y as f32 * cell_height;

    for mut node in player_marker_query.iter_mut() {
        node.left = Val::Px(player_left);
        node.bottom = Val::Px(player_bottom);
    }
}
```

### Fog of War Updates

Fog cells are static at spawn. To update fog visibility dynamically:
- Option 1: Query all `MinimapSprite` nodes and update `BackgroundColor`
- Option 2: Use a texture-based approach (future optimization)

Current implementation: Cells spawned with initial fog state, updates require system to query and modify `BackgroundColor` components.

## Position

```
+----------------------------------+
|                                  |
|          Game View               |
|                                  |
|                                  |
| +--------+                       |
| | minimap|  [status text]        |
| +--------+                       |
+----------------------------------+
```

- Fixed position: `left: 20px, bottom: 30px` (CSS-like)
- Independent of camera position
- Independent of window size (always bottom-left)
- Rendered on top of game view via Bevy UI camera (order: -1)
- Does not capture input (no `Interaction` component)
