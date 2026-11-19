// Declarative .odin -> Edit_Mesh parser for the DreamCraft 3D art pipeline.
package art_edit

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import spec "../spec"

@(private)
Parser_Cursor :: struct {
	src: string,
	pos: int,
}

@(private)
Parsed_Asset_Meta :: struct {
	id, title:     string,
	category:      spec.Model_Category,
	skinned:       bool,
	ao_height:     f32,
	default_scale: f32,
	glow_override: f32,
	v_sym, f_sym:  string,
	v_chunks:      [dynamic]string,
	f_chunks:      [dynamic]string,
}

// Return true if <models_root>/<id>/asset.odin exists on disk.
has_saved_odin_model :: proc(models_root, id: string) -> bool {
	if len(models_root) == 0 || len(id) == 0 {
		return false
	}
	root := strings.trim_right(models_root, "/\\")
	path := fmt.aprintf("%s/%s/asset.odin", root, id)
	defer delete(path)
	return os.exists(path)
}

// Load an Edit_Mesh from a directory containing asset.odin and v_NNN.odin / f_NNN.odin chunks.
edit_mesh_load_odin_dir :: proc(dir: string) -> (Edit_Mesh, bool) {
	clean_dir := strings.trim_right(dir, "/\\")
	asset_path := fmt.aprintf("%s/asset.odin", clean_dir)
	defer delete(asset_path)
	data, err := os.read_entire_file(asset_path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data)

	meta, meta_ok := parse_asset_file(string(data))
	defer destroy_parsed_meta(&meta)
	if !meta_ok {
		return {}, false
	}
	m := edit_mesh_init(
		meta.id, meta.title, meta.category, meta.skinned,
		meta.ao_height, meta.default_scale, meta.glow_override,
	)
	if !load_chunks(clean_dir, meta.v_chunks[:], &m, true) ||
	   !load_chunks(clean_dir, meta.f_chunks[:], &m, false) {
		edit_mesh_delete(&m)
		return {}, false
	}
	edit_mesh_rebuild_topology(&m)
	m.dirty = false
	return m, true
}

@(private)
destroy_parsed_meta :: proc(meta: ^Parsed_Asset_Meta) {
	delete(meta.id)
	delete(meta.title)
	delete(meta.v_sym)
	delete(meta.f_sym)
	for s in meta.v_chunks { delete(s) }
	delete(meta.v_chunks)
	for s in meta.f_chunks { delete(s) }
	delete(meta.f_chunks)
	meta^ = {}
}

@(private)
parse_asset_file :: proc(src: string) -> (Parsed_Asset_Meta, bool) {
	meta := Parsed_Asset_Meta{
		default_scale = 1.0,
		v_sym         = strings.clone("V_CHUNKS"),
		f_sym         = strings.clone("F_CHUNKS"),
	}
	start, found := find_symbol_brace(src, "ASSET")
	if !found { return meta, false }
	c := Parser_Cursor{src = src, pos = start}
	if !parse_asset_fields(&c, &meta) { return meta, false }
	if !parse_chunk_ref_list(src, meta.v_sym, &meta.v_chunks) { return meta, false }
	if !parse_chunk_ref_list(src, meta.f_sym, &meta.f_chunks) { return meta, false }
	return meta, len(meta.id) > 0
}

@(private)
parse_asset_fields :: proc(c: ^Parser_Cursor, meta: ^Parsed_Asset_Meta) -> bool {
	for {
		skip_ws_and_comments(c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' {
			c.pos += 1
			return true
		}
		field, ok := parse_ident(c)
		if !ok || !expect_byte(c, '=') || !parse_single_asset_field(c, field, meta) {
			return false
		}
		skip_optional_byte(c, ',')
	}
}

@(private)
parse_single_asset_field :: proc(c: ^Parser_Cursor, field: string, meta: ^Parsed_Asset_Meta) -> bool {
	ok: bool
	switch field {
	case "id":            ok = replace_str(&meta.id, parse_string_lit(c), false)
	case "title":         ok = replace_str(&meta.title, parse_string_lit(c), false)
	case "category":      meta.category, ok = parse_category(c)
	case "skinned":       meta.skinned, ok = parse_bool(c)
	case "ao_height":     meta.ao_height, ok = parse_f32(c)
	case "default_scale": meta.default_scale, ok = parse_f32(c)
	case "glow_override": meta.glow_override, ok = parse_f32(c)
	case "vert_chunks":   ok = replace_str(&meta.v_sym, parse_slice_ref(c), true)
	case "face_chunks":   ok = replace_str(&meta.f_sym, parse_slice_ref(c), true)
	case:                 return false
	}
	return ok
}

@(private)
replace_str :: proc(dst: ^string, val: string, ok, clone_val: bool) -> bool {
	if ok {
		delete(dst^)
		dst^ = clone_val ? strings.clone(val) : val
	}
	return ok
}

@(private)
parse_category :: proc(c: ^Parser_Cursor) -> (spec.Model_Category, bool) {
	name, ok := parse_enum_dot(c)
	if !ok { return .Props, false }
	switch name {
	case "Units": return .Units, true
	case "Trees": return .Trees, true
	case "Props": return .Props, true
	}
	return .Props, false
}

@(private)
parse_chunk_ref_list :: proc(src, sym: string, out: ^[dynamic]string) -> bool {
	start, found := find_symbol_brace(src, sym)
	if !found { return false }
	c := Parser_Cursor{src = src, pos = start}
	for {
		skip_ws_and_comments(&c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' { return true }
		name, ok := parse_slice_ref(&c)
		if !ok { return false }
		append(out, strings.clone(name))
		skip_optional_byte(&c, ',')
	}
}

@(private)
load_chunks :: proc(dir: string, syms: []string, m: ^Edit_Mesh, is_vert: bool) -> bool {
	for sym in syms {
		lower := strings.to_lower(sym)
		path := fmt.aprintf("%s/%s.odin", dir, lower)
		delete(lower)
		data, err := os.read_entire_file(path, context.allocator)
		delete(path)
		if err != nil { return false }
		ok := parse_chunk_entries(string(data), sym, m, is_vert)
		delete(data)
		if !ok { return false }
	}
	return true
}

@(private)
parse_chunk_entries :: proc(src, sym: string, m: ^Edit_Mesh, is_vert: bool) -> bool {
	start, found := find_symbol_brace(src, sym)
	if !found { return false }
	c := Parser_Cursor{src = src, pos = start}
	for {
		skip_ws_and_comments(&c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' { return true }
		if is_vert {
			append(&m.verts, parse_asset_vert(&c) or_return)
		} else {
			append(&m.faces, parse_asset_face(&c, len(m.verts)) or_return)
		}
		skip_optional_byte(&c, ',')
	}
}

@(private)
parse_asset_vert :: proc(c: ^Parser_Cursor) -> (res: Edit_Vert, ok: bool) {
	if !expect_byte(c, '{') || !expect_byte(c, '{') { return {}, false }
	pos: [3]f32
	for i in 0..<3 {
		pos[i] = parse_f32(c) or_return
		if i < 2 && !expect_byte(c, ',') { return {}, false }
	}
	skip_optional_byte(c, ',')
	if !expect_byte(c, '}') || !expect_byte(c, ',') { return {}, false }
	bone_name := parse_enum_dot(c) or_return
	bone, bone_valid := spec.bone_from_name(bone_name)
	if !bone_valid || !expect_byte(c, ',') { return {}, false }
	ao := parse_f32(c) or_return
	if !expect_byte(c, ',') { return {}, false }
	grp := parse_u32(c) or_return
	skip_optional_byte(c, ',')
	if grp > 65535 || !expect_byte(c, '}') { return {}, false }
	return Edit_Vert{pos = pos, nrm = {0, 1, 0}, bone = bone, ao = ao, group = u16(grp)}, true
}

@(private)
parse_asset_face :: proc(c: ^Parser_Cursor, vert_count: int) -> (res: Edit_Face, ok: bool) {
	if !expect_byte(c, '{') || !expect_byte(c, '{') { return {}, false }
	v: [4]u32
	for i in 0..<4 {
		v[i] = parse_u32(c) or_return
		if i < 3 && !expect_byte(c, ',') { return {}, false }
	}
	skip_optional_byte(c, ',')
	if !expect_byte(c, '}') || !expect_byte(c, ',') { return {}, false }
	cnt := parse_u32(c) or_return
	if (cnt != 3 && cnt != 4) || !expect_byte(c, ',') { return {}, false }
	for i in 0..<int(cnt) { if int(v[i]) >= vert_count { return {}, false } }
	mat_name := parse_enum_dot(c) or_return
	mat, mat_valid := spec.mat_from_name(mat_name)
	if !mat_valid || !expect_byte(c, ',') { return {}, false }
	smooth := parse_bool(c) or_return
	if !expect_byte(c, ',') { return {}, false }
	grp := parse_u32(c) or_return
	skip_optional_byte(c, ',')
	if grp > 65535 || !expect_byte(c, '}') { return {}, false }
	return Edit_Face{v = v, count = u8(cnt), mat = mat, smooth = smooth, group = u16(grp)}, true
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
parse_u32 :: proc(c: ^Parser_Cursor) -> (u32, bool) {
	skip_ws_and_comments(c)
	start := c.pos
	for c.pos < len(c.src) && c.src[c.pos] >= '0' && c.src[c.pos] <= '9' { c.pos += 1 }
	if c.pos == start { return 0, false }
	val, ok := strconv.parse_u64(c.src[start:c.pos], 10)
	if !ok || val > u64(max(u32)) { return 0, false }
	return u32(val), true
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
