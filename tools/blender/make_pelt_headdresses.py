"""Build per-species pelt headdresses ("Tocado de piel animal") from the
game's wildlife GLBs, matching the reference wolf/bear headdress photos:

1. Upper animal head (lower jaw/tongue removed, snout pitched up so the muzzle
   points forward) seats over the wearer's brow with upper canines framing the
   forehead.
2. Thick, furry cheek ruff and two volumetric front paw-lappets merge seamlessly
   into the animal's cheeks under the ears, hug the sides of the wearer's face,
   and hang straight down over the front of the shoulders onto the chest.
3. Dense 3D layered fur tufts along the cheek ruff, front paw-lappets, paw tips
   and rear cape give a shaggy, organic fur silhouette.

Run from the project root:
  Blender --background --factory-startup --python tools/blender/make_pelt_headdresses.py
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT_DIR = os.path.join(ROOT, "assets", "characters", "adapted", "pelt")
FUR_DIR = os.path.join(ROOT, "assets", "textures", "pelt")


def _is_head_bone(n: str) -> bool:
    n = n.lower()
    for k in ["head", "neck", "jaw", "ear", "eye", "nose", "tongue", "mouth", "eyelid"]:
        if k in n:
            return True
    return False


def _is_upper_skull_bone(n: str) -> bool:
    n = n.lower()
    for k in ["head", "ear", "eye", "nose", "eyelid"]:
        if k in n:
            return True
    return False


def _is_jaw_or_tongue_bone(n: str) -> bool:
    n = n.lower()
    return "jaw" in n or "tongue" in n


def _is_hind_bone(n: str) -> bool:
    n = n.lower()
    return n.startswith("legb") or n.startswith("tail")


# species -> (glb path, head-width target metres, snout pitch-up degrees, has_fangs)
# Positive rotation around +X raises +Y (the snout) toward +Z.
SPECIES = {
    "lobo": ("assets/external/wolf/WolfAnimated.glb", 0.34, 11.0, True),
    "ciervo": ("assets/models/wildlife/deer.glb", 0.38, 12.0, False),
    "zorro": ("assets/models/wildlife/fox.glb", 0.34, 15.0, True),
    "oso": ("assets/models/wildlife/bear.glb", 0.38, 9.0, True),
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
    """New object containing only faces whose corner verts all pass keep_fn."""
    src = mesh_obj.data
    weights = _dominant_bones(mesh_obj)
    wverts = _world_verts(mesh_obj)
    keep = [keep_fn(weights[v.index], wverts[v.index]) for v in src.vertices]
    bm = bmesh.new()
    bm.from_mesh(src)
    ear_layer = bm.verts.layers.float.new("pelt_ear")
    skull_layer = bm.verts.layers.float.new("pelt_skull")
    for v in bm.verts:
        v[ear_layer] = sum(w for n, w in weights[v.index].items() if "ear" in n.lower())
        v[skull_layer] = sum(w for n, w in weights[v.index].items() if _is_upper_skull_bone(n))
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
    """Keep the upper head/muzzle/ears of the animal while removing the lower
    jaw and tongue so the upper palate rests directly over the wearer's brow."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path)
    arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    meshes = [
        o for o in bpy.context.scene.objects
        if o.type == "MESH" and o.name not in ("Cube", "Icosphere") and len(o.data.vertices) > 100
    ]
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
        jaw_w = sum(w for n, w in weights.items() if _is_jaw_or_tongue_bone(n))
        hind_w = sum(w for n, w in weights.items() if _is_hind_bone(n))
        return head_w > 0.08 and jaw_w < 0.34 and hind_w < 0.5

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
    mat.blend_method = "OPAQUE"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.92
    tex_path = os.path.join(FUR_DIR, f"fur_{species}.png")
    if os.path.isfile(tex_path):
        img = bpy.data.images.load(tex_path)
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def _fang_material(species):
    """Ivory tooth material for the upper canines visible above the brow."""
    mat = bpy.data.materials.new("Fang_" + species)
    mat.use_nodes = True
    mat.blend_method = "OPAQUE"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.90, 0.86, 0.74, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.35
    return mat


def _clean_head_materials(obj):
    """Ensure imported animal head materials render opaque (or alpha-clip for
    fur cards) without broken glTF vertex-color alpha blending."""
    for m in obj.data.materials:
        if m is None:
            continue
        is_fur_card = "fur" in m.name.lower()
        m.blend_method = "CLIP" if is_fur_card else "OPAQUE"
        if is_fur_card:
            m.alpha_threshold = 0.35
        if m.use_nodes and m.node_tree:
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
            if bsdf and tex:
                nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
                if is_fur_card:
                    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
                else:
                    for l in list(bsdf.inputs["Alpha"].links):
                        nt.links.remove(l)
                    bsdf.inputs["Alpha"].default_value = 1.0


def _cape_params(top_z, crown_z):
    """Size the hood relative to `top_z` so every species wraps the wearer's
    skull and cheeks cleanly without flaring wider than the animal head."""
    rx = top_z * 0.50
    ry = top_z * 0.73
    cy = -top_z * 0.17
    equator = top_z * 0.04
    dome_h = max(top_z * 0.45, crown_z * 0.93 - equator)
    return rx, ry, cy, equator, dome_h


def _add_fangs(bm, head_obj, top_z):
    """Add upper canine teeth right under the sides of the upper lip arch so
    they frame the forehead subtly like Reference 1 and Reference 3."""
    vs = [v.co for v in head_obj.data.vertices]
    front_vs = [v for v in vs if abs(v.x) < 0.18 * top_z and v.y > 0.05 * top_z]
    if not front_vs:
        front_vs = vs
    max_y = max(v.y for v in front_vs)
    lip_band = [v for v in front_vs if max_y - 0.15 * top_z <= v.y <= max_y - 0.04 * top_z]
    if not lip_band:
        lip_band = front_vs
    lip_z = min(v.z for v in lip_band) + 0.012 * top_z
    lip_y = max_y - 0.08 * top_z
    canine_x = max(0.068 * top_z, min(0.105 * top_z, max(abs(v.x) for v in lip_band) * 0.65))

    fang_faces = []
    for side in (-1.0, 1.0):
        cx = side * canine_x
        fy = lip_y
        fz = lip_z
        rad = top_z * 0.014
        length = top_z * 0.052
        tilt = 0.05
        segs = 8
        ring_top = []
        ring_mid = []
        for k in range(segs):
            a = 2.0 * math.pi * k / segs
            ox = math.cos(a) * rad
            oy = math.sin(a) * rad * 0.85
            ring_top.append(bm.verts.new((cx + ox, fy + oy, fz)))
            ring_mid.append(
                bm.verts.new((cx + ox * 0.55 + side * tilt * length * 0.4, fy + oy * 0.55 - 0.003 * top_z, fz - length * 0.55))
            )
        tip = bm.verts.new((cx + side * tilt * length, fy - 0.006 * top_z, fz - length))
        for k in range(segs):
            kn = (k + 1) % segs
            fang_faces.append(bm.faces.new((ring_top[k], ring_top[kn], ring_mid[kn], ring_mid[k])))
            fang_faces.append(bm.faces.new((ring_mid[k], ring_mid[kn], tip)))
    return fang_faces


def _build_cape(species, head_obj, top_z, crown_z, has_fangs):
    """Build the volumetric fur hood + thick front paw-lappets + rear cape +
    3D shaggy fur tufts."""
    rx, ry, cy, equator, dome_h = _cape_params(top_z, crown_z)
    bm_head = bmesh.new()
    bm_head.from_mesh(head_obj.data)
    bvh_head = BVHTree.FromBMesh(bm_head)
    bm_head.free()

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    def add_grid(rows, cols, point_fn, uv_scale=(3.0, 3.0), mat_idx=0, flip=False):
        grid_verts = []
        for i in range(rows + 1):
            row = []
            for j in range(cols + 1):
                p = Vector(point_fn(i / rows, j / cols))
                row.append(bm.verts.new(p))
            grid_verts.append(row)
        for i in range(rows):
            for j in range(cols):
                v00 = grid_verts[i][j]
                v01 = grid_verts[i][j + 1]
                v11 = grid_verts[i + 1][j + 1]
                v10 = grid_verts[i + 1][j]
                corners = (v00, v10, v11, v01) if flip else (v00, v01, v11, v10)
                uvs = (
                    ((j / cols) * uv_scale[0], (i / rows) * uv_scale[1]),
                    (((j + 1) / cols) * uv_scale[0], (i / rows) * uv_scale[1]),
                    (((j + 1) / cols) * uv_scale[0], ((i + 1) / rows) * uv_scale[1]),
                    ((j / cols) * uv_scale[0], ((i + 1) / rows) * uv_scale[1]),
                )
                if flip:
                    uvs = (uvs[0], uvs[3], uvs[2], uvs[1])
                try:
                    f = bm.faces.new(corners)
                    f.material_index = mat_idx
                    f.smooth = True
                    for loop, uv in zip(f.loops, uvs):
                        loop[uv_layer].uv = uv
                except ValueError:
                    pass
        return grid_verts

    # 1. Upper hood dome (v=0 at crown behind ears -> v=1 at temple/jaw level)
    def dome_point(v, u):
        phi = 0.02 + v * (math.pi * 0.5 - 0.02)
        start_deg = 104.0 - 26.0 * (v ** 1.35)
        span_deg = 360.0 - 2.0 * start_deg
        theta = math.radians(start_deg + span_deg * u)
        x = rx * math.sin(phi) * math.sin(theta)
        y = cy + ry * math.sin(phi) * math.cos(theta)
        front_slope = max(0.0, math.cos(theta) + 0.10) * 0.24 * dome_h * (1.0 - v)
        z = equator + dome_h * math.cos(phi) - front_slope
        if y > cy and v < 0.85:
            hit_loc, _, _, _ = bvh_head.ray_cast(Vector((x, y, top_z + 0.5)), Vector((0.0, 0.0, -1.0)))
            if hit_loc is not None:
                tuck_z = hit_loc.z - 0.010 * top_z
                w_clamp = 1.0 - max(0.0, (v - 0.55) / 0.30)
                z = min(z, z * (1.0 - w_clamp) + tuck_z * w_clamp)
        return x, y, z

    add_grid(18, 64, dome_point, uv_scale=(3.2, 1.8), mat_idx=0, flip=False)
    add_grid(12, 48, lambda v, u: (dome_point(v, u)[0] * 0.96, cy + (dome_point(v, u)[1] - cy) * 0.96, dome_point(v, u)[2] - 0.004 * top_z), uv_scale=(3.2, 1.8), mat_idx=0, flip=True)

    # 2. Rear/shoulder cape: its front edges (start_deg = 78 deg) meet the back
    # of the two front paw columns so there is zero gap in side profile (Ref 2),
    # while staying narrow enough in X that nothing sticks out past the paws in
    # front view.
    def skirt_point(t, u):
        start_deg = 78.0 + 4.0 * t
        span_deg = 360.0 - 2.0 * start_deg
        theta = math.radians(start_deg + span_deg * u)
        back_w = max(0.0, -math.cos(theta))
        shoulder = max(0.0, (t - 0.35) / 0.65)
        ripple = 0.012 * top_z * math.sin(theta * 9.0 + t * 5.0) * t
        r_x = rx * 0.90 + shoulder * top_z * (0.06 + 0.10 * back_w) + ripple
        r_y = ry + shoulder * top_z * (0.10 * back_w) + ripple
        x = r_x * math.sin(theta)
        y = cy + r_y * math.cos(theta)
        drop = top_z * (1.06 + 0.26 * back_w)
        hem = top_z * 0.025 * (math.sin(u * math.pi * 13.0) + 0.5 * math.cos(u * math.pi * 25.0)) * (t ** 2)
        z = equator - t * drop + hem
        return x, y, z

    add_grid(24, 60, skirt_point, uv_scale=(2.8, 2.0), mat_idx=0, flip=False)
    add_grid(16, 44, lambda t, u: (skirt_point(t, u)[0] * 0.96, cy + (skirt_point(t, u)[1] - cy) * 0.96, skirt_point(t, u)[2]), uv_scale=(2.8, 2.0), mat_idx=0, flip=True)

    # 3. Continuous cheek-ruff + front paw-lappet columns: taper smoothly out
    # of the animal's cheek below the ear (z = +0.58*top_z) with zero step,
    # frame the wearer's face and rest on the shoulders/chest.
    def paw_spine(t, side):
        # t=0 inside upper cheek below ear (z=+0.58*top_z) -> t=1 on upper chest (z=-1.12*top_z)
        z = top_z * (0.58 - 1.70 * t)
        arch = math.sin(min(1.0, t / 0.34) * math.pi * 0.5)
        cx = side * top_z * (0.22 + 0.13 * arch - 0.020 * max(0.0, t - 0.40))
        cy_s = cy + top_z * (0.02 + 0.19 * (t ** 0.75))
        taper_top = math.sin(min(1.0, t / 0.26) * math.pi * 0.5) ** 0.75
        taper_bot = math.sin(min(1.0, (1.0 - t) / 0.16) * math.pi * 0.5)
        taper = max(0.18, taper_top * taper_bot)
        rad_x = top_z * 0.142 * taper
        rad_y = top_z * 0.135 * taper
        return cx, cy_s, z, rad_x, rad_y

    for side in (-1.0, 1.0):
        def paw_tube(t, u, _s=side):
            ang = 2.0 * math.pi * u
            cx, cy_s, z, rad_x, rad_y = paw_spine(t, _s)
            wave = 1.0 + 0.06 * math.sin(t * 17.0 + ang * 3.0)
            return cx + rad_x * wave * math.cos(ang), cy_s + rad_y * wave * math.sin(ang), z

        add_grid(30, 18, paw_tube, uv_scale=(1.4, 2.6), mat_idx=0, flip=(side < 0.0))

    # 4. Shaggy 3D fur tufts along the cheek ruff, the two front paw columns,
    # paw tips and rear silhouette (matches the spiky fur texture in Ref 1 & 2).
    rng = random.Random(101)

    def add_tuft(base_p, out_dir, down_dir, width, length):
        perp = out_dir.cross(down_dir)
        if perp.length < 1e-4:
            perp = Vector((0.0, 0.0, 1.0))
        perp.normalize()
        v0 = bm.verts.new(base_p - perp * (width * 0.5))
        v1 = bm.verts.new(base_p + perp * (width * 0.5))
        tip = bm.verts.new(base_p + out_dir * (length * 0.58) + down_dir * length)
        for corners in ((v0, v1, tip), (v1, v0, tip)):
            try:
                f = bm.faces.new(corners)
                f.material_index = 0
                f.smooth = True
                for loop, uv in zip(f.loops, ((0.2, 0.2), (0.8, 0.2), (0.5, 0.9))):
                    loop[uv_layer].uv = uv
            except ValueError:
                pass

    # Dense shaggy tufts all along both cheek/paw columns
    for side in (-1.0, 1.0):
        for i in range(60):
            t = 0.03 + 0.95 * (i / 59.0)
            cx, cy_s, z, rad_x, rad_y = paw_spine(t, side)
            for u_ang in (0.0, 0.14, 0.28, 0.42, 0.56, 0.72, 0.86):
                u_j = (u_ang + rng.uniform(-0.04, 0.04)) % 1.0
                ang = 2.0 * math.pi * u_j
                p = Vector((cx + rad_x * math.cos(ang), cy_s + rad_y * math.sin(ang), z))
                out_d = Vector((math.cos(ang), math.sin(ang), -0.22)).normalized()
                down_d = Vector((side * 0.04, 0.04, -1.0)).normalized()
                w = top_z * rng.uniform(0.034, 0.058)
                l = top_z * rng.uniform(0.060, 0.118)
                add_tuft(p - out_d * (0.008 * top_z), out_d, down_d, w, l)
        # Paw tip fringe at bottom of each front lappet
        cx_tip, cy_tip, z_tip, _, _ = paw_spine(0.98, side)
        tip_center = Vector((cx_tip, cy_tip, z_tip))
        for k in range(16):
            a = 2.0 * math.pi * k / 16.0
            off = Vector((math.cos(a) * top_z * 0.045, math.sin(a) * top_z * 0.038, 0.0))
            out_d = Vector((math.cos(a) * 0.32, math.sin(a) * 0.32, -1.0)).normalized()
            down_d = Vector((0.0, 0.0, -1.0))
            add_tuft(tip_center + off, out_d, down_d, top_z * 0.034, top_z * rng.uniform(0.070, 0.125))

    # Organic scattered tufts on crown/nape behind the ears (no grid rows)
    for _ in range(110):
        vj = rng.uniform(0.14, 0.94)
        uj = rng.uniform(0.08, 0.92)
        p = Vector(dome_point(vj, uj))
        out_d = Vector((p.x, p.y - cy, 0.10 * top_z)).normalized()
        down_d = Vector((0.0, -0.25, -1.0)).normalized()
        add_tuft(p - out_d * (0.010 * top_z), out_d, down_d, top_z * rng.uniform(0.030, 0.048), top_z * rng.uniform(0.045, 0.085))

    # Rear hem fringe
    for j in range(44):
        u = j / 43.0
        p = Vector(skirt_point(0.98, u))
        out_d = Vector((p.x, p.y - cy, -0.4 * top_z)).normalized()
        down_d = Vector((0.0, 0.0, -1.0))
        add_tuft(p, out_d, down_d, top_z * 0.036, top_z * rng.uniform(0.055, 0.100))

    # 5. Upper fangs for carnivore species (wolf, bear, fox)
    if has_fangs:
        fang_faces = _add_fangs(bm, head_obj, top_z)
        for f in fang_faces:
            f.material_index = 1
            f.smooth = True

    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("PeltCape_" + species)
    bm.to_mesh(mesh)
    bm.free()

    mesh.materials.append(_fur_material(species))
    if has_fangs:
        mesh.materials.append(_fang_material(species))

    obj = bpy.data.objects.new("PeltCape_" + species, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _finish(species, kept_objs, nose_axis, head_width, pitch_deg, has_fangs):
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

    # Pitch the snout up (+X rotation moves +Y toward +Z) so the upper jaw is
    # horizontal and the animal's eyes look straight ahead (Reference 1 & 3).
    obj.rotation_euler.x = math.radians(pitch_deg)
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

    # Seat: throat/upper jaw rests on Z=0, skull centered on the scalp axis.
    bm_seat = bmesh.new()
    bm_seat.from_mesh(obj.data)
    skull_l = bm_seat.verts.layers.float.get("pelt_skull")
    skull_vs = [v.co.copy() for v in bm_seat.verts if skull_l and v[skull_l] > 0.35]
    bm_seat.free()
    verts = [v.co for v in obj.data.vertices]
    if not skull_vs:
        skull_vs = verts
    seat_z = min(v.z for v in skull_vs)
    head_verts = [v for v in skull_vs if v.z > seat_z + 0.10 * head_width]
    if not head_verts:
        head_verts = skull_vs
    hx = sum(v.x for v in head_verts) / len(head_verts)
    hy = sum(v.y for v in head_verts) / len(head_verts)
    obj.location.x -= hx
    obj.location.y -= hy
    obj.location.z -= seat_z
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    ear_layer = bm.verts.layers.float.get("pelt_ear")
    skull_layer = bm.verts.layers.float.get("pelt_skull")
    top_z = max(v.co.z for v in bm.verts)
    cranium_zs = [
        v.co.z for v in bm.verts
        if (not ear_layer or v[ear_layer] < 0.08)
        and abs(v.co.x) < 0.22 * head_width
        and -0.25 * head_width <= v.co.y <= 0.12 * head_width
    ]
    crown_z = max(cranium_zs) if cranium_zs else top_z * 0.80
    rx, ry, cy, equator, dome_h = _cape_params(top_z, crown_z)

    # Remove lower neck faces behind the skull that belong purely to Neck1/Neck2.
    for f in list(bm.faces):
        if all(
            (not ear_layer or v[ear_layer] < 0.10)
            and (not skull_layer or v[skull_layer] < 0.18)
            and (v.co.y < -0.06 * head_width or v.co.z < 0.0)
            for v in f.verts
        ):
            bm.faces.remove(f)
    for v in list(bm.verts):
        if not v.link_faces:
            bm.verts.remove(v)

    ear_ys = [v.co.y for v in bm.verts if ear_layer and v[ear_layer] > 0.35]
    ear_back_y = min(ear_ys) if ear_ys else -0.14 * head_width
    tuck_start_y = ear_back_y + 0.02 * head_width

    # Project any remaining rear neck vertices strictly inside the hood dome.
    for v in bm.verts:
        ear_w = v[ear_layer] if ear_layer else 0.0
        if ear_w >= 0.30:
            continue
        if v.co.y < tuck_start_y or v.co.z < 0.0:
            blend = min(1.0, max(0.35, (tuck_start_y - v.co.y) / maxf(0.06 * head_width)))
            if v.co.z < -0.04 * top_z:
                v.co.z = -0.04 * top_z
            nx = v.co.x / maxf(rx)
            ny = (v.co.y - cy) / maxf(ry)
            nz = max(0.0, v.co.z - equator) / maxf(dome_h)
            r_ell = math.sqrt(nx * nx + ny * ny + nz * nz)
            target_r = 0.85
            if r_ell > target_r:
                k = 1.0 - blend * (1.0 - target_r / r_ell)
                v.co.x *= k
                v.co.y = cy + (v.co.y - cy) * k
                if v.co.z > equator:
                    v.co.z = equator + (v.co.z - equator) * k

    bm.to_mesh(obj.data)
    bm.free()
    _clean_head_materials(obj)
    obj.select_set(False)

    # Draped pelt hood + thick front paw-lappets + fangs.
    cape = _build_cape(species, obj, top_z, crown_z, has_fangs)
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


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kinds = args or list(SPECIES.keys())
    for species in kinds:
        if species not in SPECIES:
            raise ValueError(f"Unknown species: {species}")
        src, head_width, pitch_deg, has_fangs = SPECIES[species]
        src_abs = os.path.join(ROOT, src)
        if not os.path.isfile(src_abs):
            print(f"{species}: missing {src_abs}, skipping")
            continue
        kept, axis = _build_head(species, src_abs)
        _finish(species, kept, axis, head_width, pitch_deg, has_fangs)
