"""Model high-detail survival bows and arrows in Blender and export GLBs.

Outputs:
  assets/models/weapons/wooden_bow.glb
  assets/models/weapons/reinforced_bow.glb
  assets/models/weapons/arrow_wood.glb
  assets/models/weapons/arrow_stone.glb
  assets/models/weapons/arrow_bone.glb

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/create_bows_and_arrows.py
"""
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "models" / "weapons"


def make_mat(name: str, color, rough: float = 0.78, metallic: float = 0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def add_lofted_tube(name: str, spine_pts, mat, closed_caps: bool = True, sides: int = 16):
    """Build a smooth lofted tube along [(Vector(x,y,z), rx, rz), ...]."""
    bm = bmesh.new()
    rings = []
    n_pts = len(spine_pts)
    for i, (pt, rx, rz) in enumerate(spine_pts):
        if i == 0:
            tangent = (spine_pts[1][0] - pt).normalized()
        elif i == n_pts - 1:
            tangent = (pt - spine_pts[i - 1][0]).normalized()
        else:
            tangent = (spine_pts[i + 1][0] - spine_pts[i - 1][0]).normalized()
        # Keep normal strictly in the X direction (out of the bow's Y-Z plane)
        # so binormal stays in the Y-Z plane and the bow's D/S curve is never flattened.
        ref = Vector((1.0, 0.0, 0.0)) if abs(tangent.x) < 0.9 else Vector((0.0, 1.0, 0.0))
        binormal = tangent.cross(ref).normalized()
        normal = binormal.cross(tangent).normalized()
        ring = []
        for s in range(sides):
            ang = 2.0 * math.pi * s / sides
            offset = normal * (math.cos(ang) * rx) + binormal * (math.sin(ang) * rz)
            ring.append(bm.verts.new(pt + offset))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    if closed_caps and rings:
        c0 = bm.verts.new(spine_pts[0][0])
        c1 = bm.verts.new(spine_pts[-1][0])
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((rings[0][sn], rings[0][s], c0))
            bm.faces.new((rings[-1][s], rings[-1][sn], c1))
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_bow(reinforced: bool, out_path: Path):
    clear_scene()
    wood_mat = make_mat("Bow_Wood", (0.38, 0.23, 0.11) if not reinforced else (0.29, 0.16, 0.08), rough=0.72)
    leather_mat = make_mat("Bow_Leather", (0.19, 0.11, 0.06), rough=0.84)
    sinew_mat = make_mat("Bow_Sinew", (0.72, 0.63, 0.45), rough=0.80)
    bone_mat = make_mat("Bow_Bone", (0.87, 0.84, 0.75), rough=0.58)
    string_mat = make_mat("Bow_String", (0.78, 0.72, 0.56), rough=0.75)

    # Blender coordinates (Z up, -Y forward when exported with export_yup=True -> Y up, +Z/-Z in Godot)
    # We model with Z as the vertical limb axis [-0.62 .. +0.62] and -Y as forward (belly/back of bow).
    limb_samples = 41
    spine = []
    for i in range(limb_samples):
        u = -1.0 + 2.0 * i / (limb_samples - 1)  # -1 .. +1
        z = u * 0.62
        # Self-bow D-profile curve vs recurve S-profile for reinforced bow
        arch = (1.0 - u * u) * 0.24
        recurve = 0.0
        if reinforced and abs(u) > 0.65:
            t_rec = (abs(u) - 0.65) / 0.35
            recurve = -0.095 * (t_rec * t_rec)
        y = -(arch + recurve)
        # Thickness tapers from riser (centre) to nock tips
        riser_bulge = math.exp(-(u * u) / 0.045) * 0.008
        taper = max(0.0055, 0.016 * (1.0 - 0.62 * abs(u)) + riser_bulge)
        rx = taper * 0.85
        ry = taper * 1.15
        spine.append((Vector((0.0, y, z)), rx, ry))

    add_lofted_tube("BowStave", spine, wood_mat, closed_caps=True, sides=20)

    # Leather grip wrap with spiral cord ridges around the centre riser
    grip_pts = []
    for i in range(15):
        u = -0.14 + 0.28 * i / 14.0
        z = u * 0.62
        y = -(1.0 - u * u) * 0.24
        r = 0.0225 + 0.0015 * math.sin(i * math.pi)
        grip_pts.append((Vector((0.0, y, z)), r * 0.92, r * 1.18))
    add_lofted_tube("BowGrip", grip_pts, leather_mat, closed_caps=True, sides=18)

    # Arrow rest notch & lashing rings above and below the grip
    for collar_u in (-0.15, 0.15):
        z = collar_u * 0.62
        y = -(1.0 - collar_u * collar_u) * 0.24
        ring_pts = [
            (Vector((0.0, y, z - 0.012)), 0.023, 0.026),
            (Vector((0.0, y, z)), 0.024, 0.027),
            (Vector((0.0, y, z + 0.012)), 0.023, 0.026),
        ]
        add_lofted_tube(f"GripLashing_{collar_u:+.2f}", ring_pts, sinew_mat, closed_caps=True, sides=16)

    if reinforced:
        # Bone backing plates along upper/lower limbs + bone recurve siyah tips + extra sinew bindings
        for sign in (-1.0, 1.0):
            plate_pts = []
            for j in range(11):
                u = sign * (0.24 + 0.42 * j / 10.0)
                z = u * 0.62
                arch = (1.0 - u * u) * 0.24
                y = -arch - 0.013
                w = 0.013 * (1.0 - 0.35 * (j / 10.0))
                plate_pts.append((Vector((0.0, y, z)), w, 0.0055))
            if sign < 0:
                plate_pts.reverse()
            add_lofted_tube(f"BoneBacking_{int(sign)}", plate_pts, bone_mat, closed_caps=True, sides=12)

            # Recurve bone tip (siyah)
            tip_pts = []
            for j in range(8):
                u = sign * (0.80 + 0.20 * j / 7.0)
                z = u * 0.62
                t_rec = max(0.0, (abs(u) - 0.65) / 0.35)
                y = -((1.0 - u * u) * 0.24 - 0.095 * t_rec * t_rec)
                r = max(0.0045, 0.011 * (1.0 - 0.55 * j / 7.0))
                tip_pts.append((Vector((0.0, y, z)), r * 0.9, r * 1.2))
            if sign < 0:
                tip_pts.reverse()
            add_lofted_tube(f"BoneSiyah_{int(sign)}", tip_pts, bone_mat, closed_caps=True, sides=14)

            for bind_u in (0.30, 0.50, 0.68):
                bu = sign * bind_u
                bz = bu * 0.62
                by = -(1.0 - bu * bu) * 0.24
                br = max(0.009, 0.019 * (1.0 - 0.55 * abs(bu)))
                b_pts = [
                    (Vector((0.0, by, bz - 0.010)), br, br * 1.22),
                    (Vector((0.0, by, bz)), br * 1.05, br * 1.26),
                    (Vector((0.0, by, bz + 0.010)), br, br * 1.22),
                ]
                add_lofted_tube(f"SinewBind_{bu:+.2f}", b_pts, sinew_mat, closed_caps=True, sides=14)

    # Bowstring from lower nock to upper nock
    top_pt = spine[-1][0] + Vector((0.0, 0.006, -0.012))
    bot_pt = spine[0][0] + Vector((0.0, 0.006, 0.012))
    mid_pt = (top_pt + bot_pt) * 0.5
    str_pts = [
        (bot_pt, 0.0022, 0.0022),
        (mid_pt - Vector((0.0, 0.0, 0.04)), 0.0022, 0.0022),
        (mid_pt, 0.0032, 0.0032),  # center serving wrap
        (mid_pt + Vector((0.0, 0.0, 0.04)), 0.0022, 0.0022),
        (top_pt, 0.0022, 0.0022),
    ]
    add_lofted_tube("BowString", str_pts, string_mat, closed_caps=True, sides=10)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_yup=True)
    print(f"Exported {out_path}")


def build_arrow(kind: str, out_path: Path):
    clear_scene()
    wood_mat = make_mat("Arrow_Shaft", (0.46, 0.31, 0.16), rough=0.74)
    sinew_mat = make_mat("Arrow_Sinew", (0.68, 0.58, 0.40), rough=0.82)
    feather_mat = make_mat("Arrow_Feather", (0.82, 0.80, 0.75), rough=0.80)
    stone_mat = make_mat("Arrow_Stone", (0.28, 0.30, 0.32), rough=0.86)
    bone_mat = make_mat("Arrow_Bone", (0.88, 0.85, 0.76), rough=0.58)
    char_mat = make_mat("Arrow_FireHardened", (0.18, 0.11, 0.06), rough=0.68)

    # Shaft along Y axis in Blender (-Y forward -> -Z in Godot after export_yup)
    shaft_pts = [
        (Vector((0.0, 0.36, 0.0)), 0.0042, 0.0042),
        (Vector((0.0, 0.0, 0.0)), 0.0046, 0.0046),
        (Vector((0.0, -0.32, 0.0)), 0.0044, 0.0044),
    ]
    add_lofted_tube("ArrowShaft", shaft_pts, wood_mat, closed_caps=True, sides=12)

    # Sinew binding behind arrowhead and at fletching
    for by in (-0.31, 0.22, 0.33):
        b_pts = [
            (Vector((0.0, by - 0.008, 0.0)), 0.0052, 0.0052),
            (Vector((0.0, by + 0.008, 0.0)), 0.0052, 0.0052),
        ]
        add_lofted_tube(f"ArrowBind_{by:+.2f}", b_pts, sinew_mat, closed_caps=True, sides=12)

    # Arrowhead at -Y
    if kind == "wood":
        tip_pts = [
            (Vector((0.0, -0.31, 0.0)), 0.0048, 0.0048),
            (Vector((0.0, -0.36, 0.0)), 0.0032, 0.0032),
            (Vector((0.0, -0.41, 0.0)), 0.0006, 0.0006),
        ]
        add_lofted_tube("ArrowHead", tip_pts, char_mat, closed_caps=True, sides=12)
    else:
        head_mat = bone_mat if kind == "bone" else stone_mat
        w_scale = 0.011 if kind == "bone" else 0.014
        tip_pts = [
            (Vector((0.0, -0.31, 0.0)), 0.0045, 0.0030),
            (Vector((0.0, -0.335, 0.0)), w_scale, 0.0032),
            (Vector((0.0, -0.375, 0.0)), w_scale * 0.65, 0.0024),
            (Vector((0.0, -0.425, 0.0)), 0.0006, 0.0006),
        ]
        add_lofted_tube("ArrowHead", tip_pts, head_mat, closed_caps=True, sides=10)

    # 3 parabolic feather vanes at the rear (+Y)
    for vane_idx in range(3):
        ang = vane_idx * (2.0 * math.pi / 3.0)
        bm = bmesh.new()
        steps = 8
        inner_v = []
        outer_v = []
        for s in range(steps + 1):
            t = s / steps
            y = 0.22 + t * 0.11
            height = math.sin(t * math.pi) ** 0.7 * 0.016 + 0.002
            rad_dir = Vector((math.cos(ang), 0.0, math.sin(ang)))
            tan_dir = Vector((-math.sin(ang), 0.0, math.cos(ang)))
            v_in = bm.verts.new(Vector((0.0, y, 0.0)) + rad_dir * 0.0042)
            v_out = bm.verts.new(Vector((0.0, y + 0.008 * t, 0.0)) + rad_dir * (0.0042 + height) + tan_dir * 0.0008)
            inner_v.append(v_in)
            outer_v.append(v_out)
        for s in range(steps):
            bm.faces.new((inner_v[s], inner_v[s + 1], outer_v[s + 1], outer_v[s]))
        bm.normal_update()
        fmesh = bpy.data.meshes.new(f"FeatherVane_{vane_idx}")
        bm.to_mesh(fmesh)
        bm.free()
        fobj = bpy.data.objects.new(f"FeatherVane_{vane_idx}", fmesh)
        bpy.context.collection.objects.link(fobj)
        fobj.data.materials.append(feather_mat)
        mod = fobj.modifiers.new("Solid", "SOLIDIFY")
        mod.thickness = 0.0014
        bpy.context.view_layer.objects.active = fobj
        bpy.ops.object.modifier_apply(modifier="Solid")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_yup=True)
    print(f"Exported {out_path}")


if __name__ == "__main__":
    build_bow(False, OUT_DIR / "wooden_bow.glb")
    build_bow(True, OUT_DIR / "reinforced_bow.glb")
    build_arrow("wood", OUT_DIR / "arrow_wood.glb")
    build_arrow("stone", OUT_DIR / "arrow_stone.glb")
    build_arrow("bone", OUT_DIR / "arrow_bone.glb")
