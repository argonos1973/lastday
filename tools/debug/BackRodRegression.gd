extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _setup_third_person_animation(_character: Node3D) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
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
	if "--preview" in OS.get_cmdline_user_args():
		await preview(player)
	player.free()
	quit()

func preview(player: TestPlayer) -> void:
	player.third_person_back_item_root.free()
	player._stored_back_visuals = [null, null]
	player._stored_back_items = [{"name": "Caña de pescar", "type": "tool_fishing"}, null]
	player.puppet_model_path = player.ADAPTED_PLAYER_MODEL
	player.setup_as_puppet()
	for mesh_name in ["Tops", "Bottoms", "Shoes", "Body_torso", "Body_legs", "Desnudo_arms", "Desnudo_hands"]:
		var mesh = player._find_mesh_in_third_person(mesh_name)
		if mesh != null:
			mesh.show()
	player._build_stored_back_visual(0)
	player._update_backpack_socket()
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
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/back_rod_preview.png")

func fail(message: String) -> void:
	push_error(message)
	quit(1)
