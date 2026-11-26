# Units

## Unit Types

### Implemented Units

| Type | Name | Team | Speed | HP | Attack Range | Damage | Cooldown | Role |
|------|------|------|-------|-----|--------------|--------|----------|------|
| Hero (`Unit_Kind.Hero`) | **Liiroy, the Bold** | Player (Campaign) | 180 (+20%) | 500 (5 arm, +4 HP/s) | 3.0 cells | 35 | 40 ticks (0.67 s) | Campaign hero champion (royal cobalt & gold) |
| Melee (`Unit_Kind.Melee`) | **Luk Soldier** | Enemy / Skirmish Spawn | 150 | 100 | 3.0 cells | 15 | 60 ticks (1.0 s) | Standard frontline foot soldier |

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

The native client builds every melee unit from code in `odin/client/art/`. There
is no GLB, no Blender step, and no external asset pipeline for units.

- `odin/client/art/mamluk_model.odin` + `mamluk_head.odin` assemble the 5.36-head
  heroic model (`Y = 0..1.945`) from parametric primitives (`prims.odin`, `loft.odin`:
  lathes, lofts, ellipsoids, tori, dome-star relief, swept blade, cloth sheets).
- 26-joint rig (`odin/client/art/rig.odin`): root, pelvis, spine, chest, neck,
  head, plume, shoulders/arms/hands, legs/feet, three cape joints, sash.
- Clips are analytic kinetic-chain functions, not keyframes (`odin/client/art/anim.odin`):
  `idle` 3.60 s polyrhythmic weight-shift loop, `walk` 0.40 s (~58/42 asymmetric
  stance/swing, Richard Williams Contact/Down/Passing/Up weight wave, lagged
  spine/shoulder/elbow/wrist whip), `attack` 0.50 s (`attack_pulse` with
  anticipation, staggered strike overshoot, follow-through, lunge footwork), and
  S-wave traveling cape/sash/plume secondary motion.
- Runtime motion in `odin/client/unit_visuals.odin` (`WARRIOR_SCALE = 0.74`,
  `STRIDE_DISTANCE = 1.85`) adds smooth Idle/Walk blending, coast-to-plant
  stops, damped stop-settle cushion, acceleration lean, inward corner banking,
  and head/chest look-ahead into turns.
- Skin is rigid per part and done on the CPU each frame; the mesh buffer is
  rewritten with skinned positions and normals.
- Attack triggers when the simulation attack cooldown resets, spawns a curved
  double-crescent `slash_vfx.odin` ribbon during `t ∈ [0.28, 0.68]`, and always
  eases cleanly back into the guard pose.
- Blue/red cloth and turban bands mark the team; the model is otherwise shared.
- Look: Toriyama / Dragon Quest proportions and palette with Age of Empires / Diablo 2
  framing. See `.agents/skills/art-direction/SKILL.md`.
- Reference renders: `./bin/dreamcraft-dev --sheet` writes 12 views to `build/sheet/*.png`
  (front, 3/4, side, back, walk, attack, head, helm, enemy, walk side contact & pass).

### Legacy Unit Asset

`legacy/warrior-glb/` holds the retired Blender pipeline and GLB exports for
reference only. The client no longer loads them.

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

- **Melee Combat**:
  - `CombatStats` (damage: 15, range: 3 cells, cooldown: 1s)
  - Direct `Attack(entity)` chases and attacks until destroyed or re-ordered
  - **`Attack_Move` (`A` / HUD Attack)**: advances toward destination while auto-acquiring nearest visible enemy within `VISION_RADIUS` (`6` cells, leash `8`), fights until clear, and resumes march to destination before settling to `Idle`
  - **`Patrol` (`P` / HUD Patrol)**: 1-click patrol from current position to clicked target (or explicit `A <-> B` via API), auto-acquiring enemies within `VISION_RADIUS` (`6` cells) without losing active patrol leg or state, and resuming `A <-> B` after combat
  - `Move` (Right-click ground / `M`) walks without stopping to engage enemies
  - Damage applies on cooldown ready; dead units despawn cleanly and clear stale target handles

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

The Odin port uses these current values (Campaign Tutorial Level 1):

| Stat | **Liiroy, the Bold** (`.Hero`) | **Luk Soldier** (`.Melee`) |
|------|--------------------------------|----------------------------|
| Move speed | `180` world units/s (`HERO_SPEED`, `5.625` cells/s) | `150` world units/s (`BASE_SPEED`, `4.6875` cells/s) |
| Max HP | `500` (`HERO_MAX_HP`) | `100` (`MAX_HP`) |
| Armor | `5` (`HERO_ARMOR`, min 1 dmg taken) | `0` (`BASE_ARMOR`) |
| Passive regen | `+2 HP` / `30` ticks (`+4 HP/s`) | `0` |
| Attack damage | `35` (`HERO_ATTACK_DAMAGE`) | `15` (`ATTACK_DAMAGE`) |
| Attack range | 3 cells (Euclidean) | 3 cells (Euclidean) |
| Attack cooldown | `40` ticks (`0.67 s`) | `60` ticks (`1.0 s`) |
| Vision radius | 6 cells | 6 cells |
| Render scale & ring | `HERO_SCALE = 0.84` + gold hero aura | `WARRIOR_SCALE = 0.74` |
| Unit capacity | 256 slots (SoA pool) | 256 slots (SoA pool) |
| Path capacity | 512 cells per unit | 512 cells per unit |

In Campaign Mode (`game_reset`), the player starts with **Liiroy, the Bold** (`Unit_Kind.Hero`) at `(2, 25)` and discovers two stranded squads of **Neutral** (`Team.Neutral`) allied **Luk Soldiers** (`ALLY_RESCUE_SPAWNS`: 3 near Waypoint 1 at `(19,23)`, `(19,27)`, `(21,25)` and 2 near Waypoint 3 at `(42,24)`, `(42,26)`). Approaching within `RESCUE_RADIUS` (`5` cells) rallies the whole squad (`RESCUE_CHAIN_RADIUS = 6`) to `Team.Player`, revealing fog around every allied unit and unlocking group tactics against three escalating enemy squads (`10` **Luk Soldiers** across groups of `2`, `3`, and `5`).

### Multi-Unit Formation & Combat Surrounding
- Group `Move`, `Attack_Move`, and `Patrol` orders fan selected units out into distinct walkable cells around the clicked target (`apply_formation_command`) instead of stacking them on one tile.
- Multi-unit melee combat (`find_surround_cell`) picks unreserved walkable cells within `ATTACK_RANGE` around the target so squads naturally surround enemies.

### Event-Based Discovery Aggro (Campaign Mode)
- Undiscovered enemy Luk Soldiers start unalerted (`discovered = false`, `aggro_timer = 0`).
- When any player unit enters an undiscovered enemy's 6-cell `VISION_RADIUS`, the enemy and nearby squadmates within `SQUAD_ALERT_RADIUS` (`4` cells) become `discovered = true`, receive a `240`-tick (`4.0 s`) `ENEMY_AGGRO_DELAY_TICKS` grace window, and set `game.discovery_announced = true`.
- During the grace window the enemy waits instead of chasing, displays a pulsing amber warning ring + `! SPOTTED Xs` countdown tag, and shows a flavored HUD announcement banner (*"The challenge horn(s) sound"*).
- Taking damage (`hp < hp_max`) clears `aggro_timer` immediately on the unit and squadmates within `SQUAD_ALERT_RADIUS` so the squad retaliates together; otherwise enemies charge when `aggro_timer` reaches `0` (setting `aggro_triggered_tick` for the brief banner).
- Unit references are generation handles (`{index, generation}`), not ECS entities.
