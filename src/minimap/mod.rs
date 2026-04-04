//! Minimap rendering and updates

use crate::core::*;
use crate::units::Unit;
use bevy::prelude::*;

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
                    MinimapEntity,
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
                });
        });
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
