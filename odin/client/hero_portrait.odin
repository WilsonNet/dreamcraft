// Live hero portrait for the HUD roundel: Liiroy's own skinned mesh, framed head-and-shoulders
// into a small render target after the world pass. The world pass already skinned the mesh into
// world space this frame, so the portrait is one extra DrawMesh, no re-skinning.
package main

import "core:math"
import rl "vendor:raylib"
import ui "vinland:vui"
import g "../game"

PORTRAIT_PX :: 192

@(private = "file")
portrait: rl.RenderTexture2D

render_hero_portrait :: proc() {
	idx, ok := g.game_player_index(&app.game)
	if !ok {
		return // keep the last frame; the HUD desaturates it
	}
	m := &app.models[idx]
	if !m.loaded {
		return
	}
	if portrait.id == 0 {
		portrait = rl.LoadRenderTexture(PORTRAIT_PX, PORTRAIT_PX)
		if portrait.id == 0 {
			return
		}
		rl.SetTextureFilter(portrait.texture, .BILINEAR)
		ui.image_external_update(&vh.ctx, vh.portrait_img, u64(portrait.texture.id), PORTRAIT_PX, PORTRAIT_PX)
	}
	a := app.visuals[idx].angle * math.PI / 180
	fwd := rl.Vector3{math.sin(a), 0, math.cos(a)}
	side := rl.Vector3{fwd.z, 0, -fwd.x}
	head := unit_ground(idx) + rl.Vector3{0, 1.52, 0}
	cam := rl.Camera3D{
		position   = head + fwd * 2.0 + side * 0.55 + rl.Vector3{0, 0.12, 0},
		target     = head + rl.Vector3{0, -0.04, 0},
		up         = {0, 1, 0},
		fovy       = 15,
		projection = .PERSPECTIVE,
	}
	set_unit_shader_uniforms_at(f32(rl.GetTime()), cam.position)
	set_unit_tint(rl.Vector3{1, 1, 1}, 1)
	rl.BeginTextureMode(portrait)
	rl.ClearBackground(rl.Color{0, 0, 0, 0})
	rl.BeginMode3D(cam)
	rl.DrawMesh(m.mesh, m.material, rl.Matrix(1))
	rl.EndMode3D()
	rl.EndTextureMode()
	set_unit_shader_uniforms(f32(rl.GetTime()))
}

unload_hero_portrait :: proc() {
	if portrait.id != 0 {
		rl.UnloadRenderTexture(portrait)
		portrait = {}
	}
}
