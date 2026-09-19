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
			check(mat.albedo_texture != null and "/village_" in mat.albedo_texture.resource_path, "Walls use Blender-baked moss-free masonry")
			check(mat.normal_enabled and mat.normal_texture != null and mat.roughness_texture != null, "Walls use Blender normal and roughness maps")
	# Overgrowth decals
	var ivy_count := count_named(world, "TestHouse Ivy")
	var drape_count := count_named(world, "TestHouse Drape")
	var grime_count := count_named(world, "TestHouse Grime")
	var moss_count := count_named(world, "TestHouse Moss") + count_named(world, "TestHouse RidgeMoss")
	check(ivy_count >= 4, "Climbing ivy sheets on walls")
	check(drape_count >= 2, "Hanging ivy drapes under eaves")
	check(grime_count >= 4, "Damp grime strips at wall bases")
	check(moss_count == 0, "No moss above the house base or on the roof")
	check(count_named(world, "TestHouse BaseMoss") >= 4, "Moss is a separate layer at the base")
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
	check_overgrowth_geometry(world, Vector3.ZERO, "TestHouse", 8.0, 9.0, 4.35)
	check_roof_geometry(world.get_node("TestHouse Roof"))
	check_window_clearance(world, "TestHouse")
	# Dense weeds around the foundations actually got queued
	check(grass_queued - grass_before >= 120, "Wall-hugging weeds queued around the house")
	if OS.get_cmdline_user_args().has("--preview"):
		await preview(world)
	world.queue_free()
	await process_frame
	var sizes := [Vector3(7.5, 3.6, 6.5), Vector3(14.0, 4.9, 11.0), Vector3(8.0, 4.35, 9.0)]
	for seed_value in range(12):
		var sample := TestWorld.new()
		root.add_child(sample)
		sample._world_rng.seed = seed_value
		var size: Vector3 = sizes[seed_value % sizes.size()]
		var origin := Vector3(-25.0, 1.7, 18.0)
		var label := "Variant%d" % seed_value
		var front_width := size.x * 0.5 - 0.4 - minf(2.0, size.x * 0.16)
		var window_w := minf(1.5, front_width * 0.72)
		var window_x := size.x * 0.5 - front_width * 0.5
		sample._create_house_windows(origin, label, size.x * 0.5, size.z * 0.5, window_x, size.y, window_w, window_w * 1.3)
		sample._create_house_ivy(origin, label, size.x * 0.5, size.z * 0.5, size.y, 0.35)
		check_overgrowth_geometry(sample, origin, label, size.x, size.z, size.y)
		check_window_clearance(sample, label)
		sample.queue_free()
		await process_frame
	await check_house_variety()
	print("VILLAGE_ERRORS=", errors)
	quit(1 if errors > 0 else 0)

func check_overgrowth_geometry(world: Node3D, origin: Vector3, label: String, width: float, depth: float, height: float) -> void:
	var walls_vertical := true
	var doorway_clear := true
	var wall_bounded := true
	var wall_count := 0
	var moss_count := 0
	var moss_low := true
	for child in world.get_children():
		if not child is MeshInstance3D or not str(child.name).begins_with(label + " "):
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is PlaneMesh:
			continue
		var plane := mi.mesh as PlaneMesh
		var arrays := plane.get_mesh_arrays()
		var normal: Vector3 = mi.basis * arrays[Mesh.ARRAY_NORMAL][0]
		if " Ivy" in str(mi.name) or " Grime" in str(mi.name) or " Drape" in str(mi.name) or " BaseMoss" in str(mi.name):
			wall_count += 1
			walls_vertical = walls_vertical and absf(normal.normalized().y) < 0.001
			var center := mi.position - origin
			var front := center.z > depth * 0.5 and absf(normal.z) > 0.9
			if front:
				doorway_clear = doorway_clear and absf(center.x) - plane.size.x * 0.5 >= 0.9
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mi.transform * vertex - origin
				var along_wall := p.x if absf(normal.z) > 0.9 else p.z
				var extent := width * 0.5 if absf(normal.z) > 0.9 else depth * 0.5
				wall_bounded = wall_bounded and absf(along_wall) <= extent + 0.201
		if "Moss" in str(mi.name) or " Grime" in str(mi.name):
			moss_count += 1
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mi.transform * vertex - origin
				moss_low = moss_low and p.y <= minf(0.85, height * 0.24) + 0.001 and p.y >= -0.051
	check(wall_count > 0 and walls_vertical, label + ": wall vegetation is vertical, not a floating shelf")
	check(doorway_clear, label + ": vegetation leaves the full doorway clear")
	check(wall_bounded, label + ": wall vegetation stays within the facade")
	check(moss_count > 0 and moss_low, label + ": all moss and damp remain below 0.85 metres")

func check_roof_geometry(roof: MeshInstance3D) -> void:
	var center := roof.mesh.get_aabb().get_center()
	center.y = roof.mesh.get_aabb().position.y + roof.mesh.get_aabb().size.y / 3.0
	var outward := true
	var flat_normals := true
	var materials_correct := true
	var edges := {}
	var gables := 0
	var slopes := 0
	for s in range(roof.mesh.get_surface_count()):
		var arrays := roof.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var mat := roof.mesh.surface_get_material(s) as StandardMaterial3D
		for t in range(0, count, 3):
			var ids := [indices[t], indices[t+1], indices[t+2]] if not indices.is_empty() else [t, t+1, t+2]
			var a := vertices[ids[0]]
			var b := vertices[ids[1]]
			var c := vertices[ids[2]]
			var normal := (c-a).cross(b-a).normalized()
			outward = outward and normal.dot((a+b+c)/3.0-center) > 0.001
			for i in ids:
				flat_normals = flat_normals and normals[i].dot(normal) > 0.999
			var is_tile := mat != null and mat.albedo_texture != null and ("_slate_" in mat.albedo_texture.resource_path or "_clay_" in mat.albedo_texture.resource_path)
			if absf(normal.z) > 0.99:
				gables += 1
				materials_correct = materials_correct and not is_tile
			elif normal.y > 0.01:
				slopes += 1
				materials_correct = materials_correct and is_tile
			for pair in [[a,b], [b,c], [c,a]]:
				var points := [str(pair[0]), str(pair[1])]
				points.sort()
				var key: String = points[0] + "|" + points[1]
				edges[key] = int(edges.get(key, 0)) + 1
	check(outward, str(roof.name) + ": clockwise faces point outward, including both gables")
	check(flat_normals, str(roof.name) + ": normals are flat and match the triangle winding")
	check(edges.size() > 0 and edges.values().all(func(n): return n == 2), str(roof.name) + ": mesh is closed without missing faces")
	check(gables == 2 and slopes == 4 and materials_correct, str(roof.name) + ": gables use wall finish and slopes use roof tiles")

func check_window_clearance(world: Node3D, label: String) -> void:
	var windows: Array[AABB] = []
	for child in world.get_children():
		if child is MeshInstance3D and str(child.name).begins_with(label + " ") and "Window" in str(child.name) and str(child.name).ends_with(" Glass"):
			windows.append((child.transform * child.get_aabb()).grow(0.12))
	var clear := true
	var ivy_count := 0
	for child in world.get_children():
		if child is MeshInstance3D and str(child.name).begins_with(label + " ") and (" Ivy" in str(child.name) or " Drape" in str(child.name)):
			ivy_count += 1
			var bounds: AABB = child.transform * child.get_aabb()
			for window in windows:
				clear = clear and not bounds.grow(0.001).intersects(window)
	check(windows.size() == 6 and ivy_count > 0 and clear, label + ": ivy redistributes around all six windows with clearance")

func check_house_variety() -> void:
	var finishes := {}
	var roof_heights := {}
	var silhouettes := {}
	var sizes := [Vector3(11.4,4.35,9.4),Vector3(14.0,4.9,11.0),Vector3(9.0,3.9,7.5),Vector3(12.5,4.5,10.0),Vector3(8.0,3.7,7.0),Vector3(10.5,4.1,8.5),Vector3(13.0,4.7,10.0),Vector3(9.5,3.9,8.0),Vector3(11.0,4.3,9.0),Vector3(7.5,3.6,6.5)]
	for i in range(10):
		var sample := TestWorld.new()
		root.add_child(sample)
		sample._world_rng.seed = 150 + i
		var label := "Casa abandonada %d" % (i + 1)
		var size: Vector3 = sizes[i]
		sample._create_house(Vector3.ZERO, label, "house_%d" % (i + 1), size.x, size.z, size.y)
		var wall := sample.get_node(label + " Back S0")
		for child in wall.get_children():
			if child is MeshInstance3D:
				var mat := child.material_override as StandardMaterial3D
				finishes[str(mat.albedo_texture.resource_path) + str(mat.albedo_color)] = true
		var roof := sample.get_node(label + " Roof") as MeshInstance3D
		roof_heights[snappedf(roof.mesh.get_aabb().size.y, 0.01)] = true
		var architecture := sample.get_node(label + " Architecture")
		var signature := ""
		for child in architecture.get_children():
			if child is MultiMeshInstance3D:
				signature += str(child.name) + str(child.multimesh.instance_count)
		silhouettes[signature] = true
		check(sample.get_node_or_null(label + " Door") != null, label + ": interactive door retained")
		check_overgrowth_geometry(sample, Vector3.ZERO, label, size.x, size.z, size.y)
		check_window_clearance(sample, label)
		check_roof_geometry(roof)
		var porch_roof := sample.get_node_or_null(label + " PorchRoof") as MeshInstance3D
		if porch_roof != null:
			check_roof_geometry(porch_roof)
		if OS.get_cmdline_user_args().has("--gallery"):
			await sample._flush_grass_batches()
			await preview(sample, "/tmp/lastday_house_%02d.png" % (i + 1))
		sample.queue_free()
		await process_frame
	var finish_keys := finishes.keys()
	check(finish_keys.size() == 1 and "village_lime" in str(finish_keys[0]), "All ten houses share the reference lime plaster finish")
	check(roof_heights.size() >= 6, "Roof silhouettes vary, not only wall colors")
	check(silhouettes.size() >= 6, "Porches, shutters and architectural details vary")

func preview(world: Node3D, path: String = "/tmp/lastday_village_preview.png") -> void:
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
	var distance := 13.0
	for child in world.get_children():
		if child is MeshInstance3D and str(child.name).ends_with(" Roof"):
			distance = maxf(distance, child.get_aabb().size.x * 1.2)
	camera.position = Vector3(distance * 0.85, 4.6, distance)
	camera.look_at(Vector3(0, 2.6, 0))
	camera.fov = 62
	camera.current = true
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Village preview saved: " + path)
	if OS.get_cmdline_user_args().has("--views"):
		var views := [Vector3(0, 1.8, distance * 1.35), Vector3(distance * 1.35, 2.2, 0), Vector3(0, 1.8, -distance * 1.35), Vector3(-distance * 1.35, 2.2, 0)]
		var sheet := Image.create(1600, 900, false, Image.FORMAT_RGB8)
		for i in range(views.size()):
			camera.position = views[i]
			camera.look_at(Vector3(0, 2.8, 0))
			for frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			capture.convert(Image.FORMAT_RGB8)
			capture.resize(800, 450, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(capture, Rect2i(0, 0, 800, 450), Vector2i((i % 2) * 800, (i / 2) * 450))
		check(sheet.save_png(path.get_basename() + "_views.png") == OK, "Four-sided roof/window capture saved")
	print("VILLAGE_DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("VILLAGE_PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
