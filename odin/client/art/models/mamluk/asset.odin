package model_mamluk

import spec "../../spec"

V_CHUNKS := [18][]spec.Asset_Vert{
	V_000[:],
	V_001[:],
	V_002[:],
	V_003[:],
	V_004[:],
	V_005[:],
	V_006[:],
	V_007[:],
	V_008[:],
	V_009[:],
	V_010[:],
	V_011[:],
	V_012[:],
	V_013[:],
	V_014[:],
	V_015[:],
	V_016[:],
	V_017[:],
}

F_CHUNKS := [17][]spec.Asset_Face{
	F_000[:],
	F_001[:],
	F_002[:],
	F_003[:],
	F_004[:],
	F_005[:],
	F_006[:],
	F_007[:],
	F_008[:],
	F_009[:],
	F_010[:],
	F_011[:],
	F_012[:],
	F_013[:],
	F_014[:],
	F_015[:],
	F_016[:],
}

ASSET := spec.Model_Asset_Def{
	id            = "mamluk",
	title         = "Mamluk Base",
	category      = .Units,
	skinned       = true,
	ao_height     = 1.6000,
	default_scale = 0.7400,
	glow_override = 0.0000,
	vert_chunks   = V_CHUNKS[:],
	face_chunks   = F_CHUNKS[:],
}
