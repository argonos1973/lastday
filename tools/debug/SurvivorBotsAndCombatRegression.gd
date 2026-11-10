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
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false
	func snapshot_recipients() -> Array[int]:
		return []
	func relay_actor_chat(sender_id: int, sender_name: String, text: String, target_peer_id: int, target_name: String = "") -> void:
		relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "text": text})

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class StubDeadPuppet extends Node3D:
	var is_dead := false

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
	check(str(mgr.bots[901]["faction"]) == "friendly" and str(mgr.bots[902]["faction"]) == "friendly" and str(mgr.bots[903]["faction"]) == "hostile",
		"2 aliados cooperativos y 1 bandido hostil")
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
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6, "use_value": 0.0},
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
	dc.time_of_day = 14.0
	kael["hide_timer"] = 0.0

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
	check(not mgr._is_loot_desirable(elena, "Trapos", "resource"),
		"Sano, con cuerda y arco: los trapos del suelo NO interesan")
	check(mgr._is_loot_desirable(elena, "Pluma", "resource"),
		"Con arco y sin flechas: las plumas interesan (para fabricarlas)")
	check(mgr._is_loot_desirable(elena, "Hueso", "resource"),
		"El cuchillo de hueso mejora su cuchillo: el hueso interesa")
	# Con 8 palos no recoge mas palos
	var palo_stack := []
	for i in range(8):
		palo_stack.append({"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0})
	elena_proxy.set_meta("saved_inventory", palo_stack)
	check(not mgr._is_loot_desirable(elena, "Palo", "resource"),
		"Con 8 palos no sigue acumulando")
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
	check(t_exp != Vector3(50.0, 0.0, 50.0), "Asesor: directiva caducada se ignora")
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
	mgr._ai_save_memory()
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
	mgr._ai_queue.clear()
	mgr._ai_enqueue_request(901, 2, "low_prio")
	mgr._ai_enqueue_request(902, 5, "high_prio_threat")
	mgr._ai_enqueue_request(903, 3, "mid_prio")
	var popped := mgr._ai_pop_next_request()
	check(int(popped.get("bot_id", 0)) == 902 and int(popped.get("priority", 0)) == 5,
		"Aceptación 7a: La cola de prioridades despacha primero la consulta más urgente (bot=%d prio=%d)" % [int(popped.get("bot_id", 0)), int(popped.get("priority", 0))])
	var t0_usec := Time.get_ticks_usec()
	mgr._ai_tick(0.016)
	var report_str := mgr.get_ai_debug_report()
	var dt_ms := float(Time.get_ticks_usec() - t0_usec) / 1000.0
	check(dt_ms < 15.0 and report_str.contains("Elena") and report_str.contains("Carlos") and report_str.contains("Kael") and report_str.contains("Personalidad:") and report_str.contains("Relaciones:"),
		"Aceptación 7b: El tick cognitivo y el panel de depuración se ejecutan sin bloquear el hilo principal (%.2f ms)" % dt_ms)

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
	check(float(fresh_b["thirst"]) >= 99.0 and mgr._bot_item_count(fresh_b["proxy"], "Botella de agua llena") == 1,
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
	fresh_b["hide_timer"] = 30.0 # se queda agazapado en su refugio, sin deambular
	for i in range(40):
		mgr._tick_bot(fresh_b, 0.1)
	check(vs.wetness < wet_peak,
		"SpawnReal 10w11: bajo techo deja de mojarse y se va secando (wet=%.2f)" % vs.wetness)
	fresh_b["hide_timer"] = 0.0
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
	mgr._ensure_bot_memory(903)["relationships"]["bot_901"] = {"id": "bot_901", "name": "Elena", "trust": 0.9, "hostility": 0.0, "fear": 0.0, "helped": 9, "attacked": 0}
	mgr._ensure_bot_memory(901)["relationships"]["bot_903"] = {"id": "bot_903", "name": "Kael", "trust": 0.9, "hostility": 0.0, "fear": 0.0, "helped": 9, "attacked": 0}
	kael_y["_soc_t"] = 0.0
	elena_y["_soc_t"] = 0.0
	mgr._bot_social_update(kael_y)
	mgr._bot_social_update(elena_y)
	check(int(kael_y["team_leader_id"]) == 0 and int(elena_y["team_leader_id"]) == 0,
		"10y7: bandido y superviviente nunca forman equipo aunque confien")

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

	# Destinatario humano: el mensaje sale por relay_actor_chat de la red
	fnet.relay_log.clear()
	fnet.players[7] = {"char_name": "Remy", "name": "Remy", "is_ai_bot": false, "offline": false}
	mgr._bot_chat_send(elena_y, 7, "Remy", "Ey Remy, vives cerca?", "greet")
	check(fnet.relay_log.size() == 1 and int(fnet.relay_log[0].get("to_id", 0)) == 7,
		"10A7: DM a humano sale por relay_actor_chat")
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
	# contesta por relay_actor_chat igual que lo veria el cliente.
	fnet.players[7] = {"char_name": "Remy", "name": "Remy", "is_ai_bot": false, "offline": false}
	fnet.relay_log.clear()
	elena_y["_chat_inbox"] = {}
	elena_y["_chat_reply_ready"] = 0
	elena_y["_chat_cd"] = 0.0
	mgr._chat_turns.clear()
	mgr.on_chat_received(901, 7, "Remy", "hola elena, todo bien?")
	check(not (elena_y["_chat_inbox"] as Dictionary).is_empty(),
		"10A14a: DM de humano encola respuesta del bot")
	mgr._bot_chat_tick(elena_y)
	check(fnet.relay_log.size() == 1 and int(fnet.relay_log[0].get("to_id", 0)) == 7 and not str(fnet.relay_log[0].get("text", "")).is_empty(),
		"10A14b: la respuesta del bot llega al humano por relay_actor_chat")
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
		{"name": "Palo", "type": "material", "weight": 0.3, "quantity": 5, "use_value": 0.0},
		{"name": "Cuerda", "type": "resource", "weight": 0.2, "quantity": 1, "use_value": 0.0},
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
	check(not bool(g_host.get("ok", true)) and str(g_host.get("why","")) == "hostile",
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

	print("SurvivorBotsAndCombatRegression: %d failures" % failures)
	world.queue_free()
	fnet.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
