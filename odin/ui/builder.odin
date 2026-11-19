// Compose-style declarative tree builder in pure Odin (temp_allocator backed, zero leaks).
package ui

import rl "vendor:raylib"

begin :: proc(ctx: ^Context, width, height, dt: f32) {
	ctx.frame_index += 1
	ctx.screen_w = width
	ctx.screen_h = height
	ctx.dt = clamp(dt, 0.0, 0.05)
	ctx.nodes = make([dynamic]UI_Node, 0, 128, context.temp_allocator)
	ctx.parent_top = 0
	ctx.id_top = 0

	root := UI_Node{
		id           = id("root"),
		kind         = .Root,
		mod          = m_size(mod(), width, height),
		first_child  = -1,
		last_child   = -1,
		next_sibling = -1,
	}
	append(&ctx.nodes, root)
	ctx.parent_stack[0] = 0
	ctx.parent_top = 1
}

@(private)
push_node :: proc(ctx: ^Context, n: UI_Node) -> i32 {
	idx := i32(len(ctx.nodes))
	node := n
	node.first_child = -1
	node.last_child = -1
	node.next_sibling = -1
	if ctx.parent_top > 0 {
		parent_idx := ctx.parent_stack[ctx.parent_top - 1]
		node.mod.layer = max(node.mod.layer, ctx.nodes[parent_idx].mod.layer)
	}
	append(&ctx.nodes, node)

	if ctx.parent_top > 0 {
		parent_idx := ctx.parent_stack[ctx.parent_top - 1]
		parent := &ctx.nodes[parent_idx]
		if parent.first_child < 0 {
			parent.first_child = idx
		} else {
			ctx.nodes[parent.last_child].next_sibling = idx
		}
		parent.last_child = idx
	}
	return idx
}

open_container :: proc(ctx: ^Context, wid: UI_Id, kind: Node_Kind, m: Mod) {
	idx := push_node(ctx, UI_Node{id = wid, kind = kind, mod = m})
	if ctx.parent_top < len(ctx.parent_stack) {
		ctx.parent_stack[ctx.parent_top] = idx
		ctx.parent_top += 1
	}
}

close :: proc(ctx: ^Context) {
	if ctx.parent_top > 1 {
		ctx.parent_top -= 1
	}
}

open_row :: proc(ctx: ^Context, wid: UI_Id, m: Mod) {
	open_container(ctx, wid, .Row, m)
}

open_col :: proc(ctx: ^Context, wid: UI_Id, m: Mod) {
	open_container(ctx, wid, .Column, m)
}

open_box :: proc(ctx: ^Context, wid: UI_Id, m: Mod) {
	open_container(ctx, wid, .Box, m)
}

open_card :: proc(ctx: ^Context, wid: UI_Id, m: Mod, radius := RAD_MD) {
	styled := m
	if !styled.has_surface {
		styled = m_surface(styled, style_card(radius))
	}
	open_container(ctx, wid, .Column, styled)
}

open_scrim_modal :: proc(ctx: ^Context, modal_id: UI_Id, layer: u8, close_tag: u32, panel_m: Mod) {
	scrim := m_blocks(m_layer(m_fill(mod()), layer))
	scrim.surface = Surface_Style{
		bg_top = COL_SCRIM,
		bg_bot = COL_SCRIM,
		radius = rad(0),
	}
	scrim.has_surface = true
	if close_tag != 0 {
		scrim = m_click(scrim, close_tag, 0, true)
	}
	scrim.align = .Center
	scrim.justify = .Center
	open_box(ctx, id_combine(modal_id, id("scrim")), scrim)

	pm := m_blocks(m_layer(panel_m, layer))
	if !pm.has_surface {
		pm = m_surface(pm, style_modal())
	}
	open_col(ctx, modal_id, pm)
}

close_scrim_modal :: proc(ctx: ^Context) {
	close(ctx) // modal column
	close(ctx) // scrim box
}

spacer :: proc(ctx: ^Context, weight: f32 = 1.0) {
	push_node(ctx, UI_Node{
		id   = INVALID_ID,
		kind = .Spacer,
		mod  = m_weight(mod(), weight),
	})
}

gap_box :: proc(ctx: ^Context, w, h: f32) {
	push_node(ctx, UI_Node{
		id   = INVALID_ID,
		kind = .Spacer,
		mod  = m_size(mod(), w, h),
	})
}

divider :: proc(ctx: ^Context, vertical := false, m := Mod{}) {
	dm := m.max_w == 0 ? mod() : m
	if vertical {
		dm.width = 1
		dm.fill_h = true
	} else {
		dm.height = 1
		dm.fill_w = true
	}
	_ = push_node(ctx, UI_Node{
		id    = INVALID_ID,
		kind  = .Divider,
		mod   = dm,
		color = COL_BORDER_SUBTLE,
	})
}

ornament_divider :: proc(ctx: ^Context) {
	open_row(ctx, INVALID_ID, m_gap(m_align(m_h(m_fill(mod(), true, false), 10), .Center), 10))
	divider(ctx, false, m_weight(mod(), 1))
	gem := Surface_Style{
		bg_top   = COL_ACTIVE_TOP,
		bg_bot   = COL_ACTIVE_BOT,
		border   = COL_BORDER_GOLD,
		border_w = 1.0,
		radius   = rad(3),
		top_rim  = 0.25,
	}
	open_box(ctx, INVALID_ID, m_surface(m_size(mod(), 14, 6), gem))
	close(ctx)
	divider(ctx, false, m_weight(mod(), 1))
	close(ctx)
}

label :: proc(ctx: ^Context, text: cstring, role: Font_Role, size: f32, col: rl.Color, m := Mod{}) {
	lm := m.max_w == 0 ? mod() : m
	_ = push_node(ctx, UI_Node{
		id        = INVALID_ID,
		kind      = .Text,
		mod       = lm,
		text      = text,
		font_role = role,
		font_size = size,
		color     = col,
	})
}

icon :: proc(ctx: ^Context, tex: rl.Texture2D, size: f32, tint := rl.WHITE, m := Mod{}) {
	im := m.max_w == 0 ? mod() : m
	im = m_size(im, size, size)
	_ = push_node(ctx, UI_Node{
		id        = INVALID_ID,
		kind      = .Icon,
		mod       = im,
		icon_tex  = tex,
		icon_size = size,
		color     = tint,
	})
}

clipped_texture :: proc(
	ctx: ^Context,
	wid: UI_Id,
	tex: rl.Texture2D,
	radius: f32,
	flip_y: bool,
	border_col: rl.Color,
	m: Mod,
	custom_fn: Custom_Draw_Proc = nil,
	custom_data: rawptr = nil,
) {
	cm := m
	cm.surface = Surface_Style{
		border   = border_col,
		border_w = 1.0,
		radius   = rad(radius),
		top_rim  = 0.14,
	}
	idx := push_node(ctx, UI_Node{
		id         = wid,
		kind       = .Clipped_Tex,
		mod        = cm,
		icon_tex   = tex,
		tex_flip_y = flip_y,
		color      = rl.WHITE,
	})
	if custom_fn != nil {
		if ctx.parent_top < len(ctx.parent_stack) {
			ctx.parent_stack[ctx.parent_top] = idx
			ctx.parent_top += 1
			custom(ctx, m_layer(m_fill(mod()), cm.layer), custom_fn, custom_data)
			close(ctx)
		}
	}
}

progress_bar :: proc(ctx: ^Context, wid: UI_Id, ratio: f32, fill_col: rl.Color, m: Mod) {
	pm := m
	if !pm.has_surface {
		pm = m_surface(pm, style_progress(fill_col))
	}
	_ = push_node(ctx, UI_Node{
		id       = wid,
		kind     = .Progress,
		mod      = pm,
		progress = clamp(ratio, 0.0, 1.0),
		color    = fill_col,
	})
}

custom :: proc(ctx: ^Context, m: Mod, fn: Custom_Draw_Proc, user_data: rawptr = nil) {
	_ = push_node(ctx, UI_Node{
		id          = INVALID_ID,
		kind        = .Custom,
		mod         = m,
		custom_fn   = fn,
		custom_data = user_data,
	})
}
