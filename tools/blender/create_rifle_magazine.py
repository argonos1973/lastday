"""Detachable box magazine for the sniper rifle loot item. Godot metres, Y up.
The mag is modelled upright: feed lips at +Y, slight forward curve towards +Z,
baseplate at -Y. Scale is tuned down in the loot template like other pickups."""
import bpy, math
from pathlib import Path
R = Path(__file__).resolve().parents[2]
O = R / 'assets/models/weapons'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name, c, metallic=0.0, rough=0.7):
    m = bpy.data.materials.new(name); m.diffuse_color = (*c, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*c, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    return m

steel = mat('Mag_blued_steel', (0.055, 0.06, 0.065), metallic=0.85, rough=0.45)
brass = mat('Mag_brass_round', (0.55, 0.42, 0.12), metallic=0.9, rough=0.35)

def box(name, loc, scale, m, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = o.modifiers.new('soft', 'BEVEL'); mod.width = bevel; mod.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier='soft')
    o.data.materials.append(m)
    return o

def cyl(name, loc, radius, depth, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=12)
    o = bpy.context.object; o.name = name
    o.data.materials.append(m)
    return o

# Body: three stacked segments tilting forwards give the classic banana curve.
W, D = 0.024, 0.016          # width x depth of the mag box
segs = [(0.0, 0.00, 0.060, math.radians(0)),
        (0.0, 0.004, 0.098, math.radians(6)),
        (0.0, 0.010, 0.134, math.radians(12))]
for i, (x, z, y, tilt) in enumerate(segs):
    box('Mag_body_%d' % i, (x, y, z), (W, 0.042, D), steel, bevel=0.002, rot=(tilt, 0, 0))
# Feed lips: slightly narrower collar on top with two brass rounds peeking out.
box('Mag_feed', (0.0, 0.160, 0.014), (W * 0.82, 0.016, D * 0.9), steel, bevel=0.0015, rot=(math.radians(14), 0, 0))
cyl('Mag_round_0', (-0.005, 0.171, 0.016), 0.0045, 0.030, brass, rot=(math.radians(14), 0, math.radians(90)))
cyl('Mag_round_1', (0.005, 0.172, 0.013), 0.0045, 0.030, brass, rot=(math.radians(14), 0, math.radians(90)))
# Baseplate: a bit wider, sticks out the bottom.
box('Mag_base', (0.0, 0.036, -0.002), (W * 1.25, 0.012, D * 1.2), steel, bevel=0.0018)

O.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(O / 'rifle_magazine.glb'), export_format='GLB', export_yup=True)
print('WROTE', O / 'rifle_magazine.glb')
