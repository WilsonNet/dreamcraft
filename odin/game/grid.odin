// Flat grid storage. Obstacles and fog use bitsets, not arrays of vectors.
package game

BIT_WORDS :: (GRID_CELLS + 63) / 64

Bit_Grid :: struct {
	words: [BIT_WORDS]u64,
}

bit_grid_clear :: proc(grid: ^Bit_Grid) {
	grid.words = {}
}

bit_grid_set :: proc(grid: ^Bit_Grid, index: int) {
	assert(index >= 0 && index < GRID_CELLS)
	word := index / 64
	bit := uint(index % 64)
	grid.words[word] |= u64(1) << bit
}

bit_grid_clear_cell :: proc(grid: ^Bit_Grid, index: int) {
	assert(index >= 0 && index < GRID_CELLS)
	word := index / 64
	bit := uint(index % 64)
	grid.words[word] &~= u64(1) << bit
}

bit_grid_test :: proc(grid: ^Bit_Grid, index: int) -> bool {
	assert(index >= 0 && index < GRID_CELLS)
	word := index / 64
	bit := uint(index % 64)
	return (grid.words[word] & (u64(1) << bit)) != 0
}

bit_grid_count :: proc(grid: ^Bit_Grid) -> int {
	count := 0
	for word in grid.words {
		count += int(popcount(word))
	}
	return count
}

popcount :: proc(word: u64) -> u32 {
	count: u32
	value := word
	for value != 0 {
		value &= value - 1
		count += 1
	}
	return count
}

Grid :: struct {
	obstacles: Bit_Grid,
	obstacle_count: u16,
}

grid_reset :: proc(grid: ^Grid) {
	grid^ = {}
}

grid_block :: proc(grid: ^Grid, p: Grid_Pos) {
	index, ok := cell_index(p)
	assert(ok, "grid_block out of bounds")
	if !bit_grid_test(&grid.obstacles, index) {
		bit_grid_set(&grid.obstacles, index)
		grid.obstacle_count += 1
	}
}

grid_is_blocked :: proc(grid: ^Grid, p: Grid_Pos) -> bool {
	index, ok := cell_index(p)
	if !ok {
		return true
	}
	return bit_grid_test(&grid.obstacles, index)
}

grid_is_walkable :: proc(grid: ^Grid, p: Grid_Pos) -> bool {
	return in_bounds(p) && !grid_is_blocked(grid, p)
}

// Fog holds two bits per cell:
//   explored: seen at least once
//   visible:  inside a vision radius this tick
Fog :: struct {
	explored: Bit_Grid,
	visible: Bit_Grid,
}

fog_reset :: proc(fog: ^Fog) {
	fog^ = {}
}

fog_begin_tick :: proc(fog: ^Fog) {
	bit_grid_clear(&fog.visible)
}

fog_reveal :: proc(fog: ^Fog, center: Grid_Pos, radius: i32) {
	assert(radius >= 0, "negative vision radius")
	r2 := radius * radius
	for dy := -radius; dy <= radius; dy += 1 {
		for dx := -radius; dx <= radius; dx += 1 {
			if dx * dx + dy * dy > r2 {
				continue
			}
			p := Grid_Pos{x = center.x + dx, y = center.y + dy}
			index, ok := cell_index(p)
			if !ok {
				continue
			}
			bit_grid_set(&fog.explored, index)
			bit_grid_set(&fog.visible, index)
		}
	}
}

fog_mark_explored :: proc(fog: ^Fog, center: Grid_Pos, radius: i32) {
	assert(radius >= 0, "negative reveal radius")
	r2 := radius * radius
	for dy := -radius; dy <= radius; dy += 1 {
		for dx := -radius; dx <= radius; dx += 1 {
			if dx * dx + dy * dy > r2 {
				continue
			}
			p := Grid_Pos{x = center.x + dx, y = center.y + dy}
			index, ok := cell_index(p)
			if ok {
				bit_grid_set(&fog.explored, index)
			}
		}
	}
}

// 0 = unexplored, 1 = explored, 2 = visible.
fog_state :: proc(fog: ^Fog, p: Grid_Pos) -> u8 {
	index, ok := cell_index(p)
	if !ok {
		return 0
	}
	if bit_grid_test(&fog.visible, index) {
		return 2
	}
	if bit_grid_test(&fog.explored, index) {
		return 1
	}
	return 0
}

fog_is_visible :: proc(fog: ^Fog, p: Grid_Pos) -> bool {
	return fog_state(fog, p) == 2
}

fog_explored_count :: proc(fog: ^Fog) -> int {
	return bit_grid_count(&fog.explored)
}

fog_coverage_percent :: proc(fog: ^Fog) -> f32 {
	revealed := fog_explored_count(fog)
	return (f32(GRID_CELLS - revealed) / f32(GRID_CELLS)) * 100.0
}
