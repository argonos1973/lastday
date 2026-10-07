"""Farming props: seed pouch, berry cluster and a 4-stage growing crop.

Small ground props authored directly in Blender space (Z up, metres). The
gltf exporter writes them Y-up for Godot. Leaves are flattened, bent
ico-spheres so the plant reads organic without external textures.
"""
from pathlib import Path
import random
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/farming'
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT.mkdir(parents=True, exist_ok=True)

rng = random.Random(20261007)


def material(name, color, roughness=.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    return m


LEAF = material('crop_leaf', (.16, .34, .12))
LEAF_DARK = material('crop_leaf_dark', (.10, .24, .08))
STEM = material('crop_stem', (.24, .22, .10), .9)
BERRY = material('crop_berry', (.62, .06, .04), .5)
SOIL_MAT = material('crop_soil', (.16, .11, .07), .95)
BURLAP = material('seed_burlap', (.45, .34, .20), .95)
CORD = material('seed_cord', (.22, .15, .08), .9)
SEED = material('seed_grain', (.74, .64, .38), .8)


def finish(name):
    """Join loose objects, apply transforms and export one GLB."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f'{name}.glb'), export_format='GLB',
        use_selection=False, export_yup=True,
    )
    ob.select_set(False)
    bpy.data.objects.remove(ob)


def leaf(loc, yaw, tilt, length, width, mat=LEAF):
    """Flattened, drooping leaf pointing outward from `loc`."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    ob = bpy.context.active_object
    tip = length * .5
    for v in ob.data.vertices:
        co = v.co
        taper = 1.0 - .45 * abs(co.y)
        co.x *= width * .5 * max(taper, .25)
        co.y = co.y * tip + length * .5 + bend_droop(co.y)
        co.z *= .045
    ob.data.materials.append(mat)
    ob.rotation_euler = (tilt, 0.0, yaw)
    ob.location = loc
    return ob


def bend_droop(yn):
    # Gentle downward curl toward the leaf tip.
    return -.18 * yn * yn


def stem(loc, height, radius, lean_yaw=0.0, lean=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=height, vertices=7)
    ob = bpy.context.active_object
    ob.data.materials.append(STEM)
    ob.location = (loc[0], loc[1], loc[2] + height * .5)
    if lean:
        ob.rotation_euler[1] = lean
        ob.rotation_euler[2] = lean_yaw
    return ob


def berry(loc, radius=.013):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius)
    ob = bpy.context.active_object
    ob.data.materials.append(BERRY)
    ob.location = loc
    return ob


def plant_stage(name, stems, leaves_per_stem, height, berries=0, seed=None):
    r = random.Random(seed if seed is not None else hash(name))
    for s in range(stems):
        yaw = (s / max(stems, 1)) * 6.283 + r.uniform(-.5, .5)
        off = r.uniform(.0, .03)
        sx, sy = off * (1 if r.random() < .5 else -1), r.uniform(-.03, .03)
        h = height * r.uniform(.8, 1.05)
        stem((sx, sy, 0), h, .006 + height * .008, yaw, r.uniform(0, .18))
        n = leaves_per_stem + r.randint(0, 2)
        for i in range(n):
            t = .55 + .45 * i / max(n - 1, 1)
            ly = h * t
            lz = r.uniform(-.35, .5)
            leaf((sx, sy, ly), yaw + i * 2.4 + r.uniform(-.4, .4),
                 r.uniform(.5, 1.15), height * r.uniform(.16, .24),
                 height * r.uniform(.07, .11),
                 LEAF if r.random() > .3 else LEAF_DARK)
        for b in range(berries):
            bx = sx + r.uniform(-.05, .05)
            by = sy + r.uniform(-.05, .05)
            bz = h * r.uniform(.55, .98)
            berry((bx, by, bz), r.uniform(.010, .016))
    finish(name)


# --- Growing crop: four readable stages ---
plant_stage('crop_stage_0', 1, 2, .09, seed=11)          # two-leaf sprout
plant_stage('crop_stage_1', 2, 3, .22, seed=22)          # young plant
plant_stage('crop_stage_2', 3, 4, .38, seed=33)          # bushy, no fruit yet
plant_stage('crop_stage_3', 4, 5, .52, berries=14, seed=44)  # ripe berries

# --- Seed pouch: small burlap sack tied at the top, seeds spilling out ---
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=.075)
sack = bpy.context.active_object
for v in sack.data.vertices:
    v.co.z *= 1.15
    if v.co.z > .05:
        v.co.xy *= .55
sack.data.materials.append(BURLAP)
sack.location = (0, 0, .082)
stem((0, 0, .13), .03, .012)  # tied neck
for i in range(9):
    a = i / 9 * 6.283
    r = .09 + rng.uniform(0, .03)
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=1, radius=rng.uniform(.006, .010),
        location=(r * (1 if i % 2 else -1) * abs(rng.uniform(.2, 1)) * .4,
                  r * .5, .008))
    o = bpy.context.active_object
    o.data.materials.append(SEED)
finish('farm_seed_pouch')

# --- Berry cluster pickup: a handful of ripe berries with two leaves ---
for i in range(11):
    berry((rng.uniform(-.05, .05), rng.uniform(-.04, .04),
           .012 + rng.uniform(0, .018)), rng.uniform(.011, .015))
leaf((0, -.02, .01), .4, .9, .12, .05, LEAF_DARK)
leaf((.02, .03, .01), 2.8, .9, .11, .05)
finish('farm_berries')

# --- Tilled soil mound for the crop plot ---
bpy.ops.mesh.primitive_cylinder_add(radius=.30, depth=.05, vertices=18)
mound = bpy.context.active_object
mound.data.materials.append(SOIL_MAT)
mound.location = (0, 0, .025)
for i in range(14):
    a = i / 14 * 6.283
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=1, radius=rng.uniform(.02, .04),
        location=(.27 * (rng.uniform(.7, 1.0)) * (1 if i % 2 else -1) * .8,
                  .24 * (1 if i % 3 else -1) * .6, .045))
    clod = bpy.context.active_object
    clod.data.materials.append(SOIL_MAT)
finish('crop_soil_mound')

print('FARMING_ASSETS_DONE', sorted(p.name for p in OUT.glob('*.glb')))
