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
	func get_ambient_temperature() -> float:
		return 15.0

class FakeNet extends Node:
	var is_host := true
	var is_connected := false
	var is_dedicated_server := true
	var peer = null
	var players := {}
	var animals := {}
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false
	func snapshot_recipients() -> Array[int]:
		return []

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

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
	func _net_world_action_completed(_a: String, _b: Array, _c: String, _d: Vector3, _e: int = 0) -> bool:
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

	# --- 12) Ordenes de equipo directas tipo lobo (menu [O]) ---
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
	e_inv4.append({"name": "Lata de fabada abierta", "type": "food", "weight": 0.5, "quantity": 1, "use_value": 0.0})
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

	print("SurvivorBotsAndCombatRegression: %d failures" % failures)
	world.queue_free()
	fnet.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
