//! Core game components

use bevy::prelude::*;
use serde::{Deserialize, Serialize};

/// Team/Faction component - determines which side a unit belongs to
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Default, Reflect, Serialize, Deserialize, Component,
)]
#[reflect(Component, Serialize, Deserialize)]
pub enum Team {
    #[default]
    Player,
    Enemy,
}

/// Marker for player-controlled units (same as Team::Player)
#[derive(Component)]
pub struct PlayerUnit;

/// Marker for enemy units (same as Team::Enemy)
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

/// Interactive minimap area marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapClickArea;

/// Player marker on minimap
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct PlayerMinimapMarker;

/// Camera viewport marker on minimap
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapCameraViewport;

/// Minimap entity marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapEntity;

/// Minimap camera marker
#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MinimapCamera;
