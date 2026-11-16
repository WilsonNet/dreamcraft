// DreamCraft RTS - deterministic simulation constants.
//
// Design rules:
//   * Every array in the simulation is fixed-capacity.
//   * Simulation ticks are integer-only (Q16.16 fixed point).
//   * No simulation procedure may allocate memory.
package game

GRID_W :: 80
GRID_H :: 50
GRID_CELLS :: GRID_W * GRID_H
CELL_SIZE :: 32

WORLD_MIN_X :: -1280 // -(GRID_W * CELL_SIZE) / 2
WORLD_MIN_Y :: -800 // -(GRID_H * CELL_SIZE) / 2
WORLD_MAX_X :: 1280
WORLD_MAX_Y :: 800

TICK_RATE :: 60
TICKS_PER_SECOND :: TICK_RATE

VISION_RADIUS :: 6
WAYPOINT_REVEAL_RADIUS :: 10
WAYPOINT_REACH_RADIUS :: 3
WAYPOINT_COUNT :: 8

GOAL_X :: GRID_W - 3 // 77
START_POS :: Grid_Pos{2, 25}
ENEMY_START_POS :: Grid_Pos{50, 25}

MAX_UNITS :: 256
MAX_PATH :: 512
MAX_COMMANDS :: 128

BASE_SPEED :: 150 // world units per second
ATTACK_DAMAGE :: 15
ATTACK_RANGE :: 3 // cells, Euclidean
ATTACK_COOLDOWN_TICKS :: 60

MAX_HP :: 100

// Set to false for release builds with -define:VALIDATE_EACH_TICK=false.
VALIDATE_EACH_TICK :: #config(VALIDATE_EACH_TICK, true)

Grid_Pos :: struct {
	x, y: i32,
}

Fixed_Vec :: struct {
	x, y: Fp,
}

Team :: enum u8 {
	Player,
	Enemy,
}

Race :: enum u8 {
	Basic,
	Akana,
	Gorg,
}

Unit_Kind :: enum u8 {
	Melee,
}

Unit_State :: enum u8 {
	Idle,
	Moving,
	Patrol,
}

Unit_Handle :: struct {
	index: u16,
	generation: u32,
}

INVALID_HANDLE :: Unit_Handle{index = 0xFFFF, generation = 0}

handle_is_valid :: proc(h: Unit_Handle) -> bool {
	return h.index != 0xFFFF && h.generation != 0
}

in_bounds :: proc(p: Grid_Pos) -> bool {
	return p.x >= 0 && p.x < GRID_W && p.y >= 0 && p.y < GRID_H
}

cell_index :: proc(p: Grid_Pos) -> (index: int, ok: bool) {
	if !in_bounds(p) {
		return 0, false
	}
	return int(p.y) * GRID_W + int(p.x), true
}

cell_position :: proc(index: int) -> Grid_Pos {
	assert(index >= 0 && index < GRID_CELLS)
	return Grid_Pos{x = i32(index % GRID_W), y = i32(index / GRID_W)}
}

cells_equal :: proc(a, b: Grid_Pos) -> bool {
	return a.x == b.x && a.y == b.y
}

cells_adjacent :: proc(a, b: Grid_Pos) -> bool {
	dx := abs(a.x - b.x)
	dy := abs(a.y - b.y)
	return dx <= 1 && dy <= 1 && (dx != 0 || dy != 0)
}

chebyshev :: proc(a, b: Grid_Pos) -> i32 {
	return max(abs(a.x - b.x), abs(a.y - b.y))
}

manhattan :: proc(a, b: Grid_Pos) -> i32 {
	return abs(a.x - b.x) + abs(a.y - b.y)
}

distance_squared :: proc(a, b: Grid_Pos) -> i32 {
	dx := a.x - b.x
	dy := a.y - b.y
	return dx * dx + dy * dy
}

// Tree cluster cells copied from the Rust level. {-1, -1} is an empty slot.
@(rodata)
TREE_CLUSTERS := [30][6]Grid_Pos{
	{{8, 20}, {9, 20}, {8, 21}, {9, 21}, {10, 20}, {10, 21}},
	{{15, 10}, {16, 10}, {15, 11}, {16, 11}, {-1, -1}, {-1, -1}},
	{{15, 40}, {16, 40}, {15, 41}, {16, 41}, {-1, -1}, {-1, -1}},
	{{22, 15}, {23, 15}, {22, 16}, {23, 16}, {24, 15}, {-1, -1}},
	{{22, 35}, {23, 35}, {22, 36}, {23, 36}, {24, 35}, {-1, -1}},
	{{30, 8}, {31, 8}, {30, 9}, {31, 9}, {32, 8}, {-1, -1}},
	{{30, 42}, {31, 42}, {30, 43}, {31, 43}, {32, 42}, {-1, -1}},
	{{38, 20}, {39, 20}, {38, 21}, {39, 21}, {40, 20}, {40, 21}},
	{{38, 30}, {39, 30}, {38, 31}, {39, 31}, {40, 30}, {40, 31}},
	{{45, 12}, {46, 12}, {45, 13}, {46, 13}, {-1, -1}, {-1, -1}},
	{{45, 38}, {46, 38}, {45, 39}, {46, 39}, {-1, -1}, {-1, -1}},
	{{52, 22}, {53, 22}, {52, 23}, {53, 23}, {54, 22}, {-1, -1}},
	{{52, 28}, {53, 28}, {52, 29}, {53, 29}, {54, 28}, {-1, -1}},
	{{58, 10}, {59, 10}, {58, 11}, {59, 11}, {60, 10}, {-1, -1}},
	{{58, 40}, {59, 40}, {58, 41}, {59, 41}, {60, 40}, {-1, -1}},
	{{65, 18}, {66, 18}, {65, 19}, {66, 19}, {-1, -1}, {-1, -1}},
	{{65, 32}, {66, 32}, {65, 33}, {66, 33}, {-1, -1}, {-1, -1}},
	{{72, 8}, {73, 8}, {72, 9}, {73, 9}, {-1, -1}, {-1, -1}},
	{{72, 42}, {73, 42}, {72, 43}, {73, 43}, {-1, -1}, {-1, -1}},
	{{25, 25}, {26, 25}, {25, 26}, {26, 26}, {-1, -1}, {-1, -1}},
	{{35, 25}, {36, 25}, {35, 26}, {36, 26}, {-1, -1}, {-1, -1}},
	{{48, 25}, {49, 25}, {48, 26}, {49, 26}, {-1, -1}, {-1, -1}},
	{{55, 15}, {56, 15}, {55, 16}, {-1, -1}, {-1, -1}, {-1, -1}},
	{{55, 35}, {56, 35}, {55, 36}, {-1, -1}, {-1, -1}, {-1, -1}},
	{{62, 25}, {63, 25}, {62, 26}, {63, 26}, {-1, -1}, {-1, -1}},
	{{18, 30}, {19, 30}, {18, 31}, {19, 31}, {-1, -1}, {-1, -1}},
	{{42, 12}, {43, 12}, {42, 13}, {43, 13}, {-1, -1}, {-1, -1}},
	{{42, 38}, {43, 38}, {42, 39}, {43, 39}, {-1, -1}, {-1, -1}},
	{{68, 25}, {69, 25}, {68, 26}, {69, 26}, {-1, -1}, {-1, -1}},
	{{12, 35}, {13, 35}, {12, 36}, {13, 36}, {-1, -1}, {-1, -1}},
}

WAYPOINT_START := [WAYPOINT_COUNT]Grid_Pos{
	{10, 25},
	{20, 25},
	{30, 25},
	{40, 23}, // moved from (40, 20): that cell is a tree
	{50, 25},
	{60, 25},
	{70, 25},
	{77, 25},
}
