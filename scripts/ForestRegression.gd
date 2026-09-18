extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

class TestWorld extends MainScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void:
		pass

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		errors += 1

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	world._world_rng.seed = world.WORLD_SEED
	world._create_leafy_floor_ground()
	var ground := world.get_node("TerrainSurface") as MeshInstance3D
	check(ground.material_override is ShaderMaterial, "Ground uses blended forest material")
	check(world.get_node_or_null("TerrainSurfaceDirt") == null, "No overlapping transparent ground layer")
	world._ensure_grass_batches()
	for mesh in world.grass_batch_meshes:
		var arrays: Array = mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_TEX_UV] != null, "Grass has normals and blade UVs")
	world._load_forest_tree_pack()
	check(not world._forest_tree_meshes.is_empty(), "Forest tree pack loads")
	var batches: Array = []
	for i in range(world._forest_tree_meshes.size()):
		batches.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	for x in range(8):
		for z in range(8):
			var pos := Vector3(156 + x * 8 + rng.randf_range(-2.5, 2.5), 0, 145 + z * 8 + rng.randf_range(-2.5, 2.5))
			var variant := world._pick_forest_tree_variant(rng)
			var basis := Basis.from_euler(Vector3(-PI * 0.5, 0, rng.randf_range(0, TAU))).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4))
			batches[variant].append(Transform3D(basis, pos))
	for x in [-400.0, 400.0]:
		batches[0].append(Transform3D(Basis.IDENTITY, Vector3(x, 0, -400)))
	world._flush_forest_multimeshes(batches)
	var max_radius := 0.0
	for radius in world._forest_multimesh_radii:
		max_radius = maxf(max_radius, radius)
	check(max_radius < 50.0, "Tree batches are spatially bounded")
	check(world._forest_multimesh_nodes[0].cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Trees cast canopy shadows")
	# MultiMesh transform buffers live in the rendering server; the headless
	# dummy renderer returns empty transforms, so hide/show can only be
	# asserted with a real renderer.
	var tree_pos: Vector3 = batches[0][0].origin
	world._hide_multimesh_tree_at(tree_pos)
	if DisplayServer.get_name() != "headless":
		check(world._hidden_tree_transforms.has(tree_pos), "Interactive tree hides batched visual")
	world._show_multimesh_tree_at(tree_pos)
	check(not world._hidden_tree_transforms.has(tree_pos), "Batched tree is restored after interaction")
	for i in range(1900):
		var pos := Vector3(rng.randf_range(150, 221), 0.008, rng.randf_range(140, 217))
		world._queue_grass_instance(pos, rng.randf_range(0.16, 0.52), rng.randf_range(0.22, 0.46), Color(0.23, 0.32, 0.10).lerp(Color(0.39, 0.40, 0.18), rng.randf()))
	await world._flush_grass_batches()
	max_radius = 0.0
	for radius in world._grass_batch_radii:
		max_radius = maxf(max_radius, radius)
	check(max_radius < 35.0, "Grass batches are spatially bounded")
	for i in range(12):
		var pos := Vector3(rng.randf_range(163, 210), 0.3, rng.randf_range(163, 203))
		world._create_textured_visual_sphere("ForestTestRock%d" % i, pos, Vector3(0.8, 0.55, 0.7) * rng.randf_range(0.5, 1.8), world.POLY_ROCK_07_DIFF, Color(0.3, 0.28, 0.24))
	var rock := world.get_node("ForestTestRock0") as MeshInstance3D
	check(rock.mesh is ArrayMesh, "Rocks use irregular shared geometry")
	var rock2 := world.get_node("ForestTestRock1") as MeshInstance3D
	check(rock.material_override == rock2.material_override, "Rock materials shared rather than allocated per object")
	if OS.get_cmdline_user_args().has("--preview"):
		await preview(world)
	print("FOREST_ERRORS=", errors)
	world.queue_free()
	await process_frame
	quit(1 if errors > 0 else 0)

func preview(world: Node3D) -> void:
	root.size = Vector2i(1280, 800)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.71, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.73, 0.84)
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color(1.0, 0.91, 0.76)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(198, 1.8, 214)
	camera.look_at(Vector3(180, 3.4, 177))
	camera.fov = 72
	camera.current = true
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/lastday_forest_before.png" if OS.get_cmdline_user_args().has("--before") else "/tmp/lastday_forest_preview.png"
	check(root.get_texture().get_image().save_png(path) == OK, "Forest preview saved: " + path)
	print("FOREST_DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("FOREST_PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
