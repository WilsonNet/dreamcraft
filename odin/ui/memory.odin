// Retained widget memory (0-alloc open-addressed table) + UI Context & Frame/Layer state.
package ui

import "core:math"
import rl "vendor:raylib"

MAX_WIDGET_SLOTS :: 512
MAX_UI_EVENTS :: 64
MAX_HITS :: 256
MAX_LAYERS :: 4
MAX_DRAW_CMDS :: 512

Widget_Slot :: struct {
	id:            UI_Id,
	occupied:      bool,
	last_seen:     u64,
	target_active: bool,
	rect:          rl.Rectangle,
	hover_t:   f32,
	hover_v:   f32,
	press_t:   f32,
	press_v:   f32,
	active_t:  f32,
	active_v:  f32,
	appear_t:  f32,
	appear_v:  f32,
	ripple_t:  f32,
	ripple_uv: [2]f32,
}

Hit_Entry :: struct {
	id:             UI_Id,
	rect:           rl.Rectangle,
	clip_rect:      rl.Rectangle,
	has_clip:       bool,
	layer:          u8,
	clickable:      bool,
	trigger_press:  bool,
	blocks_pointer: bool,
	disabled:       bool,
	msg_tag:        u32,
	msg_arg:        i32,
}

Draw_Cmd_Kind :: enum u8 {
	SDF_Box,
	Clipped_Tex,
	Text,
	Icon,
	Scissor_Push,
	Scissor_Pop,
	Custom,
}

Draw_Cmd :: struct {
	kind:        Draw_Cmd_Kind,
	rect:        rl.Rectangle,
	radius:      [4]f32,
	bg_top:      rl.Color,
	bg_bot:      rl.Color,
	border_col:  rl.Color,
	shadow_col:  rl.Color,
	accent_col:  rl.Color,
	border_w:    f32,
	top_rim:     f32,
	shadow_blur: f32,
	shadow_off:  f32,
	state_lift:  f32,
	ripple_t:    f32,
	ripple_uv:   [2]f32,
	progress:    f32,
	mode:        u8,
	text:        cstring,
	font_role:   Font_Role,
	font_size:   f32,
	tex:         rl.Texture2D,
	tex_flip_y:  bool,
	custom_fn:   Custom_Draw_Proc,
	custom_data: rawptr,
}

FONT_SIZE_STEPS :: 7

Font_Atlas_Idx :: enum u8 {
	Display_Serif,
	Sans_Regular,
	Sans_Bold,
	Mono_Regular,
	Mono_Bold,
}

Font_Pack :: struct {
	baked:       [Font_Atlas_Idx][FONT_SIZE_STEPS]rl.Font,
	dpi_scale:   f32,
	fonts_ready: bool,
}

Renderer :: struct {
	sdf_shader:   rl.Shader,
	sdf_ready:    bool,
	clip_shader:  rl.Shader,
	clip_ready:   bool,
	clip_locs:    Clip_Uniforms,
	white_tex:    rl.Texture2D,
	data_tex:     rl.Texture2D,
	data_pixels:  [MAX_DRAW_CMDS * 8 * 4]u8,
	fonts:        Font_Pack,
	use_shaders:  bool,
	initialized:  bool,
}

Clip_Uniforms :: struct {
	size:      i32,
	uv_rect:   i32,
	radius:    i32,
	border_w:  i32,
	border:    i32,
	rim_alpha: i32,
}

Context :: struct {
	nodes:           [dynamic]UI_Node,
	parent_stack:    [32]i32,
	parent_top:      int,
	id_stack:        [32]UI_Id,
	id_top:          int,
	slots:           [MAX_WIDGET_SLOTS]Widget_Slot,
	slot_count:      int,
	prev_hits:       [MAX_HITS]Hit_Entry,
	prev_hit_count:  int,
	events:          [MAX_UI_EVENTS]UI_Event,
	event_count:     int,
	hovered_id:      UI_Id,
	pressed_id:      UI_Id,
	pointer_blocked: bool,
	frame_index:     u64,
	screen_w:        f32,
	screen_h:        f32,
	dt:              f32,
	measure_text_fn: proc(user: rawptr, text: cstring, role: Font_Role, size: f32) -> [2]f32,
	measure_user:    rawptr,
	renderer:        Renderer,
}

slot_find :: proc(ctx: ^Context, wid: UI_Id) -> (^Widget_Slot, bool) {
	if wid == INVALID_ID {
		return nil, false
	}
	mask := u64(MAX_WIDGET_SLOTS - 1)
	idx := int(u64(wid) & mask)
	for _ in 0..<MAX_WIDGET_SLOTS {
		slot := &ctx.slots[idx]
		if !slot.occupied {
			return nil, false
		}
		if slot.id == wid {
			return slot, true
		}
		idx = (idx + 1) & int(mask)
	}
	return nil, false
}

slot_touch :: proc(ctx: ^Context, wid: UI_Id) -> (^Widget_Slot, bool) {
	if wid == INVALID_ID {
		return nil, false
	}
	if ctx.slot_count >= (MAX_WIDGET_SLOTS * 3) / 4 {
		evict_stale_slots(ctx, 120)
	}
	mask := u64(MAX_WIDGET_SLOTS - 1)
	idx := int(u64(wid) & mask)
	for _ in 0..<MAX_WIDGET_SLOTS {
		slot := &ctx.slots[idx]
		if !slot.occupied {
			slot^ = Widget_Slot{
				id        = wid,
				occupied  = true,
				last_seen = ctx.frame_index,
			}
			ctx.slot_count += 1
			return slot, true
		}
		if slot.id == wid {
			slot.last_seen = ctx.frame_index
			return slot, true
		}
		idx = (idx + 1) & int(mask)
	}
	return nil, false
}

evict_stale_slots :: proc(ctx: ^Context, max_age: u64) {
	mask := MAX_WIDGET_SLOTS - 1
	i := 0
	for i < MAX_WIDGET_SLOTS {
		if ctx.slots[i].occupied && ctx.frame_index - ctx.slots[i].last_seen > max_age {
			remove_slot_at(ctx, i, mask)
			continue
		}
		i += 1
	}
}

@(private)
remove_slot_at :: proc(ctx: ^Context, empty_idx, mask: int) {
	hole := empty_idx
	ctx.slots[hole] = {}
	ctx.slot_count -= 1
	cur := (hole + 1) & mask
	for ctx.slots[cur].occupied {
		ideal := int(u64(ctx.slots[cur].id) & u64(mask))
		dist_cur := (cur - ideal) & mask
		dist_hole := (cur - hole) & mask
		if dist_cur >= dist_hole {
			ctx.slots[hole] = ctx.slots[cur]
			ctx.slots[cur] = {}
			hole = cur
		}
		cur = (cur + 1) & mask
	}
}

spring_step :: proc(val, vel: ^f32, target, stiffness, damping, dt: f32) {
	step_dt := clamp(dt, 0.0, 0.033)
	if step_dt <= 0 {
		return
	}
	sub := 2
	h := step_dt / f32(sub)
	for _ in 0..<sub {
		force := (target - val^) * stiffness - vel^ * damping
		vel^ += force * h
		val^ += vel^ * h
	}
	if abs(target - val^) < 0.002 && abs(vel^) < 0.02 {
		val^ = target
		vel^ = 0
	}
	val^ = clamp(val^, 0.0, 1.2)
}

get_rect :: proc(ctx: ^Context, wid: UI_Id) -> (rl.Rectangle, bool) {
	slot, ok := slot_find(ctx, wid)
	if !ok {
		return {}, false
	}
	return slot.rect, true
}

color_lerp :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	k := clamp(t, 0, 1)
	return rl.Color{
		u8(math.round(f32(a.r) + (f32(b.r) - f32(a.r)) * k)),
		u8(math.round(f32(a.g) + (f32(b.g) - f32(a.g)) * k)),
		u8(math.round(f32(a.b) + (f32(b.b) - f32(a.b)) * k)),
		u8(math.round(f32(a.a) + (f32(b.a) - f32(a.a)) * k)),
	}
}
