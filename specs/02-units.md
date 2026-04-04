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
  - Health: 100 HP with health bar above unit
   
- **Enemy Unit**: Red circle with "M" label
  - Speed: 150.0 (world units/sec)
  - Same race as player (melee unit)
  - Hidden in fog until revealed
  - Health: 100 HP with health bar above unit
  - AI Behavior:
    - Chases player when player enters enemy view radius
    - Stops chasing when player leaves enemy view radius
    - Re-paths to current player position as needed

### Race And Team Semantics

- Available races: `Basic`, `Akana`, `Gorg`.
- Tutorial Level 1 uses `Basic` race for both teams.
- The **shape** (currently circle placeholder) represents race art placeholder, not team.
- The **letter** represents unit type (`M` = Melee), not team.
- Team is represented by `Team` ownership and color tint (blue player / red enemy).

### Health Bars

All units have StarCraft-style health bars:
- Positioned above unit
- 24px wide, 4px tall
- Color indicates health level:
  - Green (> 50%)
  - Yellow (25-50%)
  - Red (< 25%)
- Background: dark gray
- Auto-spawned when unit is created

### Unit State Machine

Universal state machine for all units (player and AI):

**States**:
- `Idle`: Default state, no active behavior
- `Moving`: Unit has an active movement path
- `Patrol`: Unit is executing a repeating A↔B patrol route

## Component Structure

```rust
enum Team {
    Player,
    Enemy,
}

struct Unit {
    speed: f32,
    grid_x: usize,
    grid_y: usize,
}

enum Race {
    Basic,
    Akana,
    Gorg,
}

#[derive(Bundle)]
struct MeleeUnit {
    unit: Unit,
    health: Health,
    state: UnitStateMachine,
    target: Target,
    patrol: PatrolRoute,
}

impl MeleeUnit {
    const LABEL: &'static str = "M";
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

struct PlayerUnit;
struct EnemyUnit;
struct Selected;

struct PatrolRoute {
    active: bool,
    point_a: (usize, usize),
    point_b: (usize, usize),
    go_to_b_next: bool,
}
```

## Fog of War Visibility

### Grid States

- **3-state system**:
  - `0 = Unexplored`: Black, never seen
  - `1 = Explored`: Dark, was visible but now out of range
  - `2 = Visible`: Bright, currently in vision range

- **Vision range**: 6 cell radius (circular)

### Enemy Visibility (Line of Sight)

Enemies are hidden by default and only become visible when:
1. Within player's vision radius (6 cells, circular)
2. The enemy's cell is currently marked as "Visible" (state 2) in the visibility grid

This creates a true Fog of War experience where enemies can hide in unexplored or dark areas.

### Enemy AI

**View-Radius Agro Behavior**:
- System: `enemy_ai_chase` runs every frame
- Enemy enters chase immediately when player is inside enemy view radius
- Calculates path to player using A* pathfinding
- Recalculates when needed (path empty, finished, or destination changed)
- Clears chase path when player leaves enemy view radius

**Systems**:
- `update_enemy_visibility`: Manages visibility and triggers agro state
- `enemy_ai_chase`: Calculates chase paths for agro enemies
- `unit_movement`: Universal movement for all units (player and AI)
