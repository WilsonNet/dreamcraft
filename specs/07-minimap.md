# Minimap Specification

## Design Reference

StarCraft: Brood War style minimap — bottom-left corner, always visible.

## Implementation

### Technology
- **Rendering**: React canvas component (HTML5 Canvas 2D)
- **Data Source**: Bevy broadcasts compact text grid to `dreamcraft_minimap` localStorage key
- **Update Rate**: Every 30 frames (~0.5s at 60fps)
- **Size**: 200x125 pixels

### Why React Canvas (not Bevy Camera)

In Bevy 0.18, a second Camera2d with `order > 0`:
- Clears the entire screen with default clear color
- `bevy::render::camera::Viewport` is private — cannot restrict render area
- Result: minimap camera overwrites the main camera, making the player invisible

The React canvas approach:
- Reads lightweight text data from localStorage (no GPU overhead)
- Renders independently as an HTML overlay
- Same origin as game (trunk serves both), so localStorage works
- Easily styled and positioned with CSS

### Data Format

The `dreamcraft_minimap` key contains a text grid:
```
.......................
..P  ##..............
..   ##..............
..    .w.............
.......................
```

| Character | Meaning |
|-----------|---------|
| `.` | Unrevealed (fog of war) |
| ` ` (space) | Revealed, empty ground |
| `#` | Obstacle (tree) |
| `P` | Player position |
| `W` | Current waypoint target |
| `w` | Other waypoint (reached or pending) |

Rows separated by `\n`. Grid is `width` x `height` (80x50).

### Visual Mapping

| Character | Canvas Color |
|-----------|-------------|
| `.` | `#080e08` (very dark green) |
| ` ` | `#1a2a1a` (dark green) |
| `#` | `#1a4a1a` (medium green) |
| `P` | `#4a9aff` (blue circle) |
| `W` | `#ffdd33` (yellow circle) |
| `w` | `#665511` (dim gold) |

### Camera Viewport

A white rectangle shows the main camera's view area on the minimap:
- Camera position from `dreamcraft_debug_state`
- Viewport size: ~40x22.5 grid cells (1280/32, 720/32)
- Grid offset: (-1280, -800) with cell_size 32

### Goal Zone

The rightmost 3 columns are highlighted with a semi-transparent gold overlay when revealed.

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

- Fixed position: left: 8px, bottom: 8px
- z-index: 9998
- pointer-events: none (doesn't capture clicks)
- Box shadow for depth
- Green border (`#3a5a3a`)
