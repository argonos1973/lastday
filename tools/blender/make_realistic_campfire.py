import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Euler, noise

random.seed(20261023)

REPO = "/Volumes/copia/lastday2"
OUT_GLB = os.path.join(REPO, "assets/models/props/realistic_campfire.glb")
BARK_ALBEDO = os.path.join(REPO, "assets/models/props/wood_stick_01_0.jpg")
BARK_ROUGH = os.path.join(REPO, "assets/models/props/wood_stick_01_1.png")
BARK_NORMAL = os.path.join(REPO, "assets/models/props/wood_stick_01_2.jpg")
GRANITE_JPG = os.path.join(REPO, "assets/models/props/lake/lake_boulder_0_lake_granite.jpg")

bpy.ops.wm.read_factory_settings(use_empty=True)


def make_bark_material():
    mat = bpy.data.materials.new("MAT_CampfireLogs")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.88
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    ib = bpy.data.images.load(BARK_ALBEDO)
    tb = nt.nodes.new("ShaderNodeTexImage")
    tb.image = ib
    nt.links.new(tb.outputs["Color"], bsdf.inputs["Base Color"])

    if os.path.exists(BARK_ROUGH):
        ir = bpy.data.images.load(BARK_ROUGH)
        ir.colorspace_settings.name = 'Non-Color'
        tr = nt.nodes.new("ShaderNodeTexImage")
        tr.image = ir
        nt.links.new(tr.outputs["Color"], bsdf.inputs["Roughness"])

    if os.path.exists(BARK_NORMAL):
        inm = bpy.data.images.load(BARK_NORMAL)
        inm.colorspace_settings.name = 'Non-Color'
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = inm
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = 1.2
        nt.links.new(tn.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def make_stone_material():
    mat = bpy.data.materials.new("MAT_CampfireStones")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.90
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if os.path.exists(GRANITE_JPG):
        ig = bpy.data.images.load(GRANITE_JPG)
        tg = nt.nodes.new("ShaderNodeTexImage")
        tg.image = ig
        nt.links.new(tg.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_ash_material():
    mat = bpy.data.materials.new("MAT_CampfireAsh")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.045, 0.040, 0.036, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.98
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


bark_mat = make_bark_material()
stone_mat = make_stone_material()
ash_mat = make_ash_material()
all_objs = []


def add_ash_mound():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=20, y_segments=20, size=0.44)
    for v in bm.verts:
        r = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
        if r > 0.44:
            v.co.x *= 0.44 / r
            v.co.y *= 0.44 / r
            r = 0.44
        t = max(0.0, 1.0 - (r / 0.44) ** 2)
        nval = noise.noise(Vector((v.co.x * 9.0, v.co.y * 9.0, 1.2)))
        v.co.z = 0.004 + 0.045 * t + 0.010 * nval * t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("AshMound")
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("AshMound", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(ash_mat)
    all_objs.append(obj)


def add_ring_stones():
    num_stones = 11
    for i in range(num_stones):
        ang = (i / num_stones) * 2.0 * math.pi + random.uniform(-0.07, 0.07)
        rad = random.uniform(0.41, 0.45)
        cx = math.cos(ang) * rad
        cy = math.sin(ang) * rad
        rx = random.uniform(0.105, 0.140)
        ry = random.uniform(0.085, 0.120)
        rz = random.uniform(0.065, 0.092)

        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, 0, 0))
        st = bpy.context.active_object
        st.name = f"CampfireStone_{i}"
        seed_v = Vector((i * 3.7, i * 1.9, 0.5))
        for v in st.data.vertices:
            p = v.co.copy()
            n1 = noise.noise(p * 1.8 + seed_v)
            n2 = noise.noise(p * 3.6 - seed_v) * 0.35
            disp = 1.0 + 0.24 * n1 + 0.12 * n2
            p.x *= rx * disp
            p.y *= ry * disp
            p.z *= rz * disp
            if p.z < -rz * 0.35:
                p.z = -rz * 0.35 + (p.z + rz * 0.35) * 0.2
            v.co = p
        st.rotation_euler = Euler((random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), ang + math.pi * 0.5), 'XYZ')
        st.location = (cx, cy, rz * 0.34)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

        uv = st.data.uv_layers.get("UVMap") or st.data.uv_layers.new(name="UVMap")
        for loop in st.data.loops:
            co = st.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = (co.x * 1.6 + 0.5, co.y * 1.6 + 0.5)
        for p in st.data.polygons:
            p.use_smooth = True
        st.data.materials.append(stone_mat)
        all_objs.append(st)


def build_realistic_log(name, p_start, p_end, r_outer, r_inner, bow=0.015, has_knot=True, seed_idx=0):
    bm = bmesh.new()
    N_SEG = 26
    N_RING = 22
    direction = p_end - p_start
    tangent = direction.normalized()
    up_ref = Vector((0, 0, 1)) if abs(tangent.z) < 0.95 else Vector((1, 0, 0))
    side = tangent.cross(up_ref).normalized()
    binorm = side.cross(tangent).normalized()

    rings = []
    uv_map = {}

    knot_t = random.uniform(0.28, 0.55)
    knot_angle = random.uniform(0.0, 2.0 * math.pi)
    u_off = (seed_idx * 0.13) % 0.25

    for j in range(N_RING + 1):
        t = j / N_RING
        center = p_start.lerp(p_end, t)
        center += binorm * (bow * math.sin(t * math.pi)) + side * (bow * 0.5 * math.sin(t * math.pi * 2.0))
        rad_base = r_outer * (1.0 - t) + r_inner * t
        ring_verts = []
        for i in range(N_SEG + 1):
            theta = (i / N_SEG) * 2.0 * math.pi
            bark_disp = 0.0038 * math.sin(theta * 9.0 + t * 5.0 + seed_idx) + 0.0022 * math.cos(theta * 17.0 - t * 8.0)
            knot_bump = 0.0
            if has_knot:
                da = math.atan2(math.sin(theta - knot_angle), math.cos(theta - knot_angle))
                dt = (t - knot_t) / 0.11
                d2 = (da / 0.38) ** 2 + dt ** 2
                if d2 < 1.0:
                    knot_bump = 0.013 * (1.0 - d2) ** 2
            r = rad_base + bark_disp + knot_bump
            normal_dir = math.cos(theta) * side + math.sin(theta) * binorm
            pos = center + normal_dir * r
            v = bm.verts.new(pos)
            ring_verts.append(v)
            # Map onto the scanned bark texture region of wood_stick_01_0.jpg
            uv_map[v] = (0.15 + t * 0.55, 0.15 + u_off + (i / N_SEG) * 0.55)
        rings.append((center, ring_verts))

    for j in range(N_RING):
        r0 = rings[j][1]
        r1 = rings[j + 1][1]
        for i in range(N_SEG):
            bm.faces.new([r0[i], r0[i + 1], r1[i + 1], r1[i]])

    for end_j, flip in ((0, True), (N_RING, False)):
        c_pos, r_verts = rings[end_j]
        c_vert = bm.verts.new(c_pos)
        uv_map[c_vert] = (0.5, 0.5)
        cap_ring = []
        for i in range(N_SEG):
            rv = bm.verts.new(r_verts[i].co)
            ang = (i / N_SEG) * 2.0 * math.pi
            uv_map[rv] = (0.5 + 0.08 * math.cos(ang), 0.5 + 0.08 * math.sin(ang))
            cap_ring.append(rv)
        for i in range(N_SEG):
            ni = (i + 1) % N_SEG
            if flip:
                bm.faces.new([c_vert, cap_ring[ni], cap_ring[i]])
            else:
                bm.faces.new([c_vert, cap_ring[i], cap_ring[ni]])

    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    vert_uvs = [uv_map[v] for v in bm.verts]
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        uv_layer.data[loop.index].uv = vert_uvs[loop.vertex_index]
    for p in mesh.polygons:
        p.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(bark_mat)
    all_objs.append(obj)


add_ash_mound()
add_ring_stones()

# 2 lower cross-bed logs resting inside the stone ring
build_realistic_log("BaseLog_0", Vector((-0.34, -0.14, 0.055)), Vector((0.28, 0.12, 0.065)), 0.052, 0.046, bow=0.010, has_knot=True, seed_idx=1)
build_realistic_log("BaseLog_1", Vector((0.32, -0.18, 0.055)), Vector((-0.26, 0.16, 0.075)), 0.048, 0.044, bow=-0.010, has_knot=True, seed_idx=2)

# 6 main split/round logs arranged in a classic campfire teepee/cone
teepee_angles = [0.0, 1.05, 2.10, 3.15, 4.20, 5.25]
for idx, ang in enumerate(teepee_angles):
    r_out = random.uniform(0.36, 0.40)
    r_in = random.uniform(0.045, 0.075)
    z_out = random.uniform(0.055, 0.075)
    z_in = random.uniform(0.28, 0.34)
    twist = 0.30
    p0 = Vector((math.cos(ang) * r_out, math.sin(ang) * r_out, z_out))
    p1 = Vector((math.cos(ang + twist) * r_in, math.sin(ang + twist) * r_in, z_in))
    build_realistic_log(
        f"TeepeeLog_{idx}",
        p0,
        p1,
        random.uniform(0.046, 0.055),
        random.uniform(0.036, 0.043),
        bow=random.uniform(-0.012, 0.014),
        has_knot=(idx % 2 == 0),
        seed_idx=10 + idx,
    )

# 6 smaller kindling sticks / twigs tucked between the logs
for k in range(6):
    ang = k * (2.0 * math.pi / 6.0) + 0.55
    p0 = Vector((math.cos(ang) * 0.29, math.sin(ang) * 0.29, 0.04))
    p1 = Vector((math.cos(ang + 0.45) * 0.06, math.sin(ang + 0.45) * 0.06, 0.21))
    build_realistic_log(f"Kindling_{k}", p0, p1, 0.018, 0.013, bow=0.008, has_knot=False, seed_idx=30 + k)

bpy.ops.object.select_all(action='DESELECT')
for o in all_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objs[0]
bpy.ops.object.join()
campfire = bpy.context.active_object
campfire.name = "RealisticCampfire"

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print("Exported realistic campfire:", OUT_GLB)
