"""Build fitted field jackets, transfer the character weights and export Godot assets."""
from pathlib import Path
import math
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/adapted/jackets'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/player_with_clothes.glb'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
source = bpy.data.objects['Tops']
parts = []

def fabric(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = 0.88
    for suffix, socket, normal in [('albedo', 'Base Color', False), ('normal', 'Normal', True)]:
        tex = tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT / ('assets/textures/clothing/cloth_denim_' + suffix + '.png')), check_existing=True)
        uv = tree.nodes.new('ShaderNodeTexCoord')
        mapping = tree.nodes.new('ShaderNodeVectorMath')
        mapping.operation = 'SCALE'
        mapping.inputs[3].default_value = 5.0
        tree.links.new(uv.outputs['UV'], mapping.inputs[0])
        tree.links.new(mapping.outputs[0], tex.inputs['Vector'])
        if normal:
            tex.image.colorspace_settings.name = 'Non-Color'
            node = tree.nodes.new('ShaderNodeNormalMap')
            node.inputs['Strength'].default_value = 0.22
            tree.links.new(tex.outputs['Color'], node.inputs['Color'])
            tree.links.new(node.outputs[0], bsdf.inputs[socket])
        else:
            # Bake the color multiplier below for the glTF material.
            bsdf.inputs[socket].default_value = (*color, 1)
    return mat

cloth = fabric('FieldJacket_Olive', (0.22, 0.28, 0.14))
trim = fabric('Reinforced_seams', (0.105, 0.13, 0.075))
metal = bpy.data.materials.new('Dark_zipper_and_buttons')
metal.diffuse_color = (0.08, 0.09, 0.07, 1)
metal.use_nodes = True
metal.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = metal.diffuse_color
metal.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value = 0.65
metal.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.45

jacket = source.copy()
jacket.data = source.data.copy()
bpy.context.collection.objects.link(jacket)
jacket.name = 'field_jacket'
jacket.data.materials.clear()
jacket.data.materials.append(cloth)
for v in jacket.data.vertices:
    v.co += v.normal * 1.0
    v.co.x *= 1.025
    v.co.z *= 1.035
parts.append(jacket)
bvh = BVHTree.FromPolygons([v.co for v in jacket.data.vertices], [p.vertices[:] for p in jacket.data.polygons])

def mesh_part(name, vertices, faces, material):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = source.matrix_world.copy()
    obj.data.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    parts.append(obj)
    return obj

def sleeve(side):
    vertices, faces = [], []
    rings = [(60, 14.5, 13.5), (73, 13.3, 12.8), (88, 12.2, 12), (97, 12.8, 12), (108, 11.5, 11), (127, 9.7, 9), (144, 8.5, 8.0)]
    steps = 24
    for ri, (x, ry, rz) in enumerate(rings):
        for i in range(steps):
            angle = math.tau * i / steps
            fold = 0.4 * math.sin(angle * 5 + ri * 1.7)
            vertices.append((side * x, 299.5 + (ry + fold) * math.cos(angle), -10 + (rz + fold) * math.sin(angle)))
    for ring in range(len(rings)-1):
        for i in range(steps):
            a, b = ring * steps+i, ring * steps+(i+1)%steps
            faces.append((a, b, b+steps, a+steps) if side > 0 else (a+steps, b+steps, b, a))
    return mesh_part('Long_sleeve', vertices, faces, cloth)

def front_depth(x, y):
    hit, _, _, _ = bvh.ray_cast(Vector((x, y, 100)), Vector((0, 0, -1)))
    return hit.z if hit else 23.0

def patch(name, cx, cy, width, height, material, depth=1.5):
    # Gridded panels conform to the actual shirt surface and deform with it.
    nx, ny = 6, 6
    vertices, faces = [], []
    for j in range(ny+1):
        y = cy + (j/ny-0.5) * height
        for i in range(nx+1):
            x = cx + (i/nx-0.5) * width
            bulge = math.sin(math.pi*i/nx)*math.sin(math.pi*j/ny)*depth
            vertices.append((x, y, front_depth(x, y) + 0.5 + bulge))
    for j in range(ny):
        for i in range(nx):
            a = j*(nx+1)+i
            faces.append((a, a+1, a+nx+2, a+nx+1))
    return mesh_part(name, vertices, faces, material)

for side in [-1, 1]:
    sleeve(side)
    for y, width, height in [(276, 19, 22), (218, 22, 22)]:
        patch('Cargo_pocket', side*21, y, width, height, cloth, 2.0)
        patch('Pocket_flap', side*21, y+height/2-1, width+1.0, 5.0, trim, 2.5)
        for edge in [-1,1]:
            patch('Pocket_stitch', side*21+edge*(width/2-1), y-0.5, 0.45, height-2, trim, 0.8)
    # Sleeve cuffs are separate reinforced bands.
    vertices, faces = [], []
    for x in [137.5, 143.5]:
        for i in range(24):
            a = math.tau*i/24
            vertices.append((side*x, 299.5+8.9*math.cos(a), -10+8.5*math.sin(a)))
    for i in range(24):
        faces.append((i, (i+1)%24, (i+1)%24+24, i+24))
    mesh_part('Adjustable_cuff', vertices, faces, trim)

patch('Storm_placket', 0, 252, 5.5, 109, trim, 0.6)
patch('Zipper', 0.8, 252, 0.8, 107, metal, 1.2)
for y in range(202, 304, 16):
    patch('Snap_button', -0.9, y, 1.4, 1.4, metal, 1.2)
# Stand collar around the open neckline. Leave a narrow opening at the front.
vertices, faces = [], []
for y in [309, 319]:
    for i in range(33):
        a = 0.18 + (math.tau-0.36)*i/32
        vertices.append((14*math.sin(a), y, -6+14*math.cos(a)))
for i in range(32):
    faces.append((i, i+1, i+34, i+33))
mesh_part('Stand_collar', vertices, faces, cloth)

# Join detail geometry to a single skinned mesh with separate material surfaces.
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = jacket
bpy.ops.object.join()
for modifier in list(jacket.modifiers):
    jacket.modifiers.remove(modifier)
# Sample fitted source clothing and bare arms in the same mesh coordinate frame.
points = []
for name in ['Tops', 'Body_arms', 'Desnudo_arms']:
    obj = bpy.data.objects.get(name)
    if obj is None:
        continue
    frame = source.matrix_world.inverted() @ obj.matrix_world
    for vertex in obj.data.vertices:
        groups = {obj.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight > 0.001}
        if groups:
            points.append((frame @ vertex.co, groups))
tree = KDTree(len(points))
for i,(position,_) in enumerate(points):
    tree.insert(position, i)
tree.balance()
jacket.vertex_groups.clear()
for bone in arm.data.bones:
    jacket.vertex_groups.new(name=bone.name)
for vertex in jacket.data.vertices:
    weights = {}
    for _, index, distance in tree.find_n(vertex.co, 4):
        influence = 1.0 / max(0.2, distance)**2
        for name, weight in points[index][1].items():
            if jacket.vertex_groups.get(name):
                weights[name] = weights.get(name, 0) + weight*influence
    strongest = sorted(weights.items(), key=lambda pair: pair[1], reverse=True)[:4]
    total = sum(w for _,w in strongest)
    if total <= 0:
        raise RuntimeError('Unweighted jacket vertex')
    for name, weight in strongest:
        jacket.vertex_groups[name].add([vertex.index], weight/total, 'REPLACE')
modifier = jacket.modifiers.new('Character_skeleton', 'ARMATURE')
modifier.object = arm
jacket.parent = arm
jacket.matrix_world = source.matrix_world.copy()
bpy.context.view_layer.objects.active = jacket
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.015)
bpy.ops.object.mode_set(mode='OBJECT')

VARIANTS = [('olive', (0.22,0.28,0.14)), ('navy', (0.07,0.12,0.19)), ('sand', (0.48,0.40,0.26))]
for name, color in VARIANTS:
    cloth.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*color,1)
    cloth.diffuse_color = (*color,1)
    trim.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*(c*0.65 for c in color),1)
    bpy.ops.object.select_all(action='DESELECT')
    jacket.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / ('military_jacket_' + name + '.glb')), export_format='GLB', use_selection=True, export_animations=False, export_skins=True)
    pickup = jacket.copy()
    pickup.data = jacket.data.copy()
    bpy.context.collection.objects.link(pickup)
    pickup.parent = None
    pickup.matrix_world = jacket.matrix_world.copy()
    for m in list(pickup.modifiers):
        pickup.modifiers.remove(m)
    # Bake only object transform; retain the same proportions as the worn mesh.
    bpy.ops.object.select_all(action='DESELECT')
    pickup.select_set(True)
    bpy.context.view_layer.objects.active = pickup
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    center = sum((Vector(v) for v in pickup.bound_box), Vector())/8
    for vertex in pickup.data.vertices:
        vertex.co -= center
    pickup.location = (0,0,0)
    bpy.ops.export_scene.gltf(filepath=str(OUT / ('pickup_jacket_' + name + '.glb')), export_format='GLB', use_selection=True, export_animations=False, export_skins=False)
    bpy.data.objects.remove(pickup, do_unlink=True)
    print('JACKET_EXPORTED', name, len(jacket.data.vertices), flush=True)

cloth.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (0.22,0.28,0.14,1)
for obj in bpy.data.objects:
    obj.hide_render = obj not in [jacket, arm]
    obj.hide_set(obj not in [jacket, arm])
bpy.ops.file.pack_all()
blend = Path('/Users/sami/Documents/Codex/2026-09-08/rev/outputs/chaquetas_militares.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
print('JACKETS_COMPLETE', flush=True)
