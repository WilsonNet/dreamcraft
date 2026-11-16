#+build !js
package game

import "base:runtime"
import "core:testing"

Alloc_Probe :: struct {
	calls: int,
}

probe_alloc :: proc(
	allocator_data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> ([]byte, runtime.Allocator_Error) {
	probe := cast(^Alloc_Probe)allocator_data
	probe.calls += 1
	return nil, .Out_Of_Memory
}

@(test)
simulation_does_not_allocate :: proc(t: ^testing.T) {
	probe: Alloc_Probe
	old_context := context
	context.allocator = runtime.Allocator{procedure = probe_alloc, data = &probe}
	defer context = old_context

	game: Game
	game_init(&game)
	player, _ := game_player_handle(&game)
	command_push(&game.commands, Command{kind = .Move, actor = player, position = {20, 25}}, &game.units, &game.grid)
	sim_run(&game, 500)
	command_push(&game.commands, Command{kind = .Patrol, actor = player, position = {20, 25}, point_b = {30, 25}}, &game.units, &game.grid)
	sim_run(&game, 500)
	_ = game_hash(&game)

	testing.expect_value(t, probe.calls, 0)
	testing.expect_value(t, validate_game(&game), Validation_Error.None)
}
