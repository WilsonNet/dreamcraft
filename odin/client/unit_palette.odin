// Unit palette: material table and team cloth colours.
//
// Values follow the art-direction skill: warm skin, linen cream, aged brass,
// blue-grey steel, deep indigo cloth, warm leather. Metalness is deliberately
// low so the watercolour shader keeps the surfaces matte and readable.
package main

import rl "vendor:raylib"

Mat_Kind :: enum u8 {
	Skin,
	Steel,
	Steel_Dark,
	Iron,
	Brass,
	Brass_Dark,
	Mail,
	Leather,
	Leather_Dark,
	Blade,
	Cloth,
	Cloth_Dark,
	Cream,
	Cream_Dark,
	Jet,
	Glow,
	Hair,
	Eye,
	COUNT,
}

Mat_Def :: struct {
	albedo: rl.Color,
	metal:  f32,
	glow:   f32,
	ao:     f32,
}

MAT_DEFS := #partial [Mat_Kind]Mat_Def {
	.Skin         = {albedo = rl.Color{226, 176, 136, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Steel        = {albedo = rl.Color{128, 134, 146, 255}, metal = 0.55, glow = 0.0, ao = 1.00},
	.Steel_Dark   = {albedo = rl.Color{78, 82, 94, 255}, metal = 0.50, glow = 0.0, ao = 0.96},
	.Iron         = {albedo = rl.Color{108, 114, 126, 255}, metal = 0.20, glow = 0.0, ao = 1.00},
	.Brass        = {albedo = rl.Color{178, 140, 82, 255}, metal = 0.65, glow = 0.0, ao = 1.00},
	.Brass_Dark   = {albedo = rl.Color{112, 86, 52, 255}, metal = 0.60, glow = 0.0, ao = 0.95},
	.Mail         = {albedo = rl.Color{110, 115, 126, 255}, metal = 0.45, glow = 0.0, ao = 0.94},
	.Leather      = {albedo = rl.Color{124, 84, 52, 255}, metal = 0.04, glow = 0.0, ao = 1.00},
	.Leather_Dark = {albedo = rl.Color{74, 50, 34, 255}, metal = 0.04, glow = 0.0, ao = 0.98},
	.Blade        = {albedo = rl.Color{198, 204, 212, 255}, metal = 0.70, glow = 0.0, ao = 1.00},
	.Cloth        = {albedo = rl.Color{64, 84, 144, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Cloth_Dark   = {albedo = rl.Color{38, 50, 94, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Cream        = {albedo = rl.Color{198, 186, 158, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Cream_Dark   = {albedo = rl.Color{152, 140, 118, 255}, metal = 0.00, glow = 0.0, ao = 0.98},
	.Jet          = {albedo = rl.Color{28, 28, 32, 255}, metal = 0.20, glow = 0.0, ao = 0.90},
	.Glow         = {albedo = rl.Color{255, 158, 72, 255}, metal = 0.00, glow = 1.0, ao = 1.00},
	.Hair         = {albedo = rl.Color{56, 42, 34, 255}, metal = 0.00, glow = 0.0, ao = 0.96},
	.Eye          = {albedo = rl.Color{244, 242, 234, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
}

Team_Palette :: struct {
	cloth:      rl.Color,
	cloth_dark: rl.Color,
	cream:      rl.Color,
}

palette_for_team :: proc(enemy: bool) -> Team_Palette {
	if enemy {
		return Team_Palette{
			cloth = rl.Color{158, 58, 50, 255},
			cloth_dark = rl.Color{96, 34, 34, 255},
			cream = rl.Color{196, 184, 156, 255},
		}
	}
	return Team_Palette{
		cloth = rl.Color{64, 84, 144, 255},
		cloth_dark = rl.Color{38, 50, 94, 255},
		cream = rl.Color{198, 186, 158, 255},
	}
}

mb_material :: proc(b: ^Mesh_Builder, kind: Mat_Kind) -> Mat_Def {
	def := MAT_DEFS[kind]
	#partial switch kind {
	case .Cloth:
		def.albedo = b.palette.cloth
	case .Cloth_Dark:
		def.albedo = b.palette.cloth_dark
	case .Cream:
		def.albedo = b.palette.cream
	case .Cream_Dark:
		def.albedo = rl.Color{
			u8(f32(b.palette.cream.r) * 0.66),
			u8(f32(b.palette.cream.g) * 0.64),
			u8(f32(b.palette.cream.b) * 0.62),
			255,
		}
	case:
	}
	return def
}

