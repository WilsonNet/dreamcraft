// Root orchestrator for compiled declarative Odin animation clips.
// Individual saved clips live in subpackages under client/art/anims/<id>/
// and register here so release/test builds compile all customizations directly.
package art_anims

import spec "../spec"

BUILTIN_CLIPS := []spec.Anim_Clip_Def{}

find_builtin_clip :: proc(id: string) -> (spec.Anim_Clip_Def, bool) {
	for def in BUILTIN_CLIPS {
		if def.id == id {
			return def, true
		}
	}
	return {}, false
}
