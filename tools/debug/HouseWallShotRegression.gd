extends SceneTree
## Regresion: los disparos de bots no atraviesan paredes ni techos.
## 1) _has_clear_shot (mascara 5, igual que RifleProjectile) bloquea muros
##    capa 1 y techos capa 4, y deja pasar huecos reales de ventana.
## 2) _create_house(collision_only) — la cascara que levanta el servidor
##    dedicado — bloquea muro/techo, bloquea la puerta cerrada y deja pasar
##    el tiro por el vano con la puerta abierta.

var _failures := 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  " + msg)
	else:
		_failures += 1
		print("FAIL  " + msg)

func _wall(name: String, pos: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.collision_layer = layer
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	body.add_child(col)
	root.add_child(body)
	return body

func _init() -> void:
	await process_frame
	await physics_frame
	await physics_frame

	var mgr := preload("res://scripts/SurvivorBotManager.gd").new()
	var world := Node3D.new()
	root.add_child(world)
	root.add_child(mgr)
	mgr.world = world

	# === Pared solida en x=0 (capa 1) ===
	_wall("WallX", Vector3(0, 0, 0), Vector3(0.35, 3.2, 6.0), 1)

	print("-- Pared solida capa 1, altura de pecho --")
	_assert(not mgr._has_clear_shot(Vector3(-5, 0, 0), Vector3(5, 0, 0)),
		"rayo a traves de pared solida queda bloqueado")
	_assert(not mgr._has_clear_shot(Vector3(-5, 0, 2.5), Vector3(5, 0, -2.5)),
		"rayo diagonal a traves de pared solida queda bloqueado")
	_assert(mgr._has_clear_shot(Vector3(-5, 0, 5), Vector3(5, 0, 5)),
		"rayo sin pared en medio queda libre")

	# === Techo en capa 4 (como RoofCollision de las casas) ===
	print("-- Tirador elevado a traves del techo (capa 4) --")
	var roof := StaticBody3D.new()
	roof.name = "Roof"
	roof.position = Vector3(10, 3.2, 0)
	roof.collision_layer = 4
	var rcol := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(6, 0.7, 6)
	rcol.shape = rbox
	rcol.position.y = 0.35
	roof.add_child(rcol)
	root.add_child(roof)
	var clear_roof: bool = mgr._has_clear_shot(Vector3(4, 8.0, 0), Vector3(10, 0.5, 0))
	_assert(not clear_roof, "rayo que cruza el techo (capa 4) queda bloqueado")

	# === Hueco tipo ventana en la pared ===
	print("-- Hueco tipo ventana en la pared --")
	_wall("WinLow", Vector3(20, 0, 0), Vector3(0.35, 0.9, 6.0), 1)
	var up := StaticBody3D.new()
	up.name = "WinHigh"
	up.collision_layer = 1
	var ucol := CollisionShape3D.new()
	var ubox := BoxShape3D.new()
	ubox.size = Vector3(0.35, 1.3, 6.0)
	ucol.shape = ubox
	up.add_child(ucol)
	up.position = Vector3(20, 1.9 + 0.65, 0)
	root.add_child(up)
	_assert(mgr._has_clear_shot(Vector3(15, 0, 0), Vector3(25, 0, 0)),
		"rayo a altura de pecho por el hueco de ventana pasa (apertura real)")
	var q_low := PhysicsRayQueryParameters3D.create(
		Vector3(15, 0.5, 0), Vector3(25, 0.5, 0), 1)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	_assert(not space.intersect_ray(q_low).is_empty(),
		"rayo bajo el hueco choca con el segmento inferior de la pared")

	# === Area3D como "pared" (no debe bloquear nunca) ===
	print("-- Area3D usada como hitbox no bloquea --")
	var area := Area3D.new()
	area.collision_layer = 1
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(0.35, 3.2, 6.0)
	acol.shape = abox
	acol.position.y = 1.6
	area.add_child(acol)
	area.position = Vector3(60, 0, 0)
	root.add_child(area)
	_assert(mgr._has_clear_shot(Vector3(55, 0, 0), Vector3(65, 0, 0)),
		"Area3D en la trayectoria no bloquea el rayo (solo cuerpos)")

	# === Casa real en modo collision_only (lo que crea el servidor dedicado) ===
	print("-- Cascara de casa collision_only (servidor dedicado) --")
	var m := preload("res://scripts/Main.gd").new()
	m._create_house(Vector3(100, 0, 0), "Casa abandonada 1", "house_1", 11.4, 9.4, 4.35, true)
	for c in m.get_children():
		m.remove_child(c)
		world.add_child(c)
	m.queue_free()
	await physics_frame
	await physics_frame
	var horg := Vector3(100, 0, 0)
	_assert(not mgr._has_clear_shot(horg + Vector3(-15, 0, 0), horg),
		"tiro a traves del muro oeste queda bloqueado")
	_assert(not mgr._has_clear_shot(horg, horg + Vector3(15, 0, 0)),
		"tiro de dentro a fuera a traves del muro este queda bloqueado")
	_assert(not mgr._has_clear_shot(horg + Vector3(0, 8, 0), horg),
		"tiro cenital a traves del techo queda bloqueado")
	_assert(not mgr._has_clear_shot(horg + Vector3(2.5, 0, -15), horg + Vector3(2.5, 0, 0)),
		"tiro a traves del muro trasero (bajo la ventana) queda bloqueado")
	# Puerta delantera en z = +half_d = +4.7, vano x en [-0.9, +0.9]
	var door: Node = world.get_node_or_null("Casa abandonada 1 Door")
	_assert(door != null, "el nodo Door existe en collision_only")
	_assert(not mgr._has_clear_shot(horg + Vector3(0, 0, 12), horg),
		"puerta cerrada bloquea el tiro por el vano")
	if door != null:
		door.set_open(true)
		await create_timer(0.45).timeout
		_assert(mgr._has_clear_shot(horg + Vector3(0, 0, 12), horg),
			"puerta abierta deja pasar el tiro por el vano")

	print("")
	if _failures == 0:
		print("RESULT: todas las comprobaciones pasaron")
	else:
		print("RESULT: %d comprobacion(es) fallaron" % _failures)
	quit(1 if _failures > 0 else 0)
