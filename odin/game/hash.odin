// Stable FNV-1a state hash used by determinism tests and headless diagnostics.
package game

State_Hash :: u64

FNV_OFFSET :: u64(0xcbf29ce484222325)
FNV_PRIME :: u64(0x100000001b3)

Hash_Builder :: struct {
	value: u64,
}

hash_init :: proc() -> Hash_Builder {
	return Hash_Builder{value = FNV_OFFSET}
}

hash_byte :: proc(h: ^Hash_Builder, byte: u8) {
	h.value ~= u64(byte)
	h.value *= FNV_PRIME
}

hash_u16 :: proc(h: ^Hash_Builder, value: u16) {
	hash_byte(h, u8(value))
	hash_byte(h, u8(value >> 8))
}

hash_u32 :: proc(h: ^Hash_Builder, value: u32) {
	for shift in 0..<4 {
		hash_byte(h, u8(value >> u32(shift * 8)))
	}
}

hash_u64 :: proc(h: ^Hash_Builder, value: u64) {
	for shift in 0..<8 {
		hash_byte(h, u8(value >> u32(shift * 8)))
	}
}

hash_i32 :: proc(h: ^Hash_Builder, value: i32) {
	hash_u32(h, u32(value))
}

hash_bool :: proc(h: ^Hash_Builder, value: bool) {
	hash_byte(h, value ? 1 : 0)
}

hash_bits :: proc(h: ^Hash_Builder, bits: ^Bit_Grid) {
	for word in bits.words {
		hash_u64(h, word)
	}
}

game_hash :: proc(game: ^Game) -> State_Hash {
	h := hash_init()
	hash_u64(&h, game.tick)
	hash_bool(&h, game.level_complete)
	hash_bool(&h, game.game_over)
	hash_bits(&h, &game.grid.obstacles)
	hash_u16(&h, game.grid.obstacle_count)
	hash_bits(&h, &game.fog.explored)
	hash_bits(&h, &game.fog.visible)
	hash_waypoints(&h, &game.waypoints)
	hash_commands(&h, &game.commands)
	hash_units(&h, &game.units)
	return State_Hash(h.value)
}

hash_waypoints :: proc(h: ^Hash_Builder, waypoints: ^Waypoints) {
	hash_u32(h, u32(waypoints.count))
	hash_u32(h, u32(waypoints.current))
	for i in 0..<waypoints.count {
		hash_i32(h, waypoints.points[i].x)
		hash_i32(h, waypoints.points[i].y)
	}
}

hash_commands :: proc(h: ^Hash_Builder, queue: ^Command_Queue) {
	hash_u32(h, u32(queue.head))
	hash_u32(h, u32(queue.tail))
	hash_u32(h, u32(queue.count))
	hash_u32(h, queue.rejected)
	for i in 0..<MAX_COMMANDS {
		command := queue.entries[i]
		hash_byte(h, u8(command.kind))
		hash_u16(h, command.actor.index)
		hash_u32(h, command.actor.generation)
		hash_i32(h, command.position.x)
		hash_i32(h, command.position.y)
		hash_i32(h, command.point_b.x)
		hash_i32(h, command.point_b.y)
		hash_u16(h, command.target.index)
		hash_u32(h, command.target.generation)
		hash_bool(h, command.from_current)
	}
}

hash_units :: proc(h: ^Hash_Builder, units: ^Units) {
	hash_u32(h, u32(units.free_count))
	hash_u32(h, u32(units.alive_count))
	hash_u32(h, u32(units.selected_count))
	for i in 0..<units.free_count {
		hash_u16(h, units.free_slots[i])
	}
	for i in 0..<MAX_UNITS {
		hash_bool(h, units.alive[i])
		if !units.alive[i] {
			continue
		}
		hash_u32(h, units.generation[i])
		hash_byte(h, u8(units.team[i]))
		hash_byte(h, u8(units.race[i]))
		hash_byte(h, u8(units.kind[i]))
		hash_i32(h, units.position[i].x)
		hash_i32(h, units.position[i].y)
		hash_i32(h, units.world[i].x)
		hash_i32(h, units.world[i].y)
		hash_i32(h, units.speed[i])
		hash_u16(h, units.hp[i])
		hash_u16(h, units.hp_max[i])
		hash_byte(h, u8(units.state[i]))
		hash_u16(h, units.path_len[i])
		hash_u16(h, units.path_index[i])
		hash_i32(h, units.progress[i])
		for p in 0..<int(units.path_len[i]) {
			hash_u16(h, units.path[i][p])
		}
		hash_bool(h, units.patrol_active[i])
		hash_i32(h, units.patrol_a[i].x)
		hash_i32(h, units.patrol_a[i].y)
		hash_i32(h, units.patrol_b[i].x)
		hash_i32(h, units.patrol_b[i].y)
		hash_bool(h, units.patrol_to_b[i])
		hash_bool(h, units.attack_move_active[i])
		hash_i32(h, units.attack_move_dest[i].x)
		hash_i32(h, units.attack_move_dest[i].y)
		hash_u16(h, units.attack_target[i].index)
		hash_u32(h, units.attack_target[i].generation)
		hash_u16(h, units.cooldown[i])
		hash_bool(h, units.selected[i])
	}
}
