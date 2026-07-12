# generate_camo_net.py
# Genera una red de camuflaje deformable para refugios de palos:
# malla, esqueleto, pesos, texturas PBR y exportacion GLB para Godot 4.
# Ejecutar: blender --background --python generate_camo_net.py

import bpy
import bmesh
import os
import random
import numpy as np
from mathutils import Vector, noise

SEED = 20260712
NET_X = 4.0
NET_Y = 3.0
RES_X = 60
RES_Y = 45
BONE_COLS = 7
BONE_ROWS = 5
TEX_SIZE = 2048
ALPHA_CUTOFF = 0.45

MESH_NAME = "CamoNet_StickShelter"
ARM_NAME = "CamoNet_Skeleton"
COLL_NAME = "CamoNet_StickShelter_Collision"
MAT_NAME = "MAT_CamoNet_Woodland"
ROOT_BONE = "NetRoot"

random.seed(SEED)
rng = np.random.default_rng(SEED)

try:
    _base = os.path.dirname(os.path.abspath(__file__))
except NameError:
    _base = os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.getcwd()

EXPORT_DIR = os.path.join(_base, "camo_net_export")
TEX_DIR = os.path.join(EXPORT_DIR, "textures")
BLEND_PATH = os.path.join(EXPORT_DIR, "camouflage_stick_shelter_deformable.blend")
GLB_PATH = os.path.join(EXPORT_DIR, "camo_net_stick_shelter_deformable.glb")
os.makedirs(TEX_DIR, exist_ok=True)

# ------------------------------------------------------------ escena limpia
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(SEED)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for coll in list(bpy.data.collections):
    bpy.data.collections.remove(coll)

# ------------------------------------------------------------ malla
bm = bmesh.new()
grid_verts = {}
for j in range(RES_Y + 1):
    for i in range(RES_X + 1):
        x = -NET_X / 2.0 + NET_X * i / RES_X
        y = -NET_Y / 2.0 + NET_Y * j / RES_Y
        grid_verts[(i, j)] = bm.verts.new((x, y, 0.0))
bm.verts.ensure_lookup_table()
for j in range(RES_Y):
    for i in range(RES_X):
        bm.faces.new([grid_verts[(i, j)], grid_verts[(i + 1, j)],
                      grid_verts[(i + 1, j + 1)], grid_verts[(i, j + 1)]])
bm.faces.ensure_lookup_table()

# forma neutra: cupula suave, caida en bordes, ondulaciones
for v in bm.verts:
    x, y = v.co.x, v.co.y
    nx = x / (NET_X / 2.0)
    ny = y / (NET_Y / 2.0)
    dome = 0.22 * (1.0 - nx * nx) * (1.0 - ny * ny)
    ripple = 0.05 * noise.noise(Vector((x * 1.6, y * 1.6, 3.7)))
    droop = -0.16 * max(abs(nx), abs(ny)) ** 3
    micro = 0.03 * noise.noise(Vector((x * 4.0, y * 4.0, 9.1)))
    v.co.z = dome + ripple + droop + micro

# bordes irregulares
for (i, j), v in grid_verts.items():
    dirx = -1 if i == 0 else (1 if i == RES_X else 0)
    diry = -1 if j == 0 else (1 if j == RES_Y else 0)
    if dirx == 0 and diry == 0:
        continue
    n1 = noise.noise(Vector((v.co.x * 2.3, v.co.y * 2.3, 5.5)))
    n2 = noise.noise(Vector((v.co.x * 5.1, v.co.y * 5.1, 11.3)))
    v.co.x += dirx * (0.10 * (0.5 + 0.5 * n1) + 0.04 * n2)
    v.co.y += diry * (0.10 * (0.5 + 0.5 * n2) + 0.04 * n1)
    v.co.z -= 0.08 + 0.07 * abs(n1)

# zonas desgarradas cerca de los bordes
tears = []
for _ in range(7):
    axis = random.choice(['x', 'y'])
    sign = random.choice([-1.0, 1.0])
    if axis == 'x':
        cx = sign * random.uniform(0.55, 0.92) * (NET_X / 2.0)
        cy = random.uniform(-0.9, 0.9) * (NET_Y / 2.0)
    else:
        cx = random.uniform(-0.9, 0.9) * (NET_X / 2.0)
        cy = sign * random.uniform(0.55, 0.92) * (NET_Y / 2.0)
    tears.append((Vector((cx, cy, 0.0)), random.uniform(0.08, 0.16)))

doomed = []
for f in bm.faces:
    c = f.calc_center_median()
    c2 = Vector((c.x, c.y, 0.0))
    for tc, tr in tears:
        if (c2 - tc).length < tr:
            doomed.append(f)
            break
bmesh.ops.delete(bm, geom=doomed, context='FACES')
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

mesh = bpy.data.meshes.new(MESH_NAME)
bm.to_mesh(mesh)
bm.free()
net_obj = bpy.data.objects.new(MESH_NAME, mesh)

# ------------------------------------------------------------ UV planar
uv_layer = mesh.uv_layers.new(name="UVMap")
for loop in mesh.loops:
    co = mesh.vertices[loop.vertex_index].co
    uv_layer.data[loop.index].uv = (
        (co.x + NET_X / 2.0) / NET_X,
        (co.y + NET_Y / 2.0) / NET_Y,
    )

# ------------------------------------------------------------ armature
arm_data = bpy.data.armatures.new(ARM_NAME)
arm_obj = bpy.data.objects.new(ARM_NAME, arm_data)
scene.collection.objects.link(arm_obj)
scene.collection.objects.link(net_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')

eb_root = arm_data.edit_bones.new(ROOT_BONE)
eb_root.head = (0.0, 0.0, -0.001)
eb_root.tail = (0.0, 0.0, 0.25)

xs = [(-NET_X / 2.0) + NET_X * c / (BONE_COLS - 1) for c in range(BONE_COLS)]
ys = [(-NET_Y / 2.0) + NET_Y * r / (BONE_ROWS - 1) for r in range(BONE_ROWS)]
bone_names = []
for r in range(BONE_ROWS):
    for c in range(BONE_COLS):
        name = "NetBone_R%02d_C%02d" % (r, c)
        eb = arm_data.edit_bones.new(name)
        eb.head = (xs[c], ys[r], 0.0)
        eb.tail = (xs[c], ys[r], 0.15)
        eb.parent = eb_root
        eb.use_connect = False
        bone_names.append(name)

helper_bones = {
    "NetCorner_FL": (-NET_X / 2.0, -NET_Y / 2.0, 0.0),
    "NetCorner_FR": (NET_X / 2.0, -NET_Y / 2.0, 0.0),
    "NetCorner_BL": (-NET_X / 2.0, NET_Y / 2.0, 0.0),
    "NetCorner_BR": (NET_X / 2.0, NET_Y / 2.0, 0.0),
    "NetCenter": (0.0, 0.0, 0.22),
    "NetRidge_Front": (0.0, -NET_Y / 4.0, 0.18),
    "NetRidge_Back": (0.0, NET_Y / 4.0, 0.18),
}
for hname, hpos in helper_bones.items():
    eb = arm_data.edit_bones.new(hname)
    eb.head = hpos
    eb.tail = (hpos[0], hpos[1], hpos[2] + 0.12)
    eb.parent = eb_root
    eb.use_connect = False

bpy.ops.object.mode_set(mode='OBJECT')
for bone in arm_data.bones:
    bone.use_deform = bone.name in bone_names

# ------------------------------------------------------------ pesos bilineales
groups = {}
for name in bone_names:
    groups[name] = net_obj.vertex_groups.new(name=name)

for v in mesh.vertices:
    fx = (v.co.x + NET_X / 2.0) / NET_X
    fy = (v.co.y + NET_Y / 2.0) / NET_Y
    fx = min(max(fx, 0.0), 0.999999) * (BONE_COLS - 1)
    fy = min(max(fy, 0.0), 0.999999) * (BONE_ROWS - 1)
    c0 = int(fx)
    r0 = int(fy)
    tx = fx - c0
    ty = fy - r0
    c1 = min(c0 + 1, BONE_COLS - 1)
    r1 = min(r0 + 1, BONE_ROWS - 1)
    w = {
        (r0, c0): (1.0 - tx) * (1.0 - ty),
        (r0, c1): tx * (1.0 - ty),
        (r1, c0): (1.0 - tx) * ty,
        (r1, c1): tx * ty,
    }
    acc = {}
    for (r, c), wt in w.items():
        key = "NetBone_R%02d_C%02d" % (r, c)
        acc[key] = acc.get(key, 0.0) + wt
    total = sum(acc.values())
    for key, wt in acc.items():
        if wt > 1e-6:
            groups[key].add([v.index], wt / total, 'REPLACE')

mod = net_obj.modifiers.new(name="Armature", type='ARMATURE')
mod.object = arm_obj
mod.use_vertex_groups = True
net_obj.parent = arm_obj

# ------------------------------------------------------------ texturas
def _fbm(size, freq, octaves, seed_offset):
    total = np.zeros((size, size), dtype=np.float64)
    amp = 1.0
    amp_sum = 0.0
    lrng = np.random.default_rng(SEED + seed_offset)
    f = freq
    for _ in range(octaves):
        cells = max(2, int(f))
        coarse = lrng.random((cells + 1, cells + 1))
        idx = np.linspace(0, cells, size)
        i0 = np.floor(idx).astype(int)
        i1 = np.minimum(i0 + 1, cells)
        t = idx - i0
        t = t * t * (3.0 - 2.0 * t)
        row = coarse[i0][:, i0] * np.outer(1 - t, 1 - t) \
            + coarse[i0][:, i1] * np.outer(1 - t, t) \
            + coarse[i1][:, i0] * np.outer(t, 1 - t) \
            + coarse[i1][:, i1] * np.outer(t, t)
        total += row * amp
        amp_sum += amp
        amp *= 0.5
        f *= 2.0
    return total / amp_sum


def _save_png(name, rgba):
    img = bpy.data.images.new(name, width=TEX_SIZE, height=TEX_SIZE, alpha=True)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = os.path.join(TEX_DIR, name)
    img.file_format = 'PNG'
    img.save()
    return img


S = TEX_SIZE

# --- base color: patron woodland original por manchas fbm
n1 = _fbm(S, 6, 5, 11)
n2 = _fbm(S, 12, 5, 23)
n3 = _fbm(S, 24, 4, 37)
dirt = _fbm(S, 48, 3, 51)

palette = np.array([
    [0.28, 0.33, 0.18],  # verde oliva
    [0.16, 0.22, 0.12],  # verde oscuro
    [0.33, 0.36, 0.24],  # verde apagado
    [0.24, 0.17, 0.10],  # marron oscuro
    [0.35, 0.27, 0.16],  # marron tierra
    [0.45, 0.42, 0.30],  # beige apagado
    [0.30, 0.34, 0.28],  # gris verdoso
])

sel = (n1 * 3.1 + n2 * 2.3 + n3 * 1.6) % 1.0
idx_map = np.clip((sel * len(palette)).astype(int), 0, len(palette) - 1)
base = palette[idx_map]
# variacion de suciedad y decoloracion
base *= (0.85 + 0.3 * dirt[..., None])
base = np.clip(base, 0.0, 1.0)

# --- alfa: tiras irregulares y agujeros, aspecto de red de ocultacion
strips_a = _fbm(S, 18, 4, 71)
strips_b = _fbm(S, 34, 4, 83)
holes = _fbm(S, 9, 4, 97)
alpha = np.ones((S, S), dtype=np.float64)
# tiras de tela onduladas (bandas segun fbm)
band = np.abs(((strips_a * 8.0) % 1.0) - 0.5) * 2.0
band2 = np.abs(((strips_b * 6.0) % 1.0) - 0.5) * 2.0
alpha = np.where((band > 0.72) & (band2 > 0.35), 0.0, alpha)
# agujeros organicos de distintos tamanos
alpha = np.where(holes > 0.78, 0.0, alpha)
alpha = np.where((holes > 0.70) & (strips_b > 0.6), 0.0, alpha)
# desgaste en bordes de la textura
yy, xx = np.mgrid[0:S, 0:S] / S
edge = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
alpha = np.where((edge < 0.02) & (strips_a > 0.5), 0.0, alpha)

# --- roughness: mate con variacion ligera
rough = 0.82 + 0.08 * (n3 - 0.5) * 2.0 + 0.04 * (dirt - 0.5) * 2.0
rough = np.clip(rough, 0.72, 0.92)

# --- normal map a partir de altura (fibras + arrugas + cortes)
height = 0.55 * n2 + 0.30 * n3 + 0.15 * dirt
height += (1.0 - alpha) * -0.35  # bordes de cortes hundidos
gy, gx = np.gradient(height)
strength = 3.0
nxv = -gx * strength
nyv = -gy * strength
nzv = np.ones_like(height)
ln = np.sqrt(nxv * nxv + nyv * nyv + nzv * nzv)
normal_rgb = np.stack([(nxv / ln) * 0.5 + 0.5,
                       (nyv / ln) * 0.5 + 0.5,
                       (nzv / ln) * 0.5 + 0.5], axis=-1)

# --- ao suave
ao = np.clip(0.75 + 0.25 * n1, 0.0, 1.0)

ones = np.ones((S, S, 1))
img_base = _save_png("camo_net_basecolor.png",
                     np.concatenate([base, alpha[..., None]], axis=-1))
img_alpha = _save_png("camo_net_alpha.png",
                      np.concatenate([np.repeat(alpha[..., None], 3, axis=-1), ones], axis=-1))
img_rough = _save_png("camo_net_roughness.png",
                      np.concatenate([np.repeat(rough[..., None], 3, axis=-1), ones], axis=-1))
img_normal = _save_png("camo_net_normal.png",
                       np.concatenate([normal_rgb, ones], axis=-1))
img_ao = _save_png("camo_net_ao.png",
                   np.concatenate([np.repeat(ao[..., None], 3, axis=-1), ones], axis=-1))
img_normal.colorspace_settings.name = 'Non-Color'
img_rough.colorspace_settings.name = 'Non-Color'
img_alpha.colorspace_settings.name = 'Non-Color'
img_ao.colorspace_settings.name = 'Non-Color'

# ------------------------------------------------------------ material
mat = bpy.data.materials.new(MAT_NAME)
mat.use_nodes = True
mat.blend_method = 'CLIP'
if hasattr(mat, "shadow_method"):
    mat.shadow_method = 'CLIP'
mat.alpha_threshold = ALPHA_CUTOFF
mat.use_backface_culling = False

nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
out.location = (600, 0)
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
bsdf.location = (300, 0)
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.85
if "Specular IOR Level" in bsdf.inputs:
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

tex_base = nt.nodes.new("ShaderNodeTexImage")
tex_base.image = img_base
tex_base.location = (-300, 250)
nt.links.new(tex_base.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex_base.outputs["Alpha"], bsdf.inputs["Alpha"])

tex_rough = nt.nodes.new("ShaderNodeTexImage")
tex_rough.image = img_rough
tex_rough.location = (-300, -50)
nt.links.new(tex_rough.outputs["Color"], bsdf.inputs["Roughness"])

tex_norm = nt.nodes.new("ShaderNodeTexImage")
tex_norm.image = img_normal
tex_norm.location = (-300, -350)
nmap = nt.nodes.new("ShaderNodeNormalMap")
nmap.location = (0, -350)
nmap.inputs["Strength"].default_value = 0.8
nt.links.new(tex_norm.outputs["Color"], nmap.inputs["Color"])
nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

mesh.materials.append(mat)

# ------------------------------------------------------------ colision simple
bm2 = bmesh.new()
cres = 4
cverts = {}
for j in range(cres + 1):
    for i in range(cres + 1):
        x = -NET_X / 2.0 + NET_X * i / cres
        y = -NET_Y / 2.0 + NET_Y * j / cres
        nxc = x / (NET_X / 2.0)
        nyc = y / (NET_Y / 2.0)
        z = 0.22 * (1.0 - nxc * nxc) * (1.0 - nyc * nyc) - 0.1 * max(abs(nxc), abs(nyc)) ** 2
        cverts[(i, j)] = bm2.verts.new((x, y, z))
for j in range(cres):
    for i in range(cres):
        bm2.faces.new([cverts[(i, j)], cverts[(i + 1, j)],
                       cverts[(i + 1, j + 1)], cverts[(i, j + 1)]])
bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
coll_mesh = bpy.data.meshes.new(COLL_NAME)
bm2.to_mesh(coll_mesh)
bm2.free()
coll_obj = bpy.data.objects.new(COLL_NAME, coll_mesh)
coll_obj.hide_render = True
coll_obj["is_aux_collision"] = True
coll_obj.parent = arm_obj
scene.collection.objects.link(coll_obj)

# ------------------------------------------------------------ colecciones
c_visual = bpy.data.collections.new("CamoNet_Visual")
c_rig = bpy.data.collections.new("CamoNet_Rig")
c_coll = bpy.data.collections.new("CamoNet_Collision")
scene.collection.children.link(c_visual)
scene.collection.children.link(c_rig)
scene.collection.children.link(c_coll)
for o, c in ((net_obj, c_visual), (arm_obj, c_rig), (coll_obj, c_coll)):
    for prev in list(o.users_collection):
        prev.objects.unlink(o)
    c.objects.link(o)

# aplicar transformaciones
bpy.ops.object.select_all(action='DESELECT')
for o in (net_obj, coll_obj, arm_obj):
    o.select_set(True)
bpy.context.view_layer.objects.active = net_obj
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.select_all(action='DESELECT')

# ------------------------------------------------------------ validacion
errors = []
if MESH_NAME not in bpy.data.objects:
    errors.append("Falta la malla %s" % MESH_NAME)
if ARM_NAME not in bpy.data.objects:
    errors.append("Falta el armature %s" % ARM_NAME)
if not any(m.type == 'ARMATURE' and m.object == arm_obj for m in net_obj.modifiers):
    errors.append("Modificador Armature no configurado")
if len(mesh.uv_layers) == 0:
    errors.append("Faltan UVs")
if len(mesh.materials) == 0:
    errors.append("Material no asignado")

unweighted = 0
for v in mesh.vertices:
    tw = sum(g.weight for g in v.groups)
    if tw < 1e-5:
        unweighted += 1
    elif abs(tw - 1.0) > 1e-3:
        for g in v.groups:
            g.weight /= tw
if unweighted > 0:
    errors.append("%d vertices sin peso" % unweighted)

names_seen = set()
for b in arm_data.bones:
    if b.name in names_seen:
        errors.append("Hueso duplicado: %s" % b.name)
    names_seen.add(b.name)

for tex_name in ("camo_net_basecolor.png", "camo_net_normal.png",
                 "camo_net_roughness.png", "camo_net_alpha.png", "camo_net_ao.png"):
    if not os.path.isfile(os.path.join(TEX_DIR, tex_name)):
        errors.append("Falta textura: %s" % tex_name)

for e in errors:
    print("[ERROR] %s" % e)

# ------------------------------------------------------------ guardar y exportar
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

bpy.ops.object.select_all(action='DESELECT')
net_obj.select_set(True)
arm_obj.select_set(True)
coll_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj

bpy.ops.export_scene.gltf(
    filepath=GLB_PATH,
    export_format='GLB',
    use_selection=True,
    export_apply=False,
    export_skins=True,
    export_yup=True,
    export_texcoords=True,
    export_normals=True,
    export_tangents=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
    export_cameras=False,
    export_lights=False,
    export_animations=False,
    export_def_bones=False,
)

# ------------------------------------------------------------ resumen
mesh.calc_loop_triangles()
print("=" * 60)
print("BLEND:    %s" % os.path.abspath(BLEND_PATH))
print("GLB:      %s" % os.path.abspath(GLB_PATH))
for tex_name in ("camo_net_basecolor.png", "camo_net_normal.png",
                 "camo_net_roughness.png", "camo_net_alpha.png", "camo_net_ao.png"):
    print("TEXTURA:  %s" % os.path.abspath(os.path.join(TEX_DIR, tex_name)))
print("Vertices:   %d" % len(mesh.vertices))
print("Triangulos: %d" % len(mesh.loop_triangles))
print("Huesos:     %d (deformacion: %d)" % (len(arm_data.bones), len(bone_names)))
print("Materiales: %d" % len(mesh.materials))
print("Pesos normalizados: SI (vertices sin peso: %d)" % unweighted)
print("Exportacion completada: %s" % ("SI" if os.path.isfile(GLB_PATH) else "NO"))
print("=" * 60)
