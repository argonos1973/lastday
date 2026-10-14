"""Build per-species pelt headdresses ("Tocado de piel animal") from the
game's wildlife GLBs.

Each headdress = the real animal head (cut at the neck, own fur materials
preserved) resting on the wearer's crown, plus a procedural hide sheet that
drapes over the crown and hangs down the back — like the real animal-head
pelts in the reference photos. The sheet is textured with the generated
fur tile for the species (tools/blender/make_pelt_fur_tiles.py).

Blender world axes after glTF import: X = left/right, Y = forward/back
(glTF -Z -> Blender +Y), Z = up. The finished GLB is authored with the
animal's throat at the origin (the seat that rests on the wearer's skull)
and the snout facing -Z in glTF space (player forward). Run from the
project root:
  Blender --background --factory-startup --python tools/blender/make_pelt_headdresses.py
"""

import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT_DIR = os.path.join(ROOT, "assets", "characters", "adapted", "pelt")
FUR_DIR = os.path.join(ROOT, "assets", "textures", "pelt")


def _is_head_bone(n: str) -> bool:
    n = n.lower()
    for k in ["head", "neck", "jaw", "ear", "eye", "nose", "tongue", "mouth", "eyelid"]:
        if k in n:
            return True
    return False


def _is_hind_bone(n: str) -> bool:
    n = n.lower()
    return n.startswith("legb") or n.startswith("tail")


# species -> (glb path, head-width target metres)
SPECIES = {
    "lobo": ("assets/external/wolf/WolfAnimated.glb", 0.34),
    "ciervo": ("assets/models/wildlife/deer.glb", 0.36),
    "zorro": ("assets/models/wildlife/fox.glb", 0.30),
    "oso": ("assets/models/wildlife/bear.glb", 0.38),
}


def _world_verts(obj):
    mw = obj.matrix_world
    return [mw @ v.co for v in obj.data.vertices]


def _dominant_bones(obj):
    groups = obj.vertex_groups
    out = []
    for v in obj.data.vertices:
        w = {}
        for g in v.groups:
            if g.weight > 0.0:
                w[groups[g.group].name] = g.weight
        out.append(w)
    return out


def _mesh_bisect(mesh_obj, keep_fn):
    """New object containing only faces whose corner verts all pass keep_fn,
    evaluated on the source mesh in world space."""
    src = mesh_obj.data
    weights = _dominant_bones(mesh_obj)
    wverts = _world_verts(mesh_obj)
    keep = [keep_fn(weights[v.index], wverts[v.index]) for v in src.vertices]
    bm = bmesh.new()
    bm.from_mesh(src)
    for f in list(bm.faces):
        if not all(keep[v.index] for v in f.verts):
            bm.faces.remove(f)
    for v in list(bm.verts):
        if not keep[v.index]:
            bm.verts.remove(v)
    new_mesh = bpy.data.meshes.new(mesh_obj.name + "_pelt")
    bm.to_mesh(new_mesh)
    bm.free()
    for m in src.materials:
        new_mesh.materials.append(m)
    new_obj = bpy.data.objects.new(mesh_obj.name + "_pelt", new_mesh)
    new_obj.matrix_world = mesh_obj.matrix_world
    bpy.context.scene.collection.objects.link(new_obj)
    return new_obj


def _build_head(species, src_path):
    """Keep only the head/neck skin of the animal (verts dominated by head
    bones) so the trophy is a clean severed head — the pelt sheet is added
    procedurally afterwards."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path)
    arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if arm is None or not meshes:
        raise RuntimeError(f"{species}: no armature/mesh in {src_path}")

    mw = arm.matrix_world
    head_pos = None
    pelvis_pos = None
    for b in arm.data.bones:
        n = b.name.lower()
        wpos = mw @ b.head_local
        if n == "head" and head_pos is None:
            head_pos = wpos
        if n == "pelvis" and pelvis_pos is None:
            pelvis_pos = wpos
    if head_pos is None or pelvis_pos is None:
        raise RuntimeError(f"{species}: missing Head/Pelvis bones")

    axis = Vector((head_pos.x - pelvis_pos.x, head_pos.y - pelvis_pos.y, 0.0))
    if axis.length < 1e-4:
        axis = Vector((0, 1, 0))
    axis.normalize()

    def keep(weights, wpos):
        head_w = sum(w for n, w in weights.items() if _is_head_bone(n))
        hind_w = sum(w for n, w in weights.items() if _is_hind_bone(n))
        return head_w > 0.08 and hind_w < 0.5

    kept_objs = []
    for mesh in meshes:
        new_obj = _mesh_bisect(mesh, keep)
        if len(new_obj.data.vertices) == 0:
            bpy.data.objects.remove(new_obj)
            continue
        kept_objs.append(new_obj)

    if not kept_objs:
        raise RuntimeError(f"{species}: no geometry survived the cut")
    return kept_objs, axis


def maxf(a):
    return max(a, 1e-5)


def _fur_material(species):
    """Pelt material textured with the generated fur tile for the species."""
    mat = bpy.data.materials.new("Pelt_" + species)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.9
    tex_path = os.path.join(FUR_DIR, f"fur_{species}.png")
    if os.path.isfile(tex_path):
        img = bpy.data.images.load(tex_path)
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def _build_cape(species, head_mesh, head_width):
    """Hide sheet draped over the wearer's skull: hugs a head-sized sphere
    under the trophy head, then hangs down the back. Authored in the final
    GLB space (origin = throat seat, +Y = forward, +Z = up)."""
    verts, faces, uvs = [], [], []
    def grid(rows, cols, point):
        start = len(verts)
        for i in range(rows + 1):
            for j in range(cols + 1):
                verts.append(Vector(point(i / rows, j / cols)))
                uvs.append((j / cols, i / rows))
        for i in range(rows):
            for j in range(cols):
                a = start + i * (cols + 1) + j
                faces.append((a, a + 1, a + cols + 2, a + cols + 1))

    # Closed crown and nape. The former strip had no crown and left the
    # cut animal neck and human scalp exposed from behind.
    rx, ry = head_width * .59, head_width * .80
    cy, equator = -head_width * .17, head_width * .05
    def dome(v, u):
        phi = .015 + v * (math.pi / 2 - .015)
        theta = math.radians(50 + 260 * u)
        return (rx * math.sin(phi) * math.sin(theta),
                cy + ry * math.sin(phi) * math.cos(theta),
                equator + head_width * .72 * math.cos(phi))
    grid(16, 64, dome)

    def skirt(t, u):
        theta = math.radians(50 + 260 * u)
        edge = abs(2 * u - 1) ** 4
        shoulder = max(0.0, (t - .45) / .55)
        ripple = .012 * head_width * math.sin(theta * 13 + t * 6) * t
        x = (rx + shoulder * head_width * .14 + ripple) * math.sin(theta)
        y = cy + (ry + ripple) * math.cos(theta)
        # Back rests on the nape; the two front ends reach the upper chest.
        z = equator - head_width * t * (1.35 + .34 * edge)
        if t == 1:
            z += head_width * .025 * math.sin(u * 137)
        return x, y, z
    grid(24, 64, skirt)

    mesh = bpy.data.meshes.new("PeltCape_" + species)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    uv = mesh.uv_layers.new(name="UVMap")
    for li, loop in enumerate(mesh.loops):
        uv.data[li].uv = uvs[loop.vertex_index]
    mesh.materials.append(_fur_material(species))
    obj = bpy.data.objects.new("PeltCape_" + species, mesh)
    bpy.context.scene.collection.objects.link(obj)

    # Pelt thickness.
    mod = obj.modifiers.new("PeltThickness", "SOLIDIFY")
    mod.thickness = 0.004
    mod.offset = -0.5
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)
    return obj


def _finish(species, kept_objs, nose_axis, head_width):
    bpy.ops.object.select_all(action="DESELECT")
    for o in kept_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = kept_objs[0]
    if len(kept_objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = f"Headdress_{species}"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Rotate around Z so the nose axis points to +Y (exports as -Z forward).
    ang = math.atan2(nose_axis.y, nose_axis.x)
    obj.rotation_euler.z = math.pi * 0.5 - ang
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Scale the head to the target trophy width.
    verts = [v.co for v in obj.data.vertices]
    xs = [v.x for v in verts]
    cur_w = max(xs) - min(xs)
    if cur_w < 1e-4:
        cur_w = max(v.y for v in verts) - min(v.y for v in verts)
    s = head_width / maxf(cur_w)
    bpy.ops.transform.resize(value=(s, s, s))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Seat: throat (lowest head vert) rests on the origin, head centered on
    # the scalp axis.
    verts = [v.co for v in obj.data.vertices]
    head_verts = [v for v in verts if v.z > min(v.z for v in verts) + 0.15 * head_width]
    hx = sum(v.x for v in head_verts) / len(head_verts)
    hy = sum(v.y for v in head_verts) / len(head_verts)
    seat_z = min(v.z for v in verts)
    obj.location.x -= hx
    obj.location.y -= hy
    obj.location.z -= seat_z
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Trim the back of the neck geometrically, preserving ears/cheeks and
    # their UVs. Do not fill arbitrary mesh holes: that bridged fur cards
    # and ear rims with stretched polygons in the previous export.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        plane_co=(0, -head_width * .43, 0), plane_no=(0, 1, 0),
        clear_inner=True, clear_outer=False)
    bm.to_mesh(obj.data)
    bm.free()
    obj.select_set(False)

    # Draped pelt sheet behind/under the head.
    cape = _build_cape(species, obj, head_width)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    cape.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"headdress_{species}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=False,
        export_yup=True,
    )
    print(f"{species}: wrote {out} ({os.path.getsize(out)/1024:.0f} KiB)")


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
kinds = args or list(SPECIES.keys())
for species in kinds:
    if species not in SPECIES:
        raise ValueError(f"Unknown species: {species}")
    src, head_width = SPECIES[species]
    src_abs = os.path.join(ROOT, src)
    if not os.path.isfile(src_abs):
        print(f"{species}: missing {src_abs}, skipping")
        continue
    kept, axis = _build_head(species, src_abs)
    _finish(species, kept, axis, head_width)
