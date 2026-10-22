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
	var scale_value := 0.85
	var tower_pos := Vector3(50.0, 3.0, 120.0)
	world._build_military_watchtower_collision(tower_pos, Vector3.ONE * scale_value)

	var rig := world.get_node_or_null("MilitaryBaseWatchTowerCol") as Node3D
	if rig == null:
		_fail("no se creo el rig de colision")
		print("WATCHTOWER_ERRORS=", failures)
		quit(1)
		return
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
		["rampa1", Vector3(-1.0, 1.55, -2.55), true],
		["rampa1_top", Vector3(-1.95, 2.00, -2.55), true],
		["descanso1", Vector3(-2.62, 2.00, -2.62), false],
		["rampa2", Vector3(-2.55, 3.10, 0.0), true],
		["descanso2", Vector3(-2.62, 4.25, 2.62), false],
		["rampa3", Vector3(0.0, 5.38, 2.55), true],
		["descanso3", Vector3(2.62, 6.50, 2.62), false],
		["rampa4", Vector3(2.55, 7.60, 0.30), true],
		["pasillo", Vector3(2.60, 8.75, -1.90), false],
		["rampa5", Vector3(0.6, 9.63, -2.85), true],
		["cubierta", Vector3(-0.5, 11.08, 0.6), false],
		["cubierta_tira", Vector3(-2.55, 11.08, -2.65), false],
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
	# su centro topa con la rampa (~y9.7 local), no con suelo de cubierta (~11.1).
	var hole_hit := _ray(w3d, xf * Vector3(0.6, 13.0, -2.7), xf * Vector3(0.6, 5.0, -2.7))
	if hole_hit.is_empty():
		_fail("el hueco de la cubierta no golpea la rampa final")
	else:
		var hy: float = (rig.global_transform.affine_inverse() * (hole_hit.position as Vector3)).y
		if hy > 10.5:
			_fail("el hueco de la cubierta esta tapado (hit y=%.2f)" % hy)

	# Capsula jugador subiendo el recorrido completo con fisica real.
	var walker := CharacterBody3D.new()
	walker.floor_max_angle = deg_to_rad(65.0)
	walker.floor_snap_length = 0.25
	var wcol := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.70
	wcol.shape = capsule
	wcol.position.y = 0.85
	walker.add_child(wcol)
	root.add_child(walker)
	# Entrada por el hueco entre patas de la cara -z hasta el pie de la rampa 1.
	var path: Array[Vector2] = [
		Vector2(0.8, -2.55), Vector2(-0.6, -2.55),
		Vector2(-1.4, -2.55), Vector2(-2.5, -2.5),
		Vector2(-2.55, -1.2), Vector2(-2.55, 0.6), Vector2(-2.55, 1.9),
		Vector2(-2.6, 2.9), Vector2(-1.6, 2.55), Vector2(0.0, 2.55),
		Vector2(1.9, 2.55), Vector2(2.6, 2.6),
		Vector2(2.55, 1.5), Vector2(2.55, 0.0), Vector2(2.55, -1.6),
		Vector2(2.2, -2.45), Vector2(1.6, -2.85), Vector2(0.4, -2.85),
		Vector2(-0.9, -2.85), Vector2(-2.4, -2.6),
		Vector2(-2.4, -1.2), Vector2(-2.4, 0.8),
	]
	walker.global_position = xf * Vector3(1.6, 1.145, -2.55) + Vector3.UP * 0.2
	var wp := 0
	var frames := 0
	var max_frames := 4000
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
		var speed := 3.0
		var vel := walker.velocity
		vel.x = dir.x * speed
		vel.z = dir.y * speed
		vel.y = -0.2 if walker.is_on_floor() else walker.velocity.y - 20.0 * (1.0 / 60.0)
		walker.velocity = vel
		walker.move_and_slide()
	if wp < path.size():
		_fail("la capsula no completo el recorrido (parada en punto %d de %d)" % [wp, path.size()])
	var deck_local := rig.global_transform.affine_inverse() * walker.global_position
	if deck_local.y < 10.4:
		_fail("la capsula no alcanzo la cubierta (y local %.2f)" % deck_local.y)
	if wp >= path.size() and deck_local.y >= 10.4:
		print("WATCHTOWER_CLIMB_OK frames=%d y=%.2f" % [frames, deck_local.y])
	print("WATCHTOWER_ERRORS=", failures)
	quit(1 if failures else 0)
