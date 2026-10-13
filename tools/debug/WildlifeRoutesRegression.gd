extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92217
	var allowed := func(pos: Vector3) -> bool: return pos.distance_to(Vector3.ZERO) > 8.0
	var home := Vector3.ZERO
	var route: Array = WildlifeRoutes.build_roaming_route(rng, home, 8, 12.0, 20.0, allowed, true)
	check(route.size() == 9, "home-start route retains the requested patrol points")
	check(not route.is_empty() and route[0] is Vector3 and allowed.call(route[0]), "animal starts on a valid point near its assigned habitat")
	if not route.is_empty():
		check((route[0] as Vector3).distance_to(home) <= 105.0, "initial animal sighting stays near its configured spawn zone")
	var legacy: Array = WildlifeRoutes.build_roaming_route(rng, home, 8, 12.0, 20.0, allowed)
	check(legacy.size() == 8, "bird and legacy callers keep their existing route length")
	print("WILDLIFE_ROUTES failures=", failures)
	quit(1 if failures else 0)
