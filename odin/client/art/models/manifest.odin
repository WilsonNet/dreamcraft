// Root orchestrator for compiled declarative Odin mesh assets.
// Individual saved models live in subpackages under client/art/models/<id>/
// and register here so release/test builds compile all customizations directly.
package art_models

import spec "../spec"
import m_mamluk "./mamluk"

BUILTIN_ASSETS := []spec.Model_Asset_Def{
	m_mamluk.ASSET,
}

find_builtin_asset :: proc(id: string) -> (spec.Model_Asset_Def, bool) {
	for def in BUILTIN_ASSETS {
		if def.id == id {
			return def, true
		}
	}
	return {}, false
}
