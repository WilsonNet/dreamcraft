// Lightweight Odin literal lexer helpers for animation clip parsing.
package art_anim_edit

import "core:strconv"
import "core:strings"

@(private)
Parser_Cursor :: struct {
	src: string,
	pos: int,
}

@(private)
find_symbol_brace :: proc(src, sym: string) -> (int, bool) {
	c := Parser_Cursor{src = src}
	for c.pos < len(c.src) {
		skip_ws_and_comments(&c)
		if c.pos >= len(c.src) { break }
		if c.src[c.pos] == '"' {
			_ = scan_string(&c, nil)
		} else if is_ident_char(c.src[c.pos], true) {
			ident, _ := parse_ident(&c)
			if ident == sym {
				if brace, ok := advance_to_decl_brace(&c); ok { return brace, true }
			}
		} else {
			c.pos += 1
		}
	}
	return 0, false
}

@(private)
advance_to_decl_brace :: proc(c: ^Parser_Cursor) -> (int, bool) {
	skip_ws_and_comments(c)
	if c.pos >= len(c.src) || c.src[c.pos] != ':' { return 0, false }
	c.pos += 1
	for c.pos < len(c.src) {
		skip_ws_and_comments(c)
		if c.pos >= len(c.src) || c.src[c.pos] == '\n' { return 0, false }
		if c.src[c.pos] == '{' { return c.pos + 1, true }
		c.pos += 1
	}
	return 0, false
}

@(private)
advance_to_open_brace :: proc(c: ^Parser_Cursor) -> bool {
	for c.pos < len(c.src) {
		skip_ws_and_comments(c)
		if c.pos >= len(c.src) { return false }
		if c.src[c.pos] == '{' {
			c.pos += 1
			return true
		}
		if c.src[c.pos] == '\n' { return false }
		c.pos += 1
	}
	return false
}

@(private)
skip_ws_and_comments :: proc(c: ^Parser_Cursor) {
	for c.pos < len(c.src) {
		ch := c.src[c.pos]
		if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
			c.pos += 1
		} else if ch == '/' && c.pos + 1 < len(c.src) && c.src[c.pos + 1] == '/' {
			c.pos += 2
			for c.pos < len(c.src) && c.src[c.pos] != '\n' { c.pos += 1 }
		} else if ch == '/' && c.pos + 1 < len(c.src) && c.src[c.pos + 1] == '*' {
			c.pos += 2
			for depth := 1; c.pos + 1 < len(c.src) && depth > 0; {
				if c.src[c.pos] == '/' && c.src[c.pos + 1] == '*' { depth += 1; c.pos += 2 } else
				if c.src[c.pos] == '*' && c.src[c.pos + 1] == '/' { depth -= 1; c.pos += 2 } else { c.pos += 1 }
			}
		} else {
			break
		}
	}
}

@(private)
scan_string :: proc(c: ^Parser_Cursor, sb: ^strings.Builder) -> bool {
	if c.pos >= len(c.src) || c.src[c.pos] != '"' { return false }
	c.pos += 1
	for c.pos < len(c.src) {
		ch := c.src[c.pos]; c.pos += 1
		if ch == '\\' && c.pos < len(c.src) {
			esc := c.src[c.pos]; c.pos += 1
			if sb != nil { strings.write_byte(sb, esc == 'n' ? '\n' : (esc == 't' ? '\t' : esc)) }
			continue
		}
		if ch == '"' { return true }
		if sb != nil { strings.write_byte(sb, ch) }
	}
	return false
}

@(private)
parse_string_lit :: proc(c: ^Parser_Cursor) -> (string, bool) {
	skip_ws_and_comments(c)
	sb := strings.builder_make()
	if scan_string(c, &sb) { return strings.to_string(sb), true }
	strings.builder_destroy(&sb)
	return "", false
}

@(private)
parse_slice_ref :: proc(c: ^Parser_Cursor) -> (res: string, ok: bool) {
	ident := parse_ident(c) or_return
	skip_ws_and_comments(c)
	if c.pos < len(c.src) && c.src[c.pos] == '[' {
		c.pos += 1
		if !expect_byte(c, ':') || !expect_byte(c, ']') { return "", false }
	}
	return ident, true
}

@(private)
parse_ident :: proc(c: ^Parser_Cursor) -> (string, bool) {
	skip_ws_and_comments(c)
	if c.pos >= len(c.src) || !is_ident_char(c.src[c.pos], true) { return "", false }
	start := c.pos
	c.pos += 1
	for c.pos < len(c.src) && is_ident_char(c.src[c.pos], false) { c.pos += 1 }
	return c.src[start:c.pos], true
}

@(private)
parse_enum_dot :: proc(c: ^Parser_Cursor) -> (string, bool) {
	if !expect_byte(c, '.') { return "", false }
	return parse_ident(c)
}

@(private)
parse_bool :: proc(c: ^Parser_Cursor) -> (res: bool, ok: bool) {
	ident := parse_ident(c) or_return
	if ident == "true" { return true, true }
	if ident == "false" { return false, true }
	return false, false
}

@(private)
parse_f32 :: proc(c: ^Parser_Cursor) -> (f32, bool) {
	skip_ws_and_comments(c)
	start := c.pos
	if c.pos < len(c.src) && (c.src[c.pos] == '-' || c.src[c.pos] == '+') { c.pos += 1 }
	has_digit := false
	for c.pos < len(c.src) {
		ch := c.src[c.pos]
		if ch >= '0' && ch <= '9' { has_digit = true; c.pos += 1 } else
		if ch == '.' || ch == 'e' || ch == 'E' || ((ch == '-' || ch == '+') && c.pos > start && (c.src[c.pos - 1] == 'e' || c.src[c.pos - 1] == 'E')) {
			c.pos += 1
		} else { break }
	}
	if !has_digit { return 0, false }
	return strconv.parse_f32(c.src[start:c.pos])
}

@(private)
parse_u8 :: proc(c: ^Parser_Cursor) -> (u8, bool) {
	skip_ws_and_comments(c)
	start := c.pos
	for c.pos < len(c.src) && c.src[c.pos] >= '0' && c.src[c.pos] <= '9' {
		c.pos += 1
	}
	if c.pos == start { return 0, false }
	val, ok := strconv.parse_u64(c.src[start:c.pos], 10)
	if !ok || val > 255 { return 0, false }
	return u8(val), true
}

@(private)
expect_byte :: proc(c: ^Parser_Cursor, target: u8) -> bool {
	skip_ws_and_comments(c)
	if c.pos >= len(c.src) || c.src[c.pos] != target { return false }
	c.pos += 1
	return true
}

@(private)
skip_optional_byte :: proc(c: ^Parser_Cursor, target: u8) {
	skip_ws_and_comments(c)
	if c.pos < len(c.src) && c.src[c.pos] == target { c.pos += 1 }
}

@(private)
is_ident_char :: proc(ch: u8, first: bool) -> bool {
	alpha := (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
	return alpha || (!first && ch >= '0' && ch <= '9')
}
