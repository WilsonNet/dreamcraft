---
name: bevy
description: Bevy ECS patterns, common errors, UI patterns, native/WASM setup, headless commands
---

# Bevy Game Engine Skill

Use this skill when working with Bevy ECS game engine in Rust projects.

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
- **Solution**: Use Bevy UI nodes for minimap, debug UI, etc.

```rust
// BAD - overwrites main camera, player invisible!
commands.spawn((Camera2d, Camera { order: 1, ..Default::default() }));

// GOOD - single camera, overlays via Bevy UI
commands.spawn((Camera2d, Transform::from_xyz(x, y, 100.0)));
```

## Native Development (PRIMARY)

### Cargo Configuration (.cargo/config.toml)
```toml
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=/usr/bin/mold"]
```

### Running Native (with dynamic linking for fast iteration)
```bash
# With window (for playing)
cargo run --bin dreamcraft-bin --features bevy/dynamic_linking

# Headless (for agents/LLMs)
cargo run --bin dreamcraft-bin --features bevy/dynamic_linking -- --headless
```

### Cargo.toml
```toml
[lib]
crate-type = ["rlib"]  # NOT cdylib!

# NEVER put dynamic_linking in default features — breaks WASM!
bevy = "0.18.1"
# Use CLI flag for native only: cargo run --features bevy/dynamic_linking
```

## WASM + Trunk

### Trunk.toml
```toml
[serve]
port = 8080

[watch]
watch_paths = ["src", "index.html"]
ignore = ["target", "dist", ".playwright-mcp", "web", "bevy-docs"]
```

### index.html (minimal, no React)
```html
<link data-trunk rel="rust" data-bin="dreamcraft-web" />
<script>document.addEventListener('contextmenu', e => e.preventDefault());</script>
```

### Trunk Cache Issues
```bash
# Trunk may not detect lib.rs changes. Force rebuild:
touch src/lib.rs && trunk build
```

## Headless Commands (Native)

### File-based command system
Commands are read from `headless_command.json`, results written to `headless_result.json`.

```rust
// lib.rs - read commands every 30 frames
fn read_stdin_commands(
    mut player_query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
    obstacle_grid: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    game_state: Res<GameState>,
    mut frame_counter: Local<u64>,
) {
    *frame_counter += 1;
    if *frame_counter % 30 != 0 { return; }

    let cmd_file = std::path::Path::new("headless_command.json");
    if !cmd_file.exists() { return; }

    let buffer = std::fs::read_to_string(cmd_file).unwrap_or_default();
    let _ = std::fs::remove_file(cmd_file);

    let cmd: ConsoleCommand = serde_json::from_str(&buffer).unwrap();
    let result = handle_headless_command(&mut player_query, ...);
    write_result(&result);
}

fn write_result(result: &serde_json::Value) {
    let _ = std::fs::write("headless_result.json", result.to_string());
    println!("RESULT: {}", result);
}
```

### Available Commands
```bash
# Status
echo '{"cmd": "status"}' > headless_command.json

# Move player
echo '{"cmd": "goto", "x": 10, "y": 25}' > headless_command.json

# Verify player position
echo '{"cmd": "verify", "verify": {"type": "player_at", "x": 10, "y": 25}}' > headless_command.json

# Verify level complete
echo '{"cmd": "verify", "verify": {"type": "level_complete"}}' > headless_command.json
```

### Response Format
```json
{"ok": true, "msg": "Player at (2, 25)", "player_grid": [2, 25]}
```

## WASM Browser Interop (localStorage)

Only needed for browser/WASM builds. Uses localStorage bridge:

```rust
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = localStorage)]
    fn setItem(key: &str, value: &str);
    #[wasm_bindgen(js_namespace = localStorage)]
    fn getItem(key: &str) -> Option<String>;
    #[wasm_bindgen(js_namespace = localStorage)]
    fn removeItem(key: &str);
}
```

Commands sent via `dreamcraft_command`, results in `dreamcraft_command_result`.

## Debug Diagnostics

The debug state includes automatic warnings:
- `player_visible` — is player within camera viewport?
- `player_in_fog` — is player cell revealed?
- `camera_distance_to_player` — px distance
- `warnings` array — auto-populated from checks above
