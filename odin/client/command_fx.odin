// StarCraft 2 / Age of Empires style 3D ground command confirmation FX and
// live command-mode targeting reticle. Zero heap allocations per frame.
package main

import "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import g "../game"
import ui "../ui"

MAX_CMD_FX :: 16

Cmd_Fx_Kind :: enum u8 {
	Move,
	Attack,
	Patrol,
}

Cmd_Fx :: struct {
	active:   bool,
	kind:     Cmd_Fx_Kind,
	pos:      rl.Vector3,
	target:   g.Unit_Handle,
	clock:    f32,
	duration: f32,
}

spawn_ground_fx :: proc(kind: Cmd_Fx_Kind, pos: rl.Vector3) {
	dur := f32(0.50)
	if kind == .Attack {
		dur = 0.56
	} else if kind == .Patrol {
		dur = 0.58
	}
	slot := &app.cmd_fx[app.cmd_fx_next]
	slot^ = Cmd_Fx{
		active   = true,
		kind     = kind,
		pos      = rl.Vector3{pos.x, 0, pos.z},
		target   = g.INVALID_HANDLE,
		clock    = 0,
		duration = dur,
	}
	app.cmd_fx_next = (app.cmd_fx_next + 1) % MAX_CMD_FX
}

spawn_target_fx :: proc(target: g.Unit_Handle, pos: rl.Vector3) {
	slot := &app.cmd_fx[app.cmd_fx_next]
	slot^ = Cmd_Fx{
		active   = true,
		kind     = .Attack,
		pos      = rl.Vector3{pos.x, 0, pos.z},
		target   = target,
		clock    = 0,
		duration = 0.62,
	}
	app.cmd_fx_next = (app.cmd_fx_next + 1) % MAX_CMD_FX
}

update_command_fx :: proc(dt: f32) {
	for &fx in app.cmd_fx {
		if !fx.active {
			continue
		}
		fx.clock += dt
		if fx.clock >= fx.duration {
			fx.active = false
		}
	}
}

draw_command_fx_3d :: proc() {
	rlgl.DisableBackfaceCulling()
	rlgl.DisableDepthMask()
	rl.BeginBlendMode(.ALPHA)
	for &fx in app.cmd_fx {
		if !fx.active {
			continue
		}
		draw_single_cmd_fx(&fx)
	}
	draw_cursor_preview_3d()
	rl.EndBlendMode()
	rlgl.EnableDepthMask()
	rlgl.EnableBackfaceCulling()
}

@(private)
draw_single_cmd_fx :: proc(fx: ^Cmd_Fx) {
	t := clamp(fx.clock / fx.duration, 0, 1)
	ease := 1.0 - (1.0 - t) * (1.0 - t)
	fade := math.sin(clamp(t * 1.15, 0, 1) * math.PI * 0.5)
	alpha := clamp(1.0 - t * t, 0, 1)
	_ = fade

	center := fx.pos
	is_unit := false
	if g.handle_is_valid(fx.target) {
		if idx, ok := g.unit_index(&app.game.units, fx.target); ok {
			center = unit_ground(idx)
			is_unit = true
		}
	}
	outer_col, inner_col := fx_palette(fx.kind)
	if is_unit {
		draw_target_lock_fx(center, ease, alpha, outer_col, inner_col)
		return
	}
	draw_ground_ring(center, 0.036, math.lerp(f32(0.14), f32(0.54), ease), 0.034, 24, fx_alpha(outer_col, alpha * 0.72))
	draw_ground_diamond(center, 0.038, math.lerp(f32(0.16), f32(0.05), ease), fx_alpha(inner_col, alpha * 0.95))
	chev_r := math.lerp(f32(0.60), f32(0.15), ease)
	draw_inward_chevrons(center, 0.042, chev_r, 0.14, 0.09, fx_alpha(outer_col, alpha))
}

@(private)
draw_target_lock_fx :: proc(center: rl.Vector3, ease, alpha: f32, outer_col, inner_col: rl.Color) {
	pulse := 1.0 - ease * 0.35
	r_ring := math.lerp(f32(0.68), f32(0.46), ease)
	draw_ground_ring(center, 0.038, r_ring, 0.045 * pulse, 24, fx_alpha(outer_col, alpha * 0.90))
	draw_ground_ring(center, 0.040, 0.42, 0.025, 24, fx_alpha(inner_col, alpha * 0.85))
	draw_inward_chevrons(center, 0.044, math.lerp(f32(0.84), f32(0.50), ease), 0.16, 0.10, fx_alpha(outer_col, alpha))
}

@(private)
draw_cursor_preview_3d :: proc() {
	if app.menu_open || app.command_mode == .None {
		return
	}
	mouse := input_mouse_pos()
	if ui.blocks_pointer(&app.ui_ctx) || rl.CheckCollisionPointRec(mouse, app.minimap_rect) {
		return
	}
	hit, ok := screen_to_world_ground(mouse)
	if !ok {
		return
	}
	cell := world_to_grid_clamped(hit)
	center := cell_center(cell)
	kind := Cmd_Fx_Kind.Move
	if app.command_mode == .Attack {
		kind = .Attack
	} else if app.command_mode == .Patrol {
		kind = .Patrol
	}
	outer_col, inner_col := fx_palette(kind)
	if !g.grid_is_walkable(&app.game.grid, cell) {
		outer_col = rl.Color{215, 75, 75, 255}
		inner_col = outer_col
	}
	pulse := 0.5 + 0.5 * math.sin(f32(rl.GetTime()) * 8.0)
	draw_ground_ring(center, 0.034, 0.38 + 0.04 * pulse, 0.032, 20, fx_alpha(outer_col, 0.72))
	draw_inward_chevrons(center, 0.036, 0.46 + 0.04 * pulse, 0.11, 0.07, fx_alpha(inner_col, 0.85))
}

@(private)
fx_palette :: proc(kind: Cmd_Fx_Kind) -> (outer_col, inner_col: rl.Color) {
	switch kind {
	case .Move:
		return rl.Color{110, 245, 130, 255}, rl.Color{245, 225, 115, 255}
	case .Attack:
		return rl.Color{255, 78, 62, 255}, rl.Color{255, 196, 108, 255}
	case .Patrol:
		return rl.Color{88, 220, 255, 255}, rl.Color{255, 212, 92, 255}
	}
	return rl.WHITE, rl.WHITE
}

@(private)
fx_alpha :: proc(c: rl.Color, a: f32) -> rl.Color {
	out := c
	out.a = u8(clamp(a, 0, 1) * f32(c.a))
	return out
}

@(private)
draw_ground_ring :: proc(center: rl.Vector3, y, radius, width: f32, segs: int, col: rl.Color) {
	r_in := max(radius - width * 0.5, 0.01)
	r_out := radius + width * 0.5
	for i in 0..<segs {
		a0 := f32(i) * math.TAU / f32(segs)
		a1 := f32(i + 1) * math.TAU / f32(segs)
		c0, s0 := math.cos(a0), math.sin(a0)
		c1, s1 := math.cos(a1), math.sin(a1)
		p0 := rl.Vector3{center.x + c0 * r_in, y, center.z + s0 * r_in}
		p1 := rl.Vector3{center.x + c0 * r_out, y, center.z + s0 * r_out}
		p2 := rl.Vector3{center.x + c1 * r_out, y, center.z + s1 * r_out}
		p3 := rl.Vector3{center.x + c1 * r_in, y, center.z + s1 * r_in}
		rl.DrawTriangle3D(p0, p1, p2, col)
		rl.DrawTriangle3D(p0, p2, p3, col)
	}
}

@(private)
draw_ground_diamond :: proc(center: rl.Vector3, y, r: f32, col: rl.Color) {
	c := rl.Vector3{center.x, y, center.z}
	n := rl.Vector3{center.x, y, center.z - r}
	e := rl.Vector3{center.x + r, y, center.z}
	s := rl.Vector3{center.x, y, center.z + r}
	w := rl.Vector3{center.x - r, y, center.z}
	rl.DrawTriangle3D(c, n, e, col)
	rl.DrawTriangle3D(c, e, s, col)
	rl.DrawTriangle3D(c, s, w, col)
	rl.DrawTriangle3D(c, w, n, col)
}

@(private)
draw_inward_chevrons :: proc(center: rl.Vector3, y, radius, length, half_w: f32, col: rl.Color) {
	for k in 0..<4 {
		ang := math.PI * 0.25 + f32(k) * math.PI * 0.5
		out_dir := rl.Vector3{math.cos(ang), 0, math.sin(ang)}
		perp := rl.Vector3{-out_dir.z, 0, out_dir.x}
		tip := rl.Vector3{center.x, y, center.z} + out_dir * radius
		tail := tip + out_dir * length
		wing_l := tail + out_dir * (length * 0.45) + perp * half_w
		wing_r := tail + out_dir * (length * 0.45) - perp * half_w
		rl.DrawTriangle3D(tip, wing_l, tail, col)
		rl.DrawTriangle3D(tip, tail, wing_r, col)
	}
}
