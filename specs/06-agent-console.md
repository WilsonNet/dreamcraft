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

## Native client UI commands (HTTP control API)

The native client (`--control=<port>`) also answers these `POST /command` bodies, for driving and
inspecting the vinland-ui HUD (see `specs/09-ui-framework.md`):

| Body | Result |
|------|--------|
| `{"cmd":"ui_tree","value":40}` | `msg` holds a JSON list of elements: kind, class, text (`t`), rect |
| `{"cmd":"ui_click","text":"Resume Battle"}` | Clicks the first visible element containing the text with the synthetic mouse |
| `{"cmd":"ui_stats"}` | Nodes, instances, batches, build/render ms, pointer capture |
| `{"cmd":"pause_menu"}`, `open_picker`, `open_editor` (+ `model`), `close_editor`, `open_anim_picker`, `open_anim_editor` (+ `model`), `close_anim_editor`, `reload_models`, `reload_anims`, `open_help`, `close_help` | Jump to a screen or reload `.odin` art assets |

`GET /camera` includes `minimap: [x, y, w, h]`, `editor_model`, and `editor_clip` so tests inspect live state without hard-coding layout.

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

---

## Odin Control API (current replacement)

The Odin port replaces the React/localStorage/BRP console with a localhost
JSON API. It is available in both binaries:

```bash
odin/bin/dreamcraft --control=7777   # live game + rendering
odin/bin/headless --serve=7777       # deterministic simulation only
```

Endpoints:

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | liveness |
| GET | `/state` | tick, player/enemy, `player_units`, `enemy_units`, `neutral_units`, `rescued_count`, discovery_announced, enemy_aggro_ticks, fog %, hash, valid, validation |
| GET | `/units` | unit list with name, hero, team (`player`/`enemy`/`neutral`), position, HP, damage, armor, state, path, target, `groups`, `queued_orders`, discovered, aggro_ticks |
| GET | `/fog` | 128×80 ASCII map |
| GET | `/screenshot` | live PNG (client only) |
| GET | `/camera` | live camera, zoom, focus, cursor, `app_mode`, `editor_model`, `help_open`, edge-pan & grip state (client only) |
| POST | `/command` | execute a JSON command (plus client `reload_models`, `open_picker`, `open_editor`, `close_editor`, `pause_menu`, `toggle_help`, `open_help`, `close_help`) |
| POST | `/mouse` | inject deterministic client mouse/wheel/focus probe frames (client only) |

Mouse & camera validation tool (`odin/tests/camera_mouse_check.py`):
- `--mode probe`: tests edge arming, exact `0`/`width`/`height` borders, pitch-compensated vertical/horizontal speed, MMB 1:1 grip, `Space`+Left grip, wheel zoom, minimap click/drag, unfocus disarm, and PNG screenshots via `POST /mouse` + `GET /camera`.
- `--mode os`: drives real macOS CoreGraphics mouse events (`mouseMoved`, `leftMouseDown/Up`, `otherMouseDown/Dragged/Up`, scroll wheel) over a live `dreamcraft-dev` window and verifies camera movement via `GET /camera`.

Commands: `status`, `goto`, `patrol`, `patrol_to`, `attack`, `attack_move`, `stop`, `run`, `reset`,
`verify`, `select`, `select_all`, `deselect`, `group_assign`, `group_add`, `group_steal`, `group_steal_add`, `group_select`, `clear_enemies`, `spawn`, `kill`, `set_hp`, `teleport`, and client-only
`reload_models`, `open_picker`, `open_editor`, `close_editor`, `pause_menu`, `toggle_help`, `open_help`, `close_help` (`model` specifies asset ID). Unit commands accept `"queued": true` for Shift-queued waypoints; `verify` also supports `player_count`, `enemy_count`, `neutral_count`, `rescued_count`, `selected_count`, and `group_count`.

Playwright-style Cooperative Mesh CLI (`odin/tools/mesh_cli/` -> `odin/bin/dreamcraft-mesh` / `odin/bin/dreamcraft-mesh-dev`):
- Zero saved scripts: inline CLI args or stdin (`-`) operate on any of the 12 catalog models in chunked `.odin` format (`client/art/models/<id>/`), with `--root=`, `--json`, `--dry-run`, `--expect-fail`, and `--notify=<port>` (`POST /command {"cmd":"reload_models"}`).
- Subcommands: `list`, `extract <model>`, `info <model> [--bones|--mats|--bounds|--parts]`, `assert <model> <checks...>` (`!` negation, `--expect-fail`), `do|edit <model> <ops...>` (atomic ops + inline `expect:`).

Every response includes `valid` and `validation`, plus `game_over` when the
player has died. Agents can detect invariant violations without reading logs.

`GET /units` also returns `world` (float world position), `progress` (cells
between `position` and `next`) and `next` (current path cell). Use these to
detect interpolation jumps or snap-backs after command changes.

The web build exposes the same command set at `window.dreamcraft`:
`state()`, `units()`, `fog()`, `command(obj)`, `reset()`.

The old Agent Console / Bevy BRP MCP path is not used by the Odin client.
