extends Node
class_name SurvivorBotManager

const CityExpansion = preload("res://scripts/CityExpansion.gd")
const CityBlock = preload("res://scripts/CityBlock.gd")

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
		"preview_id": "elena",
		"faction": "friendly",
		"hair_style": "ponytail",
		"beard_stage": 0,
		"top_color": Color(0.5, 0.45, 0.2),
		"bottom_color": Color(0.2, 0.2, 0.5),
		"shoes_color": Color(0.35, 0.15, 0.1),
		"hair_color": Color(0.65, 0.25, 0.1),
		"skin_color": Color(0.82, 0.68, 0.55),
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
		"starting_clothing": ["Camiseta", "Pantalones", "Zapatillas"],
		"starting_backpack": "",
		"starting_weapon": "Cuchillo",
		"starting_items": [],
		"personality": {
			"bravery": 0.42,
			"aggression": 0.20,
			"curiosity": 0.85,
			"sociability": 0.82,
			"distrust": 0.25,
			"cooperation": 0.88,
			"survival_instinct": 0.86,
		},
	},
	{
		"bot_id": 902,
		"client_id": "ai_bot_902",
		"name": "Carlos",
		"preview_id": "laura",
		"faction": "friendly",
		"hair_style": "long",
		"beard_stage": 0,
		"top_color": Color(0.6, 0.2, 0.3),
		"bottom_color": Color(0.1, 0.15, 0.25),
		"shoes_color": Color(0.2, 0.2, 0.22),
		"hair_color": Color(0.08, 0.06, 0.04),
		"skin_color": Color(0.78, 0.65, 0.52),
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
		"starting_clothing": ["Camiseta", "Pantalones", "Zapatillas"],
		"starting_backpack": "",
		"starting_weapon": "Hacha",
		"starting_items": [],
		"personality": {
			"bravery": 0.78,
			"aggression": 0.45,
			"curiosity": 0.55,
			"sociability": 0.70,
			"distrust": 0.38,
			"cooperation": 0.76,
			"survival_instinct": 0.62,
		},
	},
	{
		"bot_id": 903,
		"client_id": "ai_bot_903",
		"name": "Kael",
		"preview_id": "soldado",
		"faction": "hostile",
		"hair_style": "buzz",
		"beard_stage": 0,
		"top_color": Color(0.2, 0.25, 0.12),
		"bottom_color": Color(0.2, 0.25, 0.12),
		"shoes_color": Color(0.15, 0.12, 0.08),
		"hair_color": Color(0.05, 0.04, 0.03),
		"skin_color": Color(0.75, 0.62, 0.48),
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
		"starting_clothing": ["Camiseta", "Pantalones", "Zapatillas"],
		"starting_backpack": "",
		"starting_weapon": "Fusil de asalto",
		"starting_items": [],
		"personality": {
			"bravery": 0.74,
			"aggression": 0.86,
			"curiosity": 0.64,
			"sociability": 0.12,
			"distrust": 0.92,
			"cooperation": 0.10,
			"survival_instinct": 0.78,
		},
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
# Aprendizaje persistente por personaje: sobrevive a la muerte/respawn, asi el
# superviviente "recuerda" donde murio, por que, que zonas ya exploro y que la
# ropa de piel es la mejor equipacion.
var _memory: Dictionary = {} # bot_id -> {deaths, last_death_pos, last_death_cause, visited, gear_learned, scarcity}
var _poi_cache: Array = [] # puntos de interes del mundo (casas, tiendas, ciudad, zonas salvajes)
var _poi_cache_built := false

# --- Asesor estrategico externo (opcional) ---
# Un LLM remoto (p.ej. Groq, endpoint compatible con OpenAI) decide CADA ~15-25
# min que hacer a cada bot a nivel estrategico: a que zona ir, si volver a
# casa, si descansar o que tipo de zona evitar. NUNCA toca supervivencia,
# combate, crafteo ni ordenes: eso sigue siendo GDScript. Si no hay API key
# (OS.get_environment("GROQ_API_KEY")), la API falla o la respuesta no valida,
# los bots se comportan exactamente igual que sin asesor.
const AI_ADVISOR_URL := "https://api.groq.com/openai/v1/chat/completions"
const AI_ADVISOR_MODEL := "qwen/qwen3.8-27b"
const AI_DECISION_MIN_SEC := 900.0
const AI_DECISION_SPREAD_SEC := 600.0
const AI_DIRECTIVE_TTL_MSEC := 1500 * 1000
const AI_MAX_CALLS_PER_DAY := 380
const AI_MAX_TOKENS_PER_DAY := 120000
const AI_POI_KINDS := ["house", "military", "city", "wild", "tower"]
const AI_ALLOWED_ACTIONS := ["explore", "scavenge", "hunt", "return_home", "rest", "avoid_zone", "forage", "fortify_camp", "seek_ally"]
const AI_PERSONALITY_TRAITS := ["bravery", "aggression", "curiosity", "sociability", "distrust", "cooperation", "survival_instinct"]
const AI_MEMORY_PATH := "user://survivor_bot_memory.json"
const AI_STATUS_PATH := "user://survivor_bot_status.json"
const AI_STATUS_SAVE_SEC := 2.0
const AI_MEMORY_MAX_SPOTS := 10
const AI_MEMORY_MAX_EVENTS := 28
const AI_OBSERVE_RADIUS := 72.0
const AI_SHARE_RADIUS := 14.0
const AI_MEMORY_SAVE_SEC := 90.0
const AI_SYSTEM_PROMPT := "You are the cognitive engine for a survival-game NPC in Last Day. Output ONLY strict JSON, no prose: {\"goal\":\"...\",\"action\":\"...\",\"target\":\"...\",\"priority\":3,\"reason\":\"...\"}. Allowed actions: explore, scavenge, hunt, forage, return_home, rest, avoid_zone, fortify_camp, seek_ally. target: one of house, military, city, wild, tower, camp, ally, or a known_locations id from the prompt (NEVER invent unknown coordinates). priority: integer 1..5. Weigh personality traits, survival needs, relationships, and memories. reason: max 8 words."
var _ai_http: HTTPRequest = null
var _ai_pending_bot := 0
var _ai_next_at: Dictionary = {} # bot_id -> msec epoch del proximo intento
var _ai_calls_day := 0
var _ai_calls_total := 0
var _ai_tokens_day := 0
var _ai_tokens_total := 0
var _ai_cache_hits := 0
var _ai_429_count := 0
var _ai_day_key := -1
var _ai_rr := 0
var _mem_accum := 0.0
var _status_accum := 0.0
var _ai_queue: Array = [] # [{bot_id, priority, reason, t}]
var _ai_last_sig: Dictionary = {} # bot_id -> String firma de situacion
var _ai_last_call_msec: Dictionary = {} # bot_id -> msec ultima llamada remota
var _ai_backoff_until_msec := 0
var _ai_backoff_sec := 60.0
var _ai_conn_status := "idle"
var ai_max_calls_per_day := AI_MAX_CALLS_PER_DAY
var ai_max_tokens_per_day := AI_MAX_TOKENS_PER_DAY
var memory_path: String = AI_MEMORY_PATH
var force_memory_io := false

func setup(main_world: Node) -> void:
	world = main_world
	_ai_load_memory()
	spawn_all_bots()
	_ai_save_live_status()

static func is_bot_peer_id(pid: int) -> bool:
	return pid >= 901 and pid <= 909

# La capsula del CharacterBody3D del jugador local tiene su extremo inferior en
# local y = 0.025 (_compute_skeleton_ground_target_y alinea los huesos del pie
# a 0.025 - min_foot_model_y). Colocando el origen del bot en ground_y - 0.025,
# las suelas apoyan exactamente sobre el suelo igual que el jugador local.
func _ground_y(x: float, z: float, from_y: float = -INF) -> float:
	var ty := 0.375
	if world != null and world.has_method("_get_exact_ground_y"):
		ty = world._get_exact_ground_y(x, z) - 0.025
	if from_y == -INF or not (world is Node3D):
		return ty
	# Escaleras, rampas y pisos transitables sobre el terreno: mismo sondeo
	# hacia abajo que usa el jugador, para subir escaleras de casas y torres.
	var w3d := (world as Node3D).get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		return ty
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y + 0.55, z), Vector3(x, from_y - 0.55, z), 1)
	var hit := w3d.direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hy := float((hit["position"] as Vector3).y)
		if hy > ty + 0.15 and hy <= from_y + 0.55:
			return hy + 0.02
	return ty

# Terreno firme y seguro: tierra seca, sin carretera ni edificio, libre de
# obstaculos/bloqueadores, con pendiente suave y lejos de zonas habitadas.
# ignore_shelter_id permite a un bot validar su propia fogata junto a su refugio.
func _is_flat_dry_pos(pos: Vector3, ignore_shelter_id: String = "") -> bool:
	if world == null:
		return false
	if world.has_method("get_river_depth_at") and float(world.get_river_depth_at(pos)) > 0.02:
		return false
	if world.has_method("_is_water_drop_position") and world._is_water_drop_position(pos):
		return false
	if _is_settled_area(pos, ignore_shelter_id):
		return false
	if world.has_method("_is_player_in_house") and world._is_player_in_house(pos):
		return false
	if world.has_method("_is_near_wildlife_blocker") and world._is_near_wildlife_blocker(pos, 1.6):
		return false
	var cy := _ground_y(pos.x, pos.z)
	for off in [Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0), Vector3(0, 0, 2.0), Vector3(0, 0, -2.0)]:
		var sy := _ground_y(pos.x + off.x, pos.z + off.z)
		if absf(sy - cy) > 0.85:
			return false
	return true

# Zonas donde un superviviente sensato jamas planta su campamento: el pueblo
# inicial (plaza y alrededores de las casas), calles y edificios de la ciudad,
# la base militar, graneros y refugios ya construidos por otros.
func _is_settled_area(pos: Vector3, ignore_shelter_id: String = "") -> bool:
	if world == null:
		return false
	# Nucleo del pueblo inicial (casas y plaza alrededor del origen)
	if Vector2(pos.x, pos.z).length() < 78.0:
		return true
	if world.has_method("_is_near_house") and world._is_near_house(pos, 16.0):
		return true
	if world.has_method("_is_near_road") and world._is_near_road(pos, 9.0):
		return true
	if CityExpansion.near_building(pos, 14.0) or CityExpansion.inside_building(pos):
		return true
	for key in ["_military_tent_pos", "_remote_tent_pos", "_city_tent_pos", "_city_tent2_pos"]:
		var t = world.get(key)
		if t is Vector3 and (t as Vector3) != Vector3.ZERO and Vector2(pos.x - (t as Vector3).x, pos.z - (t as Vector3).z).length() < 30.0:
			return true
	if Vector2(pos.x + 340.0, pos.z - 280.0).length() < 20.0: # granero remoto
		return true
	if "_built_shelters" in world:
		for sh in world._built_shelters:
			if not (sh is Dictionary) or str(sh.get("id", "")) == ignore_shelter_id:
				continue
			var sp = sh.get("pos", null)
			if sp is Vector3 and Vector2(pos.x - (sp as Vector3).x, pos.z - (sp as Vector3).z).length() < 8.0:
				return true
	return false

# Un campamento ademas necesita estar a >=35 m de cualquier otro campamento IA.
func _is_valid_camp_pos(pos: Vector3) -> bool:
	if not _is_flat_dry_pos(pos):
		return false
	for other_id in bots.keys():
		var ob: Dictionary = bots[other_id]
		if ob.get("shelter_pos", Vector3.INF) != Vector3.INF and pos.distance_to(ob["shelter_pos"]) < 35.0:
			return false
		if ob.get("camp_spot", Vector3.INF) != Vector3.INF and pos.distance_to(ob["camp_spot"]) < 35.0:
			return false
	return true

# Busca en espiral alrededor del punto preferido un sitio valido de campamento,
# preferiblemente junto a arboles (oculto) en vez de en mitad del campo.
func _find_valid_camp_spot(preferred: Vector3, _near: Vector3) -> Vector3:
	var best := preferred
	var best_score := -1.0
	var found := false
	for radius in [0.0, 8.0, 16.0, 26.0, 40.0, 60.0, 90.0, 120.0]:
		var steps := 8 if radius > 0.0 else 1
		for i in range(steps):
			var ang := TAU * float(i) / float(steps)
			var cand := preferred + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
			cand.y = _ground_y(cand.x, cand.z)
			if not _is_valid_camp_pos(cand):
				continue
			var tree_dist := _nearest_tree_dist(cand, 25.0)
			var score := 1.0 - clampf(tree_dist / 25.0, 0.0, 1.0)
			if score > best_score:
				best_score = score
				best = cand
				found = true
		if found and radius >= 16.0:
			break
	return best

func _nearest_tree_dist(pos: Vector3, max_dist: float) -> float:
	if world == null or not ("world_actions_by_id" in world):
		return max_dist
	var best := max_dist
	for aid in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[aid]
		if a == null or not is_instance_valid(a):
			continue
		if str(a.get("action_type")) != "fell_tree" and str(a.get("action_type")) != "fell_bush":
			continue
		var d := pos.distance_to((a as Node3D).global_position)
		if d < best:
			best = d
	return best

# Punto de agua alcanzable mas cercano (segmentos del rio/lago) para que el
# superviviente vaya a beber cuando se quede sin botellas.
func _nearest_water_pos(from: Vector3) -> Vector3:
	if world == null or not world.has_method("_default_river_segments"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 280.0
	for seg in world._default_river_segments():
		if not (seg is Dictionary):
			continue
		var c: Vector3 = seg.get("center", Vector3.ZERO)
		var d := Vector2(from.x - c.x, from.z - c.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best

func spawn_all_bots() -> void:
	if world == null:
		return
	for cfg in BOT_CONFIGS:
		_spawn_bot(cfg)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null and net.has_method("_broadcast_player_list"):
		net._broadcast_player_list()

# Spawn aleatorio dentro de las mismas zonas de spawn que usan los jugadores
# (_spawn_zones del mundo): zona al azar + offset +-3 m, evitando rios,
# bloqueadores y quedar pegado a otro superviviente IA.
func _random_bot_spawn(cfg: Dictionary) -> Vector3:
	var fallback := Vector3(cfg.get("spawn", Vector3.ZERO))
	var zones_v = world.get("_spawn_zones") if world != null else null
	var zones: Array = zones_v if zones_v is Array else []
	if zones.is_empty():
		return _sanitize_ground_point(fallback)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var best := _sanitize_ground_point(zones[rng.randi() % zones.size()])
	var best_sep := -1.0
	for i in range(16):
		var zone: Vector3 = zones[rng.randi() % zones.size()]
		var cand := Vector3(zone.x + rng.randf_range(-3.0, 3.0), 0.0, zone.z + rng.randf_range(-3.0, 3.0))
		if world.has_method("_is_near_river") and world._is_near_river(cand, 30.0):
			continue
		if _is_pos_blocked(cand, 0.7):
			continue
		var sep := _min_dist_to_other_bots(cand)
		if sep >= 40.0:
			return _sanitize_ground_point(cand)
		if sep > best_sep:
			best_sep = sep
			best = cand
	return _sanitize_ground_point(best)

func _min_dist_to_other_bots(pos: Vector3) -> float:
	var sep := INF
	for other_id in bots.keys():
		var op = bots[other_id].get("pos", Vector3.INF)
		if op is Vector3 and (op as Vector3) != Vector3.INF:
			sep = minf(sep, Vector2(pos.x - (op as Vector3).x, pos.z - (op as Vector3).z).length())
	return sep

func _sanitize_ground_point(preferred: Vector3) -> Vector3:
	var p := Vector3(preferred.x, _ground_y(preferred.x, preferred.z), preferred.z)
	if not _is_pos_blocked(p, 0.7):
		return p
	for radius in [2.5, 5.0, 9.0, 14.0]:
		for i in range(8):
			var ang := TAU * float(i) / 8.0
			var cand := Vector3(preferred.x + cos(ang) * radius, 0.0, preferred.z + sin(ang) * radius)
			cand.y = _ground_y(cand.x, cand.z)
			if not _is_pos_blocked(cand, 0.7):
				return cand
	return p

func _spawn_bot(cfg: Dictionary) -> void:
	var bot_id := int(cfg["bot_id"])
	if bots.has(bot_id):
		return
	var spawn_pos: Vector3 = _random_bot_spawn(cfg)
	var patrol: Array = []
	for pt in cfg.get("patrol", []):
		patrol.append(_sanitize_ground_point(pt as Vector3))
	if world.get("_military_tent_pos") is Vector3 and world._military_tent_pos != Vector3.ZERO:
		var mt: Vector3 = world._military_tent_pos
		patrol.append(_sanitize_ground_point(mt))
	# El campamento debe estar en un sitio valido: tierra firme, fuera de
	# carreteras/casas, terreno llano y lejos de otros campamentos.
	var preferred_camp: Vector3 = cfg.get("camp_spot", spawn_pos + Vector3(6.0, 0.0, 6.0))
	var camp_spot: Vector3 = _find_valid_camp_spot(preferred_camp, spawn_pos)

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
	# El arma inicial es equipo, no botin: vive en el inventario como cualquier
	# arma saqueada para que combata y craftee con ella; saved_held_item marca
	# el slot que lleva en la mano.
	var start_weapon := str(cfg.get("starting_weapon", "Cuchillo"))
	var wdur := 100.0
	var wtype := "weapon"
	match start_weapon:
		"Fusil de asalto", "Rifle francotirador": wtype = "weapon_rifle"
		"Hacha": wtype = "tool_axe"
		"Cuchillo": wdur = 80.0
	inv_items.append({"name": start_weapon, "type": wtype, "weight": 1.4, "quantity": 1, "use_value": 10.0, "durability": wdur, "max_durability": wdur})
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
		"spawned_at_msec": Time.get_ticks_msec(),
		"alive_flush_msec": Time.get_ticks_msec(),
		"energy": 100.0,
		"stuck_timer": 0.0,
		"stuck_count": 0,
		"last_move_pos": spawn_pos,
		"flee_until": 0.0,
		"gut_target": null,
		"gut_t": 0.0,
		"strafe_dir": 1.0,
		"strafe_timer": 0.0,
		"drink_at": Vector3.INF,
		"drinking_timer": 0.0,
		"patrol_dwell": 0.0,
		"flinch_timer": 0.0,
		"flinch_anim": "hit",
		"avoid_sign": 1.0 if (bot_id % 2 == 1) else -1.0,
		# Percepcion escalonada (~5 Hz): cada bot refresca sus sentidos en un
		# instante distinto para no escanear fauna/botin/jugadores a 60 Hz.
		"sense_t": fmod(float(bot_id) * 0.073, 0.21),
		"_s_predator": null,
		"_s_foe": null,
		"_s_leader": null,
		"_s_has_wolf": false,
		"_s_tame_wolf": null,
		"_s_prey": null,
		"_s_corpse": null,
		"_s_loot": {},
		"climb_route": [],
		"climb_i": -1,
		"climb_down": false,
		"climb_dwell": 0.0,
		"equip_mission": false,
		"forced_eat": false,
		"avoid_t": 0.0,
		"_avoid": Vector3.ZERO,
		# Exploracion e inercia de movimiento (flujo natural, sin tirones)
		"explore_target": Vector3.INF,
		"explore_dwell": 0.0,
		"_speed": 0.0,
		"_mdir": Vector3.ZERO,
		"_last_move_t": -99.0,
		"current_goal": "survival_patrol",
	}
	bots[bot_id] = bot_state
	# Enlazar la memoria persistente del personaje: identidad, personalidad
	# evolutiva, recuerdos de eventos, ubicaciones conocidas (sin omnisciencia),
	# relaciones sociales, estrategias y objetivos pendientes.
	var mem: Dictionary = _ensure_bot_memory(bot_id, cfg)
	bot_state["_mem"] = mem
	bot_state["personality"] = (mem.get("personality", {}) as Dictionary)
	# Al aparecer, el bot solo conoce su entorno inmediato y su patrulla inicial
	_observe_nearby_world(bot_state)
	for pt in patrol:
		if pt is Vector3:
			var pid := "patrol:%d:%d" % [int((pt as Vector3).x), int((pt as Vector3).z)]
			observe_location(bot_id, pid, "wild", pt as Vector3, "observed")
	# Prudencia aprendida: si murio por depredadores o inanicion, durante los
	# primeros minutos de su nueva vida evita la zona donde cayo.
	bot_state["caution_until"] = 240.0 if str(mem.get("last_death_cause", "")) in ["wolf_bite", "bear_bite", "starved"] else 0.0
	_publish_bot_to_net_players(bot_state)
	_sync_bot_appearance_to_clients(bot_state)
	# Si estamos en singleplayer o host con render, crear su avatar visual inmediatamente
	if world.get("net") == null or not world.net.is_dedicated_server:
		if world.has_method("_spawn_remote_player"):
			world._spawn_remote_player(bot_id)
			_apply_local_avatar_metadata(bot_state)

func _sync_bot_appearance_to_clients(b: Dictionary) -> void:
	if world == null or world.get("net") == null:
		return
	var net = world.net
	if not net.is_host or net.peer == null:
		return
	var bot_id := int(b["bot_id"])
	var cfg: Dictionary = b["cfg"]
	var Grooming = preload("res://scripts/CharacterGrooming.gd")
	var wire_cn: String = Grooming.encode_identity(str(b["name"]), str(cfg.get("hair_style", "short")), int(cfg.get("beard_stage", 0)))
	for pid in net.players.keys():
		if pid == net.get_my_id() or is_bot_peer_id(int(pid)) or net.players[pid].get("offline", false) or not net.peer_alive(pid):
			continue
		net.sync_character_appearance_remote.rpc_id(
			pid, bot_id, wire_cn,
			cfg.get("top_color", Color(0.5, 0.45, 0.2)),
			cfg.get("bottom_color", Color(0.2, 0.2, 0.5)),
			cfg.get("shoes_color", Color(0.35, 0.15, 0.1)),
			cfg.get("hair_color", Color(0.65, 0.25, 0.1)),
			cfg.get("skin_color", Color(0.82, 0.68, 0.55)),
			bool(cfg.get("top_camo", false)),
			bool(cfg.get("bottom_camo", false))
		)

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
	_ai_tick(delta)
	_mem_accum += delta
	if _mem_accum >= AI_MEMORY_SAVE_SEC:
		_mem_accum = 0.0
		_ai_save_memory()
	_status_accum += delta
	if _status_accum >= AI_STATUS_SAVE_SEC:
		_status_accum = 0.0
		_ai_save_live_status()
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

	# Necesidades reales: hambre/sed bajan como en un jugador (algo mas lento
	# para que un bot dure la sesion, pero puede morir si no encuentra recursos)
	var moving_now: bool = str(b["anim"]) == "walk" or str(b["anim"]) == "run"
	var drain_mult := 1.15 if moving_now else 0.8
	b["hunger"] = maxf(0.0, float(b["hunger"]) - delta * 0.055 * drain_mult)
	b["thirst"] = maxf(0.0, float(b["thirst"]) - delta * 0.050 * drain_mult)
	proxy.set_meta("saved_hunger", float(b["hunger"]))
	proxy.set_meta("saved_thirst", float(b["thirst"]))
	_maintain_bot_needs(b, delta)
	# Hambre o sed a cero = desgaste real de salud hasta la muerte
	var starve_dmg := 0.0
	if float(b["hunger"]) <= 0.0:
		starve_dmg += 1.1
	if float(b["thirst"]) <= 0.0:
		starve_dmg += 1.4
	if starve_dmg > 0.0:
		var hp2 := float(proxy.get_meta("proxy_health", 100.0)) - starve_dmg * delta
		proxy.set_meta("proxy_health", maxf(0.0, hp2))
		proxy.set_meta("saved_health", maxf(0.0, hp2))
		b["health"] = maxf(0.0, hp2)
		if hp2 <= 0.0:
			_kill_bot(b, "starved")
			return

	# Si acaba de recibir un disparo o golpe, acusa el impacto (flinch) antes de
	# reanudar movimiento o ataque, manteniendo la animacion shot/hit visible.
	if float(b.get("flinch_timer", 0.0)) > 0.0:
		b["flinch_timer"] = maxf(0.0, float(b["flinch_timer"]) - delta)
		b["sitting"] = false
		b["sleeping"] = false
		b["is_aiming"] = false
		b["anim"] = str(b.get("flinch_anim", "hit"))
		return

	# Refresco de sentidos a ~5 Hz escalonado entre bots. Un humano reacciona
	# en ~0.2 s; escanear toda la fauna, jugadores y botin cada frame por bot
	# era el mayor coste de la IA (get_nodes_in_group + distancias x3/frame).
	b["sense_t"] = float(b.get("sense_t", 0.0)) - delta
	if float(b["sense_t"]) <= 0.0:
		b["sense_t"] = 0.21 + fmod(float(b["bot_id"]) * 0.037, 0.08)
		b["_s_predator"] = _find_threatening_predator(b, 30.0 if float(b.get("caution_until", 0.0)) > 0.0 else 22.0)
		b["_s_foe"] = _find_combat_foe(b)
		b["_s_leader"] = _resolve_team_leader(b)
		var has_wolf := _bot_has_tamed_wolf(b)
		b["_s_has_wolf"] = has_wolf
		b["_s_tame_wolf"] = null if has_wolf else _find_tameable_wolf(b, 20.0)
		var hunt_dir := str(_ai_active_directive(b).get("action", "")) == "hunt"
		b["_s_prey"] = _find_huntable_prey(b, 44.0 if hunt_dir else 32.0)
		b["_s_corpse"] = _find_guttable_corpse(b, 22.0) if b.get("gut_target") == null else null
		b["_s_loot"] = _find_nearby_valuable_loot(b, 28.0)
		_observe_nearby_world(b)
		_try_share_allied_knowledge(b)
		# Orden de equipo "equip": si no queda equipo suelto a mano, se da por cumplida
		if bool(b.get("equip_mission", false)) and (b["_s_loot"] as Dictionary).is_empty():
			b["equip_mission"] = false

	# Luz nocturna con antorcha (se apaga si se está ocultando en su refugio)
	var is_night := _is_world_night()
	var sh_pos: Vector3 = b["shelter_pos"]
	var camp_pos: Vector3 = b["camp_spot"]
	var hiding_in_shelter: bool = float(b["hide_timer"]) > 0.0 and sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 2.6
	b["torch_lit"] = is_night and not hiding_in_shelter and _bot_has_item(proxy, "Antorcha")
	proxy.set_meta("torch_lit", bool(b["torch_lit"]))
	proxy.set_meta("in_built_shelter", sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 3.4)
	proxy.set_meta("crouching", bool(b["crouching"]))
	proxy.set_meta("prone", bool(b["prone"]))
	proxy.set_meta("sprinting", str(b["anim"]) == "run")
	proxy.set_meta("moving", moving_now)

	# 1) Detectar amenazas inmediatas: lobos/osos hostiles cercanos
	var predator := _sensed_node(b, "_s_predator")
	if predator != null:
		_handle_predator_encounter(b, predator, delta)
		return

	# 2) Doma de lobos: si hay un lobo salvaje cerca (10..22 m), tenemos carne cruda y aún no tenemos lobo domado
	if float(b["tame_cooldown"]) <= 0.0 and not bool(b.get("_s_has_wolf", false)):
		var wild_wolf := _sensed_node(b, "_s_tame_wolf")
		if wild_wolf != null and _bot_has_raw_meat(proxy):
			_perform_wolf_taming_step(b, wild_wolf, delta)
			return

	# 3) Combate contra enemigos humanos / otros bots de facción opuesta
	var human_foe := _sensed_node(b, "_s_foe")
	if human_foe != null:
		# Herido grave (< 30 HP) o en huida: repliegue real. Con refugio va a
		# ocultarse; sin refugio escapa en zigzag hasta perder la amenaza.
		var fleeing: bool = float(b["flee_until"]) > 0.0
		if fleeing:
			b["flee_until"] = maxf(0.0, float(b["flee_until"]) - delta)
		if (float(b["health"]) < 30.0 or fleeing) and not _has_combat_edge(b, human_foe):
			if sh_pos != Vector3.INF:
				b["hide_timer"] = 20.0
				_move_bot_towards(b, sh_pos, 5.2, delta, "run")
				if proxy.global_position.distance_to(sh_pos) < 1.8:
					b["crouching"] = true
					b["sitting"] = true
					b["anim"] = "sit"
				return
			if not fleeing:
				b["flee_until"] = 14.0
			var away := proxy.global_position - human_foe.global_position
			away.y = 0.0
			var away_dir := away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 1.2:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var side := Vector3(-away_dir.z, 0.0, away_dir.x)
			_move_bot_towards(b, proxy.global_position + (away_dir + side * float(b["strafe_dir"]) * 0.5).normalized() * 8.0, 5.0, delta, "run")
			return
		_engage_foe(b, human_foe, delta)
		return

	b["is_aiming"] = false

	# 3b) Destripado en curso: caminar hasta el cadáver y dedicarle unos
	# segundos agachado. Se abandona si el cadáver desaparece, se aleja
	# demasiado o el bot ya no necesita nada de él.
	var gut: Node3D = b.get("gut_target")
	if gut != null:
		var gut_ok: bool = is_instance_valid(gut) and not bool(gut.get("_gutted"))
		var gdist: float = proxy.global_position.distance_to(gut.global_position) if gut_ok else 999.0
		if not gut_ok or gdist > 60.0 or not _bot_wants_animal_loot(b, proxy):
			b["gut_target"] = null
		elif gdist > 2.4:
			_move_bot_towards(b, gut.global_position, 4.6, delta, "run")
			return
		else:
			b["gut_t"] = float(b["gut_t"]) + delta
			b["anim"] = "sit"
			if float(b["gut_t"]) >= 3.5:
				b["gut_target"] = null
				_bot_harvest_dead_animal(b, gut)
			return

	# 4) Sed critica sin botellas: ir al rio/lago a beber (solo si no esta
	# siguiendo ordenes de equipo o la sed es critica de verdad)
	var leader := _sensed_node(b, "_s_leader")
	var thirsty_line := 32.0 + (13.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0)
	if float(b["thirst"]) < thirsty_line and not _bot_has_drink(proxy) and (leader == null or float(b["thirst"]) < 18.0):
		if b["drink_at"] == Vector3.INF:
			b["drink_at"] = _nearest_water_pos(proxy.global_position)
		if b["drink_at"] != Vector3.INF:
			var d_water := Vector2(proxy.global_position.x - b["drink_at"].x, proxy.global_position.z - b["drink_at"].z).length()
			# Con agua vadeable basta tener los pies mojados para beber; el centro
			# del segmento puede quedar en zona profunda e inalcanzable.
			var feet_wet := false
			if world != null and world.has_method("get_river_depth_at"):
				feet_wet = float(world.get_river_depth_at(proxy.global_position)) > 0.05
			if d_water > 3.5 and not feet_wet:
				_move_bot_towards(b, b["drink_at"], 4.6, delta, "run")
			else:
				# En la orilla: se agacha a beber unos segundos y repone su sed
				b["drinking_timer"] = float(b["drinking_timer"]) + delta
				b["crouching"] = true
				b["sitting"] = false
				b["anim"] = "idle"
				if float(b["drinking_timer"]) >= 3.5:
					b["drinking_timer"] = 0.0
					b["drink_at"] = Vector3.INF
					b["thirst"] = 100.0
					proxy.set_meta("saved_thirst", 100.0)
					# Ya en la orilla, rellena su botella vacia: el rio es la
					# fuente y la botella solo la reserva que lleva encima.
					var inv_w: Array = proxy.get_meta("saved_inventory", [])
					for i in range(inv_w.size()):
						var it_w = inv_w[i]
						if it_w is Dictionary and str(it_w.get("name", "")) == "Botella de plastico" and int(it_w.get("quantity", 1)) > 0:
							it_w["quantity"] = int(it_w.get("quantity", 1)) - 1
							if int(it_w["quantity"]) <= 0:
								inv_w.remove_at(i)
							_bot_add_inventory_item(inv_w, {"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 1, "use_value": 45.0})
							proxy.set_meta("saved_inventory", inv_w)
							break
			return

	# 4b) Hambre sin comida comestible: forrajeo — setas (eat_food) y arboles
	# frutales (pick_fruit), lo mismo que buscaria un jugador hambriento.
	if _bot_try_forage(b, delta):
		return

	# 4c) Caza de presas (ciervos/zorros) y aprovechamiento de cadáveres cuando
	# falta comida o materiales animales (pieles, tendón para cuerda, hueso).
	if leader == null and _bot_try_hunt_or_scavenge(b, delta):
		return

	# 5) Si está reclutado en el equipo de un jugador, obedecer órdenes de equipo
	if leader != null:
		_tick_teammate_behavior(b, leader, delta)
		return

	# 5) Saqueo oportuno de objetos cercanos (comida, armas, ropa mejor, materiales)
	var loot_action: Dictionary = b.get("_s_loot", {})
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

	# 5b) Materiales de campamento: si faltan palos para el refugio/fogata y no
	# hay drops a mano, el bot tala arbustos (fell_bush) igual que un jugador —
	# filo en mano, 5 s de corte, 3 palos y semillas al suelo.
	if _bot_try_gather_mats(b, delta):
		return

	# 6) Construir campamento propio (refugio + camuflaje/pieles + fogata) y ocultarse/descansar
	if str(b["shelter_id"]).is_empty() and _can_bot_build_shelter(proxy):
		var d_camp := Vector2(proxy.global_position.x - camp_pos.x, proxy.global_position.z - camp_pos.z).length()
		if d_camp > 2.4:
			_move_bot_towards(b, camp_pos, 3.8, delta, "walk")
			return
		_bot_build_shelter(b, camp_pos)
		return

	if not str(b["shelter_id"]).is_empty() and str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)) and _can_bot_build_campfire(proxy):
		# La fogata tambien necesita suelo valido: junto al refugio pero nunca
		# en agua, carretera, pendiente ni zona habitada.
		var fire_spot := Vector3.INF
		for off in [Vector3(2.8, 0.0, 1.4), Vector3(-2.8, 0.0, 1.4), Vector3(0.0, 0.0, 3.2), Vector3(2.8, 0.0, -1.4), Vector3(0.0, 0.0, -3.2)]:
			var cand: Vector3 = sh_pos + off
			cand.y = _ground_y(cand.x, cand.z)
			if _is_flat_dry_pos(cand, str(b["shelter_id"])):
				fire_spot = cand
				break
		if fire_spot != Vector3.INF:
			_bot_build_and_light_campfire(b, fire_spot)
		else:
			# Sin sitio valido: no construye la fogata y sigue con su vida,
			# en vez de quedar bloqueado intentandolo cada tick.
			b["no_fire_spot"] = true
		return

	# De noche o con poca salud o emboscando (bandido), el superviviente vuelve a su refugio
	# (o a la casa/fogata segura mas cercana si aun no construyo el suyo), cocina y descansa
	var wants_camp: bool = is_night or float(b["health"]) < 65.0 or float(b["hide_timer"]) > 0.0
	var rest_pos: Vector3 = sh_pos if sh_pos != Vector3.INF else _nearest_safe_refuge(b, 85.0)
	if rest_pos != Vector3.INF and wants_camp:
		b["hide_timer"] = maxf(0.0, float(b["hide_timer"]) - delta)
		var d_sh := Vector2(proxy.global_position.x - rest_pos.x, proxy.global_position.z - rest_pos.z).length()
		if d_sh > 1.8:
			_move_bot_towards(b, rest_pos, 3.8, delta, "walk")
			return
		# Dentro del refugio: encender fogata si se apagó, asar carne y descansar/ocultarse
		if sh_pos != Vector3.INF:
			_ensure_bot_campfire_lit(b)
		if float(b["cook_cooldown"]) <= 0.0 and _bot_has_raw_meat(proxy) and (sh_pos != Vector3.INF or _is_near_any_lit_campfire(proxy.global_position, 6.0)):
			_bot_cook_meat_at_fire(b)
		# Solo craftea en el refugio si esta sano y no se esta ocultando de una
		# amenaza: herido o escondido descansa/aguanta, no se pone a tallar.
		if float(b["health"]) >= 70.0 and float(b["hide_timer"]) <= 0.0 and _bot_try_craft(b, delta):
			return
		b["sitting"] = true
		b["crouching"] = str(b["faction"]) == "hostile"
		proxy.set_meta("crouching", bool(b["crouching"]))
		b["anim"] = "sit"
		if float(b["health"]) < 100.0:
			var healed := minf(100.0, float(b["health"]) + delta * 1.8)
			b["health"] = healed
			proxy.set_meta("proxy_health", healed)
			proxy.set_meta("saved_health", healed)
		return

	# 6b) Crafteo: sin urgencias, fabrica con los mismos RECIPES que un jugador
	# (herramientas, armas, flechas, cuerda, ropa de piel, antorcha, comida...)
	if _bot_try_craft(b, delta):
		return

	# 7) Exploracion como un jugador real: viaja por puntos de interes (casas,
	# tiendas militares, ciudad, graneros, zonas salvajes) recordando los ya
	# visitados entre vidas, y evitando la zona donde murio la ultima vez.
	b["sitting"] = false
	b["crouching"] = false
	b["caution_until"] = maxf(0.0, float(b.get("caution_until", 0.0)) - delta)
	# Subida/bajada por escaleras siguiendo una ruta de peldaños (torres, pisos)
	if (b.get("climb_route", []) as Array).size() >= 2:
		_tick_bot_climb(b, delta)
		return
	var cur_target: Vector3 = b.get("explore_target", Vector3.INF)
	var flat_t := 9999.0
	if cur_target != Vector3.INF:
		flat_t = Vector2(proxy.global_position.x - cur_target.x, proxy.global_position.z - cur_target.z).length()
	if cur_target != Vector3.INF and flat_t < 4.0:
		# Llegada: marca el sitio como visitado y para a saquear/mirar alrededor
		_mark_poi_visited(b, cur_target)
		b["explore_target"] = Vector3.INF
		b["explore_dwell"] = randf_range(5.0, 12.0)
		cur_target = Vector3.INF
	if cur_target == Vector3.INF and float(b.get("explore_dwell", 0.0)) <= 0.0:
		b["explore_target"] = _choose_explore_target(b)
		cur_target = b["explore_target"]
	if float(b.get("explore_dwell", 0.0)) > 0.0:
		b["explore_dwell"] = float(b["explore_dwell"]) - delta
		b["anim"] = "idle"
		return
	if cur_target == Vector3.INF:
		# Sin POIs en el mundo (tests): patrulla heredada del config
		var patrol: Array = b["patrol"]
		if patrol.is_empty():
			b["anim"] = "idle"
			return
		var dwell := float(b.get("patrol_dwell", 0.0))
		if dwell > 0.0:
			b["patrol_dwell"] = dwell - delta
			b["anim"] = "idle"
			return
		var p_idx := int(b["patrol_idx"]) % patrol.size()
		var goal: Vector3 = patrol[p_idx]
		if Vector2(proxy.global_position.x - goal.x, proxy.global_position.z - goal.z).length() < 2.6:
			b["patrol_idx"] = (p_idx + 1) % patrol.size()
			goal = patrol[int(b["patrol_idx"])]
			b["patrol_dwell"] = randf_range(3.0, 9.0)
		var move_item := "Antorcha" if bool(b["torch_lit"]) else _best_weapon_name(proxy)
		b["held_item"] = move_item
		b["has_rifle"] = move_item == "Fusil de asalto" or move_item == "Rifle francotirador"
		proxy.set_meta("saved_held_item", move_item)
		_move_bot_towards(b, goal, 3.4, delta, "walk")
		return
	var move_item := "Antorcha" if bool(b["torch_lit"]) else _best_weapon_name(proxy)
	b["held_item"] = move_item
	b["has_rifle"] = move_item == "Fusil de asalto" or move_item == "Rifle francotirador"
	proxy.set_meta("saved_held_item", move_item)
	_move_bot_towards(b, cur_target, 3.5, delta, "walk")

# Puntos de interes del mundo: lo mismo que un jugador iria a saquear.
func _explore_pois() -> Array:
	if _poi_cache_built:
		return _poi_cache
	if world == null:
		return []
	var hf = world.get("HOUSE_FOOTPRINTS")
	if hf is Array:
		for h in hf:
			if h is Dictionary and h.get("origin") is Vector3:
				_poi_cache.append({"pos": h["origin"], "kind": "house"})
	for k in ["_military_tent_pos", "_remote_tent_pos", "_city_tent_pos", "_city_tent2_pos"]:
		var t = world.get(k)
		if t is Vector3 and (t as Vector3) != Vector3.ZERO:
			_poi_cache.append({"pos": t, "kind": "military"})
	for definition in CityBlock.BUILDINGS:
		if definition.get("position") is Vector3:
			_poi_cache.append({"pos": CityExpansion.CENTER + (definition["position"] as Vector3), "kind": "city"})
	var zones = world.get("_spawn_zones")
	if zones is Array:
		for z in zones:
			if z is Vector3:
				_poi_cache.append({"pos": z, "kind": "wild"})
	# La torre militar es un POI con altura: la ruta en caracol de sus
	# escaleras la guarda el mundo en _watchtower_climb.
	var wtc = world.get("_watchtower_climb")
	if wtc is Array and wtc.size() >= 2:
		_poi_cache.append({"pos": (wtc as Array).back(), "kind": "tower", "route": wtc})
	_poi_cache_built = true
	return _poi_cache

func _poi_id(p: Dictionary) -> String:
	var pp: Vector3 = p["pos"]
	return "%s:%d:%d" % [str(p.get("kind", "?")), int(pp.x), int(pp.z)]

func _mark_poi_visited(b: Dictionary, pos: Vector3) -> void:
	var mem: Dictionary = b.get("_mem", {})
	var visited: Array = mem.get("visited", [])
	var bid := int(b.get("bot_id", 0))
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		if Vector2(pos.x - pp.x, pos.z - pp.z).length() < 12.0:
			var id := _poi_id(p)
			if not visited.has(id):
				visited.append(id)
			observe_location(bid, id, str(p.get("kind", "wild")), pp, "observed", true)
			record_strategy_outcome(bid, "explore_" + str(p.get("kind", "wild")), true, 0.04)
	mem["visited"] = visited
	b["_visited"] = visited

# Elige el siguiente destino de exploracion como haria un jugador: prefiere
# sitios no visitados, acordes a su personalidad y rol, cercanos, y nunca el
# lugar donde murio la ultima vez.
func _choose_explore_target(b: Dictionary) -> Vector3:
	# Directiva del asesor externo (si existe y no ha caducado): puede forzar un
	# destino concreto (volver a casa/descansar/conocido) o filtrar tipos de POI.
	var directive := _ai_active_directive(b)
	if not directive.is_empty() and str(directive.get("mode", "")) == "pos":
		var dp = directive.get("pos")
		if dp is Vector3 and (dp as Vector3) != Vector3.INF:
			return dp
	var only_kinds: Array = directive.get("only_kinds", []) if not directive.is_empty() else []
	var avoid_kinds: Array = directive.get("avoid_kinds", []) if not directive.is_empty() else []
	var pois := _explore_pois()
	if pois.is_empty():
		return Vector3.INF
	var proxy: Node3D = b["proxy"]
	var mem: Dictionary = b.get("_mem", {})
	var visited: Array = mem.get("visited", [])
	var known: Dictionary = mem.get("known_locations", {})
	var pers: Dictionary = _get_bot_personality(b)
	var death_pos: Vector3 = mem.get("last_death_pos", Vector3.INF)
	var hostile := str(b["faction"]) == "hostile"
	var bravery := float(pers.get("bravery", 0.5))
	var curiosity := float(pers.get("curiosity", 0.5))
	var aggro_t := float(pers.get("aggression", 0.3))
	var surv_t := float(pers.get("survival_instinct", 0.7))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var best := Vector3.INF
	var best_score := -1e9
	var best_p: Dictionary = {}
	# Dos pasadas: primero solo sitios no visitados; si ya los vio todos, cualquiera.
	for pass_i in range(2):
		for p in pois:
			var pp: Vector3 = p["pos"]
			var pid := _poi_id(p)
			if pass_i == 0 and visited.has(pid):
				continue
			if death_pos != Vector3.INF and Vector2(pp.x - death_pos.x, pp.z - death_pos.z).length() < 70.0:
				continue
			var kind := str(p["kind"])
			if not only_kinds.is_empty() and not only_kinds.has(kind):
				continue
			if avoid_kinds.has(kind):
				continue
			var w := 1.0
			if hostile:
				# El supervivista hostil pondera torre/militar/ciudad según agresividad y valentía
				w = (2.4 + aggro_t * 0.8) if kind == "tower" else ((1.8 + bravery * 0.6) if kind in ["military", "city"] else 0.6)
			else:
				if kind == "tower":
					w = 0.25 + bravery * 0.45
				elif kind == "military":
					w = 1.1 + bravery * 0.75
				elif kind == "house":
					w = 1.3 + surv_t * 0.45
				elif kind == "wild":
					w = 0.9 + curiosity * 0.55
				else:
					w = 0.85 + curiosity * 0.35
			# Si ya conoce la ubicación por observación o comunicación aliada, tiene bono de certeza
			if known.has(pid):
				w *= 1.12
			var d := Vector2(proxy.global_position.x - pp.x, proxy.global_position.z - pp.z).length()
			var score := w * 100.0 - d * 0.8 + rng.randf_range(0.0, 45.0)
			score *= _ai_poi_memory_factor(b, pp, kind)
			if score > best_score:
				best_score = score
				best = pp
				best_p = p
		if best != Vector3.INF:
			break
	if str(best_p.get("kind", "")) == "tower" and best_p.get("route") is Array:
		b["climb_route"] = best_p["route"]
		b["climb_i"] = -1
		b["climb_down"] = false
		b["climb_dwell"] = 0.0
	return best

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
	# Comer si tiene hambre o necesita recuperar vida. Si ya murio de inanicion
	# aprendio a no apurar: come antes de llegar al limite.
	var hunger_line := 60.0 + (16.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0)
	# Orden directa del líder "come": come la mejor comida aunque no tenga hambre
	var force_eat := bool(b.get("forced_eat", false))
	if force_eat:
		b["forced_eat"] = false
	if (force_eat or float(b["hunger"]) < hunger_line or float(b["health"]) < 80.0) and float(b["eat_cooldown"]) <= 0.0:
		var desperate := float(b["hunger"]) < 28.0
		for i in range(inv.size()):
			var it = inv[i]
			if not (it is Dictionary):
				continue
			var nm := str(it.get("name", ""))
			# Latas cerradas y pescado crudo no se pueden comer directamente:
			# la lata hay que abrirla antes con cuchillo/hacha (receta de crafteo).
			if str(it.get("type", "")) != "food" or nm == "Carne humana" or nm == "Pez crudo" \
					or (nm.begins_with("Lata de ") and not nm.ends_with(" abierta")):
				continue
			# La carne cruda solo se come desesperado: un superviviente real la cocina
			if nm.begins_with("Carne cruda") and not desperate:
				continue
			var use_v := float(it.get("use_value", 18.0))
			var gain_h := use_v
			var gain_t := use_v * 0.20
			var gain_hp := maxf(3.0, use_v * 0.35)
			var is_can := false
			var bite := 1.0
			if nm.begins_with("Lata de ") and nm.ends_with(" abierta"):
				# Latas abiertas: se comen por porciones del 50% restante,
				# igual que en el inventario del jugador.
				is_can = true
				var dmax := float(it.get("max_durability", 100.0))
				var dcur := float(it.get("durability", dmax))
				var rem := clampf(dcur / dmax, 0.0, 1.0) if dmax > 0.0 else 0.0
				if rem <= 0.0:
					continue
				bite = minf(0.5, rem)
				gain_h = use_v * bite
				gain_t = use_v * 0.15 * bite
				gain_hp = maxf(3.0, use_v * 0.35 * bite)
			elif nm == "Naranja":
				gain_t = use_v * 0.80
				gain_hp = maxf(2.0, use_v * 0.20)
			elif nm == "Higo":
				gain_t = use_v * 0.70
				gain_hp = maxf(5.0, use_v * 0.50)
			elif nm.begins_with("Carne cruda"):
				gain_h = use_v * 0.4
				gain_t = use_v * 0.10
				gain_hp = 0.0
			if is_can:
				var dmax2 := float(it.get("max_durability", 100.0))
				it["durability"] = float(it.get("durability", dmax2)) - dmax2 * bite
				if float(it["durability"]) <= 0.0:
					inv.remove_at(i)
			else:
				it["quantity"] = int(it.get("quantity", 1)) - 1
				if int(it["quantity"]) <= 0:
					inv.remove_at(i)
			b["hunger"] = minf(100.0, float(b["hunger"]) + gain_h)
			b["thirst"] = minf(100.0, float(b["thirst"]) + gain_t)
			b["health"] = minf(100.0, float(b["health"]) + gain_hp)
			var new_hp := minf(100.0, float(b["health"]))
			proxy.set_meta("proxy_health", new_hp)
			proxy.set_meta("saved_health", new_hp)
			proxy.set_meta("saved_inventory", inv)
			b["eat_cooldown"] = 10.0
			break
	# Beber de botellas/cantimplora que lleve encima
	if float(b["thirst"]) < 55.0 and float(b["eat_cooldown"]) <= 0.0:
		for i in range(inv.size()):
			var it = inv[i]
			if not (it is Dictionary):
				continue
			var nm := str(it.get("name", ""))
			var tp := str(it.get("type", ""))
			if tp != "water" and not nm.contains("agua") and not nm.contains("Cantimplora"):
				continue
			it["quantity"] = int(it.get("quantity", 1)) - 1
			if int(it["quantity"]) <= 0:
				inv.remove_at(i)
			# Una botella llena deja la vacia reutilizable; un humano guarda un
			# par para rellenar y tira el resto — sin tope la mochila se llena.
			if nm == "Botella de agua llena" and _bot_item_count(proxy, "Botella de plastico") < 1:
				_bot_add_inventory_item(inv, {"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0})
			b["thirst"] = minf(100.0, float(b["thirst"]) + maxf(30.0, float(it.get("use_value", 40.0))))
			proxy.set_meta("saved_inventory", inv)
			proxy.set_meta("saved_thirst", float(b["thirst"]))
			b["eat_cooldown"] = 6.0
			break
	# Auto-equipar mejor ropa o mochila que haya saqueado
	_auto_equip_best_gear(b)

func _auto_equip_best_gear(b: Dictionary) -> void:
	# Como un jugador real: empiezan con la ropa de su preview de inicio y van
	# mejorando cada pieza que saquean. Aprenden que la ropa de piel es la
	# mejor (prioridad 6 en CLOTHING_PRIORITY) y se la quedan puesta.
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var worn: Array = str(b["clothing"]).split(",")
	var worn_changed := false
	var to_remove: Array = []
	for it in inv.duplicate():
		if not (it is Dictionary):
			continue
		var nm := str(it.get("name", ""))
		var tp := str(it.get("type", ""))
		if tp == "backpack" and (nm == "Mochila militar" or (nm == "Mochila pequena" and str(b["backpack"]).is_empty())):
			b["backpack"] = nm
			proxy.set_meta("saved_backpack", nm)
		elif tp == "clothing" and PlayerController.CLOTHING_SLOTS.has(nm):
			var slot := str(PlayerController.CLOTHING_SLOTS[nm])
			var cur := _worn_in_slot(worn, slot)
			if int(CLOTHING_PRIORITY.get(nm, 0)) > int(CLOTHING_PRIORITY.get(cur, 0)):
				worn = _swap_worn_slot(worn, slot, nm)
				if not cur.is_empty():
					_bot_add_inventory_item(inv, {"name": cur, "type": "clothing", "weight": 0.6, "quantity": 1, "use_value": 0.0})
				it["quantity"] = int(it.get("quantity", 1)) - 1
				if int(it["quantity"]) <= 0:
					to_remove.append(it)
				worn_changed = true
				if nm.contains("piel"):
					(b.get("_mem", {}) as Dictionary)["gear_learned"] = true
	for it in to_remove:
		inv.erase(it)
	if worn_changed:
		b["clothing"] = ",".join(worn)
		proxy.set_meta("saved_clothing", b["clothing"])
		proxy.set_meta("saved_inventory", inv)

func _worn_in_slot(worn: Array, slot: String) -> String:
	for nm in worn:
		if str(PlayerController.CLOTHING_SLOTS.get(nm, "")) == slot:
			return nm
	return ""

func _swap_worn_slot(worn: Array, slot: String, new_nm: String) -> Array:
	var out: Array = []
	var placed := false
	for nm in worn:
		if str(PlayerController.CLOTHING_SLOTS.get(nm, "")) == slot:
			if not placed:
				out.append(new_nm)
				placed = true
		else:
			out.append(nm)
	if not placed:
		out.append(new_nm)
	return out

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
	var ppos := predator.global_position
	var dist := proxy.global_position.distance_to(ppos)
	var to_pred := ppos - proxy.global_position
	to_pred.y = 0.0
	if to_pred.length_squared() > 0.001:
		b["rot"] = atan2(-to_pred.x, -to_pred.z)
		proxy.rotation.y = float(b["rot"])

	var weapon := _best_weapon_name(proxy)
	var is_rifle := weapon == "Fusil de asalto" or weapon == "Rifle francotirador"
	var melee_reach := 4.0 if weapon in ["Lanza", "Lanza de hueso", "Palo afilado", "Hacha"] else 3.5

	# Si ya está a salvo en su refugio construido o dentro de una casa (donde
	# lobos/osos no pueden entrar) y el depredador está fuera, un humano NO sale
	# corriendo a sus fauces: dispara desde seguro o aguanta a resguardo.
	if _is_bot_wolf_protected(b) and dist > melee_reach + 0.5:
		_command_bot_wolf_against(b, predator)
		var pick_safe := _pick_fight_weapon(b, dist)
		var skind := str(pick_safe.get("kind", "melee"))
		var sweapon := str(pick_safe.get("name", weapon))
		if skind in ["rifle", "bow", "thrown"] and _has_clear_shot(proxy.global_position, ppos):
			b["sitting"] = false
			b["crouching"] = false
			b["is_aiming"] = true
			b["held_item"] = sweapon
			b["has_rifle"] = skind == "rifle"
			proxy.set_meta("saved_held_item", sweapon)
			b["anim"] = "idle"
			if float(b["shoot_cooldown"]) <= 0.0:
				if skind == "rifle":
					b["shoot_cooldown"] = 0.95 if sweapon == "Fusil de asalto" else 1.65
					_bot_fire_rifle_at(b, predator, 68.0 if sweapon == "Fusil de asalto" else 145.0)
				elif skind == "bow":
					b["shoot_cooldown"] = 1.55 if sweapon == "Arco reforzado" else 1.9
					_bot_fire_bow(b, predator, sweapon)
				else:
					b["shoot_cooldown"] = 2.1
					_bot_fire_thrown(b, predator, sweapon, false)
			return
		b["is_aiming"] = false
		b["sitting"] = true
		b["crouching"] = true
		proxy.set_meta("crouching", true)
		b["anim"] = "sit"
		return

	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	proxy.set_meta("crouching", false)
	b["held_item"] = weapon
	b["has_rifle"] = is_rifle
	proxy.set_meta("saved_held_item", weapon)

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
	# Sin arma de fuego un superviviente no caza lobos ni osos: huye como haría
	# un humano y solo pelea cuerpo a cuerpo cuando el animal ya está encima.
	if dist > melee_reach + 2.2:
		_flee_predator(b, predator, delta)
		return
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
			# Si lo mata, valora si merece destriparlo (no recoge por recoger)
			if bool(predator.get("_is_dead")):
				_bot_credit_kill(b, predator)
				_bot_start_gutting(b, predator)
	else:
		# Acorralado: cierra el último tramo para poder defenderse
		_move_bot_towards(b, ppos, 4.9, delta, "run")

# Como un humano, el bot no caza depredadores sin arma de fuego: huye a un
# lugar seguro (su refugio, una fogata encendida o una casa) o en zigzag.
# Si tiene antorcha la enciende para intimidar al lobo (wary_torch), y si tiene
# boleadoras las lanza para frenar al perseguidor mientras escapa.
func _flee_predator(b: Dictionary, predator: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	_command_bot_wolf_against(b, predator)
	b["caution_until"] = maxf(float(b.get("caution_until", 0.0)), 9.0)
	var dist := proxy.global_position.distance_to(predator.global_position)
	# Antorcha encendida: mantiene a los lobos a raya (wary_torch en WildlifeController)
	if str(predator.get("animal_type")) == "wolf" and _bot_has_item(proxy, "Antorcha"):
		b["torch_lit"] = true
		b["held_item"] = "Antorcha"
		b["has_rifle"] = false
		proxy.set_meta("torch_lit", true)
		proxy.set_meta("saved_held_item", "Antorcha")
	# Boleadoras defensivas en huida: frena 6 s al depredador sin detenerse a pelear
	if _bot_item_count(proxy, "Boleadoras") > 0 and float(b["shoot_cooldown"]) <= 0.0 and dist >= 4.5 and dist <= 18.0:
		if float(predator.get_meta("bola_slow_until", 0.0)) < Time.get_unix_time_from_system() and _has_clear_shot(proxy.global_position, predator.global_position):
			b["shoot_cooldown"] = 2.6
			_bot_fire_thrown(b, predator, "Boleadoras", true)
	var sh_pos: Vector3 = b["shelter_pos"]
	if sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 110.0:
		var to_sh := sh_pos - proxy.global_position
		var to_pr := predator.global_position - proxy.global_position
		if to_sh.length() < 3.5 or to_sh.normalized().dot(to_pr.normalized()) < 0.35:
			b["hide_timer"] = 10.0
			_move_bot_towards(b, sh_pos, 5.2, delta, "run")
			return
	var refuge := _nearest_safe_refuge(b, 95.0, predator.global_position)
	if refuge != Vector3.INF:
		if proxy.global_position.distance_to(refuge) < 3.5:
			b["hide_timer"] = 8.0
		_move_bot_towards(b, refuge, 5.2, delta, "run")
		return
	var away := proxy.global_position - predator.global_position
	away.y = 0.0
	var away_dir := away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
	b["strafe_timer"] = float(b["strafe_timer"]) + delta
	if float(b["strafe_timer"]) > 1.1:
		b["strafe_dir"] = -float(b["strafe_dir"])
		b["strafe_timer"] = 0.0
	var side := Vector3(-away_dir.z, 0.0, away_dir.x)
	_move_bot_towards(b, proxy.global_position + (away_dir + side * float(b["strafe_dir"]) * 0.45).normalized() * 9.0, 5.2, delta, "run")

func _is_near_any_lit_campfire(pos: Vector3, max_dist: float) -> bool:
	if world == null or not ("_lit_campfires" in world):
		return false
	var r_sq := max_dist * max_dist
	for lc in world._lit_campfires:
		if lc is Dictionary and lc.get("pos") is Vector3:
			if pos.distance_squared_to(lc["pos"] as Vector3) <= r_sq:
				return true
	return false

# Comprueba si el bot ya está dentro de un refugio construido o de una casa
# cerrada/abierta donde lobos y osos tienen prohibido entrar.
func _is_bot_wolf_protected(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	var pos := proxy.global_position
	var sh_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
	if sh_pos != Vector3.INF and pos.distance_to(sh_pos) < 3.4:
		return true
	if world != null and world.has_method("_is_player_in_house") and world._is_player_in_house(pos):
		return true
	if world != null and "wildlife_blockers" in world:
		var p2 := Vector2(pos.x, pos.z)
		for blk in world.wildlife_blockers:
			if blk is Dictionary and (blk as Dictionary).has("house_bounds"):
				var hb: Rect2 = (blk as Dictionary)["house_bounds"]
				if hb.grow(-0.4).has_point(p2):
					return true
	return false

# Refugio seguro más cercano (propio refugio, fogata encendida o casa real)
# cuya dirección no obligue a correr hacia la amenaza.
func _nearest_safe_refuge(b: Dictionary, max_dist: float, threat_pos: Vector3 = Vector3.INF) -> Vector3:
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	var to_threat := Vector3.ZERO
	var has_threat := threat_pos != Vector3.INF
	if has_threat:
		to_threat = threat_pos - cur
		to_threat.y = 0.0
	var candidates: Array = []
	var sh_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
	if sh_pos != Vector3.INF:
		candidates.append(sh_pos)
	if world != null and "_lit_campfires" in world:
		for lc in world._lit_campfires:
			if lc is Dictionary and lc.get("pos") is Vector3:
				candidates.append(lc["pos"] as Vector3)
	if world != null and "wildlife_blockers" in world:
		for blk in world.wildlife_blockers:
			if blk is Dictionary and (blk as Dictionary).has("house_bounds"):
				var hb: Rect2 = (blk as Dictionary)["house_bounds"]
				var hc := hb.get_center()
				candidates.append(Vector3(hc.x, _ground_y(hc.x, hc.y), hc.y))
	var best := Vector3.INF
	var best_d := max_dist
	for cand in candidates:
		var cpos: Vector3 = cand
		var d := Vector2(cur.x - cpos.x, cur.z - cpos.z).length()
		if d > best_d:
			continue
		if has_threat and d > 2.5 and to_threat.length_squared() > 0.01:
			var to_c := cpos - cur
			to_c.y = 0.0
			if to_c.length_squared() > 0.01 and to_c.normalized().dot(to_threat.normalized()) > 0.25:
				continue
		best_d = d
		best = cpos
	return best

# Un humano no destripa cada cadáver que mata: solo le interesa si le falta
# algo — carne cuando tiene hambre o sin reserva, piel mientras le falte
# equipo de abrigo. Y necesita un filo igual que el jugador.
func _bot_wants_pelts(b: Dictionary, proxy: Node3D) -> bool:
	const FUR := ["Chaqueta de piel", "Pantalones de piel", "Botas de piel", "Guantes de piel", "Tocado de piel animal", "Gorro de piel"]
	var fur_worn := 0
	for it in b["clothing"]:
		if str(it) in FUR:
			fur_worn += 1
	var pelts := 0
	for it in proxy.get_meta("saved_inventory", []):
		var entry: Dictionary = it
		if str(entry.get("name", "")).begins_with("Piel de "):
			pelts += int(entry.get("quantity", 1))
	return fur_worn * 3 + pelts < 9

func _bot_wants_animal_loot(b: Dictionary, proxy: Node3D) -> bool:
	if not _bot_has_can_opener(proxy):
		return false
	if float(b["hunger"]) < 62.0 or not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0):
		return true
	return _bot_wants_pelts(b, proxy)

# Tras una baja se agenda el destripado: el bot camina hasta el cadáver y
# dedica unos segundos agachado, igual que la acción del jugador.
func _bot_start_gutting(b: Dictionary, animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal) or bool(animal.get("_gutted")):
		return
	var proxy: Node3D = b["proxy"]
	if not _bot_wants_animal_loot(b, proxy):
		return
	if proxy.global_position.distance_to(animal.global_position) > 55.0:
		return
	b["gut_target"] = animal
	b["gut_t"] = 0.0

func _bot_harvest_dead_animal(b: Dictionary, animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal) or bool(animal.get("_gutted")):
		return
	var proxy: Node3D = b["proxy"]
	if not _bot_has_can_opener(proxy):
		return
	var take_meat := float(b["hunger"]) < 62.0 or not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0)
	var take_pelts := _bot_wants_pelts(b, proxy)
	if not take_meat and not take_pelts:
		return
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var kind := str(animal.get("animal_type"))
	var meat_name := "Carne cruda de lobo"
	var meat_qty := 3
	var hide_name := "Piel de lobo"
	var hide_qty := 1
	var part_qty := 1
	match kind:
		"deer":
			meat_name = "Carne cruda de ciervo"
			meat_qty = 4
			hide_name = "Piel de ciervo"
			hide_qty = 2
			part_qty = 2
		"fox":
			meat_name = "Carne cruda de zorro"
			meat_qty = 2
			hide_name = "Piel de zorro"
			hide_qty = 1
			part_qty = 1
		"bear":
			meat_name = "Carne cruda de oso"
			meat_qty = 5
			hide_name = "Piel de oso"
			hide_qty = 3
			part_qty = 2
	if take_meat:
		_bot_add_inventory_item(inv, {"name": meat_name, "type": "food", "weight": 0.3, "quantity": meat_qty, "use_value": 15.0})
	if take_pelts:
		_bot_add_inventory_item(inv, {"name": hide_name, "type": "resource", "weight": 0.65, "quantity": hide_qty, "use_value": 0.0})
	# Hueso y tendón: solo si los necesita ahora para cuerda, refugio, arco o armas de hueso
	if _bot_item_count(proxy, "Tendón") < 4 and (_bot_wants_craft_input(b, "Tendón") or _bot_wants_craft_input(b, "Cuerda") or (str(b["shelter_id"]).is_empty() and _bot_item_count(proxy, "Cuerda") < 1)):
		_bot_add_inventory_item(inv, {"name": "Tendón", "type": "resource", "weight": 0.06, "quantity": part_qty, "use_value": 0.0})
	if _bot_item_count(proxy, "Hueso") < 4 and _bot_wants_craft_input(b, "Hueso"):
		_bot_add_inventory_item(inv, {"name": "Hueso", "type": "resource", "weight": 0.18, "quantity": part_qty, "use_value": 0.0})
	proxy.set_meta("saved_inventory", inv)
	animal.set("_gutted", true)
	var hg_mem: Dictionary = _ensure_bot_memory(int(b["bot_id"]), b.get("cfg", {}))
	var hg_st: Dictionary = hg_mem.get("stats", {})
	hg_st["animals_gutted"] = int(hg_st.get("animals_gutted", 0)) + 1
	hg_mem["stats"] = hg_st
	# collect_mode = true retira el cadáver y sincroniza animal_gutted sin
	# duplicar otro juego de pieles/carne en el suelo.
	if world != null and world.has_method("_net_gut_animal"):
		world._net_gut_animal(animal.name, int(b["bot_id"]), true)

# Acumula en mem.stats el tiempo vivo de la vida actual. Se llama al morir y
# en cada guardado periodico; el resto sin volcar lo calcula la telemetria.
func _bot_flush_alive_time(b: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var last := int(b.get("alive_flush_msec", now))
	b["alive_flush_msec"] = now
	if now <= last:
		return
	var fl_mem: Dictionary = _ensure_bot_memory(int(b.get("bot_id", 0)), b.get("cfg", {}))
	var fl_st: Dictionary = fl_mem.get("stats", {})
	fl_st["alive_total_sec"] = float(fl_st.get("alive_total_sec", 0.0)) + (now - last) / 1000.0
	fl_mem["stats"] = fl_st

func _bot_credit_kill(b: Dictionary, animal: Node3D) -> void:
	var ck_mem: Dictionary = _ensure_bot_memory(int(b.get("bot_id", 0)), b.get("cfg", {}))
	var ck_st: Dictionary = ck_mem.get("stats", {})
	var kind := str(animal.get("animal_type"))
	if kind == "wolf" or kind == "bear":
		ck_st["kills_predator"] = int(ck_st.get("kills_predator", 0)) + 1
	else:
		ck_st["kills_prey"] = int(ck_st.get("kills_prey", 0)) + 1
	ck_mem["stats"] = ck_st

# ==================== CAZA DE PRESAS (CIERVOS / ZORROS) ====================
# Así es como un humano consigue carne, pieles, hueso y tendón sin suicidarse
# contra lobos ni osos: acechando ciervos y zorros agachado (menor radio de
# alerta en WildlifeController), usando arco/lanza/boleadoras/fusil o
# persiguiéndolos hasta que agotan su sprint, y aprovechando cadáveres.

func _bot_should_hunt_prey(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if not _bot_has_can_opener(proxy):
		return false
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		return false
	if _sensed_node(b, "_s_leader") != null:
		return false
	var hunger := float(b["hunger"])
	if _is_world_night() and hunger >= 24.0:
		return false
	if hunger < 62.0 or not _bot_has_edible_food(proxy, hunger < 28.0):
		return true
	if str(_ai_active_directive(b).get("action", "")) == "hunt":
		return true
	var pick := _pick_fight_weapon(b, 16.0)
	if str(pick.get("kind", "melee")) != "melee" and _bot_wants_pelts(b, proxy):
		return true
	return false

func _find_huntable_prey(b: Dictionary, max_dist: float) -> Node3D:
	if world == null or world.get_tree() == null or not _bot_should_hunt_prey(b):
		return null
	var proxy: Node3D = b["proxy"]
	var best: Node3D = null
	var best_d := max_dist
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not (w is Node3D) or not is_instance_valid(w) or bool(w.get("_is_dead")):
			continue
		var at := str(w.get("animal_type"))
		if at != "deer" and at != "fox":
			continue
		var d := proxy.global_position.distance_to((w as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = w as Node3D
	return best

func _find_guttable_corpse(b: Dictionary, max_dist: float) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	if not _bot_wants_animal_loot(b, proxy):
		return null
	var best: Node3D = null
	var best_d := max_dist
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not (w is Node3D) or not is_instance_valid(w):
			continue
		if not bool(w.get("_is_dead")) or bool(w.get("_gutted")):
			continue
		var at := str(w.get("animal_type"))
		if at not in ["deer", "fox", "wolf", "bear"]:
			continue
		var d := proxy.global_position.distance_to((w as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = w as Node3D
	return best

func _bot_try_hunt_or_scavenge(b: Dictionary, delta: float) -> bool:
	var corpse := _sensed_node(b, "_s_corpse")
	if corpse != null and not bool(corpse.get("_gutted")) and b.get("gut_target") == null:
		_bot_start_gutting(b, corpse)
		if b.get("gut_target") != null:
			return true
	var prey := _sensed_node(b, "_s_prey")
	if prey == null or bool(prey.get("_is_dead")) or not _bot_should_hunt_prey(b):
		return false
	_hunt_prey(b, prey, delta)
	return true

func _hunt_prey(b: Dictionary, prey: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["sitting"] = false
	b["sleeping"] = false
	var ppos := prey.global_position
	var dist := proxy.global_position.distance_to(ppos)
	var to_prey := ppos - proxy.global_position
	to_prey.y = 0.0
	if to_prey.length_squared() > 0.001:
		b["rot"] = atan2(-to_prey.x, -to_prey.z)
		proxy.rotation.y = float(b["rot"])

	var pick := _pick_fight_weapon(b, dist)
	var wkind := str(pick.get("kind", "melee"))
	var weapon := str(pick.get("name", "Cuchillo"))
	# Si tiene boleadoras y la presa aún no está trabada, priorizar bolearla
	if wkind != "rifle" and _bot_item_count(proxy, "Boleadoras") > 0 and dist > 4.5 and dist <= 22.0:
		if float(prey.get_meta("bola_slow_until", 0.0)) < Time.get_unix_time_from_system():
			wkind = "bola"
			weapon = "Boleadoras"
	b["held_item"] = weapon
	b["has_rifle"] = wkind == "rifle"
	proxy.set_meta("saved_held_item", weapon)

	var prey_fleeing := str(prey.get("_state")) == "flee"
	var stalk_crouch := not prey_fleeing and dist > 12.5

	if wkind == "rifle" and dist > 3.5:
		b["is_aiming"] = true
		b["crouching"] = stalk_crouch
		proxy.set_meta("crouching", stalk_crouch)
		if dist > 30.0:
			_move_bot_towards(b, ppos, 2.8 if stalk_crouch else 4.4, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
		if dist <= 45.0 and float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, ppos):
			b["shoot_cooldown"] = 0.95 if weapon == "Fusil de asalto" else 1.65
			var dmg := 68.0 if weapon == "Fusil de asalto" else 145.0
			_bot_fire_rifle_at(b, prey, dmg)
		return

	if wkind == "bow" and dist > 4.5:
		b["is_aiming"] = true
		b["crouching"] = stalk_crouch
		proxy.set_meta("crouching", stalk_crouch)
		if dist > 22.0:
			_move_bot_towards(b, ppos, 2.7 if stalk_crouch else 4.2, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
		if dist <= 34.0 and float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, ppos):
			b["shoot_cooldown"] = 1.55 if weapon == "Arco reforzado" else 1.9
			_bot_fire_bow(b, prey, weapon)
		return

	if wkind in ["thrown", "bola"] and dist > 4.5:
		b["is_aiming"] = true
		b["crouching"] = stalk_crouch
		proxy.set_meta("crouching", stalk_crouch)
		if dist > 16.0:
			_move_bot_towards(b, ppos, 2.7 if stalk_crouch else 4.5, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
		if dist <= 22.0 and float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, ppos):
			b["shoot_cooldown"] = 2.6 if wkind == "bola" else 2.1
			_bot_fire_thrown(b, prey, weapon, wkind == "bola")
		return

	b["is_aiming"] = false
	var melee_reach := 4.0 if weapon in ["Lanza", "Lanza de hueso", "Palo afilado", "Hacha"] else 3.5
	if dist <= melee_reach:
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		b["anim"] = "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION
		if float(b["attack_cooldown"]) <= 0.0:
			b["attack_cooldown"] = 0.55
			var m_dmg := _weapon_melee_damage(weapon)
			if prey.has_method("take_damage"):
				prey.take_damage(m_dmg, true, proxy)
			if bool(prey.get("_is_dead")):
				_bot_credit_kill(b, prey)
				_bot_start_gutting(b, prey)
	elif stalk_crouch:
		# Acecho agachado: reduce el radio de alerta de 26 m a 12 m
		b["crouching"] = true
		proxy.set_meta("crouching", true)
		_move_bot_towards(b, ppos, 2.6, delta, "walk")
	else:
		# La presa ya arrancó o está trabada: esprintar tras ella hasta alcanzarla
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		_move_bot_towards(b, ppos, 5.1, delta, "run")

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
		drop_pos.y = _ground_y(drop_pos.x, drop_pos.z) + 0.06
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

# Alcance visual humano realista: de noche se ve menos (salvo que el objetivo
# lleve antorcha o linterna encendida, que lo delata), y un objetivo agachado
# o cuerpo a tierra o en refugio camuflado cuesta mucho más de distinguir.
func _effective_human_sight(target: Node3D, base_sight: float) -> float:
	if target == null or not is_instance_valid(target):
		return base_sight
	if bool(target.get_meta("in_built_shelter", false)):
		return 8.0
	var s := base_sight
	if _is_world_night():
		var lit: bool = bool(target.get_meta("torch_lit", false)) or target.get("_torch_lit") == true or bool(target.get_meta("flashlight_on", false))
		s *= 1.2 if lit else 0.62
	var is_prone_t: bool = (target.get("is_prone") == true) or bool(target.get_meta("prone", false))
	var is_crouch_t: bool = (target.get("is_crouching") == true) or bool(target.get_meta("crouching", false))
	if is_prone_t:
		s *= 0.42
	elif is_crouch_t:
		s *= 0.65
	return maxf(8.0, s)

func _find_combat_foe(b: Dictionary) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var aggro: Node3D = b.get("aggro_target")
	if aggro != null and is_instance_valid(aggro) and not bool(aggro.get_meta("proxy_dead", false)) and aggro.get("is_dead") != true:
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
			var p3 := p as Node3D
			var max_r := minf(best_d, _effective_human_sight(p3, sight))
			var d := proxy.global_position.distance_to(p3.global_position)
			if d < max_r and (d <= 10.0 or _has_clear_shot(proxy.global_position, p3.global_position)):
				best_d = d
				best = p3
		var local_p = world.get("player")
		if local_p is Node3D and is_instance_valid(local_p) and local_p.get("is_dead") != true:
			var lp3 := local_p as Node3D
			var max_rl := minf(best_d, _effective_human_sight(lp3, sight))
			var dl := proxy.global_position.distance_to(lp3.global_position)
			if dl < max_rl and (dl <= 10.0 or _has_clear_shot(proxy.global_position, lp3.global_position)):
				best_d = dl
				best = lp3
	else:
		# Aliado/cooperativo: ataca bandidos hostiles que se acerquen a él o a su líder
		for other_id in bots.keys():
			var ob: Dictionary = bots[other_id]
			if str(ob["faction"]) != "hostile":
				continue
			var op: Node3D = ob.get("proxy")
			if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
				continue
			var max_ro := minf(best_d, _effective_human_sight(op, sight))
			var d := proxy.global_position.distance_to(op.global_position)
			var dl := leader.global_position.distance_to(op.global_position) if leader != null else 9999.0
			var eff_d := minf(d, dl)
			if eff_d < max_ro and (eff_d <= 10.0 or _has_clear_shot(proxy.global_position, op.global_position)):
				best_d = eff_d
				best = op
	return best

# Un superviviente armado y con el enemigo a distancia no huye aunque este
# herido: puede seguir peleando a rango. Sin fusil o con el enemigo encima,
# la huida siempre gana.
func _has_combat_edge(b: Dictionary, foe: Node3D) -> bool:
	var proxy: Node3D = b["proxy"]
	if float(b["health"]) < 20.0:
		return false
	var dist := proxy.global_position.distance_to(foe.global_position)
	if dist <= 12.0:
		return false
	if bool(b["has_rifle"]):
		return true
	# Arco con flechas o arrojadizas tambien permiten mantener distancia
	if dist > 4.5:
		var bow := _bot_best_bow(proxy)
		if not bow.is_empty() and _bot_arrow_count(proxy) > 0:
			return true
		if not _bot_best_thrown_weapon(proxy).is_empty() or _bot_item_count(proxy, "Boleadoras") > 0:
			return true
	return false

func _engage_foe(b: Dictionary, foe: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false

	# Ordenar a su lobo domesticado que ataque también al objetivo
	_command_bot_wolf_against(b, foe)

	var fpos := foe.global_position
	var dist := proxy.global_position.distance_to(fpos)
	var to_foe := fpos - proxy.global_position
	to_foe.y = 0.0
	if to_foe.length_squared() > 0.001:
		b["rot"] = atan2(-to_foe.x, -to_foe.z)
		proxy.rotation.y = float(b["rot"])

	# Un superviviente usa el mismo arsenal que un jugador: elige el arma
	# segun la distancia — fusil, arco con flechas, arrojadiza o cuerpo a cuerpo.
	var pick := _pick_fight_weapon(b, dist)
	var weapon := str(pick.get("name", "Cuchillo"))
	var wkind := str(pick.get("kind", "melee"))
	b["held_item"] = weapon
	b["has_rifle"] = wkind == "rifle"
	proxy.set_meta("saved_held_item", weapon)

	if wkind == "rifle" and dist > 3.5 and dist <= 48.0:
		b["is_aiming"] = true
		# Combate como un jugador: si el enemigo esta demasiado lejos avanza;
		# si esta en rango de tiro, no se queda quieto — zigzaguea lateralmente
		# entre disparos para no ser un blanco facil.
		if dist > 26.0:
			_move_bot_towards(b, fpos, 4.2, delta, "run")
		else:
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 1.4:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var side := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
			_move_bot_towards(b, proxy.global_position + side * float(b["strafe_dir"]) * 3.0, 3.2, delta, "walk")
			b["rot"] = atan2(-to_foe.x, -to_foe.z)
			proxy.rotation.y = float(b["rot"])
		if float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, fpos):
			b["shoot_cooldown"] = 1.15 if weapon == "Fusil de asalto" else 1.85
			var dmg := 26.0 if weapon == "Fusil de asalto" else 48.0
			_bot_fire_rifle_at(b, foe, dmg)
		return
	if wkind == "rifle" and dist > 48.0:
		# Demasiado lejos para el fusil: acercarse corriendo en zigzag
		b["strafe_timer"] = float(b["strafe_timer"]) + delta
		if float(b["strafe_timer"]) > 1.8:
			b["strafe_dir"] = -float(b["strafe_dir"])
			b["strafe_timer"] = 0.0
		var side2 := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
		var zig_goal := fpos + side2 * float(b["strafe_dir"]) * 5.0
		_move_bot_towards(b, zig_goal, 4.6, delta, "run")
		return

	# Arco: consume una flecha por disparo, como un jugador. A distancia media
	# se mueve en zigzag; si el rival se cierra (< 9.5 m) retrocede disparando;
	# de muy cerca cambia a melee porque el arco no sirve.
	if wkind == "bow" and dist > 4.5 and dist <= 46.0:
		b["is_aiming"] = true
		if dist > 30.0:
			_move_bot_towards(b, fpos, 4.0, delta, "run")
		elif dist < 9.5 and to_foe.length_squared() > 0.01:
			_move_bot_towards(b, proxy.global_position - to_foe.normalized() * 5.0, 3.5, delta, "walk")
			b["rot"] = atan2(-to_foe.x, -to_foe.z)
			proxy.rotation.y = float(b["rot"])
		else:
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 1.5:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var sideb := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
			_move_bot_towards(b, proxy.global_position + sideb * float(b["strafe_dir"]) * 3.0, 3.2, delta, "walk")
			b["rot"] = atan2(-to_foe.x, -to_foe.z)
			proxy.rotation.y = float(b["rot"])
		if float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, fpos):
			b["shoot_cooldown"] = 1.55 if weapon == "Arco reforzado" else 1.9
			_bot_fire_bow(b, foe, weapon)
		return
	if wkind == "bow" and dist > 46.0:
		_move_bot_towards(b, fpos, 4.4, delta, "run")
		return

	# Arrojadizas (lanzas, palo afilado, boleadoras): un lanzamiento cada pocos
	# segundos; el proyectil vuela de verdad en el servidor y se ve en clientes.
	if wkind in ["thrown", "bola"] and dist > 4.5 and dist <= 38.0:
		b["is_aiming"] = true
		if dist > 26.0:
			_move_bot_towards(b, fpos, 4.2, delta, "run")
		elif dist < 8.5 and to_foe.length_squared() > 0.01:
			_move_bot_towards(b, proxy.global_position - to_foe.normalized() * 4.5, 3.5, delta, "walk")
			b["rot"] = atan2(-to_foe.x, -to_foe.z)
			proxy.rotation.y = float(b["rot"])
		else:
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 1.6:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var sidet := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
			_move_bot_towards(b, proxy.global_position + sidet * float(b["strafe_dir"]) * 3.0, 3.4, delta, "walk")
		if float(b["shoot_cooldown"]) <= 0.0 and _has_clear_shot(proxy.global_position, fpos):
			b["shoot_cooldown"] = 2.6 if wkind == "bola" else 2.1
			_bot_fire_thrown(b, foe, weapon, wkind == "bola")
		return
	if wkind in ["thrown", "bola"] and dist > 38.0:
		_move_bot_towards(b, fpos, 4.5, delta, "run")
		return

	b["is_aiming"] = false
	var reach := 3.6
	if dist <= reach:
		b["anim"] = "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION
		if float(b["attack_cooldown"]) <= 0.0:
			b["attack_cooldown"] = 0.68
			# A quemarropa usa su mejor arma cuerpo a cuerpo (o los punos)
			var melee_w := _best_melee_weapon(proxy)
			var melee_dmg := _weapon_melee_damage(melee_w) if _bot_item_count(proxy, melee_w) > 0 else 25.0
			_apply_bot_damage_to_target(b, foe, melee_dmg * 0.45, "melee")
			_reduce_bot_item_durability(proxy, melee_w, 1.5)
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
			_bot_credit_kill(b, target)
			_bot_start_gutting(b, target)
	else:
		_apply_bot_damage_to_target(b, target, dmg, "rifle")

# Daño base de cada flecha, igual que en el arco del jugador.
func _bot_arrow_base_damage(arrow_name: String) -> float:
	match arrow_name:
		"Flecha de hueso": return 215.0
		"Flecha de piedra": return 175.0
		"Flecha improvisada": return 60.0
		_: return 125.0 # Flecha de madera y cualquier otra

func _bot_projectile_drag(item_name: String) -> float:
	match item_name:
		"Flecha improvisada": return 0.52
		"Flecha de madera": return 0.34
		"Flecha de piedra": return 0.28
		"Flecha de hueso": return 0.26
		"Lanza", "Lanza de hueso": return 0.20
		"Palo afilado": return 0.26
		"Boleadoras": return 0.40
	return 0.30

# El bot dispara con arco igual que un jugador: consume la mejor flecha,
# gasta durabilidad del arco, lanza el proyectil real en el servidor y
# avisa a los clientes para que vean la flecha volar.
func _bot_fire_bow(b: Dictionary, foe: Node3D, bow_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	var bot_id := int(b["bot_id"])
	var arrow_name := _consume_bot_arrow(proxy)
	if arrow_name.is_empty():
		return
	_reduce_bot_item_durability(proxy, bow_name, 2.0)
	var origin := proxy.global_position + Vector3(0.0, 1.5, 0.0)
	var aim_pos := foe.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (aim_pos - origin).normalized()
	# Pequeña dispersion como en el tiro humano
	dir = (dir + Vector3(randf_range(-0.018, 0.018), randf_range(-0.012, 0.012), randf_range(-0.018, 0.018))).normalized()
	var speed := 95.0 if bow_name == "Arco reforzado" else 75.0
	var dmg := _bot_arrow_base_damage(arrow_name) * (1.18 if bow_name == "Arco reforzado" else 1.0)
	_broadcast_bot_projectile(bot_id, origin, dir, arrow_name, speed)
	# Alerta a la fauna cercana (el RPC devuelve limpio: el proxy no es un jugador)
	if world.has_method("_net_primitive_shot"):
		world._net_primitive_shot(bot_id, origin, dir, arrow_name, speed)
	_bot_launch_projectile(b, origin, dir, arrow_name, speed, 140.0, dmg, false)

# Lanzas, palo afilado y boleadoras: el arma no se consume (solo durabilidad),
# como al recogerla del suelo tras el lanzamiento.
func _bot_fire_thrown(b: Dictionary, foe: Node3D, item_name: String, is_bola: bool) -> void:
	var proxy: Node3D = b["proxy"]
	var bot_id := int(b["bot_id"])
	_reduce_bot_item_durability(proxy, item_name, 3.0)
	var origin := proxy.global_position + Vector3(0.0, 1.4, 0.0)
	var aim_pos := foe.global_position + Vector3(0.0, 0.9, 0.0)
	var dir := (aim_pos - origin).normalized()
	dir = (dir + Vector3(randf_range(-0.015, 0.015), randf_range(-0.01, 0.01), randf_range(-0.015, 0.015))).normalized()
	var speed := 55.0 if is_bola else 60.0
	_broadcast_bot_projectile(bot_id, origin, dir, item_name, speed)
	if world.has_method("_net_primitive_shot"):
		world._net_primitive_shot(bot_id, origin, dir, item_name, speed)
	_bot_launch_projectile(b, origin, dir, item_name, speed, 65.0, 65.0, is_bola)

# Proyectil visual en los clientes: mismo RPC que usan los jugadores.
func _broadcast_bot_projectile(bot_id: int, origin: Vector3, dir: Vector3, item_name: String, speed: float) -> void:
	var world_n = world.get("net") if world != null else null
	if world_n == null or not world_n.is_host or world_n.peer == null:
		return
	for pid in world_n.players.keys():
		if pid != world_n.get_my_id() and not is_bot_peer_id(pid) and not world_n.players[pid].get("offline", false) and world_n.peer_alive(pid):
			world_n.primitive_shot.rpc_id(pid, bot_id, origin, dir, item_name, speed, Vector3.ZERO)

# Proyectil real en el servidor (autoritativo): vuela con fisica y al impactar
# aplica el daño. Los clientes ven la copia visual del RPC anterior.
func _bot_launch_projectile(b: Dictionary, origin: Vector3, dir: Vector3, item_name: String, speed: float, max_dist: float, dmg_base: float, is_bola: bool) -> void:
	if world == null or not (world is Node3D):
		return
	var proxy: Node3D = b["proxy"]
	var projectile: Node3D = preload("res://scripts/RifleProjectile.gd").new()
	projectile.velocity = dir.normalized() * speed
	projectile.max_distance = max_dist
	var excl: Array[RID] = []
	if proxy is CollisionObject3D:
		excl.append(proxy.get_rid())
	projectile.excluded = excl
	projectile.drag_coeff = _bot_projectile_drag(item_name)
	projectile.launch_speed = speed
	projectile.align_flight = item_name.begins_with("Flecha") or item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]
	projectile.spin_speed = 22.0 if is_bola else 0.0
	(world as Node3D).add_child(projectile)
	projectile.global_position = origin
	projectile.look_at(origin + dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.97 else Vector3.FORWARD)
	var bot_ref: Dictionary = b
	projectile.impact.connect(func(collider, hit_pos: Vector3, _dist: float, _normal: Vector3):
		_on_bot_projectile_impact(bot_ref, projectile, collider, hit_pos, dmg_base, is_bola))

func _on_bot_projectile_impact(b: Dictionary, projectile: Node3D, collider, hit_pos: Vector3, dmg_base: float, is_bola: bool) -> void:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	var target: Node = null
	var is_headshot := false
	var node := collider as Node
	if node != null:
		if node.name == "HeadHitbox":
			is_headshot = true
		var walked: Node = node
		while walked != null:
			if walked.is_in_group("wildlife") or walked.is_in_group("ai_survivor_bot") or walked.is_in_group("net_player_proxy") or (walked.has_method("take_damage") and walked.has_method("apply_damage")):
				target = walked
				break
			walked = walked.get_parent()
	if target == null:
		return
	# Energia residual del proyectil: igual que en el impacto del jugador
	var energy := clampf(projectile.velocity.length() / maxf(projectile.launch_speed, 1.0), 0.45, 1.0)
	var dmg := dmg_base * (2.2 if is_headshot else 1.0) * energy
	if is_bola and target is Node3D:
		target.set_meta("bola_slow_until", Time.get_unix_time_from_system() + 6.0)
	if target is WildlifeController or target.is_in_group("wildlife"):
		if target.has_method("take_damage"):
			target.take_damage(dmg, false, proxy)
		if bool(target.get("_is_dead")):
			_bot_credit_kill(b, target)
			_bot_start_gutting(b, target)
	else:
		var wname := "rifle" if dmg_base > 100.0 else ("bola" if is_bola else "melee")
		_apply_bot_damage_to_target(b, target, dmg, wname)

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

	# Aprendizaje conductual por daño real: registrar riesgo en la zona y, si el
	# atacante es un jugador/bot, actualizar relación social (desconfianza/hostilidad/miedo).
	record_zone_hazard(bot_id, proxy.global_position, _poi_kind_near(proxy.global_position), clampf(amount / 45.0, 0.08, 0.65))
	if attacker_id > 0:
		var akey := _actor_persist_key(attacker_id)
		var aname := _actor_display_name(attacker_id)
		record_social_event(bot_id, akey, aname, "attack", clampf(amount / 35.0, 0.10, 0.80), "hit_" + weapon)
	elif weapon in ["wolf_bite", "bear_bite"]:
		_evolve_personality(b, "predator_hit", clampf(amount / 50.0, 0.1, 0.5))

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
	# Reescanear sentidos ya: reaccionar al agresor en el proximo tick, no en 0.2 s
	b["sense_t"] = 0.0

	# Reaccion visual sincronizada: el kind va directo a _net_player_hit_event,
	# que ya distingue rifle (sangre + reaccion de disparo), melee, wolf_bite
	# y bear_bite (sangre + reaccion + sonido de dolor).
	var hit_kind := weapon if weapon in ["rifle", "melee", "wolf_bite", "bear_bite", "bola"] else "melee"
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	b["hide_timer"] = 0.0
	b["flinch_anim"] = "shot" if hit_kind == "rifle" else "hit"
	b["flinch_timer"] = 0.48 if hit_kind == "rifle" else 0.30
	b["anim"] = b["flinch_anim"]
	var net = world.get("net")
	if net != null and net.has_method("_broadcast_player_hit"):
		net._broadcast_player_hit(bot_id, hit_kind, proxy.global_position, true)
	elif world.has_method("_net_player_hit_event"):
		world._net_player_hit_event(bot_id, hit_kind, proxy.global_position)

	if hp <= 0.0:
		_kill_bot(b, "melee" if weapon == "melee" else "")

# Muerte del superviviente por cualquier causa (impacto letal, mordisco,
# inanicion o deshidratacion): marca el proxy, suelta el loot y sincroniza
# la animacion/cuerpo de muerto como con un jugador real.
func _kill_bot(b: Dictionary, death_kind: String) -> void:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	var bot_id := int(b["bot_id"])
	# Aprendizaje persistente: recordar donde y por que murio para que su
	# proxima vida no repita el error (zona peligrosa, necesidades, equipo).
	var mem: Dictionary = _memory.get_or_add(bot_id, {})
	_bot_flush_alive_time(b)
	mem["deaths"] = int(mem.get("deaths", 0)) + 1
	mem["last_death_pos"] = proxy.global_position
	mem["last_death_cause"] = death_kind
	if death_kind == "starved":
		mem["scarcity"] = true
	mem["gear_learned"] = true # morir enseña: la buena equipacion importa
	# Historial de puntos letales: muertes cercanas (<25 m) se agrupan y pesan
	# en la eleccion de exploracion durante las proximas sesiones.
	var spots: Array = mem.get("death_spots", [])
	var dp := proxy.global_position
	var merged := false
	for s in spots:
		if s is Dictionary:
			var dx := dp.x - float(s.get("x", 0.0))
			var dz := dp.z - float(s.get("z", 0.0))
			if dx * dx + dz * dz < 625.0:
				s["count"] = int(s.get("count", 1)) + 1
				s["cause"] = death_kind
				merged = true
				break
	if not merged:
		spots.append({"x": dp.x, "y": dp.y, "z": dp.z, "cause": death_kind, "count": 1})
	while spots.size() > AI_MEMORY_MAX_SPOTS:
		spots.pop_front()
	mem["death_spots"] = spots
	record_zone_hazard(bot_id, dp, _poi_kind_near(dp), 0.75)
	record_bot_event(bot_id, "death", death_kind, _poi_kind_near(dp), dp, "died:" + death_kind)
	_evolve_personality(b, "death", 0.6)
	_ai_save_memory()
	proxy.set_meta("proxy_dead", true)
	proxy.remove_from_group("net_player_proxy")
	proxy.add_to_group("interactable")
	b["anim"] = "dead_melee" if death_kind == "melee" else "dead"
	b["torch_lit"] = false
	b["is_aiming"] = false
	b["crouching"] = false
	b["sitting"] = false
	b["respawn_timer"] = 0.0
	if world.has_method("_release_dead_owner_wolves"):
		world._release_dead_owner_wolves(bot_id, str(b["client_id"]), proxy, false)
	if world.has_method("_drop_player_loot"):
		world._drop_player_loot(bot_id, proxy)
	proxy.set_meta("death_broadcasted", true)
	if world.has_method("_broadcast_player_death"):
		world._broadcast_player_death(bot_id, proxy, death_kind)
	if world.has_method("_net_player_death_broadcast"):
		world._net_player_death_broadcast(bot_id, proxy.global_position, float(b["rot"]), death_kind)
	_publish_bot_to_net_players(b)

func _bot_has_drink(proxy: Node3D) -> bool:
	return _bot_drink_count(proxy) > 0

func _bot_drink_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			if str(it.get("type", "")) == "water" or nm.contains("agua") or nm.contains("Cantimplora"):
				total += int(it.get("quantity", 1))
	return total

# Recipientes para agua (llenos o vacios): un superviviente solo necesita una
# cantimplora/botella como reserva — el rio es la fuente real y alli la rellena.
func _bot_container_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			if str(it.get("type", "")) == "water" or nm.contains("agua") or nm.contains("Cantimplora") or nm == "Botella de plastico":
				total += int(it.get("quantity", 1))
	return total

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
	if node == null or not is_instance_valid(node) or bool(node.get_meta("proxy_dead", false)) or bool(node.get_meta("disconnected", false)) or node.get("is_dead") == true:
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
	var sender_key := _actor_persist_key(sender_id)
	var sender_name := _actor_display_name(sender_id)
	# Si el jugador le entrega un objeto, eso siempre suma confianza (incluso si
	# antes había desconfianza), permitiendo reconciliarse con el bot.
	if mode.begins_with("give:"):
		var gname := mode.substr(5).get_slice("|", 0)
		var gtype := mode.substr(5).get_slice("|", 1) if "|" in mode else "resource"
		if gname.is_empty():
			return ""
		var inv_give: Array = proxy.get_meta("saved_inventory", [])
		_bot_add_inventory_item(inv_give, {"name": gname, "type": gtype, "quantity": 1, "weight": 0.5, "use_value": 0.0})
		proxy.set_meta("saved_inventory", inv_give)
		_auto_equip_best_gear(b)
		var best_w2 := _best_weapon_name(proxy)
		if not best_w2.is_empty() and not bool(b["torch_lit"]):
			b["held_item"] = best_w2
			proxy.set_meta("saved_held_item", best_w2)
		record_social_event(bot_id, sender_key, sender_name, "help", 0.35, "gave_" + gname)
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "Le das %s a %s." % [gname, bname]

	if cur_leader == 0 or cur_leader != sender_id:
		var rel := get_bot_relationship(bot_id, sender_key)
		if float(rel.get("trust", 0.0)) < -0.35 or (float(rel.get("hostility", 0.0)) >= 0.65 and int(rel.get("attacked", 0)) >= 2):
			return "%s desconfía de ti tras tus ataques y rehúsa formar equipo." % bname
		b["team_leader_id"] = sender_id
		b["follow_mode"] = "follow"
		b["sitting"] = false
		b["aggro_target"] = null
		proxy.set_meta("team_leader_id", sender_id)
		proxy.set_meta("bot_follow_mode", "follow")
		record_social_event(bot_id, sender_key, sender_name, "ally", 0.15, "joined_team")
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s se ha unido a tu equipo (te sigue y te cubre)." % bname

	# Ya está en el equipo de este jugador: órdenes directas tipo menú de lobo
	if mode == "follow" or mode == "stay":
		b["follow_mode"] = mode
		if mode == "stay":
			b["stay_pos"] = proxy.global_position
		b["sitting"] = false
		proxy.set_meta("bot_follow_mode", mode)
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "%s: '¡En marcha, te sigo!'" % bname if mode == "follow" else "%s: 'Me quedo vigilando esta posición.'" % bname
	if mode == "eat":
		var inv_eat: Array = proxy.get_meta("saved_inventory", [])
		var has_food := false
		for it in inv_eat:
			if it is Dictionary and str(it.get("type", "")) == "food" and int(it.get("quantity", 1)) > 0:
				has_food = true
				break
		if not has_food:
			return "%s no tiene comida en la mochila." % bname
		b["forced_eat"] = true
		b["eat_cooldown"] = 0.0
		return "%s: 'De acuerdo, como algo.'" % bname
	if mode == "equip":
		b["equip_mission"] = true
		b["sense_t"] = 0.0
		return "%s: 'Voy a recoger el mejor equipo que haya por aquí.'" % bname

	# Ciclar orden (Sígueme -> Quieto -> Libre)
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
			b["sense_t"] = 0.0

func _command_bot_wolf_against(b: Dictionary, target: Node3D) -> void:
	if world == null or world.get_tree() == null or target == null or not is_instance_valid(target):
		return
	var key := str(b["bot_id"])
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if is_instance_valid(w) and not bool(w.get("_is_dead")) and str(w.get("animal_type")) == "wolf" and str(w.get("tamed_to")) == key:
			if w.has_method("notify_threat"):
				w.notify_threat(target, 20.0)

# Lee un nodo cacheado por el sentido escalonado descartando referencias muertas.
func _sensed_node(b: Dictionary, key: String) -> Node3D:
	var n = b.get(key, null)
	if n != null and is_instance_valid(n):
		return n as Node3D
	return null

func _find_nearby_valuable_loot(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("_dropped_items" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var r_sq := radius * radius
	var best := {}
	var best_score := -1.0
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
		# Orden "equip": solo armas, ropa y mochilas — comida y materiales no
		if bool(b.get("equip_mission", false)) and not _is_gear_item(nm, tp):
			continue
		var pos := _loot_entry_pos(entry)
		var d_sq := proxy.global_position.distance_squared_to(pos)
		if d_sq > r_sq:
			continue
		# Un superviviente prioriza: arma/medicina > comida > equipo > materiales
		# > reserva de agua. La distancia solo desempata dentro de cada clase.
		var score := _loot_priority(b, nm, tp) * 1000.0 - sqrt(d_sq)
		if score > best_score:
			best_score = score
			best = entry
	return best

# Peso de saqueo por clase: lo vital para sobrevivir y defenderse primero.
func _loot_priority(b: Dictionary, nm: String, tp: String) -> float:
	if tp == "medical":
		return 6.0
	if tp in ["weapon", "weapon_rifle", "weapon_bow", "weapon_bola", "ammo"]:
		return 6.0
	if tp == "ammo_arrow":
		return 5.5 if not _bot_best_bow(b["proxy"]).is_empty() else 3.0
	if tp == "food":
		return 6.0 if float(b["hunger"]) < 55.0 else 3.5
	if tp in ["tool_axe", "tool_spear"]:
		# Sin arma de verdad, un hacha o lanza es su defensa principal
		var has_ranged := not _best_weapon_name(b["proxy"]).is_empty()
		return 3.5 if has_ranged else 6.0
	if tp in ["tool_torch", "tool_matches"]:
		return 4.5
	if tp == "backpack" or tp == "clothing":
		return 4.0
	if tp == "water" or nm.contains("agua") or nm.contains("Cantimplora"):
		# El rio da de beber gratis: la botella es solo una reserva movil.
		return 4.0 if float(b["thirst"]) < 55.0 else 2.0
	if nm == "Botella de plastico":
		return 2.5
	if nm in ["Hueso", "Tendón", "Pluma", "Trapos", "Tronco"]:
		# Ingredientes de crafteo: solo si una receta util los necesita ahora
		return 3.8
	return 3.0 # materiales de campamento: palos, piedras, cuerda, pieles

# Cualquier filo que sirva de "Cuchillo" en las recetas (misma lista que
# CraftingSystem._is_substitute) permite abrir latas.
func _bot_has_can_opener(proxy: Node3D) -> bool:
	for tool in ["Cuchillo", "Cuchillo de piedra", "Cuchillo de hueso", "Hacha", "Hacha de piedra", "Piedra afilada"]:
		if _bot_item_count(proxy, tool) > 0:
			return true
	return false

# Comida en el suelo: solo si la necesita — con el estomago lleno no se
# llenan los bolsillos de setas que otro puede aprovechar.
func _bot_wants_food(b: Dictionary) -> bool:
	if float(b["hunger"]) < 75.0 or float(b["health"]) < 80.0:
		return true
	# Sin reserva comestible: guardar algo aunque no tenga hambre urgente
	return not _bot_has_edible_food(b["proxy"], float(b["hunger"]) < 28.0)

func _is_loot_desirable(b: Dictionary, nm: String, tp: String) -> bool:
	if tp == "food":
		if not _bot_wants_food(b):
			return false
		# Latas cerradas: sin herramienta de corte son lastre puro; con ella
		# son reserva de emergencia que el sabe abrir y comer.
		if nm.begins_with("Lata de ") and not nm.ends_with(" abierta"):
			return _bot_has_can_opener(b["proxy"]) or float(b["hunger"]) < 30.0
		return true
	if tp in ["weapon", "weapon_rifle", "weapon_bow", "weapon_bola", "tool_axe", "tool_spear", "ammo", "ammo_arrow", "medical", "tool_matches"]:
		return true
	# Bebida: una sola reserva basta — el rio es la fuente real. Si ya lleva un
	# recipiente vacio, solo coge una llena si tiene sed; si no, rellena en el rio.
	if tp == "water" or nm.contains("agua") or nm.contains("Cantimplora"):
		if _bot_drink_count(b["proxy"]) >= 1:
			return false
		return _bot_container_count(b["proxy"]) < 1 or float(b["thirst"]) < 55.0
	# Botella vacia = recipiente para rellenar en el rio; solo si no tiene ninguno
	if nm == "Botella de plastico":
		return _bot_container_count(b["proxy"]) < 1
	# Materiales base de campamento: stock modesto, no acaparar "por si acaso"
	if nm in ["Palo", "Piedra", "Cuerda", "Tela de camuflaje"]:
		var caps := {"Palo": 8, "Piedra": 6, "Cuerda": 4, "Tela de camuflaje": 2}
		return _bot_item_count(b["proxy"], nm) < int(caps.get(nm, 99))
	# Ingredientes de crafteo: solo si una receta util los necesita ahora mismo
	# (p.ej. Trapos solo si busca venda, cuerda, boleadoras o ropa de piel)
	if nm in ["Hueso", "Tendón", "Pluma", "Trapos", "Tronco"]:
		return _bot_wants_craft_input(b, nm)
	# Pieles: para ropa de piel o forro; unas pocas bastan para empezar
	if CraftingSystem._is_pelt_name(nm):
		return _bot_wants_craft_input(b, "ANY_PELT") or _bot_pelt_count(b["proxy"]) < 4
	if tp == "backpack" and nm == "Mochila militar" and str(b["backpack"]) != "Mochila militar":
		return true
	if tp == "clothing":
		# Ropa cortable (militar/camuflaje): interesa si el bot necesita trapos
		if _bot_wants_craft_input(b, nm):
			return true
		if PlayerController.CLOTHING_SLOTS.has(nm):
			var slot := str(PlayerController.CLOTHING_SLOTS[nm])
			var cur := _worn_in_slot(str(b.get("clothing", "")).split(","), slot)
			var pr := int(CLOTHING_PRIORITY.get(nm, 0))
			# Mejora real sobre lo que lleva puesto; y una vez aprendio, cualquier
			# ropa decente (>=4) interesa como repuesto.
			return pr > int(CLOTHING_PRIORITY.get(cur, 0)) or (bool(b.get("_mem", {}).get("gear_learned", false)) and pr >= 4)
	return false

# Equipo vestible/usable: lo que la orden "equip" debe buscar en el suelo.
func _is_gear_item(nm: String, tp: String) -> bool:
	if tp in ["weapon", "weapon_rifle", "tool_axe", "tool_spear", "backpack", "clothing"]:
		return true
	return PlayerController.CLOTHING_SLOTS.has(nm) or nm.begins_with("Mochila")

# Sube o baja una ruta de peldaños (torre militar, pisos): movimiento directo
# entre waypoints, el sondeo de _ground_y lo pega a la rampa/piso real.
func _tick_bot_climb(b: Dictionary, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var route: Array = b["climb_route"]
	var pos := proxy.global_position
	var ci := int(b.get("climb_i", -1))
	var step := 2.2 * delta
	if ci < 0:
		# La ruta ya no tiene destino de exploracion (p.ej. se abandono por
		# atasco): soltar la escalada en vez de insistir para siempre.
		if b.get("explore_target", Vector3.INF) == Vector3.INF:
			b["climb_route"] = []
			return
		# Aproximacion al pie de la escalera: lejos usa la nav normal, ya cerca
		# va directo para que el bloqueador de la torre no lo rechace.
		var foot: Vector3 = route[0]
		var dist := Vector2(foot.x - pos.x, foot.z - pos.z).length()
		if dist > 8.0:
			_move_bot_towards(b, foot, 3.4, delta, "walk")
			return
		if dist > 0.9:
			var dir := Vector3(foot.x - pos.x, 0, foot.z - pos.z) / maxf(dist, 0.001)
			var np0 := pos + dir * minf(3.0 * delta, dist)
			np0.y = _ground_y(np0.x, np0.z, pos.y)
			proxy.global_position = np0
			b["rot"] = lerp_angle(float(b["rot"]), atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
			proxy.rotation.y = float(b["rot"])
			b["anim"] = "walk"
			b["_speed"] = 3.0
			return
		b["climb_i"] = 0
		return
	# En lo alto monta guardia un rato, como haria un vigia, y luego baja
	var dwell := float(b.get("climb_dwell", 0.0))
	if dwell > 0.0:
		b["climb_dwell"] = dwell - delta
		b["anim"] = "idle"
		if float(b["climb_dwell"]) <= 0.0:
			b["climb_down"] = true
		return
	var wp: Vector3 = route[clampi(ci, 0, route.size() - 1)]
	var flat := Vector2(pos.x, pos.z).distance_to(Vector2(wp.x, wp.z))
	var np := pos.move_toward(Vector3(wp.x, pos.y, wp.z), minf(step, flat))
	var gy := _ground_y(np.x, np.z, pos.y)
	# Si el sondeo quedo muy lejos de la cota esperada (salio de la rampa por el
	# hueco), interpolar desde la altura actual hacia la cota del waypoint.
	np.y = move_toward(pos.y, wp.y, step) if absf(gy - wp.y) > 1.5 else gy
	proxy.global_position = np
	proxy.set_meta("saved_pos", np)
	var mv := np - pos
	mv.y = 0.0
	if mv.length() > 0.001:
		b["rot"] = lerp_angle(float(b["rot"]), atan2(-mv.x, -mv.z), minf(1.0, delta * 8.0))
		proxy.rotation.y = float(b["rot"])
	b["anim"] = "walk"
	b["_speed"] = 2.2
	if flat > 0.55 or absf(np.y - wp.y) > 1.2:
		return
	if bool(b.get("climb_down", false)):
		var ni := ci - 1
		if ni < 0:
			b["climb_i"] = -1
			b["climb_down"] = false
			b["climb_route"] = []
			b["explore_target"] = Vector3.INF
			b["explore_dwell"] = randf_range(2.0, 6.0)
		else:
			b["climb_i"] = ni
		return
	var ni2 := ci + 1
	if ni2 >= route.size():
		b["climb_dwell"] = randf_range(30.0, 75.0)
		_mark_poi_visited(b, wp)
	else:
		b["climb_i"] = ni2

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
	# La entrada viene de la cache de sentidos: otro bot pudo recogerla
	# hace 0.2 s. Revalidar que sigue en el mundo antes de duplicar el item.
	var still_there := false
	if "_dropped_items" in world:
		for e2 in world._dropped_items:
			if e2 is Dictionary and str(e2.get("id", "")) == id:
				still_there = true
				break
	if not still_there or ("_depleted_action_ids" in world and world._depleted_action_ids.has(id)):
		b["_s_loot"] = {}
		return
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	# Mochila llena: solo equipo — evita hinchar el inventario hasta la muerte
	# (al morir suelta TODO al mundo y el servidor se llenaria de drops).
	var enm := str(entry.get("name", ""))
	var etp := str(entry.get("type", "resource"))
	if inv.size() >= 60 and not _is_gear_item(enm, etp):
		b["_s_loot"] = {}
		return
	var item_dict := {
		"name": str(entry.get("name", "")),
		"type": str(entry.get("type", "resource")),
		"weight": float(entry.get("weight", 0.2)),
		"quantity": int(entry.get("qty", 1)),
		"use_value": float(entry.get("use", 0.0)),
	}
	_bot_add_inventory_item(inv, item_dict)
	proxy.set_meta("saved_inventory", inv)
	_ai_note_loot(b, enm, etp)
	_auto_equip_best_gear(b)
	var best_w := _best_weapon_name(proxy)
	if not best_w.is_empty() and not bool(b["torch_lit"]):
		b["held_item"] = best_w
		b["has_rifle"] = best_w == "Fusil de asalto" or best_w == "Rifle francotirador"
		proxy.set_meta("saved_held_item", best_w)

	if world.has_method("_net_world_action_completed"):
		world._net_world_action_completed(id, [], "", _loot_entry_pos(entry), 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.world_action_completed.rpc_id(pid, id, [], "", _loot_entry_pos(entry))

func _can_bot_build_shelter(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 4 and _bot_item_count(proxy, "Cuerda") >= 1

func _can_bot_build_campfire(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2

func _bot_build_shelter(b: Dictionary, pos: Vector3) -> void:
	var proxy: Node3D = b["proxy"]
	_consume_bot_item(proxy, "Palo", 4)
	_consume_bot_item(proxy, "Cuerda", 1)
	var has_pelts := _bot_pelt_count(proxy) >= 4
	if has_pelts:
		var used := 0
		for pelt_nm in ["Piel de lobo", "Piel de ciervo", "Piel de oso", "Piel de zorro"]:
			while used < 4 and _bot_item_count(proxy, pelt_nm) > 0:
				_consume_bot_item(proxy, pelt_nm, 1)
				used += 1
	var has_camo := _consume_bot_item(proxy, "Tela de camuflaje", 1)
	var sh_id := "bot_shelter_%d" % int(b["bot_id"])
	var yaw := float(b["rot"])
	b["shelter_id"] = sh_id
	b["shelter_pos"] = pos
	b["no_fire_spot"] = false
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

# Agua vadeable: un humano cruza rios someros (~hasta la cintura); solo el agua
# profunda bloquea el paso.
const WADE_DEPTH := 0.55

func _is_pos_blocked(pos: Vector3, margin: float = 0.45) -> bool:
	if world == null:
		return false
	if world.has_method("get_river_depth_at") and float(world.get_river_depth_at(pos)) > WADE_DEPTH:
		return true
	if world.has_method("is_bot_blocked_at"):
		return world.is_bot_blocked_at(pos, margin)
	if world.has_method("_is_near_wildlife_blocker") and world._is_near_wildlife_blocker(pos, margin):
		return true
	return false

func _is_step_blocked(from_pos: Vector3, to_pos: Vector3) -> bool:
	if _is_pos_blocked(to_pos, 0.42):
		return true
	if world != null and (world is Node3D) and (world as Node3D).get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = (world as Node3D).get_world_3d().direct_space_state
		if space != null:
			var seg := to_pos - from_pos
			seg.y = 0.0
			var seg_len := seg.length()
			if seg_len > 0.01:
				var probe_end := from_pos + (seg / seg_len) * maxf(seg_len + 0.45, 0.85)
				var q := PhysicsRayQueryParameters3D.create(from_pos + Vector3(0.0, 0.9, 0.0), probe_end + Vector3(0.0, 0.9, 0.0), 1)
				var hit: Dictionary = space.intersect_ray(q)
				if not hit.is_empty():
					return true
	return false

func _move_bot_towards(b: Dictionary, goal: Vector3, speed: float, delta: float, anim_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	# Inercia como un jugador: tras una pausa >0.5 s arranca desde parado, sin
	# saltos bruscos de velocidad ni giros instantaneos.
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(b.get("_last_move_t", -99.0)) > 0.5:
		b["_speed"] = 0.0
		b["_mdir"] = Vector3.ZERO
	b["_last_move_t"] = now
	var next_goal := goal
	var nav_guided := false
	b["path_timer"] = float(b["path_timer"]) - delta
	var flat_dist := Vector2(goal.x - cur.x, goal.z - cur.z).length()
	var direct_blocked := _is_step_blocked(cur, cur + (goal - cur).normalized() * minf(flat_dist, 1.5)) if flat_dist > 0.2 else false
	# Usar la malla de navegacion siempre que el objetivo este a >3.5 m o haya
	# un obstaculo directo interpuesto.
	var bot_nav_ref = world.get("bot_nav") if world != null else null
	if bot_nav_ref == null and world != null:
		bot_nav_ref = world.get("wolf_nav")
	if (flat_dist > 3.5 or direct_blocked) and bot_nav_ref != null:
		var path: Array = b["path"]
		if path.is_empty() or float(b["path_timer"]) <= 0.0:
			b["path"] = bot_nav_ref.find_path(cur, goal)
			b["path_idx"] = 0
			b["path_timer"] = 1.8
			path = b["path"]
		var pidx := int(b["path_idx"])
		while pidx < path.size() and Vector2(path[pidx].x - cur.x, path[pidx].z - cur.z).length() < 1.5:
			pidx += 1
		b["path_idx"] = pidx
		if pidx < path.size():
			next_goal = path[pidx]
			nav_guided = true
	# Agua somera: vadeable (mas lento, como un humano). Agua profunda: solo se
	# cruza si hay puente/piso encima; si no, rodear o abandonar el objetivo.
	var depth_cur := 0.0
	var depth_next := 0.0
	var depth_ahead := 0.0
	var ahead_xz := next_goal
	if world != null and world.has_method("get_river_depth_at"):
		depth_cur = float(world.get_river_depth_at(cur))
		depth_next = float(world.get_river_depth_at(next_goal))
		# La meta puede estar en tierra al otro lado del rio: sondear el tramo
		# inmediato para no internarse en agua profunda tras un destino seco.
		var flat_next := Vector3(next_goal.x - cur.x, 0.0, next_goal.z - cur.z)
		var look := minf(flat_next.length(), 1.4)
		if look > 0.05:
			var probe := cur + flat_next.normalized() * look
			depth_ahead = float(world.get_river_depth_at(probe))
			if depth_ahead > depth_next:
				ahead_xz = probe
	# El punto de nav ya viene validado por la malla (vados incluidos): el sondeo
	# por delante solo manda en el tramo final directo, donde una meta seca al
	# otro lado del rio podria internar al bot en agua profunda. Un probe que
	# rozara agua profunda al borde del vado ya no frena el cruce.
	if (depth_next > WADE_DEPTH or (not nav_guided and depth_ahead > WADE_DEPTH)) and depth_cur <= WADE_DEPTH:
		var surf_y := _ground_y(ahead_xz.x, ahead_xz.z, cur.y)
		var ty := 0.375
		if world.has_method("_get_exact_ground_y"):
			ty = world._get_exact_ground_y(ahead_xz.x, ahead_xz.z) - 0.025
		if surf_y - ty < 0.5:
			b["anim"] = "idle"
			b["path"] = []
			b["stuck_count"] = int(b["stuck_count"]) + 1
			if int(b["stuck_count"]) >= 2:
				b["stuck_count"] = 0
				# Rendirse con cualquier objetivo trans-rio, no solo patrullas:
				# sin esto una meta de exploracion/saqueo aparcaba al bot en la orilla.
				b["explore_target"] = Vector3.INF
				b["explore_dwell"] = 0.0
				var pat: Array = b.get("patrol", [])
				if not pat.is_empty():
					b["patrol_idx"] = (int(b["patrol_idx"]) + 1) % pat.size()
			return
	var to_next := Vector3(next_goal.x - cur.x, 0.0, next_goal.z - cur.z)
	var d := to_next.length()
	if d < 0.05:
		b["anim"] = "idle"
		return
	var dir := to_next / d
	# Sumar repulsion suave de bloqueadores cercanos para rodear muros/arboles/
	# rocas con fluidez. El vector se cachea ~0.15 s por bot: recorrer toda la
	# lista de bloqueadores a 60 Hz por bot era coste inutil.
	if world != null and world.has_method("get_wildlife_avoidance_vector_at"):
		b["avoid_t"] = float(b.get("avoid_t", 0.0)) - delta
		if float(b["avoid_t"]) <= 0.0:
			b["avoid_t"] = 0.15
			b["_avoid"] = world.get_wildlife_avoidance_vector_at(cur)
		var av: Vector3 = b.get("_avoid", Vector3.ZERO)
		av.y = 0.0
		if av.length_squared() > 0.001:
			dir = (dir + av.normalized() * 0.55).normalized()
	# Suavizado de rumbo y aceleracion: nada de avances a trompicones; el bot
	# gira y acelera progresivamente como el CharacterBody del jugador.
	var sm: Vector3 = b.get("_mdir", Vector3.ZERO)
	sm = sm + (dir - sm) * minf(1.0, delta * 7.0)
	if sm.length_squared() > 0.001:
		sm = sm.normalized()
	b["_mdir"] = sm
	var spd := move_toward(float(b.get("_speed", 0.0)), speed * (0.45 if depth_cur > 0.12 else 1.0), delta * 6.5)
	b["_speed"] = spd
	var step := minf(spd * delta, d)
	var chosen_dir := sm if sm.length_squared() > 0.001 else dir
	var new_pos := cur + chosen_dir * step
	var front_blocked := _is_step_blocked(cur, new_pos)
	# Una puerta cerrada no es un muro: si el paso choca y hay una puerta
	# cerrada al alcance, el bot la abre como un jugador y repatha ya libre.
	if front_blocked and world != null and world.has_method("bot_try_open_door_at") and (world.bot_try_open_door_at(cur) or world.bot_try_open_door_at(next_goal)):
		b["path"] = []
		b["path_timer"] = 0.0
		b["anim"] = "idle"
		return
	# Si el paso frontal choca contra un obstaculo/agua, tantear angulos libres
	if front_blocked and not _is_pos_blocked(cur, 0.25):
		var sign_pref := float(b.get("avoid_sign", 1.0))
		var steered := false
		for deg in [28.0, -28.0, 56.0, -56.0, 88.0, -88.0, 125.0, -125.0]:
			var ang := deg_to_rad(deg * sign_pref)
			var cand_dir := dir.rotated(Vector3.UP, ang)
			var cand_pos := cur + cand_dir * step
			if not _is_step_blocked(cur, cand_pos):
				chosen_dir = cand_dir
				new_pos = cand_pos
				steered = true
				break
		if not steered:
			# Bloqueado en todas direcciones: invertir sentido de rodeo y recalcular ruta
			b["avoid_sign"] = -sign_pref
			b["path"] = []
			b["path_timer"] = 0.0
	new_pos.y = _ground_y(new_pos.x, new_pos.z, cur.y)
	proxy.global_position = new_pos
	proxy.set_meta("saved_pos", new_pos)
	b["pos"] = new_pos
	b["rot"] = lerp_angle(float(b["rot"]), atan2(-chosen_dir.x, -chosen_dir.z), minf(1.0, delta * 8.0))
	proxy.rotation.y = float(b["rot"])
	b["anim"] = anim_name
	proxy.set_meta("crouching", bool(b.get("crouching", false)))
	proxy.set_meta("prone", bool(b.get("prone", false)))
	proxy.set_meta("sprinting", anim_name == "run")
	proxy.set_meta("moving", anim_name == "walk" or anim_name == "run")
	# Deteccion real de atasco: mide el avance acumulado durante la ventana
	# completa de 2.0 s (no el paso de un unico frame).
	b["stuck_timer"] = float(b["stuck_timer"]) + delta
	if float(b["stuck_timer"]) >= 2.0:
		var last_pos: Vector3 = b.get("last_move_pos", cur)
		var moved := Vector2(new_pos.x - last_pos.x, new_pos.z - last_pos.z).length()
		b["last_move_pos"] = new_pos
		b["stuck_timer"] = 0.0
		if moved < 0.75:
			b["stuck_count"] = int(b["stuck_count"]) + 1
			var level := int(b["stuck_count"])
			if level == 1:
				var side := Vector3(-chosen_dir.z, 0.0, chosen_dir.x) * float(b.get("avoid_sign", 1.0))
				var detour := _sanitize_ground_point(cur + side * 4.5)
				b["path"] = [detour]
				b["path_idx"] = 0
			elif level == 2:
				b["avoid_sign"] = -float(b.get("avoid_sign", 1.0))
				b["path"] = []
				b["path_timer"] = 0.0
			else:
				b["stuck_count"] = 0
				b["path"] = []
				# Rendirse como un humano: si el destino es inalcanzable (casa
				# cerrada, interior bloqueado), abandona el objetivo y sigue.
				if b.get("explore_target", Vector3.INF) != Vector3.INF:
					b["explore_target"] = Vector3.INF
					b["explore_dwell"] = 0.0
				var pat: Array = b.get("patrol", [])
				if not pat.is_empty():
					b["patrol_idx"] = (int(b["patrol_idx"]) + 1) % pat.size()
		else:
			b["stuck_count"] = 0

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
	var order := ["Fusil de asalto", "Rifle francotirador", "Arco reforzado", "Arco de madera",
		"Lanza de hueso", "Lanza", "Hacha de piedra", "Hacha", "Cuchillo de hueso",
		"Cuchillo de piedra", "Cuchillo", "Palo afilado"]
	for w in order:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == w and int(it.get("quantity", 1)) > 0:
				return w
	return "Cuchillo"

# Armas cuerpo a cuerpo por orden de letalidad (incluye las de crafteo).
func _best_melee_weapon(proxy: Node3D) -> String:
	var order := ["Lanza de hueso", "Lanza", "Hacha de piedra", "Hacha",
		"Cuchillo de hueso", "Cuchillo de piedra", "Cuchillo", "Palo afilado",
		"Pico", "Martillo", "Azada", "Pala"]
	for w in order:
		if _bot_item_count(proxy, w) > 0:
			return w
	return "Cuchillo"

func _bot_best_bow(proxy: Node3D) -> String:
	if _bot_item_count(proxy, "Arco reforzado") > 0:
		return "Arco reforzado"
	if _bot_item_count(proxy, "Arco de madera") > 0:
		return "Arco de madera"
	return ""

func _bot_arrow_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and (str(it.get("type", "")) == "ammo_arrow" or str(it.get("name", "")).begins_with("Flecha")):
			total += int(it.get("quantity", 1))
	return total

func _consume_bot_arrow(proxy: Node3D) -> String:
	for pref in ["Flecha de hueso", "Flecha de piedra", "Flecha de madera", "Flecha improvisada"]:
		if _consume_bot_item(proxy, pref, 1):
			return pref
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for i in range(inv.size() - 1, -1, -1):
		var it = inv[i]
		if it is Dictionary and (str(it.get("type", "")) == "ammo_arrow" or str(it.get("name", "")).begins_with("Flecha")) and int(it.get("quantity", 1)) > 0:
			var nm := str(it.get("name", ""))
			it["quantity"] = int(it.get("quantity", 1)) - 1
			if int(it["quantity"]) <= 0:
				inv.remove_at(i)
			proxy.set_meta("saved_inventory", inv)
			return nm
	return ""

func _bot_best_thrown_weapon(proxy: Node3D) -> String:
	for w in ["Lanza de hueso", "Lanza", "Palo afilado"]:
		if _bot_item_count(proxy, w) > 0:
			return w
	return ""

# Elige el arma de combate segun distancia y equipo: fusil > arco (con
# flechas) > arrojadiza > melee. Un humano hace lo mismo.
func _pick_fight_weapon(b: Dictionary, dist: float) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	for w in ["Fusil de asalto", "Rifle francotirador"]:
		if _bot_item_count(proxy, w) > 0:
			return {"kind": "rifle", "name": w}
	if dist > 4.5:
		var bow := _bot_best_bow(proxy)
		if not bow.is_empty() and _bot_arrow_count(proxy) > 0:
			return {"kind": "bow", "name": bow}
		var thrown := _bot_best_thrown_weapon(proxy)
		if not thrown.is_empty():
			return {"kind": "thrown", "name": thrown}
		if _bot_item_count(proxy, "Boleadoras") > 0:
			return {"kind": "bola", "name": "Boleadoras"}
	return {"kind": "melee", "name": _best_melee_weapon(proxy)}

func _reduce_bot_item_durability(proxy: Node3D, item_name: String, amount: float) -> void:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for it in inv:
		if it is Dictionary and str(it.get("name", "")) == item_name:
			it["durability"] = maxf(0.0, float(it.get("durability", 100.0)) - amount)
	proxy.set_meta("saved_inventory", inv)

func _weapon_melee_damage(weapon: String) -> float:
	match weapon:
		"Lanza de hueso": return 85.0
		"Lanza": return 75.0
		"Hacha de piedra": return 70.0
		"Hacha": return 65.0
		"Cuchillo de hueso": return 66.0
		"Cuchillo de piedra": return 62.0
		"Cuchillo": return 60.0
		"Pico": return 55.0
		"Palo afilado": return 50.0
		"Martillo": return 48.0
		"Azada": return 45.0
		"Pala": return 42.0
		_: return 35.0

func _bot_has_item(proxy: Node3D, item_name: String) -> bool:
	return _bot_item_count(proxy, item_name) > 0

func _bot_item_count(proxy: Node3D, item_name: String) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) == item_name:
			# Herramientas/armas rotas ya no cuentan (max_durability distingue
			# la durabilidad de arma de la "carga" de una botella de agua)
			if it.has("max_durability") and float(it.get("durability", 100.0)) <= 0.0:
				continue
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
	if tp in ["food", "resource", "material", "medical", "ammo", "water", "misc"]:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == nm:
				it["quantity"] = int(it.get("quantity", 1)) + qty
				return
	inv.append(item_dict.duplicate(true))

# ================= CRAFTEO =================
# Los bots usan los mismos RECIPES que un jugador (CraftingSystem.RECIPES)
# pero sobre su inventario serializado (saved_inventory: Array[Dictionary]).
# Misma semantica: herramientas no se consumen (-3 durabilidad), ANY_PELT /
# ANY_CLOTHING son comodines y _is_substitute cubre alternativas.

# ¿Le hace falta este insumo al bot ahora? Cierto si existe una receta que lo
# usa como input y cuyo resultado el bot querría fabricar en este momento.
# Asi el bot no recoge ni fabrica "por si acaso": solo lo que necesita.
func _bot_wants_craft_input(b: Dictionary, input_name: String) -> bool:
	# Cache por bot: el escaneo de loot evalua muchos objetos por tick
	var cache: Dictionary = b.get("_want_cache", {})
	var now := Time.get_ticks_msec()
	if int(cache.get("t", -999999)) < now - 1500:
		cache = {"t": now, "set": {}}
		b["_want_cache"] = cache
	var set: Dictionary = cache["set"]
	if set.has(input_name):
		return bool(set[input_name])
	var wanted := false
	for r in CraftingSystem.RECIPES:
		if not (r.get("inputs", {}) as Dictionary).has(input_name):
			continue
		if _bot_recipe_score(b, r) > 3.0:
			wanted = true
			break
	set[input_name] = wanted
	return wanted

func _bot_pelt_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and CraftingSystem._is_pelt_name(str(it.get("name", ""))):
			total += int(it.get("quantity", 1))
	return total

func _bot_matches_input(input_name: String, it: Dictionary) -> bool:
	if input_name == "ANY_CLOTHING":
		return str(it.get("type", "")) == "clothing"
	if input_name == "ANY_PELT":
		return CraftingSystem._is_pelt_name(str(it.get("name", "")))
	if CraftingSystem._is_tool(input_name) and float(it.get("durability", 100.0)) <= 0.0:
		return false
	var nm := str(it.get("name", ""))
	return nm == input_name or CraftingSystem._is_substitute(input_name, nm)

func _bot_count_input(inv: Array, input_name: String) -> int:
	var have := 0
	for it in inv:
		if it is Dictionary and _bot_matches_input(input_name, it):
			have += int(it.get("quantity", 1))
	return have

func _bot_can_craft(recipe: Dictionary, inv: Array) -> bool:
	for input_name in recipe.get("inputs", {}):
		if _bot_count_input(inv, input_name) < int(recipe["inputs"][input_name]):
			return false
	return true

# Aplica la receta sobre saved_inventory: consume insumos (o desgasta
# herramientas), produce la salida con especie de piel dominante y re-equipa.
func _bot_apply_craft(b: Dictionary, recipe: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var consumed_pelts := {}
	for input_name in recipe.get("inputs", {}):
		var needed := int(recipe["inputs"][input_name])
		for it in inv.duplicate():
			if needed <= 0:
				break
			if not (it is Dictionary) or not _bot_matches_input(input_name, it):
				continue
			if CraftingSystem._is_tool(input_name):
				it["durability"] = maxf(0.0, float(it.get("durability", 100.0)) - 3.0)
				needed -= int(it.get("quantity", 1))
			else:
				var take := mini(needed, int(it.get("quantity", 1)))
				it["quantity"] = int(it.get("quantity", 1)) - take
				needed -= take
				if input_name == "ANY_PELT":
					var pnm := str(it.get("name", ""))
					consumed_pelts[pnm] = int(consumed_pelts.get(pnm, 0)) + take
				if int(it.get("quantity", 1)) <= 0:
					inv.erase(it)
	var out: Dictionary = (recipe.get("output", {}) as Dictionary).duplicate()
	var pelt_species := CraftingSystem._dominant_species(consumed_pelts)
	out = CraftingSystem._pelt_output(out, pelt_species)
	var entry := {
		"name": str(out.get("name", "")),
		"type": str(out.get("type", "resource")),
		"weight": float(out.get("weight", 0.5)),
		"quantity": int(out.get("quantity", 1)),
		"use_value": float(out.get("use_value", 0.0)),
	}
	if out.has("durability"):
		entry["durability"] = float(out["durability"])
		entry["max_durability"] = float(out.get("max_durability", out["durability"]))
	if not pelt_species.is_empty():
		entry["pelt_species"] = pelt_species
	_bot_add_inventory_item(inv, entry)
	proxy.set_meta("saved_inventory", inv)
	_auto_equip_best_gear(b)
	_publish_bot_to_net_players(b)

# Prioridad de cada receta para el bot: -1 = no le interesa / no puede usarla.
func _bot_recipe_score(b: Dictionary, recipe: Dictionary) -> float:
	var proxy: Node3D = b["proxy"]
	var out: Dictionary = recipe.get("output", {})
	var oname := str(out.get("name", ""))
	var otype := str(out.get("type", ""))
	# Fogata y refugio tienen su logica propia; la caña de pescar no se usa
	if otype in ["campfire", "shelter"] or otype == "tool_fishing":
		return -1.0
	# Latas: las cerradas no se comen — hay que abrirlas con cuchillo/hacha.
	# Solo cuando tiene hambre real o salud baja, y sin acaparar abiertas.
	if oname.ends_with(" abierta"):
		if _bot_item_count(proxy, oname) > 0:
			return 1.2
		if _bot_item_count(proxy, oname.trim_suffix(" abierta")) < 1:
			return -1.0
		var need_food := float(b.get("hunger", 100.0)) < 72.0 or float(b.get("health", 100.0)) < 82.0
		return 6.2 if need_food else 1.2
	# Equipo de un solo ejemplar que ya posee no se fabrica dos veces
	var gear_types := ["weapon", "weapon_rifle", "weapon_bow", "weapon_bola", "tool_axe", "tool_spear", "backpack"]
	if otype in gear_types and _bot_item_count(proxy, oname) > 0:
		return -1.0
	if otype == "clothing":
		if oname in str(b.get("clothing", "")).split(","):
			return -1.0
		if PlayerController.CLOTHING_SLOTS.has(oname):
			var slot := str(PlayerController.CLOTHING_SLOTS[oname])
			var cur := _worn_in_slot(str(b.get("clothing", "")).split(","), slot)
			if int(CLOTHING_PRIORITY.get(oname, 0)) <= int(CLOTHING_PRIORITY.get(cur, 0)):
				return -1.0
		# Sin pieles suficientes no se ilusiona con ropa de piel que no puede hacer
		if (recipe.get("inputs", {}) as Dictionary).has("ANY_PELT") and _bot_pelt_count(proxy) < 2:
			return 1.5
		return 4.6
	# Flechas: solo si tiene arco — si no son lastre en la mochila
	if otype == "ammo_arrow" or oname.begins_with("Flecha"):
		if _bot_best_bow(proxy).is_empty():
			return -1.0
		match oname:
			"Flecha de hueso": return 6.6
			"Flecha de piedra": return 6.4
			"Flecha de madera": return 6.2
			_: return 6.0
	# Arcos: solo sin fusil (no se complica con dos sistemas a la vez)
	var has_rifle := _bot_item_count(proxy, "Fusil de asalto") + _bot_item_count(proxy, "Rifle francotirador") > 0
	if otype == "weapon_bow":
		if has_rifle:
			return -1.0
		return 5.6 if oname == "Arco reforzado" else 5.0
	if oname == "Boleadoras":
		return 3.0 if has_rifle or not _bot_best_bow(proxy).is_empty() else 5.0
	# Armas y herramienta: solo si mejoran lo que ya tiene en la mano
	if otype in ["weapon", "tool_axe", "tool_spear"]:
		if oname == "Palo afilado":
			return 4.2 # habilita lanzas, espetones y es un arma floja
		var cur := _weapon_melee_damage(_best_melee_weapon(proxy))
		var nw := _weapon_melee_damage(oname)
		var spear_bonus := 1.2 if oname in ["Lanza", "Lanza de hueso"] and _bot_best_thrown_weapon(proxy).is_empty() else 0.0
		if nw <= cur * 1.03 and spear_bonus == 0.0:
			return -1.0
		return clampf(4.5 + (nw - cur) / 40.0 + spear_bonus, 0.0, 7.0)
	if oname == "Cuerda":
		return 6.8 if _bot_item_count(proxy, "Cuerda") < 1 else 2.0
	if oname == "Trapos":
		# Cortar ropa a tiras solo cuando hacen falta: venda, cuerda,
		# boleadoras o ropa de piel — nunca por acumular
		return 5.5 if _bot_wants_craft_input(b, "Trapos") else 1.5
	if oname == "Palo":
		# Tronco -> 2 palos: habilitador cuando escasean las ramas
		return 4.0 if _bot_item_count(proxy, "Palo") < 4 else 1.5
	if oname == "Piedra afilada":
		return 4.3
	if oname == "Antorcha":
		return 5.6 if _is_world_night() and not bool(b.get("torch_lit", false)) else 2.2
	if oname == "Venda":
		return 5.2 if float(b.get("health", 100.0)) < 80.0 else 1.8
	if otype == "food":
		return 3.4
	return 2.0

# Llamado desde _tick_bot cuando el bot esta libre (sin urgencias): revisa
# cada pocos segundos si puede fabricar algo util y "trabaja" un momento.
func _bot_try_craft(b: Dictionary, delta: float) -> bool:
	var st: Dictionary = b.get("_craft_state", {})
	if not st.is_empty():
		st["t"] = float(st.get("t", 0.0)) - delta
		b["anim"] = "idle"
		b["crouching"] = true
		b["sitting"] = false
		if float(st["t"]) <= 0.0:
			b["_craft_state"] = {}
			_bot_apply_craft(b, st.get("recipe", {}))
		return true
	b["_craft_check"] = float(b.get("_craft_check", 0.0)) - delta
	if float(b["_craft_check"]) > 0.0:
		return false
	b["_craft_check"] = 7.0 + fmod(float(int(b["bot_id"])) * 1.7, 4.0)
	var inv: Array = b["proxy"].get_meta("saved_inventory", [])
	var best: Dictionary = {}
	var best_score := 3.0
	for recipe in CraftingSystem.RECIPES:
		if not _bot_can_craft(recipe, inv):
			continue
		var score := _bot_recipe_score(b, recipe)
		if score > best_score:
			best_score = score
			best = recipe
	if best.is_empty():
		return false
	b["_craft_state"] = {"recipe": best, "t": 2.4}
	b["anim"] = "idle"
	b["crouching"] = true
	return true

# ==================== SISTEMA COGNITIVO, PERSONALIDAD Y ASESOR QWEN/GROQ ====================
# Cada bot dispone de:
# - Personalidad independiente (7 rasgos en [0.05..0.98]) que evoluciona por experiencias reales.
# - Memoria persistente aislada por bot (sin omnisciencia): identidad, eventos, ubicaciones
#   observadas o compartidas por aliados cercanos, relaciones sociales, estrategias y objetivos.
# - Cola de prioridades para consultar Groq/Qwen exclusivamente desde el servidor, con deduplicación
#   de situación, manejo de HTTP 429 (backoff exponencial), presupuesto de tokens y fallback local.

func _default_personality_for_bot(bot_id: int, cfg: Dictionary = {}) -> Dictionary:
	var c := cfg
	if c.is_empty():
		for entry in BOT_CONFIGS:
			if int(entry.get("bot_id", 0)) == bot_id:
				c = entry
				break
	var base: Dictionary = (c.get("personality", {}) as Dictionary).duplicate(true)
	var defaults := {
		"bravery": 0.50,
		"aggression": 0.30,
		"curiosity": 0.60,
		"sociability": 0.60,
		"distrust": 0.35,
		"cooperation": 0.65,
		"survival_instinct": 0.75,
	}
	for k in AI_PERSONALITY_TRAITS:
		if not base.has(k):
			base[k] = defaults[k]
		else:
			base[k] = clampf(float(base[k]), 0.05, 0.98)
	return base

func _ensure_bot_memory(bot_id: int, cfg: Dictionary = {}) -> Dictionary:
	if bots.has(bot_id) and bots[bot_id].get("_mem") is Dictionary and _memory.get(bot_id) != bots[bot_id]["_mem"]:
		_memory[bot_id] = bots[bot_id]["_mem"]
	var mem: Dictionary = _memory.get_or_add(bot_id, {})
	if bots.has(bot_id):
		bots[bot_id]["_mem"] = mem
	var bname := str(cfg.get("name", "Bot_%d" % bot_id))
	var bfaction := str(cfg.get("faction", "hostile" if bot_id == 903 else "friendly"))
	if not mem.has("identity") or not (mem["identity"] is Dictionary):
		mem["identity"] = {"bot_id": bot_id, "name": bname, "faction": bfaction}
	if not mem.has("personality") or not (mem["personality"] is Dictionary):
		mem["personality"] = _default_personality_for_bot(bot_id, cfg)
	else:
		var def_p := _default_personality_for_bot(bot_id, cfg)
		var p_dict: Dictionary = mem["personality"]
		for k in AI_PERSONALITY_TRAITS:
			p_dict[k] = clampf(float(p_dict.get(k, def_p[k])), 0.05, 0.98)
	if not mem.has("deaths"):
		mem["deaths"] = 0
	if not mem.has("stats") or not (mem["stats"] is Dictionary):
		mem["stats"] = {"alive_total_sec": 0.0, "kills_prey": 0, "kills_predator": 0, "animals_gutted": 0}
	if not mem.has("last_death_pos"):
		mem["last_death_pos"] = Vector3.INF
	if not mem.has("last_death_cause"):
		mem["last_death_cause"] = ""
	if not mem.has("visited") or not (mem["visited"] is Array):
		mem["visited"] = []
	if not mem.has("gear_learned"):
		mem["gear_learned"] = false
	if not mem.has("scarcity"):
		mem["scarcity"] = false
	if not mem.has("zone_yield") or not (mem["zone_yield"] is Dictionary):
		mem["zone_yield"] = {}
	if not mem.has("death_spots") or not (mem["death_spots"] is Array):
		mem["death_spots"] = []
	if not mem.has("events") or not (mem["events"] is Array):
		mem["events"] = []
	if not mem.has("events_summary") or not (mem["events_summary"] is Dictionary):
		mem["events_summary"] = {}
	if not mem.has("known_locations") or not (mem["known_locations"] is Dictionary):
		mem["known_locations"] = {}
	if not mem.has("relationships") or not (mem["relationships"] is Dictionary):
		mem["relationships"] = {}
	if not mem.has("strategies") or not (mem["strategies"] is Dictionary):
		mem["strategies"] = {}
	if not mem.has("pending_goals") or not (mem["pending_goals"] is Array):
		mem["pending_goals"] = []
	if not mem.has("sessions"):
		mem["sessions"] = 1
	return mem

func _get_bot_personality(b: Dictionary) -> Dictionary:
	var mem: Dictionary = b.get("_mem", {})
	if mem.has("personality") and mem["personality"] is Dictionary:
		return mem["personality"]
	var bid := int(b.get("bot_id", 901))
	var p := _default_personality_for_bot(bid, b.get("cfg", {}))
	mem["personality"] = p
	b["personality"] = p
	return p

func _adjust_trait(p: Dictionary, trait_name: String, delta_v: float) -> void:
	if not AI_PERSONALITY_TRAITS.has(trait_name):
		return
	p[trait_name] = snappedf(clampf(float(p.get(trait_name, 0.5)) + delta_v, 0.05, 0.98), 0.001)

# Evolución gradual de la personalidad según experiencias verificadas.
func _evolve_personality(b: Dictionary, event_kind: String, intensity: float = 0.25) -> void:
	var p := _get_bot_personality(b)
	var step := clampf(intensity, 0.05, 1.0) * 0.08
	match event_kind:
		"death":
			_adjust_trait(p, "survival_instinct", step * 1.1)
			_adjust_trait(p, "bravery", -step * 0.8)
			_adjust_trait(p, "distrust", step * 0.6)
		"predator_hit", "zone_hazard":
			_adjust_trait(p, "survival_instinct", step * 0.7)
			_adjust_trait(p, "bravery", -step * 0.45)
		"player_attacked":
			_adjust_trait(p, "distrust", step * 1.2)
			_adjust_trait(p, "aggression", step * 0.65)
			_adjust_trait(p, "sociability", -step * 0.75)
			_adjust_trait(p, "cooperation", -step * 0.75)
		"player_helped":
			_adjust_trait(p, "sociability", step * 0.95)
			_adjust_trait(p, "cooperation", step * 1.1)
			_adjust_trait(p, "distrust", -step * 0.95)
			_adjust_trait(p, "aggression", -step * 0.4)
		"hunt_success", "kill_threat":
			_adjust_trait(p, "bravery", step * 0.7)
			_adjust_trait(p, "aggression", step * 0.35)
		"good_loot", "poi_discovered":
			_adjust_trait(p, "curiosity", step * 0.65)
		"starving":
			_adjust_trait(p, "survival_instinct", step * 0.85)
	b["personality"] = p

# Observación local: cada bot solo conoce las ubicaciones que ha visto dentro de
# su radio de percepción o que otro bot aliado le ha comunicado en persona.
func _observe_nearby_world(b: Dictionary) -> void:
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	var bid := int(b.get("bot_id", 0))
	var pos: Vector3 = (proxy as Node3D).global_position
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		if Vector2(pos.x - pp.x, pos.z - pp.z).length() <= AI_OBSERVE_RADIUS:
			observe_location(bid, _poi_id(p), str(p.get("kind", "wild")), pp, "observed")

func observe_location(bot_id: int, loc_id: String, kind: String, pos: Vector3, source: String = "observed", mark_visit: bool = false) -> void:
	if loc_id.is_empty():
		return
	var mem := _ensure_bot_memory(bot_id)
	var known: Dictionary = mem["known_locations"]
	var is_new := not known.has(loc_id)
	var entry: Dictionary = known.get(loc_id, {
		"id": loc_id,
		"kind": kind,
		"pos": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)],
		"visits": 0,
		"risk": 0.0,
		"loot_score": 0.0,
		"source": source,
	})
	if mark_visit:
		entry["visits"] = int(entry.get("visits", 0)) + 1
		entry["source"] = "observed"
	known[loc_id] = entry
	mem["known_locations"] = known
	if is_new and bots.has(bot_id):
		_evolve_personality(bots[bot_id], "poi_discovered", 0.18)

func bot_knows_location(bot_id_or_dict, target: String) -> bool:
	var t := target.strip_edges()
	if t.is_empty():
		return false
	var mem: Dictionary = {}
	if bot_id_or_dict is Dictionary:
		mem = (bot_id_or_dict as Dictionary).get("_mem", {})
	else:
		mem = _memory.get(int(bot_id_or_dict), {})
	var known: Dictionary = mem.get("known_locations", {})
	if known.has(t):
		return true
	var tl := t.to_lower()
	for k in known.keys():
		if str(k).to_lower() == tl:
			return true
	return false

func record_bot_event(bot_id: int, ev_type: String, actor: String, zone: String, pos: Vector3, detail: String = "") -> void:
	var mem := _ensure_bot_memory(bot_id)
	var events: Array = mem["events"]
	events.append({
		"t": int(Time.get_unix_time_from_system()),
		"type": ev_type,
		"actor": actor,
		"zone": zone,
		"pos": [int(pos.x), int(pos.y), int(pos.z)],
		"detail": detail.substr(0, 64),
	})
	_ai_prune_and_summarize_memories(mem)

func bot_knows_event(bot_id: int, ev_type: String, actor_or_zone: String = "") -> bool:
	var mem: Dictionary = _memory.get(bot_id, {})
	for ev in mem.get("events", []):
		if not (ev is Dictionary):
			continue
		if str(ev.get("type", "")) != ev_type:
			continue
		if actor_or_zone.is_empty() or str(ev.get("actor", "")) == actor_or_zone or str(ev.get("zone", "")) == actor_or_zone or str(ev.get("detail", "")).contains(actor_or_zone):
			return true
	return false

# Limita y resume recuerdos antiguos para acotar el contexto enviado a Qwen.
func _ai_prune_and_summarize_memories(mem: Dictionary) -> void:
	var events: Array = mem.get("events", [])
	var summary: Dictionary = mem.get("events_summary", {})
	while events.size() > AI_MEMORY_MAX_EVENTS:
		var old_ev = events.pop_front()
		if old_ev is Dictionary:
			var k := "%s:%s" % [str(old_ev.get("type", "event")), str(old_ev.get("zone", "any"))]
			summary[k] = int(summary.get(k, 0)) + 1
	mem["events"] = events
	mem["events_summary"] = summary

# Comunicación entre bots aliados cercanos (<=14 m): comparten ubicaciones
# conocidas y avisos de peligro. Un bot hostil o lejano jamás recibe estos datos.
func _try_share_allied_knowledge(b: Dictionary) -> void:
	if str(b.get("faction", "")) != "friendly":
		return
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	var bid := int(b["bot_id"])
	var pos: Vector3 = (proxy as Node3D).global_position
	for other_id in bots.keys():
		var oid := int(other_id)
		if oid == bid:
			continue
		var ob: Dictionary = bots[oid]
		if str(ob.get("faction", "")) != "friendly":
			continue
		var op = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		if pos.distance_to((op as Node3D).global_position) <= AI_SHARE_RADIUS:
			share_bot_knowledge(bid, oid)

func share_bot_knowledge(bot_id_a: int, bot_id_b: int) -> int:
	if bot_id_a == bot_id_b:
		return 0
	var mem_a := _ensure_bot_memory(bot_id_a)
	var mem_b := _ensure_bot_memory(bot_id_b)
	if str(mem_a.get("identity", {}).get("faction", "")) != "friendly" or str(mem_b.get("identity", {}).get("faction", "")) != "friendly":
		return 0
	var shared_count := 0
	var ka: Dictionary = mem_a.get("known_locations", {})
	var kb: Dictionary = mem_b.get("known_locations", {})
	for loc_id in ka.keys():
		var entry: Dictionary = ka[loc_id]
		if not kb.has(loc_id):
			var copy := entry.duplicate(true)
			copy["source"] = "shared"
			kb[loc_id] = copy
			shared_count += 1
		else:
			kb[loc_id]["risk"] = maxf(float(kb[loc_id].get("risk", 0.0)), float(entry.get("risk", 0.0)))
	for loc_id2 in kb.keys():
		var entry2: Dictionary = kb[loc_id2]
		if not ka.has(loc_id2):
			var copy2 := entry2.duplicate(true)
			copy2["source"] = "shared"
			ka[loc_id2] = copy2
			shared_count += 1
		else:
			ka[loc_id2]["risk"] = maxf(float(ka[loc_id2].get("risk", 0.0)), float(entry2.get("risk", 0.0)))
	mem_a["known_locations"] = ka
	mem_b["known_locations"] = kb
	return shared_count

func _actor_persist_key(peer_id: int) -> String:
	if peer_id <= 0:
		return "world"
	if is_bot_peer_id(peer_id):
		return "bot_%d" % peer_id
	var node := _find_actor_by_peer_id(peer_id)
	if node != null and is_instance_valid(node):
		var cid := str(node.get_meta("client_id", "")).strip_edges()
		if not cid.is_empty():
			return cid
	if world != null and world.get("net") != null and world.net.players.has(peer_id):
		var pinfo: Dictionary = world.net.players[peer_id]
		var nc := str(pinfo.get("client_id", pinfo.get("char_name", ""))).strip_edges()
		if not nc.is_empty():
			return nc
	return "player_%d" % peer_id

func _actor_display_name(peer_id: int) -> String:
	if is_bot_peer_id(peer_id) and bots.has(peer_id):
		return str(bots[peer_id].get("name", "Bot_%d" % peer_id))
	var node := _find_actor_by_peer_id(peer_id)
	if node != null and is_instance_valid(node):
		var bn := str(node.get_meta("bot_name", node.get_meta("char_name", ""))).strip_edges()
		if not bn.is_empty():
			return bn
	if world != null and world.get("net") != null and world.net.players.has(peer_id):
		var cn := str(world.net.players[peer_id].get("char_name", world.net.players[peer_id].get("name", ""))).strip_edges()
		if not cn.is_empty():
			return cn
	return "Player_%d" % peer_id

func get_bot_relationship(bot_id: int, actor_key: String) -> Dictionary:
	var mem := _ensure_bot_memory(bot_id)
	var rels: Dictionary = mem.get("relationships", {})
	if rels.has(actor_key) and rels[actor_key] is Dictionary:
		return rels[actor_key]
	return {"id": actor_key, "name": actor_key, "trust": 0.0, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0}

# Registra interacciones sociales reales (ayuda o ataque) con jugadores u otros bots.
func record_social_event(bot_id: int, actor_key: String, actor_name: String, kind: String, intensity: float = 0.25, detail: String = "") -> void:
	if actor_key.is_empty() or actor_key == "world":
		return
	var mem := _ensure_bot_memory(bot_id)
	var b: Dictionary = bots.get(bot_id, {})
	var pers: Dictionary = mem.get("personality", _default_personality_for_bot(bot_id))
	var rels: Dictionary = mem["relationships"]
	var base_trust := clampf((float(pers.get("sociability", 0.5)) - float(pers.get("distrust", 0.35))) * 0.25, -0.35, 0.35)
	var rel: Dictionary = rels.get(actor_key, {
		"id": actor_key,
		"name": actor_name if not actor_name.is_empty() else actor_key,
		"trust": base_trust,
		"hostility": 0.65 if str(mem.get("identity", {}).get("faction", "")) == "hostile" else 0.0,
		"fear": 0.0,
		"helped": 0,
		"attacked": 0,
	})
	if not actor_name.is_empty():
		rel["name"] = actor_name
	var step := clampf(intensity, 0.05, 1.0)
	match kind:
		"help", "ally":
			rel["helped"] = int(rel.get("helped", 0)) + 1
			var coop_mul := 0.75 + float(pers.get("cooperation", 0.6)) * 0.6
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + step * 0.75 * coop_mul, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) - step * 0.55, 0.0, 1.0), 0.001)
			rel["fear"] = snappedf(clampf(float(rel.get("fear", 0.0)) - step * 0.45, 0.0, 1.0), 0.001)
			if not b.is_empty():
				_evolve_personality(b, "player_helped", step)
		"attack":
			rel["attacked"] = int(rel.get("attacked", 0)) + 1
			var dist_mul := 0.8 + float(pers.get("distrust", 0.4)) * 0.6
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) - step * 0.65 * dist_mul, -1.0, 1.0), 0.001)
			var agg := float(pers.get("aggression", 0.35))
			var surv := float(pers.get("survival_instinct", 0.7))
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) + step * (0.45 + agg * 0.55), 0.0, 1.0), 0.001)
			rel["fear"] = snappedf(clampf(float(rel.get("fear", 0.0)) + step * (0.35 + surv * 0.50), 0.0, 1.0), 0.001)
			if not b.is_empty():
				_evolve_personality(b, "player_attacked", step)
				if Time.get_ticks_msec() - int(_ai_last_call_msec.get(bot_id, -999999)) > 120000:
					_ai_enqueue_request(bot_id, 5, "attacked_by_" + actor_key)
	var pos := Vector3.ZERO
	if not b.is_empty() and b.get("proxy") != null and is_instance_valid(b["proxy"]):
		pos = (b["proxy"] as Node3D).global_position
	rel["last_seen"] = [int(pos.x), int(pos.y), int(pos.z)]
	rels[actor_key] = rel
	mem["relationships"] = rels
	record_bot_event(bot_id, "social_" + kind, actor_key, _poi_kind_near(pos), pos, detail if not detail.is_empty() else kind)

func on_bot_helped_by_player(bot_id: int, giver_peer_id: int, detail: String = "helped", intensity: float = 0.35) -> void:
	var akey := _actor_persist_key(giver_peer_id)
	var aname := _actor_display_name(giver_peer_id)
	record_social_event(bot_id, akey, aname, "help", intensity, detail)

# Aprendizaje de riesgo por zona: aumenta el peligro percibido de la ubicación
# conocida más cercana y registra la experiencia.
func record_zone_hazard(bot_id: int, pos: Vector3, kind: String, severity: float = 0.3) -> void:
	var mem := _ensure_bot_memory(bot_id)
	var known: Dictionary = mem["known_locations"]
	var best_id := ""
	var best_d := 65.0
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		if d < best_d:
			best_d = d
			best_id = _poi_id(p)
			kind = str(p.get("kind", kind))
	if best_id.is_empty():
		best_id = "%s:%d:%d" % [kind if not kind.is_empty() else "wild", int(pos.x), int(pos.z)]
	observe_location(bot_id, best_id, kind if not kind.is_empty() else "wild", pos, "observed")
	var loc: Dictionary = known.get(best_id, {})
	loc["risk"] = snappedf(clampf(float(loc.get("risk", 0.0)) + clampf(severity, 0.05, 1.0), 0.0, 3.0), 0.01)
	known[best_id] = loc
	mem["known_locations"] = known
	record_strategy_outcome(bot_id, "explore_" + kind, false, severity * 0.4)
	if bots.has(bot_id):
		_evolve_personality(bots[bot_id], "zone_hazard", severity)

# Aprendizaje de estrategias exitosas y fallidas: ajusta preferencia en [0.15..2.0].
func record_strategy_outcome(bot_id: int, strategy: String, success: bool, weight_delta: float = 0.12) -> void:
	if strategy.is_empty():
		return
	var mem := _ensure_bot_memory(bot_id)
	var strats: Dictionary = mem["strategies"]
	var st: Dictionary = strats.get(strategy, {"success": 0, "fail": 0, "preference": 1.0})
	var step := clampf(weight_delta, 0.03, 0.5)
	if success:
		st["success"] = int(st.get("success", 0)) + 1
		st["preference"] = snappedf(clampf(float(st.get("preference", 1.0)) + step, 0.15, 2.0), 0.01)
	else:
		st["fail"] = int(st.get("fail", 0)) + 1
		st["preference"] = snappedf(clampf(float(st.get("preference", 1.0)) - step * 1.25, 0.15, 2.0), 0.01)
	strats[strategy] = st
	mem["strategies"] = strats

# Motor conductual local diferenciado por personalidad, memoria y relaciones:
# ante una situación idéntica, Elena (supervivencia/curiosidad), Carlos
# (valentía/cooperación/fortificación) y Kael (agresividad/desconfianza/saqueo)
# producen decisiones distintas y sirven también como fallback cuando Groq no está.
func decide_situational_action(b: Dictionary, situation: Dictionary = {}) -> Dictionary:
	var pers := _get_bot_personality(b)
	var mem: Dictionary = b.get("_mem", {})
	var strats: Dictionary = mem.get("strategies", {})
	var hp := float(situation.get("hp", b.get("health", 100.0)))
	var hunger := float(situation.get("hunger", b.get("hunger", 90.0)))
	var thirst := float(situation.get("thirst", b.get("thirst", 90.0)))
	var has_shelter := bool(situation.get("has_shelter", b.get("shelter_pos", Vector3.INF) != Vector3.INF or not str(b.get("shelter_id", "")).is_empty()))
	var threat_present := bool(situation.get("threat", _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null))
	var risky_zone := str(situation.get("risky_zone", ""))

	var bravery := float(pers.get("bravery", 0.5))
	var aggression := float(pers.get("aggression", 0.3))
	var curiosity := float(pers.get("curiosity", 0.6))
	var sociability := float(pers.get("sociability", 0.6))
	var distrust := float(pers.get("distrust", 0.35))
	var cooperation := float(pers.get("cooperation", 0.65))
	var survival := float(pers.get("survival_instinct", 0.75))

	var need_food := clampf((75.0 - hunger) / 55.0, 0.0, 1.4)
	var need_heal := clampf((80.0 - hp) / 60.0, 0.0, 1.4)
	var need_water := clampf((65.0 - thirst) / 50.0, 0.0, 1.4)

	var scores := {
		"forage": (need_food * 1.35 + need_water * 0.4 + survival * 1.15 + curiosity * 0.55 - bravery * 0.25 - aggression * 0.35) * float((strats.get("forage", {}) as Dictionary).get("preference", 1.0)),
		"hunt": (need_food * 1.25 + bravery * 0.55 + aggression * 0.45 - distrust * 0.25) * float((strats.get("hunt", {}) as Dictionary).get("preference", 1.0)),
		"fortify_camp": ((0.45 if not has_shelter else 0.15) + bravery * 1.05 + cooperation * 0.85 - curiosity * 0.55 - aggression * 0.35) * float((strats.get("fortify_camp", {}) as Dictionary).get("preference", 1.0)),
		"scavenge": (aggression * 1.25 + distrust * 1.05 + bravery * 0.40 - cooperation * 0.55) * float((strats.get("scavenge", {}) as Dictionary).get("preference", 1.0)),
		"explore": (curiosity * 1.10 + sociability * 0.35 - need_heal * 0.6 - distrust * 0.25) * float((strats.get("explore", {}) as Dictionary).get("preference", 1.0)),
		"rest": (need_heal * 1.55 + survival * 0.70 - bravery * 0.35) * float((strats.get("rest", {}) as Dictionary).get("preference", 1.0)),
		"seek_ally": (sociability * 0.95 + cooperation * 0.95 - distrust * 0.85 - aggression * 0.50) * (1.15 if threat_present else 0.75),
	}
	if threat_present and hp < 55.0 and survival > bravery:
		scores["rest"] = float(scores["rest"]) + 0.9
	if not risky_zone.is_empty():
		scores["avoid_zone"] = survival * 1.1 + distrust * 0.5 + need_heal * 0.6

	var best_act := "explore"
	var best_sc := -999.0
	for act in scores.keys():
		var sc := float(scores[act])
		if sc > best_sc:
			best_sc = sc
			best_act = str(act)

	var target := "wild"
	var goal := "adapt_and_survive"
	var prio := clampi(int(round(best_sc * 2.0)), 1, 5)
	match best_act:
		"forage":
			target = "wild"
			goal = "secure_food_safely"
		"hunt":
			target = "wild"
			goal = "hunt_prey_for_meat_and_pelts"
		"fortify_camp":
			target = "camp"
			goal = "build_and_defend_camp"
		"scavenge":
			target = "military" if aggression >= 0.6 else "house"
			goal = "dominate_high_tier_loot"
		"rest":
			target = "camp"
			goal = "recover_health_in_refuge"
		"seek_ally":
			target = "ally"
			goal = "regroup_with_trusted_ally"
		"avoid_zone":
			target = risky_zone if AI_POI_KINDS.has(risky_zone) else "city"
			goal = "evade_known_danger_zone"
		_:
			target = "house" if survival >= bravery else "city"
			goal = "explore_new_locations"

	return {
		"goal": goal,
		"action": best_act,
		"target": target,
		"poi_kind": target if AI_POI_KINDS.has(target) else "",
		"priority": prio,
		"reason": "personality:%s(%.2f)" % [best_act, best_sc],
	}

# Autoridad exclusiva del servidor: un cliente conectado jamás consulta Groq.
func _ai_can_query_remote() -> bool:
	if world == null:
		return true
	var net = world.get("net")
	if net != null and net.is_connected and not net.is_host:
		return false
	return true

func _ai_enqueue_request(bot_id: int, priority: int = 3, reason: String = "periodic") -> void:
	var p := clampi(priority, 1, 5)
	for item in _ai_queue:
		if int((item as Dictionary).get("bot_id", 0)) == bot_id:
			if p > int((item as Dictionary).get("priority", 1)):
				item["priority"] = p
				item["reason"] = reason
			return
	_ai_queue.append({"bot_id": bot_id, "priority": p, "reason": reason, "t": Time.get_ticks_msec()})
	_ai_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 1)) != int(b.get("priority", 1)):
			return int(a.get("priority", 1)) > int(b.get("priority", 1))
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)

func _ai_pop_next_request() -> Dictionary:
	while not _ai_queue.is_empty():
		var item: Dictionary = _ai_queue.pop_front()
		var bid := int(item.get("bot_id", 0))
		if bots.has(bid) and _ai_bot_eligible(bots[bid]):
			return item
	return {}

# Firma discreta de situación para evitar consultas duplicadas a Groq cuando
# el estado del bot no ha cambiado sustancialmente.
func _ai_situation_signature(b: Dictionary) -> String:
	var proxy = b.get("proxy")
	var pos := (proxy as Node3D).global_position if proxy != null and is_instance_valid(proxy) else Vector3.ZERO
	var hp_band := int(float(b.get("health", 100.0)) / 25.0)
	var h_band := int(float(b.get("hunger", 100.0)) / 25.0)
	var t_band := int(float(b.get("thirst", 100.0)) / 25.0)
	var threat := 1 if (_sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null) else 0
	var zone := _poi_kind_near(pos)
	return "%d|%d|%d|%d|%d|%s|%s" % [hp_band, h_band, t_band, threat, 1 if _is_world_night() else 0, str(b.get("held_item", "")), zone]

func _ai_ensure_http() -> void:
	if _ai_http != null and is_instance_valid(_ai_http):
		return
	_ai_http = HTTPRequest.new()
	_ai_http.timeout = 12.0
	_ai_http.request_completed.connect(_ai_on_response)
	add_child(_ai_http)

func _ai_tick(_delta: float) -> void:
	if bots.is_empty() or not _ai_can_query_remote():
		return
	var now := Time.get_ticks_msec()
	var key := OS.get_environment("GROQ_API_KEY").strip_edges()
	if key.is_empty():
		_ai_conn_status = "no_api_key (local_brain)"
		# Sin clave de Groq, los bots actualizan periódicamente su directiva con su cerebro local
		for bid in bots.keys():
			var b_loc: Dictionary = bots[bid]
			if _ai_bot_eligible(b_loc) and _ai_active_directive(b_loc).is_empty():
				_ai_apply_local_fallback_decision(int(bid), "no_api_key")
		return
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	if day != _ai_day_key:
		_ai_day_key = day
		_ai_calls_day = 0
		_ai_tokens_day = 0
	if now < _ai_backoff_until_msec:
		return
	if _ai_calls_day >= ai_max_calls_per_day or _ai_tokens_day >= ai_max_tokens_per_day:
		_ai_conn_status = "quota_reached (local_brain)"
		return
	if _ai_pending_bot != 0:
		return
	_ai_ensure_http()
	var ids: Array = bots.keys()
	ids.sort()
	for i in range(ids.size()):
		_ai_rr = (_ai_rr + 1) % ids.size()
		var bot_id: int = ids[_ai_rr]
		var b: Dictionary = bots[bot_id]
		if not _ai_bot_eligible(b):
			continue
		var next_at := int(_ai_next_at.get(bot_id, 0))
		if next_at == 0:
			_ai_next_at[bot_id] = now + (90 + _ai_rr * 150 + randi() % 120) * 1000
			continue
		if now >= next_at:
			var urgency := 4 if (float(b["hunger"]) < 45.0 or float(b["health"]) < 60.0) else 2
			_ai_enqueue_request(bot_id, urgency, "scheduled")
	var req := _ai_pop_next_request()
	if req.is_empty():
		return
	var target_bot := int(req["bot_id"])
	var tb: Dictionary = bots[target_bot]
	var sig := _ai_situation_signature(tb)
	if _ai_last_sig.get(target_bot, "") == sig and not _ai_active_directive(tb).is_empty():
		_ai_cache_hits += 1
		_ai_next_at[target_bot] = now + int(AI_DECISION_MIN_SEC * 1000.0)
		return
	_ai_last_sig[target_bot] = sig
	_ai_request_decision(key, target_bot, tb)

func _ai_bot_eligible(b: Dictionary) -> bool:
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return false
	if proxy.get_meta("proxy_dead", false):
		return false
	if int(b.get("team_leader_id", 0)) != 0:
		return false # bajo ordenes del jugador: el asesor no interfiere
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		return false
	var craft = b.get("_craft_state", {})
	if craft is Dictionary and not (craft as Dictionary).is_empty():
		return false
	return true

func _ai_request_decision(key: String, bot_id: int, b: Dictionary) -> void:
	_ai_pending_bot = bot_id
	_ai_calls_day += 1
	_ai_calls_total += 1
	_ai_last_call_msec[bot_id] = Time.get_ticks_msec()
	_ai_conn_status = "requesting"
	_ai_next_at[bot_id] = Time.get_ticks_msec() + int(AI_DECISION_MIN_SEC * 1000.0) + randi() % int(AI_DECISION_SPREAD_SEC * 1000.0)
	var payload := {
		"model": AI_ADVISOR_MODEL,
		"temperature": 0.4,
		"max_tokens": 160,
		"response_format": {"type": "json_object"},
		"messages": [
			{"role": "system", "content": AI_SYSTEM_PROMPT},
			{"role": "user", "content": _ai_build_prompt(b)},
		],
	}
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key])
	if _ai_http.request(AI_ADVISOR_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		_ai_pending_bot = 0
		_ai_conn_status = "request_error (local_fallback)"
		_ai_apply_local_fallback_decision(bot_id, "http_send_error")
		print("[AI-ADV] peticion fallida para bot %d" % bot_id)

func _ai_build_prompt(b: Dictionary) -> String:
	var proxy: Node3D = b["proxy"]
	var pos := proxy.global_position
	var mem: Dictionary = _ensure_bot_memory(int(b["bot_id"]), b.get("cfg", {}))
	var visited: Array = mem.get("visited", [])
	var cur := {}
	var d = b.get("ai_directive", {})
	if d is Dictionary and not (d as Dictionary).is_empty():
		cur = {"goal": str(d.get("goal", "")), "action": str(d.get("action", d.get("mode", ""))), "target": str(d.get("target", "")), "reason": str(d.get("reason", ""))}
	var known_list: Array = []
	var known_dict: Dictionary = mem.get("known_locations", {})
	for lid in known_dict.keys():
		if known_list.size() >= 8:
			break
		var le: Dictionary = known_dict[lid]
		known_list.append({"id": str(lid), "kind": str(le.get("kind", "")), "risk": float(le.get("risk", 0.0))})
	var rel_list: Array = []
	var rel_dict: Dictionary = mem.get("relationships", {})
	for rid in rel_dict.keys():
		if rel_list.size() >= 5:
			break
		var re: Dictionary = rel_dict[rid]
		rel_list.append({"id": str(rid), "trust": float(re.get("trust", 0.0)), "hostility": float(re.get("hostility", 0.0)), "fear": float(re.get("fear", 0.0))})
	var recent_events: Array = []
	var evs: Array = mem.get("events", [])
	for idx in range(maxi(0, evs.size() - 5), evs.size()):
		recent_events.append(evs[idx])
	var state := {
		"name": str(b["name"]),
		"faction": str(b["faction"]),
		"personality": _get_bot_personality(b),
		"hp": int(float(b["health"])),
		"hunger": int(float(b["hunger"])),
		"thirst": int(float(b["thirst"])),
		"weapon": str(b.get("held_item", "")),
		"night": _is_world_night(),
		"threat": _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null,
		"pos": [int(pos.x), int(pos.z)],
		"visited_pois": visited.size(),
		"deaths": int(mem.get("deaths", 0)),
		"items": (proxy.get_meta("saved_inventory", []) as Array).size(),
		"has_shelter": b.get("shelter_pos", Vector3.INF) != Vector3.INF,
		"known_locations": known_list,
		"relationships": rel_list,
		"recent_events": recent_events,
		"allowed_actions": AI_ALLOWED_ACTIONS,
		"last_plan": cur,
		"memory": _ai_memory_summary(mem),
	}
	return JSON.stringify(state)

func _ai_on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var bot_id := _ai_pending_bot
	_ai_pending_bot = 0
	if bot_id == 0 or not bots.has(bot_id):
		return
	if response_code == 429:
		_ai_429_count += 1
		_ai_backoff_until_msec = Time.get_ticks_msec() + int(_ai_backoff_sec * 1000.0)
		_ai_backoff_sec = minf(_ai_backoff_sec * 2.0, 600.0)
		_ai_conn_status = "rate_limited (429)"
		_ai_apply_local_fallback_decision(bot_id, "http_429_backoff")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_ai_conn_status = "offline_fallback (%d)" % response_code
		_ai_apply_local_fallback_decision(bot_id, "http_error_%d" % response_code)
		return
	_ai_backoff_sec = 60.0
	_ai_conn_status = "online (200)"
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_ai_apply_local_fallback_decision(bot_id, "invalid_json")
		return
	var usage = parsed.get("usage", {})
	if usage is Dictionary:
		var tok := int((usage as Dictionary).get("total_tokens", int((usage as Dictionary).get("prompt_tokens", 0)) + int((usage as Dictionary).get("completion_tokens", 0))))
		if tok <= 0:
			tok = 220
		_ai_tokens_day += tok
		_ai_tokens_total += tok
	else:
		_ai_tokens_day += 220
		_ai_tokens_total += 220
	var choices = parsed.get("choices", [])
	if not (choices is Array) or choices.is_empty():
		return
	var ch = choices[0]
	if not (ch is Dictionary):
		return
	var msg = ch.get("message", {})
	if not (msg is Dictionary):
		return
	var content = msg.get("content", "")
	if content is String and not (content as String).is_empty():
		_ai_apply_decision(bot_id, content)

# Valida la respuesta del modelo contra el catálogo cerrado y contra las
# ubicaciones conocidas del bot (anti-omnisciencia). Devuelve {} si no es válida.
func _ai_parse_decision(text: String, b: Dictionary = {}) -> Dictionary:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var first_nl := t.find("\n")
		var last_fence := t.rfind("```")
		if first_nl > 0 and last_fence > first_nl:
			t = t.substr(first_nl + 1, last_fence - first_nl - 1).strip_edges()
	if not t.begins_with("{"):
		return {}
	var parsed = JSON.parse_string(t)
	if not (parsed is Dictionary):
		return {}
	var action := str(parsed.get("action", "")).to_lower().strip_edges()
	if not AI_ALLOWED_ACTIONS.has(action):
		return {}
	var raw_target := str(parsed.get("target", parsed.get("poi_kind", ""))).strip_edges()
	var kind := raw_target.to_lower()
	var goal := str(parsed.get("goal", action)).substr(0, 64)
	var prio := clampi(int(parsed.get("priority", 3)), 1, 5)
	var reason := str(parsed.get("reason", "")).substr(0, 80)

	# Anti-omnisciencia: si Qwen indica un poi_id concreto ("house:100:100") o
	# coordenadas explícitas ("250,-250"), el bot DEBE conocer esa ubicación.
	var specific_pos := Vector3.INF
	if ":" in raw_target or "," in raw_target:
		if b.is_empty() or not bot_knows_location(b, raw_target):
			return {}
		var known: Dictionary = (b.get("_mem", {}) as Dictionary).get("known_locations", {})
		for k in known.keys():
			if str(k).to_lower() == kind:
				var p_arr = (known[k] as Dictionary).get("pos", [])
				if p_arr is Array and (p_arr as Array).size() >= 3:
					specific_pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
				kind = str((known[k] as Dictionary).get("kind", "wild")).to_lower()
				break

	var out := {
		"goal": goal,
		"action": action,
		"target": raw_target if not raw_target.is_empty() else kind,
		"priority": prio,
		"reason": reason,
		"source": "qwen",
	}
	if specific_pos != Vector3.INF:
		out["mode"] = "pos"
		out["pos"] = specific_pos
		return out

	match action:
		"explore":
			out["mode"] = "poi"
			out["only_kinds"] = [kind] if AI_POI_KINDS.has(kind) else []
		"scavenge":
			out["mode"] = "poi"
			out["only_kinds"] = [kind] if AI_POI_KINDS.has(kind) and kind != "wild" and kind != "tower" else ["military", "city"]
		"hunt":
			out["mode"] = "poi"
			out["only_kinds"] = ["wild"]
		"return_home", "rest", "fortify_camp":
			out["mode"] = "pos"
		"seek_ally":
			out["mode"] = "ally"
		"forage":
			out["mode"] = "food"
		"avoid_zone":
			if not AI_POI_KINDS.has(kind):
				return {}
			out["mode"] = "avoid"
			out["avoid_kinds"] = [kind]
		_:
			return {}
	return out

func _ai_apply_decision(bot_id: int, content: String) -> void:
	if not bots.has(bot_id):
		return
	var b: Dictionary = bots[bot_id]
	var d := _ai_parse_decision(content, b)
	if d.is_empty():
		return
	if str(d.get("mode", "")) == "pos" and not d.has("pos"):
		var home: Vector3 = b.get("shelter_pos", Vector3.INF)
		if str(d.get("action", "")) in ["rest", "fortify_camp"]:
			var camp: Vector3 = b.get("camp_spot", Vector3.INF)
			if camp != Vector3.INF:
				home = camp
		elif home == Vector3.INF:
			home = b.get("camp_spot", Vector3.INF)
		if home == Vector3.INF:
			return
		d["pos"] = home
	elif str(d.get("mode", "")) == "ally":
		var ally_pos := _nearest_friendly_bot_pos(bot_id)
		if ally_pos != Vector3.INF:
			d["mode"] = "pos"
			d["pos"] = ally_pos
		else:
			d["mode"] = "poi"
			d["only_kinds"] = ["house"]
	d["until"] = Time.get_ticks_msec() + AI_DIRECTIVE_TTL_MSEC
	b["ai_directive"] = d
	b["current_goal"] = str(d.get("goal", d.get("action", "survive")))
	var mem := _ensure_bot_memory(bot_id, b.get("cfg", {}))
	mem["pending_goals"] = [{"goal": b["current_goal"], "action": str(d.get("action", "")), "target": str(d.get("target", "")), "priority": int(d.get("priority", 3))}]
	print("[AI-ADV] %s: %s -> %s (p=%d, %s)" % [str(b.get("name", bot_id)), str(d.get("goal", "?")), str(d.get("action", "?")), int(d.get("priority", 3)), str(d.get("reason", ""))])

func _ai_apply_local_fallback_decision(bot_id: int, reason: String = "local_fallback") -> Dictionary:
	if not bots.has(bot_id):
		return {}
	var b: Dictionary = bots[bot_id]
	var local_d := decide_situational_action(b)
	local_d["reason"] = "%s (%s)" % [str(local_d.get("reason", "local")), reason]
	var json_str := JSON.stringify(local_d)
	_ai_apply_decision(bot_id, json_str)
	if b.get("ai_directive") is Dictionary:
		b["ai_directive"]["source"] = "local_fallback"
	return b.get("ai_directive", {})

func _nearest_friendly_bot_pos(bot_id: int) -> Vector3:
	if not bots.has(bot_id):
		return Vector3.INF
	var b: Dictionary = bots[bot_id]
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return Vector3.INF
	var pos := (proxy as Node3D).global_position
	var best := Vector3.INF
	var best_d := INF
	for oid in bots.keys():
		if int(oid) == bot_id:
			continue
		var ob: Dictionary = bots[oid]
		if str(ob.get("faction", "")) != "friendly":
			continue
		var op = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var d := pos.distance_to((op as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (op as Node3D).global_position
	return best

func _ai_active_directive(b: Dictionary) -> Dictionary:
	var d = b.get("ai_directive", {})
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return {}
	if int((d as Dictionary).get("until", 0)) < Time.get_ticks_msec():
		b["ai_directive"] = {}
		return {}
	return d

# ==================== MEMORIA PERSISTENTE ENTRE SESIONES (V2) ====================
# Persiste por separado para cada bot: identidad, personalidad evolutiva,
# eventos (y su resumen histórico), ubicaciones conocidas (con riesgo y score),
# relaciones con jugadores/bots, estrategias (éxito/fracaso/preferencia) y
# objetivos pendientes. Sobrevive al reinicio del servidor.

func _ai_memory_enabled() -> bool:
	return force_memory_io or OS.has_feature("dedicated_server")

func _ai_load_memory() -> void:
	if not _ai_memory_enabled() or not FileAccess.file_exists(memory_path):
		return
	var f := FileAccess.open(memory_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var bots_data = parsed.get("bots", {})
	if not (bots_data is Dictionary):
		return
	for key in bots_data.keys():
		var sd = bots_data[key]
		if not (sd is Dictionary):
			continue
		var bid := int(key)
		var mem: Dictionary = _ensure_bot_memory(bid)
		for field in ["identity", "personality", "deaths", "last_death_cause", "gear_learned", "scarcity", "zone_yield", "death_spots", "events", "events_summary", "known_locations", "relationships", "strategies", "pending_goals", "sessions", "stats"]:
			if sd.has(field):
				mem[field] = sd[field]
		var lp = sd.get("last_death_pos")
		if lp is Array and (lp as Array).size() >= 3:
			mem["last_death_pos"] = Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
		else:
			mem["last_death_pos"] = Vector3.INF
		mem["visited"] = [] # cada sesión regenera el loot de las casas
		mem["sessions"] = int(mem.get("sessions", 0)) + 1
		if bots.has(bid):
			bots[bid]["_mem"] = mem
			bots[bid]["personality"] = mem.get("personality", {})

func _ai_save_memory() -> void:
	if not _ai_memory_enabled():
		return
	for bid in bots.keys():
		var b: Dictionary = bots[bid]
		var bp: Node3D = b.get("proxy")
		if bp != null and is_instance_valid(bp) and not bool(bp.get_meta("proxy_dead", false)):
			_bot_flush_alive_time(b)
	var out := {"version": 2, "bots": {}}
	for bid in _memory.keys():
		var mem: Dictionary = _ensure_bot_memory(int(bid))
		_ai_prune_and_summarize_memories(mem)
		var sd := {}
		for field in ["identity", "personality", "deaths", "last_death_cause", "gear_learned", "scarcity", "zone_yield", "death_spots", "events", "events_summary", "known_locations", "relationships", "strategies", "pending_goals", "sessions", "stats"]:
			if mem.has(field):
				sd[field] = mem[field]
		var lp = mem.get("last_death_pos", Vector3.INF)
		sd["last_death_pos"] = [lp.x, lp.y, lp.z] if lp is Vector3 and lp != Vector3.INF else []
		out["bots"][str(bid)] = sd
	var f := FileAccess.open(memory_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))
	f.close()

# Registra qué botín dio la zona donde se recogió y actualiza la estrategia y ubicación.
func _ai_note_loot(b: Dictionary, item_name: String, item_type: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	var proxy = b.get("proxy")
	if mem.is_empty() or proxy == null or not is_instance_valid(proxy):
		return
	var bid := int(b.get("bot_id", 0))
	var pos := (proxy as Node3D).global_position
	var kind := _poi_kind_near(pos)
	var zy: Dictionary = mem.get("zone_yield", {})
	var zk: Dictionary = zy.get(kind, {"n": 0, "good": 0})
	zk["n"] = int(zk.get("n", 0)) + 1
	var is_good := _is_gear_item(item_name, item_type) or item_type.begins_with("weapon") or item_type == "medical"
	if is_good:
		zk["good"] = int(zk.get("good", 0)) + 1
		_evolve_personality(b, "good_loot", 0.25)
	zy[kind] = zk
	mem["zone_yield"] = zy
	record_strategy_outcome(bid, "scavenge" if kind in ["military", "city"] else "explore", true, 0.10 if is_good else 0.04)

func _poi_kind_near(pos: Vector3) -> String:
	var best := "wild"
	var best_d := 20.0
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		if d < best_d:
			best_d = d
			best = str(p.get("kind", "wild"))
	return best

# Factor 0.2-1.7 sobre el score de un POI según lo aprendido: rendimiento de
# botín, puntos letales, riesgo percibido en known_locations y estrategias.
func _ai_poi_memory_factor(b: Dictionary, pos: Vector3, kind: String) -> float:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return 1.0
	var factor := 1.0
	var zy: Dictionary = mem.get("zone_yield", {})
	var zk: Dictionary = zy.get(kind, {})
	factor += minf(float(zk.get("good", 0)) * 0.06, 0.45)
	for s in mem.get("death_spots", []):
		if s is Dictionary:
			var dx := pos.x - float(s.get("x", 0.0))
			var dz := pos.z - float(s.get("z", 0.0))
			if dx * dx + dz * dz < 2025.0:
				factor *= 0.55
				break
	var known: Dictionary = mem.get("known_locations", {})
	var pid := "%s:%d:%d" % [kind, int(pos.x), int(pos.z)]
	if known.has(pid) and known[pid] is Dictionary:
		var risk := float((known[pid] as Dictionary).get("risk", 0.0))
		if risk > 0.0:
			var surv := float(_get_bot_personality(b).get("survival_instinct", 0.7))
			factor *= clampf(1.0 - risk * (0.28 + surv * 0.25), 0.22, 1.0)
	var strats: Dictionary = mem.get("strategies", {})
	var st_key := "explore_" + kind
	if strats.has(st_key) and strats[st_key] is Dictionary:
		factor *= clampf(float((strats[st_key] as Dictionary).get("preference", 1.0)), 0.4, 1.45)
	return clampf(factor, 0.2, 1.7)

func _ai_memory_summary(mem: Dictionary) -> Dictionary:
	var out := {"deaths": int(mem.get("deaths", 0))}
	var zy: Dictionary = mem.get("zone_yield", {})
	var best := ""
	var best_good := -1
	for k in zy.keys():
		var g := int((zy[k] as Dictionary).get("good", 0))
		if g > best_good:
			best_good = g
			best = str(k)
	if best != "":
		out["best_loot_zone"] = best
	var spots: Array = mem.get("death_spots", [])
	if not spots.is_empty():
		out["death_spots"] = spots.size()
	var known: Dictionary = mem.get("known_locations", {})
	if not known.is_empty():
		out["known_locations"] = known.size()
	var rels: Dictionary = mem.get("relationships", {})
	if not rels.is_empty():
		out["relationships"] = rels.size()
	return out

# ==================== PANEL Y API DE DEPURACIÓN ====================
# Expone personalidad, objetivo actual, última decisión de Qwen, recuerdos
# relevantes, confianza hacia jugadores, peticiones/tokens y estado de Groq.

func get_bot_debug_snapshot(bot_id: int) -> Dictionary:
	if not bots.has(bot_id):
		return {}
	var b: Dictionary = bots[bot_id]
	var mem: Dictionary = _ensure_bot_memory(bot_id, b.get("cfg", {}))
	var evs: Array = mem.get("events", [])
	var recent_evs: Array = []
	for i in range(maxi(0, evs.size() - 4), evs.size()):
		recent_evs.append(evs[i])
	return {
		"bot_id": bot_id,
		"name": str(b.get("name", "")),
		"faction": str(b.get("faction", "")),
		"hp": int(float(b.get("health", 100.0))),
		"hunger": int(float(b.get("hunger", 100.0))),
		"thirst": int(float(b.get("thirst", 100.0))),
		"personality": _get_bot_personality(b).duplicate(true),
		"current_goal": str(b.get("current_goal", "survival_patrol")),
		"last_qwen_decision": (b.get("ai_directive", {}) as Dictionary).duplicate(true),
		"recent_memories": recent_evs,
		"known_locations_count": (mem.get("known_locations", {}) as Dictionary).size(),
		"relationships": (mem.get("relationships", {}) as Dictionary).duplicate(true),
		"strategies": (mem.get("strategies", {}) as Dictionary).duplicate(true),
		"pending_goals": (mem.get("pending_goals", []) as Array).duplicate(true),
		"groq_stats": {
			"status": _ai_conn_status,
			"calls_day": _ai_calls_day,
			"calls_total": _ai_calls_total,
			"tokens_day": _ai_tokens_day,
			"tokens_total": _ai_tokens_total,
			"cache_hits": _ai_cache_hits,
			"http_429_count": _ai_429_count,
			"queue_size": _ai_queue.size(),
		},
	}

func get_ai_debug_report() -> String:
	var lines: Array[String] = []
	lines.append("=== SISTEMA IA PERSISTENTE DE BOTS (GROQ / QWEN) ===")
	lines.append("Estado Groq: %s  |  Peticiones hoy: %d/%d (total %d)  |  Tokens hoy: %d/%d (total %d)  |  Caché: %d  |  429s: %d  |  Cola: %d" % [
		_ai_conn_status, _ai_calls_day, ai_max_calls_per_day, _ai_calls_total,
		_ai_tokens_day, ai_max_tokens_per_day, _ai_tokens_total, _ai_cache_hits, _ai_429_count, _ai_queue.size()
	])
	var ids: Array = bots.keys()
	ids.sort()
	for bid in ids:
		var snap := get_bot_debug_snapshot(int(bid))
		var p: Dictionary = snap.get("personality", {})
		var d: Dictionary = snap.get("last_qwen_decision", {})
		lines.append("------------------------------------------------------------")
		lines.append("[%d] %s (%s) — HP %d%% · Hambre %d%% · Sed %d%% · Objetivo: %s" % [
			int(bid), str(snap.get("name", "")), str(snap.get("faction", "")),
			int(snap.get("hp", 100)), int(snap.get("hunger", 100)), int(snap.get("thirst", 100)),
			str(snap.get("current_goal", ""))
		])
		lines.append("  Personalidad: Val=%.2f Agr=%.2f Cur=%.2f Soc=%.2f Desc=%.2f Coop=%.2f Sup=%.2f" % [
			float(p.get("bravery", 0)), float(p.get("aggression", 0)), float(p.get("curiosity", 0)),
			float(p.get("sociability", 0)), float(p.get("distrust", 0)), float(p.get("cooperation", 0)),
			float(p.get("survival_instinct", 0))
		])
		if not d.is_empty():
			lines.append("  Última decisión (%s): goal=%s action=%s target=%s prio=%d (%s)" % [
				str(d.get("source", "qwen")), str(d.get("goal", "")), str(d.get("action", "")),
				str(d.get("target", "")), int(d.get("priority", 3)), str(d.get("reason", ""))
			])
		else:
			lines.append("  Última decisión: (sin directiva activa — IA táctica local)")
		var rels: Dictionary = snap.get("relationships", {})
		if not rels.is_empty():
			var r_parts: Array[String] = []
			for rk in rels.keys():
				var rv: Dictionary = rels[rk]
				r_parts.append("%s(trust=%.2f,host=%.2f,fear=%.2f)" % [str(rv.get("name", rk)), float(rv.get("trust", 0)), float(rv.get("hostility", 0)), float(rv.get("fear", 0))])
			lines.append("  Relaciones: %s" % ", ".join(r_parts))
		else:
			lines.append("  Relaciones: ninguna registrada aún")
		var mems: Array = snap.get("recent_memories", [])
		var m_parts: Array[String] = []
		for mv in mems:
			if mv is Dictionary:
				m_parts.append("%s:%s(%s)" % [str(mv.get("type", "")), str(mv.get("actor", "")), str(mv.get("zone", ""))])
		lines.append("  Ubicaciones conocidas: %d  |  Recuerdos recientes: %s" % [
			int(snap.get("known_locations_count", 0)),
			(", ".join(m_parts) if not m_parts.is_empty() else "ninguno")
		])
	return "\n".join(lines)

func get_full_web_status() -> Dictionary:
	var tod := 14.0
	if world != null and world.get("day_cycle") != null:
		tod = float(world.day_cycle.get("time_of_day"))
	var wild_n := 0
	if world != null and world.get_tree() != null:
		wild_n = world.get_tree().get_nodes_in_group("wildlife").size()
	var online_p := 0
	var net = world.get("net") if world != null else null
	if net != null and "players" in net:
		for pid in net.players.keys():
			if int(pid) != int(net.get_my_id()) and not is_bot_peer_id(int(pid)) and not bool(net.players[pid].get("offline", false)):
				online_p += 1
	var pois_out: Array = []
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		pois_out.append({"id": _poi_id(p), "kind": str(p.get("kind", "wild")), "pos": [snappedf(pp.x, 0.1), snappedf(pp.y, 0.1), snappedf(pp.z, 0.1)]})
	var bots_out: Array = []
	var ids: Array = bots.keys()
	ids.sort()
	for bid in ids:
		var b: Dictionary = bots[bid]
		var proxy: Node3D = b.get("proxy")
		var pos := proxy.global_position if proxy != null and is_instance_valid(proxy) else Vector3(b.get("pos", Vector3.ZERO))
		var mem: Dictionary = _ensure_bot_memory(int(bid), b.get("cfg", {}))
		var snap := get_bot_debug_snapshot(int(bid))
		var camp: Vector3 = b.get("camp_spot", Vector3.INF)
		var sh: Vector3 = b.get("shelter_pos", Vector3.INF)
		var et: Vector3 = b.get("explore_target", Vector3.INF)
		snap["pos"] = [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)]
		snap["rot"] = snappedf(float(b.get("rot", 0.0)), 0.01)
		snap["anim"] = str(b.get("anim", "idle"))
		snap["dead"] = bool(proxy.get_meta("proxy_dead", false)) if proxy != null and is_instance_valid(proxy) else false
		snap["held_item"] = str(b.get("held_item", ""))
		snap["clothing"] = str(b.get("clothing", ""))
		snap["backpack"] = str(b.get("backpack", ""))
		snap["torch_lit"] = bool(b.get("torch_lit", false))
		snap["crouching"] = bool(b.get("crouching", false))
		snap["sitting"] = bool(b.get("sitting", false))
		snap["in_shelter"] = _is_bot_wolf_protected(b) if proxy != null and is_instance_valid(proxy) else false
		snap["team_leader_id"] = int(b.get("team_leader_id", 0))
		snap["follow_mode"] = str(b.get("follow_mode", "follow"))
		snap["camp_spot"] = [snappedf(camp.x, 0.1), snappedf(camp.y, 0.1), snappedf(camp.z, 0.1)] if camp != Vector3.INF else []
		snap["shelter_pos"] = [snappedf(sh.x, 0.1), snappedf(sh.y, 0.1), snappedf(sh.z, 0.1)] if sh != Vector3.INF else []
		snap["explore_target"] = [snappedf(et.x, 0.1), snappedf(et.y, 0.1), snappedf(et.z, 0.1)] if et != Vector3.INF else []
		snap["inventory"] = (proxy.get_meta("saved_inventory", []) as Array) if proxy != null and is_instance_valid(proxy) else []
		snap["known_locations"] = (mem.get("known_locations", {}) as Dictionary).values()
		snap["deaths"] = int(mem.get("deaths", 0))
		snap["last_death_cause"] = str(mem.get("last_death_cause", ""))
		# Puntuacion y tiempo de vida: mem.stats acumula vidas anteriores y el
		# tramo no volcado de la vida actual se calcula desde alive_flush_msec.
		var now_ms := Time.get_ticks_msec()
		var st: Dictionary = mem.get("stats", {})
		var is_dead := bool(snap.get("dead", false))
		var life_sec := maxf(0.0, (now_ms - int(b.get("spawned_at_msec", now_ms))) / 1000.0)
		var unflushed := 0.0 if is_dead else maxf(0.0, (now_ms - int(b.get("alive_flush_msec", now_ms))) / 1000.0)
		var alive_total := float(st.get("alive_total_sec", 0.0)) + unflushed
		var score := int(round(
			alive_total / 60.0 * 2.0
			+ float(snap.get("known_locations_count", 0)) * 10.0
			+ float(st.get("kills_prey", 0)) * 15.0
			+ float(st.get("kills_predator", 0)) * 40.0
			+ float(st.get("animals_gutted", 0)) * 5.0
			- float(mem.get("deaths", 0)) * 75.0
		))
		snap["alive_seconds"] = int(life_sec)
		snap["alive_total_seconds"] = int(alive_total)
		snap["score"] = score
		snap["stats"] = st
		bots_out.append(snap)
	return {
		"timestamp": int(Time.get_unix_time_from_system()),
		"server": {
			"fps": Engine.get_frames_per_second(),
			"time_of_day": snappedf(tod, 0.05),
			"is_night": _is_world_night(),
			"wildlife_count": wild_n,
			"players_online": online_p,
		},
		"groq": {
			"model": AI_ADVISOR_MODEL,
			"status": _ai_conn_status,
			"calls_day": _ai_calls_day,
			"max_calls_day": ai_max_calls_per_day,
			"calls_total": _ai_calls_total,
			"tokens_day": _ai_tokens_day,
			"max_tokens_day": ai_max_tokens_per_day,
			"tokens_total": _ai_tokens_total,
			"cache_hits": _ai_cache_hits,
			"http_429_count": _ai_429_count,
			"queue_size": _ai_queue.size(),
		},
		"pois": pois_out,
		"bots": bots_out,
	}

func _ai_save_live_status() -> void:
	if not _ai_memory_enabled():
		return
	var f := FileAccess.open(AI_STATUS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(get_full_web_status()))
	f.close()

# ==================== FORRAJEO: SETAS Y FRUTA ====================
# Con hambre y sin comida comestible en la mochila, el bot busca lo que un
# jugador buscaria: setas (acciones eat_food, se comen al momento) y arboles
# frutales (pick_fruit, 3 s de recolecta y la fruta cae al suelo como en el
# juego del jugador). El asesor puede ampliar el radio con la accion "forage".

func _bot_has_edible_food(proxy: Node3D, desperate: bool) -> bool:
	for it in proxy.get_meta("saved_inventory", []):
		if not (it is Dictionary):
			continue
		var nm := str(it.get("name", ""))
		var tp := str(it.get("type", ""))
		if tp != "food" or nm == "Carne humana" or nm == "Pez crudo":
			continue
		if nm.begins_with("Carne cruda") and not desperate:
			continue
		if nm.begins_with("Lata de ") and not nm.ends_with(" abierta"):
			continue
		if nm.ends_with(" abierta"):
			var dmax := float(it.get("max_durability", 100.0))
			var dcur := float(it.get("durability", dmax))
			if dmax <= 0.0 or dcur <= 0.0:
				continue
		return true
	return false

func _bot_try_forage(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var hunger := float(b["hunger"])
	var desperate := hunger < 24.0
	var scarcity := bool(b.get("_mem", {}).get("scarcity", false))
	var line := 58.0 + (14.0 if scarcity else 0.0)
	var leader := _sensed_node(b, "_s_leader")
	var allowed := hunger < line and (leader == null or desperate)
	# De noche o oculto solo sale a comer si se esta muriendo de hambre:
	# un superviviente precavido no abandona el refugio por un capricho.
	if allowed and not desperate and (float(b.get("hide_timer", 0.0)) > 0.0 or _is_world_night()):
		allowed = false
	var st0: Dictionary = b.get("_forage", {})
	if not allowed or _bot_has_edible_food(proxy, desperate):
		if not st0.is_empty():
			b["_forage"] = {}
		return false
	# Objetivo en curso: caminar hasta el, esperar el tiempo de la accion y rematar
	var st: Dictionary = b.get("_forage", {})
	if not st.is_empty():
		var apos = st.get("pos")
		if not (apos is Vector3) or (apos as Vector3) == Vector3.INF:
			b["_forage"] = {}
			return false
		var flat := Vector2(proxy.global_position.x - (apos as Vector3).x, proxy.global_position.z - (apos as Vector3).z).length()
		if flat > 2.0:
			b["sitting"] = false
			b["crouching"] = false
			_move_bot_towards(b, apos, 4.8 if flat > 9.0 else 3.8, delta, "run" if flat > 9.0 else "walk")
			return true
		st["t"] = float(st.get("t", 0.0)) + delta
		b["anim"] = "idle"
		b["crouching"] = true
		b["sitting"] = false
		if float(st["t"]) >= float(st.get("t_need", 1.2)):
			b["_forage"] = {}
			_bot_forage_complete(b, st)
		return true
	# Escaneo con cadencia: iterar world_actions_by_id cada frame por bot era caro
	b["_forage_scan"] = float(b.get("_forage_scan", 0.0)) - delta
	if float(b["_forage_scan"]) > 0.0:
		return false
	b["_forage_scan"] = 1.2 + fmod(float(int(b["bot_id"])) * 0.31, 0.5)
	var radius := 30.0
	var d0 := _ai_active_directive(b)
	if str(d0.get("mode", "")) == "food":
		radius = 55.0
	var target := _find_forage_target(b, radius)
	if target.is_empty():
		return false
	b["_forage"] = target
	return _bot_try_forage(b, 0.0)

func _find_forage_target(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("world_actions_by_id" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var best := {}
	var best_d := radius
	var now := Time.get_unix_time_from_system()
	var claims: Dictionary = world.get("_pickup_claims") if "_pickup_claims" in world else {}
	var depleted: Array = world.get("_depleted_action_ids") if "_depleted_action_ids" in world else []
	# Setas primero: se comen al momento, sin objetos al suelo ni esperas largas
	for aid in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[aid]
		if a == null or not is_instance_valid(a):
			continue
		if str(a.get("action_type")) != "eat_food" or claims.has(aid) or depleted.has(aid):
			continue
		var d := proxy.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = {"kind": "eat", "id": str(aid), "pos": a.global_position, "t": 0.0, "t_need": 1.2,
				"use": float(a.get_meta("item_use_value", 12.0)), "name": str(a.get_meta("item_name", "comida"))}
	# Frutales: solo si no hay setas al alcance (la fruta cae al suelo y hay que recogerla)
	if best.is_empty():
		for aid in world.world_actions_by_id.keys():
			var a = world.world_actions_by_id[aid]
			if a == null or not is_instance_valid(a):
				continue
			if str(a.get("action_type")) != "pick_fruit" or claims.has(aid) or depleted.has(aid):
				continue
			if now < float(a.get_meta("fruit_ready_time", 0.0)):
				continue
			var d2 := proxy.global_position.distance_to(a.global_position)
			if d2 < best_d:
				best_d = d2
				best = {"kind": "fruit", "id": str(aid), "pos": a.global_position, "t": 0.0, "t_need": 3.0,
					"fruit": str(a.get_meta("fruit_type_name", "Higo"))}
	return best

func _bot_forage_complete(b: Dictionary, st: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var kind := str(st.get("kind", ""))
	var pos: Vector3 = st.get("pos", Vector3.INF)
	var aid := str(st.get("id", ""))
	if world == null or aid.is_empty():
		return
	var action = world.world_actions_by_id.get(aid)
	if action == null or not is_instance_valid(action):
		return
	if kind == "eat":
		# Revalidar: otro pudo comersela mientras caminaba
		if "_depleted_action_ids" in world and (world._depleted_action_ids as Array).has(aid):
			return
		var use := float(st.get("use", 12.0))
		var ename := str(st.get("name", "comida"))
		var thirst_mul := 0.2
		# Latas abiertas en el suelo: una porcion del 50% por bocado; pilas de
		# comida: una unidad cada vez. El resto de casos agota la accion entera.
		var is_can := ename.begins_with("Lata de ") and ename.ends_with(" abierta")
		var new_qty := -1
		var new_dur := -1.0
		var eat_scale := 1.0
		if is_can:
			thirst_mul = 0.15
			var cmax := float(action.get_meta("item_max_durability", action.get_meta("item_durability", 100.0)))
			var cdur := float(action.get_meta("item_durability", cmax))
			if cdur <= 0.0:
				return
			var cbite := minf(cmax * 0.5, cdur)
			eat_scale = cbite / cmax
			new_dur = cdur - cbite
			if new_dur <= 0.0:
				new_qty = 0
			else:
				new_qty = int(action.get_meta("item_quantity", 1))
		else:
			var pqty := int(action.get_meta("item_quantity", 1))
			if pqty > 1:
				new_qty = pqty - 1
				new_dur = float(action.get_meta("item_durability", 100.0))
		b["hunger"] = minf(100.0, float(b["hunger"]) + use * eat_scale)
		b["thirst"] = minf(100.0, float(b["thirst"]) + use * thirst_mul * eat_scale)
		var hp := minf(100.0, float(b["health"]) + maxf(3.0, use * 0.35 * eat_scale))
		b["health"] = hp
		proxy.set_meta("proxy_health", hp)
		proxy.set_meta("saved_health", hp)
		proxy.set_meta("saved_hunger", float(b["hunger"]))
		proxy.set_meta("saved_thirst", float(b["thirst"]))
		b["eat_cooldown"] = 10.0
		if new_qty < 0 or new_qty == 0:
			if world.has_method("_net_world_action_completed"):
				world._net_world_action_completed(aid, [], "", pos, 0)
			var net = world.get("net")
			if net != null and net.is_host and net.peer != null:
				for pid in net.players.keys():
					if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
						net.world_action_completed.rpc_id(pid, aid, [], "", pos)
		else:
			# Porcion o unidad parcial: la accion sigue en pie con menos contenido
			if world.has_method("_apply_ground_craft_state"):
				world._apply_ground_craft_state(aid, new_qty, maxf(new_dur, 0.0))
			var gnet = world.get("net")
			if gnet != null and gnet.is_host and gnet.peer != null:
				gnet.ground_craft_state_changed.rpc(aid, new_qty, maxf(new_dur, 0.0))
	elif kind == "fruit":
		var now := Time.get_unix_time_from_system()
		action.set_meta("fruit_ready_time", now + 300.0)
		if "_pending_fruit_cooldowns" in world:
			(world._pending_fruit_cooldowns as Dictionary)[aid] = now + 300.0
		var fruit_name := str(st.get("fruit", "Higo"))
		var fruit_use := 20.0 if fruit_name == "Naranja" else 12.0
		var fruit_w := 0.20 if fruit_name == "Naranja" else 0.10
		var net2 = world.get("net")
		for fi in range(2):
			var fpos := pos + Vector3(randf_range(-1.8, 1.8), 0.0, randf_range(-1.8, 1.8))
			fpos.y = _ground_y(fpos.x, fpos.z) + 0.06
			# Fruta que cae al agua se pierde, igual que para el jugador
			if world.has_method("_is_water_drop_position") and world._is_water_drop_position(fpos):
				continue
			var drop_id := "fruit_%d_%d" % [Time.get_ticks_msec(), fi]
			# Mismo camino que un drop de jugador: _net_item_dropped registra el
			# objeto, crea su WorldAction y la visual en el servidor; luego se
			# reenvia a cada cliente para que lo vea y pueda recogerlo.
			if world.has_method("_net_item_dropped"):
				world._net_item_dropped(drop_id, fruit_name, "food", fruit_w, 1, fruit_use, fpos, Color(0, 0, 0, 0), 0)
			if net2 != null and net2.is_host and net2.peer != null:
				for pid in net2.players.keys():
					if pid != net2.get_my_id() and not is_bot_peer_id(pid) and not net2.players[pid].get("offline", false) and net2.peer_alive(pid):
						net2.item_dropped.rpc_id(pid, drop_id, fruit_name, "food", fruit_w, 1, fruit_use, fpos, Color(0, 0, 0, 0))
		b["eat_cooldown"] = 4.0

# ==================== RECOLECCION DE MATERIALES: TALAR ARBUSTOS ====================
# El palo no existe como drop libre: un jugador lo consigue cortando arbustos
# (accion fell_bush, 5 s con filo en mano) y el bot hace exactamente lo mismo.
# Se activa cuando faltan palos para el refugio (4) o para la fogata (2) y no
# hay drops de Palo cerca — la piedra ya la recoge el saqueo normal y la cuerda
# sale del crafteo con tendon.

const BUSH_TOOLS := ["Hacha", "Hacha de piedra", "Cuchillo", "Cuchillo de piedra", "Cuchillo de hueso", "Piedra afilada"]

func _bot_bush_tool(proxy: Node3D) -> String:
	for t in BUSH_TOOLS:
		if _bot_item_count(proxy, t) > 0:
			return t
	return ""

func _bot_release_gather_claim(b: Dictionary, st: Dictionary) -> void:
	if world == null or not ("_pickup_claims" in world):
		return
	var aid := str(st.get("id", ""))
	if aid.is_empty():
		return
	if int((world._pickup_claims as Dictionary).get(aid, -1)) == int(b["bot_id"]):
		(world._pickup_claims as Dictionary).erase(aid)
		if "_pickup_claim_until" in world:
			(world._pickup_claim_until as Dictionary).erase(aid)

func _bot_try_gather_mats(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var palo_need := 0
	if str(b["shelter_id"]).is_empty():
		palo_need = 4
	elif str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)):
		palo_need = 2
	var tool := _bot_bush_tool(proxy)
	# Escondido o reclutado no sale a talar: las ordenes del lider y la
	# amenaza van primero. El ruido del corte atrae lobos, como al jugador.
	var allowed := palo_need > 0 and _bot_item_count(proxy, "Palo") < palo_need \
			and not tool.is_empty() and float(b.get("hide_timer", 0.0)) <= 0.0 \
			and _sensed_node(b, "_s_leader") == null
	var st0: Dictionary = b.get("_gather", {})
	if not allowed:
		if not st0.is_empty():
			_bot_release_gather_claim(b, st0)
			b["_gather"] = {}
		return false
	var st: Dictionary = b.get("_gather", {})
	if not st.is_empty():
		var aid := str(st.get("id", ""))
		var apos = st.get("pos")
		var act = world.world_actions_by_id.get(aid) if world != null and "world_actions_by_id" in world else null
		var taken := false
		if world != null and "_pickup_claims" in world:
			var claimer := int((world._pickup_claims as Dictionary).get(aid, int(b["bot_id"])))
			taken = claimer != int(b["bot_id"])
		if not (apos is Vector3) or act == null or not is_instance_valid(act) or taken \
				or (world != null and "_depleted_action_ids" in world and (world._depleted_action_ids as Array).has(aid)):
			_bot_release_gather_claim(b, st)
			b["_gather"] = {}
			return false
		var flat := Vector2(proxy.global_position.x - (apos as Vector3).x, proxy.global_position.z - (apos as Vector3).z).length()
		if flat > 2.2:
			b["sitting"] = false
			b["crouching"] = false
			b["held_item"] = tool
			proxy.set_meta("saved_held_item", tool)
			_move_bot_towards(b, apos, 4.8 if flat > 9.0 else 3.8, delta, "run" if flat > 9.0 else "walk")
			return true
		st["t"] = float(st.get("t", 0.0)) + delta
		b["anim"] = "forage"
		b["crouching"] = true
		b["sitting"] = false
		b["held_item"] = tool
		proxy.set_meta("saved_held_item", tool)
		if float(st["t"]) >= float(st.get("t_need", 5.0)):
			b["_gather"] = {}
			_bot_fell_bush_complete(b, st)
		return true
	# Escaneo con cadencia, como el forrajeo
	b["_gather_scan"] = float(b.get("_gather_scan", 0.0)) - delta
	if float(b["_gather_scan"]) > 0.0:
		return false
	b["_gather_scan"] = 1.4 + fmod(float(int(b["bot_id"])) * 0.29, 0.6)
	var target := _find_bush_target(b, 80.0)
	if target.is_empty():
		return false
	if world != null and "_pickup_claims" in world:
		(world._pickup_claims as Dictionary)[target["id"]] = int(b["bot_id"])
		if "_pickup_claim_until" in world:
			(world._pickup_claim_until as Dictionary)[target["id"]] = Time.get_ticks_msec() + 30000
	b["_gather"] = target
	return _bot_try_gather_mats(b, 0.0)

func _find_bush_target(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("world_actions_by_id" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var camp: Vector3 = b.get("camp_spot", proxy.global_position)
	var claims: Dictionary = world.get("_pickup_claims") if "_pickup_claims" in world else {}
	var depleted: Array = world.get("_depleted_action_ids") if "_depleted_action_ids" in world else []
	var best := {}
	var best_score := INF
	for aid in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[aid]
		if a == null or not is_instance_valid(a):
			continue
		if str(a.get("action_type")) != "fell_bush" or claims.has(aid) or depleted.has(aid):
			continue
		var d := proxy.global_position.distance_to((a as Node3D).global_position)
		if d > radius:
			continue
		# Prefiere arbustos entre el bot y su campamento: el humano tala cerca
		# de donde va a construir, no en la punta opuesta del mapa.
		var d_camp := (a as Node3D).global_position.distance_to(camp)
		var score := d + d_camp * 0.5
		if score < best_score:
			best_score = score
			best = {"id": str(aid), "pos": (a as Node3D).global_position, "t": 0.0, "t_need": 5.0}
	return best

func _bot_fell_bush_complete(b: Dictionary, st: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var aid := str(st.get("id", ""))
	var pos: Vector3 = st.get("pos", Vector3.INF)
	_bot_release_gather_claim(b, st)
	if world == null or aid.is_empty() or pos == Vector3.INF:
		return
	var action = world.world_actions_by_id.get(aid) if "world_actions_by_id" in world else null
	if action == null or not is_instance_valid(action):
		return
	if "_depleted_action_ids" in world and (world._depleted_action_ids as Array).has(aid):
		return
	var tool := _bot_bush_tool(proxy)
	if tool.is_empty():
		return
	# Mismo coste que el jugador: el filo pierde 5 de durabilidad por arbusto.
	_reduce_bot_item_durability(proxy, tool, 5.0)
	# El ruido del corte atrae fauna hostil, igual que al jugador.
	if world.has_method("_attract_wolves_to_noise"):
		world._attract_wolves_to_noise(pos, 30.0)
	# Los mismos drops que genera el handler del jugador: 3 palos + semillas.
	var base := Time.get_ticks_msec()
	var spawns: Array = [
		{"id": "pickup_Palo_%d" % (base + randi() % 1000), "name": "Palo", "type": "resource", "pos": pos + Vector3(0.3, 0.06, 0.0), "weight": 0.3, "qty": 1, "use": 0.0},
		{"id": "pickup_Palo_%d" % (base + randi() % 1000), "name": "Palo", "type": "resource", "pos": pos + Vector3(-0.3, 0.06, 0.2), "weight": 0.3, "qty": 1, "use": 0.0},
		{"id": "pickup_Palo_%d" % (base + randi() % 1000), "name": "Palo", "type": "resource", "pos": pos + Vector3(0.1, 0.06, -0.3), "weight": 0.3, "qty": 1, "use": 0.0},
		{"id": "pickup_Semillas_%d" % (base + randi() % 1000), "name": "Semillas", "type": "resource", "pos": pos + Vector3(-0.15, 0.05, -0.25), "weight": 0.05, "qty": 1, "use": 0.0},
	]
	if world.has_method("_net_world_action_completed"):
		world._net_world_action_completed(aid, spawns, "", pos, 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.world_action_completed.rpc_id(pid, aid, spawns, "", pos)
	# Los palos caen al suelo: el saqueo normal los recoge en el proximo tick.
