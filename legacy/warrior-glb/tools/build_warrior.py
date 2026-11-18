# Build the low-poly DreamCraft melee warrior and its animation set.
#
# Run with:  blender --background --python build_warrior.py
# Outputs:
#   build/warrior_blue.glb
#   build/warrior_red.glb
#   build/preview.png
#
# The GLBs contain one skinned mesh set and three actions: idle, walk, attack.
# The native raylib client loads them directly; no sprite atlas.
import bpy, math, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(ROOT, "build")
os.makedirs(BUILD, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color, metallic=0.0, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    m.diffuse_color = (*color, 1)
    return m

M = {
    "steel": mat("Steel", (0.32, 0.38, 0.48), 0.6, 0.45),
    "dark": mat("DarkSteel", (0.14, 0.17, 0.23), 0.5, 0.5),
    "leather": mat("Leather", (0.28, 0.17, 0.09), 0.0, 0.8),
    "skin": mat("Skin", (0.70, 0.49, 0.33), 0.0, 0.8),
    "gold": mat("Gold", (0.78, 0.58, 0.18), 0.7, 0.35),
    "blade": mat("Blade", (0.72, 0.77, 0.84), 0.8, 0.3),
    "cloth": mat("Cloth", (0.12, 0.30, 0.72), 0.0, 0.85),
    "ground": mat("Ground", (0.07, 0.13, 0.08), 0.0, 0.95),
}

def cube(name, loc, size, material, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = o.modifiers.new("bev", 'BEVEL')
        b.width = bevel
        b.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o

def sphere(name, loc, radius, material, seg=10, rings=6, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=radius, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o

def cyl(name, loc, radius, depth, material, verts=8, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o

parts = []
def add(o, bone):
    parts.append((o, bone))
    return o

# Body.
add(cube("torso", (0, 0, 1.02), (0.46, 0.30, 0.40), M["steel"]), "spine")
add(cube("chest", (0, -0.03, 1.15), (0.40, 0.26, 0.16), M["dark"]), "spine")
add(cube("belt", (0, 0, 0.80), (0.40, 0.28, 0.07), M["gold"]), "spine")
add(cube("tabard", (0, -0.15, 0.72), (0.30, 0.04, 0.34), M["cloth"]), "spine")
add(cube("hips", (0, 0, 0.72), (0.34, 0.24, 0.16), M["dark"]), "pelvis")
add(cube("cape", (0, 0.17, 0.95), (0.36, 0.04, 0.50), M["cloth"]), "spine")

for side, x in (("L", -0.14), ("R", 0.14)):
    add(cube("thigh." + side, (x, 0, 0.50), (0.16, 0.17, 0.42), M["leather"]), "leg." + side)
    add(cube("boot." + side, (x, -0.03, 0.16), (0.18, 0.26, 0.30), M["dark"]), "leg." + side)

# Head and helmet.
add(sphere("head", (0, 0, 1.40), 0.20, M["skin"], 10, 6, (1, 0.95, 1.05)), "head")
add(cube("nose", (0, -0.19, 1.40), (0.07, 0.05, 0.07), M["skin"]), "head")
add(cyl("helm", (0, 0, 1.47), 0.235, 0.20, M["steel"], 10), "head")
add(sphere("helm_top", (0, 0, 1.55), 0.235, M["steel"], 10, 4, (1, 1, 0.5)), "head")
add(cube("helm_nose", (0, -0.21, 1.42), (0.05, 0.05, 0.16), M["steel"]), "head")
add(cube("crest", (0, 0.02, 1.65), (0.06, 0.18, 0.16), M["cloth"]), "head")

# Arms.
for side, x in (("L", -0.32), ("R", 0.32)):
    add(sphere("shoulder." + side, (x, 0, 1.22), 0.15, M["steel"], 8, 5, (1, 0.9, 0.9)), "arm." + side)
    add(cube("arm." + side, (x, 0, 1.00), (0.14, 0.14, 0.36), M["steel"]), "arm." + side)
    add(cube("bracer." + side, (x, 0, 0.84), (0.16, 0.16, 0.10), M["leather"]), "arm." + side)
    add(cube("hand." + side, (x, 0, 0.74), (0.13, 0.13, 0.12), M["skin"]), "arm." + side)

add(cyl("shield", (-0.38, -0.08, 1.00), 0.27, 0.06, M["dark"], 10, (math.radians(90), 0, 0)), "arm.L")
add(cyl("shield_boss", (-0.38, -0.12, 1.00), 0.10, 0.08, M["cloth"], 8, (math.radians(90), 0, 0)), "arm.L")
add(cube("sword_blade", (0.38, -0.10, 1.30), (0.06, 0.025, 0.62), M["blade"]), "arm.R")
add(cube("sword_tip", (0.38, -0.10, 1.64), (0.04, 0.02, 0.10), M["blade"]), "arm.R")
add(cube("sword_guard", (0.38, -0.10, 0.98), (0.22, 0.05, 0.05), M["gold"]), "arm.R")
add(cube("sword_grip", (0.38, -0.10, 0.90), (0.05, 0.05, 0.14), M["leather"]), "arm.R")
add(cube("sword_pommel", (0.38, -0.10, 0.82), (0.08, 0.08, 0.05), M["gold"]), "arm.R")

# Rig: rigid vertex groups, one bone per low-poly part.
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.object
arm.name = "WarriorRig"
eb = arm.data.edit_bones
for b in list(eb):
    eb.remove(b)

def bone(name, head, tail, parent=None):
    b = eb.new(name)
    b.head = head
    b.tail = tail
    b.parent = parent
    b.use_connect = False
    return b

root = bone("root", (0, 0, 0), (0, 0, 0.2))
pelvis = bone("pelvis", (0, 0, 0.68), (0, 0, 0.82), root)
spine = bone("spine", (0, 0, 0.82), (0, 0, 1.22), pelvis)
head = bone("head", (0, 0, 1.22), (0, 0, 1.62), spine)
arm_l = bone("arm.L", (-0.32, 0, 1.22), (-0.34, 0, 0.74), spine)
arm_r = bone("arm.R", (0.32, 0, 1.22), (0.34, 0, 0.74), spine)
leg_l = bone("leg.L", (-0.14, 0, 0.70), (-0.14, 0, 0.08), pelvis)
leg_r = bone("leg.R", (0.14, 0, 0.70), (0.14, 0, 0.08), pelvis)
bpy.ops.object.mode_set(mode='OBJECT')

for o, bone_name in parts:
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    vg = o.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()

for pb in arm.pose.bones:
    pb.rotation_mode = 'XYZ'

def reset_pose():
    arm.location = (0, 0, 0)
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)

def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

def set_idle(t):
    reset_pose()
    s = math.sin(t * math.tau)
    arm.pose.bones["spine"].rotation_euler.x = 0.03 * s
    arm.pose.bones["head"].rotation_euler.x = -0.02 * s
    arm.pose.bones["arm.R"].rotation_euler.x = 0.05 + 0.03 * s
    arm.pose.bones["arm.L"].rotation_euler.x = -0.05 - 0.02 * s

def set_walk(t):
    reset_pose()
    s = math.sin(t * math.tau)
    c = math.cos(t * math.tau)
    arm.pose.bones["leg.L"].rotation_euler.x = 0.55 * s
    arm.pose.bones["leg.R"].rotation_euler.x = -0.55 * s
    arm.pose.bones["arm.L"].rotation_euler.x = -0.45 * s
    arm.pose.bones["arm.R"].rotation_euler.x = 0.35 * s
    arm.pose.bones["spine"].rotation_euler.x = 0.06 + 0.02 * c
    arm.pose.bones["head"].rotation_euler.x = -0.04
    arm.location.z = 0.025 * abs(s)

def set_attack(t):
    reset_pose()
    if t < 0.35:
        k = smooth(t / 0.35)
        arm.pose.bones["arm.R"].rotation_euler.x = -1.2 * k
        arm.pose.bones["arm.R"].rotation_euler.z = -0.9 * k
        arm.pose.bones["spine"].rotation_euler.z = 0.2 * k
        arm.pose.bones["head"].rotation_euler.z = 0.1 * k
    elif t < 0.6:
        k = smooth((t - 0.35) / 0.25)
        arm.pose.bones["arm.R"].rotation_euler.x = -1.2 + 2.2 * k
        arm.pose.bones["arm.R"].rotation_euler.z = -0.9 + 0.75 * k
        arm.pose.bones["spine"].rotation_euler.z = 0.2 - 0.55 * k
        arm.pose.bones["head"].rotation_euler.z = 0.1 - 0.2 * k
    else:
        k = smooth((t - 0.6) / 0.4)
        arm.pose.bones["arm.R"].rotation_euler.x = 1.0 * (1 - k)
        arm.pose.bones["arm.R"].rotation_euler.z = -0.15 * (1 - k)
        arm.pose.bones["spine"].rotation_euler.z = -0.35 * (1 - k)
        arm.pose.bones["head"].rotation_euler.z = -0.1 * (1 - k)

# Camera: 45 degree yaw, 30 degree elevation gives the 2:1 ground ratio.
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.collection.objects.link(cam)
target = Vector((0, 0, 0.95))
cam.location = target + Vector((-1, -1, 0.7071)).normalized() * 7.0
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.25
bpy.context.scene.camera = cam

# Preview ground, hidden while exporting the model.
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
ground = bpy.context.object
ground.name = "PreviewGround"
ground.data.materials.append(M["ground"])
ground.hide_render = True

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = 64
scene.render.resolution_y = 64
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_shadows = False
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = 'BOTH'
scene.display.shading.curvature_ridge_factor = 1.5
scene.display.shading.curvature_valley_factor = 1.2
scene.display.shading.show_object_outline = True
scene.display.shading.object_outline_color = (0.03, 0.03, 0.04)
scene.display.shading.background_type = 'VIEWPORT'
scene.display.shading.background_color = (0.06, 0.10, 0.06)
scene.display.render_aa = 'OFF'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'

# Actions for the glTF animation set.
arm.animation_data_create()
arm.animation_data.action = None
scene.render.fps = 24

def bake_action(name, frames, pose_fn):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    if action.slots:
        arm.animation_data.action_slot = action.slots[0]
    for f in range(1, frames + 2):
        t = (f - 1) / frames
        pose_fn(t)
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_euler", frame=f)
        arm.keyframe_insert("location", frame=f)
    arm.animation_data.action = None

bake_action("idle", 32, set_idle)
bake_action("walk", 16, set_walk)
bake_action("attack", 10, set_attack)
reset_pose()

# Beauty preview with ground.
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.film_transparent = False
scene.display.shading.show_shadows = True
ground.hide_render = False
arm.rotation_euler.z = math.radians(45)
set_idle(0.25)
bpy.context.view_layer.update()
scene.render.filepath = os.path.join(BUILD, "preview.png")
bpy.ops.render.render(write_still=True)

# Animated GLB models, one per team.
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
for o, _ in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
for team, cloth in {"blue": (0.12, 0.30, 0.72), "red": (0.72, 0.14, 0.12)}.items():
    M["cloth"].diffuse_color = (*cloth, 1)
    bsdf = M["cloth"].node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*cloth, 1)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(BUILD, f"warrior_{team}.glb"),
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_anim_single_armature=True,
        export_apply=False,
    )
print("WARRIOR MODEL DONE")
