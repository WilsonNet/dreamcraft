//! Core plugin registration

use crate::core::{ObstacleGrid, VisibilityGrid};
use crate::grid::{self};
use crate::input;
use crate::minimap;
use crate::ui;
use crate::units::{self, Health, Target, Unit, UnitStateMachine};
use bevy::prelude::*;

use super::{
    FogWaypoints, GameState, GridConfig, MinimapBackground, MinimapCameraViewport,
    MinimapClickArea, MinimapConfig, MinimapEntity, MinimapSprite, PlayerMinimapMarker, Race, Team,
};

pub struct DreamCraftPlugin;

impl Plugin for DreamCraftPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<GameState>()
            .init_resource::<GridConfig>()
            .init_resource::<ObstacleGrid>()
            .init_resource::<VisibilityGrid>()
            .init_resource::<FogWaypoints>()
            .init_resource::<MinimapConfig>()
            .init_resource::<ui::CommandUiState>()
            .register_type::<MinimapEntity>()
            .register_type::<MinimapSprite>()
            .register_type::<MinimapBackground>()
            .register_type::<MinimapClickArea>()
            .register_type::<PlayerMinimapMarker>()
            .register_type::<MinimapCameraViewport>()
            .register_type::<Team>()
            .register_type::<Race>()
            .register_type::<Unit>()
            .register_type::<Target>()
            .register_type::<Health>()
            .register_type::<UnitStateMachine>()
            .register_type::<ui::CommandUiState>()
            .register_type::<ui::MoveCommandButton>()
            .insert_resource(ClearColor(Color::srgb(0.02, 0.04, 0.02)))
            .add_systems(Startup, (grid::setup_tutorial_level, ui::spawn_rts_hud))
            .add_systems(
                Update,
                (
                    ui::handle_move_button_interaction,
                    input::handle_input,
                    #[cfg(target_arch = "wasm32")]
                    units::read_console_commands,
                    #[cfg(not(target_arch = "wasm32"))]
                    units::read_stdin_commands,
                    units::enemy_ai_chase,
                    units::unit_movement,
                    input::camera_controls,
                    #[cfg(not(target_arch = "wasm32"))]
                    minimap::handle_minimap_click,
                    units::check_goal,
                    units::draw_path,
                    grid::update_visibility,
                    grid::update_fog,
                    units::update_enemy_visibility,
                    units::spawn_health_bars,
                    units::draw_waypoints,
                    units::check_waypoint_reached,
                    #[cfg(target_arch = "wasm32")]
                    units::broadcast_minimap_data,
                    #[cfg(not(target_arch = "wasm32"))]
                    (
                        minimap::update_native_minimap,
                        minimap::update_minimap_visibility,
                        minimap::update_camera_viewport_on_minimap,
                    ),
                    units::debug_console_output,
                ),
            );
    }
}
