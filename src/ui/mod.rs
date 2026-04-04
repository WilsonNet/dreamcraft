//! RTS HUD and command UI systems

use bevy::prelude::*;
use bevy::window::{CursorIcon, SystemCursorIcon};

const HUD_HEIGHT: f32 = 170.0;
const BUTTON_WIDTH: f32 = 46.0;
const BUTTON_HEIGHT: f32 = 34.0;
const BUTTON_RIGHT_MARGIN: f32 = 26.0;
const BUTTON_BOTTOM_MARGIN: f32 = 18.0;

#[derive(Resource, Default, Reflect)]
#[reflect(Resource)]
pub struct CommandUiState {
    pub move_mode: bool,
    pub consume_next_left_click: bool,
}

#[derive(Component, Reflect)]
#[reflect(Component)]
pub struct MoveCommandButton;

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
        });
}

pub fn handle_move_button_interaction(
    mouse: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    mut buttons: Query<&mut BackgroundColor, With<MoveCommandButton>>,
    mut command_ui: ResMut<CommandUiState>,
    mut cursor_icon: Single<&mut CursorIcon, With<Window>>,
) {
    let Some(cursor) = window.cursor_position() else {
        return;
    };

    let x_max = window.width() - BUTTON_RIGHT_MARGIN;
    let x_min = x_max - BUTTON_WIDTH;
    let y_max = window.height() - BUTTON_BOTTOM_MARGIN;
    let y_min = y_max - BUTTON_HEIGHT;
    let over_button =
        cursor.x >= x_min && cursor.x <= x_max && cursor.y >= y_min && cursor.y <= y_max;

    if let Ok(mut bg) = buttons.single_mut() {
        *bg = if over_button {
            BackgroundColor(Color::srgb(0.24, 0.24, 0.1))
        } else {
            BackgroundColor(Color::srgb(0.18, 0.18, 0.08))
        };
    }

    if mouse.just_pressed(MouseButton::Left) && over_button {
        command_ui.move_mode = true;
        command_ui.consume_next_left_click = true;
        **cursor_icon = CursorIcon::from(SystemCursorIcon::Move);
    }
}
