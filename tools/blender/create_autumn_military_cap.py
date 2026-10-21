"""Replace the autumn cap with a fitted woodland military patrol cap.

The cap is authored against the adapted player's rest-pose hair bounds and
skinned rigidly to the Mixamo Head bone. It overwrites the autumn_hat wearable
and its pickup copy, preserving the game's existing equipment/save plumbing.

Run with Blender 4.x:
  blender --background --factory-startup --python tools/blender/create_autumn_military_cap.py
"""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
CHARACTER = ROOT / "assets/characters/adapted/player_with_clothes.glb"
CAMO = ROOT / "assets/textures/clothing/camouflage_woodland.png"
OUT = ROOT / "assets/characters/adapted/civil"
WEARABLE = OUT / "autumn_hat.glb"
PICKUP = OUT / "pickup_autumn_hat.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(CHARACTER))
armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
armature.data.pose_position = "REST"
hair = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name == "Hair")
head_bone = next((bone for bone in armature.data.bones if bone.name.split(":")[-1] == "Head"), None)
if head_bone is None:
    raise RuntimeError("Mixamo Head bone not found")

hair_points = [hair.matrix_world @ vertex.co for vertex in hair.data.vertices]
hair_min = Vector([min(point[i] for point in hair_points) for i in range(3)])
hair_max = Vector([max(point[i] for point in hair_points) for i in range(3)])
center_x = (hair_min.x + hair_max.x) * 0.5
center_y = (hair_min.y + hair_max.y) * 0.5 - 0.045
hair_height = hair_max.z - hair_min.z
radius_x = (hair_max.x - hair_min.x) * 0.44
radius_y = (hair_max.y - hair_min.y) * 0.45
# Sit the lower band at the hairline and keep the crown shallow, like a patrol
# cap. The previous taller crown read as a bucket/helmet in the game preview.
base_z = hair_max.z - hair_height * 0.43
top_z = hair_max.z - hair_height * 0.10


def material(name, color, texture=None, roughness=0.9):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = 0.0
    if "Sheen Weight" in shader.inputs:
        shader.inputs["Sheen Weight"].default_value = 0.14
    mat.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    if texture is not None:
        image = bpy.data.images.load(str(texture), check_existing=True)
        image.pack()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.label = "Woodland field fabric"
        uv = nodes.new("ShaderNodeTexCoord")
        mat.node_tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    else:
        shader.inputs["Base Color"].default_value = (*color, 1.0)
    return mat


camo = material("Gorra militar · camuflaje woodland", (0.16, 0.20, 0.11), CAMO)
olive = material("Gorra militar · cinta y visera", (0.075, 0.105, 0.055))
patch_mat = material("Gorra militar · parche de velcro", (0.29, 0.34, 0.18))
seam_mat = material("Gorra militar · costuras", (0.24, 0.27, 0.16))

vertices = []
faces = []
face_materials = []
face_uvs = []
segments = 64
# A low, structured patrol-cap crown: rounded rectangular profile, gently
# tapered at the crown and sized to sit over the player's scalp.
profiles = [
    (base_z, 1.00, 1.00),
    (base_z + (top_z - base_z) * 0.12, 0.99, 0.975),
    (base_z + (top_z - base_z) * 0.52, 0.97, 0.95),
    (top_z - (top_z - base_z) * 0.09, 0.90, 0.88),
    (top_z, 0.86, 0.84),
]
uv_repeats = 2.4

for z, sx, sy in profiles:
    for index in range(segments):
        angle = math.tau * index / segments
        c, s = math.cos(angle), math.sin(angle)
        # A mild superellipse makes the crown read as tailored panels instead
        # of a smooth beanie, while retaining a comfortable head-shaped fit.
        x = math.copysign(abs(c) ** 0.82, c) * radius_x * sx
        y = math.copysign(abs(s) ** 0.82, s) * radius_y * sy
        vertices.append((center_x + x, center_y + y, z))

for ring in range(len(profiles) - 1):
    for index in range(segments):
        nxt = (index + 1) % segments
        a, b = ring * segments + index, ring * segments + nxt
        c, d = (ring + 1) * segments + nxt, (ring + 1) * segments + index
        faces.append((a, b, c, d))
        face_materials.append(1 if ring == 0 else 0)
        uv = []
        for vertex_index in (a, b, c, d):
            x, y, z = vertices[vertex_index]
            # Repeat the fabric around the circumference so the camouflage
            # keeps its natural, compact scale instead of forming broad bands.
            u = ((index + (1 if vertex_index in (b, c) else 0)) / segments) * uv_repeats
            v = (z - base_z) / max(0.001, top_z - base_z) * .35
            uv.append((u, v))
        face_uvs.append(uv)

# Slightly domed crown clears the scalp while keeping the sides low.
top_ring = (len(profiles) - 1) * segments
previous=top_ring
for radius in [.75,.5,.25,.04]:
    start=len(vertices)
    for i in range(segments):
        edge=Vector(vertices[top_ring+i])
        vertices.append((center_x+(edge.x-center_x)*radius,
                         center_y+(edge.y-center_y)*radius,
                         top_z+hair_height*.10*(1-radius*radius)))
    for i in range(segments):
        quad=(previous+i,previous+(i+1)%segments,start+(i+1)%segments,start+i)
        faces.append(quad);face_materials.append(0)
        face_uvs.append([((vertices[j][0]-center_x)/(radius_x*2)+.5,
                         (vertices[j][1]-center_y)/(radius_y*2)+.5) for j in quad])
    previous=start
faces.append(tuple(previous+i for i in range(segments)));face_materials.append(0)
face_uvs.append([((vertices[previous+i][0]-center_x)/(radius_x*2)+.5,
                 (vertices[previous+i][1]-center_y)/(radius_y*2)+.5) for i in range(segments)])

# Curved, layered visor. The upper surface uses the same woodland print; the
# lower surface is darker olive so its thickness reads clearly in the preview.
visor_segments = 24
inner = []
outer = []
lower_inner = []
lower_outer = []
for index in range(visor_segments + 1):
    x_norm = -0.88 + 1.76 * index / visor_segments
    x = center_x + radius_x * x_norm
    edge_y = center_y - radius_y * max(0.0, 1.0 - x_norm * x_norm) ** 0.5
    projection = max(0.0, 1.0 - (x_norm / 0.92) ** 2) ** 0.5
    inner.append((x, edge_y - 0.002, base_z + 0.008))
    outer.append((x, edge_y - 0.145 * projection, base_z - 0.025 * projection + .014*x_norm*x_norm))
    lower_inner.append((x, edge_y - 0.002, base_z + 0.001))
    lower_outer.append((x, edge_y - 0.145 * projection, base_z - 0.032 * projection + .014*x_norm*x_norm))
visor_start = len(vertices)
vertices.extend(inner + outer + lower_inner + lower_outer)
for index in range(visor_segments):
    a, b = visor_start + index, visor_start + index + 1
    c, d = visor_start + visor_segments + 1 + index + 1, visor_start + visor_segments + 1 + index
    lower_a = visor_start + (visor_segments + 1) * 2 + index
    lower_b = lower_a + 1
    lower_c = lower_b + visor_segments + 1
    lower_d = lower_a + visor_segments + 1
    faces.append((a, b, c, d)); face_materials.append(0)
    face_uvs.append([
        (index / visor_segments, 0.15), ((index + 1) / visor_segments, 0.15),
        ((index + 1) / visor_segments, 0.0), (index / visor_segments, 0.0),
    ])
    faces.append((lower_a, lower_d, lower_c, lower_b)); face_materials.append(1)
    face_uvs.append([
        (index / visor_segments, 0.15), ((index + 1) / visor_segments, 0.15),
        ((index + 1) / visor_segments, 0.0), (index / visor_segments, 0.0),
    ])
    faces.append((c, lower_c, lower_d, d)); face_materials.append(1)
    face_uvs.append([(0, 0), (0, 0.1), (1, 0.1), (1, 0)])

mesh = bpy.data.meshes.new("Structured_woodland_patrol_cap")
mesh.from_pydata(vertices, [], faces)
mesh.materials.append(camo)
mesh.materials.append(olive)
mesh.materials.append(patch_mat)
mesh.materials.append(seam_mat)
mesh.update()
cap = bpy.data.objects.new("autumn_hat", mesh)
bpy.context.collection.objects.link(cap)
uv_layer = mesh.uv_layers.new(name="UVMap")
for polygon, mat_index, coords in zip(mesh.polygons, face_materials, face_uvs):
    polygon.material_index = mat_index
    polygon.use_smooth = True
    for loop_index, uv in zip(polygon.loop_indices, coords):
        uv_layer.data[loop_index].uv = uv

# Front hook-and-loop panel, placed toward the face (-Y in this rig).
patch_width = radius_x * 0.40
patch_height = (top_z - base_z) * 0.25
patch_center = Vector((center_x, center_y, base_z + (top_z - base_z) * 0.57))
patch_vertices = []
patch_cols, patch_rows = 8, 4
for row in range(patch_rows + 1):
    z = patch_center.z - patch_height / 2 + patch_height * row / patch_rows
    profile_t = (z - base_z) / max(0.001, top_z - base_z)
    sy = 1.0 - 0.16 * profile_t
    for col in range(patch_cols + 1):
        x = patch_center.x - patch_width / 2 + patch_width * col / patch_cols
        normalized_x = (x - center_x) / max(0.001, radius_x * 0.97)
        surface_y = center_y - radius_y * sy * max(0.0, 1.0 - normalized_x * normalized_x) ** 0.5
        patch_vertices.append((x, surface_y - 0.009, z))
patch_faces = []
for row in range(patch_rows):
    for col in range(patch_cols):
        a = row * (patch_cols + 1) + col
        b, d = a + 1, a + patch_cols + 1
        c = d + 1
        patch_faces.append((a, b, c, d))
patch_mesh = bpy.data.meshes.new("Front_velcro_patch_mesh")
patch_mesh.from_pydata(patch_vertices, [], patch_faces)
patch_mesh.materials.append(patch_mat)
patch_mesh.update()
patch_uv = patch_mesh.uv_layers.new(name="UVMap")
for polygon in patch_mesh.polygons:
    for loop_index in polygon.loop_indices:
        co = patch_mesh.vertices[patch_mesh.loops[loop_index].vertex_index].co
        patch_uv.data[loop_index].uv = ((co.x - patch_center.x) / patch_width + 0.5, (co.z - patch_center.z) / patch_height + 0.5)
patch_obj = bpy.data.objects.new("Front_velcro_patch", patch_mesh)
bpy.context.collection.objects.link(patch_obj)

# Raised stitched seams and the rear adjustment tab, merged into the same
# rigidly skinned garment. Each line is a small closed tube, not a floating decal.
details = []
def stitch(name, points, radius=.0012, cyclic=False):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D'
    curve.bevel_depth=radius;curve.bevel_resolution=1;curve.resolution_u=1
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for point,co in zip(spline.points,points):point.co=(*co,1)
    spline.use_cyclic_u=cyclic
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(seam_mat)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH')
    details.append(bpy.context.object)

for ring in [1,3]:
    stitch('Double stitched crown seam',[(vertices[ring*segments+i][0],vertices[ring*segments+i][1],vertices[ring*segments+i][2]+.0015) for i in range(segments)],cyclic=True)
for fraction in [.72,.87]:
    stitch('Visor topstitch', [tuple(Vector(inner[i]).lerp(Vector(outer[i]),fraction)+Vector((0,0,.002))) for i in range(visor_segments+1)])
for index in [8,24,40,56]:
    stitch('Panel seam', [tuple(Vector(vertices[ring*segments+index])+Vector((0,0,.002))) for ring in range(1,len(profiles))])
# A small cloth closure across the rear band.
bpy.ops.mesh.primitive_cube_add(size=1,location=(center_x,center_y+radius_y*.99,base_z+(top_z-base_z)*.16))
strap=bpy.context.object;strap.name='Rear adjustment strap'
strap.dimensions=(radius_x*.74,.009,(top_z-base_z)*.15)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
strap.data.materials.append(olive)
bevel=strap.modifiers.new('Soft sewn edges','BEVEL');bevel.width=.003;bevel.segments=2
bpy.ops.object.modifier_apply(modifier=bevel.name);details.append(strap)

# Merge cap panels and patch into one skinned mesh, then weight every part to
# the Head bone. This follows head animation precisely and exports as one item.
bpy.ops.object.select_all(action="DESELECT")
cap.select_set(True); patch_obj.select_set(True)
for detail in details: detail.select_set(True)
bpy.context.view_layer.objects.active = cap
bpy.ops.object.join()
cap.name = "autumn_hat"
cap.data.name = "Military_patrol_cap_mesh"
group = cap.vertex_groups.new(name=head_bone.name)
group.add(list(range(len(cap.data.vertices))), 1.0, "REPLACE")
modifier = cap.modifiers.new("Character_skeleton", "ARMATURE")
modifier.object = armature
world = cap.matrix_world.copy()
cap.parent = armature
cap.matrix_world = world

# Recalculate normals on all fabric and visor surfaces.
bpy.context.view_layer.objects.active = cap
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
bm = bmesh.new()
bm.from_mesh(cap.data)
invalid_faces = bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(cap.data)
bm.free()
cap.data.validate(verbose=True, clean_customdata=False)
print("CAP_MESH", len(cap.data.vertices), len(cap.data.polygons), "materials", [m.name for m in cap.data.materials], flush=True)

def export_selected(path, objects, skins):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_animations=False, export_skins=skins,
        export_image_format="AUTO",
    )

export_selected(WEARABLE, [cap, armature], True)

pickup = cap.copy()
pickup.data = cap.data.copy()
bpy.context.collection.objects.link(pickup)
pickup.parent = None
pickup.matrix_world = cap.matrix_world.copy()
for item_modifier in list(pickup.modifiers):
    pickup.modifiers.remove(item_modifier)
bpy.context.view_layer.objects.active = pickup
bpy.ops.object.select_all(action="DESELECT")
pickup.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bounds = [Vector(corner) for corner in pickup.bound_box]
pickup_center = sum(bounds, Vector()) / len(bounds)
for vertex in pickup.data.vertices:
    vertex.co -= pickup_center
export_selected(PICKUP, [pickup], False)

print("MILITARY_CAP_EXPORTED", WEARABLE, len(cap.data.vertices), "Head bone:", head_bone.name, flush=True)
