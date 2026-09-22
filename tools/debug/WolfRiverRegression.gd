extends SceneTree

class World extends Node3D:
	var nav := NavPathfinding.new()
	var no_route := false
	func find_path_wildlife(start: Vector3, goal: Vector3) -> Array:
		return [] if no_route else nav.find_path(start, goal)
	func is_wildlife_allowed_at(pos: Vector3) -> bool:
		return not nav.is_cell_blocked(nav.world_to_grid(pos))
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0

class Wolf extends WildlifeController:
	func _play_wolf_sound(_kind: String) -> void:
		pass
	func _update_wolf_sounds(_delta: float) -> void:
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
	# A small river outside the old +/-182 m navigation coverage.
	world.nav.build([], [{"center": Vector3(300, 0, 0), "size": Vector2(40, 8), "yaw": 25.0}])
	var start := Vector3(300, 0, -15)
	var goal := Vector3(300, 0, 15)
	var path := world.nav.find_path(start, goal)
	check(path.size() > 1, "River requires a detour beyond the old grid boundary")
	var previous := start
	for point in path:
		check(world.nav._is_path_clear(previous, point), "Smoothed route crossed a blocked river cell")
		previous = point
	check(previous.distance_to(goal) < 3.0, "Detour reaches the far bank")
	var player := Node3D.new()
	world.add_child(player)
	player.position = goal
	var wolf := Wolf.new()
	world.add_child(wolf)
	wolf.set_process(false)
	wolf.animal_type = "wolf"
	wolf.move_speed = 2.0
	wolf._wolf_hunger = 90.0
	wolf._player = player
	wolf.patrol_points = [start, start + Vector3(5, 0, 0)]
	wolf.position = start
	for frame in range(900):
		wolf._process(1.0 / 30.0)
		check(world.is_wildlife_allowed_at(wolf.position), "Chasing wolf entered the river")
		if wolf.position.distance_to(player.position) < 4.1:
			break
	check(wolf.position.distance_to(player.position) < 4.1, "Wolf must complete the detour and reach the player")
	check(wolf._chase_cooldown == 0.0, "River must not make the wolf abandon pursuit")
	# Reproject a target inside water to a safe shore, including same-cell cases.
	var water_goal := Vector3(300, 0, 0)
	path = world.nav.find_path(wolf.position, water_goal)
	check(not path.is_empty() and world.is_wildlife_allowed_at(path.back()), "Water goal must end on land")
	wolf.position = water_goal
	for frame in range(300):
		if not wolf._escape_if_trapped(1.0 / 30.0):
			break
	check(world.is_wildlife_allowed_at(wolf.position), "Trapped wolf must walk to a stable shore target")
	# A disconnected bank must return a partial path, never a water shortcut.
	world.nav.build([], [{"center": Vector3.ZERO, "size": Vector2(1200, 12), "yaw": 0.0}])
	path = world.nav.find_path(Vector3(0, 0, -20), Vector3(0, 0, 20))
	check(not path.is_empty() and path.back().z < 0.0, "Disconnected target must stop on reachable shore")
	player.position = Vector3(0, 0, 20)
	wolf.position = Vector3(0, 0, -20)
	wolf._current_path.clear()
	wolf._path_recalc_timer = 0.0
	wolf._reach_check_timer = 0.0
	var initial_distance := wolf.position.distance_to(player.position)
	for frame in range(90):
		wolf._process(1.0 / 30.0)
	check(wolf._state == "retreat" and wolf._chase_cooldown > 0.0, "Wolf abandons an unreachable player")
	check(wolf._chase_target == null, "Retreat clears the chase target")
	check(wolf.position.distance_to(player.position) > initial_distance + 5.0, "Wolf moves away instead of waiting at the shore")
	check(world.is_wildlife_allowed_at(wolf.position) and wolf.position.z < 0.0, "Retreating wolf stays on reachable land")
	player.position = wolf.position + Vector3(8, 0, 0)
	wolf._process(1.0 / 30.0)
	check(wolf._state == "retreat", "Wolf must not immediately chase again during retreat")
	for frame in range(900):
		wolf._process(1.0 / 30.0)
		if wolf.position.distance_to(player.position) < 4.1:
			break
	check(wolf.position.distance_to(player.position) < 4.1, "Wolf resumes pursuit when the player returns to reachable land")
	# Door updates must also reach the native path search.
	var door := Node3D.new()
	world.add_child(door)
	var blockers := [{"pos": Vector3.ZERO, "radius": 4.0, "barn_door_always_open": true, "house_bounds": Rect2(-4, -4, 8, 8)}]
	world.nav.build(blockers, [])
	var center := world.nav.world_to_grid(Vector3.ZERO)
	check(world.nav._search.is_point_solid(center), "Closed building blocks path search")
	world.nav.update_door_cache(blockers, func(_p, _b): return false, func(_p, _b): return true)
	check(not world.nav._search.is_point_solid(center), "Open doorway updates path search")
	world.nav.update_door_cache([], func(_p, _b): return false, func(_p, _b): return false)
	check(world.nav._search.is_point_solid(center), "Closed doorway restores path obstacle")
	world.nav.build([], [])
	wolf.position = Vector3.ZERO
	player.position = Vector3(0, 3, 0)
	wolf._state = "patrol"
	wolf._chase_cooldown = 0.0
	var retreat := wolf._wolf_ai(1.0 / 30.0)
	check(wolf._state == "retreat" and retreat["target"].distance_to(wolf.position) > 20.0, "Wolf retreats from an elevated player, even directly overhead")
	for frame in range(90):
		wolf._process(1.0 / 30.0)
	check(wolf.position.distance_to(player.position) > 8.0, "Elevated player triggers sustained retreat, not a one-frame turn")
	wolf._chase_cooldown = 0.0
	wolf._state = "chase_player"
	wolf._reach_check_timer = 0.0
	wolf._attack_cooldown = 0.0
	player.position = wolf.position + Vector3(2, 0, 0)
	world.no_route = true
	wolf._wolf_ai(1.0 / 30.0)
	check(wolf._state == "retreat", "Empty route triggers retreat even within attack range")
	check(wolf._attack_cooldown == 0.0, "Wolf must not attack an unreachable nearby player")
	world.free()
	if failures == 0:
		print("PASS: river detour, full-map coverage, safe shores, retreat from unreachable players and pursuit after cooldown")
	quit(1 if failures else 0)
