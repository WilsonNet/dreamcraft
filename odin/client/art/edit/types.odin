// Core editable poly-mesh data structures and small vector helpers for the 3D art pipeline.
package art_edit

import "core:math"
import spec "../spec"

Select_Mode :: enum u8 {
	Vertex,
	Edge,
	Face,
}

Axis_Lock :: enum u8 {
	None,
	X,
	Y,
	Z,
	YZ,
	XZ,
	XY,
}

Edit_Vert :: struct {
	pos:      [3]f32,
	nrm:      [3]f32,
	bone:     spec.Bone_Id,
	ao:       f32,
	group:    u16,
	selected: bool,
}

Edit_Edge :: struct {
	a:        u32,
	b:        u32,
	faces:    [4]u32,
	face_len: u8,
	loose:    bool,
	selected: bool,
}

Edit_Face :: struct {
	v:        [4]u32,
	count:    u8,
	mat:      spec.Mat_Kind,
	smooth:   bool,
	group:    u16,
	nrm:      [3]f32,
	selected: bool,
}

Loose_Edge :: struct {
	a:        u32,
	b:        u32,
	selected: bool,
}

Edit_Mesh :: struct {
	id:            string,
	title:         string,
	category:      spec.Model_Category,
	skinned:       bool,
	ao_height:     f32,
	default_scale: f32,
	glow_override: f32,
	verts:         [dynamic]Edit_Vert,
	faces:         [dynamic]Edit_Face,
	edges:         [dynamic]Edit_Edge,
	loose_edges:   [dynamic]Loose_Edge,
	mode:          Select_Mode,
	dirty:         bool,
}

MAX_UNDO_SNAPSHOTS :: 64

Undo_Snapshot :: struct {
	verts:       []Edit_Vert,
	faces:       []Edit_Face,
	loose_edges: []Loose_Edge,
	mode:        Select_Mode,
}

Undo_Stack :: struct {
	items:  [dynamic]Undo_Snapshot,
	cursor: int,
}

Loop_Cut_Preview :: struct {
	valid:     bool,
	edge_idxs: [dynamic]u32,
	faces:     [dynamic]u32,
	a_verts:   [dynamic]u32,
	b_verts:   [dynamic]u32,
}

Knife_Node_Kind :: enum u8 {
	Vert,
	Edge,
	Face,
}

Knife_Node :: struct {
	kind:  Knife_Node_Kind,
	index: u32,
	t:     f32,
	pos:   [3]f32,
}

edge_key :: proc(a, b: u32) -> u64 {
	lo := min(a, b)
	hi := max(a, b)
	return (u64(lo) << 32) | u64(hi)
}

v3_add :: proc(a, b: [3]f32) -> [3]f32 {
	return {a[0] + b[0], a[1] + b[1], a[2] + b[2]}
}

v3_sub :: proc(a, b: [3]f32) -> [3]f32 {
	return {a[0] - b[0], a[1] - b[1], a[2] - b[2]}
}

v3_scale :: proc(a: [3]f32, s: f32) -> [3]f32 {
	return {a[0] * s, a[1] * s, a[2] * s}
}

v3_lerp :: proc(a, b: [3]f32, t: f32) -> [3]f32 {
	return v3_add(a, v3_scale(v3_sub(b, a), t))
}

v3_dot :: proc(a, b: [3]f32) -> f32 {
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

v3_cross :: proc(a, b: [3]f32) -> [3]f32 {
	return {
		a[1] * b[2] - a[2] * b[1],
		a[2] * b[0] - a[0] * b[2],
		a[0] * b[1] - a[1] * b[0],
	}
}

v3_len_sq :: proc(a: [3]f32) -> f32 {
	return v3_dot(a, a)
}

v3_len :: proc(a: [3]f32) -> f32 {
	return math.sqrt(v3_len_sq(a))
}

v3_norm :: proc(a: [3]f32) -> [3]f32 {
	l := v3_len(a)
	if l < 1e-6 {
		return {0, 1, 0}
	}
	return {a[0] / l, a[1] / l, a[2] / l}
}
