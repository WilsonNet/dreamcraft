//! Unit systems: movement, commands, goal detection

use crate::core::*;
use crate::grid::grid_to_world;
use crate::pathfinding::find_path;
use bevy::prelude::*;
use serde::{Deserialize, Serialize};

/// Unit component with movement data
#[derive(Component)]
pub struct Unit {
    pub speed: f32,
    pub grid_x: usize,
    pub grid_y: usize,
}

/// Target destination with path
#[derive(Component)]
pub struct Target {
    pub path: Vec<(usize, usize)>,
    pub path_index: usize,
}

/// Spawn a unit (player or enemy)
pub fn spawn_unit(
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

/// Move units along their path
pub fn unit_movement(
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
