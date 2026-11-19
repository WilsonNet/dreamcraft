// Root orchestrator for compiled declarative Odin mesh assets.
package art_models

import spec "../spec"

BUILTIN_ASSETS := []spec.Model_Asset_Def{}

find_builtin_asset :: proc(id: string) -> (spec.Model_Asset_Def, bool) {
	for def in BUILTIN_ASSETS {
		if def.id == id {
			return def, true
		}
	}
	return {}, false
}
