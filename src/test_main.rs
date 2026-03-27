use dreamcraft::{find_path, GridConfig};

fn main() {
    println!("=== DreamCraft Level 1 Headless Test ===\n");

    let grid = GridConfig::default();
    let obstacles = create_obstacle_grid(&grid);

    println!("Grid size: {}x{}", grid.grid_width, grid.grid_height);
    println!("Start: (2, {})", grid.grid_height / 2);
    println!(
        "Goal: ({}, {})\n",
        grid.grid_width - 2,
        grid.grid_height / 2
    );

    let start = (2, grid.grid_height / 2);
    let goal = (grid.grid_width - 3, grid.grid_height / 2);

    println!("Testing direct path from start to goal...");
    let direct_path = find_path(start, goal, &obstacles, grid.grid_width, grid.grid_height);

    if direct_path.is_empty() {
        println!("FAILED: No direct path found (level is unsolvable)");
        std::process::exit(1);
    }

    println!("Direct path found: {} steps\n", direct_path.len());

    let waypoints = vec![(10, 3), (20, 3), (25, 15), (30, 27), (35, 10)];

    println!("Testing waypoint navigation...");
    let mut current_pos = start;
    let mut total_path_length = 0;

    for (i, waypoint) in waypoints.iter().enumerate() {
        let path = find_path(
            current_pos,
            *waypoint,
            &obstacles,
            grid.grid_width,
            grid.grid_height,
        );

        if path.is_empty() {
            println!(
                "FAILED: No path from {:?} to {:?} (waypoint {})",
                current_pos,
                waypoint,
                i + 1
            );
            std::process::exit(1);
        }

        println!(
            "  Waypoint {}: {:?} -> {:?} ({} steps)",
            i + 1,
            current_pos,
            waypoint,
            path.len()
        );
        total_path_length += path.len();
        current_pos = *waypoint;
    }

    let final_path = find_path(
        current_pos,
        goal,
        &obstacles,
        grid.grid_width,
        grid.grid_height,
    );
    if final_path.is_empty() {
        println!("FAILED: No path from {:?} to goal {:?}", current_pos, goal);
        std::process::exit(1);
    }

    println!(
        "  Final leg: {:?} -> {:?} ({} steps)",
        current_pos,
        goal,
        final_path.len()
    );
    total_path_length += final_path.len();

    println!("\n=== TEST PASSED ===");
    println!("Total path length: {} steps", total_path_length);
    println!("Level is completable!");

    std::process::exit(0);
}

fn create_obstacle_grid(grid: &GridConfig) -> Vec<Vec<bool>> {
    let mut cells = vec![vec![false; grid.grid_height]; grid.grid_width];

    let tree_clusters: [[(i32, i32); 5]; 12] = [
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

    for cluster in tree_clusters.iter() {
        for &(gx, gy) in cluster {
            if gx > 0 && gx < grid.grid_width as i32 && gy < grid.grid_height as i32 {
                cells[gx as usize][gy as usize] = true;
            }
        }
    }

    cells
}
