#+build !js
package game

import "core:testing"

@(test)
units_spawn_and_destroy :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	handle, ok := unit_spawn(&units, &grid, .Player, Grid_Pos{1, 1})
	testing.expect(t, ok)
	testing.expect(t, handle_is_valid(handle))
	index, found := unit_index(&units, handle)
	testing.expect(t, found)
	testing.expect_value(t, index, 0)
	testing.expect_value(t, units.generation[index], u32(1))
	testing.expect_value(t, units.hp[index], u16(MAX_HP))
	testing.expect_value(t, units.alive_count, 1)
	testing.expect_value(t, units.free_count, MAX_UNITS - 1)

	unit_destroy(&units, index)
	_, found = unit_index(&units, handle)
	testing.expect(t, !found, "destroyed handle must be invalid")
	testing.expect_value(t, units.alive_count, 0)
	testing.expect_value(t, units.free_count, MAX_UNITS)
}

@(test)
unit_slot_reuse_bumps_generation :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	old, _ := unit_spawn(&units, &grid, .Player, Grid_Pos{1, 1})
	old_index, _ := unit_index(&units, old)
	unit_destroy(&units, old_index)

	fresh, ok := unit_spawn(&units, &grid, .Enemy, Grid_Pos{2, 2})
	testing.expect(t, ok)
	fresh_index, _ := unit_index(&units, fresh)
	testing.expect_value(t, fresh_index, old_index)
	testing.expect(t, fresh.generation != old.generation)
	_, stale_ok := unit_index(&units, old)
	testing.expect(t, !stale_ok)
}

@(test)
unit_spawn_rejects_blocked_and_out_of_bounds :: proc(t: ^testing.T) {
	grid: Grid
	grid_block(&grid, Grid_Pos{3, 3})
	units: Units
	units_reset(&units)
	_, ok := unit_spawn(&units, &grid, .Player, Grid_Pos{3, 3})
	testing.expect(t, !ok)
	_, ok = unit_spawn(&units, &grid, .Player, Grid_Pos{-1, 3})
	testing.expect(t, !ok)
	_, ok = unit_spawn(&units, &grid, .Player, Grid_Pos{GRID_W, 3})
	testing.expect(t, !ok)
	testing.expect_value(t, units.alive_count, 0)
	testing.expect_value(t, units.free_count, MAX_UNITS)
}

@(test)
unit_capacity_is_fixed :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	for i in 0..<MAX_UNITS {
		p := Grid_Pos{x = i32(i % GRID_W), y = i32(i / GRID_W)}
		_, ok := unit_spawn(&units, &grid, .Player, p)
		testing.expectf(t, ok, "spawn %d failed", i)
	}
	_, ok := unit_spawn(&units, &grid, .Player, Grid_Pos{1, 20})
	testing.expect(t, !ok, "spawn beyond capacity must fail")
	testing.expect_value(t, units.alive_count, MAX_UNITS)
	testing.expect_value(t, units.free_count, 0)
}

@(test)
unit_destroy_clears_attack_targets :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	player, _ := unit_spawn(&units, &grid, .Player, Grid_Pos{1, 1})
	enemy, _ := unit_spawn(&units, &grid, .Enemy, Grid_Pos{2, 1})
	player_index, _ := unit_index(&units, player)
	enemy_index, _ := unit_index(&units, enemy)
	units.attack_target[player_index] = enemy
	unit_destroy(&units, enemy_index)
	testing.expect(t, !handle_is_valid(units.attack_target[player_index]))
}

@(test)
unit_selection_counts_stay_consistent :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	a, _ := unit_spawn(&units, &grid, .Player, Grid_Pos{1, 1})
	b, _ := unit_spawn(&units, &grid, .Player, Grid_Pos{2, 1})
	a_index, _ := unit_index(&units, a)
	b_index, _ := unit_index(&units, b)

	unit_select(&units, a_index, false)
	testing.expect_value(t, units.selected_count, 1)
	unit_select(&units, b_index, true)
	testing.expect_value(t, units.selected_count, 2)
	unit_select_only(&units, b_index)
	testing.expect_value(t, units.selected_count, 1)
	testing.expect(t, units.selected[b_index])
	testing.expect(t, !units.selected[a_index])
	unit_clear_selection(&units)
	testing.expect_value(t, units.selected_count, 0)
}

@(test)
unit_path_copy_is_bounded :: proc(t: ^testing.T) {
	grid: Grid
	units: Units
	units_reset(&units)
	h, _ := unit_spawn(&units, &grid, .Player, Grid_Pos{0, 0})
	index, _ := unit_index(&units, h)
	too_long: [MAX_PATH + 1]u16
	testing.expect(t, !unit_set_path(&units, index, too_long[:], .Moving))
	testing.expect_value(t, units.path_len[index], 0)
	small := [3]u16{0, 1, 2}
	testing.expect(t, unit_set_path(&units, index, small[:], .Moving))
	testing.expect_value(t, units.path_len[index], 3)
	testing.expect_value(t, units.state[index], Unit_State.Moving)
}

@(test)
unit_handle_zero_is_invalid :: proc(t: ^testing.T) {
	units: Units
	units_reset(&units)
	_, ok := unit_index(&units, Unit_Handle{})
	testing.expect(t, !ok)
	_, ok = unit_index(&units, INVALID_HANDLE)
	testing.expect(t, !ok)
}
