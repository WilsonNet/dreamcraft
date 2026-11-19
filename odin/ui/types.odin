// Core types, FNV-1a widget IDs, Flutter-style BoxConstraints, Compose Modifiers, and Elm events.
package ui

import "core:hash"
import rl "vendor:raylib"

UI_Id :: distinct u64
INVALID_ID :: UI_Id(0)

Constraints :: struct {
	min_w, max_w: f32,
	min_h, max_h: f32,
}

Edges :: struct {
	left, top, right, bottom: f32,
}

Align :: enum u8 {
	Start,
	Center,
	End,
	Stretch,
}

Justify :: enum u8 {
	Start,
	Center,
	End,
	Space_Between,
}

Font_Role :: enum u8 {
	Body,
	Label,
	Medium,
	Bold,
	Heading,
	Mono,
	Mono_Bold,
}

Button_Variant :: enum u8 {
	Secondary,
	Primary,
	Tonal,
	Ghost,
	Danger,
	Tool,
	Compact,
	Bone,
}

Badge_Tone :: enum u8 {
	Neutral,
	Gold,
	Emerald,
	Crimson,
	Cyan,
	Amber,
}

Surface_Style :: struct {
	bg_top:        rl.Color,
	bg_bot:        rl.Color,
	bg_hover:      rl.Color,
	bg_active:     rl.Color,
	border:        rl.Color,
	border_hover:  rl.Color,
	border_active: rl.Color,
	accent:        rl.Color,
	border_w:      f32,
	radius:        [4]f32,
	elevation:     u8,
	top_rim:       f32,
	state_layer:   bool,
	clip_children: bool,
}

Mod :: struct {
	width:          f32,
	height:         f32,
	min_w:          f32,
	min_h:          f32,
	max_w:          f32,
	max_h:          f32,
	fill_w:         bool,
	fill_h:         bool,
	weight:         f32,
	pad:            Edges,
	gap:            f32,
	align:          Align,
	justify:        Justify,
	pos:            [2]f32,
	anchored:       bool,
	has_surface:    bool,
	surface:        Surface_Style,
	clickable:      bool,
	trigger_press:  bool,
	blocks_pointer: bool,
	layer:          u8,
	msg_tag:        u32,
	msg_arg:        i32,
	active:         bool,
	disabled:       bool,
}

UI_Input :: struct {
	mouse:         rl.Vector2,
	left_down:     bool,
	left_pressed:  bool,
	left_released: bool,
	right_pressed: bool,
	wheel_y:       f32,
	dt:            f32,
}

UI_Event :: struct {
	id:    UI_Id,
	tag:   u32,
	arg:   i32,
	mouse: rl.Vector2,
}

Node_Kind :: enum u8 {
	Root,
	Row,
	Column,
	Box,
	Spacer,
	Text,
	Icon,
	Clipped_Tex,
	Progress,
	Divider,
	Custom,
}

Custom_Draw_Proc :: #type proc(rect: rl.Rectangle, user_data: rawptr)

UI_Node :: struct {
	id:           UI_Id,
	kind:         Node_Kind,
	mod:          Mod,
	first_child:  i32,
	last_child:   i32,
	next_sibling: i32,
	size:         [2]f32,
	rect:         rl.Rectangle,
	text:         cstring,
	font_role:    Font_Role,
	font_size:    f32,
	color:        rl.Color,
	icon_tex:     rl.Texture2D,
	icon_size:    f32,
	tex_flip_y:   bool,
	progress:     f32,
	custom_fn:    Custom_Draw_Proc,
	custom_data:  rawptr,
}

id :: proc(name: string) -> UI_Id {
	h := hash.fnv64a(transmute([]u8)name)
	return h == 0 ? UI_Id(1) : UI_Id(h)
}

id_idx :: proc(name: string, idx: int) -> UI_Id {
	h := u64(id(name))
	v := u64(idx) * 0x9e3779b97f4a7c15
	x := h ~ (v + 0x517cc1b727220a95 + (h << 6) + (h >> 2))
	return x == 0 ? UI_Id(1) : UI_Id(x)
}

id_combine :: proc(parent, child: UI_Id) -> UI_Id {
	if parent == INVALID_ID {
		return child
	}
	if child == INVALID_ID {
		return parent
	}
	x := u64(parent) ~ (u64(child) + 0x9e3779b97f4a7c15 + (u64(parent) << 6) + (u64(parent) >> 2))
	return x == 0 ? UI_Id(1) : UI_Id(x)
}

rad :: proc(r: f32) -> [4]f32 {
	return {r, r, r, r}
}

rad_pill :: proc() -> [4]f32 {
	return {255, 255, 255, 255}
}

rad_each :: proc(tl, tr, br, bl: f32) -> [4]f32 {
	return {tl, tr, br, bl}
}

edges_all :: proc(v: f32) -> Edges {
	return {v, v, v, v}
}

edges_xy :: proc(x, y: f32) -> Edges {
	return {x, y, x, y}
}

edges_ltrb :: proc(l, t, r, b: f32) -> Edges {
	return {l, t, r, b}
}

mod :: proc() -> Mod {
	return Mod{
		width   = -1,
		height  = -1,
		max_w   = 1e9,
		max_h   = 1e9,
	}
}

m_size :: proc(m: Mod, w, h: f32) -> Mod {
	r := m
	r.width = w
	r.height = h
	return r
}

m_w :: proc(m: Mod, w: f32) -> Mod {
	r := m
	r.width = w
	return r
}

m_h :: proc(m: Mod, h: f32) -> Mod {
	r := m
	r.height = h
	return r
}

m_min :: proc(m: Mod, min_w, min_h: f32) -> Mod {
	r := m
	r.min_w = min_w
	r.min_h = min_h
	return r
}

m_max :: proc(m: Mod, max_w, max_h: f32) -> Mod {
	r := m
	r.max_w = max_w
	r.max_h = max_h
	return r
}

m_fill :: proc(m: Mod, w := true, h := true) -> Mod {
	r := m
	r.fill_w = w
	r.fill_h = h
	return r
}

m_weight :: proc(m: Mod, w: f32) -> Mod {
	r := m
	r.weight = w
	return r
}

m_pad :: proc(m: Mod, all: f32) -> Mod {
	r := m
	r.pad = edges_all(all)
	return r
}

m_pad_xy :: proc(m: Mod, x, y: f32) -> Mod {
	r := m
	r.pad = edges_xy(x, y)
	return r
}

m_pad_edges :: proc(m: Mod, e: Edges) -> Mod {
	r := m
	r.pad = e
	return r
}

m_gap :: proc(m: Mod, gap: f32) -> Mod {
	r := m
	r.gap = gap
	return r
}

m_align :: proc(m: Mod, align: Align) -> Mod {
	r := m
	r.align = align
	return r
}

m_justify :: proc(m: Mod, justify: Justify) -> Mod {
	r := m
	r.justify = justify
	return r
}

m_at :: proc(m: Mod, x, y: f32) -> Mod {
	r := m
	r.pos = {x, y}
	r.anchored = true
	return r
}

m_surface :: proc(m: Mod, s: Surface_Style) -> Mod {
	r := m
	r.has_surface = true
	r.surface = s
	return r
}

m_click :: proc(m: Mod, tag: u32, arg: i32 = 0, on_press := true) -> Mod {
	r := m
	r.clickable = true
	r.trigger_press = on_press
	r.blocks_pointer = true
	r.msg_tag = tag
	r.msg_arg = arg
	return r
}

m_blocks :: proc(m: Mod, block := true) -> Mod {
	r := m
	r.blocks_pointer = block
	return r
}

m_layer :: proc(m: Mod, layer: u8) -> Mod {
	r := m
	r.layer = layer
	return r
}
