extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const WildlifeControllerScript = preload("res://scripts/WildlifeController.gd")
const WildlifeRoutes = preload("res://scripts/WildlifeRoutes.gd")

class TestMain extends MainScript:
	func _ready() -> void:
		pass
	func is_wildlife_allowed_at(_pos: Vector3) -> bool:
		return true
	func _is_near_wildlife_blocker(_pos: Vector3, _extra_margin: float = 0.0) -> bool:
		return false
	func _is_pos_wolf_protected(_pos: Vector3) -> bool:
		return false
	func _get_exact_ground_y(_x: float, _z: float, _fallback: float = 0.0) -> float:
		return 0.0
	func _is_water_drop_position(_pos: Vector3) -> bool:
		return false

class TestAnimal extends WildlifeControllerScript:
	func _build_animal() -> void:
		pass
	func _play_animation_by_name(_keyword: String) -> void:
		pass
	func _play_wolf_sound(_sound: String) -> void:
		pass
	func _compute_wolf_separation(_radius: float) -> Vector3:
		return Vector3.ZERO
	func _is_near_lit_campfire(_pos: Vector3, _radius: float) -> bool:
		return false
	func _can_reach_player() -> bool:
		return true

class TestPlayer extends Node3D:
	var health := 100.0
	func apply_damage(amount: float) -> void:
		health -= amount

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := TestMain.new()
	root.add_child(world)
	current_scene = world
	world._world_rng.seed = 81427
	var anchors: Array[Vector3] = world._bear_territory_anchors()
	var player_start := Vector2(8.0, 2.5)
	for i in range(anchors.size()):
		var spawn: Vector3 = world._bear_spawn_center(i)
		var route := WildlifeRoutes.build_territory_route(world._world_rng, spawn, 24, 22.0, 58.0, 76.0, world.is_wildlife_allowed_at)
		var far_from_start := Vector2(spawn.x, spawn.z).distance_to(player_start) >= 120.0
		check(far_from_start, "bear territory %d is at least 120m from the starting area" % i)
		check(Vector2(spawn.x - anchors[i].x, spawn.z - anchors[i].z).length() <= 34.1, "bear %d spawns inside its assigned territory" % i)
		var route_bounded := route.size() == 24
		for point in route:
			route_bounded = route_bounded and Vector2(point.x - spawn.x, point.z - spawn.z).length() <= 76.1
		check(route_bounded, "bear %d patrol stays inside its home range" % i)

	var bear := TestAnimal.new()
	var deer := TestAnimal.new()
	world.add_child(bear)
	world.add_child(deer)
	bear.setup("bear", [Vector3(0, 0, 0), Vector3(2, 0, 0)])
	deer.setup("deer", [Vector3(1, 0, 0), Vector3(3, 0, 0)])
	bear._cached_wildlife = world.get_tree().get_nodes_in_group("wildlife")
	bear._wolf_hunger = 0.0
	bear._wolf_hunger_threshold = 100.0
	var prey_result: Dictionary = bear._wolf_ai(0.016)
	check(bear._state == "chase_prey" and prey_result.target == deer.global_position, "hungry bear targets a nearby deer")
	check(deer.health < deer.max_health, "bear attack damages its prey")
	deer.health = 35.0
	bear._attack_cooldown = 0.0
	bear._wolf_ai(0.016)
	bear._wolf_ai(0.016)
	check(deer._is_dead and bear._state == "eating" and bear._wolf_eating_target == deer, "bear kills and begins eating its deer prey")

	var player := TestPlayer.new()
	world.add_child(player)
	bear._player = player
	bear._player.global_position = bear.global_position + Vector3(0.5, 0.0, 0.0)
	bear._chase_cooldown = 0.0
	bear._attack_cooldown = 0.0
	bear._state = "patrol"
	bear._chase_target = null
	bear._wolf_eating_target = null
	bear._wolf_eating_timer = 0.0
	bear._wolf_hunger = 100.0
	bear._wolf_hunger_threshold = 0.0
	bear._wolf_ai(0.016)
	check(player.health == 65.0, "bear attack damages a nearby character for 35 health")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: remote bear territories, prey hunting, and character attacks")
	quit(1 if failures else 0)
