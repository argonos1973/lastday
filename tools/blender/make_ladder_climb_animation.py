"""Build assets/animations/ladder_climb.glb from walking_up_stairs.glb by
adjusting local bone quaternions (preserving parent-child hierarchy and rest lengths)."""
import math
from pathlib import Path
import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/animations/walking_up_stairs.glb'
TARGET = ROOT / 'assets/animations/ladder_climb.glb'


def rotate_bone_towards_child(pb_parent, pb_child, target_arm: Vector, blend: float = 1.0):
	"""Rotate `pb_parent.rotation_quaternion` so `pb_child.head` moves toward `target_arm`
	while preserving all descendant local rotations."""
	bpy.context.view_layer.update()
	p_head = pb_parent.head.copy()
	c_head = pb_child.head.copy()
	cur_dir = c_head - p_head
	des_dir = target_arm - p_head
	if cur_dir.length < 1e-4 or des_dir.length < 1e-4:
		return
	q_arm = Quaternion().slerp(cur_dir.normalized().rotation_difference(des_dir.normalized()), blend)
	# Convert armature-space delta rotation `q_arm` into `pb_parent` local quaternion delta
	parent_rot = pb_parent.matrix.to_quaternion()
	q_local = parent_rot.inverted() @ q_arm @ parent_rot
	pb_parent.rotation_quaternion = pb_parent.rotation_quaternion @ q_local
	bpy.context.view_layer.update()


def solve_arm_ik_local(pb_upper, pb_fore, pb_hand, target_arm: Vector, pole_arm: Vector):
	bpy.context.view_layer.update()
	s = pb_upper.head.copy()
	e = pb_fore.head.copy()
	h = pb_hand.head.copy()
	l1 = (e - s).length
	l2 = (h - e).length
	to_t = target_arm - s
	dist = min(max(to_t.length, abs(l1 - l2) + 2.0), (l1 + l2) * 0.96)
	dir_t = to_t.normalized()
	cos_a = max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)))
	ang_a = math.acos(cos_a)
	pole_dir = pole_arm - s
	pole_ortho = (pole_dir - dir_t * pole_dir.dot(dir_t)).normalized()
	desired_elbow = s + (dir_t * math.cos(ang_a) + pole_ortho * math.sin(ang_a)) * l1
	rotate_bone_towards_child(pb_upper, pb_fore, desired_elbow, 1.0)
	rotate_bone_towards_child(pb_fore, pb_hand, target_arm, 1.0)


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=str(SOURCE))
	arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
	act = arm.animation_data.action
	f_start = max(1, int(round(act.frame_range[0])))
	f_end = int(round(act.frame_range[1]))
	frames = list(range(f_start, f_end + 1))
	n_frames = len(frames)

	scn = bpy.context.scene
	samples = {}
	for f in frames:
		scn.frame_set(f)
		samples[f] = {
			pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy())
			for pb in arm.pose.bones
		}

	pb_spine1 = arm.pose.bones['mixamorig:Spine1']
	pb_spine2 = arm.pose.bones['mixamorig:Spine2']
	pb_neck = arm.pose.bones['mixamorig:Neck']
	pb_head = arm.pose.bones['mixamorig:Head']
	pb_head_end = arm.pose.bones.get('mixamorig:HeadTop_End', pb_head)
	pb_l_up = arm.pose.bones['mixamorig:LeftArm']
	pb_l_fore = arm.pose.bones['mixamorig:LeftForeArm']
	pb_l_hand = arm.pose.bones['mixamorig:LeftHand']
	pb_r_up = arm.pose.bones['mixamorig:RightArm']
	pb_r_fore = arm.pose.bones['mixamorig:RightForeArm']
	pb_r_hand = arm.pose.bones['mixamorig:RightHand']
	pb_l_upleg = arm.pose.bones['mixamorig:LeftUpLeg']
	pb_l_leg = arm.pose.bones['mixamorig:LeftLeg']
	pb_l_foot = arm.pose.bones['mixamorig:LeftFoot']
	pb_r_upleg = arm.pose.bones['mixamorig:RightUpLeg']
	pb_r_leg = arm.pose.bones['mixamorig:RightLeg']
	pb_r_foot = arm.pose.bones['mixamorig:RightFoot']

	new_act = bpy.data.actions.new('LadderClimb')
	arm.animation_data.action = new_act

	for idx, src_f in enumerate(frames):
		out_f = idx + 1
		u = idx / float(max(1, n_frames - 1))
		phase = u * math.tau

		for pb in arm.pose.bones:
			loc, rot, sca = samples[src_f][pb.name]
			pb.location = loc.copy()
			pb.rotation_quaternion = rot.copy()
			pb.scale = sca.copy()
		bpy.context.view_layer.update()

		# Keep torso upright and head tilted slightly up toward the upper rungs
		rotate_bone_towards_child(pb_spine1, pb_spine2, pb_spine1.head + Vector((0.0, 28.0, -3.0)), 0.70)
		rotate_bone_towards_child(pb_spine2, pb_neck, pb_spine2.head + Vector((0.0, 28.0, -3.0)), 0.70)
		rotate_bone_towards_child(pb_head, pb_head_end, pb_head.head + Vector((0.0, 32.0, -12.0)), 0.65)

		# Extra high-knee step for vertical ladder rungs
		l_step = 0.5 * (1.0 - math.cos(phase))
		r_step = 0.5 * (1.0 + math.cos(phase))
		if l_step > 0.05:
			lk = pb_l_leg.head + Vector((0.0, 22.0 * l_step, 10.0 * l_step))
			rotate_bone_towards_child(pb_l_upleg, pb_l_leg, lk, 0.55)
			rotate_bone_towards_child(pb_l_leg, pb_l_foot, pb_l_leg.head + Vector((0.0, -72.0, 8.0)), 0.55)
		if r_step > 0.05:
			rk = pb_r_leg.head + Vector((0.0, 22.0 * r_step, 10.0 * r_step))
			rotate_bone_towards_child(pb_r_upleg, pb_r_leg, rk, 0.55)
			rotate_bone_towards_child(pb_r_leg, pb_r_foot, pb_r_leg.head + Vector((0.0, -72.0, 8.0)), 0.55)

		# Alternating hand reach on the ladder rungs in counter-phase with legs
		chest = pb_spine2.head.copy()
		l_hand_wave = r_step   # 1.0 overhead when right foot is high, 0.0 chest pull when left foot is high
		r_hand_wave = l_step
		l_pull_out = max(0.0, -math.sin(phase)) * 6.5
		r_pull_out = max(0.0, math.sin(phase)) * 6.5

		l_target = Vector((chest.x + 21.0, chest.y + 6.0 + 52.0 * l_hand_wave, chest.z + 36.0 - l_pull_out))
		r_target = Vector((chest.x - 21.0, chest.y + 6.0 + 52.0 * r_hand_wave, chest.z + 36.0 - r_pull_out))
		l_pole = chest + Vector((52.0, -24.0, -12.0))
		r_pole = chest + Vector((-52.0, -24.0, -12.0))

		solve_arm_ik_local(pb_l_up, pb_l_fore, pb_l_hand, l_target, l_pole)
		solve_arm_ik_local(pb_r_up, pb_r_fore, pb_r_hand, r_target, r_pole)

		for pb in arm.pose.bones:
			pb.keyframe_insert('location', frame=out_f)
			pb.keyframe_insert('rotation_quaternion', frame=out_f)
			pb.keyframe_insert('scale', frame=out_f)

	scn.frame_start = 1
	scn.frame_end = n_frames

	for f_check in (1, n_frames // 4, n_frames // 2):
		scn.frame_set(f_check)
		bpy.context.view_layer.update()
		lh = arm.matrix_world @ pb_l_hand.head
		rh = arm.matrix_world @ pb_r_hand.head
		lf = arm.matrix_world @ pb_l_foot.head
		rf = arm.matrix_world @ pb_r_foot.head
		print(f'Frame {f_check:2d}: LHand={[round(x,2) for x in lh]} RHand={[round(x,2) for x in rh]} LFoot={[round(x,2) for x in lf]} RFoot={[round(x,2) for x in rf]}')

	for o in list(bpy.data.objects):
		if o.type == 'MESH':
			bpy.data.objects.remove(o, do_unlink=True)
	TARGET.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=str(TARGET),
		export_format='GLB',
		export_animations=True,
		export_animation_mode='ACTIONS',
		export_frame_range=True,
		export_skins=True,
	)
	print('LADDER_CLIMB_GLB_READY:', TARGET)


if __name__ == '__main__':
	main()
