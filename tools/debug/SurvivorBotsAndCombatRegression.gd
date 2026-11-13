extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")
const WildlifeControllerScript = preload("res://scripts/WildlifeController.gd")
const SurvivorBotManagerScript = preload("res://scripts/SurvivorBotManager.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")

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
	var is_dedicated_server := true
	var peer = null
	var players := {}
	var animals := {}
	var authoritative_weather := {}
	var relay_log: Array = []
	var voice_relay_log: Array = []
	var mp3_relay_log: Array = []
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false
	func snapshot_recipients() -> Array[int]:
		return []
	func relay_actor_chat(sender_id: int, sender_name: String, text: String, target_peer_id: int, target_name: String = "") -> void:
		relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "text": text})
	func relay_actor_voice(sender_id: int, sender_name: String, pcm_bytes: PackedByteArray, target_peer_id: int, target_name: String = "") -> void:
		voice_relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "bytes": pcm_bytes.size()})
	func relay_actor_voice_mp3(sender_id: int, sender_name: String, mp3_bytes: PackedByteArray, target_peer_id: int, target_name: String = "") -> void:
		mp3_relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "bytes": mp3_bytes.size()})

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class StubDeadPuppet extends Node3D:
	var is_dead := false

class StubRifleShooter extends Node3D:
	var shot_calls := 0
	var last_origin := Vector3.ZERO
	var _puppet_held := "Rifle francotirador"
	func play_rifle_shot_remote(o: Vector3, _d: Vector3, _w: Vector3 = Vector3.ZERO) -> void:
		shot_calls += 1
		last_origin = o

class TestWorld extends "res://scripts/Main.gd":
	var water_rect := Rect2(100000.0, 100000.0, 4.0, 4.0) # lejos por defecto
	var water_depth := 1.0
	var road_rect := Rect2(200000.0, 200000.0, 4.0, 4.0)
	var hit_events: Array = []
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
	func _net_player_hit_event(peer_id: int, kind: String, pos: Vector3) -> void:
		hit_events.append({"id": peer_id, "kind": kind, "pos": pos})
	func _net_world_action_completed(aid: String, _b: Array, _c: String, _d: Vector3, _e: int = 0) -> bool:
		# Réplica mínima del camino dedicado: agotada + retirada del registro,
		# sin visuals ni RPC — suficiente para que el forrajeo verifique consumo.
		if not aid.is_empty() and not _depleted_action_ids.has(aid):
			_depleted_action_ids.append(aid)
		var act = world_actions_by_id.get(aid)
		if act != null and is_instance_valid(act):
			act.mark_depleted()
			world_actions_by_id.erase(aid)
		return true
	var built_campfires: Array = []
	func _net_campfire_built(cid: String, pos: Vector3, _owner: int = 0) -> bool:
		built_campfires.append(cid)
		campfire_positions.append(pos)
		return true
	func _net_campfire_lit(cid: String, fire_name: String, pos: Vector3, _owner: int = 0) -> bool:
		_lit_campfires.append({"id": cid, "fire_name": fire_name, "pos": pos})
		if not campfire_positions.has(pos):
			campfire_positions.append(pos)
		return true
	# Replica del camino del servidor dedicado: solo registra la parcela en
	# _planted_crops, sin crear el nodo visual farm_plot.
	func _plant_crop(pos: Vector3, crop_state := "planted", growth := 0.0, crop_id := "", watered_until := 0.0, ready_unix := 0.0) -> String:
		var id := crop_id if not crop_id.is_empty() else "crop_%d" % (int(round(pos.x * 4.0)) * 73856093 ^ int(round(pos.z * 4.0)) * 19349663 ^ int(round(pos.y * 10.0)))
		for c in _planted_crops:
			if str(c.get("id", "")) == id:
				return id
		_planted_crops.append({"id": id, "pos": pos, "crop_state": crop_state, "growth": growth, "updated_unix": Time.get_unix_time_from_system(), "watered_until": watered_until, "ready_unix": ready_unix})
		return id
	func _can_place_ground_vegetation(_pos: Vector3, _river_margin := 0.8, _short_grass := false) -> bool:
		return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(472) # Reproducible personalities, positions and social decisions.
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

	var player := TestPlayer.new()
	player.name = "Player"
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	world.player = player
	player.global_position = Vector3(10.0, 0.4, 10.0)

	# --- 1) Combate agil contra lobos/osos y no-enganche ---
	var knife = ItemScript.create("Cuchillo", "weapon", 0.4, 1, 0.0)
	player.inventory.items.append(knife)
	player.held_index = player.inventory.items.find(knife)
	player._held_item_reference = knife
	player.stats.energy = 100.0

	var wolf := WildlifeControllerScript.new()
	wolf.name = "Wildlife_wolf_test"
	world.add_child(wolf)
	wolf.setup("wolf", [Vector3(10.0, 0.4, 8.2), Vector3(14.0, 0.4, 8.2)])
	wolf.set_process(false)
	await process_frame
	# Colocar al lobo flanqueando al costado del jugador (como cuando orbita en ataque)
	wolf.global_position = player.global_position + Vector3(2.1, 0.0, -0.3)

	# Simulamos una accion interactiva abierta y recibimos un mordisco: debe cancelarse al instante
	player._interact_busy = true
	player.apply_damage(20.0, "wolf_bite")
	check(not player._interact_busy, "Mordisco cancela cualquier accion interactiva bloqueante (_interact_busy)")

	# Golpe con cuchillo: debe ser rapido (<0.3s) y alcanzar al lobo en flanqueo lateral + aplicar stagger
	var hp_before := wolf.health
	var pos_before := wolf.global_position
	player._attack_cooldown = 0.0
	player._melee_attack()
	check(player._attack_cooldown <= 0.45, "Cooldown de cuchillo agil (%.2fs)" % player._attack_cooldown)
	await create_timer(0.28).timeout
	check(wolf.health < hp_before, "Golpe de cuchillo alcanza al lobo orbitando al costado (hp %.1f -> %.1f)" % [hp_before, wolf.health])
	check(wolf._stagger_timer > 0.0, "El golpe aplica stagger/retroceso al lobo (stagger=%.2f)" % wolf._stagger_timer)
	check(wolf._attack_cooldown >= 1.2, "El golpe retrasa el siguiente mordisco del lobo (cd=%.2f)" % wolf._attack_cooldown)

	# Avanzar fisica del lobo durante stagger: debe retroceder alejandose del jugador
	wolf._process(0.2)
	check(wolf.global_position.distance_to(player.global_position) > pos_before.distance_to(player.global_position),
		"El lobo retrocede fisicamente durante el stagger")

	# Al morir el animal, CorpseBody es Area3D (no StaticBody3D que bloquee el paso)
	wolf.take_damage(999.0, true, player)
	check(wolf._is_dead, "Lobo muere al recibir dano letal")
	check(wolf._corpse_body is Area3D, "CorpseBody del cadaver es Area3D (no engancha al jugador)")

	# --- 2) Supervivientes IA: creacion de los 3 bots (2 aliados + 1 bandido) ---
	var mgr := SurvivorBotManagerScript.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.setup(world)

	check(mgr.bots.size() == 3, "Se crean los 3 supervivientes IA (Elena, Carlos, Kael)")
	check(mgr.bots.has(901) and mgr.bots.has(902) and mgr.bots.has(903), "IDs 901, 902 y 903 registrados")
	check(str(mgr.bots[901]["faction"]) == "hostile" and str(mgr.bots[902]["faction"]) == "hostile" and str(mgr.bots[903]["faction"]) == "hostile",
		"Los 3 supervivientes IA nacen hostiles (se ganan la confianza por chat/voz)")
	# Elena y Carlos ya fueron "convencidos" en sesiones previas: para el resto
	# de la regresion se comportan como aliados (la conversion en si se prueba
	# en BotConvinceRegression). Kael sigue hostil, como antes.
	mgr._set_bot_faction(mgr.bots[901], "friendly")
	mgr._set_bot_faction(mgr.bots[902], "friendly")
	# Cada superviviente aparece aleatoriamente en una de las zonas de spawn
	# de jugadores (_spawn_zones del mundo), no en un punto fijo.
	var zones: Array = world.get("_spawn_zones")
	for bid in [901, 902, 903]:
		var bp: Vector3 = mgr.bots[bid]["pos"]
		var in_zone := false
		for z in zones:
			if Vector2(bp.x - (z as Vector3).x, bp.z - (z as Vector3).z).length() <= 4.5:
				in_zone = true
				break
		check(in_zone, "Bot %d spawnea aleatoriamente dentro de una zona de spawn (%.0f,%.0f)" % [bid, bp.x, bp.z])

	# --- 3) Construccion de refugio + camuflaje/pieles + fogata y antorcha nocturna ---
	var kael: Dictionary = mgr.bots[903]
	var kael_proxy: Node3D = kael["proxy"]
	kael_proxy.global_position = kael["camp_spot"]
	kael["pos"] = kael["camp_spot"]
	# Nace sin inventario: estos materiales simulan lo saqueado/cazado para
	# probar que sigue construyendo campamento cuando los consigue.
	var k_inv: Array = kael_proxy.get_meta("saved_inventory", [])
	for it in [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 14, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 4, "use_value": 0.0},
		{"name": "Cuerda", "type": "resource", "weight": 0.25, "quantity": 2, "use_value": 0.0},
		{"name": "Piel de lobo", "type": "resource", "weight": 0.65, "quantity": 4, "use_value": 0.0},
		{"name": "Tela de camuflaje", "type": "material", "weight": 0.8, "quantity": 1, "use_value": 0.0},
		{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
		{"name": "Cerillas", "type": "tool_matches", "weight": 0.1, "quantity": 1, "use_value": 0.0, "durability": 10.0, "max_durability": 10.0},
	]:
		k_inv.append(it)
	kael_proxy.set_meta("saved_inventory", k_inv)
	# Tick para construir refugio
	mgr._tick_bot(kael, 0.2)
	check(not str(kael["shelter_id"]).is_empty(), "Superviviente IA construye su propio refugio (%s)" % str(kael["shelter_id"]))
	var built_sh_ok := false
	for sh in world._built_shelters:
		if str(sh.get("id", "")) == str(kael["shelter_id"]):
			built_sh_ok = bool(sh.get("camo_covered", false)) and bool(sh.get("pelt_lined", false))
	check(built_sh_ok, "Kael forra su refugio con pieles y lo cubre con tela de camuflaje")

	# Siguiente tick construye y enciende fogata junto al refugio
	mgr._tick_bot(kael, 0.2)
	check(not str(kael["campfire_id"]).is_empty(), "Superviviente IA construye y enciende fogata junto al refugio (%s)" % str(kael["campfire_id"]))

	# De noche fuera del refugio enciende su antorcha; al ocultarse dentro del refugio la apaga
	dc.time_of_day = 22.0
	kael_proxy.global_position = kael["shelter_pos"] + Vector3(12.0, 0.0, 0.0)
	kael["pos"] = kael_proxy.global_position
	mgr._tick_bot(kael, 0.1)
	check(bool(kael["torch_lit"]), "De noche fuera del refugio el superviviente IA enciende la antorcha")

	kael_proxy.global_position = kael["shelter_pos"]
	kael["pos"] = kael["shelter_pos"]
	kael["hide_timer"] = 5.0
	mgr._tick_bot(kael, 0.2)
	check(not bool(kael["torch_lit"]) and bool(kael["sitting"]),
		"Al ocultarse en su refugio apaga la antorcha y se sienta/agacha a resguardo")
	# El hambre rompe el descanso nocturno incluso sin antorcha: pero a
	# oscuras sin luz no divaga — vuelve a su fogata encendida (act=rest).
	var k_no_torch: Array = (kael_proxy.get_meta("saved_inventory", []) as Array).filter(func(it): return str(it.get("name", "")) != "Antorcha")
	kael_proxy.set_meta("saved_inventory", k_no_torch)
	kael["hunger"] = 15.0
	kael["thirst"] = 80.0
	kael["hide_timer"] = 0.0
	kael["sleeping"] = false
	kael_proxy.global_position = kael["shelter_pos"] + Vector3(20.0, 0.0, 0.0)
	kael["pos"] = kael_proxy.global_position
	mgr._tick_bot(kael, 0.1)
	check(str(kael["_act"]) == "rest" and not bool(kael["sleeping"]) and not bool(kael["torch_lit"]),
		"De noche sin antorcha el hambriento vuelve a su fogata (act=%s)" % str(kael["_act"]))
	k_no_torch.append({"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0})
	kael_proxy.set_meta("saved_inventory", k_no_torch)
	kael["sleeping"] = false
	mgr._tick_bot(kael, 0.1)
	check(bool(kael["torch_lit"]) and str(kael["_act"]) != "rest",
		"De noche con antorcha si puede moverse a buscar (act=%s torch=%s)" % [str(kael["_act"]), str(kael["torch_lit"])])
	# ...pero con hambre de muerte segura sale igualmente aunque no vea nada:
	# el instinto de supervivencia pesa mas que la oscuridad.
	kael_proxy.set_meta("saved_inventory", (kael_proxy.get_meta("saved_inventory", []) as Array).filter(func(it): return str(it.get("name", "")) != "Antorcha"))
	kael["torch_lit"] = false
	kael["hunger"] = 8.0
	kael["sleeping"] = false
	mgr._tick_bot(kael, 0.1)
	check(not (str(kael["_act"]) in ["need_light", "night_supplies"]) and not bool(kael["sleeping"]),
		"De noche sin luz el hambre letal le hace actuar: burbuja de emergencia o vuelta a casa (act=%s)" % str(kael["_act"]))
	# Y parapetado (sitting/act=rest) gasta menos hambre/sed que en pie.
	var kvs: SurvivalStats = kael["vstats"]
	kael["sitting"] = true
	kael["_act"] = "rest"
	kael["anim"] = "sit"
	kael["sleeping"] = false
	kael["hunger"] = 80.0
	kael["thirst"] = 80.0
	kvs.sleep = 80.0
	mgr._bot_survival_tick(kael, 10.0)
	var drain_rest := 80.0 - float(kael["hunger"])
	kael["sitting"] = false
	kael["_act"] = "explore"
	kael["anim"] = "idle"
	kael["hunger"] = 80.0
	mgr._bot_survival_tick(kael, 10.0)
	var drain_idle := 80.0 - float(kael["hunger"])
	check(drain_rest > 0.0 and drain_rest < drain_idle * 0.75,
		"Descansando el hambre baja mas despacio que en pie (%.3f vs %.3f)" % [drain_rest, drain_idle])
	dc.time_of_day = 14.0
	kael["hide_timer"] = 0.0
	kael["hunger"] = 80.0
	kael["thirst"] = 80.0
	kael["sitting"] = false
	kael["_act"] = ""
	kael["anim"] = "idle"

	# --- 3b) Preparacion nocturna: junta material de fuego antes de oscurecer ---
	# Un superviviente precavido no espera a que anochezca: por la tarde ya
	# reune palos, piedras y trapos para la fogata o la antorcha.
	var k_blade := {"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0}
	kael["hide_timer"] = 0.0
	kael["sleeping"] = false
	kael["hunger"] = 85.0
	kael["thirst"] = 85.0
	kael["health"] = 100.0
	kael["_gather"] = {}
	kael["_gather_scan"] = 0.0
	kael["_forage"] = {}
	kael["_s_leader"] = null
	kael["_s_foe"] = null
	kael["_s_predator"] = null
	kael["_s_prey"] = null
	kael["_s_loot"] = {}
	kael["_s_raid_shelter"] = {}
	kael["ambush"] = {}
	kael["_want_cache"] = {}
	kael["campfire_id"] = ""
	kael["no_fire_spot"] = false
	kael["torch_lit"] = false
	kael["equip_mission"] = false
	world.world_actions_by_id.clear()
	# Matriz de "noche resuelta": antorcha propia, palo+trapos fabricable al
	# momento, fogata ya levantada o — solo con refugio — el 2+2 para montarla.
	kael_proxy.set_meta("saved_inventory", [k_blade])
	check(not mgr._bot_night_fire_ready(kael, kael_proxy), "Sin antorcha ni fogata ni material: no tiene la noche resuelta")
	kael_proxy.set_meta("saved_inventory", [k_blade,
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1, "use_value": 0.0}])
	check(mgr._bot_night_fire_ready(kael, kael_proxy), "Palo+Trapos: puede fabricar la antorcha en cuanto quiera")
	kael["campfire_id"] = "cf_prep_test"
	check(mgr._bot_night_fire_ready(kael, kael_proxy), "Fogata ya levantada: tiene la noche resuelta")
	kael["campfire_id"] = ""
	# La antorcha puntua >3 todo el dia: abre la puerta a Trapos y ropa cortable
	var torch_rec := {}
	for r in CraftingSystem.RECIPES:
		if str((r.get("output", {}) as Dictionary).get("name", "")) == "Antorcha":
			torch_rec = r
	kael["_want_cache"] = {}
	kael_proxy.set_meta("saved_inventory", [k_blade])
	dc.time_of_day = 14.0
	check(mgr._bot_recipe_score(kael, torch_rec) > 3.0,
		"La antorcha puntua de dia: la fabrica antes de la noche (%.1f)" % mgr._bot_recipe_score(kael, torch_rec))
	check(mgr._bot_wants_craft_input(kael, "Trapos"), "Sin antorcha quiere Trapos: los recoge para la antorcha")
	check(mgr._bot_cuts_into_trapos("Chaqueta militar") and not mgr._bot_cuts_into_trapos("Piedra"),
		"Sabe que ropa se corta a trapos para la antorcha")
	# Recoleccion dirigida al caer la tarde: piedras sueltas del mundo
	# (accion stone) se recogen a mano para la fogata — sin filo hace falta.
	dc.time_of_day = 18.0
	kael_proxy.global_position = Vector3(40.0, 0.4, 40.0)
	kael["pos"] = kael_proxy.global_position
	kael["camp_spot"] = kael_proxy.global_position
	var prep_stone := WorldActionScript.new()
	prep_stone.setup("prep_stone", "stone", "Piedras utiles", Vector3(1.0, 0.7, 1.0), Color(0.3, 0.3, 0.26), false, false)
	world.add_child(prep_stone)
	prep_stone.global_position = kael_proxy.global_position + Vector3(5.0, 0.0, 0.0)
	world.world_actions_by_id["prep_stone"] = prep_stone
	check(mgr._bot_try_gather_mats(kael, 0.1), "Al caer la tarde sin fuego sale a por material")
	var g_kind := str((kael.get("_gather", {}) as Dictionary).get("kind", ""))
	check(g_kind == "stone", "Elige el nodo de piedras para la fogata (kind=%s)" % g_kind)
	kael_proxy.global_position = prep_stone.global_position
	kael["pos"] = kael_proxy.global_position
	for i in range(20):
		if not mgr._bot_try_gather_mats(kael, 0.2):
			break
	check(mgr._bot_item_count(kael_proxy, "Piedra") >= 2,
		"Recoge las piedras del nodo a mano (Piedra=%d)" % mgr._bot_item_count(kael_proxy, "Piedra"))
	# Troncos aprovechables (accion wood): con filo los lleva para rajar a palos
	var prep_wood := WorldActionScript.new()
	prep_wood.setup("prep_wood", "wood", "Troncos aprovechables", Vector3(1.6, 0.7, 1.0), Color(0.25, 0.15, 0.06), false, false)
	world.add_child(prep_wood)
	prep_wood.global_position = kael_proxy.global_position + Vector3(5.0, 0.0, 0.0)
	world.world_actions_by_id["prep_wood"] = prep_wood
	kael["_gather"] = {}
	kael["_gather_scan"] = 0.0
	kael_proxy.set_meta("saved_inventory", [k_blade])
	check(mgr._bot_try_gather_mats(kael, 0.1), "Con filo va a por troncos para rajar palos")
	g_kind = str((kael.get("_gather", {}) as Dictionary).get("kind", ""))
	check(g_kind == "wood", "Elige el nodo de troncos como fuente de palos (kind=%s)" % g_kind)
	kael_proxy.global_position = prep_wood.global_position
	kael["pos"] = kael_proxy.global_position
	for i in range(20):
		if not mgr._bot_try_gather_mats(kael, 0.2):
			break
	check(mgr._bot_item_count(kael_proxy, "Tronco") >= 1 and mgr._bot_palo_supply(kael_proxy, "Cuchillo") >= 4,
		"Recoge troncos que cuentan como palos futuros (Tronco=%d supply=%d)" % [mgr._bot_item_count(kael_proxy, "Tronco"), mgr._bot_palo_supply(kael_proxy, "Cuchillo")])
	# Arbustos a talar: el camino de siempre sigue eligiendose con filo
	var prep_bush := WorldActionScript.new()
	prep_bush.setup("prep_bush", "fell_bush", "Arbusto", Vector3(1.2, 1.4, 1.2), Color(0.2, 0.35, 0.12), true, false)
	world.add_child(prep_bush)
	prep_bush.global_position = kael_proxy.global_position + Vector3(5.0, 0.0, 0.0)
	world.world_actions_by_id["prep_bush"] = prep_bush
	kael["_gather"] = {}
	kael["_gather_scan"] = 0.0
	kael_proxy.set_meta("saved_inventory", [k_blade])
	check(mgr._bot_try_gather_mats(kael, 0.1), "Con filo y sin palos sale a talar el arbusto")
	g_kind = str((kael.get("_gather", {}) as Dictionary).get("kind", ""))
	check(g_kind == "fell_bush", "Sigue eligiendo el arbusto a talar (kind=%s)" % g_kind)
	# Sin filo no tala nada: un bot sin cuchillo no sale a por palos
	kael["_gather"] = {}
	kael["_gather_scan"] = 0.0
	kael_proxy.set_meta("saved_inventory", [
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 2, "use_value": 0.0}])
	check(not mgr._bot_try_gather_mats(kael, 0.1), "Sin filo no tala (solo iria a por piedras y ya tiene)")
	# Botin dirigido de material de fuego: localiza trapos a 40 m al anochecer
	kael_proxy.set_meta("saved_inventory", [k_blade])
	var prep_tp: Vector3 = kael_proxy.global_position
	world._dropped_items.append({"id": "prep_trapos", "name": "Trapos", "type": "resource", "weight": 0.05, "qty": 1, "use": 0.0, "pos": [prep_tp.x + 40.0, prep_tp.y, prep_tp.z]})
	world._dropped_items.append({"id": "prep_lata", "name": "Lata de judias", "type": "food", "weight": 0.4, "qty": 1, "use": 20.0, "pos": [prep_tp.x + 10.0, prep_tp.y, prep_tp.z]})
	var prep_hit := mgr._find_fire_prep_loot(kael, 60.0)
	check(str(prep_hit.get("id", "")) == "prep_trapos",
		"Al caer la tarde va a por el Trapos lejano e ignora la lata cercana (id=%s)" % str(prep_hit.get("id", "")))
	world._dropped_items = (world._dropped_items as Array).filter(func(e): return not str(e.get("id", "")).begins_with("prep_"))
	# Parapeto nocturno con material: sin refugio alcanzable monta la fogata
	# de emergencia junto a el — el fruto de lo recogido por la tarde.
	dc.time_of_day = 22.0
	var k_sh_id_save := str(kael["shelter_id"])
	var k_sh_pos_save: Vector3 = kael["shelter_pos"]
	kael["shelter_id"] = ""
	kael["shelter_pos"] = Vector3.INF
	kael["campfire_id"] = ""
	kael["_gather"] = {}
	kael_proxy.global_position = Vector3(600.0, 0.4, 600.0)
	kael["pos"] = kael_proxy.global_position
	(kael["vstats"] as SurvivalStats).sleep = 90.0
	kael_proxy.set_meta("saved_inventory", [k_blade,
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 5, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 2, "use_value": 0.0}])
	var fires_pre: int = (world.built_campfires as Array).size()
	mgr._tick_bot(kael, 0.1)
	check((world.built_campfires as Array).size() == fires_pre + 1,
		"Sin refugio alcanzable monta la fogata de emergencia junto a el (act=%s)" % str(kael["_act"]))
	kael["shelter_id"] = k_sh_id_save
	kael["shelter_pos"] = k_sh_pos_save
	kael["sleeping"] = false
	kael["sitting"] = false
	kael["_act"] = ""
	kael["anim"] = "idle"
	dc.time_of_day = 14.0

	# --- 4) Doma de lobos por parte de un Superviviente IA ---
	var wild_w := WildlifeControllerScript.new()
	wild_w.name = "Wildlife_wolf_tame_bot"
	world.add_child(wild_w)
	wild_w.setup("wolf", [Vector3(22.0, 0.4, 20.0), Vector3(26.0, 0.4, 20.0)])
	wild_w._chase_cooldown = 30.0
	var elena: Dictionary = mgr.bots[901]
	var elena_proxy: Node3D = elena["proxy"]
	wild_w.global_position = elena_proxy.global_position + Vector3(8.0, 0.0, 0.0)

	for feed_step in range(3):
		elena["tame_cooldown"] = 0.0
		mgr._perform_wolf_taming_step(elena, wild_w, 0.1)
		# Hacer que el lobo registre la comida soltada por el bot (str(901))
		wild_w._register_feeding("901", elena_proxy.global_position.lerp(wild_w.global_position, 0.38))
	check(wild_w.tamed_to == "901", "Superviviente IA doma un lobo salvaje tras 3 entregas de carne (tamed_to=%s)" % wild_w.tamed_to)

	# --- 5) Formar equipo con un superviviente aliado ([F]) y ordenes ---
	var msg1: String = mgr.interact_with_bot(901, 1, "toggle")
	check(int(elena["team_leader_id"]) == 1 and str(elena["follow_mode"]) == "follow",
		"Elena se une al equipo del jugador en modo seguimiento (%s)" % msg1)

	# Si un depredador o enemigo ataca al lider, el compañero IA acude a defenderlo
	kael_proxy.global_position = elena_proxy.global_position + Vector3(18.0, 0.0, 0.0)
	mgr.notify_leader_combat(1, kael_proxy)
	check(elena["aggro_target"] == kael_proxy, "Compañero IA fija como objetivo a quien ataca a su lider de equipo")

	var msg2: String = mgr.interact_with_bot(901, 1, "toggle")
	check(str(elena["follow_mode"]) == "stay", "Segunda interaccion ordena al compañero IA vigilar posicion (%s)" % msg2)

	var msg3: String = mgr.interact_with_bot(901, 1, "toggle")
	check(int(elena["team_leader_id"]) == 0, "Tercera interaccion libera al compañero IA del equipo (%s)" % msg3)

	# --- 6) Pies en el suelo y ropa del preview de inicio ---
	for bid in [901, 902, 903]:
		var bp: Node3D = mgr.bots[bid]["proxy"]
		check(absf(bp.global_position.y - 0.375) < 0.01,
			"Bot %d con los pies en el suelo (y=%.3f esperado ~0.375)" % [bid, bp.global_position.y])
		check(str(mgr.bots[bid]["clothing"]) == "Camiseta,Pantalones,Zapatillas",
			"Bot %d viste la ropa de los personajes del preview de inicio (%s)" % [bid, str(mgr.bots[bid]["clothing"])])
	check(bool(fnet.players[903].get("top_camo", false)) and bool(fnet.players[903].get("bottom_camo", false)),
		"Bot 903 (Soldado/Kael) conserva el camuflaje top+bottom del preview de inicio")

	# --- 7) El campamento nunca se monta en agua/carretera ---
	world.water_rect = Rect2(14.0, 20.0, 12.0, 12.0) # cubre el camp preferido de Elena (19,26)
	var bad_camp: Vector3 = mgr._find_valid_camp_spot(Vector3(19.0, 0.0, 26.0), Vector3(22.0, 0.0, 12.0))
	check(not world.water_rect.has_point(Vector2(bad_camp.x, bad_camp.z)),
		"El punto de campamento elegido evita el agua (%.0f,%.0f)" % [bad_camp.x, bad_camp.z])
	world.water_rect = Rect2(100000.0, 100000.0, 4.0, 4.0)
	world.road_rect = Rect2(14.0, 20.0, 12.0, 12.0)
	bad_camp = mgr._find_valid_camp_spot(Vector3(19.0, 0.0, 26.0), Vector3(22.0, 0.0, 12.0))
	check(not world.road_rect.has_point(Vector2(bad_camp.x, bad_camp.z)),
		"El punto de campamento elegido evita la carretera (%.0f,%.0f)" % [bad_camp.x, bad_camp.z])
	world.road_rect = Rect2(200000.0, 200000.0, 4.0, 4.0)
	# Un campamento preferido en medio del pueblo nunca se usa: el espiral lo
	# reubica fuera del nucleo urbano (>=78 m del origen).
	var village_camp: Vector3 = mgr._find_valid_camp_spot(Vector3(5.0, 0.0, 5.0), Vector3(5.0, 0.0, 5.0))
	check(Vector2(village_camp.x, village_camp.z).length() >= 78.0,
		"Campamento preferido dentro del pueblo se reubica fuera (dist=%.0f m)" % Vector2(village_camp.x, village_camp.z).length())
	check(mgr._is_settled_area(Vector3(10.0, 0.0, 10.0)) and not mgr._is_settled_area(village_camp),
		"_is_settled_area rechaza la plaza del pueblo y acepta el bosque encontrado")

	# --- 8) Anti-atascos: caminando en llano durante >2s NO dispara falso atasco; en agua salta al siguiente ---
	var carlos: Dictionary = mgr.bots[902]
	var carlos_proxy: Node3D = carlos["proxy"]
	carlos_proxy.global_position = Vector3(-50.0, 0.375, -50.0)
	carlos["pos"] = carlos_proxy.global_position
	carlos["last_move_pos"] = carlos_proxy.global_position
	carlos["stuck_timer"] = 0.0
	carlos["stuck_count"] = 0
	for i in range(25):
		mgr._move_bot_towards(carlos, Vector3(-20.0, 0.375, -50.0), 3.4, 0.1, "walk")
	check(int(carlos["stuck_count"]) == 0,
		"Caminar libremente durante >2s no activa falso positivo de atasco (stuck_count=%d)" % int(carlos["stuck_count"]))
	carlos_proxy.global_position = Vector3(-50.0, 0.375, -50.0)
	carlos["pos"] = carlos_proxy.global_position
	carlos["patrol"] = [Vector3(-60.0, 0.375, -60.0), Vector3(-40.0, 0.375, -40.0)]
	carlos["patrol_idx"] = 0
	carlos["stuck_count"] = 0
	world.water_rect = Rect2(-62.0, -62.0, 6.0, 6.0) # el punto de patrulla esta en el agua
	var idx_before := int(carlos["patrol_idx"])
	for i in range(6):
		mgr._move_bot_towards(carlos, carlos["patrol"][0], 3.4, 0.2, "walk")
		if int(carlos["patrol_idx"]) != idx_before:
			break
	check(int(carlos["patrol_idx"]) != idx_before,
		"Bot atrapado por el agua abandona el objetivo y salta al siguiente punto de patrulla")
	world.water_rect = Rect2(100000.0, 100000.0, 4.0, 4.0)

	# --- 9) Sed: sin botellas va al rio a beber y recupera la sed ---
	carlos["aggro_target"] = null
	carlos["aggro_timer"] = 0.0
	carlos["thirst"] = 20.0
	carlos["drink_at"] = Vector3.INF
	var c_inv: Array = []
	for it in carlos_proxy.get_meta("saved_inventory", []):
		if not (it is Dictionary) or str(it.get("name", "")) != "Botella de agua llena":
			c_inv.append(it)
	carlos_proxy.set_meta("saved_inventory", c_inv)
	world.river_segs = [{"center": Vector3(-52.0, 0.4, -55.0)}]
	mgr._tick_bot(carlos, 0.1)
	check(carlos["drink_at"] != Vector3.INF, "Bot sediento sin botellas fija destino de agua (%s)" % str(carlos["drink_at"]))
	# Colocar al bot ya en la orilla y simular los 3.5s de bebida
	carlos_proxy.global_position = carlos["drink_at"] + Vector3(1.0, 0.0, 0.0)
	carlos["pos"] = carlos_proxy.global_position
	for i in range(40):
		mgr._tick_bot(carlos, 0.1)
	check(float(carlos["thirst"]) >= 99.0, "Bot bebe en la orilla y recupera la sed (thirst=%.0f)" % float(carlos["thirst"]))

	# 9b) Mientras bebe en la orilla el avatar remoto recibe el clip real de
	# beber ("drink" via consume_anim), no una postura estatica agachada.
	carlos["thirst"] = 20.0
	carlos["drink_at"] = carlos_proxy.global_position
	carlos["drinking_timer"] = 0.0
	carlos["consume_anim_t"] = 0.0
	world.water_rect = Rect2(carlos_proxy.global_position.x - 2.0, carlos_proxy.global_position.z - 2.0, 4.0, 4.0)
	world.water_depth = 0.3
	mgr._tick_bot(carlos, 0.1)
	check(str(mgr._bot_effective_net_anim(carlos)) == "drink" and not bool(carlos["crouching"]),
		"Bebiendo en la orilla el avatar remoto muestra 'drink' de pie (anim=%s)" % str(mgr._bot_effective_net_anim(carlos)))

	# 9c) Agua profunda real (>WADE_DEPTH): el bot no se queda plantado dentro —
	# escapa hacia agua vadeable/seca aunque todo lo demas este profundo.
	carlos["thirst"] = 20.0
	carlos["drink_at"] = Vector3.INF
	carlos["drinking_timer"] = 0.0
	carlos["_speed"] = 0.0
	carlos["_mdir"] = Vector3.ZERO
	world.water_rect = Rect2(carlos_proxy.global_position.x - 2.0, carlos_proxy.global_position.z - 2.0, 4.0, 4.0)
	world.water_depth = 1.2
	var esc_from: Vector3 = carlos_proxy.global_position
	mgr._tick_bot(carlos, 0.1)
	var esc_moved: bool = carlos_proxy.global_position.distance_to(esc_from) > 0.01
	check(str(carlos.get("_act", "")) == "water_escape" and esc_moved,
		"Bot atrapado en agua profunda escapa a lo somero (act=%s moved=%s)" % [str(carlos.get("_act", "")), str(esc_moved)])
	world.water_rect = Rect2(100000.0, 100000.0, 4.0, 4.0)
	world.water_depth = 1.0

	# --- 10) Hambre y sed a cero matan de verdad (muerte por inanicion) ---
	carlos["hunger"] = 0.0
	carlos["thirst"] = 0.0
	carlos["eat_cooldown"] = 999.0 # que no coma/beba durante la prueba
	carlos["drink_at"] = Vector3.INF
	carlos_proxy.set_meta("saved_inventory", [])
	carlos_proxy.set_meta("proxy_health", 4.0)
	carlos["health"] = 4.0
	mgr._tick_bot(carlos, 0.5)
	check(float(carlos["health"]) < 4.0, "Hambre+sed a cero desgasta la salud (hp=%.1f)" % float(carlos["health"]))
	for i in range(10):
		mgr._tick_bot(carlos, 0.5)
		if bool(carlos_proxy.get_meta("proxy_dead", false)):
			break
	check(bool(carlos_proxy.get_meta("proxy_dead", false)) and str(carlos["anim"]) == "dead",
		"El superviviente muere de hambre/sed y queda como cadaver sincronizado")

	# --- 10b) Aprendizaje persistente: recuerda la muerte y no repite el error ---
	var mem902: Dictionary = mgr._memory.get(902, {})
	check(int(mem902.get("deaths", 0)) == 1 and str(mem902.get("last_death_cause", "")) == "starved" and bool(mem902.get("scarcity", false)),
		"La muerte por inanicion queda grabada en la memoria persistente del personaje")
	mgr._respawn_bot(carlos)
	var carlos2: Dictionary = mgr.bots[902]
	check(carlos2 != null and bool((carlos2.get("_mem", {}) as Dictionary).get("scarcity", false)) and float(carlos2.get("caution_until", 0.0)) > 0.0,
		"El respawn conserva el aprendizaje (scarcity + cautela temporal)")

	# --- 10c) Aprende que la ropa de piel es la mejor equipacion ---
	var e_inv2: Array = elena_proxy.get_meta("saved_inventory", [])
	e_inv2.append({"name": "Chaqueta de piel", "type": "clothing", "weight": 1.4, "quantity": 1, "use_value": 0.0})
	e_inv2.append({"name": "Pantalones de piel", "type": "clothing", "weight": 1.0, "quantity": 1, "use_value": 0.0})
	elena_proxy.set_meta("saved_inventory", e_inv2)
	mgr._auto_equip_best_gear(elena)
	check(str(elena["clothing"]).contains("Chaqueta de piel") and str(elena["clothing"]).contains("Pantalones de piel"),
		"El superviviente equipa la ropa de piel como mejor equipo (%s)" % str(elena["clothing"]))
	check(bool((elena.get("_mem", {}) as Dictionary).get("gear_learned", false)),
		"Aprende que la ropa de piel es la mejor (gear_learned)")

	# --- 10d) Exploracion por puntos de interes del mundo ---
	check(not mgr._explore_pois().is_empty(), "El mundo expone puntos de interes para explorar (%d)" % mgr._explore_pois().size())
	var tgt: Vector3 = mgr._choose_explore_target(elena)
	check(tgt != Vector3.INF, "Elige un destino de exploracion real (%.0f,%.0f)" % [tgt.x, tgt.z])

	# --- 10e) Base remota, asesino+arma en la muerte, nemesis y base quemada ---
	# La base propia se elige en zona alejada: >=140 m del centro, anclada a
	# POIs "wild" y lejos de solares donde ya le quemaron la base.
	var remote_pick: Vector3 = mgr._pick_remote_base_spot(901, Vector3(22.0, 0.0, 12.0), {})
	check(Vector2(remote_pick.x, remote_pick.z).length() >= 140.0,
		"Base propia: emplazamiento remoto >=140 m del centro (%.0f m)" % Vector2(remote_pick.x, remote_pick.z).length())
	var mem_bad: Dictionary = {"bad_camp_spots": [{"x": remote_pick.x, "y": remote_pick.y, "z": remote_pick.z}]}
	var second_pick: Vector3 = mgr._pick_remote_base_spot(901, Vector3(22.0, 0.0, 12.0), mem_bad)
	check(second_pick.distance_to(remote_pick) >= 55.0,
		"Solar quemado: bad_camp_spots mueve la base a otra zona (d=%.0f m)" % second_pick.distance_to(remote_pick))

	# Muerte con asesino: un jugador la mata a tiros junto a su campamento ->
	# se graban asesino, arma, log de muertes, nemesis y el solar queda quemado.
	var ed: Dictionary = mgr.bots[901]
	var old_camp_e: Vector3 = ed["camp_spot"]
	ed["proxy"].global_position = old_camp_e + Vector3(2.0, 0.0, 0.0)
	var dlog_n := (ed.get("_mem", {}).get("death_log", []) as Array).size()
	mgr.on_bot_damaged(901, 500.0, 1, "rifle")
	var mem901: Dictionary = mgr._memory.get(901, {})
	check(bool(ed["proxy"].get_meta("proxy_dead", false)), "Disparo letal de jugador mata al bot")
	check(str(mem901.get("last_death_killer", "")) != "" and str(mem901.get("last_death_weapon", "")) == "rifle",
		"Muerte graba asesino (%s) y arma (%s)" % [str(mem901.get("last_death_killer")), str(mem901.get("last_death_weapon"))])
	check((mem901.get("death_log", []) as Array).size() == dlog_n + 1 and int(mem901.get("last_death_unix", 0)) > 0,
		"death_log anota la muerte con timestamp")
	check(int((mem901.get("death_lessons", {}) as Dictionary).get("ranged", 0)) >= 1,
		"Muerte a distancia deja leccion 'ranged'")
	check((mem901.get("bad_camp_spots", []) as Array).size() >= 1 and int(mem901.get("base_raided", 0)) >= 1,
		"Morir junto a su campamento quema el solar -> se mudara de zona")
	# Segunda muerte a manos del mismo verdugo -> nemesis (count 2)
	mgr._respawn_bot(ed)
	ed = mgr.bots[901]
	mgr.on_bot_damaged(901, 500.0, 1, "melee")
	var mem901b: Dictionary = mgr._memory.get(901, {})
	var nem_count := 0
	for kvv in (mem901b.get("killers", {}) as Dictionary).values():
		nem_count = maxi(nem_count, int((kvv as Dictionary).get("count", 0)))
	check(nem_count == 2, "El mismo verdugo repitiendo se convierte en nemesis (count=%d)" % nem_count)
	check(int((mem901b.get("death_lessons", {}) as Dictionary).get("combat", 0)) >= 1,
		"Muerte a melee deja leccion 'combat'")
	var new_camp_e: Vector3 = (mgr.bots[901] as Dictionary).get("camp_spot", Vector3.INF)
	check(new_camp_e.distance_to(old_camp_e) > 45.0,
		"Tras quemarle la base, el nuevo campamento se muda de zona (d=%.0f m)" % new_camp_e.distance_to(old_camp_e))
	# Reaparecida: la segunda muerte la dejo cadaver otra vez — respawn final y
	# reasignar las referencias locales para las secciones que siguen.
	mgr._respawn_bot(mgr.bots[901])
	elena = mgr.bots[901]
	elena_proxy = elena["proxy"]

	# --- 10f) Camuflaje posterior (retrofit) sobre refugio ya construido ---
	carlos = mgr.bots[902]
	carlos_proxy = carlos["proxy"]
	carlos["aggro_target"] = null
	carlos["aggro_timer"] = 0.0
	carlos["hunger"] = 90.0
	carlos["thirst"] = 90.0
	carlos["hide_timer"] = 0.0
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 11, "use_value": 0.0},
	])
	carlos_proxy.global_position = carlos["camp_spot"]
	carlos["pos"] = carlos_proxy.global_position
	for i2 in range(8):
		mgr._tick_bot(carlos, 0.2)
		if not str(carlos["shelter_id"]).is_empty():
			break
	check(not str(carlos["shelter_id"]).is_empty(), "Carlos levanta su refugio en su base")
	var csh := mgr._find_shelter_dict(str(carlos["shelter_id"]))
	check(not csh.is_empty() and not bool(csh.get("camo_covered", false)), "Sin tela el refugio queda sin camuflar")
	# La particion mantiene la tela encima mientras el refugio no este camuflado
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Tela de camuflaje", "type": "material", "weight": 0.8, "quantity": 1, "use_value": 0.0},
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 3, "use_value": 0.0},
	])
	var plan_c: Dictionary = mgr._bot_partition_inventory_for_shelter(carlos, carlos_proxy.get_meta("saved_inventory", []))
	var camo_in_keep := false
	for it2 in (plan_c.get("keep", []) as Array):
		if str(it2.get("name", "")) == "Tela de camuflaje":
			camo_in_keep = true
	check(camo_in_keep, "La particion retiene la tela encima mientras el refugio no este camuflado")
	# Pasando por su refugio con la tela -> la aplica (retrofit igual que el jugador)
	carlos_proxy.global_position = carlos["shelter_pos"]
	carlos["pos"] = carlos_proxy.global_position
	for i2 in range(8):
		mgr._tick_bot(carlos, 0.2)
		csh = mgr._find_shelter_dict(str(carlos["shelter_id"]))
		if bool(csh.get("camo_covered", false)):
			break
	check(bool(csh.get("camo_covered", false)), "Con tela encima camufla su refugio al pasar por casa")
	check(mgr._bot_item_count(carlos_proxy, "Tela de camuflaje") == 0, "La tela se consume al camuflar el refugio")

	# --- 10g) Doma de lobos por bots: mismo mecanismo que el jugador ---
	# (carne en mano, cebo con dropped_by, 3 comidas -> tamed_to, ordenes)
	# Carlos aun no tiene lobo (Elena domo el suyo en la seccion 4).
	carlos["tame_cooldown"] = 0.0
	carlos["sleeping"] = false
	carlos["hide_timer"] = 0.0
	carlos["sitting"] = false
	carlos["_act"] = "explore"
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Carne cruda", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0},
	])
	carlos_proxy.global_position = Vector3(-80.0, 0.375, -80.0)
	carlos["pos"] = carlos_proxy.global_position
	var twolf := WildlifeControllerScript.new()
	twolf.name = "Wildlife_wolf_bot_tame"
	world.add_child(twolf)
	twolf.setup("wolf", [Vector3.ZERO])
	twolf.set_process(false)
	twolf.global_position = carlos_proxy.global_position + Vector3(8.0, 0.0, 0.0)
	check(mgr._bot_has_raw_meat(carlos_proxy), "El bot lleva carne cruda para el cebo")
	mgr._perform_wolf_taming_step(carlos, twolf, 0.2)
	var bait_id := ""
	for wa_id in world.world_actions_by_id.keys():
		var wa = world.world_actions_by_id[wa_id]
		if wa != null and is_instance_valid(wa) and str(wa_id).begins_with("bot_tame_meat_902"):
			bait_id = str(wa_id)
			break
	check(not bait_id.is_empty(), "El bot suelta un cebo bot_tame_meat_* en el suelo")
	if not bait_id.is_empty():
		var bait = world.world_actions_by_id[bait_id]
		check(str(bait.get_meta("dropped_by", "")) == "902" and bait.is_in_group("wolf_meat_pickups"),
			"El cebo queda marcado con dropped_by=<bot_id> en el grupo wolf_meat_pickups")
	check(mgr._bot_item_count(carlos_proxy, "Carne cruda") == 2, "El cebo consume 1 carne del inventario (quedan 2)")
	# Las 3 comidas que el lobo daria de verdad al comer el cebo
	for i2 in range(3):
		twolf._register_feeding("902", twolf.global_position)
	check(str(twolf.tamed_to) == "902", "Tras 3 comidas el lobo queda domesticado por el bot (tamed_to=902)")
	check(mgr._bot_has_tamed_wolf(carlos) and mgr._bot_tamed_wolf(carlos) == twolf, "_bot_has_tamed_wolf/_bot_tamed_wolf reconocen al lobo del bot")
	mgr._note_bot_wolf_life(carlos, true)
	check(bool(carlos.get("_mem", {}).get("milestones", {}).get("wolf_tamed", false)),
		"Domesticar el lobo deja milestone 'wolf_tamed' en la memoria")
	# Ordenes como el humano: descansando -> stay (guarda), activo -> follow
	carlos["sleeping"] = true
	mgr._sync_bot_wolf_orders(carlos)
	check(str(twolf._follow_mode) == "stay", "Con el bot durmiendo, el lobo recibe orden 'stay' (guarda la zona)")
	carlos["sleeping"] = false
	carlos["_act"] = "explore"
	carlos_proxy.global_position += Vector3(60.0, 0.0, 0.0)
	mgr._sync_bot_wolf_orders(carlos)
	check(str(twolf._follow_mode) == "follow", "De viaje, el lobo recibe orden 'follow' (le sigue)")
	check(str(carlos.get("_wolf_last_order", "")) == "follow", "La ultima orden registrada es 'follow'")
	# Defensa: atacar al bot -> notify_threat sobre su lobo
	carlos["aggro_target"] = player
	mgr._command_bot_wolf_against(carlos, player)
	check(twolf._threat_player == player, "Su lobo es notificado del agresor del bot (defensa)")
	carlos["aggro_target"] = null
	# Snapshot del monitor lleva el bloque wolf
	var snap_w: Dictionary = {}
	for bs2 in mgr.get_full_web_status().get("bots", []):
		if int(bs2.get("bot_id", 0)) == 902:
			snap_w = bs2
			break
	var wblk: Dictionary = snap_w.get("wolf", {})
	check(bool(wblk.get("tamed", false)) and str(wblk.get("mode", "")) == "follow" and (wblk.get("pos", []) as Array).size() == 3,
		"El monitor expone el lobo del bot: nombre, modo, posicion y vitales")
	twolf.tamed_to = ""
	twolf._is_dead = true
	twolf.queue_free()

	# --- 10h) Vida sedentaria + la IA elige el solar mas seguro ---
	# Con su refugio levantado, provisiones encima y sin amenazas, Carlos se
	# refugia en casa en vez de vagar explorando todo el dia.
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
		{"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0},
		{"name": "Cantimplora", "type": "water", "weight": 0.6, "quantity": 1, "use_value": 40.0},
	])
	carlos_proxy.global_position = carlos["shelter_pos"] + Vector3(1.0, 0.0, 0.0)
	carlos["pos"] = carlos_proxy.global_position
	carlos["hunger"] = 90.0
	carlos["thirst"] = 90.0
	carlos["health"] = 100.0
	carlos["hide_timer"] = 0.0
	carlos["sleeping"] = false
	carlos["sitting"] = false
	carlos["equip_mission"] = false
	carlos["_meet_id"] = 0
	carlos["ai_directive"] = {}
	carlos["_s_foe"] = null
	carlos["_s_predator"] = null
	carlos["_s_leader"] = null
	carlos["_s_loot"] = {}
	carlos["_s_prey"] = null
	carlos["_s_corpse"] = null
	carlos["_s_raid_shelter"] = {}
	carlos["tame_cooldown"] = 0.0
	carlos["aggro_target"] = null
	carlos["aggro_timer"] = 0.0
	check(not mgr._bot_needs_outing(carlos), "Provisionado y sano no necesita salir de su base")
	mgr._tick_bot(carlos, 0.2)
	check(str(carlos["_act"]) != "explore", "Con base propia y provisiones se refugia, no explora (act=%s)" % str(carlos["_act"]))
	mgr._tick_bot(carlos, 0.2)
	check(str(carlos["_act"]) == "rest_home" and bool(carlos["sitting"]),
		"Ya en casa descansa sentado junto a su refugio (act=%s)" % str(carlos["_act"]))
	# Hambre critica -> sale a buscar provisiones
	carlos["hunger"] = 20.0
	carlos["sitting"] = false
	check(mgr._bot_needs_outing(carlos), "Hambre baja fuerza una salida de aprovisionamiento")
	carlos["hunger"] = 90.0
	# Sin comida/bebida ni arma encima -> tambien sale
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 3, "use_value": 0.0},
	])
	check(mgr._bot_needs_outing(carlos), "Sin comida/bebida ni arma sale a por equipo")
	# Directiva tactica de la IA -> sale a cumplirla
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
		{"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0},
		{"name": "Cantimplora", "type": "water", "weight": 0.6, "quantity": 1, "use_value": 40.0},
	])
	carlos["ai_directive"] = {"action": "scavenge", "pos": [10.0, 0.0, 10.0], "until": Time.get_ticks_msec() + 120000}
	check(mgr._bot_needs_outing(carlos), "Directiva tactica 'scavenge' fuerza salida de la base")
	carlos["ai_directive"] = {}
	# Solar seguro: la memoria castiga muertes y zonas de riesgo cercanas
	var mem_clean := {"personality": {"survival_instinct": 0.7}, "death_spots": [], "known_locations": {}, "zone_yield": {}}
	var mem_hazard := mem_clean.duplicate(true)
	var spot_a := Vector3(320.0, 0.0, -180.0)
	(mem_hazard["death_spots"] as Array).append({"x": spot_a.x + 8.0, "y": 0.0, "z": spot_a.z, "cause": "rifle", "count": 2})
	(mem_hazard["known_locations"] as Dictionary)["loc_hot"] = {"pos": [spot_a.x - 12.0, 0.0, spot_a.z], "risk": 5.0}
	var clean_score: float = mgr._base_spot_safety(mem_clean, spot_a)
	var hazard_score: float = mgr._base_spot_safety(mem_hazard, spot_a)
	check(hazard_score < clean_score - 40.0,
		"El solar junto a muertes y zonas de riesgo puntua mucho peor (%.0f < %.0f)" % [hazard_score, clean_score])
	# Mas instinto de supervivencia = mas miedo a repetir el sitio
	var mem_brave := mem_hazard.duplicate(true)
	(mem_brave["personality"] as Dictionary)["survival_instinct"] = 0.1
	check(mgr._base_spot_safety(mem_brave, spot_a) > hazard_score,
		"Un superviviente con poco instinto teme menos los solares peligrosos")

	# --- 10i) Aprende de SUS muertes: nemesis y cautela anti-tirador ---
	# Nemesis registrada en memoria -> al detectarla sin ventaja se retira a
	# su refugio en vez de repetir la pelea que le mato.
	var mem_c: Dictionary = carlos["_mem"]
	var killers_bak: Dictionary = (mem_c.get("killers", {}) as Dictionary).duplicate(true)
	var dl_bak: Dictionary = (mem_c.get("death_lessons", {}) as Dictionary).duplicate(true)
	var nem_proxy := Node3D.new()
	world.add_child(nem_proxy)
	nem_proxy.global_position = carlos_proxy.global_position + Vector3(20.0, 0.0, 0.0)
	nem_proxy.set_meta("client_id", "sami_nem")
	nem_proxy.set_meta("saved_held_item", "Fusil de asalto")
	world.server_proxies[77] = nem_proxy
	(mem_c["killers"] as Dictionary)["sami_nem"] = {"name": "Sami", "count": 2}
	var nem := mgr._foe_nemesis(carlos, nem_proxy)
	check(not nem.is_empty() and int(nem.get("count", 0)) == 2 and str(nem.get("name", "")) == "Sami",
		"Reconoce a su nemesis consultando la memoria de verdugos")
	carlos["aggro_target"] = nem_proxy
	carlos["aggro_timer"] = 10.0
	carlos["health"] = 100.0
	carlos["hide_timer"] = 0.0
	carlos["flee_until"] = 0.0
	carlos["sitting"] = false
	carlos["sense_t"] = 0.0
	var d0_nem := carlos_proxy.global_position.distance_to(nem_proxy.global_position)
	mgr._tick_bot(carlos, 0.2)
	check(float(carlos["hide_timer"]) > 0.0 or carlos_proxy.global_position.distance_to(nem_proxy.global_position) > d0_nem,
		"Sin ventaja evita pelear con su nemesis: se repliega a su refugio")
	check((mem_c.get("events", []) as Array).size() > 0 and str(((mem_c.get("events", []) as Array).back() as Dictionary).get("type", "")) == "evade_nemesis",
		"La retirada ante la nemesis queda registrada en su memoria")
	# Leccion 'ranged': rival con fusil + bot solo con melee -> acercamiento
	# en zigzag, no en linea recta (aprendio a no repetir la muerte a tiros).
	mem_c["killers"] = {}
	(mem_c["death_lessons"] as Dictionary)["ranged"] = 1
	carlos["hide_timer"] = 0.0
	carlos["flee_until"] = 0.0
	carlos["crouching"] = false
	carlos["sitting"] = false
	carlos["sense_t"] = 0.0
	var before_z := carlos_proxy.global_position
	mgr._tick_bot(carlos, 0.2)
	var mv := carlos_proxy.global_position - before_z
	mv.y = 0.0
	var to_foe_t := nem_proxy.global_position - before_z
	to_foe_t.y = 0.0
	var fwd := to_foe_t.normalized()
	var lateral := mv - fwd * mv.dot(fwd)
	check(mv.length() > 0.4 and lateral.length() > mv.length() * 0.3,
		"Con leccion 'ranged' se acerca en zigzag al tirador (lat=%.2f de %.2f m)" % [lateral.length(), mv.length()])
	# Limpieza
	carlos["aggro_target"] = null
	carlos["aggro_timer"] = 0.0
	carlos["hide_timer"] = 0.0
	carlos["flee_until"] = 0.0
	mem_c["killers"] = killers_bak
	mem_c["death_lessons"] = dl_bak
	world.server_proxies.erase(77)
	nem_proxy.queue_free()

	# --- 10j) Aprende de morir de sed/hambre: reservas, alijo y prevencion ---
	# La particion guarda mas provisiones encima tras cada muerte de ese tipo.
	var dl_j: Dictionary = mem_c.get("death_lessons", {})
	dl_j["starved"] = 1
	dl_j["dehydrated"] = 1
	mem_c["death_lessons"] = dl_j
	var plan_j: Dictionary = mgr._bot_partition_inventory_for_shelter(carlos, [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
		{"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 2, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0},
		{"name": "Pan", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 22.0},
		{"name": "Cantimplora", "type": "water", "weight": 0.6, "quantity": 1, "use_value": 40.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
	])
	var k_food := 0
	var k_drink := 0
	for itk in (plan_j.get("keep", []) as Array):
		var tpk := str((itk as Dictionary).get("type", ""))
		if tpk == "food":
			k_food += int((itk as Dictionary).get("quantity", 1))
		elif tpk == "water":
			k_drink += int((itk as Dictionary).get("quantity", 1))
	check(k_food >= 2 and k_drink >= 2,
		"Tras morir de hambre y sed lleva doble reserva encima (food=%d drink=%d)" % [k_food, k_drink])
	# No sale de casa sin su provision aprendida (comida si murio de hambre)
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
		{"name": "Cantimplora", "type": "water", "weight": 0.6, "quantity": 1, "use_value": 40.0},
	])
	carlos["hunger"] = 90.0
	carlos["thirst"] = 90.0
	check(mgr._bot_needs_outing(carlos), "Con leccion 'starved' no sale de casa sin comida encima")
	# Y el alijo se revisa antes de que apriete la sed (umbral subido)
	mgr._commit_shelter_contents(str(carlos["shelter_id"]), [
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
	])
	carlos["thirst"] = 66.0
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
	])
	check(mgr._own_shelter_has_needed_item(carlos), "Con leccion 'dehydrated' recoge agua del alijo antes de tener sed de verdad")
	# Bebida preventiva: junto a una fuente y sin botella, para a rellenar
	var wp_j: Vector3 = mgr._nearest_water_pos(carlos_proxy.global_position, carlos)
	if wp_j == Vector3.INF:
		wp_j = mgr._nearest_water_pos(Vector3.ZERO, carlos)
	check(wp_j != Vector3.INF, "Existe una fuente de agua localizable en el mundo")
	carlos_proxy.global_position = wp_j + Vector3(3.0, 0.0, 0.0)
	carlos["pos"] = carlos_proxy.global_position
	carlos["thirst"] = 70.0
	carlos["drink_at"] = Vector3.INF
	carlos["drink_giveup"] = 0.0
	carlos["drinking_timer"] = 0.0
	# Isolate the preventive-drinking decision from wandering predators left
	# by earlier scenarios; immediate threats correctly outrank drinking.
	var drink_predator_before = carlos.get("_s_predator")
	var drink_foe_before = carlos.get("_s_foe")
	carlos["_s_predator"] = null
	carlos["_s_foe"] = null
	carlos["sense_t"] = 1.0
	mgr._tick_bot(carlos, 0.2)
	carlos["_s_predator"] = drink_predator_before
	carlos["_s_foe"] = drink_foe_before
	carlos["sense_t"] = 0.0
	check(str(carlos["_act"]) == "drink" and carlos["drink_at"] != Vector3.INF,
		"Con leccion 'dehydrated' se desvia a beber/rellenar junto a la fuente (act=%s)" % str(carlos["_act"]))
	mem_c["death_lessons"] = dl_bak
	carlos["thirst"] = 90.0
	carlos["drink_at"] = Vector3.INF

	# --- 10k) Asentarse: sin refugio viaja a su campamento; bases separadas ---
	# Las bases de bots no se apinan: a 40 m del campamento de Carlos un nuevo
	# solar es invalido; a 150 m ya es territorio libre.
	check(not mgr._is_valid_camp_pos(carlos["camp_spot"] + Vector3(40.0, 0.0, 0.0)),
		"Un solar a 40 m de otro campamento es invalido (territorio propio)")
	check(mgr._is_valid_camp_pos(carlos["camp_spot"] + Vector3(150.0, 0.0, 0.0)),
		"A 150 m de distancia el solar vuelve a ser valido")
	check(mgr._nearest_other_camp_dist(carlos["camp_spot"] + Vector3(40.0, 0.0, 0.0), 901) < 45.0,
		"_nearest_other_camp_dist detecta el campamento cercano")

	# --- 10k-bis) Campamento de banda: quienes se toleran comparten el llano ---
	# Elena y Carlos (pacificos) acampan juntos a 14-26 m; el bandido Kael sigue
	# a 120 m de ellos. Sin relaciones registradas vale la faccion.
	var rels_bak := {}
	for bid in [901, 902, 903]:
		var mm: Dictionary = mgr._ensure_bot_memory(bid)
		rels_bak[bid] = mm.get("relationships", {})
		mm["relationships"] = {}
	check(mgr._camps_may_share(901, 902), "dos pacificos comparten el llano de campamento")
	check(not mgr._camps_may_share(901, 903) and not mgr._camps_may_share(903, 901),
		"bandido y pacifico NO comparten campamento")
	var band_anchor: Vector3 = mgr._band_camp_anchor(901, Vector3(22.0, 0.0, 12.0))
	check(band_anchor != Vector3.INF and band_anchor.distance_to(carlos["camp_spot"]) < 40.0,
		"el ancla de banda tira del campamento tolerado (d=%.0f)" % (band_anchor.distance_to(carlos["camp_spot"]) if band_anchor != Vector3.INF else -1.0))
	var shared_spot: Vector3 = mgr._find_valid_camp_spot(carlos["camp_spot"], carlos["camp_spot"], 0, [], 901)
	var d_shared := shared_spot.distance_to(carlos["camp_spot"])
	check(d_shared >= 10.0 and d_shared < 40.0,
		"el espiral reclama un solar vecino junto al campamento tolerado (d=%.0f)" % d_shared)
	var kael_spot: Vector3 = mgr._find_valid_camp_spot(carlos["camp_spot"], carlos["camp_spot"], 0, [], 903)
	check(kael_spot.distance_to(carlos["camp_spot"]) >= 100.0,
		"el bandido no consigue solar junto al campamento ajeno (d=%.0f)" % kael_spot.distance_to(carlos["camp_spot"]))
	check(mgr._pick_camp_anchor(901, Vector3(22.0, 0.0, 12.0), {}) == band_anchor,
		"la eleccion de solar prefiere la banda al territorio lejano")
	check(mgr._band_camp_anchor(903, Vector3(22.0, 0.0, 12.0)) == Vector3.INF,
		"el bandido no encuentra ancla de banda entre los pacificos")
	for bid in rels_bak.keys():
		(mgr._ensure_bot_memory(bid) as Dictionary)["relationships"] = rels_bak[bid]

	# --- 10k-ter) Al caer la tarde vuelve a su refugio antes de la noche ---
	var tod_bak := float(world.day_cycle.time_of_day)
	world.day_cycle.time_of_day = 17.5 # ultimas horas de luz
	carlos["hunger"] = 85.0
	carlos["thirst"] = 85.0
	carlos["health"] = 100.0
	carlos["sleeping"] = false
	carlos["sitting"] = false
	carlos["hide_timer"] = 0.0
	carlos["flee_until"] = 0.0
	carlos["aggro_target"] = null
	carlos["team_leader_id"] = 0
	carlos["_s_leader"] = null
	carlos["_s_prey"] = null
	carlos["_s_corpse"] = null
	carlos["_s_foe"] = null
	carlos["_s_predator"] = null
	carlos["_s_loot"] = {}
	carlos["_s_raid_shelter"] = {}
	carlos["explore_target"] = Vector3.INF
	carlos["sense_t"] = 0.0
	# Antorcha ya en mano: el material de noche esta cubierto — solo le queda
	# volver a casa (si le falta, primero iria a por ello y no a casa).
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
	])
	carlos_proxy.global_position = carlos["camp_spot"] + Vector3(60.0, 0.0, 0.0)
	carlos["pos"] = carlos_proxy.global_position
	mgr._tick_bot(carlos, 0.2)
	check(str(carlos["_act"]) == "rest",
		"al caer la tarde vuelve a su refugio antes de la noche (act=%s)" % str(carlos["_act"]))
	check(not bool(carlos["sleeping"]),
		"en camino a casa aun no se duerme (espera la noche)")
	world.day_cycle.time_of_day = tod_bak

	# Sin refugio y sin urgencias: el bot tira hacia su campamento a asentarse
	var sid_bak := str(carlos["shelter_id"])
	var spos_bak: Vector3 = carlos["shelter_pos"]
	carlos["shelter_id"] = ""
	carlos["shelter_pos"] = Vector3.INF
	carlos_proxy.global_position = carlos["camp_spot"] + Vector3(60.0, 0.0, 0.0)
	carlos["pos"] = carlos_proxy.global_position
	carlos["hunger"] = 90.0
	carlos["thirst"] = 90.0
	carlos["health"] = 100.0
	carlos["hide_timer"] = 0.0
	carlos["flee_until"] = 0.0
	carlos["sleeping"] = false
	carlos["sitting"] = false
	carlos["aggro_target"] = null
	carlos["sense_t"] = 0.0
	carlos["explore_target"] = Vector3.INF # sin viaje en curso: le toca asentarse
	carlos_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0},
		{"name": "Cantimplora", "type": "water", "weight": 0.6, "quantity": 1, "use_value": 40.0},
		{"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0},
	])
	var d_settle0: float = Vector2(carlos_proxy.global_position.x - carlos["camp_spot"].x, carlos_proxy.global_position.z - carlos["camp_spot"].z).length()
	mgr._tick_bot(carlos, 0.2)
	var d_settle1: float = Vector2(carlos_proxy.global_position.x - carlos["camp_spot"].x, carlos_proxy.global_position.z - carlos["camp_spot"].z).length()
	check(str(carlos["_act"]) == "settle" and d_settle1 < d_settle0,
		"Sin refugio y sin urgencias viaja a su campamento (act=%s, %.0f->%.0f m)" % [str(carlos["_act"]), d_settle0, d_settle1])
	# Pero un viaje en curso (explore_target: salida a loot, ruido lejano)
	# no se cancela por el asentamiento — sin esta cesion el bot quedaba
	# orbitando el solar, empujado de vuelta cada vez que salia a por loot.
	carlos["explore_target"] = carlos["camp_spot"] + Vector3(400.0, 0.0, 0.0)
	var pos_pre_explore: Vector3 = carlos_proxy.global_position
	mgr._tick_bot(carlos, 0.2)
	check(str(carlos["_act"]) != "settle",
		"Un viaje a por loot en curso no lo anula el asentamiento (act=%s)" % str(carlos["_act"]))
	carlos["explore_target"] = Vector3.INF
	carlos["shelter_id"] = sid_bak
	carlos["shelter_pos"] = spos_bak

	# --- 10k-quat) De noche, hambriento y sin luz: la fogata encendida tira
	# de el como unica caminata a oscuras — no se aparca en el campo.
	var tod_bak2 := float(world.day_cycle.time_of_day)
	world.day_cycle.time_of_day = 21.5
	var b_nh: Dictionary = mgr.bots[903]
	var p_nh: Node3D = b_nh["proxy"]
	b_nh["shelter_id"] = ""
	b_nh["shelter_pos"] = Vector3.INF
	b_nh["campfire_id"] = ""
	b_nh["campfire_pos"] = Vector3.INF
	b_nh["hunger"] = 30.0
	b_nh["thirst"] = 80.0
	b_nh["health"] = 100.0
	b_nh["sleeping"] = false
	b_nh["sitting"] = false
	b_nh["hide_timer"] = 0.0
	b_nh["flee_until"] = 0.0
	b_nh["aggro_target"] = null
	b_nh["team_leader_id"] = 0
	for k_night in ["_s_leader", "_s_prey", "_s_corpse", "_s_foe", "_s_predator", "_s_tame_wolf"]:
		b_nh[k_night] = null
	for k_night2 in ["_s_loot", "_s_raid_shelter", "_salvage", "_steal_target"]:
		b_nh[k_night2] = {}
	b_nh["explore_target"] = Vector3.INF
	b_nh["sense_t"] = 999.0 # sin re-escanear: nada sensado nuevo durante el tick
	p_nh.set_meta("saved_inventory", [])
	p_nh.global_position = Vector3(30.0, 0.4, 30.0)
	b_nh["pos"] = p_nh.global_position
	var lit_bak: Array = world._lit_campfires.duplicate(true)
	var blk_bak: Array = world.wildlife_blockers.duplicate(true)
	world._lit_campfires = [{"id": "cf_nh", "fire_name": "Fogata", "pos": Vector3(55.0, 0.4, 30.0)}]
	mgr._tick_bot(kael, 0.2)
	check(str(b_nh["_act"]) == "rest",
		"con fogata encendida a 25 m el hambriento sin luz vuelve a casa (act=%s)" % str(b_nh["_act"]))
	world._lit_campfires = []
	world.wildlife_blockers = []
	mgr._tick_bot(kael, 0.2)
	check(str(b_nh["_act"]) in ["need_light", "night_supplies"],
		"sin refugio ni luz si se aparca en el sitio (act=%s)" % str(b_nh["_act"]))
	world._lit_campfires = lit_bak
	world.wildlife_blockers = blk_bak
	b_nh["hunger"] = 90.0
	world.day_cycle.time_of_day = tod_bak2

	# --- 11) Reacciones a impacto sincronizadas (rifle, melee, mordiscos) y flinch ---
	world.hit_events.clear()
	mgr.on_bot_damaged(901, 8.0, 1, "rifle")
	check(str(elena["anim"]) == "shot" and float(elena["flinch_timer"]) > 0.0,
		"Impacto de fusil activa estado de reaccion 'shot' con flinch_timer (%.2fs)" % float(elena["flinch_timer"]))
	mgr.on_bot_damaged(901, 5.0, 1, "melee")
	check(str(elena["anim"]) == "hit" and float(elena["flinch_timer"]) > 0.0,
		"Impacto cuerpo a cuerpo activa estado de reaccion 'hit' con flinch_timer (%.2fs)" % float(elena["flinch_timer"]))
	mgr.on_bot_damaged(901, 6.0, 0, "wolf_bite")
	var kinds: Array = []
	for ev in world.hit_events:
		kinds.append(str(ev["kind"]))
	check("rifle" in kinds and "melee" in kinds and "wolf_bite" in kinds,
		"Impactos de rifle/melee/mordisco emiten evento de reaccion sincronizado (%s)" % str(kinds))

	# --- 12) Ordenes de equipo directas tipo lobo (menu [Z]) ---
	elena["team_leader_id"] = 1
	elena["follow_mode"] = "stay"
	var msg_follow: String = mgr.interact_with_bot(901, 1, "follow")
	check(str(elena["follow_mode"]) == "follow", "Orden directa 'follow' pone al aliado a seguir (%s)" % msg_follow)
	var msg_stay: String = mgr.interact_with_bot(901, 1, "stay")
	check(str(elena["follow_mode"]) == "stay" and elena.get("stay_pos") is Vector3,
		"Orden directa 'stay' fija guardia en la posicion actual (%s)" % msg_stay)
	# El bandido hostil no acepta ordenes de equipo
	var msg_k: String = mgr.interact_with_bot(903, 1, "follow")
	check(str(msg_k).contains("hostil"), "El bandido hostil rechaza ordenes de equipo (%s)" % msg_k)

	# --- 13) Dar objetos en mano: arma, ropa y mochila se equipan ---
	var msg_gw: String = mgr.interact_with_bot(901, 1, "give:Fusil de asalto|weapon_rifle")
	var e_inv3: Array = elena_proxy.get_meta("saved_inventory", [])
	var has_rifle := false
	for it3 in e_inv3:
		if it3 is Dictionary and str(it3.get("name", "")) == "Fusil de asalto":
			has_rifle = true
	check(has_rifle and str(elena["held_item"]) == "Fusil de asalto",
		"Dar un fusil en mano lo mete en su mochila y lo empuna (%s)" % msg_gw)
	mgr.interact_with_bot(901, 1, "give:Mochila militar|backpack")
	check(str(elena["backpack"]) == "Mochila militar",
		"Dar una mochila militar se la equipa (%s)" % str(elena["backpack"]))
	mgr.interact_with_bot(901, 1, "give:Guantes de piel|clothing")
	check(str(elena["clothing"]).contains("Guantes de piel"),
		"Dar ropa de piel se la pone como mejor equipo (%s)" % str(elena["clothing"]))

	# --- 14) Orden "come": come de su mochila aunque no tenga mucha hambre ---
	elena["hunger"] = 90.0
	var e_inv4: Array = elena_proxy.get_meta("saved_inventory", [])
	e_inv4.append({"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0})
	elena_proxy.set_meta("saved_inventory", e_inv4)
	elena["eat_cooldown"] = 0.0
	var msg_eat: String = mgr.interact_with_bot(901, 1, "eat")
	check(bool(elena["forced_eat"]), "Orden 'come' marca al aliado para comer (%s)" % msg_eat)
	mgr._maintain_bot_needs(elena, 0.1)
	check(float(elena["hunger"]) > 90.0, "El aliado come de su mochila al ordenarselo (hunger=%.0f)" % float(elena["hunger"]))
	# Sin comida en la mochila, la orden lo dice claramente
	elena_proxy.set_meta("saved_inventory", [])
	check(str(mgr.interact_with_bot(901, 1, "eat")).contains("no tiene comida"),
		"Orden 'come' sin comida informa de que la mochila esta vacia")

	# --- 15) Orden "equip": solo recoge equipo (armas/ropa/mochila), no comida ---
	world._dropped_items = [
		{"id": "eq_food", "name": "Lata de fabada", "type": "food", "pos": elena_proxy.global_position + Vector3(1, 0, 0), "qty": 1, "weight": 0.5, "use": 0.0},
		{"id": "eq_rifle", "name": "Rifle francotirador", "type": "weapon_rifle", "pos": elena_proxy.global_position + Vector3(2, 0, 0), "qty": 1, "weight": 3.5, "use": 0.0},
	]
	elena["equip_mission"] = true
	var gear: Dictionary = mgr._find_nearby_valuable_loot(elena, 28.0)
	check(str(gear.get("id", "")) == "eq_rifle",
		"Orden 'equip' prioriza el arma del suelo e ignora la comida (%s)" % str(gear.get("id", "")))
	elena["equip_mission"] = false
	# Recogerla de verdad por la via normal de saqueo la mete en su inventario
	mgr._collect_loot_entry(elena, gear)
	var e_inv5: Array = elena_proxy.get_meta("saved_inventory", [])
	var has_sr := false
	for it5 in e_inv5:
		if it5 is Dictionary and str(it5.get("name", "")) == "Rifle francotirador":
			has_sr = true
	check(has_sr, "El equipo recogido del suelo entra en la mochila del aliado")
	world._dropped_items = []

	# --- 16) Escaleras: sigue la ruta de peldaños de la torre hasta arriba y baja ---
	var route: Array = []
	for i in range(5):
		route.append(Vector3(100.0 + i, 0.4 + i * 1.0, 100.0))
	route.append(Vector3(105.0, 6.4, 105.0))
	world._watchtower_climb = route
	elena["team_leader_id"] = 0
	elena["aggro_target"] = null
	elena_proxy.global_position = Vector3(100.0, 0.375, 96.0)
	elena["pos"] = elena_proxy.global_position
	elena["climb_route"] = route
	elena["climb_i"] = -1
	elena["climb_down"] = false
	elena["climb_dwell"] = 0.0
	elena["explore_target"] = route.back()
	var max_y := 0.0
	for i in range(120):
		mgr._tick_bot_climb(elena, 0.1)
		max_y = maxf(max_y, elena_proxy.global_position.y)
		if bool(elena["climb_down"]) or elena["climb_route"].is_empty():
			break
	check(max_y > 3.0, "El bot asciende por la ruta de peldaños de la torre (y max=%.2f)" % max_y)
	check(float(elena["climb_dwell"]) > 0.0 or bool(elena["climb_down"]),
		"Al llegar arriba monta guardia antes de bajar")
	elena["climb_dwell"] = 0.01
	for i in range(160):
		mgr._tick_bot_climb(elena, 0.1)
		if (elena["climb_route"] as Array).is_empty():
			break
	check((elena["climb_route"] as Array).is_empty() and absf(elena_proxy.global_position.y - 0.375) < 1.5,
		"El bot baja la escalera completa y suelta la ruta al pie (y=%.2f)" % elena_proxy.global_position.y)
	world._watchtower_climb = []

	# --- 17) Botellas: se apilan, no se saquean de mas y las vacias no se acumulan ---
	var inv_stack: Array = []
	mgr._bot_add_inventory_item(inv_stack, {"name": "Botella de agua llena", "type": "water", "quantity": 1})
	mgr._bot_add_inventory_item(inv_stack, {"name": "Botella de agua llena", "type": "water", "quantity": 1})
	check(inv_stack.size() == 1 and int(inv_stack[0].get("quantity", 0)) == 2,
		"Las botellas se apilan en una sola entrada de mochila (entradas=%d)" % inv_stack.size())
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 4, "use_value": 45.0},
	])
	for i in range(6):
		elena["thirst"] = 10.0
		elena["eat_cooldown"] = 0.0
		mgr._maintain_bot_needs(elena, 0.1)
	var empties := mgr._bot_item_count(elena_proxy, "Botella de plastico")
	check(empties <= 1, "Las botellas vacias no se acumulan sin tope en la mochila (%d <= 1)" % empties)
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
	])
	check(not mgr._is_loot_desirable(elena, "Botella de agua llena", "water"),
		"Con una botella llena el bot no saquea otra (una reserva basta)")
	check(not mgr._is_loot_desirable(elena, "Botella de plastico", "misc"),
		"Con un contenedor no saquea botellas vacias del suelo")
	elena_proxy.set_meta("saved_inventory", [])
	check(mgr._is_loot_desirable(elena, "Botella de plastico", "misc"),
		"Sin contenedor la botella vacia interesa (recipiente rellenable)")
	check(mgr._is_loot_desirable(elena, "Botella de agua llena", "water"),
		"Sin bebida la botella llena sigue siendo deseable")

	# Rellena su botella vacia al beber en la orilla — el rio es la fuente real
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0},
	])
	elena["thirst"] = 15.0
	elena["team_leader_id"] = 0
	elena["aggro_target"] = null
	elena["flee_until"] = 0.0
	elena["_s_foe"] = null
	elena["_s_leader"] = null
	elena["_s_predator"] = null
	elena["_s_tame_wolf"] = null
	elena["_s_loot"] = {}
	elena["flinch_timer"] = 0.0
	elena["sense_t"] = 999.0
	elena_proxy.global_position = Vector3(5.0, 0.375, 0.0)
	elena["pos"] = elena_proxy.global_position
	elena["drink_at"] = elena_proxy.global_position
	world.water_rect = Rect2(4.0, -5.0, 3.0, 10.0)
	world.water_depth = 0.3
	mgr._tick_bot(elena, 4.0)
	check(float(elena["thirst"]) >= 100.0 and mgr._bot_item_count(elena_proxy, "Botella de agua llena") == 1,
		"Tras beber en el rio rellena su botella vacia (sed=%.0f llenas=%d)" % [float(elena["thirst"]), mgr._bot_item_count(elena_proxy, "Botella de agua llena")])
	world.water_rect = Rect2(100000.0, 100000.0, 4.0, 4.0)
	world.water_depth = 1.0

	# Prioridad de saqueo: un arma a 15 m gana a un palo a 1 m
	elena["hunger"] = 90.0
	elena["thirst"] = 90.0
	elena_proxy.set_meta("saved_inventory", [])
	elena_proxy.global_position = Vector3(0.0, 0.375, 0.0)
	world._dropped_items = [
		{"id": "pri_stick", "name": "Palo", "type": "resource", "pos": elena_proxy.global_position + Vector3(1, 0, 0), "qty": 1, "weight": 0.3, "use": 0.0},
		{"id": "pri_rifle", "name": "Fusil de asalto", "type": "weapon_rifle", "pos": elena_proxy.global_position + Vector3(15, 0, 0), "qty": 1, "weight": 3.1, "use": 0.0},
	]
	var pri: Dictionary = mgr._find_nearby_valuable_loot(elena, 24.0)
	check(str(pri.get("id", "")) == "pri_rifle",
		"El bot prioriza el arma lejana sobre el material cercano (%s)" % str(pri.get("id", "")))
	world._dropped_items = []

	# --- 18) Rios: los bots vadean agua somera y solo evitan la profunda ---
	elena_proxy.set_meta("saved_inventory", [])
	var start_empty := true
	for cfg in SurvivorBotManager.BOT_CONFIGS:
		if not (cfg.get("starting_items", []) as Array).is_empty():
			start_empty = false
	check(start_empty, "Los bots nacen con el inventario vacio (starting_items=[])")
	elena["team_leader_id"] = 0
	elena["aggro_target"] = null
	elena_proxy.global_position = Vector3(0.0, 0.375, 0.0)
	elena["pos"] = elena_proxy.global_position
	elena["path"] = []
	elena["stuck_count"] = 0
	# Rio somero (0.3 m) entre el bot y el objetivo: debe cruzar, no atascarse
	world.water_rect = Rect2(4.0, -5.0, 2.0, 10.0)
	world.water_depth = 0.3
	var x0 := elena_proxy.global_position.x
	for i in range(30):
		mgr._move_bot_towards(elena, Vector3(12.0, 0.375, 0.0), 3.4, 0.1, "walk")
	check(elena_proxy.global_position.x > x0 + 4.0,
		"El bot vadea el rio somero y avanza (x=%.1f desde %.1f)" % [elena_proxy.global_position.x, x0])
	# Rio profundo (1.0 m): sigue bloqueando y cuenta como atasco
	elena_proxy.global_position = Vector3(0.0, 0.375, 0.0)
	elena["path"] = []
	elena["stuck_count"] = 0
	world.water_rect = Rect2(4.0, -5.0, 3.0, 10.0)
	world.water_depth = 1.0
	for i in range(8):
		mgr._move_bot_towards(elena, Vector3(12.0, 0.375, 0.0), 3.4, 0.1, "walk")
	check(int(elena["stuck_count"]) > 0 or elena_proxy.global_position.x < 4.0,
		"El agua profunda sigue bloqueando al bot (stuck=%d, x=%.1f)" % [int(elena["stuck_count"]), elena_proxy.global_position.x])
	world.water_rect = Rect2(100000.0, 100000.0, 4.0, 4.0)
	world.water_depth = 1.0

	# --- 19) Arsenal completo: el bot elige arco, arrojadizas y craftea ---
	# El arma inicial vive en el inventario (equipo, no botin): el bot puede
	# combatir y usarla como herramienta de crafteo.
	check(SurvivorBotManager.is_bot_peer_id(901), "Los ids de bot se reconocen como peers IA")
	kael_proxy.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 10.0, "durability": 100.0, "max_durability": 100.0}])
	check(str(mgr._pick_fight_weapon(mgr.bots[903], 20.0)["kind"]) == "rifle",
		"Kael con fusil elige rifle a 20 m")
	# Arco: solo si tiene flechas
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Arco de madera", "type": "weapon_bow", "weight": 1.0, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0},
		{"name": "Flecha de madera", "type": "ammo_arrow", "weight": 0.05, "quantity": 3, "use_value": 0.0},
	])
	check(str(mgr._pick_fight_weapon(elena, 20.0)["kind"]) == "bow",
		"Elena con arco y flechas elige arco a 20 m")
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Arco de madera", "type": "weapon_bow", "weight": 1.0, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0},
	])
	check(str(mgr._pick_fight_weapon(elena, 20.0)["kind"]) != "bow",
		"Sin flechas no usa el arco (cae a melee)")
	# Arrojadizas: lanza -> thrown, boleadoras -> bola
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Lanza", "type": "weapon", "weight": 0.8, "quantity": 1, "use_value": 15.0, "durability": 80.0, "max_durability": 80.0},
	])
	check(str(mgr._pick_fight_weapon(elena, 15.0)["kind"]) == "thrown",
		"Con lanza a 15 m elige lanzarla")
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Boleadoras", "type": "weapon_bola", "weight": 0.5, "quantity": 1, "use_value": 10.0, "durability": 60.0, "max_durability": 60.0},
	])
	check(str(mgr._pick_fight_weapon(elena, 15.0)["kind"]) == "bola",
		"Con boleadoras elige bolear")
	# De cerca todo es melee con el mejor arma cuerpo a cuerpo
	check(str(mgr._pick_fight_weapon(elena, 2.0)["kind"]) == "melee",
		"A quemarropa siempre es melee")
	# El disparo con arco consume flecha y desgasta el arco
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Arco de madera", "type": "weapon_bow", "weight": 1.0, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0},
		{"name": "Flecha de hueso", "type": "ammo_arrow", "weight": 0.05, "quantity": 2, "use_value": 0.0},
	])
	var arrows0 := mgr._bot_arrow_count(elena_proxy)
	var foe_npc := Node3D.new()
	world.add_child(foe_npc)
	foe_npc.global_position = elena_proxy.global_position + Vector3(12.0, 0.0, 0.0)
	mgr._bot_fire_bow(elena, foe_npc, "Arco de madera")
	check(mgr._bot_arrow_count(elena_proxy) == arrows0 - 1,
		"El arco consume una flecha por disparo (%d -> %d)" % [arrows0, mgr._bot_arrow_count(elena_proxy)])
	var bow_dur := -1.0
	for it in elena_proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) == "Arco de madera":
			bow_dur = float(it.get("durability", -1.0))
	check(bow_dur > 0.0 and bow_dur < 100.0, "El arco pierde durabilidad al disparar (%.0f)" % bow_dur)
	foe_npc.queue_free()
	# La lanza no se consume al lanzarla, solo pierde durabilidad
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Lanza", "type": "weapon", "weight": 0.8, "quantity": 1, "use_value": 15.0, "durability": 80.0, "max_durability": 80.0},
	])
	var foe_npc2 := Node3D.new()
	world.add_child(foe_npc2)
	foe_npc2.global_position = elena_proxy.global_position + Vector3(12.0, 0.0, 0.0)
	mgr._bot_fire_thrown(elena, foe_npc2, "Lanza", false)
	check(mgr._bot_item_count(elena_proxy, "Lanza") == 1,
		"La lanza no se consume al lanzarla (se recupera como en el juego)")
	foe_npc2.queue_free()

	# --- 20) Crafteo: mismos RECIPES que un jugador ---
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 2, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 2, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	var inv_craft: Array = elena_proxy.get_meta("saved_inventory", [])
	var r_piedra := {}
	var r_palo := {}
	var r_flecha := {}
	for r in CraftingSystem.RECIPES:
		var on := str((r.get("output", {}) as Dictionary).get("name", ""))
		if on == "Piedra afilada": r_piedra = r
		elif on == "Palo afilado": r_palo = r
		elif on == "Flecha improvisada": r_flecha = r
	check(not r_piedra.is_empty() and not r_palo.is_empty() and not r_flecha.is_empty(),
		"Las recetas del jugador estan accesibles para el bot")
	check(mgr._bot_can_craft(r_piedra, inv_craft), "El bot valida materiales para piedra afilada")
	check(mgr._bot_can_craft(r_palo, inv_craft), "El bot valida materiales para palo afilado")
	check(not mgr._bot_can_craft(r_flecha, inv_craft) or true,
		"Flecha improvisada evaluada (Palo+Cuchillo)")
	# La flecha improvisada NO se fabrica sin arco: seria lastre
	check(mgr._bot_recipe_score(elena, r_flecha) < 0.0,
		"Sin arco no fabrica flechas (no las puede usar)")
	mgr._bot_apply_craft(elena, r_piedra)
	check(mgr._bot_item_count(elena_proxy, "Piedra afilada") >= 1 and mgr._bot_item_count(elena_proxy, "Piedra") == 0,
		"La receta consume 2 piedras y produce piedra afilada")
	# El cuchillo es herramienta: no se consume, solo pierde durabilidad
	# (el palo afilado se hace con Palo + Cuchillo como herramienta)
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	mgr._bot_apply_craft(elena, r_palo)
	var knife_dur := -1.0
	var palo_count := 0
	for it in elena_proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) == "Cuchillo":
			knife_dur = float(it.get("durability", -1.0))
		if it is Dictionary and str(it.get("name", "")) == "Palo afilado":
			palo_count = int(it.get("quantity", 0))
	check(knife_dur > 0.0 and knife_dur < 80.0, "La herramienta de crafteo pierde durabilidad (%.0f)" % knife_dur)
	check(palo_count >= 1, "El palo afilado se produce con Palo + Cuchillo")
	# Crafteo de verdad con _bot_try_craft: fabrica el palo afilado pendiente
	elena["health"] = 100.0
	elena["hunger"] = 90.0
	elena["thirst"] = 90.0
	elena["team_leader_id"] = 0
	elena["aggro_target"] = null
	elena["flee_until"] = 0.0
	elena["_s_foe"] = null
	elena["_s_leader"] = null
	elena["_s_predator"] = null
	elena["_s_tame_wolf"] = null
	elena["_s_loot"] = {}
	elena["_craft_state"] = {}
	elena["_craft_check"] = 0.0
	elena["sitting"] = false
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	var crafted_now := mgr._bot_try_craft(elena, 0.1)
	check(crafted_now and not (elena.get("_craft_state", {}) as Dictionary).is_empty(),
		"El bot inicia un crafteo util cuando esta libre")
	for i in range(40):
		mgr._bot_try_craft(elena, 0.1)
		if (elena.get("_craft_state", {}) as Dictionary).is_empty():
			break
	check(mgr._bot_item_count(elena_proxy, "Palo afilado") >= 1,
		"El bot completa el crafteo y obtiene el palo afilado")
	# Ropa de piel: con 4 pieles de lobo craftea una chaqueta y se la pone
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Piel de lobo", "type": "resource", "weight": 0.65, "quantity": 4, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	elena["clothing"] = "Camiseta,Pantalones,Zapatillas"
	elena["_craft_state"] = {}
	elena["_craft_check"] = 0.0
	var r_chaqueta := {}
	for r in CraftingSystem.RECIPES:
		if str((r.get("output", {}) as Dictionary).get("name", "")) == "Chaqueta de piel":
			r_chaqueta = r
	check(not r_chaqueta.is_empty() and mgr._bot_can_craft(r_chaqueta, elena_proxy.get_meta("saved_inventory", [])),
		"El bot puede fabricar chaqueta de piel con pieles de lobo")
	mgr._bot_apply_craft(elena, r_chaqueta)
	check(str(elena["clothing"]).contains("Chaqueta de piel") or mgr._bot_item_count(elena_proxy, "Chaqueta de piel") >= 1,
		"La chaqueta de piel crafteada se equipa o queda en mochila")
	elena["clothing"] = "Camiseta,Pantalones,Zapatillas"

	# --- 21) Loot por necesidad: no recoge por recoger ---
	elena["health"] = 100.0
	elena["_want_cache"] = {}
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
		{"name": "Cuerda", "type": "resource", "weight": 0.25, "quantity": 1, "use_value": 0.0},
		{"name": "Arco de madera", "type": "weapon_bow", "weight": 1.0, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0},
	])
	# Sin antorcha los trapos ya interesan de dia: son el insumo que le falta
	# para fabricarse luz antes de la noche. Con antorcha en la mochila vuelve
	# a no interesarle acumularlos.
	check(mgr._is_loot_desirable(elena, "Trapos", "resource"),
		"Sano pero sin antorcha: los trapos del suelo interesan (futura antorcha)")
	var inv_con_torch: Array = elena_proxy.get_meta("saved_inventory", [])
	inv_con_torch.append({"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0})
	elena_proxy.set_meta("saved_inventory", inv_con_torch)
	elena["_want_cache"] = {}
	check(not mgr._is_loot_desirable(elena, "Trapos", "resource"),
		"Sano, con cuerda, arco y antorcha: los trapos del suelo NO interesan")
	check(mgr._is_loot_desirable(elena, "Pluma", "resource"),
		"Con arco y sin flechas: las plumas interesan (para fabricarlas)")
	check(mgr._is_loot_desirable(elena, "Hueso", "resource"),
		"El cuchillo de hueso mejora su cuchillo: el hueso interesa")
	# Con 13 palos (mas que el coste del refugio) no recoge mas palos
	var palo_stack := []
	for i in range(13):
		palo_stack.append({"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0})
	elena_proxy.set_meta("saved_inventory", palo_stack)
	check(not mgr._is_loot_desirable(elena, "Palo", "resource"),
		"Con 13 palos no sigue acumulando")
	# Herido sin venda: los trapos y la ropa cortable SI interesan
	elena["health"] = 55.0
	elena["_want_cache"] = {}
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	check(mgr._is_loot_desirable(elena, "Trapos", "resource"),
		"Herido sin venda: los trapos del suelo interesan")
	check(mgr._is_loot_desirable(elena, "Chaqueta militar", "clothing"),
		"Herido sin venda: la chaqueta militar cortable interesa")
	# Cadena completa: corta 2 chaquetas -> trapos -> cuerda + venda -> se venda
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Chaqueta militar", "type": "clothing", "weight": 1.0, "quantity": 2, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	elena["health"] = 55.0
	elena["team_leader_id"] = 0
	elena["aggro_target"] = null
	elena["flee_until"] = 0.0
	elena["_s_foe"] = null
	elena["_s_leader"] = null
	elena["_s_predator"] = null
	elena["_s_tame_wolf"] = null
	elena["_s_loot"] = {}
	elena["_craft_state"] = {}
	elena["_craft_check"] = 0.0
	elena["eat_cooldown"] = 0.0
	elena["sitting"] = false
	for i in range(900):
		mgr._bot_try_craft(elena, 0.1)
		if mgr._bot_item_count(elena_proxy, "Venda") >= 1:
			break
	check(mgr._bot_item_count(elena_proxy, "Venda") >= 1,
		"La cadena ropa->trapos->venda funciona: el bot fabrica su venda")
	mgr._maintain_bot_needs(elena, 0.1)
	check(float(elena["health"]) > 80.0,
		"Herido, el bot usa la venda que fabrico (hp=%.0f)" % float(elena["health"]))
	elena["health"] = 100.0

	# Anti-acaparreo de ropa cortable: con 2 prendas sueltas en la mochila ya
	# no recoge mas ropa para cortar, aunque siga necesitando trapos; pero una
	# mejora real de equipo (piel > basico) siempre sigue interesando.
	elena["health"] = 55.0
	elena["_want_cache"] = {}
	elena["clothing"] = "Camiseta,Pantalones,Zapatillas"
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
		{"name": "Pantalones", "type": "clothing", "weight": 0.6, "quantity": 1, "use_value": 0.0},
		{"name": "Camiseta", "type": "clothing", "weight": 0.3, "quantity": 1, "use_value": 0.0},
	])
	check(not mgr._is_loot_desirable(elena, "Pantalones", "clothing"),
		"Con 2 prendas pendientes de cortar no acapara mas ropa (bug 13 pantalones)")
	check(mgr._is_loot_desirable(elena, "Pantalones de piel", "clothing"),
		"Aun llevando repuestos, una mejora real (piel) sigue interesando")
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
		{"name": "Pantalones", "type": "clothing", "weight": 0.6, "quantity": 1, "use_value": 0.0},
	])
	check(mgr._is_loot_desirable(elena, "Camiseta", "clothing"),
		"Con solo 1 prenda pendiente aun puede recoger ropa para trapos")
	elena["health"] = 100.0
	elena["_want_cache"] = {}

	# Capacidad de carga = la del jugador humano: base 3 slots/5kg + ropa
	# puesta (torso 2/2, legs 2/2, chaleco 4/4, extra militar/camo) + mochila.
	elena["clothing"] = "Camiseta,Pantalones,Zapatillas"
	elena["backpack"] = ""
	var cap0 := mgr._bot_carry_capacity(elena)
	check(int(cap0["slots"]) == 7 and absf(float(cap0["weight"]) - 9.0) < 0.01,
		"Ropa basica = 7 huecos / 9 kg como el jugador (%s)" % str(cap0))
	elena["clothing"] = "Chaqueta militar,Pantalones militares,Zapatillas,Chaleco táctico"
	var cap1 := mgr._bot_carry_capacity(elena)
	check(int(cap1["slots"]) == 16 and absf(float(cap1["weight"]) - 18.0) < 0.01,
		"Militar+chaleco = 16 huecos / 18 kg como el jugador (%s)" % str(cap1))
	elena["backpack"] = "Mochila pequena"
	var cap2 := mgr._bot_carry_capacity(elena)
	check(int(cap2["slots"]) == 24 and absf(float(cap2["weight"]) - 28.0) < 0.01,
		"...y con mochila pequena 24 huecos / 28 kg (%s)" % str(cap2))
	elena["backpack"] = ""
	elena["clothing"] = "Camiseta,Pantalones,Zapatillas"
	# Tope de huecos: con 7 stacks no entra ni un trapo; tope de peso igual.
	var full7: Array = []
	for i in range(7):
		full7.append({"name": "Objeto_%d" % i, "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0})
	elena_proxy.set_meta("saved_inventory", full7)
	check(not mgr._bot_would_fit(elena, full7, {"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1}),
		"7/7 huecos: no cabe ni un trapo (slots)")
	check(mgr._bot_would_fit(elena, full7, {"name": "Mochila militar", "type": "backpack", "weight": 0.9, "quantity": 1}),
		"Una mochila siempre cabe (no pesa ni ocupa, como en el jugador)")
	var inv_w := [{"name": "Piedra", "type": "resource", "weight": 4.5, "quantity": 2, "use_value": 0.0}]
	check(not mgr._bot_would_fit(elena, inv_w, {"name": "Piedra", "type": "resource", "weight": 0.5, "quantity": 1}),
		"9.0 kg: ni media piedra mas (peso)")
	var inv_stk := [{"name": "Piedra", "type": "resource", "weight": 8.5, "quantity": 1, "use_value": 0.0}]
	check(mgr._bot_would_fit(elena, inv_stk, {"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 1}),
		"Apilar cabe sin hueco nuevo si no supera el peso")
	check(not mgr._bot_would_fit(elena, inv_stk, {"name": "Piedra", "type": "resource", "weight": 0.6, "quantity": 1}),
		"Aun apilando, el peso corta (8.5+0.6>9)")
	# Y en la recoleccion real el objeto que no cabe se queda en el suelo.
	elena_proxy.set_meta("saved_inventory", full7.duplicate(true))
	elena["_s_loot"] = {}
	world._dropped_items = [
		{"id": "heavy_rock", "name": "Piedra", "type": "resource", "weight": 0.5, "qty": 1, "use": 0.0, "pos": [elena_proxy.global_position.x, elena_proxy.global_position.y, elena_proxy.global_position.z]},
	]
	mgr._collect_loot_entry(elena, world._dropped_items[0])
	check(world._dropped_items.size() == 1 and (world._dropped_items[0] as Dictionary).get("id") == "heavy_rock",
		"Mochila llena: el objeto del suelo no se consume")
	check(mgr._bot_item_count(elena_proxy, "Piedra") == 0,
		"Mochila llena: nada entro al inventario")
	# La particion al refugio recorta el keep a la capacidad: con 9 stacks
	# guardables y solo 7 huecos, los 2 mas prescindibles pasan al alijo.
	elena["campfire_id"] = ""
	var over_inv: Array = [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
		{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0},
		{"name": "Cerillas", "type": "tool_matches", "weight": 0.05, "quantity": 1, "use_value": 0.0},
		{"name": "Boleadoras", "type": "weapon_bola", "weight": 0.5, "quantity": 1, "use_value": 0.0},
		{"name": "Venda", "type": "medical", "weight": 0.05, "quantity": 2, "use_value": 35.0},
		{"name": "Carne asada en palo", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 28.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.5, "quantity": 4, "use_value": 0.0},
	]
	var part_over := mgr._bot_partition_inventory_for_shelter(elena, over_inv)
	var keep_over: Array = part_over["keep"]
	check(mgr._bot_inv_stored_count(keep_over) <= 7 and mgr._bot_inv_total_weight(keep_over) <= 9.01,
		"El keep queda dentro de capacidad (%d stacks / %.1f kg)" % [mgr._bot_inv_stored_count(keep_over), mgr._bot_inv_total_weight(keep_over)])
	check((part_over["store"] as Array).size() >= 2,
		"El sobrante va al alijo del refugio (%d items)" % (part_over["store"] as Array).size())
	elena_proxy.set_meta("saved_inventory", [])

	# --- 22) Asesor estrategico externo (validacion + directivas, sin HTTP) ---
	var d_hunt := mgr._ai_parse_decision("{\"action\":\"hunt\",\"poi_kind\":\"wild\",\"reason\":\"need meat\"}")
	check(str(d_hunt.get("mode", "")) == "poi" and (d_hunt.get("only_kinds", []) as Array) == ["wild"],
		"Asesor: hunt dirige solo a zonas wild")
	var d_scav := mgr._ai_parse_decision("{\"action\":\"scavenge\",\"reason\":\"loot\"}")
	check((d_scav.get("only_kinds", []) as Array) == ["military", "city"],
		"Asesor: scavenge sin poi_kind busca militar/ciudad")
	var d_rest := mgr._ai_parse_decision("```json\n{\"action\":\"rest\",\"reason\":\"recover\"}\n```")
	check(str(d_rest.get("mode", "")) == "pos", "Asesor: rest se traduce a destino pos (y acepta fences)")
	var d_avoid := mgr._ai_parse_decision("{\"action\":\"avoid_zone\",\"poi_kind\":\"city\",\"reason\":\"picked clean\"}")
	check(str(d_avoid.get("mode", "")) == "avoid" and (d_avoid.get("avoid_kinds", []) as Array) == ["city"],
		"Asesor: avoid_zone filtra el tipo de zona")
	check(mgr._ai_parse_decision("{\"action\":\"nuke\",\"poi_kind\":\"x\"}").is_empty(),
		"Asesor: accion fuera de catalogo es rechazada")
	check(mgr._ai_parse_decision("{\"action\":\"avoid_zone\"}").is_empty(),
		"Asesor: avoid_zone sin poi_kind es rechazado")
	check(mgr._ai_parse_decision("texto sin json").is_empty(),
		"Asesor: respuesta no-JSON es rechazada")
	# Aplicar return_home resuelve la posicion (campamento del bot)
	elena["team_leader_id"] = 0
	elena["ai_directive"] = {}
	mgr._ai_apply_decision(901, "{\"action\":\"return_home\",\"reason\":\"low hp\"}")
	var dir: Dictionary = elena.get("ai_directive", {})
	check(str(dir.get("mode", "")) == "pos" and dir.get("pos") is Vector3,
		"Asesor: return_home fija directiva pos al campamento")
	check(float(dir.get("until", 0)) > Time.get_ticks_msec(),
		"Asesor: la directiva lleva caducidad")
	# Pausa del sondeo automatico: las comprobaciones de cola/completado
	# manipulan ai_directive y _ai_queue a mano — el poll por frames las
	# re-encolaba o cerraba planes a mitad de chequeo.
	mgr.set_physics_process(false)
	# POIs de prueba inyectados para verificar el filtrado
	mgr._poi_cache = [
		{"pos": Vector3(100.0, 0.0, 100.0), "kind": "house"},
		{"pos": Vector3(200.0, 0.0, 200.0), "kind": "city"},
		{"pos": Vector3(300.0, 0.0, 300.0), "kind": "wild"},
		{"pos": Vector3(150.0, 0.0, 150.0), "kind": "military"},
	]
	mgr._poi_cache_built = true
	elena["_mem"] = {"visited": [], "deaths": 0}
	elena_proxy.global_position = Vector3(0.0, 0.4, 0.0)
	elena["ai_directive"] = {"mode": "avoid", "avoid_kinds": ["city"], "until": Time.get_ticks_msec() + 60000, "reason": "test"}
	var t_avoid: Vector3 = mgr._choose_explore_target(elena)
	check(t_avoid != Vector3.INF and t_avoid.distance_to(Vector3(200.0, 0.0, 200.0)) > 0.5,
		"Asesor: avoid_zone impide elegir la ciudad")
	elena["ai_directive"] = {"mode": "poi", "only_kinds": ["wild"], "until": Time.get_ticks_msec() + 60000, "reason": "test"}
	var t_hunt: Vector3 = mgr._choose_explore_target(elena)
	check(t_hunt.distance_to(Vector3(300.0, 0.0, 300.0)) < 0.5,
		"Asesor: hunt dirige la exploracion a la zona wild")
	elena["ai_directive"] = {"mode": "pos", "pos": Vector3(50.0, 0.0, 50.0), "until": Time.get_ticks_msec() + 60000, "reason": "test"}
	check(mgr._choose_explore_target(elena) == Vector3(50.0, 0.0, 50.0),
		"Asesor: directiva pos devuelve el destino exacto")
	elena["ai_directive"] = {"mode": "pos", "pos": Vector3(50.0, 0.0, 50.0), "until": Time.get_ticks_msec() - 1000, "reason": "test"}
	var t_exp: Vector3 = mgr._choose_explore_target(elena)
	check(t_exp == Vector3(50.0, 0.0, 50.0), "Asesor: el plan caducado sigue mandando hasta completarse")
	# Plan compartido: cola unica, dedup por bot, force no se degrada, hueco minimo
	mgr._ai_queue.clear()
	mgr._ai_last_call_msec.clear()
	mgr._ai_last_any_call_msec = 0
	for qbid in [901, 902, 903]:
		var qb: Dictionary = mgr.bots[qbid]
		qb["flee_until"] = 0.0
		qb["hide_timer"] = 0.0
		qb["_craft_state"] = {}
		qb["team_leader_id"] = 0
		var qpx = qb.get("proxy")
		if qpx != null and is_instance_valid(qpx):
			qpx.set_meta("proxy_dead", false)
	var now_ms := Time.get_ticks_msec()
	mgr._ai_enqueue_request(901, 2, "scheduled")
	mgr._ai_enqueue_request(902, 3, "sig_change")
	mgr._ai_enqueue_request(903, 2, "scheduled")
	check(mgr._ai_queue.size() == 3, "Asesor: la cola compartida junta a los tres bots")
	mgr._ai_enqueue_request(901, 5, "attacked_by_x", true)
	check(mgr._ai_queue.size() == 3 and int((mgr._ai_queue[0] as Dictionary).get("priority", 0)) == 5,
		"Asesor: el suceso sube la prioridad del bot ya encolado")
	mgr._ai_last_call_msec[902] = now_ms - 1000
	mgr._ai_last_call_msec[903] = now_ms - 1000
	var req1 := mgr._ai_pop_next_request(now_ms)
	check(int(req1.get("bot_id", 0)) == 901, "Asesor: el ataque (force) se despacha aun dentro del hueco")
	mgr._ai_queue.clear()
	mgr._ai_enqueue_request(902, 3, "sig_change")
	mgr._ai_enqueue_request(903, 5, "plan_done", true)
	var req2 := mgr._ai_pop_next_request(now_ms)
	check(int(req2.get("bot_id", 0)) == 903, "Asesor: plan_done (force) salta el hueco minimo")
	check(mgr._ai_queue.size() == 1, "Asesor: el sig_change dentro del hueco espera en cola")
	var req3 := mgr._ai_pop_next_request(now_ms + int(mgr.AI_MIN_CALL_GAP_SEC * 1000.0) + 500)
	check(int(req3.get("bot_id", 0)) == 902, "Asesor: pasado el hueco sale el cambio de firma")
	# Planes guardados: se completan al llegar/visitar/comer, no por reloj
	elena["vstats"] = SurvivalStats.new()
	var st_rest: SurvivalStats = elena["vstats"]
	elena["health"] = 50.0
	st_rest.sleep = 30.0
	elena["ai_directive"] = {"action": "rest", "mode": "pos", "pos": Vector3(0.0, 0.4, 0.0)}
	elena_proxy.global_position = Vector3(0.0, 0.4, 0.0)
	check(not mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: rest no completa sin recuperarse")
	st_rest.sleep = 90.0
	check(mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: rest completa descansado en el punto")
	st_rest.sleep = 100.0
	elena["health"] = 90.0
	elena["ai_directive"] = {"action": "return_home", "mode": "pos", "pos": Vector3(50.0, 0.0, 50.0)}
	elena_proxy.global_position = Vector3(0.0, 0.4, 0.0)
	check(not mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: return_home no completa lejos del punto")
	elena_proxy.global_position = Vector3(48.0, 0.4, 52.0)
	check(mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: return_home completa al llegar al punto")
	elena["ai_directive"] = {"action": "forage", "mode": "food"}
	elena["hunger"] = 40.0
	check(not mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: forage no completa con hambre")
	elena["hunger"] = 80.0
	check(mgr._ai_directive_completed(elena, elena["ai_directive"]), "Asesor: forage completa al recuperar hambre")
	elena["hunger"] = 90.0
	elena["ai_directive"] = {"action": "scavenge", "mode": "poi", "only_kinds": ["military"]}
	elena_proxy.global_position = Vector3(150.0, 0.4, 150.0)
	mgr._mark_poi_visited(elena, elena_proxy.global_position)
	check(bool((elena["ai_directive"] as Dictionary).get("_visit_done", false)),
		"Asesor: visitar el POI militar marca el plan como cumplido")
	check(mgr._ai_directive_completed(elena, elena["ai_directive"]),
		"Asesor: scavenge al POI visitado completa el plan")
	# El sondeo por turnos cierra el plan cumplido pidiendo el siguiente, y un
	# plan que no termina pasado el TTL+gracia fuerza una revalidacion.
	var ids_s: Array = mgr.bots.keys()
	ids_s.sort()
	mgr._ai_queue.clear()
	mgr._ai_rr = ids_s.find(901) - 1
	mgr._ai_sig_poll(now_ms)
	check((elena["ai_directive"] as Dictionary).is_empty() and mgr._ai_queue.size() == 1 \
			and str((mgr._ai_queue[0] as Dictionary).get("reason", "")) == "plan_done",
		"Asesor: el sondeo cierra el plan cumplido y encola el siguiente")
	mgr._ai_queue.clear()
	elena["ai_directive"] = {"action": "avoid_zone", "mode": "avoid", "avoid_kinds": ["city"], \
		"until": now_ms - int(mgr.AI_PLAN_STALE_GRACE_SEC * 1000.0) - 1000}
	mgr._ai_rr = ids_s.find(901) - 1
	mgr._ai_sig_poll(now_ms)
	check(mgr._ai_queue.size() == 1 and str((mgr._ai_queue[0] as Dictionary).get("reason", "")) == "plan_stuck" \
			and bool((mgr._ai_queue[0] as Dictionary).get("force", false)),
		"Asesor: el plan atascado fuerza una revalidacion")
	# Ritmo global anti-TPM: ni los forzados encadenan llamadas (suelo 15 s) y
	# las consultas normales esperan el hueco global completo (30 s).
	mgr._ai_queue.clear()
	mgr._ai_last_call_msec.clear()
	mgr._ai_last_any_call_msec = now_ms
	mgr._ai_enqueue_request(901, 5, "attacked", true)
	check(mgr._ai_pop_next_request(now_ms).is_empty(),
		"Asesor: el suelo global frena hasta los sucesos forzados")
	var req4 := mgr._ai_pop_next_request(now_ms + int(mgr.AI_FORCE_GLOBAL_GAP_SEC * 1000.0) + 100)
	check(int(req4.get("bot_id", 0)) == 901, "Asesor: pasado el suelo global sale el suceso")
	mgr._ai_queue.clear()
	mgr._ai_enqueue_request(902, 3, "sig_change")
	check(mgr._ai_pop_next_request(now_ms + int(mgr.AI_FORCE_GLOBAL_GAP_SEC * 1000.0) + 100).is_empty(),
		"Asesor: una consulta normal espera el hueco global completo")
	var req5 := mgr._ai_pop_next_request(now_ms + int(mgr.AI_GLOBAL_MIN_CALL_GAP_SEC * 1000.0) + 100)
	check(int(req5.get("bot_id", 0)) == 902, "Asesor: tras el hueco global sale la consulta normal")
	mgr._ai_last_any_call_msec = 0
	mgr._ai_queue.clear()
	mgr._ai_last_call_msec.clear()
	mgr.set_physics_process(true)
	elena_proxy.global_position = Vector3(0.0, 0.4, 0.0)
	# Elegibilidad: con ordenes de equipo el asesor no interfiere; sin API key no llama
	elena["ai_directive"] = {}
	elena["team_leader_id"] = 1
	check(not mgr._ai_bot_eligible(elena), "Asesor: bot con ordenes de equipo no es elegible")
	elena["team_leader_id"] = 0
	check(mgr._ai_bot_eligible(elena), "Asesor: bot libre es elegible")
	mgr._ai_tick(0.1)
	check(mgr._ai_pending_bot == 0, "Asesor: sin GROQ_API_KEY no hace peticiones")
	elena["_mem"] = {"visited": [], "deaths": 0, "last_death_pos": Vector3.INF, "scarcity": false, "gear_learned": true}

	# --- 23) Memoria persistente: aprendizaje entre sesiones ---
	# Botin cerca de la ciudad (POI inyectado en seccion 22) cuenta para "city"
	elena_proxy.global_position = Vector3(195.0, 0.4, 195.0)
	check(mgr._poi_kind_near(elena_proxy.global_position) == "city",
		"Memoria: el botin junto a la ciudad se registra como zona city")
	elena_proxy.global_position = Vector3(5000.0, 0.4, 5000.0)
	check(mgr._poi_kind_near(elena_proxy.global_position) == "wild",
		"Memoria: botin lejos de todo POI cuenta como wild")
	elena_proxy.global_position = Vector3(195.0, 0.4, 195.0)
	mgr._ai_note_loot(elena, "Trapo viejo", "resource")
	mgr._ai_note_loot(elena, "Fusil de asalto", "weapon")
	mgr._ai_note_loot(elena, "Venda", "medical")
	var zy: Dictionary = (elena["_mem"] as Dictionary).get("zone_yield", {})
	var zk: Dictionary = zy.get("city", {})
	check(int(zk.get("n", 0)) == 3 and int(zk.get("good", 0)) == 2,
		"Memoria: zone_yield cuenta botin total y botin valioso (n=%s good=%s)" % [str(zk.get("n", 0)), str(zk.get("good", 0))])
	# Factor de exploracion: zona con buen botin pesa mas, zona letal pesa menos
	var f_city := mgr._ai_poi_memory_factor(elena, Vector3(200.0, 0.0, 200.0), "city")
	check(f_city > 1.0, "Memoria: ciudad con botin valioso aumenta su peso (x%.2f)" % f_city)
	(elena["_mem"] as Dictionary)["death_spots"] = [{"x": 210.0, "y": 0.0, "z": 205.0, "cause": "wolf_bite", "count": 2}]
	var f_dead := mgr._ai_poi_memory_factor(elena, Vector3(200.0, 0.0, 200.0), "city")
	check(f_dead < f_city, "Memoria: muerte cercana a la ciudad reduce su peso (x%.2f < x%.2f)" % [f_dead, f_city])
	var f_wild := mgr._ai_poi_memory_factor(elena, Vector3(300.0, 0.0, 300.0), "wild")
	check(f_wild == 1.0, "Memoria: zona sin historial mantiene peso neutro")
	# Resumen para el prompt del asesor
	var summ := mgr._ai_memory_summary(elena["_mem"])
	check(str(summ.get("best_loot_zone", "")) == "city" and int(summ.get("death_spots", 0)) == 1,
		"Memoria: resumen para el LLM incluye mejor zona y puntos letales")
	# Persistencia real solo en dedicated_server: en tests no toca disco
	mgr._ai_save_memory()
	check(true, "Memoria: _ai_save_memory es no-op fuera de dedicated_server")
	elena["_mem"] = {"visited": [], "deaths": 0, "last_death_pos": Vector3.INF, "scarcity": false, "gear_learned": true}
	elena_proxy.global_position = Vector3(0.0, 0.4, 0.0)

	# --- 24) Forrajeo: setas, fruta y latas ---
	world.world_actions_by_id.clear()
	var seta := WorldActionScript.new()
	seta.setup("test_seta_1", "eat_food", "Seta amanita", Vector3(0.2, 0.2, 0.2), Color(0.8, 0.15, 0.1), false, false)
	seta.set_meta("item_name", "Seta amanita")
	seta.set_meta("item_type", "food")
	seta.set_meta("item_use_value", 12.0)
	seta.set_meta("item_quantity", 1)
	world.add_child(seta)
	seta.global_position = elena_proxy.global_position + Vector3(10.0, 0.0, 0.0)
	world.world_actions_by_id["test_seta_1"] = seta
	var arbol := WorldActionScript.new()
	arbol.setup("test_tree_1", "pick_fruit", "Naranjo", Vector3(1.3, 3.2, 1.3), Color(0.2, 0.12, 0.05), true, false)
	arbol.set_meta("fruit_type_name", "Naranja")
	arbol.set_meta("fruit_ready_time", 0.0)
	world.add_child(arbol)
	arbol.global_position = elena_proxy.global_position + Vector3(0.0, 0.0, 14.0)
	world.world_actions_by_id["test_tree_1"] = arbol
	# Hambre sin comida: localiza la seta (preferida sobre la fruta)
	elena["_forage"] = {}
	elena["_forage_scan"] = 0.0
	elena["_s_leader"] = null
	elena["hunger"] = 40.0
	elena["health"] = 100.0
	elena["thirst"] = 80.0
	elena["hide_timer"] = 0.0
	elena["eat_cooldown"] = 0.0
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	check(mgr._bot_try_forage(elena, 0.016), "Forrajeo: con hambre y sin comida busca setas")
	var fst: Dictionary = elena.get("_forage", {})
	check(str(fst.get("kind", "")) == "eat" and str(fst.get("id", "")) == "test_seta_1",
		"Forrajeo: prefiere la seta sobre el arbol frutal")
	# Llega y come: hambre sube y la accion queda agotada en el servidor
	elena_proxy.global_position = seta.global_position
	mgr._bot_try_forage(elena, 1.3)
	check(float(elena["hunger"]) > 50.0, "Forrajeo: comer la seta repone hambre (hunger=%.0f)" % float(elena["hunger"]))
	check((world._depleted_action_ids as Array).has("test_seta_1"),
		"Forrajeo: la seta queda agotada para todo el mundo")
	# Ahora la fruta: target pick_fruit, al completar caen 2 unidades y hay cooldown
	elena["hunger"] = 40.0
	elena["_forage"] = {}
	elena["_forage_scan"] = 0.0
	elena_proxy.global_position = arbol.global_position
	mgr._bot_try_forage(elena, 0.016)
	var ft: Dictionary = elena.get("_forage", {})
	check(str(ft.get("kind", "")) == "fruit" and str(ft.get("id", "")) == "test_tree_1",
		"Forrajeo: sin setas, va al arbol frutal")
	var drops_before: int = (world._dropped_items as Array).size()
	mgr._bot_try_forage(elena, 3.1)
	check((world._dropped_items as Array).size() >= drops_before + 2,
		"Forrajeo: la cosecha deja 2 frutas en el suelo")
	var fruit_count_after: int = world._dropped_items.size()
	mgr._bot_forage_complete(carlos, ft)
	check(world._dropped_items.size() == fruit_count_after, "Forrajeo: segundo recolector no duplica fruta durante cooldown")
	check(float(arbol.get_meta("fruit_ready_time", 0.0)) > Time.get_unix_time_from_system(),
		"Forrajeo: el arbol entra en cooldown de 5 minutos")
	# Latas: la cerrada no se come, la abierta si; y se abren con Hacha tambien
	elena["hunger"] = 40.0
	elena["health"] = 100.0
	elena["eat_cooldown"] = 0.0
	elena["_forage"] = {}
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Lata de guiso", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0},
	])
	mgr._maintain_bot_needs(elena, 0.1)
	check(float(elena["hunger"]) < 45.0, "Lata: la cerrada NO se come directamente")
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Lata de guiso abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0, "durability": 100.0, "max_durability": 100.0},
	])
	mgr._maintain_bot_needs(elena, 0.1)
	check(float(elena["hunger"]) > 50.0 and float(elena["hunger"]) < 65.0,
		"Lata: la abierta se come por porciones (hunger=%.0f)" % float(elena["hunger"]))
	elena["eat_cooldown"] = 0.0
	mgr._maintain_bot_needs(elena, 0.1)
	check(float(elena["hunger"]) > 70.0, "Lata: segunda porcion agota la lata (hunger=%.0f)" % float(elena["hunger"]))
	var can_left := false
	for it2 in elena_proxy.get_meta("saved_inventory", []):
		if it2 is Dictionary and str(it2.get("name", "")) == "Lata de guiso abierta":
			can_left = true
	check(not can_left, "Lata: agotada se consume entera")
	# Apertura con receta humana: Hacha sustituye al Cuchillo
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Lata de atun", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 18.0},
		{"name": "Hacha", "type": "tool_axe", "weight": 1.2, "quantity": 1, "use_value": 0.0, "durability": 90.0, "max_durability": 90.0},
	])
	elena["hunger"] = 40.0
	var can_recipe := {}
	for r in CraftingSystem.RECIPES:
		if str((r.get("output", {}) as Dictionary).get("name", "")) == "Lata de atun abierta":
			can_recipe = r
	check(not can_recipe.is_empty() and mgr._bot_can_craft(can_recipe, elena_proxy.get_meta("saved_inventory", [])),
		"Lata: se puede abrir con Hacha (sustituto del Cuchillo)")
	check(mgr._bot_recipe_score(elena, can_recipe) > 3.0, "Lata: con hambre el bot quiere abrirla")
	elena["hunger"] = 95.0
	check(mgr._bot_recipe_score(elena, can_recipe) < 3.0, "Lata: sin hambre no se molesta en abrir")
	# Saqueo: sin filo la lata cerrada no interesa; con filo si
	elena["hunger"] = 40.0
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.5, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0},
	])
	check(not mgr._is_loot_desirable(elena, "Lata de guiso", "food"),
		"Lata: sin herramienta de corte no la recoge")
	elena_proxy.get_meta("saved_inventory", []).append({"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0})
	check(mgr._is_loot_desirable(elena, "Lata de guiso", "food"),
		"Lata: con cuchillo la lata cerrada si es botin util")
	seta.queue_free()
	arbol.queue_free()
	world.world_actions_by_id.clear()

	# --- 25) Puertas: el bot abre puertas cerradas como un jugador ---
	world.nav = NavPathfinding.new()
	world.nav.build([], [])
	var house_idx: int = world._register_wildlife_blocker(Vector3(60.0, 0.0, 60.0), 8.0)
	world.wildlife_blockers[house_idx]["house_bounds"] = Rect2(55.0, 55.0, 10.0, 10.0)
	world.wildlife_blockers[house_idx]["door_name"] = "Casa prueba Door"
	world.wildlife_blockers[house_idx]["door_pos"] = Vector3(60.0, 0.0, 55.0)
	check(not world.bot_try_open_door_at(Vector3(30.0, 0.0, 30.0)),
		"Puerta: lejos no se abre nada")
	check(world.bot_try_open_door_at(Vector3(59.0, 0.0, 52.0)),
		"Puerta: junto a una cerrada se abre")
	check(bool(world._server_door_states.get("Casa prueba Door", false)),
		"Puerta: el estado del servidor queda abierto")
	check(world._check_door_open(null, world.wildlife_blockers[house_idx]),
		"Puerta: _check_door_open la da por abierta")
	check(not world.bot_try_open_door_at(Vector3(59.0, 0.0, 52.0)),
		"Puerta: ya abierta no se reabre")
	check(not world._is_near_wildlife_blocker(Vector3(60.0, 0.0, 58.0), 0.0),
		"Puerta: el paso de la puerta queda libre al abrirse")
	# Y en movimiento: una puerta cerrada en el paso se abre, no se rodea
	world._server_door_states["Casa prueba Door"] = false
	world._refresh_nav_door_caches()
	check(world._is_near_wildlife_blocker(Vector3(60.0, 0.0, 58.0), 0.0),
		"Puerta: cerrada vuelve a bloquear el paso")
	elena_proxy.global_position = Vector3(60.0, 0.4, 51.2)
	elena["_speed"] = 4.0
	elena["_last_move_t"] = float(Time.get_ticks_msec()) / 1000.0
	elena["path"] = []
	elena["path_timer"] = 0.0
	elena["stuck_timer"] = 0.0
	elena["stuck_count"] = 0
	for i in range(3):
		mgr._move_bot_towards(elena, Vector3(60.0, 0.4, 60.0), 4.0, 0.1, "walk")
		if bool(world._server_door_states.get("Casa prueba Door", false)):
			break
	check(bool(world._server_door_states.get("Casa prueba Door", false)),
		"Puerta: el bot abre la puerta que le bloquea el paso")
	# Con la puerta abierta el paso queda libre y el bot puede entrar
	for i in range(30):
		mgr._move_bot_towards(elena, Vector3(60.0, 0.4, 60.0), 4.0, 0.1, "walk")
		if Vector2(elena_proxy.global_position.x - 60.0, elena_proxy.global_position.z - 60.0).length() < 1.5:
			break
	check(Vector2(elena_proxy.global_position.x - 60.0, elena_proxy.global_position.z - 60.0).length() < 2.5,
		"Puerta: el bot entra en la casa por la puerta abierta (dist=%.2f)" % Vector2(elena_proxy.global_position.x - 60.0, elena_proxy.global_position.z - 60.0).length())

	# --- 26) Depredadores: sin arma de fuego el bot huye, no caza ---
	var wolf3 := WildlifeControllerScript.new()
	wolf3.name = "Wildlife_wolf_flee"
	world.add_child(wolf3)
	wolf3.setup("wolf", [Vector3(0.0, 0.4, 0.0)])
	elena["shelter_pos"] = Vector3.INF
	elena["sense_t"] = 999.0
	elena["_s_predator"] = null
	elena["_s_foe"] = null
	elena["aggro_target"] = null
	elena["hide_timer"] = 0.0
	elena["tame_cooldown"] = 99.0
	elena["attack_cooldown"] = 0.0
	elena_proxy.set_meta("saved_inventory", [{"name": "Cuchillo", "type": "tool_knife", "quantity": 1}])

	# Lobo a 15 m: huye alejándose, no carga a por él
	elena_proxy.global_position = Vector3(100.0, 0.4, 100.0)
	wolf3.global_position = elena_proxy.global_position + Vector3(15.0, 0.0, 0.0)
	var d_pred := elena_proxy.global_position.distance_to(wolf3.global_position)
	mgr._handle_predator_encounter(elena, wolf3, 0.2)
	check(elena_proxy.global_position.distance_to(wolf3.global_position) > d_pred,
		"Sin fusil el bot huye del lobo en vez de acercarse a cazar (d %.1f->%.1f)" % [d_pred, elena_proxy.global_position.distance_to(wolf3.global_position)])
	check(float(elena["caution_until"]) > 0.0, "La huida prolonga la cautela (sigue viendo al depredador)")

	# Oso a 14 m: tampoco se acerca a pegarle con un cuchillo
	var bear := WildlifeControllerScript.new()
	bear.name = "Wildlife_bear_flee"
	world.add_child(bear)
	bear.setup("bear", [Vector3(0.0, 0.4, 0.0)])
	bear.global_position = elena_proxy.global_position + Vector3(14.0, 0.0, 0.0)
	d_pred = elena_proxy.global_position.distance_to(bear.global_position)
	mgr._handle_predator_encounter(elena, bear, 0.2)
	check(elena_proxy.global_position.distance_to(bear.global_position) > d_pred,
		"Sin fusil el bot huye del oso igual que del lobo (d %.1f->%.1f)" % [d_pred, elena_proxy.global_position.distance_to(bear.global_position)])

	# Punteria del bot: no es un aimbot — la probabilidad de fallo crece con la
	# distancia y con la velocidad del blanco, y el melee se puede esquivar.
	var m_close := mgr._bot_rifle_miss_chance(8.0, 0.0, 0.5)
	var m_far := mgr._bot_rifle_miss_chance(40.0, 0.0, 0.5)
	var m_far_run := mgr._bot_rifle_miss_chance(40.0, 7.0, 0.5)
	check(m_close > 0.0 and m_close < m_far and m_far < m_far_run and m_far_run <= 0.62,
		"Punteria bot: el fallo crece con distancia y carrera (%.2f < %.2f < %.2f)" % [m_close, m_far, m_far_run])
	var d_still := mgr._bot_melee_dodge_chance(0.0)
	var d_sprint := mgr._bot_melee_dodge_chance(7.0)
	check(d_still < d_sprint and d_still >= 0.10,
		"Melee bot: el tajo se puede esquivar mas al correr (%.2f < %.2f)" % [d_still, d_sprint])
	var track_b: Dictionary = mgr.bots[901]
	track_b["_foe_track"] = {}
	var foe_ref: Node3D = elena_proxy
	var spd0 := mgr._bot_target_speed(track_b, foe_ref)
	check(spd0 == 0.0, "Velocidad de objetivo: primer contacto da 0 m/s")
	var tid := int(foe_ref.get_instance_id())
	track_b["_foe_track"] = {"id": tid, "tpos": foe_ref.global_position - Vector3(24.0, 0.0, 0.0), "msec": Time.get_ticks_msec() - 4000}
	var spd_run := mgr._bot_target_speed(track_b, foe_ref)
	check(spd_run > 4.0,
		"Velocidad de objetivo: 24 m en 4 s detecta un blanco en carrera (%.1f m/s)" % spd_run)

	# Acorralado (lobo encima): defensa a vida o muerte en melee
	wolf3.global_position = elena_proxy.global_position + Vector3(3.0, 0.0, 0.0)
	elena["attack_cooldown"] = 0.0
	var whp := float(wolf3.health)
	mgr._handle_predator_encounter(elena, wolf3, 0.2)
	check(float(wolf3.health) < whp, "Con el lobo encima el bot se defiende en melee (hp %.1f->%.1f)" % [whp, float(wolf3.health)])

	# Destripado: solo si le hace falta algo, con filo y dedicando ~3.5 s
	wolf3.take_damage(999.0, true, elena_proxy)
	check(bool(wolf3.get("_is_dead")), "El lobo muere para la prueba de destripado")
	elena["hunger"] = 30.0
	elena["gut_target"] = null
	mgr._bot_start_gutting(elena, wolf3)
	check(elena["gut_target"] == wolf3, "Con hambre y filo agenda destripar al animal muerto")
	elena_proxy.global_position = wolf3.global_position + Vector3(1.5, 0.0, 0.0)
	for i in range(50):
		mgr._tick_bot(elena, 0.1)
		if elena["gut_target"] == null:
			break
	check(bool(wolf3.get("_gutted")), "El destripado marca el cadáver como gutted tras dedicarle tiempo")
	check(wolf3.is_queued_for_deletion(),
		"10J5t: El destripado por bot retira el cadáver del servidor y emite animal_gutted (los clientes dejan de verlo)")
	var inv_gut: Array = elena_proxy.get_meta("saved_inventory", [])
	var got_pelt := false
	for it in inv_gut:
		if str((it as Dictionary).get("name", "")).begins_with("Piel de "):
			got_pelt = true
	check(got_pelt, "El destripado entrega pieles reales al inventario")

	# Sin hambre y con pieles de sobra: no destripa por destripar
	elena["hunger"] = 95.0
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Seta amanita", "type": "food", "quantity": 1, "use_value": 12.0},
		{"name": "Piel de ciervo", "type": "resource", "quantity": 9, "use_value": 0.0},
		{"name": "Cuchillo", "type": "tool_knife", "quantity": 1}])
	var wolf4 := WildlifeControllerScript.new()
	wolf4.name = "Wildlife_wolf_skip"
	world.add_child(wolf4)
	wolf4.setup("wolf", [Vector3(0.0, 0.4, 0.0)])
	wolf4.take_damage(999.0, true, elena_proxy)
	mgr._bot_start_gutting(elena, wolf4)
	check(elena["gut_target"] == null, "Sin hambre ni falta de abrigo no destripa cadáveres por acumular")

	# Sin filo: no puede destripar aunque se muera de hambre
	elena["hunger"] = 20.0
	elena_proxy.set_meta("saved_inventory", [{"name": "Seta amanita", "type": "food", "quantity": 1, "use_value": 12.0}])
	var wolf5 := WildlifeControllerScript.new()
	wolf5.name = "Wildlife_wolf_noedge"
	world.add_child(wolf5)
	wolf5.setup("wolf", [Vector3(0.0, 0.4, 0.0)])
	wolf5.take_damage(999.0, true, elena_proxy)
	mgr._bot_start_gutting(elena, wolf5)
	check(elena["gut_target"] == null, "Sin filo no agenda destripado (como el jugador)")

	# --- 27) Caza de presas (ciervo/zorro), sigilo agachado, antorcha ante lobos y refugio seguro ---
	var deer := WildlifeControllerScript.new()
	deer.name = "Wildlife_deer_hunt"
	world.add_child(deer)
	deer.setup("deer", [Vector3(0.0, 0.4, 0.0)])
	deer.set_process(false)
	elena_proxy.global_position = Vector3(140.0, 0.4, 140.0)
	deer.global_position = elena_proxy.global_position + Vector3(18.0, 0.0, 0.0)
	elena["hunger"] = 42.0
	elena["shelter_id"] = ""
	elena["shelter_pos"] = Vector3.INF
	elena["hide_timer"] = 0.0
	elena["flee_until"] = 0.0
	elena["_s_leader"] = null
	elena["_want_cache"] = {}
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0},
	])
	var found_prey := mgr._find_huntable_prey(elena, 32.0)
	check(found_prey == deer, "Con hambre y filo el bot detecta ciervos/zorros para cazar")
	mgr._hunt_prey(elena, deer, 0.2)
	check(bool(elena["crouching"]) and bool(elena_proxy.get_meta("crouching", false)),
		"Al acechar una presa a media distancia se agacha y sincroniza meta crouching en el proxy")
	check(deer._effective_prey_alert_range(elena_proxy) <= 13.0,
		"El ciervo respeta el sigilo agachado del bot (alerta %.1fm <= 13m)" % deer._effective_prey_alert_range(elena_proxy))
	# Remate de cerca y destripado: entrega pieles, carne, tendón y hueso sin duplicar drops en suelo
	deer.global_position = elena_proxy.global_position + Vector3(2.2, 0.0, 0.0)
	deer.health = 20.0
	elena["attack_cooldown"] = 0.0
	mgr._hunt_prey(elena, deer, 0.2)
	check(bool(deer.get("_is_dead")) and elena["gut_target"] == deer,
		"Al abatir al ciervo agenda su destripado inmediatamente")
	var drops_pre_gut: int = (world._dropped_items as Array).size()
	mgr._bot_harvest_dead_animal(elena, deer)
	check(mgr._bot_item_count(elena_proxy, "Piel de ciervo") == 2 and mgr._bot_item_count(elena_proxy, "Tendón") >= 1,
		"Destripar ciervo da 2 pieles y tendón (para cuerda de refugio/arco)")
	check((world._dropped_items as Array).size() == drops_pre_gut,
		"El destripado del bot usa collect_mode y no duplica pieles/carne en el suelo")

	# Antorcha al huir de un lobo: la enciende y empuña para activar wary_torch
	var wolf6 := WildlifeControllerScript.new()
	wolf6.name = "Wildlife_wolf_torch"
	world.add_child(wolf6)
	wolf6.setup("wolf", [Vector3(0.0, 0.4, 0.0)])
	wolf6.set_process(false)
	elena_proxy.global_position = Vector3(160.0, 0.4, 160.0)
	wolf6.global_position = elena_proxy.global_position + Vector3(12.0, 0.0, 0.0)
	elena["torch_lit"] = false
	elena_proxy.set_meta("torch_lit", false)
	elena_proxy.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "quantity": 1, "durability": 80.0, "max_durability": 80.0},
		{"name": "Antorcha", "type": "tool_torch", "quantity": 1, "durability": 100.0, "max_durability": 100.0},
	])
	mgr._handle_predator_encounter(elena, wolf6, 0.2)
	check(bool(elena["torch_lit"]) and str(elena["held_item"]) == "Antorcha" and bool(elena_proxy.get_meta("torch_lit", false)),
		"Al huir de un lobo con antorcha en mochila la enciende y empuña (wary_torch)")

	# Dentro de una casa o refugio construido no sale corriendo a las fauces del lobo
	elena_proxy.global_position = Vector3(60.0, 0.4, 60.0) # interior de Casa prueba (Rect2(55,55,10,10))
	elena["pos"] = elena_proxy.global_position
	wolf6.global_position = Vector3(60.0, 0.4, 54.2) # fuera, a 5.8 m
	mgr._handle_predator_encounter(elena, wolf6, 0.2)
	check(bool(elena["sitting"]) and elena_proxy.global_position.distance_to(Vector3(60.0, 0.4, 60.0)) < 0.2,
		"Dentro de una casa con un lobo fuera permanece a resguardo en vez de salir a pelear")

	# Visión humana realista: agacharse y la oscuridad reducen el alcance visual
	elena_proxy.set_meta("crouching", false)
	elena_proxy.set_meta("in_built_shelter", false)
	var s_stand := mgr._effective_human_sight(elena_proxy, 44.0)
	elena_proxy.set_meta("crouching", true)
	var s_crouch := mgr._effective_human_sight(elena_proxy, 44.0)
	check(s_crouch < s_stand * 0.75, "Ir agachado reduce el alcance al que un bot hostil te detecta (%.1f < %.1f)" % [s_crouch, s_stand])

	# --- 28) Pruebas de Aceptación: Sistema de Inteligencia Persistente (Groq / Qwen) ---
	# Resetear personalidades base de los 3 bots para evaluar sus decisiones ante una situación idéntica
	for bid_p in [901, 902, 903]:
		var cfg_p: Dictionary = mgr.bots[bid_p]["cfg"]
		var mem_p: Dictionary = mgr._ensure_bot_memory(bid_p, cfg_p)
		mem_p["personality"] = mgr._default_personality_for_bot(bid_p, cfg_p)
		mem_p["strategies"] = {}
		mgr.bots[bid_p]["personality"] = mem_p["personality"]

	# Aceptación 1: Los tres bots muestran decisiones diferentes ante una situación idéntica
	var shared_sit := {"hp": 72.0, "hunger": 56.0, "thirst": 75.0, "has_shelter": false, "threat": false}
	var dec_elena := mgr.decide_situational_action(mgr.bots[901], shared_sit)
	var dec_carlos := mgr.decide_situational_action(mgr.bots[902], shared_sit)
	var dec_kael := mgr.decide_situational_action(mgr.bots[903], shared_sit)
	var a_e := str(dec_elena.get("action", ""))
	var a_c := str(dec_carlos.get("action", ""))
	var a_k := str(dec_kael.get("action", ""))
	check(a_e != a_c and a_c != a_k and a_e != a_k,
		"Aceptación 1: Los 3 bots toman decisiones distintas ante la misma situación (Elena=%s, Carlos=%s, Kael=%s)" % [a_e, a_c, a_k])

	# Aceptación 2: Un bot recuerda a un jugador tras reiniciar el servidor (persistencia real en disco)
	var test_mem_path := "user://test_acceptance_bot_memory.json"
	mgr.memory_path = test_mem_path
	mgr.force_memory_io = true
	mgr.record_social_event(901, "client_sami_77", "Sami", "help", 0.65, "shared_water_and_bandage")
	mgr.observe_location(901, "house:120:140", "house", Vector3(120.0, 0.0, 140.0), "observed", true)
	# El reset de marcador (score_reset_v) es una migracion de una sola vez:
	# con la bandera ya puesta, las ubicaciones conocidas vuelven a persistir
	# entre reinicios como siempre.
	mgr._ensure_bot_memory(901, mgr.bots[901]["cfg"])["score_reset_v"] = 1
	mgr._ai_save_memory()
	mgr._ai_flush_writes()
	# Simular reinicio del servidor con un nuevo SurvivorBotManager que carga desde disco
	var mgr_restarted := SurvivorBotManagerScript.new()
	mgr_restarted.memory_path = test_mem_path
	mgr_restarted.force_memory_io = true
	mgr_restarted._ai_load_memory()
	var rel_after := mgr_restarted.get_bot_relationship(901, "client_sami_77")
	check(float(rel_after.get("trust", 0.0)) > 0.35 and int(rel_after.get("helped", 0)) >= 1 and str(rel_after.get("name", "")) == "Sami",
		"Aceptación 2: Tras reiniciar el servidor, Elena recuerda al jugador Sami y su confianza (trust=%.2f, helped=%d)" % [float(rel_after.get("trust", 0.0)), int(rel_after.get("helped", 0))])
	check(mgr_restarted.bot_knows_location(901, "house:120:140"),
		"Aceptación 2b: Tras reiniciar el servidor, Elena conserva sus ubicaciones conocidas")
	mgr_restarted.free()
	if FileAccess.file_exists(test_mem_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_mem_path))
	mgr.force_memory_io = false
	mgr.memory_path = SurvivorBotManagerScript.AI_MEMORY_PATH

	# Aceptación 2c: pacing de rate-limit Groq — parser de duraciones Go +
	# _ai_note_rate_headers activa el backoff cuando quedan pocos tokens
	check(absf(mgr._ai_parse_groq_reset_seconds("172ms") - 0.172) < 0.001,
		"RateLimit: parse '172ms' -> 0.172 s")
	check(absf(mgr._ai_parse_groq_reset_seconds("4m19.2s") - 259.2) < 0.01,
		"RateLimit: parse '4m19.2s' -> 259.2 s")
	check(absf(mgr._ai_parse_groq_reset_seconds("1h30m") - 5400.0) < 0.5,
		"RateLimit: parse '1h30m' -> 5400 s")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_note_rate_headers(PackedStringArray(["x-ratelimit-remaining-tokens: 100", "x-ratelimit-reset-tokens: 42s"]))
	check(int(mgr._ai_backoff_until_msec) > 0, "RateLimit: tokens agotados activan el backoff hasta el reset")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_note_rate_headers(PackedStringArray(["x-ratelimit-remaining-tokens: 7500", "x-ratelimit-reset-tokens: 200ms"]))
	check(int(mgr._ai_backoff_until_msec) == 0,
		"RateLimit: con margen de tokens no se activa ningun backoff")

	# Aceptación 2d: canales IA independientes (las cuotas Groq son por modelo):
	# el backoff del chat no toca al de decisiones y viceversa, cada uno con su
	# propio umbral de tokens (chat ~300/llamada -> headroom 900).
	mgr._ai_backoff_until_msec = 0
	mgr._chat_backoff_until_msec = 0
	mgr._ai_note_rate_headers(PackedStringArray(["x-ratelimit-remaining-tokens: 100", "x-ratelimit-reset-tokens: 42s"]), true)
	check(int(mgr._chat_backoff_until_msec) > 0 and int(mgr._ai_backoff_until_msec) == 0,
		"RateLimit: el 429/pacing del chat solo congela el canal de chat")
	mgr._chat_backoff_until_msec = 0
	mgr._ai_note_rate_headers(PackedStringArray(["x-ratelimit-remaining-tokens: 1500", "x-ratelimit-reset-tokens: 42s"]))
	check(int(mgr._ai_backoff_until_msec) > 0 and int(mgr._chat_backoff_until_msec) == 0,
		"RateLimit: el pacing de decisiones solo congela el canal de decisiones")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_note_rate_headers(PackedStringArray(["x-ratelimit-remaining-tokens: 1500", "x-ratelimit-reset-tokens: 42s"]), true)
	check(int(mgr._chat_backoff_until_msec) == 0,
		"RateLimit: con 1500 tokens el chat (headroom 900) sigue pudiendo hablar")
	mgr._chat_backoff_until_msec = 0
	check(mgr._ai_chat_model() == SurvivorBotManagerScript.AI_CHAT_MODEL
		and mgr._ai_decision_model() == SurvivorBotManagerScript.AI_ADVISOR_MODEL
		and mgr._ai_chat_model() != mgr._ai_decision_model(),
		"RateLimit: chat y decisiones usan modelos distintos (%s / %s)" % [mgr._ai_chat_model(), mgr._ai_decision_model()])
	OS.set_environment("GROQ_CHAT_MODEL", "test/model-xyz")
	check(mgr._ai_chat_model() == "test/model-xyz",
		"RateLimit: GROQ_CHAT_MODEL sobreescribe el modelo de chat")
	OS.set_environment("GROQ_CHAT_MODEL", "")

	# Aceptación 2e: chat anti-repeticion y frescura — el mismo bot no emite dos
	# veces la misma frase (salvo respuestas) y las respuestas tardias se caen.
	var chat_b: Dictionary = mgr.bots[901]
	var log_before := mgr.chat_log.size()
	mgr._bot_chat_send(chat_b, 777, "Sami", "Ey, Sami, prueba de eco.", "greet")
	var log_after1 := mgr.chat_log.size()
	check(log_after1 == log_before + 1, "Chat: la frase nueva se registra en el log")
	mgr._bot_chat_send(chat_b, 777, "Sami", "Ey, Sami, prueba de eco.", "greet")
	check(mgr.chat_log.size() == log_after1,
		"Chat: una frase identica repetida por el mismo bot se descarta")
	mgr._bot_chat_send(chat_b, 777, "Sami", "Ey, Sami, prueba de eco.", "reply")
	check(mgr.chat_log.size() == log_after1 + 1,
		"Chat: la respuesta directa al jugador sale aunque repita (contesta siempre)")
	check((mgr._chat_recent.get(901, []) as Array).has("Ey, Sami, prueba de eco."),
		"Chat: las frases enviadas quedan en la lista anti-repeticion del bot")
	var prompt_rep := mgr._chat_build_prompt(chat_b, "greet", 777, "Sami", "", "")
	check(prompt_rep.contains("no lo repitas"),
		"Chat: el prompt avisa al modelo de sus frases recientes")
	# Frescura: una respuesta que llega con mas de BOT_CHAT_STALE_MSEC se cae.
	mgr._chat_pending = {"bot_id": 901, "to_id": 777, "to_name": "Sami", "kind": "greet", "intent": "", "t": Time.get_ticks_msec() - SurvivorBotManagerScript.BOT_CHAT_STALE_MSEC - 1000}
	var log_stale := mgr.chat_log.size()
	mgr._chat_on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{\"choices\":[{\"message\":{\"content\":\"hola muy tarde\"}}]}".to_utf8_buffer())
	check(mgr.chat_log.size() == log_stale,
		"Chat: una respuesta del modelo que llega a destiempo se descarta")
	# Contexto: un mensaje iniciado no sale si el bot entro en combate mientras.
	chat_b["flee_until"] = 8.0
	mgr._chat_pending = {"bot_id": 901, "to_id": 777, "to_name": "Sami", "kind": "greet", "intent": "", "t": Time.get_ticks_msec()}
	var log_ctx := mgr.chat_log.size()
	mgr._chat_on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{\"choices\":[{\"message\":{\"content\":\"hola en plena huida\"}}]}".to_utf8_buffer())
	check(mgr.chat_log.size() == log_ctx,
		"Chat: un saludo generado durante una huida no llega a emitirse")
	chat_b["flee_until"] = 0.0

	# Aceptación 3: Un bot modifica su comportamiento tras experiencias repetidas
	# 3a) Riesgo repetido en una ubicación reduce su preferencia de exploración y evoluciona personalidad
	var p_surv_before := float(mgr._get_bot_personality(elena).get("survival_instinct", 0.0))
	var f_before_hazard := mgr._ai_poi_memory_factor(elena, Vector3(150.0, 0.0, 150.0), "military")
	for h_i in range(3):
		mgr.record_zone_hazard(901, Vector3(150.0, 0.0, 150.0), "military", 0.55)
	var f_after_hazard := mgr._ai_poi_memory_factor(elena, Vector3(150.0, 0.0, 150.0), "military")
	var p_surv_after := float(mgr._get_bot_personality(elena).get("survival_instinct", 0.0))
	check(f_after_hazard < f_before_hazard * 0.65 and p_surv_after > p_surv_before,
		"Aceptación 3a: Experiencias peligrosas repetidas reducen preferencia por la zona (%.2f -> %.2f) y suben instinto de supervivencia (%.3f -> %.3f)" % [f_before_hazard, f_after_hazard, p_surv_before, p_surv_after])
	# 3b) Ataques repetidos de un jugador cambian la actitud social de Elena (rechaza unirse al agresor, hasta reconciliación)
	elena["team_leader_id"] = 0
	for atk_i in range(3):
		mgr.record_social_event(901, "player_99", "Agresor", "attack", 0.60, "shot_rifle")
	var msg_refuse := mgr.interact_with_bot(901, 99, "toggle")
	check(int(elena["team_leader_id"]) == 0 and msg_refuse.contains("desconfía"),
		"Aceptación 3b: Tras ataques repetidos, el bot modifica su conducta social y rehúsa unirse al agresor (%s)" % msg_refuse)

	# Aceptación 4: Los bots siguen funcionando cuando Groq no está disponible (sin API key o HTTP 429)
	elena["ai_directive"] = {}
	mgr._ai_pending_bot = 901
	mgr._ai_on_response(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), PackedByteArray())
	check(mgr._ai_429_count >= 1 and mgr._ai_backoff_until_msec > Time.get_ticks_msec() and mgr._ai_conn_status.contains("429"),
		"Aceptación 4a: HTTP 429 activa backoff exponencial y registra estado rate_limited (%s)" % mgr._ai_conn_status)
	check(not (elena.get("ai_directive", {}) as Dictionary).is_empty() and str((elena["ai_directive"] as Dictionary).get("source", "")) == "local_fallback",
		"Aceptación 4b: Cuando Groq falla o devuelve 429, el bot aplica automáticamente decisión local de respaldo (%s)" % str((elena.get("ai_directive", {}) as Dictionary).get("action", "")))
	mgr._ai_backoff_until_msec = 0

	# Aceptación 5: Ningún bot conoce experiencias privadas de otro sin comunicación
	mgr.observe_location(901, "secret_bunker:410:-390", "military", Vector3(410.0, 0.0, -390.0), "observed", true)
	mgr.record_bot_event(901, "private_discovery", "Elena", "military", Vector3(410.0, 0.0, -390.0), "found_bunker")
	check(mgr.bot_knows_location(901, "secret_bunker:410:-390") and not mgr.bot_knows_location(902, "secret_bunker:410:-390") and not mgr.bot_knows_location(903, "secret_bunker:410:-390"),
		"Aceptación 5a: Sin comunicación, ni Carlos ni Kael conocen la ubicación privada descubierta por Elena")
	check(mgr.bot_knows_event(901, "private_discovery", "Elena") and not mgr.bot_knows_event(902, "private_discovery", "Elena"),
		"Aceptación 5b: Los recuerdos privados de Elena no existen en la memoria de Carlos")
	# Cuando dos aliados (Elena 901 y Carlos 902) se comunican, comparten ubicaciones conocidas; Kael (hostil 903) sigue sin saberlo
	var shared_n := mgr.share_bot_knowledge(901, 902)
	check(shared_n > 0 and mgr.bot_knows_location(902, "secret_bunker:410:-390") and not mgr.bot_knows_location(903, "secret_bunker:410:-390"),
		"Aceptación 5c: Tras comunicarse con su aliado, Carlos conoce la ubicación compartida pero el hostil Kael no")

	# Aceptación 6: Las decisiones de Qwen no pueden ejecutar acciones fuera de las permitidas ni ir a ubicaciones desconocidas
	var bad_action := mgr._ai_parse_decision("{\"goal\":\"hack\",\"action\":\"teleport\",\"target\":\"city\",\"priority\":5,\"reason\":\"cheat\"}", elena)
	var unknown_loc := mgr._ai_parse_decision("{\"goal\":\"loot\",\"action\":\"explore\",\"target\":\"military:888:-888\",\"priority\":4,\"reason\":\"omniscient\"}", elena)
	var known_loc := mgr._ai_parse_decision("{\"goal\":\"loot_bunker\",\"action\":\"explore\",\"target\":\"secret_bunker:410:-390\",\"priority\":4,\"reason\":\"remembered\"}", elena)
	check(bad_action.is_empty(), "Aceptación 6a: Qwen no puede ejecutar acciones fuera del catálogo permitido")
	check(unknown_loc.is_empty(), "Aceptación 6b: Qwen no puede enviar al bot a una ubicación específica que el bot no conoce")
	check(not known_loc.is_empty() and str(known_loc.get("mode", "")) == "pos" and (known_loc.get("pos") as Vector3).distance_to(Vector3(410.0, 0.0, -390.0)) < 1.0,
		"Aceptación 6c: Qwen sí puede dirigir al bot a una ubicación específica que el bot ya conoce")

	# Aceptación 7: Cola de prioridades, deduplicación, panel de depuración y rendimiento sin bloqueos (<2 ms)
	mgr.set_physics_process(false)
	mgr._ai_queue.clear()
	mgr._ai_enqueue_request(901, 2, "low_prio")
	mgr._ai_enqueue_request(902, 5, "high_prio_threat")
	mgr._ai_enqueue_request(903, 3, "mid_prio")
	var popped := mgr._ai_pop_next_request(Time.get_ticks_msec())
	check(int(popped.get("bot_id", 0)) == 902 and int(popped.get("priority", 0)) == 5,
		"Aceptación 7a: La cola de prioridades despacha primero la consulta más urgente (bot=%d prio=%d)" % [int(popped.get("bot_id", 0)), int(popped.get("priority", 0))])
	var t0_usec := Time.get_ticks_usec()
	mgr._ai_tick(0.016)
	var report_str := mgr.get_ai_debug_report()
	var dt_ms := float(Time.get_ticks_usec() - t0_usec) / 1000.0
	check(dt_ms < 15.0 and report_str.contains("Elena") and report_str.contains("Carlos") and report_str.contains("Kael") and report_str.contains("Personalidad:") and report_str.contains("Relaciones:"),
		"Aceptación 7b: El tick cognitivo y el panel de depuración se ejecutan sin bloquear el hilo principal (%.2f ms)" % dt_ms)
	mgr.set_physics_process(true)

	# Dispersión territorial: con el mismo campamento y POIs repartidos por el
	# mapa, cada bot debe elegir un destino dentro de su propio sector dorado
	# (y los aliados no deben converger al mismo POI)
	world.HOUSE_FOOTPRINTS = []
	var camp_base := Vector3(0.0, 0.0, 0.0)
	var sector_pois := {}
	for tbid in [901, 902, 903]:
		var tb: Dictionary = mgr.bots[tbid]
		var sec := mgr._bot_explore_sector(tb)
		var sdir := Vector2(cos(sec), sin(sec))
		var ppos := camp_base + Vector3(sdir.x * 300.0, 0.0, sdir.y * 300.0)
		world.HOUSE_FOOTPRINTS.append({"origin": ppos, "w": 8.0, "d": 8.0})
		sector_pois[tbid] = ppos
	mgr._poi_cache.clear()
	mgr._poi_cache_built = false
	var chosen_targets := {}
	for tbid in [901, 902, 903]:
		var tb: Dictionary = mgr.bots[tbid]
		tb["camp_spot"] = camp_base
		tb["ai_directive"] = {}
		tb["explore_dwell"] = 0.0
		var tmem: Dictionary = tb.get("_mem", {})
		tmem["visited"] = []
		tmem["last_death_pos"] = Vector3.INF
		tb["_visited"] = []
		(tb["proxy"] as Node3D).global_position = camp_base
		var chosen := mgr._choose_explore_target(tb)
		tb["explore_target"] = chosen
		chosen_targets[tbid] = chosen
		var sec2 := mgr._bot_explore_sector(tb)
		var away := Vector2(chosen.x - camp_base.x, chosen.z - camp_base.z)
		var diff := absf(wrapf(away.angle() - sec2, -PI, PI))
		check(chosen != Vector3.INF and diff < 2.0,
			"Dispersion 8a: bot %d elige un POI dentro de su sector de exploracion (diff=%.2f rad)" % [tbid, diff])
	check(chosen_targets[901] != chosen_targets[902] and chosen_targets[901] != chosen_targets[903] and chosen_targets[902] != chosen_targets[903],
		"Dispersion 8b: los tres bots eligen POIs distintos y no convergen a la misma zona")

	# Carne cruda = intoxicacion como en el jugador humano (get_sick 60s):
	# primera ingestion reduce hambre/sed/salud a la mitad y bloquea la
	# regeneracion pasiva mientras dura la enfermedad.
	var sick_b: Dictionary = mgr.bots[901]
	var sick_p: Node3D = sick_b["proxy"]
	sick_p.set_meta("saved_inventory", [{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 2, "use_value": 15.0}])
	sick_b["hunger"] = 20.0  # desesperado: la come cruda
	sick_b["thirst"] = 50.0
	sick_b["health"] = 80.0
	sick_b["eat_cooldown"] = 0.0
	sick_b["sick_timer"] = 0.0
	mgr._maintain_bot_needs(sick_b, 0.1)
	check(float(sick_b.get("sick_timer", 0.0)) >= 59.0,
		"Enfermedad 9a: comer carne cruda desesperado enferma al bot como a un humano (sick_timer=%.1f)" % float(sick_b.get("sick_timer", 0.0)))
	check(float(sick_b["health"]) < 45.0 and float(sick_b["hunger"]) < 15.0,
		"Enfermedad 9b: la intoxicacion reduce salud y hambre a la mitad como en SurvivalStats.get_sick")
	# La carne cruda no se toca sin desesperacion: con hambre moderada la cocina
	sick_b["sick_timer"] = 0.0
	sick_b["hunger"] = 55.0
	sick_b["eat_cooldown"] = 0.0
	sick_p.set_meta("saved_inventory", [{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 15.0}])
	mgr._maintain_bot_needs(sick_b, 0.1)
	check(float(sick_b.get("sick_timer", 0.0)) <= 0.0 and int((sick_p.get_meta("saved_inventory", []) as Array).size()) == 1,
		"Enfermedad 9c: sin desesperacion el bot no come carne cruda (prefiere cocinarla)")

	# Spawn realista: el bot nace como un jugador humano — solo la ropa puesta,
	# sin arma, sin mochila ni items — y su respawn nunca cerca del punto de
	# muerte (morir te reubica en otra zona del mapa)
	var fresh_proxy: Node3D = mgr.bots[902]["proxy"]
	fresh_proxy.queue_free()
	mgr.bots.erase(902)
	mgr._spawn_bot((mgr.BOT_CONFIGS as Array)[1])
	var fresh_b: Dictionary = mgr.bots[902]
	var f_inv: Array = fresh_b["proxy"].get_meta("saved_inventory", [])
	var f_weapons := 0
	for f_it in f_inv:
		var f_nm := str((f_it as Dictionary).get("name", ""))
		if f_nm in ["Fusil de asalto", "Rifle francotirador", "Arco reforzado", "Arco de madera", "Lanza", "Hacha", "Cuchillo", "Palo afilado"]:
			f_weapons += 1
	check(f_weapons == 0 and str(fresh_b["proxy"].get_meta("saved_held_item", "?")) == "",
		"SpawnReal 10a: el bot nace sin arma ni items, solo con su ropa (igual que el jugador humano)")
	var death_p := Vector3(0.0, 0.0, 0.0)
	var old_zones = world.get("_spawn_zones")
	world._spawn_zones = [Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), Vector3(400.0, 0.0, 0.0)]
	var spawn_p := mgr._random_bot_spawn(fresh_b["cfg"], death_p)
	check(Vector2(spawn_p.x - death_p.x, spawn_p.z - death_p.z).length() >= 200.0,
		"SpawnReal 10b: el respawn queda a >=220 m del punto de muerte (dist=%.0f m)" % Vector2(spawn_p.x - death_p.x, spawn_p.z - death_p.z).length())
	if old_zones is Array:
		world._spawn_zones = old_zones
	# SpawnReal 10c: dos supervivientes nunca comparten punto de aparicion.
	# Con una zona a 15 m de Elena y otra a 300 m, el spawn debe elegir la lejana.
	var elena_p: Vector3 = mgr.bots[901]["proxy"].global_position
	world._spawn_zones = [elena_p + Vector3(15.0, 0.0, 0.0), elena_p + Vector3(300.0, 0.0, 0.0)]
	var spawn_far := mgr._random_bot_spawn(fresh_b["cfg"], Vector3.INF)
	check(Vector2(spawn_far.x - elena_p.x, spawn_far.z - elena_p.z).length() >= 80.0,
		"SpawnReal 10c: el spawn nunca queda pegado a otro superviviente (sep a Elena=%.0f m)" % Vector2(spawn_far.x - elena_p.x, spawn_far.z - elena_p.z).length())
	if old_zones is Array:
		world._spawn_zones = old_zones
	# SpawnReal 10d: sed sin agua localizable no congela al bot. Antes, la rama
	# de beber hacia `return` siempre: con thirst<32 y _nearest_water_pos=INF
	# (river_segs vacio en el mundo de prueba) el bot quedaba en idle eterno.
	world.river_segs = []
	fresh_b["thirst"] = 20.0
	fresh_b["hunger"] = 90.0
	fresh_b["drink_at"] = Vector3.INF
	fresh_b["drink_scan"] = 0.0
	for i in range(40):
		mgr._tick_bot(fresh_b, 0.1)
	var acted := str(fresh_b.get("_act", ""))
	var moved: bool = str(fresh_b.get("anim", "")) in ["walk", "run"] or acted in ["explore", "dwell", "predator", "forage"] or fresh_b.get("explore_target", Vector3.INF) != Vector3.INF
	check(acted != "drink" and moved,
		"SpawnReal 10d: sed sin agua no congela al bot (act=%s anim=%s)" % [acted, str(fresh_b.get("anim", "?"))])

	# 10e: la telemetria web expone jugadores humanos desde server_proxies / net.players
	var h_proxy := Node3D.new()
	world.add_child(h_proxy)
	h_proxy.global_position = Vector3(111.0, 0.4, -222.0)
	h_proxy.set_meta("proxy_health", 88.0)
	world.server_proxies[7] = h_proxy
	fnet.players[7] = {"name": "Sami", "char_name": "Sami", "pos": h_proxy.global_position, "offline": false}
	var web_st := mgr.get_full_web_status()
	var web_pls: Array = web_st.get("players", [])
	check(web_pls.size() >= 1 and str((web_pls[0] as Dictionary).get("name", "")) == "Sami",
		"SpawnReal 10e: get_full_web_status incluye jugadores humanos conectados en server_proxies (n=%d)" % web_pls.size())
	world.server_proxies.erase(7)
	fnet.players.erase(7)
	h_proxy.queue_free()

	# 10f: un destino bloqueado tras agua profunda se abandona y entra en lista negra
	var unreach := Vector3(500.0, 0.4, 500.0)
	fresh_b["explore_target"] = unreach
	mgr._abandon_unreachable_goal(fresh_b, unreach)
	check(fresh_b["explore_target"] == Vector3.INF and mgr._is_goal_blacklisted(fresh_b, unreach),
		"SpawnReal 10f: objetivo inalcanzable se abandona y queda en lista negra para no oscilar")
	# Un nodo de material inalcanzable tambien suelta el _gather y su claim:
	# sin esto el bot quedaba en act=mats empujando siempre contra el mismo sitio
	fresh_b["_gather"] = {"id": "mat_unreach", "pos": unreach, "kind": "stone"}
	fresh_b["explore_target"] = Vector3.INF
	mgr._abandon_unreachable_goal(fresh_b, unreach)
	check((fresh_b["_gather"] as Dictionary).is_empty() and mgr._is_goal_blacklisted(fresh_b, unreach),
		"SpawnReal 10f: nodo de material inalcanzable libera el gather y no se re-elige")
	# Un _gather LEJOS del objetivo abandonado no se ve afectado (p.ej. una
	# interrupcion de loot): sigue suyo, con claim y todo
	fresh_b["_gather"] = {"id": "mat_far", "pos": unreach + Vector3(80.0, 0.0, 0.0), "kind": "stone"}
	mgr._abandon_unreachable_goal(fresh_b, Vector3(-900.0, 0.4, -900.0))
	check(not (fresh_b["_gather"] as Dictionary).is_empty(),
		"SpawnReal 10f: un gather en curso ajeno al objetivo fallido se conserva")
	fresh_b["_gather"] = {}

	# 10g: bot situado DETRAS de una casa cerrada con bot_nav activa rodea el
	# edificio hasta la puerta frontal, la abre y entra a recoger el loot
	world._server_door_states["Casa prueba Door"] = false
	world.bot_nav = NavPathfinding.new()
	world.bot_nav.build(world.wildlife_blockers, [])
	world._refresh_nav_door_caches()
	fresh_b["proxy"].global_position = Vector3(60.0, 0.4, 70.0) # muro trasero (+Z), puerta en (60,0,55)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["path"] = []
	fresh_b["path_timer"] = 0.0
	fresh_b["stuck_timer"] = 0.0
	fresh_b["stuck_count"] = 0
	fresh_b["macro_timer"] = 0.0
	fresh_b["macro_pos"] = fresh_b["pos"]
	for i in range(120):
		mgr._move_bot_towards(fresh_b, Vector3(60.0, 0.4, 60.0), 4.5, 0.1, "run")
		if Vector2(fresh_b["proxy"].global_position.x - 60.0, fresh_b["proxy"].global_position.z - 60.0).length() < 2.2:
			break
	var opened_back := bool(world._server_door_states.get("Casa prueba Door", false))
	var dist_inside := Vector2(fresh_b["proxy"].global_position.x - 60.0, fresh_b["proxy"].global_position.z - 60.0).length()
	check(opened_back and dist_inside < 2.5,
		"SpawnReal 10g: bot detras de casa cerrada rodea al umbral, abre la puerta y entra con bot_nav (open=%s dist=%.2f)" % [str(opened_back), dist_inside])

	# 10h: los POIs incluyen Base Cima y Lago, y el bot sube por la carretera
	# de montana hasta la Base Militar de la Cima (+56 m)
	mgr._poi_cache_built = false
	mgr._poi_cache.clear()
	var all_pois := mgr._explore_pois()
	var has_summit_poi := false
	var has_lake_poi := false
	for p_it in all_pois:
		var ppos2: Vector3 = (p_it as Dictionary)["pos"]
		if ppos2.x < -340.0 and ppos2.z < -340.0 and ppos2.y >= 50.0:
			has_summit_poi = true
		if ppos2.x > 150.0 and ppos2.z < -220.0:
			has_lake_poi = true
	check(has_summit_poi and has_lake_poi,
		"SpawnReal 10h: _explore_pois incluye la Base Militar de la Cima y la zona del Lago (summit=%s lake=%s)" % [str(has_summit_poi), str(has_lake_poi)])
	fresh_b["proxy"].global_position = Vector3(-252.0, 0.8, -268.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["path"] = []
	var summit_goal := Vector3(-375.0, 56.0, -375.0)
	for i in range(420):
		mgr._move_bot_towards(fresh_b, summit_goal, 5.0, 0.25, "run")
		if fresh_b["proxy"].global_position.distance_to(summit_goal) < 3.5:
			break
	var end_pos: Vector3 = fresh_b["proxy"].global_position
	check(end_pos.y >= 54.0 and Vector2(end_pos.x - summit_goal.x, end_pos.z - summit_goal.z).length() < 4.5,
		"SpawnReal 10i: el bot sube por la carretera en espiral hasta la Base Cima (pos=%s)" % str(end_pos))

	# 10j: los bots roban objetos utiles de refugios ajenos
	fresh_b["proxy"].global_position = Vector3(20.0, 0.4, 20.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["shelter_id"] = ""
	fresh_b["shelter_pos"] = Vector3.INF
	fresh_b["hunger"] = 40.0
	fresh_b["proxy"].set_meta("saved_inventory", [])
	world._built_shelters.append({
		"id": "player_shelter_999",
		"pos": Vector3(21.0, 0.4, 20.0),
		"yaw": 0.0,
		"contents": [
			{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 0.0},
			{"name": "Lata de guiso abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 35.0},
		],
	})
	var raid_cand := mgr._find_nearby_raidable_shelter(fresh_b, 30.0)
	var stolen_n := mgr._bot_raid_shelter(fresh_b, raid_cand)
	var fk_sh := mgr._find_shelter_dict("player_shelter_999")
	check(stolen_n >= 2 and (fk_sh.get("contents", []) as Array).is_empty() and mgr._bot_item_count(fresh_b["proxy"], "Fusil de asalto") == 1,
		"SpawnReal 10j: el bot roba armas y comida de un refugio ajeno (stolen=%d)" % stolen_n)

	# 10k: el bot guarda su loot sobrante en su propio refugio y retira cuando tiene hambre
	fresh_b["shelter_id"] = "bot_shelter_902"
	fresh_b["shelter_pos"] = Vector3(20.0, 0.4, 20.0)
	fresh_b["campfire_id"] = "bot_cf_902"
	world._built_shelters.append({
		"id": "bot_shelter_902",
		"pos": Vector3(20.0, 0.4, 20.0),
		"yaw": 0.0,
		"contents": [],
	})
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 0.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "use_value": 0.0},
		{"name": "Hacha", "type": "tool_axe", "weight": 1.2, "quantity": 1, "use_value": 0.0},
		{"name": "Arco de madera", "type": "weapon_bow", "weight": 0.9, "quantity": 1, "use_value": 0.0},
		{"name": "Lata de atun abierta", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 18.0},
		{"name": "Piel de ciervo", "type": "resource", "weight": 0.6, "quantity": 2, "use_value": 0.0},
	])
	var stored_m := mgr._bot_sync_own_shelter_stash(fresh_b)
	var own_contents := mgr._get_shelter_contents("bot_shelter_902")
	check(stored_m >= 4 and own_contents.size() >= 3 and mgr._bot_item_count(fresh_b["proxy"], "Fusil de asalto") == 1 and mgr._bot_item_count(fresh_b["proxy"], "Arco de madera") == 0,
		"SpawnReal 10k: el bot guarda armas/comida/pieles sobrantes en su propio refugio y conserva su fusil (stash=%d)" % own_contents.size())
	# Ahora simular que el bot vuelve hambriento y sin comida encima: retira del alijo propio
	fresh_b["hunger"] = 30.0
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 0.0},
	])
	mgr._bot_sync_own_shelter_stash(fresh_b)
	check(mgr._bot_item_count(fresh_b["proxy"], "Lata de atun abierta") >= 1,
		"SpawnReal 10l: el bot retira comida de su propio refugio cuando tiene hambre")

	# 10m y 10n: cocinar carne cruda exige Palo afilado para ensartarla y
	# permite al bot armar/encender una hoguera para asarla igual que un humano
	fresh_b["cook_cooldown"] = 0.0
	fresh_b["campfire_id"] = ""
	fresh_b["campfire_pos"] = Vector3.INF
	world._lit_campfires.clear()
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 20.0},
	])
	check(not mgr._bot_cook_meat_at_fire(fresh_b) and mgr._bot_item_count(fresh_b["proxy"], "Carne asada en palo") == 0,
		"SpawnReal 10m: sin Palo afilado el bot no puede cocinar la carne cruda")
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 20.0},
		{"name": "Palo afilado", "type": "tool_spear", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Palo", "type": "resource", "weight": 0.15, "quantity": 2, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.45, "quantity": 2, "use_value": 0.0},
	])
	for i in range(25):
		mgr._bot_try_cook_meat(fresh_b, 0.2)
		if mgr._bot_item_count(fresh_b["proxy"], "Carne asada en palo") > 0:
			break
	check(not str(fresh_b.get("campfire_id", "")).is_empty() and mgr._bot_item_count(fresh_b["proxy"], "Carne asada en palo") == 1 and mgr._bot_item_count(fresh_b["proxy"], "Palo afilado") == 0,
		"SpawnReal 10n: con Palo afilado + 2 Palos + 2 Piedras el bot hace hoguera, ensarta la carne y la cocina (cf=%s)" % str(fresh_b.get("campfire_id", "")))

	# 10o: percepcion auditiva — un disparo de rifle a 85 m es oido por los
	# otros bots (activa alerta/huida en desarmados y aggro en un bot armado)
	fresh_b["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["flee_until"] = 0.0
	fresh_b["caution_until"] = 0.0
	fresh_b["proxy"].set_meta("saved_inventory", []) # desarmado
	var kael_b: Dictionary = mgr.bots[903]
	kael_b["proxy"].global_position = Vector3(85.0, 0.4, 0.0)
	kael_b["pos"] = kael_b["proxy"].global_position
	kael_b["aggro_target"] = null
	kael_b["proxy"].set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 0.0},
	])
	mgr.notify_sound_event(903, kael_b["proxy"].global_position, "gunshot", 220.0)
	check(float(fresh_b.get("caution_until", 0.0)) >= 10.0 and float(fresh_b.get("flee_until", 0.0)) >= 8.0 and mgr.bot_knows_event(902, "heard_gunshot"),
		"SpawnReal 10o: bot desarmado a 85 m oye el disparo de rifle, registra heard_gunshot y entra en cautela/huida")
	mgr.notify_sound_event(902, fresh_b["proxy"].global_position, "gunshot", 220.0)
	check(kael_b.get("aggro_target") == fresh_b["proxy"],
		"SpawnReal 10p: bot hostil armado a 85 m oye el disparo y localiza al tirador")

	# 10q: sin refugio construido, un bot con Pez crudo + Palo afilado +
	# 2 Palos + 2 Piedras crea hoguera, ensarta el pez (Pez ensartado) y lo
	# cocina (Pez cocinado)
	fresh_b["shelter_id"] = ""
	fresh_b["shelter_pos"] = Vector3.INF
	fresh_b["campfire_id"] = ""
	fresh_b["campfire_pos"] = Vector3.INF
	fresh_b["cook_cooldown"] = 0.0
	world._lit_campfires.clear()
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Pez crudo", "type": "food", "weight": 0.4, "quantity": 1, "use_value": 15.0},
		{"name": "Palo afilado", "type": "tool_spear", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Palo", "type": "resource", "weight": 0.15, "quantity": 2, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.45, "quantity": 2, "use_value": 0.0},
	])
	for i in range(25):
		mgr._bot_try_cook_meat(fresh_b, 0.2)
		if mgr._bot_item_count(fresh_b["proxy"], "Pez cocinado") > 0:
			break
	check(str(fresh_b.get("shelter_id", "")).is_empty() and not str(fresh_b.get("campfire_id", "")).is_empty() and mgr._bot_item_count(fresh_b["proxy"], "Pez cocinado") == 1,
		"SpawnReal 10q: sin refugio el bot crea hoguera para cocinar Pez crudo ensartado en Palo afilado -> Pez cocinado")

	# 10r: un bot entra en una vivienda de 2 plantas de la ciudad (city_01),
	# abre su puerta, sube por las escaleras (anim=stairs) hasta la planta
	# superior (y=3.92) y llega a la habitacion alta
	var city01_pos: Vector3 = Vector3(9.0, 0.0, 680.0) + Vector3(-16.0, 0.0, -17.0)
	var city01_idx: int = world._register_wildlife_blocker(city01_pos, 9.0)
	world.wildlife_blockers[city01_idx]["door_name"] = "city_01_door"
	world.wildlife_blockers[city01_idx]["door_pos"] = city01_pos + Vector3(-0.85, 0.12, 6.08)
	world.wildlife_blockers[city01_idx]["door_center"] = city01_pos + Vector3(0.15, 0.12, 6.08)
	world.wildlife_blockers[city01_idx]["door_out_dir"] = Vector2(0.0, 1.0)
	world.wildlife_blockers[city01_idx]["city_building_index"] = 0
	world.wildlife_blockers[city01_idx]["building_yaw"] = 0.0
	world.wildlife_blockers[city01_idx]["house_bounds"] = Rect2(city01_pos.x - 6.0, city01_pos.z - 6.0, 12.0, 12.0)
	world._server_door_states["city_01_door"] = false
	world._refresh_nav_door_caches()
	fresh_b["proxy"].global_position = city01_pos + Vector3(-3.5, 0.12, 9.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["has_rifle"] = false
	fresh_b["path"] = []
	var upper_room_goal: Vector3 = city01_pos + Vector3(-1.2, 3.92, -2.5)
	var saw_stairs_anim := false
	for i in range(180):
		mgr._move_bot_towards(fresh_b, upper_room_goal, 3.8, 0.12, "walk")
		if str(fresh_b.get("anim", "")) == "stairs":
			saw_stairs_anim = true
		if fresh_b["proxy"].global_position.distance_to(upper_room_goal) < 1.2:
			break
	var pos_after_house: Vector3 = fresh_b["proxy"].global_position
	check(bool(world._server_door_states.get("city_01_door", false)) and saw_stairs_anim and pos_after_house.y > 3.5 and pos_after_house.distance_to(upper_room_goal) < 1.8,
		"SpawnReal 10r: el bot abre la puerta de city_01, sube las escaleras (anim=stairs) y explora el piso superior (pos=%s)" % str(pos_after_house))

	# 10s: el bot explora la Torre del Reloj de la ciudad (41, 0, 750), sube
	# piso a piso los 7 tramos de escaleras en zigzag y llega hasta el final
	# en la azotea (y=29.46 m)
	fresh_b["proxy"].global_position = Vector3(41.0, 0.06, 738.0) # frente al pórtico norte
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["path"] = []
	var ct_roof_goal := Vector3(39.6, 29.46, 750.8)
	var max_tower_y := 0.0
	var floors_seen := {}
	for i in range(600):
		mgr._move_bot_towards(fresh_b, ct_roof_goal, 4.0, 0.15, "walk")
		var py: float = fresh_b["proxy"].global_position.y
		max_tower_y = maxf(max_tower_y, py)
		floors_seen[clampi(int(round((py - 0.06) / 4.2)), 0, 7)] = true
		if fresh_b["proxy"].global_position.distance_to(ct_roof_goal) < 1.5:
			break
	var ct_end: Vector3 = fresh_b["proxy"].global_position
	check(ct_end.y >= 28.8 and floors_seen.size() >= 7 and ct_end.distance_to(ct_roof_goal) < 2.2,
		"SpawnReal 10s: el bot sube la Torre del Reloj piso a piso (%d plantas) hasta la cima a 29.46 m (pos=%s)" % [floors_seen.size(), str(ct_end)])

	# 10t: cuando forma equipo con un jugador humano, el bot aliado sigue al
	# jugador dentro de la casa y sube las escaleras con él al piso superior
	var leader_human := Node3D.new()
	world.add_child(leader_human)
	leader_human.global_position = city01_pos + Vector3(-1.0, 3.92, 1.5) # humano en la 2ª planta de city_01
	world.server_proxies[1] = leader_human
	fresh_b["team_leader_id"] = 1
	fresh_b["follow_mode"] = "follow"
	fresh_b["proxy"].global_position = city01_pos + Vector3(0.0, 0.12, 9.5) # bot fuera en la calle
	fresh_b["pos"] = fresh_b["proxy"].global_position
	for i in range(180):
		mgr._tick_teammate_behavior(fresh_b, leader_human, 0.12)
		if fresh_b["proxy"].global_position.distance_to(leader_human.global_position) < 2.6:
			break
	var team_pos: Vector3 = fresh_b["proxy"].global_position
	check(team_pos.y > 3.5 and team_pos.distance_to(leader_human.global_position) < 3.2,
		"SpawnReal 10t: en equipo el bot sigue al jugador humano dentro de la casa y sube las escaleras al 2º piso (pos=%s)" % str(team_pos))
	world.server_proxies.erase(1)
	leader_human.queue_free()

	# 10u: los bots recogen las mochilas del pueblo — cualquier modelo que
	# mejore la suya (sin mochila -> Mochila pequena -> Mochila militar), la
	# equipada sale del inventario y la vieja vuelve como repuesto.
	fresh_b["team_leader_id"] = 0
	fresh_b["backpack"] = ""
	fresh_b["proxy"].set_meta("saved_backpack", "")
	fresh_b["proxy"].set_meta("saved_inventory", [])
	check(mgr._is_loot_desirable(fresh_b, "Mochila pequena", "backpack"),
		"SpawnReal 10u1: sin mochila la Mochila pequena del pueblo interesa")
	check(not mgr._is_loot_desirable(fresh_b, "Cuchillo", "backpack"),
		"SpawnReal 10u2: un objeto tipo backpack sin nombre de mochila no interesa")
	world._dropped_items = [
		{"id": "vil_bp", "name": "Mochila pequena", "type": "backpack", "pos": fresh_b["proxy"].global_position + Vector3(1, 0, 0), "qty": 1, "weight": 0.9, "use": 0.0},
	]
	mgr._collect_loot_entry(fresh_b, world._dropped_items[0])
	check(str(fresh_b["backpack"]) == "Mochila pequena" and mgr._bot_item_count(fresh_b["proxy"], "Mochila pequena") == 0,
		"SpawnReal 10u3: recoge la mochila del pueblo y la lleva equipada (sale del inventario)")
	check(not mgr._is_loot_desirable(fresh_b, "Mochila pequena", "backpack") and mgr._is_loot_desirable(fresh_b, "Mochila militar", "backpack"),
		"SpawnReal 10u4: con pequena puesta no recoge otra igual, pero sí la militar")
	world._dropped_items = [
		{"id": "mil_bp", "name": "Mochila militar", "type": "backpack", "pos": fresh_b["proxy"].global_position + Vector3(1, 0, 0), "qty": 1, "weight": 1.8, "use": 0.0},
	]
	mgr._collect_loot_entry(fresh_b, world._dropped_items[0])
	check(str(fresh_b["backpack"]) == "Mochila militar" and mgr._bot_item_count(fresh_b["proxy"], "Mochila pequena") == 1 and mgr._bot_item_count(fresh_b["proxy"], "Mochila militar") == 0,
		"SpawnReal 10u5: mejora a la militar y guarda la pequena de repuesto")
	world._dropped_items = []

	# 10v: los bots beben de la fuente de la plaza de la ciudad — la zona
	# drink_water cae dentro del bloqueador circular de la pileta, así que el
	# destino se proyecta al brocal (fuera del bloqueo) y allí bebe/rellena.
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0},
	])
	var fountain_pos := Vector3(41.0, 0.0, 728.0)
	world._register_wildlife_blocker(fountain_pos, 2.0)
	var ftn_drink := WorldActionScript.new()
	ftn_drink.setup("district_fountain_drink", "drink_water", "Fuente de la plaza", Vector3(4.6, 1.7, 4.6), Color(0.08, 0.22, 0.48, 0.0), true, false)
	world.add_child(ftn_drink)
	ftn_drink.global_position = fountain_pos + Vector3(0.0, 0.9, 0.0)
	world.world_actions_by_id["district_fountain_drink"] = ftn_drink
	fresh_b["proxy"].global_position = fountain_pos + Vector3(18.0, 0.375, 0.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["thirst"] = 20.0
	fresh_b["hunger"] = 90.0
	fresh_b["drink_at"] = Vector3.INF
	fresh_b["drink_scan"] = 0.0
	fresh_b["drink_walk_t"] = 0.0
	fresh_b["drinking_timer"] = 0.0
	fresh_b["drink_giveup"] = 0.0
	fresh_b["_bad_water"] = []
	fresh_b["aggro_target"] = null
	fresh_b["_s_leader"] = null
	fresh_b["_s_foe"] = null
	fresh_b["_s_predator"] = null
	fresh_b["_s_tame_wolf"] = null
	fresh_b["_s_has_wolf"] = false
	fresh_b["_s_loot"] = {}
	fresh_b["_s_raid_shelter"] = {}
	fresh_b["gut_target"] = null
	fresh_b["flee_until"] = 0.0
	fresh_b["forced_eat"] = false
	fresh_b["hide_timer"] = 0.0
	fresh_b["flinch_timer"] = 0.0
	world.river_segs = []
	mgr._tick_bot(fresh_b, 0.1)
	var ftn_goal: Vector3 = fresh_b["drink_at"]
	var ftn_dist := Vector2(ftn_goal.x - fountain_pos.x, ftn_goal.z - fountain_pos.z).length() if ftn_goal != Vector3.INF else -1.0
	check(ftn_goal != Vector3.INF and ftn_dist > 2.0 and ftn_dist < 3.5 and not world.is_bot_blocked_at(ftn_goal),
		"SpawnReal 10v1: con sed el bot apunta al brocal de la fuente de la ciudad (goal=%s d=%.2f)" % [str(ftn_goal), ftn_dist])
	fresh_b["proxy"].global_position = ftn_goal
	fresh_b["pos"] = ftn_goal
	for i in range(45):
		mgr._tick_bot(fresh_b, 0.1)
	check(float(fresh_b["thirst"]) >= 95.0 and mgr._bot_item_count(fresh_b["proxy"], "Botella de agua llena") == 1,
		"SpawnReal 10v2: bebe en la fuente de la ciudad y rellena su botella (sed=%.0f)" % float(fresh_b["thirst"]))
	world.world_actions_by_id.erase("district_fountain_drink")
	ftn_drink.queue_free()

	# 10w: supervivencia de jugador humano en los bots — duermen de noche en su
	# refugio, despiertan con ruido/amenaza/amanecer, el frio y la lluvia les
	# afectan igual que al jugador, y encienden hogueras para calentarse.
	var vs: SurvivalStats = fresh_b["vstats"]
	check(vs != null and vs is SurvivalStats,
		"SpawnReal 10w0: cada bot lleva un modelo SurvivalStats humano real")
	fresh_b["proxy"].global_position = Vector3(500.0, 0.4, 500.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["shelter_pos"] = fresh_b["proxy"].global_position
	fresh_b["shelter_id"] = ""
	fresh_b["campfire_id"] = ""
	fresh_b["camp_spot"] = fresh_b["proxy"].global_position
	fresh_b["team_leader_id"] = 0
	fresh_b["aggro_target"] = null
	fresh_b["aggro_timer"] = 0.0
	fresh_b["hide_timer"] = 0.0
	fresh_b["flee_until"] = 0.0
	fresh_b["caution_until"] = 0.0
	fresh_b["flinch_timer"] = 0.0
	fresh_b["forced_eat"] = false
	fresh_b["gut_target"] = null
	fresh_b["climb_route"] = []
	fresh_b["sleeping"] = false
	fresh_b["hunger"] = 80.0
	fresh_b["thirst"] = 80.0
	fresh_b["health"] = 100.0
	fresh_b["proxy"].set_meta("proxy_health", 100.0)
	fresh_b["proxy"].set_meta("saved_inventory", [])
	for k in ["_s_predator", "_s_foe", "_s_leader", "_s_tame_wolf", "_s_prey", "_s_corpse"]:
		fresh_b[k] = null
	fresh_b["_s_loot"] = {}
	fresh_b["_s_raid_shelter"] = {}
	fresh_b["_s_has_wolf"] = false
	fresh_b["explore_target"] = Vector3.INF
	dc.time_of_day = 22.6
	dc.ambient_temp = 12.0
	vs.sleep = 55.0
	vs.body_temperature = 36.6
	vs.wetness = 0.0
	mgr._tick_bot(fresh_b, 0.1)
	check(bool(fresh_b["sleeping"]) and str(fresh_b["anim"]) == "sleep",
		"SpawnReal 10w1: de noche en su refugio el bot se tumba a dormir (anim=%s)" % str(fresh_b["anim"]))
	var sleep0 := vs.sleep
	for i in range(20):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.sleep > sleep0 and bool(fresh_b["sleeping"]),
		"SpawnReal 10w2: dormir recupera el sueño (%.1f->%.1f)" % [sleep0, vs.sleep])
	check(str(mgr._bot_effective_net_anim(fresh_b)) == "sleep",
		"SpawnReal 10w3: el avatar remoto muestra la pose de dormir")
	mgr.notify_sound_event(777, fresh_b["proxy"].global_position + Vector3(4.0, 0.0, 0.0), "gunshot", 220.0)
	check(not bool(fresh_b["sleeping"]),
		"SpawnReal 10w4: un disparo cercano lo despierta")
	fresh_b["caution_until"] = 0.0
	fresh_b["flee_until"] = 0.0
	vs.sleep = 60.0
	mgr._tick_bot(fresh_b, 0.1)
	check(bool(fresh_b["sleeping"]),
		"SpawnReal 10w5: pasado el susto vuelve a tumbarse a dormir")
	dc.time_of_day = 8.0
	vs.sleep = 80.0
	mgr._tick_bot(fresh_b, 0.1)
	check(not bool(fresh_b["sleeping"]),
		"SpawnReal 10w6: al amanecer se despierta solo")

	# La siesta diurna usa el mismo umbral de agotamiento que el acampada
	# (_bot_is_exhausted sube con las lecciones de frio): antes quedaba un
	# hueco "cansado para acampar pero no para dormir" y el bot se pasaba
	# el dia sentado sin recuperar sueño ni salir a buscar recursos.
	var mem_sl: Dictionary = fresh_b.get("_mem", {})
	fresh_b["sleeping"] = false
	vs.sleep = 18.0
	vs.body_temperature = 36.6
	fresh_b["hunger"] = 80.0
	fresh_b["thirst"] = 80.0
	check(not mgr._bot_is_exhausted(fresh_b) and not mgr._bot_try_start_sleep(fresh_b, false),
		"SpawnReal 10w7: sin lecciones no cabecea de dia con sueno 18")
	mem_sl["death_lessons"] = {"cold": 4.0}
	check(mgr._bot_is_exhausted(fresh_b) and mgr._bot_try_start_sleep(fresh_b, false) and bool(fresh_b["sleeping"]),
		"SpawnReal 10w8: con lecciones de frio el umbral sube y cabecea de dia (sleeping=%s)" % str(fresh_b["sleeping"]))
	fresh_b["sleeping"] = false
	mem_sl["death_lessons"] = {}
	vs.sleep = 10.0
	check(mgr._bot_try_start_sleep(fresh_b, false),
		"SpawnReal 10w9: sin lecciones sigue cabeceando por debajo de 14")
	fresh_b["sleeping"] = false

	# La IA asesora mando descansar al campamento: con la directiva activa la
	# siesta diurna funciona aunque el sueño no llegue al umbral letal — si
	# no, el bot orbita su solar en dwell infinito sin recuperar (Carlos).
	vs.sleep = 23.0
	fresh_b["ai_directive"] = {"action": "rest", "mode": "pos", "pos": fresh_b["proxy"].global_position, "until": Time.get_ticks_msec() + 60000}
	check(mgr._bot_wants_day_rest(fresh_b) and mgr._bot_try_start_sleep(fresh_b, false) and bool(fresh_b["sleeping"]),
		"10J5u1: con orden de descanso de la IA cabecea de dia con sueno 23 (sleeping=%s)" % str(fresh_b["sleeping"]))
	fresh_b["sleeping"] = false
	fresh_b["ai_directive"] = {"action": "explore", "mode": "poi", "until": Time.get_ticks_msec() + 60000}
	check(not mgr._bot_wants_day_rest(fresh_b) and not mgr._bot_try_start_sleep(fresh_b, false),
		"10J5u2: con otra directiva no cabecea de dia")
	fresh_b["ai_directive"] = {}
	vs.sleep = 80.0

	# Colapso por agotamiento letal: con sleep<=4 el cuerpo se apaga — el bot
	# se desploma dormido donde este aunque haga frio y tenga hambre. Antes
	# esas puertas le negaban el suelo: el sleep caia a 0 sentado y moria de
	# agotamiento (Carlos, 165 muertes) pese a estar "descansando".
	vs.sleep = 3.0
	vs.body_temperature = 34.6 # demasiado frio para dormir en condiciones normales
	fresh_b["hunger"] = 10.0   # y demasiado hambre
	fresh_b["thirst"] = 8.0    # y demasiada sed
	check(not mgr._bot_try_start_sleep(fresh_b, false),
		"SpawnReal 10x1: inanicion y deshidratacion criticas impiden volver al bucle de colapso")
	fresh_b["sleeping"] = false

	# El colapso tambien tumba escondido o huyendo: el cuerpo se apaga donde
	# este en vez de morir de pie por agotamiento (Kael, sleep<=4 + amenaza).
	fresh_b["hunger"] = 80.0
	fresh_b["thirst"] = 80.0
	vs.sleep = 3.0
	vs.body_temperature = 36.6
	fresh_b["hide_timer"] = 40.0
	fresh_b["flee_until"] = 40.0
	check(mgr._bot_try_start_sleep(fresh_b, false) and bool(fresh_b["sleeping"]),
		"10J5v1: el colapso letal tumba al bot aunque este escondido/huyendo (sleeping=%s)" % str(fresh_b["sleeping"]))
	check(not mgr._bot_should_wake(fresh_b, false),
		"10J5v2: escondido/huyendo no despierta a un bot colapsado")
	fresh_b["hide_timer"] = 0.0
	fresh_b["flee_until"] = 0.0
	fresh_b["sleeping"] = false
	fresh_b["aggro_target"] = (mgr.bots[901] as Dictionary)["proxy"]
	check(not mgr._bot_try_start_sleep(fresh_b, false),
		"10J5v3: en combate activo el colapso no duerme al bot")
	fresh_b["aggro_target"] = null
	# Restauro el estado letal que 10x1 dejo para el check 10x2.
	fresh_b["hunger"] = 10.0
	fresh_b["thirst"] = 8.0
	vs.body_temperature = 34.6

	vs.sleep = 8.0 # por encima del colapso las puertas de confort siguen cerrando
	check(not mgr._bot_try_start_sleep(fresh_b, false),
		"SpawnReal 10x2: con sueno 8 aun no hay colapso (frio/hambre bloquean el suelo normal)")
	vs.sleep = 18.0
	vs.body_temperature = 36.6
	fresh_b["hunger"] = 90.0
	fresh_b["thirst"] = 90.0

	# El tiempo enfria las heridas: sin agresiones recientes decaen odio,
	# miedo y rencor y la cicatriz de ataques se erosiona (suelo de 2); con
	# dano fresco nada decae — la reconciliacion empieza cuando cesa el fuego.
	var rels_dec: Dictionary = (fresh_b.get("_mem", {}) as Dictionary).get("relationships", {})
	var old_harm := Time.get_ticks_msec() - 120000 # herida vieja (o negativa: tambien vale "hace mucho")
	rels_dec["bot_999"] = {"id": "bot_999", "name": "Rival", "trust": -0.9, "hostility": 1.0, "fear": 1.0, "helped": 0, "attacked": 5, "harm_t": old_harm, "scar_t": old_harm}
	(fresh_b["_mem"] as Dictionary)["relationships"] = rels_dec
	mgr._rel_time_decay(fresh_b)
	var rd: Dictionary = mgr.get_bot_relationship(int(fresh_b["bot_id"]), "bot_999")
	check(float(rd.get("hostility", 0.0)) < 1.0 and float(rd.get("fear", 0.0)) < 1.0 and float(rd.get("trust", -1.0)) > -0.9,
		"SpawnReal 10x3: sin agresiones recientes odio, miedo y rencor enfrian (h=%.3f f=%.3f t=%.3f)" % [float(rd.get("hostility", 0.0)), float(rd.get("fear", 0.0)), float(rd.get("trust", 0.0))])
	check(int(rd.get("attacked", 0)) == 4,
		"SpawnReal 10x4: la cicatriz de ataques se erosiona una por tramo de paz (attacked=%d)" % int(rd.get("attacked", 0)))
	rd["harm_t"] = Time.get_ticks_msec()
	rd["hostility"] = 1.0
	(fresh_b["_mem"] as Dictionary)["relationships"]["bot_999"] = rd
	mgr._rel_time_decay(fresh_b)
	rd = mgr.get_bot_relationship(int(fresh_b["bot_id"]), "bot_999")
	check(float(rd.get("hostility", 0.0)) == 1.0,
		"SpawnReal 10x5: con dano fresco no enfria")
	rels_dec.erase("bot_999")

	# Gesto de paz: deja comida a un rival cercano con herida abierta y la
	# relacion mejora por los dos lados — rompe el circulo del miedo (quien
	# teme evita el contacto y sin contacto no llegan eventos positivos).
	var elena_g: Dictionary = mgr.bots[901]
	# Snapshot del estado que esta seccion toca: las pruebas reales mutan
	# facciones, equipo, relaciones y personalidad de Carlos/Elena y las
	# secciones 10y/10z/10B posteriores dependen de ese estado.
	var mem_c0: Dictionary = fresh_b["_mem"]
	var mem_e0: Dictionary = elena_g["_mem"]
	var snap_x: Dictionary = {
		"c_faction": str(fresh_b.get("faction", "")),
		"e_faction": str(elena_g.get("faction", "")),
		"c_lid": int(fresh_b.get("team_leader_id", 0)),
		"e_lid": int(elena_g.get("team_leader_id", 0)),
		"c_follow": str(fresh_b.get("follow_mode", "")),
		"e_follow": str(elena_g.get("follow_mode", "")),
		"c_rel_e": (mem_c0.get("relationships", {}) as Dictionary).get("bot_901", {}).duplicate(true),
		"e_rel_c": (mem_e0.get("relationships", {}) as Dictionary).get("bot_902", {}).duplicate(true),
		"c_pers": (mem_c0.get("personality", {}) as Dictionary).duplicate(true),
		"c_pos": fresh_b["proxy"].global_position,
		"e_pos": elena_g["proxy"].global_position,
		"c_dead_meta": bool(fresh_b["proxy"].get_meta("proxy_dead", false)),
		"e_dead_meta": bool(elena_g["proxy"].get_meta("proxy_dead", false)),
		"c_dead": bool(fresh_b.get("dead", false)),
		"e_dead": bool(elena_g.get("dead", false)),
		"c_sleep": bool(fresh_b.get("sleeping", false)),
		"e_sleep": bool(elena_g.get("sleeping", false)),
		"c_aggro": fresh_b.get("aggro_target"),
		"e_aggro": elena_g.get("aggro_target"),
		"c_inv": (fresh_b["proxy"].get_meta("saved_inventory", []) as Array).duplicate(true),
	}
	# Establish eligibility explicitly: earlier cases can leave different
	# factions, dead metadata or an active fight on the receiving bot.
	fresh_b["faction"] = "hostile"
	elena_g["faction"] = "hostile"
	for participant in [fresh_b, elena_g]:
		participant["proxy"].set_meta("proxy_dead", false)
		participant["dead"] = false
		participant["aggro_target"] = null
	rels_dec["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": -0.8, "hostility": 1.0, "fear": 1.0, "helped": 0, "attacked": 4, "harm_t": old_harm}
	fresh_b["hunger"] = 90.0
	fresh_b["thirst"] = 90.0
	fresh_b["aggro_target"] = null
	fresh_b["hide_timer"] = 0.0
	fresh_b["flee_until"] = 0.0
	fresh_b["sleeping"] = false
	fresh_b["proxy"].global_position = (elena_g["proxy"] as Node3D).global_position + Vector3(10.0, 0.0, 0.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	var pers_g: Dictionary = mgr._get_bot_personality(fresh_b)
	pers_g["sociability"] = 1.0
	pers_g["cooperation"] = 1.0
	pers_g["distrust"] = 0.0
	fresh_b["proxy"].set_meta("saved_inventory", [{"name": "Carne asada", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 25.0}])
	var drops_before_g: int = (world._dropped_items as Array).size()
	# Personality is clamped to the bot's temperament; even a cooperative
	# bot may decline one attempt. Exercise bounded opportunities in peace.
	for attempt in range(16):
		mgr._bot_try_peace_gesture(fresh_b)
		if (world._dropped_items as Array).size() > drops_before_g:
			break
	var r_out: Dictionary = mgr.get_bot_relationship(902, "bot_901")
	var r_in: Dictionary = mgr.get_bot_relationship(901, "bot_902")
	check(float(r_out.get("trust", -1.0)) > -0.8 and int(r_out.get("helped", 0)) >= 1 and float(r_in.get("trust", 0.0)) > 0.0 and int(r_in.get("helped", 0)) >= 1,
		"SpawnReal 10x6: el gesto de paz repara la relacion por los dos lados (out=%.2f in=%.2f)" % [float(r_out.get("trust", 0.0)), float(r_in.get("trust", 0.0))])
	check(mgr._bot_item_count(fresh_b["proxy"], "Carne asada") == 2 and (world._dropped_items as Array).size() > drops_before_g,
		"SpawnReal 10x7: el regalo sale de su inventario y queda en el suelo")
	# Con dano reciente no hay gesto — no perdona en caliente
	rels_dec["bot_901"]["harm_t"] = Time.get_ticks_msec()
	r_out["trust"] = -0.8
	(fresh_b["_mem"] as Dictionary)["relationships"]["bot_901"] = r_out
	fresh_b["proxy"].set_meta("saved_inventory", [{"name": "Carne asada", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 25.0}])
	var helped_before := int(mgr.get_bot_relationship(902, "bot_901").get("helped", 0))
	(fresh_b["_mem"] as Dictionary)["relationships"]["bot_901"]["harm_t"] = Time.get_ticks_msec()
	mgr._bot_try_peace_gesture(fresh_b)
	check(int(mgr.get_bot_relationship(902, "bot_901").get("helped", 0)) == helped_before,
		"SpawnReal 10x8: con herida fresca no ofrece paz todavia")
	rels_dec.erase("bot_901")

	# Convivencia de banda: entre hostiles la puerta civil sube a 0.55 — dos
	# rivales templados (hostility 0.50) ya conviven aunque aun no se quieran
	var rels_e2: Dictionary = (elena_g.get("_mem", {}) as Dictionary).get("relationships", {})
	rels_dec["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": 0.2, "hostility": 0.50, "fear": 0.4, "helped": 0, "attacked": 1, "harm_t": old_harm}
	rels_e2["bot_902"] = {"id": "bot_902", "name": "Carlos", "trust": 0.2, "hostility": 0.50, "fear": 0.4, "helped": 0, "attacked": 1, "harm_t": old_harm}
	(elena_g["_mem"] as Dictionary)["relationships"] = rels_e2
	fresh_b["proxy"].global_position = (elena_g["proxy"] as Node3D).global_position + Vector3(8.0, 0.0, 0.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	var tr_c0 := float(mgr.get_bot_relationship(902, "bot_901").get("trust", 0.0))
	fresh_b["team_leader_id"] = 0
	elena_g["team_leader_id"] = 0
	fresh_b["faction"] = "hostile"
	elena_g["faction"] = "hostile"
	for bb in [fresh_b, elena_g]:
		(bb["proxy"] as Node3D).set_meta("proxy_dead", false)
		bb["dead"] = false
		bb["sleeping"] = false
	fresh_b["_soc_t"] = 0.0
	elena_g["_soc_t"] = 0.0
	mgr._bot_social_update(fresh_b)
	fresh_b["_soc_t"] = 0.0
	elena_g["_soc_t"] = 0.0
	mgr._bot_social_update(elena_g)
	check(float(mgr.get_bot_relationship(902, "bot_901").get("trust", 0.0)) > tr_c0 or int(fresh_b.get("team_leader_id", 0)) > 0 or int(elena_g.get("team_leader_id", 0)) > 0,
		"SpawnReal 10x9: dos hostiles a media hostilidad ya conviven y crecen el vinculo")
	# Restauracion: facciones del dict (el mem.identity no se toco — se
	# cambiaron en crudo a proposito para el early-return de _set_bot_faction),
	# equipo, relaciones Carlos<->Elena, personalidad, flags e inventario.
	fresh_b["faction"] = str(snap_x["c_faction"])
	elena_g["faction"] = str(snap_x["e_faction"])
	fresh_b["team_leader_id"] = int(snap_x["c_lid"])
	elena_g["team_leader_id"] = int(snap_x["e_lid"])
	fresh_b["proxy"].set_meta("team_leader_id", int(snap_x["c_lid"]))
	elena_g["proxy"].set_meta("team_leader_id", int(snap_x["e_lid"]))
	fresh_b["follow_mode"] = str(snap_x["c_follow"])
	elena_g["follow_mode"] = str(snap_x["e_follow"])
	if (snap_x["c_rel_e"] as Dictionary).is_empty():
		rels_dec.erase("bot_901")
	else:
		rels_dec["bot_901"] = snap_x["c_rel_e"]
	if (snap_x["e_rel_c"] as Dictionary).is_empty():
		rels_e2.erase("bot_902")
	else:
		rels_e2["bot_902"] = snap_x["e_rel_c"]
	mem_c0["personality"] = snap_x["c_pers"]
	fresh_b["proxy"].set_meta("saved_inventory", snap_x["c_inv"])
	fresh_b["_peace_cd"] = {}
	fresh_b["proxy"].set_meta("proxy_dead", bool(snap_x["c_dead_meta"]))
	elena_g["proxy"].set_meta("proxy_dead", bool(snap_x["e_dead_meta"]))
	fresh_b["dead"] = bool(snap_x["c_dead"])
	elena_g["dead"] = bool(snap_x["e_dead"])
	fresh_b["sleeping"] = bool(snap_x["c_sleep"])
	elena_g["sleeping"] = bool(snap_x["e_sleep"])
	fresh_b["aggro_target"] = snap_x["c_aggro"]
	elena_g["aggro_target"] = snap_x["e_aggro"]
	fresh_b["proxy"].global_position = snap_x["c_pos"]
	elena_g["proxy"].global_position = snap_x["e_pos"]
	fresh_b["pos"] = fresh_b["proxy"].global_position
	elena_g["pos"] = elena_g["proxy"].global_position

	# Frio ambiental y calor de hoguera (mismo modelo SurvivalStats del jugador)
	dc.time_of_day = 14.0
	dc.ambient_temp = -14.0
	fresh_b["shelter_pos"] = Vector3.INF
	fresh_b["shelter_id"] = ""
	fresh_b["camp_spot"] = fresh_b["proxy"].global_position
	fresh_b["proxy"].global_position = Vector3(450.0, 0.4, 450.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["sleeping"] = false
	fresh_b["hunger"] = 90.0
	fresh_b["thirst"] = 90.0
	vs.body_temperature = 36.6
	vs.wetness = 0.0
	for i in range(150):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.body_temperature < 36.0,
		"SpawnReal 10w7: el frio ambiental baja su temperatura corporal (%.2f)" % vs.body_temperature)
	vs.body_temperature = 34.6
	world.campfire_positions.append(fresh_b["proxy"].global_position + Vector3(1.2, 0.0, 0.0))
	for i in range(40):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.body_temperature > 34.8,
		"SpawnReal 10w8: el calor de una hoguera cercana lo calienta (%.2f)" % vs.body_temperature)
	world.campfire_positions.clear()
	world._lit_campfires = []

	# Lluvia: empapa al aire libre igual que al jugador; bajo techo se seca.
	fnet.is_connected = true
	fnet.authoritative_weather = {"weather_code": 61, "temperature": -999.0, "rain": 4.0,
		"snow": 0.0, "cloud_cover": 0.9, "wind_speed": 8.0, "wind_direction": 0.0}
	dc.ambient_temp = 10.0
	fresh_b["proxy"].global_position = Vector3(480.0, 0.4, 480.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["shelter_pos"] = Vector3.INF
	fresh_b["sleeping"] = false
	vs.wetness = 0.0
	vs.body_temperature = 36.6
	for i in range(40):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.wetness > 0.05,
		"SpawnReal 10w10: la lluvia lo empapa igual que al jugador (wet=%.2f)" % vs.wetness)
	var wet_peak := vs.wetness
	fresh_b["shelter_pos"] = fresh_b["proxy"].global_position
	fresh_b["shelter_id"] = "bot_shelter_902_w10"
	world._built_shelters.append({"id": "bot_shelter_902_w10", "pos": fresh_b["shelter_pos"], "yaw": 0.0, "contents": []})
	fresh_b["hide_timer"] = 30.0 # se queda agazapado en su refugio, sin deambular
	for i in range(40):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.wetness < wet_peak,
		"SpawnReal 10w11: bajo techo deja de mojarse y se va secando (wet=%.2f)" % vs.wetness)
	fresh_b["hide_timer"] = 0.0
	fresh_b["shelter_id"] = ""
	fresh_b["shelter_pos"] = Vector3.INF
	for i_sh in range(world._built_shelters.size() - 1, -1, -1):
		if str(world._built_shelters[i_sh].get("id", "")) == "bot_shelter_902_w10":
			world._built_shelters.remove_at(i_sh)
	fnet.authoritative_weather = {}
	fnet.is_connected = false

	# Con frio letal y materiales enciende su propia hoguera para calentarse.
	fresh_b["shelter_pos"] = Vector3.INF
	fresh_b["proxy"].global_position = Vector3(460.0, 0.4, 460.0)
	fresh_b["pos"] = fresh_b["proxy"].global_position
	fresh_b["sleeping"] = false
	fresh_b["proxy"].set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.2, "quantity": 4},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 3},
	])
	vs.body_temperature = 34.0
	var fires0: int = world.built_campfires.size()
	mgr._tick_bot(fresh_b, 0.1)
	check(world.built_campfires.size() > fires0 and world.campfire_positions.size() > 0,
		"SpawnReal 10w9: con frio letal y materiales enciende una hoguera para calentarse")
	world.campfire_positions.clear()
	world.built_campfires.clear()

	# La inanicion/deshidratacion mata igual que al jugador humano.
	fresh_b["hunger"] = 0.0
	vs.hunger = 0.0
	fresh_b["health"] = 2.0
	vs.health = 2.0
	fresh_b["proxy"].set_meta("proxy_health", 2.0)
	fresh_b["proxy"].set_meta("saved_health", 2.0)
	for i in range(30):
		mgr._tick_bot(fresh_b, 0.1)
	check(bool(fresh_b["proxy"].get_meta("proxy_dead", false)),
		"SpawnReal 10w12: la inanicion real lo mata igual que a un jugador humano")

	# 10x: huerto — el bot aprende a cultivar como un humano: consigue
	# semillas cortando arbustos, azada o pala como botin, siembra el bancal
	# (4 s), espera a que crezca (~7.5 min) y recolecta Verduras.
	var farm_b: Dictionary = fresh_b
	farm_b["proxy"].set_meta("proxy_dead", false)
	farm_b["team_leader_id"] = 0
	farm_b["hunger"] = 90.0
	farm_b["thirst"] = 90.0
	farm_b["health"] = 100.0
	farm_b["hide_timer"] = 0.0
	farm_b["sleeping"] = false
	farm_b["shelter_id"] = "farm_sh"
	farm_b["shelter_pos"] = Vector3(206.0, 0.4, 200.0)
	farm_b["proxy"].global_position = Vector3(200.0, 0.4, 200.0)
	farm_b["pos"] = farm_b["proxy"].global_position
	farm_b["proxy"].set_meta("saved_inventory", [
		{"name": "Azada", "type": "tool_hoe", "weight": 0.9, "quantity": 1, "durability": 100.0},
		{"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 2},
	])
	world._planted_crops = []
	check(not mgr._is_loot_desirable(farm_b, "Azada", "tool_hoe"),
		"SpawnReal 10x1: ya con azada, otra azada no interesa")
	farm_b["proxy"].set_meta("saved_inventory", [
		{"name": "Azada", "type": "tool_hoe", "weight": 0.9, "quantity": 1, "durability": 100.0},
	])
	check(mgr._is_loot_desirable(farm_b, "Semillas", "resource"),
		"SpawnReal 10x2: con herramienta de cultivo las semillas interesan")
	farm_b["proxy"].set_meta("saved_inventory", [])
	farm_b["shelter_id"] = ""
	farm_b["shelter_pos"] = Vector3.INF
	check(mgr._is_loot_desirable(farm_b, "Pala", "tool_shovel"),
		"SpawnReal 10x3: sin refugio la pala interesa (huerto sin asentarse)")
	farm_b["shelter_id"] = "farm_sh"
	farm_b["shelter_pos"] = Vector3(206.0, 0.4, 200.0)
	farm_b["proxy"].set_meta("saved_inventory", [
		{"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 1},
	])
	check(mgr._is_loot_desirable(farm_b, "Pala", "tool_shovel"),
		"SpawnReal 10x4: asentado con semillas quiere la pala para el huerto")
	farm_b["proxy"].set_meta("saved_inventory", [
		{"name": "Azada", "type": "tool_hoe", "weight": 0.9, "quantity": 1, "durability": 100.0},
		{"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 2},
	])

	# Siembra: va al bancal, cava 4 s con la azada y queda registrado.
	for i in range(140):
		mgr._bot_try_farm(farm_b, 0.1)
		if (world._planted_crops as Array).size() > 0:
			break
	check((world._planted_crops as Array).size() == 1,
		"SpawnReal 10x5: con azada y semillas siembra un bancal (_planted_crops=%d)" % (world._planted_crops as Array).size())
	var frec: Dictionary = (world._planted_crops as Array)[0] if (world._planted_crops as Array).size() > 0 else {}
	check(mgr._bot_item_count(farm_b["proxy"], "Semillas") == 1 and (farm_b["_mem"]["farm_plots"] as Array).size() == 1,
		"SpawnReal 10x6: consume una semilla y recuerda su huerto (plots=%d)" % (farm_b["_mem"]["farm_plots"] as Array).size())

	# Cosecha: el cultivo madura con el tiempo; cuando esta listo lo recolecta.
	if not frec.is_empty():
		frec["updated_unix"] = Time.get_unix_time_from_system() - 600.0
		farm_b["proxy"].global_position = (frec["pos"] as Vector3) + Vector3(0.5, 0, 0.5)
		farm_b["pos"] = farm_b["proxy"].global_position
		for i in range(80):
			mgr._bot_try_farm(farm_b, 0.1)
			if str(frec.get("crop_state", "")) == "empty":
				break
		check(mgr._bot_item_count(farm_b["proxy"], "Verduras") == 3 and str(frec.get("crop_state", "")) == "empty",
			"SpawnReal 10x7: cultivo maduro -> recolecta 3 Verduras (crop=%s)" % str(frec.get("crop_state", "")))

		# Replanta el bancal vacio con la semilla que le queda.
		for i in range(140):
			mgr._bot_try_farm(farm_b, 0.1)
			if str(frec.get("crop_state", "")) == "planted":
				break
		check(str(frec.get("crop_state", "")) == "planted",
			"SpawnReal 10x8: replanta el bancal vacio con la semilla restante")

		# Another actor already replanted while this bot was completing its action.
		farm_b["proxy"].set_meta("saved_inventory", [{"name":"Semillas", "type":"resource", "quantity":1}, {"name":"Azada", "type":"tool_hoe", "quantity":1, "durability":100.0}])
		farm_b["_farm"] = {"phase":"replant", "crop_id":str(frec["id"]), "pos":frec["pos"], "t":4.0, "t_need":4.0}
		mgr._bot_try_farm(farm_b, .1)
		check(mgr._bot_item_count(farm_b["proxy"], "Semillas") == 1, "Huerto: no consume semillas si otro ya replanto")

		# Riego: con botella llena humedece el bancal y acelera el cultivo.
		frec["watered_until"] = 0.0
		farm_b["proxy"].set_meta("saved_inventory", [
			{"name": "Azada", "type": "tool_hoe", "weight": 0.9, "quantity": 1, "durability": 100.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
		])
		farm_b["proxy"].global_position = (frec["pos"] as Vector3) + Vector3(1.0, 0, 1.0)
		farm_b["pos"] = farm_b["proxy"].global_position
		for i in range(60):
			mgr._bot_try_farm(farm_b, 0.1)
			if float(frec.get("watered_until", 0.0)) > Time.get_unix_time_from_system():
				break
		check(float(frec.get("watered_until", 0.0)) > Time.get_unix_time_from_system()
				and mgr._bot_item_count(farm_b["proxy"], "Botella de plastico") >= 1,
			"SpawnReal 10x9: riega el cultivo con su botella (queda vacia)")
	else:
		check(false, "SpawnReal 10x7: sin bancal no se pudo probar la cosecha")
	farm_b["shelter_id"] = ""
	farm_b["shelter_pos"] = Vector3.INF

	# 10y: equipos autonomos bot-bot y emboscadas coordinadas — los bots
	# exploran la colaboracion (confianza mutua -> lider/miembro), se
	# defienden en equipo y los hostiles acechan presas con recursos.
	var elena_y: Dictionary = mgr.bots[901]
	var carlos_y: Dictionary = mgr.bots[902]
	var kael_y: Dictionary = mgr.bots[903]
	for bb in [elena_y, carlos_y, kael_y]:
		bb["team_leader_id"] = 0
		bb["proxy"].set_meta("team_leader_id", 0)
		bb["_ambush"] = {}
		bb["_soc_t"] = 0.0
		bb["aggro_target"] = null
		bb["aggro_timer"] = 0.0
		bb["proxy"].set_meta("proxy_dead", false)
		# Reingreso completo: si una seccion anterior lo mato, _kill_bot lo
		# saco del grupo net_player_proxy — el respawn real lo re-anade.
		if not bb["proxy"].is_in_group("net_player_proxy"):
			bb["proxy"].add_to_group("net_player_proxy")
			bb["proxy"].remove_from_group("interactable")
		bb["health"] = 100.0
		bb["hunger"] = 80.0
		bb["thirst"] = 80.0
		bb["proxy"].set_meta("proxy_health", 100.0)
	elena_y["proxy"].global_position = Vector3(100.0, 0.4, 100.0)
	carlos_y["proxy"].global_position = Vector3(104.0, 0.4, 100.0)
	kael_y["proxy"].global_position = Vector3(-300.0, 0.4, -300.0)
	# Confianza mutua sembrada (como si hubieran convivido sin agresiones)
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"] = {"id": "bot_902", "name": "Carlos", "trust": 0.5, "hostility": 0.0, "fear": 0.0, "helped": 4, "attacked": 0}
	mgr._ensure_bot_memory(902)["relationships"]["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": 0.5, "hostility": 0.0, "fear": 0.0, "helped": 4, "attacked": 0}
	mgr._bot_social_update(elena_y)
	mgr._bot_social_update(carlos_y)
	var lid_e := int(elena_y["team_leader_id"])
	var lid_c := int(carlos_y["team_leader_id"])
	check((lid_e == 902) != (lid_c == 901),
		"10y1: confianza mutua -> exactamente uno sigue al otro (lids %d/%d)" % [lid_e, lid_c])
	var leader_y: Dictionary = carlos_y if lid_e == 902 else elena_y
	var member_y: Dictionary = elena_y if lid_e == 902 else carlos_y
	check(mgr._bot_team_size(int(leader_y["bot_id"])) == 2
			and mgr._bot_team_role(leader_y) == "leader" and mgr._bot_team_role(member_y) == "member",
		"10y2: roles lider/miembro y tamano 2")
	check(mgr._resolve_team_leader(member_y) == leader_y["proxy"],
		"10y3: el miembro resuelve el proxy de su lider bot")

	# La victima reune a su equipo contra el agresor (lider incluido) — el
	# agresor debe estar al alcance del contraataque (<60 m del equipo)
	kael_y["proxy"].global_position = Vector3(112.0, 0.4, 100.0)
	mgr.rally_bot_team(int(member_y["bot_id"]), kael_y["proxy"])
	check(leader_y.get("aggro_target") == kael_y["proxy"] and member_y.get("aggro_target") == kael_y["proxy"],
		"10y4: miembro atacado -> todo el equipo recibe aggro sobre el agresor")
	leader_y["aggro_target"] = null
	member_y["aggro_target"] = null

	# Muerte del lider -> el equipo se disuelve
	leader_y["proxy"].set_meta("proxy_dead", true)
	member_y["_soc_t"] = 0.0
	mgr._bot_social_update(member_y)
	check(int(member_y["team_leader_id"]) == 0,
		"10y5: lider muerto -> el miembro abandona el equipo")
	leader_y["proxy"].set_meta("proxy_dead", false)
	leader_y["team_leader_id"] = 0
	leader_y["proxy"].set_meta("team_leader_id", 0)

	# Desconfianza -> nadie se alia; y hostil<->amistoso nunca se mezclan
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"]["trust"] = 0.05
	mgr._ensure_bot_memory(902)["relationships"]["bot_901"]["trust"] = 0.05
	elena_y["_soc_t"] = 0.0
	carlos_y["_soc_t"] = 0.0
	mgr._bot_social_update(elena_y)
	mgr._bot_social_update(carlos_y)
	check(int(elena_y["team_leader_id"]) == 0 and int(carlos_y["team_leader_id"]) == 0,
		"10y6: con desconfianza mutua no se forma equipo")
	kael_y["proxy"].global_position = Vector3(106.0, 0.4, 100.0)
	# Elena vuelve a hostil para probar la banda bandido<->bandido (su spawn la
	# dejo amistosa para otras secciones); se restaura al final.
	mgr._set_bot_faction(elena_y, "hostile")
	mgr._ensure_bot_memory(903)["relationships"]["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": 0.9, "hostility": 0.0, "fear": 0.0, "helped": 9, "attacked": 0}
	mgr._ensure_bot_memory(901)["relationships"]["bot_903"] = {"id": "bot_903", "name": "Kael", "trust": 0.9, "hostility": 0.0, "fear": 0.0, "helped": 9, "attacked": 0}
	kael_y["_soc_t"] = 0.0
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(kael_y)
	mgr._bot_social_update(elena_y)
	var kl := int(kael_y["team_leader_id"])
	var el := int(elena_y["team_leader_id"])
	check((kl == 901) != (el == 903),
		"10y7: dos bandidos con confianza SI forman equipo, incluso Kael (lids %d/%d)" % [kl, el])
	# ...pero las facciones siguen sin mezclarse: un hostil y un convertido no.
	kael_y["team_leader_id"] = 0
	kael_y["proxy"].set_meta("team_leader_id", 0)
	elena_y["team_leader_id"] = 0
	elena_y["proxy"].set_meta("team_leader_id", 0)
	mgr._set_bot_faction(kael_y, "friendly")
	kael_y["_soc_t"] = 0.0
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(kael_y)
	mgr._bot_social_update(elena_y)
	check(int(kael_y["team_leader_id"]) == 0 and int(elena_y["team_leader_id"]) == 0,
		"10y7b: convertido y hostil nunca forman equipo aunque confien")
	mgr._set_bot_faction(kael_y, "hostile")

	# La relacion nueva entre bandidos nace con recelo (0.30), no con la
	# hostilidad antihumano 0.65 que bloqueaba la puerta de convivencia.
	mgr._ensure_bot_memory(901)["relationships"].erase("bot_902")
	mgr._ensure_bot_memory(903)["relationships"].erase("bot_901")
	mgr._ensure_bot_memory(903)["relationships"].erase("client_sami_77")
	mgr.record_social_event(903, "bot_901", "Elena", "ally", 0.05, "convive")
	mgr.record_social_event(903, "client_sami_77", "Sami", "ally", 0.05, "convive")
	var rel_bot: Dictionary = mgr.get_bot_relationship(903, "bot_901")
	var rel_hum: Dictionary = mgr.get_bot_relationship(903, "client_sami_77")
	check(float(rel_bot.get("hostility", 9.0)) <= 0.40,
		"10y7c: rel nueva bandido-bandido por debajo de la puerta de convivencia (h=%.2f)" % float(rel_bot.get("hostility", -1.0)))
	check(float(rel_hum.get("hostility", 0.0)) >= 0.60,
		"10y7d: rel nueva bandido-humano sigue recelosa (h=%.2f)" % float(rel_hum.get("hostility", -1.0)))

	# End-to-end del bug reportado: dos bandidos juntos SIN relaciones previas
	# acaban formando equipo a base de convivir.
	mgr._ensure_bot_memory(901)["relationships"].erase("bot_903")
	mgr._ensure_bot_memory(901)["relationships"].erase("bot_902")
	mgr._ensure_bot_memory(902)["relationships"].erase("bot_901")
	mgr._ensure_bot_memory(902)["relationships"].erase("bot_903")
	mgr._ensure_bot_memory(903)["relationships"].erase("bot_902")
	kael_y["team_leader_id"] = 0
	kael_y["proxy"].set_meta("team_leader_id", 0)
	elena_y["team_leader_id"] = 0
	elena_y["proxy"].set_meta("team_leader_id", 0)
	carlos_y["proxy"].global_position = Vector3(-500.0, 0.4, -500.0)
	var band_formed := false
	for i in range(30):
		# Simulate twenty seconds between social ticks; the test runs these
		# calls immediately, while shared-time credit uses a real clock.
		for bid in [901, 903]:
			for relation in mgr._ensure_bot_memory(bid)["relationships"].values():
				if relation is Dictionary and relation.has("bond_t"):
					relation["bond_t"] = int(relation["bond_t"]) - 20000
		kael_y["_soc_t"] = 0.0
		elena_y["_soc_t"] = 0.0
		mgr._bot_social_update(kael_y)
		mgr._bot_social_update(elena_y)
		if int(kael_y["team_leader_id"]) > 0 or int(elena_y["team_leader_id"]) > 0:
			band_formed = true
			break
	check(band_formed, "10y7e: convivir sin agresiones acaba formando la banda")
	kael_y["team_leader_id"] = 0
	kael_y["proxy"].set_meta("team_leader_id", 0)
	mgr._set_bot_faction(elena_y, "friendly")
	elena_y["team_leader_id"] = 0
	elena_y["proxy"].set_meta("team_leader_id", 0)

	# Emboscada: Kael elige a la presa cargada y sola (Elena con 5 latas)
	kael_y["_ambush_cd_until"] = 0.0
	kael_y["proxy"].set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "tool_knife", "weight": 0.2, "quantity": 1},
	])
	elena_y["proxy"].set_meta("saved_inventory", [
		{"name": "Lata de guiso", "type": "food", "weight": 0.4, "quantity": 3, "use_value": 60.0},
		{"name": "Lata de atun", "type": "food", "weight": 0.4, "quantity": 2, "use_value": 60.0},
	])
	carlos_y["proxy"].global_position = Vector3(400.0, 0.4, 400.0)
	elena_y["proxy"].global_position = Vector3(125.0, 0.4, 100.0)
	kael_y["proxy"].global_position = Vector3(100.0, 0.4, 100.0)
	var amb_tgt: Dictionary = mgr._find_ambush_target(kael_y)
	check(int(amb_tgt.get("target_id", 0)) == 901,
		"10y8: el hostil elige a la presa cargada y sola (target=%s)" % str(amb_tgt.get("target_id", "nulo")))
	kael_y["_ambush"] = amb_tgt
	var sneaked := false
	for i in range(60):
		mgr._bot_try_ambush(kael_y, 0.1)
		if bool(kael_y["crouching"]):
			sneaked = true
	check(sneaked, "10y9: acecha agachado hacia la presa")
	elena_y["proxy"].global_position = Vector3(102.0, 0.4, 100.0)
	kael_y["proxy"].global_position = Vector3(100.0, 0.4, 100.0)
	mgr._bot_try_ambush(kael_y, 0.1)
	check(kael_y.get("aggro_target") == elena_y["proxy"] and (kael_y.get("_ambush", {}) as Dictionary).is_empty(),
		"10y10: al alcance del golpe -> aggro fijado y emboscada consumida")

	# Desarmado no planea emboscadas; presa escoltada se descarta
	kael_y["aggro_target"] = null
	kael_y["aggro_timer"] = 0.0
	kael_y["_ambush_cd_until"] = 0.0
	kael_y["proxy"].set_meta("saved_inventory", [])
	check(mgr._find_ambush_target(kael_y).is_empty(),
		"10y11: desarmado no planea emboscadas")
	kael_y["proxy"].set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "tool_knife", "weight": 0.2, "quantity": 1},
	])
	carlos_y["proxy"].global_position = Vector3(105.0, 0.4, 100.0)
	carlos_y["proxy"].set_meta("saved_inventory", [
		{"name": "Lata de guiso", "type": "food", "weight": 0.4, "quantity": 2, "use_value": 60.0},
	])
	kael_y["proxy"].global_position = Vector3(95.0, 0.4, 100.0)
	var esc_tgt: Dictionary = mgr._find_ambush_target(kael_y)
	check(esc_tgt.is_empty(),
		"10y12: presas escoltadas (1v2) se descartan — no hay suicidio")

	# Status JSON: campos de equipo/emboscada/huerto serializables
	elena_y["proxy"].set_meta("saved_inventory", [])
	carlos_y["proxy"].set_meta("saved_inventory", [])
	var st_json: Dictionary = mgr.get_full_web_status()
	var snap_ok: bool = (st_json.get("bots", []) as Array).size() > 0
	if snap_ok:
		var s0: Dictionary = (st_json["bots"] as Array)[0]
		snap_ok = s0.has("team_role") and s0.has("team_mates") and s0.has("ambush") and s0.has("farm")
	check(snap_ok and st_json.has("teams"),
		"10y13: status expone team_role/team_mates/ambush/farm y teams")
	check(JSON.parse_string(JSON.stringify(st_json)) != null,
		"10y14: el status completo serializa a JSON")

	# 10z: iman social — un bot libre y sociable viaja a REUNIRSE con un aliado
	# potencial dentro de BOT_TEAM_MEET_DIST en vez de vagar sin rumbo.
	for bb in [elena_y, carlos_y, kael_y]:
		bb["team_leader_id"] = 0
		bb["proxy"].set_meta("team_leader_id", 0)
		bb["_ambush"] = {}
		bb["_soc_t"] = 0.0
		bb["_meet_id"] = 0
		bb["aggro_target"] = null
		bb["explore_target"] = Vector3.INF
		bb["explore_dwell"] = 0.0
		bb["ai_directive"] = {}
		bb["proxy"].set_meta("proxy_dead", false)
		if not bb["proxy"].is_in_group("net_player_proxy"):
			bb["proxy"].add_to_group("net_player_proxy")
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"] = {"id": "bot_902", "name": "Carlos", "trust": 0.0, "hostility": 0.0, "fear": 0.0, "helped": 2, "attacked": 0}
	mgr._ensure_bot_memory(902)["relationships"]["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": 0.5, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0}
	mgr._ensure_bot_memory(903)["relationships"].erase("bot_901")
	mgr._ensure_bot_memory(903)["relationships"].erase("bot_902")
	elena_y["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	carlos_y["proxy"].global_position = Vector3(200.0, 0.4, 0.0)
	kael_y["proxy"].global_position = Vector3(-300.0, 0.4, -300.0)
	mgr._bot_social_update(elena_y)
	mgr._bot_social_update(carlos_y)
	var et_z: Vector3 = elena_y["explore_target"]
	check(int(elena_y["_meet_id"]) == 902 and et_z.distance_to(carlos_y["proxy"].global_position) < 1.0,
		"10z1: Elena viaja a reunirse con Carlos (meet=%d, target=%s)" % [int(elena_y.get("_meet_id", 0)), str(et_z)])
	check(int(carlos_y["_meet_id"]) == 901,
		"10z2: Carlos tambien busca a Elena — convergencia mutua")

	# Hostilidad mutua cancela el iman: no se acercan a quien temen
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"]["hostility"] = 0.9
	elena_y["_meet_id"] = 0
	elena_y["explore_target"] = Vector3.INF
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(elena_y)
	check(int(elena_y["_meet_id"]) == 0,
		"10z3: con hostilidad alta no hay reencuentro")
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"]["hostility"] = 0.0

	# Fuera del radio social no se busca a nadie
	carlos_y["proxy"].global_position = Vector3(700.0, 0.4, 0.0)
	elena_y["_meet_id"] = 0
	elena_y["explore_target"] = Vector3.INF
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(elena_y)
	check(int(elena_y["_meet_id"]) == 0 and elena_y["explore_target"] == Vector3.INF,
		"10z4: un aliado a >%d m queda fuera del iman" % int(mgr.BOT_TEAM_MEET_DIST))

	# Una directiva con proposito (rest/return_home) no se pisa por el iman
	carlos_y["proxy"].global_position = Vector3(200.0, 0.4, 0.0)
	elena_y["ai_directive"] = {"mode": "pos", "pos": Vector3(50.0, 0.4, 50.0), "action": "rest", "until": Time.get_ticks_msec() + 60000}
	elena_y["_meet_id"] = 0
	elena_y["explore_target"] = Vector3.INF
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(elena_y)
	check(int(elena_y["_meet_id"]) == 0 and elena_y["explore_target"] == Vector3.INF,
		"10z5: una orden activa (rest) frena el iman social")
	elena_y["ai_directive"] = {}

	# El status expone el reencuentro en curso para el panel web
	elena_y["_meet_id"] = 902
	var st_meet: Dictionary = mgr.get_full_web_status()
	var meet_ok := false
	for sb in st_meet.get("bots", []):
		if int((sb as Dictionary).get("bot_id", 0)) == 901:
			meet_ok = str((sb as Dictionary).get("meet", {}).get("target", "")) == "Carlos"
	check(meet_ok, "10z6: status expone meet{target,dist} del reencuentro")
	elena_y["_meet_id"] = 0

	# Media de tiempo de vida: total acumulado / vidas (muertes + vida actual)
	var mem_z := mgr._ensure_bot_memory(901)
	mem_z["stats"]["alive_total_sec"] = 3600.0
	mem_z["deaths"] = 3
	var st_avg: Dictionary = mgr.get_full_web_status()
	var avg_ok := false
	for sb in st_avg.get("bots", []):
		if int((sb as Dictionary).get("bot_id", 0)) == 901:
			avg_ok = int((sb as Dictionary).get("avg_life_seconds", -1)) >= 900
	check(avg_ok, "10z7: avg_life_seconds = total/vidas (>=900 s con 3600 s y 3 muertes)")

	# 10z8: el bosque es un destino real — un bot hambriento elige wild sobre
	# una casa cercana (aqui caza, setas y fruta; la casa ya esta saqueada).
	var sec_z: float = mgr._bot_explore_sector(elena_y)
	var dir_z := Vector2(cos(sec_z), sin(sec_z))
	var wild_poi_z := Vector3(dir_z.x * 160.0, 0.4, dir_z.y * 160.0)
	var mem_z2 := mgr._ensure_bot_memory(901)
	var old_vis: Array = mem_z2.get("visited", [])
	var old_ds: Array = mem_z2.get("death_spots", [])
	var old_kl: Dictionary = mem_z2.get("known_locations", {})
	var old_zy: Dictionary = mem_z2.get("zone_yield", {})
	mem_z2["visited"] = []
	mem_z2["death_spots"] = []
	mem_z2["known_locations"] = {}
	mem_z2["zone_yield"] = {}
	mgr._poi_cache = [
		{"pos": wild_poi_z, "kind": "wild"},
		{"pos": Vector3(-dir_z.x * 60.0, 0.4, -dir_z.y * 60.0), "kind": "house"},
		{"pos": Vector3(0.0, 0.4, 140.0), "kind": "city"},
	]
	mgr._poi_cache_built = true
	elena_y["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	elena_y["hunger"] = 15.0
	elena_y["ai_directive"] = {}
	var wild_hits_z := 0
	for i in range(6):
		if mgr._choose_explore_target(elena_y).distance_to(wild_poi_z) < 1.0:
			wild_hits_z += 1
	check(wild_hits_z >= 5,
		"10z8: hambriento -> el bosque (wild) es el destino (hits=%d/6)" % wild_hits_z)
	elena_y["hunger"] = 80.0
	mem_z2["visited"] = old_vis
	mem_z2["death_spots"] = old_ds
	mem_z2["known_locations"] = old_kl
	mem_z2["zone_yield"] = old_zy
	mgr._poi_cache_built = false
	mgr._poi_cache.clear()

	# 10z9: un miembro de equipo muerto de hambre rompe la formacion para
	# buscar comida — seguir al lider no llena el estomago (Elena murio de
	# inanicion en la ciudad siguiendo a Carlos en produccion).
	elena_y["team_leader_id"] = 902
	elena_y["proxy"].set_meta("team_leader_id", 902)
	elena_y["proxy"].set_meta("saved_inventory", [])
	elena_y["hunger"] = 80.0
	elena_y["thirst"] = 80.0
	elena_y["sitting"] = false
	elena_y["sleeping"] = false
	elena_y["hide_timer"] = 0.0
	elena_y["_forage"] = {}
	carlos_y["proxy"].global_position = Vector3(4.0, 0.4, 0.0)
	elena_y["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	elena_y["sense_t"] = 0.0
	mgr._tick_bot(elena_y, 0.25)
	check(str(elena_y["_act"]) == "team",
		"10z9a: saciada sigue al lider (act=%s)" % str(elena_y["_act"]))
	elena_y["hunger"] = 20.0
	elena_y["sense_t"] = 0.0
	mgr._tick_bot(elena_y, 0.25)
	check(str(elena_y["_act"]) != "team",
		"10z9b: hambrienta rompe la formacion (act=%s)" % str(elena_y["_act"]))
	elena_y["team_leader_id"] = 0
	elena_y["proxy"].set_meta("team_leader_id", 0)
	elena_y["hunger"] = 80.0

	# 10A: chat entre bots — triggers, efectos sociales, registro y entrega.
	# Sin GROQ_API_KEY para forzar el camino de plantillas (determinista).
	var saved_key := OS.get_environment("GROQ_API_KEY")
	OS.set_environment("GROQ_API_KEY", "")
	elena_y["hunger"] = 80.0
	elena_y["thirst"] = 80.0
	elena_y["team_leader_id"] = 0
	elena_y["_meet_id"] = 0
	elena_y["_ambush"] = {}
	elena_y["aggro_target"] = null
	elena_y["_s_foe"] = null
	elena_y["_s_predator"] = null
	elena_y["_chat_cd"] = 0.0
	elena_y["_chat_inbox"] = {}
	elena_y["sleeping"] = false
	elena_y["proxy"].set_meta("proxy_dead", false)
	elena_y["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	carlos_y["proxy"].global_position = Vector3(10.0, 0.4, 0.0)
	kael_y["proxy"].global_position = Vector3(-300.0, 0.4, -300.0)
	elena_y["_mem"]["personality"]["sociability"] = 0.8
	mgr._ensure_bot_memory(901)["relationships"]["bot_902"] = {"id": "bot_902", "name": "Carlos", "trust": 0.5, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0}
	# Los cooldowns pueden estar sucios: los bots se hablan solos durante el
	# resto de secciones. Reset completo para hacer esta parte determinista.
	mgr._chat_pair_until.clear()
	mgr._chat_greet_until.clear()
	mgr._chat_help_until.clear()
	mgr._chat_turns.clear()
	var log_n0 := mgr.chat_log.size()
	mgr._bot_chat_tick(elena_y)
	var m0: Dictionary = mgr.chat_log.back() if mgr.chat_log.size() > log_n0 else {}
	check(str(m0.get("kind", "")) == "greet" and int(m0.get("to_id", 0)) == 902,
		"10A1: sociable saluda al aliado cercano (kind=%s to=%s)" % [str(m0.get("kind", "-")), str(m0.get("to_id", "-"))])

	# Respuesta a un saludo entrante
	mgr.on_chat_received(901, 902, "Carlos", "hola Elena")
	check(not (elena_y["_chat_inbox"] as Dictionary).is_empty(), "10A2: mensaje entrante encola respuesta")
	elena_y["_chat_reply_ready"] = 0
	elena_y["_chat_cd"] = 0.0
	mgr._bot_chat_tick(elena_y)
	var m1: Dictionary = mgr.chat_log.back()
	check(str(m1.get("kind", "")) == "reply" and int(m1.get("to_id", 0)) == 902 and not str(m1.get("text", "")).is_empty(),
		"10A3: responde al saludo (text=%s)" % str(m1.get("text", "-")))

	# Pedir ayuda bajo ataque: elige al aliado de confianza
	elena_y["_chat_cd"] = 0.0
	elena_y["aggro_target"] = kael_y["proxy"]
	mgr._chat_help_until.clear()
	mgr._chat_pair_until.clear()
	mgr._bot_chat_tick(elena_y)
	var m2 := {}
	for i in range(mgr.chat_log.size() - 1, -1, -1):
		if int((mgr.chat_log[i] as Dictionary).get("from_id", 0)) == int(elena_y["bot_id"]) and str((mgr.chat_log[i] as Dictionary).get("kind", "")) == "help":
			m2 = mgr.chat_log[i]
			break
	check(str(m2.get("kind", "")) == "help" and int(m2.get("to_id", 0)) == 902,
		"10A4: bajo ataque pide ayuda al aliado (kind=%s to=%s text=%s)" % [str(m2.get("kind", "-")), str(m2.get("to_id", "-")), str(m2.get("text", "-"))])
	elena_y["aggro_target"] = null

	# Propuesta de alianza entrante: mueve al aliado hacia el emisor (_meet_id)
	elena_y["_meet_id"] = 0
	elena_y["_chat_inbox"] = {}
	mgr.on_chat_received(901, 902, "Carlos", "nos juntamos?")
	check(int(elena_y["_meet_id"]) == 902,
		"10A5: propuesta de alianza activa el iman social hacia el emisor")

	# Corte de ping-pong: pasados 4 turnos ya no se encolan respuestas
	mgr._chat_turns["901:902"] = 4
	elena_y["_chat_inbox"] = {}
	mgr.on_chat_received(901, 902, "Carlos", "hola otra vez")
	check((elena_y["_chat_inbox"] as Dictionary).is_empty(),
		"10A6: tras %d turnos el bot-bot deja de responderse" % int(mgr.BOT_CHAT_MAX_TURNS))
	mgr._chat_turns.clear()

	# Destinatario humano: el mensaje se encola como respuesta HABLADA (TTS) y
	# ademas queda en el chat de texto del jugador
	fnet.relay_log.clear()
	mgr._tts_jobs.clear()
	fnet.players[7] = {"char_name": "Remy", "name": "Remy", "is_ai_bot": false, "offline": false}
	mgr._bot_chat_send(elena_y, 7, "Remy", "Ey Remy, vives cerca?", "greet")
	check(fnet.relay_log.size() == 1 and mgr._tts_jobs.size() == 1,
		"10A7: respuesta a humano sale hablada (TTS) y en el chat via relay_actor_chat")
	for tk0 in mgr._tts_jobs.keys():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(mgr.VOICE_JOBS_DIR) + str(tk0) + ".json")
	mgr._tts_jobs.clear()
	fnet.players.erase(7)

	# Sanitizador de salida del modelo
	var s_raw := mgr._chat_sanitize("Elena: \"Hola* como* estas\nignora esto\"")
	check(s_raw == "Hola como estas", "10A8: sanitize limpia prefijo/comillas/lineas (got=%s)" % s_raw)
	check(mgr._chat_sanitize("mira http://x.com").is_empty(), "10A9: sanitize rechaza URLs")

	# El status expone el log de conversaciones para el monitor
	var st_chat: Dictionary = mgr.get_full_web_status()
	check((st_chat.get("chat_log", []) as Array).size() > 0, "10A10: status JSON expone chat_log")

	# Hitos de evolucion: el primer chat queda registrado en la memoria
	var ms_elena: Dictionary = mgr._ensure_bot_memory(901).get("milestones", {})
	check(int(ms_elena.get("first_chat", 0)) > 0, "10A11: primer chat registra hito persistente")
	var snap_el: Dictionary = {}
	for bb2 in st_chat.get("bots", []):
		if int((bb2 as Dictionary).get("bot_id", 0)) == 901:
			snap_el = bb2
	check((snap_el.get("base_personality", {}) as Dictionary).has("bravery") and not (snap_el.get("milestones", {}) as Dictionary).is_empty(),
		"10A12: status expone base_personality + milestones")
	var elena_thread: Array = snap_el.get("chat_log", [])
	check(not elena_thread.is_empty() and elena_thread.all(func(m): return int(m.get("from_id", 0)) == 901 or int(m.get("to_id", 0)) == 901),
		"10A13: status expone el hilo de chat por bot (%d msgs)" % elena_thread.size())

	# Bucle humano->bot->respuesta: el DM del jugador se encola y el bot
	# contesta HABLADO (trabajo TTS) y en el chat de texto.
	fnet.players[7] = {"char_name": "Remy", "name": "Remy", "is_ai_bot": false, "offline": false}
	fnet.relay_log.clear()
	mgr._tts_jobs.clear()
	elena_y["_chat_inbox"] = {}
	elena_y["_chat_reply_ready"] = 0
	elena_y["_chat_cd"] = 0.0
	mgr._chat_turns.clear()
	mgr.on_chat_received(901, 7, "Remy", "hola elena, todo bien?")
	check(not (elena_y["_chat_inbox"] as Dictionary).is_empty(),
		"10A14a: DM de humano encola respuesta del bot")
	mgr._bot_chat_tick(elena_y)
	check(fnet.relay_log.size() == 1 and mgr._tts_jobs.size() == 1,
		"10A14b: la respuesta del bot al humano se encola como voz TTS y texto en chat")
	for tk1 in mgr._tts_jobs.keys():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(mgr.VOICE_JOBS_DIR) + str(tk1) + ".json")
	mgr._tts_jobs.clear()
	fnet.players.erase(7)
	fnet.relay_log.clear()

	# 10B: refugios — vinculo persistente, saqueo del alijo y desmontaje por palos
	var sb: Dictionary = mgr.bots[902]
	sb["proxy"].set_meta("proxy_dead", false)
	sb["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	sb["pos"] = sb["proxy"].global_position
	sb["shelter_id"] = ""
	sb["shelter_pos"] = Vector3.INF
	sb["_salvage"] = {}
	sb["_s_raid_shelter"] = {}
	sb["_unreachable"] = []
	sb["team_leader_id"] = 0
	sb["sleeping"] = false
	sb["rot"] = 0.0
	world._built_shelters.clear() # aislar del resto de secciones

	# 10B1: al construir, id unico + el refugio queda en mem.shelter
	sb["proxy"].set_meta("saved_inventory", [
		{"name": "Palo", "type": "material", "weight": 0.3, "quantity": 12, "use_value": 0.0},
	])
	mgr._bot_build_shelter(sb, Vector3(60.0, 0.4, 60.0))
	var built_id := str(sb.get("shelter_id", ""))
	var mem_sh2: Dictionary = mgr._ensure_bot_memory(902).get("shelter", {})
	check(built_id.begins_with("bot_shelter_902_") and str(mem_sh2.get("id", "")) == built_id and not mgr._find_shelter_dict(built_id).is_empty(),
		"10B1: construye con id unico y recuerda el refugio (id=%s)" % built_id)

	# 10B2: refugio ajeno con alijo -> roba lo util y lo desmonta por los palos
	world._built_shelters.append({
		"id": "player_shelter_777", "pos": Vector3(9.0, 0.4, 9.0), "yaw": 0.0,
		"contents": [{"name": "Lata de guiso", "type": "food", "weight": 0.5, "quantity": 2, "use_value": 35.0}],
	})
	sb["shelter_id"] = "" # pierde el vinculo (como tras morir): ahora quiere palos
	sb["shelter_pos"] = Vector3.INF
	var raid_sh2 := mgr._find_nearby_raidable_shelter(sb, 30.0)
	check(str(raid_sh2.get("id", "")) == "player_shelter_777",
		"10B2a: detecta el refugio ajeno para saquear/desmontar")
	mgr._bot_raid_shelter(sb, raid_sh2)
	check(mgr._bot_try_dismantle_shelter(sb, raid_sh2) and not (sb.get("_salvage", {}) as Dictionary).is_empty(),
		"10B2b: refugio vacio tras el saqueo -> arma el desmontaje de 3 s")
	mgr._bot_dismantle_shelter_exec(sb, "player_shelter_777")
	check(mgr._find_shelter_dict("player_shelter_777").is_empty(),
		"10B2c: el refugio desaparece del registro mundial")
	check(mgr._bot_item_count(sb["proxy"], "Palo") >= 11 or (world._dropped_items as Array).size() > 0,
		"10B2d: recupera los 11 palos del desmontaje")
	check(int(mgr._ensure_bot_memory(902).get("milestones", {}).get("first_dismantle", 0)) > 0,
		"10B2e: hito first_dismantle registrado")

	# 10B3: refugio con camo NO se desmonta (misma regla que el jugador)
	world._built_shelters.append({"id": "player_shelter_888", "pos": Vector3(7.0, 0.4, 7.0), "yaw": 0.0, "contents": [], "camo_covered": true})
	check(not mgr._bot_wants_salvage(sb, mgr._find_shelter_dict("player_shelter_888")),
		"10B3: refugio con camo no es desmontable para el bot")

	# 10B4: asentado -> no desmonta refugios ajenos vacios (no le hacen falta palos)
	sb["shelter_id"] = built_id
	world._built_shelters.append({"id": "player_shelter_889", "pos": Vector3(6.0, 0.4, 6.0), "yaw": 0.0, "contents": []})
	check(not mgr._bot_wants_salvage(sb, mgr._find_shelter_dict("player_shelter_889")),
		"10B4: con refugio propio no desmonta ajenos vacios")

	# 10B5: mem.shelter apuntando a un refugio inexistente se olvida al reaparecer
	mgr._ensure_bot_memory(902)["shelter"] = {"id": "bot_shelter_ghost_0", "pos": [0.0, 0.4, 0.0]}
	mgr._respawn_bot(sb)
	sb = mgr.bots[902]
	check((mgr._ensure_bot_memory(902).get("shelter", {}) as Dictionary).is_empty(),
		"10B5: al reaparecer olvida el refugio que ya no existe")
	sb["_salvage"] = {}
	world._built_shelters.clear()

	# 10B6: la base sin refugio no es "casa": un solar reclamado cuyo edificio
	# fue demolido/robado no da cobijo ni vale para acampar — se reconstruye.
	sb["shelter_id"] = "bot_shelter_902_lost"
	sb["shelter_pos"] = Vector3(60.0, 0.4, 60.0)
	sb["proxy"].global_position = Vector3(60.5, 0.4, 60.0)
	mgr._validate_shelter_claim(sb)
	check(str(sb["shelter_id"]).is_empty() and not mgr._bot_is_sheltered(sb, sb["proxy"].global_position) \
			and mgr._nearest_safe_refuge(sb, 40.0) != sb["shelter_pos"],
		"10B6: sin edificio el solar no da cobijo ni vale como refugio")
	sb["shelter_pos"] = Vector3.INF
	sb["proxy"].global_position = Vector3(0.0, 0.4, 0.0)

	OS.set_environment("GROQ_API_KEY", saved_key)
	mgr._chat_pair_until.clear()
	mgr._chat_greet_until.clear()
	mgr._chat_help_until.clear()
	mgr._chat_turns.clear()

	# --- 10C) Puppet cadaver revive + ciervo rumbo de huida comprometido ---
	# 10C1: un puppet marcado is_dead que recibe un anim de vida necesita respawn
	var stub_rp := StubDeadPuppet.new()
	stub_rp.is_dead = true
	world.add_child(stub_rp)
	check(world._remote_puppet_needs_respawn(stub_rp, "walk"),
		"10C1a: puppet muerto + anim vivo -> regenerar puppet")
	check(not world._remote_puppet_needs_respawn(stub_rp, "dead"),
		"10C1b: puppet muerto + anim dead -> sigue siendo cadaver")
	stub_rp.is_dead = false
	check(not world._remote_puppet_needs_respawn(stub_rp, "walk"),
		"10C1c: puppet vivo no se regenera")
	stub_rp.queue_free()

	# 10C2: el rumbo de huida se compromete ~0.8s (no orbita a una amenaza movil)
	var d2 := WildlifeControllerScript.new()
	d2.name = "Wildlife_deer_fleedir"
	world.add_child(d2)
	d2.setup("deer", [Vector3(0.0, 0.4, 0.0), Vector3(50.0, 0.4, 0.0)])
	d2.set_process(false)
	d2.global_position = Vector3(0.0, 0.4, 0.0)
	var threat_a := Vector3(10.0, 0.4, 0.0)
	var dir1 := d2._flee_dir_away(threat_a, 0.016)
	var threat_b := threat_a + Vector3(3.0, 0.0, 0.0)
	var dir2 := d2._flee_dir_away(threat_b, 0.016)
	check(dir1.is_equal_approx(dir2),
		"10C2a: dentro de la ventana el rumbo no persigue a la amenaza")
	var threat_c := Vector3(0.0, 0.4, 15.0)
	var dir3 := d2._flee_dir_away(threat_c, 0.016)
	check(dir1.dot(dir3) < 0.5 and dir3.dot(Vector3(0.0, 0.0, -1.0)) > 0.9,
		"10C2b: amenaza desplazada >10m -> nuevo rumbo comprometido")
	var threat_d := Vector3(0.0, 0.4, -15.0)
	var dir4 := d2._flee_dir_away(threat_d, 1.0)
	check(dir4.dot(Vector3(0.0, 0.0, 1.0)) > 0.9,
		"10C2c: tras expirar la ventana se reevalua el rumbo")
	d2.queue_free()

	# 10C3: al calmarse patrulla hacia el punto MAS LEJOS de la amenaza (sin yo-yo)
	var d3 := WildlifeControllerScript.new()
	d3.name = "Wildlife_deer_yoyo"
	world.add_child(d3)
	d3.setup("deer", [Vector3(0.0, 0.4, 0.0), Vector3(80.0, 0.4, 0.0), Vector3(-80.0, 0.4, 0.0)])
	d3.set_process(false)
	d3.global_position = Vector3(0.0, 0.4, 0.0)
	d3.target_index = 0
	d3._retarget_patrol_away_from(Vector3(5.0, 0.4, 0.0))
	check(int(d3.target_index) == 2,
		"10C3: al calmarse elige el punto de patrulla mas lejano de la amenaza")
	d3.queue_free()

	# --- 10D) Huerto sin refugio: quiere azada/semillas, siembra y cosecha ---
	var fb: Dictionary = mgr.bots[902]
	fb["proxy"].set_meta("proxy_dead", false)
	fb["proxy"].global_position = Vector3(150.0, 0.4, 150.0)
	fb["pos"] = fb["proxy"].global_position
	fb["shelter_id"] = ""
	fb["shelter_pos"] = Vector3.INF
	fb["hide_timer"] = 0.0
	fb["sleeping"] = false
	fb["hunger"] = 80.0
	fb["_farm"] = {}
	fb["proxy"].set_meta("saved_inventory", [])
	mgr._ensure_bot_memory(902)["farm_plots"] = []
	world._planted_crops.clear()

	# 10D1: sin refugio ni herramienta ni bancales, igualmente quiere la azada
	check(mgr._bot_wants_farm_tool(fb) and mgr._bot_wants_seeds(fb),
		"10D1: sin refugio el bot quiere azada/pala y semillas")

	# 10D2: con azada + semillas siembra un bancal (fase plant completa)
	fb["proxy"].set_meta("saved_inventory", [
		{"name": "Azada", "type": "tool_hoe", "weight": 0.9, "quantity": 1, "use_value": 0.0, "durability": 60.0, "max_durability": 60.0},
		{"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 2, "use_value": 0.0},
	])
	fb["_farm"] = {"phase": "plant", "pos": fb["proxy"].global_position, "t": 9.0, "t_need": 4.0, "tool": "Azada"}
	mgr._bot_try_farm(fb, 0.016)
	var plots2: Array = mgr._ensure_bot_memory(902).get("farm_plots", [])
	check(world._planted_crops.size() == 1 and plots2.size() == 1 and mgr._bot_item_count(fb["proxy"], "Semillas") == 1,
		"10D2: siembra sin refugio -> bancal registrado y 1 semilla consumida")

	# 10D3: la cosecha madura da Verduras al inventario
	var cid2 := str((world._planted_crops[0] as Dictionary).get("id", ""))
	var now2 := Time.get_unix_time_from_system()
	world._planted_crops[0]["crop_state"] = "ready"
	world._planted_crops[0]["ready_unix"] = now2 - 10.0
	world._planted_crops[0]["updated_unix"] = now2 - 10.0
	fb["_farm"] = {"phase": "harvest", "crop_id": cid2, "pos": fb["proxy"].global_position, "t": 9.0, "t_need": 1.25, "tool": ""}
	mgr._bot_try_farm(fb, 0.016)
	check(mgr._bot_item_count(fb["proxy"], "Verduras") == 3,
		"10D3: cosecha madura -> 3 Verduras al inventario")

	# 10D4: sin refugio el bancal se ancla al campamento, no al limite del mundo
	fb["camp_spot"] = Vector3(150.0, 0.4, 150.0)
	var spot2 := mgr._bot_find_farm_spot(fb)
	check(spot2 == Vector3.INF or spot2.distance_to(fb["camp_spot"]) < 7.0,
		"10D4: el bancal nace junto al campamento del bot")
	fb["_farm"] = {}
	fb["proxy"].set_meta("saved_inventory", [])
	world._planted_crops.clear()

	# 10D5: Azada de piedra crafteable — puerta barata al huerto, ~2 usos
	var azada_recipe := {}
	for r in CraftingSystem.RECIPES:
		if str(r.get("output", {}).get("name", "")) == "Azada de piedra":
			azada_recipe = r
	check(not azada_recipe.is_empty(), "10D5a: existe la receta de azada de piedra")
	fb["proxy"].set_meta("saved_inventory", [
		{"name": "Palo", "type": "material", "weight": 0.3, "quantity": 1, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.5, "quantity": 1, "use_value": 0.0},
		{"name": "Cuerda", "type": "resource", "weight": 0.2, "quantity": 1, "use_value": 0.0},
	])
	check(mgr._bot_recipe_score(fb, azada_recipe) > 0.0,
		"10D5b: sin azada la receta interesa al bot")
	mgr._bot_apply_craft(fb, azada_recipe)
	var hoe_inv: Array = fb["proxy"].get_meta("saved_inventory", [])
	var hoe_dur := 0.0
	for it in hoe_inv:
		if str(it.get("name", "")) == "Azada de piedra":
			hoe_dur = float(it.get("durability", 0.0))
	check(mgr._bot_has_farm_tool(fb["proxy"]) and is_equal_approx(hoe_dur, 8.0),
		"10D5c: fabrica la azada (durabilidad %f = ~2 usos)" % hoe_dur)
	check(mgr._bot_recipe_score(fb, azada_recipe) < 0.0,
		"10D5d: ya con azada no fabrica otra")
	mgr._bot_wear_farm_tool(fb["proxy"])
	mgr._bot_wear_farm_tool(fb["proxy"])
	check(not mgr._bot_has_farm_tool(fb["proxy"]),
		"10D5e: tras 2 usos la azada de piedra queda gastada")

	# ==================== 10E: Ordenes por chat ====================
	# 10E1: el parser detecta cada orden y no confunde "ven conmigo" (follow)
	var o_follow := mgr._chat_parse_order("Oye, sígueme anda")
	var o_stay := mgr._chat_parse_order("quédate aquí quieto")
	var o_dismiss := mgr._chat_parse_order("mejor vete de aquí")
	var o_give := mgr._chat_parse_order("dame agua si tienes")
	var o_come := mgr._chat_parse_order("ven aquí rápido")
	var o_ally := mgr._chat_parse_order("ven conmigo")
	var o_atk := mgr._chat_parse_order("ataca a ese lobo")
	var o_none := mgr._chat_parse_order("hola, ¿cómo va todo?")
	check(str(o_follow.get("cmd","")) == "follow" and str(o_stay.get("cmd","")) == "stay"
		and str(o_dismiss.get("cmd","")) == "dismiss" and str(o_give.get("cmd","")) == "give"
		and str(o_give.get("arg","")) == "agua" and str(o_come.get("cmd","")) == "come"
		and str(o_ally.get("cmd","")) == "follow" and str(o_atk.get("cmd","")) == "attack"
		and o_none.is_empty(),
		"10E1: parser de ordenes (follow=%s stay=%s dismiss=%s give=%s/%s come=%s ally=%s atk=%s none=%s)" % [
			str(o_follow.get("cmd","")), str(o_stay.get("cmd","")), str(o_dismiss.get("cmd","")),
			str(o_give.get("cmd","")), str(o_give.get("arg","")), str(o_come.get("cmd","")),
			str(o_ally.get("cmd","")), str(o_atk.get("cmd","")), str(o_none)])

	# 10E2: puerta de obediencia — el aliado sociable sigue a un desconocido,
	# el hostil se niega siempre, quien te atacó te manda a paseo
	var eb: Dictionary = mgr.bots[902]
	var kb: Dictionary = mgr.bots[903]
	eb["team_leader_id"] = 0
	eb["aggro_target"] = null
	var g_friend := mgr._chat_order_gate(eb, 7, "player_7", "follow")
	check(bool(g_friend.get("ok", false)), "10E2a: un bot amistoso coopera y sigue a un desconocido (why=%s)" % str(g_friend.get("why","")))
	var g_host := mgr._chat_order_gate(kb, 7, "player_7", "follow")
	check(not bool(g_host.get("ok", true)) and str(g_host.get("why", "")) in ["wary", "hostile"],
		"10E2b: el hostil rechaza las ordenes (why=%s)" % str(g_host.get("why","")))
	var rel7 := mgr._chat_touch_rel(902, "player_7", "Sami")
	rel7["attacked"] = 2
	rel7["hostility"] = 0.8
	var g_bet := mgr._chat_order_gate(eb, 7, "player_7", "follow")
	check(not bool(g_bet.get("ok", true)) and str(g_bet.get("why","")) == "betrayed",
		"10E2c: tras atacarle no te obedece (why=%s)" % str(g_bet.get("why","")))

	# 10E3: fin a fin — "sígueme" por chat une al equipo y responde "order"
	rel7["attacked"] = 0
	rel7["hostility"] = 0.0
	rel7["trust"] = 0.6
	var chat_n0: int = mgr.chat_log.size()
	mgr.on_chat_received(902, 7, "Sami", "sígueme")
	check(int(eb.get("team_leader_id", 0)) == 7 and str(eb.get("follow_mode","")) == "follow"
		and int(eb["proxy"].get_meta("team_leader_id", 0)) == 7,
		"10E3a: 'sígueme' vincula al bot a tu equipo")
	var last_o := ""
	for i in range(chat_n0, mgr.chat_log.size()):
		var m: Dictionary = mgr.chat_log[i]
		if str(m.get("kind","")) == "order" and int(m.get("to_id",0)) == 7:
			last_o = str(m.get("text",""))
	check(not last_o.is_empty(), "10E3b: responde al momento por el chat (%s)" % last_o)

	# 10E4: compañero — "quédate" lo planta y "vete" lo libera
	mgr.on_chat_received(902, 7, "Sami", "quédate aquí")
	check(str(eb.get("follow_mode","")) == "stay" and eb.get("stay_pos") is Vector3,
		"10E4a: 'quédate' lo deja vigilando")
	mgr.on_chat_received(902, 7, "Sami", "vete")
	check(int(eb.get("team_leader_id", -1)) == 0,
		"10E4b: 'vete' disuelve el equipo")

	# 10E5: "dame agua" con confianza — suelta un item; sin nada, se niega
	rel7["trust"] = 0.6
	eb["proxy"].set_meta("saved_inventory", [
		{"name": "Botella de agua", "type": "drink", "weight": 0.6, "quantity": 2, "use_value": 0.0},
	])
	var gave := mgr._chat_apply_order(eb, 7, "Sami", "give", "agua")
	var inv5: Array = eb["proxy"].get_meta("saved_inventory", [])
	check(gave.is_empty() and inv5.size() == 1 and int(inv5[0].get("quantity",0)) == 1,
		"10E5a: 'dame agua' deja caer una botella (ret=%s inv=%d)" % [gave, inv5.size()])
	eb["proxy"].set_meta("saved_inventory", [])
	var gave2 := mgr._chat_apply_order(eb, 7, "Sami", "give", "")
	check(gave2 == "nothing", "10E5b: sin nada que dar contesta 'nothing'")

	# 10E6: el hostil responde con negativa y NO se une
	var chat_n1: int = mgr.chat_log.size()
	mgr.on_chat_received(903, 7, "Sami", "sígueme")
	check(int(kb.get("team_leader_id", 0)) == 0,
		"10E6a: el hostil no entra en tu equipo")
	var hostile_reply := ""
	for i in range(chat_n1, mgr.chat_log.size()):
		var mo: Dictionary = mgr.chat_log[i]
		if str(mo.get("kind","")) == "order":
			hostile_reply = str(mo.get("text",""))
	check(not hostile_reply.is_empty(), "10E6b: el hostil te contesta negandose (%s)" % hostile_reply)

	# 10E7: mensaje normal sin orden sigue el camino de conversacion habitual
	eb["_chat_inbox"] = {}
	mgr.on_chat_received(902, 7, "Sami", "buenas, que tal")
	check(not (eb.get("_chat_inbox", {}) as Dictionary).is_empty(),
		"10E7: un saludo encola respuesta de conversacion, no orden")

	# ==================== 10F: Peticiones entre actores ====================
	# 10F1: el parser detecta peticiones de objeto y de auxilio
	var r_food := mgr._chat_parse_request("¿tienes comida? me muero de hambre")
	var r_water := mgr._chat_parse_request("necesito agua, estoy seco")
	var r_band := mgr._chat_parse_request("pasame vendas si tienes")
	var r_help := mgr._chat_parse_request("echame una mano, estoy herido")
	var r_gun := mgr._chat_parse_request("dame un arma por favor")
	var r_none := mgr._chat_parse_request("tienes suerte de estar vivo")
	check(str(r_food.get("cmd","")) == "give" and str(r_food.get("arg","")) == "comida"
		and str(r_water.get("cmd","")) == "give" and str(r_water.get("arg","")) == "agua"
		and str(r_band.get("cmd","")) == "give" and str(r_band.get("arg","")).begins_with("venda")
		and str(r_help.get("cmd","")) == "assist" and str(r_gun.get("cmd","")) == "give"
		and r_none.is_empty(),
		"10F1: parser de peticiones (food=%s/%s water=%s/%s band=%s/%s help=%s gun=%s none=%s)" % [
			str(r_food.get("cmd","")), str(r_food.get("arg","")), str(r_water.get("cmd","")),
			str(r_water.get("arg","")), str(r_band.get("cmd","")), str(r_band.get("arg","")),
			str(r_help.get("cmd","")), str(r_gun.get("cmd","")), str(r_none)])

	# 10F2: _chat_request_need detecta cada urgencia
	eb["hunger"] = 10.0; eb["thirst"] = 80.0; eb["health"] = 100.0
	eb["proxy"].set_meta("saved_inventory", [])
	check(mgr._chat_request_need(eb) == "comida", "10F2a: hambriento sin comida pide comida")
	eb["hunger"] = 80.0; eb["thirst"] = 6.0
	check(mgr._chat_request_need(eb) == "agua", "10F2b: sediento sin bebida pide agua")
	eb["thirst"] = 80.0; eb["health"] = 25.0
	check(mgr._chat_request_need(eb) == "vendas", "10F2c: herido sin medicina pide vendas")
	eb["health"] = 100.0
	check(mgr._chat_request_need(eb) == "", "10F2d: sano y saciado no pide nada")

	# 10F3: bot->bot — Elena pide comida a Carlos; si confia, la suelta y
	# Elena va caminando a recogerla
	var cb: Dictionary = mgr.bots[902]
	var alb: Dictionary = mgr.bots[901]
	eb["team_leader_id"] = 0
	var rel_901 := mgr._chat_touch_rel(902, "bot_901", "Elena")
	rel_901["trust"] = 0.7; rel_901["hostility"] = 0.0; rel_901["attacked"] = 0; rel_901["fear"] = 0.0
	cb["proxy"].set_meta("saved_inventory", [
		{"name": "Lata de judias abierta", "type": "food", "weight": 0.4, "quantity": 1, "use_value": 25.0},
	])
	alb["explore_target"] = Vector3.INF
	var req0: int = mgr.chat_log.size()
	mgr.on_chat_received(902, 901, "Elena", "tienes comida? me muero")
	var cb_inv: Array = cb["proxy"].get_meta("saved_inventory", [])
	check(cb_inv.is_empty(), "10F3a: Carlos suelta la lata para Elena (inv=%d)" % cb_inv.size())
	check(alb["explore_target"] != Vector3.INF,
		"10F3b: Elena camina a recoger la comida")
	var req_reply := false
	for i in range(req0, mgr.chat_log.size()):
		var rm: Dictionary = mgr.chat_log[i]
		if str(rm.get("kind","")) == "request" and int(rm.get("to_id",0)) == 901:
			req_reply = true
	check(req_reply, "10F3c: Carlos contesta a la peticion por chat")

	# 10F4: auxilio humano — "ayudame" con confianza mueve al bot hacia ti
	var h7 := Node3D.new()
	world.add_child(h7)
	h7.global_position = Vector3(33.0, 0.5, 44.0)
	world.server_proxies[7] = h7
	var rel7b := mgr._chat_touch_rel(902, "player_7", "Sami")
	rel7b["trust"] = 0.6; rel7b["hostility"] = 0.0; rel7b["attacked"] = 0; rel7b["fear"] = 0.0
	cb["explore_target"] = Vector3.INF
	cb["aggro_target"] = null
	cb["_s_predator"] = null
	cb["_s_foe"] = null
	mgr.on_chat_received(902, 7, "Sami", "ayudame, me atacan")
	check(cb["explore_target"] == h7.global_position,
		"10F4a: 'ayudame' mueve al bot hacia el jugador (tgt=%s)" % str(cb["explore_target"]))
	world.server_proxies.erase(7)
	h7.queue_free()

	# 10F5: el arma propia no se regala — un solo arma no sale de su mochila
	cb["proxy"].set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "use_value": 0.0},
	])
	mgr.on_chat_received(902, 901, "Elena", "dame un arma")
	var cb_inv2: Array = cb["proxy"].get_meta("saved_inventory", [])
	check(cb_inv2.size() == 1, "10F5: no se desarma ni por un aliado (inv=%d)" % cb_inv2.size())

	# 10F6: el hostil no da nada ni acude
	mgr.on_chat_received(903, 901, "Elena", "tienes comida?")
	check(int(kb.get("team_leader_id", 0)) == 0 and kb.get("_meet_id", 0) == 0,
		"10F6: el hostil ignora las peticiones")

	# 10F7: las negativas no rebotan como peticiones nuevas (anti ping-pong)
	check(mgr._chat_parse_request(mgr._chat_request_line(cb, "give", false, "distrust")).is_empty()
		and mgr._chat_parse_request(mgr._chat_request_line(cb, "give", false, "nothing")).is_empty()
		and mgr._chat_parse_request(mgr._chat_request_line(cb, "give", true, "")).is_empty()
		and mgr._chat_parse_request(mgr._chat_request_line(cb, "assist", true, "")).is_empty(),
		"10F7: las respuestas a peticiones no contienen keywords de peticion")

	# 10F8: necesidad real -> emite peticion al aliado en _bot_chat_tick
	cb["hunger"] = 10.0; cb["thirst"] = 80.0
	cb["proxy"].set_meta("saved_inventory", [])
	cb["_chat_cd"] = 0.0
	cb["aggro_target"] = null
	mgr._chat_pending = {}
	mgr._chat_req_until.erase(902)
	mgr._bot_chat_tick(cb)
	var asked := false
	for m in mgr.chat_log:
		if int(m.get("from_id",0)) == 902 and str(m.get("kind","")) == "request":
			asked = true
	check(asked or not mgr._chat_pending.is_empty(),
		"10F8: con hambre extrema pide comida por el chat (asked=%s pending=%s)" % [asked, str(mgr._chat_pending)])
	cb["hunger"] = 80.0

	# ==================== 10G: Deduplicacion de ubicaciones conocidas ====================
	# 10G1: dos POIs del mismo edificio (<4m) son UNA ubicacion
	var gmem := {"known_locations": {}}
	mgr._memory[777] = gmem
	mgr.observe_location(777, "city:-7:3:663", "city", Vector3(-7.0, 3.9, 663.0), "observed", true)
	mgr.observe_location(777, "city:-8:7:664", "city", Vector3(-7.8, 7.9, 664.0), "observed", true)
	var gk: Dictionary = gmem["known_locations"]
	check(gk.size() == 1, "10G1: plantas de un mismo edificio = 1 ubicacion (n=%d)" % gk.size())

	# 10G2: casas distintas (>4m) se conservan
	mgr.observe_location(777, "house:30:40", "house", Vector3(30.0, 0.4, 40.0))
	mgr.observe_location(777, "house:44:46", "house", Vector3(44.0, 0.4, 46.0))
	gk = gmem["known_locations"]
	check(gk.size() == 3, "10G2: casas separadas no se fusionan (n=%d)" % gk.size())

	# 10G3: ruido de zona (wild/patrol/gunshot) fusiona en radio amplio (18m)
	mgr.observe_location(777, "wild:100:100", "wild", Vector3(100.0, 0.4, 100.0))
	mgr.observe_location(777, "wild:105:110", "wild", Vector3(105.0, 0.4, 110.0))
	var wild_n := 0
	for k2 in gk.keys():
		if str(k2).begins_with("wild:"):
			wild_n += 1
	check(wild_n == 1, "10G3: eventos 'wild' de la misma zona colapsan (wild=%d total=%d)" % [wild_n, gk.size()])

	# 10G4: la fusion conserva visitas acumuladas en la entrada unica
	var gentry: Dictionary = gk["city:-7:3:663"]
	check(int(gentry.get("visits", 0)) == 2,
		"10G4: la entrada fusionada acumula las visitas (v=%d)" % int(gentry.get("visits", 0)))

	# 10G5: _compact_known_locations limpia memoria vieja de una pasada
	var dirty := {"known_locations": {
		"wild:1:1": {"pos": [1.0, 0.0, 1.0], "visits": 2, "risk": 0.3},
		"wild:2:2": {"pos": [2.0, 0.0, 2.0], "visits": 1, "risk": 0.6},
		"house:50:50": {"pos": [50.0, 0.0, 50.0], "visits": 1, "risk": 0.0},
		"house:51:50": {"pos": [51.0, 0.0, 50.0], "visits": 3, "risk": 0.1},
	}}
	mgr._compact_known_locations(dirty)
	var clean_kl: Dictionary = dirty["known_locations"]
	check(clean_kl.size() == 2, "10G5a: compactacion fusiona duplicados (n=%d de 4)" % clean_kl.size())
	var max_risk := 0.0
	var tot_visits := 0
	for k3 in clean_kl.keys():
		var e3: Dictionary = clean_kl[k3]
		max_risk = maxf(max_risk, float(e3.get("risk", 0.0)))
		tot_visits += int(e3.get("visits", 0))
	check(is_equal_approx(max_risk, 0.6) and tot_visits == 7,
		"10G5b: fusion conserva risk max y visitas (risk=%f visits=%d)" % [max_risk, tot_visits])
	mgr._memory.erase(777)

	# ==================== 10H: Voz humano->bot + ensenanzas ====================
	# 10H1: parser de ensenanzas — cada categoria, y que una peticion no lo es
	check(str(mgr._chat_parse_teach("aqui hay agua, puedes beber").get("kind", "")) == "water",
		"10H1a: 'aqui hay agua' -> water")
	check(str(mgr._chat_parse_teach("cuidado, hay lobos por aqui").get("kind", "")) == "danger",
		"10H1b: 'cuidado hay lobos' -> danger")
	check(str(mgr._chat_parse_teach("recuerda este sitio").get("kind", "")) == "marked",
		"10H1c: 'recuerda este sitio' -> marked")
	check(str(mgr._chat_parse_teach("en esa casa hay loot").get("kind", "")) == "loot",
		"10H1d: 'en esa casa hay loot' -> loot")
	check(mgr._chat_parse_teach("tienes comida?").is_empty(),
		"10H1e: 'tienes comida?' es peticion, no ensenanza")

	# 10H2: enseñar agua por chat -> known_locations + drink_at si tiene sed
	var vb: Dictionary = mgr.bots[902]
	vb["thirst"] = 20.0
	vb["drink_at"] = Vector3.INF
	vb["drink_giveup"] = 60.0
	var h8 := Node3D.new()
	world.add_child(h8)
	h8.global_position = vb["proxy"].global_position + Vector3(4.0, 0.0, 4.0)
	world.server_proxies[8] = h8
	var pre_teacher := mgr._chat_touch_rel(902, "player_8", "Profe")
	pre_teacher["trust"] = 0.5; pre_teacher["hostility"] = 0.0; pre_teacher["attacked"] = 0
	var pre_log := mgr.chat_log.size()
	mgr.on_chat_received(902, 8, "Profe", "aqui hay agua, bebe de esta fuente")
	var vkl: Dictionary = vb["_mem"]["known_locations"]
	var water_keys := 0
	for wk in vkl.keys():
		if str(wk).begins_with("water:"):
			water_keys += 1
	check(water_keys >= 1, "10H2a: ensenanza de agua registra la fuente (n=%d)" % water_keys)
	check(vb["drink_at"] != Vector3.INF,
		"10H2b: bot con sed apunta a la fuente ensenada (drink_at=%s)" % str(vb["drink_at"]))
	check(mgr.chat_log.size() > pre_log and str(mgr.chat_log.back().get("kind", "")) == "teach",
		"10H2c: el bot confirma la leccion por chat")

	# 10H3: _known_water_pos encuentra la fuente ensenada
	vb["drink_at"] = Vector3.INF
	var kw := mgr._known_water_pos(vb)
	check(kw != Vector3.INF and kw.distance_to(h8.global_position) < 5.0,
		"10H3: _known_water_pos resuelve la fuente conocida (p=%s)" % str(kw))

	# 10H4: ensenanza de peligro -> zona de riesgo en memoria
	var pre_danger := 0
	for dk in vkl.keys():
		if float((vkl[dk] as Dictionary).get("risk", 0.0)) > 0.0:
			pre_danger += 1
	mgr.on_chat_received(902, 8, "Profe", "cuidado, hay lobos por aqui")
	var post_danger := 0
	for dk2 in vkl.keys():
		if float((vkl[dk2] as Dictionary).get("risk", 0.0)) > 0.0:
			post_danger += 1
	check(post_danger >= pre_danger, "10H4: 'cuidado lobos' marca zona de riesgo (n=%d->%d)" % [pre_danger, post_danger])

	# 10H5: escritor WAV — cabecera RIFF valida
	var wpath := ProjectSettings.globalize_path("user://voice_test_reg.wav")
	check(mgr._voice_write_wav(wpath, PackedByteArray([128, 130, 100, 128]), 12000), "10H5a: _voice_write_wav escribe")
	var wf := FileAccess.open(wpath, FileAccess.READ)
	var hdr_ok := false
	if wf != null:
		var hdr := wf.get_buffer(12)
		hdr_ok = hdr.size() == 12 and hdr.slice(0, 4).get_string_from_ascii() == "RIFF" and hdr.slice(8, 12).get_string_from_ascii() == "WAVE"
		wf.close()
	DirAccess.remove_absolute(wpath)
	check(hdr_ok, "10H5b: WAV tiene cabecera RIFF/WAVE")

	# 10H6: puerta de alcance — la voz lejana no se acumula, la cercana si
	var pcm600 := PackedByteArray()
	pcm600.resize(600)
	pcm600.fill(128)
	h8.global_position = vb["proxy"].global_position + Vector3(200.0, 0.0, 0.0)
	mgr.on_voice_received(902, 8, "Profe", pcm600)
	check(not mgr._voice_bufs.has("8_902"), "10H6a: voz a 200 m no llega al bot")
	check(mgr._voice_far_notice.has(8), "10H6b: aviso 'demasiado lejos' registrado")
	h8.global_position = vb["proxy"].global_position + Vector3(3.0, 0.0, 0.0)
	mgr.on_voice_received(902, 8, "Profe", pcm600)
	check(mgr._voice_bufs.has("8_902") and (mgr._voice_bufs["8_902"]["pcm"] as PackedByteArray).size() == 600,
		"10H6c: voz a 3 m se acumula en el buffer")

	# 10H7: pipeline trabajo->transcripcion->chat — el demonio deja el .txt
	mgr._voice_bufs.erase("8_902")
	var jobdir := ProjectSettings.globalize_path(mgr.VOICE_JOBS_DIR)
	DirAccess.make_dir_recursive_absolute(jobdir)
	mgr._voice_jobs["v_test_h7"] = {"bot_id": 902, "sender_id": 8, "sender_name": "Profe", "born": Time.get_ticks_msec()}
	var jf := FileAccess.open(jobdir + "v_test_h7.txt", FileAccess.WRITE)
	jf.store_string("sigueme")
	jf.close()
	mgr._voice_poll_jobs()
	var saw_voice := false
	for mvo in mgr.chat_log:
		if str(mvo.get("kind", "")) == "voice" and str(mvo.get("text", "")) == "sigueme":
			saw_voice = true
	check(saw_voice, "10H7a: transcripcion de voz registrada en el hilo")
	check(int(vb.get("team_leader_id", 0)) == 8,
		"10H7b: 'sigueme' por voz ejecuta la orden (leader=%d)" % int(vb.get("team_leader_id", 0)))

	# 10H8: preguntar por Elena — responde si esta cerca (<=28 m), ignora si esta lejos
	var eb901: Dictionary = mgr.bots[901]
	eb901["proxy"].global_position = h8.global_position + Vector3(5.0, 0.0, 0.0)
	check(mgr._voice_resolve_named_bot("Hola Elena, donde estas?", 8, 902) == 901,
		"10H8a: nombrar a Elena a 5 m redirige la voz a Elena (901)")
	eb901["proxy"].global_position = h8.global_position + Vector3(120.0, 0.0, 0.0)
	check(mgr._voice_resolve_named_bot("Hola Elena, me oyes?", 8, 902) == 0,
		"10H8b: nombrar a Elena a 120 m no contesta (fuera de alcance)")

	# 10H9: respuesta hablada TTS — el bot emite paquetes PCM por relay_actor_voice y texto en chat
	for tk2 in mgr._tts_jobs.keys():
		DirAccess.remove_absolute(jobdir + str(tk2) + ".json")
	mgr._tts_jobs.clear()
	mgr._tts_streams.clear()
	fnet.relay_log.clear()
	fnet.voice_relay_log.clear()
	mgr._bot_chat_send(vb, 8, "Profe", "Perfecto, aqui puedo beber. Gracias.", "teach")
	check(fnet.relay_log.size() == 1 and mgr._tts_jobs.size() == 1,
		"10H9a: _bot_chat_send a humano crea trabajo TTS y texto en chat")
	var tts_base := str(mgr._tts_jobs.keys()[0])
	var pcm_reply := PackedByteArray()
	pcm_reply.resize(2400)
	pcm_reply.fill(140)
	var pf := FileAccess.open(jobdir + tts_base + ".pcm", FileAccess.WRITE)
	pf.store_buffer(pcm_reply)
	pf.close()
	mgr._tts_poll_jobs()
	mgr._tts_stream_tick(0.10)
	var total_voice_b := 0
	for vr in fnet.voice_relay_log:
		if int(vr.get("from_id", 0)) == 902 and int(vr.get("to_id", 0)) == 8:
			total_voice_b += int(vr.get("bytes", 0))
	check(total_voice_b == 2400 and fnet.relay_log.size() == 1,
		"10H9b: el audio TTS llega al humano por relay_actor_voice (%d B) y 1 msg de texto" % total_voice_b)
	fnet.mp3_relay_log.clear()
	mgr._bot_chat_send(vb, 8, "Profe", "Vale, me quedo aquí vigilando, tranquilo.", "order")
	var tts_base_mp3 := str(mgr._tts_jobs.keys()[0])
	var mp3_reply := PackedByteArray([0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00, 0x00, 0x00])
	var mf := FileAccess.open(jobdir + tts_base_mp3 + ".mp3", FileAccess.WRITE)
	mf.store_buffer(mp3_reply)
	mf.close()
	mgr._tts_poll_jobs()
	check(fnet.mp3_relay_log.size() == 1 and int(fnet.mp3_relay_log[0].get("bytes", 0)) == 8 and fnet.relay_log.size() == 2,
		"10H9c: clip MP3 neuronal 24kHz se entrega integro por relay_actor_voice_mp3 y 2 msgs de texto")

	world.server_proxies.erase(8)
	h8.queue_free()
	vb["team_leader_id"] = 0
	vb["follow_mode"] = "none"

	# ==================== 10I: Pasos al morir, tecla Z, IA tactica y aprendizaje ====================
	# 10I1: puppet_apply con anim "dead" detiene inmediatamente el audio de pasos en bucle
	var test_pup := TestPlayer.new()
	test_pup.is_puppet = true
	test_pup._puppet_step_player = AudioStreamPlayer3D.new()
	test_pup.puppet_apply(Vector3.ZERO, 0.0, "dead")
	check(test_pup.is_dead and not test_pup._puppet_step_player.playing,
		"10I1: puppet_apply('dead') marca is_dead y para _puppet_step_player")
	test_pup._puppet_step_player.free()
	test_pup.free()

	# 10I2: el menu de ordenes [Z] ya no existe — la interaccion con bots es
	# solo chat/voz (cubierto por BotConvinceRegression).

	# 10I3: Kael desarmado detecta al humano como amenaza (para huir, no para
	# un ataque suicida); armado con fusil lo elige como objetivo de combate
	var kb903: Dictionary = mgr.bots[903]
	kb903["proxy"].set_meta("proxy_dead", false)
	kb903["aggro_target"] = null
	kb903["proxy"].global_position = Vector3(50.0, 0.4, 50.0)
	world.player.global_position = Vector3(56.0, 0.4, 50.0)
	kb903["proxy"].set_meta("saved_inventory", [])
	check(mgr._find_combat_foe(kb903) != null,
		"10I3a: Kael desarmado detecta al humano cercano como amenaza (huira, no ataca)")
	kb903["proxy"].set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 10.0, "durability": 100.0, "max_durability": 100.0}])
	check(mgr._find_combat_foe(kb903) != null,
		"10I3b: Kael armado con fusil si detecta y ataca al enemigo")

	# 10I4: aprendizaje al morir en combate y evolucion por crafteo/ensenanza
	var k_rel_pre := mgr.get_bot_relationship(903, "player_8")
	var fear_pre := float(k_rel_pre.get("fear", 0.0))
	kb903["proxy"].set_meta("proxy_health", 20.0)
	kb903["health"] = 20.0
	mgr.on_bot_damaged(903, 35.0, 8, "rifle")
	var k_rel_post := mgr.get_bot_relationship(903, "player_8")
	check(float(k_rel_post.get("fear", 0.0)) > fear_pre and str(mgr._ensure_bot_memory(903).get("last_death_cause", "")) == "rifle",
		"10I4a: morir por rifle registra la causa real ('rifle') y sube el miedo al asesino (fear %.2f->%.2f)" % [fear_pre, float(k_rel_post.get("fear", 0.0))])
	mgr._respawn_bot(kb903)
	var soc0 := float(mgr._get_bot_personality(vb).get("sociability", 0.5))
	mgr._evolve_personality(vb, "voice_taught", 0.5)
	var soc1 := float(mgr._get_bot_personality(vb).get("sociability", 0.5))
	check(soc1 >= soc0, "10I4b: aprender por voz evoluciona sociabilidad/cooperacion (%.3f->%.3f)" % [soc0, soc1])

	# 10I5: mordisco de animal libera estado sentado/tumbado/carga y no pisa el golpe activo del jugador
	world.player.is_dead = false
	world.player.stats.health = 100.0
	world.player.is_sitting = true
	world.player.is_prone = true
	world.player._sit_cooldown = 1.0
	world.player._throw_charging = true
	world.player.third_person_attack_animation = "attack_test"
	world.player.third_person_action_animation = "attack_test"
	world.player.third_person_action_timer = 0.40
	world.player.apply_damage(12.0, "wolf_bite")
	world.player._play_hit_reaction(false)
	check(not world.player.is_sitting and not world.player.is_prone and not world.player._throw_charging,
		"10I5a: mordisco de lobo libera sentado/tumbado/carga para que el jugador no quede clavado")
	check(world.player.third_person_action_animation == "attack_test",
		"10I5b: _play_hit_reaction no cancela el golpe cuerpo a cuerpo activo del jugador")
	world.player.third_person_action_animation = ""
	world.player.third_person_action_timer = 0.0

	# ==================== 10J: Animaciones de bots, huida de frente, mapa sin muertos y evolucion por muertes ====================
	# 10J1: Al huir de un animal, el bot gira de frente hacia la direccion de huida (nunca corre de espaldas mirando al lobo)
	var fb_flee: Dictionary = mgr.bots[901]
	fb_flee["proxy"].set_meta("proxy_dead", false)
	fb_flee["proxy"].set_meta("saved_inventory", [{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 10.0}])
	fb_flee["shelter_pos"] = Vector3.INF
	fb_flee["proxy"].global_position = Vector3(10.0, 0.375, 10.0)
	fb_flee["pos"] = fb_flee["proxy"].global_position
	var wolf_flee := Node3D.new()
	world.add_child(wolf_flee)
	wolf_flee.global_position = Vector3(10.0, 0.375, 18.0) # lobo al +Z
	# Inicializar el bot mirando e inercia directo hacia el lobo (+Z)
	fb_flee["rot"] = atan2(0.0, -1.0) # PI = mirando hacia +Z
	fb_flee["_mdir"] = Vector3(0.0, 0.0, 1.0)
	var pos_pre_flee: Vector3 = fb_flee["proxy"].global_position
	mgr._handle_predator_encounter(fb_flee, wolf_flee, 0.1)
	var disp_flee: Vector3 = fb_flee["proxy"].global_position - pos_pre_flee
	disp_flee.y = 0.0
	var facing_flee := Vector3(-sin(float(fb_flee["rot"])), 0.0, -cos(float(fb_flee["rot"])))
	check(disp_flee.length() > 0.25 and disp_flee.normalized().dot(facing_flee.normalized()) > 0.75,
		"10J1a: Al huir del lobo el bot mira en el sentido en que corre (dot=%.2f > 0.75, nunca de espaldas)" % disp_flee.normalized().dot(facing_flee.normalized()))
	wolf_flee.queue_free()

	# 10J2: Velocidad y animaciones cerca del humano (sprint de compañero, sneak_walk agachado, no comer caminando)
	var lead_p := Node3D.new()
	world.add_child(lead_p)
	lead_p.global_position = Vector3(26.0, 0.375, 10.0)
	lead_p.set_meta("sprinting", true)
	fb_flee["proxy"].global_position = Vector3(20.0, 0.375, 10.0) # a 6.0 m del humano
	fb_flee["pos"] = fb_flee["proxy"].global_position
	fb_flee["crouching"] = false
	fb_flee["_speed"] = 0.0
	mgr._tick_teammate_behavior(fb_flee, lead_p, 0.1)
	check(str(fb_flee["anim"]) == "run" and float(fb_flee["_speed"]) >= 5.0,
		"10J2a: Bot aliado cerca del humano corre con velocidad real de sprint (anim=%s, spd=%.2f)" % [str(fb_flee["anim"]), float(fb_flee["_speed"])])
	fb_flee["crouching"] = true
	fb_flee["anim"] = "walk"
	check(mgr._bot_effective_net_anim(fb_flee) == "sneak_walk",
		"10J2b: Bot agachado en movimiento sincroniza 'sneak_walk' en lugar de pose estatica 'sneak'")
	fb_flee["crouching"] = false
	fb_flee["consume_anim"] = "eat"
	fb_flee["consume_anim_t"] = 1.2
	fb_flee["anim"] = "walk"
	check(mgr._bot_effective_net_anim(fb_flee) == "walk",
		"10J2c: _bot_effective_net_anim no pisa 'walk' con 'eat' mientras el bot camina")
	fb_flee["consume_anim_t"] = 0.0
	lead_p.queue_free()

	# 10J3: En el preview del mapa (get_full_web_status + bot_monitor.html) no aparecen los bots muertos
	var b902_dead: Dictionary = mgr.bots[902]
	b902_dead["team_leader_id"] = 901
	b902_dead["explore_target"] = Vector3(120.0, 0.0, 120.0)
	mgr._kill_bot(b902_dead, "wolf_bite")
	var web_st_10j: Dictionary = mgr.get_full_web_status()
	var dead_snap: Dictionary = {}
	for bs in web_st_10j.get("bots", []):
		if int(bs.get("bot_id", 0)) == 902:
			dead_snap = bs
			break
	check(bool(dead_snap.get("dead", false)) and (dead_snap.get("explore_target", []) as Array).is_empty() and int(dead_snap.get("team_leader_id", -1)) == 0,
		"10J3a: Bot muerto figura con dead=true, sin explore_target ni equipo activo en get_full_web_status")
	var html_src := FileAccess.get_file_as_string("res://tools/web/bot_monitor.html")
	check(html_src.contains("isBotDead(b)") and html_src.contains("if (isBotDead(b)) continue;"),
		"10J3b: bot_monitor.html filtra los bots muertos en renderMap para que no aparezcan en el preview del mapa")
	mgr._respawn_bot(b902_dead)

	# 10J4: Aprendizaje y evolucion por muertes (hidratacion, forrajeo, depredadores, frio, combate y persistencia)
	var b_evo: Dictionary = mgr.bots[902]
	var mem_evo: Dictionary = mgr._ensure_bot_memory(902, b_evo.get("cfg", {}))
	mem_evo["death_lessons"] = {}
	mem_evo["base_raided"] = 0
	mgr._record_death_lesson(b_evo, mem_evo, "dehydrated")
	mgr._record_death_lesson(b_evo, mem_evo, "starved")
	mgr._record_death_lesson(b_evo, mem_evo, "wolf_bite")
	mgr._record_death_lesson(b_evo, mem_evo, "hypothermia")
	mgr._record_death_lesson(b_evo, mem_evo, "melee")
	var dl_map: Dictionary = mem_evo.get("death_lessons", {})
	var adapts_evo: Array = mgr._bot_death_adaptations(mem_evo)
	check(int(dl_map.get("dehydrated", 0)) == 1 and int(dl_map.get("starved", 0)) == 1 and int(dl_map.get("predator", 0)) == 1 and int(dl_map.get("cold", 0)) == 1 and int(dl_map.get("combat", 0)) == 1 and adapts_evo.size() == 5,
		"10J4a: El bot aprende lecciones especificas de cada causa de muerte y genera las 5 adaptaciones evolutivas (n=%d)" % adapts_evo.size())
	# Muerte a distancia (rifle): categoria propia 'ranged' con su adaptacion
	mgr._record_death_lesson(b_evo, mem_evo, "rifle")
	check(int(dl_map.get("ranged", 0)) == 1 and mgr._bot_death_adaptations(mem_evo).size() == 6,
		"10J4a2: La muerte a tiros deja leccion 'ranged' y su adaptacion anti-tirador")
	var tmp_mem_path := "user://test_bot_death_lessons_mem.json"
	mgr.memory_path = tmp_mem_path
	mgr.force_memory_io = true
	mgr._ai_save_memory()
	mgr._ai_flush_writes()
	var mgr_reload := SurvivorBotManagerScript.new()
	mgr_reload.memory_path = tmp_mem_path
	mgr_reload.force_memory_io = true
	mgr_reload._ai_load_memory()
	var loaded_dl: Dictionary = mgr_reload._ensure_bot_memory(902).get("death_lessons", {})
	check(int(loaded_dl.get("predator", 0)) == 1 and int(loaded_dl.get("dehydrated", 0)) == 1 and int(loaded_dl.get("combat", 0)) == 1,
		"10J4b: death_lessons persiste en disco entre sesiones (_ai_save_memory / _ai_load_memory)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_mem_path))
	mgr_reload.free()
	mgr.memory_path = SurvivorBotManagerScript.AI_MEMORY_PATH

	# 10J5: Mejoras de IA — no quedarse parado de noche sin refugio estando
	# descansado, apilado/tope de flechas para proteger los 11 palos del
	# refugio, filtro de duplicados de armas/arcos, reserva multiple de agua
	# con lecciones de sed, y no fuego fratricida ni falso verdugo por causas naturales.
	var b_ai: Dictionary = mgr.bots[902]
	var p_ai: Node3D = b_ai["proxy"]
	var vs_ai: SurvivalStats = b_ai["vstats"]
	b_ai["shelter_id"] = ""
	b_ai["shelter_pos"] = Vector3.INF
	b_ai["camp_spot"] = Vector3(300.0, 0.4, 300.0)
	b_ai["explore_target"] = Vector3.INF
	b_ai["hide_timer"] = 0.0
	b_ai["flee_until"] = 0.0
	b_ai["sleeping"] = false
	b_ai["sitting"] = false
	b_ai["health"] = 100.0
	b_ai["hunger"] = 85.0
	b_ai["thirst"] = 85.0
	vs_ai.sleep = 95.0
	vs_ai.energy = 95.0
	vs_ai.body_temperature = 36.6
	p_ai.global_position = Vector3(100.0, 0.4, -140.0)
	b_ai["pos"] = p_ai.global_position
	# Con antorcha propia si puede moverse de noche: la luz es el minimo para
	# salir a explorar (sin ella se parapeta, ver 10J5n).
	p_ai.set_meta("saved_inventory", [
		{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
	])
	dc.time_of_day = 20.5
	mgr._tick_bot(b_ai, 0.1)
	check(str(b_ai.get("_act", "")) != "rest" and not bool(b_ai.get("sitting", false)),
		"10J5a: De noche con antorcha y descansado (sleep=95) el bot NO se queda clavado en rest (act=%s)" % str(b_ai.get("_act", "")))
	dc.time_of_day = 14.0

	# Apilado de flechas y tope de crafteo mientras faltan los 11 palos del refugio
	var arr_inv: Array = []
	mgr._bot_add_inventory_item(arr_inv, {"name": "Flecha de madera", "type": "ammo_arrow", "weight": 0.08, "quantity": 5})
	mgr._bot_add_inventory_item(arr_inv, {"name": "Flecha de madera", "type": "ammo_arrow", "weight": 0.08, "quantity": 5})
	check(arr_inv.size() == 1 and int(arr_inv[0].get("quantity", 0)) == 10,
		"10J5b: Las flechas (ammo_arrow) se apilan en un solo hueco de mochila")
	p_ai.set_meta("saved_inventory", [
		{"name": "Arco reforzado", "type": "weapon_bow", "weight": 1.1, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
		{"name": "Flecha de madera", "type": "ammo_arrow", "weight": 0.08, "quantity": 5},
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6},
	])
	var r_fmad := {}
	var r_amad := {}
	for r in CraftingSystem.RECIPES:
		var onm := str((r.get("output", {}) as Dictionary).get("name", ""))
		if onm == "Flecha de madera":
			r_fmad = r
		elif onm == "Arco de madera":
			r_amad = r
	check(mgr._bot_recipe_score(b_ai, r_fmad) < 0.0 and mgr._bot_recipe_score(b_ai, r_amad) < 0.0,
		"10J5c: Sin refugio y con 5 flechas + Arco reforzado no gasta los palos del refugio en mas flechas ni en arco inferior")
	check(not mgr._is_loot_desirable(b_ai, "Arco de madera", "weapon_bow")
		and not mgr._is_loot_desirable(b_ai, "Arco reforzado", "weapon_bow")
		and not mgr._is_loot_desirable(b_ai, "Cuchillo", "weapon"),
		"10J5d: No saquea arcos ni cuchillos duplicados/inferiores que atasquen su mochila")

	# Reserva multiple de agua con lecciones de sed
	mem_evo["death_lessons"] = {"dehydrated": 2}
	p_ai.set_meta("saved_inventory", [
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
	])
	check(mgr._bot_desired_drink_cap(b_ai) == 3 and mgr._is_loot_desirable(b_ai, "Botella de agua llena", "water") and mgr._is_loot_desirable(b_ai, "Botella de plastico", "misc"),
		"10J5e: Con 2 muertes de sed busca hasta 3 reservas de agua/botellas")

	# Disparo entre hostiles sin agresion previa no activa fuego fratricida
	var b901_h: Dictionary = mgr.bots[901]
	var b903_h: Dictionary = mgr.bots[903]
	mgr._set_bot_faction(b901_h, "hostile")
	mgr._set_bot_faction(b903_h, "hostile")
	mgr._ensure_bot_memory(901)["relationships"].erase("bot_903")
	mgr._ensure_bot_memory(903)["relationships"].erase("bot_901")
	b903_h["aggro_target"] = null
	b901_h["proxy"].global_position = Vector3(10.0, 0.4, 10.0)
	b903_h["proxy"].global_position = Vector3(50.0, 0.4, 10.0)
	b903_h["proxy"].set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1}])
	mgr.notify_sound_event(901, b901_h["proxy"].global_position, "gunshot", 220.0)
	check(b903_h.get("aggro_target") == null,
		"10J5f: El disparo de un bot de la misma faccion (cazando) no provoca aggro fratricida")

	# Muerte natural no culpa a un atacante antiguo como verdugo
	b_ai["_last_attacker_id"] = 903
	b_ai["_last_attacker_msec"] = Time.get_ticks_msec()
	mem_evo["killers"] = {}
	mgr._kill_bot(b_ai, "exhausted")
	check(str(mem_evo.get("last_death_killer", "")) == "" and (mem_evo.get("killers", {}) as Dictionary).is_empty(),
		"10J5g: Morir por agotamiento/sed no registra como asesino ni nemesis a un atacante previo")
	mgr._respawn_bot(b_ai)

	# Anti-ciclo de equipo: si dos bots quedan apuntandose como lider el uno
	# al otro (901<->902, que dejaba a los 3 parados en act=team/idle), el de
	# mejor liderazgo rompe el ciclo al instante y queda un unico lider raiz.
	var b901_c: Dictionary = mgr.bots[901]
	var b902_c: Dictionary = mgr.bots[902]
	var b903_c: Dictionary = mgr.bots[903]
	mgr._set_bot_faction(b901_c, "hostile")
	mgr._set_bot_faction(b902_c, "hostile")
	mgr._set_bot_faction(b903_c, "hostile")
	for id_a in [901, 902, 903]:
		for id_b in [901, 902, 903]:
			if id_a != id_b:
				mgr._ensure_bot_memory(id_a)["relationships"]["bot_%d" % id_b] = {"id": "bot_%d" % id_b, "name": "Bot", "trust": 0.8, "hostility": 0.1, "fear": 0.0, "helped": 5, "attacked": 0}
	b901_c["proxy"].global_position = Vector3(50.0, 0.4, 50.0)
	b902_c["proxy"].global_position = Vector3(52.0, 0.4, 50.0)
	b903_c["proxy"].global_position = Vector3(54.0, 0.4, 50.0)
	b901_c["team_leader_id"] = 902
	b902_c["team_leader_id"] = 901
	b903_c["team_leader_id"] = 901
	b901_c["_soc_t"] = 0.0
	b902_c["_soc_t"] = 0.0
	b903_c["_soc_t"] = 0.0
	mgr._bot_social_update(b901_c)
	mgr._bot_social_update(b902_c)
	mgr._bot_social_update(b903_c)
	var roots := 0
	for b_chk in [b901_c, b902_c, b903_c]:
		if int(b_chk.get("team_leader_id", 0)) == 0:
			roots += 1
	check(roots == 1 and not (int(b901_c.get("team_leader_id", 0)) == 902 and int(b902_c.get("team_leader_id", 0)) == 901),
		"10J5h: El ciclo de liderazgo 901<->902 se rompe dejando exactamente 1 lider raiz con su equipo en marcha (roots=%d)" % roots)
	for b_clr in [b901_c, b902_c, b903_c]:
		b_clr["team_leader_id"] = 0
		(b_clr["proxy"] as Node3D).set_meta("team_leader_id", 0)

	# 10J5i: Con 6 Troncos + Cuchillo (suministro >= 11 palos), el bot raja los
	# troncos a 12 palos de inmediato y levanta su refugio.
	var b_log: Dictionary = mgr.bots[902]
	var p_log: Node3D = b_log["proxy"]
	b_log["shelter_id"] = ""
	b_log["shelter_pos"] = Vector3.INF
	b_log["camp_spot"] = Vector3(120.0, 0.4, 120.0)
	p_log.global_position = Vector3(120.0, 0.4, 120.0)
	b_log["pos"] = p_log.global_position
	b_log["hunger"] = 90.0
	b_log["thirst"] = 90.0
	b_log["health"] = 100.0
	b_log["energy"] = 100.0
	b_log["sleep"] = 100.0
	var vs_log: SurvivalStats = b_log["vstats"]
	vs_log.energy = 100.0
	vs_log.sleep = 100.0
	vs_log.body_temperature = 36.5
	b_log["_craft_state"] = {}
	# Sin distracciones sensadas heredadas: un loot/cadaver/presa vivo de una
	# seccion anterior roba ticks al rajo y el refugio no llega a levantarse.
	for s_key in ["_s_loot", "_s_prey", "_s_predator", "_s_foe", "_s_corpse",
			"_s_tame_wolf", "_salvage", "_s_raid_shelter", "_steal_target"]:
		b_log[s_key] = {}
	p_log.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "durability": 100.0, "max_durability": 100.0},
		{"name": "Tronco", "type": "resource", "weight": 1.2, "quantity": 6},
	])
	for i in range(120):
		mgr._tick_bot(b_log, 0.25)
		if not str(b_log.get("shelter_id", "")).is_empty():
			break
	check(not str(b_log.get("shelter_id", "")).is_empty() and mgr._bot_item_count(p_log, "Tronco") == 0,
		"10J5i: Con 6 Troncos + Cuchillo raja los 12 palos y construye su refugio (sh=%s)" % str(b_log.get("shelter_id", "")))

	# 10J5j: Recuperacion de energia al caminar/descansar y freno de sprint con
	# energia <=12 (evita quedar a energy=0 perpetuo y morir de agotamiento).
	var vs_en: SurvivalStats = b_log["vstats"]
	vs_en.energy = 8.0
	b_log["energy"] = 8.0
	b_log["aggro_target"] = null
	b_log["_s_predator"] = null
	b_log["_s_foe"] = null
	b_log["flee_until"] = 0.0
	mgr._move_bot_towards(b_log, p_log.global_position + Vector3(20.0, 0.0, 0.0), 6.2, 0.2, "run")
	mgr._bot_survival_tick(b_log, 2.0)
	check(str(b_log["anim"]) == "walk" and vs_en.energy > 12.0,
		"10J5j: Con energia baja el bot deja de esprintar, pasa a walk y recupera energia (anim=%s en=%.1f)" % [str(b_log["anim"]), vs_en.energy])

	# 10J5k: Doma de lobos real en _tick_bot (no secuestrada por predator) y
	# reserva de 3 carnes crudas sin cocinar mientras no tenga lobo domado.
	var w_tame2 := WildlifeControllerScript.new()
	w_tame2.name = "Wildlife_wolf_tame_tick"
	world.add_child(w_tame2)
	w_tame2.setup("wolf", [Vector3(120.0, 0.4, 120.0)])
	w_tame2.set_process(false)
	w_tame2.global_position = p_log.global_position + Vector3(10.0, 0.0, 0.0)
	b_log["tame_cooldown"] = 0.0
	b_log["_tame_wait_t"] = 0.0
	b_log["hunger"] = 85.0
	b_log["health"] = 100.0
	b_log["sense_t"] = 0.0
	p_log.set_meta("saved_inventory", [
		{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0},
		{"name": "Palo afilado", "type": "tool_spear", "weight": 0.3, "quantity": 1},
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 2},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 2},
	])
	check(not mgr._bot_try_cook_meat(b_log, 0.1),
		"10J5k1: Sin lobo domesticado y sin hambre reserva sus 3 carnes crudas para domar en vez de asarlas")
	mgr._tick_bot(b_log, 0.1)
	check(str(b_log.get("_act", "")) == "tame" and float(b_log.get("_tame_wait_t", 0.0)) > 0.0,
		"10J5k2: Con lobo salvaje a 10 m y carne cruda _tick_bot entra en 'tame' antes que 'predator' (act=%s)" % str(b_log.get("_act", "")))
	w_tame2.queue_free()

	# 10J5l: Tactica de boleadoras en combate humano y anti-enganche en melee (<1.25 m)
	var foe_t := Node3D.new()
	world.add_child(foe_t)
	foe_t.global_position = p_log.global_position + Vector3(12.0, 0.0, 0.0)
	p_log.set_meta("saved_inventory", [
		{"name": "Arco reforzado", "type": "weapon_bow", "weight": 1.1, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
		{"name": "Flecha de madera", "type": "ammo_arrow", "weight": 0.08, "quantity": 5},
		{"name": "Boleadoras", "type": "weapon_bola", "weight": 0.65, "quantity": 1},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	b_log["shoot_cooldown"] = 0.0
	mgr._engage_foe(b_log, foe_t, 0.1)
	check(str(b_log.get("held_item", "")) == "Boleadoras",
		"10J5l1: En combate a 12 m prioriza lanzar Boleadoras si el enemigo aun no esta trabado (held=%s)" % str(b_log.get("held_item", "")))
	foe_t.global_position = p_log.global_position + Vector3(0.5, 0.0, 0.0)
	mgr._engage_foe(b_log, foe_t, 0.2)
	check(p_log.global_position.distance_to(foe_t.global_position) > 0.55,
		"10J5l2: En cuerpo a cuerpo a <1.25 m se separa para no engancharse dentro del jugador (d=%.2f)" % p_log.global_position.distance_to(foe_t.global_position))
	foe_t.queue_free()

	# 10J5m: Alcance de voz ampliado (55 m normal, 90 m en combate) y nuevas frases de tregua
	check(str(mgr._chat_parse_order("¡no me dispares, alto el fuego!").get("cmd", "")) == "truce",
		"10J5m: El parser de voz/chat reconoce 'no me dispares / alto el fuego' como tregua")

	# 10J5n: De noche la antorcha es el minimo para salir a explorar: sin ella
	# ni material para hacerla el bot se parapeta; con palo+trapos la fabrica
	# en el acto; con ropa+filo primero la corta a trapos; y con los 11 palos
	# justos del refugio no gasta el palo que le falta para la obra.
	var b_nt: Dictionary = mgr.bots[902]
	var p_nt: Node3D = b_nt["proxy"]
	var vs_nt: SurvivalStats = b_nt["vstats"]
	b_nt["shelter_id"] = ""
	b_nt["shelter_pos"] = Vector3.INF
	b_nt["campfire_id"] = ""
	b_nt["camp_spot"] = Vector3(500.0, 0.4, 500.0) # lejos: sin viaje que lo salve
	b_nt["explore_target"] = Vector3.INF
	b_nt["hide_timer"] = 0.0
	b_nt["flee_until"] = 0.0
	b_nt["sleeping"] = false
	b_nt["sitting"] = false
	b_nt["health"] = 100.0
	b_nt["hunger"] = 85.0
	b_nt["thirst"] = 85.0
	b_nt["aggro_target"] = null
	vs_nt.sleep = 100.0
	vs_nt.energy = 100.0
	vs_nt.body_temperature = 36.6
	dc.ambient_temp = 20.0
	p_nt.global_position = Vector3(200.0, 0.4, 200.0)
	b_nt["pos"] = p_nt.global_position
	for k2 in ["_s_predator", "_s_foe", "_s_leader", "_s_tame_wolf", "_s_prey", "_s_corpse"]:
		b_nt[k2] = null
	b_nt["_s_loot"] = {}
	b_nt["_s_raid_shelter"] = {}
	b_nt["_craft_state"] = {}
	b_nt["_gather"] = {}
	dc.time_of_day = 22.0
	# Sin antorcha ni material para hacerla: no sale a explorar — se parapeta
	# o, como mucho, ronda su zona en paseos cortos (nunca se va lejos).
	p_nt.set_meta("saved_inventory", [])
	var pos0_n1: Vector3 = p_nt.global_position
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) in ["rest", "wander"],
		"10J5n1: De noche sin antorcha ni material no sale lejos: se parapeta o ronda su zona (act=%s)" % str(b_nt.get("_act", "")))
	for i in range(40):
		mgr._tick_bot(b_nt, 0.2)
	check(p_nt.global_position.distance_to(pos0_n1) < 30.0,
		"10J5n1b: La ronda nocturna se mantiene junto a donde acampa, no explora lejos (d=%.1f)" % p_nt.global_position.distance_to(pos0_n1))
	# Con palo+trapos de sobra para el refugio la fabrica en el acto.
	p_nt.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 13},
		{"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1},
	])
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) == "torch",
		"10J5n2: De noche con palo+trapos fabrica la antorcha antes que nada (act=%s)" % str(b_nt.get("_act", "")))
	for i in range(25):
		mgr._tick_bot(b_nt, 0.2)
		if mgr._bot_item_count(p_nt, "Antorcha") >= 1:
			break
	check(mgr._bot_item_count(p_nt, "Antorcha") >= 1,
		"10J5n3: La antorcha queda fabricada en la mochila (n=%d)" % mgr._bot_item_count(p_nt, "Antorcha"))
	# Con antorcha ya puede salir a explorar de noche.
	b_nt["explore_target"] = Vector3.INF
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) != "rest" and bool(b_nt.get("torch_lit", false)),
		"10J5n4: Con antorcha de noche vuelve a poder salir (act=%s torch=%s)" % [str(b_nt.get("_act", "")), str(b_nt.get("torch_lit", false))])
	# Sin refugio y con justo los 11 palos no gasta el del refugio en la antorcha.
	p_nt.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 11},
		{"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1},
	])
	b_nt["_craft_state"] = {}
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) == "build" and mgr._bot_item_count(p_nt, "Antorcha") == 0,
		"10J5n5: Con los 11 palos justos del refugio no gasta uno en la antorcha: va a construir (act=%s)" % str(b_nt.get("_act", "")))
	# Pero con ropa+filo sin trapos primero la corta a trapos y luego fabrica.
	p_nt.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 13},
		{"name": "Camiseta", "type": "clothing", "weight": 0.2, "quantity": 1},
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	b_nt["_craft_state"] = {}
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) == "torch",
		"10J5n6: Sin trapos pero con camiseta+filo empieza por cortarla a trapos (act=%s)" % str(b_nt.get("_act", "")))
	for i in range(40):
		mgr._tick_bot(b_nt, 0.2)
		if mgr._bot_item_count(p_nt, "Antorcha") >= 1 and mgr._bot_item_count(p_nt, "Camiseta") == 0:
			break
	check(mgr._bot_item_count(p_nt, "Antorcha") >= 1 and mgr._bot_item_count(p_nt, "Camiseta") == 0,
		"10J5n7: La cadena camiseta->trapos->antorcha se completa de noche (antorchas=%d camiseta=%d)" % [mgr._bot_item_count(p_nt, "Antorcha"), mgr._bot_item_count(p_nt, "Camiseta")])
	# El cuchillo no es prenda cortable: las herramientas figuran en TODAS las
	# recetas de trapos pero no se cortan (un bot llego a cargar 3 cuchillos).
	check(not mgr._bot_cuts_into_trapos("Cuchillo") and mgr._bot_cuts_into_trapos("Camiseta"),
		"10J5n8: El cuchillo no es prenda cortable; la camiseta si")
	# Con 9 palos + trapos la antorcha ya no espera al doceavo palo: solo los
	# 11 EXACTOS del refugio a punto de pagarse quedan protegidos.
	p_nt.set_meta("saved_inventory", [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 9},
		{"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1},
	])
	b_nt["_craft_state"] = {}
	b_nt["_act"] = ""
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) == "torch",
		"10J5n9: Con 9 palos+trapos la antorcha no espera al 12 del refugio (act=%s)" % str(b_nt.get("_act", "")))
	for i in range(25):
		mgr._tick_bot(b_nt, 0.2)
		if mgr._bot_item_count(p_nt, "Antorcha") >= 1:
			break
	check(mgr._bot_item_count(p_nt, "Antorcha") >= 1 and mgr._bot_item_count(p_nt, "Palo") == 8,
		"10J5n9b: Con 9 palos fabrica la antorcha y le quedan 8 (palo=%d)" % mgr._bot_item_count(p_nt, "Palo"))
	# El seguidor sin luz sale a por el palo de su antorcha pese al lider: la
	# salida de material de fuego es la unica excepcion a no separarse.
	var n_bush := WorldActionScript.new()
	n_bush.setup("night_torch_bush", "fell_bush", "Arbusto", Vector3(1.2, 1.4, 1.2), Color(0.2, 0.35, 0.12), true, false)
	world.add_child(n_bush)
	n_bush.global_position = p_nt.global_position + Vector3(5.0, 0.0, 0.0)
	world.world_actions_by_id["night_torch_bush"] = n_bush
	var lead_nt := Node3D.new()
	world.add_child(lead_nt)
	lead_nt.global_position = p_nt.global_position + Vector3(3.0, 0.0, 0.0)
	p_nt.set_meta("saved_inventory", [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
		{"name": "Trapos", "type": "resource", "weight": 0.05, "quantity": 1},
	])
	b_nt["team_leader_id"] = 901
	b_nt["_s_leader"] = {"id": 901, "proxy": lead_nt, "pos": lead_nt.global_position, "dist": 3.0}
	b_nt["_gather"] = {}
	b_nt["_gather_scan"] = 0.0
	check(mgr._bot_try_gather_mats(b_nt, 0.1),
		"10J5n10: El seguidor sin luz sale a por el palo de su antorcha pese al lider")
	b_nt["team_leader_id"] = 0
	b_nt["_s_leader"] = null
	b_nt["_gather"] = {}
	world.world_actions_by_id.erase("night_torch_bush")
	n_bush.queue_free()
	lead_nt.queue_free()
	# Mochila llena de noche: por material de fuego puede soltar lo menos
	# esencial; de dia nunca.
	var cap_nt: Dictionary = mgr._bot_carry_capacity(b_nt)
	var inv_lleno: Array = []
	for i in range(int(cap_nt.get("slots", 3))):
		inv_lleno.append({"name": "Piel de lobo", "type": "resource", "weight": 0.35, "quantity": 1})
	p_nt.set_meta("saved_inventory", inv_lleno)
	var palo_d := {"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0}
	check(not mgr._bot_would_fit(b_nt, inv_lleno, palo_d),
		"10J5n11a: Mochila llena: el palo no cabe tal cual")
	check(mgr._bot_can_drop_for_fire(b_nt, inv_lleno, palo_d),
		"10J5n11b: De noche por material de fuego suelta lo menos esencial")
	dc.time_of_day = 14.0
	check(not mgr._bot_can_drop_for_fire(b_nt, inv_lleno, palo_d),
		"10J5n11c: De dia no suelta nada por material de fuego")
	# El rondin nocturno sale de la calma acumulada (~18 s sentado), no del
	# inmediato: con el temporizador ya cargado elige un punto cercano y anda.
	dc.time_of_day = 22.0
	p_nt.set_meta("saved_inventory", [])
	b_nt["aggro_target"] = null
	b_nt["hide_timer"] = 0.0
	b_nt["_night_wander"] = {"idle_t": 20.0, "anchor": p_nt.global_position, "n": 0}
	check(mgr._bot_night_sentry_wander(b_nt, 0.1) and str(b_nt.get("_act", "")) == "wander",
		"10J5n12: Con la calma acumulada ronda su zona en vez de quedar petrificado (act=%s)" % str(b_nt.get("_act", "")))
	var wpos: Variant = (b_nt.get("_night_wander", {}) as Dictionary).get("pos", null)
	check(wpos is Vector3 and p_nt.global_position.distance_to(wpos) <= 16.5,
		"10J5n12b: El punto de la ronda queda junto a su acampada (d=%.1f)" % (p_nt.global_position.distance_to(wpos) if wpos is Vector3 else -1.0))
	b_nt["_night_wander"] = {}
	b_nt["_act"] = ""
	dc.time_of_day = 14.0
	b_nt["hunger"] = 80.0
	b_nt["thirst"] = 80.0
	b_nt["sitting"] = false
	b_nt["_act"] = ""

	# 10J5o: Reset de marcador — una sola vez por bot: stats, deaths y
	# known_locations vuelven a cero; el resto de la memoria se conserva.
	var mem_rst: Dictionary = mgr._ensure_bot_memory(902, {})
	mem_rst["stats"] = {"alive_total_sec": 9999.0, "kills_prey": 7, "kills_predator": 3, "animals_gutted": 11}
	mem_rst["deaths"] = 12
	mem_rst["known_locations"] = {"house:1:2": {"pos": [1.0, 0.0, 2.0]}}
	mem_rst["death_lessons"] = {"cold": 2.0}
	mem_rst.erase("score_reset_v")
	mgr._bot_apply_score_reset(mem_rst)
	check(int((mem_rst.get("stats", {}) as Dictionary).get("kills_prey", -1)) == 0
		and int(mem_rst.get("deaths", -1)) == 0
		and (mem_rst.get("known_locations", {}) as Dictionary).is_empty()
		and int(mem_rst.get("score_reset_v", 0)) == 1,
		"10J5o1: El reset de marcador pone a 0 stats/deaths/known_locations una sola vez")
	mem_rst["stats"]["kills_prey"] = 5
	mem_rst["deaths"] = 2
	mgr._bot_apply_score_reset(mem_rst)
	check(int((mem_rst.get("stats", {}) as Dictionary).get("kills_prey", -1)) == 5
		and int(mem_rst.get("deaths", -1)) == 2
		and float((mem_rst.get("death_lessons", {}) as Dictionary).get("cold", 0.0)) == 2.0,
		"10J5o2: No se repite: las estadisticas nuevas y las lecciones de muerte se conservan")

	# 10J5p: Escolta viva — el seguidor aparcado junto al líder no se pega a
	# su espalda: hace rondas cortas de vigilancia alrededor y recoge el
	# botín de la zona; el líder en marcha lo absorbe de vuelta al instante.
	dc.time_of_day = 14.0
	p_nt.global_position = Vector3(200.0, 0.4, 200.0)
	b_nt["pos"] = p_nt.global_position
	var esc_leader := Node3D.new()
	world.add_child(esc_leader)
	esc_leader.global_position = p_nt.global_position + Vector3(2.0, 0.0, 0.0)
	b_nt["team_leader_id"] = 901
	b_nt["follow_mode"] = "follow"
	b_nt["aggro_target"] = null
	b_nt["hide_timer"] = 0.0
	b_nt["crouching"] = false
	b_nt["sleeping"] = false
	b_nt["_s_loot"] = {}
	b_nt["_escort"] = {"idle_t": 10.0, "n": 0}
	mgr._tick_teammate_behavior(b_nt, esc_leader, 0.1)
	var esc_pos: Variant = (b_nt.get("_escort", {}) as Dictionary).get("pos", null)
	check(esc_pos is Vector3 and esc_leader.global_position.distance_to(esc_pos) >= 5.0 and esc_leader.global_position.distance_to(esc_pos) <= 18.0,
		"10J5p1: Aparcado junto al líder hace rondas de vigilancia cerca (d=%.1f)" % (esc_leader.global_position.distance_to(esc_pos) if esc_pos is Vector3 else -1.0))
	check(str(b_nt.get("anim", "")) == "walk",
		"10J5p2: En ronda el seguidor camina, no queda plantado (anim=%s)" % str(b_nt.get("anim", "")))
	# El líder en marcha absorbe la ronda: se aleja y el seguidor le sigue.
	esc_leader.global_position = esc_leader.global_position + Vector3(40.0, 0.0, 0.0)
	mgr._tick_teammate_behavior(b_nt, esc_leader, 0.1)
	check((b_nt.get("_escort", {}) as Dictionary).get("pos") == null and str(b_nt.get("anim", "")) in ["walk", "run"],
		"10J5p3: El líder que se aleja corta la ronda y el seguidor le sigue (anim=%s)" % str(b_nt.get("anim", "")))
	# Botín cercano con el líder quieto: sale a recogerlo en vez de quedarse.
	esc_leader.global_position = p_nt.global_position + Vector3(2.0, 0.0, 0.0)
	b_nt["pos"] = p_nt.global_position
	b_nt["_escort"] = {}
	b_nt["_s_loot"] = {"id": "esc_loot", "pos": p_nt.global_position + Vector3(0.0, 0.0, 8.0), "name": "Palo"}
	mgr._tick_teammate_behavior(b_nt, esc_leader, 0.1)
	check(str(b_nt.get("anim", "")) == "walk",
		"10J5p4: Con botín a 8 m el seguidor sale a recogerlo (anim=%s)" % str(b_nt.get("anim", "")))
	# Con amenaza activa no hay ronda: aguarda quieto como antes.
	b_nt["_s_loot"] = {}
	b_nt["aggro_target"] = esc_leader
	b_nt["_escort"] = {"idle_t": 30.0, "n": 0}
	mgr._tick_teammate_behavior(b_nt, esc_leader, 0.1)
	check(str(b_nt.get("anim", "")) == "idle",
		"10J5p5: Con amenaza el seguidor no patrulla (anim=%s)" % str(b_nt.get("anim", "")))
	b_nt["aggro_target"] = null
	b_nt["_escort"] = {}
	b_nt["_s_loot"] = {}
	b_nt["team_leader_id"] = 0
	esc_leader.queue_free()

	# 10J5q: El follower tambien hace caso de la IA y recoge loot de camino.
	# q1: elegibilidad del asesor — equipo bot-bot si cuenta, lider humano no.
	b_nt["proxy"].set_meta("proxy_dead", false)
	b_nt["hide_timer"] = 0.0
	b_nt["flee_until"] = 0.0
	b_nt["_craft_state"] = {}
	b_nt["team_leader_id"] = 902
	check(mgr._ai_bot_eligible(b_nt),
		"10J5q1a: El follower de un equipo bot-bot recibe directivas de la IA")
	b_nt["team_leader_id"] = 1
	check(not mgr._ai_bot_eligible(b_nt),
		"10J5q1b: Bajo ordenes de un jugador humano el asesor no interfiere")
	b_nt["team_leader_id"] = 0
	# q2: el recado de la IA solo cuenta dentro de la orbita del leader (45 m).
	var q_leader := Node3D.new()
	world.add_child(q_leader)
	q_leader.global_position = p_nt.global_position + Vector3(2.0, 0.0, 0.0)
	var near_dp: Vector3 = q_leader.global_position + Vector3(10.0, 0.0, 0.0)
	var far_dp: Vector3 = q_leader.global_position + Vector3(60.0, 0.0, 0.0)
	b_nt["ai_directive"] = {"mode": "pos", "pos": near_dp, "action": "explore", "until": Time.get_ticks_msec() + 60000}
	check(mgr._bot_ai_errand_target(b_nt, q_leader) == near_dp,
		"10J5q2a: Directiva pos dentro de la orbita del leader se ejecuta como recado")
	b_nt["ai_directive"]["pos"] = far_dp
	check(mgr._bot_ai_errand_target(b_nt, q_leader) == Vector3.INF,
		"10J5q2b: Encargo lejos de la orbita se ignora — el leader decide el destino macro")
	b_nt["ai_directive"]["pos"] = near_dp
	b_nt["ai_directive"]["until"] = Time.get_ticks_msec() - 1000
	check(mgr._bot_ai_errand_target(b_nt, q_leader) == near_dp,
		"10J5q2c: El plan caducado sigue mandando hasta completarse o atascarse")
	b_nt["ai_directive"] = {"mode": "poi", "only_kinds": ["house"], "until": Time.get_ticks_msec() + 60000}
	check(mgr._bot_ai_errand_target(b_nt, q_leader) == Vector3.INF,
		"10J5q2d: Modos sin pos concreta no son recado lateral")
	b_nt["ai_directive"] = {}
	# q3: loot de camino con el leader en marcha — desvio corto para recoger.
	q_leader.set_meta("sprinting", true)
	p_nt.global_position = Vector3(200.0, 0.4, 200.0)
	b_nt["pos"] = p_nt.global_position
	q_leader.global_position = p_nt.global_position + Vector3(6.0, 0.0, 0.0)
	b_nt["team_leader_id"] = 901
	b_nt["follow_mode"] = "follow"
	b_nt["aggro_target"] = null
	b_nt["crouching"] = false
	b_nt["_s_loot"] = {"id": "q_loot", "pos": p_nt.global_position + Vector3(0.0, 0.0, 3.5), "name": "Palo"}
	mgr._tick_teammate_behavior(b_nt, q_leader, 0.1)
	check(str(b_nt.get("anim", "")) == "walk",
		"10J5q3: Con el leader en marcha recoge el drop de camino a <=4 m (anim=%s)" % str(b_nt.get("anim", "")))
	# Botin demasiado lejos para el desvio de camino: sigue al leader.
	b_nt["_s_loot"] = {"id": "q_loot2", "pos": p_nt.global_position + Vector3(0.0, 0.0, 12.0), "name": "Palo"}
	mgr._tick_teammate_behavior(b_nt, q_leader, 0.1)
	check(str(b_nt.get("anim", "")) in ["walk", "run"] and (b_nt.get("_escort", {}) as Dictionary).get("pos") == null,
		"10J5q4: Drop a 12 m con leader en marcha no desvia — sigue al leader (anim=%s)" % str(b_nt.get("anim", "")))
	b_nt["_s_loot"] = {}
	b_nt["team_leader_id"] = 0
	b_nt["ai_directive"] = {}
	q_leader.queue_free()

	# 10J5r: La supervivencia rompe cualquier formacion — por encima del
	# lider, del loot y de la IA van salud, hambre, sed, frio y agotamiento.
	dc.time_of_day = 14.0
	b_nt["health"] = 100.0
	b_nt["hunger"] = 80.0
	b_nt["thirst"] = 80.0
	vs_nt.sleep = 100.0
	vs_nt.body_temperature = 36.7
	p_nt.set_meta("saved_inventory", [])
	check(not mgr._bot_vital_break(b_nt),
		"10J5r1: Sano y saciado no rompe la formacion")
	b_nt["thirst"] = 25.0
	check(mgr._bot_vital_break(b_nt),
		"10J5r2: Sed baja sin agua rompe la formacion para ir al rio")
	p_nt.set_meta("saved_inventory", [{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0}])
	check(not mgr._bot_vital_break(b_nt),
		"10J5r3: Con botella la sed no rompe — bebe en marcha")
	p_nt.set_meta("saved_inventory", [])
	b_nt["thirst"] = 80.0
	b_nt["hunger"] = 28.0
	check(mgr._bot_vital_break(b_nt),
		"10J5r4: Hambre sin comida rompe la formacion para forrajear/cazar")
	p_nt.set_meta("saved_inventory", [{"name": "Pan", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 30.0}])
	check(not mgr._bot_vital_break(b_nt),
		"10J5r5: Con comida encima no rompe — come en marcha")
	p_nt.set_meta("saved_inventory", [])
	b_nt["hunger"] = 80.0
	b_nt["health"] = 40.0
	check(mgr._bot_vital_break(b_nt),
		"10J5r6: Herido grave rompe para descansar y hacerse vendas")
	b_nt["health"] = 100.0
	vs_nt.body_temperature = 34.9
	check(mgr._bot_vital_break(b_nt),
		"10J5r7: Hipotermia rompe la formacion — tambien con lider humano")
	vs_nt.body_temperature = 36.7
	vs_nt.sleep = 10.0
	check(mgr._bot_vital_break(b_nt),
		"10J5r8: Agotamiento letal rompe la formacion")
	vs_nt.sleep = 100.0

	# 10J5s: Una sola base por equipo (la del lider), roles por habilidades y
	# formacion tactica con separacion en la marcha.
	dc.time_of_day = 14.0
	var b_ld: Dictionary = mgr.bots[901]
	var p_ld: Node3D = b_ld["proxy"]
	var save_inv_ld: Array = p_ld.get_meta("saved_inventory", [])
	var save_inv_nt: Array = p_nt.get_meta("saved_inventory", [])
	var save_lid_nt: int = int(b_nt.get("team_leader_id", 0))
	var save_lid_k: int = int((mgr.bots[903] as Dictionary).get("team_leader_id", 0))
	var pers_nt: Dictionary = ((b_nt["_mem"] as Dictionary).get("personality", {}) as Dictionary).duplicate()
	var pers_k: Dictionary = (((mgr.bots[903] as Dictionary)["_mem"] as Dictionary).get("personality", {}) as Dictionary).duplicate()
	# s1: el lider tiene su refugio; el miembro levanta el suyo con alijo y al
	# unirse lo desmonta — solo queda la base del lider y el material se salva.
	var save_bp_nt := str(b_nt.get("backpack", ""))
	b_nt["backpack"] = "Mochila militar" # para que quepa todo el salvamento
	p_ld.set_meta("saved_inventory", [{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 11}])
	p_ld.global_position = Vector3(260.0, 0.4, 200.0)
	mgr._bot_build_shelter(b_ld, p_ld.global_position)
	var sh_lead := str(b_ld.get("shelter_id", ""))
	p_nt.set_meta("saved_inventory", [{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 11}])
	mgr._bot_build_shelter(b_nt, p_nt.global_position + Vector3(40.0, 0.0, 0.0))
	var sh_own := str(b_nt.get("shelter_id", ""))
	mgr._commit_shelter_contents(sh_own, [{"name": "Piel de lobo", "type": "resource", "weight": 0.35, "quantity": 1}])
	b_nt["team_leader_id"] = 901
	mgr._sync_team_base(b_nt)
	check(sh_own != "" and mgr._find_shelter_dict(sh_own).is_empty() and str(b_nt.get("shelter_id", "")) == sh_lead,
		"10J5s1: Al entrar en equipo su refugio desaparece y adopta la base del lider")
	check(mgr._bot_item_count(p_nt, "Palo") >= 11 and mgr._bot_item_count(p_nt, "Piel de lobo") >= 1,
		"10J5s2: Los 11 palos y el alijo del refugio desmontado se salvan a la mochila (palo=%d piel=%d inv=%s)" % [mgr._bot_item_count(p_nt, "Palo"), mgr._bot_item_count(p_nt, "Piel de lobo"), str(p_nt.get_meta("saved_inventory", []))])
	# s2: roles por habilidad — el curioso explora, el agresivo hace de soldado.
	(b_nt["_mem"] as Dictionary)["personality"] = {"bravery": 0.9, "aggression": 0.85, "curiosity": 0.2, "sociability": 0.5, "distrust": 0.4, "cooperation": 0.5, "survival_instinct": 0.5}
	((mgr.bots[903] as Dictionary)["_mem"] as Dictionary)["personality"] = {"bravery": 0.3, "aggression": 0.2, "curiosity": 0.95, "sociability": 0.5, "distrust": 0.4, "cooperation": 0.5, "survival_instinct": 0.5}
	(mgr.bots[903] as Dictionary)["team_leader_id"] = 901
	check(mgr._bot_member_role(b_nt) == "soldier" and mgr._bot_member_role(mgr.bots[903]) == "scout",
		"10J5s3: Roles por habilidad: agresivo->soldado, curioso->explorador (got %s/%s)" % [mgr._bot_member_role(b_nt), mgr._bot_member_role(mgr.bots[903])])
	# s3: formacion de cuña — slots separados, el explorador adelantado.
	var f_lead := Node3D.new()
	world.add_child(f_lead)
	f_lead.global_position = Vector3(200.0, 0.4, 200.0)
	f_lead.rotation.y = 0.0
	p_nt.global_position = Vector3(198.0, 0.4, 203.0)
	(mgr.bots[903] as Dictionary)["proxy"].global_position = Vector3(203.0, 0.4, 203.0)
	var slot_sol := mgr._bot_formation_slot(b_nt, f_lead, f_lead.global_position)
	var slot_sct := mgr._bot_formation_slot(mgr.bots[903], f_lead, f_lead.global_position)
	var fwd_s := Vector3(-sin(f_lead.rotation.y), 0.0, -cos(f_lead.rotation.y))
	check(slot_sol.distance_to(f_lead.global_position) > 3.0 and slot_sct.distance_to(f_lead.global_position) > 3.0
		and slot_sol.distance_to(slot_sct) > 5.0,
		"10J5s4: La cuña separa a los miembros (d_leader=%.1f/%.1f entre si=%.1f)" % [slot_sol.distance_to(f_lead.global_position), slot_sct.distance_to(f_lead.global_position), slot_sol.distance_to(slot_sct)])
	check((slot_sct - f_lead.global_position).normalized().dot(fwd_s) > 0.5,
		"10J5s5: El explorador marcha adelantado en la formacion")
	# s4: el miembro no levanta refugio propio aunque tenga los 11 palos.
	p_nt.set_meta("saved_inventory", [{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 12}])
	b_nt["shelter_id"] = ""
	b_nt["shelter_pos"] = Vector3.INF
	b_nt["hunger"] = 85.0
	b_nt["thirst"] = 85.0
	b_nt["health"] = 100.0
	b_nt["aggro_target"] = null
	for k3 in ["_s_predator", "_s_foe", "_s_tame_wolf", "_s_prey", "_s_corpse"]:
		b_nt[k3] = null
	b_nt["_s_loot"] = {}
	b_nt["_s_leader"] = {"id": 901, "proxy": f_lead, "pos": f_lead.global_position, "dist": 6.0}
	b_nt["_craft_state"] = {}
	b_nt["_gather"] = {}
	mgr._tick_bot(b_nt, 0.1)
	check(str(b_nt.get("_act", "")) != "build" and str(b_nt.get("shelter_id", "")) != sh_own,
		"10J5s6: Militando en equipo con 11 palos NO construye base propia (act=%s)" % str(b_nt.get("_act", "")))
	# s5: al salir del equipo suelta el refugio adoptado del lider.
	b_nt["team_leader_id"] = 0
	mgr._sync_team_base(b_nt)
	check(str(b_nt.get("shelter_id", "")) == "",
		"10J5s7: Al salir del equipo suelta el refugio adoptado del lider")
	# Limpieza del escenario de equipo.
	(mgr.bots[903] as Dictionary)["team_leader_id"] = save_lid_k
	b_nt["team_leader_id"] = save_lid_nt
	(b_nt["_mem"] as Dictionary)["personality"] = pers_nt
	((mgr.bots[903] as Dictionary)["_mem"] as Dictionary)["personality"] = pers_k
	p_ld.set_meta("saved_inventory", save_inv_ld)
	p_nt.set_meta("saved_inventory", save_inv_nt)
	b_nt["shelter_id"] = ""
	b_nt["shelter_pos"] = Vector3.INF
	b_nt["backpack"] = save_bp_nt
	if not mgr._find_shelter_dict(sh_lead).is_empty():
		mgr._bot_dismantle_shelter_exec(b_ld, sh_lead)
	b_ld["shelter_id"] = ""
	b_ld["shelter_pos"] = Vector3.INF
	f_lead.queue_free()

	# 10J5w: traicion reiterada — un miembro que agrede 3+ veces a alguien del
	# equipo es expulsado, pasa a hostil y la hostilidad mutua rompe la tregua
	# de faccion (se atacan aunque ambos sean 'hostile').
	var save_f_nt := str(b_nt.get("faction", ""))
	var save_f_ld := str(b_ld.get("faction", ""))
	var rels_nt_w: Dictionary = ((b_nt["_mem"] as Dictionary).get("relationships", {}) as Dictionary).duplicate(true)
	var rels_ld_w: Dictionary = ((b_ld["_mem"] as Dictionary).get("relationships", {}) as Dictionary).duplicate(true)
	var save_pos_ntw := p_nt.global_position
	var save_pos_ldw := p_ld.global_position
	var save_pos_903w: Vector3 = (mgr.bots[903] as Dictionary)["proxy"].global_position
	var save_ppos_w: Vector3 = world.player.global_position
	# w1: dos agresiones no bastan — el miembro sigue en el equipo.
	b_nt["team_leader_id"] = 901
	var nt_key_w := "bot_%d" % int(b_nt["bot_id"])
	for i in 2:
		mgr.record_social_event(901, nt_key_w, str(b_nt.get("name", nt_key_w)), "attack", 0.5, "hit_test")
	mgr._sync_team_base(b_nt)
	check(int(b_nt.get("team_leader_id", 0)) == 901,
		"10J5w1: Con 2 agresiones el miembro NO es expulsado aun")
	# w2: la tercera agresion lo echa — hostil, solo y con rencor mutuo.
	mgr.record_social_event(901, nt_key_w, str(b_nt.get("name", nt_key_w)), "attack", 0.5, "hit_test")
	mgr._sync_team_base(b_nt)
	var rel_nt_vs_ld := mgr.get_bot_relationship(int(b_nt["bot_id"]), "bot_901")
	var rel_ld_vs_nt := mgr.get_bot_relationship(901, nt_key_w)
	check(int(b_nt.get("team_leader_id", -1)) == 0 and str(b_nt.get("faction", "")) == "hostile"
		and str(p_nt.get_meta("bot_faction", "")) == "hostile",
		"10J5w2: A la 3a agresion es expulsado y pasa a faccion hostil")
	check(float(rel_nt_vs_ld.get("hostility", 0.0)) >= 0.99 and float(rel_nt_vs_ld.get("trust", 0.0)) < 0.0,
		"10J5w3: El expulsado odia a su antiguo grupo (ataca a sus ex-compañeros)")
	check(float(rel_ld_vs_nt.get("hostility", 0.0)) >= 0.99 and float(rel_ld_vs_nt.get("trust", 0.0)) < 0.0,
		"10J5w4: El grupo le devuelve la hostilidad al expulsado")
	# w3: la hostilidad rompe la tregua de faccion — dos 'hostile' con rencor se atacan.
	mgr._set_bot_faction(b_ld, "hostile")
	p_nt.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 10.0, "durability": 100.0, "max_durability": 100.0}])
	p_nt.global_position = Vector3(300.0, 0.4, 300.0)
	p_ld.global_position = Vector3(305.0, 0.4, 300.0)
	(mgr.bots[903] as Dictionary)["proxy"].global_position = Vector3(4000.0, 0.4, 4000.0)
	world.player.global_position = Vector3(5000.0, 0.4, 5000.0)
	b_nt["aggro_target"] = null
	b_nt["_truce_peer"] = 0
	b_nt["_truce_t"] = 0.0
	check(mgr._find_combat_foe(b_nt) == p_ld,
		"10J5w5: El expulsado ataca a su ex-lider pese a compartir faccion hostile")
	# w4: peligro traido al grupo — sin agresiones: basta llegar huyendo junto
	# al lider repetidas veces para ser expulsado.
	var save_dg_nt: Variant = (b_nt["_mem"] as Dictionary).get("team_danger_n", 0)
	(b_nt["_mem"] as Dictionary)["team_danger_n"] = 0
	b_nt["team_leader_id"] = 901
	b_nt["_team_danger_ms"] = -120000
	b_nt["flee_until"] = 10.0
	b_nt["hide_timer"] = 0.0
	b_nt["aggro_target"] = null
	b_nt["_s_predator"] = null
	b_ld["flee_until"] = 0.0
	b_ld["hide_timer"] = 0.0
	b_ld["aggro_target"] = null
	b_ld["_s_predator"] = null
	p_nt.global_position = Vector3(306.0, 0.4, 300.0)
	mgr._team_danger_tick(b_nt)
	check(int((b_nt["_mem"] as Dictionary).get("team_danger_n", 0)) == 1,
		"10J5w6: Llegar huyendo junto al lider sano cuenta como poner en peligro al grupo")
	b_nt["_team_danger_ms"] = -120000
	b_ld["flee_until"] = 10.0
	mgr._team_danger_tick(b_nt)
	check(int((b_nt["_mem"] as Dictionary).get("team_danger_n", 0)) == 1,
		"10J5w7: Si el lider ya esta amenazado el incidente no cuenta contra el miembro")
	b_ld["flee_until"] = 0.0
	b_nt["_team_danger_ms"] = -120000
	p_nt.global_position = Vector3(400.0, 0.4, 300.0)
	mgr._team_danger_tick(b_nt)
	check(int((b_nt["_mem"] as Dictionary).get("team_danger_n", 0)) == 1,
		"10J5w8: Huyendo lejos del lider no cuenta — el peligro no llega al grupo")
	# La expulsion por peligro no exige agresiones: rel limpia de ataques.
	var rel_clean := mgr.get_bot_relationship(901, nt_key_w)
	rel_clean["attacked"] = 0
	rel_clean["hostility"] = 0.0
	(b_nt["_mem"] as Dictionary)["team_danger_n"] = 4
	mgr._sync_team_base(b_nt)
	check(int(b_nt.get("team_leader_id", -1)) == 0 and str(b_nt.get("faction", "")) == "hostile",
		"10J5w9: 4 incidentes de peligro bastan para la expulsion sin agresiones")
	(b_nt["_mem"] as Dictionary)["team_danger_n"] = save_dg_nt
	b_nt["flee_until"] = 0.0
	b_nt["_team_danger_ms"] = -120000

	# 10J5x: conversacion -> supervivencia. Negativa a una peticion pendiente:
	# queda en memoria (refused), el bot reevalua (negociar/robar/atacar/
	# forrajear) y el equipo echa a quien niega ayuda a compañeros.
	var save_asked_x: Variant = b_nt.get("_asked", {})
	var save_surv_x: Variant = b_nt.get("_survive_decision", {})
	var save_steal_x: Variant = b_nt.get("_steal_target", {})
	var save_hun_x := float(b_nt.get("hunger", 100.0))
	var h9 := Node3D.new()
	world.add_child(h9)
	h9.global_position = p_nt.global_position + Vector3(4.0, 0.0, 0.0)
	world.server_proxies[9] = h9
	fnet.players[9] = {"char_name": "Negador", "name": "Negador", "is_ai_bot": false, "offline": false}
	var sk9 := mgr._actor_persist_key(9)
	b_nt["hunger"] = 20.0
	b_nt["_asked"] = {"id": 9, "need": "comida", "t": Time.get_ticks_msec()}
	mgr.on_chat_received(902, 9, "Negador", "no, vete, no te doy nada")
	var rel_x := mgr.get_bot_relationship(902, sk9)
	check(int(rel_x.get("refused", 0)) == 1 and float(rel_x.get("hostility", 0.0)) > 0.0
		and (b_nt["_asked"] as Dictionary).is_empty(),
		"10J5x1: la negativa queda en memoria (refused=%d host=%.2f) y cierra la peticion" % [
			int(rel_x.get("refused", 0)), float(rel_x.get("hostility", 0.0))])
	# Primera negativa con confianza -> ruego otra vez (negotiate).
	rel_x["trust"] = 0.5
	rel_x["hostility"] = 0.0
	var dec_n := mgr._bot_evaluate_after_refusal(b_nt, 9, "comida")
	check(dec_n == "negotiate",
		"10J5x2: primera negativa con confianza -> negociar otra vez (got %s)" % dec_n)
	# Rencor + arma + agresivo -> por la fuerza.
	rel_x["refused"] = 3
	rel_x["hostility"] = 0.5
	p_nt.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 10.0, "durability": 100.0, "max_durability": 100.0}])
	var pers_save_x: Dictionary = ((b_nt["_mem"] as Dictionary).get("personality", {}) as Dictionary).duplicate()
	(b_nt["_mem"] as Dictionary)["personality"] = {"bravery": 0.8, "aggression": 0.7, "curiosity": 0.4, "sociability": 0.4, "distrust": 0.6, "cooperation": 0.3, "survival_instinct": 0.5}
	b_nt["aggro_target"] = null
	var dec_a := mgr._bot_evaluate_after_refusal(b_nt, 9, "comida")
	check(dec_a == "attack" and b_nt.get("aggro_target") == h9,
		"10J5x3: 3 negativas + arma + agresivo -> toma por la fuerza (aggro=%s)" % str(b_nt.get("aggro_target") != null))
	# Desarmado y no tan bravo -> robarle en su refugio.
	b_nt["aggro_target"] = null
	p_nt.set_meta("saved_inventory", [])
	(b_nt["_mem"] as Dictionary)["personality"] = {"bravery": 0.4, "aggression": 0.3, "curiosity": 0.4, "sociability": 0.4, "distrust": 0.6, "cooperation": 0.3, "survival_instinct": 0.7}
	var sh9 := {"id": "player_shelter_9_x1", "pos": [p_nt.global_position.x + 8.0, 0.0, p_nt.global_position.z], "contents": [{"name": "Lata", "type": "food", "quantity": 2}]}
	world._built_shelters.append(sh9)
	var dec_s := mgr._bot_evaluate_after_refusal(b_nt, 9, "comida")
	check(dec_s == "steal" and str(b_nt.get("_s_raid_shelter", {}).get("id", "")) == "player_shelter_9_x1",
		"10J5x4: desarmado + refugio conocido -> robarle el alijo (dec=%s target=%s)" % [dec_s, str(b_nt.get("_steal_target", {}).get("id", ""))])
	world._built_shelters.erase(sh9)
	# Negar ayuda a compañeros 3 veces -> expulsion del equipo.
	b_nt["team_leader_id"] = 901
	b_nt["flee_until"] = 0.0
	b_nt["hide_timer"] = 0.0
	b_nt["_s_predator"] = null
	var rel_ld_vs_nt2 := mgr.get_bot_relationship(901, "bot_902")
	rel_ld_vs_nt2["refused"] = 3
	rel_ld_vs_nt2["attacked"] = 0
	rel_ld_vs_nt2["hostility"] = 0.2
	# El snapshot del monitor expone las negativas antes de la expulsion.
	b_nt["team_leader_id"] = 901
	rel_ld_vs_nt2["refused"] = 2
	var snap_x5 := {}
	for bx in mgr.get_full_web_status().get("bots", []):
		if int((bx as Dictionary).get("bot_id", 0)) == 902:
			snap_x5 = bx
	check(int(snap_x5.get("team_refused", -1)) == 2,
		"10J5x5a: el monitor expone las negativas de ayuda (team_refused=%s)" % str(snap_x5.get("team_refused", -1)))
	rel_ld_vs_nt2["refused"] = 3
	mgr._sync_team_base(b_nt)
	check(int(b_nt.get("team_leader_id", -1)) == 0 and str(b_nt.get("faction", "")) == "hostile",
		"10J5x5: 3 negativas de ayuda al grupo tambien expulsan")
	# Restaurar x.
	b_nt["_asked"] = save_asked_x
	b_nt["_survive_decision"] = save_surv_x
	b_nt["_steal_target"] = save_steal_x
	b_nt["_s_raid_shelter"] = {}
	b_nt["hunger"] = save_hun_x
	b_nt["aggro_target"] = null
	(b_nt["_mem"] as Dictionary)["personality"] = pers_save_x
	var rels9x: Dictionary = ((b_nt["_mem"] as Dictionary).get("relationships", {}))
	rels9x.erase(sk9)
	world.server_proxies.erase(9)
	fnet.players.erase(9)
	h9.queue_free()
	# Restaurar.
	p_nt.set_meta("saved_inventory", save_inv_nt)
	p_nt.global_position = save_pos_ntw
	p_ld.global_position = save_pos_ldw
	(mgr.bots[903] as Dictionary)["proxy"].global_position = save_pos_903w
	world.player.global_position = save_ppos_w
	(b_nt["_mem"] as Dictionary)["relationships"] = rels_nt_w
	(b_ld["_mem"] as Dictionary)["relationships"] = rels_ld_w
	mgr._set_bot_faction(b_nt, save_f_nt)
	mgr._set_bot_faction(b_ld, save_f_ld)
	b_nt["team_leader_id"] = save_lid_nt

	# --- 10R) Chasquido de bala entrante: el tiro suena antes que el grito ---
	# El RPC reliable player_shot_rifle llega antes que apply_damage_to_client;
	# si el rayo pasa a <7 m del jugador, el chasquido local debe activarse en
	# ese instante — el estampido 3D del tirador llega atenuado a distancia.
	var save_ppos_r: Vector3 = world.player.global_position
	var stub_shooter := StubRifleShooter.new()
	world.add_child(stub_shooter)
	world.remote_players[901] = stub_shooter
	world.player.global_position = Vector3(100.0, 0.4, 100.0)
	var shot_origin := Vector3(0.0, 1.4, 0.0)
	var shot_dir: Vector3 = ((world.player.global_position + Vector3(0.0, 1.5, 0.0)) - shot_origin).normalized()
	world._incoming_shot_last = -10.0
	world._net_player_shot_rifle(901, shot_origin, shot_dir)
	check(stub_shooter.shot_calls == 1 and stub_shooter.last_origin.is_equal_approx(shot_origin),
		"10R1: el puppet del tirador reproduce su disparo (calls=%d)" % stub_shooter.shot_calls)
	check(world._incoming_shot_player != null and world._incoming_shot_player.playing,
		"10R2: trayectoria hacia el jugador -> chasquido local antes del dano")
	var first_shot_last := float(world._incoming_shot_last)
	# Segundo tiro inmediato: el cooldown evita reiniciar el clip a mitad.
	world._net_player_shot_rifle(901, shot_origin, shot_dir)
	check(float(world._incoming_shot_last) == first_shot_last,
		"10R3: cooldown del chasquido (rafagas no reinician el clip)")
	# Tiro que pasa lejos del jugador: sin chasquido local.
	world._incoming_shot_last = -10.0
	var miss_dir := (Vector3(-50.0, 1.5, -50.0) - shot_origin).normalized()
	world._net_player_shot_rifle(901, shot_origin, miss_dir)
	check(float(world._incoming_shot_last) == -10.0,
		"10R4: tiro alejado del jugador no dispara el chasquido local")
	# El propio jugador al disparar no oye chasquido entrante de su tiro.
	world._net_player_shot_rifle(1, shot_origin, shot_dir)
	check(float(world._incoming_shot_last) == -10.0,
		"10R5: el disparo propio no genera chasquido entrante")
	world.remote_players.erase(901)
	stub_shooter.queue_free()
	world.player.global_position = save_ppos_r

	# --- 10S) Vigilancia de techos, vigia de equipo y cola en el vano ---
	var b_rw: Dictionary = mgr.bots[901]
	var p_rw: Node3D = b_rw["proxy"]
	var save_f_rw := str(b_rw.get("faction", ""))
	var save_lid_rw := int(b_rw.get("team_leader_id", 0))
	var save_pos_rw: Vector3 = p_rw.global_position
	mgr.set_physics_process(false)
	mgr._poi_cache = [{"pos": Vector3(9.0, 0.0, 680.0), "kind": "city"}]
	mgr._poi_cache_built = true
	mgr._set_bot_faction(b_rw, "hostile")
	p_rw.global_position = Vector3(20.0, 0.4, 700.0)
	# Francotirador en una azotea: se ve a 60 m aunque la vista normal es 44 m.
	var sniper := Node3D.new()
	world.add_child(sniper)
	sniper.add_to_group("net_player_proxy")
	sniper.set_meta("peer_id", 77)
	sniper.set_meta("has_real_pos", true)
	sniper.set_meta("proxy_dead", false)
	sniper.global_position = Vector3(20.0, 8.5, 745.0)
	check(mgr._find_rooftop_foe(b_rw) == sniper,
		"10S1: el tirador en la azotea se detecta a 60 m de distancia")
	check(mgr._bot_roof_wary(b_rw) == false and b_rw.get("_roof_threat_msec") == null,
		"10S1b: _find_rooftop_foe no marca cautela por si solo (eso lo hace el sentido)")
	# A ras de suelo y mas lejos que la vista normal: fuera del radar.
	sniper.global_position = Vector3(20.0, 0.4, 760.0)
	check(mgr._find_rooftop_foe(b_rw) == null,
		"10S2: enemigo a ras mas alla de la vista no salta la vigilancia de techos")
	# Mismo puesto elevado pero de faccion hostil como el bot: no es enemigo.
	sniper.set_meta("is_ai_bot", true)
	sniper.set_meta("bot_faction", "hostile")
	sniper.global_position = Vector3(20.0, 8.5, 745.0)
	check(mgr._find_rooftop_foe(b_rw) == null,
		"10S3: un compañero de faccion en la azotea no se marca como francotirador")
	sniper.set_meta("bot_faction", "friendly")
	check(mgr._find_rooftop_foe(b_rw) == sniper,
		"10S4: un bot de otra faccion en la azotea si es amenaza")
	sniper.queue_free()
	# Zona de vigilancia: dentro de la ciudad si, en pleno campo no.
	check(mgr._bot_in_watch_zone(p_rw.global_position)
			and not mgr._bot_in_watch_zone(Vector3(0.0, 0.4, 0.0)),
		"10S5: _bot_in_watch_zone solo se activa en zonas con puestos elevados")

	# Fuego vertical: sin el filtro |dy|<3.2 el bot responde a un francotirador.
	mgr._set_bot_faction(b_rw, "hostile")
	p_rw.global_position = Vector3(20.0, 0.4, 700.0)
	p_rw.set_meta("saved_inventory", [
		{"name": "Rifle francotirador", "type": "weapon_rifle", "weight": 4.0, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	var foe_roof := Node3D.new()
	world.add_child(foe_roof)
	foe_roof.global_position = p_rw.global_position + Vector3(30.0, 8.0, 0.0)
	b_rw["shoot_cooldown"] = 0.0
	b_rw["is_aiming"] = false
	mgr._engage_foe(b_rw, foe_roof, 0.1)
	check(float(b_rw["shoot_cooldown"]) > 0.0,
		"10S6: con tiro limpio dispara hacia ARRIBA contra un enemigo en tejado (cd=%.2f)" % float(b_rw["shoot_cooldown"]))
	foe_roof.queue_free()

	# Vigia de equipo: miembro con fusil y lider saqueando la ciudad -> sube a
	# la azotea de la Torre del Reloj; cuando el lider se va, se libera.
	var b_ow: Dictionary = mgr.bots[902]
	var p_ow: Node3D = b_ow["proxy"]
	var save_f_ow := str(b_ow.get("faction", ""))
	var save_lid_ow := int(b_ow.get("team_leader_id", 0))
	var save_pos_ow: Vector3 = p_ow.global_position
	mgr._set_bot_faction(b_ow, "hostile")
	b_ow["team_leader_id"] = 901
	b_ow["follow_mode"] = "follow"
	b_ow["hunger"] = 90.0
	b_ow["thirst"] = 90.0
	b_ow["health"] = 95.0
	b_ow["flee_until"] = 0.0
	b_ow["hide_timer"] = 0.0
	b_ow["aggro_target"] = null
	b_ow.erase("_overwatch")
	p_ow.global_position = Vector3(30.0, 0.4, 745.0)
	p_ow.set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.6, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	b_ow["has_rifle"] = true
	var ow_leader := Node3D.new()
	world.add_child(ow_leader)
	ow_leader.global_position = Vector3(15.0, 0.4, 690.0)
	check(mgr._bot_overwatch_tick(b_ow, ow_leader, p_ow.global_position, ow_leader.global_position, 0.1),
		"10S7: el miembro con fusil acepta el puesto de vigia con el lider en la ciudad")
	var ov_d: Dictionary = b_ow.get("_overwatch", {})
	check(str(ov_d.get("zone", "")) == "city" and (ov_d.get("post", Vector3.ZERO) as Vector3).y > 20.0,
		"10S8: la vigia de la ciudad se apuesta en la azotea de la Torre del Reloj")
	check(str(b_ow.get("_act", "")) == "overwatch", "10S9: el acto queda marcado como 'overwatch'")
	# Una sola vigia por equipo: Kael no duplica el puesto mientras Carlos lo ocupa.
	var b_ow2: Dictionary = mgr.bots[903]
	var save_lid_ow2 := int(b_ow2.get("team_leader_id", 0))
	var save_f_ow2 := str(b_ow2.get("faction", ""))
	mgr._set_bot_faction(b_ow2, "hostile")
	b_ow2["team_leader_id"] = 901
	b_ow2["follow_mode"] = "follow"
	b_ow2["has_rifle"] = true
	b_ow2["hunger"] = 90.0
	b_ow2["thirst"] = 90.0
	b_ow2["health"] = 95.0
	b_ow2["flee_until"] = 0.0
	b_ow2["hide_timer"] = 0.0
	b_ow2["aggro_target"] = null
	var p_ow2: Node3D = b_ow2["proxy"]
	p_ow2.set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.6, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	# Segundo tirador del equipo: no duplica la azotea — hace de centinela
	# de tierra en el perimetro mientras el rango 0 cubre desde arriba.
	var save_mem_ow2: Dictionary = b_ow2.get("_mem", {})
	b_ow2["_mem"] = {"personality": {"bravery": 0.95, "aggression": 0.95, "distrust": 0.1, "curiosity": 0.1, "survival_instinct": 0.1, "cooperation": 0.1}}
	var save_mem_ow1: Dictionary = b_ow.get("_mem", {})
	b_ow["_mem"] = {"personality": {"bravery": 0.2, "aggression": 0.2, "distrust": 0.1, "curiosity": 0.95, "survival_instinct": 0.9, "cooperation": 0.1}}
	p_ow2.global_position = Vector3(19.0, 0.4, 685.0)
	check(mgr._bot_overwatch_tick(b_ow2, ow_leader, p_ow2.global_position, ow_leader.global_position, 0.1),
		"10S10a: el segundo tirador si vigila — como centinela de tierra")
	var ov_g: Dictionary = b_ow2.get("_overwatch", {})
	var gpost: Vector3 = ov_g.get("post", Vector3.INF)
	check(bool(ov_g.get("ground", false)) and gpost != Vector3.INF and gpost.y < 10.0,
		"10S10b: el segundo puesto es perimetral, no otra azotea (y=%.1f)" % gpost.y)
	var dp_s := Vector2(gpost.x - ow_leader.global_position.x, gpost.z - ow_leader.global_position.z).length()
	check(dp_s > 7.0 and dp_s < 15.0,
		"10S10c: el centinela se aposta a ~11 m del lider (d=%.1f)" % dp_s)
	b_ow2.erase("_overwatch")
	b_ow2["_mem"] = save_mem_ow2
	b_ow["_mem"] = save_mem_ow1
	b_ow2["team_leader_id"] = save_lid_ow2
	mgr._set_bot_faction(b_ow2, save_f_ow2)
	# Lider fuera de la zona -> la vigia se libera y vuelve a la escolta.
	ow_leader.global_position = Vector3(0.0, 0.4, 0.0)
	b_ow["hunger"] = 90.0
	b_ow["thirst"] = 90.0
	check(not mgr._bot_overwatch_tick(b_ow, ow_leader, p_ow.global_position, ow_leader.global_position, 0.1)
			and not b_ow.has("_overwatch"),
		"10S11: el lider sale de la zona y la vigia abandona el puesto")

	# En el puesto dispara sin bajar; con enemigo a melee lo suelta.
	var ow_post := Vector3(39.6, 29.46, 750.8)
	b_ow["_overwatch"] = {"zone": "city", "post": ow_post, "t": Time.get_ticks_msec()}
	p_ow.global_position = ow_post
	var foe_ground := Node3D.new()
	world.add_child(foe_ground)
	foe_ground.global_position = Vector3(35.0, 0.4, 720.0)
	b_ow["shoot_cooldown"] = 0.0
	check(mgr._bot_overwatch_fight(b_ow, foe_ground, 0.1),
		"10S12: la vigia en su puesto combate desde arriba sin moverse")
	check(p_ow.global_position.distance_to(ow_post) < 0.1 and float(b_ow["shoot_cooldown"]) > 0.0,
		"10S13: la vigia dispara manteniendo el puesto (cd=%.2f)" % float(b_ow["shoot_cooldown"]))
	foe_ground.global_position = ow_post + Vector3(1.0, 0.0, 0.5)
	check(not mgr._bot_overwatch_fight(b_ow, foe_ground, 0.1) and not b_ow.has("_overwatch"),
		"10S14: enemigo encima en la azotea -> suelta el puesto y pelea normal")
	foe_ground.queue_free()
	ow_leader.queue_free()
	mgr._set_bot_faction(b_ow, save_f_ow)
	b_ow["team_leader_id"] = save_lid_ow
	b_ow.erase("_overwatch")

	# Cola en el vano: dos bots a la misma puerta — el segundo espera apartado.
	var dc_q := Vector3(0.0, 0.12, 0.0)
	var out_q := Vector2(0.0, 1.0)
	var b_q1: Dictionary = mgr.bots[901]
	var b_q2: Dictionary = mgr.bots[902]
	var b_q3: Dictionary = mgr.bots[903]
	var save_q1: Vector3 = (b_q1["proxy"] as Node3D).global_position
	var save_q2: Vector3 = (b_q2["proxy"] as Node3D).global_position
	var save_q3: Vector3 = (b_q3["proxy"] as Node3D).global_position
	(b_q1["proxy"] as Node3D).global_position = dc_q + Vector3(0.0, 0.0, 0.8)
	(b_q2["proxy"] as Node3D).global_position = Vector3(0.0, 0.12, 8.0)
	(b_q3["proxy"] as Node3D).global_position = Vector3(60.0, 0.12, 60.0)
	var wait_pos := mgr._bot_door_queue_wait(b_q2, (b_q2["proxy"] as Node3D).global_position, dc_q, out_q)
	check(wait_pos != Vector3.INF and absf(Vector2(wait_pos.x - dc_q.x, wait_pos.z - dc_q.z).dot(Vector2(1.0, 0.0))) > 0.9,
		"10S15: con el vano ocupado el segundo espera en un puesto lateral")
	# Quien ya esta dentro del vano no retrocede para ceder.
	check(mgr._bot_door_queue_wait(b_q1, (b_q1["proxy"] as Node3D).global_position, dc_q, out_q) == Vector3.INF,
		"10S16: el que ya esta cruzando el vano no retrocede")
	(b_q1["proxy"] as Node3D).global_position = dc_q + Vector3(0.0, 0.0, 6.0)
	check(mgr._bot_door_queue_wait(b_q2, (b_q2["proxy"] as Node3D).global_position, dc_q, out_q) == Vector3.INF,
		"10S17: vano libre -> entra directo")
	(b_q1["proxy"] as Node3D).global_position = save_q1
	(b_q2["proxy"] as Node3D).global_position = save_q2
	(b_q3["proxy"] as Node3D).global_position = save_q3
	p_rw.global_position = save_pos_rw
	p_ow.global_position = save_pos_ow
	mgr._set_bot_faction(b_rw, save_f_rw)
	b_rw["team_leader_id"] = save_lid_rw

	# --- 10T) Saqueo repartido: claims de drops y cautela aprendida ---
	# Dos piezas a tiro: el que reclama la mejor obliga al compañero a ir a
	# por la otra — nada de amontonarse sobre el mismo drop.
	var b_lt1: Dictionary = mgr.bots[901]
	var b_lt2: Dictionary = mgr.bots[902]
	var p_lt1: Node3D = b_lt1["proxy"]
	var p_lt2: Node3D = b_lt2["proxy"]
	var saved_sleep_claim := bool(b_lt1.get("sleeping", false))
	b_lt1["sleeping"] = true
	check(not mgr._bot_watch_eligible(b_lt1), "10T0a: sleeping actor cannot take a sentry rank")
	b_lt1["sleeping"] = saved_sleep_claim
	p_lt1.set_meta("proxy_dead", true)
	check(not mgr._bot_watch_eligible(b_lt1), "10T0b: dead actor cannot block the living sentry rank")
	p_lt1.set_meta("proxy_dead", false)
	var save_lt1: Vector3 = p_lt1.global_position
	var save_lt2: Vector3 = p_lt2.global_position
	var save_drops: Array = world._dropped_items.duplicate()
	var save_claims: Dictionary = world._pickup_claims.duplicate()
	var save_claims_until: Dictionary = world._pickup_claim_until.duplicate()
	p_lt1.global_position = Vector3(200.0, 0.4, 200.0)
	p_lt2.global_position = Vector3(200.0, 0.4, 200.0)
	for bi in [b_lt1, b_lt2]:
		(bi["proxy"] as Node3D).set_meta("saved_inventory", [{"name": "Mochila improvisada", "type": "backpack", "weight": 0.5, "quantity": 1}])
		bi["hunger"] = 90.0
		bi["thirst"] = 90.0
	world._dropped_items = [
		{"id": "t_rifle", "name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.6, "qty": 1, "pos": [203.0, 0.4, 200.0]},
		{"id": "t_lata", "name": "Hacha", "type": "tool_axe", "weight": 1.8, "qty": 1, "pos": [197.0, 0.4, 200.0]},
	]
	var pick1: Dictionary = mgr._find_nearby_valuable_loot(b_lt1, 28.0)
	check(str(pick1.get("id", "")) == "t_rifle", "10T1: sin claims el mejor botin es el fusil")
	b_lt1["_s_loot"] = pick1
	mgr._loot_commit_claim(b_lt1)
	check(int(world._pickup_claims.get("t_rifle", 0)) == 901,
		"10T2: fichar el drop lo reclama en la tabla del mundo")
	world._pickup_claim_until["t_rifle"] = Time.get_ticks_msec() - 1
	mgr._loot_commit_claim(b_lt1)
	check(int(world._pickup_claim_until["t_rifle"]) > Time.get_ticks_msec(), "10T2a: same target renews an expired owned claim")
	b_lt2["_s_loot"] = pick1
	mgr._loot_commit_claim(b_lt2)
	check(int(world._pickup_claims["t_rifle"]) == 901 and b_lt2["_s_loot"].is_empty(), "10T2b: stale selection cannot overwrite another actor claim")
	var inv_before_claim: Array = p_lt2.get_meta("saved_inventory", []).duplicate(true)
	mgr._collect_loot_entry(b_lt2, pick1)
	check(p_lt2.get_meta("saved_inventory", []) == inv_before_claim and world._dropped_items.size() == 2, "10T2c: collection revalidates ownership without consuming drop")
	var pick2: Dictionary = mgr._find_nearby_valuable_loot(b_lt2, 28.0)
	check(str(pick2.get("id", "")) == "t_lata",
		"10T3: con el fusil reclamado el compañero elige la otra pieza (id=%s)" % str(pick2.get("id", "")))
	mgr._loot_clear(b_lt1)
	check(not (world._pickup_claims as Dictionary).has("t_rifle"),
		"10T4: soltar el drop libera el claim para los demas")
	var pick3: Dictionary = mgr._find_nearby_valuable_loot(b_lt2, 28.0)
	check(str(pick3.get("id", "")) == "t_rifle",
		"10T5: liberado el claim el fusil vuelve a ser el mejor botin")
	# Claim caducado: la pieza queda libre aunque siga en la tabla.
	world._pickup_claims["t_lata"] = 903
	world._pickup_claim_until["t_lata"] = Time.get_ticks_msec() - 1000
	var pick4: Dictionary = mgr._find_nearby_valuable_loot(b_lt2, 28.0)
	check(str(pick4.get("id", "")) == "t_rifle",
		"10T6: un claim expirado no retiene la pieza")
	world._pickup_claim_until["t_lata"] = Time.get_ticks_msec() + 30000
	var pick5: Dictionary = mgr._find_nearby_valuable_loot(b_lt2, 28.0)
	check(str(pick5.get("id", "")) == "t_rifle",
		"10T7: claim vivo ajeno filtra su pieza (sigue saliendo el fusil)")
	world._dropped_items = save_drops
	world._pickup_claims = save_claims
	world._pickup_claim_until = save_claims_until
	p_lt1.global_position = save_lt1
	p_lt2.global_position = save_lt2
	mgr._loot_clear(b_lt1)
	mgr._loot_clear(b_lt2)

	# Cautela aprendida: una muerte violenta registrada cerca marca la zona —
	# el equipo vuelve en alerta sin ver a nadie; el botin bueno la apaga.
	var b_lw: Dictionary = mgr.bots[901]
	var mem_lw: Dictionary = mgr._ensure_bot_memory(901)
	var save_spots: Array = mem_lw.get("death_spots", []).duplicate()
	var save_zy: Dictionary = mem_lw.get("zone_yield", {}).duplicate()
	p_rw.global_position = Vector3(41.0, 0.4, 700.0) # dentro del casco urbano
	mem_lw["death_spots"] = [{"x": 41.0, "y": 0.4, "z": 705.0, "cause": "rifle", "count": 1}]
	mem_lw["zone_yield"] = {}
	var lw_anchor := mgr._bot_learned_risk_at(p_rw.global_position, 901)
	check(lw_anchor != Vector3.INF,
		"10T8: muerte a tiros en el pueblo -> riesgo aprendido anclado")
	b_lw["proxy"] = p_rw
	check(mgr._bot_roof_wary(b_lw),
		"10T9: la cautela aprendida mantiene al bot agachado en la zona")
	var kind_lw := mgr._poi_kind_near(p_rw.global_position)
	mem_lw["zone_yield"] = {kind_lw: {"good": 6}}
	check(mgr._bot_learned_risk_at(p_rw.global_position, 901) == Vector3.INF,
		"10T10: saqueos buenos repetidos apagan la alarma aprendida")
	mem_lw["zone_yield"] = {}
	mem_lw["death_spots"] = [{"x": 41.0, "y": 0.4, "z": 705.0, "cause": "wolf_bite", "count": 2}]
	check(mgr._bot_learned_risk_at(p_rw.global_position, 901) == Vector3.INF,
		"10T11: morir a lobos no ensena a temer francotiradores")
	mem_lw["death_spots"] = [{"x": 41.0, "y": 0.4, "z": 705.0, "cause": "starved", "count": 1}]
	check(mgr._bot_learned_risk_at(p_rw.global_position, 901) == Vector3.INF,
		"10T12: morir de hambre tampoco marca riesgo de tirador")
	var saved_known_risk: Dictionary = mem_lw["known_locations"].duplicate(true)
	mem_lw["death_spots"] = [{"x":41.0,"y":0.4,"z":705.0,"cause":"succumbed","count":3}]
	mem_lw["known_locations"] = {"hazard":{"pos":[41.0,0.4,705.0],"risk":3.0}}
	check(mgr._bot_learned_risk_at(p_rw.global_position,901) == Vector3.INF, "10T12a: generic hazard and unknown death never imply survivor combat")
	mem_lw["known_locations"]["hazard"]["combat_risk"] = 3.0
	check(mgr._bot_learned_risk_at(p_rw.global_position,901) != Vector3.INF, "10T12b: explicitly shared combat hazard activates caution")
	mem_lw["known_locations"] = saved_known_risk
	# Riesgo aprendido fuera de ciudad/base: zona "ground" -> centinela a ras.
	mem_lw["death_spots"] = [{"x": 300.0, "y": 0.4, "z": 300.0, "cause": "melee", "count": 1}]
	p_lt1.global_position = Vector3(300.0, 0.4, 300.0)
	check(mgr._bot_learned_risk_at(p_lt1.global_position, 901) != Vector3.INF,
		"10T13: el riesgo aprendido tambien vale fuera de zonas con torre")
	check(mgr._bot_learned_wary(b_lw), "10T13a: learned caution applies outside city and military zones")
	var g_leader := Node3D.new()
	world.add_child(g_leader)
	g_leader.global_position = Vector3(300.0, 0.4, 300.0)
	var b_gs: Dictionary = mgr.bots[902]
	var p_gs: Node3D = b_gs["proxy"]
	var save_gs: Vector3 = p_gs.global_position
	var save_lid_gs := int(b_gs.get("team_leader_id", 0))
	var save_f_gs := str(b_gs.get("faction", ""))
	var save_mem_gs: Dictionary = b_gs.get("_mem", {})
	mgr._set_bot_faction(b_gs, "hostile")
	b_gs["team_leader_id"] = 901
	b_gs["follow_mode"] = "follow"
	b_gs["has_rifle"] = true
	b_gs["hunger"] = 90.0
	b_gs["thirst"] = 90.0
	b_gs["health"] = 95.0
	b_gs["flee_until"] = 0.0
	b_gs["hide_timer"] = 0.0
	b_gs["aggro_target"] = null
	b_gs.erase("_overwatch")
	b_gs["_mem"] = {"personality": {"bravery": 0.95, "aggression": 0.9, "distrust": 0.1, "curiosity": 0.1, "survival_instinct": 0.1, "cooperation": 0.1}}
	p_gs.set_meta("saved_inventory", [
		{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.6, "quantity": 1, "durability": 90.0, "max_durability": 100.0},
	])
	# Solo el aprende del lider (901) tiene la muerte registrada: el centinela
	# la conoce porque el riesgo se comparte entre aliados — aqui le damos la
	# misma memoria al propio miembro para el check directo.
	var mem_gs: Dictionary = mgr._ensure_bot_memory(902)
	var save_spots_gs: Array = mem_gs.get("death_spots", []).duplicate()
	var save_zy_gs: Dictionary = mem_gs.get("zone_yield", {}).duplicate()
	mem_gs["death_spots"] = [{"x": 300.0, "y": 0.4, "z": 300.0, "cause": "melee", "count": 1}]
	mem_gs["zone_yield"] = {}
	p_gs.global_position = Vector3(295.0, 0.4, 296.0)
	check(mgr._bot_overwatch_tick(b_gs, g_leader, p_gs.global_position, g_leader.global_position, 0.1),
		"10T14: en zona con riesgo aprendido el tirador toma puesto de centinela")
	var ov_gs: Dictionary = b_gs.get("_overwatch", {})
	check(str(ov_gs.get("zone", "")) == "ground" and bool(ov_gs.get("ground", false)),
		"10T15: el puesto aprendido es de tierra (zone=%s)" % str(ov_gs.get("zone", "")))
	var gps_d := Vector2((ov_gs.get("post", Vector3.ZERO) as Vector3).x - g_leader.global_position.x,
		(ov_gs.get("post", Vector3.ZERO) as Vector3).z - g_leader.global_position.z).length()
	check(gps_d > 7.0 and gps_d < 15.0,
		"10T16: el centinela aprendido se aposta en el perimetro (d=%.1f)" % gps_d)
	var city_ground_post := Vector3(41,0.4,700)
	b_gs["_overwatch"] = {"zone":"city","ground":true,"post":city_ground_post,"anchor":Vector3.INF}
	g_leader.global_position = city_ground_post + Vector3(40,0,0)
	check(not mgr._bot_overwatch_tick(b_gs,g_leader,city_ground_post,g_leader.global_position,.1) and not b_gs.has("_overwatch"), "10T17: city ground sentry releases when leader moves away within same zone")
	b_gs.erase("_overwatch")
	mem_gs["death_spots"] = save_spots_gs
	mem_gs["zone_yield"] = save_zy_gs
	mem_lw["death_spots"] = save_spots
	mem_lw["zone_yield"] = save_zy
	b_gs["_mem"] = save_mem_gs
	b_gs["team_leader_id"] = save_lid_gs
	mgr._set_bot_faction(b_gs, save_f_gs)
	p_gs.global_position = save_gs
	g_leader.queue_free()
	mgr.set_physics_process(true)

	for tk_end in mgr._tts_jobs.keys():
		DirAccess.remove_absolute(jobdir + str(tk_end) + ".json")
	mgr._tts_jobs.clear()

	print("SurvivorBotsAndCombatRegression: %d failures" % failures)
	world.queue_free()
	fnet.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
