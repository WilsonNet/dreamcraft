// Pure-Odin lightweight SVG data structures and 2D affine transforms.
package svg

import "core:math"

RGBA8 :: [4]u8
Mat2D :: [6]f32 // [a, b, c, d, e, f]: x' = a*x + c*y + e, y' = b*x + d*y + f

Line_Cap :: enum u8 {
	Butt,
	Round,
	Square,
}

Line_Join :: enum u8 {
	Miter,
	Round,
	Bevel,
}

Fill_Rule :: enum u8 {
	Nonzero,
	Even_Odd,
}

Paint :: struct {
	has_color:   bool,
	use_current: bool,
	color:       RGBA8,
}

Style :: struct {
	fill:           Paint,
	stroke:         Paint,
	stroke_width:   f32,
	stroke_cap:     Line_Cap,
	stroke_join:    Line_Join,
	opacity:        f32,
	fill_opacity:   f32,
	stroke_opacity: f32,
	fill_rule:      Fill_Rule,
}

Subpath :: struct {
	pts:    [dynamic][2]f32,
	closed: bool,
}

Shape :: struct {
	subpaths: [dynamic]Subpath,
	style:    Style,
	xf:       Mat2D,
}

Document :: struct {
	width:        f32,
	height:       f32,
	view_box:     [4]f32, // min_x, min_y, width, height
	has_view_box: bool,
	shapes:       [dynamic]Shape,
}

default_style :: proc() -> Style {
	return Style{
		fill           = Paint{has_color = true, color = {0, 0, 0, 255}},
		stroke_width   = 1.0,
		stroke_cap     = .Butt,
		stroke_join    = .Miter,
		opacity        = 1.0,
		fill_opacity   = 1.0,
		stroke_opacity = 1.0,
		fill_rule      = .Nonzero,
	}
}

document_delete :: proc(doc: ^Document) {
	if doc == nil {
		return
	}
	for &sh in doc.shapes {
		shape_delete(&sh)
	}
	delete(doc.shapes)
	doc^ = {}
}

shape_delete :: proc(sh: ^Shape) {
	for &sp in sh.subpaths {
		delete(sp.pts)
	}
	delete(sh.subpaths)
	sh^ = {}
}

mat2d_identity :: proc() -> Mat2D {
	return {1, 0, 0, 1, 0, 0}
}

mat2d_translate :: proc(tx, ty: f32) -> Mat2D {
	return {1, 0, 0, 1, tx, ty}
}

mat2d_scale :: proc(sx, sy: f32) -> Mat2D {
	return {sx, 0, 0, sy, 0, 0}
}

mat2d_rotate :: proc(deg: f32, cx: f32 = 0, cy: f32 = 0) -> Mat2D {
	rad := deg * math.PI / 180.0
	cs := math.cos(rad)
	sn := math.sin(rad)
	r := Mat2D{cs, sn, -sn, cs, 0, 0}
	if cx == 0 && cy == 0 {
		return r
	}
	return mat2d_mul(mat2d_translate(cx, cy), mat2d_mul(r, mat2d_translate(-cx, -cy)))
}

mat2d_mul :: proc(p, q: Mat2D) -> Mat2D {
	return {
		p[0] * q[0] + p[2] * q[1],
		p[1] * q[0] + p[3] * q[1],
		p[0] * q[2] + p[2] * q[3],
		p[1] * q[2] + p[3] * q[3],
		p[0] * q[4] + p[2] * q[5] + p[4],
		p[1] * q[4] + p[3] * q[5] + p[5],
	}
}

mat2d_point :: proc(m: Mat2D, pt: [2]f32) -> [2]f32 {
	return {m[0] * pt[0] + m[2] * pt[1] + m[4], m[1] * pt[0] + m[3] * pt[1] + m[5]}
}

mat2d_scale_avg :: proc(m: Mat2D) -> f32 {
	sx := math.sqrt(m[0] * m[0] + m[1] * m[1])
	sy := math.sqrt(m[2] * m[2] + m[3] * m[3])
	return 0.5 * (sx + sy)
}
