//! RTS HUD and command UI systems

use crate::core::*;
use crate::grid;
use bevy::prelude::*;
use bevy::window::{CursorIcon, SystemCursorIcon};

const HUD_HEIGHT: f32 = 170.0;
const BUTTON_WIDTH: f32 = 46.0;
const BUTTON_HEIGHT: f32 = 34.0;
const BUTTON_GAP: f32 = 8.0;
const BUTTON_RIGHT_MARGIN: f32 = 26.0;
const BUTTON_BOTTOM_MARGIN: f32 = 18.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Reflect)]
pub enum CommandMode {
    #[default]
    None,
    Move,
    Patrol,
}

#[derive(Resource, Default, Reflect)]
#[reflect(Resource)]
pub struct CommandUiState {
    pub mode: CommandMode,
    pub patrol_first_point: Option<(usize, usize)>,
    pub consume_next_left_click: bool,
}

#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MoveCommandButton;

#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct PatrolCommandButton;

pub fn spawn_rts_hud(mut commands: Commands, window: Single<Entity, With<Window>>) {
    commands
        .entity(*window)
        .insert(CursorIcon::from(SystemCursorIcon::Default));

    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px(0.0),
                right: Val::Px(0.0),
                bottom: Val::Px(0.0),
                height: Val::Px(HUD_HEIGHT),
                ..default()
            },
            BackgroundColor(Color::srgba(0.04, 0.05, 0.06, 0.92)),
            GlobalZIndex(5),
        ))
        .with_children(|parent| {
            parent
                .spawn((
                    Button,
                    Node {
                        position_type: PositionType::Absolute,
                        right: Val::Px(BUTTON_RIGHT_MARGIN),
                        bottom: Val::Px(BUTTON_BOTTOM_MARGIN),
                        width: Val::Px(BUTTON_WIDTH),
                        height: Val::Px(BUTTON_HEIGHT),
                        border: UiRect::all(Val::Px(2.0)),
                        justify_content: JustifyContent::Center,
                        align_items: AlignItems::Center,
                        ..default()
                    },
                    BorderColor::all(Color::srgb(0.8, 0.8, 0.25)),
                    BackgroundColor(Color::srgb(0.18, 0.18, 0.08)),
                    MoveCommandButton,
                ))
                .with_children(|button| {
                    button.spawn((
                        Text::new("Mo"),
                        TextFont {
                            font_size: 16.0,
                            ..default()
                        },
                        TextColor(Color::srgb(0.95, 0.95, 0.6)),
                    ));
                });

            parent
                .spawn((
                    Button,
                    Node {
                        position_type: PositionType::Absolute,
                        right: Val::Px(BUTTON_RIGHT_MARGIN),
                        bottom: Val::Px(BUTTON_BOTTOM_MARGIN + BUTTON_HEIGHT + BUTTON_GAP),
                        width: Val::Px(BUTTON_WIDTH),
                        height: Val::Px(BUTTON_HEIGHT),
                        border: UiRect::all(Val::Px(2.0)),
                        justify_content: JustifyContent::Center,
                        align_items: AlignItems::Center,
                        ..default()
                    },
                    BorderColor::all(Color::srgb(0.7, 0.8, 0.3)),
                    BackgroundColor(Color::srgb(0.12, 0.2, 0.12)),
                    PatrolCommandButton,
                ))
                .with_children(|button| {
                    button.spawn((
                        Text::new("Pt"),
                        TextFont {
                            font_size: 16.0,
                            ..default()
                        },
                        TextColor(Color::srgb(0.85, 1.0, 0.85)),
                    ));
                });
        });
}

pub fn handle_move_button_interaction(
    mouse: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    mut move_buttons: Query<
        &mut BackgroundColor,
        (With<MoveCommandButton>, Without<PatrolCommandButton>),
    >,
    mut patrol_buttons: Query<
        &mut BackgroundColor,
        (With<PatrolCommandButton>, Without<MoveCommandButton>),
    >,
    mut command_ui: ResMut<CommandUiState>,
    mut cursor_icon: Single<&mut CursorIcon, With<Window>>,
) {
    let Some(cursor) = window.cursor_position() else {
        return;
    };

    let over_move = is_over_button(
        cursor,
        window.width(),
        window.height(),
        BUTTON_BOTTOM_MARGIN,
    );
    let patrol_bottom = BUTTON_BOTTOM_MARGIN + BUTTON_HEIGHT + BUTTON_GAP;
    let over_patrol = is_over_button(cursor, window.width(), window.height(), patrol_bottom);

    if let Ok(mut bg) = move_buttons.single_mut() {
        *bg = if over_move {
            BackgroundColor(Color::srgb(0.24, 0.24, 0.1))
        } else {
            BackgroundColor(Color::srgb(0.18, 0.18, 0.08))
        };
    }

    if let Ok(mut bg) = patrol_buttons.single_mut() {
        *bg = if over_patrol {
            BackgroundColor(Color::srgb(0.18, 0.28, 0.18))
        } else {
            BackgroundColor(Color::srgb(0.12, 0.2, 0.12))
        };
    }

    if mouse.just_pressed(MouseButton::Left) && over_move {
        command_ui.mode = CommandMode::Move;
        command_ui.patrol_first_point = None;
        command_ui.consume_next_left_click = true;
        **cursor_icon = CursorIcon::from(SystemCursorIcon::Move);
    }

    if mouse.just_pressed(MouseButton::Left) && over_patrol {
        command_ui.mode = CommandMode::Patrol;
        command_ui.patrol_first_point = None;
        command_ui.consume_next_left_click = true;
        **cursor_icon = CursorIcon::from(SystemCursorIcon::Crosshair);
    }
}

fn is_over_button(cursor: Vec2, window_width: f32, window_height: f32, bottom_margin: f32) -> bool {
    let x_max = window_width - BUTTON_RIGHT_MARGIN;
    let x_min = x_max - BUTTON_WIDTH;
    let y_max = window_height - bottom_margin;
    let y_min = y_max - BUTTON_HEIGHT;
    cursor.x >= x_min && cursor.x <= x_max && cursor.y >= y_min && cursor.y <= y_max
}

// ── Escape Menu ──────────────────────────────────────────────────────────────

#[derive(Resource, Default)]
pub struct PauseMenu {
    pub open: bool,
    pub retry_requested: bool,
}

#[derive(Component)]
pub struct EscapeMenuRoot;

#[derive(Component)]
pub struct RetryButton;

#[derive(Component)]
pub struct ResumeButton;

pub fn spawn_escape_menu(mut commands: Commands) {
    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px(0.0),
                right: Val::Px(0.0),
                top: Val::Px(0.0),
                bottom: Val::Px(0.0),
                flex_direction: FlexDirection::Column,
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                ..default()
            },
            BackgroundColor(Color::srgba(0.0, 0.0, 0.0, 0.65)),
            Visibility::Hidden,
            GlobalZIndex(10),
            EscapeMenuRoot,
        ))
        .with_children(|parent| {
            parent
                .spawn((
                    Node {
                        width: Val::Px(280.0),
                        padding: UiRect::all(Val::Px(24.0)),
                        flex_direction: FlexDirection::Column,
                        row_gap: Val::Px(14.0),
                        align_items: AlignItems::Center,
                        border: UiRect::all(Val::Px(1.0)),
                        ..default()
                    },
                    BackgroundColor(Color::srgb(0.08, 0.1, 0.12)),
                    BorderColor::all(Color::srgb(0.35, 0.35, 0.4)),
                ))
                .with_children(|panel| {
                    panel.spawn((
                        Text::new("Paused"),
                        TextFont {
                            font_size: 28.0,
                            ..default()
                        },
                        TextColor(Color::srgb(0.9, 0.9, 0.95)),
                    ));

                    panel
                        .spawn((
                            Button,
                            Node {
                                width: Val::Px(200.0),
                                height: Val::Px(42.0),
                                justify_content: JustifyContent::Center,
                                align_items: AlignItems::Center,
                                ..default()
                            },
                            BackgroundColor(Color::srgb(0.18, 0.25, 0.18)),
                            RetryButton,
                        ))
                        .with_children(|b| {
                            b.spawn((
                                Text::new("Retry Level"),
                                TextFont {
                                    font_size: 18.0,
                                    ..default()
                                },
                                TextColor(Color::srgb(0.7, 1.0, 0.7)),
                            ));
                        });

                    panel
                        .spawn((
                            Button,
                            Node {
                                width: Val::Px(200.0),
                                height: Val::Px(42.0),
                                justify_content: JustifyContent::Center,
                                align_items: AlignItems::Center,
                                ..default()
                            },
                            BackgroundColor(Color::srgb(0.22, 0.22, 0.28)),
                            ResumeButton,
                        ))
                        .with_children(|b| {
                            b.spawn((
                                Text::new("Resume"),
                                TextFont {
                                    font_size: 18.0,
                                    ..default()
                                },
                                TextColor(Color::srgb(0.9, 0.9, 1.0)),
                            ));
                        });
                });
        });
}

pub fn toggle_escape_menu(
    keys: Res<ButtonInput<KeyCode>>,
    mut pause_menu: ResMut<PauseMenu>,
    mut menu_query: Query<&mut Visibility, With<EscapeMenuRoot>>,
) {
    if !keys.just_pressed(KeyCode::Escape) {
        return;
    }
    pause_menu.open = !pause_menu.open;
    if let Ok(mut vis) = menu_query.single_mut() {
        *vis = if pause_menu.open {
            Visibility::Inherited
        } else {
            Visibility::Hidden
        };
    }
}

pub fn handle_escape_menu_buttons(
    mut pause_menu: ResMut<PauseMenu>,
    retry_query: Query<&Interaction, (With<RetryButton>, Changed<Interaction>)>,
    resume_query: Query<&Interaction, (With<ResumeButton>, Changed<Interaction>)>,
    mut menu_query: Query<&mut Visibility, With<EscapeMenuRoot>>,
) {
    for interaction in retry_query.iter() {
        if *interaction == Interaction::Pressed {
            pause_menu.retry_requested = true;
            if let Ok(mut vis) = menu_query.single_mut() {
                *vis = Visibility::Hidden;
            }
            pause_menu.open = false;
        }
    }
    for interaction in resume_query.iter() {
        if *interaction == Interaction::Pressed {
            if let Ok(mut vis) = menu_query.single_mut() {
                *vis = Visibility::Hidden;
            }
            pause_menu.open = false;
        }
    }
}

pub fn execute_retry(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut obstacle_grid: ResMut<ObstacleGrid>,
    mut visibility_grid: ResMut<VisibilityGrid>,
    mut fog_waypoints: ResMut<FogWaypoints>,
    mut game_state: ResMut<GameState>,
    grid: Res<GridConfig>,
    #[cfg(not(target_arch = "wasm32"))] minimap_config: Res<MinimapConfig>,
    mut pause_menu: ResMut<PauseMenu>,
    mut unit_query: Query<Entity, Or<(With<PlayerUnit>, With<EnemyUnit>)>>,
    mut fog_query: Query<Entity, With<FogCell>>,
    mut tree_query: Query<Entity, With<Tree>>,
    mut waypoint_query: Query<Entity, With<WaypointMarker>>,
    mut goal_query: Query<Entity, With<GoalZone>>,
) {
    if !pause_menu.retry_requested {
        return;
    }
    pause_menu.retry_requested = false;

    grid::cleanup_level(
        &mut commands,
        &mut unit_query,
        &mut fog_query,
        &mut tree_query,
        &mut waypoint_query,
        &mut goal_query,
    );
    grid::respawn_level(
        &mut commands,
        &mut meshes,
        &mut materials,
        &mut obstacle_grid,
        &mut visibility_grid,
        &mut fog_waypoints,
        &grid,
        #[cfg(not(target_arch = "wasm32"))]
        &minimap_config,
    );
    game_state.level_complete = false;
}
