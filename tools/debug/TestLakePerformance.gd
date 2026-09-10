extends "res://scripts/Main.gd"
## Isolated rendering benchmark: no game saves, weather requests or player input.
func _process(_delta: float) -> void:
	# Explicit draw also exercises rendering when the macOS window is occluded.
	RenderingServer.force_draw(false)

func _ready() -> void:
	seed(WORLD_SEED)
	_world_rng.seed = WORLD_SEED
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 12.0
	day_cycle._update_lighting()
	nav = NavPathfindingScript.new()
	world_streaming_mgr = WorldStreamingManager.new()
	add_child(world_streaming_mgr)
	world_streaming_mgr.setup(self)
	sector_persistence_mgr = SectorPersistenceManager.new()
	add_child(sector_persistence_mgr)
	await _create_map()
	player = Node3D.new()
	add_child(player)
	player.position = Vector3(252, 0.4, -254)
	_update_grass_visibility()
	_update_forest_visibility()
	# Isolate rendering from wildlife AI so both stages have identical work.
	for animal in get_tree().get_nodes_in_group("wildlife"):
		animal.set_process(false)
		animal.set_physics_process(false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(252, 3, -248)
	camera.look_at(Vector3(250, 2, -310))
	camera.far = 1800.0
	camera.current = true
	var probes: Array[ReflectionProbe] = []
	for water in get_tree().get_nodes_in_group("river_water"):
		if water.get("_reflection") != null:
			probes.append(water._reflection)
	print("LAKE_BENCH ready, probes=", probes.size())
	for legacy in [true, false]:
		for probe in probes:
			var pose := probe.global_transform
			probe.top_level = not legacy
			probe.global_transform = pose
			probe.cull_mask = (0xFFFFF & ~(1 << 19)) if legacy else (0xFFFFF & ~((1 << 19) | (1 << 18)))
			probe.reflection_mask = 0xFFFFF if legacy else (1 << 19)
			probe.mesh_lod_threshold = 1.0 if legacy else 8.0
		await get_tree().create_timer(5.0).timeout
		var samples: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < 15000000:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			previous = now
		samples.sort()
		var total := 0.0
		var slow := 0
		for sample in samples:
			total += sample
			if sample > 33.33:
				slow += 1
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if draws == 0.0:
			push_warning("No rendered frames: these timings are NOT a GPU/FPS comparison")
		print("LAKE_BENCH ", "moving_probe" if legacy else "fixed_probe", " frames=", samples.size(), " mean_ms=", total / samples.size(), " p95_ms=", samples[int(samples.size() * 0.95)], " max_ms=", samples.back(), " frames_over_33ms=", slow, " draw_calls=", draws)
	# Do not wait forever for a draw if macOS occludes this window.
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot != null:
		screenshot.save_png("res://work/lake_performance/verified.png")
	get_tree().quit()
