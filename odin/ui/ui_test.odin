#+build !js
package ui

import "core:mem"
import "core:testing"

@(test)
constraints_and_row_column_weight_layout :: proc(t: ^testing.T) {
	ctx: Context
	defer free_all(context.temp_allocator)
	begin(&ctx, 800, 600, 1.0 / 60.0)
	open_row(&ctx, id("top_row"), m_pad(m_gap(m_size(mod(), 500, 44), 10), 6))
	open_box(&ctx, id("left_item"), m_size(mod(), 100, 32)); close(&ctx)
	spacer(&ctx, 1)
	open_box(&ctx, id("right_item"), m_size(mod(), 80, 32)); close(&ctx)
	close(&ctx)
	finish_layout(&ctx)

	r_row, ok_r := get_rect(&ctx, id("top_row"))
	r_left, ok_l := get_rect(&ctx, id("left_item"))
	r_right, ok_ri := get_rect(&ctx, id("right_item"))
	testing.expect(t, ok_r && ok_l && ok_ri)
	testing.expect_value(t, r_row.width, f32(500))
	testing.expect_value(t, r_left.x, f32(6))
	// 500 - 12 (pad) - 100 - 80 - 20 (2 gaps) = 288 spacer => right starts at 6 + 100 + 10 + 288 + 10 = 414.
	testing.expect_value(t, r_right.x, f32(414))
}

@(test)
widget_memory_lookup_collision_and_lru_eviction :: proc(t: ^testing.T) {
	ctx: Context
	for i in 0..<240 {
		ctx.frame_index = u64(i < 120 ? 1 : 200)
		_, ok := slot_touch(&ctx, id_idx("slot", i))
		testing.expect(t, ok)
	}
	ctx.frame_index = 200
	evict_stale_slots(&ctx, 120)
	// First 120 entries (last_seen=1) were evicted; remaining 120 entries (last_seen=200) stay reachable.
	_, gone := slot_find(&ctx, id_idx("slot", 0))
	testing.expect(t, !gone)
	for i in 120..<240 {
		_, ok := slot_find(&ctx, id_idx("slot", i))
		testing.expect(t, ok)
	}
	testing.expect_value(t, ctx.slot_count, 120)
}

@(test)
spring_and_ripple_convergence :: proc(t: ^testing.T) {
	val, vel := f32(0), f32(0)
	for _ in 0..<60 {
		spring_step(&val, &vel, 1.0, 520, 34, 1.0 / 60.0)
	}
	testing.expect(t, abs(val - 1.0) < 0.01)
	testing.expect(t, abs(vel) < 0.05)

	ctx: Context
	defer free_all(context.temp_allocator)
	begin(&ctx, 800, 600, 1.0 / 60.0)
	button(&ctx, id("btn"), Button_Opts{label = "Click", msg_tag = 7}, m_size(m_at(mod(), 20, 20), 120, 36))
	finish_layout(&ctx)
	process_input(&ctx, UI_Input{mouse = {60, 35}, left_pressed = true, left_down = true, dt = 1.0 / 60.0})
	slot, ok := slot_find(&ctx, id("btn"))
	testing.expect(t, ok && slot.ripple_t > 0 && slot.hover_t > 0)
}

@(test)
reverse_z_hit_testing_and_modal_blocking :: proc(t: ^testing.T) {
	ctx: Context
	defer free_all(context.temp_allocator)
	MSG_BG :: u32(1)
	MSG_MODAL :: u32(2)
	MSG_SCRIM :: u32(3)

	begin(&ctx, 800, 600, 1.0 / 60.0)
	button(&ctx, id("bg_btn"), Button_Opts{label = "Under", msg_tag = MSG_BG}, m_size(m_at(mod(), 100, 100), 160, 40))
	open_scrim_modal(&ctx, id("modal"), 2, MSG_SCRIM, m_size(mod(), 300, 200))
	button(&ctx, id("modal_btn"), Button_Opts{label = "Over", msg_tag = MSG_MODAL}, m_size(mod(), 140, 36))
	close_scrim_modal(&ctx)
	finish_layout(&ctx)

	// Center click hits modal_btn, NOT bg_btn.
	mb, ok := get_rect(&ctx, id("modal_btn"))
	testing.expect(t, ok)
	process_input(&ctx, UI_Input{mouse = {mb.x + 10, mb.y + 10}, left_pressed = true, left_down = true, dt = 1.0 / 60.0})
	evs := events(&ctx)
	testing.expect_value(t, len(evs), 1)
	testing.expect_value(t, evs[0].tag, MSG_MODAL)
	testing.expect(t, blocks_pointer(&ctx))

	// Clicking directly on bg_btn coords while modal open hits the scrim instead of bg_btn!
	process_input(&ctx, UI_Input{mouse = {120, 120}, left_pressed = true, left_down = true, dt = 1.0 / 60.0})
	evs2 := events(&ctx)
	testing.expect_value(t, len(evs2), 1)
	testing.expect_value(t, evs2[0].tag, MSG_SCRIM)
}

@(test)
clipped_children_reject_clicks_outside_clip_rect :: proc(t: ^testing.T) {
	ctx: Context
	defer free_all(context.temp_allocator)
	MSG_CLIPPED :: u32(9)
	well := style_well()
	well.clip_children = true

	begin(&ctx, 800, 600, 1.0 / 60.0)
	open_col(&ctx, id("well"), m_size(m_surface(m_at(mod(), 10, 10), well), 100, 50))
	button(&ctx, id("in_btn"), Button_Opts{label = "A", msg_tag = MSG_CLIPPED}, m_size(mod(), 90, 36))
	button(&ctx, id("out_btn"), Button_Opts{label = "B", msg_tag = MSG_CLIPPED}, m_size(mod(), 90, 36))
	close(&ctx)
	finish_layout(&ctx)

	// out_btn y starts at 10 + 36 = 46 and extends to y = 82, outside clip height 50 (y=60).
	process_input(&ctx, UI_Input{mouse = {40, 72}, left_pressed = true, left_down = true, dt = 1.0 / 60.0})
	testing.expect_value(t, len(events(&ctx)), 0)
	process_input(&ctx, UI_Input{mouse = {40, 25}, left_pressed = true, left_down = true, dt = 1.0 / 60.0})
	testing.expect_value(t, len(events(&ctx)), 1)
}

@(test)
display_list_generation_is_zero_persistent_alloc :: proc(t: ^testing.T) {
	ctx: Context
	alloc_count := 0
	fail_alloc := mem.Allocator{
		procedure = proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
			if mode == .Alloc || mode == .Resize || mode == .Alloc_Non_Zeroed {
				cnt := cast(^int)allocator_data
				cnt^ += 1
				return nil, .Out_Of_Memory
			}
			return nil, nil
		},
		data = &alloc_count,
	}
	old := context.allocator
	context.allocator = fail_alloc
	defer context.allocator = old

	for _ in 0..<1000 {
		begin(&ctx, 1280, 720, 1.0 / 60.0)
		open_row(&ctx, id("hud"), m_gap(m_pad(m_size(mod(), 400, 60), 8), 8))
		button(&ctx, id("b1"), Button_Opts{label = "Move", active = true, msg_tag = 1})
		button(&ctx, id("b2"), Button_Opts{label = "Attack", msg_tag = 2})
		progress_bar(&ctx, id("hp"), 0.75, COL_TEXT_MOVE, m_size(mod(), 100, 8))
		close(&ctx)
		finish_layout(&ctx)
		cmds := build_display_list(&ctx)
		testing.expect(t, len(cmds) >= 3)
		process_input(&ctx, UI_Input{mouse = {20, 20}, dt = 1.0 / 60.0})
		free_all(context.temp_allocator)
	}
	testing.expect_value(t, alloc_count, 0)
}

@(test)
auto_width_keycap_button_does_not_stretch_row :: proc(t: ^testing.T) {
	ctx: Context
	defer free_all(context.temp_allocator)
	begin(&ctx, 800, 600, 1.0 / 60.0)
	open_row(&ctx, id("footer"), m_fill(m_size(mod(), 600, 44), true, false))
	button(&ctx, id("back_btn"), Button_Opts{label = "Back", keycap = "Esc", msg_tag = 1})
	spacer(&ctx, 1)
	button(&ctx, id("edit_btn"), Button_Opts{label = "Edit Model", keycap = "Enter", msg_tag = 2})
	button(&ctx, id("fill_btn"), Button_Opts{label = "Fill", keycap = "F", msg_tag = 3}, m_w(mod(), 180))
	close(&ctx)
	finish_layout(&ctx)

	r_back, ok_b := get_rect(&ctx, id("back_btn"))
	r_edit, ok_e := get_rect(&ctx, id("edit_btn"))
	r_fill, ok_f := get_rect(&ctx, id("fill_btn"))
	testing.expect(t, ok_b && ok_e && ok_f)
	testing.expect(t, r_back.width < 220)
	testing.expect(t, r_edit.x > 300)
	testing.expect_value(t, r_fill.width, f32(180))
}
