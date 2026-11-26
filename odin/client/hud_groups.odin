// StarCraft-style multi-unit selection grid, subgroup pills, control group tabs,
// and first-quest rescue tutorial banner in the Saint Louis Basin aesthetic.
package main

import "core:fmt"
import ui "vinland:vui"
import g "../game"

@(private)
GROUP_LABELS := [g.CONTROL_GROUP_COUNT]string{
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}

compose_control_group_bar :: proc() -> bool {
	if app.menu_open || app.game.game_over || app.game.level_complete {
		return false
	}
	units := &app.game.units
	bound_count := 0
	for slot in 0..<g.CONTROL_GROUP_COUNT {
		if g.group_member_count(units, slot) > 0 {
			bound_count += 1
		}
	}
	player_count := g.unit_team_count(units, .Player)
	if bound_count == 0 && player_count <= 1 {
		return false
	}
	if ui.div("absolute bottom-[150px] left-[448px] flex items-center gap-1.5") {
		if bound_count == 0 {
			if ui.div(ui.cx("rounded-t-[10px] corner-t-bevel px-[4px] pt-[4px] shadow-[0_-2px_8px_rgba(0,0,0,0.6)]", PLATE)) {
				if ui.div(ui.cx("flex items-center gap-2 rounded-t-[7px] corner-t-bevel px-3 py-1", WELL)) {
					ui.icon(vh.gi.khatam, "size-3.5 text-brass-hi")
					ui.text("Ctrl+1..9 bind group · Shift+1..9 add · Alt+1..9 steal · Tab cycle", "text-[12px] font-bold text-silver")
				}
			}
			return true
		}
		for slot in 0..<g.CONTROL_GROUP_COUNT {
			count := g.group_member_count(units, slot)
			if count == 0 {
				continue
			}
			ui.push_id(slot)
			compose_group_tab(slot, count, unit_matches_group(units, slot))
			ui.pop_id()
		}
	}
	return true
}

@(private)
compose_group_tab :: proc(slot, count: int, active: bool) {
	plate_cls := active ? "bg-linear-to-b from-[#e6d2a2] via-brass-hi to-brass-lo ring-1 ring-black/85 shadow-[0_-2px_10px_rgba(236,217,166,0.35)]" : ui.cx("ring-1 ring-black/85", PLATE)
	well_cls := active ? "bg-linear-to-b from-lapis-hi to-lapis-lo ring-1 ring-brass-hi" : "bg-bitumen hover:bg-bitumen-raised ring-1 ring-brass-lo/70"
	if ui.button_box(ui.cx("pointer-events-auto rounded-t-[9px] corner-t-bevel px-[3px] pt-[3px]", plate_cls)) {
		if ui.div(ui.cx("flex items-center gap-1.5 rounded-t-[6px] corner-t-bevel px-2.5 py-1", well_cls)) {
			keycap(GROUP_LABELS[slot])
			ui.text(fmt.tprintf("x%d", count), active ? "text-[12px] font-extrabold tabular-nums text-inlay" : "text-[12px] font-extrabold tabular-nums text-silver")
		}
		if ui.clicked() {
			handle_group_tab_click(slot)
		}
	}
}

compose_selection_panel :: proc(w: f32) {
	idx, alive := primary_display_unit()
	sel_count := g.unit_selected_player_count(&app.game.units)
	if sel_count <= 1 {
		if !alive || app.game.units.kind[idx] == .Hero {
			compose_hero_plate(w)
		} else {
			compose_single_unit_plate(idx)
		}
		return
	}
	compose_multi_selection_plate(idx, sel_count)
}

@(private)
compose_single_unit_plate :: proc(idx: int) {
	u := &app.game.units
	if ui.div("relative flex min-w-0 grow items-center gap-5") {
		compose_portrait_dome(true, u.selected[idx])
		if ui.div("flex min-w-0 grow flex-col gap-2 pl-1") {
			if ui.div("flex min-w-0 items-baseline gap-3") {
				ui.text("Luk Soldier", "shrink-0 font-display text-[22px] text-brass-hi text-shadow-[0_2px_0_rgba(0,0,0,0.85)]")
				ui.text("Vanguard Trooper", "truncate text-[13px] font-bold text-silver-dim")
			}
			compose_hp_vial(u.hp[idx], u.hp_max[idx])
			if ui.div("flex gap-5 whitespace-nowrap") {
				stat(vh.gi.attack, "Attack", fmt.tprintf("%d", g.unit_attack_damage(u, idx)))
				stat(vh.gi.stop, "Armour", fmt.tprintf("%d", g.unit_armor(u, idx)))
			}
		}
	}
}

@(private)
compose_multi_selection_plate :: proc(lead_idx, sel_count: int) {
	u := &app.game.units
	if ui.div("relative flex min-w-0 grow items-center gap-4") {
		compose_portrait_dome(true, true)
		if ui.div("flex min-w-0 grow flex-col gap-1.5 pl-1") {
			compose_subgroup_header(u, lead_idx, sel_count)
			compose_selection_wireframe_grid(u)
		}
	}
}

@(private)
compose_portrait_dome :: proc(alive, selected: bool) {
	if ui.button_box("group relative -mt-[74px] shrink-0 self-start pointer-events-auto") {
		ui.el(ui.cx("pointer-events-none absolute -top-[18px] left-1/2 h-[110px] w-[146px] -translate-x-1/2 rounded-t-[120px] corner-t-arch", PLATE))
		ui.el("pointer-events-none absolute -top-[13px] left-1/2 h-[104px] w-[136px] -translate-x-1/2 rounded-t-[114px] corner-t-arch bg-bitumen/45 bg-tex-interlace bg-tile-10")
		glow := selected ? "shadow-[0_0_16px_rgba(236,217,166,0.3),0_4px_8px_rgba(0,0,0,0.8)]" : "shadow-[0_4px_8px_rgba(0,0,0,0.8)]"
		if ui.div(ui.cx("relative mt-[4px] rounded-full p-[7px]", PLATE, glow)) {
			if ui.div(selected ? "rounded-full bg-linear-to-b from-inlay to-brass-lo p-[2px]" : "rounded-full bg-linear-to-b from-silver to-[#5d6166] p-[2px]") {
				if ui.div(alive ? "relative size-[112px] overflow-hidden rounded-full bg-radial from-[#3e5c96] via-lapis to-[#0a1226]" : "relative size-[112px] overflow-hidden rounded-full bg-radial from-[#4a3a30] to-bitumen-deep") {
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
}

@(private)
compose_hp_vial :: proc(hp, hp_max_raw: u16) {
	hp_max := max(hp_max_raw, 1)
	pct := clamp(f32(hp) / f32(hp_max), 0, 1)
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
}

@(private)
compose_subgroup_header :: proc(u: ^g.Units, lead_idx, sel_count: int) {
	heroes := selected_kind_count(u, .Hero)
	melees := selected_kind_count(u, .Melee)
	if ui.div("flex min-w-0 items-center gap-2 whitespace-nowrap") {
		if heroes > 0 && melees > 0 {
			if chip_button(fmt.tprintf("Liiroy (%d)", heroes), app.active_subgroup == .Hero, extra = "h-6 pointer-events-auto") {
				app.active_subgroup = .Hero
			}
			if chip_button(fmt.tprintf("Soldiers (%d)", melees), app.active_subgroup == .Melee, extra = "h-6 pointer-events-auto") {
				app.active_subgroup = .Melee
			}
			keycap("Tab")
		} else {
			name := g.unit_kind_name(u.kind[lead_idx])
			ui.text(fmt.tprintf("%s x%d", name, sel_count), "font-display text-[18px] leading-none text-brass-hi")
		}
	}
}

@(private)
compose_selection_wireframe_grid :: proc(u: ^g.Units) {
	if ui.div("flex flex-wrap gap-1.5") {
		shown := 0
		for i in 0..<g.MAX_UNITS {
			if !u.alive[i] || u.team[i] != .Player || !u.selected[i] {
				continue
			}
			if shown >= 16 {
				break
			}
			ui.push_id(i)
			compose_selection_card(u, i)
			ui.pop_id()
			shown += 1
		}
	}
}

@(private)
compose_selection_card :: proc(u: ^g.Units, idx: int) {
	is_sub := u.kind[idx] == app.active_subgroup
	is_hero := u.kind[idx] == .Hero
	ring := is_sub ? "ring-2 ring-inlay bg-linear-to-b from-[#2b3f69] to-[#121b30]" : "ring-1 ring-brass-lo bg-bitumen-deep hover:ring-brass"
	if ui.button_box(ui.cx("flex h-[40px] w-[36px] flex-col items-center justify-between rounded-[5px] corner-bevel p-1 pointer-events-auto", ring)) {
		ui.icon(is_hero ? vh.gi.khatam : vh.gi.helm, is_hero ? "size-4 text-inlay" : "size-4 text-silver")
		pct := clamp(f32(u.hp[idx]) / f32(max(u.hp_max[idx], 1)), 0, 1)
		bar_cls := pct > 0.5 ? "h-full rounded-full bg-[#52c97a]" : (pct > 0.25 ? "h-full rounded-full bg-amber-alert" : "h-full rounded-full bg-carnelian-hi")
		if ui.div("h-[5px] w-full overflow-hidden rounded-full bg-black/80 ring-1 ring-black") {
			ui.el(bar_cls)
			ui.last_style().width = ui.pct(pct * 100)
		}
		if ui.clicked() {
			handle_selection_card_click(idx)
		}
	}
}

compose_rescue_banner :: proc() {
	if app.game.last_rescue_tick == 0 || app.game.tick < app.game.last_rescue_tick {
		return
	}
	if app.game.tick - app.game.last_rescue_tick >= 420 {
		return
	}
	first_squad := app.game.rescued_count <= 3
	title := first_squad ? fmt.tprintf("Vanguard Survivors Rally (+%d)", app.game.last_rescue_batch) : fmt.tprintf("Bridge Watch Joins the March (+%d)", app.game.last_rescue_batch)
	hint := first_squad ? "Drag box or Shift+Click to select, Ctrl+Click same type, Ctrl+1 to bind Group 1, Shift+RMB to queue." : "Shift+1 adds them to Group 1, Alt+2 steals into Group 2, Tab cycles unit types, F2 selects all."
	if ui.div("absolute top-[44px] left-1/2 w-[620px] max-w-[calc(100%-32px)] -translate-x-1/2") {
		if basin_panel("", "flex flex-col gap-1.5 px-5 py-3") {
			if ui.div("flex items-center gap-3") {
				ui.icon(vh.gi.khatam, "size-6 shrink-0 text-[#48e0a8]")
				ui.text(title, "grow font-display text-[22px] leading-none text-brass-hi")
				ui.text(fmt.tprintf("%d Soldiers", app.game.rescued_count), "shrink-0 text-[13px] font-extrabold text-[#48e0a8]")
			}
			ui.text(hint, "text-[13px] font-bold text-silver")
		}
	}
}
