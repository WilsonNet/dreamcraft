// Playwright-style Cooperative Mesh CLI tool (zero saved scripts, positive/negative assertions).
package mesh_cli

import "core:fmt"
import "core:net"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import art "../../client/art"
import edit "../../client/art/edit"

Cli_Opts :: struct {
	root:             string,
	root_overridden:  bool,
	json:             bool,
	force_procedural: bool,
	save:             bool,
	dry_run:          bool,
	expect_fail:      bool,
	notify_port:      int,
	help:             bool,
	show_bones:       bool,
	show_mats:        bool,
	show_bounds:      bool,
	show_parts:       bool,
	pos:              [dynamic]string,
}

main :: proc() {
	code := run_cli(os.args[1:])
	if code != 0 { os.exit(code) }
}

run_cli :: proc(args: []string) -> int {
	defer free_all(context.temp_allocator)
	opts, parse_err := parse_cli_opts(args)
	defer delete(opts.pos)
	if parse_err != "" {
		fmt.eprintfln("error: %s", parse_err)
		delete(parse_err)
		return 2
	}
	if opts.help || len(opts.pos) == 0 {
		print_help()
		return 0
	}
	cmd := opts.pos[0]
	switch cmd {
	case "help":            print_help(); return 0
	case "list":            return cmd_list(&opts)
	case "extract":         return cmd_extract(&opts)
	case "info":            return cmd_info(&opts)
	case "assert":          return cmd_assert(&opts)
	case "do", "edit":      return cmd_do(&opts)
	}
	fmt.eprintfln("error: unknown subcommand '%s' (run --help)", cmd)
	return 2
}

@(private)
parse_cli_opts :: proc(args: []string) -> (Cli_Opts, string) {
	opts: Cli_Opts
	if def_root, ok := art.resolve_models_root(); ok { opts.root = def_root }
	for a in args {
		if strings.has_prefix(a, "--root=") {
			opts.root = a[7:]; opts.root_overridden = true
		} else if strings.has_prefix(a, "--notify=") {
			p, p_ok := strconv.parse_int(a[9:], 10)
			if !p_ok || p <= 0 || p > 65535 { return opts, fmt.aprintf("invalid notify port '%s'", a[9:]) }
			opts.notify_port = p
		} else if !apply_flag_opt(&opts, a) {
			if strings.has_prefix(a, "--") { return opts, fmt.aprintf("unknown flag '%s'", a) }
			append(&opts.pos, a)
		}
	}
	return opts, ""
}

@(private)
apply_flag_opt :: proc(opts: ^Cli_Opts, a: string) -> bool {
	switch a {
	case "--help", "-h":      opts.help = true
	case "--json":            opts.json = true
	case "--force-procedural": opts.force_procedural = true
	case "--save":            opts.save = true
	case "--dry-run":         opts.dry_run = true
	case "--expect-fail":     opts.expect_fail = true
	case "--bones":           opts.show_bones = true
	case "--mats":            opts.show_mats = true
	case "--bounds":          opts.show_bounds = true
	case "--parts":           opts.show_parts = true
	case:                     return false
	}
	return true
}

@(private)
print_help :: proc() {
	fmt.println(`dreamcraft-mesh — Cooperative Mesh Authoring & Assertion CLI

Usage:
  dreamcraft-mesh [flags] <subcommand> [args...]

Subcommands:
  list                                   List all 12 catalog models & custom status
  extract <model>                        Export model to git-friendly .odin chunks
  info <model> [--bones|--mats|--bounds|--parts]
  assert <model> <check1> [check2...]    Positive/negative checks (!negates, --expect-fail)
  do|edit <model> [op1 op2 ...]          Transactional ops + inline expect:<check> (or stdin '-')

Flags:
  --root=<dir>  --json  --force-procedural  --save  --dry-run  --expect-fail  --notify=<port>

Ops: select-{all,none,invert,mode,bone,mat,group,above,below,box,linked}
     translate:dx,dy,dz[:mirror]  rotate:ax,ay,az:deg[:pivot=..][:mirror]
     scale:f[:axis=..][:pivot=..][:mirror]  snap-ground
     set-{mat,bone,smooth,group}  extrude:d  inset:f  loop-cut:e[:cuts][:slide]
     fill  merge[:dist]  delete:{verts,edges,faces}
     add-{box,cone,cylinder,lathe,ellipsoid,torus}:pos=x,y,z:...  expect:<expr>
Checks: verts|faces|quads{>=,<=,==}N  min_y|max_y|height|max_r{>=,<=}F
        has_bone=B  has_mat=M  not_has_mat=M  {mat,bone}_{min,max}_y=K:F  manifold  odin_valid`)
}

@(private)
load_model_for_cli :: proc(id: string, opts: ^Cli_Opts) -> (edit.Edit_Mesh, bool, string) {
	entry, ok := art.catalog_find(id)
	if !ok { return {}, false, fmt.aprintf("unknown model '%s'", id) }
	if !opts.force_procedural && len(opts.root) > 0 {
		if edit.has_saved_odin_model(opts.root, id) {
			return load_odin_entry(opts.root, id, entry, false)
		}
		if entry.base_fallback != "" && edit.has_saved_odin_model(opts.root, entry.base_fallback) {
			return load_odin_entry(opts.root, entry.base_fallback, entry, true)
		}
	}
	force := opts.force_procedural || opts.root_overridden
	em, load_ok := art.catalog_load_edit_mesh(id, force)
	if !load_ok { return {}, false, fmt.aprintf("failed to load model '%s'", id) }
	return em, true, ""
}

@(private)
load_odin_entry :: proc(root, dir_id: string, entry: art.Catalog_Entry, relabel: bool) -> (edit.Edit_Mesh, bool, string) {
	dir := fmt.aprintf("%s/%s", strings.trim_right(root, "/\\"), dir_id)
	defer delete(dir)
	em, ok := edit.edit_mesh_load_odin_dir(dir)
	if !ok { return {}, false, fmt.aprintf("failed loading .odin from '%s'", dir) }
	if relabel {
		delete(em.id); delete(em.title)
		em.id, em.title = strings.clone(entry.id), strings.clone(entry.title)
		em.category, em.skinned = entry.category, entry.skinned
		em.ao_height, em.default_scale, em.glow_override = entry.ao_height, entry.default_scale, entry.glow_override
	}
	return em, true, ""
}

@(private)
notify_reload_models :: proc(port: int) -> (bool, string) {
	if port <= 0 { return true, "" }
	sock, err := net.dial_tcp(net.Endpoint{address = net.IP4_Loopback, port = port})
	if err != nil { return false, fmt.aprintf("notify 127.0.0.1:%d failed: %v", port, err) }
	defer net.close(sock)
	_ = net.set_option(sock, .Send_Timeout, 250 * time.Millisecond)
	_ = net.set_option(sock, .Receive_Timeout, 250 * time.Millisecond)
	body := `{"cmd":"reload_models"}`
	req_buf: [256]u8
	req := fmt.bprintf(
		req_buf[:],
		"POST /command HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
		port, len(body), body,
	)
	if _, send_err := net.send_tcp(sock, transmute([]byte)req); send_err != .None {
		return false, fmt.aprintf("notify send failed: %v", send_err)
	}
	resp: [256]u8
	_, _ = net.recv_tcp(sock, resp[:])
	return true, ""
}

@(private)
maybe_notify :: proc(opts: ^Cli_Opts) -> string {
	if opts.notify_port <= 0 { return "" }
	ok, warn := notify_reload_models(opts.notify_port)
	if !ok && !opts.json {
		fmt.eprintfln("warning: %s", warn)
		delete(warn)
		return ""
	}
	return warn
}

@(private)
is_custom_model :: proc(opts: ^Cli_Opts, id: string) -> bool {
	if opts.root_overridden { return edit.has_saved_odin_model(opts.root, id) }
	return art.catalog_has_custom_odin(id)
}

@(private)
cmd_list :: proc(opts: ^Cli_Opts) -> int {
	if opts.json {
		sb := strings.builder_make(); defer strings.builder_destroy(&sb)
		build_list_json(&sb, opts)
		fmt.println(strings.to_string(sb))
		return 0
	}
	fmt.printfln("%-16s %-16s %-7s %-7s %-6s", "ID", "TITLE", "CAT", "SKINNED", "CUSTOM")
	for e in art.MODEL_CATALOG {
		fmt.printfln("%-16s %-16s %-7v %-7v %-6v", e.id, e.title, e.category, e.skinned, is_custom_model(opts, e.id))
	}
	return 0
}

@(private)
build_list_json :: proc(sb: ^strings.Builder, opts: ^Cli_Opts) {
	strings.write_byte(sb, '[')
	for e, i in art.MODEL_CATALOG {
		if i > 0 { strings.write_byte(sb, ',') }
		fmt.sbprintf(sb, `{{"id":"%s","title":`, e.id)
		json_write_str(sb, e.title)
		fmt.sbprintf(sb, `,"category":"%v","skinned":%v,"scale":%.2f,"custom":%v}}`, e.category, e.skinned, e.default_scale, is_custom_model(opts, e.id))
	}
	strings.write_byte(sb, ']')
}

@(private)
cmd_extract :: proc(opts: ^Cli_Opts) -> int {
	if len(opts.pos) < 2 { fmt.eprintln("error: extract requires <model>"); return 2 }
	em, ok, load_err := load_model_for_cli(opts.pos[1], opts)
	if !ok { fmt.eprintfln("error: %s", load_err); delete(load_err); return 1 }
	defer edit.edit_mesh_delete(&em)
	if len(opts.root) == 0 { fmt.eprintln("error: models root not found (use --root=...)"); return 1 }

	dir := ""
	if !opts.dry_run {
		save_ok: bool
		if dir, save_ok = edit.edit_mesh_save_odin(&em, opts.root); !save_ok {
			fmt.eprintfln("error: failed writing .odin to '%s'", opts.root)
			return 1
		}
	}
	defer if dir != "" { delete(dir) }
	warn := opts.dry_run ? "" : maybe_notify(opts)
	defer if warn != "" { delete(warn) }
	s := compute_mesh_stats(&em); defer mesh_stats_delete(&s)
	if opts.json {
		sb := strings.builder_make(); defer strings.builder_destroy(&sb)
		fmt.sbprintf(&sb, `{{"ok":true,"id":"%s","path":`, em.id)
		json_write_str(&sb, dir)
		fmt.sbprintf(&sb, `,"verts":%d,"faces":%d,"quads":%d,"tris":%d,"dry_run":%v}}`, s.verts, s.faces, s.quads, s.tris, opts.dry_run)
		fmt.println(strings.to_string(sb))
	} else {
		fmt.printfln("extracted %s -> %s (%d verts, %d faces, %d quads, %d tris)", em.id, opts.dry_run ? "(dry-run)" : dir, s.verts, s.faces, s.quads, s.tris)
	}
	return 0
}

@(private)
cmd_info :: proc(opts: ^Cli_Opts) -> int {
	if len(opts.pos) < 2 { fmt.eprintln("error: info requires <model>"); return 2 }
	em, ok, load_err := load_model_for_cli(opts.pos[1], opts)
	if !ok { fmt.eprintfln("error: %s", load_err); delete(load_err); return 1 }
	defer edit.edit_mesh_delete(&em)
	s := compute_mesh_stats(&em); defer mesh_stats_delete(&s)
	if opts.json { print_info_json(&em, &s); return 0 }

	all := !opts.show_bones && !opts.show_mats && !opts.show_bounds && !opts.show_parts
	fmt.printfln("model: %s (%s) verts=%d edges=%d faces=%d quads=%d tris=%d", em.id, em.title, s.verts, s.edges, s.faces, s.quads, s.tris)
	if all || opts.show_bounds {
		fmt.printfln("bounds: min=[%.4f, %.4f, %.4f] max=[%.4f, %.4f, %.4f] max_r=%.4f radius=%.4f",
			s.min_p[0], s.min_p[1], s.min_p[2], s.max_p[0], s.max_p[1], s.max_p[2], s.max_r, s.radius)
	}
	if all || opts.show_parts { fmt.printfln("groups: %v", s.groups[:]) }
	if all || opts.show_bones { print_active_bones(&s) }
	if all || opts.show_mats { print_active_mats(&s) }
	return 0
}

@(private)
cmd_assert :: proc(opts: ^Cli_Opts) -> int {
	if len(opts.pos) < 3 { fmt.eprintln("error: assert requires <model> <check1> ..."); return 2 }
	em, ok, load_err := load_model_for_cli(opts.pos[1], opts)
	if !ok { fmt.eprintfln("error: %s", load_err); delete(load_err); return 1 }
	defer edit.edit_mesh_delete(&em)

	results := make([dynamic]Assert_Result, 0, len(opts.pos) - 2)
	defer assert_results_delete(&results)
	all_pass := true
	for chk in opts.pos[2:] {
		r := eval_assert(&em, chk)
		if !r.passed { all_pass = false }
		append(&results, r)
	}
	exit_ok := opts.expect_fail ? !all_pass : all_pass
	if opts.json {
		sb := strings.builder_make(); defer strings.builder_destroy(&sb)
		fmt.sbprintf(&sb, `{{"ok":%v,"expect_fail":%v,"all_passed":%v,"checks":`, exit_ok, opts.expect_fail, all_pass)
		write_assert_results_json(&sb, results[:])
		strings.write_byte(&sb, '}')
		fmt.println(strings.to_string(sb))
	} else {
		fmt.printfln("assert %s: %s (expect_fail=%v)", em.id, exit_ok ? "OK" : "FAILED", opts.expect_fail)
		print_assert_results_text(results[:])
	}
	return exit_ok ? 0 : 1
}

@(private)
cmd_do :: proc(opts: ^Cli_Opts) -> int {
	if len(opts.pos) < 2 { fmt.eprintln("error: do requires <model> [ops...]"); return 2 }
	em, ok, load_err := load_model_for_cli(opts.pos[1], opts)
	if !ok { fmt.eprintfln("error: %s", load_err); delete(load_err); return 1 }
	defer edit.edit_mesh_delete(&em)

	stdin_ops: [dynamic]string
	defer { for s in stdin_ops { delete(s) }; delete(stdin_ops) }
	op_tokens := opts.pos[2:]
	if len(op_tokens) == 0 || (len(op_tokens) == 1 && op_tokens[0] == "-") {
		raw, read_err := os.read_entire_file(os.stdin, context.allocator)
		if read_err != nil { fmt.eprintln("error: failed reading stdin"); return 1 }
		defer delete(raw)
		stdin_ops = split_op_batch(string(raw))
		op_tokens = stdin_ops[:]
	}
	if len(op_tokens) == 0 { fmt.eprintln("error: no operations provided"); return 2 }

	report := make([dynamic]Assert_Result)
	defer assert_results_delete(&report)
	changed, op_err := run_cli_ops(&em, op_tokens, &report)
	defer if op_err != "" { delete(op_err) }
	return finalize_do(opts, &em, changed, op_err, report[:])
}

@(private)
finalize_do :: proc(opts: ^Cli_Opts, em: ^edit.Edit_Mesh, changed: bool, op_err: string, report: []Assert_Result) -> int {
	ops_ok := op_err == ""
	saved := false
	save_dir := ""
	defer if save_dir != "" { delete(save_dir) }

	if ops_ok && !opts.dry_run && !opts.expect_fail && (opts.save || changed) {
		if len(opts.root) == 0 {
			fmt.eprintln("error: models root not found (use --root=...)")
			return 1
		}
		save_ok: bool
		if save_dir, save_ok = edit.edit_mesh_save_odin(em, opts.root); !save_ok {
			fmt.eprintfln("error: failed saving .odin to '%s'", opts.root)
			return 1
		}
		saved = true
		warn := maybe_notify(opts)
		if warn != "" { delete(warn) }
	}
	exit_ok := opts.expect_fail ? !ops_ok : ops_ok
	if opts.json {
		sb := strings.builder_make(); defer strings.builder_destroy(&sb)
		fmt.sbprintf(&sb, `{{"ok":%v,"ops_ok":%v,"changed":%v,"saved":%v,"verts":%d,"faces":%d,"err":`,
			exit_ok, ops_ok, changed, saved, len(em.verts), len(em.faces))
		json_write_str(&sb, op_err)
		strings.write_string(&sb, `,"checks":`)
		write_assert_results_json(&sb, report)
		strings.write_byte(&sb, '}')
		fmt.println(strings.to_string(sb))
	} else {
		fmt.printfln("do %s: %s (changed=%v saved=%v verts=%d faces=%d)", em.id, exit_ok ? "OK" : "FAILED", changed, saved, len(em.verts), len(em.faces))
		if op_err != "" { fmt.printfln("  op_error: %s", op_err) }
		print_assert_results_text(report)
	}
	return exit_ok ? 0 : 1
}
