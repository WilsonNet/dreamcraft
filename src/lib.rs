use bevy::prelude::*;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::collections::BinaryHeap;

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

pub struct DreamCraftPlugin;

impl Plugin for DreamCraftPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<GameState>()
            .init_resource::<GridConfig>()
            .init_resource::<ObstacleGrid>()
            .init_resource::<VisibilityGrid>()
            .init_resource::<FogWaypoints>()
            .init_resource::<MinimapConfig>()
            .insert_resource(ClearColor(Color::srgb(0.02, 0.04, 0.02)))
            .add_systems(Startup, setup_tutorial_level)
            .add_systems(
                Update,
                (
                    handle_input,
                    #[cfg(target_arch = "wasm32")]
                    read_console_commands,
                    #[cfg(not(target_arch = "wasm32"))]
                    read_stdin_commands,
                    unit_movement,
                    camera_controls,
                    check_goal,
                    draw_path,
                    update_visibility,
                    update_fog,
                    draw_waypoints,
                    check_waypoint_reached,
                    #[cfg(target_arch = "wasm32")]
                    broadcast_minimap_data,
                    #[cfg(not(target_arch = "wasm32"))]
                    (update_native_minimap, update_minimap_visibility),
                    debug_console_output,
                ),
            );
    }
}

// ==================== Resources ====================

#[derive(Resource, Default)]
pub struct GameState {
    pub selected_units: Vec<Entity>,
    pub level_complete: bool,
}

#[derive(Resource)]
pub struct GridConfig {
    pub cell_size: f32,
    pub grid_width: usize,
    pub grid_height: usize,
    pub offset: Vec2,
}

impl Default for GridConfig {
    fn default() -> Self {
        Self {
            cell_size: 32.0,
            grid_width: 80,
            grid_height: 50,
            offset: Vec2::new(-1280.0, -800.0),
        }
    }
}

#[derive(Resource, Default)]
pub struct ObstacleGrid {
    pub cells: Vec<Vec<bool>>,
}

#[derive(Resource)]
pub struct VisibilityGrid {
    pub cells: Vec<Vec<u8>>,
    pub view_radius: usize,
}

impl Default for VisibilityGrid {
    fn default() -> Self {
        Self {
            cells: Vec::new(),
            view_radius: 5,
        }
    }
}

#[derive(Resource, Clone)]
pub struct FogWaypoints {
    pub waypoints: Vec<(usize, usize)>,
    pub current_target: usize,
}

impl Default for FogWaypoints {
    fn default() -> Self {
        Self {
            waypoints: vec![
                (10, 25),
                (20, 25),
                (30, 25),
                (40, 20),
                (50, 25),
                (60, 25),
                (70, 25),
                (77, 25),
            ],
            current_target: 0,
        }
    }
}

#[derive(Resource)]
pub struct MinimapConfig {
    pub width: f32,
    pub height: f32,
}

impl Default for MinimapConfig {
    fn default() -> Self {
        Self {
            width: 200.0,
            height: 125.0,
        }
    }
}

// ==================== Components ====================

#[derive(Component)]
pub struct Unit {
    pub speed: f32,
    pub grid_x: usize,
    pub grid_y: usize,
}

#[derive(Component)]
pub struct Target {
    pub path: Vec<(usize, usize)>,
    pub path_index: usize,
}

#[derive(Component)]
pub struct Selected;

#[derive(Component)]
pub struct Tree;

#[derive(Component)]
pub struct GoalZone;

#[derive(Component)]
pub struct PlayerUnit;

#[derive(Component)]
pub struct EnemyUnit;

#[derive(Component)]
pub struct FogCell;

#[derive(Component)]
pub struct WaypointMarker {
    pub index: usize,
    pub reached: bool,
}

#[derive(Component)]
pub struct MinimapSprite;

#[derive(Component)]
pub struct MinimapCamera;

#[derive(Component)]
struct MinimapEntity;

#[derive(Component)]
struct MinimapBackground;

#[derive(Component)]
struct PlayerMinimapMarker;

// ==================== Constants ====================

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

// ==================== Startup Systems ====================

fn setup_tutorial_level(
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

    let camera = spawn_camera(&mut commands, start_pos);
    initialize_grids(
        &mut obstacle_grid,
        &mut visibility_grid,
        &grid,
        start_x,
        start_y,
    );

    #[cfg(not(target_arch = "wasm32"))]
    spawn_minimap(
        &mut commands,
        &mut meshes,
        &mut materials,
        &obstacle_grid,
        &visibility_grid,
        &fog_waypoints,
        &grid,
        &minimap_config,
        camera,
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

#[cfg(not(target_arch = "wasm32"))]
fn spawn_minimap(
    commands: &mut Commands,
    _meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    obstacles: &ObstacleGrid,
    visibility: &VisibilityGrid,
    waypoints: &FogWaypoints,
    grid: &GridConfig,
    cfg: &MinimapConfig,
    camera: Entity,
) {
    let cell_w = cfg.width / grid.grid_width as f32;
    let cell_h = cfg.height / grid.grid_height as f32;

    commands.entity(camera).with_children(|p| {
        p.spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px(20.0),
                bottom: Val::Px(30.0),
                width: Val::Px(cfg.width),
                height: Val::Px(cfg.height),
                ..default()
            },
            BackgroundColor(Color::srgba(0.1, 0.1, 0.1, 0.9)),
            MinimapEntity,
            MinimapBackground,
        ))
        .with_children(|border| {
            border.spawn((
                Node {
                    position_type: PositionType::Absolute,
                    left: Val::Px(-4.0),
                    right: Val::Px(-4.0),
                    top: Val::Px(-4.0),
                    bottom: Val::Px(-4.0),
                    ..default()
                },
                BackgroundColor(Color::srgb(0.3, 0.5, 0.3)),
                MinimapEntity,
            ));
        });

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

                p.spawn((
                    Node {
                        position_type: PositionType::Absolute,
                        left: Val::Px(gx as f32 * cell_w),
                        bottom: Val::Px(gy as f32 * cell_h),
                        width: Val::Px(cell_w.max(1.0)),
                        height: Val::Px(cell_h.max(1.0)),
                        ..default()
                    },
                    BackgroundColor(color),
                    MinimapEntity,
                    MinimapSprite,
                ));
            }
        }

        for (i, &(wx, wy)) in waypoints.waypoints.iter().enumerate() {
            if i > 0 {
                let color = if i == waypoints.current_target {
                    Color::srgba(1.0, 0.9, 0.2, 1.0)
                } else {
                    Color::srgba(0.8, 0.7, 0.1, 0.7)
                };
                p.spawn((
                    Node {
                        position_type: PositionType::Absolute,
                        left: Val::Px(wx as f32 * cell_w),
                        bottom: Val::Px(wy as f32 * cell_h),
                        width: Val::Px(8.0),
                        height: Val::Px(8.0),
                        ..default()
                    },
                    BackgroundColor(color),
                    MinimapEntity,
                    MinimapSprite,
                ));
            }
        }

        p.spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px((grid.grid_width - 2) as f32 * cell_w),
                bottom: Val::Px((grid.grid_height / 2) as f32 * cell_h),
                width: Val::Px(10.0),
                height: Val::Px(10.0),
                ..default()
            },
            BackgroundColor(Color::srgba(0.9, 0.8, 0.2, 1.0)),
            MinimapEntity,
            MinimapSprite,
        ));

        p.spawn((
            Node {
                position_type: PositionType::Absolute,
                left: Val::Px(2.0 * cell_w),
                bottom: Val::Px((grid.grid_height / 2) as f32 * cell_h),
                width: Val::Px(12.0),
                height: Val::Px(12.0),
                ..default()
            },
            BackgroundColor(Color::srgb(0.3, 0.6, 0.9)),
            MinimapEntity,
            PlayerMinimapMarker,
        ));
    });
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

fn spawn_unit(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid_x: usize,
    grid_y: usize,
    speed: f32,
    color: Color,
    is_player: bool,
    grid: &GridConfig,
) {
    let pos = grid_to_world(grid_x, grid_y, grid);
    let mut entity = commands.spawn((
        Mesh2d(meshes.add(Circle::new(12.0))),
        MeshMaterial2d(materials.add(color)),
        Transform::from_xyz(pos.x, pos.y, 5.0),
        Unit {
            speed,
            grid_x,
            grid_y,
        },
        Target {
            path: Vec::new(),
            path_index: 0,
        },
    ));

    if is_player {
        entity.insert((PlayerUnit, Selected));
    } else {
        entity.insert(EnemyUnit);
    }

    entity.with_children(|p| {
        p.spawn((
            Text2d::new("M"),
            TextFont {
                font_size: 18.0,
                ..default()
            },
            TextColor(Color::WHITE),
            Transform::from_xyz(0.0, -1.0, 6.0),
        ));
    });
}

// ==================== Visibility Systems ====================

fn reveal_area(cx: usize, cy: usize, visibility: &mut VisibilityGrid, grid: &GridConfig) {
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

fn clear_visibility(visibility: &mut VisibilityGrid) {
    for row in visibility.cells.iter_mut() {
        for cell in row.iter_mut() {
            if *cell == 2 {
                *cell = 1;
            }
        }
    }
}

fn update_visibility(
    query: Query<&Unit, With<PlayerUnit>>,
    mut visibility: ResMut<VisibilityGrid>,
    grid: Res<GridConfig>,
) {
    for unit in query.iter() {
        clear_visibility(&mut visibility);
        reveal_area(unit.grid_x, unit.grid_y, &mut visibility, &grid);
    }
}

fn update_fog(
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

// ==================== Input & Movement Systems ====================

fn handle_input(
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

fn unit_movement(
    mut query: Query<(&mut Unit, &mut Target, &mut Transform), With<PlayerUnit>>,
    grid: Res<GridConfig>,
    time: Res<Time>,
) {
    for (mut unit, mut target, mut transform) in query.iter_mut() {
        if target.path_index < target.path.len() {
            let (nx, ny) = target.path[target.path_index];
            let target_pos = grid_to_world(nx, ny, &grid);
            let dir = target_pos - transform.translation.truncate();
            let dist = dir.length();

            if dist < 5.0 {
                unit.grid_x = nx;
                unit.grid_y = ny;
                target.path_index += 1;
            } else {
                let vel = dir.normalize() * unit.speed * time.delta_secs();
                transform.translation.x += vel.x;
                transform.translation.y += vel.y;
            }
        }
    }
}

fn camera_controls(
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

// ==================== Game Logic Systems ====================

fn check_goal(
    query: Query<&Unit, With<PlayerUnit>>,
    grid: Res<GridConfig>,
    mut state: ResMut<GameState>,
) {
    if state.level_complete {
        return;
    }
    for unit in query.iter() {
        if unit.grid_x >= grid.grid_width - 3 {
            state.level_complete = true;
        }
    }
}

fn draw_path(query: Query<&Target, With<PlayerUnit>>, grid: Res<GridConfig>, mut gizmos: Gizmos) {
    for target in query.iter() {
        if target.path.is_empty() {
            continue;
        }
        let mut prev: Option<Vec2> = None;
        for (i, &(gx, gy)) in target.path.iter().enumerate() {
            if i < target.path_index {
                continue;
            }
            let pos = grid_to_world(gx, gy, &grid);
            if i == target.path_index {
                gizmos.circle_2d(pos, 8.0, Color::srgb(0.3, 0.8, 1.0));
            } else if i < target.path_index + 10 {
                let a = 1.0 - (i - target.path_index) as f32 * 0.08;
                gizmos.circle_2d(pos, 5.0, Color::srgba(0.6, 0.9, 0.6, a));
            }
            if let Some(p) = prev {
                gizmos.line_2d(p, pos, Color::srgba(0.4, 0.8, 0.4, 0.3));
            }
            prev = Some(pos);
        }
    }
}

fn draw_waypoints(
    mut materials: ResMut<Assets<ColorMaterial>>,
    waypoints: Res<FogWaypoints>,
    mut query: Query<(&mut WaypointMarker, &mut MeshMaterial2d<ColorMaterial>)>,
) {
    for (marker, mut mat) in query.iter_mut() {
        let color = if marker.reached {
            Color::srgba(0.3, 0.8, 0.3, 0.3)
        } else if marker.index == waypoints.current_target {
            Color::srgba(1.0, 0.9, 0.3, 0.9)
        } else {
            Color::srgba(0.6, 0.5, 0.1, 0.3)
        };
        mat.0 = materials.add(color);
    }
}

fn check_waypoint_reached(
    query: Query<&Unit, With<PlayerUnit>>,
    mut waypoints: ResMut<FogWaypoints>,
    mut marker_query: Query<&mut WaypointMarker>,
    grid: Res<GridConfig>,
    mut visibility: ResMut<VisibilityGrid>,
) {
    if waypoints.current_target >= waypoints.waypoints.len() {
        return;
    }
    let (tx, ty) = waypoints.waypoints[waypoints.current_target];

    for unit in query.iter() {
        let dist = ((unit.grid_x as i32 - tx as i32).abs() + (unit.grid_y as i32 - ty as i32).abs())
            as usize;
        if dist <= 3 {
            let next = waypoints.current_target + 1;
            if next < waypoints.waypoints.len() {
                waypoints.current_target = next;
                let (rx, ry) = waypoints.waypoints[next];
                for dx in -10..=10 {
                    for dy in -10..=10 {
                        if dx * dx + dy * dy <= 100 {
                            let nx = rx as i32 + dx;
                            let ny = ry as i32 + dy;
                            if nx >= 0
                                && nx < grid.grid_width as i32
                                && ny >= 0
                                && ny < grid.grid_height as i32
                            {
                                visibility.cells[nx as usize][ny as usize] = 2;
                            }
                        }
                    }
                }
                for mut m in marker_query.iter_mut() {
                    if m.index == next - 1 {
                        m.reached = true;
                    }
                }
            }
        }
    }
}

// ==================== Minimap Update Systems ====================

#[cfg(not(target_arch = "wasm32"))]
fn update_native_minimap(
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
        node.left = Val::Px(unit.grid_x as f32 * cw);
        node.bottom = Val::Px(unit.grid_y as f32 * ch);
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn update_minimap_visibility(
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

// ==================== Debug & Console Systems ====================

#[derive(Serialize, Deserialize, Debug)]
struct DebugState {
    frame: u64,
    camera_pos: [f32; 2],
    player_pos: [f32; 2],
    player_grid: [usize; 2],
    current_waypoint: usize,
    total_waypoints: usize,
    waypoints: Vec<(usize, usize)>,
    level_complete: bool,
    is_selected: bool,
    has_target: bool,
    path_length: usize,
    revealed_cells: usize,
    total_cells: usize,
    fog_coverage_pct: f32,
    obstacle_count: usize,
    grid_width: usize,
    grid_height: usize,
    player_visible: bool,
    player_in_fog: bool,
    camera_distance: f32,
    warnings: Vec<String>,
}

fn debug_console_output(
    camera: Query<&Transform, (With<Camera2d>, Without<MinimapCamera>)>,
    player: Query<(&Unit, &Transform, &Target, Option<&Selected>), With<PlayerUnit>>,
    waypoints: Res<FogWaypoints>,
    state: Res<GameState>,
    visibility: Res<VisibilityGrid>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    mut frame: Local<u64>,
) {
    *frame += 1;
    if *frame % 30 != 0 {
        return;
    }

    let cam_pos = camera
        .single()
        .map(|t| t.translation.truncate())
        .unwrap_or(Vec2::ZERO);
    let (unit, transform, target, selected) = player.single().unwrap();

    let total = grid.grid_width * grid.grid_height;
    let revealed = visibility
        .cells
        .iter()
        .flat_map(|c| c.iter())
        .filter(|&&v| v >= 1)
        .count();
    let obs = obstacles
        .cells
        .iter()
        .flat_map(|c| c.iter())
        .filter(|&&v| v)
        .count();

    let dist = ((cam_pos.x - transform.translation.x).powi(2)
        + (cam_pos.y - transform.translation.y).powi(2))
    .sqrt();
    let in_fog = unit.grid_x < grid.grid_width
        && unit.grid_y < grid.grid_height
        && visibility.cells[unit.grid_x][unit.grid_y] != 2;
    let visible = (transform.translation.x - cam_pos.x).abs() < 640.0
        && (transform.translation.y - cam_pos.y).abs() < 360.0
        && !in_fog;

    let mut warnings = Vec::new();
    if !visible {
        warnings.push("Player not visible!".into());
    }
    if in_fog {
        warnings.push("Player in fog!".into());
    }
    if dist > 800.0 {
        warnings.push(format!("Camera far from player ({:.0}px)", dist));
    }
    if selected.is_none() {
        warnings.push("Player not selected!".into());
    }

    let debug = DebugState {
        frame: *frame,
        camera_pos: [cam_pos.x, cam_pos.y],
        player_pos: [transform.translation.x, transform.translation.y],
        player_grid: [unit.grid_x, unit.grid_y],
        current_waypoint: waypoints.current_target,
        total_waypoints: waypoints.waypoints.len(),
        waypoints: waypoints.waypoints.clone(),
        level_complete: state.level_complete,
        is_selected: selected.is_some(),
        has_target: !target.path.is_empty() && target.path_index < target.path.len(),
        path_length: target.path.len().saturating_sub(target.path_index),
        revealed_cells: revealed,
        total_cells: total,
        fog_coverage_pct: ((total - revealed) as f32 / total as f32) * 100.0,
        obstacle_count: obs,
        grid_width: grid.grid_width,
        grid_height: grid.grid_height,
        player_visible: visible,
        player_in_fog: in_fog,
        camera_distance: dist,
        warnings,
    };

    broadcast_debug_state(&serde_json::to_string(&debug).unwrap_or_default());
}

#[cfg(target_arch = "wasm32")]
fn broadcast_debug_state(json: &str) {
    setItem("dreamcraft_debug_state", json);
}

#[cfg(not(target_arch = "wasm32"))]
fn broadcast_debug_state(_json: &str) {}

#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = localStorage)]
    fn setItem(key: &str, value: &str);
    #[wasm_bindgen(js_namespace = localStorage)]
    fn getItem(key: &str) -> Option<String>;
    #[wasm_bindgen(js_namespace = localStorage)]
    fn removeItem(key: &str);
}

#[derive(Deserialize, Debug)]
struct ConsoleCommand {
    cmd: String,
    x: Option<usize>,
    y: Option<usize>,
    verify: Option<VerifyCommand>,
}

#[derive(Deserialize, Debug)]
struct VerifyCommand {
    #[serde(rename = "type")]
    verify_type: String,
    x: Option<usize>,
    y: Option<usize>,
}

#[cfg(target_arch = "wasm32")]
fn read_console_commands(
    mut query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    state: Res<GameState>,
) {
    let cmd_str = match getItem("dreamcraft_command") {
        Some(s) if !s.is_empty() => s,
        _ => return,
    };
    removeItem("dreamcraft_command");

    if let Ok(cmd) = serde_json::from_str(&cmd_str) {
        let result = handle_headless_command(&mut query, &obstacles, &grid, &state, cmd);
        setItem("dreamcraft_command_result", &result.to_string());
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn read_stdin_commands(
    mut query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    state: Res<GameState>,
    mut frame: Local<u64>,
) {
    *frame += 1;
    if *frame % 30 != 0 {
        return;
    }

    let path = std::path::Path::new("headless_command.json");
    if !path.exists() {
        return;
    }

    if let Ok(buffer) = std::fs::read_to_string(path) {
        let _ = std::fs::remove_file(path);
        if let Ok(cmd) = serde_json::from_str(&buffer) {
            let result = handle_headless_command(&mut query, &obstacles, &grid, &state, cmd);
            let _ = std::fs::write("headless_result.json", result.to_string());
            println!("RESULT: {}", result);
        }
    }
}

fn handle_headless_command(
    query: &mut Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
    obstacles: &ObstacleGrid,
    grid: &GridConfig,
    state: &GameState,
    cmd: ConsoleCommand,
) -> serde_json::Value {
    match cmd.cmd.as_str() {
        "goto" => {
            let (x, y) = (cmd.x.unwrap_or(0), cmd.y.unwrap_or(0));
            for (unit, mut target) in query.iter_mut() {
                let path = find_path(
                    (unit.grid_x, unit.grid_y),
                    (x, y),
                    &obstacles.cells,
                    grid.grid_width,
                    grid.grid_height,
                );
                if !path.is_empty() {
                    target.path = path;
                    target.path_index = 0;
                    return serde_json::json!({"ok": true, "msg": format!("Moving to ({},{})", x, y)});
                }
            }
            serde_json::json!({"ok": false, "msg": "No path found"})
        }
        "status" => {
            let (unit, _) = query.single().unwrap();
            serde_json::json!({
                "ok": true,
                "msg": format!("Player at ({}, {})", unit.grid_x, unit.grid_y),
                "player_grid": [unit.grid_x, unit.grid_y]
            })
        }
        "verify" => {
            if let Some(v) = cmd.verify {
                match v.verify_type.as_str() {
                    "player_at" => {
                        let (unit, _) = query.single().unwrap();
                        let (vx, vy) = (v.x.unwrap_or(0), v.y.unwrap_or(0));
                        let ok = unit.grid_x == vx && unit.grid_y == vy;
                        let msg = if ok {
                            "Player at expected position".into()
                        } else {
                            format!(
                                "Player at ({}, {}), expected ({}, {})",
                                unit.grid_x, unit.grid_y, vx, vy
                            )
                        };
                        serde_json::json!({"ok": ok, "msg": msg})
                    }
                    "level_complete" => serde_json::json!({
                        "ok": state.level_complete,
                        "msg": if state.level_complete { "Level complete" } else { "Level not complete" }
                    }),
                    _ => serde_json::json!({"ok": false, "msg": "Unknown verify type"}),
                }
            } else {
                serde_json::json!({"ok": false, "msg": "No verify spec"})
            }
        }
        _ => serde_json::json!({"ok": false, "msg": format!("Unknown command: {}", cmd.cmd)}),
    }
}

#[cfg(target_arch = "wasm32")]
fn broadcast_minimap_data(
    visibility: Res<VisibilityGrid>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    player: Query<&Unit, With<PlayerUnit>>,
    waypoints: Res<FogWaypoints>,
    mut frame: Local<u64>,
) {
    *frame += 1;
    if *frame % 30 != 0 {
        return;
    }
    let unit = player.single().unwrap();

    let mut map = String::with_capacity(grid.grid_width * grid.grid_height + grid.grid_height);
    for gy in 0..grid.grid_height {
        for gx in 0..grid.grid_width {
            let ch = if gx == unit.grid_x && gy == unit.grid_y {
                'P'
            } else if waypoints
                .waypoints
                .get(waypoints.current_target)
                .map_or(false, |&(wx, wy)| gx == wx && gy == wy)
            {
                'W'
            } else if waypoints
                .waypoints
                .iter()
                .any(|&(wx, wy)| gx == wx && gy == wy)
            {
                'w'
            } else if visibility.cells[gx][gy] == 0 {
                '.'
            } else if obstacles.cells[gx][gy] {
                '#'
            } else {
                ' '
            };
            map.push(ch);
        }
        map.push('\n');
    }

    setItem("dreamcraft_minimap", &map);
    let meta = serde_json::json!({
        "width": grid.grid_width,
        "height": grid.grid_height,
        "player": [unit.grid_x, unit.grid_y],
    });
    setItem("dreamcraft_minimap_meta", &meta.to_string());
}

// ==================== Pathfinding ====================

#[derive(Copy, Clone, Eq, PartialEq)]
struct AStarNode {
    x: usize,
    y: usize,
    f: u32,
    g: u32,
}

impl Ord for AStarNode {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .f
            .cmp(&self.f)
            .then_with(|| self.x.cmp(&other.x))
            .then_with(|| self.y.cmp(&other.y))
    }
}

impl PartialOrd for AStarNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub fn find_path(
    start: (usize, usize),
    goal: (usize, usize),
    obstacles: &[Vec<bool>],
    width: usize,
    height: usize,
) -> Vec<(usize, usize)> {
    if goal.0 >= width || goal.1 >= height || obstacles[goal.0][goal.1] {
        return Vec::new();
    }

    let mut open = BinaryHeap::new();
    let mut came_from = vec![vec![None; height]; width];
    let mut g_score = vec![vec![u32::MAX; height]; width];
    let mut closed = vec![vec![false; height]; width];

    g_score[start.0][start.1] = 0;
    let h =
        ((goal.0 as i32 - start.0 as i32).abs() + (goal.1 as i32 - start.1 as i32).abs()) as u32;
    open.push(AStarNode {
        x: start.0,
        y: start.1,
        f: h,
        g: 0,
    });

    let dirs: [(i32, i32); 4] = [(0, 1), (1, 0), (0, -1), (-1, 0)];

    while let Some(cur) = open.pop() {
        if cur.x == goal.0 && cur.y == goal.1 {
            let mut path = vec![goal];
            let mut pos = goal;
            while let Some(prev) = came_from[pos.0][pos.1] {
                path.push(prev);
                pos = prev;
            }
            path.reverse();
            return path;
        }

        if closed[cur.x][cur.y] {
            continue;
        }
        closed[cur.x][cur.y] = true;

        for (dx, dy) in dirs {
            let nx = cur.x as i32 + dx;
            let ny = cur.y as i32 + dy;
            if nx < 0 || nx >= width as i32 || ny < 0 || ny >= height as i32 {
                continue;
            }
            let (nx, ny) = (nx as usize, ny as usize);
            if obstacles[nx][ny] || closed[nx][ny] {
                continue;
            }

            let tentative = cur.g + 1;
            if tentative < g_score[nx][ny] {
                came_from[nx][ny] = Some((cur.x, cur.y));
                g_score[nx][ny] = tentative;
                let h =
                    ((goal.0 as i32 - nx as i32).abs() + (goal.1 as i32 - ny as i32).abs()) as u32;
                open.push(AStarNode {
                    x: nx,
                    y: ny,
                    f: tentative + h,
                    g: tentative,
                });
            }
        }
    }
    Vec::new()
}

pub fn grid_to_world(gx: usize, gy: usize, grid: &GridConfig) -> Vec2 {
    Vec2::new(
        grid.offset.x + (gx as f32 + 0.5) * grid.cell_size,
        grid.offset.y + (gy as f32 + 0.5) * grid.cell_size,
    )
}

fn world_to_grid(world: Vec2, grid: &GridConfig) -> (usize, usize) {
    let gx = ((world.x - grid.offset.x) / grid.cell_size).floor() as i32;
    let gy = ((world.y - grid.offset.y) / grid.cell_size).floor() as i32;
    (
        gx.clamp(0, grid.grid_width as i32 - 1) as usize,
        gy.clamp(0, grid.grid_height as i32 - 1) as usize,
    )
}

pub fn run() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(DreamCraftPlugin)
        .run();
}
