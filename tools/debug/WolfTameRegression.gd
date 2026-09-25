extends SceneTree

# Regresión de domesticación de lobos: alimentación, confianza, recelo,
# seguimiento, comandos, defensa contra lobos y jugadores, y luto del dueño.

class TestWorld extends Node3D:
	var removed_actions: Array = []
	var recorded_wolves := {}
	var cleared_wolves: Array = []

	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array:
		return [goal]
	func is_wildlife_allowed_at(_pos: Vector3) -> bool:
		return true
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0
	func _net_item_picked_up(action_id: String) -> void:
		removed_actions.append(action_id)
		for c in get_children():
			if c.get("action_id") == action_id:
				c.queue_free()
	func _record_tamed_wolf(feeder_id: String, wolf_name: String) -> void:
		recorded_wolves[feeder_id] = wolf_name
	func _clear_tamed_wolf_record(feeder_id: String) -> void:
		cleared_wolves.append(feeder_id)

class TestPlayer extends Node3D:
	signal notice(text)
	var is_dead := false
	var notices: Array = []
	func _init() -> void:
		notice.connect(func(t): notices.append(t))

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
var _meat_count := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func make_wolf(world: Node, pos: Vector3) -> TestWolf:
	var w := TestWolf.new()
	w.name = "Wolf_%d" % randi()
	world.add_child(w)
	w.add_to_group("wildlife")
	w.add_to_group("wildlife_wolf")
	w.animal_type = "wolf"
	w.move_speed = 2.0
	w.health = 240.0
	w.max_health = 240.0
	w.patrol_points = [pos, pos + Vector3(6, 0, 0)]
	w.position = pos
	w._wolf_hunger = 90.0
	w._wolf_hunger_threshold = 70.0
	w.set_process(false)
	return w

func spawn_meat(world: Node, pos: Vector3, feeder_id: String) -> WorldAction:
	_meat_count += 1
	var a := WorldAction.new()
	var id := "meat_test_%d" % _meat_count
	a.setup(id, "eat_food", "Carne cruda de lobo", Vector3(0.5, 0.4, 0.5), Color(0.4, 0.1, 0.1), false, false)
	a.position = pos
	world.add_child(a)
	a.set_meta("dropped_by", feeder_id)
	a.set_meta("wolf_food", true)
	a.add_to_group("wolf_meat_pickups")
	return a

func make_proxy(world: Node, pid: int, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = "ServerProxy_%d" % pid
	p.add_to_group("net_player_proxy")
	p.set_meta("peer_id", pid)
	p.set_meta("has_real_pos", true)
	p.position = pos
	world.add_child(p)
	return p

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	var player := TestPlayer.new()
	player.name = "Player"
	player.position = Vector3(10, 0, 0)
	world.add_child(player)

	# --- 1. Alimentar cerca suma confianza; alimentar lejos no ---
	var wolf := make_wolf(world, Vector3.ZERO)
	var meat1 := spawn_meat(world, Vector3(2, 0, 0), "local")
	wolf._consume_meat_pickup(meat1)
	check(int(wolf._tame_progress.get("local", 0)) == 1, "Feeding close increments progress")
	player.global_position = Vector3(60, 0, 0)
	var meat2 := spawn_meat(world, Vector3(2, 0, 1), "local")
	wolf._consume_meat_pickup(meat2)
	check(int(wolf._tame_progress.get("local", 0)) == 1, "Feeding with feeder >15m away does not count")
	player.global_position = Vector3(10, 0, 0)

	# --- 2. Otro jugador (proxy) tiene su propio progreso ---
	var proxy7 := make_proxy(world, 7, Vector3(5, 0, 0))
	var meat7 := spawn_meat(world, Vector3(1, 0, 0), "7")
	wolf._consume_meat_pickup(meat7)
	check(int(wolf._tame_progress.get("7", 0)) == 1, "Other player's feeding has its own counter")
	check(int(wolf._tame_progress.get("local", 0)) == 1, "Feeding by another does not merge")

	# --- 3. Quien alimenta deja de ser presa (recelo) ---
	wolf._resolve_player()
	check(wolf._player != proxy7, "Feeder proxy is never a chase target")
	check(wolf._player == null, "Local feeder is not a chase target either")
	wolf._wolf_ai(0.05)
	check(wolf._state == "wary", "Wolf enters wary state near a feeder")
	var wary_dist_before := wolf.global_position.distance_to(player.global_position)
	check(wary_dist_before > 0.0, "Wary wolf keeps distance instead of approaching to attack")

	# --- 4. Golpear al lobo pierde la confianza ---
	wolf.take_damage(5.0, false, player)
	check(not wolf._tame_progress.has("local"), "Attacking the wolf clears that player's trust")
	check(wolf._tame_progress.has("7"), "Other feeders keep their trust")

	# --- 5. Tres comidas validas -> domesticado ---
	var wolf2 := make_wolf(world, Vector3(0, 0, 40))
	player.global_position = wolf2.global_position + Vector3(3, 0, 0)
	for i in range(3):
		var m := spawn_meat(world, wolf2.global_position + Vector3(1, 0, 0), "local")
		wolf2._consume_meat_pickup(m)
	check(wolf2.tamed_to == "local", "Three feedings tame the wolf to the local player")
	check(wolf2._state == "follow" or wolf2._state == "guard", "Tamed wolf enters follow state")
	check(wolf2._tame_progress.is_empty(), "Progress resets after taming")

	# --- 6. Seguir al dueno ---
	var follow_res := wolf2._wolf_ai(0.05)
	check(bool(follow_res.get("handled", false)), "Tamed AI handles the movement")
	check(follow_res["target"].distance_to(player.global_position) < 6.0, "Follow target stays near the owner")
	check(follow_res["speed"] > 0.0, "Tamed wolf moves toward a distant owner")
	# Ya en su sitio -> quieto
	wolf2.global_position = player.global_position + Vector3(2.0, 0, 0)
	var near_res := wolf2._wolf_ai(0.05)
	check(near_res["speed"] == 0.0, "Tamed wolf idles once it reached the owner")

	# --- 7. Comando Quieto / Seguir solo del dueno ---
	wolf2.interact(player)
	check(wolf2._follow_mode == "stay", "Owner command toggles to stay")
	check(wolf2._stay_pos.distance_to(wolf2.global_position) < 0.5, "Stay anchors the current position")
	player.global_position = Vector3(80, 0, 0)
	var stay_res := wolf2._wolf_ai(0.05)
	check(stay_res["speed"] == 0.0 or stay_res["target"].distance_to(wolf2._stay_pos) < 6.0, "Stay keeps the wolf at its post")
	var stranger := TestPlayer.new()
	stranger.name = "OtherPlayer"
	stranger.position = wolf2.global_position + Vector3(1, 0, 0)
	world.add_child(stranger)
	var mode_before: String = wolf2._follow_mode
	wolf2.interact(stranger)
	check(wolf2._follow_mode == mode_before, "Non-owner cannot command the wolf")
	wolf2.interact(player)
	check(wolf2._follow_mode == "follow", "Owner toggles back to follow")

	# --- 8. Defensa contra un lobo salvaje que persiga al dueno ---
	player.global_position = Vector3(80, 0, 0)
	wolf2.global_position = player.global_position + Vector3(2, 0, 0)
	var wild := make_wolf(world, player.global_position + Vector3(10, 0, 0))
	wild._player = player
	wild._chase_target = player
	wild._state = "chase_player"
	wolf2._cached_wildlife = [wild]
	wolf2._wolf_ai(0.05)
	check(wolf2._wolf_foe == wild, "Tamed wolf intercepts the wild wolf chasing its owner")
	wolf2.global_position = wild.global_position + Vector3(2, 0, 0)
	wolf2._attack_cooldown = 0.0
	var wild_hp_before := wild.health
	wolf2._wolf_ai(0.05)
	check(wild.health < wild_hp_before, "Tamed wolf bites the wild wolf in melee range")
	check(wild._wolf_foe == wolf2, "Wild wolf retaliates against the tamed wolf")
	# Mismo dueno -> sin fuego amigo
	var wolf3 := make_wolf(world, wolf2.global_position + Vector3(2, 0, 0))
	wolf3.tamed_to = "local"
	wolf2._wolf_foe = null
	wolf3.take_damage(10.0, false, wolf2)
	check(wolf3._wolf_foe != wolf2, "Wolves of the same owner do not fight each other")

	# --- 9. Defensa contra jugador hostil ---
	var hostile := make_proxy(world, 9, wolf2.global_position + Vector3(8, 0, 0))
	wolf2._wolf_foe = null
	wolf2._cached_wildlife = []  # el lobo salvaje del test anterior sigue "persiguiendo" al dueno
	wolf2.notify_threat(hostile, 20.0)
	wolf2._chase_cooldown = 0.0
	var threat_res := wolf2._wolf_ai(0.05)
	check(not bool(threat_res.get("handled", false)), "Active threat falls through to the normal chase")
	check(wolf2._player == hostile, "Threat becomes the chase target")
	wolf2._wolf_ai(0.05)
	check(wolf2._state == "chase_player", "Wolf chases the hostile player")
	# Amenaza muerta -> deja de perseguir
	hostile.set_meta("proxy_dead", true)
	wolf2._wolf_ai(0.05)
	check(wolf2._threat_player == null, "Dead threat is cleared")
	hostile.set_meta("proxy_dead", false)
	# El dueno jamas es amenaza
	wolf2.notify_threat(player, 20.0)
	check(wolf2._threat_player == null or wolf2._threat_player != player, "Wolf never treats its owner as a threat")
	# Un atacante del lobo domesticado se convierte en amenaza (defensa propia)
	var hostile2 := make_proxy(world, 10, wolf2.global_position + Vector3(6, 0, 0))
	wolf2._threat_player = null
	wolf2.take_damage(5.0, false, hostile2)
	check(wolf2._threat_player == hostile2, "Attacking a tamed wolf makes you its threat")

	# --- 9.5. Un jugador solo puede tener un lobo domesticado ---
	var wolf_second := make_wolf(world, player.global_position + Vector3(5, 0, 0))
	player.global_position = wolf_second.global_position + Vector3(3, 0, 0)
	for i in range(3):
		var m := spawn_meat(world, wolf_second.global_position + Vector3(1, 0, 0), "local")
		wolf_second._consume_meat_pickup(m)
	check(wolf_second.tamed_to == "", "A second wolf does not tame while the owner already has one")
	check(int(wolf_second._tame_progress.get("local", 0)) >= 3, "The second wolf still trusts the player")
	stranger.free()

	# --- 10. Muerte del dueno: luto y vuelta a lo salvaje ---
	wolf2._threat_player = null
	wolf2._wolf_foe = null
	player.is_dead = true
	wolf2._wolf_ai(0.05)
	check(wolf2._state == "guard", "Dead owner: wolf guards the corpse")
	wolf2._owner_dead_timer = wolf2.TAME_GUARD_SECONDS
	wolf2._wolf_ai(0.05)
	check(wolf2.tamed_to == "", "After mourning the wolf turns wild again")

	# --- 11. Lobo domesticado puede ser despellejado al morir (corpse flow intacto) ---
	wolf2.tamed_to = "local"
	wolf2.take_damage(999.0, false, hostile2)
	check(wolf2._is_dead, "Tamed wolf can die")
	check(world.cleared_wolves.has("local"), "Owner record cleared on wolf death")

	# --- 12. Registro en el servidor (peer_id) ---
	var wolf4 := make_wolf(world, Vector3(0, 0, 80))
	var proxy11 := make_proxy(world, 11, wolf4.global_position + Vector3(4, 0, 0))
	for i in range(3):
		var m := spawn_meat(world, wolf4.global_position + Vector3(1, 0, 0), "11")
		wolf4._consume_meat_pickup(m)
	check(wolf4.tamed_to == "11", "Proxy player can tame a wolf")
	check(world.recorded_wolves.get("11", "") == wolf4.name, "Server records the tamed wolf by peer id")
	wolf4._go_wild()
	check(world.cleared_wolves.has("11"), "Going wild clears the server record")

	world.free()
	if failures == 0:
		print("WolfTameRegression: ALL PASS")
	quit(1 if failures else 0)
