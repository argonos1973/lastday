import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, noise

random.seed(20260414)

REPO = "/Volumes/copia/lastday2"
PROPS_DIR = os.path.join(REPO, "assets/models/props")
OUT_GLB = os.path.join(PROPS_DIR, "camo_net.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

# shipping_container_anos.glb world AABB in Godot at rot=0:
# X: [-3.615, +3.615] (7.23), Y(height): [0.0, 2.89], Z: [-1.48, +1.48] (2.96)
CONT_X = 7.25
CONT_Y = 2.98
CONT_Z = 2.89

# 1) Bevelled container proxy collider
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, CONT_Z * 0.5))
col_obj = bpy.context.active_object
col_obj.name = "ContainerCollider"
col_obj.scale = (CONT_X, CONT_Y, CONT_Z)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

bev = col_obj.modifiers.new("Bevel", 'BEVEL')
bev.width = 0.08
bev.segments = 3
bpy.context.view_layer.objects.active = col_obj
bpy.ops.object.modifier_apply(modifier=bev.name)

bpy.ops.object.modifier_add(type='COLLISION')
col_obj.collision.thickness_outer = 0.03
col_obj.collision.thickness_inner = 0.02
col_obj.collision.cloth_friction = 14.0

# 2) Build cloth sheet with irregular border length
NET_W = 8.9
NET_D = 6.1
RES_X = 96
RES_Y = 66

bm = bmesh.new()
grid = {}
for j in range(RES_Y + 1):
    for i in range(RES_X + 1):
        u = i / RES_X
        v = j / RES_Y
        x = (u - 0.5) * NET_W
        y = (v - 0.5) * NET_D
        ang = math.atan2(y, x)
        lobe = 0.22 * math.sin(ang * 2.0 + 0.6) + 0.14 * math.cos(ang * 3.0 - 0.8)
        edge_dist = min(u, 1.0 - u, v, 1.0 - v)
        if edge_dist < 0.22:
            factor = (0.22 - edge_dist) / 0.22
            wobble = noise.noise(Vector((x * 0.9, y * 0.9, 2.3))) * 0.35 + lobe
            x += (1.0 if u > 0.5 else -1.0) * wobble * factor * 0.45
            y += (1.0 if v > 0.5 else -1.0) * wobble * factor * 0.55
        z = CONT_Z + 0.05 + 0.025 * noise.noise(Vector((x * 0.9, y * 0.9, 1.1)))
        grid[(i, j)] = bm.verts.new((x, y, z))

bm.verts.ensure_lookup_table()
for j in range(RES_Y):
    for i in range(RES_X):
        bm.faces.new([
            grid[(i, j)],
            grid[(i + 1, j)],
            grid[(i + 1, j + 1)],
            grid[(i, j + 1)],
        ])
bm.faces.ensure_lookup_table()

tears = [
    (Vector((-2.8, -2.2, 0.0)), 0.32),
    (Vector((1.7, -2.3, 0.0)), 0.26),
    (Vector((3.7, 0.5, 0.0)), 0.28),
    (Vector((-1.3, 2.25, 0.0)), 0.28),
    (Vector((2.5, 2.15, 0.0)), 0.24),
    (Vector((-3.8, -0.4, 0.0)), 0.27),
]
doomed = []
for f in bm.faces:
    c = f.calc_center_median()
    c2 = Vector((c.x, c.y, 0.0))
    for tc, tr in tears:
        if (c2 - tc).length < tr:
            doomed.append(f)
            break
bmesh.ops.delete(bm, geom=doomed, context='FACES')
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

mesh = bpy.data.meshes.new("CamoNet_Container")
bm.to_mesh(mesh)
bm.free()

uv_layer = mesh.uv_layers.new(name="UVMap")
for loop in mesh.loops:
    co = mesh.vertices[loop.vertex_index].co
    uv_layer.data[loop.index].uv = (
        (co.x / NET_W + 0.5) * 2.2,
        (co.y / NET_D + 0.5) * 1.5,
    )

net_obj = bpy.data.objects.new("CamoNet_Container", mesh)
scene.collection.objects.link(net_obj)
net_obj.rotation_euler = (0.0, 0.0, math.radians(2.5))
net_obj.location = (-0.08, 0.05, 0.0)
bpy.context.view_layer.objects.active = net_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 3) Soft heavy cloth simulation
cloth_mod = net_obj.modifiers.new("Cloth", 'CLOTH')
cs = cloth_mod.settings
cs.quality = 8
cs.mass = 0.65
cs.tension_stiffness = 10.0
cs.compression_stiffness = 3.0
cs.shear_stiffness = 5.0
cs.bending_stiffness = 0.015
cs.air_damping = 1.0

ccs = cloth_mod.collision_settings
ccs.use_collision = True
ccs.distance_min = 0.022
ccs.collision_quality = 5

scene.frame_start = 1
scene.frame_end = 85
for frame in range(1, 86):
    scene.frame_set(frame)

bpy.context.view_layer.objects.active = net_obj
bpy.ops.object.modifier_apply(modifier=cloth_mod.name)

hx = CONT_X * 0.5 + 0.022
hy = CONT_Y * 0.5 + 0.022
hz = CONT_Z + 0.018
for v in net_obj.data.vertices:
    p = v.co
    if p.z < CONT_Z - 0.06:
        drop = (CONT_Z - p.z)
        pleat = 0.035 * math.sin(p.x * 3.8 + p.y * 2.7) * min(drop, 1.6)
        if abs(p.y) > CONT_Y * 0.45:
            p.y += math.copysign(abs(pleat), p.y)
        if abs(p.x) > CONT_X * 0.45:
            p.x += math.copysign(abs(pleat), p.x)
    if abs(p.x) < hx and abs(p.y) < hy and p.z < hz:
        dx = hx - abs(p.x)
        dy = hy - abs(p.y)
        dz = hz - p.z
        if dz <= dx and dz <= dy:
            p.z = hz
        elif dx <= dy:
            p.x = math.copysign(hx, p.x)
        else:
            p.y = math.copysign(hy, p.y)

for poly in net_obj.data.polygons:
    poly.use_smooth = True

bpy.data.objects.remove(col_obj, do_unlink=True)

# 4) PBR woodland camo material (image names match existing camo_net_camo_net_*.png imports)
mat = bpy.data.materials.new("MAT_CamoNet_Woodland")
mat.use_nodes = True
mat.blend_method = 'CLIP'
mat.alpha_threshold = 0.45
mat.use_backface_culling = False

nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.88
if "Specular IOR Level" in bsdf.inputs:
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

img_base = bpy.data.images.load(os.path.join(PROPS_DIR, "camo_net_camo_net_basecolor.png"))
img_rough = bpy.data.images.load(os.path.join(PROPS_DIR, "camo_net_camo_net_roughness.png"))
img_norm = bpy.data.images.load(os.path.join(PROPS_DIR, "camo_net_camo_net_normal.png"))
img_rough.colorspace_settings.name = 'Non-Color'
img_norm.colorspace_settings.name = 'Non-Color'

t_base = nt.nodes.new("ShaderNodeTexImage")
t_base.image = img_base
nt.links.new(t_base.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(t_base.outputs["Alpha"], bsdf.inputs["Alpha"])

t_rough = nt.nodes.new("ShaderNodeTexImage")
t_rough.image = img_rough
nt.links.new(t_rough.outputs["Color"], bsdf.inputs["Roughness"])

t_norm = nt.nodes.new("ShaderNodeTexImage")
t_norm.image = img_norm
nmap = nt.nodes.new("ShaderNodeNormalMap")
nmap.inputs["Strength"].default_value = 0.85
nt.links.new(t_norm.outputs["Color"], nmap.inputs["Color"])
nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

net_obj.data.materials.append(mat)

bpy.ops.object.select_all(action='DESELECT')
net_obj.select_set(True)
bpy.context.view_layer.objects.active = net_obj

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_texcoords=True,
    export_normals=True,
    export_tangents=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
)
print("EXPORTED:", OUT_GLB)
