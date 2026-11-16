// Headless deterministic runner and control server.
//
// Modes:
//   dreamcraft-headless                     poll headless_command.json
//   dreamcraft-headless --script file.jsonl  one JSON command per line
//   dreamcraft-headless --ticks N            run N ticks, print state
//   dreamcraft-headless --serve[=PORT]       HTTP control API + simulation
package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import control "../control"
import g "../game"

Runner :: struct {
	game: g.Game,
	done: bool,
	server: control.Server,
	serving: bool,
	paused: bool,
}

main :: proc() {
	runner: Runner
	g.game_init(&runner.game)

	if path, ok := find_arg(os.args, "--script"); ok {
		os.exit(run_script(&runner, path))
	}
	if ticks, ok := find_ticks(os.args); ok {
		g.sim_run(&runner.game, ticks)
		result := control.execute(&runner.game, control.Command{cmd = "status"})
		write_result(&result)
		return
	}
	if port, ok := find_serve_port(os.args); ok {
		if !control.server_start(&runner.server, &runner.game, port) {
			os.exit(2)
		}
		runner.serving = true
		runner.paused = has_arg(os.args, "--paused")
	}
	defer if runner.serving {
		control.server_close(&runner.server)
	}
	run_polling(&runner)
}

find_arg :: proc(args: []string, name: string) -> (value: string, ok: bool) {
	for i in 0..<len(args) - 1 {
		if args[i] == name {
			return args[i + 1], true
		}
	}
	return "", false
}

has_arg :: proc(args: []string, name: string) -> bool {
	for arg in args {
		if arg == name {
			return true
		}
	}
	return false
}

find_ticks :: proc(args: []string) -> (ticks: int, ok: bool) {
	for i in 0..<len(args) - 1 {
		if args[i] == "--ticks" {
			if parsed, parsed_ok := parse_int(args[i + 1]); parsed_ok {
				return parsed, true
			}
		}
	}
	return 0, false
}

find_serve_port :: proc(args: []string) -> (port: int, ok: bool) {
	for arg in args {
		if arg == "--serve" {
			return 7777, true
		}
		if strings.has_prefix(arg, "--serve=") {
			if parsed, parsed_ok := parse_int(arg[len("--serve="):]); parsed_ok {
				return parsed, true
			}
		}
	}
	return 0, false
}

parse_int :: proc(value: string) -> (int, bool) {
	result := 0
	if len(value) == 0 {
		return 0, false
	}
	for ch in value {
		if ch < '0' || ch > '9' {
			return 0, false
		}
		result = result * 10 + int(ch - '0')
	}
	return result, true
}

run_polling :: proc(runner: ^Runner) {
	for !runner.done {
		if runner.serving {
			control.server_poll(&runner.server)
		}
		process_command_file(runner)
		if !runner.paused {
			g.sim_tick(&runner.game)
		}
		free_all(context.temp_allocator)
		time.sleep(16 * time.Millisecond)
	}
}

run_script :: proc(runner: ^Runner, path: string) -> int {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintfln("cannot read script %q: %v", path, err)
		return 2
	}
	defer delete(data)

	exit_code := 0
	for line in strings.split_lines(string(data)) {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 || trimmed[0] == '#' {
			continue
		}
		command: control.Command
		if unmarshal_err := json.unmarshal_string(trimmed, &command, allocator = context.temp_allocator); unmarshal_err != nil {
			result := control.execute(&runner.game, control.Command{cmd = "status"})
			result.ok = false
			result.msg = fmt.tprintf("bad json: %v", unmarshal_err)
			write_result(&result)
			free_all(context.temp_allocator)
			exit_code = 1
			continue
		}
		result := execute_command(runner, command)
		write_result(&result)
		free_all(context.temp_allocator)
		if !result.ok {
			exit_code = 1
		}
		if runner.done {
			break
		}
	}
	return exit_code
}

process_command_file :: proc(runner: ^Runner) {
	path := "headless_command.json"
	if !os.exists(path) {
		return
	}
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return
	}
	defer delete(data)
	_ = os.remove(path)

	command: control.Command
	if unmarshal_err := json.unmarshal(data, &command, allocator = context.temp_allocator); unmarshal_err != nil {
		result := control.execute(&runner.game, control.Command{cmd = "status"})
		result.ok = false
		result.msg = fmt.tprintf("bad json: %v", unmarshal_err)
		write_result(&result)
		return
	}
	result := execute_command(runner, command)
	write_result(&result)
	free_all(context.temp_allocator)
}

execute_command :: proc(runner: ^Runner, command: control.Command) -> control.Result {
	if command.cmd == "quit" {
		runner.done = true
		return control.execute(&runner.game, control.Command{cmd = "status"})
	}
	return control.execute(&runner.game, command)
}

write_result :: proc(result: ^control.Result) {
	data, err := json.marshal(result^)
	if err != nil {
		fmt.eprintln("failed to marshal result")
		return
	}
	defer delete(data)
	if write_err := os.write_entire_file("headless_result.json", data); write_err != nil {
		fmt.eprintfln("failed to write result: %v", write_err)
	}
	fmt.printfln("RESULT: %s", string(data))
}
