// rlgl-compatible immediate mode and render state on top of gfx (subset DreamCraft uses).
package rlgl

import gfx ".."

LINES :: gfx.IM_LINES
TRIANGLES :: gfx.IM_TRIANGLES
QUADS :: gfx.IM_QUADS

Begin :: proc(mode: int) {
	gfx.im_begin(mode)
}

End :: proc() {
	gfx.im_end()
}

Vertex3f :: proc(x, y, z: f32) {
	gfx.im_vertex({x, y, z})
}

Vertex2f :: proc(x, y: f32) {
	gfx.im_vertex({x, y, 0})
}

Color4ub :: proc(r, g, b, a: u8) {
	gfx.im_color({r, g, b, a})
}

TexCoord2f :: proc(u, v: f32) {
	gfx.im_texcoord(u, v)
}

EnableDepthTest :: proc() {
	gfx.set_depth_test(true)
}

DisableDepthTest :: proc() {
	gfx.set_depth_test(false)
}

EnableDepthMask :: proc() {
	gfx.set_depth_write(true)
}

DisableDepthMask :: proc() {
	gfx.set_depth_write(false)
}

EnableBackfaceCulling :: proc() {
	gfx.set_cull(true)
}

DisableBackfaceCulling :: proc() {
	gfx.set_cull(false)
}

// Draws are recorded and replayed at EndDrawing, so there is no batch to flush.
DrawRenderBatchActive :: proc() {}
