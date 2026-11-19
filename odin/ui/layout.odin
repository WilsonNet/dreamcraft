// Flutter / Compose single-pass BoxConstraints layout solver (Measure + Place) and hit collection.
package ui

import "core:math"
import rl "vendor:raylib"

finish_layout :: proc(ctx: ^Context) {
	if len(ctx.nodes) == 0 {
		ctx.prev_hit_count = 0
		return
	}
	root_c := Constraints{
		min_w = ctx.screen_w,
		max_w = ctx.screen_w,
		min_h = ctx.screen_h,
		max_h = ctx.screen_h,
	}
	measure_node(ctx, 0, root_c)
	place_node(ctx, 0, 0, 0)
	ctx.prev_hit_count = 0
	collect_hits(ctx, 0, false, {})
}

resolve_constraints :: proc(m: Mod, incoming: Constraints) -> Constraints {
	c := incoming
	if m.min_w > 0 { c.min_w = max(c.min_w, m.min_w) }
	if m.min_h > 0 { c.min_h = max(c.min_h, m.min_h) }
	if m.max_w < c.max_w { c.max_w = max(c.min_w, m.max_w) }
	if m.max_h < c.max_h { c.max_h = max(c.min_h, m.max_h) }
	if m.width >= 0 {
		w := clamp(m.width, c.min_w, c.max_w)
		c.min_w, c.max_w = w, w
	} else if m.fill_w && c.max_w < 1e8 {
		c.min_w = c.max_w
	}
	if m.height >= 0 {
		h := clamp(m.height, c.min_h, c.max_h)
		c.min_h, c.max_h = h, h
	} else if m.fill_h && c.max_h < 1e8 {
		c.min_h = c.max_h
	}
	return c
}

@(private)
measure_node :: proc(ctx: ^Context, idx: i32, incoming: Constraints) -> [2]f32 {
	node := &ctx.nodes[idx]
	c := resolve_constraints(node.mod, incoming)
	inner := shrink_constraints(c, node.mod.pad)
	sz: [2]f32
	switch node.kind {
	case .Root, .Box:
		sz = measure_box(ctx, idx, inner)
	case .Row:
		sz = measure_flex(ctx, idx, inner, true, node.mod.gap)
	case .Column:
		sz = measure_flex(ctx, idx, inner, false, node.mod.gap)
	case .Spacer, .Divider:
		sz = {0, 0}
	case .Text:
		sz = measure_text_leaf(ctx, node, inner)
	case .Icon:
		sz = {node.icon_size, node.icon_size}
	case .Clipped_Tex, .Progress, .Custom:
		sz = {c.min_w > 0 ? c.min_w : 120, c.min_h > 0 ? c.min_h : 24}
	}
	pad := node.mod.pad
	w := clamp(sz[0] + pad.left + pad.right, c.min_w, c.max_w)
	h := clamp(sz[1] + pad.top + pad.bottom, c.min_h, c.max_h)
	ctx.nodes[idx].size = {w, h}
	return ctx.nodes[idx].size
}

@(private)
shrink_constraints :: proc(c: Constraints, p: Edges) -> Constraints {
	px := p.left + p.right
	py := p.top + p.bottom
	return Constraints{
		min_w = max(0, c.min_w - px),
		max_w = max(0, c.max_w - px),
		min_h = max(0, c.min_h - py),
		max_h = max(0, c.max_h - py),
	}
}

@(private)
measure_box :: proc(ctx: ^Context, idx: i32, inner: Constraints) -> [2]f32 {
	max_size := [2]f32{0, 0}
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		ch := &ctx.nodes[child]
		csz := measure_node(ctx, child, Constraints{0, inner.max_w, 0, inner.max_h})
		if !ch.mod.anchored {
			max_size[0] = max(max_size[0], csz[0])
			max_size[1] = max(max_size[1], csz[1])
		}
		child = ctx.nodes[child].next_sibling
	}
	// Re-measure fill children if parent box grew wider/taller via siblings.
	target_c := Constraints{
		min_w = inner.min_w,
		max_w = min(inner.max_w, max(inner.min_w, max_size[0])),
		min_h = inner.min_h,
		max_h = min(inner.max_h, max(inner.min_h, max_size[1])),
	}
	child = ctx.nodes[idx].first_child
	for child >= 0 {
		cm := ctx.nodes[child].mod
		if !cm.anchored && (cm.fill_w || cm.fill_h) {
			measure_node(ctx, child, target_c)
		}
		child = ctx.nodes[child].next_sibling
	}
	return max_size
}

@(private)
measure_flex :: proc(ctx: ^Context, idx: i32, inner: Constraints, horiz: bool, gap: f32) -> [2]f32 {
	main_max := horiz ? inner.max_w : inner.max_h
	cross_max := horiz ? inner.max_h : inner.max_w
	fixed_main, total_w, max_cross: f32
	count, weighted := 0, 0
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		count += 1
		cm := ctx.nodes[child].mod
		if cm.weight > 0 {
			total_w += cm.weight
			weighted += 1
		} else {
			cc := horiz ? Constraints{0, max(0, main_max - fixed_main), 0, cross_max} : Constraints{0, cross_max, 0, max(0, main_max - fixed_main)}
			csz := measure_node(ctx, child, cc)
			fixed_main += horiz ? csz[0] : csz[1]
			max_cross = max(max_cross, horiz ? csz[1] : csz[0])
		}
		child = ctx.nodes[child].next_sibling
	}
	gaps := count > 1 ? gap * f32(count - 1) : 0
	if weighted > 0 && total_w > 0 {
		avail := max(0, main_max - fixed_main - gaps)
		fixed_main += measure_weighted_children(ctx, idx, horiz, cross_max, avail, total_w, &max_cross)
	}
	total_main := fixed_main + gaps
	return horiz ? [2]f32{total_main, max_cross} : [2]f32{max_cross, total_main}
}

@(private)
measure_weighted_children :: proc(ctx: ^Context, idx: i32, horiz: bool, cross_max, avail, total_w: f32, max_cross: ^f32) -> f32 {
	used := f32(0)
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		w := ctx.nodes[child].mod.weight
		if w > 0 {
			share := avail * (w / total_w)
			cc := horiz ? Constraints{share, share, 0, cross_max} : Constraints{0, cross_max, share, share}
			if ctx.nodes[child].mod.fill_w && !horiz { cc.min_w = cross_max }
			if ctx.nodes[child].mod.fill_h && horiz { cc.min_h = cross_max }
			csz := measure_node(ctx, child, cc)
			used += horiz ? csz[0] : csz[1]
			max_cross^ = max(max_cross^, horiz ? csz[1] : csz[0])
		}
		child = ctx.nodes[child].next_sibling
	}
	return used
}

@(private)
measure_text_leaf :: proc(ctx: ^Context, node: ^UI_Node, inner: Constraints) -> [2]f32 {
	if len(node.text) == 0 {
		return {0, node.font_size}
	}
	if ctx.measure_text_fn != nil {
		m := ctx.measure_text_fn(ctx.measure_user, node.text, node.font_role, node.font_size)
		return {min(m[0], inner.max_w), m[1]}
	}
	est := f32(len(node.text)) * node.font_size * 0.54
	return {min(est, inner.max_w), node.font_size * 1.15}
}

@(private)
place_node :: proc(ctx: ^Context, idx: i32, x, y: f32) {
	node := &ctx.nodes[idx]
	node.rect = {math.round(x), math.round(y), node.size[0], node.size[1]}
	pad := node.mod.pad
	ix := x + pad.left
	iy := y + pad.top
	iw := max(0, node.size[0] - pad.left - pad.right)
	ih := max(0, node.size[1] - pad.top - pad.bottom)
	switch node.kind {
	case .Root, .Box:
		place_box_children(ctx, idx, ix, iy, iw, ih, node.mod.align, node.mod.justify)
	case .Row:
		place_flex_children(ctx, idx, true, ix, iy, iw, ih, node.mod)
	case .Column:
		place_flex_children(ctx, idx, false, ix, iy, iw, ih, node.mod)
	case .Spacer, .Text, .Icon, .Clipped_Tex, .Progress, .Divider, .Custom:
	}
}

@(private)
place_box_children :: proc(ctx: ^Context, idx: i32, ix, iy, iw, ih: f32, def_align: Align, def_justify: Justify) {
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		ch := &ctx.nodes[child]
		cm := ch.mod
		if cm.anchored {
			place_node(ctx, child, ix + cm.pos[0], iy + cm.pos[1])
		} else {
			if cm.fill_w { ch.size[0] = iw }
			if cm.fill_h { ch.size[1] = ih }
			cj := cm.justify != .Start ? cm.justify : def_justify
			ca := cm.align != .Start ? cm.align : def_align
			cx := align_offset(ix, iw, ch.size[0], justify_to_align(cj))
			cy := align_offset(iy, ih, ch.size[1], ca)
			place_node(ctx, child, cx, cy)
		}
		child = ctx.nodes[child].next_sibling
	}
}

@(private)
justify_to_align :: proc(j: Justify) -> Align {
	switch j {
	case .Center: return .Center
	case .End:    return .End
	case .Start, .Space_Between:
	}
	return .Start
}

@(private)
place_flex_children :: proc(ctx: ^Context, idx: i32, horiz: bool, ix, iy, iw, ih: f32, m: Mod) {
	used, gap, start := flex_spacing(ctx, idx, horiz, horiz ? iw : ih, m.gap, m.justify)
	_ = used
	cursor := (horiz ? ix : iy) + start
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		ch := &ctx.nodes[child]
		cross_avail := horiz ? ih : iw
		child_align := ch.mod.align != .Start ? ch.mod.align : m.align
		if child_align == .Stretch || (horiz && ch.mod.fill_h) || (!horiz && ch.mod.fill_w) {
			if horiz { ch.size[1] = ih } else { ch.size[0] = iw }
		}
		cross_pos := align_offset(horiz ? iy : ix, cross_avail, horiz ? ch.size[1] : ch.size[0], child_align)
		cx := horiz ? cursor : cross_pos
		cy := horiz ? cross_pos : cursor
		place_node(ctx, child, cx, cy)
		cursor += (horiz ? ch.size[0] : ch.size[1]) + gap
		child = ctx.nodes[child].next_sibling
	}
}

@(private)
flex_spacing :: proc(ctx: ^Context, idx: i32, horiz: bool, avail, base_gap: f32, j: Justify) -> (used, gap, start: f32) {
	count := 0
	child := ctx.nodes[idx].first_child
	for child >= 0 {
		used += horiz ? ctx.nodes[child].size[0] : ctx.nodes[child].size[1]
		count += 1
		child = ctx.nodes[child].next_sibling
	}
	gap = base_gap
	total := used + (count > 1 ? gap * f32(count - 1) : 0)
	rem := max(0, avail - total)
	switch j {
	case .Start:
	case .Center:        start = rem * 0.5
	case .End:           start = rem
	case .Space_Between: gap = count > 1 ? base_gap + rem / f32(count - 1) : base_gap
	}
	return
}

@(private)
align_offset :: proc(origin, avail, item: f32, a: Align) -> f32 {
	switch a {
	case .Center:           return origin + (avail - item) * 0.5
	case .End:              return origin + avail - item
	case .Start, .Stretch:  return origin
	}
	return origin
}

@(private)
collect_hits :: proc(ctx: ^Context, idx: i32, has_clip: bool, clip_r: rl.Rectangle) {
	node := &ctx.nodes[idx]
	if node.id != INVALID_ID {
		if slot, ok := slot_touch(ctx, node.id); ok {
			if slot.rect.width == 0 && slot.rect.height == 0 && node.mod.active {
				slot.active_t = 1.0
			}
			slot.rect = node.rect
			slot.target_active = node.mod.active
		}
	}
	if (node.mod.clickable || node.mod.blocks_pointer) && ctx.prev_hit_count < MAX_HITS {
		ctx.prev_hits[ctx.prev_hit_count] = Hit_Entry{
			id             = node.id,
			rect           = node.rect,
			clip_rect      = clip_r,
			has_clip       = has_clip,
			layer          = node.mod.layer,
			clickable      = node.mod.clickable,
			trigger_press  = node.mod.trigger_press,
			blocks_pointer = node.mod.blocks_pointer,
			disabled       = node.mod.disabled,
			msg_tag        = node.mod.msg_tag,
			msg_arg        = node.mod.msg_arg,
		}
		ctx.prev_hit_count += 1
	}
	next_clip, next_has := clip_r, has_clip
	if node.mod.has_surface && node.mod.surface.clip_children {
		next_clip = next_has ? intersect_rect(clip_r, node.rect) : node.rect
		next_has = true
	}
	child := node.first_child
	for child >= 0 {
		collect_hits(ctx, child, next_has, next_clip)
		child = ctx.nodes[child].next_sibling
	}
}

intersect_rect :: proc(a, b: rl.Rectangle) -> rl.Rectangle {
	x0 := max(a.x, b.x)
	y0 := max(a.y, b.y)
	x1 := min(a.x + a.width, b.x + b.width)
	y1 := min(a.y + a.height, b.y + b.height)
	return {x0, y0, max(0, x1 - x0), max(0, y1 - y0)}
}
