import fs from "node:fs";
import assert from "node:assert/strict";

const bytes = fs.readFileSync(new URL("./main.wasm", import.meta.url));
let exports_ = null;
const imports = {
	odin_env: {
		write() {},
		rand_bytes(ptr, len) {
			new Uint8Array(exports_.memory.buffer, ptr, len).fill(1);
		},
	},
};

const { instance } = await WebAssembly.instantiate(bytes, imports);
exports_ = instance.exports;
exports_._start();
assert.equal(exports_.web_pixels_width(), 640);
assert.equal(exports_.web_pixels_height(), 400);
assert.equal(exports_.web_iso_offset_x(), 260);
assert.equal(exports_.web_iso_offset_y(), 70);
assert.equal(exports_.web_iso_half_w(), 4);
assert.equal(exports_.web_iso_half_h(), 2);

function readString(ptr, len) {
	return new TextDecoder().decode(new Uint8Array(exports_.memory.buffer, ptr, len));
}

function state() {
	exports_.web_refresh_state();
	return JSON.parse(readString(exports_.web_state_ptr(), exports_.web_state_len()));
}

function units() {
	exports_.web_refresh_units();
	return JSON.parse(readString(exports_.web_units_ptr(), exports_.web_units_len()));
}

function fog() {
	exports_.web_refresh_fog();
	return readString(exports_.web_fog_ptr(), exports_.web_fog_len());
}

let s = state();
assert.equal(s.valid, true);
assert.deepEqual(s.player_grid, [2, 25]);
assert.equal(s.game_over, false);
assert.equal(fog().length, 80 * 50 + 50);
assert.match(fog(), /P/);

assert.equal(exports_.web_move(10, 25), 1);
exports_.web_run(140);
s = state();
assert.deepEqual(s.player_grid, [10, 25]);
assert.equal(s.valid, true);

// Re-ordering mid-segment continues forward instead of snapping to the cell.
exports_.web_reset();
assert.equal(exports_.web_move(12, 25), 1);
exports_.web_run(6);
const before = units()[0].world[0];
assert.equal(exports_.web_move(20, 25), 1);
exports_.web_run(1);
const after = units()[0].world[0];
assert.ok(after > before, `reorder snapped back: ${before} -> ${after}`);
assert.equal(state().valid, true);

assert.equal(exports_.web_reset(), 1);
assert.equal(exports_.web_kill(50, 25), 1);
assert.equal(exports_.web_teleport(77, 25), 1);
exports_.web_run(1);
s = state();
assert.equal(s.level_complete, true);
assert.equal(s.valid, true);

exports_.web_reset();
assert.equal(exports_.web_kill(2, 25), 1);
exports_.web_run(1);
s = state();
assert.equal(s.player_alive, false);
assert.equal(s.game_over, true);
assert.equal(s.valid, true);

exports_.web_reset();
assert.equal(exports_.web_spawn(1, 5, 25, 30), 1);
assert.equal(units().length, 3);
assert.equal(exports_.web_set_hp(5, 25, 1), 1);
assert.equal(exports_.web_kill(5, 25), 1);
assert.equal(state().valid, true);

console.log("web wasm smoke passed");
