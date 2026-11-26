// Git-friendly declarative .odin exporter for Edit_Clip animations and manifest orchestrator.
package art_anim_edit

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import spec "../spec"

ANIM_KF_CHUNK_LIMIT :: 10

// Export an Edit_Clip to <anims_root>/<id>/ as chunked .odin files and update manifest.odin.
// Caller owns the returned dir string when ok is true.
edit_clip_save_odin :: proc(c: ^Edit_Clip, anims_root: string) -> (dir: string, ok: bool) {
	if c == nil || len(c.id) == 0 || len(anims_root) == 0 {
		return "", false
	}
	edit_clip_sort_keyframes(c)
	root := strings.trim_right(anims_root, "/\\")
	out_dir := fmt.aprintf("%s/%s", root, c.id)
	if err := os.make_directory_all(out_dir); err != nil && err != .Exist {
		delete(out_dir)
		return "", false
	}
	ident := sanitize_ident(c.id)
	defer delete(ident)
	pkg_name := fmt.aprintf("anim_%s", ident)
	defer delete(pkg_name)

	k_chunks := write_all_kf_chunks(out_dir, pkg_name, c.keyframes[:])
	if k_chunks < 0 {
		delete(out_dir)
		return "", false
	}
	if !write_clip_file(out_dir, pkg_name, c, k_chunks) {
		delete(out_dir)
		return "", false
	}
	cleanup_stale_kf_chunks(out_dir, k_chunks)
	if !rewrite_anims_manifest(root) {
		delete(out_dir)
		return "", false
	}
	return out_dir, true
}

// Scan subdirectories of anims_root for clip.odin and regenerate <anims_root>/manifest.odin.
rewrite_anims_manifest :: proc(anims_root: string) -> bool {
	root := strings.trim_right(anims_root, "/\\")
	if len(root) == 0 || !os.is_dir(root) {
		return false
	}
	dirs, ok := collect_anim_subdirs(root)
	if !ok {
		return false
	}
	defer {
		for d in dirs {
			delete(d)
		}
		delete(dirs)
	}
	slice.sort(dirs[:])

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	write_manifest_header(&sb, dirs[:])
	write_manifest_body(&sb, dirs[:])

	manifest_path := fmt.aprintf("%s/manifest.odin", root)
	defer delete(manifest_path)
	return os.write_entire_file(manifest_path, strings.to_string(sb)) == nil
}

@(private)
collect_anim_subdirs :: proc(root: string) -> ([dynamic]string, bool) {
	infos, err := os.read_all_directory_by_path(root, context.allocator)
	if err != nil {
		return nil, false
	}
	defer os.file_info_slice_delete(infos, context.allocator)

	dirs := make([dynamic]string)
	for fi in infos {
		if fi.type != .Directory || strings.has_prefix(fi.name, ".") {
			continue
		}
		clip_path := fmt.aprintf("%s/clip.odin", fi.fullpath)
		has_clip := os.exists(clip_path)
		delete(clip_path)
		if has_clip {
			append(&dirs, strings.clone(fi.name))
		}
	}
	return dirs, true
}

@(private)
write_manifest_header :: proc(sb: ^strings.Builder, dirs: []string) {
	strings.write_string(sb, "// Root orchestrator for compiled declarative Odin animation clips.\n")
	strings.write_string(sb, "// Individual saved clips live in subpackages under client/art/anims/<id>/\n")
	strings.write_string(sb, "// and register here so release/test builds compile all customizations directly.\n")
	strings.write_string(sb, "package art_anims\n\n")
	strings.write_string(sb, "import spec \"../spec\"\n")
	for d in dirs {
		ident := sanitize_ident(d)
		fmt.sbprintf(sb, "import a_%s \"./%s\"\n", ident, d)
		delete(ident)
	}
	strings.write_string(sb, "\n")
}

@(private)
write_manifest_body :: proc(sb: ^strings.Builder, dirs: []string) {
	if len(dirs) == 0 {
		strings.write_string(sb, "BUILTIN_CLIPS := []spec.Anim_Clip_Def{}\n\n")
	} else {
		strings.write_string(sb, "BUILTIN_CLIPS := []spec.Anim_Clip_Def{\n")
		for d in dirs {
			ident := sanitize_ident(d)
			fmt.sbprintf(sb, "\ta_%s.CLIP,\n", ident)
			delete(ident)
		}
		strings.write_string(sb, "}\n\n")
	}
	strings.write_string(sb, "find_builtin_clip :: proc(id: string) -> (spec.Anim_Clip_Def, bool) {\n")
	strings.write_string(sb, "\tfor def in BUILTIN_CLIPS {\n")
	strings.write_string(sb, "\t\tif def.id == id {\n")
	strings.write_string(sb, "\t\t\treturn def, true\n")
	strings.write_string(sb, "\t\t}\n")
	strings.write_string(sb, "\t}\n")
	strings.write_string(sb, "\treturn {}, false\n")
	strings.write_string(sb, "}\n")
}

@(private)
write_all_kf_chunks :: proc(dir, pkg_name: string, kfs: []Edit_Keyframe) -> int {
	if len(kfs) == 0 {
		return 0
	}
	count := (len(kfs) + ANIM_KF_CHUNK_LIMIT - 1) / ANIM_KF_CHUNK_LIMIT
	for ci in 0 ..< count {
		lo := ci * ANIM_KF_CHUNK_LIMIT
		hi := min(lo + ANIM_KF_CHUNK_LIMIT, len(kfs))
		if !write_kf_chunk(dir, pkg_name, ci, kfs[lo:hi]) {
			return -1
		}
	}
	return count
}

@(private)
write_kf_chunk :: proc(dir, pkg_name: string, idx: int, kfs: []Edit_Keyframe) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintf(&sb, "package %s\n\nimport spec \"../../spec\"\n\n", pkg_name)
	fmt.sbprintf(&sb, "K_%03d := [%d]spec.Anim_Keyframe_Def{{\n", idx, len(kfs))
	for &kf in kfs {
		write_kf_entry(&sb, &kf)
	}
	strings.write_string(&sb, "}\n")
	path := fmt.aprintf("%s/k_%03d.odin", dir, idx)
	defer delete(path)
	return os.write_entire_file(path, strings.to_string(sb)) == nil
}

@(private)
write_kf_entry :: proc(sb: ^strings.Builder, kf: ^Edit_Keyframe) {
	interp := kf.interp
	if int(interp) > int(spec.Anim_Interp.Ease_Out) {
		interp = .Smooth
	}
	fmt.sbprintf(
		sb,
		"\t{{time = %.4f, interp = .%s, root_offset = {{%.4f, %.4f, %.4f}}, bones = {{\n",
		norm_f32(kf.time),
		spec.INTERP_NAMES[interp],
		norm_f32(kf.root_offset[0]),
		norm_f32(kf.root_offset[1]),
		norm_f32(kf.root_offset[2]),
	)
	for bi in 0 ..< BONE_COUNT {
		r := kf.rot[bi]
		if abs(r[0]) + abs(r[1]) + abs(r[2]) < 0.0001 {
			continue
		}
		fmt.sbprintf(
			sb,
			"\t\t{{.%s, {{%.4f, %.4f, %.4f}}}},\n",
			spec.BONE_NAMES[spec.Bone_Id(bi)],
			norm_f32(r[0]),
			norm_f32(r[1]),
			norm_f32(r[2]),
		)
	}
	strings.write_string(sb, "\t}")
	write_kf_handles(sb, kf)
	strings.write_string(sb, "},\n")
}

@(private)
write_kf_handles :: proc(sb: ^strings.Builder, kf: ^Edit_Keyframe) {
	has_custom := false
	for bi in 0 ..< BONE_COUNT {
		for ax in 0 ..< 3 {
			if kf.rot_handle[bi][ax] != .Auto_Clamped { has_custom = true; break }
		}
		if has_custom { break }
	}
	if !has_custom {
		for ax in 0 ..< 3 {
			if kf.root_handle[ax] != .Auto_Clamped { has_custom = true; break }
		}
	}
	if !has_custom {
		return
	}
	strings.write_string(sb, ", handles = {\n")
	for bi in 0 ..< BONE_COUNT {
		for ax in 0 ..< 3 {
			h := kf.rot_handle[bi][ax]
			if h == .Auto_Clamped { continue }
			write_single_handle(sb, spec.BONE_NAMES[spec.Bone_Id(bi)], ax, h, kf.rot_in[bi][ax], kf.rot_out[bi][ax])
		}
	}
	for ax in 0 ..< 3 {
		h := kf.root_handle[ax]
		if h == .Auto_Clamped { continue }
		write_single_handle(sb, "COUNT", ax, h, kf.root_in[ax], kf.root_out[ax])
	}
	strings.write_string(sb, "\t}")
}

@(private)
write_single_handle :: proc(sb: ^strings.Builder, bone_name: string, ax: int, h: spec.Anim_Handle, in_h, out_h: [2]f32) {
	fmt.sbprintf(
		sb,
		"\t\t{{.%s, %d, .%s, {{%.4f, %.4f}}, {{%.4f, %.4f}}}},\n",
		bone_name,
		ax,
		spec.HANDLE_NAMES[h],
		norm_f32(in_h[0]),
		norm_f32(in_h[1]),
		norm_f32(out_h[0]),
		norm_f32(out_h[1]),
	)
}

@(private)
write_clip_file :: proc(dir, pkg_name: string, c: ^Edit_Clip, k_chunks: int) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintf(&sb, "package %s\n\nimport spec \"../../spec\"\n\n", pkg_name)
	write_kf_chunk_refs(&sb, k_chunks)
	strings.write_string(&sb, "CLIP := spec.Anim_Clip_Def{\n\tid               = \"")
	write_escaped_str(&sb, c.id)
	strings.write_string(&sb, "\",\n\ttitle            = \"")
	write_escaped_str(&sb, c.title)
	fmt.sbprintf(
		&sb,
		"\",\n\tduration         = %.4f,\n\tloop             = %v,\n\tadditive         = %v,\n\tsecondary_weight = %.4f,\n\tkeyframe_chunks  = K_CHUNKS[:],\n}}\n",
		norm_f32(max(c.duration, 0.05)),
		c.loop,
		c.additive,
		norm_f32(max(c.secondary_weight, 0)),
	)
	path := fmt.aprintf("%s/clip.odin", dir)
	defer delete(path)
	return os.write_entire_file(path, strings.to_string(sb)) == nil
}

@(private)
write_kf_chunk_refs :: proc(sb: ^strings.Builder, count: int) {
	if count == 0 {
		strings.write_string(sb, "K_CHUNKS := [0][]spec.Anim_Keyframe_Def{}\n\n")
		return
	}
	fmt.sbprintf(sb, "K_CHUNKS := [%d][]spec.Anim_Keyframe_Def{{\n", count)
	for i in 0 ..< count {
		fmt.sbprintf(sb, "\tK_%03d[:],\n", i)
	}
	strings.write_string(sb, "}\n\n")
}

@(private)
cleanup_stale_kf_chunks :: proc(dir: string, k_chunks: int) {
	infos, err := os.read_all_directory_by_path(dir, context.allocator)
	if err != nil {
		return
	}
	defer os.file_info_slice_delete(infos, context.allocator)
	for fi in infos {
		if fi.type != .Regular {
			continue
		}
		if idx, ok := parse_kf_chunk_filename(fi.name); ok && idx >= k_chunks {
			_ = os.remove(fi.fullpath)
		}
	}
}

@(private)
parse_kf_chunk_filename :: proc(name: string) -> (idx: int, ok: bool) {
	if !strings.has_suffix(name, ".odin") || !strings.has_prefix(name, "k_") || len(name) < 8 {
		return 0, false
	}
	num_str := name[2 : len(name) - 5]
	for r in num_str {
		if r < '0' || r > '9' {
			return 0, false
		}
	}
	val, parse_ok := strconv.parse_int(num_str, 10)
	return val, parse_ok && val >= 0
}

@(private)
norm_f32 :: proc(v: f32) -> f32 {
	if math.is_nan(v) || math.is_inf(v) || abs(v) < 0.00005 {
		return 0.0
	}
	return v
}

@(private)
write_escaped_str :: proc(sb: ^strings.Builder, s: string) {
	for i in 0 ..< len(s) {
		ch := s[i]
		if ch == '"' || ch == '\\' {
			strings.write_byte(sb, '\\')
		}
		strings.write_byte(sb, ch)
	}
}

@(private)
sanitize_ident :: proc(raw: string, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	for i in 0 ..< len(raw) {
		ch := raw[i]
		is_alpha := (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
		is_digit := ch >= '0' && ch <= '9'
		if is_alpha || is_digit || ch == '_' {
			strings.write_byte(&sb, ch)
		} else {
			strings.write_byte(&sb, '_')
		}
	}
	if strings.builder_len(sb) == 0 {
		strings.write_string(&sb, "clip")
	}
	return strings.to_string(sb)
}
