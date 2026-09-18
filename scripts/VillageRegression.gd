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

func count_named(world: Node, needle: String) -> int:
	var n := 0
	for child in world.get_children():
		if child.name.contains(needle):
			n += 1
	return n

func first_named(world: Node, needle: String) -> Node:
	for child in world.get_children():
		if child.name.contains(needle):
			return child
	return null

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	world._world_rng.seed = world.WORLD_SEED
	var grass_before := 0
	for t in world.grass_batch_transforms:
		grass_before += (t as Array).size()
	world._create_house(Vector3(0, 0, 0), "TestHouse", "test_house", 8.0, 9.0, 4.35)
	var grass_queued := 0
	for t in world.grass_batch_transforms:
		grass_queued += (t as Array).size()
	await world._flush_grass_batches()
	# Weathered plaster walls
	var wall := world.get_node_or_null("TestHouse Back S0")
	check(wall != null, "Wall segments generated")
	if wall != null:
		var wall_mesh: MeshInstance3D = null
		var wall_col := false
		for c in wall.get_children():
			if c is MeshInstance3D:
				wall_mesh = c
			if c is CollisionShape3D:
				wall_col = true
		check(wall_col, "Wall collision preserved")
		check(wall_mesh != null and wall_mesh.material_override is StandardMaterial3D, "Walls have a material")
		if wall_mesh != null and wall_mesh.material_override is StandardMaterial3D:
			var mat := wall_mesh.material_override as StandardMaterial3D
			check(mat.albedo_texture != null and mat.albedo_texture.resource_path == world.TEX_PLASTER_AGED, "Walls use aged plaster texture")
	# Overgrowth decals
	var ivy_count := count_named(world, "TestHouse Ivy")
	var drape_count := count_named(world, "TestHouse Drape")
	var grime_count := count_named(world, "TestHouse Grime")
	var moss_count := count_named(world, "TestHouse Moss") + count_named(world, "TestHouse RidgeMoss")
	check(ivy_count >= 4, "Climbing ivy sheets on walls")
	check(drape_count >= 2, "Hanging ivy drapes under eaves")
	check(grime_count >= 4, "Damp grime strips at wall bases")
	check(moss_count >= 4, "Moss patches on the roof")
	var ivy := first_named(world, "TestHouse Ivy") as MeshInstance3D
	if ivy != null:
		var mat := ivy.material_override as StandardMaterial3D
		check(mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "Ivy uses alpha-scissor material")
		check(mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path == world.TEX_IVY_SHEET, "Ivy uses the Blender ivy texture")
		check(mat != null and mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Ivy renders double-sided")
	var grime := first_named(world, "TestHouse Grime") as MeshInstance3D
	if grime != null:
		var gmat := grime.material_override as StandardMaterial3D
		check(gmat != null and gmat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Grime blends smoothly onto plaster")
	# Doorway stays clear: no decal crosses |x| < 0.85 on the front face (+z)
	var door_clear := true
	for child in world.get_children():
		if child is MeshInstance3D and (child.name.contains(" Ivy") or child.name.contains(" Grime") or child.name.contains(" Drape")):
			var mi := child as MeshInstance3D
			if mi.position.z > 0.0 and mi.position.z > absf(mi.position.x):
				var mesh := mi.mesh as PlaneMesh
				var w := mesh.size.x if mesh != null else 0.0
				if absf(mi.position.x) - w * 0.5 < 0.85:
					door_clear = false
	check(door_clear, "Vegetation decals keep the doorway clear")
	# Dense weeds around the foundations actually got queued
	check(grass_queued - grass_before >= 120, "Wall-hugging weeds queued around the house")
	if OS.get_cmdline_user_args().has("--preview"):
		await preview(world)
	print("VILLAGE_ERRORS=", errors)
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
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60, 60)
	ground.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.24, 0.30, 0.14)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	world.add_child(ground)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(11, 4.6, 13)
	camera.look_at(Vector3(0, 2.2, 0))
	camera.fov = 62
	camera.current = true
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/lastday_village_preview.png"
	check(root.get_texture().get_image().save_png(path) == OK, "Village preview saved: " + path)
	print("VILLAGE_DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("VILLAGE_PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
