extends SceneTree

# Regresion de la colision de la torre de vigilancia de la base militar:
# simula una capsula de jugador subiendo las cinco rampas en caracol hasta la
# cubierta y verifica el grupo "stair_surface", los descansillos y que el
# hueco de la escalera no quede tapado por la cubierta.
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func _fail(msg: String) -> void:
	failures += 1
	push_error("WATCHTOWER: " + msg)

func _ray(world_3d: World3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = 1
	return world_3d.direct_space_state.intersect_ray(params)

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world._city_tent_pos = Vector3(50.0, 0.0, 120.0)
	world._build_city_military_base_perimeter(false)

	var vis := world.get_node_or_null("MilitaryBaseWatchTower") as Node3D
	var rig := world.get_node_or_null("MilitaryBaseWatchTowerCol") as Node3D
	if rig == null or vis == null:
		_fail("no se creo la torre o el rig de colision")
		print("WATCHTOWER_ERRORS=", failures)
		quit(1)
		return
	if vis.global_position.distance_to(rig.global_position) > 0.01:
		_fail("desfase entre torre visual (%s) y colision (%s)" % [str(vis.global_position), str(rig.global_position)])

	# Verificar que los bloques de cemento tienen la colision a ras de su cara superior (~1.94 m), no al doble.
	var wall_vis := world.get_node_or_null("MilitaryBaseWall_0") as Node3D
	var wall_col := world.get_node_or_null("MilitaryBaseWallCol_0") as StaticBody3D
	if wall_vis == null or wall_col == null or wall_col.get_child_count() == 0:
		_fail("falta MilitaryBaseWall_0 / MilitaryBaseWallCol_0")
	else:
		var wall_cs := wall_col.get_child(0) as CollisionShape3D
		var wall_box := wall_cs.shape as BoxShape3D
		var wall_top_y := wall_cs.global_position.y + wall_box.size.y * 0.5 - wall_vis.global_position.y
		if absf(wall_top_y - 1.90) > 0.05:
			_fail("altura de colision del bloque de cemento incorrecta: %.2f m (esperado ~1.90 m)" % wall_top_y)

	var stairs := rig.get_node_or_null("Stairs") as StaticBody3D
	var solid := rig.get_node_or_null("Solid") as StaticBody3D
	if stairs != null and not stairs.is_in_group("stair_surface"):
		_fail("el cuerpo de rampas no esta en stair_surface")
	if stairs == null or solid == null:
		_fail("faltan cuerpos Stairs/Solid")
		print("WATCHTOWER_ERRORS=", failures)
		quit(1)
		return
	if stairs.get_child_count() < 5:
		_fail("menos de 5 rampas en Stairs")

	var scale_value := rig.scale.y
	var tower_pos := rig.global_position
	# Suelo plano a la altura de las patas de la torre (local y=1.145 * 0.85),
	# centrado bajo la torre de prueba.
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(40.0, 1.0, 40.0)
	gcol.shape = gbox
	var foot_y := tower_pos.y + 1.145 * scale_value
	ground.position = Vector3(tower_pos.x, foot_y - 0.5, tower_pos.z)
	ground.add_child(gcol)
	root.add_child(ground)

	var xf := rig.global_transform
	var w3d := world.get_world_3d()
	for i in range(3):
		await physics_frame

	# Cada punto alto debe apoyar sobre Stairs/Solid; el hueco de la cubierta NO.
	var samples := [
		["rampa1", Vector3(-1.0, 1.55, -2.51), true],
		["rampa1_top", Vector3(-1.80, 1.95, -2.51), true],
		["descanso1", Vector3(-2.52, 2.01, -2.50), false],
		["rampa2", Vector3(-2.52, 3.13, 0.0), true],
		["descanso2", Vector3(-2.52, 4.25, 2.50), false],
		["rampa3", Vector3(0.0, 5.37, 2.52), true],
		["descanso3", Vector3(2.50, 6.49, 2.50), false],
		["rampa4", Vector3(2.52, 7.61, 0.12), true],
		["pasillo", Vector3(2.50, 8.73, -2.20), false],
		["rampa5", Vector3(0.0, 9.86, -2.51), true],
		["cubierta", Vector3(-0.5, 10.99, 0.6), false],
		["cubierta_tira", Vector3(-2.53, 10.99, -2.52), false],
		["caseta_interior", Vector3(0.0, 10.99, 0.0), false],
	]
	for s in samples:
		var lp: Vector3 = s[1]
		var from: Vector3 = xf * (lp + Vector3(0, 0.6, 0))
		var to: Vector3 = xf * (lp - Vector3(0, 0.6, 0))
		var hit := _ray(w3d, from, to)
		if hit.is_empty():
			_fail("sin suelo en %s" % s[0])
			continue
		var expect_stair: bool = s[2]
		if expect_stair != bool((hit.collider as Object).is_in_group("stair_surface")):
			_fail("grupo stair_surface incorrecto en %s (collider=%s)" % [s[0], hit.collider.name])
		var hit_local_y: float = (rig.global_transform.affine_inverse() * (hit.position as Vector3)).y
		if absf(hit_local_y - lp.y) > 0.30:
			_fail("altura inesperada en %s: %.2f vs %.2f" % [s[0], hit_local_y, lp.y])

	# El hueco de la cubierta debe dejar pasar la escalera: un rayo vertical en
	# su centro topa con la rampa (~y9.5 local), no con suelo de cubierta (~11.0).
	var hole_hit := _ray(w3d, xf * Vector3(0.6, 13.0, -2.51), xf * Vector3(0.6, 5.0, -2.51))
	if hole_hit.is_empty():
		_fail("el hueco de la cubierta no golpea la rampa final")
	else:
		var hy: float = (rig.global_transform.affine_inverse() * (hole_hit.position as Vector3)).y
		if hy > 10.5:
			_fail("el hueco de la cubierta esta tapado (hit y=%.2f)" % hy)

	# Capsula EXACTA de PlayerController._create_body() (radius=0.35, height=1.75, pos.y=0.90,
	# floor_snap_length=0.1, velocity.y=-1.0 en suelo) subiendo los 5 tramos y entrando en la caseta.
	var walker := CharacterBody3D.new()
	walker.floor_max_angle = deg_to_rad(65.0)
	walker.floor_snap_length = 0.1
	var wcol := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	wcol.shape = capsule
	wcol.position.y = 0.90
	walker.add_child(wcol)
	root.add_child(walker)
	var routes := [
		# Ruta 1: centrada de esquina a esquina y entrando en la caseta.
		[
			Vector2(-2.52, -2.51),
			Vector2(-2.52, 2.52),
			Vector2(2.52, 2.52),
			Vector2(2.52, -2.51),
			Vector2(-2.52, -2.51),
			Vector2(-2.52, 0.0),
			Vector2(0.0, 0.0),
		],
		# Ruta 2: abriendose hacia el borde exterior en cada descansillo (como hace un jugador con WASD).
		[
			Vector2(-2.70, -2.68),
			Vector2(-2.70, 2.68),
			Vector2(2.68, 2.68),
			Vector2(2.68, -2.68),
			Vector2(-2.68, -2.68),
			Vector2(-2.55, 0.0),
			Vector2(0.0, 0.0),
		],
		# Ruta 3: cerrandose hacia el marco interior en cada giro.
		[
			Vector2(-2.35, -2.35),
			Vector2(-2.35, 2.35),
			Vector2(2.35, 2.35),
			Vector2(2.35, -2.35),
			Vector2(-2.35, -2.35),
			Vector2(-2.45, 0.0),
			Vector2(0.0, 0.0),
		],
	]
	var total_frames := 0
	var deck_local := Vector3.ZERO
	for r_idx in range(routes.size()):
		var path: Array = routes[r_idx]
		walker.velocity = Vector3.ZERO
		walker.global_position = xf * Vector3(0.6, 1.145, -2.51) + Vector3.UP * 0.05
		for i in range(3):
			await physics_frame
		var wp := 0
		var frames := 0
		var max_frames := 2500
		while wp < path.size() and frames < max_frames:
			await physics_frame
			frames += 1
			var target2: Vector2 = path[wp]
			var target3: Vector3 = xf * Vector3(target2.x, 0.0, target2.y)
			var flat := Vector2(target3.x - walker.global_position.x, target3.z - walker.global_position.z)
			if flat.length() < 0.28:
				wp += 1
				continue
			var dir := flat.normalized()
			var speed := 3.2
			var vel := walker.velocity
			vel.x = dir.x * speed
			vel.z = dir.y * speed
			vel.y = -1.0 if walker.is_on_floor() else walker.velocity.y - 20.0 * (1.0 / 60.0)
			walker.velocity = vel
			walker.move_and_slide()
			if walker.is_on_floor():
				walker.velocity.y = 0.0
		total_frames += frames
		deck_local = rig.global_transform.affine_inverse() * walker.global_position
		if wp < path.size():
			_fail("ruta %d: la capsula no completo el recorrido (parada en punto %d de %d, pos_local=%s)" % [r_idx, wp, path.size(), str(deck_local)])
		elif deck_local.y < 10.8:
			_fail("ruta %d: la capsula no alcanzo la cubierta (y local %.2f)" % [r_idx, deck_local.y])

	# Ruta 4 (WASD puro): el jugador empuja recto en cada eje cardinal hasta
	# tocar la pared del fondo del descansillo y gira 90 grados.
	walker.velocity = Vector3.ZERO
	walker.global_position = xf * Vector3(0.6, 1.145, -2.50) + Vector3.UP * 0.05
	for i in range(3):
		await physics_frame
	var dirs_local: Array[Vector3] = [
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(1, 0, 0),
		Vector3(0, 0, -1),
		Vector3(-1, 0, 0),
	]
	for leg in range(dirs_local.size()):
		var wdir: Vector3 = (xf.basis * dirs_local[leg]).normalized()
		var prev_p := walker.global_position
		var still := 0
		for f in range(400):
			await physics_frame
			total_frames += 1
			var vel := walker.velocity
			vel.x = wdir.x * 3.5
			vel.z = wdir.z * 3.5
			vel.y = -1.0 if walker.is_on_floor() else walker.velocity.y - 20.0 * (1.0 / 60.0)
			walker.velocity = vel
			walker.move_and_slide()
			if walker.is_on_floor():
				walker.velocity.y = 0.0
			if walker.global_position.distance_to(prev_p) < 0.003:
				still += 1
				if still >= 8:
					break
			else:
				still = 0
				prev_p = walker.global_position
	var wasd_local := rig.global_transform.affine_inverse() * walker.global_position
	if wasd_local.y < 10.8:
		_fail("WASD puro no alcanzo la cubierta (pos_local=%s)" % str(wasd_local))

	# Verificar que al posarse sobre un bloque de cemento los pies quedan a ~1.94 m (no flotando a ~2.97 m).
	if wall_vis != null:
		walker.velocity = Vector3.ZERO
		walker.global_position = wall_vis.global_position + Vector3(0.0, 2.30, 0.0)
		for f in range(60):
			await physics_frame
			walker.velocity = Vector3(0.0, -1.0 if walker.is_on_floor() else walker.velocity.y - 20.0 * (1.0 / 60.0), 0.0)
			walker.move_and_slide()
		var feet_above_wall := walker.global_position.y - wall_vis.global_position.y
		if absf(feet_above_wall - 1.90) > 0.08:
			_fail("pies sobre bloque de cemento a %.2f m (esperado ~1.90 m)" % feet_above_wall)

	if failures == 0:
		print("WATCHTOWER_CLIMB_OK frames=%d y=%.2f wasd_y=%.2f pos=%s" % [total_frames, deck_local.y, wasd_local.y, str(deck_local)])
	print("WATCHTOWER_ERRORS=", failures)
	quit(1 if failures else 0)
