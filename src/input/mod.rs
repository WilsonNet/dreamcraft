//! Input handling: mouse, keyboard, camera controls

use crate::core::*;
use crate::grid::world_to_grid;
use crate::pathfinding::find_path;
use crate::units::{Target, Unit};
use bevy::prelude::*;

/// Handle right-click movement commands
pub fn handle_input(
    mouse: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    camera: Single<(&Camera, &GlobalTransform)>,
    grid: Res<GridConfig>,
    obstacles: Res<ObstacleGrid>,
    mut query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
) {
    let (cam, cam_transform) = *camera;
    if let Some(cursor) = window.cursor_position() {
        if let Ok(world) = cam.viewport_to_world_2d(cam_transform, cursor) {
            let (gx, gy) = world_to_grid(world, &grid);
            if mouse.just_pressed(MouseButton::Right) {
                for (unit, mut target) in query.iter_mut() {
                    let path = find_path(
                        (unit.grid_x, unit.grid_y),
                        (gx, gy),
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
    }
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
