// Animated low-poly warrior models.
//
// The GLBs are exported from tools/warrior/build_warrior.py with three
// actions: idle, walk, attack. Each unit gets its own model instance so units
// can play different animations at the same time.
package main

import "core:c"
import "core:math"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import g "../game"

WARRIOR_IDLE_SECONDS :: f32(1.375)
WARRIOR_WALK_SECONDS :: f32(0.708333)
WARRIOR_ATTACK_SECONDS :: f32(0.458333)
WARRIOR_SCALE :: f32(1.2)

Unit_Visual :: struct {
	handle: g.Unit_Handle,
	angle: f32,
	clock: f32,
	attack: f32,
	prev_cooldown: u16,
}

Unit_Model :: struct {
	loaded: bool,
	team: g.Team,
	model: rl.Model,
	anims: [^]rl.ModelAnimation,
	anim_count: c.int,
	idle_index: int,
	walk_index: int,
	attack_index: int,
	idle_frames: int,
	walk_frames: int,
	attack_frames: int,
}

init_warrior_assets :: proc() {
	units := &app.game.units
	for i in 0..<g.MAX_UNITS {
		if units.alive[i] {
			ensure_unit_model(i)
		}
	}
}

unload_warrior_assets :: proc() {
	for &unit_model in app.models {
		if !unit_model.loaded {
			continue
		}
		if unit_model.anim_count > 0 && unit_model.anims != nil {
			rl.UnloadModelAnimations(unit_model.anims, unit_model.anim_count)
		}
		rl.UnloadModel(unit_model.model)
		unit_model = {}
	}
}

reset_warrior_visuals :: proc() {
	for &visual in app.visuals {
		visual = {}
	}
	app.last_tick = 0
}

ensure_unit_model :: proc(index: int) {
	unit_model := &app.models[index]
	team := app.game.units.team[index]
	if unit_model.loaded && unit_model.team == team {
		return
	}
	if unit_model.loaded {
		if unit_model.anim_count > 0 && unit_model.anims != nil {
			rl.UnloadModelAnimations(unit_model.anims, unit_model.anim_count)
		}
		rl.UnloadModel(unit_model.model)
		unit_model^ = {}
	}
	path := warrior_model_path(team)
	if path == nil {
		return
	}
	model := rl.LoadModel(path)
	if model.meshCount == 0 {
		return
	}
	count: c.int
	anims := rl.LoadModelAnimations(path, &count)
	if count <= 0 || anims == nil {
		rl.UnloadModel(model)
		return
	}
	unit_model.model = model
	unit_model.anims = anims
	unit_model.anim_count = count
	unit_model.team = team
	unit_model.loaded = true
	unit_model.idle_index = find_animation(anims, count, "idle")
	unit_model.walk_index = find_animation(anims, count, "walk")
	unit_model.attack_index = find_animation(anims, count, "attack")
	unit_model.idle_frames = animation_frames(anims, count, unit_model.idle_index)
	unit_model.walk_frames = animation_frames(anims, count, unit_model.walk_index)
	unit_model.attack_frames = animation_frames(anims, count, unit_model.attack_index)
}

warrior_model_path :: proc(team: g.Team) -> cstring {
	file := "warrior_blue.glb"
	if team == .Enemy {
		file = "warrior_red.glb"
	}
	candidates := [2]string{"assets/warrior/", "odin/assets/warrior/"}
	for prefix in candidates {
		path := strings.concatenate({prefix, file}, context.temp_allocator)
		if os.exists(path) {
			return strings.clone_to_cstring(path, context.temp_allocator)
		}
	}
	return nil
}

find_animation :: proc(anims: [^]rl.ModelAnimation, count: c.int, name: string) -> int {
	for i in 0..<int(count) {
		anim_name := strings.clone_from_cstring(cast(cstring)&anims[i].name[0], context.temp_allocator)
		if anim_name == name {
			return i
		}
	}
	return -1
}

animation_frames :: proc(anims: [^]rl.ModelAnimation, count: c.int, index: int) -> int {
	if index < 0 || index >= int(count) {
		return 0
	}
	return int(anims[index].keyframeCount)
}

update_warrior_visuals :: proc(dt: f32) {
	units := &app.game.units
	if app.game.tick < app.last_tick {
		reset_warrior_visuals()
	}
	app.last_tick = app.game.tick
	for i in 0..<g.MAX_UNITS {
		visual := &app.visuals[i]
		if !units.alive[i] {
			visual^ = {}
			continue
		}
		ensure_unit_model(i)
		handle := g.unit_handle(units, i)
		if visual.handle != handle {
			visual^ = Unit_Visual{
				handle = handle,
				angle = visual.angle,
				prev_cooldown = units.cooldown[i],
			}
		}
		visual.clock += dt
		if units.cooldown[i] > visual.prev_cooldown {
			visual.attack = WARRIOR_ATTACK_SECONDS
		}
		visual.prev_cooldown = units.cooldown[i]
		if visual.attack > 0 {
			visual.attack = max(0, visual.attack - dt)
			if target, ok := g.unit_index(units, units.attack_target[i]); ok {
				visual.angle = angle_toward(units.position[target], units.position[i], visual.angle)
			}
		} else if g.unit_has_path(units, i) {
			visual.angle = path_angle(units, i, visual.angle)
		}
		update_unit_animation(i)
	}
}

path_angle :: proc(units: ^g.Units, index: int, fallback: f32) -> f32 {
	for p in int(units.path_index[index])..<int(units.path_len[index]) {
		cell := g.cell_position(int(units.path[index][p]))
		if g.cells_equal(cell, units.position[index]) {
			continue
		}
		return angle_toward(cell, units.position[index], fallback)
	}
	return fallback
}

// glTF model faces +Z at angle 0. Grid +Y is +Z, grid +X is +X.
angle_toward :: proc(target, origin: g.Grid_Pos, fallback: f32) -> f32 {
	dx := target.x - origin.x
	dy := target.y - origin.y
	if dx == 0 && dy == 0 {
		return fallback
	}
	return math.atan2(f32(dx), f32(dy)) * 180.0 / math.PI
}

update_unit_animation :: proc(index: int) {
	model := &app.models[index]
	visual := &app.visuals[index]
	if !model.loaded || model.anim_count <= 0 {
		return
	}
	anim_index := model.idle_index
	seconds := WARRIOR_IDLE_SECONDS
	frames := model.idle_frames
	if visual.attack > 0 {
		anim_index = model.attack_index
		seconds = WARRIOR_ATTACK_SECONDS
		frames = model.attack_frames
	} else if g.unit_has_path(&app.game.units, index) {
		anim_index = model.walk_index
		seconds = WARRIOR_WALK_SECONDS
		frames = model.walk_frames
	}
	if anim_index < 0 || frames <= 0 {
		return
	}
	elapsed := visual.clock
	if visual.attack > 0 {
		elapsed = WARRIOR_ATTACK_SECONDS - visual.attack
	} else {
		elapsed = math.mod(visual.clock, seconds)
	}
	frame := elapsed / seconds * f32(frames - 1)
	rl.UpdateModelAnimation(model.model, model.anims[anim_index], frame)
}

draw_warrior_model :: proc(index: int, position: rl.Vector3) -> bool {
	model := &app.models[index]
	if !model.loaded {
		return false
	}
	angle := app.visuals[index].angle
	rl.DrawModelEx(model.model, position, rl.Vector3{0, 1, 0}, angle, rl.Vector3{WARRIOR_SCALE, WARRIOR_SCALE, WARRIOR_SCALE}, rl.WHITE)
	return true
}
