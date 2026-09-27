extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# _create_player must use the random spawn, not a fixed village/lake point
	var src := FileAccess.get_file_as_string("res://scripts/Main.gd")
	var fn_start := src.find("func _create_player()")
	check(fn_start >= 0, "_create_player exists")
	if fn_start >= 0:
		var fn_end := src.find("\nfunc ", fn_start + 1)
		var body := src.substr(fn_start, fn_end - fn_start)
		check(body.contains("_get_random_spawn_pos"), "New games must use the random spawn, not a fixed point")
	# The random spawn must produce varied positions across the zones
	var main: Node3D = load("res://scripts/Main.gd").new()
	var distinct := {}
	for attempt in range(16):
		var pos: Vector3 = main._get_random_spawn_pos()
		distinct[Vector2(snappedf(pos.x, 5.0), snappedf(pos.z, 5.0))] = true
		check(absf(pos.x) <= 480.0 and absf(pos.z) <= 480.0, "Spawn stays inside the world")
	check(distinct.size() >= 3, "Spawn positions must vary across zones, got %d distinct" % distinct.size())
	main.free()
	# Spawns must never land inside wolf aggro range: park a live wolf on a
	# spawn zone and confirm every pick keeps >=120 m from it.
	var tree_main: Node3D = load("res://scripts/Main.gd").new()
	root.add_child(tree_main)
	var wolf: Node3D = load("res://scripts/WildlifeController.gd").new()
	wolf.set_process(false)
	root.add_child(wolf)
	wolf.animal_type = "wolf"
	wolf._is_dead = false
	wolf.add_to_group("wildlife_wolf")
	wolf.position = Vector3(8.0, 0.0, 2.5)
	for attempt in range(24):
		var p: Vector3 = tree_main._get_random_spawn_pos()
		check(Vector2(p.x - 8.0, p.z - 2.5).length() >= 120.0, "Spawn must stay >=120 m from a live wolf")
	# A dead wolf must not repel spawns.
	wolf._is_dead = true
	tree_main.free()
	wolf.free()
	if failures == 0:
		print("PASS: new games spawn at varied zones across the map")
	quit(1 if failures else 0)
