extends SceneTree

# Preview GPU de la fogata mejorada: hoguera con brasas, nucleo luminoso,
# llamas, chispas y humo sobre un suelo oscuro, de noche.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1100, 800)
	var scene := Node3D.new()
	root.add_child(scene)
	# Suelo oscuro
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.10, 0.09, 0.08)
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	scene.add_child(ground)
	# Un tronco seco al lado para ver la luz calida sobre superficies
	var log := MeshInstance3D.new()
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.12
	log_mesh.bottom_radius = 0.12
	log_mesh.height = 1.6
	log.mesh = log_mesh
	log.rotation_degrees = Vector3(90, 20, 0)
	log.position = Vector3(1.1, 0.12, 0.4)
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.24, 0.16, 0.10)
	log_mat.roughness = 0.95
	log.material_override = log_mat
	scene.add_child(log)
	# La hoguera: modelo 3D realista (troncos con corteza, nudos, carbon, ceniza y piedras) + fuego
	var cf_scene := load("res://assets/models/props/realistic_campfire.glb") as PackedScene
	if cf_scene != null:
		var cf_inst := cf_scene.instantiate() as Node3D
		cf_inst.scale = Vector3(1.15, 1.15, 1.15)
		scene.add_child(cf_inst)
	# Luz + efectos de fuego (igual que _create_campfire_fire: pos + Vector3(0, 0.15, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.15, 0)
	light.light_color = Color(1.0, 0.65, 0.25)
	light.light_energy = 7.0
	light.omni_range = 24.0
	light.omni_attenuation = 0.95
	scene.add_child(light)
	var effects := preload("res://scripts/FireVisuals.gd").new()
	effects.small = false
	light.add_child(effects)
	# Antorcha pequena al lado para comparar small=true
	var torch_light := OmniLight3D.new()
	torch_light.position = Vector3(1.8, 0.8, -0.6)
	torch_light.light_color = Color(1.0, 0.7, 0.3)
	torch_light.light_energy = 2.0
	torch_light.omni_range = 6.0
	scene.add_child(torch_light)
	var torch_fx := preload("res://scripts/FireVisuals.gd").new()
	torch_fx.small = true
	torch_light.add_child(torch_fx)
	var stick2 := MeshInstance3D.new()
	var st2 := CylinderMesh.new()
	st2.top_radius = 0.03
	st2.bottom_radius = 0.04
	st2.height = 0.9
	stick2.mesh = st2
	stick2.material_override = log_mat
	stick2.position = Vector3(1.8, 0.45, -0.6)
	scene.add_child(stick2)
	# Camara cercana para apreciar los troncos con corteza, nudos, carbon, ceniza y piedras
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(1.05, 0.95, 1.85)
	camera.look_at(Vector3(0.0, 0.25, 0.0))
	camera.fov = 42
	# Noche
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.015, 0.02, 0.03)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.12, 0.16, 0.24)
	environment.environment.ambient_light_energy = 0.35
	scene.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 140, 0)
	moon.light_color = Color(0.3, 0.4, 0.6)
	moon.light_energy = 0.15
	scene.add_child(moon)
	for frame in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	var output := "res://build/tmp/campfire_preview.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("Preview saved: ", output)
	quit()
