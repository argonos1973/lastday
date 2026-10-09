"""Fit the supplied military vest, plaid jacket and military backpack onto the
character rig (player_with_clothes.glb) and export Godot-ready GLBs.

- Vest + jacket: positioned over the torso, skinned via nearest-vertex weight
  transfer from the character's own clothing/body meshes (same technique as
  create_military_jackets.py), exported with the armature so
  MilitaryJackets.attach can retarget the skin in-game.
- Backpack: normalized upright, decimated, centered — it mounts on the spine
  socket like backpack_detailed.glb.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT.parent / 'fuentes_lastday' / 'gear'
JACKETS = ROOT / 'assets/characters/adapted/jackets'
ADAPTED = ROOT / 'assets/characters/adapted'
RENDER_ONLY = '--render-only' in sys.argv

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/player_with_clothes.glb'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.data.pose_position = 'REST'


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def merge_meshes(objs, name):
    meshes = [o for o in objs if o.type == 'MESH']
    non_mesh = [o.name for o in objs if o.type != 'MESH']
    for o in meshes:
        o.parent = None
        o.matrix_world = o.matrix_world.copy()
    if len(meshes) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes:
            o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
    merged = meshes[0]
    merged.name = name
    for n in non_mesh:
        dead = bpy.data.objects.get(n)
        if dead is not None:
            bpy.data.objects.remove(dead, do_unlink=True)
    return merged


def apply_transform(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bounds_of(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in pts) for i in range(3)])
    hi = Vector([max(v[i] for v in pts) for i in range(3)])
    return lo, hi


def transfer_weights(garment, ref_names):
    """Nearest-sample weight transfer, same as create_military_jackets.py."""
    inv = garment.matrix_world.inverted()
    points = []
    for name in ref_names:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        frame = inv @ obj.matrix_world
        for vertex in obj.data.vertices:
            groups = {obj.vertex_groups[g.group].name: g.weight
                      for g in vertex.groups if g.weight > 0.001}
            if groups:
                points.append((frame @ vertex.co, groups))
    tree = KDTree(len(points))
    for i, (position, _) in enumerate(points):
        tree.insert(position, i)
    tree.balance()
    garment.vertex_groups.clear()
    for bone in arm.data.bones:
        garment.vertex_groups.new(name=bone.name)
    for vertex in garment.data.vertices:
        weights = {}
        for _, index, distance in tree.find_n(vertex.co, 4):
            influence = 1.0 / max(0.2, distance) ** 2
            for name, weight in points[index][1].items():
                if garment.vertex_groups.get(name):
                    weights[name] = weights.get(name, 0) + weight * influence
        strongest = sorted(weights.items(), key=lambda p: p[1], reverse=True)[:4]
        total = sum(w for _, w in strongest)
        if total <= 0:
            raise RuntimeError('Unweighted vertex in ' + garment.name)
        for name, weight in strongest:
            garment.vertex_groups[name].add([vertex.index], weight / total, 'REPLACE')
    modifier = garment.modifiers.new('Character_skeleton', 'ARMATURE')
    modifier.object = arm
    # The Mixamo armature carries a 0.01 scale; parenting reinterprets the
    # local matrix. Keep the garment's world transform so exports keep real
    # size (same as create_military_jackets.py).
    world = garment.matrix_world.copy()
    garment.parent = arm
    garment.matrix_world = world


# The character GLB ships a ~2 m helper sphere that rides along with armature
# exports; remove it so the garment GLBs stay clean. The glTF exporter picks up
# the orphaned mesh datablock too, so purge mesh data as well.
for helper in [o for o in bpy.data.objects if 'sphere' in o.name.lower()]:
    bpy.data.objects.remove(helper, do_unlink=True)
for mesh in [m for m in bpy.data.meshes if 'sphere' in m.name.lower()]:
    bpy.data.meshes.remove(mesh)

tops = bpy.data.objects['Tops']
t_lo, t_hi = bounds_of(tops)
t_size = t_hi - t_lo
t_center = (t_lo + t_hi) * 0.5
print('TOPS bounds', tuple(round(v, 2) for v in t_lo), tuple(round(v, 2) for v in t_hi), flush=True)

CHEST_Z = t_hi.z - t_size.z * 0.30  # upper torso centre


def constrain_garment_weights(garment, sleeves):
    # Torso panels never inherit an arm bone merely because it is nearby.
    names={b.name.split(':')[-1]:b.name for b in arm.data.bones}
    for v in garment.data.vertices:
        sampled={garment.vertex_groups[g.group].name:g.weight for g in v.groups}
        for group in garment.vertex_groups: group.remove([v.index])
        if sleeves and abs(v.co.x)>.44 and v.co.z>2.70:
            side='Left' if v.co.x>0 else 'Right'
            blend=max(0,min(1,(abs(v.co.x)-.82)/.24))
            shoulder=max(0,min(1,(abs(v.co.x)-.44)/.18))
            shoulder=shoulder*shoulder*(3-2*shoulder)
            pairs=[('Spine2',1-shoulder),(side+'Arm',(1-blend)*shoulder),(side+'ForeArm',blend*shoulder)]
        else:
            blend=max(0,min(1,(v.co.z-2.48)/.32))
            pairs=[('Spine1',1-blend),('Spine2',blend)]
        weights={names[name]:weight for name,weight in pairs if weight>0}
        if not sleeves:
            # Shoulder webbing follows the shirt/shoulder rather than only
            # Spine2, preventing it sinking through when arms swing.
            blend=max(0,min(1,(v.co.z-2.90)/.18))
            weights={name:weight*(1-blend) for name,weight in weights.items()}
            for name,weight in sampled.items(): weights[name]=weights.get(name,0)+weight*blend
        strongest=sorted(weights.items(),key=lambda item:item[1],reverse=True)[:4]
        total=sum(weight for _,weight in strongest)
        for name,weight in strongest:
            if weight>0: garment.vertex_groups[name].add([v.index],weight/total,'REPLACE')


def fit_vest():
    vest = merge_meshes(import_glb(str(SRC / 'tactical_plate_carrier_vest_-_game_ready.glb')), 'plate_carrier')
    # Source front is +X, whereas the character faces -Y.
    apply_transform(vest)
    vest.data.transform(Matrix.Rotation(-math.pi * .5, 4, 'Z'))
    v_lo, v_hi = bounds_of(vest)
    v_size = v_hi - v_lo
    # Vest is now upright with the plate facing -Y.
    # Scale so its height covers ~55% of the shirt torso.
    scale = (t_size.z * 0.55) / v_size.z
    vest.scale = Vector((scale, scale, scale))
    apply_transform(vest)
    v_lo, v_hi = bounds_of(vest)
    v_center = (v_lo + v_hi) * 0.5
    # Centre on the chest: collar opening at the neck, plate over the chest.
    vest.location += Vector((t_center.x - v_center.x, (t_lo.y + t_hi.y) * 0.5 - v_center.y + t_size.y * 0.02,
                             CHEST_Z - v_center.z))
    apply_transform(vest)
    # The carrier must surround the shirt, not the bare chest. Its original
    # uniform height fit put both plates underneath Tops.
    for v in vest.data.vertices:
        v.co.x = t_center.x + (v.co.x-t_center.x)*1.38
        v.co.y = t_center.y + (v.co.y-t_center.y)*1.38
        # Longer plate over the ribs; straps meet the shoulders rather
        # than the collar. Preserve width/depth independently of height.
        upper=max(0,min(1,(v.co.z-2.85)/.32))
        upper=upper*upper*(3-2*upper)
        v.co.z = CHEST_Z + (v.co.z-CHEST_Z)*1.14 - .15 + .14*upper
    # Wrap the straps around the shirt's actual outer shell. Merely lowering
    # the complete carrier buries its shoulder webbing in the clothed torso.
    from mathutils.bvhtree import BVHTree
    shirt_points=[tops.matrix_world@v.co for v in tops.data.vertices]
    shell=BVHTree.FromPolygons(shirt_points,[list(p.vertices) for p in tops.data.polygons])
    for v in vest.data.vertices:
        if v.co.z<2.84: continue
        center=Vector((t_center.x,t_center.y,v.co.z))
        radial=v.co-center
        if radial.length<.001: continue
        hit,normal,_,distance=shell.ray_cast(center,radial.normalized(),2.0)
        if hit is not None and distance+.045>radial.length:
            v.co=center+radial.normalized()*(distance+.045)
    transfer_weights(vest, ['Tops', 'Body_torso', 'Desnudo_torso'])
    constrain_garment_weights(vest, False)
    export_skinned(vest, 'plate_carrier')


def fit_jacket():
    jacket = merge_meshes(import_glb(str(SRC / 'plaid_jacket.glb')), 'plaid_jacket')
    # Source is already upright in world space (front -Y, collar up, sleeves
    # along X in an A-pose) — no initial rotation needed.
    apply_transform(jacket)
    j_lo, j_hi = bounds_of(jacket)
    j_size = j_hi - j_lo
    # Rough pre-fit: cover the shirt torso and sit the collar at the neck.
    # Exact wrapping is left to the shrinkwrap passes below.
    scale = (t_size.z * 0.95) / j_size.z
    jacket.scale = Vector((scale, scale, scale))
    apply_transform(jacket)
    j_lo, j_hi = bounds_of(jacket)
    jacket.location += Vector((t_center.x - (j_lo.x + j_hi.x) * 0.5,
                               t_center.y - (j_lo.y + j_hi.y) * 0.5,
                               t_hi.z - j_hi.z + t_size.z * 0.02))
    apply_transform(jacket)
    # Raise the drooping A-pose sleeves onto the T-pose arm line first —
    # without this the wrap below glues them to the torso in a bat wing.
    shoulder_x = t_size.x * 0.20
    max_x = max(abs(v.co.x) for v in jacket.data.vertices)
    cuff_verts = [v for v in jacket.data.vertices if abs(v.co.x) > max_x * 0.8]
    root_verts = [v for v in jacket.data.vertices if shoulder_x < abs(v.co.x) < t_size.x * 0.30]
    if cuff_verts and root_verts:
        cuff_z = sum(v.co.z for v in cuff_verts) / len(cuff_verts)
        cuff_x = sum(abs(v.co.x) for v in cuff_verts) / len(cuff_verts)
        root_z = sum(v.co.z for v in root_verts) / len(root_verts)
        arm_z = t_hi.z - t_size.z * 0.16  # T-pose arm line
        droop = min(math.atan2(arm_z - cuff_z, cuff_x - shoulder_x), math.radians(85))
        print('SLEEVE droop deg', round(math.degrees(droop), 1), flush=True)
        ca, sa = math.cos(droop), math.sin(droop)
        for v in jacket.data.vertices:
            side = 1.0 if v.co.x > 0 else -1.0
            if side * v.co.x <= shoulder_x:
                continue
            dx = abs(v.co.x) - shoulder_x
            dz = v.co.z - root_z
            v.co.x = side * (shoulder_x + dx * ca - dz * sa)
            v.co.z = root_z + dx * sa + dz * ca
    # Wrap the coat around the character's own clothes by projecting each
    # vertex onto the nearest surface point of the right shell — sleeves onto
    # the arms, the rest onto the shirt/trousers — plus a wearing margin.
    # Manual BVH projection is deterministic where a Shrinkwrap modifier's
    # vertex_group is unreliable in background mode.
    from mathutils.bvhtree import BVHTree

    def bvh_of(names):
        verts, faces = [], []
        for name in names:
            source = bpy.data.objects.get(name)
            if source is None:
                continue
            base = len(verts)
            verts += [source.matrix_world @ v.co for v in source.data.vertices]
            faces += [[base + i for i in p.vertices] for p in source.data.polygons]
        return BVHTree.FromPolygons(verts, faces)

    # Body_torso is what actually draws the bare arms in-game (it stays
    # visible under this coat), so sleeves must wrap over it too — wrapping
    # only the hidden Desnudo/Body_arms leaves the skin poking through.
    body_bvh = bvh_of(('Tops', 'Bottoms', 'Body_torso'))
    arms_bvh = bvh_of(('Body_arms', 'Desnudo_arms', 'Body_torso'))
    # Arm profile per x-slice: axis centre and outer radius, so each sleeve
    # vertex can be wrapped cylindrically around the arm it covers.
    arm_pts = []
    for name in ('Body_arms', 'Desnudo_arms', 'Body_torso'):
        source = bpy.data.objects.get(name)
        if source is not None:
            arm_pts += [source.matrix_world @ v.co for v in source.data.vertices]
    arm_bins = {}
    for p in arm_pts:
        if abs(p.x) > shoulder_x and p.z > t_lo.z + t_size.z * 0.55:
            key = (1 if p.x > 0 else -1, int(abs(p.x) / 0.08))
            arm_bins.setdefault(key, []).append(p)
    arm_prof = {}
    for key, pts in arm_bins.items():
        cy = sum(p.y for p in pts) / len(pts)
        cz = sum(p.z for p in pts) / len(pts)
        dists = sorted(math.hypot(p.y - cy, p.z - cz) for p in pts)
        radius = dists[int(len(dists) * 0.8)]
        arm_prof[key] = (cy, cz, radius)

    def arm_wrap(x):
        side = 1 if x > 0 else -1
        for d in range(0, 5):
            for step in (int(abs(x) / 0.08) + d, int(abs(x) / 0.08) - d):
                if step >= 0 and (side, step) in arm_prof:
                    return arm_prof[(side, step)]
        return None

    def is_sleeve_vert(v):
        return abs(v.co.x) > shoulder_x and v.co.z > t_lo.z + t_size.z * 0.55

    # A drooped sleeve sits below the arm axis: pushing each vertex radially
    # from that axis collapses the tube into a crescent hanging under the arm.
    # First recentre each x-slice of the sleeve onto the measured axis, then
    # push out to the arm surface radius plus a wearing margin.
    sleeve_bins = {}
    for v in jacket.data.vertices:
        if is_sleeve_vert(v):
            key = (1 if v.co.x > 0 else -1, int(abs(v.co.x) / 0.08))
            sleeve_bins.setdefault(key, []).append(v)
    sleeve_centers = {}
    for key, vs in sleeve_bins.items():
        sleeve_centers[key] = (sum(v.co.y for v in vs) / len(vs),
                               sum(v.co.z for v in vs) / len(vs))

    for v in jacket.data.vertices:
        x = abs(v.co.x)
        if is_sleeve_vert(v):
            prof = arm_wrap(x)
            key = (1 if v.co.x > 0 else -1, int(x / 0.08))
            sc = sleeve_centers.get(key)
            if prof is not None and sc is not None:
                cy, cz, radius = prof
                sy, sz = sc
                vy = v.co.y + (cy - sy)
                vz = v.co.z + (cz - sz)
                dy, dz = vy - cy, vz - cz
                length = math.hypot(dy, dz)
                target = radius + 0.07
                if length > 0.001:
                    v.co.y = cy + dy / length * target
                    v.co.z = cz + dz / length * target
                else:
                    v.co.y, v.co.z = vy, vz
                continue
        body_hit = body_bvh.find_nearest(v.co)
        if body_hit[0] is not None and body_hit[3] > 0.001:
            v.co = body_hit[0] + body_hit[1] * 0.07
    # The source coat is elbow-length: stretch the sleeve tips along the arm
    # axis so the cuff reaches the wrist and the forearm stays covered.
    arm_end = 0.85
    cuff_target = 1.32
    max_sleeve = max(abs(v.co.x) for v in jacket.data.vertices
                     if v.co.z > t_lo.z + t_size.z * 0.55)
    if max_sleeve > arm_end + 0.05:
        stretch = (cuff_target - arm_end) / (max_sleeve - arm_end)
        for v in jacket.data.vertices:
            x = abs(v.co.x)
            if x > arm_end and v.co.z > t_lo.z + t_size.z * 0.55:
                v.co.x = (1.0 if v.co.x > 0 else -1.0) * (arm_end + (x - arm_end) * stretch)
    transfer_weights(jacket, ['Body_arms', 'Body_torso', 'Desnudo_torso'])
    constrain_garment_weights(jacket, True)
    export_skinned(jacket, 'plaid')


def export_skinned(garment, variant):
    bpy.ops.object.select_all(action='DESELECT')
    garment.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(JACKETS / ('military_jacket_' + variant + '.glb')),
                              export_format='GLB', use_selection=True,
                              export_animations=False, export_skins=True)
    # Flat pickup copy: same worn shape, no skin, centred at the origin.
    pickup = garment.copy()
    pickup.data = garment.data.copy()
    bpy.context.collection.objects.link(pickup)
    pickup.parent = None
    pickup.matrix_world = garment.matrix_world.copy()
    for m in list(pickup.modifiers):
        pickup.modifiers.remove(m)
    bpy.ops.object.select_all(action='DESELECT')
    pickup.select_set(True)
    bpy.context.view_layer.objects.active = pickup
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    center = sum((Vector(v) for v in pickup.bound_box), Vector()) / 8
    for vertex in pickup.data.vertices:
        vertex.co -= center
    pickup.location = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=str(JACKETS / ('pickup_jacket_' + variant + '.glb')),
                              export_format='GLB', use_selection=True,
                              export_animations=False, export_skins=False)
    bpy.data.objects.remove(pickup, do_unlink=True)
    print('GARMENT_EXPORTED', variant, len(garment.data.vertices), flush=True)


def fit_backpack():
    objs = import_glb(str(SRC / 'military_backpack.glb'))
    meshes = [o for o in objs if o.type == 'MESH']
    for o in meshes:
        o.parent = None
        o.matrix_world = o.matrix_world.copy()
        # Decimate the heavy photogrammetry-style parts.
        tris = len(o.data.polygons)
        if tris > 8000:
            dec = o.modifiers.new('dec', 'DECIMATE')
            dec.ratio = 20000.0 / tris
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier='dec')
        o.data.materials and None
    all_pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    lo = Vector([min(v[i] for v in all_pts) for i in range(3)])
    hi = Vector([max(v[i] for v in all_pts) for i in range(3)])
    center = (lo + hi) * 0.5
    height = hi.z - lo.z
    target_h = 0.62
    s = target_h / height
    from mathutils import Matrix
    for o in meshes:
        m = o.matrix_world.copy()
        for v in o.data.vertices:
            v.co = (m @ v.co - center) * s
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ADAPTED / 'military_backpack.glb'),
                              export_format='GLB', use_selection=True,
                              export_animations=False, export_skins=False)
    print('BACKPACK_EXPORTED', flush=True)


if '--plaid-only' not in sys.argv:
    fit_vest()
if '--vest-only' not in sys.argv:
    fit_jacket()
if '--garments-only' not in sys.argv and '--vest-only' not in sys.argv and '--plaid-only' not in sys.argv:
    fit_backpack()

if RENDER_ONLY or True:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = scene.render.resolution_y = 640
    world = bpy.data.worlds.new('W')
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.12, 0.14, 0.18, 1)
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
    scene.collection.objects.link(cam)
    scene.camera = cam
    char_pts = [tops.matrix_world @ v.co for v in tops.data.vertices]
    c = sum(char_pts, Vector()) / len(char_pts)
    d = Vector((0, -1.6, 0.55)) * t_size.z * 1.9
    cam.location = c + d
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = '/tmp/gear_fit_front.png'
    bpy.ops.render.render(write_still=True)
    d2 = Vector((1.6, 0, 0.35)) * t_size.z * 1.9
    cam.location = c + d2
    cam.rotation_euler = (-d2).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = '/tmp/gear_fit_side.png'
    bpy.ops.render.render(write_still=True)
print('DONE')
