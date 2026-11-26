// Declarative .odin -> Edit_Clip parser for the DreamCraft 3D animation pipeline.
package art_anim_edit

import "core:fmt"
import "core:os"
import "core:strings"
import spec "../spec"

@(private)
Parsed_Clip_Meta :: struct {
	id, title:        string,
	duration:         f32,
	loop:             bool,
	additive:         bool,
	secondary_weight: f32,
	k_sym:            string,
	k_chunks:         [dynamic]string,
}

// Return true if <anims_root>/<id>/clip.odin exists on disk.
has_saved_odin_clip :: proc(anims_root, id: string) -> bool {
	if len(anims_root) == 0 || len(id) == 0 {
		return false
	}
	root := strings.trim_right(anims_root, "/\\")
	path := fmt.aprintf("%s/%s/clip.odin", root, id)
	defer delete(path)
	return os.exists(path)
}

// Load an Edit_Clip from a directory containing clip.odin and k_NNN.odin chunks.
edit_clip_load_odin_dir :: proc(dir: string) -> (Edit_Clip, bool) {
	clean_dir := strings.trim_right(dir, "/\\")
	clip_path := fmt.aprintf("%s/clip.odin", clean_dir)
	defer delete(clip_path)
	data, err := os.read_entire_file(clip_path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data)

	meta, meta_ok := parse_clip_file(string(data))
	defer destroy_parsed_clip_meta(&meta)
	if !meta_ok {
		return {}, false
	}
	c := edit_clip_init(
		meta.id, meta.title, meta.duration, meta.loop, meta.additive, meta.secondary_weight,
	)
	if !load_kf_chunks(clean_dir, meta.k_chunks[:], &c) {
		edit_clip_delete(&c)
		return {}, false
	}
	edit_clip_sort_keyframes(&c)
	recompute_clip_handles(&c)
	c.dirty = false
	return c, true
}

@(private)
destroy_parsed_clip_meta :: proc(meta: ^Parsed_Clip_Meta) {
	delete(meta.id)
	delete(meta.title)
	delete(meta.k_sym)
	for s in meta.k_chunks {
		delete(s)
	}
	delete(meta.k_chunks)
	meta^ = {}
}

@(private)
parse_clip_file :: proc(src: string) -> (Parsed_Clip_Meta, bool) {
	meta := Parsed_Clip_Meta{
		duration = 1.0,
		k_sym    = strings.clone("K_CHUNKS"),
	}
	start, found := find_symbol_brace(src, "CLIP")
	if !found { return meta, false }
	c := Parser_Cursor{src = src, pos = start}
	if !parse_clip_fields(&c, &meta) { return meta, false }
	if !parse_chunk_ref_list(src, meta.k_sym, &meta.k_chunks) { return meta, false }
	return meta, len(meta.id) > 0
}

@(private)
parse_clip_fields :: proc(c: ^Parser_Cursor, meta: ^Parsed_Clip_Meta) -> bool {
	for {
		skip_ws_and_comments(c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' {
			c.pos += 1
			return true
		}
		field, ok := parse_ident(c)
		if !ok || !expect_byte(c, '=') || !parse_single_clip_field(c, field, meta) {
			return false
		}
		skip_optional_byte(c, ',')
	}
}

@(private)
parse_single_clip_field :: proc(c: ^Parser_Cursor, field: string, meta: ^Parsed_Clip_Meta) -> bool {
	ok: bool
	switch field {
	case "id":               ok = replace_str(&meta.id, parse_string_lit(c), false)
	case "title":            ok = replace_str(&meta.title, parse_string_lit(c), false)
	case "duration":         meta.duration, ok = parse_f32(c)
	case "loop":             meta.loop, ok = parse_bool(c)
	case "additive":         meta.additive, ok = parse_bool(c)
	case "secondary_weight": meta.secondary_weight, ok = parse_f32(c)
	case "keyframe_chunks":  ok = replace_str(&meta.k_sym, parse_slice_ref(c), true)
	case:                    return false
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
load_kf_chunks :: proc(dir: string, syms: []string, clip: ^Edit_Clip) -> bool {
	for sym in syms {
		lower := strings.to_lower(sym)
		path := fmt.aprintf("%s/%s.odin", dir, lower)
		delete(lower)
		data, err := os.read_entire_file(path, context.allocator)
		delete(path)
		if err != nil { return false }
		ok := parse_kf_chunk_entries(string(data), sym, clip)
		delete(data)
		if !ok { return false }
	}
	return true
}

@(private)
parse_kf_chunk_entries :: proc(src, sym: string, clip: ^Edit_Clip) -> bool {
	start, found := find_symbol_brace(src, sym)
	if !found { return false }
	c := Parser_Cursor{src = src, pos = start}
	for {
		skip_ws_and_comments(&c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' { return true }
		append(&clip.keyframes, parse_keyframe_def(&c) or_return)
		skip_optional_byte(&c, ',')
	}
}

@(private)
parse_keyframe_def :: proc(c: ^Parser_Cursor) -> (kf: Edit_Keyframe, ok: bool) {
	if !expect_byte(c, '{') { return {}, false }
	for {
		skip_ws_and_comments(c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' {
			c.pos += 1
			return kf, true
		}
		field := parse_ident(c) or_return
		if !expect_byte(c, '=') { return {}, false }
		switch field {
		case "time":
			kf.time = clamp(parse_f32(c) or_return, 0, 1)
		case "interp":
			name := parse_enum_dot(c) or_return
			interp, valid := spec.interp_from_name(name)
			if !valid { return {}, false }
			kf.interp = interp
		case "root_offset":
			kf.root_offset = parse_vec3(c) or_return
		case "bones":
			if !parse_bone_rot_list(c, &kf) { return {}, false }
		case "handles":
			if !parse_handle_list(c, &kf) { return {}, false }
		case:
			return {}, false
		}
		skip_optional_byte(c, ',')
	}
}

@(private)
parse_bone_rot_list :: proc(c: ^Parser_Cursor, kf: ^Edit_Keyframe) -> bool {
	if !advance_to_open_brace(c) { return false }
	for {
		skip_ws_and_comments(c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' {
			c.pos += 1
			return true
		}
		if !expect_byte(c, '{') { return false }
		bone_name := parse_enum_dot(c) or_return
		bone, valid := spec.bone_from_name(bone_name)
		if !valid || !expect_byte(c, ',') { return false }
		rot := parse_vec3(c) or_return
		skip_optional_byte(c, ',')
		if !expect_byte(c, '}') { return false }
		kf.rot[int(bone)] = rot
		skip_optional_byte(c, ',')
	}
}

@(private)
parse_handle_list :: proc(c: ^Parser_Cursor, kf: ^Edit_Keyframe) -> bool {
	if !advance_to_open_brace(c) { return false }
	for {
		skip_ws_and_comments(c)
		if c.pos < len(c.src) && c.src[c.pos] == '}' {
			c.pos += 1
			return true
		}
		if !parse_single_handle_entry(c, kf) { return false }
		skip_optional_byte(c, ',')
	}
}

@(private)
parse_single_handle_entry :: proc(c: ^Parser_Cursor, kf: ^Edit_Keyframe) -> bool {
	if !expect_byte(c, '{') { return false }
	bone_name := parse_enum_dot(c) or_return
	is_root := bone_name == "COUNT"
	bone := spec.Bone_Id.COUNT
	if !is_root {
		b, valid := spec.bone_from_name(bone_name)
		if !valid { return false }
		bone = b
	}
	if !expect_byte(c, ',') { return false }
	ax := parse_u8(c) or_return
	if ax >= 3 || !expect_byte(c, ',') { return false }
	h_name := parse_enum_dot(c) or_return
	h_kind, h_ok := spec.handle_from_name(h_name)
	if !h_ok || !expect_byte(c, ',') { return false }
	in_h := parse_vec2(c) or_return
	if !expect_byte(c, ',') { return false }
	out_h := parse_vec2(c) or_return
	skip_optional_byte(c, ',')
	if !expect_byte(c, '}') { return false }

	if is_root {
		kf.root_handle[ax], kf.root_in[ax], kf.root_out[ax] = h_kind, in_h, out_h
	} else {
		kf.rot_handle[int(bone)][ax], kf.rot_in[int(bone)][ax], kf.rot_out[int(bone)][ax] = h_kind, in_h, out_h
	}
	return true
}

@(private)
parse_vec2 :: proc(c: ^Parser_Cursor) -> (v: [2]f32, ok: bool) {
	if !expect_byte(c, '{') { return {}, false }
	v[0] = parse_f32(c) or_return
	if !expect_byte(c, ',') { return {}, false }
	v[1] = parse_f32(c) or_return
	skip_optional_byte(c, ',')
	if !expect_byte(c, '}') { return {}, false }
	return v, true
}

@(private)
parse_vec3 :: proc(c: ^Parser_Cursor) -> (v: [3]f32, ok: bool) {
	if !expect_byte(c, '{') { return {}, false }
	for i in 0 ..< 3 {
		v[i] = parse_f32(c) or_return
		if i < 2 && !expect_byte(c, ',') { return {}, false }
	}
	skip_optional_byte(c, ',')
	if !expect_byte(c, '}') { return {}, false }
	return v, true
}
