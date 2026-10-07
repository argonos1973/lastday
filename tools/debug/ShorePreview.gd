extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

class TestWorld extends MainScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void:
		pass

# Renders a small preview of the new shore band + Blender props over a water
# plane, without generating the map. Run WITHOUT --headless:
#   work/godot4.7/Godot.app/Contents/MacOS/Godot --path . --script tools/debug/ShorePreview.gd
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lake_preview := "--lake" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 800)
	var world := Node3D.new()
	get_root().add_child(world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(.19,.36,.57)
	sky_material.sky_horizon_color = Color(.65,.72,.78)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.73, 0.84)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color(1.0, 0.91, 0.76)
	sun.light_energy = 1.15
	sun.shadow_enabled = not "--no-shadows" in OS.get_cmdline_user_args()
	sun.directional_shadow_max_distance = 85
	world.add_child(sun)

	# Two ground slabs flanking the river channel so the real river segment
	# (which owns its water + bottom planes) stays visible between them.
	for gz in ([] if lake_preview or not "--legacy-ground" in OS.get_cmdline_user_args() else [-1.0, 1.0]):
		var ground := MeshInstance3D.new()
		var ground_mesh := PlaneMesh.new()
		ground_mesh.size = Vector2(60, 14)
		ground.mesh = ground_mesh
		ground.position = Vector3(0, 0.003, gz * (2.8 + 7.0))
		var ground_mat := StandardMaterial3D.new()
		ground_mat.albedo_color = Color(0.24, 0.30, 0.14)
		ground_mat.roughness = 0.95
		ground.material_override = ground_mat
		world.add_child(ground)
	if lake_preview and "--legacy-ground" in OS.get_cmdline_user_args():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(160):
			var a := float(i) * TAU / 160.0
			var b := float(i + 1) * TAU / 160.0
			var p := Vector3(cos(a)*64.5,0,sin(a)*38.7)
			var q := Vector3(cos(b)*64.5,0,sin(b)*38.7)
			for vertex in [p,p*2,q,q,p*2,q*2]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertex)
		var ground := MeshInstance3D.new()
		ground.mesh = surface.commit()
		ground.position = Vector3(250,0,-307)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.24,.30,.14)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ground.material_override = material
		world.add_child(ground)

	var main := TestWorld.new()
	world.add_child(main)
	main._world_rng.seed = 424242
	var seg := {"center": Vector3(0, 0.085, 0), "size": Vector2(26, 5.6), "yaw": 0.0}
	if lake_preview:
		seg.size = Vector2(150,90)
		seg.center = Vector3(250,0.085,-307)
	main.river_segments_data = [seg]
	await main._create_river_segment(seg.center, seg.size, seg.yaw)
	main._create_fish_school(seg.center, seg.size, seg.yaw)
	if lake_preview:
		await main._create_lake_bank_tall_grass(seg.center,seg.size,seg.yaw)
		await main._create_lake_shore_rocks(seg.center,seg.size,seg.yaw)
		main._create_lake_granite_shore(seg.center,seg.size,seg.yaw)
		main._create_lake_rowboat(seg.center,seg.size,seg.yaw)
	main._create_leafy_floor_ground()
	if "--diffuse" in OS.get_cmdline_user_args():
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(.4,.48,.54)
		for water in main.get_children():
			if water is RiverWater:
				water.material_override.set_shader_parameter("mirror_strength",0.0)
	var names := {}
	for c in main.get_children():
		names[str(c.name).split("@")[0].rstrip("0123456789")] = true
	print("SPAWNED_NODES: ", names.keys())
	var prop_counts := {"ShoreBand": 0, "PebblePatch": 0, "FlatStone": 0, "Driftwood": 0, "PebbleClusterStone": 0, "Boulder": 0}
	var stack: Array = main.get_children()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var n := str(node.name)
		for key in prop_counts:
			if n.contains(key):
				prop_counts[key] += 1
	print("PROP_COUNTS: ", prop_counts)
	if lake_preview:
		# Identify each prop by its GLB mesh source: Godot renames duplicate
		# node names to @Node3D@N, so names alone cannot tell instances apart.
		var source_counts := {}
		for c in main.get_children():
			var src := _mesh_source_path(c)
			var key := src.get_file() if not src.is_empty() else str(c.name)
			source_counts[key] = source_counts.get(key, 0) + 1
		print("SOURCE_COUNTS: ", source_counts)

	# Debug isolation: hide prop classes by mesh source path.
	#   --no-slabs --no-boulders --no-outcrops --no-granite
	#   --no-flatstones --no-pebbles --hide-source <substr>
	var uargs := OS.get_cmdline_user_args()
	var hide_terms: Array = []
	for pair in [["--no-slabs", "lake_slab"], ["--no-boulders", "lake_boulder"], ["--no-outcrops", "lake_outcrop"], ["--no-granite", "/lake/"], ["--no-flatstones", "flatstone"], ["--no-pebbles", "pebble"]]:
		if pair[0] in uargs:
			hide_terms.append(pair[1])
	var hi := uargs.find("--hide-source")
	if hi >= 0 and hi + 1 < uargs.size():
		hide_terms.append(uargs[hi + 1])
	var name_hide := ""
	var nh := uargs.find("--hide")
	if nh >= 0 and nh + 1 < uargs.size():
		name_hide = uargs[nh + 1]
	for c in main.get_children():
		var n := str(c.name)
		if "--water-only" in uargs and c is Node3D:
			c.visible = n.begins_with("MountainRiverWater") or n.begins_with("RiverBottom")
			continue
		if not name_hide.is_empty() and n.contains(name_hide):
			c.visible = false
			continue
		if not hide_terms.is_empty():
			var src := _mesh_source_path(c)
			for term in hide_terms:
				if src.contains(term):
					c.visible = false
					break

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-3.4, 1.0, 4.6)
	camera.look_at(Vector3(0.5, -0.1, 2.2))
	if lake_preview:
		camera.position = seg.center + Vector3(-10,2.3,41.5)
		camera.look_at(seg.center + Vector3(4,0,38))
	if "--player-view" in OS.get_cmdline_user_args():
		camera.position = seg.center + Vector3(0,1.7,40.0 if lake_preview else 3.5)
		camera.look_at(seg.center + Vector3(0,-.05,34.5 if lake_preview else .7))
	camera.fov = 50
	camera.current = true
	for i in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var ok := img.save_png("/tmp/lastday_lake_shore_preview.png" if lake_preview else "/tmp/lastday_shore_preview.png")
	print("SHORE_PREVIEW_SAVED " + str(ok))
	if "--motion" in OS.get_cmdline_user_args():
		for frame in range(60):
			await create_timer(.05).timeout
			await RenderingServer.frame_post_draw
			var prefix := "/tmp/lake_motion_" if lake_preview else "/tmp/river_motion_"
			root.get_texture().get_image().save_png(prefix + "%03d.png" % frame)
	quit(0 if ok == OK else 1)

func _mesh_source_path(node: Node) -> String:
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var path := (n as MeshInstance3D).mesh.resource_path
			if not path.is_empty():
				return path
		stack.append_array(n.get_children())
	return ""
