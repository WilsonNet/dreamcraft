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
            .init_resource::<MinimapConfig>()
            .insert_resource(ClearColor(Color::srgb(0.02, 0.04, 0.02)))
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
                    update_minimap,
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
    pub revealed: Vec<Vec<bool>>,
    pub view_radius: usize,
}

impl Default for VisibilityGrid {
    fn default() -> Self {
        Self {
            revealed: Vec::new(),
            view_radius: 5,
        }
    }
}

#[derive(Resource, Clone)]
pub struct FogWaypoints {
    pub waypoints: Vec<(usize, usize)>,
    pub current_target: usize,
}

#[derive(Resource)]
pub struct MinimapConfig {
    pub width: f32,
    pub height: f32,
    pub position: Vec2,
}

impl Default for MinimapConfig {
    fn default() -> Self {
        Self {
            width: 200.0,
            height: 125.0,
            position: Vec2::new(-600.0, -350.0),
        }
    }
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

#[derive(Component)]
pub struct MinimapMarker;

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

fn setup_tutorial_level(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut obstacle_grid: ResMut<ObstacleGrid>,
    mut visibility_grid: ResMut<VisibilityGrid>,
    fog_waypoints: ResMut<FogWaypoints>,
    grid: Res<GridConfig>,
    minimap_config: Res<MinimapConfig>,
) {
    commands.spawn(Camera2d);

    obstacle_grid.cells = vec![vec![false; grid.grid_height]; grid.grid_width];

    let ground_color = materials.add(Color::srgb(0.12, 0.2, 0.12));
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
    visibility_grid.view_radius = 6;

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
                materials.add(Color::srgba(1.0, 0.85, 0.2, 0.9))
            } else {
                materials.add(Color::srgba(0.6, 0.5, 0.1, 0.4))
            };
            let waypoint_mesh = meshes.add(Circle::new(18.0));
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

    let goal_color = materials.add(Color::srgb(0.9, 0.8, 0.2));
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

    setup_minimap(
        &mut commands,
        &grid,
        &obstacle_grid,
        &visibility_grid,
        &fog_waypoints,
        &minimap_config,
        &mut meshes,
        &mut materials,
    );
}

fn setup_minimap(
    commands: &mut Commands,
    grid: &GridConfig,
    obstacle_grid: &ObstacleGrid,
    visibility: &VisibilityGrid,
    fog_waypoints: &FogWaypoints,
    minimap_config: &MinimapConfig,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
) {
    let bg_mesh = meshes.add(Rectangle::new(minimap_config.width, minimap_config.height));
    let bg_color = materials.add(Color::srgba(0.05, 0.1, 0.05, 0.95));
    commands.spawn((
        Mesh2d(bg_mesh),
        MeshMaterial2d(bg_color),
        Transform::from_xyz(minimap_config.position.x, minimap_config.position.y, 100.0),
        MinimapMarker,
    ));

    let border_mesh = meshes.add(Rectangle::new(
        minimap_config.width + 4.0,
        minimap_config.height + 4.0,
    ));
    let border_color = materials.add(Color::srgba(0.3, 0.5, 0.3, 0.8));
    commands.spawn((
        Mesh2d(border_mesh),
        MeshMaterial2d(border_color),
        Transform::from_xyz(minimap_config.position.x, minimap_config.position.y, 99.0),
        MinimapMarker,
    ));

    let cell_width = minimap_config.width / grid.grid_width as f32;
    let cell_height = minimap_config.height / grid.grid_height as f32;
    let cell_mesh = meshes.add(Rectangle::new(cell_width.max(1.0), cell_height.max(1.0)));

    for gx in 0..grid.grid_width {
        for gy in 0..grid.grid_height {
            let mx = minimap_config.position.x - minimap_config.width / 2.0
                + (gx as f32 + 0.5) * cell_width;
            let my = minimap_config.position.y - minimap_config.height / 2.0
                + (gy as f32 + 0.5) * cell_height;

            let color = if obstacle_grid.cells[gx][gy] {
                materials.add(Color::srgba(0.1, 0.4, 0.1, 1.0))
            } else if !visibility.revealed[gx][gy] {
                materials.add(Color::srgba(0.02, 0.04, 0.02, 1.0))
            } else {
                materials.add(Color::srgba(0.15, 0.25, 0.15, 1.0))
            };

            commands.spawn((
                Mesh2d(cell_mesh.clone()),
                MeshMaterial2d(color),
                Transform::from_xyz(mx, my, 101.0),
                MinimapMarker,
            ));
        }
    }

    for (i, &(wx, wy)) in fog_waypoints.waypoints.iter().enumerate() {
        if i > 0 {
            let mx = minimap_config.position.x - minimap_config.width / 2.0
                + (wx as f32 + 0.5) * cell_width;
            let my = minimap_config.position.y - minimap_config.height / 2.0
                + (wy as f32 + 0.5) * cell_height;

            let color = if i == fog_waypoints.current_target {
                materials.add(Color::srgba(1.0, 0.9, 0.2, 1.0))
            } else {
                materials.add(Color::srgba(0.8, 0.7, 0.1, 0.7))
            };

            let marker_mesh = meshes.add(Circle::new(4.0));
            commands.spawn((
                Mesh2d(marker_mesh),
                MeshMaterial2d(color),
                Transform::from_xyz(mx, my, 102.0),
                MinimapMarker,
            ));
        }
    }

    let goal_x = grid.grid_width - 2;
    let goal_y = grid.grid_height / 2;
    let gmx =
        minimap_config.position.x - minimap_config.width / 2.0 + (goal_x as f32 + 0.5) * cell_width;
    let gmy = minimap_config.position.y - minimap_config.height / 2.0
        + (goal_y as f32 + 0.5) * cell_height;
    let goal_mesh = meshes.add(Circle::new(5.0));
    let goal_color = materials.add(Color::srgba(0.9, 0.8, 0.2, 1.0));
    commands.spawn((
        Mesh2d(goal_mesh),
        MeshMaterial2d(goal_color),
        Transform::from_xyz(gmx, gmy, 102.0),
        MinimapMarker,
    ));

    let start_x = 2;
    let start_y = grid.grid_height / 2;
    let smx = minimap_config.position.x - minimap_config.width / 2.0
        + (start_x as f32 + 0.5) * cell_width;
    let smy = minimap_config.position.y - minimap_config.height / 2.0
        + (start_y as f32 + 0.5) * cell_height;
    let start_mesh = meshes.add(Circle::new(3.0));
    let start_color = materials.add(Color::srgba(0.2, 0.5, 0.2, 0.6));
    commands.spawn((
        Mesh2d(start_mesh),
        MeshMaterial2d(start_color),
        Transform::from_xyz(smx, smy, 102.0),
        MinimapMarker,
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

    let mut open_set = BinaryHeap::new();
    let mut came_from = vec![vec![None; height]; width];
    let mut g_score = vec![vec![u32::MAX; height]; width];
    let mut closed = vec![vec![false; height]; width];

    g_score[start.0][start.1] = 0;

    let h =
        ((goal.0 as i32 - start.0 as i32).abs() + (goal.1 as i32 - start.1 as i32).abs()) as u32;
    open_set.push(AStarNode {
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
                open_set.push(AStarNode {
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

    let speed = 400.0;
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

        if dist <= 3 {
            let next_target = fog_waypoints.current_target + 1;
            if next_target < fog_waypoints.waypoints.len() {
                fog_waypoints.current_target = next_target;

                let (reveal_x, reveal_y) = fog_waypoints.waypoints[next_target];
                for dx in -10..=10 {
                    for dy in -10..=10 {
                        if dx * dx + dy * dy <= 100 {
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

fn update_minimap(
    query: Query<&Transform, With<PlayerUnit>>,
    grid: Res<GridConfig>,
    minimap_config: Res<MinimapConfig>,
) {
    for transform in query.iter() {
        let _world_pos = transform.translation.truncate();
    }
}

pub fn run() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(DreamCraftPlugin)
        .run();
}
