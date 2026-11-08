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
		return 1.0 if water_rect.has_point(Vector2(pos.x, pos.z)) else 0.0
	func _is_on_road(pos: Vector3) -> bool:
		return road_rect.has_point(Vector2(pos.x, pos.z))
	func _is_player_in_house(_pos: Vector3) -> bool:
		return false
	func _default_river_segments() -> Array:
		return river_segs
	func _net_player_hit_event(peer_id: int, kind: String, pos: Vector3) -> void:
		hit_events.append({"id": peer_id, "kind": kind, "pos": pos})

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

	# --- 3) Construccion de refugio + camuflaje/pieles + fogata y antorcha nocturna ---
	var kael: Dictionary = mgr.bots[903]
	var kael_proxy: Node3D = kael["proxy"]
	kael_proxy.global_position = kael["camp_spot"]
	kael["pos"] = kael["camp_spot"]
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

	print("SurvivorBotsAndCombatRegression: %d failures" % failures)
	world.queue_free()
	fnet.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
