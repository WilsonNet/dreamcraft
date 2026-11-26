// StarCraft-style selection modifiers, double-click type select, control groups (1..0),
// subgroup Tab cycling, and F2 select-all-army for the native client.
package main

import rl "../gfx"
import g "../game"

DOUBLE_CLICK_WINDOW :: f64(0.35)

@(private)
GROUP_HOTKEYS := [g.CONTROL_GROUP_COUNT]rl.KeyboardKey{
	.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE, .ZERO,
}

input_shift_down :: proc() -> bool {
	return rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
}

input_ctrl_down :: proc() -> bool {
	return rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) ||
		rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
}

input_alt_down :: proc() -> bool {
	return rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
}

handle_control_group_keys :: proc() {
	if rl.IsKeyPressed(.F2) {
		_ = g.unit_select_all_player(&app.game.units)
		sync_active_subgroup()
		app.command_mode = .None
		app.dragging = false
	}
	if rl.IsKeyPressed(.TAB) {
		cycle_active_subgroup(input_shift_down())
	}
	for key, slot in GROUP_HOTKEYS {
		if rl.IsKeyPressed(key) {
			apply_group_hotkey(slot)
		}
	}
}

@(private)
apply_group_hotkey :: proc(slot: int) {
	units := &app.game.units
	alt := input_alt_down()
	ctrl := input_ctrl_down()
	shift := input_shift_down()
	if alt && shift {
		_ = g.group_apply(units, slot, .Steal_Add)
		return
	}
	if alt {
		_ = g.group_apply(units, slot, .Steal_Assign)
		return
	}
	if ctrl {
		_ = g.group_apply(units, slot, .Assign)
		return
	}
	if shift {
		_ = g.group_apply(units, slot, .Add)
		return
	}
	recall_group_with_double_tap(slot)
}

@(private)
recall_group_with_double_tap :: proc(slot: int) {
	count := g.group_apply(&app.game.units, slot, .Recall)
	if count == 0 {
		return
	}
	sync_active_subgroup()
	now := rl.GetTime()
	if app.last_group_tap_slot == slot && (now - app.last_group_tap_time) <= DOUBLE_CLICK_WINDOW {
		if c, ok := g.group_centroid(&app.game.units, slot); ok {
			center_camera_on_fixed(c)
		}
	}
	app.last_group_tap_slot = slot
	app.last_group_tap_time = now
}

select_click_starcraft :: proc(mouse: rl.Vector2) {
	units := &app.game.units
	shift := input_shift_down()
	ctrl := input_ctrl_down()
	index, ok := unit_at_screen(mouse, .Player)
	now := rl.GetTime()
	if !ok {
		app.last_click_unit = g.INVALID_HANDLE
		app.last_click_time = now
		if !shift {
			g.unit_clear_selection(units)
			sync_active_subgroup()
		}
		return
	}
	handle := g.unit_handle(units, index)
	is_double := app.last_click_unit == handle && (now - app.last_click_time) <= DOUBLE_CLICK_WINDOW
	app.last_click_unit = handle
	app.last_click_time = now

	if ctrl || is_double {
		select_kind_on_screen(units.kind[index], shift)
	} else if shift {
		g.unit_toggle_select(units, index)
	} else {
		g.unit_select_only(units, index)
	}
	sync_active_subgroup()
}

select_box_starcraft :: proc(start, finish: rl.Vector2) {
	min_x, max_x := min(start.x, finish.x), max(start.x, finish.x)
	min_y, max_y := min(start.y, finish.y), max(start.y, finish.y)
	units := &app.game.units
	if !input_shift_down() {
		g.unit_clear_selection(units)
	}
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		point := rl.GetWorldToScreen(unit_ground(i) + rl.Vector3{0, 0.9, 0}, app.camera)
		if point.x >= min_x && point.x <= max_x && point.y >= min_y && point.y <= max_y {
			g.unit_select(units, i, true)
		}
	}
	sync_active_subgroup()
}

@(private)
select_kind_on_screen :: proc(kind: g.Unit_Kind, additive: bool) {
	units := &app.game.units
	w := f32(rl.GetScreenWidth())
	h := max(f32(rl.GetScreenHeight()) - HUD_HEIGHT, 1)
	matches: [g.MAX_UNITS]int
	match_count := 0
	all_selected := true
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player || units.kind[i] != kind {
			continue
		}
		pt := rl.GetWorldToScreen(unit_ground(i) + rl.Vector3{0, 0.9, 0}, app.camera)
		if pt.x >= 0 && pt.x <= w && pt.y >= 0 && pt.y <= h {
			matches[match_count] = i
			match_count += 1
			if !units.selected[i] {
				all_selected = false
			}
		}
	}
	if !additive {
		g.unit_clear_selection(units)
	}
	for idx in matches[:match_count] {
		if additive && all_selected {
			g.unit_deselect(units, idx)
		} else {
			g.unit_select(units, idx, true)
		}
	}
}

handle_selection_card_click :: proc(index: int) {
	units := &app.game.units
	if index < 0 || index >= g.MAX_UNITS || !units.alive[index] || units.team[index] != .Player {
		return
	}
	ctrl := input_ctrl_down()
	shift := input_shift_down()
	kind := units.kind[index]
	if ctrl && shift {
		_ = g.unit_deselect_kind(units, kind)
	} else if ctrl {
		_ = g.unit_select_kind_only(units, kind)
	} else if shift {
		g.unit_deselect(units, index)
	} else {
		g.unit_select_only(units, index)
	}
	sync_active_subgroup()
}

handle_group_tab_click :: proc(slot: int) {
	apply_group_hotkey(slot)
}

sync_active_subgroup :: proc() {
	units := &app.game.units
	if g.unit_selected_player_count(units) == 0 {
		app.active_subgroup = .Hero
		return
	}
	has_hero := false
	has_melee := false
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player || !units.selected[i] {
			continue
		}
		if units.kind[i] == app.active_subgroup {
			return
		}
		if units.kind[i] == .Hero {
			has_hero = true
		} else {
			has_melee = true
		}
	}
	app.active_subgroup = has_hero ? .Hero : (has_melee ? .Melee : .Hero)
}

cycle_active_subgroup :: proc(reverse: bool) {
	units := &app.game.units
	kinds: [2]g.Unit_Kind
	count := 0
	for k in ([2]g.Unit_Kind{.Hero, .Melee}) {
		if selected_kind_count(units, k) > 0 {
			kinds[count] = k
			count += 1
		}
	}
	if count <= 1 {
		sync_active_subgroup()
		return
	}
	pos := 0
	for i in 0..<count {
		if kinds[i] == app.active_subgroup {
			pos = i
			break
		}
	}
	step := reverse ? count - 1 : 1
	app.active_subgroup = kinds[(pos + step) % count]
}

selected_kind_count :: proc(units: ^g.Units, kind: g.Unit_Kind) -> int {
	count := 0
	for i in 0..<g.MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && units.selected[i] && units.kind[i] == kind {
			count += 1
		}
	}
	return count
}

primary_display_unit :: proc() -> (index: int, ok: bool) {
	units := &app.game.units
	fallback := -1
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player || !units.selected[i] {
			continue
		}
		if units.kind[i] == app.active_subgroup {
			return i, true
		}
		if fallback < 0 {
			fallback = i
		}
	}
	if fallback >= 0 {
		return fallback, true
	}
	return g.game_player_index(&app.game)
}

unit_matches_group :: proc(units: ^g.Units, slot: int) -> bool {
	if slot < 0 || slot >= g.CONTROL_GROUP_COUNT || units.selected_count == 0 {
		return false
	}
	bit := u16(1) << u16(slot)
	matched := 0
	for i in 0..<g.MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		in_group := (units.group_mask[i] & bit) != 0
		if in_group != units.selected[i] {
			return false
		}
		if in_group {
			matched += 1
		}
	}
	return matched > 0
}

center_camera_on_fixed :: proc(pos: g.Fixed_Vec) {
	app.camera_target = clamp_camera_target(world_to_3d(pos))
	app.camera_target.y = CAMERA_TARGET_HEIGHT
	app.camera_follow = false
	app.camera_vel = {}
	apply_camera()
}
