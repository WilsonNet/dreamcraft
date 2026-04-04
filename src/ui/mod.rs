//! RTS HUD and command UI systems

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
