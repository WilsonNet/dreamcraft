// Optional vinland-ui hot reload (`vui-hot`, see ../../vinland-ui/tools/vui-hot).
//
// The client owns its window through `gfx`, so it runs under vui-hot as a "classic loop": when a
// newer build is ready, `hot_reload_pending` ends the frame loop, `main`'s defers close the window
// and the control server, and the new build starts again with the kept simulation and zoom (the
// camera re-centres on the hero). In a normal `odin build` none of this runs: `vapp.keep` is a
// no-op and `hot_reload_pending` is always false.
package main

import vapp "vinland:vui/app"
import vhot "vinland:vui/hot"

// Carry the simulation (tick, units, fog, quest progress) and zoom over a reload. Call after
// `g.game_init` and `init_world_assets` so restored values win over the defaults.
hot_keep_state :: proc() {
	if !vapp.is_hot() {
		return
	}
	vapp.keep(&app.game)
	if vapp.keep(&app.zoom) {
		app.target_zoom = app.zoom
	}
	reset_camera() // re-centre on the restored hero
}

hot_reload_pending :: proc() -> bool {
	h := vapp.hot_host()
	return h != nil && vhot.reload_requested(h)
}
