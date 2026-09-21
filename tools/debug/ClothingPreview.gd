extends SceneTree

class PreviewPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _sync_held_item() -> void:
		pass
	func _load_torch_animations() -> void:
		pass
	func _preload_rod_pose() -> void:
		pass
	func _load_rod_animations() -> void:
		pass

func diagnostic_material(material: StandardMaterial3D) -> StandardMaterial3D:
	var result := material.duplicate() as StandardMaterial3D
	var args := OS.get_cmdline_user_args()
	result.ao_enabled = result.ao_enabled and not "--no-ao" in args
	result.heightmap_enabled = result.heightmap_enabled and not "--no-height" in args
	result.normal_enabled = result.normal_enabled and not "--no-normal" in args
	if "--flat" in args:
		result.albedo_texture = null
		result.normal_enabled = false
		result.heightmap_enabled = false
		result.ao_enabled = false
	return result

# Isolated material check and preview; never loads or saves a player game.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var factory = load("res://scripts/MaterialFactory.gd")
	for kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots", "jersey", "denim", "leather"]:
		var mat = factory.make_clothing_material(kind, Color(0.3, 0.4, 0.5))
		if mat.albedo_texture == null or mat.normal_texture == null or mat.roughness_texture == null:
			push_error("Missing clothing maps: " + kind)
			quit(1)
			return
	if not "--preview" in OS.get_cmdline_user_args():
		print("PASS: all nine clothing materials have color, normal and roughness maps")
		quit()
		return
	root.size = Vector2i(1000, 1000)
	var gallery := "--gallery" in OS.get_cmdline_user_args()
	if gallery:
		root.size = Vector2i(1440, 960)
	var scene := Node3D.new()
	root.add_child(scene)
	var live := "--live" in OS.get_cmdline_user_args()
	var model = load("res://assets/characters/adapted/player_with_clothes.glb").instantiate()
	scene.add_child(model)
	if live:
		var player := PreviewPlayer.new()
		scene.add_child(player)
		model.reparent(player)
		player.third_person_model = model
		player.is_clothing_model = true
		player._hide_third_person_export_helpers(model)
		player.inventory = player.InventoryScript.new()
		player.add_child(player.inventory)
		player._init_survival_clothing(model)
		player._apply_character_colors()
		player.equip_clothing("Camiseta", Color(0.3, 0.4, 0.6))
		player.equip_clothing("Pantalones", Color(0.15, 0.12, 0.1))
		player.equip_clothing("Zapatillas", Color(0.6, 0.5, 0.2))
		player._setup_third_person_animation(model)
		var animation := player.third_person_walk_animation if "--walk" in OS.get_cmdline_user_args() else player.third_person_idle_animation
		player.third_person_animation_player.play(animation)
		var seek_time := 0.4
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--seek="):
				seek_time = float(argument.trim_prefix("--seek="))
		player.third_person_animation_player.seek(seek_time, true)
		player.third_person_animation_player.pause()
	else:
		for node in model.find_children("*", "Node3D", true, false):
			node.show()
	var bounds := AABB()
	var first := true
	var gallery_kinds := {"Tops": "top", "Bottoms": "bottom", "Shoes": "shoes", "soldier_legs": "soldier", "soldier_torso": "soldier", "cloth_hands": "gloves", "cloth_feet": "boots"}
	var gallery_index := 0
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if live:
			if child.material_override is StandardMaterial3D and child.name in ["Tops", "Bottoms", "Shoes"]:
				child.material_override = diagnostic_material(child.material_override)
			if "--garments-only" in OS.get_cmdline_user_args() and child.name not in ["Tops", "Bottoms", "Shoes"]:
				child.hide()
			if child.visible:
				print("VISIBLE ", child.name)
			continue
		if gallery:
			if not gallery_kinds.has(str(child.name)):
				child.hide()
				continue
			var garment_kind: String = gallery_kinds[str(child.name)]
			var garment_color: Color = {"top": Color(0.28, 0.4, 0.52), "bottom": Color(0.28, 0.30, 0.33), "soldier": Color(0.32, 0.36, 0.23), "shoes": Color(0.65, 0.61, 0.53), "boots": Color(0.19, 0.16, 0.13), "gloves": Color(0.36, 0.29, 0.20)}[garment_kind]
			child.reparent(scene, false)
			child.skeleton = NodePath()
			child.skin = null
			child.transform = Transform3D.IDENTITY
			child.material_override = factory.make_clothing_material(garment_kind, garment_color)
			if "--no-ao" in OS.get_cmdline_user_args():
				child.material_override.ao_enabled = false
			if "--no-height" in OS.get_cmdline_user_args():
				child.material_override.heightmap_enabled = false
			if garment_kind == "gloves":
				# Inspect one glove close up instead of the empty span of the T-pose.
				var source_mesh: Mesh = child.mesh
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for slot in range(source_mesh.get_surface_count()):
					var arrays := source_mesh.surface_get_arrays(slot)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for triangle in range(0, indices.size(), 3):
						if vertices[indices[triangle]].x <= 0:
							continue
						for corner in range(3):
							var v := indices[triangle + corner]
							surface.set_normal(normals[v])
							surface.set_uv(uvs[v])
							surface.add_vertex(vertices[v])
				surface.generate_tangents()
				child.mesh = surface.commit()
			var box: AABB = child.get_aabb()
			var garment_scale := 1.8 / maxf(box.size.x, box.size.y)
			child.scale = Vector3.ONE * garment_scale
			child.rotation_degrees.y = -18
			var cell := Vector3((gallery_index % 4 - 1.5) * 2.4, 1.25 if gallery_index < 4 else -1.25, 0)
			child.position = cell - child.basis * box.get_center()
			var label := Label3D.new()
			label.text = {"Tops": "CAMISETA", "Bottoms": "PANTALÓN", "Shoes": "ZAPATILLAS", "soldier_legs": "MILITAR", "soldier_torso": "CHAQUETA", "cloth_hands": "GUANTES", "cloth_feet": "BOTAS"}[str(child.name)]
			label.font_size = 36
			label.pixel_size = 0.007
			label.position = cell + Vector3(0, -1.12, 0.2)
			scene.add_child(label)
			gallery_index += 1
			continue
		var kind: String = {"Tops": "top", "Bottoms": "bottom", "Shoes": "shoes"}.get(str(child.name), "")
		if str(child.name) in ["Cube", "Body_feet"] or str(child.name).begins_with("cloth_") or str(child.name).begins_with("soldier_") or str(child.name).begins_with("Desnudo_"):
			child.hide()
			continue
		if not kind.is_empty():
			var color := Color(0.28, 0.40, 0.52) if kind == "top" else Color(0.23, 0.25, 0.28)
			if kind == "shoes":
				color = Color(0.65, 0.61, 0.53)
			child.material_override = factory.make_clothing_material(kind, color)
		# Show garment meshes in their common bind space for material inspection.
		child.reparent(scene, false)
		child.skeleton = NodePath()
		child.skin = null
		child.transform = Transform3D.IDENTITY
		var box: AABB = child.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var height: float = bounds.size.y
	if live:
		center = Vector3(0, 1.9, 0)
		height = 3.9
	if gallery:
		center = Vector3.ZERO
		height = 5.2
	print("BOUNDS ", bounds)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = center + Vector3(height * 0.65, height * 0.12, height * 1.65)
	camera.look_at(center)
	camera.fov = 38
	camera.far = height * 10
	if live:
		camera.position = center + Vector3(0, height * 0.04, height * 1.6)
		camera.look_at(center)
		camera.fov = 42
	if gallery:
		camera.position = Vector3(0, 0.1, 12)
		camera.look_at(Vector3.ZERO)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 9.6
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.6
	if "--noon" in OS.get_cmdline_user_args():
		# Sun high and slightly behind the camera: the head casts a shadow right
		# onto the belly, arms onto the thighs — like the in-game screenshot.
		light.rotation_degrees = Vector3(-70, 0, 0)
		light.shadow_enabled = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.14, 0.16, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.86, 1.0)
	environment.environment.ambient_light_energy = 0.5
	scene.add_child(environment)
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "/tmp/lastday_equipment_gallery.png" if gallery else "/tmp/lastday_clothing_preview.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("Preview saved: ", output)
	quit()
