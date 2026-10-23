import bpy
import bmesh
import math
import os

REPO = "/Volumes/copia/lastday2"
M4_GLB = os.path.join(REPO, "assets/models/weapons/m4_carbine_rifle.glb")
OUT_GLB = os.path.join(REPO, "assets/models/weapons/m4_rear_sight.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=M4_GLB)

iron_src = None
gun_mat = None
for obj in bpy.data.objects:
    if obj.type == "MESH" and "Iron_Sight" in obj.name:
        iron_src = obj
        if obj.data.materials:
            gun_mat = obj.data.materials[0]
        break

for obj in list(bpy.data.objects):
    if obj != iron_src:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.object.select_all(action='DESELECT')
iron_src.select_set(True)
bpy.context.view_layer.objects.active = iron_src
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 1. Duplicate Iron_Sight to rear Picatinny rail (y_blender = +0.0380, z_godot = -0.0380)
# and widen X so its two protective ears clearly flank the circular rear peep ring!
rear_body = iron_src.copy()
rear_body.data = iron_src.data.copy()
rear_body.name = "RearSightBody"
bpy.context.scene.collection.objects.link(rear_body)
for v in rear_body.data.vertices:
    v.co.y = (v.co.y + 0.0422) * 1.15 + 0.0380
    # Widen the upper protective ears (z > 0.056) by 3.6x so they sit at x = +-0.0038
    # outside the circular peep ring (r = 0.0024), while keeping the rail clamp base snug on the rail.
    t_ear = max(0.0, min(1.0, (v.co.z - 0.0545) / 0.0040))
    widen = 1.45 * (1.0 - t_ear) + 3.75 * t_ear
    v.co.x *= widen
    if v.co.z > 0.058:
        v.co.z += 0.0016
rear_body.data.update()

# 2. On the FRONT sight (iron_src at y = -0.0432), add the central A2 square post
# rising from the sight floor (z = 0.0565) up to z = 0.0626 between the two front ears.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.0432, 0.0596))
front_post = bpy.context.active_object
front_post.name = "FrontSightPost"
for v in front_post.data.vertices:
    top_f = 1.0 if v.co.z > 0 else 1.35
    v.co.x *= 0.00058 * top_f
    v.co.y *= 0.00090 * top_f
    v.co.z *= 0.0062
front_post.data.update()
for p in front_post.data.polygons:
    p.use_smooth = False
front_post.data.materials.append(gun_mat)

# 3. Perfectly circular rear diopter peep ring at (0.0, +0.0380, 0.0626)
z_line = 0.0626
y_rear = 0.0380

bpy.ops.mesh.primitive_torus_add(
    align='WORLD',
    location=(0.0, y_rear, z_line),
    rotation=(math.radians(90.0), 0.0, 0.0),
    major_radius=0.00235,
    minor_radius=0.00042,
    major_segments=64,
    minor_segments=24,
)
ring = bpy.context.active_object
ring.name = "RearPeepRing"
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
# Compress only Y (depth along barrel) in world space so X-Z stays a 100% true circle!
for v in ring.data.vertices:
    v.co.y = (v.co.y - y_rear) * 0.55 + y_rear
ring.data.update()
for p in ring.data.polygons:
    p.use_smooth = True
ring.data.materials.append(gun_mat)

# Solid stem connecting the bottom of the circular peep ring into the rear sight base
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, y_rear, 0.0586))
stem = bpy.context.active_object
stem.name = "RearPeepStem"
for v in stem.data.vertices:
    v.co.x *= 0.0015
    v.co.y *= 0.0018
    v.co.z *= 0.0040
stem.data.update()
stem.data.materials.append(gun_mat)

# Knurled windage adjustment drum on the right side of the rear sight
bpy.ops.mesh.primitive_cylinder_add(
    vertices=28,
    radius=0.00145,
    depth=0.0018,
    location=(0.0044, y_rear, 0.0604),
    rotation=(0.0, math.radians(90.0), 0.0),
)
knob = bpy.context.active_object
knob.name = "WindageDrum"
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for p in knob.data.polygons:
    p.use_smooth = True
knob.data.materials.append(gun_mat)

for o in [front_post, ring, stem, knob]:
    uv = o.data.uv_layers.get("UVMap") or o.data.uv_layers.new(name="UVMap")
    for loop in o.data.loops:
        # Map to a uniform dark anodized metal patch of the M4 texture (no UV wrap seams)
        uv.data[loop.index].uv = (0.28, 0.28)

bpy.ops.object.select_all(action='DESELECT')
for o in [iron_src, rear_body, front_post, ring, stem, knob]:
    o.select_set(True)
bpy.context.view_layer.objects.active = rear_body
bpy.ops.object.join()

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print("Exported unified M4 sights:", OUT_GLB)
