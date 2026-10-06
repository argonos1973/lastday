"""Normalize the supplied tactical helmet for the game's bone-bound headwear fit."""
from pathlib import Path
import bpy, math
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT.parent/'fuentes_lastday/tactical_helmet/tactical_helmet_with_headset_game-ready.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)])
scale=.32/(hi.z-lo.z)
transform=Matrix.Rotation(math.pi * 1.5,4,'Z') @ Matrix.Scale(scale,4) @ Matrix.Translation(-(lo+hi)/2)
for ob in meshes:
 ob.data.transform(transform@ob.matrix_world)
 ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.name='TacticalHelmet'
for ob in list(bpy.context.scene.objects):
 if ob not in meshes:bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=meshes[0]
for mat in bpy.data.materials:
 if mat.use_nodes:
  bs=mat.node_tree.nodes.get('Principled BSDF')
  if bs:bs.inputs['Roughness'].default_value=.75
out=ROOT/'assets/models/equipment/tactical_helmet.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
(ROOT/'outputs').mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'outputs/casco_tactico_adaptado.blend'))
print('EXPORTED',out)
