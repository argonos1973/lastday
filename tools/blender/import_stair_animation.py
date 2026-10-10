import bpy
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(root/'outputs/Walking Up The Stairs.fbx'))
for a in bpy.data.actions: print('STAIR_ACTION',a.name,list(a.frame_range))
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.materials.clear()
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
print('BONES',len(rig.data.bones),'FPS',bpy.context.scene.render.fps)
act=rig.animation_data.action
bpy.context.scene.frame_start=int(act.frame_range[0]);bpy.context.scene.frame_end=int(act.frame_range[1])
for f in [int(act.frame_range[0]),int(act.frame_range[1])]:
 bpy.context.scene.frame_set(f); b=next(b for b in rig.pose.bones if 'Hips' in b.name);print('HIPS',f,list(rig.matrix_world@b.head))
bpy.ops.export_scene.gltf(filepath=str(root/'assets/animations/walking_up_stairs.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True)
