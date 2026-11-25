// High-resolution painterly ground texture, Catmull-Rom dirt trail,
// bilinear fog-of-war texture upload, and 3D ground shader binding.
package main

import "core:math"
import rl "../gfx"
import g "../game"

GROUND_TEX_SCALE :: 16
GROUND_TEX_W :: g.GRID_W * GROUND_TEX_SCALE
GROUND_TEX_H :: g.GRID_H * GROUND_TEX_SCALE
TRAIL_SEGMENTS :: 75

@(private)
Cluster_Bounds :: struct {
	min_x, max_x, min_y, max_y: f32,
}

init_ground :: proc() {
	app.ground_shader = load_ground_shader()
	app.ground_ready = rl.IsShaderValid(app.ground_shader)
	if app.ground_ready {
		app.ground_time = rl.GetShaderLocation(app.ground_shader, "u_time")
	}

	trail := build_trail_polyline()
	pixels := make([]rl.Color, GROUND_TEX_W * GROUND_TEX_H)
	defer delete(pixels)
	bake_ground_albedo(pixels, trail[:])

	img := rl.Image{
		data = raw_data(pixels), width = GROUND_TEX_W, height = GROUND_TEX_H,
		mipmaps = 1, format = .UNCOMPRESSED_R8G8B8A8,
	}
	app.ground_texture = rl.LoadTextureFromImage(img)
	rl.SetTextureFilter(app.ground_texture, .BILINEAR)
	rl.SetTextureWrap(app.ground_texture, .CLAMP)

	fog_img := rl.GenImageColor(g.GRID_W, g.GRID_H, rl.BLACK)
	app.fog_texture = rl.LoadTextureFromImage(fog_img)
	rl.UnloadImage(fog_img)
	rl.SetTextureFilter(app.fog_texture, .BILINEAR)
	rl.SetTextureWrap(app.fog_texture, .CLAMP)

	app.ground_model = rl.LoadModelFromMesh(rl.GenMeshPlane(f32(g.GRID_W), f32(g.GRID_H), 1, 1))
	rl.SetMaterialTexture(&app.ground_model.materials[0], .ALBEDO, app.ground_texture)
	rl.SetMaterialTexture(&app.ground_model.materials[0], .METALNESS, app.fog_texture)
	if app.ground_ready {
		app.ground_model.materials[0].shader = app.ground_shader
	}
	update_fog_texture()
}

unload_ground :: proc() {
	if app.ground_model.meshCount > 0 {
		mat := &app.ground_model.materials[0]
		mat.shader = {}
		if mat.maps != nil {
			mat.maps[rl.MaterialMapIndex.METALNESS].texture = {}
		}
		rl.UnloadModel(app.ground_model)
		app.ground_model = {}
	}
	app.ground_texture = {}
	if app.fog_texture.id > 0 {
		rl.UnloadTexture(app.fog_texture)
		app.fog_texture = {}
	}
	if app.ground_ready {
		rl.UnloadShader(app.ground_shader)
		app.ground_shader = {}
		app.ground_ready = false
	}
	app.ground_time = 0
}

update_fog_texture :: proc() {
	if app.fog_texture.id == 0 {
		return
	}
	for gy in 0..<g.GRID_H {
		for gx in 0..<g.GRID_W {
			state := g.fog_state(&app.game.fog, g.Grid_Pos{x = i32(gx), y = i32(gy)})
			v: u8 = 0
			if state == 1 {
				v = 128
			} else if state == 2 {
				v = 255
			}
			app.fog_pixels[gy * g.GRID_W + gx] = rl.Color{v, v, v, 255}
		}
	}
	rl.UpdateTexture(app.fog_texture, raw_data(app.fog_pixels[:]))
	app.fog_last_tick = app.game.tick
	app.fog_dirty = false
}

draw_ground_3d :: proc() {
	if app.ground_model.meshCount == 0 {
		return
	}
	if app.ground_ready && app.ground_time >= 0 {
		t := f32(rl.GetTime())
		rl.SetShaderValue(app.ground_shader, app.ground_time, &t, .FLOAT)
	}
	rl.DrawModel(app.ground_model, rl.Vector3{0, 0, 0}, 1, rl.WHITE)
}

@(private)
load_ground_shader :: proc() -> rl.Shader {
	// embedded GPU program (gfx/shaders/ground.*), selected by its historical file name
	shader := rl.LoadShader(nil, "ground.fs")
	return rl.IsShaderValid(shader) ? shader : {}
}

@(private)
build_trail_polyline :: proc() -> [TRAIL_SEGMENTS + 1][2]f32 {
	knots := [18][2]f32{
		{2.5, 25.5}, {10.5, 25.5}, {16.8, 24.4},
		{20.5, 25.5}, {25.8, 22.6}, {30.5, 25.5},
		{35.8, 28.4}, {40.5, 23.5}, {45.0, 22.6},
		{48.8, 22.5}, {50.7, 25.4}, {53.5, 25.7},
		{60.5, 25.5}, {63.0, 28.5}, {66.0, 25.6},
		{68.8, 22.5}, {70.7, 25.4}, {77.5, 25.5},
	}
	pts: [TRAIL_SEGMENTS + 1][2]f32
	spans := f32(len(knots) - 1)
	for i in 0..=TRAIL_SEGMENTS {
		u := (f32(i) / f32(TRAIL_SEGMENTS)) * spans
		seg := min(int(u), len(knots) - 2)
		lt := u - f32(seg)
		p1 := knots[seg]
		p2 := knots[seg + 1]
		p0 := seg > 0 ? knots[seg - 1] : [2]f32{2 * p1.x - p2.x, 2 * p1.y - p2.y}
		p3 := seg + 2 < len(knots) ? knots[seg + 2] : [2]f32{2 * p2.x - p1.x, 2 * p2.y - p1.y}
		pts[i] = catmull_rom_2d(p0, p1, p2, p3, lt)
	}
	return pts
}

@(private)
catmull_rom_2d :: proc(p0, p1, p2, p3: [2]f32, t: f32) -> [2]f32 {
	t2 := t * t
	t3 := t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
}

@(private)
build_cluster_bounds :: proc() -> [len(g.TREE_CLUSTERS)]Cluster_Bounds {
	bounds: [len(g.TREE_CLUSTERS)]Cluster_Bounds
	for cluster, ci in g.TREE_CLUSTERS {
		b := Cluster_Bounds{min_x = 999, max_x = -999, min_y = 999, max_y = -999}
		for cell in cluster {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			cx := f32(cell.x) + 0.5
			cy := f32(cell.y) + 0.5
			b.min_x = min(b.min_x, cx)
			b.max_x = max(b.max_x, cx)
			b.min_y = min(b.min_y, cy)
			b.max_y = max(b.max_y, cy)
		}
		bounds[ci] = b
	}
	return bounds
}

@(private)
nearest_tree_dist :: proc(gx, gy: f32, bounds: []Cluster_Bounds) -> f32 {
	best_d2 := f32(64.0)
	PAD :: f32(3.4)
	for ci in 0..<len(g.TREE_CLUSTERS) {
		b := bounds[ci]
		if gx < b.min_x - PAD || gx > b.max_x + PAD || gy < b.min_y - PAD || gy > b.max_y + PAD {
			continue
		}
		for cell in g.TREE_CLUSTERS[ci] {
			if cell.x < 0 || cell.y < 0 {
				continue
			}
			dx := gx - (f32(cell.x) + 0.5)
			dy := gy - (f32(cell.y) + 0.5)
			best_d2 = min(best_d2, dx * dx + dy * dy)
		}
	}
	return math.sqrt(best_d2)
}

@(private)
nearest_trail_dist :: proc(gx, gy: f32, trail: [][2]f32) -> f32 {
	if gy < 17.5 || gy > 33.5 {
		return 10.0
	}
	best_d2 := f32(64.0)
	for i in 0..<TRAIL_SEGMENTS {
		a := trail[i]
		b := trail[i + 1]
		if gx < min(a.x, b.x) - 3.0 || gx > max(a.x, b.x) + 3.0 {
			continue
		}
		best_d2 = min(best_d2, seg_dist_sq(gx, gy, a.x, a.y, b.x, b.y))
	}
	return math.sqrt(best_d2)
}

@(private)
seg_dist_sq :: proc(px, py, ax, ay, bx, by: f32) -> f32 {
	vx := bx - ax
	vy := by - ay
	len2 := vx * vx + vy * vy
	t: f32 = 0
	if len2 > 0.00001 {
		t = clamp(((px - ax) * vx + (py - ay) * vy) / len2, 0, 1)
	}
	dx := px - (ax + vx * t)
	dy := py - (ay + vy * t)
	return dx * dx + dy * dy
}

@(private)
bake_ground_albedo :: proc(pixels: []rl.Color, trail: [][2]f32) {
	bounds := build_cluster_bounds()
	for py in 0..<GROUND_TEX_H {
		gy := (f32(py) + 0.5) / f32(GROUND_TEX_SCALE)
		row := py * GROUND_TEX_W
		for px in 0..<GROUND_TEX_W {
			gx := (f32(px) + 0.5) / f32(GROUND_TEX_SCALE)
			pixels[row + px] = ground_albedo_pixel(gx, gy, trail, bounds[:])
		}
	}
}

@(private)
ground_albedo_pixel :: proc(gx, gy: f32, trail: [][2]f32, bounds: []Cluster_Bounds) -> rl.Color {
	d_tree := nearest_tree_dist(gx, gy, bounds)
	d_trail := nearest_trail_dist(gx, gy, trail)
	col := meadow_color(gx, gy)
	col = apply_forest_floor(col, gx, gy, d_tree)
	col = apply_trail_color(col, gx, gy, d_trail, d_tree)
	col = apply_wildflowers(col, gx, gy, d_tree, d_trail)
	col = apply_sanctuary_color(col, gx, gy, d_tree)
	return rgb_to_color(col)
}

@(private)
meadow_color :: proc(gx, gy: f32) -> [3]f32 {
	broad := fbm2(gx * 0.11 + 3.1, gy * 0.11 + 7.4)
	stroke := fbm2(gx * 0.42 + gy * 0.14, gy * 0.62 - gx * 0.16)
	tuft := vnoise2(gx * 2.35, gy * 2.35)
	cool_sage := [3]f32{0.31, 0.47, 0.22}
	warm_meadow := [3]f32{0.44, 0.60, 0.27}
	sun_chartreuse := [3]f32{0.58, 0.71, 0.32}
	col := mix3(cool_sage, warm_meadow, smooth_step(0.26, 0.76, broad * 0.65 + stroke * 0.35))
	col = mix3(col, sun_chartreuse, smooth_step(0.52, 0.88, broad * 0.55 + stroke * 0.45) * 0.62)
	blade := (tuft - 0.5) * 0.055
	return col + [3]f32{blade * 0.85, blade, blade * 0.55}
}

@(private)
apply_forest_floor :: proc(base: [3]f32, gx, gy, d_tree: f32) -> [3]f32 {
	if d_tree > 2.3 {
		return base
	}
	n := fbm2(gx * 1.45 + 11.2, gy * 1.45 + 5.7)
	dapple := vnoise2(gx * 2.8 + 4.0, gy * 2.8 + 9.0)
	wobbled := d_tree + (n - 0.5) * 0.46
	moss_mask := 1.0 - smooth_step(0.75, 1.90, wobbled)
	humus_mask := 1.0 - smooth_step(0.35, 0.92, wobbled)
	moss := mix3([3]f32{0.23, 0.38, 0.19}, [3]f32{0.34, 0.48, 0.23}, dapple)
	humus := mix3([3]f32{0.24, 0.19, 0.13}, [3]f32{0.19, 0.29, 0.17}, n * 0.65)
	return mix3(mix3(base, moss, moss_mask * 0.88), humus, humus_mask * 0.86)
}

@(private)
apply_trail_color :: proc(base: [3]f32, gx, gy, d_trail, d_tree: f32) -> [3]f32 {
	if d_trail > 1.45 {
		return base
	}
	wobble := (fbm2(gx * 1.85 + 1.9, gy * 1.85 + 8.3) - 0.5) * 0.34 + (vnoise2(gx * 5.2, gy * 5.2) - 0.5) * 0.16
	d := d_trail + wobble
	clear := smooth_step(0.65, 1.35, d_tree) * (1.0 - smooth_step(f32(g.GOAL_X) - 0.65, f32(g.GOAL_X) - 0.15, gx))
	shoulder := (1.0 - smooth_step(0.46, 0.74, d)) * clear
	center := (1.0 - smooth_step(0.14, 0.48, d)) * clear
	pebble := (vnoise2(gx * 9.5 + 3.2, gy * 9.5 + 1.4) - 0.5) * 0.13 + (vnoise2(gx * 19.0, gy * 19.0) - 0.5) * 0.08
	road := mix3([3]f32{0.58, 0.49, 0.32}, [3]f32{0.77, 0.65, 0.45}, smooth_step(0.15, 0.85, center))
	road += [3]f32{pebble, pebble * 0.92, pebble * 0.75}
	return mix3(base, road, shoulder * 0.94)
}

@(private)
apply_wildflowers :: proc(base: [3]f32, gx, gy, d_tree, d_trail: f32) -> [3]f32 {
	if d_tree < 1.15 || d_tree > 3.60 || d_trail < 1.10 || gx >= f32(g.GOAL_X) - 0.6 {
		return base
	}
	CELL_SCALE :: f32(2.40)
	sx := gx * CELL_SCALE
	sy := gy * CELL_SCALE
	ix := math.floor(sx)
	iy := math.floor(sy)
	patch := fbm2(gx * 0.32 + 21.0, gy * 0.32 + 13.0)
	seed := hash2(ix, iy)
	if patch < 0.46 || seed < 0.86 {
		return base
	}
	fx := ix + 0.25 + hash2(ix + 17.0, iy + 31.0) * 0.50
	fy := iy + 0.25 + hash2(ix + 53.0, iy + 11.0) * 0.50
	bloom := 1.0 - smooth_step(0.055, 0.125, math.hypot(sx - fx, sy - fy))
	if bloom <= 0.001 {
		return base
	}
	flower := [3]f32{0.92, 0.81, 0.34}
	if seed > 0.94 {
		flower = [3]f32{0.58, 0.70, 0.88}
	} else if seed > 0.90 {
		flower = [3]f32{0.94, 0.91, 0.82}
	}
	return mix3(base, flower, bloom * 0.78)
}

@(private)
apply_sanctuary_color :: proc(base: [3]f32, gx, gy, d_tree: f32) -> [3]f32 {
	border_x := f32(g.GOAL_X) - 0.2
	if gx < border_x - 0.45 {
		return base
	}
	wobble := (vnoise2(gx * 2.4, gy * 2.4) - 0.5) * 0.14
	gold_mask := smooth_step(border_x + 0.05, border_x + 0.55, gx + wobble)
	broad := fbm2(gx * 0.45 + 5.0, gy * 0.45 + 19.0)
	tuft := vnoise2(gx * 3.8, gy * 3.8)
	wheat := mix3([3]f32{0.54, 0.59, 0.26}, [3]f32{0.78, 0.69, 0.34}, broad * 0.68 + tuft * 0.32)
	wheat = mix3(wheat, [3]f32{0.42, 0.52, 0.24}, (1.0 - smooth_step(0.6, 1.5, d_tree)) * 0.55)
	col := mix3(base, wheat, gold_mask * 0.84)

	edge_dist := abs(gx - (border_x + 0.18) + (vnoise2(gx * 1.8, gy * 1.8) - 0.5) * 0.12)
	if edge_dist > 0.42 {
		return col
	}
	row_y := gy * 1.8
	row_idx := math.floor(row_y)
	col_off: f32 = (int(row_idx) & 1) == 1 ? 0.5 : 0.0
	fy := row_y - row_idx
	sx := (gx - border_x) * 2.1 + col_off
	stone_col := math.floor(sx)
	fx := sx - stone_col
	mortar := smooth_step(0.06, 0.14, fy) * (1.0 - smooth_step(0.86, 0.94, fy))
	mortar *= smooth_step(0.07, 0.16, fx) * (1.0 - smooth_step(0.84, 0.93, fx))
	stone := mix3([3]f32{0.58, 0.54, 0.46}, [3]f32{0.78, 0.75, 0.65}, hash2(stone_col, row_idx))
	mosaic := mix3([3]f32{0.39, 0.46, 0.27}, stone, mortar)
	return mix3(col, mosaic, 1.0 - smooth_step(0.24, 0.42, edge_dist))
}

@(private)
hash2 :: proc(x, y: f32) -> f32 {
	s := math.sin(x * 127.1 + y * 311.7) * 43758.5453123
	return s - math.floor(s)
}

@(private)
vnoise2 :: proc(x, y: f32) -> f32 {
	ix := math.floor(x)
	iy := math.floor(y)
	fx := x - ix
	fy := y - iy
	ux := fx * fx * (3.0 - 2.0 * fx)
	uy := fy * fy * (3.0 - 2.0 * fy)
	ab := hash2(ix, iy) + (hash2(ix + 1.0, iy) - hash2(ix, iy)) * ux
	cd := hash2(ix, iy + 1.0) + (hash2(ix + 1.0, iy + 1.0) - hash2(ix, iy + 1.0)) * ux
	return ab + (cd - ab) * uy
}

@(private)
fbm2 :: proc(x, y: f32) -> f32 {
	return vnoise2(x, y) * 0.55 + vnoise2(x * 2.03 + 13.7, y * 2.03 + 29.1) * 0.30 + vnoise2(x * 4.11 + 41.3, y * 4.11 + 17.9) * 0.15
}

@(private)
smooth_step :: proc(edge0, edge1, x: f32) -> f32 {
	t := clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
}

@(private)
mix3 :: proc(a, b: [3]f32, t: f32) -> [3]f32 {
	return a + (b - a) * clamp(t, 0.0, 1.0)
}

@(private)
rgb_to_color :: proc(c: [3]f32) -> rl.Color {
	return rl.Color{
		u8(clamp(c[0] * 255.0 + 0.5, 0.0, 255.0)),
		u8(clamp(c[1] * 255.0 + 0.5, 0.0, 255.0)),
		u8(clamp(c[2] * 255.0 + 0.5, 0.0, 255.0)),
		255,
	}
}
