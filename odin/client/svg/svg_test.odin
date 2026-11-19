#+build !js
package svg

import "core:os"
import "core:strings"
import "core:testing"

@(test)
parse_and_rasterize_shapes_transforms_and_current_color :: proc(t: ^testing.T) {
	src := `
	<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
		<!-- group with transform + override fill -->
		<g transform="translate(2, 2)" fill="#4080ff">
			<rect x="2" y="2" width="16" height="16" rx="3"/>
		</g>
		<line x1="4" y1="12" x2="20" y2="12"/>
	</svg>`
	doc, ok := parse_svg(src)
	defer document_delete(&doc)
	testing.expect(t, ok)
	testing.expect_value(t, len(doc.shapes), 2)

	rgba := render_svg_rgba(&doc, 48, 48, {240, 210, 120, 255})
	defer delete(rgba)
	testing.expect_value(t, len(rgba), 48 * 48 * 4)

	// Center pixel (24, 24) hits the horizontal gold stroke from currentColor.
	mid := (24 * 48 + 24) * 4
	testing.expect(t, rgba[mid + 3] > 230)
	testing.expect(t, rgba[mid + 0] > 200 && rgba[mid + 1] > 180)
	// Corner (0, 0) outside rounded rect stays transparent.
	testing.expect_value(t, rgba[3], u8(0))
}

@(test)
evenodd_cutout_leaves_center_hole_transparent :: proc(t: ^testing.T) {
	src := `
	<svg viewBox="0 0 24 24">
		<path fill="#ffffff" fill-rule="evenodd" d="M2 2 H22 V22 H2 Z M8 8 V16 H16 V8 Z"/>
	</svg>`
	doc, ok := parse_svg(src)
	defer document_delete(&doc)
	testing.expect(t, ok)

	rgba := render_svg_rgba(&doc, 24, 24)
	defer delete(rgba)
	// Outer ring (4, 4) is opaque; center hole (12, 12) is completely transparent.
	outer := (4 * 24 + 4) * 4
	center := (12 * 24 + 12) * 4
	testing.expect_value(t, rgba[outer + 3], u8(255))
	testing.expect_value(t, rgba[center + 3], u8(0))
}

@(test)
arcs_beziers_and_antialiasing_work :: proc(t: ^testing.T) {
	src := `
	<svg viewBox="0 0 24 24" fill="none">
		<path d="M4 12a8 8 0 0114-5.6" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
		<path d="M4 18C8 14 16 22 20 16" stroke="gold" stroke-width="2"/>
		<polygon points="12,2 14,6 10,6" fill="red"/>
	</svg>`
	doc, ok := parse_svg(src)
	defer document_delete(&doc)
	testing.expect(t, ok)
	testing.expect_value(t, len(doc.shapes), 3)

	rgba := render_svg_rgba(&doc, 48, 48)
	defer delete(rgba)
	semi := 0
	opaque := 0
	for i := 3; i < len(rgba); i += 4 {
		a := rgba[i]
		if a > 0 && a < 255 { semi += 1 }
		if a == 255 { opaque += 1 }
	}
	testing.expect(t, opaque > 40)
	testing.expect(t, semi > 20)
}

@(test)
invalid_or_empty_svg_fails_cleanly_without_leaks :: proc(t: ^testing.T) {
	doc, ok := parse_svg("not svg at all")
	defer document_delete(&doc)
	testing.expect(t, !ok)

	empty_buf := render_svg_rgba(&doc, 0, 16)
	testing.expect(t, empty_buf == nil)
}

@(test)
disk_icon_svgs_parse_and_rasterize_cleanly :: proc(t: ^testing.T) {
	dir := "assets/icons"
	if !os.exists(dir) { dir = "odin/assets/icons" }
	if !os.exists(dir) { dir = "../../assets/icons" }
	testing.expect(t, os.exists(dir), "assets/icons folder missing")
	if !os.exists(dir) { return }

	entries, err := os.read_all_directory_by_path(dir, context.allocator)
	testing.expect(t, err == nil)
	defer os.file_info_slice_delete(entries, context.allocator)

	checked := 0
	for entry in entries {
		if !strings.has_suffix(entry.name, ".svg") { continue }
		bytes, r_err := os.read_entire_file(entry.fullpath, context.allocator)
		testing.expect(t, r_err == nil)
		defer delete(bytes)

		doc, p_ok := parse_svg(string(bytes))
		defer document_delete(&doc)
		testing.expect(t, p_ok, entry.name)
		testing.expect(t, len(doc.shapes) > 0, entry.name)

		rgba := render_svg_rgba(&doc, 48, 48, {240, 212, 118, 255})
		defer delete(rgba)
		ink := 0
		for i := 3; i < len(rgba); i += 4 {
			if rgba[i] > 32 { ink += 1 }
		}
		testing.expect(t, ink > 12, entry.name)
		checked += 1
	}
	testing.expect(t, checked >= 37)
}
