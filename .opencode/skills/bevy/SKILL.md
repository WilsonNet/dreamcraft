---
name: bevy
description: Bevy ECS patterns, common errors, UI patterns, WASM setup, debug console, minimap
---

# Bevy Game Engine Skill

Use this skill when working with Bevy ECS game engine in Rust/WASM projects.

## Common Patterns

### Camera 2D Setup
```rust
commands.spawn((
    Camera2d,
    Name::new("MainCamera"),
    Transform::from_xyz(start_x, start_y, 100.0),
));
```

### Querying Single Entity
```rust
// WRONG - single() returns Result
let transform = camera_query.single_mut();

// CORRECT - unwrap or check
let mut transform = camera_query.single_mut().unwrap();
```

### UI Node Properties (bevy_ui)
```rust
// Position
position_type: PositionType::Absolute,  // NOT NodePositionType

// Borders
border: UiRect::all(Val::Px(2.0)),
BorderColor::all(Color::srgb(0.3, 0.5, 0.3)),  // NOT BorderColor(...)

// Sizing
width: Val::Px(200.0),
height: Val::Px(125.0),
```

### Resource Change Detection
```rust
if visibility.is_changed() {
    // update fog cells
}
```

### A* Pathfinding Node Naming
```rust
// DON'T name it Node - conflicts with bevy_ui::Node!
struct AStarNode { x: usize, y: usize, f: u32, g: u32 }
```

### WindowResolution in Bevy 0.18
```rust
// WRONG - f32 tuples don't implement Into<WindowResolution>
resolution: (1280.0, 720.0).into(),

// CORRECT - use u32 tuples
resolution: (1280, 720).into(),
```

## Common Errors

| Error | Fix |
|-------|-----|
| "struct Node has no field" | Renamed your A* node to `AStarNode` |
| "use of undeclared type NodePositionType" | Should be `PositionType` |
| "BorderColor struct literal" | Use `BorderColor::all(Color::...)` |
| "single() returns Result" | Use `.unwrap()` on single() calls |
| Query B0001 Error | Don't access `&T` and `&mut T` on same component |
| "Viewport struct private" | Can't use `bevy::render::camera::Viewport` in 0.18 |
| "From not implemented for WindowResolution" | Use `(u32, u32)` not `(f32, f32)` |
| Second camera overwrites screen | Cameras with order > 0 clear the whole screen — use HTML overlays |

## CRITICAL: Multiple Camera Pitfall

**DO NOT use a second Camera2d for minimap/overlays.** In Bevy 0.18:
- A camera with `order: 1` and no viewport renders full screen
- It clears with default clear color, overwriting the main camera
- `bevy::render::camera::Viewport` is private — cannot set viewport
- **Solution**: Use HTML/React canvas overlays for minimap, debug UI, etc.

```rust
// BAD - overwrites main camera, player invisible!
commands.spawn((Camera2d, Camera { order: 1, ..Default::default() }));

// GOOD - single camera, overlays via HTML/React
commands.spawn((Camera2d, Transform::from_xyz(x, y, 100.0)));
// Minimap/console rendered as React components in index.html
```

## WASM + Trunk

### Cargo.toml
```toml
[lib]
crate-type = ["rlib"]  # NOT cdylib!

# NEVER put dynamic_linking in default features — breaks WASM!
bevy = "0.18.1"  # NOT bevy = { features = ["dynamic_linking"] }
# Use CLI flag for native only: cargo run --features bevy/dynamic_linking
```

### WASM Entry Point (src/web.rs)
```rust
use bevy::prelude::*;
use dreamcraft::DreamCraftPlugin;

fn main() {  // NOT #[wasm_bindgen(start)] — trunk handles this
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "DreamCraft RTS".into(),
                resolution: (1280, 720).into(),  // u32!
                fit_canvas_to_parent: true,
                prevent_default_event_handling: false,
                ..default()
            }),
            ..default()
        }))
        .add_plugins(DreamCraftPlugin)
        .run();
}
```

### Trunk.toml
```toml
[serve]
port = 8080

[watch]
watch_paths = ["src", "index.html"]
ignore = ["target", "dist", ".playwright-mcp", "web", "bevy-docs"]
```

### index.html
```html
<link data-trunk rel="rust" data-bin="dreamcraft-web" />
<!-- Prevent right-click context menu -->
<script>document.addEventListener('contextmenu', e => e.preventDefault());</script>
```

### Trunk Cache Issues
```bash
# Trunk may not detect lib.rs changes. Force rebuild:
touch src/lib.rs && trunk build
```

## Bevy <-> React Interop via localStorage

### Bevy Side: Broadcasting State
```rust
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = localStorage)]
    fn setItem(key: &str, value: &str);
    #[wasm_bindgen(js_namespace = localStorage)]
    fn getItem(key: &str) -> Option<String>;
    #[wasm_bindgen(js_namespace = localStorage)]
    fn removeItem(key: &str);
}

fn broadcast_debug_state(json: &str) {
    setItem("dreamcraft_debug_state", json);
}
```

### Bevy Side: Reading Commands
```rust
fn read_console_commands(/* ... */) {
    let cmd_str = match getItem("dreamcraft_command") {
        Some(s) if !s.is_empty() => s,
        _ => return,
    };
    removeItem("dreamcraft_command");
    // Parse and execute...
    setItem("dreamcraft_command_result", &result_json);
}
```

### React Side (in index.html)
```js
// Read state
const s = JSON.parse(localStorage.getItem('dreamcraft_debug_state'));

// Send command
localStorage.setItem('dreamcraft_command', JSON.stringify({ cmd: 'goto', x: 10, y: 25 }));

// Read result
const r = JSON.parse(localStorage.getItem('dreamcraft_command_result'));
```

## Debug Diagnostics

The debug state includes automatic warnings:
- `player_visible` — is player within camera viewport?
- `player_in_fog` — is player cell revealed?
- `camera_distance_to_player` — px distance
- `warnings` array — auto-populated from checks above

These surface in the Agent Console UI as a red warning banner and in `status` output.

## Minimap (StarCraft-style)

Implemented as React canvas component, NOT a Bevy camera:
- Bevy broadcasts `dreamcraft_minimap` (compact text grid) to localStorage
- React reads it and draws on a `<canvas>` element
- Characters: `.` = fog, `#` = obstacle, ` ` = revealed, `P` = player, `W` = current waypoint, `w` = other waypoint
- Camera viewport drawn as white rectangle
