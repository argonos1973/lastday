extends SceneTree

# Regresion del sistema "bots hostiles -> aliados por confianza":
#  - Los 3 bots (Elena 901, Carlos 902, Kael 903) nacen hostiles.
#  - Un hostil armado elige como objetivo a un humano proximo.
#  - La tregua por chat ("alto ahi") crea una pausa de fuego contra el emisor.
#  - "sigueme" con confianza suficiente convierte hostil -> friendly
#    (umbral por personalidad: Kael exige mucho mas que Elena).
#  - Hostilidad/ataques bloquean la conversion.
#  - "te doy pan" retira el item del inventario del jugador y lo da al bot.
#  - La allegiance persiste en memoria y el bot renace friendly.

const SurvivorBotManagerScript = preload("res://scripts/SurvivorBotManager.gd")

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

class FakeDayCycle extends Node:
	var time_of_day := 14.0
	var ambient_temp := 15.0
	var weather_darkness := 0.0
	func get_ambient_temperature() -> float:
		return ambient_temp
	func is_night() -> bool:
		return time_of_day < 6.2 or time_of_day > 19.3

class FakeNet extends Node:
	var is_host := true
	var is_connected := false
	var is_dedicated_server := false
	var peer = null
	var players := {}
	var animals := {}
	var authoritative_weather := {}
	var relay_log: Array = []
	var gift_taken_log: Array = []
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return true
	func snapshot_recipients() -> Array[int]:
		return []
	func relay_actor_chat(sender_id: int, sender_name: String, text: String, target_peer_id: int, target_name: String = "") -> void:
		relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "text": text})
	func bot_gift_taken(item_name: String, item_type: String) -> void:
		gift_taken_log.append({"name": item_name, "type": item_type})

class TestWorld extends "res://scripts/Main.gd":
	var water_rect := Rect2(100000.0, 100000.0, 4.0, 4.0)
	var water_depth := 1.0
	var road_rect := Rect2(200000.0, 200000.0, 4.0, 4.0)
	var river_segs: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float:
		return 0.4
	func get_river_depth_at(pos: Vector3) -> float:
		return water_depth if water_rect.has_point(Vector2(pos.x, pos.z)) else 0.0
	func _is_on_road(pos: Vector3) -> bool:
		return road_rect.has_point(Vector2(pos.x, pos.z))
	func _is_player_in_house(_pos: Vector3) -> bool:
		return false
	func _default_river_segments() -> Array:
		return river_segs
	func _net_player_hit_event(_peer_id: int, _kind: String, _pos: Vector3) -> void:
		pass
	func _can_place_ground_vegetation(_pos: Vector3, _river_margin := 0.8, _short_grass := false) -> bool:
		return true

func _initialize() -> void:
	call_deferred("run")

func _make_world() -> Array:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var fnet := FakeNet.new()
	fnet.name = "NetworkManager"
	root.add_child(fnet)
	world.net = fnet
	var dc := FakeDayCycle.new()
	world.add_child(dc)
	world.day_cycle = dc
	return [world, fnet]

# Proxy de jugador humano remoto (servidor dedicado) con inventario propio.
func _make_human_proxy(world, sender_id: int, pos: Vector3, items: Array = []) -> Node3D:
	var p := Node3D.new()
	p.name = "ServerProxy_%d" % sender_id
	world.add_child(p)
	p.global_position = pos
	p.set_meta("peer_id", sender_id)
	p.set_meta("client_id", "tester_%d" % sender_id)
	p.set_meta("bot_name", "Tester")
	p.set_meta("has_real_pos", true)
	p.set_meta("proxy_dead", false)
	p.set_meta("saved_inventory", items.duplicate(true))
	p.set_meta("saved_health", 100.0)
	p.set_meta("saved_hunger", 100.0)
	p.set_meta("saved_thirst", 100.0)
	world.server_proxies[sender_id] = p
	world.net.players[sender_id] = {"name": "Tester", "char_name": "Tester"}
	p.add_to_group("net_player_proxy")
	return p

func _give_bot_weapon(b: Dictionary, weapon_name: String) -> void:
	var inv: Array = b["proxy"].get_meta("saved_inventory", [])
	inv.append({"name": weapon_name, "type": "weapon", "weight": 3.0, "quantity": 1, "use_value": 0.0})
	b["proxy"].set_meta("saved_inventory", inv)

func run() -> void:
	var mem_path := "user://test_bot_convince_mem.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mem_path))
	var w := _make_world()
	var world: TestWorld = w[0]
	var fnet: FakeNet = w[1]

	var mgr := SurvivorBotManagerScript.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.memory_path = mem_path
	mgr.setup(world)

	# --- 1) Los 3 bots nacen hostiles ---
	check(mgr.bots.size() == 3, "Se crean los 3 bots")
	var all_hostile := true
	for bid in [901, 902, 903]:
		if str(mgr.bots[bid]["faction"]) != "hostile":
			all_hostile = false
	check(all_hostile, "Elena, Carlos y Kael nacen TODOS hostiles")

	# --- 2) Un hostil armado elige al humano proximo como objetivo ---
	var kael: Dictionary = mgr.bots[903]
	var pan_stack := {"name": "Pan", "type": "food", "weight": 0.2, "quantity": 2, "use_value": 30.0}
	var human := _make_human_proxy(world, 7, kael["pos"] + Vector3(6.0, 0.0, 0.0), [pan_stack])
	_give_bot_weapon(kael, "Cuchillo")
	var foe := mgr._find_combat_foe(kael)
	check(foe == human, "Kael hostil armado toma al jugador cercano como objetivo")

	# --- 3) Tregua por chat: deja de disparar al emisor ---
	mgr.on_chat_received(903, 7, "Tester", "alto ahi, basta de disparar")
	check(int(kael.get("_truce_peer", 0)) == 7 and float(kael.get("_truce_t", 0.0)) > 0.0,
		"'alto ahi' activa la tregua (_truce_peer=7, _truce_t>0)")
	foe = mgr._find_combat_foe(kael)
	check(foe != human, "Con tregua vigente Kael ya no apunta al jugador")
	kael["_truce_t"] = 0.0 # expira la tregua para el resto del test

	# --- 4) "sigueme" con confianza baja NO convierte; la respuesta llega al chat ---
	var elena: Dictionary = mgr.bots[901]
	mgr.on_chat_received(901, 7, "Tester", "sigueme")
	check(str(elena["faction"]) == "hostile", "'sigueme' sin confianza NO convierte a Elena")
	var replied := false
	for m in fnet.relay_log:
		if int(m.get("from_id", 0)) == 901 and int(m.get("to_id", 0)) == 7:
			replied = true
	check(replied, "La respuesta del bot llega al chat del jugador (relay_actor_chat)")

	# --- 5) La confianza sube con chat positivo ---
	var rel_e := mgr.get_bot_relationship(901, "tester_7")
	var trust_before := float(rel_e.get("trust", 0.0))
	mgr.on_chat_received(901, 7, "Tester", "hola buenas, que tal")
	rel_e = mgr.get_bot_relationship(901, "tester_7")
	check(float(rel_e.get("trust", 0.0)) > trust_before, "El saludo sube la confianza del bot")

	# --- 6) Confianza alta + "sigueme" convierte a Elena ---
	rel_e = mgr.get_bot_relationship(901, "tester_7")
	rel_e["trust"] = 0.9
	rel_e["hostility"] = 0.1
	mgr.on_chat_received(901, 7, "Tester", "sigueme")
	check(str(elena["faction"]) == "friendly", "Elena se convierte en aliada con confianza alta")
	check(int(elena.get("team_leader_id", 0)) == 7, "Elena convertida sigue al jugador (team_leader_id=7)")
	check(str(elena["proxy"].get_meta("bot_faction", "")) == "friendly", "El meta bot_faction del proxy se actualiza")
	check(str(fnet.players.get(901, {}).get("bot_faction", "")) == "friendly" or str(fnet.players.get(901, {}).get("faction", "")) == "friendly",
		"El estado publicado al jugador remoto refleja la nueva faccion")

	# --- 7) Kael exige MUCHA mas confianza (paranoico) ---
	var rel_k := mgr.get_bot_relationship(903, "tester_7")
	rel_k["trust"] = 0.5
	rel_k["hostility"] = 0.1
	mgr.on_chat_received(903, 7, "Tester", "sigueme")
	check(str(kael["faction"]) == "hostile", "Kael NO se convierte con trust=0.5 (umbral ~0.64)")
	rel_k["trust"] = 0.8
	mgr.on_chat_received(903, 7, "Tester", "sigueme")
	check(str(kael["faction"]) == "friendly", "Kael SI se convierte con trust=0.8")

	# --- 8) La hostilidad bloquea la conversion ---
	var carlos: Dictionary = mgr.bots[902]
	var rel_c := mgr.get_bot_relationship(902, "tester_7")
	rel_c["trust"] = 0.9
	rel_c["hostility"] = 0.95
	rel_c["attacked"] = 3
	mgr.on_chat_received(902, 7, "Tester", "sigueme")
	check(str(carlos["faction"]) == "hostile", "Carlos sigue hostil: te ha atacado 3 veces (hostilidad 0.95)")
	# Y el regalo de un iracundo tambien se rechaza (la relacion es por emisor)
	var pan_offer := {"name": "Pan", "type": "food", "weight": 0.2, "quantity": 1, "use_value": 30.0}
	var human2 := _make_human_proxy(world, 8, carlos["pos"] + Vector3(4.0, 0.0, 0.0), [pan_offer])
	var rel_c8 := mgr._chat_touch_rel(902, "tester_8", "Tester8")
	rel_c8["hostility"] = 0.95
	rel_c8["attacked"] = 3
	mgr.on_chat_received(902, 8, "Tester8", "te doy pan")
	var carlos_inv: Array = carlos["proxy"].get_meta("saved_inventory", [])
	var got_pan := false
	for it in carlos_inv:
		if str(it.get("name", "")) == "Pan":
			got_pan = true
	check(not got_pan, "Carlos iracundo rechaza el pan de un agresor")

	# --- 9) Regalo normal: el item sale del jugador y entra al bot ---
	# El regalo exige cercania (<=16 m): acerco al jugador junto a Elena.
	human.global_position = (elena["proxy"] as Node3D).global_position + Vector3(3.0, 0.0, 0.0)
	mgr.on_chat_received(901, 7, "Tester", "te doy pan")
	var elena_inv: Array = elena["proxy"].get_meta("saved_inventory", [])
	var pan_in_bot := false
	for it in elena_inv:
		if str(it.get("name", "")) == "Pan":
			pan_in_bot = true
	check(pan_in_bot, "Elena (ya aliada) acepta el pan: entra en su inventario")
	var sinv7: Array = human.get_meta("saved_inventory", [])
	var pan_left := 0
	for it in sinv7:
		if str(it.get("name", "")) == "Pan":
			pan_left += int(it.get("quantity", 1))
	check(pan_left == 1, "El pan sale del inventario del jugador que lo regala (queda 1 de 2)")
	# La faccion de Carlos sigue hostil tras el intento fallido de 902? (ya verificado)
	# Relacion de Carlos con tester_8: el regalo rechazado no debio dar item.
	var c_inv2: Array = carlos["proxy"].get_meta("saved_inventory", [])
	var pan_in_carlos := false
	for it in c_inv2:
		if str(it.get("name", "")) == "Pan":
			pan_in_carlos = true
	check(not pan_in_carlos, "El regalo rechazado no duplica el item")

	# --- 10) Los ataques reales bajan la confianza ---
	var rel_e2 := mgr.get_bot_relationship(901, "tester_7")
	var tr_before_atk := float(rel_e2.get("trust", 0.0))
	mgr.record_social_event(901, "tester_7", "Tester", "attack", 0.5, "shot")
	rel_e2 = mgr.get_bot_relationship(901, "tester_7")
	check(float(rel_e2.get("trust", 0.0)) < tr_before_atk, "Atacar al bot baja su confianza")

	# --- 11) La allegiance persiste: respawn con memoria -> friendly ---
	mgr.force_memory_io = true
	mgr._ai_save_memory()
	var mgr2 := SurvivorBotManagerScript.new()
	mgr2.name = "SurvivorBotManager2"
	world.add_child(mgr2)
	mgr2.memory_path = mem_path
	mgr2.force_memory_io = true
	mgr2.setup(world)
	check(str(mgr2.bots[901]["faction"]) == "friendly", "Elena renace aliada: la conversion persiste en memoria")
	check(str(mgr2.bots[903]["faction"]) == "friendly", "Kael tambien persiste como aliado")
	check(str(mgr2.bots[902]["faction"]) == "hostile", "Carlos sigue hostil: nunca se convencio")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(mem_path))
	print("BotConvinceRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
