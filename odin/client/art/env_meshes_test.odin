#+build !js
package art

import "core:math"
import "core:testing"

@(private)
check_prop_mesh :: proc(t: ^testing.T, b: ^Mesh_Builder) -> (min_y, max_y, max_r: f32) {
	testing.expect(t, !b.overflow)
	testing.expect(t, len(b.pos) > 0)
	testing.expect(t, mb_triangle_count(b) > 0)
	testing.expect_value(t, len(b.pos), len(b.nrm))
	testing.expect_value(t, len(b.pos), len(b.col))
	testing.expect_value(t, len(b.pos), len(b.uv))
	testing.expect_value(t, len(b.idx) % 3, 0)

	min_y = 1e9
	max_y = -1e9
	bad_normal := 0
	bad_finite := 0
	for i in 0..<len(b.pos) {
		p := b.pos[i]
		n := b.nrm[i]
		if math.is_nan(p.x) || math.is_nan(p.y) || math.is_nan(p.z) ||
		   math.is_nan(n.x) || math.is_nan(n.y) || math.is_nan(n.z) {
			bad_finite += 1
		}
		nlen := math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
		if abs(nlen - 1.0) > 0.02 {
			bad_normal += 1
		}
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
		max_r = max(max_r, math.sqrt(p.x * p.x + p.z * p.z))
	}
	testing.expect_value(t, bad_finite, 0)
	testing.expect_value(t, bad_normal, 0)
	return
}

@(test)
tree_variants_tower_within_expected_height_bands :: proc(t: ^testing.T) {
	builders := [4](proc() -> Mesh_Builder){
		build_pine_tall,
		build_pine_mid,
		build_oak_broad,
		build_oak_elder,
	}
	for fn in builders {
		b := fn()
		defer mb_delete(&b)
		min_y, max_y, max_r := check_prop_mesh(t, &b)
		testing.expect(t, min_y >= -0.05)
		testing.expect(t, max_y >= 2.65 && max_y <= 3.45)
		testing.expect(t, max_r <= 1.25)
	}
}

@(test)
rock_and_shrub_props_build_cleanly :: proc(t: ^testing.T) {
	rock := build_boulder_moss()
	defer mb_delete(&rock)
	r_min_y, r_max_y, r_max_r := check_prop_mesh(t, &rock)
	testing.expect(t, r_min_y >= -0.06)
	testing.expect(t, r_max_y >= 0.30 && r_max_y <= 0.48)
	testing.expect(t, r_max_r <= 0.45)

	shrub := build_shrub_fern()
	defer mb_delete(&shrub)
	s_min_y, s_max_y, s_max_r := check_prop_mesh(t, &shrub)
	testing.expect(t, s_min_y >= -0.05)
	testing.expect(t, s_max_y >= 0.34 && s_max_y <= 0.50)
	testing.expect(t, s_max_r <= 0.45)
}

@(test)
waypoint_banner_and_selection_ring_match_specs :: proc(t: ^testing.T) {
	wp := build_waypoint_disc()
	defer mb_delete(&wp)
	wp_min_y, wp_max_y, wp_max_r := check_prop_mesh(t, &wp)
	testing.expect(t, wp_min_y >= -0.01 && wp_max_y < 0.15)
	testing.expect(t, wp_max_r <= 0.52)

	bn := build_goal_banner()
	defer mb_delete(&bn)
	bn_min_y, bn_max_y, bn_max_r := check_prop_mesh(t, &bn)
	testing.expect(t, bn_min_y >= -0.01)
	testing.expect(t, bn_max_y >= 2.45 && bn_max_y <= 2.80)
	testing.expect(t, bn_max_r <= 0.70)

	sr := build_selection_ring()
	defer mb_delete(&sr)
	sr_min_y, sr_max_y, sr_max_r := check_prop_mesh(t, &sr)
	testing.expect(t, sr_min_y >= 0.028 && sr_max_y <= 0.036)
	testing.expect(t, sr_max_r <= 0.55)
	for uv in sr.uv {
		testing.expect(t, abs(uv.y - 0.35) < 0.001)
	}
}
