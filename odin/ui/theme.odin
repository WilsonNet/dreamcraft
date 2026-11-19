// Arab / European Medieval Fantasy (Lord of the Rings x One Thousand and One Nights x Mamluk) UI tokens.
package ui

import rl "vendor:raylib"

RAD_XS :: f32(4)
RAD_SM :: f32(6)
RAD_MD :: f32(8)
RAD_LG :: f32(12)
RAD_XL :: f32(14)

// Torchlit Damascus obsidian, oiled walnut, and recessed velvet-slate grounds
COL_SCRIM          :: rl.Color{8, 6, 5, 182}
COL_SURFACE_0      :: rl.Color{17, 14, 12, 240}
COL_SURFACE_1      :: rl.Color{25, 21, 17, 244}
COL_SURFACE_2      :: rl.Color{35, 29, 23, 248}
COL_SURFACE_3      :: rl.Color{46, 38, 30, 252}
COL_SURFACE_WELL   :: rl.Color{12, 10, 8, 246}

// Tooled leather & aged brass secondary buttons
COL_BTN_TOP        :: rl.Color{46, 37, 29, 250}
COL_BTN_BOT        :: rl.Color{32, 26, 20, 250}
COL_BTN_HOVER      :: rl.Color{62, 50, 38, 254}

// Oasis emerald & gold-leaf primary CTA
COL_PRIMARY_TOP    :: rl.Color{42, 108, 66, 252}
COL_PRIMARY_BOT    :: rl.Color{28, 76, 46, 252}
COL_PRIMARY_HOVER  :: rl.Color{54, 130, 80, 255}

// Sovereign sun-gold & amber damask active state
COL_ACTIVE_TOP     :: rl.Color{172, 122, 34, 254}
COL_ACTIVE_BOT     :: rl.Color{124, 84, 20, 254}

// Carbuncle crimson silk danger state
COL_DANGER_TOP     :: rl.Color{142, 42, 38, 250}
COL_DANGER_BOT     :: rl.Color{98, 28, 26, 250}
COL_DANGER_HOVER   :: rl.Color{168, 52, 46, 255}

// Burnished brass, silver-lapis, and gilded filigree borders
COL_BORDER_SUBTLE  :: rl.Color{104, 84, 54, 150}
COL_BORDER_DEFAULT :: rl.Color{146, 118, 72, 210}
COL_BORDER_HOVER   :: rl.Color{218, 182, 108, 245}
COL_BORDER_GOLD    :: rl.Color{248, 214, 120, 252}
COL_BORDER_PRIMARY :: rl.Color{126, 214, 142, 240}
COL_BORDER_DANGER  :: rl.Color{236, 108, 96, 240}

// Illuminated vellum parchment & silk-road gem typography colors
COL_TEXT_PRIMARY   :: rl.Color{248, 241, 228, 255}
COL_TEXT_SECONDARY :: rl.Color{218, 204, 180, 255}
COL_TEXT_MUTED     :: rl.Color{172, 156, 132, 255}
COL_TEXT_GOLD      :: rl.Color{248, 216, 124, 255}
COL_TEXT_ACTIVE    :: rl.Color{255, 250, 234, 255}
COL_TEXT_MOVE      :: rl.Color{122, 236, 148, 255}
COL_TEXT_ATTACK    :: rl.Color{255, 120, 100, 255}
COL_TEXT_PATROL    :: rl.Color{112, 224, 252, 255}
COL_TEXT_DANGER    :: rl.Color{250, 114, 100, 255}

style_island :: proc(radius := RAD_LG) -> Surface_Style {
	return Surface_Style{
		bg_top        = COL_SURFACE_1,
		bg_bot        = COL_SURFACE_0,
		bg_hover      = COL_SURFACE_1,
		bg_active     = COL_SURFACE_2,
		border        = COL_BORDER_DEFAULT,
		border_hover  = COL_BORDER_HOVER,
		border_active = COL_BORDER_GOLD,
		accent        = COL_TEXT_GOLD,
		border_w      = 1.2,
		radius        = rad(radius),
		elevation     = 2,
		top_rim       = 0.18,
	}
}

style_modal :: proc(radius := RAD_XL, border := COL_BORDER_GOLD) -> Surface_Style {
	return Surface_Style{
		bg_top        = COL_SURFACE_3,
		bg_bot        = COL_SURFACE_1,
		bg_hover      = COL_SURFACE_3,
		bg_active     = COL_SURFACE_3,
		border        = border,
		border_hover  = border,
		border_active = border,
		accent        = border,
		border_w      = 1.4,
		radius        = rad(radius),
		elevation     = 3,
		top_rim       = 0.24,
	}
}

style_card :: proc(radius := RAD_MD) -> Surface_Style {
	return Surface_Style{
		bg_top        = COL_SURFACE_2,
		bg_bot        = COL_SURFACE_1,
		bg_hover      = COL_SURFACE_2,
		bg_active     = COL_SURFACE_3,
		border        = COL_BORDER_SUBTLE,
		border_hover  = COL_BORDER_DEFAULT,
		border_active = COL_BORDER_GOLD,
		accent        = COL_TEXT_GOLD,
		border_w      = 1.0,
		radius        = rad(radius),
		elevation     = 1,
		top_rim       = 0.14,
	}
}

style_well :: proc(radius := RAD_MD) -> Surface_Style {
	return Surface_Style{
		bg_top        = COL_SURFACE_WELL,
		bg_bot        = COL_SURFACE_0,
		bg_hover      = COL_SURFACE_WELL,
		bg_active     = COL_SURFACE_WELL,
		border        = COL_BORDER_SUBTLE,
		border_hover  = COL_BORDER_SUBTLE,
		border_active = COL_BORDER_SUBTLE,
		accent        = COL_TEXT_GOLD,
		border_w      = 1.0,
		radius        = rad(radius),
		elevation     = 0,
		top_rim       = 0.05,
		clip_children = true,
	}
}

style_bar :: proc() -> Surface_Style {
	return Surface_Style{
		bg_top    = COL_SURFACE_1,
		bg_bot    = COL_SURFACE_0,
		bg_hover  = COL_SURFACE_1,
		bg_active = COL_SURFACE_1,
		border    = COL_BORDER_SUBTLE,
		border_w  = 1.0,
		radius    = rad(0),
		elevation = 1,
		top_rim   = 0.08,
	}
}

style_pill_track :: proc() -> Surface_Style {
	return Surface_Style{
		bg_top        = COL_SURFACE_WELL,
		bg_bot        = COL_SURFACE_0,
		border        = COL_BORDER_SUBTLE,
		border_w      = 1.0,
		radius        = rad_pill(),
		elevation     = 0,
		top_rim       = 0.06,
		clip_children = true,
	}
}

@(private)
BUTTON_STYLES := [Button_Variant]Surface_Style{
	.Secondary = {
		bg_top = COL_BTN_TOP, bg_bot = COL_BTN_BOT, bg_hover = COL_BTN_HOVER, bg_active = COL_ACTIVE_TOP,
		border = COL_BORDER_DEFAULT, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.1, radius = {RAD_MD, RAD_MD, RAD_MD, RAD_MD},
		elevation = 1, top_rim = 0.16, state_layer = true,
	},
	.Primary = {
		bg_top = COL_PRIMARY_TOP, bg_bot = COL_PRIMARY_BOT, bg_hover = COL_PRIMARY_HOVER, bg_active = COL_ACTIVE_TOP,
		border = COL_BORDER_PRIMARY, border_hover = COL_BORDER_GOLD, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_PRIMARY, border_w = 1.1, radius = {RAD_MD, RAD_MD, RAD_MD, RAD_MD},
		elevation = 1, top_rim = 0.22, state_layer = true,
	},
	.Tonal = {
		// Royal Lapis Lazuli & Damascus steel (Levantine / Gondorian accent)
		bg_top = {32, 46, 68, 250}, bg_bot = {22, 32, 48, 250}, bg_hover = {44, 62, 90, 254}, bg_active = COL_ACTIVE_TOP,
		border = {104, 142, 192, 215}, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.1, radius = {RAD_MD, RAD_MD, RAD_MD, RAD_MD},
		elevation = 1, top_rim = 0.18, state_layer = true,
	},
	.Ghost = {
		bg_top = {32, 26, 20, 125}, bg_bot = {22, 18, 14, 125}, bg_hover = {56, 46, 35, 228}, bg_active = COL_ACTIVE_TOP,
		border = {104, 84, 54, 100}, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.0, radius = {RAD_MD, RAD_MD, RAD_MD, RAD_MD},
		elevation = 0, top_rim = 0.10, state_layer = true,
	},
	.Danger = {
		bg_top = COL_DANGER_TOP, bg_bot = COL_DANGER_BOT, bg_hover = COL_DANGER_HOVER, bg_active = COL_DANGER_HOVER,
		border = COL_BORDER_DANGER, border_hover = {250, 144, 128, 252}, border_active = COL_BORDER_DANGER,
		accent = COL_TEXT_PRIMARY, border_w = 1.1, radius = {RAD_MD, RAD_MD, RAD_MD, RAD_MD},
		elevation = 1, top_rim = 0.20, state_layer = true,
	},
	.Tool = {
		bg_top = {38, 31, 24, 244}, bg_bot = {27, 22, 17, 244}, bg_hover = {56, 45, 35, 252}, bg_active = COL_ACTIVE_TOP,
		border = COL_BORDER_SUBTLE, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.0, radius = {RAD_SM, RAD_SM, RAD_SM, RAD_SM},
		elevation = 1, top_rim = 0.14, state_layer = true,
	},
	.Compact = {
		bg_top = {36, 30, 23, 246}, bg_bot = {26, 21, 16, 246}, bg_hover = {54, 44, 34, 252}, bg_active = COL_ACTIVE_TOP,
		border = COL_BORDER_SUBTLE, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.0, radius = {RAD_SM, RAD_SM, RAD_SM, RAD_SM},
		elevation = 0, top_rim = 0.14, state_layer = true,
	},
	.Bone = {
		bg_top = {34, 28, 22, 244}, bg_bot = {24, 20, 16, 244}, bg_hover = {50, 41, 32, 252}, bg_active = COL_ACTIVE_TOP,
		border = COL_BORDER_SUBTLE, border_hover = COL_BORDER_HOVER, border_active = COL_BORDER_GOLD,
		accent = COL_TEXT_GOLD, border_w = 1.0, radius = {RAD_XS, RAD_XS, RAD_XS, RAD_XS},
		elevation = 0, top_rim = 0.10, state_layer = true,
	},
}

style_button :: proc(variant: Button_Variant) -> Surface_Style {
	return BUTTON_STYLES[variant]
}

style_tab :: proc(selected: bool) -> Surface_Style {
	s := style_button(.Compact)
	s.radius = rad_pill()
	s.border_w = selected ? 1.1 : 0.75
	s.top_rim = selected ? 0.24 : 0.05
	if !selected {
		s.bg_top = rl.Color{23, 19, 15, 175}
		s.bg_bot = rl.Color{18, 15, 12, 175}
		s.border = rl.Color{86, 68, 44, 95}
	}
	return s
}

style_badge :: proc(tone: Badge_Tone) -> (Surface_Style, rl.Color) {
	bg, border, fg := badge_palette(tone)
	return Surface_Style{
		bg_top        = bg,
		bg_bot        = bg,
		bg_hover      = rl.Color{min(bg.r + 18, 255), min(bg.g + 16, 255), min(bg.b + 14, 255), 252},
		bg_active     = COL_ACTIVE_TOP,
		border        = border,
		border_hover  = fg,
		border_active = COL_BORDER_GOLD,
		accent        = fg,
		border_w      = 1.0,
		radius        = rad_pill(),
		elevation     = 0,
		top_rim       = 0.16,
		state_layer   = true,
	}, fg
}

@(private)
badge_palette :: proc(tone: Badge_Tone) -> (bg, border, fg: rl.Color) {
	switch tone {
	case .Gold:
		return rl.Color{64, 48, 18, 244}, rl.Color{214, 174, 74, 238}, COL_TEXT_GOLD
	case .Emerald:
		return rl.Color{22, 56, 34, 244}, rl.Color{86, 172, 104, 235}, COL_TEXT_MOVE
	case .Crimson:
		return rl.Color{68, 24, 22, 244}, rl.Color{206, 86, 76, 235}, COL_TEXT_ATTACK
	case .Cyan:
		return rl.Color{18, 48, 62, 244}, rl.Color{86, 184, 212, 235}, COL_TEXT_PATROL
	case .Amber:
		return rl.Color{66, 44, 16, 244}, rl.Color{220, 154, 62, 235}, rl.Color{255, 202, 98, 255}
	case .Neutral:
	}
	return rl.Color{34, 28, 22, 242}, COL_BORDER_DEFAULT, COL_TEXT_SECONDARY
}

style_keycap :: proc() -> Surface_Style {
	return Surface_Style{
		bg_top    = rl.Color{46, 37, 28, 248},
		bg_bot    = rl.Color{28, 22, 17, 248},
		border    = rl.Color{148, 118, 72, 225},
		border_w  = 1.0,
		radius    = rad(4),
		elevation = 0,
		top_rim   = 0.24,
	}
}

style_swatch :: proc(col: rl.Color, selected: bool) -> Surface_Style {
	return Surface_Style{
		bg_top        = col,
		bg_bot        = col,
		bg_hover      = col,
		bg_active     = col,
		border        = selected ? COL_BORDER_GOLD : rl.Color{74, 60, 42, 235},
		border_hover  = COL_TEXT_PRIMARY,
		border_active = COL_BORDER_GOLD,
		accent        = COL_TEXT_GOLD,
		border_w      = selected ? 2.0 : 1.0,
		radius        = rad(RAD_SM),
		elevation     = selected ? 1 : 0,
		top_rim       = 0.16,
		state_layer   = true,
	}
}

style_progress :: proc(fill_col: rl.Color) -> Surface_Style {
	return Surface_Style{
		bg_top    = rl.Color{16, 13, 11, 244},
		bg_bot    = rl.Color{11, 9, 8, 244},
		border    = COL_BORDER_SUBTLE,
		accent    = fill_col,
		border_w  = 1.0,
		radius    = rad_pill(),
		elevation = 0,
		top_rim   = 0.08,
	}
}
