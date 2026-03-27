# Bevy Game Engine Skill

Use this skill when working with Bevy ECS game engine in Rust/WASM projects.

## Common Patterns

### Camera 2D Setup
```rust
commands.spawn(Camera2d);
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

// Margins
left: Val::Px(10.0),
bottom: Val::Px(10.0),
```

### Spawning with Children (UI)
```rust
commands.spawn((Camera2d, Name::new("MinimapCamera")))
    .with_children(|parent| {
        parent.spawn((
            Node {
                width: Val::Px(200.0),
                ..Default::default()
            },
            BackgroundColor(Color::srgb(0.1, 0.1, 0.1)),
        ));
    });
```

### Query Single Window
```rust
// WRONG
let window = window_query.single();

// CORRECT
let window = window_query.single().unwrap();
let width = window.width();
```

### Resource Change Detection
```rust
// Check if resource changed this frame
if visibility.is_changed() {
    // update fog cells
}
```

### A* Pathfinding Node Naming
```rust
// DON'T name it Node - conflicts with bevy_ui::Node!
// DO name it AStarNode or PathNode
struct AStarNode {
    x: usize,
    y: usize,
    f: u32,
    g: u32,
}
```

## Common Errors

### "struct Node has no field"
- You named your A* node `Node` - rename to `AStarNode`

### "use of undeclared type NodePositionType"
- Should be `PositionType`

### "BorderColor struct literal"
- Use `BorderColor::all(Color::...)` not `BorderColor(Color::...)`

### "single() returns Result"
- Use `.unwrap()` or `.expect()` on single() calls

### Query B0001 Error
- Don't access both `&T` and `&mut T` on same component
- Use `ParamSet<(Query<&T>, Query<&mut T>>)`

## WASM + Trunk

### Cargo.toml crate-type
```toml
[lib]
crate-type = ["rlib"]  # NOT cdylib!
```

### Trunk.toml
```toml
[build]
target = "wasm32-unknown-unknown"

[[bin]]
name = "dreamcraft-bin"  # Different from lib name
```

### index.html
```html
<link data-trunk rel="rust" data-bin="dreamcraft-bin" />
```
