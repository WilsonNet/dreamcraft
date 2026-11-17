// Painterly ground texture and soft contact shadows.
package main

import rl "vendor:raylib"
import g "../game"

@(private)
ground_hash :: proc(x, y: int) -> f32 {
	n := u32(x * 374761393 + y * 668265263)
	n = (n ~ (n >> 13)) * 1274126177
	return f32(n & 0xffff) / 65535.0
}

@(private)
ground_tint :: proc(state: int, gx, gy: int) -> rl.Color {
	jitter := ground_hash(gx, gy) - 0.5
	v := i32(jitter * 14)
	switch state {
	case 0:
		return rl.Color{8, 13, 9, 255}
	case 1:
		return rl.Color{
			u8(clamp(30 + v, 0, 255)),
			u8(clamp(54 + v, 0, 255)),
			u8(clamp(34 + v, 0, 255)),
			255,
		}
	case:
		return rl.Color{
			u8(clamp(66 + v, 0, 255)),
			u8(clamp(112 + v, 0, 255)),
			u8(clamp(62 + v, 0, 255)),
			255,
		}
	}
}

// Visible cells next to fog dim toward it, so the play area fades out instead
// of ending on a hard tile border.
@(private)
ground_fog_shade :: proc(cell: g.Grid_Pos, state: int) -> f32 {
	if state == 0 {
		return 1.0
	}
	dimmer: f32 = 1.0
	for dy in ([3]i32{-2, 0, 2}) {
		for dx in ([3]i32{-2, 0, 2}) {
			if dx == 0 && dy == 0 {
				continue
			}
			other := g.Grid_Pos{x = cell.x + dx, y = cell.y + dy}
			if int(g.fog_state(&app.game.fog, other)) < state {
				dimmer = min(dimmer, 0.78)
			}
		}
	}
	return dimmer
}

draw_unit_shadow :: proc(ground: rl.Vector3, size: f32, alpha: u8) {
	if !app.shadow_ready {
		return
	}
	mat := app.shadow_model.materials[0]
	if mat.maps != nil {
		mat.maps[0].color = rl.Color{255, 255, 255, alpha}
	}
	transform := xf_mul(rl.MatrixTranslate(ground.x, 0.022, ground.z), rl.MatrixScale(size, 1, size))
	rl.DrawMesh(app.shadow_model.meshes[0], mat, transform)
}

init_shadow_assets :: proc() {
	image := rl.GenImageGradientRadial(64, 64, 1.0, rl.Color{0, 0, 0, 150}, rl.Color{0, 0, 0, 0})
	app.shadow_texture = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	rl.SetTextureFilter(app.shadow_texture, .BILINEAR)
	app.shadow_model = rl.LoadModelFromMesh(rl.GenMeshPlane(1.55, 1.55, 1, 1))
	rl.SetMaterialTexture(&app.shadow_model.materials[0], .ALBEDO, app.shadow_texture)
	app.shadow_ready = true
}

unload_shadow_assets :: proc() {
	if !app.shadow_ready {
		return
	}
	// UnloadModel releases the material's diffuse texture, so drop our handle
	// instead of unloading it a second time.
	if app.shadow_model.meshCount > 0 {
		rl.UnloadModel(app.shadow_model)
	}
	app.shadow_texture = {}
	app.shadow_model = {}
	app.shadow_ready = false
}
