// Shared art pipeline schema: materials, bone IDs, and declarative mesh assets.
package art_spec

Mat_Kind :: enum u8 {
	Skin,
	Steel,
	Steel_Dark,
	Iron,
	Brass,
	Brass_Dark,
	Mail,
	Leather,
	Leather_Dark,
	Blade,
	Cloth,
	Cloth_Dark,
	Cream,
	Cream_Dark,
	Jet,
	Glow,
	Hair,
	Eye,
	Iris,
	Bark,
	Bark_Dark,
	Leaf_Deep,
	Leaf_Mid,
	Leaf_Sun,
	Leaf_Pine,
	Leaf_Pine_Sun,
	Moss,
	Stone,
	Stone_Dark,
	Banner_Cloth,
	Banner_Gold,
	COUNT,
}

Bone_Id :: enum u8 {
	Root,
	Pelvis,
	Spine,
	Chest,
	Neck,
	Head,
	Plume,
	Shoulder_L,
	Arm_L,
	Forearm_L,
	Hand_L,
	Shoulder_R,
	Arm_R,
	Forearm_R,
	Hand_R,
	Thigh_L,
	Shin_L,
	Foot_L,
	Thigh_R,
	Shin_R,
	Foot_R,
	Cape_1,
	Cape_2,
	Cape_3,
	Sash,
	COUNT,
}

Model_Category :: enum u8 {
	Units,
	Trees,
	Props,
}

Asset_Vert :: struct {
	pos:   [3]f32,
	bone:  Bone_Id,
	ao:    f32,
	group: u16,
}

Asset_Face :: struct {
	v:      [4]u32,
	count:  u8,
	mat:    Mat_Kind,
	smooth: bool,
	group:  u16,
}

Model_Asset_Def :: struct {
	id:            string,
	title:         string,
	category:      Model_Category,
	skinned:       bool,
	ao_height:     f32,
	default_scale: f32,
	glow_override: f32,
	vert_chunks:   [][]Asset_Vert,
	face_chunks:   [][]Asset_Face,
}

MAT_NAMES := [Mat_Kind]string {
	.Skin          = "Skin",
	.Steel         = "Steel",
	.Steel_Dark    = "Steel_Dark",
	.Iron          = "Iron",
	.Brass         = "Brass",
	.Brass_Dark    = "Brass_Dark",
	.Mail          = "Mail",
	.Leather       = "Leather",
	.Leather_Dark  = "Leather_Dark",
	.Blade         = "Blade",
	.Cloth         = "Cloth",
	.Cloth_Dark    = "Cloth_Dark",
	.Cream         = "Cream",
	.Cream_Dark    = "Cream_Dark",
	.Jet           = "Jet",
	.Glow          = "Glow",
	.Hair          = "Hair",
	.Eye           = "Eye",
	.Iris          = "Iris",
	.Bark          = "Bark",
	.Bark_Dark     = "Bark_Dark",
	.Leaf_Deep     = "Leaf_Deep",
	.Leaf_Mid      = "Leaf_Mid",
	.Leaf_Sun      = "Leaf_Sun",
	.Leaf_Pine     = "Leaf_Pine",
	.Leaf_Pine_Sun = "Leaf_Pine_Sun",
	.Moss          = "Moss",
	.Stone         = "Stone",
	.Stone_Dark    = "Stone_Dark",
	.Banner_Cloth  = "Banner_Cloth",
	.Banner_Gold   = "Banner_Gold",
	.COUNT         = "COUNT",
}

BONE_NAMES := [Bone_Id]string {
	.Root       = "Root",
	.Pelvis     = "Pelvis",
	.Spine      = "Spine",
	.Chest      = "Chest",
	.Neck       = "Neck",
	.Head       = "Head",
	.Plume      = "Plume",
	.Shoulder_L = "Shoulder_L",
	.Arm_L      = "Arm_L",
	.Forearm_L  = "Forearm_L",
	.Hand_L     = "Hand_L",
	.Shoulder_R = "Shoulder_R",
	.Arm_R      = "Arm_R",
	.Forearm_R  = "Forearm_R",
	.Hand_R     = "Hand_R",
	.Thigh_L    = "Thigh_L",
	.Shin_L     = "Shin_L",
	.Foot_L     = "Foot_L",
	.Thigh_R    = "Thigh_R",
	.Shin_R     = "Shin_R",
	.Foot_R     = "Foot_R",
	.Cape_1     = "Cape_1",
	.Cape_2     = "Cape_2",
	.Cape_3     = "Cape_3",
	.Sash       = "Sash",
	.COUNT      = "COUNT",
}

mat_from_name :: proc(name: string) -> (Mat_Kind, bool) {
	for n, kind in MAT_NAMES {
		if kind != .COUNT && n == name {
			return kind, true
		}
	}
	return .Skin, false
}

bone_from_name :: proc(name: string) -> (Bone_Id, bool) {
	for n, bone in BONE_NAMES {
		if bone != .COUNT && n == name {
			return bone, true
		}
	}
	return .Root, false
}
