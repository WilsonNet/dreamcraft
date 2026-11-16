// Deterministic A* on the fixed grid.
//
// No allocation, no recursion, no floating point. The pathfinder owns all
// scratch memory and is reused for every query.
package game

Path_Result :: enum u8 {
	Found,
	No_Path,
	Invalid_Goal,
	Output_Too_Small,
}

Pathfinder :: struct {
	g_score: [GRID_CELLS]u16,
	h_score: [GRID_CELLS]u16,
	f_score: [GRID_CELLS]u32,
	parent: [GRID_CELLS]u16,
	seen_stamp: [GRID_CELLS]u32,
	closed_stamp: [GRID_CELLS]u32,
	heap: [GRID_CELLS]u16,
	heap_pos: [GRID_CELLS]i16,
	heap_len: int,
	stamp: u32,
	expanded: int,
	initialized: bool,
}

pathfinder_reset :: proc(pf: ^Pathfinder) {
	pf^ = {}
	for &position in pf.heap_pos {
		position = -1
	}
	pf.initialized = true
}

find_path :: proc(
	pf: ^Pathfinder,
	grid: ^Grid,
	start, goal: Grid_Pos,
	out: []u16,
) -> (length: int, result: Path_Result) {
	if !pf.initialized {
		pathfinder_reset(pf)
	}
	if !in_bounds(goal) || grid_is_blocked(grid, goal) {
		return 0, .Invalid_Goal
	}
	if !in_bounds(start) || grid_is_blocked(grid, start) {
		return 0, .Invalid_Goal
	}
	if cells_equal(start, goal) {
		if len(out) < 1 {
			return 0, .Output_Too_Small
		}
		index, _ := cell_index(start)
		out[0] = u16(index)
		return 1, .Found
	}

	pf.stamp += 1
	if pf.stamp == 0 {
		pf.seen_stamp = {}
		pf.closed_stamp = {}
		pf.stamp = 1
	}
	pf.heap_len = 0
	pf.expanded = 0

	start_index, _ := cell_index(start)
	goal_index, _ := cell_index(goal)
	pf.g_score[start_index] = 0
	pf.h_score[start_index] = heuristic(start, goal)
	pf.f_score[start_index] = u32(pf.h_score[start_index])
	pf.parent[start_index] = u16(start_index)
	pf.seen_stamp[start_index] = pf.stamp
	heap_push(pf, u16(start_index))

	for pf.heap_len > 0 {
		current := heap_pop_min(pf)
		current_index := int(current)
		if pf.closed_stamp[current_index] == pf.stamp {
			continue
		}
		pf.closed_stamp[current_index] = pf.stamp
		pf.expanded += 1

		if current_index == goal_index {
			length = reconstruct_path(pf, start_index, goal_index, out)
			pathfinder_clear_heap(pf)
			if length == 0 {
				return 0, .Output_Too_Small
			}
			return length, .Found
		}

		current_pos := cell_position(current_index)
		base_g := pf.g_score[current_index]
		for dy := i32(-1); dy <= 1; dy += 1 {
			for dx := i32(-1); dx <= 1; dx += 1 {
				if dx == 0 && dy == 0 {
					continue
				}
				neighbor := Grid_Pos{x = current_pos.x + dx, y = current_pos.y + dy}
				if !in_bounds(neighbor) {
					continue
				}
				neighbor_index, _ := cell_index(neighbor)
				if pf.closed_stamp[neighbor_index] == pf.stamp {
					continue
				}
				if grid_is_blocked(grid, neighbor) {
					continue
				}
				if dx != 0 && dy != 0 && diagonal_blocked(grid, current_pos, neighbor) {
					continue
				}

				step: u16 = 10
				if dx != 0 && dy != 0 {
					step = 14
				}
				tentative := base_g + step
				seen := pf.seen_stamp[neighbor_index] == pf.stamp
				if seen && tentative >= pf.g_score[neighbor_index] {
					continue
				}

				pf.seen_stamp[neighbor_index] = pf.stamp
				pf.g_score[neighbor_index] = tentative
				pf.h_score[neighbor_index] = heuristic(neighbor, goal)
				pf.f_score[neighbor_index] = u32(tentative) + u32(pf.h_score[neighbor_index])
				pf.parent[neighbor_index] = current
				heap_push_or_update(pf, u16(neighbor_index))
			}
		}
	}

	pathfinder_clear_heap(pf)
	return 0, .No_Path
}

@(private)
heuristic :: proc(a, b: Grid_Pos) -> u16 {
	dx := abs(a.x - b.x)
	dy := abs(a.y - b.y)
	min_d := min(dx, dy)
	max_d := max(dx, dy)
	return u16(min_d * 14 + (max_d - min_d) * 10)
}

@(private)
diagonal_blocked :: proc(grid: ^Grid, from, to: Grid_Pos) -> bool {
	side_a := Grid_Pos{x = from.x, y = to.y}
	side_b := Grid_Pos{x = to.x, y = from.y}
	return grid_is_blocked(grid, side_a) && grid_is_blocked(grid, side_b)
}

@(private)
reconstruct_path :: proc(pf: ^Pathfinder, start_index, goal_index: int, out: []u16) -> int {
	length := 0
	cursor := goal_index
	for {
		length += 1
		if cursor == start_index {
			break
		}
		parent := int(pf.parent[cursor])
		assert(parent != cursor, "A* parent cycle")
		cursor = parent
		if length > GRID_CELLS {
			assert(false, "A* path longer than grid")
			return 0
		}
	}
	if length > len(out) {
		return 0
	}
	cursor = goal_index
	for i := length - 1; i >= 0; i -= 1 {
		out[i] = u16(cursor)
		if cursor == start_index {
			break
		}
		cursor = int(pf.parent[cursor])
	}
	return length
}

@(private)
node_less :: proc(pf: ^Pathfinder, a, b: u16) -> bool {
	ai := int(a)
	bi := int(b)
	if pf.f_score[ai] != pf.f_score[bi] {
		return pf.f_score[ai] < pf.f_score[bi]
	}
	if pf.h_score[ai] != pf.h_score[bi] {
		return pf.h_score[ai] < pf.h_score[bi]
	}
	return a < b
}

@(private)
heap_push :: proc(pf: ^Pathfinder, cell: u16) {
	assert(pf.heap_len < GRID_CELLS, "A* heap overflow")
	index := pf.heap_len
	pf.heap[index] = cell
	pf.heap_pos[int(cell)] = i16(index)
	pf.heap_len += 1
	heap_sift_up(pf, index)
}

@(private)
heap_push_or_update :: proc(pf: ^Pathfinder, cell: u16) {
	position := pf.heap_pos[int(cell)]
	if position >= 0 {
		heap_sift_up(pf, int(position))
		return
	}
	heap_push(pf, cell)
}

@(private)
heap_sift_up :: proc(pf: ^Pathfinder, index: int) {
	child := index
	for child > 0 {
		parent := (child - 1) / 2
		if !node_less(pf, pf.heap[child], pf.heap[parent]) {
			break
		}
		heap_swap(pf, child, parent)
		child = parent
	}
}

@(private)
heap_pop_min :: proc(pf: ^Pathfinder) -> u16 {
	assert(pf.heap_len > 0)
	root := pf.heap[0]
	pf.heap_pos[int(root)] = -1
	pf.heap_len -= 1
	if pf.heap_len > 0 {
		pf.heap[0] = pf.heap[pf.heap_len]
		pf.heap_pos[int(pf.heap[0])] = 0
		heap_sift_down(pf, 0)
	}
	return root
}

@(private)
heap_sift_down :: proc(pf: ^Pathfinder, index: int) {
	parent := index
	for {
		left := parent * 2 + 1
		if left >= pf.heap_len {
			break
		}
		smallest := left
		right := left + 1
		if right < pf.heap_len && node_less(pf, pf.heap[right], pf.heap[left]) {
			smallest = right
		}
		if !node_less(pf, pf.heap[smallest], pf.heap[parent]) {
			break
		}
		heap_swap(pf, parent, smallest)
		parent = smallest
	}
}

@(private)
heap_swap :: proc(pf: ^Pathfinder, a, b: int) {
	pf.heap[a], pf.heap[b] = pf.heap[b], pf.heap[a]
	pf.heap_pos[int(pf.heap[a])] = i16(a)
	pf.heap_pos[int(pf.heap[b])] = i16(b)
}

@(private)
pathfinder_clear_heap :: proc(pf: ^Pathfinder) {
	for i := 0; i < pf.heap_len; i += 1 {
		pf.heap_pos[int(pf.heap[i])] = -1
	}
	pf.heap_len = 0
}

// Validation helper used by tests and by the runtime invariant checker.
path_is_valid :: proc(grid: ^Grid, start: Grid_Pos, path: []u16, goal: Grid_Pos) -> bool {
	if len(path) == 0 {
		return false
	}
	if !cells_equal(cell_position(int(path[0])), start) {
		return false
	}
	for i in 0..<len(path) {
		p := cell_position(int(path[i]))
		if !in_bounds(p) || grid_is_blocked(grid, p) {
			return false
		}
		if i > 0 && !cells_adjacent(cell_position(int(path[i - 1])), p) {
			return false
		}
	}
	return cells_equal(cell_position(int(path[len(path) - 1])), goal)
}
