extends SceneTree

class World extends Node3D:
	var world_actions_by_id: Dictionary = {}
	var position_checks := 0
	func is_wildlife_allowed_at(_position: Vector3) -> bool:
		position_checks += 1
		return true
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0

class Wolf extends WildlifeController:
	var ticks := 0
	func _build_animal() -> void:
		pass
	func _play_wolf_sound(_kind: String) -> void:
		pass
	func _update_wolf_sounds(_delta: float) -> void:
		pass
	func _wolf_ai(_delta: float) -> Dictionary:
		ticks += 1
		return {"target": global_position, "speed": 0.0}

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var player := Node3D.new()
	world.add_child(player)
	var wolves: Array[Wolf] = []
	for index in range(24):
		var wolf := Wolf.new()
		wolf.name = "Wildlife_wolf_%d" % index
		world.add_child(wolf)
		wolf.set_process(false)
		wolf.setup("wolf", [Vector3(300, 0, index), Vector3(310, 0, index)])
		wolf._player = player
		wolves.append(wolf)
	var peak_ticks := 0
	for frame in range(120):
		var frame_ticks := 0
		for wolf in wolves:
			var before := wolf.ticks
			wolf._process(1.0 / 60.0)
			frame_ticks += wolf.ticks - before
		peak_ticks = maxi(peak_ticks, frame_ticks)
	check(peak_ticks <= 4, "Distant wolves must not all update on the same frame")
	check(world.position_checks <= 72, "Distant wolves must not check escape positions every frame")
	for wolf in wolves:
		check(wolf.ticks >= 1 and wolf.ticks <= 3, "Far wolves retain one update per second")
	var seeker := wolves[0]
	for index in range(3000):
		var action := WorldAction.new()
		action.action_type = "drink_water"
		world.add_child(action)
		world.world_actions_by_id[str(index)] = action
	var meat := WorldAction.new()
	meat.action_type = "wolf_meat_raw"
	world.add_child(meat)
	world.world_actions_by_id["meat"] = meat
	var started := Time.get_ticks_usec()
	for attempt in range(24):
		check(seeker._find_nearest_meat_pickup() == meat, "Wolf finds available meat")
	var elapsed := Time.get_ticks_usec() - started
	print("WILDLIFE_BENCH peak_ticks=", peak_ticks, " position_checks=", world.position_checks, " meat_queries_ms=", elapsed / 1000.0)
	check(elapsed < 5000, "Meat queries must not scan thousands of unrelated actions")
	meat.depleted = true
	check(seeker._find_nearest_meat_pickup() == null, "Depleted meat is ignored")
	meat.depleted = false
	meat.action_type = "pickup_item"
	check(seeker._find_nearest_meat_pickup() == null, "Retyped action leaves the food index")
	meat.action_type = "wolf_meat_raw"
	check(seeker._find_nearest_meat_pickup() == meat, "Retyping restores the food index")
	world.remove_child(meat)
	check(seeker._find_nearest_meat_pickup() == null, "Removed meat leaves the scene index")
	meat.free()
	world.free()
	if failures == 0:
		print("PASS: distributed wildlife updates and indexed food queries")
	quit(1 if failures else 0)
