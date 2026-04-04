# Units

## Unit Types

### Implemented Units

| Type | Symbol | Color | Speed | HP | Attack Range | Damage | Role |
|------|--------|-------|-------|-----|--------------|--------|------|
| Melee | M | Blue (player) / Red (enemy) | 5.0 | 150 | 3.0 | 15 | Frontline combat |

### Planned Units

| Type | Symbol | Color | Speed | HP | Attack Range | Damage | Role |
|------|--------|-------|-------|-----|--------------|--------|------|
| Gatherer | G | Green | 4.0 | 100 | 2.0 | 5 | Resource collection |
| Scout | S | Cyan | 10.0 | 50 | 2.0 | 5 | Vision/scouting |
| Ranged | R | Purple | 4.0 | 80 | 15.0 | 10 | Ranged attacks |

## Current Implementation (Tutorial Level 1)

- **Player Unit**: Blue circle with "M" label
  - Speed: 150.0 (world units/sec)
  - Vision range: 6 cells (radius)
  - Controlled via right-click movement
  
- **Enemy Unit**: Red circle with "M" label
  - Speed: 80.0 (world units/sec)
  - Same race as player (melee unit)
  - Hidden in fog until revealed
  - Stationary (no AI implemented yet)

## Component Structure

```rust
struct Unit {
    unit_type: UnitType,
    speed: f32,
    hp: u32,
    max_hp: u32,
    attack_range: f32,
    vision_range: f32,
    damage: u32,
}

struct UnitTransform {
    position: Vec2,
    velocity: Vec2,
    rotation: f32,
}

struct Target {
    position: Option<Vec2>,
    entity: Option<Entity>,
    path: Vec<Vec2>,
}

struct Selected;
```

## Fog of War Visibility

- **3-state system**:
  - `0 = Unexplored`: Black, never seen
  - `1 = Explored`: Dark, was visible but now out of range
  - `2 = Visible`: Bright, currently in vision range

- **Vision range**: 6 cell radius (circular)

- **Enemy hidden in fog**: Enemy units only visible when within player's vision range