# Input System

## Controls

| Input | Action |
|-------|--------|
| Left Click | Select single unit |
| Left Drag | Box select |
| Right Click | Move selected units / Attack enemy |
| Left Click on `Mo` HUD button (bottom-right) | Enter Move command mode |
| Left Click on terrain (while Move mode active) | Issue move command and exit Move mode |
| Left Click on `Pt` HUD button (bottom-right stack) | Enter Patrol command mode |
| First Left Click on terrain (Patrol mode) | Set patrol point A |
| Second Left Click on terrain (Patrol mode) | Set patrol point B and start A↔B loop |
| Left Click on Minimap | Center main camera to clicked map location |
| Right Click on Enemy | Attack (move into melee range and deal damage) |
| Shift + Click | Add to selection |
| Escape | Clear selection |

## Selection Box
- Start drag from top-left
- End drag at bottom-right
- Units within box are selected
- Minimum 5px drag distance = box select

## Camera

### WASD / Arrow Keys
- WASD or arrow keys pan the camera at 400 px/sec
- Camera is clamped to grid bounds (+200px margin)

### Screen Edge Scrolling (RTS Standard)
- When mouse cursor enters the 20px zone at any screen edge, camera scrolls
- Scroll speed is progressive: faster the closer the cursor is to the edge
- Speed ramps from 200 px/sec (at 20px from edge) to 600 px/sec (at 0px from edge)
- X and Y axes scroll independently
- Works alongside keyboard camera controls
- Camera is clamped to grid bounds

## Movement
- Right-click sets target position
- Right-click on an enemy unit issues an attack command instead
- `Mo` command mode allows left-click movement orders from the lower RTS HUD
- A* pathfinding calculates route
- Pathfinding supports 8-direction movement (including diagonals)
- Units follow path waypoints
- Stop at destination
- Unit state becomes `Moving` while traversing an active path

## Patrol
- `Pt` command mode uses two clicks to define patrol points A and B
- After both points are set, unit loops between A and B indefinitely
- Patrol uses pathfinding for each leg (A->B then B->A)
- Patrol is cancelled by explicit move orders (`Right Click` or `Mo` order)

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
