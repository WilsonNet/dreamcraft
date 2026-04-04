//! Unit systems: movement, commands, goal detection

use crate::core::*;
use crate::grid::grid_to_world;
use crate::pathfinding::find_path;
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

/// Unit behavior states
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Reflect)]
pub enum UnitState {
    #[default]
    Idle,
    Moving,
}

/// Unit component with movement data
#[derive(Component, Default, Reflect)]
#[reflect(Component)]
pub struct Unit {
    pub speed: f32,
    pub grid_x: usize,
    pub grid_y: usize,
}

/// Health component for units
#[derive(Component, Default, Reflect)]
#[reflect(Component)]
pub struct Health {
    pub current: u32,
    pub max: u32,
}

/// State machine for unit behavior
#[derive(Component, Default, Reflect)]
#[reflect(Component)]
pub struct UnitStateMachine {
    pub state: UnitState,
}

/// Target destination with path
#[derive(Component, Default, Reflect)]
#[reflect(Component)]
pub struct Target {
    pub path: Vec<(usize, usize)>,
    pub path_index: usize,
}

/// Health bar marker
#[derive(Component)]
pub struct HealthBar;

/// MeleeUnit bundle - all melee units share these components
/// Player and Enemy are identical units, differentiated only by Team
#[derive(Bundle, Default)]
pub struct MeleeUnit {
    pub unit: Unit,
    pub health: Health,
    pub state: UnitStateMachine,
    pub target: Target,
}

impl MeleeUnit {
    pub fn new(grid_x: usize, grid_y: usize) -> Self {
        Self {
            unit: Unit {
                speed: 150.0,
                grid_x,
                grid_y,
            },
            health: Health {
                current: 100,
                max: 100,
            },
            state: UnitStateMachine::default(),
            target: Target::default(),
        }
    }
}

/// Spawn a unit with a specific team using MeleeUnit bundle
pub fn spawn_unit(
    commands: &mut Commands,
    meshes: &mut ResMut<Assets<Mesh>>,
    materials: &mut ResMut<Assets<ColorMaterial>>,
    grid_x: usize,
    grid_y: usize,
    team: Team,
    grid: &GridConfig,
) {
    let pos = grid_to_world(grid_x, grid_y, grid);
    let color = match team {
        Team::Player => Color::srgb(0.3, 0.5, 0.9),
        Team::Enemy => Color::srgb(0.9, 0.3, 0.3),
    };
    let label = match team {
        Team::Player => "M",
        Team::Enemy => "E",
    };

    // Spawn MeleeUnit bundle - identical for both player and enemy
    let mut entity = commands.spawn((
        Mesh2d(meshes.add(Circle::new(12.0))),
        MeshMaterial2d(materials.add(color)),
        Transform::from_xyz(pos.x, pos.y, 5.0),
        MeleeUnit::new(grid_x, grid_y),
        team,
    ));

    if team == Team::Player {
        entity.insert(PlayerUnit);
    } else {
        entity.insert((EnemyUnit, Visibility::Hidden));
    }

    entity.with_children(|p| {
        p.spawn((
            Text2d::new(label),
            TextFont {
                font_size: 18.0,
                ..default()
            },
            TextColor(Color::WHITE),
            Transform::from_xyz(0.0, 0.0, 1.0),
        ));
    });
}

/// Check if player reached the goal
pub fn check_goal(
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

/// Spawn health bars for units
pub fn spawn_health_bars(mut commands: Commands, units: Query<(Entity, &Health), Added<Health>>) {
    for (entity, health) in units.iter() {
        let health_percent = health.current as f32 / health.max as f32;

        commands.entity(entity).with_children(|parent| {
            // Health bar background
            parent.spawn((
                Sprite {
                    color: Color::srgb(0.2, 0.2, 0.2),
                    custom_size: Some(Vec2::new(24.0, 4.0)),
                    ..default()
                },
                Transform::from_xyz(0.0, 18.0, 7.0),
                HealthBar,
            ));

            // Health bar fill
            parent.spawn((
                Sprite {
                    color: if health_percent > 0.5 {
                        Color::srgb(0.2, 0.8, 0.2)
                    } else if health_percent > 0.25 {
                        Color::srgb(0.9, 0.7, 0.1)
                    } else {
                        Color::srgb(0.9, 0.2, 0.2)
                    },
                    custom_size: Some(Vec2::new(24.0 * health_percent, 4.0)),
                    ..default()
                },
                Transform::from_xyz(-12.0 + 12.0 * health_percent, 18.0, 8.0),
                HealthBar,
            ));
        });
    }
}

/// Update enemy visibility based on player vision radius
pub fn update_enemy_visibility(
    player: Query<&Unit, With<PlayerUnit>>,
    mut enemies: Query<(&Unit, &mut Visibility), With<EnemyUnit>>,
    visibility_grid: Res<VisibilityGrid>,
) {
    let Ok(player_unit) = player.single() else {
        return;
    };

    // Simple check: enemy is visible if player can see its cell
    for (enemy_unit, mut visibility) in enemies.iter_mut() {
        let dist_sq = (enemy_unit.grid_x as i32 - player_unit.grid_x as i32).pow(2)
            + (enemy_unit.grid_y as i32 - player_unit.grid_y as i32).pow(2);
        let in_vision_radius = (dist_sq as f32).sqrt() < visibility_grid.view_radius as f32;

        let cell_visible = enemy_unit.grid_x < visibility_grid.cells.len()
            && enemy_unit.grid_y < visibility_grid.cells[0].len()
            && visibility_grid.cells[enemy_unit.grid_x][enemy_unit.grid_y] == 2;

        if in_vision_radius && cell_visible {
            *visibility = Visibility::Visible;
        } else {
            *visibility = Visibility::Hidden;
        }
    }
}

/// Enemy AI - chase player when in vision range
/// Enemy is an identical unit to player - same speed, same class
/// Only chases while player is within enemy view radius
pub fn enemy_ai_chase(
    player: Query<(&Unit, &Transform), With<PlayerUnit>>,
    mut enemies: Query<(&Unit, &mut Target, &Transform), With<EnemyUnit>>,
    grid: Res<GridConfig>,
    obstacles: Res<ObstacleGrid>,
    visibility_grid: Res<VisibilityGrid>,
) {
    let Ok((player_unit, player_transform)) = player.single() else {
        return;
    };

    let player_world = player_transform.translation.truncate();

    for (enemy_unit, mut target, enemy_transform) in enemies.iter_mut() {
        let enemy_world = enemy_transform.translation.truncate();
        let dist = (player_world - enemy_world).length();
        let vision_radius = visibility_grid.view_radius as f32 * grid.cell_size;

        // Always agro while player is inside view radius
        if dist > vision_radius {
            target.path.clear();
            target.path_index = 0;
            continue;
        }

        let destination = (player_unit.grid_x, player_unit.grid_y);
        let needs_repath = target.path.is_empty()
            || target.path_index >= target.path.len()
            || target.path.last().copied() != Some(destination);

        if needs_repath {
            let path = find_path(
                (enemy_unit.grid_x, enemy_unit.grid_y),
                destination,
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

/// Move all units (player and enemy) along their paths
pub fn unit_movement(
    mut query: Query<(&mut Unit, &mut Target, &mut Transform)>,
    grid: Res<GridConfig>,
    time: Res<Time>,
) {
    for (mut unit, mut target, mut transform) in query.iter_mut() {
        if target.path_index >= target.path.len() {
            continue;
        }

        let (nx, ny) = target.path[target.path_index];
        if nx == unit.grid_x && ny == unit.grid_y {
            target.path_index += 1;
            continue;
        }

        let target_pos = grid_to_world(nx, ny, &grid);
        let current_world = transform.translation.truncate();
        let dir = target_pos - current_world;
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

/// Draw path gizmos for debugging
pub fn draw_path(
    query: Query<&Target, With<PlayerUnit>>,
    grid: Res<GridConfig>,
    mut gizmos: Gizmos,
) {
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

/// Update waypoint markers appearance
pub fn draw_waypoints(
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

/// Check if player reached a waypoint
pub fn check_waypoint_reached(
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

// ==================== Console Commands ====================

#[derive(Serialize, Deserialize, Debug)]
struct ConsoleCommand {
    cmd: String,
    x: Option<usize>,
    y: Option<usize>,
    #[serde(default)]
    verify: Option<VerifyCommand>,
}

#[derive(Serialize, Deserialize, Debug)]
struct VerifyCommand {
    #[serde(rename = "type")]
    verify_type: String,
    x: Option<usize>,
    y: Option<usize>,
}

#[cfg(target_arch = "wasm32")]
pub fn read_console_commands(
    mut query: Query<(&mut Unit, &mut Target), With<PlayerUnit>>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    state: Res<GameState>,
) {
    use wasm_bindgen::prelude::*;
    #[wasm_bindgen]
    extern "C" {
        #[wasm_bindgen(js_namespace = localStorage)]
        fn getItem(key: &str) -> Option<String>;
        #[wasm_bindgen(js_namespace = localStorage)]
        fn removeItem(key: &str);
        #[wasm_bindgen(js_namespace = localStorage)]
        fn setItem(key: &str, value: &str);
    }

    let cmd_str = match getItem("dreamcraft_command") {
        Some(s) if !s.is_empty() => s,
        _ => return,
    };
    removeItem("dreamcraft_command");

    if let Ok(cmd) = serde_json::from_str(&cmd_str) {
        let result = handle_command(&mut query, &obstacles, &grid, &state, cmd);
        setItem("dreamcraft_command_result", &result.to_string());
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub fn read_stdin_commands(
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
            let result = handle_command(&mut query, &obstacles, &grid, &state, cmd);
            let _ = std::fs::write("headless_result.json", result.to_string());
            println!("RESULT: {}", result);
        }
    }
}

fn handle_command(
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

// ==================== Debug Output ====================

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

pub fn debug_console_output(
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
    use wasm_bindgen::prelude::*;
    #[wasm_bindgen]
    extern "C" {
        #[wasm_bindgen(js_namespace = localStorage)]
        fn setItem(key: &str, value: &str);
    }
    setItem("dreamcraft_debug_state", json);
}

#[cfg(not(target_arch = "wasm32"))]
fn broadcast_debug_state(_json: &str) {}

#[cfg(target_arch = "wasm32")]
pub fn broadcast_minimap_data(
    visibility: Res<VisibilityGrid>,
    obstacles: Res<ObstacleGrid>,
    grid: Res<GridConfig>,
    player: Query<&Unit, With<PlayerUnit>>,
    waypoints: Res<FogWaypoints>,
    mut frame: Local<u64>,
) {
    use wasm_bindgen::prelude::*;
    #[wasm_bindgen]
    extern "C" {
        #[wasm_bindgen(js_namespace = localStorage)]
        fn setItem(key: &str, value: &str);
    }

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
