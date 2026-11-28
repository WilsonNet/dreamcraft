#+build !js
package game

import "core:testing"

@(test)
path_open_grid_supports_diagonals :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16

	length, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{7, 7}, out[:])
	testing.expect_value(t, result, Path_Result.Found)
	testing.expect(t, length > 0)
	testing.expect(t, path_is_valid(&grid, Grid_Pos{0, 0}, out[:length], Grid_Pos{7, 7}))

	has_diagonal := false
	for i in 1..<length {
		a := cell_position(int(out[i - 1]))
		b := cell_position(int(out[i]))
		if a.x != b.x && a.y != b.y {
			has_diagonal = true
		}
	}
	testing.expect(t, has_diagonal, "open grid path should use diagonals")
}

@(test)
path_start_equals_goal :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	length, result := find_path(&pf, &grid, Grid_Pos{4, 4}, Grid_Pos{4, 4}, out[:])
	testing.expect_value(t, result, Path_Result.Found)
	testing.expect_value(t, length, 1)
	testing.expect_value(t, cell_position(int(out[0])), Grid_Pos{4, 4})
}

@(test)
path_rejects_blocked_goal :: proc(t: ^testing.T) {
	grid: Grid
	grid_block(&grid, Grid_Pos{4, 4})
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	_, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{4, 4}, out[:])
	testing.expect_value(t, result, Path_Result.Invalid_Goal)
}

@(test)
path_rejects_out_of_bounds :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	_, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{GRID_W, 3}, out[:])
	testing.expect_value(t, result, Path_Result.Invalid_Goal)
	_, result = find_path(&pf, &grid, Grid_Pos{-1, 0}, Grid_Pos{3, 3}, out[:])
	testing.expect_value(t, result, Path_Result.Invalid_Goal)
}

@(test)
path_rejects_small_output :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [2]u16
	_, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{10, 10}, out[:])
	testing.expect_value(t, result, Path_Result.Output_Too_Small)
}

@(test)
path_goes_around_obstacle :: proc(t: ^testing.T) {
	grid: Grid
	grid_block(&grid, Grid_Pos{5, 5})
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	length, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{9, 9}, out[:])
	testing.expect_value(t, result, Path_Result.Found)
	testing.expect(t, path_is_valid(&grid, Grid_Pos{0, 0}, out[:length], Grid_Pos{9, 9}))
	for i in 0..<length {
		testing.expect(t, cell_position(int(out[i])) != Grid_Pos{5, 5})
	}
}

@(test)
path_stops_at_wall :: proc(t: ^testing.T) {
	grid: Grid
	for y in 0..<GRID_H {
		grid_block(&grid, Grid_Pos{3, i32(y)})
	}
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	_, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{6, 0}, out[:])
	testing.expect_value(t, result, Path_Result.No_Path)
}

@(test)
path_is_deterministic :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	pf: Pathfinder
	pathfinder_reset(&pf)
	out_a: [MAX_PATH]u16
	out_b: [MAX_PATH]u16
	start := Grid_Pos{2, 25}
	goal := GOAL_POS
	len_a, result_a := find_path(&pf, &grid, start, goal, out_a[:])
	len_b, result_b := find_path(&pf, &grid, start, goal, out_b[:])
	testing.expect_value(t, result_a, Path_Result.Found)
	testing.expect_value(t, result_b, Path_Result.Found)
	testing.expect_value(t, len_a, len_b)
	testing.expect_value(t, len(out_a[:len_a]), len(out_b[:len_b]))
	for i in 0..<len_a {
		testing.expect_value(t, out_a[i], out_b[i])
	}
}

@(test)
path_level_is_solvable :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	length, result := find_path(&pf, &grid, START_POS, GOAL_POS, out[:])
	testing.expect_value(t, result, Path_Result.Found)
	testing.expect(t, path_is_valid(&grid, START_POS, out[:length], GOAL_POS))
}

@(test)
path_waypoints_are_reachable :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	previous := START_POS
	for point in WAYPOINT_START {
		length, result := find_path(&pf, &grid, previous, point, out[:])
		testing.expectf(t, result == .Found, "no path to %v", point)
		if result == .Found {
			testing.expect(t, path_is_valid(&grid, previous, out[:length], point))
		}
		previous = point
	}
}

@(test)
pathfinder_reuses_scratch_across_queries :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder
	pathfinder_reset(&pf)
	out: [MAX_PATH]u16
	for i in 0..<20 {
		goal := Grid_Pos{i32(i % 10), i32(i % 7)}
		length, result := find_path(&pf, &grid, Grid_Pos{0, 0}, goal, out[:])
		testing.expect_value(t, result, Path_Result.Found)
		testing.expect(t, length > 0)
	}
}

@(test)
pathfinder_self_initializes :: proc(t: ^testing.T) {
	grid: Grid
	pf: Pathfinder // deliberately not reset
	out: [MAX_PATH]u16
	length, result := find_path(&pf, &grid, Grid_Pos{0, 0}, Grid_Pos{4, 4}, out[:])
	testing.expect_value(t, result, Path_Result.Found)
	testing.expect(t, length > 0)
	testing.expect(t, path_is_valid(&grid, Grid_Pos{0, 0}, out[:length], Grid_Pos{4, 4}))
}
