import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, noise

random.seed(20261022)

REPO = "/Volumes/copia/lastday2"
PROPS_DIR = os.path.join(REPO, "assets/models/props")
OUT_SHELTER_GLB = os.path.join(PROPS_DIR, "shelter_camo_net.glb")
OUT_PICKUP_GLB = os.path.join(PROPS_DIR, "camo_net_pickup.glb")
OUT_TOWER_NET_GLB = os.path.join(PROPS_DIR, "watchtower_camo_net.glb")
SRC_TOWER_GLB = os.path.join(REPO, "watch_tower_made_of_wood_low-poly.glb")
OUT_TOWER_GLB = os.path.join(PROPS_DIR, "military_watch_tower.glb")
WOODLAND_PNG = os.path.join(REPO, "assets/textures/clothing/camouflage_woodland.png")


def make_camo_material(opaque=False):
    mat = bpy.data.materials.new("MAT_CamoNet_Woodland")
    mat.use_nodes = True
    mat.blend_method = 'OPAQUE' if opaque else 'CLIP'
    if not opaque:
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

    base_path = WOODLAND_PNG if opaque else os.path.join(PROPS_DIR, "camo_net_camo_net_basecolor.png")
    img_base = bpy.data.images.load(base_path)
    img_rough = bpy.data.images.load(os.path.join(PROPS_DIR, "camo_net_camo_net_roughness.png"))
    img_norm = bpy.data.images.load(os.path.join(PROPS_DIR, "camo_net_camo_net_normal.png"))
    img_rough.colorspace_settings.name = 'Non-Color'
    img_norm.colorspace_settings.name = 'Non-Color'

    t_base = nt.nodes.new("ShaderNodeTexImage")
    t_base.image = img_base
    nt.links.new(t_base.outputs["Color"], bsdf.inputs["Base Color"])
    if not opaque:
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
    return mat


def game_to_blender(p):
    # Game coords: X right, Y up, Z forward(+)/back(-) -> Blender: (X, -Z, Y)
    return Vector((p[0], -p[2], p[1]))


def roof_height(z_game):
    # Matches create_branch_shelter.py height(z) + foliage clearance so the net
    # drapes cleanly over the entire leaf roof without any branches poking out.
    t = max(0.0, min(1.0, (z_game + 1.95) / 3.45))
    return 0.16 + t * 2.30


def build_shelter_drape():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = make_camo_material()
    bm = bmesh.new()

    # Parameterized continuous tent-drape grid:
    # u in [-1, 1] spans left skirt -> roof width -> right skirt
    # v in [0, 1] spans back ground skirt -> inclined roof -> front entrance curtain to ground
    NU = 88
    NV = 92
    grid = {}

    for j in range(NV + 1):
        v = j / NV
        # Along v:
        # 0.00 .. 0.72: from back ground (z=-2.10) up the roof to front ridge (z=+1.56, y=2.32)
        # 0.72 .. 1.00: front curtain dropping down over the entrance (z=+1.56..+1.70, y=2.32 -> 0.02)
        if v <= 0.72:
            tv = v / 0.72
            z_base = -2.10 + tv * (1.56 - (-2.10))
            y_roof = roof_height(z_base)
            # Soft sag between rafters
        else:
            tv = (v - 0.72) / 0.28
            # Entrance curtain hangs from ridge (y=2.46) down to ground (y=0.02)
            # flaring slightly outward at the bottom (+Z)
            z_base = 1.56 + tv * 0.16 + 0.05 * math.sin(tv * math.pi)
            y_roof = 2.46 * (1.0 - tv) + 0.02 * tv

        for i in range(NU + 1):
            u = (i / NU) * 2.0 - 1.0  # -1 .. +1
            abs_u = abs(u)
            sign_u = 1.0 if u >= 0.0 else -1.0

            # Inner 62% of u is the roof/curtain width (-1.62 .. +1.62 m);
            # outer 38% drapes down the left/right sides to the ground.
            if abs_u <= 0.62:
                tu = u / 0.62
                x = tu * 1.72
                y = y_roof
                z = z_base
                if v > 0.72:
                    # Vertical curtain pleats across the entrance
                    tv = (v - 0.72) / 0.28
                    pleat = 0.055 * math.sin(tu * math.pi * 6.0) * math.sin(tv * math.pi * 0.9)
                    z += pleat
                    # Slight center slit ripple so it looks like a parting curtain
                    y += 0.02 * math.cos(tu * math.pi * 4.0) * (1.0 - tv)
                else:
                    # Slight rafter wave on roof
                    y += 0.028 * math.cos(tu * math.pi * 7.0)
            else:
                # Side wall drape from roof edge (x=±1.72, y=y_roof) down to ground (x=±1.98, y=0.02)
                ts = (abs_u - 0.62) / 0.38
                x = sign_u * (1.72 + ts * 0.28 + 0.04 * math.sin(ts * math.pi))
                y = y_roof * (1.0 - ts) + 0.02 * ts
                z = z_base + 0.04 * math.sin(v * math.pi * 5.0) * ts

            # Organic cloth noise
            nval = noise.noise(Vector((x * 1.3, z * 1.3, y * 1.3 + 0.7)))
            x += 0.025 * nval
            z += 0.025 * noise.noise(Vector((x * 1.1 + 3.1, z * 1.1, y * 1.1)))
            y = max(0.015, y + 0.02 * nval)

            grid[(i, j)] = bm.verts.new(game_to_blender((x, y, z)))

    bm.verts.ensure_lookup_table()
    for j in range(NV):
        for i in range(NU):
            bm.faces.new([
                grid[(i, j)],
                grid[(i + 1, j)],
                grid[(i + 1, j + 1)],
                grid[(i, j + 1)],
            ])
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("ShelterCamoNet")
    bm.to_mesh(mesh)
    bm.free()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        vi = loop.vertex_index
        # Recover grid (i, j) from vertex index
        i = vi % (NU + 1)
        j = vi // (NU + 1)
        uv_layer.data[loop.index].uv = ((i / NU) * 2.6, (j / NV) * 2.4)

    for poly in mesh.polygons:
        poly.use_smooth = True

    obj = bpy.data.objects.new("ShelterCamoNet", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=OUT_SHELTER_GLB,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )
    print("Exported shelter camo net:", OUT_SHELTER_GLB)


def build_folded_pickup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = make_camo_material(opaque=True)
    # Folded/rolled military camouflage net bundle (~0.80 x 0.26 x 0.46 m)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.13))
    obj = bpy.context.active_object
    obj.name = "CamoNetPickup"
    obj.scale = (0.78, 0.46, 0.26)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    sub = obj.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 3
    sub.render_levels = 3
    bpy.ops.object.modifier_apply(modifier=sub.name)

    for v in obj.data.vertices:
        p = v.co
        fold = 0.018 * math.sin(p.x * 18.0) + 0.012 * math.cos(p.y * 14.0)
        nval = 0.022 * noise.noise(Vector((p.x * 4.0, p.y * 4.0, p.z * 4.0 + 1.5)))
        p.z = max(0.005, p.z + fold + nval)
        p.x += 0.015 * nval
        p.y += 0.015 * fold

    uv_layer = obj.data.uv_layers.get("UVMap") or obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.loops:
        co = obj.data.vertices[loop.vertex_index].co
        uv_layer.data[loop.index].uv = (co.x * 1.4 + 0.5, co.y * 1.4 + 0.5)

    for poly in obj.data.polygons:
        poly.use_smooth = True

    obj.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=OUT_PICKUP_GLB,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )
    print("Exported folded camo net pickup:", OUT_PICKUP_GLB)


def build_taller_watchtower():
    if not os.path.exists(SRC_TOWER_GLB):
        print("Source tower not found, skipping:", SRC_TOWER_GLB)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC_TOWER_GLB)
    # Raise the watchtower cabin lintel/ceiling/roof by +1.10 local units
    # (+0.935 m at 0.85 scale) so the player never clips the doorway or roof
    # with their head, and raise the window sill slightly (+0.18).
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mw = obj.matrix_world
        mw_inv = mw.inverted()
        for v in obj.data.vertices:
            w = mw @ v.co
            if w.z > 12.50:
                w.z += 1.10
                v.co = mw_inv @ w
            elif 12.15 <= w.z <= 12.25:
                w.z += 0.18
                v.co = mw_inv @ w
        obj.data.update()
    bpy.ops.export_scene.gltf(
        filepath=OUT_TOWER_GLB,
        export_format='GLB',
        export_apply=True,
    )
    print("Exported taller military watchtower:", OUT_TOWER_GLB)


def build_watchtower_camo_net():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = make_camo_material(opaque=False)
    bm = bmesh.new()

    # Continuous canopy over the watchtower roof (y_game = 15.33, x/z in [-3.62, +3.62])
    # that drapes down around all 4 outer sides from the roof edge (y=15.30)
    # down to the balcony railings (y=11.88, x/z around +-3.22).
    # Parameterized as:
    # - Top roof sheet (NR x NR) covering [-3.62, +3.62]^2 at y=15.33
    # - Connected 4-side outer curtain ring (NU_S x NV_S) hanging from the roof
    #   perimeter (x/z = +-3.62, y=15.30) down to the top of the balcony
    #   railings (x/z = +-3.25, y=11.88).
    NR = 48
    roof_grid = {}
    roof_hw = 3.68
    for j in range(NR + 1):
        vz = (j / NR) * 2.0 - 1.0
        for i in range(NR + 1):
            vx = (i / NR) * 2.0 - 1.0
            x = vx * roof_hw
            z = vz * roof_hw
            # Subtle sag between roof rafters + slight dome over center
            edge = max(abs(vx), abs(vz))
            y = 15.37 - 0.04 * (edge * edge) + 0.025 * math.cos(vx * math.pi * 3.0) * math.cos(vz * math.pi * 3.0)
            nval = noise.noise(Vector((x * 0.8, z * 0.8, y * 0.8 + 1.3)))
            x += 0.02 * nval
            z += 0.02 * noise.noise(Vector((x * 0.8 + 4.1, z * 0.8, y * 0.8)))
            y += 0.015 * nval
            roof_grid[(i, j)] = bm.verts.new(game_to_blender((x, y, z)))

    # Outer lateral drape from roof edge (y=15.34, hw=3.68) down to the balcony
    # railings (y=11.85, hw=3.26 so it rests just outside the +-3.16 railing/posts),
    # with observation window openings aligned with the cabin windows (y=12.40..14.15).
    NU_S = 160
    NV_S = 44
    side_grid = {}
    y_top = 15.34
    y_bot = 11.85
    # Window opening in normalized side coords: f in [0.32, 0.68], tv in [0.34, 0.84]
    f_win_min, f_win_max = 0.32, 0.68
    tv_win_min, tv_win_max = 0.34, 0.84
    for j in range(NV_S + 1):
        tv = j / NV_S  # 0 = roof edge (15.34), 1 = railing top (11.85)
        hw = 3.68 * (1.0 - tv) + 3.26 * tv - 0.07 * math.sin(tv * math.pi)
        for i in range(NU_S + 1):
            u = (i / NU_S) * 4.0
            side = min(3, int(u))
            f = u - side  # 0..1 along each side
            s_coord = (f * 2.0 - 1.0) * hw
            # Gently gather cloth folds around the window opening border
            in_tv_band = (tv_win_min - 0.06) <= tv <= (tv_win_max + 0.06)
            gather = 0.0
            if in_tv_band:
                dist_f = min(abs(f - f_win_min), abs(f - f_win_max))
                if dist_f < 0.08:
                    gather = 0.055 * (1.0 - dist_f / 0.08)
            if side == 0:    # West (-X)
                x, z = -(hw + gather), s_coord
                nx, nz = -1.0, 0.0
            elif side == 1:  # South (+Z)
                x, z = s_coord, hw + gather
                nx, nz = 0.0, 1.0
            elif side == 2:  # East (+X)
                x, z = hw + gather, -s_coord
                nx, nz = 1.0, 0.0
            else:            # North (-Z)
                x, z = -s_coord, -(hw + gather)
                nx, nz = 0.0, -1.0
            # Soft rounded corners
            corner_d = abs(f * 2.0 - 1.0)
            if corner_d > 0.88:
                tc = (corner_d - 0.88) / 0.12
                inset = 0.07 * tc * tc
                x -= (1.0 if x > 0 else -1.0) * inset
                z -= (1.0 if z > 0 else -1.0) * inset
            pleat = 0.05 * math.sin(f * math.pi * 10.0) * math.sin(tv * math.pi * 0.95)
            hem_wave = 0.07 * math.sin(f * math.pi * 6.0) * (tv * tv)
            y = y_top * (1.0 - tv) + (y_bot + hem_wave) * tv
            nval = 0.028 * noise.noise(Vector((x * 0.9, z * 0.9, y * 0.9 + 2.7)))
            x += nx * (pleat + nval)
            z += nz * (pleat + nval)
            side_grid[(i, j)] = bm.verts.new(game_to_blender((x, y, z)))

    bm.verts.ensure_lookup_table()
    roof_vert_count = (NR + 1) * (NR + 1)
    for j in range(NR):
        for i in range(NR):
            bm.faces.new([
                roof_grid[(i, j)],
                roof_grid[(i + 1, j)],
                roof_grid[(i + 1, j + 1)],
                roof_grid[(i, j + 1)],
            ])

    for j in range(NV_S):
        tv_mid = (j + 0.5) / NV_S
        for i in range(NU_S):
            u_mid = ((i + 0.5) / NU_S) * 4.0
            f_mid = u_mid - min(3, int(u_mid))
            # Leave window opening on all 4 sides aligned with the cabin windows
            if f_win_min <= f_mid <= f_win_max and tv_win_min <= tv_mid <= tv_win_max:
                continue
            bm.faces.new([
                side_grid[(i, j)],
                side_grid[(i + 1, j)],
                side_grid[(i + 1, j + 1)],
                side_grid[(i, j + 1)],
            ])

    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("WatchtowerCamoNet")
    bm.to_mesh(mesh)
    bm.free()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        vi = loop.vertex_index
        if vi < roof_vert_count:
            i = vi % (NR + 1)
            j = vi // (NR + 1)
            uv_layer.data[loop.index].uv = ((i / NR) * 2.8, (j / NR) * 2.8)
        else:
            wvi = vi - roof_vert_count
            i = wvi % (NU_S + 1)
            j = wvi // (NU_S + 1)
            uv_layer.data[loop.index].uv = ((i / NU_S) * 8.0, (j / NV_S) * 1.4)

    for poly in mesh.polygons:
        poly.use_smooth = True

    obj = bpy.data.objects.new("WatchtowerCamoNet", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=OUT_TOWER_NET_GLB,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )
    print("Exported watchtower camo net:", OUT_TOWER_NET_GLB)


build_shelter_drape()
build_folded_pickup()
build_taller_watchtower()
build_watchtower_camo_net()
