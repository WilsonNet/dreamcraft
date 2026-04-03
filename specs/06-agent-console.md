# Agent Console Specification

## Purpose

The Agent Console is a React overlay that provides real-time game state inspection, diagnostics, and headless control. It enables both human debugging and automated (agentic) testing via Playwright.

## Toggle

- **Key**: Backtick (`` ` ``)
- **Position**: Right side panel (440px wide)
- **Z-index**: 9999 (above everything)

## UI Layout

```
+------------------------------+
| Agent Console  [Connected]  ESC |
+------------------------------+
| Pos:(2,25) WP:0/8 Fog:98% ... |
+------------------------------+
| [Warning banner if any]       |
+------------------------------+
| Console output (scrollable)   |
| > status                      |
| -- Game State --              |
| ...                           |
+------------------------------+
| > [input field]               |
+------------------------------+
```

## Commands

| Command | Description |
|---------|-------------|
| `help` | List all commands |
| `status` | Full game state with diagnostics |
| `fog` | Fog of war coverage stats |
| `waypoints` | List all waypoints with distances and reached status |
| `goto <x> <y>` | Move player to grid position (via A* pathfinding) |
| `next` | Move to current waypoint target |
| `autoplay` | Sequentially visit all waypoints, then goal zone |
| `reset` | Reset level to start |
| `watch` | Toggle live state output every 2s |
| `clear` | Clear console output |

## Diagnostics

The debug state includes automatic health checks:

| Field | Warning Condition |
|-------|------------------|
| `player_visible` | Player outside camera viewport |
| `player_in_fog` | Player cell not revealed |
| `camera_distance_to_player` | Distance > 800px |
| `is_selected` | Player unit lost selection |

Warnings display as:
1. Red banner below status bar (always visible when console open)
2. In `status` command output under "WARNINGS" section

## Communication Protocol

### localStorage Keys

| Key | Direction | Format | Update Rate |
|-----|-----------|--------|-------------|
| `dreamcraft_debug_state` | Bevy -> React | JSON (DebugState) | Every 30 frames |
| `dreamcraft_minimap` | Bevy -> React | Text grid (`.#PW `) | Every 30 frames |
| `dreamcraft_minimap_meta` | Bevy -> React | JSON (width, height, player) | Every 30 frames |
| `dreamcraft_command` | React -> Bevy | JSON (`{cmd, x?, y?}`) | On demand |
| `dreamcraft_command_result` | Bevy -> React | JSON (`{ok, msg}`) | On command |

### DebugState Schema
```json
{
  "frame": 60,
  "camera_pos": [-1200.0, 16.0],
  "player_pos": [-1200.0, 16.0],
  "player_grid": [2, 25],
  "current_waypoint": 0,
  "total_waypoints": 8,
  "waypoints": [[10,25], [20,25], ...],
  "level_complete": false,
  "is_selected": true,
  "has_target": false,
  "path_length": 0,
  "revealed_cells": 85,
  "total_cells": 4000,
  "fog_coverage_pct": 97.875,
  "obstacle_count": 132,
  "grid_width": 80,
  "grid_height": 50,
  "player_visible": true,
  "player_in_fog": false,
  "camera_distance_to_player": 0.0,
  "warnings": []
}
```

## Headless API

Exposed on `window.dreamcraftConsole`:

```js
getState()                    // Returns parsed DebugState or null
sendCommand(cmd, x, y)        // Writes command to localStorage
getCommandResult()             // Reads and clears command result
```

## Playwright Testing Pattern

```js
// Navigate and wait for game
await page.goto('http://localhost:8080');
await page.waitForTimeout(3000);

// Read state
const state = await page.evaluate(() =>
  JSON.parse(localStorage.getItem('dreamcraft_debug_state'))
);

// Send command
await page.evaluate(() =>
  localStorage.setItem('dreamcraft_command',
    JSON.stringify({ cmd: 'goto', x: 10, y: 25 }))
);

// Wait and verify
await page.waitForTimeout(5000);
const after = await page.evaluate(() =>
  JSON.parse(localStorage.getItem('dreamcraft_debug_state'))
);
assert(after.player_grid[0] === 10);
```
