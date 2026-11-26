// Shared art pipeline schema for declarative keyframe animation clips.
package art_spec

Anim_Interp :: enum u8 {
	Linear,
	Smooth,
	Step,
	Ease_In,
	Ease_Out,
}

Anim_Handle :: enum u8 {
	Auto_Clamped,
	Auto,
	Aligned,
	Free,
	Vector,
}

Anim_Category :: enum u8 {
	Base,
	Hero,
	Enemy,
}

Anim_Kind :: enum u8 {
	Idle,
	Walk,
	Attack,
}

Anim_Bone_Rot :: struct {
	bone: Bone_Id,
	rot:  [3]f32,
}

Anim_Handle_Def :: struct {
	bone:   Bone_Id, // .COUNT denotes root_offset channel
	axis:   u8,
	handle: Anim_Handle,
	in_h:   [2]f32,
	out_h:  [2]f32,
}

Anim_Keyframe_Def :: struct {
	time:        f32,
	interp:      Anim_Interp,
	root_offset: [3]f32,
	bones:       []Anim_Bone_Rot,
	handles:     []Anim_Handle_Def,
}

Anim_Clip_Def :: struct {
	id:               string,
	title:            string,
	duration:         f32,
	loop:             bool,
	additive:         bool,
	secondary_weight: f32,
	keyframe_chunks:  [][]Anim_Keyframe_Def,
}

INTERP_NAMES := [Anim_Interp]string {
	.Linear   = "Linear",
	.Smooth   = "Smooth",
	.Step     = "Step",
	.Ease_In  = "Ease_In",
	.Ease_Out = "Ease_Out",
}

HANDLE_NAMES := [Anim_Handle]string {
	.Auto_Clamped = "Auto_Clamped",
	.Auto         = "Auto",
	.Aligned      = "Aligned",
	.Free         = "Free",
	.Vector       = "Vector",
}

interp_from_name :: proc(name: string) -> (Anim_Interp, bool) {
	for n, kind in INTERP_NAMES {
		if n == name {
			return kind, true
		}
	}
	return .Smooth, false
}

handle_from_name :: proc(name: string) -> (Anim_Handle, bool) {
	for n, kind in HANDLE_NAMES {
		if n == name {
			return kind, true
		}
	}
	return .Auto_Clamped, false
}
