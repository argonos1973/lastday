extends SceneTree
## Run with Godot --headless --path . --script tools/debug/TestHeldGrip.gd.
class GripPlayer extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := GripPlayer.new()
	root.add_child(player)
	var character: Node3D = load("res://assets/characters/adapted/player_with_clothes.glb").instantiate()
	player.add_child(character)
	character.scale = Vector3.ONE * 0.72
	player.third_person_model = character
	var skeleton: Skeleton3D = player._find_skeleton(character)
	player._hand_skeleton = skeleton
	player._hand_bone_idx = skeleton.find_bone("mixamorig_RightHand")
	assert(player._hand_bone_idx >= 0)
	player.third_person_hand_item_root = Node3D.new()
	character.add_child(player.third_person_hand_item_root)
	var modifier = load("res://scripts/HeldGripModifier.gd").new()
	modifier.controller = player
	skeleton.add_child(modifier)
	var wrist_rest := skeleton.get_bone_pose_rotation(player._hand_bone_idx)
	for data in [["Botella de agua", "water", "_build_third_person_plastic_bottle"], ["Hacha", "tool_axe", "_build_third_person_axe"], ["Vendaje", "medical", "_build_third_person_bandage"], ["Bateria", "battery", "_build_third_person_battery"]]:
		for child in player.third_person_hand_item_root.get_children():
			child.free()
		var item = load("res://scripts/Item.gd").create(data[0], data[1], 0.5, 1, 0)
		player.call(data[2])
		player._fit_held_prop_to_palm(item)
		assert(player._generic_hand_grip)
		assert(player.third_person_hand_item_root.get_child_count() == 1)
		for turn in [Vector3.ZERO, Vector3(0.6, 1.2, -0.4), Vector3(-0.8, -0.5, 1.5)]:
			skeleton.set_bone_pose_rotation(player._hand_bone_idx, wrist_rest * Quaternion.from_euler(turn))
			player._update_hand_socket()
			var wrist_world := skeleton.global_transform * skeleton.get_bone_global_pose(player._hand_bone_idx)
			var basis := wrist_world.basis.orthonormalized()
			var actual := basis.inverse() * (player.third_person_hand_item_root.global_position - wrist_world.origin)
			assert(actual.distance_to(player._palm_grip_offset() * 0.72) < 0.0001)
			assert(player.third_person_hand_item_root.global_basis.orthonormalized().is_equal_approx(basis))
		modifier._process_modification()
		var finger := skeleton.find_bone("mixamorig_RightHandMiddle2")
		assert(skeleton.get_bone_pose_rotation(finger).angle_to(skeleton.get_bone_rest(finger).basis.get_rotation_quaternion()) > 0.2)
		player._generic_hand_grip = false
		skeleton.reset_bone_poses()
		modifier._process_modification()
		assert(skeleton.get_bone_pose_rotation(finger).is_equal_approx(skeleton.get_bone_rest(finger).basis.get_rotation_quaternion()))
	print("PASS: four props follow wrist rotation; fingers close for grip and leave empty-hand poses unchanged")
	player.free()
	quit()
