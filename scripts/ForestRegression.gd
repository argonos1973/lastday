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
	world._world_rng.seed = GameConst.WORLD_SEED
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
		world._create_textured_visual_sphere("ForestTestRock%d" % i, pos, Vector3(0.8, 0.55, 0.7) * rng.randf_range(0.5, 1.8), MaterialFactory.POLY_ROCK_07_DIFF, Color(0.3, 0.28, 0.24))
	var rock := world.get_node("ForestTestRock0") as MeshInstance3D
	check(rock.mesh is ArrayMesh, "Rocks use irregular shared geometry")
	var rock2 := world.get_node("ForestTestRock1") as MeshInstance3D
	check(rock.material_override == rock2.material_override, "Rock materials shared rather than allocated per object")
	check(rock.mesh.get_meta("granite_source", "").begins_with(GameConst.LAKE_DIR), "World rocks reuse the lake granite geometry")
	var world_rock_material := rock.material_override as ShaderMaterial
	var granite_texture := world_rock_material.get_shader_parameter("rock_albedo") as Texture2D
	check(granite_texture != null and granite_texture.resource_path.contains("lake_granite"), "World rocks share the lake granite surface")
	check(world._get_drop_model_paths("Piedra", "resource")[0].begins_with(GameConst.LAKE_DIR), "Collectable stones use the same granite family")
	for path in world.REAL_ROCK_MODELS + world.SHORE_FLATSTONES:
		check(str(path).begins_with(GameConst.LAKE_DIR), "Scattered and shore rock variants use granite")
	var lake_center := Vector3(250, .085, -307)
	var lake_size := Vector2(150, 90)
	world.river_segments_data = [{"center": lake_center, "size": lake_size, "yaw": 0.0}]
	var lake_batches: Array = []
	for entry in world._forest_tree_meshes:
		lake_batches.append([])
	var lake_positions: Array = []
	var rng_state := world._world_rng.state
	var rng_seed := world._world_rng.seed
	world._append_lake_forest(lake_batches, lake_positions)
	check(lake_positions.size() > 100, "Lake forest uses existing tree assets")
	check(world._tree_entries_by_id.size() == lake_positions.size(), "Lake trees registered for chopping and depletion")
	var tree_count := lake_positions.size()
	world._append_lake_forest(lake_batches, lake_positions)
	check(lake_positions.size() == tree_count, "Lake tree batching avoids existing trunks")
	world._create_forest_collision(lake_positions)
	check(not world._forest_collision_grid.is_empty(), "Lake trunks registered for streamed collision")
	world._create_lake_granite_shore(lake_center, lake_size, 0.0)
	check(world._world_rng.state == rng_state and world._world_rng.seed == rng_seed, "Lake decoration preserves gameplay RNG")
	var slab_count := 0
	var boulder_count := 0
	var outcrop_count := 0
	for node in world.get_children():
		slab_count += int(str(node.name).begins_with("LakeGraniteSlab"))
		boulder_count += int(str(node.name).begins_with("LakeGraniteBoulder"))
		outcrop_count += int(str(node.name).begins_with("LakeGraniteOutcrop"))
	check(slab_count >= 10 and slab_count < 30, "Rock shelves form broken groups rather than a solid ring")
	check(boulder_count == 28 and outcrop_count == 2, "Lake granite assets all instantiate")
	await physics_frame
	await physics_frame
	var solid_rocks := 0
	for node in world.get_children():
		if not str(node.name).begins_with("LakeGranite"):
			continue
		var bodies := node.find_children("*", "StaticBody3D", true, false)
		if not bodies.is_empty() and bodies[0].collision_layer & 1:
			solid_rocks += 1
	check(solid_rocks == slab_count + boulder_count + outcrop_count, "Every lake rock has environment collision")
	var first_slab: Node3D
	for node in world.get_children():
		if str(node.name).begins_with("LakeGraniteSlab"):
			first_slab = node
			break
	var slab_meshes: Array = []
	NodeUtils.collect_mesh_instances(first_slab, slab_meshes)
	var slab_mesh := slab_meshes[0] as MeshInstance3D
	var slab_bounds: AABB = slab_mesh.global_transform * slab_mesh.get_aabb()
	var slab_point := slab_bounds.get_center()
	var dry_point := Vector3(180, 0, 180)
	world._queue_grass_instance(slab_point, .6, .2, Color.GREEN)
	world._queue_grass_instance(dry_point, .6, .2, Color.YELLOW)
	world._queue_tall_grass_instance(slab_point, 1.0, Color.GREEN)
	world._queue_tall_grass_instance(dry_point, 1.0, Color.YELLOW)
	check(world.has_method("_clear_lake_granite_grass"), "Lake granite clears intersecting vegetation")
	if world.has_method("_clear_lake_granite_grass"):
		world.call("_clear_lake_granite_grass")
		var grass_counts: Array[int] = []
		var colors_aligned := true
		for pair in [[world.grass_batch_transforms, world.grass_batch_colors], [world._tall_grass_transforms, world._tall_grass_colors]]:
			var count := 0
			for variant in range(pair[0].size()):
				count += pair[0][variant].size()
				colors_aligned = colors_aligned and pair[0][variant].size() == pair[1][variant].size()
				for i in range(pair[0][variant].size()):
					colors_aligned = colors_aligned and pair[0][variant][i].origin.is_equal_approx(dry_point) and pair[1][variant][i].r > .8
			grass_counts.append(count)
		check(grass_counts == [1, 1], "Grass and reeds avoid slabs but remain on dry soil")
		check(colors_aligned, "Vegetation pruning keeps transforms and colors aligned")
	var ray := PhysicsRayQueryParameters3D.create(slab_point + Vector3.UP * 8.0, slab_point - Vector3.UP * 8.0, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and first_slab.is_ancestor_of(hit.get("collider")), "Lake slabs support a real downward physics ray")
	var edge_rock := MeshInstance3D.new()
	var edge_arrays := []
	edge_arrays.resize(Mesh.ARRAY_MAX)
	edge_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(340, .8, 340), Vector3(343, .8, 340), Vector3(340, .8, 343)])
	edge_rock.mesh = ArrayMesh.new()
	edge_rock.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, edge_arrays)
	edge_rock.add_to_group("lake_granite")
	world.add_child(edge_rock)
	var edge_inside := Vector3(340.6, 0, 340.6)
	var edge_outside := Vector3(342.6, 0, 342.6)
	world._queue_grass_instance(edge_inside, .4, .15, Color.GREEN)
	world._queue_grass_instance(edge_outside, .4, .15, Color.GREEN)
	world._clear_lake_granite_grass()
	var kept_outside := false
	var kept_inside := false
	for transforms in world.grass_batch_transforms:
		for transform: Transform3D in transforms:
			kept_outside = kept_outside or transform.origin.is_equal_approx(edge_outside)
			kept_inside = kept_inside or transform.origin.is_equal_approx(edge_inside)
	check(kept_outside and not kept_inside, "Grass follows rock triangles rather than rectangular clearings")
	edge_rock.free()
	var shore_material := slab_mesh.material_override as ShaderMaterial
	check(shore_material != null and shore_material.get_shader_parameter("shore_blend") == true, "Lake granite blends with the forest floor")
	if shore_material != null:
		check(shore_material.get_shader_parameter("shore_normal") is Texture2D and shore_material.get_shader_parameter("shore_roughness") is Texture2D, "Granite imports normal and roughness maps")
		check(shore_material.get_shader_parameter("leaf_albedo") == MaterialFactory.make_forest_ground_material().get_shader_parameter("leaf_albedo"), "Rock feet use the same leaf texture as the terrain")
	check(MaterialFactory.make_forest_rock_material().get_shader_parameter("shore_blend") != true, "Lake material does not alter other forest rocks")
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
