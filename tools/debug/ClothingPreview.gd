extends SceneTree

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
	var scene := Node3D.new()
	root.add_child(scene)
	var model = load("res://assets/characters/adapted/player_with_clothes.glb").instantiate()
	scene.add_child(model)
	for node in model.find_children("*", "Node3D", true, false):
		node.show()
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
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
	print("BOUNDS ", bounds)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = center + Vector3(height * 0.65, height * 0.12, height * 1.65)
	camera.look_at(center)
	camera.fov = 38
	camera.far = height * 10
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.6
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
	root.get_texture().get_image().save_png("/tmp/lastday_clothing_preview.png")
	print("Preview saved: /tmp/lastday_clothing_preview.png")
	quit()
