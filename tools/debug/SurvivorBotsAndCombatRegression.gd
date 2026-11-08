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
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float:
		return 0.4

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

	print("SurvivorBotsAndCombatRegression: %d failures" % failures)
	world.queue_free()
	fnet.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
