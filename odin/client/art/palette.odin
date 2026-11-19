// Unit palette: material table and team cloth colours.
//
// Values follow the art-direction skill: warm skin, linen cream, aged brass,
// blue-grey steel, deep indigo cloth, warm leather. Metalness is deliberately
// low so the watercolour shader keeps the surfaces matte and readable.
package art

import rl "vendor:raylib"
import spec "./spec"

Mat_Kind :: spec.Mat_Kind

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
	.Hair          = {albedo = rl.Color{56, 42, 34, 255}, metal = 0.00, glow = 0.0, ao = 0.96},
	.Eye           = {albedo = rl.Color{246, 244, 238, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Iris          = {albedo = rl.Color{52, 78, 126, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Bark          = {albedo = rl.Color{114, 78, 50, 255}, metal = 0.00, glow = 0.0, ao = 0.94},
	.Bark_Dark     = {albedo = rl.Color{76, 52, 34, 255}, metal = 0.00, glow = 0.0, ao = 0.86},
	.Leaf_Deep     = {albedo = rl.Color{42, 92, 52, 255}, metal = 0.00, glow = 0.0, ao = 0.78},
	.Leaf_Mid      = {albedo = rl.Color{66, 128, 60, 255}, metal = 0.00, glow = 0.0, ao = 0.94},
	.Leaf_Sun      = {albedo = rl.Color{104, 156, 66, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Leaf_Pine     = {albedo = rl.Color{46, 102, 58, 255}, metal = 0.00, glow = 0.0, ao = 0.90},
	.Leaf_Pine_Sun = {albedo = rl.Color{76, 138, 68, 255}, metal = 0.00, glow = 0.0, ao = 1.00},
	.Moss          = {albedo = rl.Color{86, 136, 58, 255}, metal = 0.00, glow = 0.0, ao = 0.92},
	.Stone         = {albedo = rl.Color{148, 144, 134, 255}, metal = 0.00, glow = 0.0, ao = 0.96},
	.Stone_Dark    = {albedo = rl.Color{98, 96, 92, 255}, metal = 0.00, glow = 0.0, ao = 0.86},
	.Banner_Cloth  = {albedo = rl.Color{166, 48, 44, 255}, metal = 0.00, glow = 0.0, ao = 0.96},
	.Banner_Gold   = {albedo = rl.Color{218, 174, 74, 255}, metal = 0.55, glow = 0.10, ao = 1.00},
}

Team_Palette :: struct {
	cloth:      rl.Color,
	cloth_dark: rl.Color,
	cream:      rl.Color,
	hero:       bool,
}

palette_for_team :: proc(enemy: bool) -> Team_Palette {
	return palette_for_unit(enemy, false)
}

palette_for_unit :: proc(enemy: bool, hero: bool = false) -> Team_Palette {
	if enemy {
		return Team_Palette{
			cloth = rl.Color{158, 58, 50, 255},
			cloth_dark = rl.Color{96, 34, 34, 255},
			cream = rl.Color{196, 184, 156, 255},
		}
	}
	if hero {
		// Royal cobalt and gilded ivory distinguish Liiroy, the Bold from regular Luk Soldiers.
		return Team_Palette{
			cloth = rl.Color{42, 98, 212, 255},
			cloth_dark = rl.Color{22, 52, 134, 255},
			cream = rl.Color{240, 206, 118, 255},
			hero = true,
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

