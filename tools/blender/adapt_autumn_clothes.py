"""Adapt the CC-BY Autumn Clothes FBX to the player's Mixamo skeleton.

Run with Blender 4.x:
  blender -b --python tools/blender/adapt_autumn_clothes.py

The source has no skin weights, so each garment is fitted to the game's
corresponding rest-pose mesh and receives weights sampled from the existing
weighted body/clothing meshes. Textures are repacked into the exported GLBs.
"""
from pathlib import Path
import math
import sys
import bpy
import bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/blender/sources/autumn_clothes'
FBX = SOURCE / 'source/Autumn Clothes.fbx'
TEX = SOURCE / 'textures'
OUT = ROOT / 'assets/characters/adapted/civil'
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/player_with_clothes.glb'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'
refs = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}


def world_bounds(objects):
    pts = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return (Vector([min(p[i] for p in pts) for i in range(3)]),
            Vector([max(p[i] for p in pts) for i in range(3)]))


def make_material(name, prefix):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .88
    def game_image(path, brightness=1.0, color_tint=None):
        image = bpy.data.images.load(str(path), check_existing=True)
        width, height = image.size
        limit = 2048 if prefix == 'Jacket' else 1024
        if max(width, height) > limit:
            scale = float(limit) / max(width, height)
            image.scale(max(1, int(width * scale)), max(1, int(height * scale)))
        if brightness != 1.0 or color_tint is not None:
            px = list(image.pixels[:])
            for i in range(0, len(px), 4):
                if prefix == 'Jacket' and color_tint is not None:
                    for channel in range(3):
                        px[i + channel] = min(1.0, max(0.0, px[i + channel]) ** .82 * 1.15)
                elif color_tint is None:
                    px[i] = min(1.0, px[i] * brightness)
                    px[i + 1] = min(1.0, px[i + 1] * brightness)
                    px[i + 2] = min(1.0, px[i + 2] * brightness)
                else:
                    # The source albedo is nearly black and desaturated. Lift
                    # its grayscale detail and tint it into readable civilian
                    # earth tones while preserving seams and fabric variation.
                    luminance = max(px[i], px[i + 1], px[i + 2])
                    floor = .62 if prefix == 'Pants' else .16
                    value = min(1.0, max(floor, luminance ** .38) * brightness)
                    for channel in range(3):
                        px[i + channel] = min(1.0, value * color_tint[channel])
            image.pixels[:] = px
        image.pack()
        return image
    palette = {
        'Jacket': ((.55, .58, .36), 1.22),   # worn olive canvas
        'Pants': ((.72, .64, .47), 1.18),    # faded brown-grey hiking trousers
        'Shoe': ((.34, .23, .14), 1.08),     # leather boots
        'Hat': ((.46, .43, .30), 1.12),      # faded khaki cap
    }
    tint, brightness = palette[prefix]
    base = game_image(TEX / (prefix + '_BC.jpg'), brightness, tint)
    base_node = nt.nodes.new('ShaderNodeTexImage'); base_node.image = base
    nt.links.new(base_node.outputs['Color'], bsdf.inputs['Base Color'])
    rough_path = TEX / (prefix + '_RGH.jpg')
    if rough_path.exists() and prefix != 'Jacket':
        rough = game_image(rough_path)
        rough.colorspace_settings.name = 'Non-Color'
        node = nt.nodes.new('ShaderNodeTexImage'); node.image = rough
        nt.links.new(node.outputs['Color'], bsdf.inputs['Roughness'])
    normal_path = TEX / (prefix + '_N.jpg')
    if normal_path.exists():
        normal = game_image(normal_path)
        normal.colorspace_settings.name = 'Non-Color'
        node = nt.nodes.new('ShaderNodeTexImage'); node.image = normal
        nmap = nt.nodes.new('ShaderNodeNormalMap')
        nmap.inputs['Strength'].default_value = .22 if prefix == 'Jacket' else .35
        nt.links.new(node.outputs['Color'], nmap.inputs['Color'])
        nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    metal_path = TEX / (prefix + '_M.jpg')
    if metal_path.exists():
        metal = game_image(metal_path)
        metal.colorspace_settings.name = 'Non-Color'
        node = nt.nodes.new('ShaderNodeTexImage'); node.image = metal
        nt.links.new(node.outputs['Color'], bsdf.inputs['Metallic'])
    return mat


materials = {key: make_material('Autumn_' + key, key) for key in ['Jacket', 'Pants', 'Shoe', 'Hat']}
bpy.ops.import_scene.fbx(filepath=str(FBX))
source_meshes = {o.name: o for o in bpy.data.objects if o.type == 'MESH' and o.name not in refs}


def fit_group(names, material, destination_bounds, sample_names, output_name, head_only=False, bounds_names=None):
    objs = [source_meshes[name] for name in names]
    for obj in objs:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True); bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if output_name == 'autumn_jacket':
        # Preserve the original coat proportions. Its sleeves are in A-pose;
        # map their shoulder-to-cuff axis to the actual horizontal arm chain.
        # A single bounding-box stretch flattens the torso and bends the cuffs.
        def smooth(a, b, x):
            t = max(0.0, min(1.0, (x-a)/(b-a)))
            return t*t*(3.0-2.0*t)
        shoulder = Vector((.185, .058, 1.485))
        axis = Vector((.324, 0.0, -.444)).normalized()
        radial = Vector((-axis.z, 0.0, axis.x))
        for obj in objs:
            for v in obj.data.vertices:
                p = v.co.copy()
                side = 1.0 if p.x >= 0 else -1.0
                x = abs(p.x)
                waist_ease = .35*smooth(1.02, 1.14, p.z)*(1.0-smooth(1.37, 1.47, p.z))
                trunk = Vector((p.x*(2.35+waist_ease), p.y*2.35+.015, p.z*2.04-.03))
                # Give the closed front clearance over the trouser waistband
                # and the bent thigh; retain the coat's original pocket folds.
                front = smooth(0.0, .065, -p.y)
                lower = 1.0-smooth(1.18, 1.38, p.z)
                trunk.y -= front*(.035+.045*lower)
                relative = Vector((x, p.y, p.z))-shoulder
                sleeve = Vector((side*(.39 + relative.dot(axis)*1.92),
                                 .11 + relative.y*2.0,
                                 2.999 + relative.dot(radial)*2.0))
                influence = smooth(.17, .25, x)*smooth(.38, .45, x+.17*p.z)
                v.co = trunk.lerp(sleeve, influence)

    else:
        bounds_objs = objs if bounds_names is None else [source_meshes[n] for n in bounds_names]
        src_lo, src_hi = world_bounds(bounds_objs)
        dst_lo, dst_hi = destination_bounds
        ratio = Vector([(dst_hi[i] - dst_lo[i]) / max(.0001, src_hi[i] - src_lo[i]) for i in range(3)])
        for obj in objs:
            for v in obj.data.vertices:
                for axis in range(3):
                    v.co[axis] = dst_lo[axis] + (v.co[axis] - src_lo[axis]) * ratio[axis]
    if output_name == 'autumn_jacket':
        # Close the original scarf-sized neckline with a fitted standing
        # collar. Follow the real boundary so there is no floating neck ring.
        bm = bmesh.new()
        bm.from_mesh(objs[0].data)
        boundary = {e for e in bm.edges if e.is_boundary}
        loops = []
        while boundary:
            edge = boundary.pop()
            group = set(edge.verts)
            todo = list(edge.verts)
            while todo:
                v = todo.pop()
                for e in v.link_edges:
                    if e in boundary:
                        boundary.remove(e)
                        for w in e.verts:
                            if w not in group:
                                group.add(w)
                                todo.append(w)
            loops.append(group)
        neck = max(loops, key=lambda group: sum(v.co.z for v in group)/len(group))
        first = min(neck, key=lambda v: v.co.x)
        ordered = [first]
        previous = None
        cursor = first
        while True:
            neighbors = [e.other_vert(cursor) for e in cursor.link_edges
                         if e.is_boundary and e.other_vert(cursor) in neck]
            nxt = next(v for v in neighbors if v != previous)
            if nxt == first:
                break
            ordered.append(nxt)
            previous, cursor = cursor, nxt
        ring = [v.co.copy() for v in ordered]
        if sum(ring[i].x*ring[(i+1)%len(ring)].y-ring[(i+1)%len(ring)].x*ring[i].y for i in range(len(ring))) < 0:
            ring.reverse()
        bm.free()
        n = len(ring)
        vertices = []
        for row in range(4):
            for p in ring:
                angle = math.atan2(p.y-.035, p.x)
                neck_top = Vector((.165*math.cos(angle), .035+.16*math.sin(angle), 3.235))
                if row == 0: point = p
                elif row == 1: point = p.lerp(neck_top, .68)
                elif row == 2: point = neck_top
                else: point = Vector((neck_top.x*.94, .035+(neck_top.y-.035)*.94, 3.223))
                vertices.append(point)
        faces = [(r*n+i, r*n+(i+1)%n, (r+1)*n+(i+1)%n, (r+1)*n+i)
                 for r in range(3) for i in range(n)]
        mesh = bpy.data.meshes.new('Fitted_collar')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        collar = bpy.data.objects.new('Fitted_collar', mesh)
        bpy.context.collection.objects.link(collar)
        collar_mat = bpy.data.materials.new('Autumn_Ribbed_Collar')
        collar_mat.use_nodes = True
        collar_bsdf = collar_mat.node_tree.nodes.get('Principled BSDF')
        collar_bsdf.inputs['Base Color'].default_value = (.035, .042, .055, 1)
        collar_bsdf.inputs['Roughness'].default_value = .94
        collar.data.materials.append(collar_mat)
        uv = mesh.uv_layers.new(name='UVMap')
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                index = mesh.loops[li].vertex_index
                uv.data[li].uv = (.10+.25*(index%n)/n, .35+.025*(index//n))
        objs.append(collar)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs: obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    garment = objs[0]
    garment.name = output_name
    if garment.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for polygon in garment.data.polygons:
        polygon.use_smooth = True
    # Recalculate normals after the proportional fitting transform.
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    garment.vertex_groups.clear()
    for bone in arm.data.bones: garment.vertex_groups.new(name=bone.name)
    if head_only:
        head = next((b.name for b in arm.data.bones if b.name.split(':')[-1] == 'Head'), None)
        if head is None: raise RuntimeError('Mixamo Head bone not found')
        for v in garment.data.vertices: garment.vertex_groups[head].add([v.index], 1.0, 'REPLACE')
    else:
        points = []
        inv = garment.matrix_world.inverted()
        for ref_name in sample_names:
            obj = refs.get(ref_name)
            if obj is None: continue
            frame = inv @ obj.matrix_world
            for v in obj.data.vertices:
                weights = {obj.vertex_groups[g.group].name: g.weight for g in v.groups if g.weight > .001}
                if weights: points.append((frame @ v.co, weights))
        if not points: raise RuntimeError('No weighted source points for ' + output_name)
        tree = KDTree(len(points))
        for i, (pos, _) in enumerate(points): tree.insert(pos, i)
        tree.balance()
        for v in garment.data.vertices:
            accum = {}
            for _, index, distance in tree.find_n(v.co, 8):
                factor = 1.0 / max(.025, distance) ** 2
                for bone, weight in points[index][1].items():
                    if garment.vertex_groups.get(bone): accum[bone] = accum.get(bone, 0.0) + factor * weight
            strongest = sorted(accum.items(), key=lambda item: item[1], reverse=True)[:4]
            total = sum(w for _, w in strongest)
            if total <= 0: raise RuntimeError('Unweighted vertex in ' + output_name)
            for bone, weight in strongest: garment.vertex_groups[bone].add([v.index], weight / total, 'REPLACE')
    mod = garment.modifiers.new('Character_skeleton', 'ARMATURE'); mod.object = arm
    # Keep vertices in the same world-space bind pose as the game rig.
    world = garment.matrix_world.copy()
    garment.parent = arm
    garment.matrix_world = world
    return garment


def export_pair(garment, stem):
    bpy.ops.object.select_all(action='DESELECT'); garment.select_set(True); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (stem + '.glb')), export_format='GLB',
                              use_selection=True, export_animations=False, export_skins=True)
    # A flat, centered copy is used for world loot previews and inventory icons.
    pickup = garment.copy(); pickup.data = garment.data.copy(); bpy.context.collection.objects.link(pickup)
    pickup.parent = None; pickup.matrix_world = garment.matrix_world.copy()
    for m in list(pickup.modifiers): pickup.modifiers.remove(m)
    bpy.ops.object.select_all(action='DESELECT'); pickup.select_set(True); bpy.context.view_layer.objects.active = pickup
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    center = sum((Vector(c) for c in pickup.bound_box), Vector()) / 8
    for v in pickup.data.vertices: v.co -= center
    bpy.ops.export_scene.gltf(filepath=str(OUT / ('pickup_' + stem + '.glb')), export_format='GLB',
                              use_selection=True, export_animations=False, export_skins=False)
    bpy.data.objects.remove(pickup, do_unlink=True)
    print('AUTUMN_GEAR_EXPORTED', stem, len(garment.data.vertices), flush=True)


def bounds(name): return world_bounds([refs[name]])

# Fit the original coat body, then bridge its neckline with a fitted collar.
# Keep the source pocket, zipper, button and cuff details.
jacket_dest = bounds('soldier_torso')
jacket = fit_group(['Arms_Main_LP', 'Parts_LP', 'Zip_LP', 'Buttons_LP', 'Lace_Leather_LP'],
                    materials['Jacket'], jacket_dest,
                    ['Body_arms', 'Desnudo_torso'],
                    'autumn_jacket', bounds_names=['Arms_Main_LP'])
export_pair(jacket, 'autumn_jacket')
if '--jacket-only' in sys.argv:
    print('AUTUMN_JACKET_COMPLETE', flush=True)
    sys.exit(0)

# Long trousers span hip-to-ankle, using the player's bare legs as the fit guide.
legs_lo, legs_hi = bounds('Desnudo_legs')
pants_dest = (Vector((bounds('Bottoms')[0].x, bounds('Bottoms')[0].y, legs_lo.z + .10)),
              Vector((bounds('Bottoms')[1].x, bounds('Bottoms')[1].y, jacket_dest[0].z + .10)))
pants = fit_group(['Pants_LP_2'], materials['Pants'], pants_dest,
                  ['Bottoms', 'Desnudo_legs', 'Body_legs', 'soldier_legs'], 'autumn_pants')
export_pair(pants, 'autumn_pants')

# Headwear is attached to the Head bone, centered on the existing hair cap.
hair_lo, hair_hi = bounds('Hair')
hat_dest = (Vector((hair_lo.x * .96, hair_lo.y * .94, hair_hi.z - .21)),
            Vector((hair_hi.x * .96, hair_hi.y * .94, hair_hi.z + .015)))
hat = fit_group(['Hat_LP'], materials['Hat'], hat_dest, [], 'autumn_hat', head_only=True)
export_pair(hat, 'autumn_hat')

# Hiking boots replace both default shoe meshes and use their existing rig fit.
boots = fit_group(['Shoe_Left_LP', 'Shoe_Right_LP'], materials['Shoe'], bounds('military_boots'),
                  ['Shoes', 'military_boots', 'Body_feet', 'Desnudo_feet'], 'autumn_boots')
export_pair(boots, 'autumn_boots')

for image in bpy.data.images:
    if image.source == 'FILE': image.pack()
print('AUTUMN_CLOTHES_COMPLETE', str(OUT), flush=True)
