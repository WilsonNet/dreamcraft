// vinland-ui inside the game's SDL3 GPU frame (vinland:vui/sdlgpu draws the HUD as the last
// step of the backbuffer pass, in the same command buffer as the world). This file keeps what
// is specific to the game: the Basin tokens, icon registration, the probe-driven synthetic
// mouse and the agent commands. The HUD is built once per frame after the camera update, so
// world-anchored labels never lag; world clicks are routed by hit-testing the last layout.
package main

import "core:fmt"
import "core:strings"
import "core:time"
import rl "../gfx"
import ui "vinland:vui"
import sdl "vendor:sdl3"
import vsg "vinland:vui/sdlgpu"
import vfont "vinland:vui/fonts/game"
import vicons "vinland:vui/icons/game"
import vmat "vinland:vui/materials"

Vui_Host :: struct {
	ctx:              ui.Context,
	r:                vsg.Renderer,
	ready:            bool,
	gi:               vicons.Game_Icons,
	draw:             ^ui.Draw_List,
	minimap_img:      ui.Image_Id,
	picker_img:       ui.Image_Id,
	anim_picker_img:  ui.Image_Id,
	minimap_id:       ui.Id,
	anim_timeline_id: ui.Id,
	portrait_img:     ui.Image_Id,
	icon_masks:       [dynamic]rl.Texture2D,
	frame_ms:         f32, // CPU: build + layout + paint
	render_ms:        f32, // CPU: upload + draw recording inside the frame's command buffer
}

vh: Vui_Host

// Basin palette (see .impeccable/surfaces brief): bitumen field, hammered brass, silver inlay,
// lapis medallions, carnelian for damage and danger, gold inlay for what is armed or selected.
@(private)
register_basin_tokens :: proc(t: ^ui.Theme) {
	ui.theme_set_color(t, "bitumen", ui.rgb(0x16130f))
	ui.theme_set_color(t, "bitumen-raised", ui.rgb(0x221c16))
	ui.theme_set_color(t, "bitumen-deep", ui.rgb(0x0c0a08))
	ui.theme_set_color(t, "brass", ui.rgb(0x9a7843))
	ui.theme_set_color(t, "brass-hi", ui.rgb(0xcdb37c))
	ui.theme_set_color(t, "brass-lo", ui.rgb(0x584222))
	ui.theme_set_color(t, "silver", ui.rgb(0xb8bab8))
	ui.theme_set_color(t, "silver-dim", ui.rgb(0x8a8d8f))
	ui.theme_set_color(t, "lapis", ui.rgb(0x253c68))
	ui.theme_set_color(t, "lapis-hi", ui.rgb(0x324e86))
	ui.theme_set_color(t, "lapis-lo", ui.rgb(0x14213e))
	ui.theme_set_color(t, "carnelian", ui.rgb(0x74281d))
	ui.theme_set_color(t, "carnelian-hi", ui.rgb(0xa4473a))
	ui.theme_set_color(t, "inlay", ui.rgb(0xecd9a6))
	ui.theme_set_color(t, "amber-alert", ui.rgb(0xd49a44))
	ui.theme_set_color(t, "parchment", ui.rgb(0xe9dcbc))
	ui.theme_set_color(t, "ink", ui.rgb(0x3b2a16))
	ui.theme_changed()
}

vui_init :: proc() {
	ui.init(&vh.ctx)
	vfont.register(&vh.ctx)
	vh.ctx.theme.default_font = "game"
	// Painted grade: the HUD sits inside the watercolour world instead of on top of it.
	vh.ctx.grade = ui.GRADE_PAINTED
	register_basin_tokens(&vh.ctx.theme)
	vmat.register(&vh.ctx)
	vh.gi = vicons.register(&vh.ctx)
	// The game's own SVG icon atlas (white, tinted by bg colour) as named external textures:
	// `bg-silver bg-tex-ic-tool_grab`.
	for id in Icon_Id {
		if id == .None || id == .COUNT {
			continue
		}
		tex := icon_texture(id)
		if tex.id == 0 {
			continue
		}
		// Icons are masks in the HUD: keep the coverage, drop the SVG's own colours so every
		// icon takes the one tint its class gives it (silver, brass, ink).
		mask := icon_mask_texture(tex)
		append(&vh.icon_masks, mask)
		img := ui.image_register_external(&vh.ctx, rl.texture_handle(mask), int(mask.width), int(mask.height))
		ui.image_name(&vh.ctx, icon_class_name(id), img)
	}
	vh.ready = vsg.init(&vh.r, rl.device(), rl.color_format(), rl.depth_format())
	vh.minimap_img = ui.image_register_external(&vh.ctx, rl.texture_handle(app.minimap), int(app.minimap.width), int(app.minimap.height), nearest = true)
	vh.picker_img = ui.image_register_external(&vh.ctx, 0, 1, 1, flip_y = true)
	vh.anim_picker_img = ui.image_register_external(&vh.ctx, 0, 1, 1, flip_y = true)
	vh.portrait_img = ui.image_register_external(&vh.ctx, 0, 1, 1, flip_y = true)
	if !vh.ready {
		fmt.eprintln("dreamcraft: VUI GPU renderer failed to initialise; HUD disabled")
	}
}

vui_shutdown :: proc() {
	vsg.destroy(&vh.r, &vh.ctx)
	for t in vh.icon_masks {
		rl.UnloadTexture(t)
	}
	delete(vh.icon_masks)
	unload_hero_portrait()
	ui.destroy(&vh.ctx)
	vh.ready = false
}

@(private)
icon_mask_texture :: proc(tex: rl.Texture2D) -> rl.Texture2D {
	img := rl.LoadImageFromTexture(tex)
	defer rl.UnloadImage(img)
	rl.ImageFormat(&img, .UNCOMPRESSED_R8G8B8A8)
	px := ([^]u8)(img.data)[:int(img.width) * int(img.height) * 4]
	for i := 0; i < len(px); i += 4 {
		px[i], px[i + 1], px[i + 2] = 255, 255, 255
	}
	out := rl.LoadTextureFromImage(img)
	rl.GenTextureMipmaps(&out)
	rl.SetTextureFilter(out, .TRILINEAR)
	return out
}

@(private)
icon_class_name :: proc(id: Icon_Id) -> string {
	return strings.to_lower(fmt.tprintf("ic-%v", id), context.temp_allocator)
}

// `bg-tex-ic-…` class for one of the game's SVG icons.
icon_tex :: proc(id: Icon_Id) -> string {
	return fmt.tprintf("bg-tex-%s", icon_class_name(id))
}

@(private)
vui_input :: proc() -> ui.Input {
	// mouse only (game hotkeys never reach a focused button); the left button and position
	// come from the probe-aware input so agents' synthetic clicks drive the HUD like the world
	in_: ui.Input
	in_.mouse = input_mouse_pos()
	in_.mouse_inside = input_cursor_on_screen()
	OTHER := [2]struct {
		rb: rl.MouseButton,
		vb: ui.Mouse_Button,
	}{{.RIGHT, .Right}, {.MIDDLE, .Middle}}
	for b in OTHER {
		if rl.IsMouseButtonDown(b.rb) {
			in_.buttons += {b.vb}
		}
		if rl.IsMouseButtonPressed(b.rb) {
			in_.pressed += {b.vb}
		}
		if rl.IsMouseButtonReleased(b.rb) {
			in_.released += {b.vb}
		}
	}
	if input_left_down() {
		in_.buttons += {.Left}
	}
	if input_left_pressed() {
		in_.pressed += {.Left}
	}
	if input_left_released() {
		in_.released += {.Left}
	}
	in_.click_count = .Left in in_.pressed ? 1 : 0
	in_.wheel = {0, -input_wheel_y() * 48}
	return in_
}

// Builds this frame's UI. Call once per frame after input sampling, before world input.
vui_frame :: proc(dt: f32) {
	if !vh.ready {
		return
	}
	w, h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
	scale := rl.GetWindowScaleDPI().x
	if app.mode == .Model_Picker && app.editor.picker_rect_tex.id > 0 {
		t := app.editor.picker_rect_tex.texture
		ui.image_external_update(&vh.ctx, vh.picker_img, rl.texture_handle(t), int(t.width), int(t.height))
	}
	if app.mode == .Anim_Picker && app.anim_ed.picker_rect_tex.id > 0 {
		t := app.anim_ed.picker_rect_tex.texture
		ui.image_external_update(&vh.ctx, vh.anim_picker_img, rl.texture_handle(t), int(t.width), int(t.height))
	}
	t0 := time.tick_now()
	ui.begin_frame(&vh.ctx, vui_input(), {w, h}, scale, rl.GetTime())
	compose_active_ui(w, h)
	vh.draw = ui.end_frame(&vh.ctx)
	when #config(DC_UI_DEBUG, false) {
		@(static) last: ui.Id
		if vh.ctx.hover_id != last {
			last = vh.ctx.hover_id
			for n in vh.ctx.nodes {
				if n.id == last {
					fmt.eprintln("hover ->", n.class, n.rect)
				}
			}
			fmt.eprintln("hover id", last, "mouse", vh.ctx.input.mouse, "inside", vh.ctx.input.mouse_inside)
		}
	}
	vh.frame_ms = f32(time.duration_milliseconds(time.tick_since(t0)))
	if vh.minimap_id != 0 {
		r := ui.rect_of(vh.minimap_id)
		if r.w > 0 {
			app.minimap_rect = {r.x, r.y, r.w, r.h}
		}
	}
	if app.mode == .Anim_Editor && vh.anim_timeline_id != 0 {
		r := ui.rect_of(vh.anim_timeline_id)
		if r.w > 0 {
			app.anim_ed.timeline_rect = {r.x, r.y, r.w, r.h}
		}
	}
}

// Draws the UI over the frame drawn so far (between BeginDrawing/EndDrawing): recorded now,
// uploaded and drawn when the frame's command buffer is replayed.
vui_render :: proc() {
	if !vh.ready || vh.draw == nil {
		return
	}
	vh.render_ms = 0
	rl.record_callback(vui_prepare, vui_draw, nil)
}

@(private)
vui_prepare :: proc(cmd: ^sdl.GPUCommandBuffer, _: rawptr) {
	t0 := time.tick_now()
	vsg.prepare(&vh.r, &vh.ctx, vh.draw, cmd)
	vh.render_ms += f32(time.duration_milliseconds(time.tick_since(t0)))
}

@(private)
vui_draw :: proc(cmd: ^sdl.GPUCommandBuffer, pass: ^sdl.GPURenderPass, w, h: i32, _: rawptr) {
	t0 := time.tick_now()
	vsg.draw(&vh.r, &vh.ctx, vh.draw, cmd, pass, w, h)
	vh.render_ms += f32(time.duration_milliseconds(time.tick_since(t0)))
}

ui_pointer_captured :: proc() -> bool {
	if !vh.ready {
		return false
	}
	p := input_mouse_pos()
	return ui.pointer_over_ui(&vh.ctx, [2]f32{p.x, p.y})
}

// ---------------------------------------------------------------------------
// Agent feedback loop: inspect and drive the HUD through the control API.
// ---------------------------------------------------------------------------

// {"cmd":"ui_tree","value":<depth>} -> element tree JSON (tag, class, text, rect).
vui_tree_json :: proc(depth: int) -> string {
	sb := strings.builder_make(context.temp_allocator)
	ui.debug_tree(&vh.ctx, &sb, depth > 0 ? depth : 64)
	return strings.to_string(sb)
}

// {"cmd":"ui_click","text":"Resume Battle","value":<nth>} clicks the nth (0-based) visible
// element whose text contains the string, through the same synthetic mouse path as /mouse.
vui_click_text :: proc(text_in: string, nth := 0) -> (msg: string, ok: bool) {
	// the request string lives in temp memory that the synthetic frames below reset
	buf: [128]u8
	text := string(buf[:copy(buf[:], text_in)])
	center, found := ui.find_text(&vh.ctx, text, nth)
	if !found {
		return fmt.tprintf("No visible UI text matching %q", text), false
	}
	probe_click_at(center)
	return fmt.tprintf("Clicked %q at (%.0f, %.0f)", text, center.x, center.y), true
}

vui_stats_json :: proc() -> string {
	return fmt.tprintf(
		`{{"nodes":%d,"draw_cmds":%d,"batches":%d,"build_ms":%.3f,"render_ms":%.3f,"pointer_over_ui":%v}}`,
		len(vh.ctx.nodes), vh.draw != nil ? len(vh.draw.cmds) : 0, vh.draw != nil ? len(vh.draw.batches) : 0, vh.frame_ms, vh.render_ms, ui_pointer_captured(),
	)
}
