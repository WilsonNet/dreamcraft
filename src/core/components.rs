//! Core game components

use bevy::prelude::*;

/// Marker for player-controlled units
#[derive(Component)]
pub struct PlayerUnit;

/// Marker for enemy units
#[derive(Component)]
pub struct EnemyUnit;

/// Marker for selected units
#[derive(Component)]
pub struct Selected;

/// Marker for tree obstacles
#[derive(Component)]
pub struct Tree;

/// Marker for goal zone
#[derive(Component)]
pub struct GoalZone;

/// Marker for fog of war cells
#[derive(Component)]
pub struct FogCell;

/// Waypoint marker component
#[derive(Component)]
pub struct WaypointMarker {
    pub index: usize,
    pub reached: bool,
}

/// Minimap sprite marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapSprite;

/// Minimap background marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapBackground;

/// Player marker on minimap
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct PlayerMinimapMarker;

/// Minimap entity marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapEntity;

/// Minimap camera marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapCamera;
