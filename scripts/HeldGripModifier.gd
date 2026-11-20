extends SkeletonModifier3D
## Applies the grip after animation, without baking it into the idle/walk pose.
var controller: Node3D

func _process_modification() -> void:
	if not is_instance_valid(controller) or bool(controller.get("is_dead")):
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	# Undo any pose written by _physics_process/_process before this modifier
	# runs so pitch/finger rotations never accumulate across frames.
	controller._restore_aim_pitch_pose(skeleton)
	controller._m4_saved_left_arm_poses.clear()
	controller._processing_held_grip = true
	if controller._generic_hand_grip or (controller._has_fishing_rod and not controller._is_fishing):
		var rig: Dictionary = controller._grip_rig_for(skeleton, controller._hand_bone_idx, false)
		controller._apply_grip_fingers(skeleton, rig, true, controller._hand_grip_curl)
	if skeleton != controller._hand_skeleton:
		controller._apply_aim_pitch_pose(skeleton)
	# Read the final animated wrist, so props don't trail behind it by one frame.
	controller._update_hand_socket()
	if is_instance_valid(controller._torch_hand_root) and controller._torch_hand_root.get_child_count() > 0:
		controller._update_torch_hand_socket()
	if is_instance_valid(controller._drink_hand_root) and controller._drink_hand_root.get_child_count() > 0:
		controller._update_drink_hand_socket()
	if is_instance_valid(controller._rifle_weapon_offset):
		controller._update_rifle_visuals(0.0)

	controller._aim_pitch_saved_rotations.clear()
	controller._m4_saved_left_arm_poses.clear()
	controller._processing_held_grip = false
