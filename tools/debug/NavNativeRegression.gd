extends SceneTree

## Regresión PoC: LastDayNav (GDExtension C) vs NavPathfinding (GDScript).
## Mismo grid sintético: bloqueadores circulares, una casa con puerta, un granero
## y dos cuerpos de agua. Compara is_cell_blocked celda a celda, paridad de
## alcanzabilidad en find_path, validez geométrica del camino nativo y el efecto
## de update_door_cache. Termina con un micro-benchmark C vs GDScript.

const NavPathfindingScript = preload("res://scripts/NavPathfinding.gd")

var _failures := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)

func _make_blockers() -> Array:
	return [
		{"pos": Vector3(10, 0, 10), "radius": 6.0},
		{"pos": Vector3(-30, 0, 30), "radius": 4.0},
		{"pos": Vector3(20, 0, -20), "radius": 1.8, "house_bounds": Rect2(12, -30, 16, 18), "door_open": false},
		{"pos": Vector3(45, 0, 120), "radius": 1.8, "house_bounds": Rect2(41, 111, 8, 18), "barn_door_always_open": true, "front_door_x": 45.0, "front_door_w": 3.0, "back_door_x": 45.0, "back_door_w": 3.0},
		{"pos": Vector3(120, 0, -60), "radius": 3.0, "house_bounds": Rect2(112, -72, 16, 20), "door_open": true},
	]

func _make_rivers() -> Array:
	return [
		{"center": Vector3(-50, 0, 0), "size": Vector2(40, 10), "yaw": 15.0},
		{"center": Vector3(200, 0, -200), "size": Vector2(80, 40), "yaw": 0.0},
	]

func _path_valid(nav, path: Array) -> bool:
	# Cada tramo recto entre puntos del camino no debe cruzar celdas bloqueadas.
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var dist := Vector2(b.x - a.x, b.z - a.z).length()
		var steps := int(ceil(dist / 1.0))
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / maxf(1.0, float(steps)))
			var cell := Vector2i(int(round(p.x / 2.0)) + 242, int(round(p.z / 2.0)) + 250)
			if nav.is_cell_blocked(cell):
				return false
	return true

func _init() -> void:
	print("=== NavNativeRegression ===")
	if not ClassDB.class_exists("LastDayNav"):
		push_error("LastDayNav GDExtension NOT loaded")
		_failures += 1
		quit(1)
		return
	var nav_c = ClassDB.instantiate("LastDayNav")
	var nav_gd = NavPathfindingScript.new()
	var blockers := _make_blockers()
	var rivers := _make_rivers()

	var t0 := Time.get_ticks_usec()
	nav_c.build(blockers, rivers)
	var t_c_build := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	nav_gd.build(blockers, rivers)
	var t_gd_build := Time.get_ticks_usec() - t0
	print("build: C=%d us  GDScript=%d us" % [t_c_build, t_gd_build])

	# 1) Paridad de is_cell_blocked en una ventana alrededor de los obstáculos.
	var mismatches := 0
	for gx in range(180, 300):
		for gz in range(180, 330):
			var cell := Vector2i(gx, gz)
			if nav_c.is_cell_blocked(cell) != nav_gd.is_cell_blocked(cell):
				mismatches += 1
	_check(mismatches == 0, "is_cell_blocked parity over 12k cells (mismatches=%d)" % mismatches)

	# 2) Paridad de alcanzabilidad: mismos pares start/goal, ambos encuentran
	#    camino o ambos fallan (distinto desempate del A* está permitido).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var pairs := []
	for i in range(60):
		var a := Vector3(rng.randf_range(-200.0, 200.0), 0, rng.randf_range(-200.0, 200.0))
		var b := Vector3(rng.randf_range(-200.0, 200.0), 0, rng.randf_range(-200.0, 200.0))
		pairs.append([a, b])
	var reach_mismatch := 0
	var valid_bad := 0
	var gd_valid_bad := 0
	for p in pairs:
		var pc: Array = nav_c.find_path(p[0], p[1])
		var pg: Array = nav_gd.find_path(p[0], p[1])
		if pc.is_empty() != pg.is_empty():
			reach_mismatch += 1
		if not pc.is_empty() and not _path_valid(nav_c, pc):
			valid_bad += 1
		if not pg.is_empty() and not _path_valid(nav_gd, pg):
			gd_valid_bad += 1
	_check(reach_mismatch == 0, "find_path reachability parity on %d random pairs" % pairs.size())
	_check(valid_bad == 0, "native paths stay on walkable cells (bad=%d)" % valid_bad)
	_check(gd_valid_bad == 0, "gdscript paths stay on walkable cells (bad=%d)" % gd_valid_bad)

	# 3) Casos dirigidos.
	var pc: Array = nav_c.find_path(Vector3(0, 0, 0), Vector3(40, 0, 40))
	_check(pc.size() >= 1, "simple open-field path found")
	# Origen dentro de la casa cerrada -> debe salir por la celda libre más cercana.
	var pc2: Array = nav_c.find_path(Vector3(20, 0, -21), Vector3(-80, 0, 60))
	var pg2: Array = nav_gd.find_path(Vector3(20, 0, -21), Vector3(-80, 0, 60))
	_check(pc2.is_empty() == pg2.is_empty(), "blocked origin parity (C=%d GD=%d)" % [pc2.size(), pg2.size()])
	# Meta dentro del lago -> objetivo alcanzable en la orilla, nunca dentro.
	var pc3: Array = nav_c.find_path(Vector3(0, 0, 0), Vector3(200, 0, -200))
	var pg3: Array = nav_gd.find_path(Vector3(0, 0, 0), Vector3(200, 0, -200))
	_check(pc3.is_empty() == pg3.is_empty(), "lake goal parity (C=%d GD=%d)" % [pc3.size(), pg3.size()])
	if not pc3.is_empty():
		_check(_path_valid(nav_c, pc3), "lake partial path walkable")

	# 4) update_door_cache: abrir la puerta de la casa libera celdas bloqueadas.
	# GD recibe los callables reales de Main; C tiene esa geometria embebida,
	# asi que la paridad valida a la vez el port de los pasillos.
	blockers[2]["door_open"] = true
	var door_passage := func(world_pos: Vector3, house_origin: Vector3) -> bool:
		var local_x := world_pos.x - house_origin.x
		var local_z := world_pos.z - house_origin.z
		return abs(local_x) <= 1.5 and local_z >= -5.2 and local_z <= 5.2
	var barn_passage := func(world_pos: Vector3, blocker: Dictionary) -> bool:
		var bpos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var front_x: float = float(blocker.get("front_door_x", bpos.x))
		var front_w: float = float(blocker.get("front_door_w", 2.0))
		var back_x: float = float(blocker.get("back_door_x", bpos.x))
		var back_w: float = float(blocker.get("back_door_w", 2.0))
		var half_d: float = float(blocker.get("house_bounds", Rect2()).size.y) * 0.5
		if abs(world_pos.x - front_x) <= front_w * 0.5 + 0.5 and world_pos.z <= bpos.z + 1.0 and world_pos.z >= bpos.z - half_d - 2.0:
			return true
		return abs(world_pos.x - back_x) <= back_w * 0.5 + 0.5 and world_pos.z >= bpos.z - 1.0 and world_pos.z <= bpos.z + half_d + 2.0
	nav_c.update_door_cache(blockers, door_passage, barn_passage)
	nav_gd.update_door_cache(blockers, door_passage, barn_passage)
	var door_mismatch := 0
	var shown := 0
	for gx in range(180, 300):
		for gz in range(180, 330):
			var cell := Vector2i(gx, gz)
			if nav_c.is_cell_blocked(cell) != nav_gd.is_cell_blocked(cell):
				door_mismatch += 1
				if shown < 12:
					shown += 1
					var w := Vector3((cell.x - 242) * 2.0, 0, (cell.y - 250) * 2.0)
					print("  mismatch cell=%v world=%v C=%s GD=%s" % [cell, w, nav_c.is_cell_blocked(cell), nav_gd.is_cell_blocked(cell)])
	_check(door_mismatch == 0, "door_open cell parity after update_door_cache (mismatch=%d)" % door_mismatch)

	# 5) Regiones desconectadas reconectadas por puerta (transitivo y cierre).
	var nav_part := ClassDB.instantiate("LastDayNav")
	var partitions := [
		{"pos": Vector3(-20, 0, 0), "house_bounds": Rect2(-22, -500, 4, 1400), "barn_door_always_open": true},
		{"pos": Vector3(20, 0, 0), "house_bounds": Rect2(18, -500, 4, 1400), "barn_door_always_open": true},
	]
	nav_part.build(partitions, [])
	var p_closed: Array = nav_part.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	_check(not p_closed.is_empty() and p_closed.back().x < -22.0, "closed wall separates regions in LastDayNav (end_x=%.1f)" % (p_closed.back().x if not p_closed.is_empty() else 999.0))
	nav_part.update_door_cache(partitions, func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	var p_open: Array = nav_part.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	_check(not p_open.is_empty() and p_open.back().distance_to(Vector3(40, 0, 0)) < 3.0, "two doors join three regions transitively in LastDayNav")
	nav_part.update_door_cache([partitions[0]], func(_p, _b): return false, func(p, _b): return absf(p.z) < 3.0)
	var p_half: Array = nav_part.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	_check(not p_half.is_empty() and p_half.back().x > -18.0 and p_half.back().x < 18.0, "closing one door removes only that connection (end_x=%.1f)" % (p_half.back().x if not p_half.is_empty() else 999.0))
	# Rebuild clears stale open doors and reuses heap cleanly.
	nav_part.build(partitions, [{"center": Vector3(100, 0, 100), "size": Vector2(40, 10), "yaw": 15}])
	var p_rebuilt: Array = nav_part.find_path(Vector3(-40, 0, 0), Vector3(40, 0, 0))
	_check(not p_rebuilt.is_empty() and p_rebuilt.back().x < -22.0, "rebuild clears stale open doors and handles int yaw")

	# 6) Paridad de metodos auxiliares (world_to_grid, grid_to_world, _is_path_clear).
	var sample_pos := Vector3(37.4, 0.0, -83.1)
	var cg: Vector2i = nav_c.world_to_grid(sample_pos)
	var gg: Vector2i = nav_gd.world_to_grid(sample_pos)
	_check(cg == gg and nav_c.grid_to_world(cg) == nav_gd.grid_to_world(gg), "world_to_grid / grid_to_world parity")
	_check(nav_c._is_path_clear(Vector3(0, 0, 0), Vector3(10, 0, 10)) == nav_gd._is_path_clear(Vector3(0, 0, 0), Vector3(10, 0, 10)), "_is_path_clear parity on blocked line")

	# 7) Benchmark find_path.
	t0 = Time.get_ticks_usec()
	for i in range(2000):
		for p in pairs.slice(0, 20):
			nav_c.find_path(p[0], p[1])
	var t_c := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for i in range(2000):
		for p in pairs.slice(0, 20):
			nav_gd.find_path(p[0], p[1])
	var t_gd := Time.get_ticks_usec() - t0
	print("find_path x40000: C=%d ms  GDScript=%d ms  speedup=%.1fx" % [t_c / 1000, t_gd / 1000, float(t_gd) / maxf(1.0, float(t_c))])

	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: %d" % _failures)
		quit(1)
