extends SceneTree

# Regresión: un lobo u oso SALVAJE debe fijar y morder a un jugador solo en
# campo abierto — sin domados, sin cebo, sin protecciones. Cubre el síntoma
# "los salvajes no atacan al personaje, van arriba y abajo": si alguna puerta
# bloquea el chase, el animal solo merodea.

class TestWorld extends Node3D:
	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array:
		return [goal]
	func find_path_wolf(_start: Vector3, goal: Vector3) -> Array:
		return [goal]
	func is_wildlife_allowed_at(_pos: Vector3) -> bool:
		return true
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0
	func _is_pos_wolf_protected(_pos: Vector3) -> bool:
		return false
	func _is_near_lit_campfire(_pos: Vector3, _r: float) -> bool:
		return false

class TestPlayer extends Node3D:
	var is_dead := false
	var hits: Array = []
	func apply_damage(amount: float, _kind: String = "") -> void:
		hits.append(amount)
	func _play_hit_reaction(_h: bool) -> void:
		pass

class TestWolf extends WildlifeController:
	func _play_wolf_sound(_kind: String) -> void:
		pass
	func _update_wolf_sounds(_delta: float) -> void:
		pass
	func _spawn_blood_splatter() -> void:
		pass
	func _play_pain_sound() -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func make_animal(world: Node, pos: Vector3, kind: String) -> TestWolf:
	var w := TestWolf.new()
	w.name = "%s_%d" % [kind, randi()]
	world.add_child(w)
	w.add_to_group("wildlife")
	w.animal_type = kind
	w.move_speed = 2.0
	if kind == "bear":
		w.health = 650.0
		w.max_health = 650.0
	else:
		w.health = 240.0
		w.max_health = 240.0
	w.patrol_points = [pos, pos + Vector3(6, 0, 0)]
	w.position = pos
	w._wolf_hunger = 90.0
	w._wolf_hunger_threshold = 70.0
	w.set_process(false)
	return w

# Simula N segundos de IA + movimiento hacia el target devuelto.
func sim(wolf: TestWolf, seconds: float, dt: float = 0.05) -> void:
	var steps := int(seconds / dt)
	for i in range(steps):
		var res := wolf._wolf_ai(dt)
		var target: Vector3 = res.get("target", wolf.global_position)
		var speed: float = res.get("speed", 0.0)
		if speed > 0.0:
			wolf.global_position = wolf.global_position.move_toward(target, speed * dt)
		wolf._attack_cooldown = maxf(0.0, wolf._attack_cooldown - dt)
		wolf._chase_cooldown = maxf(0.0, wolf._chase_cooldown - dt)
		wolf._foe_timer = maxf(0.0, wolf._foe_timer - dt)
		wolf._prey_flee_timer = maxf(0.0, wolf._prey_flee_timer - dt)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	# --- Lobo salvaje vs jugador solo a 20 m: debe perseguir y morder ---
	var player := TestPlayer.new()
	player.name = "Player"
	player.position = Vector3.ZERO
	world.add_child(player)

	var wolf := make_animal(world, Vector3(20, 0, 0), "wolf")
	wolf._resolve_player()
	check(wolf._player == player, "Wild wolf selects the lone player as target")
	sim(wolf, 2.0)
	check(wolf._state == "chase_player", "Wild wolf enters chase_player (got %s)" % wolf._state)
	sim(wolf, 20.0)
	check(player.hits.size() > 0, "Wild wolf lands at least one bite on the player (got %d hits)" % player.hits.size())
	check(wolf.global_position.distance_to(player.global_position) < 12.0, "Wild wolf closes on the player (dist %.1f)" % wolf.global_position.distance_to(player.global_position))

	# --- Oso salvaje vs jugador solo a 30 m: debe avisar y luego cargar ---
	var player2 := TestPlayer.new()
	player2.name = "Player"
	# Reemplaza el nodo Player anterior para que _resolve_player lo coja
	world.remove_child(player)
	world.add_child(player2)
	player2.position = Vector3(100, 0, 0)
	player.queue_free()

	var bear := make_animal(world, Vector3(130, 0, 0), "bear")
	bear._resolve_player()
	check(bear._player == player2, "Wild bear selects the lone player as target")
	sim(bear, 6.0)
	check(bear._state in ["chase_player", "bear_warn"], "Wild bear warns or chases (got %s)" % bear._state)
	sim(bear, 25.0)
	check(player2.hits.size() > 0, "Wild bear lands at least one swipe (got %d hits)" % player2.hits.size())
	check(bear.global_position.distance_to(player2.global_position) < 14.0, "Wild bear closes on the player (dist %.1f)" % bear.global_position.distance_to(player2.global_position))

	# --- Lobo que fija un domado inalcanzable: debe soltarlo y volver al jugador ---
	var player3 := TestPlayer.new()
	player3.name = "Player"
	world.remove_child(player2)
	world.add_child(player3)
	player3.position = Vector3(200, 0, 0)
	player2.queue_free()

	var wolf3 := make_animal(world, Vector3(225, 0, 0), "wolf")
	var tamed := make_animal(world, Vector3(215, 0, 0), "wolf")
	tamed.tamed_to = "7"
	# El domado queda a 10 m pero huye mas rapido de lo que el salvaje lo muerde:
	# lo movemos a 30 m del jugador cada paso para simular que no lo alcanza.
	wolf3._resolve_player()
	sim(wolf3, 3.0)
	if wolf3._wolf_foe != null:
		# Persecución fútil: el foe queda siempre fuera de alcance
		for i in range(300):
			if wolf3._wolf_foe == null:
				break
			var res := wolf3._wolf_ai(0.05)
			var speed: float = res.get("speed", 0.0)
			var tgt: Vector3 = res.get("target", wolf3.global_position)
			if speed > 0.0:
				wolf3.global_position = wolf3.global_position.move_toward(tgt, speed * 0.05)
			# El domado se mantiene a 12 m: nunca alcanzado a morder
			var away := (tamed.global_position - wolf3.global_position).normalized()
			if away.length_squared() < 0.01:
				away = Vector3.RIGHT
			tamed.global_position = wolf3.global_position + away * 12.0
			wolf3._foe_engaged += 0.05
	check(wolf3._wolf_foe == null or wolf3._foe_engaged > 0.0, "Futile wolf-vs-wolf chase is dropped")
	if wolf3._wolf_foe == null:
		sim(wolf3, 3.0)
		check(wolf3._player == player3 or wolf3._state == "chase_player", "After dropping the futile foe the wolf hunts the player (state %s)" % wolf3._state)

	# --- Oso + manada de lobos salvajes: un golpe oso->lobo jamás debe secuestrar
	# _player con un WildlifeController ni impedir que ambos ataquen al jugador ---
	world.remove_child(player3)
	player3.queue_free()
	var pack_bear := make_animal(world, Vector3(320, 0, 0), "bear")
	pack_bear._wolf_hunger = 30.0
	var pack_wolf_a := make_animal(world, Vector3(300, 0, 0), "wolf")
	var pack_wolf_b := make_animal(world, Vector3(296, 0, 0), "wolf")
	var pack_list: Array = [pack_bear, pack_wolf_a, pack_wolf_b]
	pack_bear._cached_wildlife = pack_list
	pack_wolf_a._cached_wildlife = pack_list
	pack_wolf_b._cached_wildlife = pack_list
	# El oso muerde a pack_wolf_a antes de que haya jugador conectado:
	pack_wolf_a.take_damage(60.0, false, pack_bear)
	check(not (pack_wolf_a._player is WildlifeController), "Wolf hit by bear must not set _player to the bear")
	check(not (pack_wolf_b._player is WildlifeController), "Pack alert from bear hit must not poison packmates' _player with the bear")
	check(pack_bear._find_nearest_prey() == null, "Hungry bear ignores wild wolves as hunting prey")

	# Ahora se conecta un jugador (proxy del servidor) cerca de ellos:
	var proxy := Node3D.new()
	proxy.name = "ServerProxy_2"
	proxy.position = Vector3(292, 0, 0)
	proxy.set_meta("peer_id", 2)
	proxy.set_meta("protection_timer", 0.0)
	proxy.set_meta("has_real_pos", true)
	proxy.set_meta("disconnected", false)
	proxy.set_meta("reconnecting", false)
	proxy.set_meta("proxy_health", 100.0)
	proxy.set_meta("proxy_dead", false)
	world.add_child(proxy)
	proxy.add_to_group("net_player_proxy")

	pack_wolf_b._resolve_player()
	pack_bear.position = Vector3(278, 0, 0)
	pack_bear.patrol_points = [Vector3(278, 0, 0), Vector3(282, 0, 0)]
	pack_bear._resolve_player()
	check(pack_wolf_b._player == proxy, "Wild wolf selects connected server proxy after bear encounter")
	check(pack_bear._player == proxy, "Wild bear selects connected server proxy")
	sim(pack_wolf_b, 2.0)
	sim(pack_bear, 2.0)
	check(pack_wolf_b._state == "chase_player", "Wild wolf chases player even with a bear 20m away when player is closer (got %s)" % pack_wolf_b._state)
	check(pack_bear._state in ["chase_player", "bear_warn"], "Wild bear engages player instead of chasing wild wolves (got %s)" % pack_bear._state)

	if failures == 0:
		print("WildPlayerChaseRegression: ALL PASS")
	else:
		print("WildPlayerChaseRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
