// Battlefield HUD in the "Saint Louis Basin" world: the console is the band of a Mamluk
// inlaid brass basin. Hammered brass rims, a bitumen-black field, silver interlace, roundels,
// and command medallions that fill with gold inlay when armed.
package main

import "core:fmt"
import rl "vendor:raylib"
import ui "vinland:vui"
import g "../game"

CONSOLE_H :: f32(150)
HUD_HEIGHT :: CONSOLE_H

// ---------------------------------------------------------------------------
// Shared Basin components
// ---------------------------------------------------------------------------

LABEL :: "text-[13px] font-bold uppercase tracking-[0.12em] text-silver"
VALUE :: "text-[13px] font-bold tabular-nums text-silver"
BRASS_RIM :: "bg-linear-to-b from-brass-hi via-brass to-brass-lo bg-tex-hammered bg-tile-96"

Tone :: enum {
	Lapis,
	Carnelian,
	Inlay, // the one primary action of a dialog: gold inlay, dark ink
	Brass,
}

@(private)
tone_fill :: proc(t: Tone) -> string {
	switch t {
	case .Lapis:
		return "bg-linear-to-b from-lapis-hi to-lapis-lo"
	case .Carnelian:
		return "bg-linear-to-b from-carnelian-hi to-carnelian"
	case .Inlay:
		return "bg-linear-to-b from-inlay via-brass-hi to-[#7c5d2a]"
	case .Brass:
		return "bg-linear-to-b from-bitumen-raised to-bitumen"
	}
	return ""
}

// Brass-rimmed bitumen panel: `if basin_panel("w-[420px]") { ... }`.
@(deferred_none = basin_panel_end)
basin_panel :: proc(outer := "", inner := "", loc := #caller_location) -> bool {
	ui.open(ui.cx("relative rounded-[16px] corner-scoop p-[10px] shadow-[0_8px_24px_rgba(0,0,0,0.7)] pointer-events-auto", PLATE, outer), loc = loc)
	ui.el(ui.cx(ENGRAVED, "inset-[4px] rounded-[13px] corner-scoop"))
	rivet("top-[3px] left-[3px]")
	rivet("top-[3px] right-[3px]")
	rivet("bottom-[3px] left-[3px]")
	rivet("bottom-[3px] right-[3px]")
	ui.open(ui.cx("relative rounded-[10px] corner-scoop", WELL, inner))
	return true
}

basin_panel_end :: proc() {
	ui.close()
	ui.close()
}

keycap :: proc(k: string, loc := #caller_location) {
	ui.text(k, "rounded-[3px] corner-bevel bg-bitumen-deep px-1.5 py-px text-[11px] font-extrabold text-brass-hi ring-1 ring-brass-lo", loc = loc)
}

// Engraved silver heading with a short interlace rule after it.
engraved_heading :: proc(text: string, loc := #caller_location) {
	if ui.div("flex items-center gap-3", loc = loc) {
		ui.text(text, "text-[13px] font-bold uppercase tracking-[0.12em] text-brass-hi")
		ui.el("h-2 grow bg-brass/60 bg-tex-interlace bg-tile-8")
	}
}

// Round command medallion with an icon, a keycap and a label. Armed = gold inlay.
// Medallion_State: Armed is the one command waiting for a click (full gold inlay); On marks a
// toggle that is engaged (gold ring on lapis); Disabled when nothing can receive the order.
Medallion_State :: enum {
	Idle,
	On,
	Armed,
	Disabled,
}

medallion :: proc(icon: ui.Icon, label, key: string, state: Medallion_State, size := "size-[58px]", loc := #caller_location) -> (clicked: bool) {
	flags: ui.Elem_Flags = state == .Disabled ? {.Disabled} : {}
	if ui.button_box(state == .Disabled ? "group flex w-[68px] flex-col items-center gap-1 opacity-45 cursor-not-allowed pointer-events-auto" : "group flex w-[68px] flex-col items-center gap-1 pointer-events-auto", flags, loc = loc) {
		// bezel: cast brass ring with a lit top edge and a contact shadow
		bezel: string
		dome: string
		switch state {
		case .Armed:
			bezel = "bg-linear-to-b from-[#e6d2a2] via-brass-hi to-brass-lo ring-1 ring-black/80 shadow-[0_0_14px_rgba(205,179,124,0.35),0_3px_4px_rgba(0,0,0,0.8)]"
			dome = "bg-radial from-[#ecd8a8] via-[#c9a35f] to-[#6e4e1e] inset-shadow-[0_-4px_6px_rgba(60,35,5,0.55)]"
		case .On:
			bezel = "bg-linear-to-b from-[#e6d2a2] via-brass-hi to-brass-lo ring-1 ring-black/80 shadow-[0_3px_4px_rgba(0,0,0,0.8)]"
			dome = "bg-radial from-[#4f6fa8] via-lapis to-[#0b1428] inset-shadow-[0_-4px_6px_rgba(0,0,0,0.6)] ring-2 ring-inset ring-brass-hi"
		case .Idle:
			bezel = "bg-linear-to-b from-brass-hi via-brass to-[#4a3618] ring-1 ring-black/80 shadow-[0_3px_4px_rgba(0,0,0,0.8)] transition-colors group-hover:from-[#e6d2a2]"
			dome = "bg-radial from-[#46659e] via-lapis to-[#0b1428] inset-shadow-[0_-4px_6px_rgba(0,0,0,0.6)] group-active:from-lapis"
		case .Disabled:
			bezel = "bg-linear-to-b from-[#7a6a50] to-[#3a3024] ring-1 ring-black/80"
			dome = "bg-radial from-[#3a3630] to-bitumen-deep"
		}
		if ui.div(ui.cx("relative rounded-full p-[4px]", size, bezel)) {
			if state == .Armed {
				ui.el("pointer-events-none absolute -inset-[5px] rounded-full ring-2 ring-brass-hi/70 animate-pulse")
			}
			if ui.div(ui.cx("relative flex size-full items-center justify-center overflow-hidden rounded-full", dome)) {
				// specular highlight of the domed enamel
				ui.el("pointer-events-none absolute inset-0 rounded-full inset-shadow-[0_3px_2px_rgba(255,250,235,0.22)]")
				ui.el("pointer-events-none absolute inset-0 rounded-full inset-shadow-[0_-3px_3px_rgba(205,179,124,0.18)]")
				ui.icon(icon, state == .Armed ? "relative size-7 text-[#24140a]" : "relative size-7 text-silver transition-colors group-hover:text-inlay")
			}
			if key != "" {
				if ui.div("absolute -right-2 -bottom-1") {
					keycap(key)
				}
			}
		}
		ui.text(label, state == .Armed || state == .On ? "text-[13px] font-extrabold uppercase tracking-[0.1em] text-brass-hi text-shadow-[0_1px_0_rgba(0,0,0,0.9)]" : "text-[13px] font-bold uppercase tracking-[0.1em] text-silver-dim text-shadow-[0_1px_0_rgba(0,0,0,0.9)] group-hover:text-silver")
		clicked = state != .Disabled && ui.clicked()
	}
	return
}

// Bevelled plaque button for menus and dialogs.
plaque_button :: proc(label: string, tone: Tone, key := "", icon_cls := "", extra := "", loc := #caller_location) -> (clicked: bool) {
	ink := tone == .Inlay ? "text-[#2a1a08]" : "text-[#e4d8bf]"
	if ui.button_box(ui.cx("group flex h-11 items-center gap-3 rounded-md corner-bevel px-4 ring-1 ring-brass inset-shadow-xs inset-shadow-white/25 transition-[filter] hover:brightness-115 active:brightness-90", tone_fill(tone), extra), loc = loc) {
		if icon_cls != "" {
			ui.el(ui.cx("size-5 shrink-0", tone == .Inlay ? "bg-[#2a1a08]" : "bg-silver", icon_cls))
		}
		ui.text(label, ui.cx("grow text-[14px] font-extrabold uppercase tracking-[0.1em]", ink))
		if key != "" {
			keycap(key)
		}
		clicked = ui.clicked()
	}
	return
}

// Small bevelled tool toggle used by the editor bars.
chip_button :: proc(label: string, active: bool, icon_cls := "", extra := "", loc := #caller_location) -> (clicked: bool) {
	cls := active ? "bg-linear-to-b from-brass-hi to-[#7c5d2a] ring-silver text-[#2a1a08]" : "bg-linear-to-b from-bitumen-raised to-bitumen ring-brass-lo text-silver hover:ring-brass hover:text-inlay"
	if ui.button_box(ui.cx("flex h-7 shrink-0 items-center gap-1.5 rounded-[4px] corner-bevel px-2 ring-1 transition-colors", cls, extra), loc = loc) {
		if icon_cls != "" {
			ui.el(ui.cx("size-4 shrink-0", active ? "bg-[#2a1a08]" : "bg-silver", icon_cls))
		}
		if label != "" {
			ui.text(label, "text-[12px] font-bold uppercase tracking-[0.08em] whitespace-nowrap")
		}
		clicked = ui.clicked()
	}
	return
}

// ---------------------------------------------------------------------------
// Frame composition
// ---------------------------------------------------------------------------

compose_active_ui :: proc(w, h: f32) {
	// full-screen layer that never catches the mouse; panels opt back in
	if ui.div("relative size-full pointer-events-none") {
		switch app.mode {
		case .Game, .Pause_Menu:
			compose_world_overlays(w, h)
			compose_battlefield_hud(w, h)
			if app.menu_open || app.mode == .Pause_Menu {
				compose_pause_menu()
			}
		case .Model_Picker:
			compose_model_picker(w, h)
		case .Model_Editor:
			compose_model_editor(w, h)
		}
		if app.help_open {
			compose_help_window(w, h)
		}
	}
}

compose_battlefield_hud :: proc(w, h: f32) {
	compose_top_cartouche()
	compose_console(w)
	compose_command_prompt()
	compose_campaign_banner()
	compose_outcome_banner()
	compose_selection_box()
}

@(private)
compose_top_cartouche :: proc() {
	if ui.div("absolute top-0 left-1/2 -translate-x-1/2 flex items-stretch") {
		if ui.div(ui.cx("relative rounded-b-[18px] corner-b-scoop px-[10px] pb-[10px] pointer-events-auto shadow-[0_4px_10px_rgba(0,0,0,0.7)]", PLATE)) {
			ui.el(ui.cx(ENGRAVED, "inset-x-[3px] bottom-[3px] top-0 rounded-b-[16px] corner-b-scoop"))
			rivet("bottom-[10px] left-[-4px]")
			rivet("bottom-[10px] right-[-4px]")
			if ui.div(ui.cx("relative flex h-10 items-center gap-5 rounded-b-[12px] corner-b-scoop px-6 whitespace-nowrap", WELL)) {
				ui.text("Through the Woods", "font-display text-[22px] leading-none text-brass-hi text-shadow-[0_1px_0_rgba(0,0,0,0.9)]")
				ui.el("h-4 w-px bg-brass-lo")
				ui.text(fmt.tprintf("Waypoint %d / %d", app.game.waypoints.current, app.game.waypoints.count), VALUE)
				ui.text(fmt.tprintf("Fog %.1f%%", g.fog_coverage_percent(&app.game.fog)), VALUE)
				ui.text(fmt.tprintf("%d fps", rl.GetFPS()), "text-[13px] font-bold tabular-nums text-silver-dim")
				ui.el("h-4 w-px bg-brass-lo")
				if chip_button("Help", app.help_open, extra = "h-6") {
					handle_hud_ui_msg(.Help_Toggle)
				}
			}
		}
	}
}

// Cast-brass plate: hammered gradient, lit top edge, shaded lower edge, dark outer seam.
PLATE :: "bg-linear-to-b from-[#c9b07a] via-brass to-[#5e4520] bg-tex-hammered bg-tile-96 ring-1 ring-black/85 inset-shadow-[0_2px_0_rgba(240,226,190,0.4)]"
// Recessed well cut into a plate.
WELL :: "bg-bitumen inset-shadow-[0_2px_5px_rgba(0,0,0,0.7)] ring-1 ring-black/90 shadow-[0_0_0_2px_rgba(205,179,124,0.4)]"
// Engraved interlace band cut into a plate rim (sits under a WELL, which covers its centre).
ENGRAVED :: "pointer-events-none absolute bg-bitumen/45 bg-tex-interlace bg-tile-10"

@(private)
rivet :: proc(cls: string, loc := #caller_location) {
	ui.el(ui.cx("pointer-events-none absolute size-[10px] rounded-full bg-radial from-[#e2cf9e] via-brass to-[#4a3618] ring-1 ring-black/70 shadow-[0_1px_1px_rgba(0,0,0,0.8)]", cls), loc = loc)
}

// The console: a low brass-and-bitumen band with two raised housings (map, commands) and the
// hero's portrait dome breaking its top edge, like the cast fittings of a basin.
@(private)
compose_console :: proc(w: f32) {
	if ui.div("absolute inset-x-0 bottom-0 flex h-[190px] items-end") {
		// the band
		if ui.div("absolute inset-x-0 bottom-0 h-[150px] pointer-events-auto shadow-[0_-8px_20px_rgba(0,0,0,0.6)]") {
			// cast frieze: an engraved interlace band between two dark grooves
			if ui.div(ui.cx("relative h-[30px]", PLATE)) {
				ui.el("pointer-events-none absolute inset-x-0 top-[6px] h-px bg-black/70")
				ui.el("pointer-events-none absolute inset-x-0 top-[7px] h-[16px] bg-bitumen/80 bg-tex-interlace bg-tile-28")
				ui.el("pointer-events-none absolute inset-x-0 top-[23px] h-px bg-black/70")
				ui.el("pointer-events-none absolute inset-x-0 top-[24px] h-px bg-brass-hi/40")
			}
			if ui.div("relative h-[120px] bg-linear-to-b from-[#1e1914] to-bitumen") {
				ui.el("pointer-events-none absolute inset-0 bg-brass-lo/25 bg-tex-khatam bg-tile-56")
				ui.el("pointer-events-none absolute inset-x-0 top-[6px] h-px bg-silver/55")
				ui.el("pointer-events-none absolute inset-x-0 top-[7px] h-px bg-black/60")
				ui.el("pointer-events-none absolute inset-x-0 bottom-[7px] h-px bg-silver/55")
				ui.el("pointer-events-none absolute inset-x-0 bottom-[6px] h-px bg-black/60")
			}
		}
		compose_minimap_housing()
		if ui.div("relative flex h-[150px] min-w-0 grow items-center gap-6 px-6 pt-[30px]") {
			compose_hero_plate(w)
			if w >= 1100 {
				compose_march_strip()
			}
		}
		compose_command_housing()
	}
}

// Cusped crest standing on a housing's top edge: a small pointed arch carrying a khatam star,
// so the console's skyline reads as cast fittings instead of three boxes.
@(private)
housing_crest :: proc(pos: string, loc := #caller_location) {
	if ui.div(ui.cx("pointer-events-none absolute -top-[26px] flex h-[34px] w-[70px] items-start justify-center rounded-t-[38px] corner-t-arch pt-[9px]", PLATE, pos), loc = loc) {
		ui.icon(vh.gi.khatam, "size-[14px] text-bitumen/80")
	}
}

@(private)
compose_minimap_housing :: proc() {
	if ui.div(ui.cx("relative h-[196px] w-[270px] shrink-0 rounded-tr-[44px] corner-tr-bevel p-[16px] pointer-events-auto shadow-[4px_0_10px_rgba(0,0,0,0.6)]", PLATE)) {
		// chamfer insets share one cut: r_in = r - d * (2 - sqrt(2))
		ui.el(ui.cx(ENGRAVED, "inset-[5px] rounded-tr-[41px] corner-tr-bevel"))
		housing_crest("left-[104px]")
		rivet("top-[4px] left-[4px]")
		rivet("bottom-[4px] left-[4px]")
		rivet("bottom-[4px] right-[4px]")
		rivet("top-[19px] right-[19px]")
		if ui.div(ui.cx("relative flex size-full flex-col gap-1.5 rounded-tr-[35px] corner-tr-bevel p-2", WELL)) {
			if ui.div("flex items-center justify-between px-1") {
				ui.text("Whispering March", "text-[13px] font-bold uppercase tracking-[0.12em] text-brass-hi")
				ui.text(app.camera_follow ? "Lock" : "Free", app.camera_follow ? "text-[13px] font-bold uppercase tracking-[0.12em] text-brass-hi" : "text-[13px] font-bold uppercase tracking-[0.12em] text-silver-dim")
			}
			// Map in a silver-lipped stadium roundel: the march is an 80x50 grid, so a circle
			// would crop the start and the goal at its ends.
			if ui.div("rounded-full bg-linear-to-b from-brass-hi via-brass to-brass-lo p-[3px] ring-1 ring-black/80") {
				ui.open("rounded-full bg-linear-to-b from-silver to-silver-dim p-[1.5px]")
				defer ui.close()
				if ui.div("relative h-[118px] w-full overflow-hidden rounded-full bg-[#18140e]") {
					vh.minimap_id = ui.current_id()
					ui.image(vh.minimap_img, "size-full")
					ui.canvas("absolute inset-0", draw_minimap_camera_canvas)
					ui.el("pointer-events-none absolute inset-0 rounded-full inset-shadow-[0_2px_8px_rgba(0,0,0,0.85)]")
				}
			}
		}
	}
}

@(private)
compose_command_housing :: proc() {
	if ui.div(ui.cx("relative h-[196px] w-[262px] shrink-0 rounded-tl-[44px] corner-tl-bevel p-[16px] pointer-events-auto shadow-[-4px_0_10px_rgba(0,0,0,0.6)]", PLATE)) {
		ui.el(ui.cx(ENGRAVED, "inset-[5px] rounded-tl-[41px] corner-tl-bevel"))
		housing_crest("right-[96px]")
		rivet("top-[4px] right-[4px]")
		rivet("bottom-[4px] right-[4px]")
		rivet("bottom-[4px] left-[4px]")
		rivet("top-[19px] left-[19px]")
		if ui.div(ui.cx("relative flex size-full flex-col items-center justify-center rounded-tl-[35px] corner-tl-bevel pt-2", WELL)) {
			compose_command_medallions()
		}
	}
}

@(private)
compose_hero_plate :: proc(w: f32) {
	idx, alive := g.game_player_index(&app.game)
	if ui.div("relative flex min-w-0 grow items-center gap-5") {
		selected := alive && app.game.units.selected[idx]
		// portrait dome: rises out of the band like a cast boss
		if ui.button_box("group relative -mt-[74px] shrink-0 self-start pointer-events-auto") {
			// pointed crown arch behind the dome (a mihrab-like halo), seated on the frieze
			ui.el(ui.cx("pointer-events-none absolute -top-[18px] left-1/2 h-[110px] w-[146px] -translate-x-1/2 rounded-t-[120px] corner-t-arch", PLATE))
			ui.el("pointer-events-none absolute -top-[13px] left-1/2 h-[104px] w-[136px] -translate-x-1/2 rounded-t-[114px] corner-t-arch bg-bitumen/45 bg-tex-interlace bg-tile-10")
			glow := selected ? "shadow-[0_0_16px_rgba(236,217,166,0.3),0_4px_8px_rgba(0,0,0,0.8)]" : "shadow-[0_4px_8px_rgba(0,0,0,0.8)]"
			if ui.div(ui.cx("relative mt-[4px] rounded-full p-[7px]", PLATE, glow)) {
				if ui.div(selected ? "rounded-full bg-linear-to-b from-inlay to-brass-lo p-[2px]" : "rounded-full bg-linear-to-b from-silver to-[#5d6166] p-[2px]") {
					if ui.div(alive ? "relative size-[112px] overflow-hidden rounded-full bg-radial from-[#3e5c96] via-lapis to-[#0a1226]" : "relative size-[112px] overflow-hidden rounded-full bg-radial from-[#4a3a30] to-bitumen-deep") {
						// Liiroy's own mesh, rendered live (hero_portrait.odin); greyed when he falls
						ui.image(vh.portrait_img, alive ? "size-full" : "size-full grayscale opacity-50")
						ui.el("pointer-events-none absolute inset-0 rounded-full inset-shadow-[0_-6px_12px_rgba(0,0,0,0.55)]")
											}
				}
			}
			rivet("top-[2px] left-1/2 -translate-x-1/2")
			if ui.clicked() {
				handle_hud_ui_msg(.Hud_Select_Hero)
			}
		}
		if ui.div("flex min-w-0 grow flex-col gap-2 pl-1") {
			if ui.div("flex min-w-0 items-baseline gap-3") {
				ui.text("Liiroy, the Bold", "shrink-0 font-display text-[22px] text-brass-hi text-shadow-[0_2px_0_rgba(0,0,0,0.85)]")
				ui.text("First Captain", "truncate text-[13px] font-bold text-silver-dim")
			}
			if !alive {
				ui.text("Has fallen in the Whispering March", "text-[13px] font-bold uppercase tracking-[0.12em] text-carnelian-hi")
				return
			}
			u := &app.game.units
			hp := u.hp[idx]
			hp_max := max(u.hp_max[idx], 1)
			pct := clamp(f32(hp) / f32(hp_max), 0, 1)
			// glass vial in a brass channel with end caps
			if ui.div("flex items-center gap-2") {
				if ui.div(ui.cx("relative flex h-[22px] max-w-[360px] grow items-center rounded-full px-[5px]", PLATE)) {
					if ui.div("relative h-[12px] grow overflow-hidden rounded-full bg-[#1a0806] inset-shadow-[0_2px_3px_rgba(0,0,0,0.9)]") {
						fill := pct <= 0.25 ? "h-full rounded-full bg-linear-to-b from-carnelian-hi from-0% via-carnelian via-35% to-[#3a0d09] animate-pulse transition-all duration-300" : "h-full rounded-full bg-linear-to-b from-carnelian-hi from-0% via-carnelian via-35% to-[#3a0d09] transition-all duration-300"
						ui.el(fill)
						ui.last_style().width = ui.pct(pct * 100)
						ui.el("pointer-events-none absolute inset-x-[6px] top-[2px] h-px bg-white/15")
						ui.el("pointer-events-none absolute inset-y-[2px] left-1/4 w-px bg-black/55")
						ui.el("pointer-events-none absolute inset-y-[2px] left-1/2 w-px bg-black/55")
						ui.el("pointer-events-none absolute inset-y-[2px] left-3/4 w-px bg-black/55")
					}
				}
				ui.text(fmt.tprintf("%d / %d", hp, hp_max), "shrink-0 text-[13px] font-extrabold tabular-nums text-silver text-shadow-[0_1px_0_rgba(0,0,0,0.9)]")
			}
			if ui.div("flex gap-5 whitespace-nowrap") {
				stat(vh.gi.attack, "Attack", fmt.tprintf("%d", g.unit_attack_damage(u, idx)))
				stat(vh.gi.stop, "Armour", fmt.tprintf("%d", g.unit_armor(u, idx)))
				regen := f32(g.HERO_REGEN_AMOUNT) * f32(g.TICKS_PER_SECOND) / f32(g.HERO_REGEN_INTERVAL_TICKS)
				stat(vh.gi.heart, "Regen", fmt.tprintf("+%.0f/s", regen))
			}
		}
	}
}

// The eight oath-stones of the march as a strip of khatam stars: kindled (brass), the next
// stone (gold inlay, the only actionable target) and the ones still in the fog.
@(private)
compose_march_strip :: proc() {
	wp := &app.game.waypoints
	if ui.div(ui.cx("relative flex w-[200px] shrink-0 flex-col gap-2 rounded-[10px] corner-bevel p-3", WELL)) {
		if ui.div("flex items-baseline justify-between") {
			ui.text("The March", "text-[13px] font-bold uppercase tracking-[0.12em] text-brass-hi")
			ui.text(fmt.tprintf("%d / %d", wp.current, wp.count), VALUE)
		}
		if ui.div("grid grid-cols-4 gap-x-2 gap-y-1.5") {
			for i in 0 ..< int(wp.count) {
				ui.push_id(i)
				cls := "size-[22px] text-brass-lo/60"
				if i < int(wp.current) {
					cls = "size-[22px] text-brass-hi"
				} else if i == int(wp.current) {
					cls = "size-[22px] text-inlay"
				}
				if ui.div(i == int(wp.current) ? "flex size-[34px] items-center justify-center rounded-full bg-radial from-[#3a2e1c] to-bitumen-deep ring-2 ring-brass-hi shadow-[0_0_10px_rgba(227,201,138,0.35)]" : "flex size-[34px] items-center justify-center rounded-full bg-bitumen-deep ring-1 ring-brass-lo/70 inset-shadow-[0_2px_3px_rgba(0,0,0,0.8)]") {
					ui.icon(vh.gi.khatam, cls)
				}
				ui.pop_id()
			}
		}
	}
}

@(private)
stat :: proc(icon: ui.Icon, label, value: string, loc := #caller_location) {
	if ui.div("flex items-center gap-1.5", loc = loc) {
		ui.icon(icon, "size-4 text-brass")
		ui.text(label, "text-[13px] font-bold uppercase tracking-[0.12em] text-silver-dim")
		ui.text(value, "text-[13px] font-extrabold tabular-nums text-silver")
	}
}

@(private)
compose_command_medallions :: proc() {
	gi := &vh.gi
	if ui.div("relative grid grid-cols-3 gap-x-1 gap-y-1.5") {
		_, alive := g.game_player_index(&app.game)
		order :: proc(alive, armed: bool) -> Medallion_State {
			return !alive ? .Disabled : (armed ? .Armed : .Idle)
		}
		if medallion(gi.move, "Move", "M", order(alive, app.command_mode == .Move)) {
			handle_hud_ui_msg(.Hud_Move)
		}
		if medallion(gi.attack, "Attack", "A", order(alive, app.command_mode == .Attack)) {
			handle_hud_ui_msg(.Hud_Attack)
		}
		if medallion(gi.patrol, "Patrol", "P", order(alive, app.command_mode == .Patrol)) {
			handle_hud_ui_msg(.Hud_Patrol)
		}
		if medallion(gi.stop, "Stop", "S", order(alive, false)) {
			handle_hud_ui_msg(.Hud_Stop)
		}
		if medallion(gi.helm, app.camera_follow ? "Follow" : "Free", "F", !alive ? .Disabled : (app.camera_follow ? .On : .Idle)) {
			handle_hud_ui_msg(.Hud_Toggle_Follow)
		}
		if medallion(gi.scroll, "Menu", "Esc", app.menu_open ? .On : .Idle) {
			app.menu_open = true
		}
	}
}

@(private)
compose_command_prompt :: proc() {
	if _, alive := g.game_player_index(&app.game); app.command_mode == .None || !alive || app.game.game_over || app.menu_open {
		return
	}
	verb, hint, dot: string
	switch app.command_mode {
	case .Move:
		verb, hint, dot = "Move", "Click a destination", "bg-brass-hi"
	case .Attack:
		verb, hint, dot = "Attack", "Click an enemy, or ground to attack-move", "bg-carnelian-hi"
	case .Patrol:
		verb, hint, dot = "Patrol", "Click the patrol endpoint", "bg-lapis-hi"
	case .None:
	}
	// seated on the frieze beside the portrait crown, over the hero's column
	if ui.div("absolute bottom-[146px] left-[448px]") {
		if ui.div(ui.cx("relative rounded-t-[14px] corner-t-bevel px-[6px] pt-[6px] shadow-[0_-4px_10px_rgba(0,0,0,0.6)]", PLATE)) {
			if ui.div(ui.cx("relative flex items-center gap-4 rounded-t-[10px] corner-t-bevel px-5 py-2 whitespace-nowrap", WELL)) {
				ui.el(ui.cx("size-2 rounded-full", dot))
				ui.text(verb, "font-display text-[22px] leading-none text-brass-hi")
				ui.text(hint, "text-[13px] font-bold text-silver")
				ui.text("Esc or right-click cancels", "text-[13px] font-bold text-silver-dim")
			}
		}
	}
}

@(private)
compose_campaign_banner :: proc() {
	if app.menu_open || app.game.game_over || app.game.level_complete {
		return
	}
	aggro_ticks, grace_active, charge_active := active_campaign_alert()
	if !grace_active && !charge_active {
		return
	}
	if ui.div("absolute top-[44px] left-1/2 w-[560px] max-w-[calc(100%-32px)] -translate-x-1/2") {
		if basin_panel("", "flex flex-col gap-2 px-5 py-3") {
			if ui.div("flex items-center gap-3") {
				ui.icon(vh.gi.khatam, grace_active ? "size-6 shrink-0 text-amber-alert" : "size-6 shrink-0 text-carnelian-hi")
				ui.text(grace_active ? "The challenge horn sounds" : "The Luk Soldier charges", "grow font-display text-[22px] leading-none text-brass-hi")
				if grace_active {
					ui.text(fmt.tprintf("%.1f s", f32(aggro_ticks) / f32(g.TICKS_PER_SECOND)), "shrink-0 whitespace-nowrap text-[13px] font-extrabold tabular-nums text-amber-alert")
				}
			}
			if grace_active {
				ui.text("A Luk Soldier has seen Liiroy. Strike first while he hesitates: press A or right-click him.", "text-[13px] font-bold text-silver")
				ratio := clamp(f32(aggro_ticks) / f32(g.ENEMY_AGGRO_DELAY_TICKS), 0, 1)
				if ui.div("h-2 rounded-full bg-bitumen-deep ring-1 ring-brass-lo") {
					ui.el("h-full rounded-full bg-linear-to-r from-[#9b6a1c] to-amber-alert")
					ui.last_style().width = ui.pct(ratio * 100)
				}
			} else {
				ui.text("Stand fast: Liiroy, the Bold meets the foe in battle.", "text-[13px] font-bold text-silver")
			}
		}
	}
}

@(private)
compose_outcome_banner :: proc() {
	if !app.game.game_over && !app.game.level_complete {
		return
	}
	won := app.game.level_complete
	if ui.div("absolute inset-x-0 top-[22%] flex justify-center") {
		if ui.div(ui.cx("w-[380px] rounded-t-[260px] corner-t-arch rounded-b-[10px] p-[5px] shadow-2xl shadow-black pointer-events-auto", BRASS_RIM)) {
			if ui.div("flex flex-col items-center gap-3 rounded-t-[255px] corner-t-arch rounded-b-[7px] bg-bitumen px-8 pt-24 pb-6 inset-shadow-sm inset-shadow-black") {
				ui.icon(vh.gi.khatam, won ? "size-10 text-brass-hi" : "size-10 text-carnelian-hi")
				ui.text(won ? "The Banner Is Reached" : "Liiroy Has Fallen", "text-center font-display text-[24px] font-bold text-brass-hi")
				ui.text(won ? "The Emir's seal crossed the Whispering March." : "The march is lost. Gather the vanguard and ride again.", "text-center text-[14px] font-bold text-silver")
				if plaque_button("Retry Level", won ? Tone.Lapis : Tone.Carnelian, "", icon_tex(.Reset), "mt-2 w-full") {
					retry_level()
				}
			}
		}
	}
}

@(private)
compose_selection_box :: proc() {
	if !app.dragging {
		return
	}
	mouse := input_mouse_pos()
	x0 := min(app.drag_start.x, mouse.x)
	y0 := min(app.drag_start.y, mouse.y)
	ui.el("absolute rounded-[2px] border border-brass-hi/90 bg-brass-hi/10")
	st := ui.last_style()
	st.inset = {ui.px(y0), {}, {}, ui.px(x0)}
	st.width = ui.px(abs(mouse.x - app.drag_start.x))
	st.height = ui.px(abs(mouse.y - app.drag_start.y))
}

// ---------------------------------------------------------------------------
// World-anchored overlays: nameplates, health, challenge countdown
// ---------------------------------------------------------------------------

compose_world_overlays :: proc(w, h: f32) {
	units := &app.game.units
	for i in 0 ..< g.MAX_UNITS {
		if !units.alive[i] || !g.enemy_is_visible(&app.game, i) {
			continue
		}
		hero := units.kind[i] == .Hero
		head := unit_ground(i) + rl.Vector3{0, hero ? 2.08 : 1.85, 0}
		screen := rl.GetWorldToScreen(head, app.camera)
		if screen.x < 0 || screen.x > w || screen.y < 0 || screen.y > h - HUD_HEIGHT {
			continue
		}
		ui.push_id(i)
		plate_w: f32 = hero ? 120 : 100
		if ui.div("absolute flex flex-col items-center gap-1") {
			st := ui.style()
			st.inset = {ui.px(screen.y - 10), {}, {}, ui.px(screen.x - plate_w / 2)}
			st.width = ui.px(plate_w)
			enemy := units.team[i] == .Enemy
			if enemy && units.discovered[i] && units.aggro_timer[i] > 0 {
				secs := f32(units.aggro_timer[i]) / f32(g.TICKS_PER_SECOND)
				ui.text(fmt.tprintf("Spotted %.1fs", secs), "rounded-full bg-bitumen/90 px-2 text-[12px] font-extrabold tabular-nums text-amber-alert ring-1 ring-amber-alert/70")
			}
			ui.text(hero ? "Liiroy, the Bold" : "Luk Soldier", hero ? "text-[13px] font-extrabold whitespace-nowrap text-brass-hi text-shadow-sm text-shadow-black" : "text-[12px] font-bold whitespace-nowrap text-[#e6c9bf] text-shadow-sm text-shadow-black")
			pct := clamp(f32(units.hp[i]) / f32(max(units.hp_max[i], 1)), 0, 1)
			if ui.div(hero ? "h-[7px] w-[46px] rounded-full bg-bitumen-deep p-px ring-1 ring-brass" : "h-[6px] w-[32px] rounded-full bg-bitumen-deep p-px ring-1 ring-brass-lo") {
				fill := enemy ? "h-full rounded-full bg-carnelian-hi" : (pct <= 0.25 ? "h-full rounded-full bg-[#c25a46]" : "h-full rounded-full bg-linear-to-b from-carnelian-hi to-carnelian")
				ui.el(fill)
				ui.last_style().width = ui.pct(pct * 100)
			}
		}
		ui.pop_id()
	}
}

// ---------------------------------------------------------------------------
// Pause menu and F1 shortcut window
// ---------------------------------------------------------------------------

compose_pause_menu :: proc() {
	if ui.button_box("absolute inset-0 flex items-center justify-center bg-black/60 cursor-default pointer-events-auto") {
		if ui.clicked_self() {
			handle_hud_ui_msg(.Pause_Resume)
		}
		if ui.div(ui.cx("w-[380px] rounded-t-[300px] corner-t-arch rounded-b-[12px] p-[5px] shadow-2xl shadow-black", BRASS_RIM)) {
			if ui.div("relative flex flex-col gap-3 rounded-t-[295px] corner-t-arch rounded-b-[9px] bg-bitumen px-7 pt-28 pb-6 inset-shadow-sm inset-shadow-black") {
				ui.el("pointer-events-none absolute inset-0 rounded-t-[295px] corner-t-arch rounded-b-[9px] bg-brass-lo/20 bg-tex-khatam bg-tile-32")
				ui.open("relative flex flex-col gap-3")
				defer ui.close()
				ui.text("Paused", "text-center font-decorative text-[28px] font-bold text-brass-hi")
				ui.text("The march waits for your word.", "mb-2 text-center text-[13px] font-bold text-silver-dim")
				if plaque_button("Resume Battle", .Inlay, "Esc", icon_tex(.Game)) {
					handle_hud_ui_msg(.Pause_Resume)
				}
				if plaque_button("Model Editor", .Lapis, "", icon_tex(.Models)) {
					handle_hud_ui_msg(.Pause_Editor)
				}
				if plaque_button("Retry Level", .Carnelian, "", icon_tex(.Reset)) {
					handle_hud_ui_msg(.Pause_Retry)
				}
				if ui.div("mt-1 flex items-center justify-center gap-2") {
					keycap("F1")
					ui.text("Shortcuts for every screen", "text-[13px] font-bold text-silver-dim")
				}
			}
		}
	}
}

compose_help_window :: proc(w, h: f32) {
	sheet := help_sheet_for_view(active_help_view())
	cols := len(sheet.groups) >= 2 ? 2 : 1
	if ui.button_box("absolute inset-0 flex items-center justify-center bg-black/65 cursor-default pointer-events-auto") {
		if ui.clicked_self() {
			handle_hud_ui_msg(.Help_Close)
		}
		width := cols == 2 ? "w-[900px]" : "w-[600px]"
		if basin_panel(ui.cx(width, "max-w-[calc(100%-32px)] max-h-[calc(100%-32px)]"), "flex max-h-[calc(100vh-48px)] flex-col gap-4 p-6") {
			if ui.div("flex items-center gap-3") {
				ui.el(ui.cx("size-6 shrink-0 bg-brass-hi", icon_tex(sheet.icon)))
				ui.text(fmt.tprintf("%s shortcuts", sheet.heading), "grow font-display text-[20px] font-bold text-brass-hi")
				ui.text(string(sheet.badge), "rounded-full bg-lapis-lo px-3 py-0.5 text-[12px] font-extrabold uppercase tracking-wider text-silver ring-1 ring-brass")
				if chip_button("Close", false, extra = "h-7") {
					handle_hud_ui_msg(.Help_Close)
				}
			}
			if ui.div(cols == 2 ? "grid grid-cols-2 gap-x-8 gap-y-4 overflow-y-auto" : "grid grid-cols-1 gap-4 overflow-y-auto") {
				for grp, gi in sheet.groups {
					ui.push_id(gi)
					if ui.div("flex flex-col gap-2 border-t border-brass-lo/70 pt-3") {
						if len(sheet.groups) > 1 {
							ui.text(string(grp.title), "text-[13px] font-bold uppercase tracking-[0.12em] text-brass-hi")
						}
						for it, ii in grp.items {
							ui.push_id(ii)
							if ui.div("flex items-center gap-3") {
								if ui.div("flex w-[150px] shrink-0") {
									keycap(string(it.keys))
								}
								ui.text(string(it.desc), "text-[13px] font-bold text-silver")
							}
							ui.pop_id()
						}
					}
					ui.pop_id()
				}
			}
			if len(sheet.groups) > 1 {
				ui.text("F1 opens this window on every screen.", "text-[13px] font-bold text-silver-dim")
			}
		}
	}
}

// Camera footprint drawn over the minimap image (VUI canvas, logical px).
@(private)
draw_minimap_camera_canvas :: proc(ctx: ^ui.Context, r: ui.Rect, _: rawptr) {
	rect := rl.Rectangle{r.x, r.y, r.w, r.h}
	w := f32(rl.GetScreenWidth())
	h := max(f32(rl.GetScreenHeight()) - HUD_HEIGHT, 1)
	corners := [4]rl.Vector2{{0, 0}, {w, 0}, {w, h}, {0, h}}
	pts: [4]rl.Vector2
	for sc, i in corners {
		p, ok := screen_to_world_ground(sc)
		if !ok {
			return
		}
		pts[i] = world_to_minimap(p, rect)
	}
	col := ui.rgb(0xcdb37c, 0.7)
	for i in 0 ..< 4 {
		if a, b, ok := clip_segment_rect(pts[i], pts[(i + 1) % 4], rect); ok {
			ui.draw_line(ctx, a, b, col, 1)
		}
	}
}
