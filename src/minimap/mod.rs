//! Minimap rendering and updates

use crate::core::*;
use crate::units::Unit;
use bevy::prelude::*;
use bevy::ui::{FocusPolicy, RelativeCursorPosition};

/// Spawn the minimap UI (fixed screen position, CSS-like)
pub fn spawn_minimap(
    commands: &mut Commands,
    obstacles: &ObstacleGrid,
    visibility: &VisibilityGrid,
    waypoints: &FogWaypoints,
    grid: &GridConfig,
    cfg: &MinimapConfig,
) {
    let cell_w = cfg.width / grid.grid_width as f32;
    let cell_h = cfg.height / grid.grid_height as f32;

    // 1. Container (The Border)
    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px(16.0),   // 20 - 4 for border
                bottom: Val::Px(26.0), // 30 - 4 for border
                width: Val::Px(cfg.width + 8.0),
                height: Val::Px(cfg.height + 8.0),
                ..default()
            },
            BackgroundColor(Color::srgb(0.3, 0.5, 0.3)), // Green border
            MinimapEntity,
            MinimapBackground,
        ))
        .with_children(|parent| {
            // 2. Inner background (The dark area)
            parent
                .spawn((
                    Node {
                        position_type: PositionType::Absolute,
                        left: Val::Px(4.0),
                        bottom: Val::Px(4.0),
                        width: Val::Px(cfg.width),
                        height: Val::Px(cfg.height),
                        ..default()
                    },
                    BackgroundColor(Color::srgba(0.1, 0.1, 0.1, 1.0)),
                    Interaction::None,
                    RelativeCursorPosition::default(),
                    FocusPolicy::Block,
                    MinimapEntity,
                    MinimapClickArea,
                ))
                .with_children(|bg| {
                    // 3. Cells
                    for gx in 0..grid.grid_width {
                        for gy in 0..grid.grid_height {
                            let color = if obstacles.cells[gx][gy] {
                                Color::srgba(0.2, 0.6, 0.2, 1.0)
                            } else {
                                match visibility.cells[gx][gy] {
                                    0 => Color::srgba(0.02, 0.03, 0.02, 1.0),
                                    1 => Color::srgba(0.1, 0.15, 0.1, 1.0),
                                    _ => Color::srgba(0.25, 0.4, 0.25, 1.0),
                                }
                            };

                            bg.spawn((
                                Node {
                                    position_type: PositionType::Absolute,
                                    left: Val::Px(gx as f32 * cell_w),
                                    bottom: Val::Px(gy as f32 * cell_h),
                                    width: Val::Px(cell_w + 0.1), // Slight overlap to prevent gaps
                                    height: Val::Px(cell_h + 0.1),
                                    ..default()
                                },
                                BackgroundColor(color),
                                MinimapEntity,
                                MinimapSprite,
                            ));
                        }
                    }

                    // Waypoints (Remove MinimapSprite so visibility update doesn't overwrite color)
                    for (i, &(wx, wy)) in waypoints.waypoints.iter().enumerate() {
                        if i > 0 {
                            let color = if i == waypoints.current_target {
                                Color::srgba(1.0, 0.9, 0.2, 1.0)
                            } else {
                                Color::srgba(0.8, 0.7, 0.1, 0.7)
                            };
                            bg.spawn((
                                Node {
                                    position_type: PositionType::Absolute,
                                    left: Val::Px(wx as f32 * cell_w - 2.0),
                                    bottom: Val::Px(wy as f32 * cell_h - 2.0),
                                    width: Val::Px(4.0),
                                    height: Val::Px(4.0),
                                    ..default()
                                },
                                BackgroundColor(color),
                                MinimapEntity,
                                // MinimapSprite removed
                            ));
                        }
                    }

                    // Goal (Remove MinimapSprite)
                    bg.spawn((
                        Node {
                            position_type: PositionType::Absolute,
                            left: Val::Px((grid.grid_width - 2) as f32 * cell_w - 3.0),
                            bottom: Val::Px((grid.grid_height / 2) as f32 * cell_h - 3.0),
                            width: Val::Px(6.0),
                            height: Val::Px(6.0),
                            ..default()
                        },
                        BackgroundColor(Color::srgba(0.9, 0.8, 0.2, 1.0)),
                        MinimapEntity,
                        // MinimapSprite removed
                    ));

                    // Player marker
                    bg.spawn((
                        Node {
                            position_type: PositionType::Absolute,
                            left: Val::Px(2.0 * cell_w - 4.0),
                            bottom: Val::Px((grid.grid_height / 2) as f32 * cell_h - 4.0),
                            width: Val::Px(8.0),
                            height: Val::Px(8.0),
                            ..default()
                        },
                        BackgroundColor(Color::srgb(0.3, 0.6, 0.9)),
                        MinimapEntity,
                        PlayerMinimapMarker,
                    ));

                    // Camera viewport indicator
                    bg.spawn((
                        Node {
                            position_type: PositionType::Absolute,
                            left: Val::Px(0.0),
                            bottom: Val::Px(0.0),
                            width: Val::Px(12.0),
                            height: Val::Px(12.0),
                            border: UiRect::all(Val::Px(1.0)),
                            ..default()
                        },
                        BorderColor::all(Color::srgba(0.8, 0.9, 1.0, 0.95)),
                        BackgroundColor(Color::srgba(0.6, 0.8, 1.0, 0.12)),
                        MinimapEntity,
                        MinimapCameraViewport,
                    ));
                });
        });
}

/// Center camera on minimap click location
pub fn handle_minimap_click(
    mouse: Res<ButtonInput<MouseButton>>,
    click_area: Query<&RelativeCursorPosition, With<MinimapClickArea>>,
    mut camera_query: Query<&mut Transform, (With<Camera2d>, Without<MinimapCamera>)>,
    grid: Res<GridConfig>,
) {
    if !mouse.just_pressed(MouseButton::Left) {
        return;
    }
    let Ok(cursor) = click_area.single() else {
        return;
    };
    if !cursor.cursor_over {
        return;
    }
    let Some(normalized) = cursor.normalized else {
        return;
    };

    let x = (normalized.x + 0.5).clamp(0.0, 1.0);
    let y = (normalized.y + 0.5).clamp(0.0, 1.0);
    let gx = (x * (grid.grid_width.saturating_sub(1)) as f32).round() as usize;
    let gy = ((1.0 - y) * (grid.grid_height.saturating_sub(1)) as f32).round() as usize;
    let world = crate::grid::grid_to_world(gx, gy, &grid);

    if let Ok(mut camera) = camera_query.single_mut() {
        camera.translation.x = world.x;
        camera.translation.y = world.y;

        let hw = grid.cell_size * grid.grid_width as f32 / 2.0 + 200.0;
        let hh = grid.cell_size * grid.grid_height as f32 / 2.0 + 200.0;
        camera.translation.x = camera.translation.x.clamp(-hw, hw);
        camera.translation.y = camera.translation.y.clamp(-hh, hh);
    }
}

/// Update minimap camera viewport box from current window/camera view
pub fn update_camera_viewport_on_minimap(
    window: Single<&Window>,
    camera_query: Query<(&Camera, &GlobalTransform), (With<Camera2d>, Without<MinimapCamera>)>,
    mut viewport_query: Query<&mut Node, With<MinimapCameraViewport>>,
    grid: Res<GridConfig>,
    cfg: Res<MinimapConfig>,
) {
    let Ok((camera, transform)) = camera_query.single() else {
        return;
    };
    let Ok(mut viewport) = viewport_query.single_mut() else {
        return;
    };
    let Some((min, max)) = camera_world_bounds(camera, transform, *window) else {
        return;
    };

    let min_px = world_to_minimap(min, &grid, &cfg);
    let max_px = world_to_minimap(max, &grid, &cfg);
    let left = min_px.x.min(max_px.x).clamp(0.0, cfg.width);
    let right = min_px.x.max(max_px.x).clamp(0.0, cfg.width);
    let bottom = min_px.y.min(max_px.y).clamp(0.0, cfg.height);
    let top = min_px.y.max(max_px.y).clamp(0.0, cfg.height);

    viewport.left = Val::Px(left);
    viewport.bottom = Val::Px(bottom);
    viewport.width = Val::Px((right - left).max(2.0));
    viewport.height = Val::Px((top - bottom).max(2.0));
}

fn camera_world_bounds(
    camera: &Camera,
    transform: &GlobalTransform,
    window: &Window,
) -> Option<(Vec2, Vec2)> {
    let size = window.size();
    let p0 = camera
        .viewport_to_world_2d(transform, Vec2::new(0.0, 0.0))
        .ok()?;
    let p1 = camera
        .viewport_to_world_2d(transform, Vec2::new(size.x, 0.0))
        .ok()?;
    let p2 = camera
        .viewport_to_world_2d(transform, Vec2::new(0.0, size.y))
        .ok()?;
    let p3 = camera
        .viewport_to_world_2d(transform, Vec2::new(size.x, size.y))
        .ok()?;
    let min = Vec2::new(
        p0.x.min(p1.x).min(p2.x).min(p3.x),
        p0.y.min(p1.y).min(p2.y).min(p3.y),
    );
    let max = Vec2::new(
        p0.x.max(p1.x).max(p2.x).max(p3.x),
        p0.y.max(p1.y).max(p2.y).max(p3.y),
    );
    Some((min, max))
}

fn world_to_minimap(world: Vec2, grid: &GridConfig, cfg: &MinimapConfig) -> Vec2 {
    let map_w = grid.grid_width as f32 * grid.cell_size;
    let map_h = grid.grid_height as f32 * grid.cell_size;
    let nx = ((world.x - grid.offset.x) / map_w).clamp(0.0, 1.0);
    let ny = ((world.y - grid.offset.y) / map_h).clamp(0.0, 1.0);
    Vec2::new(nx * cfg.width, ny * cfg.height)
}

/// Update player marker position on minimap
pub fn update_native_minimap(
    grid: Res<GridConfig>,
    player: Query<&Unit, With<PlayerUnit>>,
    mut marker: Query<&mut Node, With<PlayerMinimapMarker>>,
    cfg: Res<MinimapConfig>,
    mut frame: Local<u64>,
) {
    *frame += 1;
    if *frame % 5 != 0 {
        return;
    }
    let unit = player.single().unwrap();
    let cw = cfg.width / grid.grid_width as f32;
    let ch = cfg.height / grid.grid_height as f32;

    for mut node in marker.iter_mut() {
        node.left = Val::Px(unit.grid_x as f32 * cw - 4.0);
        node.bottom = Val::Px(unit.grid_y as f32 * ch - 4.0);
    }
}

/// Update minimap cell colors based on visibility
pub fn update_minimap_visibility(
    visibility: Res<VisibilityGrid>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    cfg: Res<MinimapConfig>,
    mut query: Query<
        (&mut BackgroundColor, &Node),
        (With<MinimapSprite>, Without<PlayerMinimapMarker>),
    >,
    mut frame: Local<u64>,
) {
    if !visibility.is_changed() {
        return;
    }
    *frame += 1;
    if *frame % 10 != 0 {
        return;
    }

    let cw = cfg.width / grid.grid_width as f32;
    let ch = cfg.height / grid.grid_height as f32;

    for (mut bg, node) in query.iter_mut() {
        let gx = match node.left {
            Val::Px(x) => (x / cw).round() as usize,
            _ => continue,
        };
        let gy = match node.bottom {
            Val::Px(y) => (y / ch).round() as usize,
            _ => continue,
        };
        if gx >= grid.grid_width || gy >= grid.grid_height {
            continue;
        }

        let color = if obstacles.cells[gx][gy] {
            Color::srgba(0.2, 0.6, 0.2, 1.0)
        } else {
            match visibility.cells[gx][gy] {
                0 => Color::srgba(0.02, 0.03, 0.02, 1.0),
                1 => Color::srgba(0.1, 0.15, 0.1, 1.0),
                _ => Color::srgba(0.25, 0.4, 0.25, 1.0),
            }
        };
        *bg = BackgroundColor(color);
    }
}
