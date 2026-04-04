//! Grid setup, visibility, and fog of war systems

use crate::core::{
    FogCell, FogWaypoints, GoalZone, GridConfig, MinimapConfig, ObstacleGrid, PlayerUnit, Tree,
    VisibilityGrid, WaypointMarker,
};
use crate::units::{spawn_unit, Unit};
use bevy::prelude::*;

/// Tree cluster positions
const TREE_CLUSTERS: [[(i32, i32); 6]; 30] = [
    [(8, 20), (9, 20), (8, 21), (9, 21), (10, 20), (10, 21)],
    [(15, 10), (16, 10), (15, 11), (16, 11), (0, 0), (0, 0)],
    [(15, 40), (16, 40), (15, 41), (16, 41), (0, 0), (0, 0)],
    [(22, 15), (23, 15), (22, 16), (23, 16), (24, 15), (0, 0)],
    [(22, 35), (23, 35), (22, 36), (23, 36), (24, 35), (0, 0)],
    [(30, 8), (31, 8), (30, 9), (31, 9), (32, 8), (0, 0)],
    [(30, 42), (31, 42), (30, 43), (31, 43), (32, 42), (0, 0)],
    [(38, 20), (39, 20), (38, 21), (39, 21), (40, 20), (40, 21)],
    [(38, 30), (39, 30), (38, 31), (39, 31), (40, 30), (40, 31)],
    [(45, 12), (46, 12), (45, 13), (46, 13), (0, 0), (0, 0)],
    [(45, 38), (46, 38), (45, 39), (46, 39), (0, 0), (0, 0)],
    [(52, 22), (53, 22), (52, 23), (53, 23), (54, 22), (0, 0)],
    [(52, 28), (53, 28), (52, 29), (53, 29), (54, 28), (0, 0)],
    [(58, 10), (59, 10), (58, 11), (59, 11), (60, 10), (0, 0)],
    [(58, 40), (59, 40), (58, 41), (59, 41), (60, 40), (0, 0)],
    [(65, 18), (66, 18), (65, 19), (66, 19), (0, 0), (0, 0)],
    [(65, 32), (66, 32), (65, 33), (66, 33), (0, 0), (0, 0)],
    [(72, 8), (73, 8), (72, 9), (73, 9), (0, 0), (0, 0)],
    [(72, 42), (73, 42), (72, 43), (73, 43), (0, 0), (0, 0)],
    [(25, 25), (26, 25), (25, 26), (26, 26), (0, 0), (0, 0)],
    [(35, 25), (36, 25), (35, 26), (36, 26), (0, 0), (0, 0)],
    [(48, 25), (49, 25), (48, 26), (49, 26), (0, 0), (0, 0)],
    [(55, 15), (56, 15), (55, 16), (0, 0), (0, 0), (0, 0)],
    [(55, 35), (56, 35), (55, 36), (0, 0), (0, 0), (0, 0)],
    [(62, 25), (63, 25), (62, 26), (63, 26), (0, 0), (0, 0)],
    [(18, 30), (19, 30), (18, 31), (19, 31), (0, 0), (0, 0)],
    [(42, 12), (43, 12), (42, 13), (43, 13), (0, 0), (0, 0)],
    [(42, 38), (43, 38), (42, 39), (43, 39), (0, 0), (0, 0)],
    [(68, 25), (69, 25), (68, 26), (69, 26), (0, 0), (0, 0)],
    [(12, 35), (13, 35), (12, 36), (13, 36), (0, 0), (0, 0)],
];

/// Setup the tutorial level
pub fn setup_tutorial_level(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut obstacle_grid: ResMut<ObstacleGrid>,
    mut visibility_grid: ResMut<VisibilityGrid>,
    fog_waypoints: ResMut<FogWaypoints>,
    grid: Res<GridConfig>,
    #[cfg(not(target_arch = "wasm32"))] minimap_config: Res<MinimapConfig>,
) {
    let start_x = 2;
    let start_y = grid.grid_height / 2;
    let start_pos = grid_to_world(start_x, start_y, &grid);

    let _camera = spawn_camera(&mut commands, start_pos);
    initialize_grids(
        &mut obstacle_grid,
        &mut visibility_grid,
        &grid,
        start_x,
        start_y,
    );

    #[cfg(not(target_arch = "wasm32"))]
    crate::minimap::spawn_minimap(
        &mut commands,
        &obstacle_grid,
        &visibility_grid,
        &fog_waypoints,
        &grid,
        &minimap_config,
    );

    spawn_ground(&mut commands, &mut meshes, &mut materials, &grid);
    spawn_fog(
        &mut commands,
        &mut meshes,
        &mut materials,
        &visibility_grid,
        &grid,
    );
    spawn_waypoints(
        &mut commands,
        &mut meshes,
        &mut materials,
        &fog_waypoints,
        &grid,
    );
    spawn_trees(&mut commands, &mut meshes, &mut materials, &grid);
    spawn_goal(&mut commands, &mut meshes, &mut materials, &grid);
    spawn_player(
        &mut commands,
        &mut meshes,
        &mut materials,
        start_x,
        start_y,
        &grid,
    );
    spawn_enemy(&mut commands, &mut meshes, &mut materials, 50, 25, &grid);
}

fn spawn_camera(commands: &mut Commands, position: Vec2) -> Entity {
    commands
        .spawn((
            Camera2d,
            Name::new("MainCamera"),
            Transform::from_xyz(position.x, position.y, 100.0),
        ))
        .id()
}

fn initialize_grids(
    obstacles: &mut ObstacleGrid,
    visibility: &mut VisibilityGrid,
    grid: &GridConfig,
    start_x: usize,
    start_y: usize,
) {
    obstacles.cells = vec![vec![false; grid.grid_height]; grid.grid_width];
    for cluster in TREE_CLUSTERS.iter() {
        for &(gx, gy) in cluster {
            if gx > 0 && gx < grid.grid_width as i32 && gy < grid.grid_height as i32 {
                obstacles.cells[gx as usize][gy as usize] = true;
            }
        }
    }

    visibility.cells = vec![vec![0u8; grid.grid_height]; grid.grid_width];
    visibility.view_radius = 6;
    reveal_area(start_x, start_y, visibility, grid);
}

fn spawn_ground(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid: &GridConfig,
) {
    let ground = meshes.add(Rectangle::new(
        grid.cell_size * grid.grid_width as f32,
        grid.cell_size * grid.grid_height as f32,
    ));
    commands.spawn((
        Mesh2d(ground),
        MeshMaterial2d(materials.add(Color::srgb(0.12, 0.2, 0.12))),
        Transform::from_xyz(0.0, 0.0, -2.0),
    ));
}

fn spawn_fog(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    visibility: &VisibilityGrid,
    grid: &GridConfig,
) {
    let fog_mesh = meshes.add(Rectangle::new(grid.cell_size, grid.cell_size));
    let fog_color = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.95));

    for gx in 0..grid.grid_width {
        for gy in 0..grid.grid_height {
            if visibility.cells[gx][gy] == 0 {
                let pos = grid_to_world(gx, gy, grid);
                commands.spawn((
                    Mesh2d(fog_mesh.clone()),
                    MeshMaterial2d(fog_color.clone()),
                    Transform::from_xyz(pos.x, pos.y, 10.0),
                    FogCell,
                ));
            }
        }
    }
}

fn spawn_waypoints(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    waypoints: &FogWaypoints,
    grid: &GridConfig,
) {
    for (i, &(wx, wy)) in waypoints.waypoints.iter().enumerate() {
        if i > 0 {
            let pos = grid_to_world(wx, wy, grid);
            let color = if i == waypoints.current_target {
                materials.add(Color::srgba(1.0, 0.85, 0.2, 0.9))
            } else {
                materials.add(Color::srgba(0.6, 0.5, 0.1, 0.4))
            };
            commands.spawn((
                Mesh2d(meshes.add(Circle::new(18.0))),
                MeshMaterial2d(color),
                Transform::from_xyz(pos.x, pos.y, 3.0),
                WaypointMarker {
                    index: i,
                    reached: false,
                },
            ));
        }
    }
}

fn spawn_trees(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid: &GridConfig,
) {
    let trunk_mesh = meshes.add(Rectangle::new(12.0, 20.0));
    let leaves_mesh = meshes.add(Circle::new(18.0));
    let trunk_mat = materials.add(Color::srgb(0.4, 0.25, 0.1));
    let leaves_mat = materials.add(Color::srgb(0.1, 0.5, 0.2));

    for cluster in TREE_CLUSTERS.iter() {
        for &(gx, gy) in cluster {
            if gx > 0 && gx < grid.grid_width as i32 && gy < grid.grid_height as i32 {
                let pos = grid_to_world(gx as usize, gy as usize, grid);
                commands.spawn((
                    Mesh2d(trunk_mesh.clone()),
                    MeshMaterial2d(trunk_mat.clone()),
                    Transform::from_xyz(pos.x, pos.y - 5.0, 1.0),
                    Tree,
                ));
                commands.spawn((
                    Mesh2d(leaves_mesh.clone()),
                    MeshMaterial2d(leaves_mat.clone()),
                    Transform::from_xyz(pos.x, pos.y + 10.0, 2.0),
                    Tree,
                ));
            }
        }
    }
}

fn spawn_goal(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid: &GridConfig,
) {
    let goal = meshes.add(Rectangle::new(
        grid.cell_size * 3.0,
        grid.cell_size * grid.grid_height as f32,
    ));
    let pos_x = grid_to_world(grid.grid_width - 2, grid.grid_height / 2, grid).x;
    commands.spawn((
        Mesh2d(goal),
        MeshMaterial2d(materials.add(Color::srgb(0.9, 0.8, 0.2))),
        Transform::from_xyz(pos_x, 0.0, 0.0),
        GoalZone,
    ));
}

fn spawn_player(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid_x: usize,
    grid_y: usize,
    grid: &GridConfig,
) {
    spawn_unit(
        commands,
        meshes,
        materials,
        grid_x,
        grid_y,
        150.0,
        Color::srgb(0.3, 0.6, 0.9),
        true,
        grid,
    );
}

fn spawn_enemy(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid_x: usize,
    grid_y: usize,
    grid: &GridConfig,
) {
    spawn_unit(
        commands,
        meshes,
        materials,
        grid_x,
        grid_y,
        80.0,
        Color::srgb(0.9, 0.3, 0.3),
        false,
        grid,
    );
}

/// Reveal area around a point (mark as visible)
pub fn reveal_area(cx: usize, cy: usize, visibility: &mut VisibilityGrid, grid: &GridConfig) {
    let r = visibility.view_radius as i32;
    for dx in -r..=r {
        for dy in -r..=r {
            if dx * dx + dy * dy <= r * r {
                let nx = cx as i32 + dx;
                let ny = cy as i32 + dy;
                if nx >= 0 && nx < grid.grid_width as i32 && ny >= 0 && ny < grid.grid_height as i32
                {
                    visibility.cells[nx as usize][ny as usize] = 2;
                }
            }
        }
    }
}

/// Clear visibility (mark visible cells as explored)
fn clear_visibility(visibility: &mut VisibilityGrid) {
    for row in visibility.cells.iter_mut() {
        for cell in row.iter_mut() {
            if *cell == 2 {
                *cell = 1;
            }
        }
    }
}

/// Update visibility based on player position
pub fn update_visibility(
    query: Query<&Unit, With<PlayerUnit>>,
    mut visibility: ResMut<VisibilityGrid>,
    grid: Res<GridConfig>,
) {
    for unit in query.iter() {
        clear_visibility(&mut visibility);
        reveal_area(unit.grid_x, unit.grid_y, &mut visibility, &grid);
    }
}

/// Update fog appearance based on visibility
pub fn update_fog(
    visibility: Res<VisibilityGrid>,
    grid: Res<GridConfig>,
    mut query: Query<(&mut MeshMaterial2d<ColorMaterial>, &Transform), With<FogCell>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    if !visibility.is_changed() {
        return;
    }

    let visible = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.0));
    let explored = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.5));
    let unexplored = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.95));

    for (mut mat, transform) in query.iter_mut() {
        let (gx, gy) = world_to_grid(transform.translation.truncate(), &grid);
        mat.0 = match visibility.cells[gx][gy] {
            0 => unexplored.clone(),
            1 => explored.clone(),
            _ => visible.clone(),
        };
    }
}

/// Convert grid coordinates to world position
pub fn grid_to_world(gx: usize, gy: usize, grid: &GridConfig) -> Vec2 {
    Vec2::new(
        grid.offset.x + (gx as f32 + 0.5) * grid.cell_size,
        grid.offset.y + (gy as f32 + 0.5) * grid.cell_size,
    )
}

/// Convert world position to grid coordinates
pub fn world_to_grid(world: Vec2, grid: &GridConfig) -> (usize, usize) {
    let gx = ((world.x - grid.offset.x) / grid.cell_size).floor() as i32;
    let gy = ((world.y - grid.offset.y) / grid.cell_size).floor() as i32;
    (
        gx.clamp(0, grid.grid_width as i32 - 1) as usize,
        gy.clamp(0, grid.grid_height as i32 - 1) as usize,
    )
}
