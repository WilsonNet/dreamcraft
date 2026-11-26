// Native client command-line flag parsers.
package main

import "core:strings"

has_arg :: proc(args: []string, flag: string) -> bool {
	for arg in args {
		if arg == flag {
			return true
		}
	}
	return false
}

// --zoom=<n> is a dev aid for inspecting models up close.
find_zoom :: proc(args: []string) -> (zoom: f32, ok: bool) {
	for arg in args {
		if !strings.has_prefix(arg, "--zoom=") {
			continue
		}
		value := arg[len("--zoom="):]
		seen := false
		for ch in value {
			if ch == '.' || (ch >= '0' && ch <= '9') {
				seen = true
			} else {
				return 0, false
			}
		}
		if !seen {
			return 0, false
		}
		parsed := f32(parse_decimal(value))
		if parsed <= 0 {
			return 0, false
		}
		return parsed, true
	}
	return 0, false
}

@(private)
parse_decimal :: proc(text: string) -> f64 {
	whole: f64 = 0
	fraction: f64 = 0
	scale: f64 = 0.1
	after_point := false
	for ch in text {
		if ch == '.' {
			after_point = true
			continue
		}
		digit := f64(ch - '0')
		if after_point {
			fraction += digit * scale
			scale *= 0.1
		} else {
			whole = whole * 10 + digit
		}
	}
	return whole + fraction
}

find_editor_arg :: proc(args: []string) -> (id: string, ok: bool) {
	for arg in args {
		if arg == "--editor" || arg == "--model-editor" {
			return "", true
		}
		if strings.has_prefix(arg, "--editor=") {
			return arg[len("--editor="):], true
		}
	}
	return "", false
}

find_anim_editor_arg :: proc(args: []string) -> (id: string, ok: bool) {
	for arg in args {
		if arg == "--anim-editor" {
			return "", true
		}
		if strings.has_prefix(arg, "--anim-editor=") {
			return arg[len("--anim-editor="):], true
		}
	}
	return "", false
}

find_control_port :: proc(args: []string) -> (port: int, ok: bool) {
	for arg in args {
		if arg == "--control" {
			return 7777, true
		}
		if strings.has_prefix(arg, "--control=") {
			value := arg[len("--control="):]
			if len(value) == 0 {
				return 0, false
			}
			parsed := 0
			for ch in value {
				if ch < '0' || ch > '9' {
					return 0, false
				}
				parsed = parsed * 10 + int(ch - '0')
			}
			return parsed, true
		}
	}
	return 0, false
}

// --bench=<frames>: uncapped frames in the opening scene, printing CPU frame-time stats.
find_bench :: proc(args: []string) -> (frames: int, ok: bool) {
	for arg in args {
		if strings.has_prefix(arg, "--bench=") {
			n := 0
			for ch in arg[len("--bench="):] {
				if ch < '0' || ch > '9' {
					return 0, false
				}
				n = n * 10 + int(ch - '0')
			}
			return max(n, 1), true
		}
	}
	return 0, false
}
