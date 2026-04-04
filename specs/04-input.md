# Input System

## Controls

| Input | Action |
|-------|--------|
| Left Click | Select single unit |
| Left Drag | Box select |
| Right Click | Move selected units |
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
- A* pathfinding calculates route
- Units follow path waypoints
- Stop at destination

## Minimap Camera Navigation
- Left-click inside minimap recenters the main camera
- Click position is mapped from minimap normalized coordinates to grid coordinates
- Y-axis is inverted from UI space so minimap top maps to high grid Y
- Camera position is clamped to world camera bounds after recentering
