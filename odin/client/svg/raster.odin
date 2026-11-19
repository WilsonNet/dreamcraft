// Anti-aliased RGBA software rasterizer for parsed SVG documents (4x4 SSAA fills + smooth strokes).
package svg

import "core:math"

@(private)
Px_Subpath :: struct {
	pts:    [][2]f32,
	closed: bool,
}

render_svg_rgba :: proc(
	doc: ^Document,
	out_w, out_h: int,
	current_color := RGBA8{255, 255, 255, 255},
	allocator := context.allocator,
) -> []u8 {
	if doc == nil || out_w <= 0 || out_h <= 0 {
		return nil
	}
	buf := make([]u8, out_w * out_h * 4, allocator)
	cov := make([]f32, out_w * out_h, context.temp_allocator)
	vx, vy, vw, vh := doc_view_box(doc)
	scale := min(f32(out_w) / max(vw, 1e-4), f32(out_h) / max(vh, 1e-4))
	ox := (f32(out_w) - vw * scale) * 0.5 - vx * scale
	oy := (f32(out_h) - vh * scale) * 0.5 - vy * scale

	for &sh in doc.shapes {
		raster_shape(&sh, scale, ox, oy, out_w, out_h, current_color, buf, cov)
	}
	return buf
}

@(private)
doc_view_box :: proc(doc: ^Document) -> (vx, vy, vw, vh: f32) {
	if doc.has_view_box && doc.view_box[2] > 0 && doc.view_box[3] > 0 {
		return doc.view_box[0], doc.view_box[1], doc.view_box[2], doc.view_box[3]
	}
	return 0, 0, doc.width > 0 ? doc.width : 24, doc.height > 0 ? doc.height : 24
}

@(private)
raster_shape :: proc(
	sh: ^Shape,
	scale, ox, oy: f32,
	w, h: int,
	cur_col: RGBA8,
	buf: []u8,
	cov: []f32,
) {
	px_paths := make([]Px_Subpath, len(sh.subpaths), context.temp_allocator)
	lo := [2]f32{f32(w), f32(h)}
	hi := [2]f32{0, 0}
	for &sp, si in sh.subpaths {
		pts := make([][2]f32, len(sp.pts), context.temp_allocator)
		for p, pi in sp.pts {
			tp := mat2d_point(sh.xf, p)
			q := [2]f32{tp[0] * scale + ox, tp[1] * scale + oy}
			pts[pi] = q
			lo = {min(lo[0], q[0]), min(lo[1], q[1])}
			hi = {max(hi[0], q[0]), max(hi[1], q[1])}
		}
		px_paths[si] = Px_Subpath{pts = pts, closed = sp.closed}
	}

	if sh.style.fill.has_color {
		fill_col := resolve_paint(sh.style.fill, cur_col, sh.style.opacity * sh.style.fill_opacity)
		if fill_col[3] > 0 {
			raster_fill(px_paths, sh.style.fill_rule, lo, hi, w, h, cov, buf, fill_col)
		}
	}
	if sh.style.stroke.has_color && sh.style.stroke_width > 0 {
		stroke_col := resolve_paint(sh.style.stroke, cur_col, sh.style.opacity * sh.style.stroke_opacity)
		if stroke_col[3] > 0 {
			px_w := sh.style.stroke_width * scale * mat2d_scale_avg(sh.xf)
			raster_stroke(px_paths, sh.style.stroke_cap, px_w, lo, hi, w, h, cov, buf, stroke_col)
		}
	}
}

@(private)
resolve_paint :: proc(p: Paint, cur: RGBA8, alpha_mul: f32) -> RGBA8 {
	c := p.use_current ? cur : p.color
	a := clamp(f32(c[3]) * clamp(alpha_mul, 0, 1), 0, 255)
	return {c[0], c[1], c[2], u8(math.round(a))}
}

@(private)
raster_fill :: proc(
	paths: []Px_Subpath,
	rule: Fill_Rule,
	lo, hi: [2]f32,
	w, h: int,
	cov: []f32,
	buf: []u8,
	col: RGBA8,
) {
	x0 := max(0, int(math.floor(lo[0])) - 1)
	y0 := max(0, int(math.floor(lo[1])) - 1)
	x1 := min(w - 1, int(math.ceil(hi[0])) + 1)
	y1 := min(h - 1, int(math.ceil(hi[1])) + 1)
	if x0 > x1 || y0 > y1 { return }

	for py in y0..=y1 {
		for px in x0..=x1 {
			hits := 0
			for sy in 0..<4 {
				qy := f32(py) + (f32(sy) + 0.5) * 0.25
				for sx in 0..<4 {
					qx := f32(px) + (f32(sx) + 0.5) * 0.25
					if point_in_paths(paths, qx, qy, rule) { hits += 1 }
				}
			}
			cov[py * w + px] = f32(hits) / 16.0
		}
	}
	blend_coverage_rect(x0, y0, x1, y1, w, cov, buf, col)
}

@(private)
point_in_paths :: proc(paths: []Px_Subpath, px, py: f32, rule: Fill_Rule) -> bool {
	winding := 0
	even_odd := false
	for sp in paths {
		n := len(sp.pts)
		if n < 3 { continue }
		for i in 0..<n {
			a := sp.pts[i]
			b := sp.pts[(i + 1) % n]
			if rule == .Even_Odd {
				if (a[1] > py) != (b[1] > py) {
					ix := a[0] + (py - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
					if px < ix { even_odd = !even_odd }
				}
			} else {
				if a[1] <= py {
					if b[1] > py && is_left_side(a, b, px, py) > 0 { winding += 1 }
				} else {
					if b[1] <= py && is_left_side(a, b, px, py) < 0 { winding -= 1 }
				}
			}
		}
	}
	return rule == .Even_Odd ? even_odd : winding != 0
}

@(private)
is_left_side :: proc(a, b: [2]f32, px, py: f32) -> f32 {
	return (b[0] - a[0]) * (py - a[1]) - (px - a[0]) * (b[1] - a[1])
}

@(private)
raster_stroke :: proc(
	paths: []Px_Subpath,
	cap: Line_Cap,
	stroke_px: f32,
	lo, hi: [2]f32,
	w, h: int,
	cov: []f32,
	buf: []u8,
	col: RGBA8,
) {
	half_w := max(stroke_px * 0.5, 0.35)
	pad := int(math.ceil(half_w)) + 2
	x0 := max(0, int(math.floor(lo[0])) - pad)
	y0 := max(0, int(math.floor(lo[1])) - pad)
	x1 := min(w - 1, int(math.ceil(hi[0])) + pad)
	y1 := min(h - 1, int(math.ceil(hi[1])) + pad)
	if x0 > x1 || y0 > y1 { return }

	for py in y0..=y1 {
		for px in x0..=x1 {
			cov[py * w + px] = 0
		}
	}
	for sp in paths {
		n := len(sp.pts)
		if n < 2 { continue }
		seg_count := sp.closed ? n : n - 1
		for i in 0..<seg_count {
			a := sp.pts[i]
			b := sp.pts[(i + 1) % n]
			cap_a := sp.closed || i > 0 ? Line_Cap.Round : cap
			cap_b := sp.closed || i < seg_count - 1 ? Line_Cap.Round : cap
			stamp_stroke_seg(a, b, half_w, cap_a, cap_b, w, h, cov)
		}
	}
	blend_coverage_rect(x0, y0, x1, y1, w, cov, buf, col)
}

@(private)
stamp_stroke_seg :: proc(
	a, b: [2]f32,
	half_w: f32,
	cap_a, cap_b: Line_Cap,
	w, h: int,
	cov: []f32,
) {
	dx, dy := b[0] - a[0], b[1] - a[1]
	seg_len := math.sqrt(dx * dx + dy * dy)
	ux, uy := seg_len > 1e-5 ? dx / seg_len : 1.0, seg_len > 1e-5 ? dy / seg_len : 0.0
	pad := half_w + 1.25
	x0 := max(0, int(math.floor(min(a[0], b[0]) - pad)))
	y0 := max(0, int(math.floor(min(a[1], b[1]) - pad)))
	x1 := min(w - 1, int(math.ceil(max(a[0], b[0]) + pad)))
	y1 := min(h - 1, int(math.ceil(max(a[1], b[1]) + pad)))
	if x0 > x1 || y0 > y1 { return }

	for py in y0..=y1 {
		for px in x0..=x1 {
			d := cap_seg_signed_dist(f32(px) + 0.5, f32(py) + 0.5, a, b, ux, uy, seg_len, half_w, cap_a, cap_b)
			c := clamp(0.5 - d, 0, 1)
			idx := py * w + px
			if c > cov[idx] { cov[idx] = c }
		}
	}
}

@(private)
cap_seg_signed_dist :: proc(
	px, py: f32,
	a, b: [2]f32,
	ux, uy, seg_len, half_w: f32,
	cap_a, cap_b: Line_Cap,
) -> f32 {
	rx, ry := px - a[0], py - a[1]
	along := rx * ux + ry * uy
	perp := abs(-rx * uy + ry * ux)
	if along >= 0 && along <= seg_len { return perp - half_w }
	if along < 0 {
		if cap_a == .Round { return math.hypot(rx, ry) - half_w }
		ext := cap_a == .Square ? half_w : f32(0)
		return max(-along - ext, perp - half_w)
	}
	ex, ey := px - b[0], py - b[1]
	if cap_b == .Round { return math.hypot(ex, ey) - half_w }
	ext := cap_b == .Square ? half_w : f32(0)
	return max(along - seg_len - ext, perp - half_w)
}

@(private)
blend_coverage_rect :: proc(x0, y0, x1, y1, w: int, cov: []f32, buf: []u8, col: RGBA8) {
	sa_base := f32(col[3]) / 255.0
	sr, sg, sb := f32(col[0]), f32(col[1]), f32(col[2])
	for py in y0..=y1 {
		for px in x0..=x1 {
			c := cov[py * w + px]
			if c <= 1e-4 { continue }
			sa := c * sa_base
			off := (py * w + px) * 4
			da := f32(buf[off + 3]) / 255.0
			out_a := sa + da * (1.0 - sa)
			if out_a <= 1e-5 { continue }
			inv := 1.0 / out_a
			r := (sr * sa + f32(buf[off + 0]) * da * (1.0 - sa)) * inv
			g := (sg * sa + f32(buf[off + 1]) * da * (1.0 - sa)) * inv
			b := (sb * sa + f32(buf[off + 2]) * da * (1.0 - sa)) * inv
			buf[off + 0] = u8(clamp(math.round(r), 0, 255))
			buf[off + 1] = u8(clamp(math.round(g), 0, 255))
			buf[off + 2] = u8(clamp(math.round(b), 0, 255))
			buf[off + 3] = u8(clamp(math.round(out_a * 255.0), 0, 255))
		}
	}
}
