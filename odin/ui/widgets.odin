// Quickshell-styled high-level widgets (Buttons, Keycaps, Badges, Segmented Tabs, Swatches, Raw Bars).
package ui

import "core:math"
import rl "vendor:raylib"

Button_Opts :: struct {
	label:       cstring,
	keycap:      cstring,
	icon_tex:    rl.Texture2D,
	icon_tint:   rl.Color,
	icon_size:   f32,
	variant:     Button_Variant,
	active:      bool,
	disabled:    bool,
	center_text: bool,
	font_size:   f32,
	msg_tag:     u32,
	msg_arg:     i32,
}

button :: proc(ctx: ^Context, wid: UI_Id, opts: Button_Opts, m := Mod{}) {
	bm := m.max_w == 0 ? mod() : m
	bm = m_surface(bm, style_button(opts.variant))
	bm.active = opts.active
	bm.disabled = opts.disabled
	if opts.msg_tag != 0 {
		bm = m_click(bm, opts.msg_tag, opts.msg_arg, true)
	}
	if bm.pad.left == 0 && bm.pad.right == 0 {
		bm.pad = opts.variant == .Compact || opts.variant == .Bone ? edges_xy(8, 3) : edges_xy(10, 5)
	}
	bm.align = .Center
	if opts.center_text && len(opts.keycap) == 0 {
		bm.justify = .Center
	}
	if bm.gap == 0 {
		bm.gap = 7
	}
	fs := opts.font_size > 0 ? opts.font_size : (opts.variant == .Compact || opts.variant == .Bone ? f32(12) : f32(14))
	fg := button_fg(opts, ctx, wid)
	icon_col := opts.icon_tint.a > 0 ? opts.icon_tint : fg
	isz := opts.icon_size > 0 ? opts.icon_size : (opts.variant == .Compact ? f32(15) : f32(17))

	open_row(ctx, wid, bm)
	if opts.icon_tex.id > 0 {
		icon(ctx, opts.icon_tex, isz, icon_col)
	}
	if len(opts.label) > 0 {
		role: Font_Role = opts.active || opts.variant == .Primary ? .Medium : .Body
		label(ctx, opts.label, role, fs, fg)
	}
	if len(opts.keycap) > 0 {
		if bm.fill_w || bm.width > 0 || bm.weight > 0 {
			spacer(ctx, 1)
		} else {
			gap_box(ctx, 4, 1)
		}
		keycap(ctx, opts.keycap, opts.active ? .Gold : .Neutral, m_layer(mod(), bm.layer))
	}
	close(ctx)
}

@(private)
button_fg :: proc(opts: Button_Opts, ctx: ^Context, wid: UI_Id) -> rl.Color {
	if opts.disabled {
		return COL_TEXT_MUTED
	}
	if opts.active {
		return COL_TEXT_ACTIVE
	}
	if is_hovered(ctx, wid) {
		return COL_TEXT_PRIMARY
	}
	if opts.variant == .Primary {
		return rl.Color{250, 246, 236, 255}
	}
	return rl.Color{240, 230, 214, 255}
}

badge :: proc(ctx: ^Context, wid: UI_Id, text: cstring, tone: Badge_Tone, m := Mod{}, msg_tag: u32 = 0, msg_arg: i32 = 0) {
	bm := m.max_w == 0 ? mod() : m
	surf, fg := style_badge(tone)
	bm = m_surface(bm, surf)
	if bm.pad.left == 0 {
		bm.pad = edges_xy(9, 4)
	}
	bm.align = .Center
	bm.justify = .Center
	if msg_tag != 0 {
		bm = m_click(bm, msg_tag, msg_arg, true)
	}
	open_row(ctx, wid, bm)
	label(ctx, text, .Mono_Bold, 11, fg)
	close(ctx)
}

keycap :: proc(ctx: ^Context, text: cstring, tone := Badge_Tone.Neutral, m := Mod{}, size: f32 = 11) {
	km := m.max_w == 0 ? mod() : m
	km = m_surface(km, style_keycap())
	if km.pad.left == 0 {
		km.pad = edges_xy(6, 2.5)
	}
	km.align = .Center
	km.justify = .Center
	fg := COL_TEXT_GOLD
	if tone == .Cyan { fg = COL_TEXT_PATROL }
	if tone == .Emerald { fg = COL_TEXT_MOVE }
	if tone == .Crimson { fg = COL_TEXT_ATTACK }
	open_row(ctx, INVALID_ID, km)
	label(ctx, text, .Mono_Bold, size, fg)
	close(ctx)
}

segmented_tab :: proc(
	ctx: ^Context,
	wid: UI_Id,
	text: cstring,
	icon_tex: rl.Texture2D,
	selected: bool,
	msg_tag: u32,
	msg_arg: i32,
	m := Mod{},
) {
	tm := m.max_w == 0 ? mod() : m
	tm = m_surface(tm, style_tab(selected))
	tm = m_click(tm, msg_tag, msg_arg, true)
	tm.active = selected
	if tm.pad.left == 0 {
		tm.pad = edges_xy(8, 5)
	}
	tm.gap = 5
	tm.align = .Center
	tm.justify = .Center
	fg := selected ? COL_TEXT_ACTIVE : COL_TEXT_SECONDARY
	open_row(ctx, wid, tm)
	if icon_tex.id > 0 {
		icon(ctx, icon_tex, 15, fg)
	}
	label(ctx, text, selected ? .Medium : .Body, 13, fg)
	close(ctx)
}

swatch :: proc(ctx: ^Context, wid: UI_Id, fill: rl.Color, selected: bool, msg_tag: u32, msg_arg: i32, m := Mod{}) {
	sm := m.max_w == 0 ? mod() : m
	sm = m_surface(sm, style_swatch(fill, selected))
	sm = m_click(sm, msg_tag, msg_arg, true)
	sm.active = selected
	open_box(ctx, wid, sm)
	close(ctx)
}

// Raw immediate helpers for world-space projected bars & drag marquee boxes (zero Widget_Memory usage).
draw_raw_bar :: proc(r: ^Renderer, rect: rl.Rectangle, ratio: f32, fill, border: rl.Color) {
	rad := min(rect.width, rect.height) * 0.5
	if !r.use_shaders {
		rl.DrawRectangleRounded(rect, 0.9, 6, rl.Color{14, 18, 16, 225})
		fw := rect.width * clamp(ratio, 0, 1)
		if fw > 1 {
			rl.DrawRectangleRounded({rect.x + 1, rect.y + 1, max(fw - 2, 1), max(rect.height - 2, 1)}, 0.9, 6, fill)
		}
		rl.DrawRectangleRoundedLinesEx(rect, 0.9, 6, 1, border)
		return
	}
	cmds := [1]Draw_Cmd{{
		kind       = .SDF_Box,
		rect       = rect,
		radius     = rad_each(rad, rad, rad, rad),
		bg_top     = rl.Color{14, 18, 16, 232},
		bg_bot     = rl.Color{10, 13, 12, 232},
		border_col = border,
		accent_col = fill,
		border_w   = 1.0,
		top_rim    = 0.12,
		progress   = clamp(ratio, 0, 1),
		mode       = 1,
	}}
	draw_sdf_batch(r, cmds[:])
}

draw_raw_pill :: proc(r: ^Renderer, rect: rl.Rectangle, bg_top, bg_bot, border: rl.Color, radius: f32 = 8, rim: f32 = 0.10) {
	if !r.use_shaders {
		rn := clamp((radius * 2) / max(min(rect.width, rect.height), 1), 0, 1)
		rl.DrawRectangleRounded(rect, rn, 8, bg_top)
		rl.DrawRectangleRoundedLinesEx(rect, rn, 8, 1, border)
		return
	}
	cmds := [1]Draw_Cmd{{
		kind       = .SDF_Box,
		rect       = rect,
		radius     = ui_rad4(radius),
		bg_top     = bg_top,
		bg_bot     = bg_bot,
		border_col = border,
		border_w   = 1.0,
		top_rim    = rim,
	}}
	draw_sdf_batch(r, cmds[:])
}

@(private)
ui_rad4 :: proc(v: f32) -> [4]f32 {
	x := clamp(v, 0, 255)
	return {x, x, x, x}
}

measure_ctx_text :: proc(ctx: ^Context, text: cstring, role: Font_Role, size: f32) -> [2]f32 {
	if ctx.measure_text_fn != nil {
		m := ctx.measure_text_fn(ctx.measure_user, text, role, size)
		return {math.ceil(m[0]), math.ceil(m[1])}
	}
	return {f32(len(text)) * size * 0.54, size * 1.15}
}
