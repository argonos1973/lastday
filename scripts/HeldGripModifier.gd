extends SkeletonModifier3D
## Applies the grip after animation, without baking it into the idle/walk pose.
var controller: Node3D
var joints: Array[Dictionary] = []

func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for finger in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
		for segment in range(1, 4):
			for prefix in ["mixamorig:", "mixamorig_", ""]:
				var index := skeleton.find_bone(prefix + "RightHand" + finger + str(segment))
				if index >= 0:
					joints.append({"index": index, "finger": finger, "segment": segment})
					break

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
		for joint in joints:
			var index: int = joint.index
			var segment: int = joint.segment
			var angle: float = [48.0, 68.0, 42.0][segment - 1]
			var axis := Vector3.RIGHT
			if joint.finger == "Thumb":
				axis = Vector3(0.0, 0.0, 1.0) if segment == 1 else Vector3.RIGHT
				angle = 42.0 if segment == 1 else 25.0
			var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			var target := rest * Quaternion(axis, deg_to_rad(angle * controller._hand_grip_curl))
			skeleton.set_bone_pose_rotation(index, target)
	if skeleton != controller._hand_skeleton:
		controller._apply_aim_pitch_pose(skeleton)
	# Read the final animated wrist, so props don't trail behind it by one frame.
	controller._update_hand_socket()
	if is_instance_valid(controller._rifle_weapon_offset):
		controller._update_rifle_visuals(0.0)

	controller._aim_pitch_saved_rotations.clear()
	controller._m4_saved_left_arm_poses.clear()
	controller._processing_held_grip = false
