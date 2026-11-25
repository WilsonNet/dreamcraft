package gfx

import "core:c"
import "core:math"
import "core:mem"

// Drawing modes, the immediate-mode batch (rlgl's Begin/Vertex/End) and raylib's shapes.

@(private)
Imm_Vertex :: struct {
	pos: [3]f32,
	uv:  [2]f32,
	col: Color,
}

@(private)
Imm :: struct {
	active: bool,
	prim:   int, // LINES, TRIANGLES, QUADS
	verts:  [dynamic]Imm_Vertex,
	color:  Color,
	uv:     [2]f32,
	tex:    u32,
}

@(private)
IM: Imm

IM_LINES :: 0x0001
IM_TRIANGLES :: 0x0004
IM_QUADS :: 0x0007

CULL_NEAR :: 0.05
CULL_FAR :: 4000.0

// ------------------------------------------------------------------ modes

BeginDrawing :: proc() {
	if G.dev == nil {
		return
	}
	G.drawing = true
	target_ensure(0, int(GetRenderWidth()), int(GetRenderHeight()))
	pass_begin(0, false, {})
	set_2d()
}

EndDrawing :: proc() {
	if G.dev == nil {
		end_frame_timing()
		return
	}
	pass_end()
	replay(true)
	G.drawing = false
	end_frame_timing()
}

ClearBackground :: proc(color: Color) {
	if G.pass < 0 {
		return
	}
	cc := [4]f32{f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255}
	p := &G.passes[G.pass]
	if p.count == 0 {
		p.clear = true
		p.clear_color = cc
		return
	}
	target := p.target
	pass_end()
	pass_begin(target, true, cc)
}

BeginTextureMode :: proc(target: RenderTexture2D) {
	if G.dev == nil || int(target.id) <= 0 || int(target.id) >= len(G.targets) {
		return
	}
	if G.pass >= 0 {
		pass_end()
	}
	G.tex_mode = int(target.id)
	pass_begin(int(target.id), false, {})
	G.mode3d = false
	set_2d()
}

EndTextureMode :: proc() {
	if G.tex_mode < 0 {
		return
	}
	pass_end()
	G.tex_mode = -1
	G.mode3d = false
	if G.drawing {
		pass_begin(0, false, {})
		set_2d()
	}
}

@(private)
set_2d :: proc() {
	w, h: f32
	if G.pass >= 0 && G.passes[G.pass].target == 0 {
		w, h = f32(GetScreenWidth()), f32(GetScreenHeight())
	} else {
		tw, th := current_target_size()
		w, h = f32(tw), f32(th)
	}
	G.proj = MatrixOrtho(0, w, h, 0, 0, 1)
	G.view = Matrix(1)
}

@(private)
camera_projection :: proc(camera: Camera3D, aspect: f32) -> Matrix {
	if camera.projection == .ORTHOGRAPHIC {
		top := camera.fovy / 2
		right := top * aspect
		return MatrixOrtho(-right, right, -top, top, CULL_NEAR, CULL_FAR)
	}
	return MatrixPerspective(camera.fovy * DEG2RAD, aspect, CULL_NEAR, CULL_FAR)
}

BeginMode3D :: proc(camera: Camera3D) {
	w, h := current_target_size()
	G.proj = camera_projection(camera, f32(w) / f32(max(h, 1)))
	G.view = MatrixLookAt(camera.position, camera.target, camera.up)
	G.mode3d = true
	G.raster.depth_test = true
}

EndMode3D :: proc() {
	G.mode3d = false
	G.raster.depth_test = false
	set_2d()
}

BeginBlendMode :: proc(mode: BlendMode) {
	G.raster.blend = mode
}

EndBlendMode :: proc() {
	G.raster.blend = .ALPHA
}

BeginShaderMode :: proc(shader: Shader) {
	G.shader_mode = u32(shader.id)
}

EndShaderMode :: proc() {
	G.shader_mode = 0
}

BeginScissorMode :: proc(x, y, width, height: c.int) {
	s: f32 = 1
	if G.pass >= 0 && G.passes[G.pass].target == 0 {
		s = GetWindowScaleDPI().x
	}
	G.scissor_on = true
	G.scissor = {i32(f32(x) * s), i32(f32(y) * s), i32(f32(width) * s), i32(f32(height) * s)}
	G.imm_end = -1
}

EndScissorMode :: proc() {
	G.scissor_on = false
	G.imm_end = -1
}

// rlgl state (exposed through gfx/rlgl)
set_depth_test :: proc(on: bool) {
	G.raster.depth_test = on
}

set_depth_write :: proc(on: bool) {
	G.raster.depth_write = on
}

set_cull :: proc(on: bool) {
	G.raster.cull = on
}

// ------------------------------------------------------------------ immediate batch

im_begin :: proc(mode: int) {
	IM.active = true
	IM.prim = mode
	clear(&IM.verts)
}

im_color :: proc(col: Color) {
	IM.color = col
}

im_texcoord :: proc(u, v: f32) {
	IM.uv = {u, v}
}

im_vertex :: proc(v: Vector3) {
	append(&IM.verts, Imm_Vertex{pos = v, uv = IM.uv, col = IM.color})
}

im_end :: proc() {
	IM.active = false
	if len(IM.verts) == 0 || G.pass < 0 {
		clear(&IM.verts)
		IM.tex = 0
		return
	}
	prim: u8 = IM.prim == IM_LINES ? 1 : 0
	verts := IM.verts[:]
	quads: [dynamic]Imm_Vertex
	if IM.prim == IM_QUADS {
		quads = make([dynamic]Imm_Vertex, 0, len(verts) / 4 * 6, context.temp_allocator)
		for i := 0; i + 3 < len(verts); i += 4 {
			append(&quads, verts[i], verts[i + 1], verts[i + 2], verts[i], verts[i + 2], verts[i + 3])
		}
		verts = quads[:]
	}
	imm_submit(prim, verts, IM.tex)
	clear(&IM.verts)
	IM.tex = 0
}

@(private)
imm_submit :: proc(prim: u8, verts: []Imm_Vertex, tex: u32) {
	if len(verts) == 0 || G.pass < 0 {
		return
	}
	prog := G.shader_mode != 0 && !G.mode3d ? G.shader_mode : DEFAULT_SHADER
	key := current_key(prog, prim, true)
	if !G.mode3d {
		key.cull = false // 2D quads have no back faces worth culling
	}
	block := build_block(prog, Matrix(1), WHITE)
	bytes := len(verts) * size_of(Imm_Vertex)
	// extend the previous immediate draw when nothing about the state changed
	if G.imm_end == len(G.staging) && len(G.draws) > 0 {
		last := &G.draws[len(G.draws) - 1]
		if last.kind == .Imm && last.key == key && last.tex[0] == tex && last.scissor_on == G.scissor_on && last.scissor == G.scissor && int(last.uni_size) == len(block) && mem.compare(G.uniforms[last.uni_off:][:last.uni_size], block) == 0 {
			off := len(G.staging)
			resize(&G.staging, off + bytes)
			mem.copy(&G.staging[off], raw_data(verts), bytes)
			last.count += u32(len(verts))
			G.imm_end = len(G.staging)
			return
		}
	}
	off := stage(raw_data(verts), bytes)
	uo, us := push_uniforms(block)
	d := Draw{
		kind = .Imm,
		key = key,
		count = u32(len(verts)),
		uni_off = uo,
		uni_size = us,
		tex = {tex, 0},
		scissor_on = G.scissor_on,
		scissor = G.scissor,
	}
	d.streams[0] = {off = off, arena = true}
	record(d)
	G.imm_end = len(G.staging)
}

// ------------------------------------------------------------------ 3D shapes (raylib rmodels.c)

Vector3Perpendicular :: proc(v: Vector3) -> Vector3 {
	m := abs(v.x)
	axis := Vector3{1, 0, 0}
	if abs(v.y) < m {
		m = abs(v.y)
		axis = {0, 1, 0}
	}
	if abs(v.z) < m {
		axis = {0, 0, 1}
	}
	return Vector3CrossProduct(v, axis)
}

DrawLine3D :: proc(startPos, endPos: Vector3, color: Color) {
	im_begin(IM_LINES)
	im_color(color)
	im_vertex(startPos)
	im_vertex(endPos)
	im_end()
}

DrawCircle3D :: proc(center: Vector3, radius: f32, rotationAxis: Vector3, rotationAngle: f32, color: Color) {
	m := MatrixTranslate(center.x, center.y, center.z) * MatrixRotate(rotationAxis, rotationAngle * DEG2RAD)
	im_begin(IM_LINES)
	im_color(color)
	for i := 0; i < 360; i += 10 {
		a := f32(i) * DEG2RAD
		b := f32(i + 10) * DEG2RAD
		im_vertex(Vector3Transform({math.sin(a) * radius, math.cos(a) * radius, 0}, m))
		im_vertex(Vector3Transform({math.sin(b) * radius, math.cos(b) * radius, 0}, m))
	}
	im_end()
}

DrawTriangle3D :: proc(v1, v2, v3: Vector3, color: Color) {
	im_begin(IM_TRIANGLES)
	im_color(color)
	im_vertex(v1)
	im_vertex(v2)
	im_vertex(v3)
	im_end()
}

DrawSphere :: proc(centerPos: Vector3, radius: f32, color: Color) {
	DrawSphereEx(centerPos, radius, 16, 16, color)
}

DrawSphereEx :: proc(centerPos: Vector3, radius: f32, rings, slices: c.int, color: Color) {
	ring_angle := DEG2RAD * (180.0 / f32(rings + 1))
	slice_angle := DEG2RAD * (360.0 / f32(slices))
	cr, sr := math.cos(ring_angle), math.sin(ring_angle)
	cs, ss := math.cos(slice_angle), math.sin(slice_angle)
	v: [4]Vector3
	v[2] = {0, 1, 0}
	v[3] = {sr, cr, 0}
	put :: proc(p, c: Vector3, r: f32) {
		im_vertex(c + p * r)
	}
	im_begin(IM_TRIANGLES)
	im_color(color)
	for _ in 0 ..< rings + 1 {
		for _ in 0 ..< slices {
			v[0] = v[2]
			v[1] = v[3]
			v[2] = {cs * v[2].x - ss * v[2].z, v[2].y, ss * v[2].x + cs * v[2].z}
			v[3] = {cs * v[3].x - ss * v[3].z, v[3].y, ss * v[3].x + cs * v[3].z}
			put(v[0], centerPos, radius)
			put(v[3], centerPos, radius)
			put(v[1], centerPos, radius)
			put(v[0], centerPos, radius)
			put(v[2], centerPos, radius)
			put(v[3], centerPos, radius)
		}
		v[2] = v[3]
		v[3] = {cr * v[3].x + sr * v[3].y, -sr * v[3].x + cr * v[3].y, v[3].z}
	}
	im_end()
}

DrawCylinder :: proc(position: Vector3, radiusTop, radiusBottom, height: f32, sides: c.int, color: Color) {
	n := max(int(sides), 3)
	step := 360.0 / f32(n)
	p := position
	ring :: proc(i: int, step, r, y: f32, p: Vector3) -> Vector3 {
		a := DEG2RAD * f32(i) * step
		return p + {math.sin(a) * r, y, math.cos(a) * r}
	}
	im_begin(IM_TRIANGLES)
	im_color(color)
	if radiusTop > 0 {
		for i in 0 ..< n {
			im_vertex(ring(i, step, radiusBottom, 0, p))
			im_vertex(ring(i + 1, step, radiusBottom, 0, p))
			im_vertex(ring(i + 1, step, radiusTop, height, p))
			im_vertex(ring(i, step, radiusTop, height, p))
			im_vertex(ring(i, step, radiusBottom, 0, p))
			im_vertex(ring(i + 1, step, radiusTop, height, p))
		}
		for i in 0 ..< n {
			im_vertex(p + {0, height, 0})
			im_vertex(ring(i, step, radiusTop, height, p))
			im_vertex(ring(i + 1, step, radiusTop, height, p))
		}
	} else {
		for i in 0 ..< n {
			im_vertex(p + {0, height, 0})
			im_vertex(ring(i, step, radiusBottom, 0, p))
			im_vertex(ring(i + 1, step, radiusBottom, 0, p))
		}
	}
	for i in 0 ..< n {
		im_vertex(p)
		im_vertex(ring(i + 1, step, radiusBottom, 0, p))
		im_vertex(ring(i, step, radiusBottom, 0, p))
	}
	im_end()
}

DrawCylinderEx :: proc(startPos, endPos: Vector3, startRadius, endRadius: f32, sides: c.int, color: Color) {
	n := max(int(sides), 3)
	dir := endPos - startPos
	if dir == {0, 0, 0} {
		return
	}
	b1 := Vector3Normalize(Vector3Perpendicular(dir))
	b2 := Vector3Normalize(Vector3CrossProduct(b1, dir))
	base := 2 * math.PI / f32(n)
	im_begin(IM_TRIANGLES)
	im_color(color)
	for i in 0 ..< n {
		a0 := base * f32(i)
		a1 := base * f32(i + 1)
		w1 := startPos + b1 * (math.sin(a0) * startRadius) + b2 * (math.cos(a0) * startRadius)
		w2 := startPos + b1 * (math.sin(a1) * startRadius) + b2 * (math.cos(a1) * startRadius)
		w3 := endPos + b1 * (math.sin(a0) * endRadius) + b2 * (math.cos(a0) * endRadius)
		w4 := endPos + b1 * (math.sin(a1) * endRadius) + b2 * (math.cos(a1) * endRadius)
		if startRadius > 0 {
			im_vertex(startPos)
			im_vertex(w2)
			im_vertex(w1)
		}
		im_vertex(w1)
		im_vertex(w2)
		im_vertex(w3)
		im_vertex(w2)
		im_vertex(w4)
		im_vertex(w3)
		if endRadius > 0 {
			im_vertex(endPos)
			im_vertex(w3)
			im_vertex(w4)
		}
	}
	im_end()
}

DrawPlane :: proc(centerPos: Vector3, size: Vector2, color: Color) {
	c := centerPos
	hx, hz := size.x * 0.5, size.y * 0.5
	im_begin(IM_QUADS)
	im_color(color)
	im_vertex(c + {-hx, 0, -hz})
	im_vertex(c + {-hx, 0, hz})
	im_vertex(c + {hx, 0, hz})
	im_vertex(c + {hx, 0, -hz})
	im_end()
}

// ------------------------------------------------------------------ 2D shapes

DrawRectangle :: proc(posX, posY, width, height: c.int, color: Color) {
	DrawRectangleRec({f32(posX), f32(posY), f32(width), f32(height)}, color)
}

DrawRectangleV :: proc(position, size: Vector2, color: Color) {
	DrawRectangleRec({position.x, position.y, size.x, size.y}, color)
}

DrawRectangleRec :: proc(rec: Rectangle, color: Color) {
	x0, y0 := rec.x, rec.y
	x1, y1 := rec.x + rec.width, rec.y + rec.height
	im_begin(IM_QUADS)
	im_color(color)
	im_vertex({x0, y0, 0})
	im_vertex({x0, y1, 0})
	im_vertex({x1, y1, 0})
	im_vertex({x1, y0, 0})
	im_end()
}

DrawRectangleLines :: proc(posX, posY, width, height: c.int, color: Color) {
	x0, y0 := f32(posX) + 0.5, f32(posY) + 0.5
	x1, y1 := f32(posX + width) - 0.5, f32(posY + height) - 0.5
	im_begin(IM_LINES)
	im_color(color)
	im_vertex({x0, y0, 0})
	im_vertex({x1, y0, 0})
	im_vertex({x1, y0, 0})
	im_vertex({x1, y1, 0})
	im_vertex({x1, y1, 0})
	im_vertex({x0, y1, 0})
	im_vertex({x0, y1, 0})
	im_vertex({x0, y0, 0})
	im_end()
}

DrawRectangleLinesEx :: proc(rec: Rectangle, lineThick: f32, color: Color) {
	t := min(lineThick, rec.width / 2, rec.height / 2)
	DrawRectangleRec({rec.x, rec.y, rec.width, t}, color)
	DrawRectangleRec({rec.x, rec.y + rec.height - t, rec.width, t}, color)
	DrawRectangleRec({rec.x, rec.y + t, t, rec.height - 2 * t}, color)
	DrawRectangleRec({rec.x + rec.width - t, rec.y + t, t, rec.height - 2 * t}, color)
}

DrawCircleLines :: proc(centerX, centerY: c.int, radius: f32, color: Color) {
	cx, cy := f32(centerX), f32(centerY)
	im_begin(IM_LINES)
	im_color(color)
	for i := 0; i < 360; i += 10 {
		a := f32(i) * DEG2RAD
		b := f32(i + 10) * DEG2RAD
		im_vertex({cx + math.cos(a) * radius, cy + math.sin(a) * radius, 0})
		im_vertex({cx + math.cos(b) * radius, cy + math.sin(b) * radius, 0})
	}
	im_end()
}

DrawCircle :: proc(centerX, centerY: c.int, radius: f32, color: Color) {
	cx, cy := f32(centerX), f32(centerY)
	im_begin(IM_TRIANGLES)
	im_color(color)
	for i := 0; i < 360; i += 10 {
		a := f32(i) * DEG2RAD
		b := f32(i + 10) * DEG2RAD
		im_vertex({cx, cy, 0})
		im_vertex({cx + math.sin(b) * radius, cy + math.cos(b) * radius, 0})
		im_vertex({cx + math.sin(a) * radius, cy + math.cos(a) * radius, 0})
	}
	im_end()
}

DrawLine :: proc(startPosX, startPosY, endPosX, endPosY: c.int, color: Color) {
	im_begin(IM_LINES)
	im_color(color)
	im_vertex({f32(startPosX) + 0.5, f32(startPosY) + 0.5, 0})
	im_vertex({f32(endPosX) + 0.5, f32(endPosY) + 0.5, 0})
	im_end()
}

DrawTexture :: proc(texture: Texture2D, posX, posY: c.int, tint: Color) {
	DrawTexturePro(texture, {0, 0, f32(texture.width), f32(texture.height)}, {f32(posX), f32(posY), f32(texture.width), f32(texture.height)}, {0, 0}, 0, tint)
}

DrawTexturePro :: proc(texture: Texture2D, source, dest: Rectangle, origin: Vector2, rotation: f32, tint: Color) {
	if texture.id == 0 || texture.width <= 0 || texture.height <= 0 {
		return
	}
	src := source
	flip_x, flip_y := false, false
	if src.width < 0 {
		flip_x = true
		src.width = -src.width
	}
	if src.height < 0 {
		flip_y = true
		src.height = -src.height
	}
	tw, th := f32(texture.width), f32(texture.height)
	u0, u1 := src.x / tw, (src.x + src.width) / tw
	v0, v1 := src.y / th, (src.y + src.height) / th
	if flip_x {
		u0, u1 = u1, u0
	}
	if flip_y {
		v0, v1 = v1, v0
	}
	tl, tr, bl, br: Vector2
	if rotation == 0 {
		x := dest.x - origin.x
		y := dest.y - origin.y
		tl = {x, y}
		tr = {x + dest.width, y}
		bl = {x, y + dest.height}
		br = {x + dest.width, y + dest.height}
	} else {
		sr := math.sin(rotation * DEG2RAD)
		cr := math.cos(rotation * DEG2RAD)
		x, y := dest.x, dest.y
		dx, dy := -origin.x, -origin.y
		tl = {x + dx * cr - dy * sr, y + dx * sr + dy * cr}
		tr = {x + (dx + dest.width) * cr - dy * sr, y + (dx + dest.width) * sr + dy * cr}
		bl = {x + dx * cr - (dy + dest.height) * sr, y + dx * sr + (dy + dest.height) * cr}
		br = {x + (dx + dest.width) * cr - (dy + dest.height) * sr, y + (dx + dest.width) * sr + (dy + dest.height) * cr}
	}
	im_begin(IM_QUADS)
	IM.tex = u32(texture.id)
	im_color(tint)
	im_texcoord(u0, v0)
	im_vertex({tl.x, tl.y, 0})
	im_texcoord(u0, v1)
	im_vertex({bl.x, bl.y, 0})
	im_texcoord(u1, v1)
	im_vertex({br.x, br.y, 0})
	im_texcoord(u1, v0)
	im_vertex({tr.x, tr.y, 0})
	im_end()
	im_texcoord(0, 0)
}
