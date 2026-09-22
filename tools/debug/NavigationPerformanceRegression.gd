extends SceneTree

class BaselineNav extends NavPathfinding:
	func _astar(start_cell: Vector2i, goal_cell: Vector2i, start_world: Vector3) -> Array:
		var cells := _search.get_id_path(start_cell, goal_cell, true)
		var path: Array = []
		for cell in cells:
			path.append(grid_to_world(cell))
		if path.size() > 1 and _is_path_clear(start_world, path[1]):
			path.pop_front()
		return _smooth_path(path)

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func measure(nav: NavPathfinding, start: Vector3, goal: Vector3, label: String) -> void:
	var worst_us := 0
	var total_us := 0
	for sample in range(12):
		var started := Time.get_ticks_usec()
		var path := nav.find_path(start + Vector3(sample * 2, 0, 0), goal)
		var elapsed := Time.get_ticks_usec() - started
		worst_us = maxi(worst_us, elapsed)
		total_us += elapsed
		for point in path:
			check(not nav.is_cell_blocked(nav.world_to_grid(point)), label + " stays on land")
	print("NAV_BENCH ", label, " total_ms=", total_us / 1000.0, " worst_ms=", worst_us / 1000.0)
	check(worst_us < 16000, label + " single query exceeds the frame budget")
	check(total_us < 40000, label + " repeated queries stall the main thread")

func run() -> void:
	var nav := BaselineNav.new() if "--baseline" in OS.get_cmdline_user_args() else NavPathfinding.new()
	nav.build([], [{"center": Vector3.ZERO, "size": Vector2(1200, 12), "yaw": 0.0}])
	measure(nav, Vector3(0, 0, -20), Vector3(0, 0, 20), "disconnected banks")
	nav.build([], [{"center": Vector3(250, 0, -307), "size": Vector2(150, 90), "yaw": 0.0}])
	measure(nav, Vector3(250, 0, -250), Vector3(250, 0, -365), "lake detour")
	measure(nav, Vector3(-200, 0, 100), Vector3(200, 0, 100), "open terrain")
	var world = load("res://scripts/Main.gd").new()
	nav.build([], world._default_river_segments())
	world.free()
	measure(nav, Vector3(-100, 0, -100), Vector3(9, 0, 6), "world rivers to village")
	measure(nav, Vector3(250, 0, -250), Vector3(258, 0, -264), "world rivers to saved lake position")
	measure(nav, Vector3(98, 0, -2), Vector3(96, 0, 36), "long east tributary detour")
	measure(nav, Vector3(-22, 0, 126), Vector3(54, 0, 136), "long south tributary detour")
	var walls := [{"pos": Vector3.ZERO, "house_bounds": Rect2(-2, -484, 4, 968), "barn_door_always_open": true}]
	nav.build(walls, [])
	var left := Vector3(-20, 0, 0)
	var right := Vector3(20, 0, 0)
	var closed := nav.find_path(left, right)
	check(not closed.is_empty() and closed.back().x < 0.0, "Closed wall separates regions")
	nav.update_door_cache(walls, func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	var opened := nav.find_path(left, right)
	check(not opened.is_empty() and opened.back().distance_to(right) < 3.0, "Opening a door reconnects regions")
	var update_start := Time.get_ticks_usec()
	nav.update_door_cache([], func(_p, _b): return false, func(_p, _b): return false)
	check(Time.get_ticks_usec() - update_start < 16000, "Closing a door must not flood-fill the whole map")
	closed = nav.find_path(left, right)
	check(not closed.is_empty() and closed.back().x < 0.0, "Closing a door separates regions again")
	nav.update_door_cache(walls, func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	nav.build(walls, [])
	closed = nav.find_path(left, right)
	check(not closed.is_empty() and closed.back().x < 0.0, "Rebuilding navigation clears stale open doors")
	var small := NavPathfinding.new()
	small._grid_size = 64
	var partitions := [
		{"pos": Vector3(-14, 0, 0), "house_bounds": Rect2(-16, -64, 4, 128), "barn_door_always_open": true},
		{"pos": Vector3(14, 0, 0), "house_bounds": Rect2(12, -64, 4, 128), "barn_door_always_open": true},
	]
	small.build(partitions, [])
	small.update_door_cache(partitions, func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	var across := small.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	check(not across.is_empty() and across.back().x == 40.0, "Two doors join three regions transitively")
	small.update_door_cache([partitions[0]], func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	across = small.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	check(not across.is_empty() and across.back().x < 12.0, "Closing one door removes only that connection")
	small._grid_size = 8
	small.build([
		{"pos": Vector3(-4, 0, -6), "radius": 0.1},
		{"pos": Vector3(-6, 0, -4), "radius": 0.1},
	], [])
	var corner := small.find_path(Vector3(-6, 0, -6), Vector3(-4, 0, -4))
	check(corner.size() == 1 and corner[0] == Vector3(-6, 0, -6), "Touching diagonal corners do not connect regions")
	if failures == 0:
		print("PASS: navigation query frame budget and door connectivity")
	quit(1 if failures else 0)
