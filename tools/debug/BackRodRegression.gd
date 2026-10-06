extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	var load_animations := false
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _setup_third_person_animation(character: Node3D) -> void:
		if load_animations:
			super._setup_third_person_animation(character)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not _check_backpack_attachment():
		return
	var player := TestPlayer.new()
	root.add_child(player)
	player.third_person_back_item_root = Node3D.new()
	player.add_child(player.third_person_back_item_root)
	for slot in range(2):
		player._stored_back_items[slot] = {"name": "Caña de pescar", "type": "tool_fishing"}
		player._build_stored_back_visual(slot)
		var container: Node3D = player._stored_back_visuals[slot]
		if container == null or container.get_child_count() != 1:
			fail("Missing back rod")
			return
		var box: AABB = player._hierarchy_local_aabb(container)
		if box.get_center().length() > 0.001:
			fail("Rod displaced from shoulder: %s" % box.get_center())
			return
		if absf(box.size.y - 1.65) > 0.02 or box.size.y < maxf(box.size.x, box.size.z) * 5.0:
			fail("Rod is not upright or has wrong scale: %s" % box.size)
			return
		var expected_x := -0.20 if slot == 0 else 0.20
		if absf(container.position.x - expected_x) > 0.001:
			fail("Wrong shoulder")
			return
	# Repeated synchronization must replace the prop without a visible duplicate.
	player._build_stored_back_visual(0)
	if player.third_person_back_item_root.get_child_count() != 2:
		fail("Duplicate back prop after synchronization")
		return
	player._stored_back_items[0] = null
	player._build_stored_back_visual(0)
	if player._stored_back_visuals[0] != null or player.third_person_back_item_root.get_child_count() != 1:
		fail("Empty shoulder retained a visual")
		return
	print("PASS: rod centered upright on both shoulders; repeated synchronization and removal")
	var animated_ok: bool = await check_animated_backpack(player)
	player.free()
	if animated_ok:
		print("PASS: real turn/sleep animations keep backpack and shoulders bound after skeleton updates")
	quit(0 if animated_ok else 1)

func _check_backpack_attachment() -> bool:
	var player := TestPlayer.new()
	root.add_child(player)
	player.third_person_model = Node3D.new()
	player.third_person_model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.55), Vector3(0, 0.1, 0))
	player.add_child(player.third_person_model)
	var skeleton := Skeleton3D.new()
	skeleton.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 0.01), Vector3.ZERO)
	skeleton.add_bone("Hips")
	skeleton.add_bone("Spine2")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(0, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	skeleton.set_bone_rest(1, Transform3D(Basis(Vector3.UP, 0.2), Vector3(0, 120, 0)))
	skeleton.reset_bone_poses()
	player.third_person_model.add_child(skeleton)
	player._create_third_person_item_slots()
	player._update_backpack_socket()
	var socket: Node3D = player.third_person_back_item_root
	var rest_bone := skeleton.global_transform * skeleton.get_bone_global_pose(1)
	var attachment := rest_bone.affine_inverse() * socket.global_transform
	var shoulder := Node3D.new()
	shoulder.position = Vector3(-0.2, 0.03, -0.25)
	socket.add_child(shoulder)
	var shoulder_local := shoulder.transform
	var poses := [Vector3(0, 0.9, 0), Vector3(PI * 0.5, 0, 0), Vector3(0, 0, 0.8), Vector3.ZERO]
	for puppet in [false, true]:
		player.is_puppet = puppet
		for i in range(poses.size()):
			player.is_sleeping = i == 1
			player.is_crouching = i == 2
			player.third_person_action_timer = 1.0 if i == 0 else 0.0
			player.rotation.y = float(i) * 0.7
			player.position = Vector3(18, 3, -24)
			skeleton.set_bone_pose_rotation(1, (Basis.from_euler(poses[i]) * skeleton.get_bone_rest(1).basis).get_rotation_quaternion())
			player._update_backpack_socket()
			var bone := skeleton.global_transform * skeleton.get_bone_global_pose(1)
			var expected := bone * attachment
			if not socket.global_transform.is_equal_approx(expected):
				player.free()
				fail("Backpack loses spine-relative position/orientation in pose %d (puppet=%s)" % [i, puppet])
				return false
			if not shoulder.transform.is_equal_approx(shoulder_local):
				player.free()
				fail("Backpack tracking changes the shoulder's local placement")
				return false
	player.free()
	print("PASS: backpack follows spine rotation and offset when turning, sleeping and crouching, locally and on puppets")
	return true

func check_animated_backpack(player: TestPlayer) -> bool:
	player.third_person_back_item_root.free()
	player._stored_back_visuals = [null, null]
	player._stored_back_items = [{"name": "Caña de pescar", "type": "tool_fishing"}, null]
	player.puppet_model_path = GameConst.PLAYER_MODEL
	player.load_animations = true
	player.setup_as_puppet()
	player.puppet_apply_visuals("Camiseta,Pantalones,Zapatillas", "", "Mochila pequena")
	player._build_stored_back_visual(0)
	var skeleton: Skeleton3D = player._spine_skeleton
	var animation: AnimationPlayer = player.third_person_animation_player
	if skeleton == null or animation == null:
		fail("Missing real skeleton or animation player")
		return false
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton.reset_bone_poses()
	player._update_backpack_socket()
	var bone: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(player._spine_bone_idx)
	var attachment: Transform3D = bone.affine_inverse() * player.third_person_back_item_root.global_transform
	var backpack: Node3D = player.third_person_back_item_root.get_node("BackpackAsset")
	var backpack_local := backpack.transform
	var rod: Node3D = player._stored_back_visuals[0]
	var rod_local := rod.transform
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(3, 2.6, 5)
	camera.look_at(Vector3(0, 1.8, 0))
	camera.fov = 45
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.19, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.5
	root.add_child(light)
	var poses := {"idle": player.third_person_idle_animation, "turn": player.third_person_left_turn_animation, "sleep": player.third_person_sleep_animation}
	for pose in poses:
		var name: String = poses[pose]
		if name.is_empty() or not animation.has_animation(name):
			fail("Missing animation: " + pose)
			return false
		player.is_sleeping = pose == "sleep"
		animation.play(name)
		animation.advance(0.0)
		for fraction in [0.1, 0.5, 0.9]:
			animation.seek(animation.current_animation_length * fraction, true)
			await process_frame
			await process_frame
			bone = skeleton.global_transform * skeleton.get_bone_global_pose(player._spine_bone_idx)
			if not player.third_person_back_item_root.global_transform.is_equal_approx(bone * attachment):
				fail("Backpack drift after skeleton update in %s at %.1f" % [pose, fraction])
				return false
			if not backpack.transform.is_equal_approx(backpack_local) or not rod.transform.is_equal_approx(rod_local):
				fail("Backpack or shoulder geometry changed relative to its socket")
				return false
		if "--preview" in OS.get_cmdline_user_args():
			var box := AABB(skeleton.global_transform * skeleton.get_bone_global_pose(0).origin, Vector3.ZERO)
			for i in range(skeleton.get_bone_count()):
				box = box.expand(skeleton.global_transform * skeleton.get_bone_global_pose(i).origin)
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.25 + 0.4
			camera.position = box.get_center() + Vector3(3, 2.5, 5)
			camera.look_at(box.get_center())
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "/tmp/backpack_%s_preview.png" % pose
			root.get_texture().get_image().save_png(path)
			print("Preview: " + path)
	light.free()
	environment.free()
	camera.free()
	return true

func fail(message: String) -> void:
	push_error(message)
	quit(1)
