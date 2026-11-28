// DreamCraft RTS - deterministic simulation constants.
//
// Design rules:
//   * Every array in the simulation is fixed-capacity.
//   * Simulation ticks are integer-only (Q16.16 fixed point).
//   * No simulation procedure may allocate memory.
package game

GRID_W :: 128
GRID_H :: 80
GRID_CELLS :: GRID_W * GRID_H
CELL_SIZE :: 32

WORLD_MIN_X :: -2048 // -(GRID_W * CELL_SIZE) / 2
WORLD_MIN_Y :: -1280 // -(GRID_H * CELL_SIZE) / 2
WORLD_MAX_X :: 2048
WORLD_MAX_Y :: 1280

TICK_RATE :: 60
TICKS_PER_SECOND :: TICK_RATE

VISION_RADIUS :: 6
WAYPOINT_REVEAL_RADIUS :: 10
WAYPOINT_REACH_RADIUS :: 3
WAYPOINT_COUNT :: 10

GOAL_X :: GRID_W - 3 // 125
START_POS :: Grid_Pos{2, 25}
GOAL_POS :: Grid_Pos{125, 41} // where the road enters the goal glade
ENEMY_START_POS :: Grid_Pos{76, 64} // Forty-Blades ambush glade

MAX_UNITS :: 256
MAX_PATH :: 512
MAX_COMMANDS :: 128

BASE_SPEED :: 105 // world units per second (~3.3 cells/s, a marching pace; multiple of 15 keeps the Q16.16 step exact)
BASE_ARMOR :: 0
ATTACK_DAMAGE :: 15
ATTACK_RANGE :: 3 // cells, Euclidean
ATTACK_COOLDOWN_TICKS :: 60

MAX_HP :: 100

HERO_SPEED :: 120 // heroic stride (~3.75 cells/s)
HERO_MAX_HP :: 500
HERO_ARMOR :: 5
HERO_ATTACK_DAMAGE :: 35
HERO_ATTACK_COOLDOWN_TICKS :: 40
HERO_REGEN_INTERVAL_TICKS :: 30 // +2 HP every 0.5s (+4 HP/s)
HERO_REGEN_AMOUNT :: 2

ENEMY_AGGRO_DELAY_TICKS :: 240 // 4.0s discovery grace before enemy charges
RESCUE_RADIUS :: 5 // player approach radius to rally stranded allies
RESCUE_CHAIN_RADIUS :: 6 // nearby neutral allies rally together as a squad
SQUAD_ALERT_RADIUS :: 4 // nearby enemy squadmates alert & retaliate together
CONTROL_GROUP_COUNT :: 10 // slots 0..9 (keys 1..9, 0)
CONTROL_GROUP_VALID_MASK :: u16((1 << CONTROL_GROUP_COUNT) - 1)
MAX_UNIT_ORDERS :: 8 // Shift-queued per-unit orders

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
	Neutral,
}

Race :: enum u8 {
	Basic,
	Akana,
	Gorg,
}

Unit_Kind :: enum u8 {
	Melee,
	Hero,
}

unit_kind_name :: proc(kind: Unit_Kind) -> string {
	switch kind {
	case .Melee:
		return "Luk Soldier"
	case .Hero:
		return "Liiroy, the Bold"
	}
	return "Luk Soldier"
}

Unit_State :: enum u8 {
	Idle,
	Moving,
	Patrol,
	Attack_Move,
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

// Level layout (road, clearings, forest) lives in level.odin. Waypoints sit on the road.
WAYPOINT_START := [WAYPOINT_COUNT]Grid_Pos{
	{12, 25},
	{20, 25}, // Squad 1 rescue
	{33, 13},
	{56, 14}, // Forward Scouts glade
	{43, 52}, // Squad 2 rescue
	{62, 72},
	{76, 64}, // Forty-Blades ambush
	{90, 23},
	{114, 26}, // Eastern Warband
	GOAL_POS,
}

// 5 stranded allies in 2 rescue squads along the road:
//   Squad 1 ("Vanguard Survivors", 3 soldiers) in the clearing at Waypoint 2 (20,25)
//   Squad 2 ("Bridge Watch", 2 soldiers) in the southern clearing (43,52)
ALLY_RESCUE_SPAWNS := [5]Grid_Pos{
	{19, 23}, {19, 27}, {21, 25},
	{44, 51}, {44, 53},
}

// 13 enemies in 4 escalating groups:
//   Group 1 ("Forward Scouts", 2) in the northern glade (56,14)
//   Group 2 ("Forty-Blades Ambush", 3) centered on ENEMY_START_POS (76,64)
//   Group 3 ("Road Sentries", 3) holding the road north at (83,42)
//   Group 4 ("Eastern Warband", 5) in the last glade before the goal (114,26)
ENEMY_SQUAD_SPAWNS := [13]Grid_Pos{
	{57, 13}, {57, 16},
	ENEMY_START_POS, {77, 63}, {77, 65},
	{83, 43}, {82, 41}, {84, 45},
	{114, 24}, {114, 26}, {114, 28}, {115, 25}, {115, 27},
}

INITIAL_UNIT_COUNT :: 1 + len(ALLY_RESCUE_SPAWNS) + len(ENEMY_SQUAD_SPAWNS)
