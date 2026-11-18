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

- **Player Unit**: Blue animated 3D knight (idle/walk/attack)
  - Speed: 150.0 (world units/sec)
  - Vision range: 6 cells (radius)
  - Controlled via right-click movement
  - Right-click on enemy = attack
  - Health: 100 HP with health bar above unit
  - Combat: 15 damage, 3-cell range, 1s cooldown
    
- **Enemy Unit**: Red animated 3D knight (idle/walk/attack)
  - Speed: 150.0 (world units/sec)
  - Same race as player (melee unit)
  - Hidden in fog until revealed
  - Health: 100 HP with health bar above unit
  - Combat: 15 damage, 3-cell range, 1s cooldown
  - AI Behavior:
    - Chases player when player enters enemy view radius
    - Attacks player on cooldown when in melee range
    - Stops chasing when player leaves enemy view radius

### Race And Team Semantics

- Available races: `Basic`, `Akana`, `Gorg`.
- Tutorial Level 1 uses `Basic` race for both teams.
- The native client renders the **melee warrior model**; blue/red cloth marks team.
- The HUD and debug APIs still use `M` as the logical melee type.
- Team is represented by `Team` ownership and color tint (blue player / red enemy).

### Unit Model: Mamluk

The native client builds every melee unit from code. There is no GLB, no
Blender step, and no asset pipeline for units.

- `odin/client/mamluk_model.odin` + `mamluk_head.odin` assemble the model from
  parametric primitives (lathes, ellipsoids, tori, swept blades, domed plates).
- 25-joint rig (`odin/client/unit_rig.odin`): root, pelvis, spine, chest, neck,
  head, plume, shoulders/arms/hands, legs/feet, three cape joints, sash.
- Clips are analytic functions, not keyframes:
  `idle` 2.40 s loop, `walk` 0.72 s loop, `attack` 0.46 s one-shot
  (`odin/client/unit_anim.odin`).
- Skin is rigid per part and done on the CPU each frame; the mesh buffer is
  rewritten with skinned positions and normals.
- Face direction follows the next path cell, or the attack target.
- Attack triggers when the simulation attack cooldown resets and always eases
  back into the guard pose.
- Blue/red cloth and turban bands mark the team; the model is otherwise shared.
- Look: Toriyama / Dragon Quest proportions and palette with Diablo 2 framing.
  See `.agents/skills/art-direction/SKILL.md`.
- Reference renders: `./bin/dreamcraft-dev --sheet` writes `build/sheet/*.png`
  (front, 3/4, side, back, walk, attack, head, helm).

### Legacy Unit Asset

`odin/assets/warrior/*.glb` and `odin/tools/warrior/` are kept for reference
only. The client no longer loads them.

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
- Health bar updates dynamically when damage is taken

### Combat System

**Melee Combat**:
- All units have `CombatStats` (damage: 15, range: 3 cells, cooldown: 1s)
- Units with `AttackTarget(entity)` pathfind toward target and attack when in range
- Attack cooldown timer decrements each frame; attacks fire when timer reaches 0
- Damage is applied instantly (no projectile animation yet)
- Units despawn when health reaches 0

**Right-Click to Attack**:
- Right-clicking on an enemy unit sets `AttackTarget` for the player unit
- Player unit pathfinds to enemy and attacks on cooldown
- Issuing a move order clears `AttackTarget`
- Move and Patrol commands always override combat targeting

**Enemy AI Combat**:
- `enemy_ai_chase` sets `AttackTarget(player_entity)` when player is within vision radius
- `attack_movement` handles pathfinding toward the attack target
- `combat_tick` applies damage when in range
- Enemies stop chasing (clear `AttackTarget`) when player leaves vision radius

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

struct CombatStats {
    damage: u32,
    attack_range: f32,
    cooldown_timer: f32,
}

struct AttackTarget(Option<Entity>);
```

## Systems

### Combat Systems (in `combat/`)
- `attack_movement` — Pathfind toward attack target; stop when in range
- `combat_tick` — Apply damage to target when in range and cooldown ready
- `death_check` — Despawn entities with 0 HP

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

---

## Odin Implementation Values

The Odin port uses these current values (tutorial level):

| Stat | Value |
|------|-------|
| Move speed | 150 world units/s (4.6875 cells/s) |
| Max HP | 100 |
| Attack damage | 15 |
| Attack range | 3 cells (Euclidean) |
| Attack cooldown | 60 ticks (1.0 s) |
| Vision radius | 6 cells |
| Unit capacity | 256 slots (SoA pool) |
| Path capacity | 512 cells per unit |

Player and enemy share the same melee stat block; team/color is the only
difference. Unit references are generation handles, not ECS entities.
