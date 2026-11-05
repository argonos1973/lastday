extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var pine := load("res://assets/models/environment/pines/pine_sapling_medium.glb").instantiate() as Node3D
	scene.add_child(pine)
	for node in pine.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var mat: StandardMaterial3D = node.get_active_material(surface).duplicate()
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = .3
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.metallic = 0.0
			mat.roughness = .9
			node.set_surface_override_material(surface,mat)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.shadow_enabled = true
	scene.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.18,.22,.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .65
	env.environment.ambient_light_color = Color.WHITE
	scene.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.24,.24,.19)
	mat.roughness = 1.0
	ground.material_override = mat
	scene.add_child(ground)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8,5,11)
	camera.look_at(Vector3(0,3.5,0))
	camera.fov = 40
	camera.current = true
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/pine_sapling_preview.png")
	print("PINE_PREVIEW_OK")
	scene.queue_free()
	await process_frame
	quit()
