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
	if not is_instance_valid(controller):
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
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
	# Read the final animated wrist, so props don't trail behind it by one frame.
	controller._update_hand_socket()
