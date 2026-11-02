"""Convert 'Climbing Ladder.fbx' at the project root into assets/animations/ladder_climb.glb
(animation-only Mixamo donor GLB, meshes/cameras/lights stripped)."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE_FBX = ROOT / 'Climbing Ladder.fbx'
TARGET = ROOT / 'assets/animations/ladder_climb.glb'


def main():
	if not SOURCE_FBX.exists():
		raise FileNotFoundError(f'Missing source FBX: {SOURCE_FBX}')
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=str(SOURCE_FBX))

	for obj in list(bpy.data.objects):
		if obj.type != 'ARMATURE':
			bpy.data.objects.remove(obj, do_unlink=True)

	arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
	act = arm.animation_data.action
	act.name = 'LadderClimb'
	f_start = max(1, int(round(act.frame_range[0])))
	f_end = int(round(act.frame_range[1]))
	scn = bpy.context.scene
	scn.frame_start = f_start
	scn.frame_end = f_end

	# In 'Climbing Ladder.fbx', mixamorig:Hips is authored facing +Y (180 deg yaw
	# relative to our forward -Y / +Z Mixamo convention). Rotate Hips by 180 deg around
	# its vertical Y axis so the character faces the ladder rungs when climbing.
	from mathutils import Quaternion
	hips_pb = arm.pose.bones.get('mixamorig:Hips')
	if hips_pb is not None:
		yaw_180 = Quaternion((0.0, 0.0, 1.0, 0.0))
		baked_hips = {}
		for f in range(f_start, f_end + 1):
			scn.frame_set(f)
			bpy.context.view_layer.update()
			baked_hips[f] = (yaw_180 @ hips_pb.rotation_quaternion.copy()).normalized()
		for f, q in baked_hips.items():
			scn.frame_set(f)
			hips_pb.rotation_quaternion = q
			hips_pb.keyframe_insert('rotation_quaternion', frame=f)

	TARGET.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(TARGET),
		export_format='GLB',
		export_animations=True,
		export_animation_mode='ACTIVE_ACTIONS',
		export_frame_range=True,
		export_skins=True,
	)
	print(f'LADDER_CLIMB_GLB_READY: {TARGET} ({f_end - f_start + 1} frames from {SOURCE_FBX.name})')


if __name__ == '__main__':
	main()
