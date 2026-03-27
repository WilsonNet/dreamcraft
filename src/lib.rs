use bevy::prelude::*;
use std::cmp::Ordering;
use std::collections::BinaryHeap;

pub struct DreamCraftPlugin;

impl Plugin for DreamCraftPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<GameState>()
            .init_resource::<GridConfig>()
            .init_resource::<ObstacleGrid>()
            .init_resource::<VisibilityGrid>()
            .init_resource::<FogWaypoints>()
            .insert_resource(ClearColor(Color::srgb(0.05, 0.08, 0.05)))
            .add_systems(Startup, setup_tutorial_level)
            .add_systems(
                Update,
                (
                    handle_input,
                    unit_movement,
                    camera_controls,
                    check_goal,
                    draw_path,
                    update_visibility,
                    update_fog,
                    draw_waypoints,
                    check_waypoint_reached,
                ),
            );
    }
}

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
            grid_width: 40,
            grid_height: 30,
            offset: Vec2::new(-640.0, -480.0),
        }
    }
}

#[derive(Resource, Default)]
pub struct ObstacleGrid {
    pub cells: Vec<Vec<bool>>,
}

#[derive(Resource)]
pub struct VisibilityGrid {
    pub revealed: Vec<Vec<bool>>,
    pub view_radius: usize,
}

impl Default for VisibilityGrid {
    fn default() -> Self {
        Self {
            revealed: Vec::new(),
            view_radius: 4,
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
            waypoints: vec![(8, 15), (15, 15), (22, 15), (28, 12), (34, 15), (37, 15)],
            current_target: 0,
        }
    }
}

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
pub struct FogCell;

#[derive(Component)]
pub struct WaypointMarker {
    pub index: usize,
    pub reached: bool,
}

const TREE_CLUSTERS: [[(i32, i32); 5]; 12] = [
    [(8, 10), (9, 10), (8, 11), (9, 11), (10, 10)],
    [(15, 5), (16, 5), (15, 6), (16, 6), (0, 0)],
    [(20, 8), (21, 8), (20, 9), (21, 9), (22, 8)],
    [(20, 20), (21, 20), (20, 21), (21, 21), (22, 20)],
    [(25, 12), (26, 12), (25, 13), (26, 13), (27, 12)],
    [(30, 5), (31, 5), (30, 6), (31, 6), (32, 5)],
    [(12, 25), (13, 25), (12, 26), (13, 26), (14, 25)],
    [(5, 5), (6, 5), (5, 6), (6, 6), (0, 0)],
    [(35, 20), (36, 20), (35, 21), (36, 21), (37, 20)],
    [(28, 25), (29, 25), (28, 26), (29, 26), (30, 25)],
    [(16, 18), (17, 18), (16, 19), (0, 0), (0, 0)],
    [(10, 4), (11, 4), (10, 5), (0, 0), (0, 0)],
];

fn setup_tutorial_level(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut obstacle_grid: ResMut<ObstacleGrid>,
    mut visibility_grid: ResMut<VisibilityGrid>,
    fog_waypoints: ResMut<FogWaypoints>,
    grid: Res<GridConfig>,
) {
    commands.spawn(Camera2d);

    obstacle_grid.cells = vec![vec![false; grid.grid_height]; grid.grid_width];

    let ground_color = materials.add(Color::srgb(0.15, 0.25, 0.15));
    let ground = meshes.add(Rectangle::new(
        grid.cell_size * grid.grid_width as f32,
        grid.cell_size * grid.grid_height as f32,
    ));
    commands.spawn((
        Mesh2d(ground),
        MeshMaterial2d(ground_color),
        Transform::from_xyz(0.0, 0.0, -2.0),
    ));

    visibility_grid.revealed = vec![vec![false; grid.grid_height]; grid.grid_width];
    visibility_grid.view_radius = 5;

    let start_x = 2;
    let start_y = grid.grid_height / 2;
    reveal_area(start_x, start_y, &mut visibility_grid, &grid);

    let fog_color = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.95));
    let fog_mesh = meshes.add(Rectangle::new(grid.cell_size, grid.cell_size));

    for gx in 0..grid.grid_width {
        for gy in 0..grid.grid_height {
            if !visibility_grid.revealed[gx][gy] {
                let world_pos = grid_to_world(gx, gy, &grid);
                commands.spawn((
                    Mesh2d(fog_mesh.clone()),
                    MeshMaterial2d(fog_color.clone()),
                    Transform::from_xyz(world_pos.x, world_pos.y, 10.0),
                    FogCell,
                ));
            }
        }
    }

    for (i, &(wp_x, wp_y)) in fog_waypoints.waypoints.iter().enumerate() {
        if i > 0 {
            let world_pos = grid_to_world(wp_x, wp_y, &grid);
            let waypoint_color = if i == fog_waypoints.current_target {
                materials.add(Color::srgba(1.0, 0.8, 0.2, 0.8))
            } else {
                materials.add(Color::srgba(0.6, 0.5, 0.1, 0.4))
            };
            let waypoint_mesh = meshes.add(Circle::new(16.0));
            commands.spawn((
                Mesh2d(waypoint_mesh),
                MeshMaterial2d(waypoint_color),
                Transform::from_xyz(world_pos.x, world_pos.y, 3.0),
                WaypointMarker {
                    index: i,
                    reached: false,
                },
            ));
        }
    }

    let tree_trunk_color = materials.add(Color::srgb(0.4, 0.25, 0.1));
    let tree_leaves_color = materials.add(Color::srgb(0.1, 0.5, 0.2));
    let trunk_mesh = meshes.add(Rectangle::new(12.0, 20.0));
    let leaves_mesh = meshes.add(Circle::new(18.0));

    for cluster in TREE_CLUSTERS.iter() {
        for &(gx, gy) in cluster {
            if gx > 0 && gx < grid.grid_width as i32 && gy < grid.grid_height as i32 {
                let gx = gx as usize;
                let gy = gy as usize;
                obstacle_grid.cells[gx][gy] = true;

                let world_pos = grid_to_world(gx, gy, &grid);

                commands.spawn((
                    Mesh2d(trunk_mesh.clone()),
                    MeshMaterial2d(tree_trunk_color.clone()),
                    Transform::from_xyz(world_pos.x, world_pos.y - 5.0, 1.0),
                    Tree,
                ));

                commands.spawn((
                    Mesh2d(leaves_mesh.clone()),
                    MeshMaterial2d(tree_leaves_color.clone()),
                    Transform::from_xyz(world_pos.x, world_pos.y + 10.0, 2.0),
                    Tree,
                ));
            }
        }
    }

    let goal_color = materials.add(Color::srgb(0.8, 0.7, 0.2));
    let goal_mesh = meshes.add(Rectangle::new(
        grid.cell_size * 3.0,
        grid.cell_size * grid.grid_height as f32,
    ));
    let goal_x = grid_to_world(grid.grid_width - 2, grid.grid_height / 2, &grid).x;
    commands.spawn((
        Mesh2d(goal_mesh),
        MeshMaterial2d(goal_color),
        Transform::from_xyz(goal_x, 0.0, 0.0),
        GoalZone,
    ));

    let player_color = materials.add(Color::srgb(0.3, 0.6, 0.9));
    let player_mesh = meshes.add(Circle::new(12.0));

    let start_x = 2;
    let start_y = grid.grid_height / 2;
    let world_pos = grid_to_world(start_x, start_y, &grid);

    commands.spawn((
        Mesh2d(player_mesh),
        MeshMaterial2d(player_color),
        Transform::from_xyz(world_pos.x, world_pos.y, 5.0),
        Unit {
            speed: 150.0,
            grid_x: start_x,
            grid_y: start_y,
        },
        Target {
            path: Vec::new(),
            path_index: 0,
        },
        PlayerUnit,
        Selected,
    ));
}

fn reveal_area(cx: usize, cy: usize, visibility: &mut VisibilityGrid, grid: &GridConfig) {
    let r = visibility.view_radius as i32;
    let cx = cx as i32;
    let cy = cy as i32;
    for dx in -r..=r {
        for dy in -r..=r {
            if dx * dx + dy * dy <= r * r {
                let nx = cx + dx;
                let ny = cy + dy;
                if nx >= 0 && nx < grid.grid_width as i32 && ny >= 0 && ny < grid.grid_height as i32
                {
                    visibility.revealed[nx as usize][ny as usize] = true;
                }
            }
        }
    }
}

pub fn grid_to_world(gx: usize, gy: usize, grid: &GridConfig) -> Vec2 {
    Vec2::new(
        grid.offset.x + (gx as f32 + 0.5) * grid.cell_size,
        grid.offset.y + (gy as f32 + 0.5) * grid.cell_size,
    )
}

fn world_to_grid(world_pos: Vec2, grid: &GridConfig) -> (usize, usize) {
    let gx = ((world_pos.x - grid.offset.x) / grid.cell_size).floor() as i32;
    let gy = ((world_pos.y - grid.offset.y) / grid.cell_size).floor() as i32;

    let gx = gx.clamp(0, grid.grid_width as i32 - 1) as usize;
    let gy = gy.clamp(0, grid.grid_height as i32 - 1) as usize;

    (gx, gy)
}

#[derive(Copy, Clone, Eq, PartialEq)]
struct Node {
    x: usize,
    y: usize,
    f: u32,
    g: u32,
}

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .f
            .cmp(&self.f)
            .then_with(|| self.x.cmp(&other.x))
            .then_with(|| self.y.cmp(&other.y))
    }
}

impl PartialOrd for Node {
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

    let mut open_set = BinaryHeap::new();
    let mut came_from = vec![vec![None; height]; width];
    let mut g_score = vec![vec![u32::MAX; height]; width];
    let mut closed = vec![vec![false; height]; width];

    g_score[start.0][start.1] = 0;

    let h =
        ((goal.0 as i32 - start.0 as i32).abs() + (goal.1 as i32 - start.1 as i32).abs()) as u32;
    open_set.push(Node {
        x: start.0,
        y: start.1,
        f: h,
        g: 0,
    });

    let directions: [(i32, i32); 4] = [(0, 1), (1, 0), (0, -1), (-1, 0)];

    while let Some(current) = open_set.pop() {
        if current.x == goal.0 && current.y == goal.1 {
            let mut path = vec![goal];
            let mut pos = goal;
            while let Some(prev) = came_from[pos.0][pos.1] {
                path.push(prev);
                pos = prev;
            }
            path.reverse();
            return path;
        }

        if closed[current.x][current.y] {
            continue;
        }
        closed[current.x][current.y] = true;

        for (dx, dy) in directions {
            let nx = current.x as i32 + dx;
            let ny = current.y as i32 + dy;

            if nx < 0 || nx >= width as i32 || ny < 0 || ny >= height as i32 {
                continue;
            }

            let nx = nx as usize;
            let ny = ny as usize;

            if obstacles[nx][ny] || closed[nx][ny] {
                continue;
            }

            let tentative_g = current.g + 1;

            if tentative_g < g_score[nx][ny] {
                came_from[nx][ny] = Some((current.x, current.y));
                g_score[nx][ny] = tentative_g;

                let h =
                    ((goal.0 as i32 - nx as i32).abs() + (goal.1 as i32 - ny as i32).abs()) as u32;
                open_set.push(Node {
                    x: nx,
                    y: ny,
                    f: tentative_g + h,
                    g: tentative_g,
                });
            }
        }
    }

    Vec::new()
}

fn handle_input(
    mouse: Res<ButtonInput<MouseButton>>,
    window: Single<&Window>,
    camera: Single<(&Camera, &GlobalTransform)>,
    grid: Res<GridConfig>,
    obstacle_grid: Res<ObstacleGrid>,
    mut query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
) {
    let (camera, camera_transform) = *camera;

    if let Some(cursor_pos) = window.cursor_position() {
        if let Ok(world_pos) = camera.viewport_to_world_2d(camera_transform, cursor_pos) {
            let (click_gx, click_gy) = world_to_grid(world_pos, &grid);

            if mouse.just_pressed(MouseButton::Right) {
                for (unit, mut target) in query.iter_mut() {
                    let path = find_path(
                        (unit.grid_x, unit.grid_y),
                        (click_gx, click_gy),
                        &obstacle_grid.cells,
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
            let (next_gx, next_gy) = target.path[target.path_index];
            let target_world = grid_to_world(next_gx, next_gy, &grid);

            let current_pos = transform.translation.truncate();
            let direction = target_world - current_pos;
            let distance = direction.length();

            if distance < 5.0 {
                unit.grid_x = next_gx;
                unit.grid_y = next_gy;
                target.path_index += 1;
            } else {
                let velocity = direction.normalize() * unit.speed * time.delta_secs();
                transform.translation.x += velocity.x;
                transform.translation.y += velocity.y;
            }
        }
    }
}

fn camera_controls(
    keys: Res<ButtonInput<KeyCode>>,
    camera_query: Single<&mut Transform, With<Camera2d>>,
    time: Res<Time>,
    grid: Res<GridConfig>,
) {
    let mut camera_transform = camera_query.into_inner();

    let speed = 300.0;
    let mut velocity = Vec3::ZERO;

    if keys.pressed(KeyCode::KeyW) || keys.pressed(KeyCode::ArrowUp) {
        velocity.y += speed;
    }
    if keys.pressed(KeyCode::KeyS) || keys.pressed(KeyCode::ArrowDown) {
        velocity.y -= speed;
    }
    if keys.pressed(KeyCode::KeyA) || keys.pressed(KeyCode::ArrowLeft) {
        velocity.x -= speed;
    }
    if keys.pressed(KeyCode::KeyD) || keys.pressed(KeyCode::ArrowRight) {
        velocity.x += speed;
    }

    camera_transform.translation += velocity * time.delta_secs();

    let half_width = grid.cell_size * grid.grid_width as f32 / 2.0 + 200.0;
    let half_height = grid.cell_size * grid.grid_height as f32 / 2.0 + 200.0;

    camera_transform.translation.x = camera_transform
        .translation
        .x
        .clamp(-half_width, half_width);
    camera_transform.translation.y = camera_transform
        .translation
        .y
        .clamp(-half_height, half_height);
}

fn check_goal(
    query: Query<&Unit, With<PlayerUnit>>,
    grid: Res<GridConfig>,
    mut game_state: ResMut<GameState>,
) {
    if game_state.level_complete {
        return;
    }

    for unit in query.iter() {
        if unit.grid_x >= grid.grid_width - 3 {
            game_state.level_complete = true;
        }
    }
}

fn draw_path(query: Query<&Target, With<PlayerUnit>>, grid: Res<GridConfig>, mut gizmos: Gizmos) {
    for target in query.iter() {
        if target.path.is_empty() {
            continue;
        }

        let mut prev_pos: Option<Vec2> = None;

        for (i, &(gx, gy)) in target.path.iter().enumerate() {
            if i < target.path_index {
                continue;
            }

            let world_pos = grid_to_world(gx, gy, &grid);

            if i == target.path_index {
                gizmos.circle_2d(world_pos, 8.0, Color::srgb(0.3, 0.8, 1.0));
            } else if i < target.path_index + 10 {
                let alpha = 1.0 - (i - target.path_index) as f32 * 0.08;
                gizmos.circle_2d(world_pos, 5.0, Color::srgba(0.6, 0.9, 0.6, alpha));
            }

            if let Some(prev) = prev_pos {
                gizmos.line_2d(prev, world_pos, Color::srgba(0.4, 0.8, 0.4, 0.3));
            }
            prev_pos = Some(world_pos);
        }
    }
}

fn update_visibility(
    query: Query<&Unit, With<PlayerUnit>>,
    mut visibility: ResMut<VisibilityGrid>,
    grid: Res<GridConfig>,
) {
    for unit in query.iter() {
        reveal_area(unit.grid_x, unit.grid_y, &mut visibility, &grid);
    }
}

fn update_fog(
    _query: Query<&Transform, With<FogCell>>,
    visibility: Res<VisibilityGrid>,
    grid: Res<GridConfig>,
    mut fog_query: Query<(&mut MeshMaterial2d<ColorMaterial>, &Transform), With<FogCell>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    if !visibility.is_changed() {
        return;
    }

    let _fog_color_hidden = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.95));
    let fog_color_revealed = materials.add(Color::srgba(0.02, 0.03, 0.02, 0.0));

    for (mut mat2d, transform) in fog_query.iter_mut() {
        let (gx, gy) = world_to_grid(transform.translation.truncate(), &grid);
        if visibility.revealed[gx][gy] {
            mat2d.0 = fog_color_revealed.clone();
        }
    }
}

fn draw_waypoints(
    mut materials: ResMut<Assets<ColorMaterial>>,
    fog_waypoints: Res<FogWaypoints>,
    mut waypoint_query: Query<(&mut WaypointMarker, &mut MeshMaterial2d<ColorMaterial>)>,
) {
    let _fog_waypoints_changed = fog_waypoints.is_changed();

    for (marker, mut mat) in waypoint_query.iter_mut() {
        let color = if marker.reached {
            Color::srgba(0.3, 0.8, 0.3, 0.3)
        } else if marker.index == fog_waypoints.current_target {
            Color::srgba(1.0, 0.9, 0.3, 0.9)
        } else {
            Color::srgba(0.6, 0.5, 0.1, 0.3)
        };
        mat.0 = materials.add(color);
    }
}

fn check_waypoint_reached(
    query: Query<&Unit, With<PlayerUnit>>,
    mut fog_waypoints: ResMut<FogWaypoints>,
    mut waypoint_query: Query<&mut WaypointMarker>,
    grid: Res<GridConfig>,
    mut visibility: ResMut<VisibilityGrid>,
) {
    if fog_waypoints.current_target >= fog_waypoints.waypoints.len() {
        return;
    }

    let (target_x, target_y) = fog_waypoints.waypoints[fog_waypoints.current_target];

    for unit in query.iter() {
        let dist = ((unit.grid_x as i32 - target_x as i32).abs()
            + (unit.grid_y as i32 - target_y as i32).abs()) as usize;

        if dist <= 2 {
            let next_target = fog_waypoints.current_target + 1;
            if next_target < fog_waypoints.waypoints.len() {
                fog_waypoints.current_target = next_target;

                let (reveal_x, reveal_y) = fog_waypoints.waypoints[next_target];
                for dx in -8..=8 {
                    for dy in -8..=8 {
                        if dx * dx + dy * dy <= 64 {
                            let nx = reveal_x as i32 + dx;
                            let ny = reveal_y as i32 + dy;
                            if nx >= 0
                                && nx < grid.grid_width as i32
                                && ny >= 0
                                && ny < grid.grid_height as i32
                            {
                                visibility.revealed[nx as usize][ny as usize] = true;
                            }
                        }
                    }
                }

                for mut marker in waypoint_query.iter_mut() {
                    if marker.index == next_target - 1 {
                        marker.reached = true;
                    }
                }
            }
        }
    }
}

pub fn run() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(DreamCraftPlugin)
        .run();
}
