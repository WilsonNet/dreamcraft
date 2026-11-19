// Batched GPU Display_List executor: 1-draw-call SDF boxes, ClipRRect textures, SDF text, icons, & fallbacks.
package ui

import "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

init :: proc(ctx: ^Context, use_shaders := true) {
	r := &ctx.renderer
	r.use_shaders = use_shaders
	img := rl.GenImageColor(1, 1, rl.WHITE)
	r.white_tex = rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)

	dimg := rl.GenImageColor(MAX_DRAW_CMDS, 8, rl.BLANK)
	r.data_tex = rl.LoadTextureFromImage(dimg)
	rl.UnloadImage(dimg)
	rl.SetTextureFilter(r.data_tex, .POINT)
	rl.SetTextureWrap(r.data_tex, .CLAMP)

	if use_shaders {
		init_shaders(r)
	}
	font_init(&r.fonts, use_shaders)
	ctx.measure_user = &r.fonts
	ctx.measure_text_fn = proc(user: rawptr, text: cstring, role: Font_Role, size: f32) -> [2]f32 {
		return measure_font_text(cast(^Font_Pack)user, text, role, size)
	}
	r.initialized = true
}

@(private)
init_shaders :: proc(r: ^Renderer) {
	if sh, ok := load_shader_file("ui_sdf.vs", "ui_sdf.fs"); ok {
		r.sdf_shader = sh
		r.sdf_ready = true
	}
	if sh, ok := load_shader_file("", "ui_clip_tex.fs"); ok {
		r.clip_shader = sh
		r.clip_ready = true
		r.clip_locs = Clip_Uniforms{
			size      = rl.GetShaderLocation(sh, "u_size"),
			uv_rect   = rl.GetShaderLocation(sh, "u_uv_rect"),
			radius    = rl.GetShaderLocation(sh, "u_radius"),
			border_w  = rl.GetShaderLocation(sh, "u_border_w"),
			border    = rl.GetShaderLocation(sh, "u_border_col"),
			rim_alpha = rl.GetShaderLocation(sh, "u_rim_alpha"),
		}
	}
}

unload :: proc(ctx: ^Context) {
	r := &ctx.renderer
	if !r.initialized {
		return
	}
	font_unload(&r.fonts)
	if rl.IsShaderValid(r.sdf_shader) { rl.UnloadShader(r.sdf_shader) }
	if rl.IsShaderValid(r.clip_shader) { rl.UnloadShader(r.clip_shader) }
	if r.data_tex.id > 0 { rl.UnloadTexture(r.data_tex) }
	if r.white_tex.id > 0 { rl.UnloadTexture(r.white_tex) }
	r^ = {}
	ctx.measure_text_fn = nil
	ctx.measure_user = nil
}

render :: proc(ctx: ^Context) {
	cmds := build_display_list(ctx)
	defer ctx.nodes = nil
	if len(cmds) == 0 {
		return
	}
	r := &ctx.renderer
	scissor_depth := 0
	i := 0
	for i < len(cmds) {
		if cmds[i].kind == .SDF_Box {
			j := i
			for j < len(cmds) && cmds[j].kind == .SDF_Box && (j - i) < MAX_DRAW_CMDS {
				j += 1
			}
			draw_sdf_batch(r, cmds[i:j])
			i = j
			continue
		}
		exec_single_cmd(r, cmds[i], &scissor_depth)
		i += 1
	}
	for scissor_depth > 0 {
		rl.EndScissorMode()
		scissor_depth -= 1
	}
}

@(private)
exec_single_cmd :: proc(r: ^Renderer, cmd: Draw_Cmd, scissor_depth: ^int) {
	#partial switch cmd.kind {
	case .Clipped_Tex:
		draw_clipped_tex(r, cmd)
	case .Text:
		draw_font_text(&r.fonts, cmd.text, {cmd.rect.x, cmd.rect.y}, cmd.font_role, cmd.font_size, cmd.bg_top)
	case .Icon:
		if cmd.tex.id > 0 {
			src := rl.Rectangle{0, 0, f32(cmd.tex.width), f32(cmd.tex.height)}
			dst := rl.Rectangle{math.round(cmd.rect.x), math.round(cmd.rect.y), cmd.rect.width, cmd.rect.height}
			rl.DrawTexturePro(cmd.tex, src, dst, {0, 0}, 0, cmd.bg_top)
		}
	case .Scissor_Push:
		begin_hi_dpi_scissor(cmd.rect)
		scissor_depth^ += 1
	case .Scissor_Pop:
		if scissor_depth^ > 0 {
			rl.EndScissorMode()
			scissor_depth^ -= 1
		}
	case .Custom:
		if cmd.custom_fn != nil {
			cmd.custom_fn(cmd.rect, cmd.custom_data)
		}
	}
}

begin_hi_dpi_scissor :: proc(rect: rl.Rectangle) {
	sw := max(f32(rl.GetScreenWidth()), 1)
	sh := max(f32(rl.GetScreenHeight()), 1)
	rw := max(f32(rl.GetRenderWidth()), sw)
	rh := max(f32(rl.GetRenderHeight()), sh)
	sx := rw / sw
	sy := rh / sh
	rl.BeginScissorMode(
		i32(math.floor(rect.x * sx)),
		i32(math.floor(rect.y * sy)),
		max(i32(math.ceil(rect.width * sx)), 1),
		max(i32(math.ceil(rect.height * sy)), 1),
	)
}

draw_sdf_batch :: proc(r: ^Renderer, cmds: []Draw_Cmd) {
	if len(cmds) == 0 {
		return
	}
	if !r.use_shaders || !r.sdf_ready || r.data_tex.id == 0 {
		draw_sdf_fallback(cmds)
		return
	}
	pack_sdf_slots(r, cmds)
	rl.UpdateTexture(r.data_tex, raw_data(r.data_pixels[:]))
	rl.BeginShaderMode(r.sdf_shader)
	rlgl.SetTexture(r.data_tex.id)
	rlgl.DisableBackfaceCulling()
	rlgl.Begin(rlgl.QUADS)
	for &cmd, slot in cmds {
		emit_sdf_quad(&cmd, slot, r.data_tex.id)
	}
	rlgl.End()
	rlgl.EnableBackfaceCulling()
	rlgl.SetTexture(0)
	rl.EndShaderMode()
}

@(private)
emit_sdf_quad :: proc(cmd: ^Draw_Cmd, slot: int, tex_id: u32) {
	if rlgl.CheckRenderBatchLimit(4) != 0 {
		rlgl.SetTexture(tex_id)
	}
	rect := cmd.rect
	hw := rect.width * 0.5
	hh := rect.height * 0.5
	pad := cmd.shadow_blur > 0 ? cmd.shadow_blur + abs(cmd.shadow_off) + 3.0 : 2.0
	x0, y0 := rect.x - pad, rect.y - pad
	x1, y1 := rect.x + rect.width + pad, rect.y + rect.height + pad
	lx, ly := hw + pad, hh + pad
	sz := f32(slot)
	top := cmd.bg_top
	bot := cmd.bg_bot.a > 0 ? cmd.bg_bot : top

	rlgl.Color4ub(top.r, top.g, top.b, top.a)
	rlgl.TexCoord2f(-lx, -ly)
	rlgl.Vertex3f(x0, y0, sz)

	rlgl.Color4ub(bot.r, bot.g, bot.b, bot.a)
	rlgl.TexCoord2f(-lx, ly)
	rlgl.Vertex3f(x0, y1, sz)

	rlgl.Color4ub(bot.r, bot.g, bot.b, bot.a)
	rlgl.TexCoord2f(lx, ly)
	rlgl.Vertex3f(x1, y1, sz)

	rlgl.Color4ub(top.r, top.g, top.b, top.a)
	rlgl.TexCoord2f(lx, -ly)
	rlgl.Vertex3f(x1, y0, sz)
}

@(private)
pack_sdf_slots :: proc(r: ^Renderer, cmds: []Draw_Cmd) {
	for &cmd, slot in cmds {
		write_texel(r, slot, 0, clamp_u8(cmd.radius[0]), clamp_u8(cmd.radius[1]), clamp_u8(cmd.radius[2]), clamp_u8(cmd.radius[3]))
		bc := cmd.border_col
		write_texel(r, slot, 1, bc.r, bc.g, bc.b, bc.a)
		hw_u := u16(clamp(math.round(cmd.rect.width * 0.5 * 4.0), 1, 65535))
		hh_u := u16(clamp(math.round(cmd.rect.height * 0.5 * 4.0), 1, 65535))
		write_texel(r, slot, 2, u8(hw_u >> 8), u8(hw_u & 0xFF), u8(hh_u >> 8), u8(hh_u & 0xFF))
		write_texel(
			r, slot, 3,
			clamp_u8(cmd.border_w * 16.0),
			clamp_u8(cmd.top_rim * 255.0),
			clamp_u8((cmd.shadow_blur / 64.0) * 255.0),
			clamp_u8(cmd.shadow_off * 2.0 + 128.0),
		)
		sc := cmd.shadow_col
		write_texel(r, slot, 4, sc.r, sc.g, sc.b, sc.a)
		ra := cmd.ripple_t > 0 ? clamp_u8((1.0 - cmd.ripple_t) * 255.0) : u8(0)
		write_texel(r, slot, 5, clamp_u8(cmd.ripple_uv[0] * 255.0), clamp_u8(cmd.ripple_uv[1] * 255.0), clamp_u8(cmd.ripple_t * 255.0), ra)
		write_texel(r, slot, 6, clamp_u8(cmd.progress * 255.0), cmd.mode, 0, clamp_u8(cmd.state_lift * 255.0))
		ac := cmd.accent_col
		write_texel(r, slot, 7, ac.r, ac.g, ac.b, ac.a)
	}
}

@(private)
write_texel :: proc(r: ^Renderer, slot, row: int, b0, b1, b2, b3: u8) {
	off := (row * MAX_DRAW_CMDS + slot) * 4
	r.data_pixels[off + 0] = b0
	r.data_pixels[off + 1] = b1
	r.data_pixels[off + 2] = b2
	r.data_pixels[off + 3] = b3
}

@(private)
clamp_u8 :: proc(v: f32) -> u8 {
	return u8(clamp(math.round(v), 0, 255))
}

@(private)
draw_sdf_fallback :: proc(cmds: []Draw_Cmd) {
	for &cmd in cmds {
		rn := clamp((cmd.radius[0] * 2.0) / max(min(cmd.rect.width, cmd.rect.height), 1.0), 0.0, 1.0)
		if cmd.bg_top.a > 0 {
			rl.DrawRectangleRounded(cmd.rect, rn, 8, cmd.bg_top)
		}
		if cmd.mode == 1 && cmd.progress > 0.005 {
			fw := max(cmd.rect.width * clamp(cmd.progress, 0, 1) - 2, 2)
			rl.DrawRectangleRounded({cmd.rect.x + 1, cmd.rect.y + 1, fw, max(cmd.rect.height - 2, 2)}, rn, 8, cmd.accent_col)
		}
		if cmd.border_w > 0 && cmd.border_col.a > 0 {
			rl.DrawRectangleRoundedLinesEx(cmd.rect, rn, 8, cmd.border_w, cmd.border_col)
		}
	}
}

@(private)
draw_clipped_tex :: proc(r: ^Renderer, cmd: Draw_Cmd) {
	if cmd.tex.id == 0 {
		return
	}
	tw := f32(cmd.tex.width)
	th := cmd.tex_flip_y ? -f32(cmd.tex.height) : f32(cmd.tex.height)
	src := rl.Rectangle{0, 0, tw, th}
	if !r.use_shaders || !r.clip_ready {
		rl.DrawTexturePro(cmd.tex, src, cmd.rect, {0, 0}, 0, rl.WHITE)
		if cmd.border_w > 0 && cmd.border_col.a > 0 {
			rn := clamp((cmd.radius[0] * 2.0) / max(min(cmd.rect.width, cmd.rect.height), 1.0), 0.0, 1.0)
			rl.DrawRectangleRoundedLinesEx(cmd.rect, rn, 8, cmd.border_w, cmd.border_col)
		}
		return
	}
	sz := [2]f32{cmd.rect.width, cmd.rect.height}
	uv_r := cmd.tex_flip_y ? [4]f32{0, 1, 1, 0} : [4]f32{0, 0, 1, 1}
	rad0 := cmd.radius[0]
	bw := cmd.border_w
	bc := [4]f32{f32(cmd.border_col.r) / 255.0, f32(cmd.border_col.g) / 255.0, f32(cmd.border_col.b) / 255.0, f32(cmd.border_col.a) / 255.0}
	rim := cmd.top_rim

	rl.BeginShaderMode(r.clip_shader)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.size, &sz, .VEC2)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.uv_rect, &uv_r, .VEC4)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.radius, &rad0, .FLOAT)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.border_w, &bw, .FLOAT)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.border, &bc, .VEC4)
	rl.SetShaderValue(r.clip_shader, r.clip_locs.rim_alpha, &rim, .FLOAT)
	rl.DrawTexturePro(cmd.tex, src, cmd.rect, {0, 0}, 0, rl.WHITE)
	rl.EndShaderMode()
}

draw_text :: proc(ctx: ^Context, text: cstring, pos: rl.Vector2, role: Font_Role, size: f32, col: rl.Color) {
	if ctx.renderer.initialized {
		draw_font_text(&ctx.renderer.fonts, text, pos, role, size, col)
		return
	}
	rl.DrawText(text, i32(math.round(pos.x)), i32(math.round(pos.y)), i32(math.round(size)), col)
}
