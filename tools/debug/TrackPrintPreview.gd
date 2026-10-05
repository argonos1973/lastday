extends SceneTree

# Preview de huellas: tres rastros (zarpa lobo, pezuna ciervo, zarpa zorro)
# avanzando hacia +Z con lado alterno. Vista cenital.
# Uso: Godot --path . --script tools/debug/TrackPrintPreview.gd (sin --headless)

const TrackPrintScript = preload("res://scripts/TrackPrint.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.33, 0.25)
	plane.material = gm
	ground.mesh = plane
	scene.add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 20, 0)
	scene.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.55, 0.65)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 0.7
	env.environment = e
	scene.add_child(env)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.4, 0.4)
	cam.rotation_degrees = Vector3(-85, 0, 0)
	scene.add_child(cam)
	cam.current = true

	# Tres rastros paralelos moviendose hacia +Z (abajo en la vista si el
	# eje -Z queda arriba de la camara). yaw = atan2(dir.x, dir.z).
	var kinds := [["paw", 0.6], ["hoof", 0.55], ["paw", 0.45]]
	var xoff := -3.0
	var side := 1.0
	for k in kinds:
		var kind: String = k[0]
		var size: float = k[1] * 0.4
		for i in range(9):
			side = -side
			var dir := Vector3(0, 0, 1)
			var lat := Vector3(-dir.z, 0, dir.x) * side * 0.12
			var pos := Vector3(xoff + lat.x, 0.02, -2.2 + i * 0.55)
			TrackPrintScript.spawn(scene, pos, atan2(dir.x, dir.z), kind, size)
		xoff += 3.0
		side = 1.0

	for i in range(10):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/lastday_tracks_preview.png")
	print("PREVIEW_SAVED")
	quit(0)
