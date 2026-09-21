extends SceneTree

const Jackets = preload("res://scripts/MilitaryJackets.gd")
class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(_character: Node3D) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func deformed_bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var result := AABB()
	var first := true
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in range(vertices.size()):
			var point := Vector3.ZERO
			var sum := 0.0
			for influence in range(4):
				var weight := weights[i*4+influence]
				if weight <= 0: continue
				var bind := bones[i*4+influence]
				var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind))
				if bone < 0: bone = mesh.skin.get_bind_bone(bind)
				point += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[i]) * weight
				sum += weight
			if absf(sum-1.0) > 0.02:
				push_error("Jacket has unnormalized weights")
				quit(1)
				return AABB()
			point = skeleton.global_transform * point
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result

func run() -> void:
	var players: Array = []
	var index := 0
	for item_name in Jackets.VARIANTS:
		var player := TestPlayer.new()
		root.add_child(player)
		player.stats = preload("res://scripts/SurvivalStats.gd").new()
		player.inventory = preload("res://scripts/Inventory.gd").new()
		player.add_child(player.inventory)
		player.puppet_model_path = player.ADAPTED_PLAYER_MODEL
		player.setup_as_puppet()
		player.equip_clothing("Pantalones")
		player.equip_clothing("Zapatillas")
		player.equip_clothing(item_name)
		var key: String = "field_jacket_" + Jackets.VARIANTS[item_name]
		var mesh: MeshInstance3D = player._survival_cloth_nodes.get(key)
		if mesh == null or not mesh.visible or mesh.mesh.get_surface_count() < 3:
			fail("Jacket did not equip: " + item_name)
			return
		var skeleton := Jackets.skeleton_in(player.third_person_model)
		var bounds := deformed_bounds(mesh, skeleton)
		print(item_name, " rest bounds ", bounds)
		if bounds.size.x > 3.0 or bounds.size.x < 1.0 or bounds.size.y > 2.0 or bounds.size.y < 0.5:
			fail("Jacket scale or skin binding is wrong")
			return
		var arm := skeleton.find_bone("mixamorig:LeftArm")
		if arm < 0:
			arm = skeleton.find_bone("mixamorig_LeftArm")
		if arm < 0:
			fail("Missing arm in character fixture")
			return
		var old_rotation := skeleton.get_bone_pose_rotation(arm)
		skeleton.set_bone_pose_rotation(arm, old_rotation * Quaternion(Vector3.FORWARD, 0.8))
		skeleton.force_update_all_bone_transforms()
		var posed := deformed_bounds(mesh, skeleton)
		if posed.is_equal_approx(bounds) or posed.size.length() > 5.0:
			fail("Jacket does not follow the arm")
			return
		skeleton.set_bone_pose_rotation(arm, old_rotation)
		skeleton.force_update_all_bone_transforms()
		player.unequip_clothing(item_name)
		if mesh.visible:
			fail("Jacket remains visible after unequip")
			return
		player.equip_clothing(item_name)
		if player._survival_cloth_nodes[key] != mesh:
			fail("Jacket duplicated on re-equip")
			return
		player.position.x = (index-1)*2.6
		player.rotation_degrees.y = 180
		players.append(player)
		index += 1
	print("PASS: all three jackets equip, deform with the arm, unequip and reuse the same mesh")
	if "--preview" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 2.4, 10)
		camera.look_at(Vector3(0, 1.85, 0))
		camera.fov = 48
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -25, 0)
		light.light_energy = 1.6
		root.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.12, 0.15, 0.18)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.65
		root.add_child(env)
		for frame in range(20): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/military_jackets_preview.png")
	for player in players:
		player.stats.free()
		player.free()
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)
