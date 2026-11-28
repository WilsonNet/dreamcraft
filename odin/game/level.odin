// Tutorial Level 1, "Through the Woods": a winding forest road through dense woods.
//
// Everything that is not the road, a clearing, or the eastern goal glade is forest, so the march
// follows the road (no straight-line shortcut to the goal). The road is a polyline of knots shared
// with the client, which paints the dirt trail along the same knots. Carving is integer-only so
// every platform builds the same grid (and the same state hash).
package game

// Road centre line, west to east, in cell coordinates. Each knot cell is walkable.
@(rodata)
ROUTE_KNOTS := [?]Grid_Pos{
	{1, 25}, // start camp
	{12, 25},
	{20, 25}, // Squad 1 rescue clearing
	{28, 21},
	{33, 12},
	{45, 8},
	{56, 14}, // Forward Scouts glade
	{59, 27},
	{51, 40},
	{43, 52}, // Bridge Watch rescue clearing
	{48, 65},
	{62, 72},
	{76, 64}, // Forty-Blades ambush glade
	{84, 52},
	{83, 38}, // Road Sentries
	{90, 23},
	{103, 15},
	{114, 26}, // Eastern Warband glade
	{117, 39},
	{127, 41}, // goal glade
}

// Road half-width is sqrt(ROAD_R2_BASE .. ROAD_R2_BASE + ROAD_R2_JITTER - 1) cells: 5-7 cells wide.
ROAD_R2_BASE :: 6
ROAD_R2_JITTER :: 5

Clearing :: struct {
	center: Grid_Pos,
	radius: i32,
}

@(rodata)
LEVEL_CLEARINGS := [?]Clearing{
	{{5, 25}, 6}, // start camp
	{{20, 25}, 6}, // Squad 1
	{{56, 14}, 5}, // scouts
	{{43, 52}, 5}, // Squad 2
	{{76, 64}, 6}, // ambush
	{{83, 42}, 4}, // sentries
	{{114, 26}, 6}, // warband
	{{124, 41}, 5}, // goal glade
}

@(private = "file")
level_hash :: proc(x, y: i32) -> u32 {
	n := u32(x) * 374761393 + u32(y) * 668265263 + 0x9e3779b9
	n = (n ~ (n >> 13)) * 1274126177
	return n ~ (n >> 16)
}

// Squared distance from cell p to segment ab, times |ab|^2 (exact integer, no division).
// Returns the scaled distance and the scale.
@(private = "file")
segment_dist2_scaled :: proc(p, a, b: Grid_Pos) -> (num: i64, den: i64) {
	vx := i64(b.x - a.x)
	vy := i64(b.y - a.y)
	px := i64(p.x - a.x)
	py := i64(p.y - a.y)
	len2 := vx * vx + vy * vy
	if len2 == 0 {
		return px * px + py * py, 1
	}
	dot := px * vx + py * vy
	if dot <= 0 {
		return px * px + py * py, 1
	}
	if dot >= len2 {
		qx := i64(p.x - b.x)
		qy := i64(p.y - b.y)
		return qx * qx + qy * qy, 1
	}
	// |p|^2 - dot^2/len2, scaled by len2
	return (px * px + py * py) * len2 - dot * dot, len2
}

// True when the cell lies on the road (with a ragged, deterministic edge).
level_cell_on_road :: proc(p: Grid_Pos) -> bool {
	r2 := i64(ROAD_R2_BASE + i32(level_hash(p.x, p.y) % ROAD_R2_JITTER))
	for i in 0..<len(ROUTE_KNOTS) - 1 {
		a := ROUTE_KNOTS[i]
		b := ROUTE_KNOTS[i + 1]
		if p.x < min(a.x, b.x) - 3 || p.x > max(a.x, b.x) + 3 || p.y < min(a.y, b.y) - 3 || p.y > max(a.y, b.y) + 3 {
			continue
		}
		num, den := segment_dist2_scaled(p, a, b)
		if num <= r2 * den {
			return true
		}
	}
	return false
}

level_cell_in_clearing :: proc(p: Grid_Pos) -> bool {
	jitter := i32(level_hash(p.x + 7, p.y + 3) % 4)
	for c in LEVEL_CLEARINGS {
		r := c.radius
		if distance_squared(p, c.center) <= r * r + jitter * 2 - 2 {
			return true
		}
	}
	return false
}

level_cell_is_forest :: proc(p: Grid_Pos) -> bool {
	return !level_cell_on_road(p) && !level_cell_in_clearing(p)
}

grid_init_level :: proc(grid: ^Grid) {
	grid_reset(grid)
	for y in 0..<i32(GRID_H) {
		for x in 0..<i32(GRID_W) {
			p := Grid_Pos{x, y}
			if level_cell_is_forest(p) {
				index, _ := cell_index(p)
				bit_grid_set(&grid.obstacles, index)
			}
		}
	}
	grid.obstacle_count = u16(bit_grid_count(&grid.obstacles))
}
