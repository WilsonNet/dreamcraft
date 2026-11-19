// Git-friendly declarative .odin exporter for Edit_Mesh assets and manifest orchestrator.
package art_edit

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import spec "../spec"

ODIN_CHUNK_LIMIT :: 300

// Export an Edit_Mesh to <models_root>/<id>/ as chunked .odin files and update manifest.odin.
// Caller owns the returned dir string when ok is true.
edit_mesh_save_odin :: proc(m: ^Edit_Mesh, models_root: string) -> (dir: string, ok: bool) {
	if m == nil || len(m.id) == 0 || len(models_root) == 0 {
		return "", false
	}
	root := strings.trim_right(models_root, "/\\")
	out_dir := fmt.aprintf("%s/%s", root, m.id)
	if err := os.make_directory_all(out_dir); err != nil && err != .Exist {
		delete(out_dir)
		return "", false
	}
	ident := sanitize_ident(m.id)
	defer delete(ident)
	pkg_name := fmt.aprintf("model_%s", ident)
	defer delete(pkg_name)

	v_chunks := write_all_vert_chunks(out_dir, pkg_name, m.verts[:])
	f_chunks := write_all_face_chunks(out_dir, pkg_name, m.faces[:])
	if v_chunks < 0 || f_chunks < 0 {
		delete(out_dir)
		return "", false
	}
	if !write_asset_file(out_dir, pkg_name, m, v_chunks, f_chunks) {
		delete(out_dir)
		return "", false
	}
	cleanup_stale_chunks(out_dir, v_chunks, f_chunks)
	if !rewrite_models_manifest(root) {
		delete(out_dir)
		return "", false
	}
	return out_dir, true
}

// Scan subdirectories of models_root for asset.odin and regenerate <models_root>/manifest.odin.
rewrite_models_manifest :: proc(models_root: string) -> bool {
	root := strings.trim_right(models_root, "/\\")
	if len(root) == 0 || !os.is_dir(root) {
		return false
	}
	dirs, ok := collect_model_subdirs(root)
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
collect_model_subdirs :: proc(root: string) -> ([dynamic]string, bool) {
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
		asset_path := fmt.aprintf("%s/asset.odin", fi.fullpath)
		has_asset := os.exists(asset_path)
		delete(asset_path)
		if has_asset {
			append(&dirs, strings.clone(fi.name))
		}
	}
	return dirs, true
}

@(private)
write_manifest_header :: proc(sb: ^strings.Builder, dirs: []string) {
	strings.write_string(sb, "// Root orchestrator for compiled declarative Odin mesh assets.\n")
	strings.write_string(sb, "// Individual saved models live in subpackages under client/art/models/<id>/\n")
	strings.write_string(sb, "// and register here so release/test builds compile all customizations directly.\n")
	strings.write_string(sb, "package art_models\n\n")
	strings.write_string(sb, "import spec \"../spec\"\n")
	for d in dirs {
		ident := sanitize_ident(d)
		fmt.sbprintf(sb, "import m_%s \"./%s\"\n", ident, d)
		delete(ident)
	}
	strings.write_string(sb, "\n")
}

@(private)
write_manifest_body :: proc(sb: ^strings.Builder, dirs: []string) {
	if len(dirs) == 0 {
		strings.write_string(sb, "BUILTIN_ASSETS := []spec.Model_Asset_Def{}\n\n")
	} else {
		strings.write_string(sb, "BUILTIN_ASSETS := []spec.Model_Asset_Def{\n")
		for d in dirs {
			ident := sanitize_ident(d)
			fmt.sbprintf(sb, "\tm_%s.ASSET,\n", ident)
			delete(ident)
		}
		strings.write_string(sb, "}\n\n")
	}
	strings.write_string(sb, "find_builtin_asset :: proc(id: string) -> (spec.Model_Asset_Def, bool) {\n")
	strings.write_string(sb, "\tfor def in BUILTIN_ASSETS {\n")
	strings.write_string(sb, "\t\tif def.id == id {\n")
	strings.write_string(sb, "\t\t\treturn def, true\n")
	strings.write_string(sb, "\t\t}\n")
	strings.write_string(sb, "\t}\n")
	strings.write_string(sb, "\treturn {}, false\n")
	strings.write_string(sb, "}\n")
}

@(private)
write_all_vert_chunks :: proc(dir, pkg_name: string, verts: []Edit_Vert) -> int {
	if len(verts) == 0 {
		return 0
	}
	count := (len(verts) + ODIN_CHUNK_LIMIT - 1) / ODIN_CHUNK_LIMIT
	for ci in 0..<count {
		lo := ci * ODIN_CHUNK_LIMIT
		hi := min(lo + ODIN_CHUNK_LIMIT, len(verts))
		if !write_vert_chunk(dir, pkg_name, ci, verts[lo:hi]) {
			return -1
		}
	}
	return count
}

@(private)
write_all_face_chunks :: proc(dir, pkg_name: string, faces: []Edit_Face) -> int {
	if len(faces) == 0 {
		return 0
	}
	count := (len(faces) + ODIN_CHUNK_LIMIT - 1) / ODIN_CHUNK_LIMIT
	for ci in 0..<count {
		lo := ci * ODIN_CHUNK_LIMIT
		hi := min(lo + ODIN_CHUNK_LIMIT, len(faces))
		if !write_face_chunk(dir, pkg_name, ci, faces[lo:hi]) {
			return -1
		}
	}
	return count
}

@(private)
write_vert_chunk :: proc(dir, pkg_name: string, idx: int, verts: []Edit_Vert) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintf(&sb, "package %s\n\nimport spec \"../../spec\"\n\n", pkg_name)
	fmt.sbprintf(&sb, "V_%03d := [%d]spec.Asset_Vert{{\n", idx, len(verts))
	for v in verts {
		bone := v.bone
		if int(bone) >= int(spec.Bone_Id.COUNT) {
			bone = .Root
		}
		fmt.sbprintf(
			&sb,
			"\t{{{{%.4f, %.4f, %.4f}}, .%s, %.4f, %d}},\n",
			norm_f32(v.pos[0]),
			norm_f32(v.pos[1]),
			norm_f32(v.pos[2]),
			spec.BONE_NAMES[bone],
			norm_f32(v.ao),
			v.group,
		)
	}
	strings.write_string(&sb, "}\n")
	path := fmt.aprintf("%s/v_%03d.odin", dir, idx)
	defer delete(path)
	return os.write_entire_file(path, strings.to_string(sb)) == nil
}

@(private)
write_face_chunk :: proc(dir, pkg_name: string, idx: int, faces: []Edit_Face) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintf(&sb, "package %s\n\nimport spec \"../../spec\"\n\n", pkg_name)
	fmt.sbprintf(&sb, "F_%03d := [%d]spec.Asset_Face{{\n", idx, len(faces))
	for f in faces {
		mat := f.mat
		if int(mat) >= int(spec.Mat_Kind.COUNT) {
			mat = .Skin
		}
		fmt.sbprintf(
			&sb,
			"\t{{{{%d, %d, %d, %d}}, %d, .%s, %v, %d}},\n",
			f.v[0],
			f.v[1],
			f.v[2],
			f.v[3],
			f.count,
			spec.MAT_NAMES[mat],
			f.smooth,
			f.group,
		)
	}
	strings.write_string(&sb, "}\n")
	path := fmt.aprintf("%s/f_%03d.odin", dir, idx)
	defer delete(path)
	return os.write_entire_file(path, strings.to_string(sb)) == nil
}

@(private)
write_asset_file :: proc(dir, pkg_name: string, m: ^Edit_Mesh, v_chunks, f_chunks: int) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	fmt.sbprintf(&sb, "package %s\n\nimport spec \"../../spec\"\n\n", pkg_name)
	write_chunk_refs(&sb, "V_CHUNKS", "spec.Asset_Vert", "V", v_chunks)
	write_chunk_refs(&sb, "F_CHUNKS", "spec.Asset_Face", "F", f_chunks)
	strings.write_string(&sb, "ASSET := spec.Model_Asset_Def{\n\tid            = \"")
	write_escaped_str(&sb, m.id)
	strings.write_string(&sb, "\",\n\ttitle         = \"")
	write_escaped_str(&sb, m.title)
	fmt.sbprintf(
		&sb,
		"\",\n\tcategory      = .%s,\n\tskinned       = %v,\n\tao_height     = %.4f,\n\tdefault_scale = %.4f,\n\tglow_override = %.4f,\n\tvert_chunks   = V_CHUNKS[:],\n\tface_chunks   = F_CHUNKS[:],\n}}\n",
		category_name(m.category),
		m.skinned,
		norm_f32(m.ao_height),
		norm_f32(m.default_scale),
		norm_f32(m.glow_override),
	)
	path := fmt.aprintf("%s/asset.odin", dir)
	defer delete(path)
	return os.write_entire_file(path, strings.to_string(sb)) == nil
}

@(private)
write_chunk_refs :: proc(sb: ^strings.Builder, sym, elem_type, prefix: string, count: int) {
	if count == 0 {
		fmt.sbprintf(sb, "%s := [0][]%s{{}}\n\n", sym, elem_type)
		return
	}
	fmt.sbprintf(sb, "%s := [%d][]%s{{\n", sym, count, elem_type)
	for i in 0..<count {
		fmt.sbprintf(sb, "\t%s_%03d[:],\n", prefix, i)
	}
	strings.write_string(sb, "}\n\n")
}

@(private)
cleanup_stale_chunks :: proc(dir: string, v_chunks, f_chunks: int) {
	infos, err := os.read_all_directory_by_path(dir, context.allocator)
	if err != nil {
		return
	}
	defer os.file_info_slice_delete(infos, context.allocator)
	for fi in infos {
		if fi.type != .Regular {
			continue
		}
		kind, idx, ok := parse_chunk_filename(fi.name)
		if !ok {
			continue
		}
		if (kind == 'v' && idx >= v_chunks) || (kind == 'f' && idx >= f_chunks) {
			_ = os.remove(fi.fullpath)
		}
	}
}

@(private)
parse_chunk_filename :: proc(name: string) -> (kind: u8, idx: int, ok: bool) {
	if !strings.has_suffix(name, ".odin") || len(name) < 8 {
		return 0, 0, false
	}
	if (name[0] != 'v' && name[0] != 'f') || name[1] != '_' {
		return 0, 0, false
	}
	num_str := name[2:len(name) - 5]
	if len(num_str) == 0 {
		return 0, 0, false
	}
	for r in num_str {
		if r < '0' || r > '9' {
			return 0, 0, false
		}
	}
	val, parse_ok := strconv.parse_int(num_str, 10)
	if !parse_ok || val < 0 {
		return 0, 0, false
	}
	return name[0], val, true
}

@(private)
norm_f32 :: proc(v: f32) -> f32 {
	if math.is_nan(v) || math.is_inf(v) || abs(v) < 0.00005 {
		return 0.0
	}
	return v
}

@(private)
category_name :: proc(cat: spec.Model_Category) -> string {
	switch cat {
	case .Units:
		return "Units"
	case .Trees:
		return "Trees"
	case .Props:
		return "Props"
	}
	return "Props"
}

@(private)
write_escaped_str :: proc(sb: ^strings.Builder, s: string) {
	for i in 0..<len(s) {
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
	for i in 0..<len(raw) {
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
		strings.write_string(&sb, "model")
	}
	return strings.to_string(sb)
}
