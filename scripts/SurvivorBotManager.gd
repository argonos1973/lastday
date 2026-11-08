extends Node
class_name SurvivorBotManager

# Gestor de Supervivientes IA (bots con modelo, ropa, inventario y acciones reales):
# - 2 cooperativos ("Elena", "Carlos") que pueden reclutarse al equipo del jugador ([F]),
#   compartir fogata/refugio, recibir comida/agua, defender al compañero frente a lobos,
#   osos y bandidos, y domar lobos.
# - 1 bandido hostil ("Kael") que saquea tiendas militares, monta su refugio camuflado
#   con fogata, doma lobos y ataca o tiende emboscadas a jugadores y aliados.

const BOT_CONFIGS := [
	{
		"bot_id": 901,
		"client_id": "ai_bot_901",
		"name": "Elena",
		"faction": "friendly",
		"hair_style": "ponytail",
		"beard_stage": 0,
		"top_color": Color(0.22, 0.38, 0.28),
		"bottom_color": Color(0.24, 0.26, 0.30),
		"shoes_color": Color(0.16, 0.14, 0.12),
		"hair_color": Color(0.26, 0.15, 0.08),
		"skin_color": Color(0.84, 0.72, 0.62),
		"top_camo": false,
		"bottom_camo": false,
		"spawn": Vector3(22.0, 0.0, 12.0),
		"camp_spot": Vector3(19.0, 0.0, 26.0),
		"patrol": [
			Vector3(22.0, 0.0, 12.0),
			Vector3(36.0, 0.0, 22.0),
			Vector3(-18.0, 0.0, 26.0),
			Vector3(-24.0, 0.0, -14.0),
			Vector3(28.0, 0.0, -28.0),
		],
		"starting_clothing": ["Chaqueta de otoño", "Pantalones de senderismo", "Botas de montaña"],
		"starting_backpack": "Mochila pequena",
		"starting_weapon": "Cuchillo",
		"starting_items": [
			{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "use_value": 0.0},
			{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
			{"name": "Cerillas", "type": "tool_matches", "weight": 0.1, "quantity": 1, "use_value": 0.0, "durability": 10.0, "max_durability": 10.0},
			{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0},
			{"name": "Carne asada en palo", "type": "food", "weight": 0.3, "quantity": 2, "use_value": 28.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
			{"name": "Venda", "type": "medical", "weight": 0.1, "quantity": 2, "use_value": 30.0},
			{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6, "use_value": 0.0},
			{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 4, "use_value": 0.0},
			{"name": "Cuerda", "type": "resource", "weight": 0.25, "quantity": 2, "use_value": 0.0},
		],
	},
	{
		"bot_id": 902,
		"client_id": "ai_bot_902",
		"name": "Carlos",
		"faction": "friendly",
		"hair_style": "short",
		"beard_stage": 2,
		"top_color": Color(0.32, 0.28, 0.20),
		"bottom_color": Color(0.20, 0.24, 0.18),
		"shoes_color": Color(0.14, 0.12, 0.10),
		"hair_color": Color(0.18, 0.12, 0.07),
		"skin_color": Color(0.78, 0.66, 0.55),
		"top_camo": false,
		"bottom_camo": false,
		"spawn": Vector3(-28.0, 0.0, 34.0),
		"camp_spot": Vector3(-34.0, 0.0, 44.0),
		"patrol": [
			Vector3(-28.0, 0.0, 34.0),
			Vector3(-42.0, 0.0, 14.0),
			Vector3(-32.0, 0.0, -34.0),
			Vector3(40.0, 0.0, 112.0),
			Vector3(12.0, 0.0, 68.0),
		],
		"starting_clothing": ["Chaqueta de campaña azul", "Pantalones cargo con rodilleras", "Botas survival", "Guantes de trabajo"],
		"starting_backpack": "Mochila pequena",
		"starting_weapon": "Hacha",
		"starting_items": [
			{"name": "Hacha", "type": "tool_axe", "weight": 1.2, "quantity": 1, "use_value": 0.0},
			{"name": "Lanza", "type": "weapon", "weight": 1.1, "quantity": 1, "use_value": 0.0},
			{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
			{"name": "Cerillas", "type": "tool_matches", "weight": 0.1, "quantity": 1, "use_value": 0.0, "durability": 10.0, "max_durability": 10.0},
			{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0},
			{"name": "Lata de guiso", "type": "food", "weight": 0.5, "quantity": 2, "use_value": 35.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0},
			{"name": "Venda", "type": "medical", "weight": 0.1, "quantity": 2, "use_value": 30.0},
			{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6, "use_value": 0.0},
			{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 4, "use_value": 0.0},
			{"name": "Cuerda", "type": "resource", "weight": 0.25, "quantity": 2, "use_value": 0.0},
		],
	},
	{
		"bot_id": 903,
		"client_id": "ai_bot_903",
		"name": "Kael",
		"faction": "hostile",
		"hair_style": "buzz",
		"beard_stage": 3,
		"top_color": Color(0.18, 0.22, 0.14),
		"bottom_color": Color(0.28, 0.24, 0.15),
		"shoes_color": Color(0.10, 0.10, 0.08),
		"hair_color": Color(0.14, 0.10, 0.06),
		"skin_color": Color(0.75, 0.62, 0.50),
		"top_camo": true,
		"bottom_camo": true,
		"spawn": Vector3(68.0, 0.0, -75.0),
		"camp_spot": Vector3(76.0, 0.0, -84.0),
		"patrol": [
			Vector3(68.0, 0.0, -75.0),
			Vector3(44.0, 0.0, -28.0),
			Vector3(32.0, 0.0, 24.0),
			Vector3(-28.0, 0.0, -18.0),
			Vector3(52.0, 0.0, 95.0),
		],
		"starting_clothing": ["Chaqueta de campaña verde", "Pantalones camuflaje desert", "Botas militares", "Chaleco táctico", "Casco militar", "Guantes militares"],
		"starting_backpack": "Mochila militar",
		"starting_weapon": "Fusil de asalto",
		"starting_items": [
			{"name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.1, "quantity": 1, "use_value": 0.0},
			{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "quantity": 1, "use_value": 0.0},
			{"name": "Antorcha", "type": "tool_torch", "weight": 0.5, "quantity": 1, "use_value": 0.0, "durability": 600.0, "max_durability": 600.0},
			{"name": "Cerillas", "type": "tool_matches", "weight": 0.1, "quantity": 1, "use_value": 0.0, "durability": 10.0, "max_durability": 10.0},
			{"name": "Carne cruda de lobo", "type": "food", "weight": 0.3, "quantity": 4, "use_value": 15.0},
			{"name": "Lata de guiso", "type": "food", "weight": 0.5, "quantity": 2, "use_value": 35.0},
			{"name": "Tela de camuflaje", "type": "material", "weight": 0.8, "quantity": 1, "use_value": 0.0},
			{"name": "Piel de lobo", "type": "resource", "weight": 0.65, "quantity": 4, "use_value": 0.0},
			{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 6, "use_value": 0.0},
			{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 4, "use_value": 0.0},
			{"name": "Cuerda", "type": "resource", "weight": 0.25, "quantity": 2, "use_value": 0.0},
		],
	},
]

const CLOTHING_PRIORITY := {
	"Camiseta": 1, "Chaqueta de cuadros": 2, "Chaqueta de otoño": 3,
	"Chaqueta militar digital": 4, "Chaqueta camuflaje": 4, "Chaqueta camuflaje desert": 4,
	"Chaqueta de campaña verde": 5, "Chaqueta de campaña azul": 5, "Chaqueta de campaña arena": 5,
	"Chaqueta de piel": 6,
	"Pantalones": 1, "Pantalones de senderismo": 3, "Pantalones cargo con rodilleras": 4,
	"Pantalones militares": 4, "Pantalones camuflaje": 5, "Pantalones camuflaje desert": 5,
	"Pantalones de piel": 6,
	"Zapatillas": 1, "Botas survival": 3, "Botas de montaña": 4, "Botas militares": 5, "Botas de piel": 6,
	"Guantes de trabajo": 2, "Guantes survival": 3, "Guantes militares": 4, "Guantes de piel": 5,
	"Gorra militar": 2, "Gorro de otoño": 2, "Sombrero de pescador": 3, "Gorro de piel": 4,
	"Casco militar": 5, "Tocado de piel animal": 5,
	"Chaleco táctico": 6,
}

var world: Node = null
var bots: Dictionary = {} # bot_id -> Dictionary state
var _sync_accum := 0.0
var _ai_accum := 0.0

func setup(main_world: Node) -> void:
	world = main_world
	spawn_all_bots()

static func is_bot_peer_id(pid: int) -> bool:
	return pid >= 901 and pid <= 909

func spawn_all_bots() -> void:
	if world == null:
		return
	for cfg in BOT_CONFIGS:
		_spawn_bot(cfg)

func _spawn_bot(cfg: Dictionary) -> void:
	var bot_id := int(cfg["bot_id"])
	if bots.has(bot_id):
		return
	var spawn_pos: Vector3 = cfg["spawn"]
	if world.has_method("_get_exact_ground_y"):
		spawn_pos.y = maxf(world._get_exact_ground_y(spawn_pos.x, spawn_pos.z), 0.35)
	var patrol: Array = []
	for pt in cfg.get("patrol", []):
		var v: Vector3 = pt
		if world.has_method("_get_exact_ground_y"):
			v.y = maxf(world._get_exact_ground_y(v.x, v.z), 0.35)
		patrol.append(v)
	if world.get("_military_tent_pos") is Vector3 and world._military_tent_pos != Vector3.ZERO:
		var mt: Vector3 = world._military_tent_pos
		patrol.append(Vector3(mt.x, maxf(world._get_exact_ground_y(mt.x, mt.z), 0.35), mt.z))
	var camp_spot: Vector3 = cfg.get("camp_spot", spawn_pos + Vector3(6.0, 0.0, 6.0))
	if world.has_method("_get_exact_ground_y"):
		camp_spot.y = maxf(world._get_exact_ground_y(camp_spot.x, camp_spot.z), 0.35)

	var proxy := Node3D.new()
	proxy.name = "ServerProxy_%d" % bot_id
	proxy.position = spawn_pos
	proxy.set_meta("peer_id", bot_id)
	proxy.set_meta("client_id", str(cfg["client_id"]))
	proxy.set_meta("is_ai_bot", true)
	proxy.set_meta("bot_name", str(cfg["name"]))
	proxy.set_meta("bot_faction", str(cfg["faction"]))
	proxy.set_meta("team_leader_id", 0)
	proxy.set_meta("bot_follow_mode", "follow")
	proxy.set_meta("protection_timer", 0.0)
	proxy.set_meta("has_real_pos", true)
	proxy.set_meta("disconnected", false)
	proxy.set_meta("reconnecting", false)
	proxy.set_meta("proxy_health", 100.0)
	proxy.set_meta("saved_health", 100.0)
	proxy.set_meta("saved_hunger", 95.0)
	proxy.set_meta("saved_thirst", 95.0)
	proxy.set_meta("proxy_dead", false)

	var inv_items: Array = (cfg.get("starting_items", []) as Array).duplicate(true)
	var cloth_arr: Array = (cfg.get("starting_clothing", []) as Array).duplicate()
	var cloth_str := ",".join(cloth_arr)
	var bp_str := str(cfg.get("starting_backpack", "Mochila pequena"))
	var held_str := str(cfg.get("starting_weapon", "Cuchillo"))

	proxy.set_meta("saved_inventory", inv_items)
	proxy.set_meta("saved_clothing", cloth_str)
	proxy.set_meta("saved_backpack", bp_str)
	proxy.set_meta("saved_held_item", held_str)
	proxy.set_meta("saved_extra", {
		"stats_extra": {"survival_seconds": float(cfg.get("beard_stage", 0)) * 15000.0, "energy": 100.0, "sleep": 100.0, "body_temperature": 36.8},
		"rifle_ammo": {"initialized": true, "m4_initialized": true, "m4_magazine": 30, "m4_reserve": 90, "magazine": 5, "reserve": 20},
	})

	world.add_child(proxy)
	proxy.global_position = spawn_pos
	proxy.add_to_group("net_player_proxy")
	proxy.add_to_group("ai_survivor_bot")
	if "server_proxies" in world:
		world.server_proxies[bot_id] = proxy

	var bot_state := {
		"bot_id": bot_id,
		"client_id": str(cfg["client_id"]),
		"name": str(cfg["name"]),
		"faction": str(cfg["faction"]), # "friendly" | "hostile"
		"proxy": proxy,
		"cfg": cfg,
		"pos": spawn_pos,
		"rot": 0.0,
		"anim": "idle",
		"clothing": cloth_str,
		"clothing_colors": [],
		"backpack": bp_str,
		"held_item": held_str,
		"is_aiming": false,
		"has_rifle": held_str == "Fusil de asalto" or held_str == "Rifle francotirador",
		"sleeping": false,
		"sitting": false,
		"prone": false,
		"crouching": false,
		"torch_lit": false,
		"flashlight_on": false,
		"health": 100.0,
		"hunger": 95.0,
		"thirst": 95.0,
		"patrol": patrol,
		"patrol_idx": 0,
		"path": [],
		"path_idx": 0,
		"path_timer": 0.0,
		"state": "patrol",
		"attack_cooldown": 0.0,
		"shoot_cooldown": 0.0,
		"tame_cooldown": 0.0,
		"eat_cooldown": 0.0,
		"cook_cooldown": 0.0,
		"camp_spot": camp_spot,
		"shelter_id": "",
		"shelter_pos": Vector3.INF,
		"campfire_id": "",
		"campfire_pos": Vector3.INF,
		"hide_timer": 0.0,
		"team_leader_id": 0, # 0 = libre, >0 = peer_id del jugador líder (1 en SP/host)
		"follow_mode": "follow", # "follow" | "stay" | "guard"
		"stay_pos": spawn_pos,
		"aggro_target": null,
		"aggro_timer": 0.0,
		"respawn_timer": 0.0,
	}
	bots[bot_id] = bot_state
	_publish_bot_to_net_players(bot_state)
	# Si estamos en singleplayer o host con render, crear su avatar visual inmediatamente
	if world.get("net") == null or not world.net.is_dedicated_server:
		if world.has_method("_spawn_remote_player"):
			world._spawn_remote_player(bot_id)
			_apply_local_avatar_metadata(bot_state)

func _apply_local_avatar_metadata(b: Dictionary) -> void:
	if world == null or not ("remote_players" in world):
		return
	var bot_id := int(b["bot_id"])
	if not world.remote_players.has(bot_id):
		return
	var rp: Node3D = world.remote_players[bot_id]
	if rp == null or not is_instance_valid(rp):
		return
	rp.set_meta("is_ai_bot", true)
	rp.set_meta("bot_id", bot_id)
	rp.set_meta("bot_name", str(b["name"]))
	rp.set_meta("bot_faction", str(b["faction"]))
	rp.set_meta("team_leader_id", int(b["team_leader_id"]))
	rp.set_meta("bot_follow_mode", str(b["follow_mode"]))
	if not rp.is_in_group("interactable"):
		rp.add_to_group("interactable")

func _publish_bot_to_net_players(b: Dictionary) -> void:
	if world == null or world.get("net") == null:
		return
	var net = world.net
	var bot_id := int(b["bot_id"])
	var cfg: Dictionary = b["cfg"]
	net.players[bot_id] = {
		"name": str(b["name"]),
		"char_name": str(b["name"]),
		"hair_style": str(cfg.get("hair_style", "short")),
		"beard_stage": int(cfg.get("beard_stage", 0)),
		"top_color": cfg.get("top_color", Color(0.3, 0.35, 0.28)),
		"bottom_color": cfg.get("bottom_color", Color(0.22, 0.24, 0.26)),
		"shoes_color": cfg.get("shoes_color", Color(0.14, 0.12, 0.10)),
		"hair_color": cfg.get("hair_color", Color(0.2, 0.14, 0.08)),
		"skin_color": cfg.get("skin_color", Color(0.8, 0.68, 0.56)),
		"top_camo": bool(cfg.get("top_camo", false)),
		"bottom_camo": bool(cfg.get("bottom_camo", false)),
		"pos": b["pos"],
		"rot": float(b["rot"]),
		"anim": str(b["anim"]),
		"equipped_clothing": str(b["clothing"]),
		"clothing_colors": b["clothing_colors"],
		"held_item": str(b["held_item"]),
		"equipped_backpack": str(b["backpack"]),
		"is_aiming": bool(b["is_aiming"]),
		"has_rifle": bool(b["has_rifle"]),
		"sleeping": bool(b["sleeping"]),
		"sitting": bool(b["sitting"]),
		"prone": bool(b["prone"]),
		"crouching": bool(b["crouching"]),
		"torch_lit": bool(b["torch_lit"]),
		"flashlight_on": bool(b["flashlight_on"]),
		"ready": true,
		"in_world": true,
		"offline": false,
		"is_ai_bot": true,
		"bot_faction": str(b["faction"]),
		"team_leader_id": int(b["team_leader_id"]),
		"bot_follow_mode": str(b["follow_mode"]),
		"last_seen": Time.get_ticks_msec(),
	}

func tick(delta: float) -> void:
	if world == null:
		return
	var net = world.get("net")
	# Solo la instancia con autoridad (servidor dedicado, host o singleplayer) simula la IA
	if net != null and net.is_connected and not net.is_host:
		_refresh_client_bot_avatars()
		return
	for bot_id in bots.keys():
		_tick_bot(bots[bot_id], delta)
	_sync_accum += delta
	if _sync_accum >= 0.10:
		_sync_accum = fmod(_sync_accum, 0.10)
		_broadcast_bots()

func _refresh_client_bot_avatars() -> void:
	if world == null or world.get("net") == null or not ("remote_players" in world):
		return
	for pid in world.net.players.keys():
		var pdata: Dictionary = world.net.players[pid]
		if not bool(pdata.get("is_ai_bot", false)) and not is_bot_peer_id(int(pid)):
			continue
		if world.remote_players.has(pid):
			var rp: Node3D = world.remote_players[pid]
			if rp != null and is_instance_valid(rp):
				rp.set_meta("is_ai_bot", true)
				rp.set_meta("bot_id", int(pid))
				rp.set_meta("bot_name", str(pdata.get("char_name", pdata.get("name", "Superviviente"))))
				rp.set_meta("bot_faction", str(pdata.get("bot_faction", "friendly" if int(pid) != 903 else "hostile")))
				rp.set_meta("team_leader_id", int(pdata.get("team_leader_id", 0)))
				rp.set_meta("bot_follow_mode", str(pdata.get("bot_follow_mode", "follow")))
				if not rp.is_in_group("interactable"):
					rp.add_to_group("interactable")

func _broadcast_bots() -> void:
	if world == null:
		return
	var net = world.get("net")
	for bot_id in bots.keys():
		var b: Dictionary = bots[bot_id]
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		if net != null and net.is_host and net.is_connected and net.peer != null:
			for pid in net.snapshot_recipients():
				if is_bot_peer_id(pid):
					continue
				net.sync_player_state.rpc_id(
					pid, bot_id, b["pos"], float(b["rot"]), str(b["anim"]),
					str(b["clothing"]), str(b["held_item"]), str(b["backpack"]),
					bool(b["is_aiming"]), bool(b["has_rifle"]),
					bool(b["sleeping"]), bool(b["sitting"]), bool(b["prone"]), bool(b["crouching"]),
					bool(b["torch_lit"]), bool(b["flashlight_on"]), b["clothing_colors"]
				)
		elif (net == null or not net.is_connected) and world.has_method("_update_remote_players"):
			world._update_remote_players()

func _tick_bot(b: Dictionary, delta: float) -> void:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	if bool(proxy.get_meta("proxy_dead", false)):
		b["anim"] = "dead"
		b["torch_lit"] = false
		b["is_aiming"] = false
		b["respawn_timer"] = float(b.get("respawn_timer", 0.0)) + delta
		if float(b["respawn_timer"]) >= 180.0:
			_respawn_bot(b)
		return

	# Sincronizar vida real desde el proxy (por si recibió daño de lobo, oso o jugador)
	var live_hp := float(proxy.get_meta("proxy_health", 100.0))
	if live_hp < float(b["health"]) - 0.5:
		# Recibió daño recientemente: salir de descanso/ocultación para defenderse o huir
		b["sitting"] = false
		b["sleeping"] = false
		b["hide_timer"] = 0.0
	b["health"] = live_hp

	b["attack_cooldown"] = maxf(0.0, float(b["attack_cooldown"]) - delta)
	b["shoot_cooldown"] = maxf(0.0, float(b["shoot_cooldown"]) - delta)
	b["tame_cooldown"] = maxf(0.0, float(b["tame_cooldown"]) - delta)
	b["eat_cooldown"] = maxf(0.0, float(b["eat_cooldown"]) - delta)
	b["cook_cooldown"] = maxf(0.0, float(b["cook_cooldown"]) - delta)
	b["aggro_timer"] = maxf(0.0, float(b["aggro_timer"]) - delta)
	if float(b["aggro_timer"]) <= 0.0:
		b["aggro_target"] = null

	# Necesidades básicas y autocuración/alimentación
	b["hunger"] = maxf(10.0, float(b["hunger"]) - delta * 0.025)
	b["thirst"] = maxf(10.0, float(b["thirst"]) - delta * 0.030)
	_maintain_bot_needs(b, delta)

	# Luz nocturna con antorcha (se apaga si se está ocultando en su refugio)
	var is_night := _is_world_night()
	var sh_pos: Vector3 = b["shelter_pos"]
	var camp_pos: Vector3 = b["camp_spot"]
	var hiding_in_shelter: bool = float(b["hide_timer"]) > 0.0 and sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 2.6
	b["torch_lit"] = is_night and not hiding_in_shelter and _bot_has_item(proxy, "Antorcha")
	proxy.set_meta("torch_lit", bool(b["torch_lit"]))
	proxy.set_meta("in_built_shelter", sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 3.4)

	# 1) Detectar amenazas inmediatas: lobos/osos hostiles cercanos
	var predator := _find_threatening_predator(b, 22.0)
	if predator != null:
		_handle_predator_encounter(b, predator, delta)
		return

	# 2) Doma de lobos: si hay un lobo salvaje cerca (10..22 m), tenemos carne cruda y aún no tenemos lobo domado
	if float(b["tame_cooldown"]) <= 0.0 and not _bot_has_tamed_wolf(b):
		var wild_wolf := _find_tameable_wolf(b, 20.0)
		if wild_wolf != null and _bot_has_raw_meat(proxy):
			_perform_wolf_taming_step(b, wild_wolf, delta)
			return

	# 3) Combate contra enemigos humanos / otros bots de facción opuesta
	var human_foe := _find_combat_foe(b)
	if human_foe != null:
		# Si está gravemente herido (< 28 HP) y tiene refugio, se repliega a ocultarse en su refugio
		if float(b["health"]) < 28.0 and sh_pos != Vector3.INF:
			b["hide_timer"] = 20.0
			_move_bot_towards(b, sh_pos, 5.2, delta, "run")
			if proxy.global_position.distance_to(sh_pos) < 1.8:
				b["crouching"] = true
				b["sitting"] = true
				b["anim"] = "sit"
			return
		_engage_foe(b, human_foe, delta)
		return

	b["is_aiming"] = false

	# 4) Si está reclutado en el equipo de un jugador, obedecer órdenes de equipo
	var leader := _resolve_team_leader(b)
	if leader != null:
		_tick_teammate_behavior(b, leader, delta)
		return

	# 5) Saqueo oportuno de objetos cercanos (comida, armas, ropa mejor, materiales)
	var loot_action := _find_nearby_valuable_loot(b, 28.0)
	if not loot_action.is_empty():
		b["sitting"] = false
		b["crouching"] = false
		var lpos := _loot_entry_pos(loot_action)
		var d_loot := Vector2(proxy.global_position.x - lpos.x, proxy.global_position.z - lpos.z).length()
		if d_loot <= 2.1:
			_collect_loot_entry(b, loot_action)
		else:
			_move_bot_towards(b, lpos, 4.4, delta, "run")
		return

	# 6) Construir campamento propio (refugio + camuflaje/pieles + fogata) y ocultarse/descansar
	if str(b["shelter_id"]).is_empty() and _can_bot_build_shelter(proxy):
		var d_camp := Vector2(proxy.global_position.x - camp_pos.x, proxy.global_position.z - camp_pos.z).length()
		if d_camp > 2.4:
			_move_bot_towards(b, camp_pos, 3.8, delta, "walk")
			return
		_bot_build_shelter(b, camp_pos)
		return

	if not str(b["shelter_id"]).is_empty() and str(b["campfire_id"]).is_empty() and _can_bot_build_campfire(proxy):
		var fire_spot: Vector3 = sh_pos + Vector3(2.8, 0.0, 1.4)
		if world.has_method("_get_exact_ground_y"):
			fire_spot.y = maxf(world._get_exact_ground_y(fire_spot.x, fire_spot.z), 0.35)
		_bot_build_and_light_campfire(b, fire_spot)
		return

	# De noche o con poca salud o emboscando (bandido), el superviviente vuelve a su refugio,
	# enciende la fogata, cocina carne y se oculta dentro del refugio
	var wants_camp: bool = is_night or float(b["health"]) < 65.0 or float(b["hide_timer"]) > 0.0
	if sh_pos != Vector3.INF and wants_camp:
		b["hide_timer"] = maxf(0.0, float(b["hide_timer"]) - delta)
		var d_sh := Vector2(proxy.global_position.x - sh_pos.x, proxy.global_position.z - sh_pos.z).length()
		if d_sh > 1.8:
			_move_bot_towards(b, sh_pos, 3.8, delta, "walk")
			return
		# Dentro del refugio: encender fogata si se apagó, asar carne y descansar/ocultarse
		_ensure_bot_campfire_lit(b)
		if float(b["cook_cooldown"]) <= 0.0 and _bot_has_raw_meat(proxy):
			_bot_cook_meat_at_fire(b)
		b["sitting"] = true
		b["crouching"] = str(b["faction"]) == "hostile"
		b["anim"] = "sit"
		if float(b["health"]) < 100.0:
			var healed := minf(100.0, float(b["health"]) + delta * 1.8)
			b["health"] = healed
			proxy.set_meta("proxy_health", healed)
			proxy.set_meta("saved_health", healed)
		return

	# 7) Patrulla activa por el mapa buscando suministros y cazando
	b["sitting"] = false
	b["crouching"] = false
	var patrol: Array = b["patrol"]
	if patrol.is_empty():
		b["anim"] = "idle"
		return
	var p_idx := int(b["patrol_idx"]) % patrol.size()
	var goal: Vector3 = patrol[p_idx]
	if Vector2(proxy.global_position.x - goal.x, proxy.global_position.z - goal.z).length() < 2.6:
		b["patrol_idx"] = (p_idx + 1) % patrol.size()
		goal = patrol[int(b["patrol_idx"])]
	var move_item := "Antorcha" if bool(b["torch_lit"]) else _best_weapon_name(proxy)
	b["held_item"] = move_item
	b["has_rifle"] = move_item == "Fusil de asalto" or move_item == "Rifle francotirador"
	proxy.set_meta("saved_held_item", move_item)
	_move_bot_towards(b, goal, 3.4, delta, "walk")

func _maintain_bot_needs(b: Dictionary, _delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	# Vendarse si tiene poca salud o sangrado
	if float(b["health"]) < 72.0 and float(b["eat_cooldown"]) <= 0.0:
		for i in range(inv.size()):
			var it = inv[i]
			if it is Dictionary and str(it.get("name", "")) == "Venda" and int(it.get("quantity", 1)) > 0:
				it["quantity"] = int(it.get("quantity", 1)) - 1
				if int(it["quantity"]) <= 0:
					inv.remove_at(i)
				var new_hp := minf(100.0, float(b["health"]) + 32.0)
				b["health"] = new_hp
				proxy.set_meta("proxy_health", new_hp)
				proxy.set_meta("saved_health", new_hp)
				proxy.set_meta("saved_inventory", inv)
				b["eat_cooldown"] = 8.0
				break
	# Comer si tiene hambre o necesita recuperar vida
	if (float(b["hunger"]) < 60.0 or float(b["health"]) < 80.0) and float(b["eat_cooldown"]) <= 0.0:
		for i in range(inv.size()):
			var it = inv[i]
			if not (it is Dictionary):
				continue
			var nm := str(it.get("name", ""))
			if str(it.get("type", "")) == "food" and not nm.begins_with("Carne cruda") and nm != "Carne humana":
				it["quantity"] = int(it.get("quantity", 1)) - 1
				if int(it["quantity"]) <= 0:
					inv.remove_at(i)
				b["hunger"] = minf(100.0, float(b["hunger"]) + 35.0)
				var new_hp := minf(100.0, float(b["health"]) + 14.0)
				b["health"] = new_hp
				proxy.set_meta("proxy_health", new_hp)
				proxy.set_meta("saved_health", new_hp)
				proxy.set_meta("saved_inventory", inv)
				b["eat_cooldown"] = 10.0
				break
	# Auto-equipar mejor ropa o mochila que haya saqueado
	_auto_equip_best_gear(b)

func _auto_equip_best_gear(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var current_clothes: Array = str(b["clothing"]).split(",", false)
	var by_slot := {}
	for entry in current_clothes:
		var clean := str(entry).strip_edges().split("|")[0]
		var slot := str(PlayerController.CLOTHING_SLOTS.get(clean, ""))
		if not slot.is_empty():
			by_slot[slot] = entry.strip_edges()
	var changed := false
	for it in inv:
		if not (it is Dictionary):
			continue
		var nm := str(it.get("name", ""))
		var tp := str(it.get("type", ""))
		if tp == "backpack" and nm == "Mochila militar" and str(b["backpack"]) != "Mochila militar":
			b["backpack"] = "Mochila militar"
			proxy.set_meta("saved_backpack", "Mochila militar")
			changed = true
		elif tp == "clothing" and PlayerController.CLOTHING_SLOTS.has(nm):
			var slot := str(PlayerController.CLOTHING_SLOTS[nm])
			var cur_entry := str(by_slot.get(slot, ""))
			var cur_clean := cur_entry.split("|")[0]
			var cur_score := int(CLOTHING_PRIORITY.get(cur_clean, 0))
			var new_score := int(CLOTHING_PRIORITY.get(nm, 1))
			if new_score > cur_score:
				var pelt := str(it.get("pelt_species", ""))
				by_slot[slot] = (nm + "|" + pelt) if not pelt.is_empty() else nm
				changed = true
	if changed:
		var updated := PackedStringArray()
		for k in by_slot.keys():
			updated.append(str(by_slot[k]))
		b["clothing"] = ",".join(updated)
		proxy.set_meta("saved_clothing", str(b["clothing"]))

func _find_threatening_predator(b: Dictionary, max_dist: float) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var leader := _resolve_team_leader(b)
	var best: Node3D = null
	var best_d := max_dist
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not (w is Node3D) or not is_instance_valid(w) or bool(w.get("_is_dead")):
			continue
		var at := str(w.get("animal_type"))
		if at != "wolf" and at != "bear":
			continue
		var tamed := str(w.get("tamed_to"))
		if not tamed.is_empty():
			# Si es el lobo domado del propio bot o de su líder aliado, no es amenaza
			if tamed == str(b["bot_id"]) or (leader != null and (tamed == "local" or tamed == str(b["team_leader_id"]))):
				continue
		var d := proxy.global_position.distance_to((w as Node3D).global_position)
		var d_leader := leader.global_position.distance_to((w as Node3D).global_position) if leader != null else 9999.0
		var eff_d := minf(d, d_leader)
		if eff_d < best_d:
			best_d = eff_d
			best = w as Node3D
	return best

func _handle_predator_encounter(b: Dictionary, predator: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	var weapon := _best_weapon_name(proxy)
	b["held_item"] = weapon
	var is_rifle := weapon == "Fusil de asalto" or weapon == "Rifle francotirador"
	b["has_rifle"] = is_rifle
	proxy.set_meta("saved_held_item", weapon)

	var ppos := predator.global_position
	var dist := proxy.global_position.distance_to(ppos)
	var to_pred := ppos - proxy.global_position
	to_pred.y = 0.0
	if to_pred.length_squared() > 0.001:
		b["rot"] = atan2(-to_pred.x, -to_pred.z)
		proxy.rotation.y = float(b["rot"])

	# Si lleva fusil y está a > 4 m, dispara al depredador retrocediendo para mantener distancia
	if is_rifle and dist > 3.6:
		b["is_aiming"] = true
		if dist < 8.5 and to_pred.length_squared() > 0.01:
			var back_goal := proxy.global_position - to_pred.normalized() * 5.0
			_move_bot_towards(b, back_goal, 3.6, delta, "walk")
			b["rot"] = atan2(-to_pred.x, -to_pred.z)
		else:
			b["anim"] = "idle"
		if float(b["shoot_cooldown"]) <= 0.0:
			b["shoot_cooldown"] = 0.95 if weapon == "Fusil de asalto" else 1.65
			var dmg := 68.0 if weapon == "Fusil de asalto" else 145.0
			_bot_fire_rifle_at(b, predator, dmg)
		return

	b["is_aiming"] = false
	var melee_reach := 4.0 if weapon in ["Lanza", "Lanza de hueso", "Palo afilado", "Hacha"] else 3.5
	if dist <= melee_reach:
		# Paso lateral ágil mientras golpea para no quedarse quieto bajo las fauces
		var side := Vector3(-to_pred.z, 0.0, to_pred.x).normalized() if to_pred.length_squared() > 0.01 else Vector3.RIGHT
		_move_bot_towards(b, proxy.global_position + side * 2.2, 3.4, delta, "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION)
		b["rot"] = atan2(-to_pred.x, -to_pred.z)
		if float(b["attack_cooldown"]) <= 0.0:
			b["attack_cooldown"] = 0.55
			var m_dmg := _weapon_melee_damage(weapon)
			if predator.has_method("take_damage"):
				predator.take_damage(m_dmg, true, proxy)
			# Si lo mata, lo destripa automáticamente para aprovechar carne y pieles
			if bool(predator.get("_is_dead")):
				_bot_harvest_dead_animal(b, predator)
	else:
		_move_bot_towards(b, ppos, 4.9, delta, "run")

func _bot_harvest_dead_animal(b: Dictionary, animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal) or bool(animal.get("_gutted")):
		return
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var kind := str(animal.get("animal_type"))
	var meat_name := "Carne cruda de ciervo" if kind == "deer" else ("Carne cruda de oso" if kind == "bear" else "Carne cruda de lobo")
	var hide_name := "Piel de ciervo" if kind == "deer" else ("Piel de oso" if kind == "bear" else "Piel de lobo")
	_bot_add_inventory_item(inv, {"name": meat_name, "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0})
	_bot_add_inventory_item(inv, {"name": hide_name, "type": "resource", "weight": 0.65, "quantity": 2, "use_value": 0.0})
	proxy.set_meta("saved_inventory", inv)
	if world != null and world.has_method("_net_gut_animal"):
		world._net_gut_animal(animal.name, int(b["bot_id"]), false)

func _find_tameable_wolf(b: Dictionary, max_dist: float) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not (w is Node3D) or not is_instance_valid(w) or bool(w.get("_is_dead")):
			continue
		if str(w.get("animal_type")) != "wolf" or not str(w.get("tamed_to")).is_empty():
			continue
		var d := proxy.global_position.distance_to((w as Node3D).global_position)
		if d >= 5.5 and d <= max_dist:
			return w as Node3D
	return null

func _bot_has_tamed_wolf(b: Dictionary) -> bool:
	if world == null or world.get_tree() == null:
		return false
	var key := str(b["bot_id"])
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if is_instance_valid(w) and not bool(w.get("_is_dead")) and str(w.get("animal_type")) == "wolf" and str(w.get("tamed_to")) == key:
			return true
	return false

func _perform_wolf_taming_step(b: Dictionary, wolf: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	# Sostener carne en la mano pacifica al lobo salvaje (_player_holds_meat)
	var meat_name := _first_raw_meat_name(proxy)
	if meat_name.is_empty():
		return
	b["held_item"] = meat_name
	b["has_rifle"] = false
	proxy.set_meta("saved_held_item", meat_name)

	var wpos := wolf.global_position
	var d := proxy.global_position.distance_to(wpos)
	if d > 11.5:
		_move_bot_towards(b, wpos, 3.2, delta, "walk")
		return
	# Soltar la pieza de carne en el suelo con dropped_by = str(bot_id)
	if _consume_bot_item(proxy, meat_name, 1):
		var drop_pos := proxy.global_position.lerp(wpos, 0.38)
		if world.has_method("_get_exact_ground_y"):
			drop_pos.y = maxf(world._get_exact_ground_y(drop_pos.x, drop_pos.z), 0.35) + 0.06
		var drop_id := "bot_tame_meat_%d_%d" % [int(b["bot_id"]), Time.get_ticks_msec()]
		if world.has_method("_spawn_raw_meat_visual"):
			world._spawn_raw_meat_visual(drop_id, meat_name, drop_pos)
		if world.has_method("_tag_meat_drop"):
			world._tag_meat_drop(drop_id, meat_name, str(b["bot_id"]))
		if "_dropped_items" in world:
			world._dropped_items.append({"id": drop_id, "name": meat_name, "type": "food", "weight": 0.3, "qty": 1, "use": 15.0, "pos": [drop_pos.x, drop_pos.y, drop_pos.z], "action_type": "wolf_meat_raw"})
		var net = world.get("net")
		if net != null and net.is_host and net.peer != null:
			for pid in net.players.keys():
				if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
					net.item_dropped.rpc_id(pid, drop_id, meat_name, "food", 0.3, 1, 15.0, drop_pos)
		# Asegurar que el lobo tenga hambre suficiente para acudir al cebo
		if "_wolf_hunger" in wolf and float(wolf._wolf_hunger) >= float(wolf._wolf_hunger_threshold):
			wolf._wolf_hunger = float(wolf._wolf_hunger_threshold) - 15.0
		b["tame_cooldown"] = 11.0
		b["anim"] = "idle"

func _find_combat_foe(b: Dictionary) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var aggro: Node3D = b.get("aggro_target")
	if aggro != null and is_instance_valid(aggro) and not bool(aggro.get_meta("proxy_dead", false)) and not bool(aggro.get("is_dead")):
		if proxy.global_position.distance_to(aggro.global_position) < 60.0:
			return aggro

	var faction := str(b["faction"])
	var leader := _resolve_team_leader(b)
	var sight := 44.0 if faction == "hostile" else 28.0
	var best: Node3D = null
	var best_d := sight

	# Si es hostil ("Kael"), busca jugadores humanos y bots aliados
	if faction == "hostile":
		for p in world.get_tree().get_nodes_in_group("net_player_proxy"):
			if not (p is Node3D) or p == proxy or not is_instance_valid(p):
				continue
			if bool(p.get_meta("proxy_dead", false)) or not bool(p.get_meta("has_real_pos", false)):
				continue
			if bool(p.get_meta("is_ai_bot", false)) and str(p.get_meta("bot_faction", "")) == "hostile":
				continue
			# Si el objetivo está oculto en un refugio camuflado, solo lo ve de muy cerca (< 8 m)
			var in_sh := bool(p.get_meta("in_built_shelter", false))
			var max_r := 8.0 if in_sh else best_d
			var d := proxy.global_position.distance_to((p as Node3D).global_position)
			if d < max_r:
				best_d = d
				best = p as Node3D
		var local_p = world.get("player")
		if local_p is Node3D and is_instance_valid(local_p) and not bool(local_p.get("is_dead")):
			var in_sh_l := bool(local_p.get_meta("in_built_shelter", false))
			var max_rl := 8.0 if in_sh_l else best_d
			var dl := proxy.global_position.distance_to((local_p as Node3D).global_position)
			if dl < max_rl:
				best_d = dl
				best = local_p as Node3D
	else:
		# Aliado/cooperativo: ataca bandidos hostiles que se acerquen a él o a su líder
		for other_id in bots.keys():
			var ob: Dictionary = bots[other_id]
			if str(ob["faction"]) != "hostile":
				continue
			var op: Node3D = ob.get("proxy")
			if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
				continue
			var d := proxy.global_position.distance_to(op.global_position)
			var dl := leader.global_position.distance_to(op.global_position) if leader != null else 9999.0
			if minf(d, dl) < best_d:
				best_d = minf(d, dl)
				best = op
	return best

func _engage_foe(b: Dictionary, foe: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	var weapon := _best_weapon_name(proxy)
	b["held_item"] = weapon
	var is_rifle := weapon == "Fusil de asalto" or weapon == "Rifle francotirador"
	b["has_rifle"] = is_rifle
	proxy.set_meta("saved_held_item", weapon)

	# Ordenar a su lobo domesticado que ataque también al objetivo
	_command_bot_wolf_against(b, foe)

	var fpos := foe.global_position
	var dist := proxy.global_position.distance_to(fpos)
	var to_foe := fpos - proxy.global_position
	to_foe.y = 0.0
	if to_foe.length_squared() > 0.001:
		b["rot"] = atan2(-to_foe.x, -to_foe.z)
		proxy.rotation.y = float(b["rot"])

	if is_rifle and dist > 3.5 and dist <= 48.0:
		b["is_aiming"] = true
		if dist > 22.0:
			_move_bot_towards(b, fpos, 3.8, delta, "walk")
		else:
			b["anim"] = "idle"
		if float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, fpos):
			b["shoot_cooldown"] = 1.15 if weapon == "Fusil de asalto" else 1.85
			var dmg := 26.0 if weapon == "Fusil de asalto" else 48.0
			_bot_fire_rifle_at(b, foe, dmg)
		return

	b["is_aiming"] = false
	var reach := 3.6
	if dist <= reach:
		b["anim"] = "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION
		if float(b["attack_cooldown"]) <= 0.0:
			b["attack_cooldown"] = 0.68
			_apply_bot_damage_to_target(b, foe, _weapon_melee_damage(weapon) * 0.45, "melee")
	else:
		_move_bot_towards(b, fpos, 4.7, delta, "run")

func _bot_fire_rifle_at(b: Dictionary, target: Node3D, dmg: float) -> void:
	var proxy: Node3D = b["proxy"]
	var bot_id := int(b["bot_id"])
	var origin := proxy.global_position + Vector3(0.0, 1.4, 0.0)
	var aim_pos := target.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim_pos - origin).normalized()
	if world.has_method("_net_player_shot_rifle"):
		world._net_player_shot_rifle(bot_id, origin, dir, Vector3.ZERO)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.player_shot_rifle.rpc_id(pid, bot_id, origin, dir, Vector3.ZERO)
	if target is WildlifeController or target.is_in_group("wildlife"):
		if target.has_method("take_damage"):
			target.take_damage(dmg, false, proxy)
		if bool(target.get("_is_dead")):
			_bot_harvest_dead_animal(b, target)
	else:
		_apply_bot_damage_to_target(b, target, dmg, "rifle")

func _apply_bot_damage_to_target(b: Dictionary, target: Node3D, amount: float, weapon: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	var bot_id := int(b["bot_id"])
	if target.is_in_group("ai_survivor_bot"):
		var target_bot_id := int(target.get_meta("peer_id", 0))
		on_bot_damaged(target_bot_id, amount, bot_id, weapon)
		return
	if target.is_in_group("net_player_proxy"):
		var target_pid := int(target.get_meta("peer_id", 0))
		if target_pid > 0 and world.has_method("_net_damage_player"):
			world._net_damage_player(target_pid, amount, bot_id, weapon)
		return
	if target.has_method("apply_damage"):
		target.apply_damage(amount, weapon)
		if weapon == "rifle" and target.has_method("_play_shot_reaction"):
			target._play_shot_reaction()
		elif target.has_method("_play_hit_reaction"):
			target._play_hit_reaction(true)

func on_bot_damaged(bot_id: int, amount: float, attacker_id: int, weapon: String = "melee") -> void:
	if not bots.has(bot_id):
		return
	var b: Dictionary = bots[bot_id]
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	var hp := maxf(0.0, float(proxy.get_meta("proxy_health", 100.0)) - amount)
	b["health"] = hp
	proxy.set_meta("proxy_health", hp)
	proxy.set_meta("saved_health", hp)

	# Si el atacante es un jugador o bot, responder a la agresión
	var attacker_node := _find_actor_by_peer_id(attacker_id)
	if attacker_node != null and attacker_node != proxy:
		# Si su propio líder le dispara repetidamente, rompe la alianza y se defiende
		if int(b["team_leader_id"]) == attacker_id and amount >= 15.0:
			b["team_leader_id"] = 0
			proxy.set_meta("team_leader_id", 0)
		if int(b["team_leader_id"]) == 0 or attacker_id != int(b["team_leader_id"]):
			b["aggro_target"] = attacker_node
			b["aggro_timer"] = 30.0
			_command_bot_wolf_against(b, attacker_node)

	var net = world.get("net")
	if net != null and net.has_method("_broadcast_player_hit"):
		net._broadcast_player_hit(bot_id, weapon if weapon in ["rifle", "melee"] else "melee", proxy.global_position, true)
	elif world.has_method("_net_player_hit_event"):
		world._net_player_hit_event(bot_id, weapon if weapon in ["rifle", "melee"] else "melee", proxy.global_position)

	if hp <= 0.0:
		proxy.set_meta("proxy_dead", true)
		proxy.remove_from_group("net_player_proxy")
		proxy.add_to_group("interactable")
		b["anim"] = "dead_melee" if weapon == "melee" else "dead"
		b["torch_lit"] = false
		b["is_aiming"] = false
		b["respawn_timer"] = 0.0
		if world.has_method("_release_dead_owner_wolves"):
			world._release_dead_owner_wolves(bot_id, str(b["client_id"]), proxy, false)
		if world.has_method("_drop_player_loot"):
			world._drop_player_loot(bot_id, proxy)
		proxy.set_meta("death_broadcasted", true)
		if world.has_method("_broadcast_player_death"):
			world._broadcast_player_death(bot_id, proxy, "melee" if weapon == "melee" else "")
		if world.has_method("_net_player_death_broadcast"):
			world._net_player_death_broadcast(bot_id, proxy.global_position, float(b["rot"]), "melee" if weapon == "melee" else "")
		_publish_bot_to_net_players(b)

func _respawn_bot(b: Dictionary) -> void:
	var cfg: Dictionary = b["cfg"]
	var bot_id := int(b["bot_id"])
	var old_proxy: Node3D = b.get("proxy")
	if old_proxy != null and is_instance_valid(old_proxy):
		old_proxy.queue_free()
	if "server_proxies" in world:
		world.server_proxies.erase(bot_id)
	if "remote_players" in world and world.remote_players.has(bot_id):
		var rp = world.remote_players[bot_id]
		if is_instance_valid(rp):
			rp.queue_free()
		world.remote_players.erase(bot_id)
	bots.erase(bot_id)
	_spawn_bot(cfg)

func _resolve_team_leader(b: Dictionary) -> Node3D:
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0:
		return null
	var node := _find_actor_by_peer_id(lid)
	if node == null or not is_instance_valid(node) or bool(node.get_meta("proxy_dead", false)) or bool(node.get_meta("disconnected", false)) or bool(node.get("is_dead")):
		return null
	return node

func _find_actor_by_peer_id(pid: int) -> Node3D:
	if pid <= 0 or world == null:
		return null
	if pid in bots:
		return bots[pid].get("proxy")
	if "server_proxies" in world and world.server_proxies.has(pid):
		return world.server_proxies[pid]
	var local_p = world.get("player")
	var net = world.get("net")
	var my_id: int = net.get_my_id() if (net != null and net.has_method("get_my_id")) else 1
	if pid == my_id and local_p is Node3D and is_instance_valid(local_p):
		return local_p as Node3D
	return null

func _tick_teammate_behavior(b: Dictionary, leader: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var mode := str(b.get("follow_mode", "follow"))
	var weapon := "Antorcha" if bool(b["torch_lit"]) else _best_weapon_name(proxy)
	b["held_item"] = weapon
	b["has_rifle"] = weapon == "Fusil de asalto" or weapon == "Rifle francotirador"
	proxy.set_meta("saved_held_item", weapon)

	# Si el líder está bajo ataque de otro jugador/bot o depredador, asistirle
	if mode == "stay":
		b["sitting"] = true
		b["crouching"] = false
		b["anim"] = "sit"
		return

	b["sitting"] = false
	var lpos := leader.global_position
	var dist := proxy.global_position.distance_to(lpos)
	if dist > 4.2:
		var spd := 5.2 if dist > 9.0 else 3.6
		var clip := "run" if dist > 9.0 else "walk"
		_move_bot_towards(b, lpos, spd, delta, clip)
	else:
		# Cerca del líder: si hay un botín útil muy a mano (< 8 m), recogerlo
		var nearby_loot := _find_nearby_valuable_loot(b, 7.5)
		if not nearby_loot.is_empty():
			var lp := _loot_entry_pos(nearby_loot)
			if proxy.global_position.distance_to(lp) <= 2.1:
				_collect_loot_entry(b, nearby_loot)
			else:
				_move_bot_towards(b, lp, 3.6, delta, "walk")
		else:
			b["anim"] = "idle"
			b["crouching"] = bool(leader.get("is_crouching") == true or leader.get_meta("crouching", false) == true)

func interact_with_bot(bot_id: int, sender_id: int, mode: String = "toggle") -> String:
	if not bots.has(bot_id):
		return ""
	var b: Dictionary = bots[bot_id]
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return ""
	if str(b["faction"]) == "hostile":
		return "%s es hostil y no quiere formar equipo." % str(b["name"])

	var cur_leader := int(b.get("team_leader_id", 0))
	var bname := str(b["name"])
	if cur_leader == 0 or cur_leader != sender_id:
		b["team_leader_id"] = sender_id
		b["follow_mode"] = "follow"
		b["sitting"] = false
		b["aggro_target"] = null
		proxy.set_meta("team_leader_id", sender_id)
		proxy.set_meta("bot_follow_mode", "follow")
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s se ha unido a tu equipo (te sigue y te cubre)." % bname

	# Ya está en el equipo de este jugador: ciclar orden (Sígueme -> Quieto -> Libre)
	if mode == "dismiss":
		b["team_leader_id"] = 0
		proxy.set_meta("team_leader_id", 0)
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s vuelve a explorar por su cuenta." % bname

	var cur_mode := str(b.get("follow_mode", "follow"))
	if cur_mode == "follow":
		b["follow_mode"] = "stay"
		b["stay_pos"] = proxy.global_position
		proxy.set_meta("bot_follow_mode", "stay")
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s: 'Me quedo vigilando esta posición.'" % bname
	elif cur_mode == "stay":
		b["team_leader_id"] = 0
		b["follow_mode"] = "follow"
		b["sitting"] = false
		proxy.set_meta("team_leader_id", 0)
		proxy.set_meta("bot_follow_mode", "follow")
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s deja el equipo y sigue su camino." % bname
	else:
		b["follow_mode"] = "follow"
		b["sitting"] = false
		proxy.set_meta("bot_follow_mode", "follow")
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s: '¡En marcha, te sigo!'" % bname

func notify_leader_combat(leader_id: int, target_node: Node3D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	for bot_id in bots.keys():
		var b: Dictionary = bots[bot_id]
		if int(b.get("team_leader_id", 0)) != leader_id:
			continue
		var proxy: Node3D = b.get("proxy")
		if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
			continue
		if proxy.global_position.distance_to(target_node.global_position) <= 55.0:
			b["aggro_target"] = target_node
			b["aggro_timer"] = 25.0
			b["follow_mode"] = "follow"
			b["sitting"] = false

func _command_bot_wolf_against(b: Dictionary, target: Node3D) -> void:
	if world == null or world.get_tree() == null or target == null or not is_instance_valid(target):
		return
	var key := str(b["bot_id"])
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if is_instance_valid(w) and not bool(w.get("_is_dead")) and str(w.get("animal_type")) == "wolf" and str(w.get("tamed_to")) == key:
			if w.has_method("notify_threat"):
				w.notify_threat(target, 20.0)

func _find_nearby_valuable_loot(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("_dropped_items" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var r_sq := radius * radius
	var best := {}
	var best_d_sq := r_sq
	var depleted: Array = world.get("_depleted_action_ids") if "_depleted_action_ids" in world else []
	for entry in world._dropped_items:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		if id.is_empty() or depleted.has(id):
			continue
		# No robar la carne que alguien acaba de tirar como cebo para un lobo
		if id.begins_with("bot_tame_meat_"):
			continue
		if "world_actions_by_id" in world and world.world_actions_by_id.has(id):
			var wa = world.world_actions_by_id[id]
			if wa != null and is_instance_valid(wa) and wa.has_meta("dropped_by"):
				continue
		var nm := str(entry.get("name", ""))
		var tp := str(entry.get("type", ""))
		if not _is_loot_desirable(b, nm, tp):
			continue
		var pos := _loot_entry_pos(entry)
		var d_sq := proxy.global_position.distance_squared_to(pos)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = entry
	return best

func _is_loot_desirable(b: Dictionary, nm: String, tp: String) -> bool:
	if tp in ["weapon", "weapon_rifle", "tool_axe", "tool_spear", "ammo", "medical", "food", "water", "tool_matches"]:
		return true
	if nm in ["Palo", "Piedra", "Cuerda", "Tela de camuflaje"] or nm.begins_with("Piel de "):
		return true
	if tp == "backpack" and nm == "Mochila militar" and str(b["backpack"]) != "Mochila militar":
		return true
	if tp == "clothing" and PlayerController.CLOTHING_SLOTS.has(nm):
		return int(CLOTHING_PRIORITY.get(nm, 0)) >= 4
	return false

func _loot_entry_pos(entry: Dictionary) -> Vector3:
	var p = entry.get("pos", Vector3.ZERO)
	if p is Vector3:
		return p
	if p is Array and p.size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return Vector3.ZERO

func _collect_loot_entry(b: Dictionary, entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id.is_empty() or world == null:
		return
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var item_dict := {
		"name": str(entry.get("name", "")),
		"type": str(entry.get("type", "resource")),
		"weight": float(entry.get("weight", 0.2)),
		"quantity": int(entry.get("qty", 1)),
		"use_value": float(entry.get("use", 0.0)),
	}
	_bot_add_inventory_item(inv, item_dict)
	proxy.set_meta("saved_inventory", inv)
	_auto_equip_best_gear(b)
	var best_w := _best_weapon_name(proxy)
	if not best_w.is_empty() and not bool(b["torch_lit"]):
		b["held_item"] = best_w
		b["has_rifle"] = best_w == "Fusil de asalto" or best_w == "Rifle francotirador"
		proxy.set_meta("saved_held_item", best_w)

	if world.has_method("_net_world_action_completed"):
		world._net_world_action_completed(id, _loot_entry_pos(entry), 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.world_action_completed.rpc_id(pid, "", [], id, _loot_entry_pos(entry))

func _can_bot_build_shelter(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 4 and _bot_item_count(proxy, "Cuerda") >= 1

func _can_bot_build_campfire(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2

func _bot_build_shelter(b: Dictionary, pos: Vector3) -> void:
	var proxy: Node3D = b["proxy"]
	_consume_bot_item(proxy, "Palo", 4)
	_consume_bot_item(proxy, "Cuerda", 1)
	var has_pelts := _bot_item_count(proxy, "Piel de lobo") + _bot_item_count(proxy, "Piel de ciervo") >= 4
	if has_pelts:
		var used := 0
		for pelt_nm in ["Piel de lobo", "Piel de ciervo"]:
			while used < 4 and _bot_item_count(proxy, pelt_nm) > 0:
				_consume_bot_item(proxy, pelt_nm, 1)
				used += 1
	var has_camo := _consume_bot_item(proxy, "Tela de camuflaje", 1)
	var sh_id := "bot_shelter_%d" % int(b["bot_id"])
	var yaw := float(b["rot"])
	b["shelter_id"] = sh_id
	b["shelter_pos"] = pos
	if world.has_method("_spawn_player_shelter_with_id"):
		world._spawn_player_shelter_with_id(sh_id, pos, yaw, has_pelts, has_camo)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.shelter_built.rpc_id(pid, sh_id, pos, yaw)
				if has_pelts:
					net.shelter_lined.rpc_id(pid, sh_id, true)
				if has_camo:
					net.shelter_camo_changed.rpc_id(pid, sh_id, true)

func _bot_build_and_light_campfire(b: Dictionary, pos: Vector3) -> void:
	var proxy: Node3D = b["proxy"]
	_consume_bot_item(proxy, "Palo", 2)
	_consume_bot_item(proxy, "Piedra", 2)
	var cf_id := "bot_campfire_%d" % int(b["bot_id"])
	b["campfire_id"] = cf_id
	b["campfire_pos"] = pos
	if world.has_method("_net_campfire_built"):
		world._net_campfire_built(cf_id, pos, 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.campfire_built.rpc_id(pid, cf_id, pos)
	_ensure_bot_campfire_lit(b)

func _ensure_bot_campfire_lit(b: Dictionary) -> void:
	var cf_id := str(b.get("campfire_id", ""))
	if cf_id.is_empty() or world == null:
		return
	for lc in world.get("_lit_campfires") if "_lit_campfires" in world else []:
		if lc is Dictionary and str(lc.get("id", "")) == cf_id:
			return
	var fire_name := "CampfireFire_Bot_%d_%d" % [int(b["bot_id"]), Time.get_ticks_msec()]
	var pos: Vector3 = b["campfire_pos"]
	if world.has_method("_net_campfire_lit"):
		world._net_campfire_lit(cf_id, fire_name, pos, 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.campfire_lit.rpc_id(pid, cf_id, fire_name, pos)

func _bot_cook_meat_at_fire(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var raw := _first_raw_meat_name(proxy)
	if raw.is_empty():
		return
	if _consume_bot_item(proxy, raw, 1):
		var inv: Array = proxy.get_meta("saved_inventory", [])
		_bot_add_inventory_item(inv, {"name": "Carne asada en palo", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 28.0})
		proxy.set_meta("saved_inventory", inv)
		b["cook_cooldown"] = 18.0

func _move_bot_towards(b: Dictionary, goal: Vector3, speed: float, delta: float, anim_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	var next_goal := goal
	b["path_timer"] = float(b["path_timer"]) - delta
	var flat_dist := Vector2(goal.x - cur.x, goal.z - cur.z).length()
	if flat_dist > 14.0 and world != null and world.get("wolf_nav") != null:
		var path: Array = b["path"]
		if path.is_empty() or float(b["path_timer"]) <= 0.0:
			b["path"] = world.wolf_nav.find_path(cur, goal)
			b["path_idx"] = 0
			b["path_timer"] = 1.5
			path = b["path"]
		var pidx := int(b["path_idx"])
		while pidx < path.size() and Vector2(path[pidx].x - cur.x, path[pidx].z - cur.z).length() < 1.6:
			pidx += 1
		b["path_idx"] = pidx
		if pidx < path.size():
			next_goal = path[pidx]
	var to_next := Vector3(next_goal.x - cur.x, 0.0, next_goal.z - cur.z)
	var d := to_next.length()
	if d < 0.05:
		b["anim"] = "idle"
		return
	var dir := to_next / d
	var step := minf(speed * delta, d)
	var new_pos := cur + dir * step
	if world != null and world.has_method("_get_exact_ground_y"):
		new_pos.y = maxf(world._get_exact_ground_y(new_pos.x, new_pos.z), 0.35)
	proxy.global_position = new_pos
	proxy.set_meta("saved_pos", new_pos)
	b["pos"] = new_pos
	b["rot"] = lerp_angle(float(b["rot"]), atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
	proxy.rotation.y = float(b["rot"])
	b["anim"] = anim_name

func _has_clear_shot(from_pos: Vector3, to_pos: Vector3) -> bool:
	if world == null or not (world is Node3D) or (world as Node3D).get_world_3d() == null:
		return true
	var space: PhysicsDirectSpaceState3D = (world as Node3D).get_world_3d().direct_space_state
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(from_pos + Vector3(0, 1.3, 0), to_pos + Vector3(0, 1.1, 0), 1)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()

func _is_world_night() -> bool:
	if world != null and world.get("day_cycle") != null:
		var tod := float(world.day_cycle.get("time_of_day"))
		return tod < 6.2 or tod > 19.3
	return false

func _best_weapon_name(proxy: Node3D) -> String:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var order := ["Fusil de asalto", "Rifle francotirador", "Lanza de hueso", "Lanza", "Hacha", "Cuchillo", "Palo afilado"]
	for w in order:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == w and int(it.get("quantity", 1)) > 0:
				return w
	return "Cuchillo"

func _weapon_melee_damage(weapon: String) -> float:
	match weapon:
		"Lanza de hueso": return 85.0
		"Lanza": return 75.0
		"Hacha": return 65.0
		"Cuchillo": return 60.0
		"Palo afilado": return 50.0
		_: return 35.0

func _bot_has_item(proxy: Node3D, item_name: String) -> bool:
	return _bot_item_count(proxy, item_name) > 0

func _bot_item_count(proxy: Node3D, item_name: String) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) == item_name:
			total += int(it.get("quantity", 1))
	return total

func _bot_has_raw_meat(proxy: Node3D) -> bool:
	return not _first_raw_meat_name(proxy).is_empty()

func _first_raw_meat_name(proxy: Node3D) -> String:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			if nm.begins_with("Carne cruda"):
				return nm
	return ""

func _consume_bot_item(proxy: Node3D, item_name: String, qty: int = 1) -> bool:
	if _bot_item_count(proxy, item_name) < qty:
		return false
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var left := qty
	for i in range(inv.size() - 1, -1, -1):
		var it = inv[i]
		if not (it is Dictionary) or str(it.get("name", "")) != item_name:
			continue
		var q := int(it.get("quantity", 1))
		var take := mini(left, q)
		it["quantity"] = q - take
		left -= take
		if int(it["quantity"]) <= 0:
			inv.remove_at(i)
		if left <= 0:
			break
	proxy.set_meta("saved_inventory", inv)
	return true

func _bot_add_inventory_item(inv: Array, item_dict: Dictionary) -> void:
	var nm := str(item_dict.get("name", ""))
	var tp := str(item_dict.get("type", "resource"))
	var qty := int(item_dict.get("quantity", 1))
	if tp in ["food", "resource", "material", "medical", "ammo"]:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == nm:
				it["quantity"] = int(it.get("quantity", 1)) + qty
				return
	inv.append(item_dict.duplicate(true))
