use dreamcraft::{create_obstacle_grid, find_path, GridConfig};

#[test]
fn test_direct_path_exists() {
    let grid = GridConfig::default();
    let obstacles = create_obstacle_grid();

    let start = (2, grid.grid_height / 2);
    let goal = (grid.grid_width - 3, grid.grid_height / 2);

    let path = find_path(start, goal, &obstacles, grid.grid_width, grid.grid_height);

    assert!(
        !path.is_empty(),
        "No path found from start to goal - level is unsolvable!"
    );
    assert_eq!(
        path.first(),
        Some(&start),
        "Path should start at starting position"
    );
    assert_eq!(path.last(), Some(&goal), "Path should end at goal");
}

#[test]
fn test_waypoints_navigation() {
    let grid = GridConfig::default();
    let obstacles = create_obstacle_grid();

    let start = (2, grid.grid_height / 2);
    let waypoints = vec![(10, 5), (20, 5), (25, 15), (30, 25), (35, 15)];
    let goal = (grid.grid_width - 3, grid.grid_height / 2);

    let mut current = start;

    for waypoint in waypoints.iter().chain(std::iter::once(&goal)) {
        let path = find_path(
            current,
            *waypoint,
            &obstacles,
            grid.grid_width,
            grid.grid_height,
        );
        assert!(
            !path.is_empty(),
            "No path from {:?} to {:?}",
            current,
            waypoint
        );
        current = *waypoint;
    }
}

#[test]
fn test_obstacle_grid_created() {
    let grid = GridConfig::default();
    let obstacles = create_obstacle_grid();

    assert_eq!(obstacles.len(), grid.grid_width);
    assert_eq!(obstacles[0].len(), grid.grid_height);

    assert!(
        obstacles[2][grid.grid_height / 2] == false,
        "Start position should be free"
    );
    assert!(
        obstacles[grid.grid_width - 3][grid.grid_height / 2] == false,
        "Goal should be free"
    );
}

#[test]
fn test_no_path_through_single_obstacle() {
    let mut obstacles = vec![vec![false; 10]; 10];
    obstacles[5][5] = true;

    let path = find_path((0, 0), (9, 9), &obstacles, 10, 10);

    assert!(!path.is_empty(), "Should find path around obstacle");

    assert!(
        !path.contains(&(5, 5)),
        "Path should not go through obstacle"
    );
}

#[test]
fn test_path_length_reasonable() {
    let grid = GridConfig::default();
    let obstacles = create_obstacle_grid();

    let start = (2, grid.grid_height / 2);
    let goal = (grid.grid_width - 3, grid.grid_height / 2);

    let path = find_path(start, goal, &obstacles, grid.grid_width, grid.grid_height);

    let direct_distance =
        ((goal.0 as i32 - start.0 as i32).abs() + (goal.1 as i32 - start.1 as i32).abs()) as usize;

    assert!(
        path.len() < direct_distance * 3,
        "Path should not be excessively longer than direct route"
    );
}
