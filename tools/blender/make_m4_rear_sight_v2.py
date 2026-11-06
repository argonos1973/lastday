import bpy
import bmesh
import math
import os

# High-detail realistic M4 A2/LMT rear iron sight + A2 front sight assembly
# authored in the exact coordinate space of m4_carbine_rifle.glb.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/make_m4_rear_sight_v2.py

REPO = "/Volumes/copia/lastday2"
M4_GLB = os.path.join(REPO, "assets/models/weapons/m4_carbine_rifle.glb")
OUT_GLB = os.path.join(REPO, "assets/models/weapons/m4_rear_sight.glb")

SIGHT_LINE = 0.05820   # compact sight line height above rail (Z in Blender, Y in Godot)
Y_REAR = 0.04300       # rear rail slot (+Y in Blender = -Z in Godot)
Y_FRONT = -0.04450     # front sight station (-Y in Blender = +Z in Godot)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=M4_GLB)

gun_mat = None
for obj in bpy.data.objects:
    if obj.type == "MESH" and obj.data.materials:
        gun_mat = obj.data.materials[0]
        break

for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

parts = []


def add_mesh_from_pydata(name, verts, faces, uv_coord=(0.28, 0.28), smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if gun_mat is not None:
        me.materials.append(gun_mat)
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        uv.data[loop.index].uv = uv_coord
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    parts.append(obj)
    return obj


def extrude_profile_y(name, profile_xz, y0, y1, bevel_y=0.00008, uv_coord=(0.28, 0.28)):
    """Extrudes a 2D closed polygon in (X, Z) along Y from y0 to y1 with
    chamfered front/back edges and flat caps (split normals so flat faces stay
    perfectly flat instead of ballooning)."""
    n = len(profile_xz)
    cx = sum(p[0] for p in profile_xz) / n
    cz = sum(p[1] for p in profile_xz) / n
    verts = []
    rings_y = [y0, y0 + bevel_y, y1 - bevel_y, y1]
    shrinks = [0.955, 1.0, 1.0, 0.955]
    for ry, sh in zip(rings_y, shrinks):
        for px, pz in profile_xz:
            vx = cx + (px - cx) * sh
            vz = cz + (pz - cz) * sh
            verts.append((vx, ry, vz))
    faces = []
    for r in range(3):
        base0 = r * n
        base1 = (r + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((base0 + i, base0 + j, base1 + j, base1 + i))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(3 * n + i for i in range(n)))
    return add_mesh_from_pydata(name, verts, faces, uv_coord=uv_coord, smooth=False)


def add_machined_aperture_disc(name, r_in, r_out, y_center, half_thick, seg=96):
    """Builds a real flat-faced Parkerized steel diopter disc with a separate
    countersunk inner cone and chamfered outer rim so the front/rear faces stay
    razor-flat while the circular rim and peep hole are silky smooth."""
    b_in = half_thick * 0.45
    b_out = half_thick * 0.28
    r_in_edge = r_in + b_in * 0.48
    r_out_edge = r_out - b_out * 0.65

    # Part A: Smooth circumferential surfaces (inner bore + inner bevels + outer rim + outer bevels)
    # Using split rings for sharp transitions to the flat front/back faces.
    cyl_rings = [
        # Inner countersink + bore
        ((r_in_edge, +half_thick), (r_in, +half_thick - b_in)),
        ((r_in, +half_thick - b_in), (r_in, -half_thick + b_in)),
        ((r_in, -half_thick + b_in), (r_in_edge, -half_thick)),
        # Outer bevels + outer cylinder
        ((r_out_edge, -half_thick), (r_out, -half_thick + b_out)),
        ((r_out, -half_thick + b_out), (r_out, +half_thick - b_out)),
        ((r_out, +half_thick - b_out), (r_out_edge, +half_thick)),
    ]
    for idx, ((r0, dy0), (r1, dy1)) in enumerate(cyl_rings):
        verts = []
        faces = []
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            ca, sa = math.cos(a), math.sin(a)
            verts.append((r0 * ca, y_center + dy0, SIGHT_LINE + r0 * sa))
            verts.append((r1 * ca, y_center + dy1, SIGHT_LINE + r1 * sa))
        for i in range(seg):
            ni = (i + 1) % seg
            v0 = i * 2
            v1 = ni * 2
            v2 = ni * 2 + 1
            v3 = i * 2 + 1
            faces.append((v0, v1, v2, v3))
        add_mesh_from_pydata(f"{name}_ring_{idx}", verts, faces, uv_coord=(0.24, 0.24), smooth=True)

    # Part B: Perfectly flat front (+Y, shooter side) and back (-Y, muzzle side) annular faces
    for side_sign, suffix in [(+1.0, "front"), (-1.0, "back")]:
        verts = []
        faces = []
        y_val = y_center + side_sign * half_thick
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            ca, sa = math.cos(a), math.sin(a)
            verts.append((r_in_edge * ca, y_val, SIGHT_LINE + r_in_edge * sa))
            verts.append((r_out_edge * ca, y_val, SIGHT_LINE + r_out_edge * sa))
        for i in range(seg):
            ni = (i + 1) % seg
            v0 = i * 2
            v1 = ni * 2
            v2 = ni * 2 + 1
            v3 = i * 2 + 1
            if side_sign > 0:
                faces.append((v0, v3, v2, v1))
            else:
                faces.append((v0, v1, v2, v3))
        add_mesh_from_pydata(f"{name}_{suffix}", verts, faces, uv_coord=(0.22, 0.22), smooth=False)


# =========================================================================
# 1. REAR SIGHT ASSEMBLY (A2 / LMT tactical rear sight at Y_REAR)
# =========================================================================

# 1a. Flat-faced Parkerized peep aperture disc + integral lower stem
R_IN = 0.00048
R_OUT = 0.00067
add_machined_aperture_disc("RearPeepDisc", R_IN, R_OUT, Y_REAR, 0.00018, seg=96)

# Integral neck/stem seamlessly uniting the peep disc bottom to the cradle floor
stem_profile = [
    (-0.00028, 0.05685),
    (0.00028, 0.05685),
    (0.00023, 0.05725),
    (0.00025, 0.05750),
    (0.00028, 0.05770),
    (-0.00028, 0.05770),
    (-0.00025, 0.05750),
    (-0.00023, 0.05725),
]
extrude_profile_y("RearPeepStem", stem_profile, Y_REAR - 0.00015, Y_REAR + 0.00015, bevel_y=0.00003, uv_coord=(0.24, 0.24))

# Secondary L-aperture folded forward in the cradle
leaf_tab = [
    (-0.00036, 0.05682),
    (0.00036, 0.05682),
    (0.00040, 0.05702),
    (-0.00040, 0.05702),
]
extrude_profile_y("RearFoldedLeaf", leaf_tab, Y_REAR - 0.00068, Y_REAR - 0.00010, bevel_y=0.00004, uv_coord=(0.22, 0.22))

# 1b. Forged A2 protective ears (smoothly curved outer contour & rounded crest, open top)
for side in (-1.0, 1.0):
    ear_profile = [
        (side * 0.00086, 0.05690),
        (side * 0.00138, 0.05690),
        (side * 0.00143, 0.05730),
        (side * 0.00144, 0.05772),
        (side * 0.00140, 0.05814),
        (side * 0.00134, 0.05850),
        (side * 0.00126, 0.05878),
        (side * 0.00118, 0.05896),
        (side * 0.00110, 0.05906),
        (side * 0.00102, 0.05904),
        (side * 0.00095, 0.05895),
        (side * 0.00088, 0.05878),
        (side * 0.00088, 0.05785),
    ]
    if side < 0:
        ear_profile.reverse()
    extrude_profile_y(f"RearEar_{'R' if side < 0 else 'L'}", ear_profile, Y_REAR - 0.00080, Y_REAR + 0.00046, bevel_y=0.00008, uv_coord=(0.30, 0.30))

# Compact cradle housing sitting directly on the Picatinny rail clamp
cradle_profile = [
    (-0.00138, 0.05695),
    (-0.00086, 0.05695),
    (-0.00066, 0.05684),
    (0.00066, 0.05684),
    (0.00086, 0.05695),
    (0.00138, 0.05695),
    (0.00134, 0.05610),
    (0.00116, 0.05555),
    (-0.00116, 0.05555),
    (-0.00134, 0.05610),
]
extrude_profile_y("RearCradleHousing", cradle_profile, Y_REAR - 0.00088, Y_REAR + 0.00050, bevel_y=0.00008, uv_coord=(0.28, 0.28))

# Low-profile Picatinny rail clamp base
clamp_profile = [
    (-0.00162, 0.05445),
    (-0.00134, 0.05445),
    (-0.00118, 0.05495),
    (0.00118, 0.05495),
    (0.00134, 0.05445),
    (0.00162, 0.05445),
    (0.00170, 0.05520),
    (0.00134, 0.05562),
    (-0.00134, 0.05562),
    (-0.00170, 0.05520),
]
extrude_profile_y("RearPicatinnyClamp", clamp_profile, Y_REAR - 0.00160, Y_REAR + 0.00085, bevel_y=0.00008, uv_coord=(0.25, 0.25))


def add_knurled_cylinder(name, x0, x1, y_c, z_c, radius, ridges=22, uv_coord=(0.34, 0.34)):
    verts = []
    faces = []
    n = ridges * 2
    for x_val in [x0, x1]:
        for i in range(n):
            a = 2.0 * math.pi * i / n
            r = radius * (1.025 if i % 2 == 0 else 0.945)
            verts.append((x_val, y_c + r * math.cos(a), z_c + r * math.sin(a)))
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(n + i for i in range(n)))
    return add_mesh_from_pydata(name, verts, faces, uv_coord=uv_coord, smooth=False)


# Windage knob on right ear (-X in Blender = right on screen)
add_knurled_cylinder("WindageDrumRight", -0.00182, -0.00138, Y_REAR - 0.00012, 0.05735, 0.00038, ridges=22, uv_coord=(0.35, 0.35))
# Windage screw retention cap on left ear (+X in Blender = left on screen)
add_knurled_cylinder("WindageCapLeft", 0.00138, 0.00158, Y_REAR - 0.00012, 0.05735, 0.00025, ridges=14, uv_coord=(0.32, 0.32))
# Tactical rail clamp thumbscrew on the left side of the Picatinny base
add_knurled_cylinder("RailClampNut", 0.00162, 0.00215, Y_REAR - 0.00030, 0.05505, 0.00042, ridges=22, uv_coord=(0.34, 0.34))


# =========================================================================
# 2. FRONT SIGHT ASSEMBLY (A2 front post + stepped base + protective wings)
# =========================================================================

# 2a. Central square A2 front sight post — slender, crisp tip at exact SIGHT_LINE
post_profile = [
    (-0.00011, 0.05675),
    (0.00011, 0.05675),
    (0.00008, SIGHT_LINE),
    (-0.00008, SIGHT_LINE),
]
extrude_profile_y("FrontSightPost", post_profile, Y_FRONT - 0.00018, Y_FRONT + 0.00018, bevel_y=0.00003, uv_coord=(0.20, 0.20))

# Stepped elevation detent flange at the base of the front post
flange1_profile = [
    (-0.00024, 0.05642),
    (0.00024, 0.05642),
    (0.00020, 0.05680),
    (-0.00020, 0.05680),
]
extrude_profile_y("FrontPostFlangeUpper", flange1_profile, Y_FRONT - 0.00026, Y_FRONT + 0.00026, bevel_y=0.00003, uv_coord=(0.24, 0.24))

flange2_profile = [
    (-0.00036, 0.05608),
    (0.00036, 0.05608),
    (0.00030, 0.05646),
    (-0.00030, 0.05646),
]
extrude_profile_y("FrontPostFlangeLower", flange2_profile, Y_FRONT - 0.00036, Y_FRONT + 0.00036, bevel_y=0.00004, uv_coord=(0.25, 0.25))

# 2b. Front sight A2 protective wings flanking the post with open air gap
for side in (-1.0, 1.0):
    fwing_profile = [
        (side * 0.00052, 0.05605),
        (side * 0.00096, 0.05605),
        (side * 0.00108, 0.05668),
        (side * 0.00112, 0.05728),
        (side * 0.00106, 0.05785),
        (side * 0.00095, 0.05828),
        (side * 0.00084, 0.05848),
        (side * 0.00070, 0.05848),
        (side * 0.00077, 0.05805),
        (side * 0.00079, 0.05742),
        (side * 0.00074, 0.05670),
    ]
    if side < 0:
        fwing_profile.reverse()
    extrude_profile_y(f"FrontWing_{'R' if side < 0 else 'L'}", fwing_profile, Y_FRONT - 0.00090, Y_FRONT + 0.00075, bevel_y=0.00006, uv_coord=(0.28, 0.28))

# Front sight A-frame bridge + barrel collar
fbase_profile = [
    (-0.00096, 0.05612),
    (0.00096, 0.05612),
    (0.00112, 0.05320),
    (0.00092, 0.04940),
    (-0.00092, 0.04940),
    (-0.00112, 0.05320),
]
extrude_profile_y("FrontSightAFrame", fbase_profile, Y_FRONT - 0.00140, Y_FRONT + 0.00115, bevel_y=0.00008, uv_coord=(0.27, 0.27))

# Join all parts into RearSightBody so the GLB has a single clean mesh
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
parts[0].name = "RearSightBody"

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print("Exported realistic M4 A2 sights:", OUT_GLB)
