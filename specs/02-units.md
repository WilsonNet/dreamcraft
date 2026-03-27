# Units

## Unit Types

| Type | Symbol | Speed | HP | Attack Range | Damage | Role |
|------|--------|-------|-----|--------------|--------|------|
| Gatherer | G | 4.0 | 100 | 2.0 | 5 | Resource collection |
| Scout | S | 10.0 | 50 | 2.0 | 5 | Vision/scouting |
| Melee | M | 5.0 | 150 | 3.0 | 15 | Frontline combat |
| Ranged | R | 4.0 | 80 | 15.0 | 10 | Ranged attacks |

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