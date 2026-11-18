//! Core plugin registration

use crate::combat;
use crate::combat::{AttackTarget, CombatStats};
use crate::core::{ObstacleGrid, VisibilityGrid};
use crate::grid::{self};
use crate::input;
use crate::minimap;
use crate::ui::{self, PauseMenu};
use crate::units::{self, Health, PatrolRoute, Target, Unit, UnitStateMachine};
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
            .init_resource::<PauseMenu>()
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
            .register_type::<PatrolRoute>()
            .register_type::<UnitStateMachine>()
            .register_type::<CombatStats>()
            .register_type::<AttackTarget>()
            .register_type::<ui::MoveCommandButton>()
            .register_type::<ui::PatrolCommandButton>()
            .insert_resource(ClearColor(Color::srgb(0.02, 0.04, 0.02)))
            .add_systems(
                Startup,
                (
                    grid::setup_tutorial_level,
                    ui::spawn_rts_hud,
                    ui::spawn_escape_menu,
                ),
            )
            .add_systems(
                Update,
                (
                    ui::handle_move_button_interaction,
                    input::handle_input,
                    units::enemy_ai_chase,
                    units::patrol_loop,
                    units::unit_movement,
                    input::camera_controls,
                    input::screen_edge_scroll,
                    units::check_goal,
                    units::draw_path,
                ),
            )
            .add_systems(
                Update,
                (
                    units::spawn_health_bars,
                    combat::attack_movement,
                    combat::combat_tick,
                    combat::death_check,
                    units::update_health_bars,
                    grid::update_visibility,
                    grid::update_fog,
                    units::update_enemy_visibility,
                    units::draw_waypoints,
                    units::check_waypoint_reached,
                    units::debug_console_output,
                ),
            )
            .add_systems(
                Update,
                (
                    #[cfg(target_arch = "wasm32")]
                    units::read_console_commands,
                    #[cfg(not(target_arch = "wasm32"))]
                    units::read_stdin_commands,
                    ui::toggle_escape_menu,
                    ui::handle_escape_menu_buttons,
                    ui::execute_retry,
                    #[cfg(not(target_arch = "wasm32"))]
                    minimap::handle_minimap_click,
                    #[cfg(target_arch = "wasm32")]
                    units::broadcast_minimap_data,
                    #[cfg(not(target_arch = "wasm32"))]
                    (
                        minimap::update_native_minimap,
                        minimap::update_minimap_visibility,
                        minimap::update_camera_viewport_on_minimap,
                    ),
                ),
            );
    }
}
