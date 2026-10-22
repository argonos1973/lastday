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


def make_camo_material():
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
    mat = make_camo_material()
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
        uv_layer.data[loop.index].uv = (co.x * 1.8 + 0.5, co.y * 1.8 + 0.5)

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


build_shelter_drape()
build_folded_pickup()
