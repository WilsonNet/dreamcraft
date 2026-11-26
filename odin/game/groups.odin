// StarCraft-style selection modifiers, control groups (1..0), and per-unit order queues.
// Zero allocations; all state lives in fixed arrays on Units.
package game

Group_Op :: enum u8 {
	Assign,
	Add,
	Steal_Assign,
	Steal_Add,
	Recall,
}

unit_deselect :: proc(units: ^Units, index: int) {
	if index < 0 || index >= MAX_UNITS || !units.alive[index] {
		return
	}
	if units.selected[index] {
		units.selected[index] = false
		units.selected_count -= 1
	}
}

unit_toggle_select :: proc(units: ^Units, index: int) {
	assert(units.alive[index], "toggling dead unit")
	if units.selected[index] {
		unit_deselect(units, index)
	} else {
		unit_select(units, index, true)
	}
}

unit_select_kind_only :: proc(units: ^Units, kind: Unit_Kind) -> int {
	count := 0
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.selected[i] {
			if units.kind[i] == kind {
				count += 1
			} else {
				unit_deselect(units, i)
			}
		}
	}
	return count
}

unit_deselect_kind :: proc(units: ^Units, kind: Unit_Kind) -> int {
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.selected[i] && units.kind[i] == kind {
			unit_deselect(units, i)
		}
	}
	return units.selected_count
}

unit_select_all_player :: proc(units: ^Units) -> int {
	unit_clear_selection(units)
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player {
			unit_select(units, i, true)
		}
	}
	return units.selected_count
}

group_apply :: proc(units: ^Units, slot: int, op: Group_Op) -> int {
	if slot < 0 || slot >= CONTROL_GROUP_COUNT {
		return 0
	}
	bit := u16(1) << u16(slot)
	switch op {
	case .Assign:
		return group_assign(units, bit)
	case .Add:
		return group_add(units, bit)
	case .Steal_Assign:
		return group_steal_assign(units, bit)
	case .Steal_Add:
		return group_steal_add(units, bit)
	case .Recall:
		return group_recall(units, slot, bit)
	}
	return 0
}

@(private)
group_assign :: proc(units: ^Units, bit: u16) -> int {
	if unit_selected_player_count(units) == 0 {
		return 0
	}
	count := 0
	for i in 0..<MAX_UNITS {
		units.group_mask[i] &~= bit
		if units.alive[i] && units.team[i] == .Player && units.selected[i] {
			units.group_mask[i] |= bit
			count += 1
		}
	}
	return count
}

@(private)
group_add :: proc(units: ^Units, bit: u16) -> int {
	count := 0
	for i in 0..<MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		if units.selected[i] {
			units.group_mask[i] |= bit
		}
		if (units.group_mask[i] & bit) != 0 {
			count += 1
		}
	}
	return count
}

@(private)
group_steal_assign :: proc(units: ^Units, bit: u16) -> int {
	if unit_selected_player_count(units) == 0 {
		return 0
	}
	count := 0
	for i in 0..<MAX_UNITS {
		units.group_mask[i] &~= bit
		if units.alive[i] && units.team[i] == .Player && units.selected[i] {
			units.group_mask[i] = bit
			count += 1
		}
	}
	return count
}

@(private)
group_steal_add :: proc(units: ^Units, bit: u16) -> int {
	count := 0
	for i in 0..<MAX_UNITS {
		if !units.alive[i] || units.team[i] != .Player {
			continue
		}
		if units.selected[i] {
			units.group_mask[i] = bit
		}
		if (units.group_mask[i] & bit) != 0 {
			count += 1
		}
	}
	return count
}

@(private)
group_recall :: proc(units: ^Units, slot: int, bit: u16) -> int {
	if group_member_count(units, slot) == 0 {
		return 0
	}
	unit_clear_selection(units)
	count := 0
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && (units.group_mask[i] & bit) != 0 {
			unit_select(units, i, true)
			count += 1
		}
	}
	return count
}

group_member_count :: proc(units: ^Units, slot: int) -> int {
	if slot < 0 || slot >= CONTROL_GROUP_COUNT {
		return 0
	}
	bit := u16(1) << u16(slot)
	count := 0
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && (units.group_mask[i] & bit) != 0 {
			count += 1
		}
	}
	return count
}

group_has_hero :: proc(units: ^Units, slot: int) -> bool {
	if slot < 0 || slot >= CONTROL_GROUP_COUNT {
		return false
	}
	bit := u16(1) << u16(slot)
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && units.kind[i] == .Hero && (units.group_mask[i] & bit) != 0 {
			return true
		}
	}
	return false
}

group_centroid :: proc(units: ^Units, slot: int) -> (Fixed_Vec, bool) {
	if slot < 0 || slot >= CONTROL_GROUP_COUNT {
		return {}, false
	}
	bit := u16(1) << u16(slot)
	sum_x, sum_y: i64
	count: i64
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && (units.group_mask[i] & bit) != 0 {
			sum_x += i64(units.world[i].x)
			sum_y += i64(units.world[i].y)
			count += 1
		}
	}
	if count == 0 {
		return {}, false
	}
	return Fixed_Vec{x = Fp(sum_x / count), y = Fp(sum_y / count)}, true
}

selection_centroid :: proc(units: ^Units) -> (Fixed_Vec, bool) {
	sum_x, sum_y: i64
	count: i64
	for i in 0..<MAX_UNITS {
		if units.alive[i] && units.team[i] == .Player && units.selected[i] {
			sum_x += i64(units.world[i].x)
			sum_y += i64(units.world[i].y)
			count += 1
		}
	}
	if count == 0 {
		return {}, false
	}
	return Fixed_Vec{x = Fp(sum_x / count), y = Fp(sum_y / count)}, true
}

unit_clear_orders :: proc(units: ^Units, index: int) {
	units.order_count[index] = 0
}

unit_push_order :: proc(units: ^Units, index: int, order: Unit_Order) -> bool {
	count := int(units.order_count[index])
	if count >= MAX_UNIT_ORDERS {
		return false
	}
	units.order_queue[index][count] = order
	units.order_count[index] = u8(count + 1)
	return true
}

unit_pop_order :: proc(units: ^Units, index: int) -> (order: Unit_Order, ok: bool) {
	count := int(units.order_count[index])
	if count <= 0 {
		return {}, false
	}
	order = units.order_queue[index][0]
	for i in 1..<count {
		units.order_queue[index][i - 1] = units.order_queue[index][i]
	}
	units.order_count[index] = u8(count - 1)
	return order, true
}

unit_is_idle_for_queue :: proc(units: ^Units, index: int) -> bool {
	return units.state[index] == .Idle &&
		!unit_has_path(units, index) &&
		!handle_is_valid(units.attack_target[index])
}
