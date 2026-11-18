//! Input handling: mouse, keyboard, camera controls

use crate::combat::AttackTarget;
use crate::core::*;
use crate::grid::world_to_grid;
use crate::pathfinding::find_path;
use crate::units::{PatrolRoute, Target, Unit, UnitState};
use bevy::prelude::*;
use bevy::window::{CursorIcon, SystemCursorIcon};

/// Handle right-click movement commands and attack targeting
pub fn handle_input(
    mouse: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    camera: Single<(&Camera, &GlobalTransform)>,
    grid: Res<GridConfig>,
    obstacles: Res<ObstacleGrid>,
    mut params: ParamSet<(
        Query<(Entity, &Unit), With<EnemyUnit>>,
        Query<
            (
                &mut Unit,
                &mut Target,
                &mut crate::units::UnitStateMachine,
                &mut PatrolRoute,
                &mut AttackTarget,
            ),
            With<PlayerUnit>,
        >,
    )>,
    mut command_ui: ResMut<crate::ui::CommandUiState>,
    mut cursor_icon: Single<&mut CursorIcon, With<Window>>,
) {
    if mouse.just_pressed(MouseButton::Left) && command_ui.consume_next_left_click {
        command_ui.consume_next_left_click = false;
        return;
    }

    let command_click =
        command_ui.mode == crate::ui::CommandMode::Move && mouse.just_pressed(MouseButton::Left);
    let patrol_click =
        command_ui.mode == crate::ui::CommandMode::Patrol && mouse.just_pressed(MouseButton::Left);
    let quick_move = mouse.just_pressed(MouseButton::Right);
    if !command_click && !patrol_click && !quick_move {
        return;
    }

    let (cam, cam_transform) = *camera;
    if let Some(cursor) = window.cursor_position() {
        if let Ok(world) = cam.viewport_to_world_2d(cam_transform, cursor) {
            let (gx, gy) = world_to_grid(world, &grid);

            if quick_move {
                let enemy_hit = params
                    .p0()
                    .iter()
                    .find(|(_, eu)| eu.grid_x == gx && eu.grid_y == gy)
                    .map(|(e, _)| e);

                if let Some(enemy_entity) = enemy_hit {
                    for (_, _, _, _, mut attack_target) in params.p1().iter_mut() {
                        attack_target.0 = Some(enemy_entity);
                    }
                } else {
                    issue_move_order(
                        &mut params.p1(),
                        (gx, gy),
                        &obstacles,
                        &grid,
                        true,
                    );
                }
                reset_command_mode(&mut command_ui, &mut cursor_icon);
                return;
            }

            if command_click {
                issue_move_order(&mut params.p1(), (gx, gy), &obstacles, &grid, true);
                reset_command_mode(&mut command_ui, &mut cursor_icon);
                return;
            }

            if patrol_click {
                if let Some(first) = command_ui.patrol_first_point {
                    issue_patrol_order(&mut params.p1(), first, (gx, gy), &obstacles, &grid);
                    reset_command_mode(&mut command_ui, &mut cursor_icon);
                } else {
                    command_ui.patrol_first_point = Some((gx, gy));
                    command_ui.consume_next_left_click = false;
                }
            }
        }
    }
}

fn issue_move_order(
    query: &mut Query<
        (
            &mut Unit,
            &mut Target,
            &mut crate::units::UnitStateMachine,
            &mut PatrolRoute,
            &mut AttackTarget,
        ),
        With<PlayerUnit>,
    >,
    destination: (usize, usize),
    obstacles: &ObstacleGrid,
    grid: &GridConfig,
    break_patrol: bool,
) {
    for (unit, mut target, mut state_machine, mut patrol, mut attack_target) in query.iter_mut() {
        attack_target.0 = None;
        if break_patrol {
            patrol.active = false;
        }

        let path = find_path(
            (unit.grid_x, unit.grid_y),
            destination,
            &obstacles.cells,
            grid.grid_width,
            grid.grid_height,
        );
        if path.is_empty() {
            continue;
        }
        target.path = path;
        target.path_index = 0;
        state_machine.state = UnitState::Moving;
    }
}

fn issue_patrol_order(
    query: &mut Query<
        (
            &mut Unit,
            &mut Target,
            &mut crate::units::UnitStateMachine,
            &mut PatrolRoute,
            &mut AttackTarget,
        ),
        With<PlayerUnit>,
    >,
    point_a: (usize, usize),
    point_b: (usize, usize),
    obstacles: &ObstacleGrid,
    grid: &GridConfig,
) {
    for (unit, mut target, mut state_machine, mut patrol, mut attack_target) in query.iter_mut() {
        attack_target.0 = None;
        patrol.active = true;
        patrol.point_a = point_a;
        patrol.point_b = point_b;
        patrol.go_to_b_next = true;

        let path = find_path(
            (unit.grid_x, unit.grid_y),
            point_a,
            &obstacles.cells,
            grid.grid_width,
            grid.grid_height,
        );
        if path.is_empty() {
            continue;
        }
        target.path = path;
        target.path_index = 0;
        state_machine.state = UnitState::Patrol;
    }
}

fn reset_command_mode(
    command_ui: &mut crate::ui::CommandUiState,
    cursor_icon: &mut Single<&mut CursorIcon, With<Window>>,
) {
    command_ui.mode = crate::ui::CommandMode::None;
    command_ui.patrol_first_point = None;
    command_ui.consume_next_left_click = false;
    ***cursor_icon = CursorIcon::from(SystemCursorIcon::Default);
}

/// Camera pan controls (WASD/Arrow keys)
pub fn camera_controls(
    keys: Res<ButtonInput<KeyCode>>,
    mut query: Query<&mut Transform, (With<Camera2d>, Without<MinimapCamera>)>,
    time: Res<Time>,
    grid: Res<GridConfig>,
) {
    if let Ok(mut t) = query.single_mut() {
        let speed = 400.0;
        let mut vel = Vec3::ZERO;
        if keys.pressed(KeyCode::KeyW) || keys.pressed(KeyCode::ArrowUp) {
            vel.y += speed;
        }
        if keys.pressed(KeyCode::KeyS) || keys.pressed(KeyCode::ArrowDown) {
            vel.y -= speed;
        }
        if keys.pressed(KeyCode::KeyA) || keys.pressed(KeyCode::ArrowLeft) {
            vel.x -= speed;
        }
        if keys.pressed(KeyCode::KeyD) || keys.pressed(KeyCode::ArrowRight) {
            vel.x += speed;
        }
        t.translation += vel * time.delta_secs();

        let hw = grid.cell_size * grid.grid_width as f32 / 2.0 + 200.0;
        let hh = grid.cell_size * grid.grid_height as f32 / 2.0 + 200.0;
        t.translation.x = t.translation.x.clamp(-hw, hw);
        t.translation.y = t.translation.y.clamp(-hh, hh);
    }
}

/// Progressive screen edge scrolling (RTS standard)
/// Scroll speed increases the closer the cursor is to the screen edge
pub fn screen_edge_scroll(
    window: Single<&Window>,
    mut query: Query<&mut Transform, (With<Camera2d>, Without<MinimapCamera>)>,
    time: Res<Time>,
    grid: Res<GridConfig>,
) {
    const SCROLL_ZONE: f32 = 20.0;
    const BASE_SPEED: f32 = 200.0;
    const MAX_SPEED: f32 = 600.0;

    if let Ok(mut t) = query.single_mut() {
        if let Some(cursor) = window.cursor_position() {
            let size = window.size();
            let mut vel = Vec3::ZERO;

            if cursor.x < SCROLL_ZONE {
                let factor = 1.0 - (cursor.x / SCROLL_ZONE);
                vel.x -= BASE_SPEED + (MAX_SPEED - BASE_SPEED) * factor;
            } else if cursor.x > size.x - SCROLL_ZONE {
                let factor = 1.0 - ((size.x - cursor.x) / SCROLL_ZONE);
                vel.x += BASE_SPEED + (MAX_SPEED - BASE_SPEED) * factor;
            }

            if cursor.y < SCROLL_ZONE {
                let factor = 1.0 - (cursor.y / SCROLL_ZONE);
                vel.y += BASE_SPEED + (MAX_SPEED - BASE_SPEED) * factor;
            } else if cursor.y > size.y - SCROLL_ZONE {
                let factor = 1.0 - ((size.y - cursor.y) / SCROLL_ZONE);
                vel.y -= BASE_SPEED + (MAX_SPEED - BASE_SPEED) * factor;
            }

            t.translation += vel * time.delta_secs();

            let hw = grid.cell_size * grid.grid_width as f32 / 2.0 + 200.0;
            let hh = grid.cell_size * grid.grid_height as f32 / 2.0 + 200.0;
            t.translation.x = t.translation.x.clamp(-hw, hw);
            t.translation.y = t.translation.y.clamp(-hh, hh);
        }
    }
}
