extends SceneTree

class World extends Node3D:
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0

class Bird extends BirdController:
	func _build_bird() -> void:
		_bird_root = Node3D.new()
		add_child(_bird_root)
	func _build_hitbox() -> void:
		pass

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
	# Two flockmates on the same tiny loop; both must regenerate identical routes
	var birds: Array[Bird] = []
	for index in range(2):
		var bird := Bird.new()
		world.add_child(bird)
		bird.set_flock_id(7)
		bird.setup([Vector3(0, 0, 0), Vector3(8, 0, 0)])
		bird._drink_cooldown = 99999.0
		birds.append(bird)
	# Fly until the loop completes and the route regenerates
	var guard := 0
	while birds[0]._route_generation == 0 and guard < 6000:
		for bird in birds:
			bird._process(0.1)
		guard += 1
	check(birds[0]._route_generation == 1, "Bird regenerates its route when the loop completes")
	check(birds[0].patrol_points.size() == 37, "Regenerated route has far waypoint plus roaming walk")
	check(birds[0].target_index == 0, "Waypoint index restarts after regeneration")
	var far: Vector3 = birds[0].patrol_points[0]
	check(Vector2(far.x, far.z).length() >= 370.0, "First waypoint of a new route is on a distant map rim")
	var same_route := birds[0].patrol_points.size() == birds[1].patrol_points.size()
	if same_route:
		for i in range(birds[0].patrol_points.size()):
			if birds[0].patrol_points[i] != birds[1].patrol_points[i]:
				same_route = false
				break
	check(same_route, "Flockmates regenerate identical waypoints")
	# Successive generations must visit different distant regions
	var gen1_first: Vector3 = birds[0].patrol_points[0]
	birds[0]._regenerate_route()
	var gen2_first: Vector3 = birds[0].patrol_points[0]
	check(gen1_first != gen2_first, "Each generation targets a different region")
	# Over several generations the flock must cover most of the map
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for gen in range(8):
		birds[0]._regenerate_route()
		for point in birds[0].patrol_points:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
			min_z = minf(min_z, point.z)
			max_z = maxf(max_z, point.z)
	check(max_x - min_x > 500.0 and max_z - min_z > 500.0, "Routes across generations span most of the map")
	world.free()
	if failures == 0:
		print("PASS: bird flocks roam new routes across the whole map")
	quit(1 if failures else 0)
