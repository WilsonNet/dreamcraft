//! Combat system: attacking, damage, death

use crate::core::{GridConfig, ObstacleGrid};
use crate::pathfinding::find_path;
use crate::units::{Health, Target, Unit};
use bevy::prelude::*;

/// Combat stats for a unit
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct CombatStats {
    pub damage: u32,
    pub attack_range: f32,
    pub cooldown_timer: f32,
}

impl Default for CombatStats {
    fn default() -> Self {
        Self {
            damage: 15,
            attack_range: 3.0,
            cooldown_timer: 0.0,
        }
    }
}

impl CombatStats {
    pub fn melee() -> Self {
        Self::default()
    }
}

/// Attack target for a unit (who to attack)
#[derive(Component, Default, Reflect)]
#[reflect(Component)]
pub struct AttackTarget(pub Option<Entity>);

/// Move toward attack target when out of range, stop when in range
pub fn attack_movement(
    mut attackers: Query<(&Unit, &mut Target, &mut AttackTarget, &CombatStats)>,
    targets: Query<&Unit>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
) {
    for (unit, mut target, mut attack_target, stats) in attackers.iter_mut() {
        let Some(target_entity) = attack_target.0 else {
            continue;
        };
        let Ok(target_unit) = targets.get(target_entity) else {
            attack_target.0 = None;
            continue;
        };

        let dx = (unit.grid_x as i32 - target_unit.grid_x as i32).abs() as f32;
        let dy = (unit.grid_y as i32 - target_unit.grid_y as i32).abs() as f32;
        let dist = (dx * dx + dy * dy).sqrt();

        if dist <= stats.attack_range {
            target.path.clear();
            target.path_index = 0;
            continue;
        }

        let dest = (target_unit.grid_x, target_unit.grid_y);
        let needs_repath = target.path.is_empty()
            || target.path_index >= target.path.len()
            || target.path.last().copied() != Some(dest);

        if needs_repath {
            let path = find_path(
                (unit.grid_x, unit.grid_y),
                dest,
                &obstacles.cells,
                grid.grid_width,
                grid.grid_height,
            );
            if !path.is_empty() {
                target.path = path;
                target.path_index = 0;
            }
        }
    }
}

/// Apply damage when in attack range and cooldown is ready
pub fn combat_tick(
    mut attackers: Query<(&mut CombatStats, &Unit, &AttackTarget)>,
    mut targets: Query<&mut Health>,
    time: Res<Time>,
) {
    for (mut stats, _unit, attack_target) in attackers.iter_mut() {
        stats.cooldown_timer -= time.delta_secs();
        if stats.cooldown_timer > 0.0 {
            continue;
        }

        let Some(target_entity) = attack_target.0 else {
            continue;
        };

        let Ok(mut target_health) = targets.get_mut(target_entity) else {
            continue;
        };

        if target_health.current == 0 {
            continue;
        }

        target_health.current = target_health.current.saturating_sub(stats.damage);
        stats.cooldown_timer = 1.0;
    }
}

/// Despawn dead entities
pub fn death_check(mut commands: Commands, units: Query<(Entity, &Health)>) {
    for (entity, health) in units.iter() {
        if health.current == 0 {
            commands.entity(entity).despawn();
        }
    }
}
