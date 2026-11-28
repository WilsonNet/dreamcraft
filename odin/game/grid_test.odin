#+build !js
package game

import "core:testing"

@(test)
bit_grid_set_test_clear :: proc(t: ^testing.T) {
	bits: Bit_Grid
	testing.expect(t, !bit_grid_test(&bits, 0))
	bit_grid_set(&bits, 0)
	bit_grid_set(&bits, 63)
	bit_grid_set(&bits, 64)
	bit_grid_set(&bits, GRID_CELLS - 1)
	testing.expect(t, bit_grid_test(&bits, 0))
	testing.expect(t, bit_grid_test(&bits, 63))
	testing.expect(t, bit_grid_test(&bits, 64))
	testing.expect(t, bit_grid_test(&bits, GRID_CELLS - 1))
	testing.expect_value(t, bit_grid_count(&bits), 4)
	bit_grid_clear_cell(&bits, 64)
	testing.expect(t, !bit_grid_test(&bits, 64))
	testing.expect_value(t, bit_grid_count(&bits), 3)
	bit_grid_clear(&bits)
	testing.expect_value(t, bit_grid_count(&bits), 0)
}

@(test)
grid_level_obstacle_count :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	testing.expect_value(t, int(grid.obstacle_count), 8486)
	testing.expect_value(t, bit_grid_count(&grid.obstacles), 8486)
	testing.expect(t, !grid_is_blocked(&grid, START_POS))
	testing.expect(t, !grid_is_blocked(&grid, ENEMY_START_POS))
	testing.expect(t, grid_is_blocked(&grid, Grid_Pos{14, 20})) // woods north-east of the start camp
	testing.expect(t, !grid_is_blocked(&grid, GOAL_POS))
	for k in ROUTE_KNOTS {
		testing.expect(t, !grid_is_blocked(&grid, k), "road knots must be walkable")
	}
}

@(test)
grid_out_of_bounds_is_blocked :: proc(t: ^testing.T) {
	grid: Grid
	grid_init_level(&grid)
	testing.expect(t, grid_is_blocked(&grid, Grid_Pos{-1, 0}))
	testing.expect(t, grid_is_blocked(&grid, Grid_Pos{GRID_W, 0}))
	testing.expect(t, grid_is_blocked(&grid, Grid_Pos{0, GRID_H}))
	testing.expect(t, !grid_is_walkable(&grid, Grid_Pos{GRID_W, -1}))
}

@(test)
fog_reveal_marks_visible_and_explored :: proc(t: ^testing.T) {
	fog: Fog
	fog_reveal(&fog, Grid_Pos{10, 10}, 2)
	testing.expect_value(t, fog_state(&fog, Grid_Pos{10, 10}), u8(2))
	testing.expect_value(t, fog_state(&fog, Grid_Pos{12, 10}), u8(2))
	testing.expect_value(t, fog_state(&fog, Grid_Pos{13, 10}), u8(0))
	testing.expect(t, fog_is_visible(&fog, Grid_Pos{9, 11}))
	testing.expect(t, !fog_is_visible(&fog, Grid_Pos{13, 10}))
}

@(test)
fog_tick_clears_visible_but_keeps_explored :: proc(t: ^testing.T) {
	fog: Fog
	fog_reveal(&fog, Grid_Pos{10, 10}, 2)
	testing.expect_value(t, fog_explored_count(&fog), 13)
	fog_begin_tick(&fog)
	testing.expect_value(t, fog_state(&fog, Grid_Pos{10, 10}), u8(1))
	testing.expect_value(t, fog_explored_count(&fog), 13)
	testing.expect_value(t, validate_fog(&fog), Validation_Error.None)
}

@(test)
fog_reveal_clamps_at_edges :: proc(t: ^testing.T) {
	fog: Fog
	fog_reveal(&fog, Grid_Pos{0, 0}, 6)
	testing.expect_value(t, fog_state(&fog, Grid_Pos{0, 0}), u8(2))
	testing.expect(t, fog_explored_count(&fog) > 0)
	testing.expect(t, fog_explored_count(&fog) < 81)
}

@(test)
fog_coverage_starts_partial :: proc(t: ^testing.T) {
	game := new(Game)
	defer free(game)
	game_init(game)
	coverage := fog_coverage_percent(&game.fog)
	testing.expect(t, coverage > 80.0)
	testing.expect(t, coverage < 100.0)
}
