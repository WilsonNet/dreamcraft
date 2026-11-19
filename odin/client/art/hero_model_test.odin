package art

import "core:testing"

@(test)
hero_mamluk_uses_gilded_royal_palette_and_builds_clean_mesh :: proc(t: ^testing.T) {
	regular := palette_for_unit(false, false)
	hero := palette_for_unit(false, true)
	testing.expect(t, !regular.hero)
	testing.expect(t, hero.hero)
	testing.expect(t, hero.cream.r > regular.cream.r)

	mesh := build_mamluk(false, true)
	defer mb_delete(&mesh)
	testing.expect(t, !mesh.overflow)
	testing.expect(t, mesh.palette.hero)
	testing.expect(t, mb_vertex_count(&mesh) > 0)
	testing.expect(t, mb_triangle_count(&mesh) > 0)
}
