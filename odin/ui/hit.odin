// Reverse-z hit testing, pointer blocking, Elm UI_Event emission, and damped spring transitions.
package ui

import rl "vendor:raylib"

process_input :: proc(ctx: ^Context, inp: UI_Input) {
	ctx.dt = clamp(inp.dt, 0.0, 0.05)
	ctx.event_count = 0
	ctx.hovered_id = INVALID_ID
	ctx.pointer_blocked = false

	hit, found := find_top_hit(ctx, inp.mouse)
	if found {
		ctx.pointer_blocked = hit.blocks_pointer || hit.clickable
		if hit.clickable && !hit.disabled {
			ctx.hovered_id = hit.id
		}
	}
	handle_pointer_edges(ctx, inp, hit, found)
	step_all_springs(ctx, inp)
}

@(private)
find_top_hit :: proc(ctx: ^Context, mouse: rl.Vector2) -> (Hit_Entry, bool) {
	best_layer := -1
	best_entry: Hit_Entry
	found := false
	for i := ctx.prev_hit_count - 1; i >= 0; i -= 1 {
		h := ctx.prev_hits[i]
		if !h.clickable && !h.blocks_pointer {
			continue
		}
		if h.has_clip && !rl.CheckCollisionPointRec(mouse, h.clip_rect) {
			continue
		}
		if !rl.CheckCollisionPointRec(mouse, h.rect) {
			continue
		}
		if int(h.layer) > best_layer {
			best_layer = int(h.layer)
			best_entry = h
			found = true
		}
	}
	return best_entry, found
}

@(private)
handle_pointer_edges :: proc(ctx: ^Context, inp: UI_Input, hit: Hit_Entry, found: bool) {
	if inp.left_pressed {
		if found && hit.clickable && !hit.disabled {
			ctx.pressed_id = hit.id
			trigger_ripple(ctx, hit.id, hit.rect, inp.mouse)
			if hit.trigger_press {
				emit_event(ctx, hit.id, hit.msg_tag, hit.msg_arg, inp.mouse)
			}
		} else {
			ctx.pressed_id = INVALID_ID
		}
	}
	if inp.left_released {
		if ctx.pressed_id != INVALID_ID && found && hit.clickable && !hit.disabled && hit.id == ctx.pressed_id && !hit.trigger_press {
			emit_event(ctx, hit.id, hit.msg_tag, hit.msg_arg, inp.mouse)
		}
		ctx.pressed_id = INVALID_ID
	}
}

@(private)
trigger_ripple :: proc(ctx: ^Context, wid: UI_Id, rect: rl.Rectangle, mouse: rl.Vector2) {
	slot, ok := slot_touch(ctx, wid)
	if !ok {
		return
	}
	u := clamp((mouse.x - rect.x) / max(rect.width, 1.0), 0.0, 1.0)
	v := clamp((mouse.y - rect.y) / max(rect.height, 1.0), 0.0, 1.0)
	slot.ripple_t = 0.001
	slot.ripple_uv = {u, v}
}

@(private)
emit_event :: proc(ctx: ^Context, wid: UI_Id, tag: u32, arg: i32, mouse: rl.Vector2) {
	if tag == 0 || ctx.event_count >= MAX_UI_EVENTS {
		return
	}
	ctx.events[ctx.event_count] = UI_Event{
		id    = wid,
		tag   = tag,
		arg   = arg,
		mouse = mouse,
	}
	ctx.event_count += 1
}

@(private)
step_all_springs :: proc(ctx: ^Context, inp: UI_Input) {
	for i in 0..<MAX_WIDGET_SLOTS {
		slot := &ctx.slots[i]
		if !slot.occupied {
			continue
		}
		is_hov := slot.id == ctx.hovered_id ? f32(1) : f32(0)
		is_prs := (slot.id == ctx.pressed_id && inp.left_down && slot.id == ctx.hovered_id) ? f32(1) : f32(0)
		is_act := slot.target_active ? f32(1) : f32(0)
		spring_step(&slot.hover_t, &slot.hover_v, is_hov, 520, 34, ctx.dt)
		spring_step(&slot.press_t, &slot.press_v, is_prs, 680, 38, ctx.dt)
		spring_step(&slot.active_t, &slot.active_v, is_act, 420, 30, ctx.dt)
		spring_step(&slot.appear_t, &slot.appear_v, 1.0, 380, 28, ctx.dt)
		if slot.ripple_t > 0 {
			slot.ripple_t += ctx.dt * 2.35
			if slot.ripple_t >= 1.0 {
				slot.ripple_t = 0
			}
		}
	}
}

events :: proc(ctx: ^Context) -> []UI_Event {
	return ctx.events[:ctx.event_count]
}

blocks_pointer :: proc(ctx: ^Context) -> bool {
	return ctx.pointer_blocked
}

is_hovered :: proc(ctx: ^Context, wid: UI_Id) -> bool {
	return wid != INVALID_ID && ctx.hovered_id == wid
}

is_pressed :: proc(ctx: ^Context, wid: UI_Id) -> bool {
	return wid != INVALID_ID && ctx.pressed_id == wid
}
