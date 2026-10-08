import bpy
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/player_with_clothes.glb'))
o=bpy.data.objects['Desnudo_arms']; rig=o.find_armature()
# Broaden the elbow's transferred skin weights while preserving wrist/shoulder seams.
for side in ('Left','Right'):
    upper=o.vertex_groups['mixamorig:'+side+'Arm']; fore=o.vertex_groups['mixamorig:'+side+'ForeArm']
    bone=rig.data.bones['mixamorig:'+side+'ForeArm']
    xf=o.matrix_world.inverted()@rig.matrix_world
    head=xf@bone.head_local; tail=xf@bone.tail_local; direction=(tail-head).normalized()
    for v in o.data.vertices:
        d=v.co-head; along=d.dot(direction)
        if abs(along)>18 or (d-direction*along).length>22:continue
        t=max(0,min(1,(along+18)/36)); t=t*t*(3-2*t)
        for g in list(v.groups):o.vertex_groups[g.group].remove([v.index])
        upper.add([v.index],1-t,'REPLACE');fore.add([v.index],t,'REPLACE')
bpy.context.view_layer.objects.active=o
o.select_set(True)
sub=o.modifiers.new('Smooth elbow topology','SUBSURF');sub.levels=1
bpy.ops.object.modifier_move_up(modifier=sub.name)
bpy.ops.object.modifier_apply(modifier=sub.name)
for p in o.data.polygons:p.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/arms_refined.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_materials='NONE')
print('REFINED_ARMS',len(o.data.vertices))
