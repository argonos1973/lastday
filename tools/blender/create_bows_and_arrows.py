"""Model high-detail survival bows, arrows, rope coils, animal bones and sinew in Blender.

Outputs:
  assets/models/weapons/wooden_bow.glb
  assets/models/weapons/reinforced_bow.glb
  assets/models/weapons/arrow_wood.glb
  assets/models/weapons/arrow_stone.glb
  assets/models/weapons/arrow_bone.glb
  assets/models/props/rope_coil.glb
  assets/models/props/animal_bone.glb
  assets/models/props/animal_sinew.glb

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/create_bows_and_arrows.py
"""
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "models" / "weapons"
PROPS_DIR = ROOT / "assets" / "models" / "props"


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


def add_lofted_tube(name: str, spine_pts, mat, closed_caps: bool = True, sides: int = 16, ref_axis: Vector = None):
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
        if ref_axis is not None and abs(tangent.dot(ref_axis)) < 0.92:
            ref = ref_axis
        else:
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


def add_uv_sphere(name: str, center: Vector, radii: Vector, mat, rot_euler=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=1.0, location=center, rotation=rot_euler)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def build_bow(reinforced: bool, out_path: Path):
    clear_scene()
    wood_mat = make_mat("Bow_Wood", (0.38, 0.23, 0.11) if not reinforced else (0.29, 0.16, 0.08), rough=0.72)
    leather_mat = make_mat("Bow_Leather", (0.19, 0.11, 0.06), rough=0.84)
    sinew_mat = make_mat("Bow_Sinew", (0.72, 0.63, 0.45), rough=0.80)
    bone_mat = make_mat("Bow_Bone", (0.87, 0.84, 0.75), rough=0.58)
    string_mat = make_mat("Bow_String", (0.78, 0.72, 0.56), rough=0.75)

    # Center the leather grip at (0, 0, 0) so the archer's left hand holds the
    # riser directly. Limb tips curve back toward +Y in Blender (+Z in Godot).
    limb_samples = 41
    spine = []
    for i in range(limb_samples):
        u = -1.0 + 2.0 * i / (limb_samples - 1)  # -1 .. +1
        z = u * 0.62
        arch = (1.0 - u * u) * 0.24
        recurve = 0.0
        if reinforced and abs(u) > 0.65:
            t_rec = (abs(u) - 0.65) / 0.35
            recurve = -0.095 * (t_rec * t_rec)
        y = (arch + recurve) - 0.24
        riser_bulge = math.exp(-(u * u) / 0.045) * 0.008
        taper = max(0.0055, 0.016 * (1.0 - 0.62 * abs(u)) + riser_bulge)
        rx = taper * 0.85
        ry = taper * 1.15
        spine.append((Vector((0.0, y, z)), rx, ry))

    add_lofted_tube("BowStave", spine, wood_mat, closed_caps=True, sides=20)

    grip_pts = []
    for i in range(15):
        u = -0.14 + 0.28 * i / 14.0
        z = u * 0.62
        y = (1.0 - u * u) * 0.24 - 0.24
        r = 0.0225 + 0.0015 * math.sin(i * math.pi)
        grip_pts.append((Vector((0.0, y, z)), r * 0.92, r * 1.18))
    add_lofted_tube("BowGrip", grip_pts, leather_mat, closed_caps=True, sides=18)

    for collar_u in (-0.15, 0.15):
        z = collar_u * 0.62
        y = (1.0 - collar_u * collar_u) * 0.24 - 0.24
        ring_pts = [
            (Vector((0.0, y, z - 0.012)), 0.023, 0.026),
            (Vector((0.0, y, z)), 0.024, 0.027),
            (Vector((0.0, y, z + 0.012)), 0.023, 0.026),
        ]
        add_lofted_tube(f"GripLashing_{collar_u:+.2f}", ring_pts, sinew_mat, closed_caps=True, sides=16)

    if reinforced:
        for sign in (-1.0, 1.0):
            plate_pts = []
            for j in range(11):
                u = sign * (0.24 + 0.42 * j / 10.0)
                z = u * 0.62
                arch = (1.0 - u * u) * 0.24
                y = arch - 0.24 + 0.013
                w = 0.013 * (1.0 - 0.35 * (j / 10.0))
                plate_pts.append((Vector((0.0, y, z)), w, 0.0055))
            if sign < 0:
                plate_pts.reverse()
            add_lofted_tube(f"BoneBacking_{int(sign)}", plate_pts, bone_mat, closed_caps=True, sides=12)

            tip_pts = []
            for j in range(8):
                u = sign * (0.80 + 0.20 * j / 7.0)
                z = u * 0.62
                t_rec = max(0.0, (abs(u) - 0.65) / 0.35)
                y = ((1.0 - u * u) * 0.24 - 0.095 * t_rec * t_rec) - 0.24
                r = max(0.0045, 0.011 * (1.0 - 0.55 * j / 7.0))
                tip_pts.append((Vector((0.0, y, z)), r * 0.9, r * 1.2))
            if sign < 0:
                tip_pts.reverse()
            add_lofted_tube(f"BoneSiyah_{int(sign)}", tip_pts, bone_mat, closed_caps=True, sides=14)

            for bind_u in (0.30, 0.50, 0.68):
                bu = sign * bind_u
                bz = bu * 0.62
                by = (1.0 - bu * bu) * 0.24 - 0.24
                br = max(0.009, 0.019 * (1.0 - 0.55 * abs(bu)))
                b_pts = [
                    (Vector((0.0, by, bz - 0.010)), br, br * 1.22),
                    (Vector((0.0, by, bz)), br * 1.05, br * 1.26),
                    (Vector((0.0, by, bz + 0.010)), br, br * 1.22),
                ]
                add_lofted_tube(f"SinewBind_{bu:+.2f}", b_pts, sinew_mat, closed_caps=True, sides=14)

    top_pt = spine[-1][0] + Vector((0.0, -0.006, -0.012))
    bot_pt = spine[0][0] + Vector((0.0, -0.006, 0.012))
    mid_pt = (top_pt + bot_pt) * 0.5
    str_pts = [
        (bot_pt, 0.0022, 0.0022),
        (mid_pt - Vector((0.0, 0.0, 0.04)), 0.0022, 0.0022),
        (mid_pt, 0.0032, 0.0032),
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

    shaft_pts = [
        (Vector((0.0, 0.36, 0.0)), 0.0042, 0.0042),
        (Vector((0.0, 0.0, 0.0)), 0.0046, 0.0046),
        (Vector((0.0, -0.32, 0.0)), 0.0044, 0.0044),
    ]
    add_lofted_tube("ArrowShaft", shaft_pts, wood_mat, closed_caps=True, sides=12)

    for by in (-0.31, 0.22, 0.33):
        b_pts = [
            (Vector((0.0, by - 0.008, 0.0)), 0.0052, 0.0052),
            (Vector((0.0, by + 0.008, 0.0)), 0.0052, 0.0052),
        ]
        add_lofted_tube(f"ArrowBind_{by:+.2f}", b_pts, sinew_mat, closed_caps=True, sides=12)

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


def build_rope_coil(out_path: Path):
    """Braided hemp rope coil with stacked concentric turns, cinch wraps and frayed tail ends."""
    clear_scene()
    hemp_main = make_mat("Rope_HempMain", (0.46, 0.34, 0.19), rough=0.88)
    hemp_dark = make_mat("Rope_HempDark", (0.31, 0.22, 0.12), rough=0.92)
    wrap_mat = make_mat("Rope_Wrap", (0.24, 0.16, 0.09), rough=0.86)

    # Stacked spiral coil lying mostly flat, slightly tilted for 3D readability
    # Twist 2 braided strands around the helical centerline so the rope reads as twisted cordage
    turns = 4.25
    total_samples = 180
    for strand_idx in range(2):
        mat = hemp_main if strand_idx == 0 else hemp_dark
        phase = strand_idx * math.pi
        pts = []
        for i in range(total_samples):
            t = i / (total_samples - 1)
            ang = t * turns * 2.0 * math.pi
            layer = int(t * 2.0)
            radial_prog = (t * 2.0) % 1.0
            base_r = 0.068 + radial_prog * 0.044
            # Slight oval natural sag
            cx = math.cos(ang) * base_r * 1.12
            cy = math.sin(ang) * base_r * 0.94
            cz = 0.016 + layer * 0.017 + 0.003 * math.sin(ang * 2.0)
            # Local strand twist around the rope core
            twist_ang = t * turns * 26.0 * math.pi + phase
            rad_vec = Vector((math.cos(ang), math.sin(ang), 0.0))
            up_vec = Vector((0.0, 0.0, 1.0))
            offset = rad_vec * (math.cos(twist_ang) * 0.0038) + up_vec * (math.sin(twist_ang) * 0.0038)
            pts.append((Vector((cx, cy, cz)) + offset, 0.0072, 0.0068))
        add_lofted_tube(f"RopeStrand_{strand_idx}", pts, mat, closed_caps=True, sides=12, ref_axis=Vector((0.0, 0.0, 1.0)))

    # Two cross-binding wraps holding the coil bundled on opposite sides
    for side_sign in (-1.0, 1.0):
        bx = side_sign * 0.096
        for wrap_i in (-1, 0, 1):
            wy = wrap_i * 0.009
            ring = []
            for k in range(20):
                a = 2.0 * math.pi * k / 19.0
                px = bx + math.cos(a) * 0.030
                py = wy + math.sin(a) * 0.004
                pz = 0.025 + math.sin(a) * 0.022
                ring.append((Vector((px, py, pz)), 0.0048, 0.0048))
            add_lofted_tube(f"CoilTie_{int(side_sign)}_{wrap_i}", ring, wrap_mat, closed_caps=True, sides=10)

    # Loose tail end curving out from the coil with 3 frayed fibers
    tail_pts = [
        (Vector((0.095, -0.02, 0.022)), 0.0085, 0.0085),
        (Vector((0.125, -0.055, 0.016)), 0.0082, 0.0082),
        (Vector((0.145, -0.095, 0.011)), 0.0075, 0.0075),
    ]
    add_lofted_tube("RopeTail", tail_pts, hemp_main, closed_caps=True, sides=12)
    for fray_i in (-1, 0, 1):
        f_pts = [
            (Vector((0.142, -0.090, 0.011)), 0.0036, 0.0036),
            (Vector((0.160 + fray_i * 0.008, -0.118 + abs(fray_i) * 0.004, 0.008 + fray_i * 0.003)), 0.0020, 0.0020),
        ]
        add_lofted_tube(f"RopeFray_{fray_i}", f_pts, hemp_dark, closed_caps=True, sides=8)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_yup=True)
    print(f"Exported {out_path}")


def build_animal_bone(out_path: Path):
    """Anatomical harvested animal bone bundle: femur with dual condyles, marrow tint & curved rib."""
    clear_scene()
    ivory_mat = make_mat("Bone_Ivory", (0.66, 0.60, 0.48), rough=0.68)
    joint_mat = make_mat("Bone_Cartilage", (0.52, 0.45, 0.35), rough=0.74)
    marrow_mat = make_mat("Bone_Periosteum", (0.44, 0.14, 0.11), rough=0.76)

    # Main femur shaft along Y with natural anterior bow
    shaft_pts = []
    for i in range(17):
        u = -1.0 + 2.0 * i / 16.0
        y = u * 0.165
        # Flare out at the metaphyses near both ends
        flare = 0.012 * (u ** 4)
        arch_z = 0.022 + (1.0 - u * u) * 0.008
        arch_x = math.sin(u * 1.4) * 0.006
        rx = 0.0135 + flare * 1.35
        rz = 0.0120 + flare * 0.95
        shaft_pts.append((Vector((arch_x, y, arch_z)), rx, rz))
    add_lofted_tube("FemurShaft", shaft_pts, ivory_mat, closed_caps=True, sides=18)

    # Subtle fresh periosteum / marrow collar near the proximal neck
    collar_pts = [
        (Vector((0.0, -0.105, 0.025)), 0.0155, 0.0140),
        (Vector((0.0, -0.080, 0.027)), 0.0150, 0.0135),
        (Vector((0.0, -0.058, 0.028)), 0.0142, 0.0128),
    ]
    add_lofted_tube("FemurPeriosteum", collar_pts, marrow_mat, closed_caps=True, sides=16)

    # Proximal femoral head + greater trochanter (-Y end)
    add_uv_sphere("FemoralHead", Vector((0.024, -0.178, 0.028)), Vector((0.024, 0.022, 0.022)), joint_mat)
    add_uv_sphere("GreaterTrochanter", Vector((-0.020, -0.165, 0.024)), Vector((0.019, 0.023, 0.018)), ivory_mat)
    # Distal medial & lateral condyles (+Y end)
    add_uv_sphere("CondyleMedial", Vector((0.018, 0.172, 0.022)), Vector((0.021, 0.025, 0.021)), joint_mat)
    add_uv_sphere("CondyleLateral", Vector((-0.018, 0.172, 0.022)), Vector((0.021, 0.025, 0.021)), joint_mat)

    # Accompanying curved rib bone resting beside the femur for rich silhouette on the ground
    rib_pts = []
    for i in range(15):
        t = i / 14.0
        ang = -0.35 + t * 1.55
        rx_pos = 0.032 + math.sin(ang) * 0.068
        ry_pos = -0.115 + t * 0.215
        rz_pos = 0.012 + math.sin(t * math.pi) * 0.014
        taper = max(0.0035, 0.0085 * math.sin(t * math.pi * 0.88 + 0.12))
        rib_pts.append((Vector((rx_pos, ry_pos, rz_pos)), taper * 1.35, taper * 0.72))
    add_lofted_tube("RibBone", rib_pts, ivory_mat, closed_caps=True, sides=14)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_yup=True)
    print(f"Exported {out_path}")


def build_animal_sinew(out_path: Path):
    """Harvested animal tendon/sinew bundle: glossy collagen fibers with fleshy muscle insertions."""
    clear_scene()
    collagen_light = make_mat("Sinew_CollagenLight", (0.62, 0.51, 0.36), rough=0.52)
    collagen_amber = make_mat("Sinew_CollagenAmber", (0.48, 0.36, 0.23), rough=0.58)
    muscle_end = make_mat("Sinew_MuscleAttachment", (0.42, 0.11, 0.09), rough=0.68)

    # 4 intertwined glistening tendon cords forming an S-curved anatomical bundle
    offsets = [
        (Vector((-0.010, 0.0, 0.014)), 0.0078, collagen_light, 0.0),
        (Vector((0.010, 0.0, 0.015)), 0.0074, collagen_amber, 1.6),
        (Vector((0.0, 0.0, 0.022)), 0.0082, collagen_light, 3.1),
        (Vector((-0.004, 0.0, 0.010)), 0.0065, collagen_amber, 4.7),
    ]
    for idx, (base_off, rad, mat, phase) in enumerate(offsets):
        pts = []
        for i in range(21):
            u = -1.0 + 2.0 * i / 20.0
            y = u * 0.145
            # Gentle S-curve + helical twist
            sway_x = math.sin(u * 1.8) * 0.018 + math.cos(u * 4.5 + phase) * 0.006
            sway_z = math.sin(u * 4.5 + phase) * 0.004 + (1.0 - u * u) * 0.005
            # Thick tendon belly in the middle, tapering into flat aponeurosis at ends
            belly = 0.65 + 0.55 * (1.0 - u * u)
            pts.append((Vector((base_off.x + sway_x, y, base_off.z + sway_z)), rad * belly * 1.15, rad * belly * 0.82))
        add_lofted_tube(f"TendonCord_{idx}", pts, mat, closed_caps=True, sides=14)

    # Fleshy red-brown myotendinous junctions at both ends where the sinew was cut from the muscle
    for sign, y_base in ((-1.0, -0.115), (1.0, 0.115)):
        m_pts = [
            (Vector((sign * 0.012, y_base - sign * 0.018, 0.014)), 0.014, 0.010),
            (Vector((sign * 0.015, y_base, 0.015)), 0.017, 0.012),
            (Vector((sign * 0.017, y_base + sign * 0.022, 0.013)), 0.011, 0.008),
        ]
        if sign < 0:
            m_pts.reverse()
        add_lofted_tube(f"MuscleJunction_{int(sign)}", m_pts, muscle_end, closed_caps=True, sides=14)

    # Central sinew wrap binding the harvested bundle together
    for k in (-1, 0, 1):
        wy = k * 0.008
        ring = []
        for s in range(18):
            a = 2.0 * math.pi * s / 17.0
            px = math.cos(a) * 0.018
            pz = 0.016 + math.sin(a) * 0.012
            ring.append((Vector((px, wy, pz)), 0.0036, 0.0036))
        add_lofted_tube(f"SinewTie_{k}", ring, collagen_amber, closed_caps=True, sides=10)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", export_yup=True)
    print(f"Exported {out_path}")


if __name__ == "__main__":
    build_bow(False, OUT_DIR / "wooden_bow.glb")
    build_bow(True, OUT_DIR / "reinforced_bow.glb")
    build_arrow("wood", OUT_DIR / "arrow_wood.glb")
    build_arrow("stone", OUT_DIR / "arrow_stone.glb")
    build_arrow("bone", OUT_DIR / "arrow_bone.glb")
    build_rope_coil(PROPS_DIR / "rope_coil.glb")
    build_animal_bone(PROPS_DIR / "animal_bone.glb")
    build_animal_sinew(PROPS_DIR / "animal_sinew.glb")
