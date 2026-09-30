extends SceneTree

# Regresión de domesticación de lobos: alimentación, confianza, recelo,
# seguimiento, comandos, defensa contra lobos y jugadores, y luto del dueño.

class TestWorld extends Node3D:
	var removed_actions: Array = []
	var recorded_wolves := {}
	var cleared_wolves: Array = []
	var blocked_goal := Vector3.INF

	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array:
		return [] if goal == blocked_goal else [goal]
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

class ServerWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _delayed_send_saved_appearance(_peer_id: int, _cid: String) -> void:
		pass
	func _delayed_send_spawn_pos(_peer_id: int, _pos: Vector3, _died: bool = false) -> void:
		pass
	func _delayed_send_reconnect_state(_peer_id: int, _pos: Vector3, _inv: Array, _hp: float, _hunger: float, _thirst: float, _clothing: String, _backpack: String, _held_item: String, _held_idx: int, _sleeping: bool, _sitting: bool, _rot: float, _prone: bool = false, _crouching: bool = false, _extra: Dictionary = {}) -> void:
		pass

class TestBird extends BirdController:
	func _ready() -> void:
		set_process(false)

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
	await test_feeding_priority()
	await test_server_persistence()
	if failures == 0:
		print("WolfTameRegression: ALL PASS")
	quit(1 if failures else 0)

func test_feeding_priority() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var player := TestPlayer.new()
	player.name = "Player"
	world.add_child(player)
	player.position = Vector3(10, 0, 0)
	var wolf := make_wolf(world, Vector3.ZERO)
	wolf._wolf_hunger = 20.0
	for i in range(3):
		var meat := spawn_meat(world, Vector3(1, 0, 0), "local")
		wolf._process(0.5)
		check(wolf._wolf_eating_target == meat, "Real AI accepts nearby offering %d before attacking feeder" % (i + 1))
		if wolf._wolf_eating_target != meat:
			break
		wolf._process(8.0)
		check(world.removed_actions.has(meat.action_id), "Eating actually consumes the offered pickup")
		await process_frame
	check(wolf.tamed_to == "local", "Three real AI feeding cycles tame the wolf")
	wolf.free()
	wolf = make_wolf(world, Vector3.ZERO)
	var food := spawn_meat(world, Vector3(1, 0, 0), "local")
	wolf._resolve_player()
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "A full wolf is not pacified by an offering")
	wolf._wolf_hunger = 20.0
	food.remove_meta("dropped_by")
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "Unattributed meat does not suppress an attack")
	food.set_meta("dropped_by", "local")
	player.position = Vector3(20, 0, 0)
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "A distant offering does not pacify the wolf")
	player.position = Vector3(10, 0, 0)
	food.depleted = true
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "Depleted food cannot distract the wolf")
	food.depleted = false
	world.blocked_goal = food.global_position
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "Unreachable food does not suppress pursuit")
	world.blocked_goal = Vector3.INF
	food.position = Vector3(5, 0, 0)
	var approach := wolf._wolf_ai(0.05)
	check(wolf._state == "seek_corpse" and approach["target"] == food.global_position, "Hungry wolf approaches a reachable offering")
	wolf._prey_flee_timer = 5.0
	wolf._wolf_ai(0.05)
	check(wolf._wolf_eating_target == null, "Food does not cancel fleeing after an attack")
	player.is_dead = true
	wolf._register_feeding("local")
	check(wolf._tame_progress.is_empty(), "A dead player cannot gain feeding trust")
	player.is_dead = false
	wolf._prey_flee_timer = 0.0
	var proxy := make_proxy(world, 7, Vector3(10, 0, 0))
	food.set_meta("dropped_by", "7")
	food.position = Vector3(1, 0, 0)
	wolf._player = null
	wolf._resolve_player()
	wolf._wolf_ai(0.05)
	check(wolf._wolf_eating_target == food, "Real AI also accepts a remote player's first offering")
	proxy.set_meta("disconnected", true)
	wolf._process(8.0)
	check(not wolf._tame_progress.has("7"), "Disconnecting before the meal ends grants no trust")
	world.free()

func sync_inventory(world: ServerWorld, pid: int, extra: Dictionary) -> void:
	world._store_player_inventory(pid, [], 100.0, 100.0, 100.0, "", "", "", -1, false, false, 0.0, false, false, extra)

func test_server_persistence() -> void:
	var world := ServerWorld.new()
	root.add_child(world)
	current_scene = world
	var net := root.get_node("NetworkManager")
	world.net = net
	net.is_host = true
	net.players = {7: {"client_id": "wolf_owner"}, 11: {"client_id": "other_owner"}}
	var owner := make_proxy(world, 7, Vector3(4, 0, 0))
	owner.set_meta("client_id", "wolf_owner")
	world.server_proxies[7] = owner
	world._server_saved_players["wolf_owner"] = {"extra": {}}
	var wolf := make_wolf(world, Vector3.ZERO)
	for i in range(3):
		wolf._register_feeding("7")
	check(owner.get_meta("saved_extra", {}).get("tamed_wolf", "") == wolf.name, "Taming records the wolf on the real server proxy")
	var extra := {"stats_extra": {"sleep": 80.0}, "tamed_wolf": "untrusted_wolf"}
	sync_inventory(world, 7, extra)
	check(owner.get_meta("saved_extra", {}).get("tamed_wolf", "") == wolf.name, "Inventory sync cannot replace server-owned wolf identity")
	check(extra["tamed_wolf"] == "untrusted_wolf", "Sanitizing the wolf record does not mutate the incoming payload")
	sync_inventory(world, 7, {"stats_extra": {"sleep": 75.0}})
	check(owner.get_meta("saved_extra", {}).get("tamed_wolf", "") == wolf.name, "Inventory sync without a wolf preserves the bond")
	check(owner.get_meta("saved_extra", {}).get("stats_extra", {}).get("sleep") == 75.0, "Client survival stats still update")
	wolf.apply_command("stay")
	var stay_pos := wolf._stay_pos
	world.server_proxies.erase(7)
	world.proxy_by_client_id["wolf_owner"] = owner
	owner.set_meta("disconnected", true)
	net.players.erase(7)
	net.players[9] = {"client_id": "wolf_owner"}
	wolf._owner_node = null
	world._match_proxy_to_client(9, "wolf_owner")
	await process_frame
	check(wolf.tamed_to == "9", "Actual reconnect rebinds the wolf to the new peer")
	check(wolf._resolve_owner() == owner, "Reconnected wolf resolves the correct owner proxy")
	check(wolf._follow_mode == "stay" and wolf._stay_pos == stay_pos, "Reconnect preserves the stay command and position")
	world._net_command_wolf(wolf.name, "follow", 11)
	check(wolf._follow_mode == "stay", "Another player cannot command the reconnected wolf")
	world._net_command_wolf(wolf.name, "follow", 9)
	check(wolf._follow_mode == "follow", "Reconnected owner can command its wolf")
	wolf.notify_threat(owner)
	check(wolf._threat_player == null, "Reconnected owner is never treated as a threat")
	var second := make_wolf(world, Vector3(1, 0, 0))
	for i in range(3):
		second._register_feeding("9")
	check(second.tamed_to.is_empty(), "Reconnect does not allow taming a second wolf")

	var other := make_proxy(world, 11, Vector3(3, 0, 0))
	other.set_meta("client_id", "other_owner")
	world.server_proxies[11] = other
	world._restore_tamed_wolf(11, wolf.name)
	check(wolf.tamed_to == "9", "Restoration cannot steal another player's wolf")
	var bird := TestBird.new()
	world.add_child(bird)
	bird.add_to_group("wildlife")
	var deer := make_wolf(world, Vector3(20, 0, 0))
	deer.animal_type = "deer"
	var data := SaveGameHooks.collect_world_data(world)
	var entries: Array = data.get("tamed_wildlife", [])
	check(entries.size() == 1, "World collection with birds and wild animals saves only the tamed wolf")
	if entries.size() == 1:
		var restored := make_wolf(world, Vector3(30, 0, 0))
		SaveGameHooks._apply_tamed_wildlife_entry(restored, entries[0])
		check(restored.tamed_to == wolf.tamed_to and restored.health == wolf.health, "Tamed wolf state survives a world-data round trip")
		check(restored._wolf_hunger == wolf._wolf_hunger and restored._stay_pos == wolf._stay_pos, "Hunger and stay position survive the round trip")
		check(restored._owner_client_id == "wolf_owner", "Persistent owner identity survives the round trip")
		var local_entry: Dictionary = entries[0].duplicate(true)
		local_entry.erase("owner_client_id")
		local_entry["owner"] = "local"
		local_entry["mode"] = "stay"
		SaveGameHooks._apply_tamed_wildlife_entry(restored, local_entry)
		check(restored.tamed_to == "local" and restored._follow_mode == "stay", "Existing single-player saves without client identity still restore")
		restored.free()

	world.server_proxies.erase(9)
	world.proxy_by_client_id["wolf_owner"] = owner
	owner.set_meta("disconnected", true)
	net.players.erase(9)
	wolf._go_wild()
	check(not owner.get_meta("saved_extra", {}).has("tamed_wolf"), "Going wild clears a disconnected owner's proxy record")
	check(not world._server_saved_players["wolf_owner"].get("extra", {}).has("tamed_wolf"), "Going wild clears the offline owner's saved baseline")
	world.proxy_by_client_id.erase("wolf_owner")
	world.server_proxies[9] = owner
	owner.set_meta("reconnecting", false)
	sync_inventory(world, 9, {"tamed_wolf": str(wolf.name)})
	check(not owner.get_meta("saved_extra", {}).has("tamed_wolf"), "A stale client snapshot cannot recreate a released bond")
	world._restore_tamed_wolf(9, wolf.name)
	check(wolf.tamed_to.is_empty(), "A stale restore cannot retame a released wolf")
	net.players[9] = {"client_id": "wolf_owner"}
	owner.set_meta("disconnected", false)
	for i in range(3):
		wolf._register_feeding("9")
	check(wolf.tamed_to == "9", "The same owner can tame the released wolf again normally")
	wolf.take_damage(999.0, false, other)
	check(not owner.get_meta("saved_extra", {}).has("tamed_wolf"), "Wolf death clears the real server proxy record")
	check(not world._server_saved_players["wolf_owner"].get("extra", {}).has("tamed_wolf"), "Wolf death clears the real saved baseline")
	world._restore_tamed_wolf(11, wolf.name)
	check(wolf._is_dead and wolf.tamed_to != "11", "Restoration cannot revive or transfer a dead wolf")
	world.free()
	net.players.clear()
	net.is_host = false
