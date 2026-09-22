extends SceneTree

class NoSave extends Node:
	func has_save() -> bool:
		return true
	func load_game() -> Dictionary:
		return {}
	func save_game(_player: Dictionary, _world: Dictionary) -> bool:
		return false
	func enable_auto_save() -> void:
		pass

class ProfileNav extends NavPathfinding:
	var profiler: Node
	func _smooth_path(path: Array) -> Array:
		var started := Time.get_ticks_usec()
		var result := super._smooth_path(path)
		profiler.record("path_smoothing", started)
		if profiler.sampling and Time.get_ticks_usec() - started > 8000:
			print("SLOW_SMOOTH ms=", (Time.get_ticks_usec() - started) / 1000.0, " points=", path.size(), " start=", path.front(), " end=", path.back())
		return result
	func _reachable_goal(start: Vector2i, goal: Vector2i) -> Vector2i:
		var started := Time.get_ticks_usec()
		var result := super._reachable_goal(start, goal)
		profiler.record("reachable_goal", started)
		return result

class ProfileAnimal extends WildlifeController:
	func _wolf_ai(delta: float) -> Dictionary:
		var started := Time.get_ticks_usec()
		var result := super._wolf_ai(delta)
		get_parent().record("wolf_ai", started)
		return result
	func _find_nearest_meat_pickup() -> Node3D:
		var started := Time.get_ticks_usec()
		var result := super._find_nearest_meat_pickup()
		get_parent().record("meat_scan", started)
		return result
	func _escape_if_trapped(delta: float) -> bool:
		var started := Time.get_ticks_usec()
		var result := super._escape_if_trapped(delta)
		get_parent().record("wildlife_escape", started)
		return result
	func _move_towards(target: Vector3, speed: float, delta: float, turn_speed: float) -> void:
		var started := Time.get_ticks_usec()
		super._move_towards(target, speed, delta, turn_speed)
		get_parent().record("wildlife_move", started)
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		get_parent().record("wildlife", started)

class ProfilePlayer extends "res://scripts/PlayerController.gd":
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		get_parent().record("player_process", started)
	func _physics_process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._physics_process(delta)
		get_parent().record("player_physics", started)

class ProfileWorld extends "res://scripts/Main.gd":
	signal profile_ready
	var sampling := false
	var frame_costs: Dictionary = {}
	var totals: Dictionary = {}
	var peaks: Dictionary = {}
	func record(label: String, started: int) -> void:
		if not sampling:
			return
		var elapsed := Time.get_ticks_usec() - started
		frame_costs[label] = int(frame_costs.get(label, 0)) + elapsed
		totals[label] = int(totals.get(label, 0)) + elapsed
		peaks[label] = maxi(int(peaks.get(label, 0)), elapsed)
	func _ready() -> void:
		await super._ready()
		profile_ready.emit()
	func _create_map() -> void:
		nav = ProfileNav.new()
		nav.profiler = self
		await super._create_map()
	func _save_world_change_silent() -> void:
		pass
	func _create_player() -> void:
		player = ProfilePlayer.new()
		player.name = "Player"
		player.position = Vector3(9, _get_exact_ground_y(9, 6) + 0.5, 6)
		add_child(player)
		player.stats.died.connect(_on_player_died)
		player.item_dropped.connect(_on_item_dropped)
	func _create_wildlife_animal(kind: String, points: Array) -> void:
		var animal := ProfileAnimal.new()
		animal.name = "Wildlife_%s_%d" % [kind, _animal_id_counter]
		_animal_id_counter += 1
		add_child(animal)
		animal.setup(kind, points)
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		record("main", started)
	func find_path_wildlife(start: Vector3, goal: Vector3) -> Array:
		var started := Time.get_ticks_usec()
		var result := super.find_path_wildlife(start, goal)
		record("navigation", started)
		return result
	func _get_exact_ground_y(x: float, z: float, from_y: float = 500.0) -> float:
		var started := Time.get_ticks_usec()
		var result := super._get_exact_ground_y(x, z, from_y)
		record("ground_raycast", started)
		return result
	func _update_tree_interactions() -> void:
		var started := Time.get_ticks_usec()
		super._update_tree_interactions()
		record("tree_interactions", started)
	func _update_boulder_interactions() -> void:
		var started := Time.get_ticks_usec()
		super._update_boulder_interactions()
		record("boulder_interactions", started)
	func _update_forest_visibility() -> void:
		var started := Time.get_ticks_usec()
		super._update_forest_visibility()
		record("forest_visibility", started)
	func _update_forest_collision() -> void:
		var started := Time.get_ticks_usec()
		super._update_forest_collision()
		record("forest_collision", started)
	func _update_shadow_proximity() -> void:
		var started := Time.get_ticks_usec()
		super._update_shadow_proximity()
		record("shadow_proximity", started)
	func _update_weather_effects(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._update_weather_effects(delta)
		record("weather", started)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var save_manager := root.get_node("SaveGameManager")
	root.remove_child(save_manager)
	save_manager.free()
	var no_save := NoSave.new()
	no_save.name = "SaveGameManager"
	root.add_child(no_save)
	root.get_node("GameSession").selected_character_id = ""
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var world := ProfileWorld.new()
	root.add_child(world)
	current_scene = world
	await world.profile_ready
	print("PROFILE_READY nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " player=", world.player.global_position, " camera=", root.get_camera_3d())
	world.player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(3.0).timeout
	var frames := 600
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			frames = int(argument.trim_prefix("--frames="))
	if "--no-wildlife" in OS.get_cmdline_user_args():
		for animal in get_nodes_in_group("wildlife"):
			animal.set_process(false)
	if "--no-render" in OS.get_cmdline_user_args():
		root.disable_3d = true
	world.sampling = true
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	var spikes := 0
	for frame in range(frames):
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed_ms := (now - previous) / 1000.0
		previous = now
		samples.append(elapsed_ms)
		if elapsed_ms > 50.0:
			spikes += 1
			if spikes <= 25:
				print("FRAME_SPIKE ms=", elapsed_ms, " costs_us=", world.frame_costs)
		world.frame_costs.clear()
		if frame % 120 == 0:
			print("FRAME_MONITOR process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if "--walk" in OS.get_cmdline_user_args():
			Input.action_press("move_forward")
	Input.action_release("move_forward")
	world.sampling = false
	samples.sort()
	print("FRAME_RESULT samples=", samples.size(), " p50_ms=", samples[samples.size() / 2], " p95_ms=", samples[int(samples.size() * 0.95)], " max_ms=", samples.back(), " spikes_over_50ms=", spikes)
	for label in world.totals:
		print("CPU_PROFILE ", label, " total_ms=", world.totals[label] / 1000.0, " max_call_ms=", world.peaks[label] / 1000.0)
	world._scene_quitting = true
	current_scene = null
	world.queue_free()
	await process_frame
	await process_frame
	quit()
