// Lightweight XML/SVG document parser supporting <svg>, <g>, paths, shapes, transforms, and styles.
package svg

import "core:strconv"
import "core:strings"

@(private)
MAX_GROUP_DEPTH :: 32

@(private)
Group_State :: struct {
	style: Style,
	xf:    Mat2D,
}

@(private)
Attr :: struct {
	key: string,
	val: string,
}

@(private)
skip_xml_non_tag :: proc(src: string, idx: int) -> (next_idx: int, skipped, ok: bool) {
	if strings.has_prefix(src[idx:], "<!--") {
		end := strings.index(src[idx + 4:], "-->")
		if end < 0 { return 0, false, false }
		return idx + 4 + end + 3, true, true
	}
	if strings.has_prefix(src[idx:], "<?") || strings.has_prefix(src[idx:], "<!") {
		end := strings.index_byte(src[idx:], '>')
		if end < 0 { return 0, false, false }
		return idx + end + 1, true, true
	}
	return idx, false, true
}

parse_svg :: proc(src: string) -> (doc: Document, ok: bool) {
	stack: [MAX_GROUP_DEPTH]Group_State
	stack[0] = Group_State{style = default_style(), xf = mat2d_identity()}
	depth, seen_svg, i := 1, false, 0
	for i < len(src) {
		lt := strings.index_byte(src[i:], '<')
		if lt < 0 { break }
		i += lt
		next_i, skipped, xml_ok := skip_xml_non_tag(src, i)
		if !xml_ok { break }
		if skipped { i = next_i; continue }
		tag_end, self_close, ok_tag := scan_tag_end(src, i)
		if !ok_tag { break }
		inner := strings.trim_space(src[i + 1:tag_end])
		i = tag_end + 1
		if self_close && len(inner) > 0 && inner[len(inner) - 1] == '/' {
			inner = strings.trim_space(inner[:len(inner) - 1])
		}
		if len(inner) == 0 { continue }
		if inner[0] == '/' {
			if depth > 1 && strings.trim_space(inner[1:]) == "g" { depth -= 1 }
			continue
		}
		tag_name, attrs := parse_tag_header(inner)
		if tag_name == "svg" {
			seen_svg = true; parse_svg_root(&doc, attrs, &stack[0])
		} else if tag_name == "g" && !self_close && depth < MAX_GROUP_DEPTH {
			stack[depth] = stack[depth - 1]
			apply_common_attrs(attrs, &stack[depth].style, &stack[depth].xf)
			depth += 1
		} else {
			emit_element(&doc, tag_name, attrs, stack[depth - 1].style, stack[depth - 1].xf)
		}
	}
	return doc, seen_svg
}

@(private)
scan_tag_end :: proc(src: string, start: int) -> (end_idx: int, self_close, ok: bool) {
	quote: u8 = 0
	for k := start + 1; k < len(src); k += 1 {
		ch := src[k]
		if quote != 0 {
			if ch == quote { quote = 0 }
		} else if ch == '"' || ch == '\'' {
			quote = ch
		} else if ch == '>' {
			self_close = k > start + 1 && src[k - 1] == '/'
			return k, self_close, true
		}
	}
	return 0, false, false
}

@(private)
parse_tag_header :: proc(inner: string) -> (name: string, attrs: []Attr) {
	list := make([dynamic]Attr, 0, 12, context.temp_allocator)
	k := 0
	for k < len(inner) && !is_xml_ws(inner[k]) { k += 1 }
	name = inner[:k]
	for k < len(inner) {
		for k < len(inner) && is_xml_ws(inner[k]) { k += 1 }
		if k >= len(inner) { break }
		ks := k
		for k < len(inner) && !is_xml_ws(inner[k]) && inner[k] != '=' { k += 1 }
		key := inner[ks:k]
		for k < len(inner) && is_xml_ws(inner[k]) { k += 1 }
		if k >= len(inner) || inner[k] != '=' { continue }
		k += 1
		for k < len(inner) && is_xml_ws(inner[k]) { k += 1 }
		if k >= len(inner) { break }
		val: string
		if inner[k] == '"' || inner[k] == '\'' {
			q := inner[k]; k += 1
			vs := k
			for k < len(inner) && inner[k] != q { k += 1 }
			val = inner[vs:k]
			if k < len(inner) { k += 1 }
		} else {
			vs := k
			for k < len(inner) && !is_xml_ws(inner[k]) { k += 1 }
			val = inner[vs:k]
		}
		if len(key) > 0 { append(&list, Attr{key = key, val = val}) }
	}
	return name, list[:]
}

@(private)
parse_svg_root :: proc(doc: ^Document, attrs: []Attr, root: ^Group_State) {
	doc.width, doc.height = 24, 24
	for a in attrs {
		if a.key == "width"  { if v, ok := parse_len_f32(a.val); ok { doc.width = v } }
		if a.key == "height" { if v, ok := parse_len_f32(a.val); ok { doc.height = v } }
		if a.key == "viewBox" {
			nums := parse_num_list(a.val)
			if len(nums) >= 4 {
				doc.view_box = {nums[0], nums[1], nums[2], nums[3]}
				doc.has_view_box = true
			}
		}
	}
	apply_common_attrs(attrs, &root.style, &root.xf)
}

@(private)
emit_element :: proc(doc: ^Document, tag: string, attrs: []Attr, base_st: Style, base_xf: Mat2D) {
	st := base_st
	xf := base_xf
	apply_common_attrs(attrs, &st, &xf)
	sh := Shape{style = st, xf = xf}
	switch tag {
	case "path":
		if d, ok := find_attr(attrs, "d"); ok { parse_path_subpaths(d, &sh.subpaths) }
	case "rect":
		x, _ := attr_f32(attrs, "x", 0)
		y, _ := attr_f32(attrs, "y", 0)
		w, _ := attr_f32(attrs, "width", 0)
		h, _ := attr_f32(attrs, "height", 0)
		rx, _ := attr_f32(attrs, "rx", 0)
		ry, _ := attr_f32(attrs, "ry", 0)
		if sp := build_rect_subpath(x, y, w, h, rx, ry); len(sp.pts) >= 3 { append(&sh.subpaths, sp) }
	case "circle":
		cx, _ := attr_f32(attrs, "cx", 0); cy, _ := attr_f32(attrs, "cy", 0); r, _ := attr_f32(attrs, "r", 0)
		if sp := build_ellipse_subpath(cx, cy, r, r); len(sp.pts) >= 3 { append(&sh.subpaths, sp) }
	case "ellipse":
		cx, _ := attr_f32(attrs, "cx", 0); cy, _ := attr_f32(attrs, "cy", 0)
		rx, _ := attr_f32(attrs, "rx", 0); ry, _ := attr_f32(attrs, "ry", 0)
		if sp := build_ellipse_subpath(cx, cy, rx, ry); len(sp.pts) >= 3 { append(&sh.subpaths, sp) }
	case "line":
		emit_line_shape(&sh, attrs)
	case "polyline", "polygon":
		if p, ok := find_attr(attrs, "points"); ok {
			if sp := parse_points_subpath(p, tag == "polygon"); len(sp.pts) >= 2 { append(&sh.subpaths, sp) }
		}
	}
	if len(sh.subpaths) > 0 {
		append(&doc.shapes, sh)
	} else {
		shape_delete(&sh)
	}
}

@(private)
emit_line_shape :: proc(sh: ^Shape, attrs: []Attr) {
	x1, _ := attr_f32(attrs, "x1", 0); y1, _ := attr_f32(attrs, "y1", 0)
	x2, _ := attr_f32(attrs, "x2", 0); y2, _ := attr_f32(attrs, "y2", 0)
	sp := Subpath{closed = false}
	append(&sp.pts, [2]f32{x1, y1}, [2]f32{x2, y2})
	append(&sh.subpaths, sp)
	sh.style.fill = {}
}

@(private)
apply_common_attrs :: proc(attrs: []Attr, st: ^Style, xf: ^Mat2D) {
	for a in attrs {
		switch a.key {
		case "fill":           st.fill = parse_paint(a.val)
		case "stroke":         st.stroke = parse_paint(a.val)
		case "stroke-width":   if v, ok := parse_len_f32(a.val); ok { st.stroke_width = max(0, v) }
		case "opacity":        if v, ok := strconv.parse_f32(a.val); ok { st.opacity *= clamp(v, 0, 1) }
		case "fill-opacity":   if v, ok := strconv.parse_f32(a.val); ok { st.fill_opacity = clamp(v, 0, 1) }
		case "stroke-opacity": if v, ok := strconv.parse_f32(a.val); ok { st.stroke_opacity = clamp(v, 0, 1) }
		case "fill-rule":      st.fill_rule = a.val == "evenodd" ? .Even_Odd : .Nonzero
		case "stroke-linecap": st.stroke_cap = a.val == "round" ? .Round : (a.val == "square" ? .Square : .Butt)
		case "stroke-linejoin":st.stroke_join = a.val == "round" ? .Round : (a.val == "bevel" ? .Bevel : .Miter)
		case "transform":      xf^ = mat2d_mul(xf^, parse_transform(a.val))
		}
	}
}

@(private)
parse_paint :: proc(raw: string) -> Paint {
	s := strings.trim_space(raw)
	if len(s) == 0 || s == "none" || s == "transparent" { return {} }
	if strings.equal_fold(s, "currentColor") {
		return Paint{has_color = true, use_current = true, color = {255, 255, 255, 255}}
	}
	if s[0] == '#' {
		if c, ok := parse_hex_color(s[1:]); ok { return Paint{has_color = true, color = c} }
	}
	if strings.has_prefix(s, "rgb(") || strings.has_prefix(s, "rgba(") {
		if c, ok := parse_rgb_func(s); ok { return Paint{has_color = true, color = c} }
	}
	if c, ok := parse_named_color(s); ok { return Paint{has_color = true, color = c} }
	return {}
}

@(private)
parse_hex_color :: proc(h: string) -> (col: RGBA8, ok: bool) {
	if len(h) == 3 || len(h) == 4 {
		r := hex_val(h[0]) or_return; g := hex_val(h[1]) or_return; b := hex_val(h[2]) or_return
		a := len(h) == 4 ? (hex_val(h[3]) or_return) : u8(15)
		return {r * 17, g * 17, b * 17, a * 17}, true
	}
	if len(h) == 6 || len(h) == 8 {
		r := (hex_val(h[0]) or_return) * 16 + (hex_val(h[1]) or_return)
		g := (hex_val(h[2]) or_return) * 16 + (hex_val(h[3]) or_return)
		b := (hex_val(h[4]) or_return) * 16 + (hex_val(h[5]) or_return)
		a := u8(255)
		if len(h) == 8 { a = (hex_val(h[6]) or_return) * 16 + (hex_val(h[7]) or_return) }
		return {r, g, b, a}, true
	}
	return {}, false
}

@(private)
hex_val :: proc(ch: u8) -> (u8, bool) {
	if ch >= '0' && ch <= '9' { return ch - '0', true }
	if ch >= 'a' && ch <= 'f' { return ch - 'a' + 10, true }
	if ch >= 'A' && ch <= 'F' { return ch - 'A' + 10, true }
	return 0, false
}

@(private)
parse_rgb_func :: proc(s: string) -> (RGBA8, bool) {
	l := strings.index_byte(s, '(')
	r := strings.last_index_byte(s, ')')
	if l < 0 || r <= l { return {}, false }
	nums := parse_num_list(s[l + 1:r])
	if len(nums) < 3 { return {}, false }
	a := len(nums) >= 4 ? u8(clamp(nums[3] <= 1.0 ? nums[3] * 255.0 : nums[3], 0, 255)) : u8(255)
	return {u8(clamp(nums[0], 0, 255)), u8(clamp(nums[1], 0, 255)), u8(clamp(nums[2], 0, 255)), a}, true
}

@(private)
parse_named_color :: proc(s: string) -> (RGBA8, bool) {
	switch s {
	case "white":  return {255, 255, 255, 255}, true
	case "black":  return {0, 0, 0, 255}, true
	case "red":    return {230, 72, 72, 255}, true
	case "green":  return {82, 185, 92, 255}, true
	case "blue":   return {78, 150, 232, 255}, true
	case "gold":   return {235, 212, 118, 255}, true
	case "yellow": return {245, 216, 82, 255}, true
	case "orange": return {242, 152, 62, 255}, true
	case "cyan":   return {96, 224, 240, 255}, true
	case "gray", "grey": return {150, 156, 150, 255}, true
	}
	return {}, false
}

@(private)
parse_transform :: proc(s: string) -> Mat2D {
	res := mat2d_identity()
	i := 0
	for i < len(s) {
		lp := strings.index_byte(s[i:], '(')
		if lp < 0 { break }
		rp := strings.index_byte(s[i + lp:], ')')
		if rp < 0 { break }
		fn := strings.trim_space(s[i:i + lp])
		nums := parse_num_list(s[i + lp + 1:i + lp + rp])
		if fn == "translate" && len(nums) >= 1 {
			res = mat2d_mul(res, mat2d_translate(nums[0], len(nums) >= 2 ? nums[1] : 0))
		} else if fn == "scale" && len(nums) >= 1 {
			res = mat2d_mul(res, mat2d_scale(nums[0], len(nums) >= 2 ? nums[1] : nums[0]))
		} else if fn == "rotate" && len(nums) >= 1 {
			cx := len(nums) >= 3 ? nums[1] : 0
			cy := len(nums) >= 3 ? nums[2] : 0
			res = mat2d_mul(res, mat2d_rotate(nums[0], cx, cy))
		} else if fn == "matrix" && len(nums) >= 6 {
			res = mat2d_mul(res, Mat2D{nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]})
		}
		i = i + lp + rp + 1
	}
	return res
}

@(private)
find_attr :: proc(attrs: []Attr, key: string) -> (string, bool) {
	for a in attrs {
		if a.key == key { return a.val, true }
	}
	return "", false
}

@(private)
attr_f32 :: proc(attrs: []Attr, key: string, def_val: f32) -> (f32, bool) {
	if s, ok := find_attr(attrs, key); ok {
		if v, parsed := parse_len_f32(s); parsed { return v, true }
	}
	return def_val, false
}

@(private)
parse_len_f32 :: proc(s: string) -> (f32, bool) {
	t := strings.trim_space(s)
	t = strings.trim_suffix(t, "px")
	return strconv.parse_f32(t)
}

@(private)
parse_num_list :: proc(s: string) -> []f32 {
	c := Path_Cursor{src = s}
	out := make([dynamic]f32, 0, 8, context.temp_allocator)
	for {
		v, ok := next_num(&c)
		if !ok { break }
		append(&out, v)
	}
	return out[:]
}

@(private)
is_xml_ws :: proc(ch: u8) -> bool {
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
