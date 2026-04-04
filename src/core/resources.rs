//! Core game resources

use bevy::prelude::*;

/// Game state resource
#[derive(Resource, Default)]
pub struct GameState {
    pub selected_units: Vec<Entity>,
    pub level_complete: bool,
}

/// Grid configuration
#[derive(Resource)]
pub struct GridConfig {
    pub cell_size: f32,
    pub grid_width: usize,
    pub grid_height: usize,
    pub offset: Vec2,
}

impl Default for GridConfig {
    fn default() -> Self {
        Self {
            cell_size: 32.0,
            grid_width: 80,
            grid_height: 50,
            offset: Vec2::new(-1280.0, -800.0),
        }
    }
}

/// Obstacle grid (trees, buildings, etc.)
#[derive(Resource, Default, Clone)]
pub struct ObstacleGrid {
    pub cells: Vec<Vec<bool>>,
}

/// Visibility grid for fog of war
/// 0 = unexplored, 1 = explored, 2 = visible
#[derive(Resource, Clone)]
pub struct VisibilityGrid {
    pub cells: Vec<Vec<u8>>,
    pub view_radius: usize,
}

impl Default for VisibilityGrid {
    fn default() -> Self {
        Self {
            cells: Vec::new(),
            view_radius: 5,
        }
    }
}

/// Fog waypoints for tutorial
#[derive(Resource, Clone)]
pub struct FogWaypoints {
    pub waypoints: Vec<(usize, usize)>,
    pub current_target: usize,
}

impl Default for FogWaypoints {
    fn default() -> Self {
        Self {
            waypoints: vec![
                (10, 25),
                (20, 25),
                (30, 25),
                (40, 20),
                (50, 25),
                (60, 25),
                (70, 25),
                (77, 25),
            ],
            current_target: 0,
        }
    }
}

/// Minimap configuration
#[derive(Resource)]
pub struct MinimapConfig {
    pub width: f32,
    pub height: f32,
}

impl Default for MinimapConfig {
    fn default() -> Self {
        Self {
            width: 200.0,
            height: 125.0,
        }
    }
}
