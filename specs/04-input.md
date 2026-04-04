# Input System

## Controls

| Input | Action |
|-------|--------|
| Left Click | Select single unit |
| Left Drag | Box select |
| Right Click | Move selected units |
| Left Click on `Mo` HUD button (bottom-right) | Enter Move command mode |
| Left Click on terrain (while Move mode active) | Issue move command and exit Move mode |
| Left Click on Minimap | Center main camera to clicked map location |
| Right Click on Enemy | Attack |
| Shift + Click | Add to selection |
| Escape | Clear selection |

## Selection Box
- Start drag from top-left
- End drag at bottom-right
- Units within box are selected
- Minimum 5px drag distance = box select

## Movement
- Right-click sets target position
- `Mo` command mode allows left-click movement orders from the lower RTS HUD
- A* pathfinding calculates route
- Units follow path waypoints
- Stop at destination
- Unit state becomes `Moving` while traversing an active path

## Command Cursor
- Clicking `Mo` changes cursor to a move-style cursor
- After issuing a movement target with left-click, cursor returns to default

## HUD Layout Notes
- Lower HUD is taller than minimap top edge by about 10px
- Minimap remains visually above HUD background layer
- Command button area is anchored to bottom-right
- Bottom-center command card region is reserved for future control groups

## Minimap Camera Navigation
- Left-click inside minimap recenters the main camera
- Click position is mapped from minimap normalized coordinates to grid coordinates
- Y-axis is inverted from UI space so minimap top maps to high grid Y
- Camera position is clamped to world camera bounds after recentering
