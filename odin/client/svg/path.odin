// SVG path `d` lexer/curve flattener and primitive shape builders.
package svg

import "core:math"
import "core:strconv"

@(private)
Path_Cursor :: struct {
	src:      string,
	idx:      int,
	cur:      [2]f32,
	sub:      [2]f32,
	prev_cp:  [2]f32,
	prev_cmd: u8,
	cmd:      u8,
}

parse_path_subpaths :: proc(d: string, subpaths: ^[dynamic]Subpath) {
	c := Path_Cursor{src = d}
	for {
		skip_path_sep(&c)
		if c.idx >= len(c.src) { break }
		ch := c.src[c.idx]
		if is_cmd_letter(ch) {
			c.cmd = ch
			c.idx += 1
			if ch == 'Z' || ch == 'z' {
				close_current_subpath(&c, subpaths)
				c.prev_cmd = ch
				continue
			}
		} else if c.cmd == 0 {
			break
		} else if c.cmd == 'M' {
			c.cmd = 'L'
		} else if c.cmd == 'm' {
			c.cmd = 'l'
		}
		exec_path_cmd(&c, subpaths)
	}
}

@(private)
exec_path_cmd :: proc(c: ^Path_Cursor, subpaths: ^[dynamic]Subpath) {
	rel := c.cmd >= 'a' && c.cmd <= 'z'
	uc := rel ? (c.cmd - 32) : c.cmd
	switch uc {
	case 'M':
		pt, ok := next_pair(c, rel); if !ok { c.idx = len(c.src); return }
		c.cur, c.sub = pt, pt
		append(subpaths, Subpath{})
		add_subpath_pt(subpaths, pt)
	case 'L':
		pt, ok := next_pair(c, rel); if !ok { c.idx = len(c.src); return }
		c.cur = pt
		add_subpath_pt(subpaths, pt)
	case 'H':
		v, ok := next_num(c); if !ok { c.idx = len(c.src); return }
		c.cur[0] = rel ? c.cur[0] + v : v
		add_subpath_pt(subpaths, c.cur)
	case 'V':
		v, ok := next_num(c); if !ok { c.idx = len(c.src); return }
		c.cur[1] = rel ? c.cur[1] + v : v
		add_subpath_pt(subpaths, c.cur)
	case 'C', 'S':
		exec_cubic_cmd(c, subpaths, uc == 'S', rel)
	case 'Q', 'T':
		exec_quad_cmd(c, subpaths, uc == 'T', rel)
	case 'A':
		exec_arc_cmd(c, subpaths, rel)
	case:
		c.idx = len(c.src)
	}
	c.prev_cmd = c.cmd
}

@(private)
exec_cubic_cmd :: proc(c: ^Path_Cursor, subpaths: ^[dynamic]Subpath, smooth, rel: bool) {
	p1 := c.cur
	if smooth {
		if c.prev_cmd == 'C' || c.prev_cmd == 'c' || c.prev_cmd == 'S' || c.prev_cmd == 's' {
			p1 = {2 * c.cur[0] - c.prev_cp[0], 2 * c.cur[1] - c.prev_cp[1]}
		}
	} else {
		var1, ok1 := next_pair(c, rel); if !ok1 { c.idx = len(c.src); return }
		p1 = var1
	}
	p2, ok2 := next_pair(c, rel); if !ok2 { c.idx = len(c.src); return }
	p3, ok3 := next_pair(c, rel); if !ok3 { c.idx = len(c.src); return }
	flatten_cubic(subpaths, c.cur, p1, p2, p3)
	c.prev_cp = p2
	c.cur = p3
}

@(private)
exec_quad_cmd :: proc(c: ^Path_Cursor, subpaths: ^[dynamic]Subpath, smooth, rel: bool) {
	p1 := c.cur
	if smooth {
		if c.prev_cmd == 'Q' || c.prev_cmd == 'q' || c.prev_cmd == 'T' || c.prev_cmd == 't' {
			p1 = {2 * c.cur[0] - c.prev_cp[0], 2 * c.cur[1] - c.prev_cp[1]}
		}
	} else {
		var1, ok1 := next_pair(c, rel); if !ok1 { c.idx = len(c.src); return }
		p1 = var1
	}
	p2, ok2 := next_pair(c, rel); if !ok2 { c.idx = len(c.src); return }
	flatten_quad(subpaths, c.cur, p1, p2)
	c.prev_cp = p1
	c.cur = p2
}

@(private)
exec_arc_cmd :: proc(c: ^Path_Cursor, subpaths: ^[dynamic]Subpath, rel: bool) {
	rx, ok1 := next_num(c)
	ry, ok2 := next_num(c)
	rot, ok3 := next_num(c)
	large, ok4 := next_flag(c)
	sweep, ok5 := next_flag(c)
	end_pt, ok6 := next_pair(c, rel)
	if !(ok1 && ok2 && ok3 && ok4 && ok5 && ok6) {
		c.idx = len(c.src)
		return
	}
	flatten_arc(subpaths, c.cur, rx, ry, rot, large, sweep, end_pt)
	c.cur = end_pt
}

@(private)
close_current_subpath :: proc(c: ^Path_Cursor, subpaths: ^[dynamic]Subpath) {
	if len(subpaths) > 0 {
		sp := &subpaths[len(subpaths) - 1]
		sp.closed = true
	}
	c.cur = c.sub
}

@(private)
add_subpath_pt :: proc(subpaths: ^[dynamic]Subpath, pt: [2]f32) {
	if len(subpaths) == 0 {
		append(subpaths, Subpath{})
	}
	sp := &subpaths[len(subpaths) - 1]
	if len(sp.pts) > 0 {
		last := sp.pts[len(sp.pts) - 1]
		if abs(last[0] - pt[0]) < 1e-5 && abs(last[1] - pt[1]) < 1e-5 {
			return
		}
	}
	append(&sp.pts, pt)
}

@(private)
flatten_cubic :: proc(subpaths: ^[dynamic]Subpath, p0, p1, p2, p3: [2]f32) {
	STEPS :: 12
	for s in 1..=STEPS {
		t := f32(s) / f32(STEPS)
		u := 1.0 - t
		b0, b1, b2, b3 := u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
		add_subpath_pt(subpaths, {
			b0 * p0[0] + b1 * p1[0] + b2 * p2[0] + b3 * p3[0],
			b0 * p0[1] + b1 * p1[1] + b2 * p2[1] + b3 * p3[1],
		})
	}
}

@(private)
flatten_quad :: proc(subpaths: ^[dynamic]Subpath, p0, p1, p2: [2]f32) {
	STEPS :: 10
	for s in 1..=STEPS {
		t := f32(s) / f32(STEPS)
		u := 1.0 - t
		b0, b1, b2 := u * u, 2 * u * t, t * t
		add_subpath_pt(subpaths, {
			b0 * p0[0] + b1 * p1[0] + b2 * p2[0],
			b0 * p0[1] + b1 * p1[1] + b2 * p2[1],
		})
	}
}

// W3C SVG F.6.5/F.6.6 endpoint-to-center elliptical arc flattening.
@(private)
flatten_arc :: proc(subpaths: ^[dynamic]Subpath, p0: [2]f32, rx_in, ry_in, x_rot: f32, large, sweep: bool, p1: [2]f32) {
	if abs(p0[0] - p1[0]) < 1e-5 && abs(p0[1] - p1[1]) < 1e-5 { return }
	rx, ry := abs(rx_in), abs(ry_in)
	if rx < 1e-5 || ry < 1e-5 { add_subpath_pt(subpaths, p1); return }

	phi := x_rot * math.PI / 180.0
	cphi, sphi := math.cos(phi), math.sin(phi)
	dx, dy := 0.5 * (p0[0] - p1[0]), 0.5 * (p0[1] - p1[1])
	x1p := cphi * dx + sphi * dy
	y1p := -sphi * dx + cphi * dy

	lam := (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
	if lam > 1.0 { s := math.sqrt(lam); rx *= s; ry *= s }

	num := max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
	den := max(1e-9, rx * rx * y1p * y1p + ry * ry * x1p * x1p)
	factor := (large == sweep ? f32(-1.0) : f32(1.0)) * math.sqrt(num / den)
	cxp := factor * (rx * y1p / ry)
	cyp := factor * (-ry * x1p / rx)
	cx := cphi * cxp - sphi * cyp + 0.5 * (p0[0] + p1[0])
	cy := sphi * cxp + cphi * cyp + 0.5 * (p0[1] + p1[1])

	t1 := svg_vec_angle({1, 0}, {(x1p - cxp) / rx, (y1p - cyp) / ry})
	dt := svg_vec_angle({(x1p - cxp) / rx, (y1p - cyp) / ry}, {(-x1p - cxp) / rx, (-y1p - cyp) / ry})
	if !sweep && dt > 0 { dt -= math.TAU }
	if sweep && dt < 0 { dt += math.TAU }
	steps := max(4, int(math.ceil(abs(dt) / (math.PI / 8.0))))
	for i in 1..=steps {
		th := t1 + dt * f32(i) / f32(steps)
		lx, ly := rx * math.cos(th), ry * math.sin(th)
		add_subpath_pt(subpaths, {cphi * lx - sphi * ly + cx, sphi * lx + cphi * ly + cy})
	}
}

@(private)
svg_vec_angle :: proc(u, v: [2]f32) -> f32 {
	det := u[0] * v[1] - u[1] * v[0]
	dot := u[0] * v[0] + u[1] * v[1]
	return math.atan2(det, dot)
}

@(private)
is_cmd_letter :: proc(ch: u8) -> bool {
	return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

@(private)
skip_path_sep :: proc(c: ^Path_Cursor) {
	for c.idx < len(c.src) {
		ch := c.src[c.idx]
		if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == ',' {
			c.idx += 1
		} else {
			break
		}
	}
}

@(private)
next_num :: proc(c: ^Path_Cursor) -> (f32, bool) {
	skip_path_sep(c)
	if c.idx >= len(c.src) { return 0, false }
	start := c.idx
	if c.src[c.idx] == '-' || c.src[c.idx] == '+' { c.idx += 1 }
	seen_dot := false
	seen_digit := false
	for c.idx < len(c.src) {
		ch := c.src[c.idx]
		if ch >= '0' && ch <= '9' {
			seen_digit = true
			c.idx += 1
		} else if ch == '.' && !seen_dot {
			seen_dot = true
			c.idx += 1
		} else if (ch == 'e' || ch == 'E') && seen_digit {
			c.idx += 1
			if c.idx < len(c.src) && (c.src[c.idx] == '+' || c.src[c.idx] == '-') { c.idx += 1 }
		} else {
			break
		}
	}
	if !seen_digit { c.idx = start; return 0, false }
	v, ok := strconv.parse_f32(c.src[start:c.idx])
	return v, ok
}

@(private)
next_flag :: proc(c: ^Path_Cursor) -> (bool, bool) {
	skip_path_sep(c)
	if c.idx >= len(c.src) { return false, false }
	ch := c.src[c.idx]
	if ch == '0' || ch == '1' {
		c.idx += 1
		return ch == '1', true
	}
	return false, false
}

@(private)
next_pair :: proc(c: ^Path_Cursor, rel: bool) -> ([2]f32, bool) {
	x, ok1 := next_num(c)
	y, ok2 := next_num(c)
	if !ok1 || !ok2 { return {}, false }
	return rel ? [2]f32{c.cur[0] + x, c.cur[1] + y} : [2]f32{x, y}, true
}

build_rect_subpath :: proc(x, y, w, h, rx_in, ry_in: f32) -> Subpath {
	sp := Subpath{closed = true}
	if w <= 0 || h <= 0 { return sp }
	rx := min(rx_in > 0 ? rx_in : ry_in, w * 0.5)
	ry := min(ry_in > 0 ? ry_in : rx_in, h * 0.5)
	if rx <= 1e-4 && ry <= 1e-4 {
		append(&sp.pts, [2]f32{x, y}, [2]f32{x + w, y}, [2]f32{x + w, y + h}, [2]f32{x, y + h})
		return sp
	}
	corners := [4][2]f32{{x + w - rx, y + ry}, {x + w - rx, y + h - ry}, {x + rx, y + h - ry}, {x + rx, y + ry}}
	starts := [4]f32{-math.PI * 0.5, 0, math.PI * 0.5, math.PI}
	for c in 0..<4 {
		for s in 0..=4 {
			a := starts[c] + f32(s) * (math.PI * 0.5 / 4.0)
			append(&sp.pts, [2]f32{corners[c][0] + math.cos(a) * rx, corners[c][1] + math.sin(a) * ry})
		}
	}
	return sp
}

build_ellipse_subpath :: proc(cx, cy, rx, ry: f32) -> Subpath {
	sp := Subpath{closed = true}
	if rx <= 0 || ry <= 0 { return sp }
	STEPS :: 28
	for i in 0..<STEPS {
		a := f32(i) * math.TAU / f32(STEPS)
		append(&sp.pts, [2]f32{cx + math.cos(a) * rx, cy + math.sin(a) * ry})
	}
	return sp
}

parse_points_subpath :: proc(text: string, closed: bool) -> Subpath {
	sp := Subpath{closed = closed}
	c := Path_Cursor{src = text}
	for {
		x, ok1 := next_num(&c)
		y, ok2 := next_num(&c)
		if !ok1 || !ok2 { break }
		append(&sp.pts, [2]f32{x, y})
	}
	return sp
}
