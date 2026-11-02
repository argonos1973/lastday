"""Rolled bandage pickup model: cloth roll + loose unrolled tail.

Run from the project root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
      --python tools/blender/create_bandage_model.py

Writes assets/models/props/bandage_roll.glb (~14 cm drop model).
"""
import bpy, math, os
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/bandage_roll.glb'

bpy.ops.wm.read_factory_settings(use_empty=True)

cloth = bpy.data.materials.new('Venda tela')
cloth.use_nodes = True
bsdf = cloth.node_tree.nodes['Principled BSDF']
bsdf.inputs['Base Color'].default_value = (0.82, 0.78, 0.66, 1.0)
bsdf.inputs['Roughness'].default_value = 0.92
edge = bpy.data.materials.new('Venda borde')
edge.use_nodes = True
ebsdf = edge.node_tree.nodes['Principled BSDF']
ebsdf.inputs['Base Color'].default_value = (0.68, 0.63, 0.52, 1.0)
ebsdf.inputs['Roughness'].default_value = 0.95

# The roll: a flattened torus reads instantly as a coiled strip.
bpy.ops.mesh.primitive_torus_add(major_radius=0.048, minor_radius=0.024,
                                 major_segments=40, minor_segments=16,
                                 location=(0, 0, 0.020))
roll = bpy.context.object
roll.name = 'Venda_rollo'
roll.scale = (1.0, 1.0, 0.85)
roll.data.materials.append(cloth)
bpy.ops.object.shade_smooth()

# Wound edge hint: a slightly darker thin ring inside the roll face.
bpy.ops.mesh.primitive_torus_add(major_radius=0.030, minor_radius=0.004,
                                 major_segments=32, minor_segments=8,
                                 location=(0, 0, 0.0385))
ring = bpy.context.object
ring.name = 'Venda_rollo_borde'
ring.data.materials.append(edge)

# Loose tail: a thin rounded strip trailing off the roll. Build it as a
# subdivided plane bent over the roll edge so it hangs like unrolled cloth.
verts, faces = [], []
W, L, SEG, TH = 0.040, 0.165, 6, 0.0016
for i in range(SEG + 1):
    t = i / SEG
    # From the roll top surface down past its edge onto the ground plane.
    y = 0.052 - t * L
    z = 0.043 - t * 0.042 + math.sin(min(t * 2.2, 1.0) * math.pi) * 0.008
    for s in (-1, 1):
        verts.append((s * W / 2, y, max(z, TH)))
for i in range(SEG):
    a, b = i * 2, i * 2 + 2
    faces.append((a, b, b + 1, a + 1))
    faces.append((a + 1, b + 1, b, a))
mesh = bpy.data.meshes.new('Venda_tira')
mesh.from_pydata(verts, [], faces)
mesh.materials.append(cloth)
tail = bpy.data.objects.new('Venda_tira', mesh)
bpy.context.collection.objects.link(tail)

for o in [roll, ring, tail]:
    o.select_set(True)
bpy.context.view_layer.objects.active = roll
os.makedirs(OUT.parent, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB',
                          use_selection=True, export_yup=True)
print('BANDAGE_DONE', os.path.getsize(OUT))
