// Compiles the placed UI tree into a z-layered Display_List with animated Widget_Memory states.
package ui

import "core:math"
import rl "vendor:raylib"

build_display_list :: proc(ctx: ^Context) -> []Draw_Cmd {
	if len(ctx.nodes) == 0 {
		return nil
	}
	cmds := make([dynamic]Draw_Cmd, 0, len(ctx.nodes) * 2, context.temp_allocator)
	for layer in 0..<MAX_LAYERS {
		emit_layer_node(ctx, 0, u8(layer), &cmds)
	}
	return cmds[:]
}

@(private)
emit_layer_node :: proc(ctx: ^Context, idx: i32, target_layer: u8, cmds: ^[dynamic]Draw_Cmd) {
	node := &ctx.nodes[idx]
	visible_here := node.mod.layer == target_layer
	clipped := false
	if visible_here {
		clipped = node.mod.has_surface && node.mod.surface.clip_children
		emit_node_self(ctx, node, cmds)
		if clipped {
			append(cmds, Draw_Cmd{kind = .Scissor_Push, rect = node.rect})
		}
	}
	child := node.first_child
	for child >= 0 {
		emit_layer_node(ctx, child, target_layer, cmds)
		child = ctx.nodes[child].next_sibling
	}
	if clipped {
		append(cmds, Draw_Cmd{kind = .Scissor_Pop})
	}
}

@(private)
emit_node_self :: proc(ctx: ^Context, node: ^UI_Node, cmds: ^[dynamic]Draw_Cmd) {
	switch node.kind {
	case .Root, .Spacer:
		return
	case .Row, .Column, .Box:
		if node.mod.has_surface {
			append_surface_cmd(ctx, node, cmds, 0, 0)
		}
	case .Progress:
		append_surface_cmd(ctx, node, cmds, 1, node.progress)
	case .Divider:
		col := node.color.a > 0 ? node.color : COL_BORDER_SUBTLE
		append(cmds, Draw_Cmd{kind = .SDF_Box, rect = node.rect, bg_top = col, bg_bot = col})
	case .Text, .Icon, .Clipped_Tex, .Custom:
		emit_leaf_node(node, cmds)
	}
}

@(private)
emit_leaf_node :: proc(node: ^UI_Node, cmds: ^[dynamic]Draw_Cmd) {
	#partial switch node.kind {
	case .Text:
		if len(node.text) > 0 {
			append(cmds, Draw_Cmd{kind = .Text, rect = node.rect, text = node.text, font_role = node.font_role, font_size = node.font_size, bg_top = node.color})
		}
	case .Icon:
		if node.icon_tex.id > 0 {
			append(cmds, Draw_Cmd{kind = .Icon, rect = node.rect, tex = node.icon_tex, bg_top = node.color})
		}
	case .Clipped_Tex:
		append(cmds, Draw_Cmd{
			kind = .Clipped_Tex, rect = node.rect, radius = node.mod.surface.radius,
			border_col = node.mod.surface.border, border_w = node.mod.surface.border_w,
			top_rim = node.mod.surface.top_rim, tex = node.icon_tex, tex_flip_y = node.tex_flip_y, bg_top = node.color,
		})
	case .Custom:
		if node.custom_fn != nil {
			append(cmds, Draw_Cmd{kind = .Custom, rect = node.rect, custom_fn = node.custom_fn, custom_data = node.custom_data})
		}
	}
}

@(private)
append_surface_cmd :: proc(ctx: ^Context, node: ^UI_Node, cmds: ^[dynamic]Draw_Cmd, mode: u8, prog: f32) {
	s := node.mod.surface
	hov, prs, act, app_t, rip_t, rip_uv := sample_slot_anim(ctx, node.id, node.mod.active)
	bg_top, bg_bot, b_col := resolve_surface_colors(s, hov, act, node.mod.disabled)
	rect := node.rect
	if prs > 0.01 && s.state_layer && min(rect.width, rect.height) >= 18 {
		shrink := prs * 0.8
		rect = {rect.x + shrink, rect.y + shrink + prs * 0.4, max(2, rect.width - shrink * 2), max(2, rect.height - shrink * 2)}
	}
	blur, off_y, s_alpha := elevation_shadow(s.elevation, hov, prs, app_t)
	_ = math.round(rect.x)
	append(cmds, Draw_Cmd{
		kind = .SDF_Box, rect = rect, radius = s.radius, bg_top = bg_top, bg_bot = bg_bot, border_col = b_col,
		shadow_col = rl.Color{4, 7, 5, s_alpha}, accent_col = s.accent, border_w = s.border_w,
		top_rim = clamp(s.top_rim + hov * 0.08 + act * 0.06, 0, 0.45), shadow_blur = blur, shadow_off = off_y,
		state_lift = s.state_layer ? clamp(hov * 0.55 + prs * 0.35, 0, 1) : 0,
		ripple_t = s.state_layer ? rip_t : 0, ripple_uv = rip_uv, progress = prog, mode = mode,
	})
}

@(private)
resolve_surface_colors :: proc(s: Surface_Style, hov, act: f32, disabled: bool) -> (bg_top, bg_bot, b_col: rl.Color) {
	bg_top = s.bg_top
	bg_bot = s.bg_bot.a > 0 ? s.bg_bot : s.bg_top
	b_col = s.border
	if !s.state_layer || disabled {
		return
	}
	if s.bg_hover.a > 0 && hov > 0.001 {
		bg_top = color_lerp(bg_top, s.bg_hover, hov)
		bg_bot = color_lerp(bg_bot, s.bg_hover, hov * 0.85)
	}
	if s.bg_active.a > 0 && act > 0.001 {
		bg_top = color_lerp(bg_top, s.bg_active, act)
		bg_bot = color_lerp(bg_bot, color_darken(s.bg_active, 0.72), act)
	}
	if s.border_hover.a > 0 && hov > 0.001 { b_col = color_lerp(b_col, s.border_hover, hov) }
	if s.border_active.a > 0 && act > 0.001 { b_col = color_lerp(b_col, s.border_active, act) }
	return
}

@(private)
sample_slot_anim :: proc(ctx: ^Context, wid: UI_Id, def_active: bool) -> (hov, prs, act, app_t, rip_t: f32, rip_uv: [2]f32) {
	act = def_active ? 1.0 : 0.0
	app_t = 1.0
	slot, ok := slot_find(ctx, wid)
	if !ok {
		return
	}
	return slot.hover_t, slot.press_t, slot.active_t, slot.appear_t, slot.ripple_t, slot.ripple_uv
}

@(private)
elevation_shadow :: proc(elev: u8, hov, prs, app_t: f32) -> (blur, off_y: f32, alpha: u8) {
	if elev == 0 {
		return 0, 0, 0
	}
	base_blur := f32(elev) * 4.5 + 2.0 + hov * 2.5 - prs * 2.0
	base_off := f32(elev) * 2.0 + hov * 1.0 - prs * 1.2
	base_a := min(f32(elev) * 44.0 + 36.0 + hov * 20.0, 190.0) * clamp(app_t, 0.2, 1.0)
	return max(0, base_blur), max(0, base_off), u8(base_a)
}

@(private)
color_darken :: proc(c: rl.Color, k: f32) -> rl.Color {
	return rl.Color{u8(f32(c.r) * k), u8(f32(c.g) * k), u8(f32(c.b) * k), c.a}
}
