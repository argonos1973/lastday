extends SceneTree

# Renders the Inicio saved-character preview using the real save file, so the
# start-screen clothing materials can be verified without opening the game.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(700, 1000)
	var sgm = load("res://scripts/SaveGameManager.gd").new()
	sgm.name = "SaveGameManager"
	root.add_child(sgm)
	var gs = load("res://scripts/GameSession.gd").new()
	gs.name = "GameSession"
	root.add_child(gs)
	var scene := Node3D.new()
	root.add_child(scene)
	var model = load("res://assets/characters/adapted/player_with_clothes.glb").instantiate()
	model.rotation_degrees = Vector3.ZERO
	scene.add_child(model)
	var cfg: Dictionary = sgm.get_saved_character_config()
	if cfg.is_empty():
		push_error("No saved character config")
		quit(1)
		return
	var SaveIntegration = load("res://scripts/InicioSaveIntegration.gd")
	SaveIntegration.apply_saved_equipment_preview(model, cfg)
	var dump: Array = [model]
	while not dump.is_empty():
		var n: Node = dump.pop_back()
		if n is MeshInstance3D:
			print("MESH ", n.name, " visible=", n.visible)
		for c in n.get_children():
			dump.append(c)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hide="):
			var target := argument.trim_prefix("--hide=")
			var mstack: Array = [model]
			while not mstack.is_empty():
				var n: Node = mstack.pop_back()
				if n is MeshInstance3D and str(n.name) == target:
					n.visible = false
				for c in n.get_children():
					mstack.append(c)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var keep := argument.trim_prefix("--only=").split(",")
			var stack3: Array = [model]
			while not stack3.is_empty():
				var n3: Node = stack3.pop_back()
				if n3 is MeshInstance3D and not keep.has(str(n3.name)):
					n3.visible = false
				for c3 in n3.get_children():
					stack3.append(c3)
		elif argument == "--flat-shoes":
			var stack2: Array = [model]
			while not stack2.is_empty():
				var n2: Node = stack2.pop_back()
				if n2 is MeshInstance3D and str(n2.name) == "Shoes":
					var fm := StandardMaterial3D.new()
					fm.albedo_color = Color(0.6, 0.5, 0.2)
					n2.material_override = fm
				for c2 in n2.get_children():
					stack2.append(c2)
	var ap: AnimationPlayer = null
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			ap = n
			break
		for c in n.get_children():
			stack.append(c)
	if ap != null:
		var chosen := ""
		for a in ap.get_animation_list():
			if a.findn("idle") >= 0:
				chosen = a
				break
		if chosen.is_empty() and ap.get_animation_list().size() > 0:
			chosen = ap.get_animation_list()[0]
		if not chosen.is_empty():
			ap.play(chosen)
			ap.seek(0.5, true)
			ap.pause()
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 1.0, 5.2)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 34
	for argument in OS.get_cmdline_user_args():
		if argument == "--waist":
			camera.position = Vector3(0.3, 1.75, 1.5)
			camera.look_at(Vector3(0.1, 1.55, 0))
			camera.fov = 28
		elif argument == "--feet":
			camera.position = Vector3(0.5, 0.25, 1.1)
			camera.look_at(Vector3(0, 0.1, 0))
			camera.fov = 45
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-50, -20, 0)
	light.light_energy = 1.6
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.14, 0.16, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.86, 1.0)
	env.environment.ambient_light_energy = 0.5
	scene.add_child(env)
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "/tmp/lastday_save_preview.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("Preview saved: ", output)
	quit()
