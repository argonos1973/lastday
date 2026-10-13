extends SceneTree

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _get_exact_ground_y(_x: float, _z: float, _from: float = 250.0) -> float:
		return 0.0

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
	world.river_segments_data = [
		{"center": Vector3.ZERO, "size": Vector2(40, 8), "yaw": 0.0},
		{"center": Vector3(150, 0, 0), "size": Vector2(130, 90), "yaw": 0.0}]
	world.nav = NavPathfinding.new()
	world.nav.build([], world._wildlife_water_obstacles())
	check(not world.is_wildlife_allowed_at(Vector3(150, 0, 0)), "Lake remains blocked")
	check(world.nav.is_cell_blocked(world.nav.world_to_grid(Vector3(150, 0, 0))), "Nav agrees on lake")
	world.wolf_nav = NavPathfinding.new()
	world.wolf_nav.build([], world.river_segments_data)
	var wolf := WildlifeController.new()
	world.add_child(wolf)
	wolf.set_process(false)
	wolf.animal_type = "wolf"
	wolf.position = Vector3(0, 0, -7)
	var wolf_goal := Vector3(0, 0, 7)
	check(not wolf._direct_route_allowed(wolf_goal), "Wolf cannot take chase shortcut through river")
	var wolf_path := wolf._request_path(wolf.position, wolf_goal)
	check(not wolf_path.is_empty(), "Wolf finds river detour")
	for waypoint in wolf_path:
		for frame in range(2400):
			wolf._move_towards(waypoint, 3.0, 1.0 / 30.0, 6.0)
			check(wolf._is_position_allowed(wolf.position), "Wolf detour stays on land")
			if wolf.position.distance_to(waypoint) < 0.1:
				break
	check(wolf.position.distance_to(wolf_goal) < 2.0, "Wolf reaches opposite bank around river")
	wolf.free()
	for kind in ["deer", "fox"]:
		var animal := WildlifeController.new()
		world.add_child(animal)
		animal.set_process(false)
		animal.animal_type = kind
		animal.move_speed = 2.0
		animal.position = Vector3(0, 0, -12)
		var goal := Vector3(0, 0, 12)
		var path := animal._request_path(animal.position, goal)
		check(not path.is_empty() and path.back().distance_to(goal) < 1.0, kind + ": far bank reachable")
		var entered_water := false
		for frame in range(900):
			animal._update_water_depth(1.0 / 30.0)
			animal._move_towards(goal, 3.0, 1.0 / 30.0, 6.0)
			entered_water = entered_water or absf(animal.position.z) < 3.0
			check(not animal._escape_if_trapped(1.0 / 30.0), kind + ": crossing must not trigger shore escape")
			if animal.position.distance_to(goal) < 0.1:
				break
		check(entered_water and animal.position.distance_to(goal) < 0.1, kind + ": must cross river continuously")
		animal.free()
	world.river_segments_data.clear()
	for item in ["Ciervo muerto", "Lobo muerto", "Zorro muerto", "Oso muerto", "Animal muerto"]:
		var kind := WildlifeController.corpse_species(item)
		var alive := WildlifeController.new()
		world.add_child(alive)
		alive.set_process(false)
		alive.animal_type = kind
		check(alive._try_build_external_animal(), item + ": live model loads")
		check(alive._visual_root != null and alive._visual_root.visible, item + ": live model is visible")
		var id := kind + str(randi())
		world._spawn_dropped_item_visual(id, item, "material", 8.0, 1, 0.0, Vector3(0, 0, 30))
		var corpse := world.get_node_or_null("Pickup_" + id) as Node3D
		check(corpse != null, item + ": dropped visual exists")
		if corpse != null:
			check(corpse.scale.is_equal_approx(alive._visual_root.scale), item + ": dropped scale matches live animal")
			check(absf(corpse.rotation.z + PI / 2.0) < 0.001, item + ": lies on side")
		var action = world.world_actions_by_id.get(id)
		check(action != null and action.get_meta("animal_type", "") == kind, item + ": species retained for gutting")
		alive._water_depth = 0.8
		alive._water_query_timer = 0.0
		alive._update_water_depth(0.1)
		alive._walk_time = 0.0
		alive._animate_legs(0.1)
		check(alive._visual_root.position.y < -0.05, item + ": walking keeps water immersion")
		alive.free()
	world.free()
	print("WILDLIFE_RIVER_DROP failures=", failures)
	quit(1 if failures else 0)
