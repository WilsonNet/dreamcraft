// DreamCraft side of the vinland-ui raylib bridge (vinland:vui/raylib owns the generic part:
// input sampling, GL render after rlgl flush, pointer capture). This file keeps only what is
// specific to the game: the Basin tokens, icon registration, the probe-driven synthetic mouse
// and the agent commands. The HUD is built once per frame after the camera update, so
// world-anchored labels never lag; world clicks are routed by hit-testing the last layout.
package main

import "core:fmt"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import ui "vinland:vui"
import vrl "vinland:vui/raylib"
import vfont "vinland:vui/fonts/game"
import vicons "vinland:vui/icons/game"
import vmat "vinland:vui/materials"

Vui_Host :: struct {
	ctx:          ui.Context,
	host:         vrl.Host,
	ready:        bool,
	gi:           vicons.Game_Icons,
	draw:         ^ui.Draw_List,
	minimap_img:  ui.Image_Id,
	picker_img:   ui.Image_Id,
	minimap_id:   ui.Id,
	portrait_img: ui.Image_Id,
	icon_masks:   [dynamic]rl.Texture2D,
	frame_ms:     f32, // CPU: build + layout + paint
	render_ms:    f32, // CPU: GL submission
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
		img := ui.image_register_external(&vh.ctx, u64(mask.id), int(mask.width), int(mask.height))
		ui.image_name(&vh.ctx, icon_class_name(id), img)
	}
	vh.ready = vrl.init(&vh.host, &vh.ctx)
	vh.minimap_img = vrl.texture_image(&vh.host, app.minimap)
	vh.picker_img = ui.image_register_external(&vh.ctx, 0, 1, 1, flip_y = true)
	vh.portrait_img = ui.image_register_external(&vh.ctx, 0, 1, 1, flip_y = true)
	if !vh.ready {
		fmt.eprintln("dreamcraft: VUI GL renderer failed to initialise; HUD disabled")
	}
}

vui_shutdown :: proc() {
	vrl.destroy(&vh.host)
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
	// generic sampling from the bridge, then the probe-aware mouse so agents' synthetic
	// clicks (/mouse, ui_click) drive the HUD exactly like the world
	in_ := vrl.input()
	in_.mouse = input_mouse_pos()
	in_.mouse_inside = input_cursor_on_screen()
	in_.buttons -= {.Left}
	in_.pressed -= {.Left}
	in_.released -= {.Left}
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
	size, _ := vrl.viewport()
	w, h := size.x, size.y
	if app.mode == .Model_Picker && app.editor.picker_rect_tex.id > 0 {
		vrl.texture_update(&vh.host, vh.picker_img, app.editor.picker_rect_tex.texture)
	}
	t0 := time.tick_now()
	vrl.begin(&vh.host, vui_input())
	compose_active_ui(w, h)
	vh.draw = vrl.end(&vh.host)
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
}

// Draws the UI over whatever raylib has drawn this frame (between BeginDrawing/EndDrawing).
vui_render :: proc() {
	t0 := time.tick_now()
	vrl.render(&vh.host)
	vh.render_ms = f32(time.duration_milliseconds(time.tick_since(t0)))
}

ui_pointer_captured :: proc() -> bool {
	p := input_mouse_pos()
	return vrl.pointer_over_ui(&vh.host, [2]f32{p.x, p.y})
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
		len(vh.ctx.nodes), vh.host.r.last_cmds, vh.host.r.last_batches, vh.frame_ms, vh.render_ms, ui_pointer_captured(),
	)
}
