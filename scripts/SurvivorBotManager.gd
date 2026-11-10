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
	if x < -210.0 and z < -210.0:
		ty = maxf(ty, HighMountainZone.ground_height_at(Vector3(x, 0.0, z)) - 0.025)
	if from_y == -INF or not (world is Node3D):
		return ty
	# Escaleras, rampas y pisos transitables sobre el terreno: mismo sondeo
	# hacia abajo que usa el jugador, para subir escaleras de casas y torres.
	var w3d := (world as Node3D).get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		return ty
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y + 1.15, z), Vector3(x, from_y - 1.15, z), 5)
	var hit := w3d.direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hy := float((hit["position"] as Vector3).y)
		if hy >= ty - 0.05 and hy <= from_y + 1.15:
			return hy - 0.025
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
func _nearest_water_pos(from: Vector3, b: Dictionary = {}) -> Vector3:
	if world == null or not world.has_method("_default_river_segments"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 280.0
	for seg in world._default_river_segments():
		if not (seg is Dictionary):
			continue
		var c: Vector3 = seg.get("center", Vector3.ZERO)
		var sz: Vector2 = seg.get("size", Vector2.ZERO)
		var yaw: float = deg_to_rad(float(seg.get("yaw", 0.0)))
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var across := Vector3(sin(yaw), 0.0, cos(yaw))
		var off := from - c
		off.y = 0.0
		var target_pt := c
		if sz.x >= 60.0:
			# Lago: apuntar a la orilla de la elipse mas cercana al bot, nunca
			# al centro profundo de 150x90 m.
			var rx := maxf(1.0, sz.x * 0.5 * 0.82)
			var rz := maxf(1.0, sz.y * 0.5 * 0.82)
			var nf := off.dot(along) / rx
			var ns := off.dot(across) / rz
			var nlen := sqrt(nf * nf + ns * ns)
			if nlen > 0.01:
				target_pt = c + along * (nf / nlen * rx) + across * (ns / nlen * rz)
		elif sz.x > 0.1 and sz.y > 0.1:
			# Rio: apuntar a la orilla somera del lado del bot en vez del eje
			# profundo, para que _move_bot_towards no frene antes de beber.
			var lf := clampf(off.dot(along), -sz.x * 0.45, sz.x * 0.45)
			var side_sign := 1.0 if off.dot(across) >= 0.0 else -1.0
			var hw := maxf(0.5, sz.y * 0.5 - 0.35)
			target_pt = c + along * lf + across * (side_sign * hw)
		if not b.is_empty() and _is_water_blacklisted(b, target_pt):
			continue
		var d := Vector2(from.x - target_pt.x, from.z - target_pt.z).length()
		if d < best_d:
			best_d = d
			best = target_pt
	# Fuentes y otras zonas drink_water en tierra firme (p.ej. la fuente de la
	# plaza de la ciudad): el bot puede beber y rellenar su botella en ellas
	# igual que un jugador con E mantenida. Las acciones drink_N del rio/lago
	# caen dentro del agua y ya las cubren los segmentos de arriba.
	if "world_actions_by_id" in world:
		for aid in world.world_actions_by_id.keys():
			var a = world.world_actions_by_id[aid]
			if a == null or not is_instance_valid(a) or not (a is Node3D):
				continue
			if str(a.get("action_type")) != "drink_water":
				continue
			var ap: Vector3 = (a as Node3D).global_position
			if world.has_method("get_river_depth_at") and float(world.get_river_depth_at(ap)) >= 0.05:
				continue
			var target_pt := Vector3(ap.x, 0.0, ap.z)
			if world.has_method("is_bot_blocked_at") and world.is_bot_blocked_at(target_pt):
				target_pt = _unblock_bot_point(target_pt, from)
				if target_pt == Vector3.INF:
					continue
			if not b.is_empty() and _is_water_blacklisted(b, target_pt):
				continue
			var d := Vector2(from.x - target_pt.x, from.z - target_pt.z).length()
			if d < best_d:
				best_d = d
				best = target_pt
	return best

# Punto dentro de un bloqueador circular (la fuente de la plaza es un bloque
# solido de radio 2.0): proyecta el destino al brocal del bloqueo, hacia el
# lado por donde viene el bot, para que pueda beber sin chocar con la pileta.
func _unblock_bot_point(blocked: Vector3, from: Vector3) -> Vector3:
	if world == null:
		return Vector3.INF
	var blockers: Array = world.get("wildlife_blockers") if world.get("wildlife_blockers") != null else []
	for bl in blockers:
		if not (bl is Dictionary) or bl.has("house_bounds") or bool(bl.get("tent_open", false)):
			continue
		var bp: Vector3 = bl.get("pos", Vector3.ZERO)
		var radius := float(bl.get("radius", 1.8))
		if Vector2(blocked.x - bp.x, blocked.z - bp.z).length() > radius:
			continue
		var dir := Vector2(from.x - bp.x, from.z - bp.z)
		if dir.length() < 0.01:
			dir = Vector2(1.0, 0.0)
		dir = dir.normalized()
		var rim := radius + 0.55
		var cand := Vector3(bp.x + dir.x * rim, 0.0, bp.z + dir.y * rim)
		if world.has_method("is_bot_blocked_at") and world.is_bot_blocked_at(cand):
			continue
		return cand
	return Vector3.INF

func spawn_all_bots() -> void:
	if world == null:
		return
	for cfg in BOT_CONFIGS:
		_spawn_bot(cfg)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null and net.has_method("_broadcast_player_list"):
		net._broadcast_player_list()

# Spawn dentro de las mismas zonas de spawn que usan los jugadores
# (_spawn_zones del mundo): se evaluan TODAS las zonas con pequenos offsets
# y se toma la primera con >=80 m de separacion a cualquier superviviente
# (bot o jugador humano). Si ninguna llega, se elige la que maximiza la
# separacion: dos supervivientes nunca comparten punto de aparicion.
# El respawn ademas queda siempre a >=220 m del punto de muerte.
func _random_bot_spawn(cfg: Dictionary, avoid_pos: Vector3 = Vector3.INF) -> Vector3:
	var fallback := Vector3(cfg.get("spawn", Vector3.ZERO))
	var zones_v = world.get("_spawn_zones") if world != null else null
	var zones: Array = zones_v if zones_v is Array else []
	if zones.is_empty():
		return _sanitize_ground_point(fallback)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var order: Array = range(zones.size())
	for i in range(order.size()):
		var j: int = rng.randi() % order.size()
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var best := Vector3.INF
	var best_sep := -1.0
	for zi in order:
		var zone: Vector3 = zones[zi]
		for j in range(3):
			var cand := Vector3(zone.x + rng.randf_range(-3.0, 3.0), 0.0, zone.z + rng.randf_range(-3.0, 3.0))
			if avoid_pos != Vector3.INF and Vector2(cand.x - avoid_pos.x, cand.z - avoid_pos.z).length() < 220.0:
				continue
			if world.has_method("_is_near_river") and world._is_near_river(cand, 30.0):
				continue
			if _is_pos_blocked(cand, 0.7):
				continue
			var sep := _min_dist_to_survivors(cand)
			if sep >= 80.0:
				return _sanitize_ground_point(cand)
			if sep > best_sep:
				best_sep = sep
				best = cand
	if best != Vector3.INF:
		return _sanitize_ground_point(best)
	# Sin candidato valido: la zona MAS ALEJADA del punto de muerte (o al azar)
	var far_zone: Vector3 = zones[rng.randi() % zones.size()]
	if avoid_pos != Vector3.INF:
		var far_d := -1.0
		for z in zones:
			var zv: Vector3 = z
			var dz := Vector2(zv.x - avoid_pos.x, zv.z - avoid_pos.z).length()
			if dz > far_d:
				far_d = dz
				far_zone = zv
	return _sanitize_ground_point(far_zone)

func _min_dist_to_other_bots(pos: Vector3) -> float:
	var sep := INF
	for other_id in bots.keys():
		var ob: Dictionary = bots[other_id]
		var opr = ob.get("proxy")
		var op: Vector3 = ob.get("pos", Vector3.INF)
		if opr != null and is_instance_valid(opr) and opr is Node3D:
			op = (opr as Node3D).global_position
		if op is Vector3 and op != Vector3.INF:
			sep = minf(sep, Vector2(pos.x - op.x, pos.z - op.z).length())
	return sep

# Distancia al superviviente mas cercano (bot o jugador humano con proxy vivo).
func _min_dist_to_survivors(pos: Vector3) -> float:
	var sep := _min_dist_to_other_bots(pos)
	if world == null:
		return sep
	for prop_name in ["server_proxies", "proxy_by_client_id", "net_player_proxy"]:
		var proxies = world.get(prop_name)
		if proxies is Dictionary:
			for k in (proxies as Dictionary).keys():
				if str(k).is_valid_int() and is_bot_peer_id(int(k)):
					continue
				var pr = (proxies as Dictionary)[k]
				if pr != null and is_instance_valid(pr) and pr is Node3D:
					sep = minf(sep, Vector2(pos.x - (pr as Node3D).global_position.x, pos.z - (pr as Node3D).global_position.z).length())
	var net = world.get("net")
	if net != null and "players" in net:
		for pid in net.players.keys():
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)):
				continue
			var pdata: Dictionary = net.players[pid]
			if bool(pdata.get("is_ai_bot", false)) or bool(pdata.get("offline", false)):
				continue
			var ppos = pdata.get("pos")
			if ppos is Vector3 and (ppos as Vector3) != Vector3.ZERO:
				sep = minf(sep, Vector2(pos.x - (ppos as Vector3).x, pos.z - (ppos as Vector3).z).length())
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
	var spawn_pos: Vector3 = _random_bot_spawn(cfg, Vector3(_ensure_bot_memory(bot_id, cfg).get("last_death_pos", Vector3.INF)))
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

	# Como el jugador humano: el bot nace solo con la ropa puesta, sin arma,
	# sin mochila y sin items — todo lo que lleve lo ha saqueado o fabricado.
	var inv_items: Array = (cfg.get("starting_items", []) as Array).duplicate(true)
	var cloth_arr: Array = (cfg.get("starting_clothing", []) as Array).duplicate()
	var cloth_str := ",".join(cloth_arr)
	var bp_str := str(cfg.get("starting_backpack", ""))
	var held_str := ""

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
		"sick_timer": 0.0,
		"cook_cooldown": 0.0,
		"camp_spot": camp_spot,
		"shelter_id": "",
		"shelter_pos": Vector3.INF,
		"campfire_id": "",
		"campfire_pos": Vector3.INF,
		"hide_timer": 0.0,
		"team_leader_id": 0, # 0 = libre, >0 = peer_id del jugador líder (1 en SP/host)
		"follow_mode": "follow", # "follow" | "stay" | "guard"
		"_chat_cd": 0.0,
		"_chat_reply_ready": 0,
		"_chat_inbox": {},
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
		"_farm": {},
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
	# Modelo de supervivencia identico al del jugador humano (SurvivalStats):
	# hambre, sed, energia, sueño, temperatura corporal y lluvia con las mismas
	# reglas. La senal died mata al bot por inanicion/hipotermia/calor/etc.
	var vstats := SurvivalStats.new()
	vstats.health = float(bot_state["health"])
	vstats.hunger = float(bot_state["hunger"])
	vstats.thirst = float(bot_state["thirst"])
	vstats.energy = 100.0
	vstats.sleep = 100.0
	vstats.body_temperature = 36.7
	vstats.died.connect(_on_bot_stats_died.bind(bot_state))
	bot_state["vstats"] = vstats
	# Enlazar la memoria persistente del personaje: identidad, personalidad
	# evolutiva, recuerdos de eventos, ubicaciones conocidas (sin omnisciencia),
	# relaciones sociales, estrategias y objetivos pendientes.
	var mem: Dictionary = _ensure_bot_memory(bot_id, cfg)
	bot_state["_mem"] = mem
	bot_state["personality"] = (mem.get("personality", {}) as Dictionary)
	# Recuerda su refugio si aun existe y no le pilla absurdamente lejos; si no,
	# lo olvida — queda como estructura huerfana saqueable/desmontable.
	var mem_sh: Dictionary = mem.get("shelter", {})
	var sh_sid := str(mem_sh.get("id", ""))
	var sh_mpos := mem_sh.get("pos", [])
	var sh_restored := false
	if not sh_sid.is_empty() and sh_mpos is Array and (sh_mpos as Array).size() >= 3 and not _find_shelter_dict(sh_sid).is_empty():
		var sp2 := Vector3(float((sh_mpos as Array)[0]), float((sh_mpos as Array)[1]), float((sh_mpos as Array)[2]))
		if Vector2(spawn_pos.x - sp2.x, spawn_pos.z - sp2.z).length() <= 220.0:
			bot_state["shelter_id"] = sh_sid
			bot_state["shelter_pos"] = sp2
			sh_restored = true
	if not sh_restored:
		mem["shelter"] = {}
	# Al aparecer, el bot solo conoce su entorno inmediato y su patrulla inicial
	_observe_nearby_world(bot_state)
	for pt in patrol:
		if pt is Vector3:
			var pid := "patrol:%d:%d" % [int((pt as Vector3).x), int((pt as Vector3).z)]
			observe_location(bot_id, pid, "wild", pt as Vector3, "observed")
	# Prudencia aprendida: si murio por depredadores o inanicion, durante los
	# primeros minutos de su nueva vida evita la zona donde cayo.
	bot_state["caution_until"] = 240.0 if str(mem.get("last_death_cause", "")) in ["wolf_bite", "bear_bite", "starved", "dehydrated", "hypothermia"] else 0.0
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
	_voice_tick(delta)
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

func _bot_effective_net_anim(b: Dictionary) -> String:
	var raw := str(b.get("anim", "idle"))
	if raw == "dead":
		return "dead"
	if bool(b.get("sleeping", false)):
		return "sleep"
	if float(b.get("consume_anim_t", 0.0)) > 0.0 and raw in ["idle", "walk"]:
		return str(b.get("consume_anim", "eat"))
	if bool(b.get("sitting", false)) or raw == "sit":
		return "sit"
	if bool(b.get("crouching", false)) and raw in ["walk", "idle"]:
		return "sneak"
	if bool(b.get("has_rifle", false)):
		if raw == "run":
			return "riflerun"
		if raw == "walk":
			return "riflewalk"
		if raw == "idle":
			return "rifleaim" if bool(b.get("is_aiming", false)) else "rifleidle"
	return raw

func _broadcast_bots() -> void:
	if world == null:
		return
	var net = world.get("net")
	for bot_id in bots.keys():
		var b: Dictionary = bots[bot_id]
		var net_anim := _bot_effective_net_anim(b)
		_publish_bot_to_net_players(b)
		if net != null and net.players.has(bot_id):
			net.players[bot_id]["anim"] = net_anim
		_apply_local_avatar_metadata(b)
		if net != null and net.is_host and net.is_connected and net.peer != null:
			for pid in net.snapshot_recipients():
				if is_bot_peer_id(pid):
					continue
				net.sync_player_state.rpc_id(
					pid, bot_id, b["pos"], float(b["rot"]), net_anim,
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
		b["_act"] = "dead"
		b["torch_lit"] = false
		b["is_aiming"] = false
		b["_ambush"] = {}
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
	b["sick_timer"] = maxf(0.0, float(b.get("sick_timer", 0.0)) - delta)
	b["cook_cooldown"] = maxf(0.0, float(b["cook_cooldown"]) - delta)
	b["_soc_t"] = maxf(0.0, float(b.get("_soc_t", 0.0)) - delta)
	b["_meet_ev_t"] = maxf(0.0, float(b.get("_meet_ev_t", 0.0)) - delta)
	b["_chat_cd"] = maxf(0.0, float(b.get("_chat_cd", 0.0)) - delta)
	b["aggro_timer"] = maxf(0.0, float(b["aggro_timer"]) - delta)
	if float(b["aggro_timer"]) <= 0.0:
		b["aggro_target"] = null

	# Supervivencia identica a la del jugador humano: SurvivalStats simula
	# hambre, sed, energia, sueño, temperatura corporal, lluvia, vadeo, calor
	# de fogata/antorcha y muerte por inanicion/hipotermia/calor/agotamiento.
	_bot_survival_tick(b, delta)
	if bool(proxy.get_meta("proxy_dead", false)):
		return
	proxy.set_meta("saved_hunger", float(b["hunger"]))
	proxy.set_meta("saved_thirst", float(b["thirst"]))
	_maintain_bot_needs(b, delta)

	# Si acaba de recibir un disparo o golpe, acusa el impacto (flinch) antes de
	# reanudar movimiento o ataque, manteniendo la animacion shot/hit visible.
	if float(b.get("flinch_timer", 0.0)) > 0.0:
		b["flinch_timer"] = maxf(0.0, float(b["flinch_timer"]) - delta)
		b["sitting"] = false
		b["sleeping"] = false
		b["is_aiming"] = false
		b["anim"] = str(b.get("flinch_anim", "hit"))
		b["_act"] = "flinch"
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
		b["_s_raid_shelter"] = _find_nearby_raidable_shelter(b, 38.0)
		_observe_nearby_world(b)
		_try_share_allied_knowledge(b)
		_bot_social_update(b)
		# Orden de equipo "equip": si no queda equipo suelto a mano, se da por cumplida
		if bool(b.get("equip_mission", false)) and (b["_s_loot"] as Dictionary).is_empty():
			b["equip_mission"] = false

	# Luz nocturna con antorcha (se apaga si se está ocultando en su refugio)
	var is_night := _is_world_night()
	var sh_pos: Vector3 = b["shelter_pos"]
	var camp_pos: Vector3 = b["camp_spot"]
	var hiding_in_shelter: bool = float(b["hide_timer"]) > 0.0 and sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 2.6
	b["torch_lit"] = is_night and not hiding_in_shelter and not bool(b.get("sleeping", false)) and _bot_has_item(proxy, "Antorcha")
	proxy.set_meta("torch_lit", bool(b["torch_lit"]))
	proxy.set_meta("in_built_shelter", sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 3.4)
	proxy.set_meta("crouching", bool(b["crouching"]))
	proxy.set_meta("prone", bool(b["prone"]))
	proxy.set_meta("sprinting", str(b["anim"]) == "run")
	var moving_now: bool = str(b["anim"]) == "walk" or str(b["anim"]) == "run"
	proxy.set_meta("moving", moving_now)

	# Dormido: sigue tumbado salvo que haya motivo para despertar (amenaza
	# detectada, frio/calor letal, hambre/sed urgente o amanecer con el
	# deposito medio lleno). Los sentidos escalonados siguen refrescandose
	# arriba, asi un depredador o enemigo acercandose lo despierta.
	if bool(b.get("sleeping", false)):
		if _bot_should_wake(b, is_night):
			b["sleeping"] = false
			b["anim"] = "idle"
		else:
			b["anim"] = "sleep"
			b["sitting"] = false
			b["crouching"] = false
			proxy.set_meta("crouching", false)
			return

	# 1) Detectar amenazas inmediatas: lobos/osos hostiles cercanos
	var predator := _sensed_node(b, "_s_predator")
	if predator != null:
		b["_act"] = "predator"
		_handle_predator_encounter(b, predator, delta)
		return

	# 2) Doma de lobos: si hay un lobo salvaje cerca (10..22 m), tenemos carne cruda y aún no tenemos lobo domado
	if float(b["tame_cooldown"]) <= 0.0 and not bool(b.get("_s_has_wolf", false)):
		var wild_wolf := _sensed_node(b, "_s_tame_wolf")
		if wild_wolf != null and _bot_has_raw_meat(proxy):
			b["_act"] = "tame"
			_perform_wolf_taming_step(b, wild_wolf, delta)
			return

	# 2b) Emboscada: hostiles (solos o en equipo) acechan agachados a una
	#     victima con recursos y golpean a la vez. Cede ante depredadores.
	if _bot_try_ambush(b, delta):
		b["_act"] = "ambush"
		return

	# 3) Combate contra enemigos humanos / otros bots de facción opuesta
	var human_foe := _sensed_node(b, "_s_foe")
	if human_foe != null:
		b["_act"] = "foe"
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
		b["_act"] = "gut"
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
	b["drink_giveup"] = maxf(0.0, float(b.get("drink_giveup", 0.0)) - delta)
	var thirsty_line := 32.0 + (13.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0)
	if float(b["thirst"]) < thirsty_line and float(b.get("drink_giveup", 0.0)) <= 0.0 and not _bot_has_drink(proxy) and (leader == null or float(b["thirst"]) < 18.0):
		b["_act"] = "drink"
		if b["drink_at"] == Vector3.INF:
			b["drink_scan"] = float(b.get("drink_scan", 0.0)) - delta
			if float(b["drink_scan"]) <= 0.0:
				b["drink_at"] = _nearest_water_pos(proxy.global_position, b)
				if b["drink_at"] == Vector3.INF:
					b["drink_at"] = _known_water_pos(b) # fuente enseñada por chat/voz
				b["drink_walk_t"] = 0.0
				b["drink_scan"] = 0.0 if b["drink_at"] != Vector3.INF else (4.0 + fmod(float(int(b["bot_id"])) * 0.7, 1.5))
		if b["drink_at"] != Vector3.INF:
			var d_water := Vector2(proxy.global_position.x - b["drink_at"].x, proxy.global_position.z - b["drink_at"].z).length()
			# Con agua vadeable o ya en la orilla (_is_near_river <=3.2 m) basta
			# para beber: el nav detiene al bot a ~2.6 m del borde del agua y
			# exigir pisar el centro profundo causaba un deadlock eterno en idle.
			var feet_wet := false
			if world != null and world.has_method("get_river_depth_at"):
				feet_wet = float(world.get_river_depth_at(proxy.global_position)) > 0.05
			var at_shore: bool = d_water <= 4.5 or feet_wet or (world != null and world.has_method("_is_near_river") and bool(world._is_near_river(proxy.global_position, 3.2)))
			if not at_shore:
				b["drink_walk_t"] = float(b.get("drink_walk_t", 0.0)) + delta
				if float(b["drink_walk_t"]) > 12.0:
					var bw: Array = b.get("_bad_water", [])
					bw.append({"pos": b["drink_at"], "until": float(Time.get_ticks_msec()) / 1000.0 + 120.0})
					b["_bad_water"] = bw
					b["drink_at"] = Vector3.INF
					b["drink_walk_t"] = 0.0
					b["drink_giveup"] = 12.0
				else:
					_move_bot_towards(b, b["drink_at"], 4.6, delta, "run")
					return
			else:
				# En la orilla: se agacha a beber unos segundos y repone su sed
				b["drink_walk_t"] = 0.0
				b["drinking_timer"] = float(b["drinking_timer"]) + delta
				b["crouching"] = true
				b["sitting"] = false
				b["anim"] = "drink"
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
		# Sin agua localizable (drink_at == INF): NO parar al bot — sigue con
		# su vida (forrajeo, saqueo, explorar) y reintenta localizar agua en
		# el proximo escaneo de sed en ~4 s. Antes este return se ejecutaba
		# siempre y el bot quedaba congelado en idle para siempre.

	# 4b) Hambre sin comida comestible: forrajeo — setas (eat_food) y arboles
	# frutales (pick_fruit), lo mismo que buscaria un jugador hambriento.
	if _bot_try_forage(b, delta):
		b["_act"] = "forage"
		return

	# Inanicion desesperada (mismo umbral que starving_or_parched, l.1259):
	# un miembro de equipo muerto de hambre rompe la formacion para buscar
	# comida — seguir al lider no llena el estomago (_bot_try_forage ya hace
	# esta excepcion con su propio 'desperate', pero no llega a setas ni
	# frutales en mitad de la ciudad).
	var desperate_food: bool = float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, true)

	# 4c) Caza de presas (ciervos/zorros) y aprovechamiento de cadáveres cuando
	# falta comida o materiales animales (pieles, tendón para cuerda, hueso).
	if (leader == null or desperate_food) and _bot_try_hunt_or_scavenge(b, delta):
		b["_act"] = "hunt"
		return

	# 5) Si está reclutado en el equipo de un jugador, obedecer órdenes de equipo
	if leader != null and not desperate_food:
		b["_act"] = "team"
		_tick_teammate_behavior(b, leader, delta)
		return

	# 5) Saqueo oportuno de objetos cercanos (comida, armas, ropa mejor, materiales)
	var loot_action: Dictionary = b.get("_s_loot", {})
	if not loot_action.is_empty():
		b["_act"] = "loot"
		b["sitting"] = false
		b["crouching"] = false
		var lpos := _loot_entry_pos(loot_action)
		var d_loot := Vector2(proxy.global_position.x - lpos.x, proxy.global_position.z - lpos.z).length()
		if d_loot <= 2.1 and absf(proxy.global_position.y - lpos.y) <= 1.8:
			_collect_loot_entry(b, loot_action)
		else:
			_move_bot_towards(b, lpos, 4.4, delta, "run")
		return

	# 5a) Saqueo y desmontaje de refugios ajenos: roba lo util y si el refugio
	# le sirve como material lo desmonta (3 s) para llevarse los 11 palos.
	var salv: Dictionary = b.get("_salvage", {})
	if not salv.is_empty():
		b["_act"] = "salvage"
		b["sitting"] = false
		b["crouching"] = true
		b["anim"] = "forage"
		salv["t"] = float(salv.get("t", 0.0)) + delta
		b["_salvage"] = salv
		if float(salv["t"]) >= 3.0:
			b["_salvage"] = {}
			b["_s_raid_shelter"] = {}
			_bot_dismantle_shelter_exec(b, str(salv.get("id", "")))
		return
	var raid_sh: Dictionary = b.get("_s_raid_shelter", {})
	if not raid_sh.is_empty():
		b["_act"] = "raid_shelter"
		b["sitting"] = false
		b["crouching"] = false
		var rpos := _shelter_entry_pos(raid_sh)
		var d_raid := Vector2(proxy.global_position.x - rpos.x, proxy.global_position.z - rpos.z).length()
		if d_raid <= 2.4:
			_bot_raid_shelter(b, raid_sh)
			if not _bot_try_dismantle_shelter(b, raid_sh):
				b["_s_raid_shelter"] = {}
		else:
			_move_bot_towards(b, rpos, 4.4, delta, "run")
		return

	# 5b) Materiales de campamento: si faltan palos para el refugio/fogata y no
	# hay drops a mano, el bot tala arbustos (fell_bush) igual que un jugador —
	# filo en mano, 5 s de corte, 3 palos y semillas al suelo.
	if _bot_try_gather_mats(b, delta):
		b["_act"] = "mats"
		return

	# 6) Hacer hoguera y cocinar carne cruda o pescado crudo ensartado en Palo
	# afilado, igual que un jugador humano: NO hace falta tener refugio para
	# crear una hoguera cuando lleva carne o pescado para asar.
	if _bot_try_cook_meat(b, delta):
		b["_act"] = "cook"
		return

	# 6a-bis) Huerto: cosecha madura que se pudre, limpia bancales, replanta,
	# riega de paso y siembra bancales nuevos con azada/pala + semillas —
	# la fuente de comida renovable de un superviviente asentado.
	if _bot_try_farm(b, delta):
		b["_act"] = "farm"
		return

	# 6b) Construir refugio propio si ya reunio los materiales
	if str(b["shelter_id"]).is_empty() and _can_bot_build_shelter(proxy):
		b["_act"] = "build"
		var d_camp := Vector2(proxy.global_position.x - camp_pos.x, proxy.global_position.z - camp_pos.z).length()
		if d_camp > 2.4:
			_move_bot_towards(b, camp_pos, 3.8, delta, "walk")
			return
		_bot_build_shelter(b, camp_pos)
		return

	if not str(b["shelter_id"]).is_empty() and str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)) and _can_bot_build_campfire(proxy):
		b["_act"] = "campfire"
		var fire_spot := _find_nearby_campfire_spot(b, sh_pos)
		if fire_spot != Vector3.INF:
			_bot_build_and_light_campfire(b, fire_spot)
		else:
			b["no_fire_spot"] = true
		return

	# De noche o con poca salud o emboscando (bandido), el superviviente vuelve a su refugio
	# (o a la casa/fogata segura mas cercana si aun no construyo el suyo), cocina y descansa.
	# Excepcion vital: si se esta muriendo de hambre o sed (<26) y no se esta
	# escondiendo de un ataque, sentarse a "descansar" es suicidio — debe seguir
	# buscando comida/agua fuera.
	var starving_or_parched: bool = (float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, true)) or (float(b["thirst"]) < 22.0 and not _bot_has_drink(proxy))
	# 6a) Alijo en su propio refugio: si ya está junto a su refugio sincroniza
	# (retira lo que necesite y guarda el sobrante); si necesita comida/agua/arma
	# que tiene guardada allí o acumula >=3 objetos sobrantes, vuelve a su
	# refugio para gestionar el alijo como un jugador humano.
	if sh_pos != Vector3.INF and not str(b["shelter_id"]).is_empty():
		var d_own_sh := Vector2(proxy.global_position.x - sh_pos.x, proxy.global_position.z - sh_pos.z).length()
		if d_own_sh <= 2.6:
			_bot_sync_own_shelter_stash(b)
		var needs_from_stash := _own_shelter_has_needed_item(b) and d_own_sh < 110.0
		var storable_n := _bot_count_storable_items(b)
		var wants_stash_run := needs_from_stash or (not starving_or_parched and (storable_n >= 3 or (storable_n >= 1 and d_own_sh < 24.0)))
		if wants_stash_run and d_own_sh > 2.4:
			b["_act"] = "stash"
			b["sitting"] = false
			b["crouching"] = false
			_move_bot_towards(b, sh_pos, 4.2, delta, "run" if d_own_sh > 12.0 else "walk")
			return
	# Helándose: si no hay fuego encendido al alcance, arma una hoguera aquí
	# mismo antes de seguir — igual que haría un jugador humano.
	if _bot_is_freezing(b) and not _is_near_any_lit_campfire(proxy.global_position, 8.0) and _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2:
		_bot_build_and_light_campfire(b, proxy.global_position + Vector3(0.9, 0.0, 0.9))
	var wants_camp: bool = float(b["hide_timer"]) > 0.0 or (not starving_or_parched and (is_night or float(b["health"]) < 65.0 or _bot_is_freezing(b) or _bot_is_exhausted(b)))
	# Con frio o agotamiento extremo busca refugio/fuego bastante mas lejos que
	# el radio normal: sobrevivir pesa mas que la comodidad.
	var refuge_radius := 85.0
	if _bot_is_freezing(b) or _bot_is_exhausted(b):
		refuge_radius = 220.0
	var rest_pos: Vector3 = sh_pos if sh_pos != Vector3.INF else _nearest_safe_refuge(b, refuge_radius)
	if rest_pos != Vector3.INF and wants_camp:
		b["_act"] = "rest"
		b["hide_timer"] = maxf(0.0, float(b["hide_timer"]) - delta)
		var d_sh := Vector2(proxy.global_position.x - rest_pos.x, proxy.global_position.z - rest_pos.z).length()
		if d_sh > 1.8:
			_move_bot_towards(b, rest_pos, 3.8, delta, "walk")
			return
		# Dentro del refugio: encender fogata si se apagó, asar carne (solo si tiene Palo afilado / Carne ensartada) y descansar/ocultarse
		if sh_pos != Vector3.INF:
			_ensure_bot_campfire_lit(b)
		if float(b["cook_cooldown"]) <= 0.0 and _bot_can_cook_raw_meat(proxy) and (sh_pos != Vector3.INF or _is_near_any_lit_campfire(proxy.global_position, 6.0)):
			_bot_cook_meat_at_fire(b)
		# Solo craftea en el refugio si esta sano y no se esta ocultando de una
		# amenaza: herido o escondido descansa/aguanta, no se pone a tallar.
		# (De noche la Antorcha puntua alto aqui: la fabrica antes de dormir.)
		if float(b["health"]) >= 70.0 and float(b["hide_timer"]) <= 0.0 and _bot_try_craft(b, delta):
			return
		# Dormir de noche igual que un jugador humano: se tumba, recupera
		# sueño/energia/salud y despierta al amanecer, con frio o calor letal,
		# hambre/sed urgente, o al oir/sufrir una amenaza.
		if _bot_try_start_sleep(b, is_night):
			return
		b["sitting"] = true
		b["crouching"] = str(b["faction"]) == "hostile"
		proxy.set_meta("crouching", bool(b["crouching"]))
		b["anim"] = "sit"
		if float(b["health"]) < 100.0 and float(b.get("sick_timer", 0.0)) <= 0.0:
			var healed := minf(100.0, float(b["health"]) + delta * 1.8)
			b["health"] = healed
			proxy.set_meta("proxy_health", healed)
			proxy.set_meta("saved_health", healed)
		return

	# 6b) Crafteo: sin urgencias, fabrica con los mismos RECIPES que un jugador
	# (herramientas, armas, flechas, cuerda, ropa de piel, antorcha, comida...)
	if _bot_try_craft(b, delta):
		b["_act"] = "craft"
		return

	# 7) Exploracion como un jugador real: viaja por puntos de interes (casas,
	# tiendas militares, ciudad, graneros, zonas salvajes) recordando los ya
	# visitados entre vidas, y evitando la zona donde murio la ultima vez.
	b["_act"] = "explore"
	b["sitting"] = false
	b["crouching"] = false
	b["caution_until"] = maxf(0.0, float(b.get("caution_until", 0.0)) - delta)
	# Subida/bajada por escaleras siguiendo una ruta de peldaños (torres, pisos)
	if (b.get("climb_route", []) as Array).size() >= 2:
		_tick_bot_climb(b, delta)
		return
	var cur_target: Vector3 = b.get("explore_target", Vector3.INF)
	var flat_t := 9999.0
	var dy_t := 0.0
	if cur_target != Vector3.INF:
		flat_t = Vector2(proxy.global_position.x - cur_target.x, proxy.global_position.z - cur_target.z).length()
		dy_t = absf(proxy.global_position.y - cur_target.y)
	if cur_target != Vector3.INF and flat_t < 4.0 and (cur_target.y < 1.8 or dy_t < 1.9):
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
		b["_act"] = "dwell"
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
			var b_pos: Vector3 = CityExpansion.CENTER + (definition["position"] as Vector3)
			var b_yaw: float = float(definition.get("yaw", 0.0))
			_poi_cache.append({"pos": b_pos + Vector3(-0.6, 0.12, 1.2).rotated(Vector3.UP, b_yaw), "kind": "city"})
			if int(definition.get("floors", 2)) > 2:
				# Bloque de 4 plantas (city_17): plantas superiores hasta la cima (11.82 m)
				_poi_cache.append({"pos": b_pos + Vector3(1.2, 4.02, -2.2).rotated(Vector3.UP, b_yaw), "kind": "city"})
				_poi_cache.append({"pos": b_pos + Vector3(1.2, 7.92, -2.2).rotated(Vector3.UP, b_yaw), "kind": "city"})
				_poi_cache.append({"pos": b_pos + Vector3(1.2, 11.82, -2.2).rotated(Vector3.UP, b_yaw), "kind": "city"})
			else:
				# Viviendas de 2 plantas: planta superior (3.92 m) subiendo escaleras
				_poi_cache.append({"pos": b_pos + Vector3(-1.2, 3.92, -2.6).rotated(Vector3.UP, b_yaw), "kind": "city"})
	# Torre del Reloj de la ciudad (41, 0, 750): vestíbulo, plantas intermedias y azotea (29.46 m)
	_poi_cache.append({"pos": Vector3(41.0, 0.06, 745.0), "kind": "city"})
	_poi_cache.append({"pos": Vector3(39.0, 12.66, 750.0), "kind": "tower"})
	_poi_cache.append({"pos": Vector3(39.6, 29.46, 750.8), "kind": "tower"})
	var zones = world.get("_spawn_zones")
	if zones is Array:
		for z in zones:
			if z is Vector3:
				_poi_cache.append({"pos": z, "kind": "wild"})
	# Zona del Lago (NE) y perímetro exterior del mapa para que los bots
	# exploren los cuatro cuadrantes completos, no solo el anillo ±200 m.
	for ext_p in [
		Vector3(162.0, 0.4, -307.0), # Orilla oeste del lago / embarcadero
		Vector3(250.0, 0.4, -368.0), # Orilla norte del lago
		Vector3(342.0, 0.4, -307.0), # Orilla este del lago
		Vector3(215.0, 0.4, -225.0), # Bosque sur del lago
		Vector3(-252.0, 0.8, -268.0), # Pie de la carretera de montaña (NW)
		Vector3(-150.0, 0.4, -330.0), # Valle norte
		Vector3(40.0, 0.4, -330.0), # Valle noreste
		Vector3(-330.0, 0.4, -90.0), # Bosque oeste
		Vector3(-330.0, 0.4, 150.0), # Bosque suroeste
		Vector3(330.0, 0.4, 160.0), # Bosque sureste
		Vector3(220.0, 0.4, 320.0), # Llanura sureste
		Vector3(-200.0, 0.4, 330.0), # Llanura suroeste
	]:
		_poi_cache.append({"pos": ext_p, "kind": "wild"})
	# Base Militar de la Cima (HighMountainZone, cota +56 m): accesible por la
	# carretera asfaltada en espiral (MOUNTAIN_ROAD_WAYPOINTS_3D).
	var hm_origin := Vector3(HighMountainZone.SUMMIT_CENTER.x, HighMountainZone.SUMMIT_HEIGHT, HighMountainZone.SUMMIT_CENTER.y)
	var hm_yaw := deg_to_rad(HighMountainZone.BASE_YAW_DEG)
	_poi_cache.append({"pos": hm_origin + HighMountainZone.TENT_A_OFFSET.rotated(Vector3.UP, hm_yaw), "kind": "military"})
	_poi_cache.append({"pos": hm_origin + HighMountainZone.TENT_B_OFFSET.rotated(Vector3.UP, hm_yaw), "kind": "military"})
	_poi_cache.append({"pos": hm_origin + (HighMountainZone.COMMS_TOWER_OFFSET + Vector3(-6.8, 0.0, 3.4)).rotated(Vector3.UP, hm_yaw), "kind": "military"})
	# La torre militar es un POI con altura: la ruta en caracol de sus
	# escaleras la guarda el mundo en _watchtower_climb.
	var wtc = world.get("_watchtower_climb")
	if wtc is Array and wtc.size() >= 2:
		_poi_cache.append({"pos": (wtc as Array).back(), "kind": "tower", "route": wtc})
	_poi_cache_built = true
	return _poi_cache

func _poi_id(p: Dictionary) -> String:
	var pp: Vector3 = p["pos"]
	if pp.y >= 2.2:
		return "%s:%d:%d:%d" % [str(p.get("kind", "?")), int(pp.x), int(pp.y), int(pp.z)]
	return "%s:%d:%d" % [str(p.get("kind", "?")), int(pp.x), int(pp.z)]

func _mark_poi_visited(b: Dictionary, pos: Vector3) -> void:
	var mem: Dictionary = b.get("_mem", {})
	var visited: Array = mem.get("visited", [])
	var bid := int(b.get("bot_id", 0))
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		if Vector2(pos.x - pp.x, pos.z - pp.z).length() < 12.0 and (pp.y < 2.2 or absf(pos.y - pp.y) < 2.4):
			var id := _poi_id(p)
			if not visited.has(id):
				visited.append(id)
			observe_location(bid, id, str(p.get("kind", "wild")), pp, "observed", true)
			record_strategy_outcome(bid, "explore_" + str(p.get("kind", "wild")), true, 0.04)
	mem["visited"] = visited
	b["_visited"] = visited

# Direccion preferente de exploracion de cada bot: angulo aureo separa los
# sectores ~222 grados entre ellos al inicio y rota cada 2 POIs visitados para
# barrer los 360 grados del mapa (Lago NE, Base Cima NW, Ciudad S, Granero SW).
func _bot_explore_sector(b: Dictionary) -> float:
	var bid := int(b.get("bot_id", 0))
	var visited: Array = b.get("_mem", {}).get("visited", [])
	var step := int(visited.size() / 2)
	return TAU * fposmod(float(bid) * 0.618034 + float(step) * 0.381966, 1.0)

func _is_pos_already_visited(b: Dictionary, pos: Vector3) -> bool:
	var visited: Array = b.get("_mem", {}).get("visited", [])
	if visited.is_empty():
		return false
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		if Vector2(pos.x - pp.x, pos.z - pp.z).length() < 14.0:
			if visited.has(_poi_id(p)):
				return true
	return false

func _is_water_blacklisted(b: Dictionary, pos: Vector3) -> bool:
	var bl: Array = b.get("_bad_water", [])
	if bl.is_empty():
		return false
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	for entry in bl:
		if entry is Dictionary and float(entry.get("until", 0.0)) > now_s:
			var bp = entry.get("pos")
			if bp is Vector3 and Vector2(pos.x - (bp as Vector3).x, pos.z - (bp as Vector3).z).length() < 12.0:
				return true
	return false

# Lista negra temporal de destinos inalcanzables para que un bot que se rinde
# ante un rio/obstaculo no vuelva a elegir el mismo POI en el frame siguiente.
func _is_goal_blacklisted(b: Dictionary, pos: Vector3) -> bool:
	var bl: Array = b.get("_unreachable", [])
	if bl.is_empty():
		return false
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	for entry in bl:
		if entry is Dictionary and float(entry.get("until", 0.0)) > now_s:
			var bp = entry.get("pos")
			if bp is Vector3 and Vector2(pos.x - (bp as Vector3).x, pos.z - (bp as Vector3).z).length() < 18.0:
				return true
	return false

func _abandon_unreachable_goal(b: Dictionary, goal: Vector3) -> void:
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var bl: Array = b.get("_unreachable", [])
	var kept: Array = []
	for entry in bl:
		if entry is Dictionary and float(entry.get("until", 0.0)) > now_s:
			kept.append(entry)
	if goal != Vector3.INF:
		kept.append({"pos": goal, "until": now_s + 240.0})
		_mark_poi_visited(b, goal)
	var et: Vector3 = b.get("explore_target", Vector3.INF)
	if et != Vector3.INF:
		kept.append({"pos": et, "until": now_s + 240.0})
		_mark_poi_visited(b, et)
		b["explore_target"] = Vector3.INF
		b["explore_dwell"] = 0.0
	var sl: Dictionary = b.get("_s_loot", {})
	if not sl.is_empty():
		var sl_pos := _loot_entry_pos(sl)
		kept.append({"pos": sl_pos, "until": now_s + 240.0})
		b["_s_loot"] = {}
	b["_unreachable"] = kept
	b["path"] = []
	b["path_timer"] = 0.0
	b["climb_route"] = []
	var d0: Dictionary = b.get("_ai_directive", {})
	if not d0.is_empty() and str(d0.get("mode", "")) == "pos":
		b["_ai_directive"] = {}
	if str(b.get("_act", "")) == "drink" and b.get("drink_at", Vector3.INF) != Vector3.INF and Vector2(goal.x - b["drink_at"].x, goal.z - b["drink_at"].z).length() < 6.0:
		b["drink_at"] = Vector3.INF
		b["drink_giveup"] = 12.0
	if not (b.get("_forage", {}) as Dictionary).is_empty():
		b["_forage"] = {}
	var pat: Array = b.get("patrol", [])
	if not pat.is_empty():
		b["patrol_idx"] = (int(b["patrol_idx"]) + 1) % pat.size()

# Elige el siguiente destino de exploracion como haria un jugador: prefiere
# sitios no visitados, acordes a su personalidad y rol, cercanos, y nunca el
# lugar donde murio la ultima vez.
func _choose_explore_target(b: Dictionary) -> Vector3:
	# Directiva del asesor externo (si existe y no ha caducado): puede forzar un
	# destino concreto (volver a casa/descansar/conocido) o filtrar tipos de POI.
	var directive := _ai_active_directive(b)
	if not directive.is_empty() and str(directive.get("mode", "")) == "pos":
		var dp = directive.get("pos")
		var d_act := str(directive.get("action", ""))
		# No permitir que una directiva explore/scavenge/hunt de Qwen basada en
		# known_locations devuelva al bot a un POI que ya visito: eso los
		# encerraba en el pueblo en vez de salir al Lago, Base Cima o Ciudad.
		var skip_visited_dp: bool = d_act in ["explore", "scavenge", "hunt"] and dp is Vector3 and _is_pos_already_visited(b, dp)
		if dp is Vector3 and (dp as Vector3) != Vector3.INF and not _is_goal_blacklisted(b, dp) and not skip_visited_dp:
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
	# El hambre empuja hacia el monte: ahi estan la caza, las setas y la fruta,
	# no en las ruinas que ya se saquearon.
	var need_food := clampf((75.0 - float(b.get("hunger", 80.0))) / 55.0, 0.0, 1.0)
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
			if _is_goal_blacklisted(b, pp):
				continue
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
				w = (2.4 + aggro_t * 0.8) if kind == "tower" else ((1.8 + bravery * 0.6) if kind in ["military", "city"] else (0.6 + need_food * 0.9))
			else:
				if kind == "tower":
					w = 0.25 + bravery * 0.45
				elif kind == "military":
					w = 1.1 + bravery * 0.75
				elif kind == "house":
					w = 1.3 + surv_t * 0.45
				elif kind == "city":
					w = 1.25 + curiosity * 0.45
				elif kind == "wild":
					# Paridad con casa/ciudad: el bosque es un destino real, no
					# el ultimo recurso — y con hambre gana a cualquier ruina.
					w = 1.2 + curiosity * 0.55 + need_food * 0.85
				else:
					w = 0.85 + curiosity * 0.35
			# Si ya conoce la ubicación por observación o comunicación aliada, tiene bono de certeza
			if known.has(pid):
				w *= 1.12
			var d := Vector2(proxy.global_position.x - pp.x, proxy.global_position.z - pp.z).length()
			var score := w * 100.0 - minf(d, 220.0) * 0.25 + rng.randf_range(0.0, 30.0)
			# Bono de expedicion a regiones exteriores (Lago NE, Base Cima NW,
			# Granero remoto SW, Ciudad S, campamentos militares) tras el primer
			# saqueo local, para que recorran todo el mapa.
			if visited.size() >= 1 and Vector2(pp.x, pp.z).length() > 190.0:
				score += (55.0 + curiosity * 45.0)
			# Dispersion territorial: cada bot tiene un sector de exploracion
			# propio (determinista por bot_id) desde su campamento — asi los tres
			# no orbitan el mismo pueblo. La curiosidad tira hacia POIs lejanos.
			var base: Vector3 = b.get("camp_spot", proxy.global_position)
			if base == Vector3.INF:
				base = proxy.global_position
			var away := Vector2(pp.x - base.x, pp.z - base.z)
			if away.length() > 30.0:
				var sector := _bot_explore_sector(b)
				var diff := absf(wrapf(away.angle() - sector, -PI, PI))
				score += (1.0 - diff / PI) * (55.0 + curiosity * 65.0)
				score += curiosity * minf(d, 380.0) * 0.38
			# Anti-cluster: si otro bot ya esta en esa zona o va hacia ella
			# (<110 m, tamano de todo el pueblo), los demas se reparten fuera.
			for ob in bots.values():
				if ob == b:
					continue
				var ot: Vector3 = ob.get("explore_target", Vector3.INF)
				var op: Vector3 = ob.get("pos", Vector3.INF)
				if (ot != Vector3.INF and Vector2(ot.x - pp.x, ot.z - pp.z).length() < 110.0) or (op != Vector3.INF and Vector2(op.x - pp.x, op.z - pp.z).length() < 110.0):
					score -= 180.0
			score *= _ai_poi_memory_factor(b, pp, kind)
			if score > best_score:
				best_score = score
				best = pp
				best_p = p
		if best != Vector3.INF:
			if pass_i == 1:
				visited.clear()
				mem["visited"] = visited
			break
	if str(best_p.get("kind", "")) == "tower" and best_p.get("route") is Array:
		b["climb_route"] = best_p["route"]
		b["climb_i"] = -1
		b["climb_down"] = false
		b["climb_dwell"] = 0.0
	return best

func _maintain_bot_needs(b: Dictionary, _delta: float) -> void:
	b["consume_anim_t"] = maxf(0.0, float(b.get("consume_anim_t", 0.0)) - _delta)
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
			if (nm.begins_with("Carne cruda") or nm == "Carne ensartada" or nm == "Pez ensartado") and not desperate:
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
			elif nm.begins_with("Carne cruda") or nm == "Carne ensartada" or nm == "Pez ensartado":
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
			# Carne cruda = intoxicacion como en el jugador (get_sick 60s:
			# primera vez reduce hambre/sed/salud a la mitad, sin regen pasiva)
			if nm.begins_with("Carne cruda") or nm == "Carne ensartada" or nm == "Pez ensartado":
				if float(b.get("sick_timer", 0.0)) <= 0.0:
					b["hunger"] = float(b["hunger"]) * 0.5
					b["thirst"] = float(b["thirst"]) * 0.5
					b["health"] = float(b["health"]) * 0.5
				b["sick_timer"] = maxf(float(b.get("sick_timer", 0.0)), 60.0)
			var new_hp := minf(100.0, float(b["health"]))
			proxy.set_meta("proxy_health", new_hp)
			proxy.set_meta("saved_health", new_hp)
			proxy.set_meta("saved_inventory", inv)
			b["eat_cooldown"] = 10.0
			b["consume_anim"] = "eat"
			b["consume_anim_t"] = 1.6
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
			b["consume_anim"] = "drink"
			b["consume_anim_t"] = 1.6
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
		# La mochila equipada sale del inventario (como al ponérsela un jugador)
		# y la vieja vuelve a la mochila como repuesto guardable en su refugio.
		if tp == "backpack" and _backpack_tier(nm) > _backpack_tier(str(b["backpack"])):
			var old_bp := str(b["backpack"])
			b["backpack"] = nm
			proxy.set_meta("saved_backpack", nm)
			it["quantity"] = int(it.get("quantity", 1)) - 1
			if int(it["quantity"]) <= 0:
				to_remove.append(it)
			if not old_bp.is_empty():
				_bot_add_inventory_item(inv, {"name": old_bp, "type": "backpack", "weight": 0.9, "quantity": 1, "use_value": 0.0})
		elif tp == "clothing" and PlayerController.CLOTHING_SLOTS.has(nm):
			var slot := str(PlayerController.CLOTHING_SLOTS[nm])
			var cur := _worn_in_slot(worn, slot)
			if int(CLOTHING_PRIORITY.get(nm, 0)) > int(CLOTHING_PRIORITY.get(cur, 0)):
				worn = _swap_worn_slot(worn, slot, nm)
				if not cur.is_empty():
					var old_piece := {"name": cur, "type": "clothing", "weight": 0.6, "quantity": 1, "use_value": 0.0}
					if not _bot_try_add_inventory_item(b, inv, old_piece):
						_bot_drop_to_ground(b, old_piece) # no le cabe: la vieja queda tirada
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
		var meat := {"name": meat_name, "type": "food", "weight": 0.3, "quantity": meat_qty, "use_value": 15.0}
		if not _bot_try_add_inventory_item(b, inv, meat):
			_bot_drop_to_ground(b, meat) # no le cabe: queda junto a la presa
	if take_pelts:
		var hide := {"name": hide_name, "type": "resource", "weight": 0.65, "quantity": hide_qty, "use_value": 0.0}
		if not _bot_try_add_inventory_item(b, inv, hide):
			_bot_drop_to_ground(b, hide)
	# Hueso y tendón: solo si los necesita ahora para cuerda, refugio, arco o armas de hueso
	if _bot_item_count(proxy, "Tendón") < 4 and (_bot_wants_craft_input(b, "Tendón") or _bot_wants_craft_input(b, "Cuerda") or (str(b["shelter_id"]).is_empty() and _bot_item_count(proxy, "Cuerda") < 1)):
		var tendon := {"name": "Tendón", "type": "resource", "weight": 0.06, "quantity": part_qty, "use_value": 0.0}
		if not _bot_try_add_inventory_item(b, inv, tendon):
			_bot_drop_to_ground(b, tendon)
	if _bot_item_count(proxy, "Hueso") < 4 and _bot_wants_craft_input(b, "Hueso"):
		var bone := {"name": "Hueso", "type": "resource", "weight": 0.18, "quantity": part_qty, "use_value": 0.0}
		if not _bot_try_add_inventory_item(b, inv, bone):
			_bot_drop_to_ground(b, bone)
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
		_evolve_personality(b, "kill_threat", 0.45)
	else:
		ck_st["kills_prey"] = int(ck_st.get("kills_prey", 0)) + 1
		_evolve_personality(b, "hunt_success", 0.30)
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

# Percepcion auditiva entre bots y jugadores: disparos (220 m), esprints/tala
# (34-55 m), puertas (30 m) y pasos normales (16 m) se oyen aunque haya muros
# o arboles interpuestos.
func _can_bot_hear_actor(b: Dictionary, target: Node3D, dist: float) -> bool:
	var is_sprint: bool = bool(target.get_meta("sprinting", false)) or str(target.get("_puppet_anim")).to_lower().find("run") >= 0 or target.get("is_sprinting") == true
	if is_sprint and dist <= 34.0:
		return true
	var is_crouch: bool = (target.get("is_crouching") == true) or bool(target.get_meta("crouching", false))
	var is_prone: bool = (target.get("is_prone") == true) or bool(target.get_meta("prone", false))
	var is_moving: bool = bool(target.get_meta("moving", false)) or target.get("is_moving") == true or str(target.get("_puppet_anim")).to_lower().find("walk") >= 0
	if is_moving and not is_crouch and not is_prone and dist <= 16.0:
		return true
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	if float(b.get("last_heard_until", 0.0)) > now_s:
		var hpos: Vector3 = b.get("last_heard_pos", Vector3.INF)
		if hpos != Vector3.INF and target.global_position.distance_to(hpos) <= 18.0:
			return true
	return false

func notify_sound_event(actor_id: int, sound_pos: Vector3, kind: String, radius: float = 120.0) -> void:
	if world == null:
		return
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var actor_node := _find_actor_by_peer_id(actor_id) if actor_id > 0 else null
	for bid in bots.keys():
		if int(bid) == actor_id:
			continue
		var b: Dictionary = bots[bid]
		var proxy: Node3D = b.get("proxy")
		if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
			continue
		var d := proxy.global_position.distance_to(sound_pos)
		if d > radius:
			continue
		b["last_heard_pos"] = sound_pos
		b["last_heard_kind"] = kind
		b["last_heard_actor"] = actor_id
		b["last_heard_until"] = now_s + (18.0 if kind == "gunshot" else 9.0)
		b["caution_until"] = maxf(float(b.get("caution_until", 0.0)), 14.0 if kind == "gunshot" else 7.0)
		# Un ruido real lo despierta: sale del sueño como un jugador humano.
		if bool(b.get("sleeping", false)):
			b["sleeping"] = false
			b["anim"] = "idle"
		record_bot_event(int(bid), "heard_" + kind, "actor_%d" % actor_id, _poi_kind_near(sound_pos), sound_pos, "%s:%.0fm" % [kind, d])
		if kind == "gunshot":
			var my_faction := str(b.get("faction", "friendly"))
			var shooter_hostile := (actor_id == 903) or (my_faction == "hostile" and actor_id != 903)
			if not shooter_hostile and actor_id > 0:
				var rel := get_bot_relationship(int(bid), _actor_persist_key(actor_id))
				shooter_hostile = float(rel.get("hostility", 0.0)) > 0.25
			var has_gun := _best_weapon_name(proxy) in ["Fusil de asalto", "Rifle francotirador"]
			var pers := _get_bot_personality(b)
			var brave := float(pers.get("bravery", 0.5))
			if shooter_hostile:
				if (has_gun or (my_faction == "hostile" and brave >= 0.45)) and float(b.get("health", 100.0)) >= 55.0:
					if actor_node != null and is_instance_valid(actor_node) and d <= 130.0:
						b["aggro_target"] = actor_node
						b["aggro_timer"] = 14.0
					elif b.get("explore_target", Vector3.INF) == Vector3.INF or d <= 140.0:
						b["explore_target"] = sound_pos
				elif d <= 95.0:
					b["flee_until"] = maxf(float(b.get("flee_until", 0.0)), 10.0)
					record_zone_hazard(int(bid), sound_pos, "gunshot", 0.30)

func _find_combat_foe(b: Dictionary) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var aggro: Node3D = b.get("aggro_target")
	if aggro != null and is_instance_valid(aggro) and not bool(aggro.get_meta("proxy_dead", false)) and aggro.get("is_dead") != true:
		if proxy.global_position.distance_to(aggro.global_position) < 130.0:
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
			var heard := _can_bot_hear_actor(b, p3, proxy.global_position.distance_to(p3.global_position))
			var max_r := minf(best_d, maxf(34.0 if heard else 0.0, _effective_human_sight(p3, sight)))
			var d := proxy.global_position.distance_to(p3.global_position)
			if d < max_r and (d <= 10.0 or heard or _has_clear_shot(proxy.global_position, p3.global_position)):
				best_d = d
				best = p3
		var local_p = world.get("player")
		if local_p is Node3D and is_instance_valid(local_p) and local_p.get("is_dead") != true:
			var lp3 := local_p as Node3D
			var heard_l := _can_bot_hear_actor(b, lp3, proxy.global_position.distance_to(lp3.global_position))
			var max_rl := minf(best_d, maxf(34.0 if heard_l else 0.0, _effective_human_sight(lp3, sight)))
			var dl := proxy.global_position.distance_to(lp3.global_position)
			if dl < max_rl and (dl <= 10.0 or heard_l or _has_clear_shot(proxy.global_position, lp3.global_position)):
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
			var d := proxy.global_position.distance_to(op.global_position)
			var dl := leader.global_position.distance_to(op.global_position) if leader != null else 9999.0
			var eff_d := minf(d, dl)
			var heard_o := _can_bot_hear_actor(b, op, eff_d)
			var max_ro := minf(best_d, maxf(34.0 if heard_o else 0.0, _effective_human_sight(op, sight)))
			if eff_d < max_ro and (eff_d <= 10.0 or heard_o or _has_clear_shot(proxy.global_position, op.global_position)):
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
	if death_kind in ["starved", "dehydrated", "hypothermia", "exhausted"]:
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
	var old_stats = b.get("vstats")
	if old_stats != null and is_instance_valid(old_stats):
		old_stats.free()
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
	b["climb_route"] = []

	# Si el líder está bajo ataque de otro jugador/bot o depredador, asistirle
	if mode == "stay":
		b["sitting"] = true
		b["crouching"] = false
		b["anim"] = "sit"
		return

	b["sitting"] = false
	b["crouching"] = bool(leader.get("is_crouching") == true or leader.get_meta("crouching", false) == true)
	var lpos := leader.global_position
	var cur := proxy.global_position
	var dist := cur.distance_to(lpos)
	var step_wp := _resolve_building_interior_waypoint(b, cur, lpos)
	var separated_by_structure: bool = step_wp != lpos or absf(cur.y - lpos.y) > 1.3
	if dist > 3.2 or separated_by_structure:
		var spd := 5.2 if (dist > 8.5 and not bool(b["crouching"])) else 3.8
		var clip := "run" if (dist > 8.5 and not bool(b["crouching"])) else "walk"
		_move_bot_towards(b, lpos, spd, delta, clip)
	else:
		# Cerca del líder en la misma planta: si hay un botín útil muy a mano (< 8 m), recogerlo
		var nearby_loot := _find_nearby_valuable_loot(b, 7.5)
		if not nearby_loot.is_empty():
			var lp := _loot_entry_pos(nearby_loot)
			if Vector2(cur.x - lp.x, cur.z - lp.z).length() <= 2.1 and absf(cur.y - lp.y) <= 1.8:
				_collect_loot_entry(b, nearby_loot)
			else:
				_move_bot_towards(b, lp, 3.6, delta, "walk")
		else:
			b["anim"] = "idle"

# --- Equipos bot-bot autonomos y emboscadas coordinadas ---------------------
# Los bots exploran la colaboracion como estrategia: quienes se cruzan y
# conviven sin agresiones acumulan confianza hasta formar equipo (lider/
# miembros segun valentia+cooperacion). El equipo se rompe por muerte del
# lider, traicion o alejamiento. Los hostiles usan el mismo mecanismo para
# coordinar emboscadas contra bots o humanos que cargan recursos.
const BOT_TEAM_FORM_TRUST := 0.30
const BOT_TEAM_BREAK_TRUST := 0.08
const BOT_TEAM_MAX_SIZE := 3
const BOT_TEAM_FORM_DIST := 26.0
const BOT_TEAM_GIVE_UP_DIST := 160.0
# Radio del "iman social": dentro de el un bot libre y sociable viaja a
# reunirse con un aliado potencial en vez de dejar el encuentro al azar.
const BOT_TEAM_MEET_DIST := 450.0
const BOT_AMBUSH_STRIKE_RANGED := 12.5
const BOT_AMBUSH_STRIKE_MELEE := 6.0
const BOT_AMBUSH_ABORT_DIST := 90.0
const BOT_AMBUSH_MAX_SECONDS := 24.0

func _bot_lead_score(b: Dictionary) -> float:
	var pers: Dictionary = _ensure_bot_memory(int(b["bot_id"])).get("personality", {})
	return float(pers.get("bravery", 0.5)) + float(pers.get("cooperation", 0.5))

func _bot_team_size(leader_id: int) -> int:
	var n := 1
	for bid in bots.keys():
		if bid != leader_id and int(bots[bid].get("team_leader_id", 0)) == leader_id:
			n += 1
	return n

func _bot_team_ids(b: Dictionary) -> Array:
	var my_id := int(b["bot_id"])
	var lid := int(b.get("team_leader_id", 0))
	var leader := lid if lid > 0 else my_id
	var ids: Array = []
	if bots.has(leader):
		ids.append(leader)
	for bid in bots.keys():
		if bid != leader and int(bots[bid].get("team_leader_id", 0)) == leader:
			ids.append(bid)
	return ids

func _bot_team_role(b: Dictionary) -> String:
	var lid := int(b.get("team_leader_id", 0))
	if lid > 0:
		return "member"
	for bid in bots.keys():
		if int(bots[bid].get("team_leader_id", 0)) == int(b["bot_id"]):
			return "leader"
	return ""

# ¿Quiere este bot compañia? Los sociables/cooperativos viajan a reunirse con
# un aliado potencial; un vinculo previo (confianza o ayudas) siempre tira.
# Los bandidos se juntan por agresividad — una banda nace para dar el golpe.
func _bot_wants_company(b: Dictionary, rel: Dictionary) -> bool:
	if float(rel.get("trust", 0.0)) >= BOT_TEAM_FORM_TRUST or int(rel.get("helped", 0)) >= 2:
		return true
	var pers := _get_bot_personality(b)
	if str(b.get("faction", "")) == "hostile":
		return float(pers.get("aggression", 0.5)) + float(pers.get("sociability", 0.5)) >= 0.7
	return float(pers.get("sociability", 0.5)) + float(pers.get("cooperation", 0.5)) >= 1.0

# Llamado al escaneo de sentidos (~5 Hz); el trabajo real se cadencia a ~4 s
# para no disparar eventos sociales ni reevaluar alianzas cada decima.
func _bot_social_update(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	if bool(proxy.get_meta("proxy_dead", false)):
		return
	b["_soc_t"] = float(b.get("_soc_t", 0.0))
	if float(b["_soc_t"]) > 0.0:
		return
	b["_soc_t"] = 3.2 + fmod(float(b["bot_id"]) * 0.11, 0.9)
	var my_id := int(b["bot_id"])
	var my_key := "bot_%d" % my_id
	var lid := int(b.get("team_leader_id", 0))
	if lid > 0:
		b["_meet_id"] = 0 # ya esta en equipo: no busca a nadie

	# 1) Mantener o romper el equipo actual (solo si el lider es otro bot;
	#    los equipos reclutados por un humano se gestionan por ordenes)
	if lid > 0 and is_bot_peer_id(lid):
		var lb: Dictionary = bots.get(lid, {})
		var lp: Node3D = lb.get("proxy")
		var leader_gone: bool = lb.is_empty() or lp == null or not is_instance_valid(lp) or bool(lp.get_meta("proxy_dead", false))
		var rel := get_bot_relationship(my_id, "bot_%d" % lid)
		var too_far := (not leader_gone) and proxy.global_position.distance_to(lp.global_position) > BOT_TEAM_GIVE_UP_DIST
		if leader_gone or float(rel.get("trust", 0.0)) < BOT_TEAM_BREAK_TRUST or too_far:
			record_bot_event(my_id, "team_leave", "bot_%d" % lid, _poi_kind_near(proxy.global_position), proxy.global_position,
				"lider muerto" if leader_gone else ("desconfianza" if float(rel.get("trust", 0.0)) < BOT_TEAM_BREAK_TRUST else "se perdio"))
			b["team_leader_id"] = 0
			proxy.set_meta("team_leader_id", 0)
			lid = 0
		elif randf() < 0.55:
			# Sobrevivir juntos consolida la confianza (aprendizaje persistente)
			record_social_event(my_id, "bot_%d" % lid, str(lb.get("name", "")), "ally", 0.03, "equipo")

	# 2) Formar equipo: convivir cerca sin agresiones sube la confianza hasta
	#    que alguien se ofrece a seguir al bot con mejor perfil de lider
	if lid <= 0:
		var my_faction := str(b.get("faction", ""))
		var my_lead := _bot_lead_score(b)
		var best_target := 0
		var best_trust := -1.0
		var meet_id := 0
		var meet_dist := INF
		for oid in bots.keys():
			if oid == my_id:
				continue
			var ob: Dictionary = bots[oid]
			if str(ob.get("faction", "")) != my_faction:
				continue # bandidos y supervivientes no se mezclan
			var op: Node3D = ob.get("proxy")
			if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
				continue
			var oid_lid := int(ob.get("team_leader_id", 0))
			if oid_lid > 0 and not is_bot_peer_id(oid_lid):
				continue # sigue a un humano: no es un aliado libre
			var odist := proxy.global_position.distance_to(op.global_position)
			if odist > BOT_TEAM_MEET_DIST:
				continue
			var okey := "bot_%d" % oid
			var rel_out := get_bot_relationship(my_id, okey)
			var rel_in := get_bot_relationship(oid, my_key)
			# Los bandidos parten con desconfianza alta entre ellos: su puerta
			# de convivencia es mas laxa (una banda tarda mas en fraguarse).
			var host_gate := 0.40 if my_faction == "hostile" else 0.05
			var civil := float(rel_out.get("hostility", 0.0)) <= host_gate and float(rel_in.get("hostility", 0.0)) <= host_gate
			if odist > BOT_TEAM_FORM_DIST:
				# Iman social: lejos para convivir pero al alcance — un bot que
				# quiere compañia viaja a reunirse con su aliado potencial.
				if civil and _bot_wants_company(b, rel_out) and odist < meet_dist:
					meet_dist = odist
					meet_id = oid
				continue
			if civil:
				record_social_event(my_id, okey, str(ob.get("name", okey)), "ally", 0.05, "convive")
				record_social_event(oid, my_key, str(b.get("name", my_key)), "ally", 0.05, "convive")
				rel_out = get_bot_relationship(my_id, okey)
				rel_in = get_bot_relationship(oid, my_key)
			var mutual := minf(float(rel_out.get("trust", 0.0)), float(rel_in.get("trust", 0.0)))
			if mutual < BOT_TEAM_FORM_TRUST:
				continue
			# Si ya milita en un equipo, el candidato es su lider (el equipo crece);
			# si esta libre, solo me uno si lidera mejor que yo — si no, el se
			# unira a mi en su propio ciclo (desempate deterministico).
			var olid := int(ob.get("team_leader_id", 0))
			var target_id: int = olid if (olid > 0 and is_bot_peer_id(olid)) else oid
			if olid <= 0 and _bot_lead_score(ob) <= my_lead:
				continue
			if _bot_team_size(target_id) >= BOT_TEAM_MAX_SIZE:
				continue
			if olid > 0:
				var lrel := get_bot_relationship(my_id, "bot_%d" % target_id)
				var lrel_in := get_bot_relationship(target_id, my_key)
				mutual = minf(float(lrel.get("trust", 0.0)), float(lrel_in.get("trust", 0.0)))
				if mutual < BOT_TEAM_FORM_TRUST:
					continue
			if mutual > best_trust:
				best_trust = mutual
				best_target = target_id
		if best_target > 0:
			b["team_leader_id"] = best_target
			proxy.set_meta("team_leader_id", best_target)
			b["follow_mode"] = "follow"
			b["sense_t"] = 0.0
			b["_meet_id"] = 0
			var tn := str((bots.get(best_target, {}) as Dictionary).get("name", str(best_target)))
			record_bot_event(my_id, "team_join", "bot_%d" % best_target, _poi_kind_near(proxy.global_position), proxy.global_position, "sigue a " + tn)
			_record_milestone(my_id, "first_team")
			_record_milestone(best_target, "first_lead")
		elif meet_id > 0:
			# Reencuentro: fijar la meta de exploracion en la posicion VIVA del
			# aliado potencial (se reescribe cada ciclo, siguiendo su marcha)
			# hasta entrar en radio de convivencia, donde crece la confianza.
			var mb: Dictionary = bots.get(meet_id, {})
			var mp: Node3D = mb.get("proxy")
			var adir := _ai_active_directive(b)
			var dir_busy := not adir.is_empty() and str(adir.get("action", "")) in ["return_home", "rest", "avoid_zone", "fortify_camp"]
			if mp != null and is_instance_valid(mp) and not dir_busy and (b.get("_ambush", {}) as Dictionary).is_empty():
				b["explore_target"] = mp.global_position
				b["explore_dwell"] = 0.0
				b["_meet_id"] = meet_id
				if float(b.get("_meet_ev_t", 0.0)) <= 0.0:
					b["_meet_ev_t"] = 70.0
					record_bot_event(my_id, "team_seek", "bot_%d" % meet_id, _poi_kind_near(proxy.global_position), proxy.global_position, "busca a " + str(mb.get("name", meet_id)))
			else:
				b["_meet_id"] = 0
		else:
			b["_meet_id"] = 0

	# 3) Coordinacion de emboscada: el lider hostil (o un hostil solo) elige la
	#    presa; sus miembros reciben el mismo objetivo en su propio ciclo
	var am: Dictionary = b.get("_ambush", {})
	var is_hostile: bool = str(b.get("faction", "")) == "hostile"
	if is_hostile and (lid <= 0 or _bot_team_role(b) == "leader"):
		# Hostil solo o lider de su equipo: elige la presa el mismo
		if am.is_empty():
			var victim := _find_ambush_target(b)
			if not victim.is_empty():
				b["_ambush"] = victim
				record_bot_event(my_id, "ambush_plan", "peer_%d" % int(victim.get("target_id", 0)), _poi_kind_near(proxy.global_position), proxy.global_position, "acecha a " + str(victim.get("target_name", "")))
				_record_milestone(my_id, "first_ambush")
	elif is_hostile and lid > 0 and is_bot_peer_id(lid) and bots.has(lid):
		# Miembro de un lider hostil: copia su presa — el golpe es simultaneo
		var lamb: Dictionary = bots[lid].get("_ambush", {})
		if not lamb.is_empty() and int(lamb.get("target_id", 0)) != int(am.get("target_id", -1)):
			b["_ambush"] = lamb.duplicate()

	# 4) Chat: respuestas, gritos de ayuda, alianzas, saludos y susurros
	_bot_chat_tick(b)

# Reune a todo el equipo de la victima (lider + miembros) contra el agresor:
# el equivalente bot de un grito de ayuda. Se llama desde _net_damage_player.
func rally_bot_team(victim_id: int, attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker) or not bots.has(victim_id):
		return
	var victim_b: Dictionary = bots[victim_id]
	var lid := int(victim_b.get("team_leader_id", 0))
	var leader := lid if lid > 0 else victim_id
	for bid in bots.keys():
		var tb: Dictionary = bots[bid]
		if bid != leader and int(tb.get("team_leader_id", 0)) != leader:
			continue
		var tp: Node3D = tb.get("proxy")
		if tp == null or not is_instance_valid(tp) or bool(tp.get_meta("proxy_dead", false)):
			continue
		if tp.global_position.distance_to(attacker.global_position) <= 60.0:
			tb["aggro_target"] = attacker
			tb["aggro_timer"] = 25.0
			tb["sitting"] = false
			tb["sleeping"] = false
			tb["sense_t"] = 0.0

func _peer_id_for_actor(node: Node3D) -> int:
	for bid in bots.keys():
		if bots[bid].get("proxy") == node:
			return int(bid)
	if world != null and "server_proxies" in world:
		for pid in world.server_proxies.keys():
			if world.server_proxies[pid] == node:
				return int(pid)
	var local_p = world.get("player") if world != null else null
	if local_p == node:
		var net = world.get("net")
		return net.get_my_id() if (net != null and net.has_method("get_my_id")) else 1
	return 0

func _bot_has_ranged_weapon(proxy: Node3D) -> bool:
	if _bot_item_count(proxy, "Fusil de asalto") + _bot_item_count(proxy, "Rifle francotirador") > 0:
		return true
	return not _bot_best_bow(proxy).is_empty() and _bot_arrow_count(proxy) > 0

# La presa ideal de una emboscada: cerca, cargada de recursos, sola y con pocos
# aliados — el bandido roba lo que necesita, no mata por matar.
func _find_ambush_target(b: Dictionary) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var now_s := Time.get_ticks_msec() / 1000.0
	if now_s < float(b.get("_ambush_cd_until", 0.0)):
		return {}
	var weapon := _pick_fight_weapon(b, 10.0)
	if str(weapon.get("name", "")).is_empty():
		return {}
	var my_team := _bot_team_ids(b)
	var desperate: bool = float(b["hunger"]) < 30.0 or float(b["thirst"]) < 25.0
	var sight := 52.0
	var best: Dictionary = {}
	var best_score := -1.0
	for p in world.get_tree().get_nodes_in_group("net_player_proxy"):
		if not (p is Node3D) or p == proxy or not is_instance_valid(p):
			continue
		if bool(p.get_meta("proxy_dead", false)) or not bool(p.get_meta("has_real_pos", false)):
			continue
		if bool(p.get_meta("is_ai_bot", false)) and str(p.get_meta("bot_faction", "")) == "hostile":
			continue # no canibalismo entre bandidos
		var pid := _peer_id_for_actor(p)
		if pid > 0 and pid in my_team:
			continue # nunca contra el propio equipo
		var p3 := p as Node3D
		var d := proxy.global_position.distance_to(p3.global_position)
		if d > sight or (d > 12.0 and not _has_clear_shot(proxy.global_position, p3.global_position)):
			continue
		# Valor del botin visible: inventario + mochila + arma en mano
		var inv_n := (p3.get_meta("saved_inventory", []) as Array).size()
		var loot_val := float(inv_n)
		if not str(p3.get_meta("saved_backpack", "")).is_empty():
			loot_val += 5.0
		if not str(p3.get_meta("saved_held_item", "")).is_empty():
			loot_val += 1.5
		var victim_hp := float(p3.get_meta("proxy_health", 100.0))
		# Escoltas: si la presa tiene compañia cerca y el mio no la supera, pasar
		var allies := 0
		for q in world.get_tree().get_nodes_in_group("net_player_proxy"):
			if q == p3 or not (q is Node3D) or not is_instance_valid(q):
				continue
			if bool(q.get_meta("proxy_dead", false)):
				continue
			var qid := _peer_id_for_actor(q)
			if qid > 0 and qid in my_team:
				continue
			if p3.global_position.distance_to(q.global_position) <= 20.0:
				allies += 1
		if allies >= my_team.size() and not desperate:
			continue
		if loot_val < 4.0 and not desperate:
			continue
		var score := loot_val + (8.0 if allies == 0 else 0.0) + (4.0 if victim_hp < 60.0 else 0.0) - d * 0.15
		if score > best_score:
			best_score = score
			best = {"target_id": pid, "target_name": _actor_display_name(pid) if pid > 0 else "?", "t": 0.0}
	return best

# Ejecuta la emboscada cada tick: acecho agachado hasta el borde del asalto y
# golpe conjunto (el equipo entero recibe aggro sobre la victima a la vez).
func _bot_try_ambush(b: Dictionary, delta: float) -> bool:
	var amb: Dictionary = b.get("_ambush", {})
	if amb.is_empty():
		return false
	var proxy: Node3D = b["proxy"]
	var now_s := Time.get_ticks_msec() / 1000.0
	var abort := func(cd: float) -> bool:
		b["_ambush"] = {}
		b["_ambush_cd_until"] = now_s + cd
		return false
	var target := _find_actor_by_peer_id(int(amb.get("target_id", 0)))
	if target == null or not is_instance_valid(target) or bool(target.get_meta("proxy_dead", false)) or target.get("is_dead") == true:
		return abort.call(70.0)
	var d := proxy.global_position.distance_to(target.global_position)
	if d > BOT_AMBUSH_ABORT_DIST:
		return abort.call(50.0)
	if float(b["thirst"]) < 16.0 or float(b["hunger"]) < 10.0 or float(b["health"]) < 30.0:
		return abort.call(60.0)
	amb["t"] = float(amb.get("t", 0.0)) + delta
	b["_ambush"] = amb
	var strike := BOT_AMBUSH_STRIKE_RANGED if _bot_has_ranged_weapon(proxy) else BOT_AMBUSH_STRIKE_MELEE
	if d <= strike or (float(amb["t"]) > BOT_AMBUSH_MAX_SECONDS and d <= strike + 8.0):
		# GOLPE: todo el equipo ataca a la vez
		b["_ambush"] = {}
		b["_ambush_cd_until"] = now_s + 75.0
		b["aggro_target"] = target
		b["aggro_timer"] = 30.0
		b["sleeping"] = false
		b["crouching"] = false
		b["sense_t"] = 0.0
		rally_bot_team(int(b["bot_id"]), target)
		record_bot_event(int(b["bot_id"]), "ambush_strike", "peer_%d" % int(amb.get("target_id", 0)), _poi_kind_near(target.global_position), target.global_position, "asalto a " + str(amb.get("target_name", "")))
		return true
	if float(amb["t"]) > BOT_AMBUSH_MAX_SECONDS:
		return abort.call(45.0)
	# Acechar agachado: el que va en cuclillas se detecta mucho peor
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = true
	_move_bot_towards(b, target.global_position, 2.9, delta, "walk")
	return true

# --- Chat entre bots y con humanos ------------------------------------------
# Los bots hablan por el chat del juego como supervivientes reales: bot->humano
# llega al panel de chat del jugador (NetworkManager.relay_actor_chat),
# humano->bot lo "oye" la IA via _net_bot_hear_chat, y bot->bot recorre el
# mismo canal internamente. El texto lo redacta Qwen con la personalidad del
# bot (peticion aparte en _chat_http para no robar la cola de decisiones); si
# no hay clave/cuota salen plantillas locales. El chat produce conducta real:
# pedir ayuda mueve al aliado a socorrer y proponer alianza hace que ambos
# converjan via _meet_id hasta formar equipo.
const BOT_CHAT_CD := 26.0
const BOT_CHAT_PAIR_CD := 70.0
const BOT_CHAT_REPLY_CD := 7.0
const BOT_CHAT_GREET_RANGE := 16.0
const BOT_CHAT_GREET_CD := 200.0
const BOT_CHAT_HELP_CD := 120.0
const BOT_CHAT_REQ_CD := 90.0
const BOT_CHAT_LOG_MAX := 24
const BOT_CHAT_MAX_TURNS := 4
const BOT_CHAT_SYSTEM_PROMPT := "Eres un superviviente en un mundo postapocaliptico (juego Last Day). Hablas por el chat del juego como una persona real: frases cortas, informales, en espanol, directas. Prohibido: emojis, comillas, roleplay con asteriscos, mencionar que eres IA. Responde SOLO con el texto del mensaje, maximo 140 caracteres."

var _chat_http: HTTPRequest = null
var _chat_pending: Dictionary = {}          # peticion Qwen en vuelo {bot_id,to_id,to_name,kind,intent}
var chat_log: Array = []                    # [{ts,from_id,from,to_id,to,kind,text}] para el monitor
var _chat_pair_until: Dictionary = {}       # "a:b" -> msec (enfriamiento de iniciados)
var _chat_greet_until: Dictionary = {}      # "a:b" -> msec (saludos, ventana larga)
var _chat_turns: Dictionary = {}            # "a:b" -> int (corta el ping-pong bot-bot)
var _chat_help_until: Dictionary = {}       # bot_id -> msec
var _chat_req_until: Dictionary = {}        # bot_id -> msec (peticiones de recursos)

func _chat_pair_key(a: int, b2: int) -> String:
	return "%d:%d" % [mini(a, b2), maxi(a, b2)]

func _chat_pair_ok(a: int, b2: int, now: int) -> bool:
	return now >= int(_chat_pair_until.get(_chat_pair_key(a, b2), 0))

# Llega un mensaje al bot (humano o bot): registra el efecto social, encola la
# respuesta y, si procede, desencadena conducta (socorrer / ir a unirse).
func on_chat_received(target_id: int, sender_id: int, sender_name: String, text: String) -> void:
	var clean := text.strip_edges().substr(0, 160)
	if clean.is_empty() or not bots.has(target_id) or target_id == sender_id:
		return
	var tb: Dictionary = bots[target_id]
	var tproxy: Node3D = tb.get("proxy")
	if tproxy == null or not is_instance_valid(tproxy) or bool(tproxy.get_meta("proxy_dead", false)):
		return
	var sender_is_bot := bots.has(sender_id)
	var skey := ("bot_%d" % sender_id) if sender_is_bot else _actor_persist_key(sender_id)
	var intent := _chat_classify(clean)
	var rel := _chat_touch_rel(target_id, skey, sender_name)
	match intent:
		"help":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.02, -1.0, 1.0), 0.001)
		"alliance":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.04, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(maxf(0.0, float(rel.get("hostility", 0.0)) - 0.03), 0.001)
		"greet":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.02, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(maxf(0.0, float(rel.get("hostility", 0.0)) - 0.02), 0.001)
		"threat":
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) + 0.06, 0.0, 1.0), 0.001)
			rel["fear"] = snappedf(clampf(float(rel.get("fear", 0.0)) + 0.05, 0.0, 1.0), 0.001)
	# Un grito de ayuda o una propuesta de alianza mueve al aliado hacia el
	# emisor: mismo iman social que los reencuentros (26 m -> equipo).
	var hostile_me := str(tb.get("faction", "")) == "hostile"
	if (intent == "help" or intent == "alliance") and sender_is_bot and not hostile_me \
		and int(tb.get("team_leader_id", 0)) == 0 and int(tb.get("_meet_id", 0)) == 0 \
		and float(rel.get("trust", 0.0)) > 0.10:
		tb["_meet_id"] = sender_id
		tb["_soc_t"] = 0.0
		_record_milestone(target_id, "first_rescue" if intent == "help" else "first_alliance")
	# Ensenanzas del mundo (chat o voz): "aqui hay agua", "cuidado hay lobos",
	# "recuerda este sitio" — va antes que las ordenes para que "bebe aqui"
	# enseñe la fuente en vez de mandar beber de la botella.
	var teach := _chat_parse_teach(clean)
	if not teach.is_empty():
		var snode := _find_actor_by_peer_id(sender_id)
		var spos := tproxy.global_position
		if snode != null and is_instance_valid(snode):
			spos = snode.global_position
		_chat_teach_apply(tb, sender_id, sender_name, skey, str(teach["kind"]), spos)
		_bot_chat_send(tb, sender_id, sender_name, _chat_teach_line(tb, str(teach["kind"])), "teach")
		return
	# Ordenes directas del chat humano: "sigueme", "quedate", "dame agua"...
	# Obedece segun relacion + personalidad y contesta al momento.
	if not sender_is_bot:
		var order := _chat_parse_order(clean)
		if not order.is_empty():
			_chat_handle_order(tb, sender_id, sender_name, skey, str(order["cmd"]), str(order.get("arg", "")))
			return
	# Peticiones entre cualquiera ("tienes comida?", "necesito vendas",
	# "ayudame"): el receptor decide si da, acude o se niega.
	var req := _chat_parse_request(clean)
	if not req.is_empty():
		_chat_handle_request(tb, sender_id, sender_name, skey, sender_is_bot, str(req["cmd"]), str(req.get("arg", "")))
		return
	# Encolar respuesta (la ultima gana); los turnos cortan el ping-pong
	var pk := _chat_pair_key(target_id, sender_id)
	if not sender_is_bot or int(_chat_turns.get(pk, 0)) < BOT_CHAT_MAX_TURNS:
		tb["_chat_inbox"] = {"from_id": sender_id, "from_name": sender_name, "text": clean, "intent": intent}

func _chat_touch_rel(bot_id: int, skey: String, sname: String) -> Dictionary:
	var mem := _ensure_bot_memory(bot_id)
	var rels: Dictionary = mem["relationships"]
	if not rels.has(skey) or not (rels[skey] is Dictionary):
		var pers: Dictionary = mem.get("personality", _default_personality_for_bot(bot_id))
		rels[skey] = {"id": skey, "name": sname, "trust": clampf((float(pers.get("sociability", 0.5)) - float(pers.get("distrust", 0.35))) * 0.25, -0.35, 0.35), "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0}
	var rel: Dictionary = rels[skey]
	if not sname.is_empty():
		rel["name"] = sname
	return rel

func _chat_classify(text: String) -> String:
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u") + " "
	for kw in ["ayuda", "auxilio", "socorro", "me atacan", "me pega", "me mata", "ven rapido", "ven ya", "un lobo me", "un oso me", "me dispara"]:
		if t.contains(kw):
			return "help"
	for kw in ["nos junt", "juntarnos", "juntemonos", "unete", "alianza", "en equipo", "hacer equipo", "ven conmigo", "vamos juntos"]:
		if t.contains(kw):
			return "alliance"
	for kw in ["te mat", "te reviento", "muere", "te quito", "voy a por ti", "te voy a", "te espero", "entrega"]:
		if t.contains(kw):
			return "threat"
	for kw in ["hola", "buenas", "saludos", "que tal", "ey ", "ei ", "oye "]:
		if t.contains(kw):
			return "greet"
	return "talk"

# ==================== ORDENES POR CHAT ====================
# El jugador da ordenes escritas ("sigueme", "quedate", "dame agua"...) y el bot
# obedece — o no — segun su relacion (trust/hostility/fear), su personalidad
# (cooperacion, desconfianza, agresion) y su situacion (bajo ataque, ya en otro
# equipo, faccion hostil). La respuesta sale al momento por el mismo chat.

func _chat_parse_order(text: String) -> Dictionary:
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("?", " ").replace("¿", " ").replace("!", " ").replace("¡", " ").replace(",", " ").replace(".", " ") + " "
	# follow antes que come: "ven/vente conmigo" es seguir, no solo acercarse
	for kw in ["sigueme", "siguenos", "ven conmigo", "vente conmigo", "venga conmigo", "acompaname", "unete a mi", "en mi equipo", "follow me"]:
		if t.contains(kw):
			return {"cmd": "follow"}
	for kw in [" ataca ", "matalo", "matela", "matadle", "encargate", "dispara a", "a por el", "a por ella", "defiendeme", "protegeme"]:
		if t.contains(kw):
			return {"cmd": "attack"}
	for kw in [" dame ", " pasame ", " tirame ", " comparte "]:
		if t.contains(kw):
			var arg := ""
			for w in ["agua", "comida", "vendaje", "venda", "vendas", "botiquin", "arma", "pistola", "rifle", "fusil", "cuchillo", "hacha", "municion", "balas", "comer", "lata", "carne", "verduras", "medicina", "sed"]:
				if t.contains(" " + w):
					arg = w
					break
			return {"cmd": "give", "arg": arg}
	for kw in ["quedate", "quedate aqui", "espera aqui", "esperame", "quieto", "quieta", "no te muevas", "mantente", "guarda esto", "vigila aqui"]:
		if t.contains(kw):
			return {"cmd": "stay"}
	for kw in ["vete", "largate", " largo ", "dejame en paz", "alejate", "dejame solo", "dejame sola", "sigue tu camino", "vete de aqui", "marchate"]:
		if t.contains(kw):
			return {"cmd": "dismiss"}
	for kw in ["ven aqui", "ven aca", " vente ", "acercate", "venga aqui", "aproximate", "ven a por mi"]:
		if t.contains(kw):
			return {"cmd": "come"}
	for kw in ["equipate", "busca equipo", "recoge equipo", "armate", "busca loot", "saquea", "busca suministros", "busca cosas"]:
		if t.contains(kw):
			return {"cmd": "equip"}
	for kw in [" come ", " come algo", "comete", "alimentate", " bebe ", "bebe algo", "bebe agua", "hidratate"]:
		if t.contains(kw):
			return {"cmd": "eat"}
	return {}

# Umbral de obediencia por orden: compromiso mayor exige mas confianza.
func _chat_order_gate(b: Dictionary, sender_id: int, skey: String, cmd: String) -> Dictionary:
	if int(b.get("team_leader_id", 0)) == sender_id:
		return {"ok": true, "why": "team"}
	if str(b.get("faction", "")) == "hostile":
		return {"ok": false, "why": "hostile"}
	var rel := get_bot_relationship(int(b["bot_id"]), skey)
	if int(rel.get("attacked", 0)) >= 1 and float(rel.get("hostility", 0.0)) >= 0.5:
		return {"ok": false, "why": "betrayed"}
	# Bajo fuego no acepta compromisos (puede quedarse, irse o defenderse)
	if b.get("aggro_target") != null or _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null:
		if not cmd in ["stay", "dismiss", "attack"]:
			return {"ok": false, "why": "busy"}
	var pers := _get_bot_personality(b)
	var score := float(rel.get("trust", 0.0)) * 0.75 \
		+ float(pers.get("cooperation", 0.5)) * 0.30 \
		+ float(pers.get("sociability", 0.5)) * 0.12 \
		- float(pers.get("distrust", 0.35)) * 0.28 \
		- float(rel.get("hostility", 0.0)) * 0.55 \
		- float(pers.get("aggression", 0.35)) * 0.10 \
		+ minf(int(rel.get("helped", 0)) * 0.05, 0.20)
	var need := {"follow": 0.10, "come": 0.05, "stay": -0.10, "eat": -0.10,
		"equip": -0.05, "dismiss": -0.20, "give": 0.30, "attack": 0.40}.get(cmd, 0.0)
	if float(rel.get("fear", 0.0)) > 0.55 and cmd in ["follow", "come", "give"]:
		return {"ok": false, "why": "scared"}
	if score < need:
		return {"ok": false, "why": "distrust"}
	return {"ok": true, "why": "trust"}

# Ejecuta la orden; devuelve "" si se aplico o el motivo del fallo.
func _chat_apply_order(b: Dictionary, sender_id: int, sname: String, cmd: String, arg: String) -> String:
	var proxy: Node3D = b["proxy"]
	var bot_id := int(b["bot_id"])
	var skey := _actor_persist_key(sender_id)
	match cmd:
		"follow":
			var other := int(b.get("team_leader_id", 0))
			if other != 0 and other != sender_id:
				return "other_team"
			if other != sender_id:
				b["team_leader_id"] = sender_id
				b["follow_mode"] = "follow"
				b["sitting"] = false
				b["sleeping"] = false
				b["aggro_target"] = null
				b["_meet_id"] = 0
				proxy.set_meta("team_leader_id", sender_id)
				proxy.set_meta("bot_follow_mode", "follow")
				record_social_event(bot_id, skey, sname, "ally", 0.15, "chat_order_follow")
				_publish_bot_to_net_players(b)
				_apply_local_avatar_metadata(b)
		"stay":
			if int(b.get("team_leader_id", 0)) == sender_id:
				b["follow_mode"] = "stay"
				b["stay_pos"] = proxy.global_position
				proxy.set_meta("bot_follow_mode", "stay")
				_publish_bot_to_net_players(b)
				_apply_local_avatar_metadata(b)
			else:
				b["explore_target"] = proxy.global_position
				b["explore_dwell"] = 60.0
			b["sitting"] = false
		"come":
			var node := _find_actor_by_peer_id(sender_id)
			if node == null or not is_instance_valid(node):
				return "no_target"
			if int(b.get("team_leader_id", 0)) == sender_id:
				b["follow_mode"] = "follow"
				proxy.set_meta("bot_follow_mode", "follow")
				_publish_bot_to_net_players(b)
				_apply_local_avatar_metadata(b)
			else:
				b["explore_target"] = node.global_position
				b["explore_dwell"] = 0.0
				b["sitting"] = false
		"dismiss":
			if int(b.get("team_leader_id", 0)) == sender_id:
				b["team_leader_id"] = 0
				b["follow_mode"] = "follow"
				proxy.set_meta("team_leader_id", 0)
				proxy.set_meta("bot_follow_mode", "follow")
				_publish_bot_to_net_players(b)
				_apply_local_avatar_metadata(b)
			else:
				var node2 := _find_actor_by_peer_id(sender_id)
				var away := Vector3.RIGHT
				if node2 != null and is_instance_valid(node2):
					var dv := proxy.global_position - node2.global_position
					dv.y = 0.0
					if dv.length() > 0.5:
						away = dv.normalized()
				b["explore_target"] = proxy.global_position + away * 80.0
				b["explore_dwell"] = 0.0
				b["_meet_id"] = 0
		"eat":
			var has_food := false
			for it in proxy.get_meta("saved_inventory", []):
				if it is Dictionary and str(it.get("type", "")) == "food" and int(it.get("quantity", 1)) > 0:
					has_food = true
					break
			if not has_food:
				return "no_food"
			b["forced_eat"] = true
			b["eat_cooldown"] = 0.0
		"equip":
			b["equip_mission"] = true
			b["sense_t"] = 0.0
		"give":
			return _chat_give_item(b, arg)
		"attack":
			var foe := _chat_order_target(b, sender_id)
			if foe == null:
				return "no_target"
			b["aggro_target"] = foe
			b["aggro_timer"] = 20.0
			b["sitting"] = false
			b["sense_t"] = 0.0
	return ""

func _chat_give_match(arg: String) -> String:
	if arg in ["agua", "sed"]:
		return "drink"
	if arg in ["venda", "vendas", "vendaje", "botiquin", "medicina"]:
		return "medical"
	if arg in ["arma", "pistola", "rifle", "fusil", "cuchillo", "hacha"]:
		return "weapon"
	if arg in ["municion", "balas"]:
		return "ammo"
	return "food"

# Deja caer al suelo lo pedido (o lo primero comestible si no se concreta).
func _chat_give_item(b: Dictionary, arg: String) -> String:
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var want := _chat_give_match(arg) if not arg.is_empty() else ""
	var idx := -1
	var backup := -1
	for i in range(inv.size()):
		var it = inv[i]
		if not (it is Dictionary) or str(it.get("type", "")) == "backpack":
			continue
		var tp := str(it.get("type", ""))
		if want.is_empty():
			if tp in ["food", "drink", "medical"]:
				idx = i
				break
			if backup < 0 and tp != "tool":
				backup = i
		elif tp == want or (want == "food" and tp == "drink"):
			idx = i
			break
	if idx < 0:
		idx = backup
	if idx < 0:
		return "nothing"
	var item: Dictionary = (inv[idx] as Dictionary).duplicate(true)
	var qty := int(item.get("quantity", 1))
	if qty > 1:
		inv[idx]["quantity"] = qty - 1
		item["quantity"] = 1
	else:
		inv.remove_at(idx)
	proxy.set_meta("saved_inventory", inv)
	_bot_drop_to_ground(b, item)
	_auto_equip_best_gear(b)
	_publish_bot_to_net_players(b)
	return ""

# Objetivo de "ataca": el depredador/hostil mas cercano al bot o a quien ordena.
func _chat_order_target(b: Dictionary, sender_id: int) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var snode := _find_actor_by_peer_id(sender_id)
	var best: Node3D = null
	var best_d := 34.0
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not is_instance_valid(w) or bool(w.get("_is_dead")):
			continue
		if str(w.get("animal_type")) not in ["wolf", "bear"]:
			continue
		var d := proxy.global_position.distance_to(w.global_position)
		if snode != null and is_instance_valid(snode):
			d = minf(d, snode.global_position.distance_to(w.global_position) * 0.6)
		if d < best_d:
			best_d = d
			best = w
	for bid in bots.keys():
		var ob: Dictionary = bots[bid]
		if int(ob.get("bot_id", 0)) == int(b["bot_id"]):
			continue
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		if str(ob.get("faction", "")) != "hostile" and ob.get("aggro_target") != snode:
			continue
		var d2 := proxy.global_position.distance_to(op.global_position)
		if snode != null and is_instance_valid(snode):
			d2 = minf(d2, snode.global_position.distance_to(op.global_position) * 0.6)
		if d2 < best_d:
			best_d = d2
			best = op
	return best

func _chat_order_line(b: Dictionary, cmd: String, ok: bool, why: String) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.55 and float(pers.get("aggression", 0.35)) < 0.5
	if ok:
		match cmd:
			"follow":
				return "Vale, voy contigo. Tu mandas." if warm else "De acuerdo, te sigo. No me hagas arrepentirme."
			"stay":
				return "Me quedo aqui, tranquila." if warm else "Bien. Me quedo quieto."
			"come":
				return "Voy para alla, esperame." if warm else "Ya voy."
			"dismiss":
				return "Entendido, sigo mi camino. Suerte." if warm else "De acuerdo, me voy."
			"eat":
				return "Si, me cae bien un bocado." if warm else "Vale, como algo."
			"equip":
				return "Buena idea, necesito mejor equipo." if warm else "Ire a ver que encuentro."
			"give":
				return "Toma, te lo dejo aqui." if warm else "Dale, quedatelo."
			"attack":
				return "Voy a por el!" if float(pers.get("aggression", 0.35)) > 0.5 else "De acuerdo, lo intento. Cubreme."
	match why:
		"hostile":
			return "¿Ordenes? A mi no me mandas."
		"betrayed":
			return "Despues de lo que me hiciste, olvidate."
		"scared":
			return "Ni se te ocurra acercarte. Dejame en paz."
		"busy":
			return "¡Ahora no! Tengo problemas mas grandes."
		"other_team":
			return "Ya voy con otro. No le voy a dejar."
		"no_food":
			return "No tengo nada comestible encima."
		"nothing":
			return "No llevo nada que darte."
		"no_target":
			return "¿Atacar a quien? No veo ninguna amenaza cerca."
	return "Ni te conozco. ¿Por que iba a hacerte caso?" if warm else "No me fio de ti lo suficiente."

func _chat_handle_order(b: Dictionary, sender_id: int, sname: String, skey: String, cmd: String, arg: String) -> void:
	var gate := _chat_order_gate(b, sender_id, skey, cmd)
	var why := str(gate.get("why", ""))
	var ok := bool(gate.get("ok", false))
	if ok:
		why = _chat_apply_order(b, sender_id, sname, cmd, arg)
		ok = why.is_empty()
	var line := _chat_order_line(b, cmd, ok, why)
	if not line.is_empty():
		_bot_chat_send(b, sender_id, sname, line, "order")
	if ok:
		record_social_event(int(b["bot_id"]), skey, sname, "help", 0.12, "chat_order_" + cmd)

# ==================== PETICIONES ENTRE ACTORES ====================
# "¿Tienes comida?", "necesito vendas", "echame una mano": lo piden bots a
# bots, bots a humanos y humanos a bots. Distinto de la orden "dame": aqui se
# suplica y el receptor decide segun relacion + personalidad. ATENCION: las
# frases de respuesta no pueden contener las keywords de peticion/orden o
# rebotarian como peticiones nuevas (ping-pong infinito entre bots).

func _chat_parse_request(text: String) -> Dictionary:
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("?", " ").replace("¿", " ").replace("!", " ").replace("¡", " ").replace(",", " ").replace(".", " ") + " "
	# Auxilio primero: "necesito ayuda" no es una peticion de objeto
	for kw in ["ayudame", " ayuda", "necesito ayuda", "echame una mano", "echame un cable", "acorralado", "acorralada", "estoy herido", "estoy herida", "estoy malherido", "me tienen", "vienen a por mi", "protegeme", "cubreme"]:
		if t.contains(kw):
			return {"cmd": "assist"}
	for kw in [" tienes ", " llevas ", " necesito ", " me falta ", " pasame ", " prestame ", " regalame ", " traeme ", " dame ", " compartes ", " comparte "]:
		if t.contains(kw):
			var arg := ""
			for w in ["agua", "comida", "vendaje", "venda", "vendas", "botiquin", "arma", "pistola", "rifle", "fusil", "cuchillo", "hacha", "municion", "balas", "comer", "lata", "carne", "verduras", "medicina", "sed"]:
				if t.contains(" " + w):
					arg = w
					break
			# "tienes suerte"/"llevas razon" no piden objeto; "necesito/dame" sin
			# nombre igualmente piden "algo comestible" por defecto mas abajo
			if arg.is_empty() and kw in [" tienes ", " llevas ", " compartes ", " comparte "]:
				continue
			return {"cmd": "give", "arg": arg}
	return {}

# Que echa en falta el bot ahora mismo ("" = nada urgente).
func _chat_request_need(b: Dictionary) -> String:
	var proxy: Node3D = b["proxy"]
	if float(b.get("hunger", 100.0)) < 18.0 and not _bot_has_edible_food(proxy, true):
		return "comida"
	if float(b.get("thirst", 100.0)) < 12.0 and not _bot_has_drink(proxy):
		return "agua"
	if float(b.get("health", 100.0)) < 35.0:
		var has_med := false
		for it in proxy.get_meta("saved_inventory", []):
			if it is Dictionary and str(it.get("type", "")) == "medical":
				has_med = true
				break
		if not has_med:
			return "vendas"
	var under_fire: bool = b.get("aggro_target") != null or _sensed_node(b, "_s_foe") != null or _sensed_node(b, "_s_predator") != null
	if under_fire and _best_weapon_name(proxy).is_empty():
		return "arma"
	return ""

# A quien pedirselo: el aliado de mas confianza; si no hay, el actor mas cercano.
func _chat_req_recipient(b: Dictionary) -> Dictionary:
	var ally := _chat_best_ally(b)
	if not ally.is_empty():
		return ally
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var best := {}
	var best_d := 65.0
	for oid in bots.keys():
		if oid == my_id:
			continue
		var ob: Dictionary = bots[oid]
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		if str(ob.get("faction", "")) == "hostile" and str(b.get("faction", "")) != "hostile":
			continue
		var rel := get_bot_relationship(my_id, "bot_%d" % oid)
		if float(rel.get("hostility", 0.0)) > 0.4:
			continue
		var d := proxy.global_position.distance_to(op.global_position)
		if d < best_d:
			best_d = d
			best = {"id": oid, "name": str(ob.get("name", str(oid)))}
	var net = world.get("net") if world != null else null
	if net != null and "players" in net:
		for pid in net.players.keys():
			var pdata: Dictionary = net.players[pid]
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)) or bool(pdata.get("is_ai_bot", false)) or bool(pdata.get("offline", false)):
				continue
			var pp := _find_actor_by_peer_id(int(pid))
			if pp == null:
				continue
			var rel2 := get_bot_relationship(my_id, _actor_persist_key(int(pid)))
			if float(rel2.get("hostility", 0.0)) > 0.4:
				continue
			var d2 := proxy.global_position.distance_to(pp.global_position)
			if d2 < best_d:
				best_d = d2
				best = {"id": int(pid), "name": str(pdata.get("char_name", pdata.get("name", "Jugador")))}
	return best

func _chat_weapon_count(proxy: Node3D) -> int:
	var n := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("type", "")) in ["weapon", "axe_tool"]:
			n += 1
	return n

# Responder a una peticion: dar el objeto (cae al suelo; el que pide va a por
# el), acudir al auxilio o negarse — todo segun la misma puerta de confianza.
func _chat_handle_request(b: Dictionary, sender_id: int, sname: String, skey: String, sender_is_bot: bool, cmd: String, arg: String) -> void:
	var bot_id := int(b["bot_id"])
	var ok := false
	var why := "distrust"
	match cmd:
		"give":
			var gate := _chat_order_gate(b, sender_id, skey, "give")
			ok = bool(gate.get("ok", false))
			why = str(gate.get("why", ""))
			if ok:
				var want := _chat_give_match(arg) if not arg.is_empty() else ""
				if want == "weapon" and _chat_weapon_count(b["proxy"]) <= 1:
					ok = false
					why = "keep_weapon" # nadie se desarma en un apocalipsis
				else:
					why = _chat_apply_order(b, sender_id, sname, "give", arg)
					ok = why.is_empty()
			if ok:
				record_social_event(bot_id, skey, sname, "help", 0.15, "gave_" + (arg if not arg.is_empty() else "item"))
				if sender_is_bot and bots.has(sender_id):
					var rb: Dictionary = bots[sender_id]
					rb["explore_target"] = (b["proxy"] as Node3D).global_position
					rb["explore_dwell"] = 0.0
					record_social_event(sender_id, "bot_%d" % bot_id, str(b.get("name", "")), "help", 0.2, "received_" + (arg if not arg.is_empty() else "item"))
		"assist":
			var gate2 := _chat_order_gate(b, sender_id, skey, "come")
			ok = bool(gate2.get("ok", false))
			why = str(gate2.get("why", ""))
			if ok:
				if sender_is_bot:
					b["_meet_id"] = sender_id
					b["sitting"] = false
				else:
					var sn := _find_actor_by_peer_id(sender_id)
					if sn == null or not is_instance_valid(sn):
						ok = false
						why = "no_target"
					else:
						b["explore_target"] = sn.global_position
						b["explore_dwell"] = 0.0
						b["sitting"] = false
	var line := _chat_request_line(b, cmd, ok, why)
	if not line.is_empty():
		_bot_chat_send(b, sender_id, sname, line, "request")

func _chat_request_line(b: Dictionary, cmd: String, ok: bool, why: String) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.55 and float(pers.get("aggression", 0.35)) < 0.5
	if ok:
		if cmd == "assist":
			return "Voy corriendo, aguanta ahi!" if warm else "Ya voy, no te muevas."
		return "Toma, te lo dejo aqui." if warm else "Vale, te lo dejo en el suelo."
	match why:
		"hostile":
			return "Pideselo a otro, tu y yo no somos socios."
		"betrayed":
			return "En serio? Me atacaste y ahora vienes a pedirme."
		"scared":
			return "No te acerques. Largo."
		"busy":
			return "No ves que estoy luchando por mi vida?!"
		"keep_weapon":
			return "Mi arma no la suelto, lo siento."
		"nothing", "no_food":
			return "No tengo nada, de verdad."
		"no_target":
			return "No encuentro a quien atacar."
	return "Lo siento, tambien ando justo." if warm else "No tengo para repartir."

# ==================== ENSEÑANZAS (chat o voz) ====================
# "aqui hay agua", "cuidado hay lobos", "registra esta casa": el que habla
# transmite conocimiento del mundo. Se guarda en known_locations y, si es
# agua, el bot la usa de verdad cuando tiene sed (_known_water_pos).

func _chat_parse_teach(text: String) -> Dictionary:
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("?", " ").replace("¿", " ").replace("!", " ").replace("¡", " ").replace(",", " ").replace(".", " ") + " "
	for kw in ["cuidado", "peligro", "peligrosa", "hay lobos", "hay un oso", "zona mala", "aqui matan", "aqui te atacan", "aqui disparan"]:
		if t.contains(kw):
			return {"kind": "danger"}
	for kw in ["hay agua", "aqui se bebe", "bebe aqui", "bebe de ", "puedes beber", "esta fuente", "este rio", "agua aqui", "de esta fuente", "en la fuente", "bebe en "]:
		if t.contains(kw):
			return {"kind": "water"}
	for kw in ["hay comida", "hay loot", "botin aqui", "saquea esto", "registra esta", "en esa casa", "en esa tienda", "hay suministros", "aqui hay cosas"]:
		if t.contains(kw):
			return {"kind": "loot"}
	for kw in ["puedes dormir", "refugiate", "refugio aqui", "monta aqui", "acampa aqui", "este sitio es seguro", "aqui estas seguro", "aqui estas segura"]:
		if t.contains(kw):
			return {"kind": "camp"}
	for kw in ["recuerda este sitio", "recuerda esto", "apunta este lugar", "marca este punto"]:
		if t.contains(kw):
			return {"kind": "marked"}
	return {}

# Aplica la ensenanza: registra el lugar en la memoria del bot y, si es agua,
# le sirve de verdad cuando tenga sed (fallback de _nearest_water_pos).
func _chat_teach_apply(b: Dictionary, sender_id: int, sname: String, skey: String, kind: String, pos: Vector3) -> void:
	var bid := int(b["bot_id"])
	var grid := func(p: Vector3, cell: float) -> String: return "%d:%d" % [int(p.x / cell), int(p.z / cell)]
	match kind:
		"water":
			observe_location(bid, "water:" + grid.call(pos, 30.0), "water", pos)
			if float(b.get("thirst", 100.0)) < 45.0:
				b["drink_at"] = pos
				b["drink_giveup"] = 0.0
				b["drink_scan"] = 0.0
		"loot":
			observe_location(bid, "loot:" + grid.call(pos, 30.0), "loot", pos)
		"danger":
			record_zone_hazard(bid, pos, "taught", 0.4)
		"camp":
			observe_location(bid, "camp:" + grid.call(pos, 30.0), "camp", pos)
		_:
			observe_location(bid, "marked:" + grid.call(pos, 30.0), "wild", pos)
	record_social_event(bid, skey, sname, "help", 0.25, "taught_" + kind)
	# Y se lo cuenta al resto: un aliado cercano tambien aprende el dato
	for oid in bots.keys():
		if oid != bid:
			observe_location(oid, "taught:%d:%d" % [int(pos.x / 30.0), int(pos.z / 30.0)], kind if kind != "danger" else "wild", pos, "shared")

func _chat_teach_line(b: Dictionary, kind: String) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.55 and float(pers.get("aggression", 0.35)) < 0.5
	match kind:
		"water":
			return "Perfecto, aqui puedo beber. Gracias." if warm else "Anotado, agua aqui."
		"danger":
			return "Entendido, me mantengo lejos de esta zona." if warm else "Recibido, ojo con este sitio."
		"loot":
			return "Apuntado, me pasare a revisarlo." if warm else "Ok, lo registro."
		"camp":
			return "Buen sitio para descansar, gracias." if warm else "Vale, campamento aqui."
	return "Lo apunto en mi mapa." if warm else "Anotado."

func _known_water_pos(b: Dictionary) -> Vector3:
	var mem: Dictionary = b.get("_mem", {})
	var known: Dictionary = mem.get("known_locations", {})
	var proxy: Node3D = b["proxy"]
	var best := Vector3.INF
	var best_d := 420.0
	for lid in known.keys():
		if str(lid).get_slice(":", 0) != "water":
			continue
		var e = known[lid]
		if not (e is Dictionary):
			continue
		var ep = e.get("pos", null)
		if not (ep is Array) or (ep as Array).size() < 3:
			continue
		var p := Vector3(float(ep[0]), float(ep[1]), float(ep[2]))
		var d := proxy.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best

# ==================== VOZ HUMANO -> BOT (STT local) ====================
# El jugador abre el DM de voz hacia el bot (como con otro jugador): el PCM
# 8-bit u8 12 kHz se acumula, un silencio de 1.4 s cierra la frase, se escribe
# un WAV en user://voice_jobs/ y el demonio faster-whisper del host escribe
# <base>.txt. Solo se oye a quemarropa (BOT_VOICE_RANGE) — la voz es fisica.

const BOT_VOICE_RANGE := 28.0
const BOT_VOICE_GAP_MSEC := 1400
const BOT_VOICE_MAX_BYTES := 240000 # ~20 s a 12 kHz u8
const VOICE_JOBS_DIR := "user://voice_jobs/"

var _voice_bufs: Dictionary = {}      # "sid_bid" -> {pcm, last, sid, bid, sname}
var _voice_jobs: Dictionary = {}      # basename -> {bot_id, sender_id, sender_name, born}
var _voice_far_notice: Dictionary = {} # sid -> msec

func on_voice_received(target_id: int, sender_id: int, sender_name: String, pcm: PackedByteArray) -> void:
	if not bots.has(target_id) or pcm.is_empty():
		return
	var tb: Dictionary = bots[target_id]
	var proxy: Node3D = tb.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	var snode := _find_actor_by_peer_id(sender_id)
	if snode == null or not is_instance_valid(snode):
		return
	if proxy.global_position.distance_to(snode.global_position) > BOT_VOICE_RANGE:
		var nowm0 := Time.get_ticks_msec()
		var last_notice := int(_voice_far_notice.get(sender_id, -1))
		if last_notice < 0 or nowm0 - last_notice > 10000:
			_voice_far_notice[sender_id] = nowm0
			var net0 = world.get("net") if world != null else null
			if net0 != null and net0.has_method("relay_actor_chat"):
				net0.relay_actor_chat(target_id, str(tb.get("name", "?")), "(esta demasiado lejos — no te oye)", sender_id, sender_name)
		return
	var key := "%d_%d" % [sender_id, target_id]
	var entry: Dictionary = _voice_bufs.get(key, {"pcm": PackedByteArray(), "last": 0, "sid": sender_id, "bid": target_id, "sname": sender_name})
	var buf: PackedByteArray = entry["pcm"]
	buf.append_array(pcm)
	if buf.size() > BOT_VOICE_MAX_BYTES:
		buf = buf.slice(buf.size() - BOT_VOICE_MAX_BYTES)
	entry["pcm"] = buf
	entry["last"] = Time.get_ticks_msec()
	_voice_bufs[key] = entry

# En tick(): cierra frases por silencio y recoge transcripciones del demonio.
func _voice_tick(_delta: float) -> void:
	var nowm := Time.get_ticks_msec()
	for k in _voice_bufs.keys():
		var e: Dictionary = _voice_bufs[k]
		if nowm - int(e.get("last", 0)) > BOT_VOICE_GAP_MSEC:
			_voice_bufs.erase(k)
			_voice_enqueue_job(e)
	if not _voice_jobs.is_empty():
		_voice_poll_jobs()

func _voice_enqueue_job(e: Dictionary) -> void:
	var pcm: PackedByteArray = e["pcm"]
	if pcm.size() < 1200:
		return
	var base := "v_%d_%d_%d" % [int(e["sid"]), int(e["bid"]), Time.get_ticks_msec() % 100000000]
	var dir := ProjectSettings.globalize_path(VOICE_JOBS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	if not _voice_write_wav(dir + base + ".wav", pcm, 12000):
		return
	_voice_jobs[base] = {"bot_id": int(e["bid"]), "sender_id": int(e["sid"]), "sender_name": str(e["sname"]), "born": Time.get_ticks_msec()}

func _voice_poll_jobs() -> void:
	var dir := ProjectSettings.globalize_path(VOICE_JOBS_DIR)
	var nowm := Time.get_ticks_msec()
	for base in _voice_jobs.keys():
		var job: Dictionary = _voice_jobs[base]
		var txt_path: String = dir + str(base) + ".txt"
		var wav_path: String = dir + str(base) + ".wav"
		var text := ""
		var done := FileAccess.file_exists(txt_path)
		if done:
			var f := FileAccess.open(txt_path, FileAccess.READ)
			if f != null:
				text = f.get_as_text().strip_edges()
				f.close()
		elif nowm - int(job.get("born", 0)) > 8000:
			done = true # el demonio no respondio — soltar el trabajo
		if not done:
			continue
		_voice_jobs.erase(base)
		DirAccess.remove_absolute(txt_path)
		DirAccess.remove_absolute(wav_path)
		if text.is_empty():
			continue
		var bid := int(job["bot_id"])
		var sid := int(job["sender_id"])
		var sname := str(job.get("sender_name", "?"))
		chat_log.append({"ts": int(Time.get_unix_time_from_system()), "from_id": sid, "from": sname,
			"to_id": bid, "to": _actor_display_name(bid), "kind": "voice", "text": text})
		while chat_log.size() > BOT_CHAT_LOG_MAX:
			chat_log.pop_front()
		on_chat_received(bid, sid, sname, text)

# WAV/RIFF PCM unsigned-8 mono — lo justo para que faster-whisper lo lea.
func _voice_write_wav(path: String, pcm_u8: PackedByteArray, rate: int = 12000) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm_u8.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)  # PCM
	f.store_16(1)  # mono
	f.store_32(rate)
	f.store_32(rate)
	f.store_16(1)  # block align
	f.store_16(8)  # bits
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm_u8.size())
	f.store_buffer(pcm_u8)
	f.close()
	return true

func _chat_sanitize(text: String) -> String:
	var raw := text.strip_edges()
	if raw.contains("http") or raw.contains("```"):
		return ""
	var out := ""
	for ln in raw.split("\n"):
		var l := ln.strip_edges()
		if l.is_empty():
			continue
		l = l.replace("*", "").replace("\"", "").replace("`", "")
		var colon := l.find(":")
		if colon > 0 and colon <= 16 and l.substr(0, colon).count(" ") <= 1 and not l.substr(colon).contains("/"):
			l = l.substr(colon + 1).strip_edges()
		out = l
		break
	if out.length() > 160:
		out = out.substr(0, 160)
	if out.begins_with("["):
		return ""
	return out.strip_edges()

# Envia el mensaje: queda registrado para el monitor y se entrega — a un bot
# por el mismo canal interno, a un humano por RPC via relay_actor_chat.
func _bot_chat_send(b: Dictionary, to_id: int, to_name: String, text: String, kind: String) -> void:
	var clean := _chat_sanitize(text)
	if clean.is_empty():
		clean = _chat_fallback_line(b, kind, to_name, "")
	if clean.is_empty():
		return
	var my_id := int(b["bot_id"])
	var sname := str(b.get("name", "Bot"))
	if to_name.is_empty():
		to_name = _actor_display_name(to_id)
	chat_log.append({
		"ts": int(Time.get_unix_time_from_system()), "from_id": my_id, "from": sname,
		"to_id": to_id, "to": to_name, "kind": kind, "text": clean,
	})
	while chat_log.size() > BOT_CHAT_LOG_MAX:
		chat_log.pop_front()
	var pk := _chat_pair_key(my_id, to_id)
	_chat_turns[pk] = int(_chat_turns.get(pk, 0)) + 1
	_record_milestone(my_id, "first_chat")
	if bots.has(to_id):
		on_chat_received(to_id, my_id, sname, clean)
	else:
		var net = world.get("net") if world != null else null
		if net != null and net.has_method("relay_actor_chat"):
			net.relay_actor_chat(my_id, sname, clean, to_id, to_name)

# Decide canal (Qwen si hay clave+cola libre; si no, plantilla) y aplica los
# enfriamientos. kind: reply|greet|help|alliance|whisper|taunt.
func _chat_dispatch(b: Dictionary, kind: String, to_id: int, to_name: String, ctx: String = "", intent: String = "") -> void:
	if to_id <= 0:
		return
	var my_id := int(b["bot_id"])
	var now := Time.get_ticks_msec()
	# Las respuestas siempre pasan (los turnos ya cortan el ping-pong); los
	# iniciados respetan el enfriamiento por pareja y por bot.
	if kind != "reply":
		if not _chat_pair_ok(my_id, to_id, now) or float(b.get("_chat_cd", 0.0)) > 0.0:
			return
		_chat_pair_until[_chat_pair_key(my_id, to_id)] = now + int(BOT_CHAT_PAIR_CD * 1000.0)
		b["_chat_cd"] = BOT_CHAT_CD
		if kind == "greet":
			_chat_greet_until[_chat_pair_key(my_id, to_id)] = now + int(BOT_CHAT_GREET_CD * 1000.0)
	if _chat_attempt_qwen(b, kind, to_id, to_name, ctx, intent):
		return # el mensaje sale cuando responde el modelo
	_bot_chat_send(b, to_id, to_name, _chat_fallback_line(b, kind, to_name, ctx, intent), kind)

# Triggers sociales del chat, evaluados en el paso social (~3.2 s por bot).
func _bot_chat_tick(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	if proxy == null or bool(proxy.get_meta("proxy_dead", false)) or bool(b.get("sleeping", false)):
		return
	var now := Time.get_ticks_msec()
	var my_id := int(b["bot_id"])
	# 1) Responder al ultimo mensaje recibido
	var inbox: Dictionary = b.get("_chat_inbox", {})
	if not inbox.is_empty():
		b["_chat_inbox"] = {}
		if now >= int(b.get("_chat_reply_ready", 0)):
			b["_chat_reply_ready"] = now + int(BOT_CHAT_REPLY_CD * 1000.0)
			_chat_dispatch(b, "reply", int(inbox.get("from_id", 0)), str(inbox.get("from_name", "?")), str(inbox.get("text", "")), str(inbox.get("intent", "talk")))
		return
	if float(b.get("_chat_cd", 0.0)) > 0.0 or not _chat_pending.is_empty():
		return
	var pers := _get_bot_personality(b)
	var hostile := str(b.get("faction", "")) == "hostile"
	# 2) Pedir ayuda bajo ataque — al aliado mas fiable
	if (b.get("aggro_target") != null or _sensed_node(b, "_s_foe") != null or _sensed_node(b, "_s_predator") != null) \
		and now >= int(_chat_help_until.get(my_id, 0)):
		var ally := _chat_best_ally(b)
		if not ally.is_empty():
			_chat_help_until[my_id] = now + int(BOT_CHAT_HELP_CD * 1000.0)
			_chat_dispatch(b, "help", int(ally["id"]), str(ally["name"]), _chat_threat_name(b))
			return
	# 2b) Pedir recursos (comida/agua/vendas/arma) al mejor aliado o al actor
	#     mas cercano — los amistosos ruegan, los hostiles no piden nada
	if not hostile and now >= int(_chat_req_until.get(my_id, 0)):
		var need := _chat_request_need(b)
		if not need.is_empty():
			var rec := _chat_req_recipient(b)
			if not rec.is_empty():
				_chat_req_until[my_id] = now + int(BOT_CHAT_REQ_CD * 1000.0)
				_chat_dispatch(b, "request", int(rec["id"]), str(rec["name"]), need)
				return
	var amb: Dictionary = b.get("_ambush", {})
	if hostile and not amb.is_empty():
		# 3) Susurro a un compinche cercano mientras se prepara el golpe
		var mate := _chat_nearest_mate(b, 45.0)
		if not mate.is_empty():
			_chat_dispatch(b, "whisper", int(mate["id"]), str(mate["name"]), str(amb.get("target_name", "")))
			return
		# 4) Provocar a la presa a quemarropa (solo los muy agresivos)
		var vid := int(amb.get("target_id", 0))
		var victim := _find_actor_by_peer_id(vid)
		if victim != null and is_instance_valid(victim) and float(pers.get("aggression", 0.5)) > 0.7 \
			and proxy.global_position.distance_to(victim.global_position) < 25.0:
			_chat_dispatch(b, "taunt", vid, str(amb.get("target_name", "?")))
			return
	# 5) Proponer alianza al aliado potencial que busca (_meet_id), antes de
	#    que la confianza cierre el equipo sola
	var mtid := int(b.get("_meet_id", 0))
	if mtid > 0 and not hostile and int(b.get("team_leader_id", 0)) == 0 and bots.has(mtid):
		var rel_m := get_bot_relationship(my_id, "bot_%d" % mtid)
		var tr := float(rel_m.get("trust", 0.0))
		if tr > 0.10 and tr < BOT_TEAM_FORM_TRUST + 0.12:
			_chat_dispatch(b, "alliance", mtid, _actor_display_name(mtid))
			return
	# 6) Saludo al encontrarse con alguien a quemarropa (solo sociables no hostiles)
	if not hostile and float(pers.get("sociability", 0.5)) >= 0.45:
		var cand := _chat_greet_candidate(b, now)
		if not cand.is_empty():
			_chat_dispatch(b, "greet", int(cand["id"]), str(cand["name"]))
			return

func _chat_best_ally(b: Dictionary) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var my_team := _bot_team_ids(b)
	var best := {}
	var best_s := -1.0
	for oid in bots.keys():
		if oid == my_id:
			continue
		var ob: Dictionary = bots[oid]
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var rel := get_bot_relationship(my_id, "bot_%d" % oid)
		var tr := float(rel.get("trust", 0.0))
		var in_team: bool = oid in my_team
		if (not in_team and tr < 0.25) or float(rel.get("hostility", 0.0)) > 0.5:
			continue
		var d := proxy.global_position.distance_to(op.global_position)
		var s := (10.0 if in_team else 0.0) + tr * 3.0 - d * 0.004
		if s > best_s:
			best_s = s
			best = {"id": oid, "name": str(ob.get("name", str(oid)))}
	var net = world.get("net") if world != null else null
	if net != null and "players" in net:
		for pid in net.players.keys():
			var pdata: Dictionary = net.players[pid]
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)) or bool(pdata.get("is_ai_bot", false)) or bool(pdata.get("offline", false)):
				continue
			var rel := get_bot_relationship(my_id, _actor_persist_key(int(pid)))
			if float(rel.get("trust", 0.0)) < 0.5 or float(rel.get("hostility", 0.0)) > 0.4:
				continue
			var pp := _find_actor_by_peer_id(int(pid))
			if pp == null:
				continue
			var s := float(rel.get("trust", 0.0)) * 3.0 - proxy.global_position.distance_to(pp.global_position) * 0.004
			if s > best_s:
				best_s = s
				best = {"id": int(pid), "name": str(pdata.get("char_name", pdata.get("name", "Jugador")))}
	return best

func _chat_nearest_mate(b: Dictionary, max_d: float) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var best := {}
	var best_d := max_d
	for tid in _bot_team_ids(b):
		if tid == my_id or not bots.has(tid):
			continue
		var op: Node3D = (bots[tid] as Dictionary).get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var d := proxy.global_position.distance_to(op.global_position)
		if d < best_d:
			best_d = d
			best = {"id": tid, "name": str((bots[tid] as Dictionary).get("name", str(tid)))}
	return best

func _chat_greet_candidate(b: Dictionary, now: int) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var best := {}
	var best_d := BOT_CHAT_GREET_RANGE
	for oid in bots.keys():
		if oid == my_id:
			continue
		var ob: Dictionary = bots[oid]
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var rel := get_bot_relationship(my_id, "bot_%d" % oid)
		if float(rel.get("hostility", 0.0)) > 0.4 or float(rel.get("fear", 0.0)) > 0.55:
			continue
		var d := proxy.global_position.distance_to(op.global_position)
		if d < best_d and now >= int(_chat_greet_until.get(_chat_pair_key(my_id, oid), 0)):
			best_d = d
			best = {"id": oid, "name": str(ob.get("name", str(oid)))}
	var net = world.get("net") if world != null else null
	if net != null and "players" in net:
		for pid in net.players.keys():
			var pdata: Dictionary = net.players[pid]
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)) or bool(pdata.get("is_ai_bot", false)) or bool(pdata.get("offline", false)):
				continue
			var rel := get_bot_relationship(my_id, _actor_persist_key(int(pid)))
			if float(rel.get("hostility", 0.0)) > 0.4 or float(rel.get("fear", 0.0)) > 0.55:
				continue
			var pp := _find_actor_by_peer_id(int(pid))
			if pp == null or not is_instance_valid(pp):
				continue
			var d := proxy.global_position.distance_to(pp.global_position)
			if d < best_d and now >= int(_chat_greet_until.get(_chat_pair_key(my_id, int(pid)), 0)):
				best_d = d
				best = {"id": int(pid), "name": str(pdata.get("char_name", pdata.get("name", "Jugador")))}
	return best

func _chat_threat_name(b: Dictionary) -> String:
	var pred := _sensed_node(b, "_s_predator")
	if pred != null:
		match str(pred.get("animal_type")):
			"wolf":
				return "un lobo"
			"bear":
				return "un oso"
		return "una alimana"
	var foe: Node3D = _sensed_node(b, "_s_foe")
	if foe == null:
		foe = b.get("aggro_target")
	if foe != null and is_instance_valid(foe):
		var fid := _peer_id_for_actor(foe)
		return _actor_display_name(fid) if fid > 0 else "alguien"
	return "algo"

func _chat_zone_name(pos: Vector3) -> String:
	match _poi_kind_near(pos):
		"house":
			return "el pueblo"
		"city":
			return "la ciudad"
		"military":
			return "la base militar"
		"tower":
			return "la torre"
	return "el monte"

func _chat_fallback_line(b: Dictionary, kind: String, to_name: String, ctx: String = "", intent: String = "") -> String:
	var proxy: Node3D = b["proxy"]
	var nm := to_name if not to_name.is_empty() else "tu"
	var pers := _get_bot_personality(b)
	match kind:
		"greet":
			if float(pers.get("sociability", 0.5)) > 0.7:
				return str(["Ey %s, que tal por ahi." % nm, "Buenas %s, me alegro de ver a alguien vivo." % nm][int(b["bot_id"]) % 2])
			return "Hum. %s." % nm
		"help":
			var threat := ctx if not ctx.is_empty() else "algo"
			return str(["%s encima! %s, ven, estoy en %s!" % [threat, nm, _chat_zone_name(proxy.global_position)],
				"Ayuda! Me ataca %s, en %s!" % [threat, _chat_zone_name(proxy.global_position)]][int(b["bot_id"]) % 2])
		"alliance":
			return str(["%s, nos juntamos? Dos pares de ojos ven mas." % nm,
				"Equipo, %s? Solo no se llega lejos." % nm][int(b["bot_id"]) % 2])
		"whisper":
			return str(["Quieto. Espera a que se acerque.",
				"No te muevas, casi lo tenemos."][int(b["bot_id"]) % 2])
		"taunt":
			return str(["Mala suerte, %s. Entrega lo que llevas." % nm,
				"Te veo, %s. Esa mochila me viene bien." % nm][int(b["bot_id"]) % 2])
		"request":
			match ctx:
				"comida":
					return str(["%s, tienes comida? Me estoy muriendo de hambre." % nm,
						"Pasame algo de comer, %s, por favor." % nm][int(b["bot_id"]) % 2])
				"agua":
					return str(["%s, agua... me muero de sed." % nm,
						"¿Tienes algo de beber, %s? Estoy seco." % nm][int(b["bot_id"]) % 2])
				"vendas":
					return "Estoy herido, %s, llevas vendas o un botiquin encima?" % nm
				"arma":
					return "Voy desarmado, %s. Te sobra un arma, un cuchillo, lo que sea?" % nm
			return "%s, me hace falta %s. Tienes algo?" % [nm, ctx]
		"reply":
			return _chat_fallback_reply(b, intent, nm)
	return ""

func _chat_fallback_reply(b: Dictionary, intent: String, nm: String) -> String:
	var hostile := str(b.get("faction", "")) == "hostile"
	match intent:
		"help":
			if hostile:
				return "Problema tuyo."
			return "Aguanta, voy para alla."
		"alliance":
			return "Prefiero ir solo." if (hostile or float(_get_bot_personality(b).get("distrust", 0.3)) > 0.6) else "Me apunto. Ven a buscarme."
		"greet":
			return "Buenas %s." % nm
		"threat":
			return "Vale, tranquilo." if float(_get_bot_personality(b).get("bravery", 0.5)) < 0.4 else "No me busques."
	return "Te leo, %s." % nm

func _chat_ensure_http() -> void:
	if _chat_http != null and is_instance_valid(_chat_http):
		return
	_chat_http = HTTPRequest.new()
	_chat_http.timeout = 10.0
	_chat_http.request_completed.connect(_chat_on_response)
	add_child(_chat_http)

# Redacta el mensaje con Qwen (una peticion en vuelo, comparte la cuota diaria
# con las decisiones). Devuelve false y el llamador usa la plantilla local.
func _chat_attempt_qwen(b: Dictionary, kind: String, to_id: int, to_name: String, ctx: String, intent: String) -> bool:
	if not _chat_pending.is_empty() or not _ai_can_query_remote():
		return false
	var key := OS.get_environment("GROQ_API_KEY").strip_edges()
	if key.is_empty() or _ai_calls_day >= ai_max_calls_per_day or _ai_tokens_day >= ai_max_tokens_per_day:
		return false
	_chat_ensure_http()
	_chat_pending = {"bot_id": int(b["bot_id"]), "to_id": to_id, "to_name": to_name, "kind": kind, "intent": intent}
	_ai_calls_day += 1
	_ai_calls_total += 1
	var payload := {
		"model": AI_ADVISOR_MODEL,
		"temperature": 0.85,
		"max_tokens": 60,
		"messages": [
			{"role": "system", "content": BOT_CHAT_SYSTEM_PROMPT},
			{"role": "user", "content": _chat_build_prompt(b, kind, to_id, to_name, ctx, intent)},
		],
	}
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key])
	if _chat_http.request(AI_ADVISOR_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		_chat_pending = {}
		return false
	return true

func _chat_build_prompt(b: Dictionary, kind: String, to_id: int, to_name: String, ctx: String, intent: String) -> String:
	var proxy: Node3D = b["proxy"]
	var pers := _get_bot_personality(b)
	var my_id := int(b["bot_id"])
	var to_key := ("bot_%d" % to_id) if bots.has(to_id) else _actor_persist_key(to_id)
	var rel := get_bot_relationship(my_id, to_key)
	var tr := float(rel.get("trust", 0.0))
	var ho := float(rel.get("hostility", 0.0))
	var rel_desc := "un desconocido"
	if tr > 0.5:
		rel_desc = "aliado de confianza"
	elif tr > 0.15:
		rel_desc = "conocido amistoso"
	elif ho > 0.5:
		rel_desc = "tu enemigo"
	elif ho > 0.2:
		rel_desc = "alguien que te cae mal"
	var sit := ""
	match kind:
		"greet":
			sit = "Te cruzas con %s de cerca. Saludale por el chat." % to_name
		"help":
			sit = "Te ataca %s y necesitas que %s venga a socorrerte. Escribe el grito de ayuda mencionando que estas en %s." % [ctx, to_name, _chat_zone_name(proxy.global_position)]
		"alliance":
			sit = "Te acercas a %s y quieres proponerle hacer equipo para sobrevivir juntos." % to_name
		"whisper":
			sit = "Preparas una emboscada contra %s junto a %s. Dale la orden en una frase susurrada." % [ctx, to_name]
		"taunt":
			sit = "Estas a punto de atacar a %s para robarle. Escribe una frase intimidante." % to_name
		"request":
			sit = "Te falta %s de verdad y le pides ayuda a %s. Escribele la peticion, breve y natural." % [ctx, to_name]
		"reply":
			var intent_txt: String = {"help": "te pide ayuda", "alliance": "te propone hacer equipo", "greet": "te saluda", "threat": "te amenaza"}.get(intent, "te escribe")
			sit = "%s %s. Su mensaje: \"%s\". Responde segun tu caracter y tu relacion con el." % [to_name, intent_txt, ctx]
	return "Eres %s, superviviente %s en Last Day. Caracter: valentia %.2f, agresividad %.2f, sociable %.2f, desconfianza %.2f.\nEstado: vida %d, hambre %d, sed %d. Zona: %s. Llevas: %s.\n%s es %s (confianza %.2f, hostilidad %.2f).\n%s" % [
		str(b.get("name", "Bot")), str(b.get("faction", "friendly")),
		float(pers.get("bravery", 0.5)), float(pers.get("aggression", 0.5)),
		float(pers.get("sociability", 0.5)), float(pers.get("distrust", 0.3)),
		int(float(b.get("health", 100))), int(float(b.get("hunger", 80))), int(float(b.get("thirst", 80))),
		_chat_zone_name(proxy.global_position), str(b.get("held_item", "las manos")),
		to_name, rel_desc, tr, ho, sit]

func _chat_on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var req := _chat_pending
	_chat_pending = {}
	if req.is_empty():
		return
	var bid := int(req.get("bot_id", 0))
	if not bots.has(bid):
		return
	var b: Dictionary = bots[bid]
	var to_id := int(req.get("to_id", 0))
	var to_name := str(req.get("to_name", ""))
	var kind := str(req.get("kind", "talk"))
	var intent := str(req.get("intent", ""))
	var text := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var usage = parsed.get("usage", {})
			var tok := int((usage as Dictionary).get("total_tokens", 140)) if usage is Dictionary else 140
			_ai_tokens_day += maxi(tok, 60)
			_ai_tokens_total += maxi(tok, 60)
			var ch = parsed.get("choices", [])
			if ch is Array and not (ch as Array).is_empty():
				var msg = (ch[0] as Dictionary).get("message", {})
				if msg is Dictionary:
					text = str((msg as Dictionary).get("content", ""))
	else:
		_ai_tokens_day += 60
		_ai_tokens_total += 60
	text = _chat_sanitize(text)
	if text.is_empty():
		text = _chat_fallback_line(b, kind, to_name, "", intent)
	_bot_chat_send(b, to_id, to_name, text, kind)

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
		var gitem := {"name": gname, "type": gtype, "quantity": 1, "weight": 0.5, "use_value": 0.0}
		if not _bot_try_add_inventory_item(b, inv_give, gitem):
			# Mochila llena: el objeto no se pierde — cae a los pies del bot
			_bot_drop_to_ground(b, gitem)
			return "%s no puede cargar %s — lo deja en el suelo." % [bname, gname]
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
		b["sleeping"] = false
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
		# No le cabe en la mochila (slots/peso del modelo humano): ni lo mira
		if not _bot_would_fit(b, proxy.get_meta("saved_inventory", []), _loot_entry_item_dict(entry)):
			continue
		# Orden "equip": solo armas, ropa y mochilas — comida y materiales no
		if bool(b.get("equip_mission", false)) and not _is_gear_item(nm, tp):
			continue
		var pos := _loot_entry_pos(entry)
		var dy_loot := absf(pos.y - proxy.global_position.y)
		var flat_d := Vector2(pos.x - proxy.global_position.x, pos.z - proxy.global_position.z).length()
		# Permitir botín en pisos superiores de las casas de la ciudad, el bloque
		# de 4 plantas y la Torre del Reloj cuando el bot está junto o dentro del
		# edificio: primero limpia su planta actual (penalización suave por dy) y
		# luego sube las escaleras para saquear los pisos superiores.
		if dy_loot > 2.4 and flat_d > 18.0:
			continue
		if _is_goal_blacklisted(b, pos):
			continue
		var d_sq := proxy.global_position.distance_squared_to(pos)
		if d_sq > r_sq and not (dy_loot > 2.4 and flat_d <= 18.0):
			continue
		# Un superviviente prioriza: arma/medicina > comida > equipo > materiales
		# > reserva de agua. La distancia y el cambio de planta desempatan.
		var score := _loot_priority(b, nm, tp) * 1000.0 - flat_d - dy_loot * 14.0
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
	if tp in ["tool_hoe", "tool_shovel"]:
		return 3.6
	if nm == "Semillas":
		return 3.8
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
	# Azada/Pala: herramienta de huerto — interesa siempre (una por bot);
	# no hace falta refugio para cultivar un bancal.
	if tp in ["tool_hoe", "tool_shovel"]:
		return _bot_wants_farm_tool(b)
	# Semillas de arbusto o de cosecha: solo sirven si puede cultivarlas.
	if nm == "Semillas":
		return _bot_wants_seeds(b)
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
	# Mochilas: cualquier modelo sirve, pero solo se recoge si es mejor que la
	# que ya lleva equipada (sin mochila < pequeña < militar) — nunca repuestos.
	if tp == "backpack" or nm.begins_with("Mochila"):
		return _backpack_tier(nm) > _backpack_tier(str(b["backpack"]))
	if tp == "clothing":
		if PlayerController.CLOTHING_SLOTS.has(nm):
			var slot := str(PlayerController.CLOTHING_SLOTS[nm])
			var cur := _worn_in_slot(str(b.get("clothing", "")).split(","), slot)
			var pr := int(CLOTHING_PRIORITY.get(nm, 0))
			# Mejora real sobre lo que lleva puesto: siempre interesa.
			if pr > int(CLOTHING_PRIORITY.get(cur, 0)):
				return true
			# Tras aprender, ropa decente (>=4) vale como repuesto: maximo una
			# por slot y sin acaparar prendas sueltas en la mochila.
			if bool(b.get("_mem", {}).get("gear_learned", false)) and pr >= 4 and _bot_slot_spare_count(b["proxy"], slot) < 1 and _bot_spare_clothing_count(b["proxy"]) < 2:
				return true
		# Ropa cortable -> Trapos (Pantalones/Camiseta/militares...): solo si
		# necesita trapos y no lleva ya prendas pendientes de cortar — dos
		# piezas bastan para varios trapos; mas seria recoger por recoger.
		if _bot_wants_craft_input(b, nm):
			return _bot_spare_clothing_count(b["proxy"]) < 2
	return false

# Nivel de mochila para decidir si recogerla/equiparla mejora al bot:
# sin mochila = 0 < Mochila pequena/Mochila = 1 < Mochila militar = 2.
func _backpack_tier(nm: String) -> int:
	if nm == "Mochila militar":
		return 2
	if nm.begins_with("Mochila"):
		return 1
	return 0

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
	b["anim"] = "stairs" if (absf(np.y - pos.y) > delta * 0.14 and not bool(b.get("has_rifle", false))) else "walk"
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
	# Capacidad como el jugador humano (slots/peso por ropa y mochila). Si no
	# le cabe, el objeto se queda en el mundo — ira a descargar a su refugio.
	var enm := str(entry.get("name", ""))
	var etp := str(entry.get("type", "resource"))
	if inv.size() >= 60 and not _is_gear_item(enm, etp):
		b["_s_loot"] = {}
		return
	var item_dict := _loot_entry_item_dict(entry)
	if not _bot_try_add_inventory_item(b, inv, item_dict):
		b["_s_loot"] = {}
		return
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
	# Id unico por construccion: el refugio viejo queda en pie (huerfano
	# saqueable) si el bot levanta otro lejos tras reaparecer.
	var sh_id := "bot_shelter_%d_%d" % [int(b["bot_id"]), int(Time.get_unix_time_from_system())]
	var yaw := float(b["rot"])
	b["shelter_id"] = sh_id
	b["shelter_pos"] = pos
	b["no_fire_spot"] = false
	# El refugio es suyo y lo recuerda — sobrevive a la muerte dentro de la
	# misma sesion de mundo (el alijo tambien se conserva).
	_ensure_bot_memory(int(b["bot_id"]))["shelter"] = {"id": sh_id, "pos": [pos.x, pos.y, pos.z]}
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
	# Al terminar de levantar su refugio, guarda ya el botin sobrante.
	_bot_sync_own_shelter_stash(b)

func _shelter_entry_pos(sh: Dictionary) -> Vector3:
	var p = sh.get("pos", Vector3.ZERO)
	if p is Vector3:
		return p
	if p is Array and p.size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return Vector3.ZERO

func _find_shelter_dict(sh_id: String) -> Dictionary:
	if sh_id.is_empty() or world == null or not ("_built_shelters" in world):
		return {}
	for sh in world._built_shelters:
		if sh is Dictionary and str(sh.get("id", "")) == sh_id:
			return sh
	return {}

func _get_shelter_contents(sh_id: String) -> Array:
	var sh := _find_shelter_dict(sh_id)
	if sh.is_empty():
		return []
	var c = sh.get("contents", [])
	return (c as Array).duplicate(true) if c is Array else []

func _commit_shelter_contents(sh_id: String, contents: Array) -> void:
	if sh_id.is_empty() or world == null:
		return
	var sh := _find_shelter_dict(sh_id)
	if not sh.is_empty():
		sh["contents"] = contents
	if "world_actions_by_id" in world and world.world_actions_by_id.has(sh_id):
		var act = world.world_actions_by_id[sh_id]
		if act != null and is_instance_valid(act):
			act.set_meta("contents", contents)
	if world.has_method("_set_backpack_entry_contents"):
		world._set_backpack_entry_contents(sh_id, contents)
	if world.has_method("_broadcast_backpack_contents"):
		world._broadcast_backpack_contents(sh_id, contents)
	if world.has_method("_save_world_change_silent"):
		world._save_world_change_silent()

# Busca refugios ajenos cercanos que tengan objetos deseables en su alijo.
func _find_nearby_raidable_shelter(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("_built_shelters" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var own_id := str(b.get("shelter_id", ""))
	var leader_id := int(b.get("team_leader_id", 0))
	# El alijo del lider tambien es sagrado — y si el lider es un bot su
	# refugio usa el prefijo bot_shelter_, no player_shelter_.
	var leader_sh := ("bot_shelter_%d" if is_bot_peer_id(leader_id) else "player_shelter_%d") % leader_id if leader_id > 0 else ""
	var best: Dictionary = {}
	var best_d := radius
	for sh in world._built_shelters:
		if not (sh is Dictionary):
			continue
		var sid := str(sh.get("id", ""))
		# El alijo propio y el del lider son sagrados (el lider puede tener
		# varios refugios: ids unicos, compara por prefijo).
		if sid.is_empty() or sid == own_id or (not leader_sh.is_empty() and sid.begins_with(leader_sh)):
			continue
		var spos := _shelter_entry_pos(sh)
		if _is_goal_blacklisted(b, spos):
			continue
		var d := Vector2(proxy.global_position.x - spos.x, proxy.global_position.z - spos.z).length()
		if d > best_d:
			continue
		var has_wanted := false
		var contents = sh.get("contents", [])
		if contents is Array:
			for cd in contents:
				if cd is Dictionary and _is_loot_desirable(b, str(cd.get("name", "")), str(cd.get("type", "resource"))):
					has_wanted = true
					break
		if has_wanted or _bot_wants_salvage(b, sh):
			best_d = d
			best = sh
	return best

# Roba los objetos utiles de un refugio ajeno y sincroniza el alijo con clientes.
func _bot_raid_shelter(b: Dictionary, sh_entry: Dictionary) -> int:
	var sid := str(sh_entry.get("id", ""))
	var sh := _find_shelter_dict(sid)
	if sh.is_empty():
		return 0
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var contents: Array = (sh.get("contents", []) as Array).duplicate(true)
	var stolen := 0
	for i in range(contents.size() - 1, -1, -1):
		if inv.size() >= 60:
			break
		var cd = contents[i]
		if not (cd is Dictionary):
			continue
		var nm := str(cd.get("name", ""))
		var tp := str(cd.get("type", "resource"))
		var qty := maxi(1, int(cd.get("quantity", cd.get("qty", 1))))
		var took_from_stack := 0
		while qty > 0 and _is_loot_desirable(b, nm, tp):
			var one: Dictionary = (cd as Dictionary).duplicate(true)
			one["quantity"] = 1
			if not _bot_try_add_inventory_item(b, inv, one):
				break # mochila llena: el resto se queda en el refugio ajeno
			proxy.set_meta("saved_inventory", inv)
			qty -= 1
			took_from_stack += 1
			stolen += 1
		if took_from_stack > 0:
			if qty <= 0:
				contents.remove_at(i)
			else:
				contents[i]["quantity"] = qty
			_ai_note_loot(b, nm, tp)
	if stolen > 0:
		_commit_shelter_contents(sid, contents)
		_auto_equip_best_gear(b)
		var best_w := _best_weapon_name(proxy)
		if not best_w.is_empty() and not bool(b["torch_lit"]):
			b["held_item"] = best_w
			b["has_rifle"] = best_w == "Fusil de asalto" or best_w == "Rifle francotirador"
			proxy.set_meta("saved_held_item", best_w)
		record_bot_event(int(b["bot_id"]), "raid_shelter", sid, "shelter", _shelter_entry_pos(sh), "stolen:%d" % stolen)
		_record_milestone(int(b["bot_id"]), "first_raid")
	return stolen

# Quiere desmontar un refugio ajeno: sin casa propia aprovecha los palos para
# levantar otra lejos; los hostiles desmontan por negacion. Igual que el
# jugador, no se desmonta si lleva camo ni forro de pieles.
func _bot_wants_salvage(b: Dictionary, sh: Dictionary) -> bool:
	if bool(sh.get("camo_covered", false)) or bool(sh.get("pelt_lined", false)):
		return false
	if str(b.get("shelter_id", "")).is_empty():
		return true
	return str(b.get("faction", "")) == "hostile"

# Si el refugio cumple las reglas de desmontaje del jugador, lo vacia (lo que
# no le sirve cae al suelo como drops reales) y arma el temporizador de 3 s.
func _bot_try_dismantle_shelter(b: Dictionary, sh_entry: Dictionary) -> bool:
	var sid := str(sh_entry.get("id", ""))
	var sh := _find_shelter_dict(sid)
	if sh.is_empty() or not _bot_wants_salvage(b, sh):
		return false
	var contents: Array = sh.get("contents", [])
	for cd in contents:
		if cd is Dictionary:
			_bot_drop_to_ground(b, {"name": str(cd.get("name", "")), "type": str(cd.get("type", "resource")), "weight": float(cd.get("weight", 0.3)), "quantity": maxi(1, int(cd.get("quantity", cd.get("qty", 1)))), "use_value": float(cd.get("use_value", cd.get("use", 0.0)))})
	if not contents.is_empty():
		_commit_shelter_contents(sid, [])
	b["_salvage"] = {"id": sid, "t": 0.0}
	return true

# Replica server-side del _execute_shelter_dismantle del jugador: quita el
# modelo y el registro, suelta los 11 palos (a mochila o al suelo) y lo
# transmite a los clientes conectados.
func _bot_dismantle_shelter_exec(b: Dictionary, sh_id: String) -> void:
	var sh := _find_shelter_dict(sh_id)
	if sh.is_empty() or world == null:
		return
	var proxy: Node3D = b["proxy"]
	var sticks := {"name": "Palo", "type": "material", "weight": 0.3, "quantity": 11, "use_value": 0.0}
	var inv: Array = proxy.get_meta("saved_inventory", [])
	if not _bot_try_add_inventory_item(b, inv, sticks):
		_bot_drop_to_ground(b, sticks)
	var stick_names := ["PlayerShelter_%s" % sh_id, "PlayerShelter_%s_SupportA" % sh_id, "PlayerShelter_%s_SupportB" % sh_id,
		"PlayerShelter_%s_Net" % sh_id, "PlayerShelter_%s_PeltLining" % sh_id, "PlayerShelter_%s_CamoNet" % sh_id]
	for i in range(9):
		stick_names.append("PlayerShelter_%s_Roof_%d" % [sh_id, i])
	for sn in stick_names:
		var sn_node := world.get_node_or_null(sn)
		if sn_node != null:
			sn_node.queue_free()
	if "_built_shelters" in world:
		for i in range(world._built_shelters.size() - 1, -1, -1):
			if world._built_shelters[i] is Dictionary and str(world._built_shelters[i].get("id", "")) == sh_id:
				world._built_shelters.remove_at(i)
	if "world_actions_by_id" in world and world.world_actions_by_id.has(sh_id):
		var act = world.world_actions_by_id[sh_id]
		if act != null and is_instance_valid(act):
			if world.has_method("_hide_action_visual"):
				world._hide_action_visual(act)
			act.mark_depleted()
		world.world_actions_by_id.erase(sh_id)
	if "_depleted_action_ids" in world and not world._depleted_action_ids.has(sh_id):
		world._depleted_action_ids.append(sh_id)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if int(pid) != int(net.get_my_id()) and not is_bot_peer_id(int(pid)) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.shelter_dismantled.rpc_id(int(pid), sh_id)
	if world.has_method("_save_world_change_silent"):
		world._save_world_change_silent()
	_record_milestone(int(b["bot_id"]), "first_dismantle")
	record_bot_event(int(b["bot_id"]), "shelter_dismantle", sh_id, "shelter", _shelter_entry_pos(sh), "desmonta refugio por los palos")

func _own_shelter_has_needed_item(b: Dictionary) -> bool:
	var sid := str(b.get("shelter_id", ""))
	var contents := _get_shelter_contents(sid)
	if contents.is_empty():
		return false
	var proxy: Node3D = b["proxy"]
	var need_food: bool = float(b["hunger"]) < 60.0 and not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0)
	var need_water: bool = float(b["thirst"]) < 60.0 and not _bot_has_drink(proxy)
	var need_weapon: bool = _best_weapon_name(proxy).is_empty()
	var need_med: bool = float(b["health"]) < 78.0 and _bot_item_count(proxy, "Venda") == 0
	for cd in contents:
		if not (cd is Dictionary):
			continue
		var nm := str(cd.get("name", ""))
		var tp := str(cd.get("type", ""))
		if need_food and tp == "food":
			return true
		if need_water and (tp == "water" or nm.contains("agua") or nm.contains("Cantimplora")):
			return true
		if need_weapon and tp in ["weapon", "weapon_rifle", "weapon_bow", "tool_axe", "tool_spear"]:
			return true
		if need_med and nm == "Venda":
			return true
	return false

# Calcula que entradas del inventario actual son sobrantes para guardar en el
# refugio propio (conservando encima su mejor arma, su municion, 1 filo,
# 1 comida de reserva, 1 bebida y 2 vendas).
func _bot_count_storable_items(b: Dictionary) -> int:
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	if inv.is_empty():
		return 0
	var contents := _get_shelter_contents(str(b.get("shelter_id", "")))
	if contents.size() >= 18:
		return 0
	var plan := _bot_partition_inventory_for_shelter(b, inv)
	return (plan.get("store", []) as Array).size()

func _bot_partition_inventory_for_shelter(b: Dictionary, inv: Array) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var best_w := _best_weapon_name(proxy)
	var cutters := ["Cuchillo", "Cuchillo de piedra", "Cuchillo de hueso", "Hacha", "Hacha de piedra", "Piedra afilada"]
	var kept_primary := false
	var kept_cutter: bool = best_w in cutters
	var kept_bola := false
	var kept_torch := false
	var kept_matches := false
	var food_kept := 0
	var drink_kept := 0
	var med_kept := 0
	var has_cf := not str(b.get("campfire_id", "")).is_empty() or bool(b.get("no_fire_spot", false))
	var stick_cap := 2 if has_cf else 4
	var stone_cap := 1 if has_cf else 2
	var stick_kept := 0
	var stone_kept := 0
	var keep: Array = []
	var store: Array = []
	for raw_it in inv:
		if not (raw_it is Dictionary):
			continue
		var it: Dictionary = (raw_it as Dictionary).duplicate(true)
		var nm := str(it.get("name", ""))
		var tp := str(it.get("type", "resource"))
		var qty := maxi(1, int(it.get("quantity", 1)))
		if tp == "backpack":
			keep.append(it)
			continue
		if not best_w.is_empty() and nm == best_w and not kept_primary:
			kept_primary = true
			if qty > 1:
				var k1 := it.duplicate(true); k1["quantity"] = 1; keep.append(k1)
				var s1 := it.duplicate(true); s1["quantity"] = qty - 1; store.append(s1)
			else:
				keep.append(it)
			continue
		if nm in cutters and not kept_cutter:
			kept_cutter = true
			if qty > 1:
				var kc := it.duplicate(true); kc["quantity"] = 1; keep.append(kc)
				var sc := it.duplicate(true); sc["quantity"] = qty - 1; store.append(sc)
			else:
				keep.append(it)
			continue
		if nm == "Boleadoras" and not kept_bola:
			kept_bola = true
			keep.append(it)
			continue
		if nm == "Antorcha" and not kept_torch:
			kept_torch = true
			keep.append(it)
			continue
		if nm == "Cerillas" and not kept_matches:
			kept_matches = true
			keep.append(it)
			continue
		if tp in ["ammo", "ammo_arrow"]:
			var keep_ammo := (best_w == "Fusil de asalto" and (nm == "Cargador de M4" or nm == "Balas 5.56")) \
				or (best_w == "Rifle francotirador" and nm == "Cargador de fusil") \
				or (best_w in ["Arco de madera", "Arco reforzado"] and tp == "ammo_arrow")
			if keep_ammo:
				keep.append(it)
			else:
				store.append(it)
			continue
		if tp in ["weapon", "weapon_rifle", "weapon_bow", "tool_axe", "tool_spear", "tool_hoe", "tool_shovel"]:
			if nm == "Palo afilado" and _bot_has_raw_meat(proxy):
				keep.append(it)
			else:
				store.append(it)
			continue
		if tp == "food":
			if nm == "Carne ensartada" or nm == "Pez ensartado" or (nm.begins_with("Carne cruda") and _bot_item_count(proxy, "Palo afilado") > 0):
				keep.append(it)
				continue
			if food_kept < 1:
				var take_k := mini(1 - food_kept, qty)
				food_kept += take_k
				var kf := it.duplicate(true); kf["quantity"] = take_k; keep.append(kf)
				if qty - take_k > 0:
					var sf := it.duplicate(true); sf["quantity"] = qty - take_k; store.append(sf)
			else:
				store.append(it)
			continue
		if tp == "water" or nm.contains("agua") or nm.contains("Cantimplora") or nm == "Botella de plastico":
			if drink_kept < 1:
				drink_kept += 1
				var kd := it.duplicate(true); kd["quantity"] = 1; keep.append(kd)
				if qty > 1:
					var sd := it.duplicate(true); sd["quantity"] = qty - 1; store.append(sd)
			else:
				store.append(it)
			continue
		if nm == "Venda" or tp == "medical":
			if med_kept < 2:
				var take_m := mini(2 - med_kept, qty)
				med_kept += take_m
				var km := it.duplicate(true); km["quantity"] = take_m; keep.append(km)
				if qty - take_m > 0:
					var sm := it.duplicate(true); sm["quantity"] = qty - take_m; store.append(sm)
			else:
				store.append(it)
			continue
		if nm == "Palo":
			if stick_kept < stick_cap:
				var take_st := mini(stick_cap - stick_kept, qty)
				stick_kept += take_st
				var kst := it.duplicate(true); kst["quantity"] = take_st; keep.append(kst)
				if qty - take_st > 0:
					var sst := it.duplicate(true); sst["quantity"] = qty - take_st; store.append(sst)
			else:
				store.append(it)
			continue
		if nm == "Piedra":
			if stone_kept < stone_cap:
				var take_sn := mini(stone_cap - stone_kept, qty)
				stone_kept += take_sn
				var ksn := it.duplicate(true); ksn["quantity"] = take_sn; keep.append(ksn)
				if qty - take_sn > 0:
					var ssn := it.duplicate(true); ssn["quantity"] = qty - take_sn; store.append(ssn)
			else:
				store.append(it)
			continue
		store.append(it)
	# Si lo que se queda encima supera su capacidad real (slots/peso por ropa
	# y mochila, igual que el jugador), lo mas prescindible pasa al refugio.
	var cap := _bot_carry_capacity(b)
	var guard := 0
	while guard < 64 and (_bot_inv_stored_count(keep) > int(cap["slots"]) or _bot_inv_total_weight(keep) > float(cap["weight"]) + 0.001):
		guard += 1
		var idx := _bot_least_essential_index(b, keep)
		if idx < 0:
			break
		store.append(keep[idx])
		keep.remove_at(idx)
	return {"keep": keep, "store": store}

# Retira lo que necesite de su propio refugio y guarda alli todo el loot sobrante.
func _bot_sync_own_shelter_stash(b: Dictionary) -> int:
	var sid := str(b.get("shelter_id", ""))
	if sid.is_empty():
		return 0
	var sh := _find_shelter_dict(sid)
	if sh.is_empty():
		return 0
	var proxy: Node3D = b["proxy"]
	var inv: Array = (proxy.get_meta("saved_inventory", []) as Array).duplicate(true)
	var contents: Array = (sh.get("contents", []) as Array).duplicate(true)
	var changed := false
	var moved := 0
	# 1) Retirar del refugio propio si al bot le falta comida, bebida, arma o venda
	for i in range(contents.size() - 1, -1, -1):
		var cd = contents[i]
		if not (cd is Dictionary):
			continue
		var nm := str(cd.get("name", ""))
		var tp := str(cd.get("type", "resource"))
		var want_withdraw := false
		if tp == "food" and float(b["hunger"]) < 60.0 and not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0):
			want_withdraw = true
		elif (tp == "water" or nm.contains("agua") or nm.contains("Cantimplora")) and float(b["thirst"]) < 60.0 and not _bot_has_drink(proxy):
			want_withdraw = true
		elif tp in ["weapon", "weapon_rifle", "weapon_bow", "tool_axe", "tool_spear"] and _best_weapon_name(proxy).is_empty():
			want_withdraw = true
		elif nm == "Venda" and _bot_item_count(proxy, "Venda") == 0:
			want_withdraw = true
		if want_withdraw:
			var one: Dictionary = (cd as Dictionary).duplicate(true)
			one["quantity"] = 1
			if not _bot_try_add_inventory_item(b, inv, one):
				continue # no le cabe: se queda guardado en su refugio
			proxy.set_meta("saved_inventory", inv)
			var rem := int(cd.get("quantity", 1)) - 1
			if rem <= 0:
				contents.remove_at(i)
			else:
				contents[i]["quantity"] = rem
			changed = true
			moved += 1
	# 2) Guardar en el refugio propio todo el botin sobrante (hasta 18 huecos)
	var part := _bot_partition_inventory_for_shelter(b, inv)
	var keep_inv: Array = part["keep"]
	var to_store: Array = part["store"]
	for st_item in to_store:
		var sdict: Dictionary = st_item
		if contents.size() < 18 or (world != null and world.has_method("_stash_can_merge") and world._stash_can_merge(contents, sdict)):
			if world != null and world.has_method("_stash_merge_or_append"):
				world._stash_merge_or_append(contents, sdict)
			else:
				_bot_add_inventory_item(contents, sdict)
			changed = true
			moved += int(sdict.get("quantity", 1))
		else:
			keep_inv.append(sdict)
	if changed:
		proxy.set_meta("saved_inventory", keep_inv)
		_commit_shelter_contents(sid, contents)
		_auto_equip_best_gear(b)
		var best_w := _best_weapon_name(proxy)
		b["held_item"] = best_w if not bool(b["torch_lit"]) else "Antorcha"
		b["has_rifle"] = best_w == "Fusil de asalto" or best_w == "Rifle francotirador"
		proxy.set_meta("saved_held_item", b["held_item"])
	return moved

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

func _find_nearby_campfire_spot(b: Dictionary, origin: Vector3) -> Vector3:
	for off in [Vector3(2.8, 0.0, 1.4), Vector3(-2.8, 0.0, 1.4), Vector3(0.0, 0.0, 3.2), Vector3(2.8, 0.0, -1.4), Vector3(0.0, 0.0, -3.2), Vector3(4.2, 0.0, 0.0), Vector3(-4.2, 0.0, 0.0)]:
		var cand: Vector3 = origin + off
		cand.y = _ground_y(cand.x, cand.z)
		if _is_flat_dry_pos(cand, str(b.get("shelter_id", ""))):
			return cand
	return Vector3.INF

func _nearest_lit_campfire_pos(from_pos: Vector3, max_dist: float) -> Vector3:
	if world == null or not ("_lit_campfires" in world):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := max_dist
	for lc in world._lit_campfires:
		if lc is Dictionary and lc.get("pos") is Vector3:
			var cp: Vector3 = lc["pos"]
			var d := Vector2(from_pos.x - cp.x, from_pos.z - cp.z).length()
			if d < best_d:
				best_d = d
				best = cp
	return best

# Cocinar carne cruda igual que el jugador humano: exige ensartar primero la
# carne en un Palo afilado ("Carne ensartada") y cocinarla en una hoguera
# encendida (propia o cercana; si no hay y tiene 2 Palos + 2 Piedras, arma y
# enciende una hoguera en el sitio).
func _bot_try_cook_meat(b: Dictionary, delta: float) -> bool:
	if float(b.get("cook_cooldown", 0.0)) > 0.0:
		return false
	var proxy: Node3D = b["proxy"]
	if not _bot_can_cook_raw_meat(proxy):
		return false
	var cur := proxy.global_position
	var fire_pos := _nearest_lit_campfire_pos(cur, 85.0)
	var cf_pos: Vector3 = b.get("campfire_pos", Vector3.INF)
	if fire_pos == Vector3.INF and cf_pos != Vector3.INF and Vector2(cur.x - cf_pos.x, cur.z - cf_pos.z).length() < 110.0:
		fire_pos = cf_pos
	if fire_pos == Vector3.INF:
		if not _can_bot_build_campfire(proxy):
			return false
		var base_origin: Vector3 = b.get("shelter_pos", Vector3.INF)
		if base_origin == Vector3.INF or Vector2(cur.x - base_origin.x, cur.z - base_origin.z).length() > 35.0:
			base_origin = cur
		var spot := _find_nearby_campfire_spot(b, base_origin)
		if spot == Vector3.INF:
			spot = cur + Vector3(2.2, 0.0, 0.0)
			spot.y = _ground_y(spot.x, spot.z)
		_bot_build_and_light_campfire(b, spot)
		fire_pos = spot
	# Ensartar la carne cruda o pescado crudo con el Palo afilado antes de acercarla al fuego
	if not _bot_skewer_raw_meat(proxy):
		return false
	var held_skewer := "Pez ensartado" if _bot_item_count(proxy, "Pez ensartado") > 0 else "Carne ensartada"
	var d_fire := Vector2(cur.x - fire_pos.x, cur.z - fire_pos.z).length()
	if d_fire > 2.4:
		b["sitting"] = false
		b["crouching"] = false
		b["held_item"] = held_skewer
		proxy.set_meta("saved_held_item", held_skewer)
		_move_bot_towards(b, fire_pos, 4.0, delta, "walk")
		return true
	if cf_pos != Vector3.INF and Vector2(fire_pos.x - cf_pos.x, fire_pos.z - cf_pos.z).length() < 2.5:
		_ensure_bot_campfire_lit(b)
	b["held_item"] = held_skewer
	proxy.set_meta("saved_held_item", held_skewer)
	b["sitting"] = true
	b["crouching"] = false
	b["anim"] = "sit"
	return _bot_cook_meat_at_fire(b)

func _bot_cook_meat_at_fire(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	# Regla idéntica al jugador humano: no se puede cocinar carne cruda ni
	# pescado crudo sin ensartarlos en un Palo afilado ("Carne ensartada" / "Pez ensartado").
	if not _bot_skewer_raw_meat(proxy):
		return false
	var skewered := ""
	var is_fish := false
	if _bot_item_count(proxy, "Carne ensartada") > 0:
		skewered = "Carne ensartada"
	elif _bot_item_count(proxy, "Pez ensartado") > 0:
		skewered = "Pez ensartado"
		is_fish = true
	if skewered.is_empty():
		return false
	if _consume_bot_item(proxy, skewered, 1):
		var inv: Array = proxy.get_meta("saved_inventory", [])
		if is_fish:
			_bot_add_inventory_item(inv, {"name": "Pez cocinado", "type": "food", "weight": 0.35, "quantity": 1, "use_value": 30.0})
		else:
			_bot_add_inventory_item(inv, {"name": "Carne asada en palo", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 28.0})
		proxy.set_meta("saved_inventory", inv)
		b["cook_cooldown"] = 12.0
		return true
	return false

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
					var col = hit.get("collider")
					if col is Node and (col as Node).is_in_group("stair_surface"):
						return false
					var nrm: Vector3 = hit.get("normal", Vector3.UP)
					if nrm.y > 0.42:
						return false
					return true
	return false

const CT_ORIGIN := Vector3(41.0, 0.0, 750.0)

func _is_in_clock_tower(pos: Vector3, margin: float = 0.2) -> bool:
	return absf(pos.x - CT_ORIGIN.x) <= 9.0 + margin and absf(pos.z - CT_ORIGIN.z) <= 8.0 + margin and pos.y >= -0.4 and pos.y <= 34.5

func _find_city_building_for_pos(pos: Vector3, margin: float = 0.25) -> int:
	for i in range(CityBlock.BUILDINGS.size()):
		var def: Dictionary = CityBlock.BUILDINGS[i]
		if not (def.get("position") is Vector3):
			continue
		var b_origin: Vector3 = CityExpansion.CENTER + (def["position"] as Vector3)
		var yaw: float = float(def.get("yaw", 0.0))
		var fp: Vector2 = def.get("footprint", Vector2(6.0, 6.0))
		var h_max: float = float(def.get("interior_height", 7.9)) + 1.2
		var lc := (pos - b_origin).rotated(Vector3.UP, -yaw)
		if absf(lc.x) <= fp.x + margin and absf(lc.z) <= fp.y + margin and lc.y >= -0.4 and lc.y <= h_max:
			return i
	return -1

func _is_in_any_building_3d(pos: Vector3) -> bool:
	if _is_in_clock_tower(pos, 0.35):
		return true
	if _find_city_building_for_pos(pos, 0.35) >= 0:
		return true
	if world != null and world.has_method("_is_player_in_house") and bool(world._is_player_in_house(pos)):
		return true
	return false

func _try_open_building_door(b: Dictionary, cur: Vector3, door_world: Vector3) -> bool:
	if world == null or not world.has_method("bot_try_open_door_at"):
		return false
	if Vector2(cur.x - door_world.x, cur.z - door_world.z).length() > 4.8:
		return false
	if world.bot_try_open_door_at(door_world) or world.bot_try_open_door_at(cur):
		b["path"] = []
		b["path_timer"] = 0.0
		return true
	return false

func _is_city_building_door_open(b_idx: int, door_world: Vector3) -> bool:
	if world == null:
		return true
	var dname := "city_%02d_door" % (b_idx + 1)
	if "_server_door_states" in world and (world._server_door_states as Dictionary).has(dname):
		if bool((world._server_door_states as Dictionary)[dname]):
			return true
	if "wildlife_blockers" in world:
		for blk in world.wildlife_blockers:
			if blk is Dictionary and int((blk as Dictionary).get("city_building_index", -1)) == b_idx:
				if world.has_method("_check_door_open"):
					return bool(world._check_door_open((blk as Dictionary).get("door", null), blk))
				return bool((blk as Dictionary).get("door_open", false))
	return false

# Resuelve el paso exacto de entrada/salida por puertas y de subida/bajada por
# escaleras en:
# 1) Torre del Reloj de la ciudad (7 tramos en zigzag hasta 29.46 m)
# 2) Bloque de 4 plantas city_17 (3 tramos hasta 11.82 m)
# 3) Las 16 viviendas de 2 plantas city_01..city_16 (planta alta 3.92 m y azotea)
# 4) Torre de vigilancia militar (_watchtower_climb)
# 5) Casas del pueblo (Casa abandonada 1..10)
func _resolve_building_interior_waypoint(b: Dictionary, cur: Vector3, goal: Vector3) -> Vector3:
	# 1) Torre del Reloj (41, 0, 750)
	var cur_ct := _is_in_clock_tower(cur, 0.25)
	var goal_ct := _is_in_clock_tower(goal, 0.8)
	if cur_ct or goal_ct:
		return _resolve_clock_tower_waypoint(cur, goal, cur_ct, goal_ct)

	# 2) Edificios de la ciudad (city_01..city_17, 2 y 4 plantas con escaleras)
	var cur_cb := _find_city_building_for_pos(cur, 0.25)
	var goal_cb := _find_city_building_for_pos(goal, 0.85)
	if cur_cb >= 0 or goal_cb >= 0:
		var target_cb := cur_cb if (cur_cb >= 0 and (goal_cb < 0 or cur_cb != goal_cb)) else goal_cb
		return _resolve_city_building_waypoint(b, cur, goal, target_cb, cur_cb == target_cb, goal_cb == target_cb)

	# 3) Torre de vigilancia militar (_watchtower_climb) cuando el objetivo o el
	# compañero humano está en la torre (o el bot necesita bajar de ella)
	if world != null and "_watchtower_climb" in world:
		var wtc = world.get("_watchtower_climb")
		if wtc is Array and (wtc as Array).size() >= 2:
			var wps: Array = wtc
			var foot_wp: Vector3 = wps[0]
			var cur_near_wt: bool = Vector2(cur.x - foot_wp.x, cur.z - foot_wp.z).length() <= 7.5 and cur.y >= foot_wp.y - 0.5
			var goal_on_wt: bool = Vector2(goal.x - foot_wp.x, goal.z - foot_wp.z).length() <= 7.5 and goal.y > foot_wp.y + 0.6
			if goal_on_wt or (cur_near_wt and cur.y > foot_wp.y + 0.6):
				return _resolve_watchtower_waypoint(cur, goal, wps, goal_on_wt)

	# 4) Casas del pueblo y resto de bloqueadores con puerta (house_bounds)
	return _resolve_door_approach_goal(b, cur, goal)

func _resolve_clock_tower_waypoint(cur: Vector3, goal: Vector3, cur_in: bool, goal_in: bool) -> Vector3:
	var lc := cur - CT_ORIGIN
	if not cur_in and goal_in:
		# Entrada norte frente a la plaza (x=0, z=-8.0)
		if lc.z > -7.8 or absf(lc.x) > 1.45:
			return CT_ORIGIN + Vector3(0.0, 0.06, -10.2)
		return CT_ORIGIN + Vector3(0.0, 0.06, -5.2)
	var lg := (goal - CT_ORIGIN) if goal_in else Vector3(0.0, 0.06, -5.2)
	var goal_lvl := clampi(int(round((lg.y - 0.06) / 4.2)), 0, 7)
	# Ascenso piso a piso (tramos 0..6): un tramo fl solo se da por terminado
	# cuando el bot alcanza tanto la altura y1 como el rellano final |z| >= 4.35.
	if lg.y > lc.y + 0.35:
		var landing_bonus := 0.22 if absf(lc.z) >= 4.35 else -0.02
		var fl := clampi(int(floor((lc.y - 0.06 + landing_bonus) / 4.2)), 0, 6)
		fl = mini(fl, maxi(0, goal_lvl - 1))
		var lane_x := 4.7 if (fl % 2 == 0) else 2.35
		var z_start := -5.0 if (fl % 2 == 0) else 5.0
		var z_end := 5.0 if (fl % 2 == 0) else -5.0
		var y0 := float(fl) * 4.2 + 0.06
		var y1 := float(fl + 1) * 4.2 + 0.06
		if lc.x >= 1.2 and absf(lc.x - lane_x) <= 0.65 and absf(lc.z - z_start) > 0.55:
			return CT_ORIGIN + Vector3(lane_x, y1, z_end)
		if lc.x < 1.25:
			if absf(lc.z - z_start) > 0.75:
				return CT_ORIGIN + Vector3(0.2, y0, z_start)
			return CT_ORIGIN + Vector3(lane_x, y0, z_start)
		if absf(lc.z - z_start) > 0.85:
			return CT_ORIGIN + Vector3(0.2, y0, z_start)
		if absf(lc.x - lane_x) > 0.45:
			return CT_ORIGIN + Vector3(lane_x, y0, z_start)
		return CT_ORIGIN + Vector3(lane_x, y1, z_end)
	# Descenso piso a piso (tramos 6..0)
	if lg.y < lc.y - 0.35:
		var desc_bonus := -0.22 if absf(lc.z) >= 4.35 else 0.02
		var fl_d := clampi(int(ceil((lc.y - 0.06 + desc_bonus) / 4.2)) - 1, 0, 6)
		var lane_xd := 4.7 if (fl_d % 2 == 0) else 2.35
		var z_top_d := 5.0 if (fl_d % 2 == 0) else -5.0
		var z_bot_d := -5.0 if (fl_d % 2 == 0) else 5.0
		var y_cur := float(fl_d + 1) * 4.2 + 0.06
		var y_prev := float(fl_d) * 4.2 + 0.06
		if lc.x >= 1.2 and absf(lc.x - lane_xd) <= 0.65 and absf(lc.z - z_top_d) > 0.55:
			return CT_ORIGIN + Vector3(lane_xd, y_prev, z_bot_d)
		if lc.x < 1.25:
			if absf(lc.z - z_top_d) > 0.75:
				return CT_ORIGIN + Vector3(0.2, y_cur, z_top_d)
			return CT_ORIGIN + Vector3(lane_xd, y_cur, z_top_d)
		if absf(lc.z - z_top_d) > 0.85:
			return CT_ORIGIN + Vector3(0.2, y_cur, z_top_d)
		if absf(lc.x - lane_xd) > 0.45:
			return CT_ORIGIN + Vector3(lane_xd, y_cur, z_top_d)
		return CT_ORIGIN + Vector3(lane_xd, y_prev, z_bot_d)
	var cur_lvl := clampi(int(round((lc.y - 0.06) / 4.2)), 0, 7)
	# Misma planta en la Torre del Reloj
	if not goal_in:
		# Ya en planta 0 (cur_lvl == 0) y saliendo al exterior por el pórtico norte
		if lc.x > 1.25:
			if lc.z > -4.2:
				return CT_ORIGIN + Vector3(4.7, 0.06, -5.0)
			return CT_ORIGIN + Vector3(0.0, 0.06, -5.2)
		if absf(lc.x) > 1.35 or lc.z > -4.2:
			return CT_ORIGIN + Vector3(0.0, 0.06, -5.2)
		return CT_ORIGIN + Vector3(0.0, 0.06, -10.2)
	var y_fl := float(cur_lvl) * 4.2 + 0.06
	if cur_lvl == 7:
		if lc.x > 1.3 and lg.x <= 1.2 and lc.z > 2.2:
			return CT_ORIGIN + Vector3(0.6, y_fl, 3.0)
		return goal
	if cur_lvl > 0 and lc.x >= 1.2 and lg.x < 1.2:
		var pass_z := 5.0 if lc.z >= 0.0 else -5.0
		if absf(lc.z - pass_z) > 0.75:
			return CT_ORIGIN + Vector3(lc.x, y_fl, pass_z)
		return CT_ORIGIN + Vector3(0.2, y_fl, pass_z)
	if cur_lvl == 0 and lc.x > 1.25 and lg.x <= 1.2:
		return CT_ORIGIN + Vector3(0.4, 0.06, -5.0)
	return goal

func _resolve_city_building_waypoint(b: Dictionary, cur: Vector3, goal: Vector3, b_idx: int, cur_in: bool, goal_in: bool) -> Vector3:
	var def: Dictionary = CityBlock.BUILDINGS[b_idx]
	var b_origin: Vector3 = CityExpansion.CENTER + (def["position"] as Vector3)
	var yaw: float = float(def.get("yaw", 0.0))
	var lc := (cur - b_origin).rotated(Vector3.UP, -yaw)
	var door_world := b_origin + Vector3(0.15, 0.12, 6.08).rotated(Vector3.UP, yaw)
	var is_open := _is_city_building_door_open(b_idx, door_world)
	if not is_open and _try_open_building_door(b, cur, door_world):
		is_open = true
	if not cur_in and goal_in:
		if not is_open or lc.z < 5.75 or absf(lc.x - 0.15) > 0.65 or lc.z > 8.8:
			return b_origin + Vector3(0.15, 0.12, 8.3).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(0.15, 0.12, 4.6).rotated(Vector3.UP, yaw)
	var lg := (goal - b_origin).rotated(Vector3.UP, -yaw) if goal_in else Vector3(0.15, 0.12, 4.6)
	# Bloque de 4 plantas (city_17, b_idx == 16)
	if int(def.get("floors", 2)) > 2:
		if lc.x <= -1.85 and absf(lc.z) < 4.3:
			var fl_h := clampi(int(floor((lc.y - 0.16 + 0.25) / 3.9)), 0, 2)
			if lg.y >= lc.y - 0.2:
				return b_origin + Vector3(-3.0, 0.16 + float(fl_h + 1) * 3.9, -5.0).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(-3.0, 0.16 + float(fl_h) * 3.9, 5.0).rotated(Vector3.UP, yaw)
		var cur_lvl_h := clampi(int(round((lc.y - 0.16) / 3.9)), 0, 3)
		var goal_lvl_h := clampi(int(round((lg.y - 0.16) / 3.9)), 0, 3)
		var y_cur_h := 0.16 + float(cur_lvl_h) * 3.9
		if goal_lvl_h > cur_lvl_h:
			var y_next_h := 0.16 + float(cur_lvl_h + 1) * 3.9
			if lc.x <= -1.85 and lc.z < -3.8:
				return b_origin + Vector3(-0.8, y_cur_h, -4.8).rotated(Vector3.UP, yaw)
			if lc.x > -1.85 and lc.z < 4.3:
				return b_origin + Vector3(-0.8, y_cur_h, 4.8).rotated(Vector3.UP, yaw)
			if lc.x > -2.35 and lc.z >= 4.3:
				return b_origin + Vector3(-3.0, y_cur_h, 4.8).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(-3.0, y_next_h, -5.0).rotated(Vector3.UP, yaw)
		if goal_lvl_h < cur_lvl_h:
			var y_prev_h := 0.16 + float(cur_lvl_h - 1) * 3.9
			if lc.x <= -1.85 and lc.z > 3.8:
				return b_origin + Vector3(-0.8, y_cur_h, 4.8).rotated(Vector3.UP, yaw)
			if lc.x > -1.85 and lc.z > -4.3:
				return b_origin + Vector3(-0.8, y_cur_h, -4.8).rotated(Vector3.UP, yaw)
			if lc.x > -2.35 and lc.z <= -4.3:
				return b_origin + Vector3(-3.0, y_cur_h, -4.8).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(-3.0, y_prev_h, 5.0).rotated(Vector3.UP, yaw)
		if not goal_in:
			if lc.x <= -1.85:
				return b_origin + Vector3(-0.8, 0.16, 4.8).rotated(Vector3.UP, yaw)
			if lc.z < 4.2 or absf(lc.x - 0.15) > 0.65:
				return b_origin + Vector3(0.15, 0.16, 4.6).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(0.15, 0.16, 8.3).rotated(Vector3.UP, yaw)
		if lc.x <= -1.85 and lg.x > -1.85:
			return b_origin + Vector3(-0.8, y_cur_h, -4.8 if lc.z < 0.0 else 4.8).rotated(Vector3.UP, yaw)
		if cur_lvl_h > 0 and (lc.z - 0.1) * (lg.z - 0.1) < 0.0 and (lc.x > 0.35 or lg.x > 0.35):
			if absf(lc.z - 0.1) > 0.55 or lc.x > 0.35:
				return b_origin + Vector3(-0.4, y_cur_h, 0.1).rotated(Vector3.UP, yaw)
		return goal
	# Viviendas de 2 plantas (city_01..city_16)
	var flat_roof := (b_idx % 4 == 1 or b_idx % 4 == 2)
	var stair_x := 5.15 if flat_roof else 4.5
	if lc.x >= 3.5 and lc.z > -2.3 and lc.z < 4.2 and lc.y < 4.5:
		if lg.y > 2.0:
			return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(stair_x, 0.12, 4.7).rotated(Vector3.UP, yaw)
	if flat_roof and lc.x >= 3.1 and lc.x <= 4.45 and lc.z > -2.3 and lc.z < 4.3 and lc.y >= 3.6:
		if lg.y > 6.0:
			return b_origin + Vector3(3.85, 7.86, 4.8).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
	var cur_lvl_c := 0 if lc.y < 2.2 else (1 if lc.y < 6.0 else 2)
	var goal_lvl_c := 0 if lg.y < 2.2 else (1 if (lg.y < 6.0 or not flat_roof) else 2)
	if cur_lvl_c == 0 and goal_lvl_c >= 1:
		if lc.x < 3.8:
			if lc.z < 3.8:
				return b_origin + Vector3(-0.2, 0.12, 4.7).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(stair_x, 0.12, 4.7).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 1 and goal_lvl_c == 0:
		if lc.x < 3.8:
			if lc.z > -2.2:
				return b_origin + Vector3(1.6, 3.92, -3.0).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(stair_x, 0.12, 4.7).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 1 and goal_lvl_c == 2:
		if lc.x < 3.2:
			if lc.z > -2.2:
				return b_origin + Vector3(1.6, 3.92, -3.0).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
		if absf(lc.x - 3.85) > 0.45 and lc.z <= -2.2:
			return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(3.85, 7.86, 4.8).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 2 and goal_lvl_c < 2:
		if absf(lc.x - 3.85) > 0.55 or lc.z < 4.2:
			return b_origin + Vector3(3.85, 7.86, 4.8).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
	if not goal_in:
		if lc.z < 4.2 or absf(lc.x - 0.15) > 0.65:
			return b_origin + Vector3(0.15, 0.12, 4.6).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(0.15, 0.12, 8.3).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 1 and lc.x > 2.3 and lg.x <= 2.3:
		return b_origin + Vector3(1.6, 3.92, -3.0).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 0 and lc.x > 3.5 and lg.x <= 3.5:
		return b_origin + Vector3(0.15, 0.12, 4.7).rotated(Vector3.UP, yaw)
	return goal

func _resolve_watchtower_waypoint(cur: Vector3, goal: Vector3, wps: Array, goal_on_wt: bool) -> Vector3:
	var foot_wp: Vector3 = wps[0]
	if goal_on_wt and cur.y < foot_wp.y - 0.15 and Vector2(cur.x - foot_wp.x, cur.z - foot_wp.z).length() > 1.2:
		return foot_wp
	var best_i := 0
	var best_d := 1e9
	for i in range(wps.size()):
		var wp: Vector3 = wps[i]
		var d := Vector2(cur.x - wp.x, cur.z - wp.z).length() + absf(cur.y - wp.y) * 2.2
		if d < best_d:
			best_d = d
			best_i = i
	if goal_on_wt:
		if absf(cur.y - goal.y) <= 0.9 and Vector2(cur.x - goal.x, cur.z - goal.z).length() <= 3.5:
			return goal
		return wps[mini(best_i + 1, wps.size() - 1)]
	if best_i == 0 and Vector2(cur.x - foot_wp.x, cur.z - foot_wp.z).length() <= 1.2:
		return goal
	return wps[maxi(0, best_i - 1)]

# Si el objetivo esta dentro de una casa cuya puerta esta cerrada (y el bot
# esta fuera, p. ej. al norte/detras del edificio), redirige primero al umbral
# exterior alineado con el centro del vano para que la bordee, la abra al
# llegar (<4.8 m) y cruce recto el vano en vez de chocar contra el muro.
func _resolve_door_approach_goal(b: Dictionary, cur: Vector3, goal: Vector3) -> Vector3:
	if world == null or not ("wildlife_blockers" in world) or not world.has_method("bot_try_open_door_at"):
		return goal
	var p_cur := Vector2(cur.x, cur.z)
	var p_goal := Vector2(goal.x, goal.z)
	for blk in world.wildlife_blockers:
		if not (blk is Dictionary) or not (blk as Dictionary).has("house_bounds"):
			continue
		var dblk: Dictionary = blk
		if bool(dblk.get("barn_door_always_open", false)):
			continue
		var hb: Rect2 = dblk["house_bounds"]
		var cur_in := hb.grow(-0.25).has_point(p_cur)
		var goal_in := hb.grow(0.8).has_point(p_goal)
		if cur_in == goal_in:
			continue
		var bpos: Vector3 = dblk.get("pos", Vector3.ZERO)
		var dc: Vector3 = world._blocker_door_center(dblk, bpos, hb) if world.has_method("_blocker_door_center") else dblk.get("door_center", dblk.get("door_pos", Vector3.INF))
		var dpos: Vector3 = dblk.get("door_pos", dc)
		var door_obj = dblk.get("door", null)
		if not dc.is_finite() and door_obj is Node3D and is_instance_valid(door_obj):
			dc = (door_obj as Node3D).global_position
			dpos = dc
		if not dc.is_finite():
			continue
		var out_dir: Vector2 = world._blocker_door_out_dir(dblk, bpos, hb) if world.has_method("_blocker_door_out_dir") else dblk.get("door_out_dir", Vector2(0.0, 1.0))
		if out_dir.length_squared() < 0.01:
			out_dir = Vector2(0.0, 1.0)
		var side_dir := Vector2(-out_dir.y, out_dir.x)
		var rel := p_cur - Vector2(dc.x, dc.z)
		var along := rel.dot(out_dir)
		var across := absf(rel.dot(side_dir))
		var is_open: bool = bool(world._check_door_open(door_obj, dblk)) if world.has_method("_check_door_open") else bool(dblk.get("door_open", false))
		var d_door := minf(p_cur.distance_to(Vector2(dc.x, dc.z)), p_cur.distance_to(Vector2(dpos.x, dpos.z)))
		if not is_open and d_door <= 4.8:
			if world.bot_try_open_door_at(dpos) or world.bot_try_open_door_at(dc) or world.bot_try_open_door_at(cur):
				b["path"] = []
				b["path_timer"] = 0.0
				is_open = true
		if goal_in:
			if not is_open or along < -0.25 or across > 0.65 or along > 3.0:
				return Vector3(dc.x + out_dir.x * 2.4, cur.y, dc.z + out_dir.y * 2.4)
			if along > -0.8:
				return Vector3(dc.x - out_dir.x * 1.4, cur.y, dc.z - out_dir.y * 1.4)
			return goal
		# Saliendo de la casa al exterior: alinearse primero con el vano interior
		# y cruzar recto hacia fuera.
		if not is_open or across > 0.65 or along < -1.8:
			return Vector3(dc.x - out_dir.x * 1.2, cur.y, dc.z - out_dir.y * 1.2)
		return Vector3(dc.x + out_dir.x * 2.4, cur.y, dc.z + out_dir.y * 2.4)
	return goal

# Guia de ascenso y descenso por la carretera asfaltada en espiral hacia la
# Base Militar de la Cima (HighMountainZone, cota +56 m): un humano no escala
# el acantilado en linea recta ni se tira desde 56 m; sube y baja siguiendo los
# puntos de get_road_polyline_3d() desde el pie (-252, 0.8, -268) hasta la
# entrada sureste de la base (-356, 56, -356).
func _resolve_mountain_road_waypoint(cur: Vector3, goal: Vector3) -> Vector3:
	var on_summit_cur: bool = cur.x < -315.0 and cur.z < -315.0 and cur.y >= 48.0
	var goal_is_summit: bool = goal.x < -290.0 and goal.z < -290.0 and goal.y >= 20.0
	var on_road_slope: bool = not on_summit_cur and cur.x < -210.0 and cur.z < -210.0 and ((cur.x < -235.0 and cur.z < -235.0) or cur.y > 4.0)
	if not goal_is_summit and not on_summit_cur and not on_road_slope:
		return goal
	if on_summit_cur and goal_is_summit:
		return goal
	var pts := HighMountainZone.get_road_polyline_3d()
	if pts.size() < 70:
		return goal
	var foot_idx := 64 # (-252.0, 0.8, -268.0) pie de la montaña
	var top_idx := pts.size() - 1 # (-356.0, 56.0, -356.0) puerta sureste de la base
	if goal_is_summit:
		# Ascenso: desde el valle ir primero al pie de la carretera (foot_idx)
		if not on_road_slope and Vector2(cur.x - pts[foot_idx].x, cur.z - pts[foot_idx].z).length() > 14.0:
			return pts[foot_idx]
		var best_i := foot_idx
		var best_d := 1e9
		for i in range(foot_idx, pts.size()):
			var p: Vector3 = pts[i]
			var d := Vector2(cur.x - p.x, cur.z - p.z).length() + absf(cur.y - p.y) * 2.5
			if d < best_d:
				best_d = d
				best_i = i
		if best_i >= top_idx - 1 and Vector2(cur.x - pts[top_idx].x, cur.z - pts[top_idx].z).length() < 9.0:
			return goal
		return pts[mini(best_i + 3, top_idx)]
	# Descenso: desde la meseta o la ladera hacia el valle
	if on_summit_cur and Vector2(cur.x - pts[top_idx].x, cur.z - pts[top_idx].z).length() > 8.0:
		return pts[top_idx]
	var best_i2 := top_idx
	var best_d2 := 1e9
	for i in range(foot_idx, pts.size()):
		var p2: Vector3 = pts[i]
		var d2 := Vector2(cur.x - p2.x, cur.z - p2.z).length() + absf(cur.y - p2.y) * 2.5
		if d2 < best_d2:
			best_d2 = d2
			best_i2 = i
	if best_i2 <= foot_idx + 1 and Vector2(cur.x - pts[foot_idx].x, cur.z - pts[foot_idx].z).length() < 10.0:
		return goal
	return pts[maxi(foot_idx, best_i2 - 3)]

func _move_bot_towards(b: Dictionary, raw_goal: Vector3, speed: float, delta: float, anim_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	var road_goal := _resolve_mountain_road_waypoint(cur, raw_goal)
	var goal := _resolve_building_interior_waypoint(b, cur, road_goal)
	var on_mountain_3d: bool = road_goal != raw_goal or (cur.x < -235.0 and cur.z < -235.0 and cur.y > 2.0)
	var flat_dist := Vector2(goal.x - cur.x, goal.z - cur.z).length()
	var in_building_3d: bool = not on_mountain_3d and (_is_in_any_building_3d(cur) or (goal != road_goal and flat_dist <= 8.5))
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
	var direct_blocked := _is_step_blocked(cur, cur + (goal - cur).normalized() * minf(flat_dist, 1.5)) if (flat_dist > 0.2 and not in_building_3d) else false
	# Usar la malla de navegacion en exterior cuando el objetivo este a >3.5 m o
	# haya un obstaculo directo; dentro de edificios/escaleras/vanos seguir los
	# waypoints 3D exactos sin cuantizarlos a la rejilla de 2.0 m.
	var bot_nav_ref = world.get("bot_nav") if world != null else null
	if bot_nav_ref == null and world != null:
		bot_nav_ref = world.get("wolf_nav")
	if in_building_3d or (on_mountain_3d and (cur.x < -235.0 and cur.z < -235.0)):
		nav_guided = true
	elif (flat_dist > 3.5 or direct_blocked) and bot_nav_ref != null:
		var path: Array = b["path"]
		if path.is_empty() or float(b["path_timer"]) <= 0.0:
			b["path"] = bot_nav_ref.find_path(cur, goal)
			b["path_idx"] = 0
			b["path_timer"] = 1.8
			path = b["path"]
		var pidx := int(b["path_idx"])
		# Si find_path devuelve un unico punto (_nearest_free_cell) que queda
		# MAS LEJOS del objetivo que la posicion actual, el nav esta intentando
		# tirar hacia atras desde el margen de un rio o edificio: ignorar ese
		# retroceso evita el pendulo infinito de 6 m en la orilla.
		if path.size() == 1 and Vector2(path[0].x - goal.x, path[0].z - goal.z).length() >= flat_dist - 0.2:
			pidx = 1
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
	if not in_building_3d and world != null and world.has_method("get_river_depth_at"):
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
	if not in_building_3d and (depth_next > WADE_DEPTH or (not nav_guided and depth_ahead > WADE_DEPTH)) and depth_cur <= WADE_DEPTH:
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
				_abandon_unreachable_goal(b, raw_goal)
			return
	var to_next := Vector3(next_goal.x - cur.x, 0.0, next_goal.z - cur.z)
	var d := to_next.length()
	if d < 0.05:
		b["anim"] = "idle"
		return
	var dir := to_next / d
	# Sumar repulsion suave de bloqueadores cercanos solo en exterior libre:
	# dentro de edificios, escaleras o umbrales de puerta empujaria contra el marco.
	if not in_building_3d and world != null and world.has_method("get_wildlife_avoidance_vector_at"):
		b["avoid_t"] = float(b.get("avoid_t", 0.0)) - delta
		if float(b["avoid_t"]) <= 0.0:
			b["avoid_t"] = 0.15
			b["_avoid"] = world.get_wildlife_avoidance_vector_at(cur)
		var av: Vector3 = b.get("_avoid", Vector3.ZERO)
		av.y = 0.0
		if av.length_squared() > 0.001:
			dir = (dir + av.normalized() * 0.55).normalized()
	# Suavizado de rumbo y aceleracion (mas agil en rellanos de escalera/puertas)
	var sm: Vector3 = b.get("_mdir", Vector3.ZERO)
	var turn_rate := 18.0 if in_building_3d else 7.0
	sm = sm + (dir - sm) * minf(1.0, delta * turn_rate)
	if sm.length_squared() > 0.001:
		sm = sm.normalized()
	b["_mdir"] = sm
	var on_stair_segment: bool = in_building_3d and absf(next_goal.y - cur.y) > 0.25
	var eff_speed := minf(speed, 3.2) if on_stair_segment else speed
	# Sobrepeso: frena igual que al jugador humano (walk * (1 - carry * 0.2))
	var carry_ratio := _bot_carry_ratio(b)
	if carry_ratio > 0.0:
		eff_speed *= 1.0 - carry_ratio * 0.2
	var spd := move_toward(float(b.get("_speed", 0.0)), eff_speed * (0.45 if depth_cur > 0.12 else 1.0), delta * (11.0 if in_building_3d else 6.5))
	b["_speed"] = spd
	var step := minf(spd * delta, d)
	var chosen_dir := dir if in_building_3d else (sm if sm.length_squared() > 0.001 else dir)
	var new_pos := cur + chosen_dir * step
	var front_blocked := false if on_stair_segment else _is_step_blocked(cur, new_pos)
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
	var gy := _ground_y(new_pos.x, new_pos.z, cur.y)
	if on_stair_segment or (in_building_3d and absf(next_goal.y - cur.y) > 0.01):
		var t_ramp := clampf(step / maxf(d, 0.01), 0.0, 1.0)
		var ramp_y := lerpf(cur.y, next_goal.y, t_ramp)
		new_pos.y = ramp_y if absf(gy - ramp_y) > 0.4 else (maxf(gy, ramp_y) if next_goal.y > cur.y else minf(gy, ramp_y))
	elif in_building_3d and cur.y > 1.8 and gy < cur.y - 1.5:
		new_pos.y = cur.y
	else:
		new_pos.y = gy
	proxy.global_position = new_pos
	proxy.set_meta("saved_pos", new_pos)
	b["pos"] = new_pos
	b["rot"] = lerp_angle(float(b["rot"]), atan2(-chosen_dir.x, -chosen_dir.z), minf(1.0, delta * 8.0))
	proxy.rotation.y = float(b["rot"])
	var climbing_stairs_now: bool = on_stair_segment or (in_building_3d and absf(new_pos.y - cur.y) > delta * 0.16)
	b["anim"] = ("stairs" if not bool(b.get("has_rifle", false)) else "walk") if climbing_stairs_now else anim_name
	proxy.set_meta("crouching", bool(b.get("crouching", false)))
	proxy.set_meta("prone", bool(b.get("prone", false)))
	proxy.set_meta("sprinting", anim_name == "run" and not climbing_stairs_now)
	proxy.set_meta("moving", anim_name == "walk" or anim_name == "run" or climbing_stairs_now)
	# Deteccion real de atasco: mide el avance 3D acumulado durante la ventana
	# completa de 2.0 s (incluyendo ascenso vertical en escaleras).
	b["stuck_timer"] = float(b["stuck_timer"]) + delta
	if float(b["stuck_timer"]) >= 2.0:
		var last_pos: Vector3 = b.get("last_move_pos", cur)
		var moved: float = new_pos.distance_to(last_pos)
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
				_abandon_unreachable_goal(b, raw_goal)
		else:
			b["stuck_count"] = 0
	# Detector de oscilacion (macro-progreso 3D cada 6 s): usa distancia 3D para
	# que subir escaleras en zigzag (donde X/Z vuelve al mismo rellano un piso
	# mas arriba) nunca se confunda con un bucle en el sitio.
	b["macro_timer"] = float(b.get("macro_timer", 0.0)) + delta
	if not b.has("macro_pos"):
		b["macro_pos"] = cur
	if float(b["macro_timer"]) >= 6.0:
		var mpos: Vector3 = b.get("macro_pos", cur)
		var macro_moved: float = new_pos.distance_to(mpos)
		b["macro_pos"] = new_pos
		b["macro_timer"] = 0.0
		if macro_moved < 3.0 and cur.distance_to(raw_goal) > 4.0:
			b["avoid_sign"] = -float(b.get("avoid_sign", 1.0))
			_abandon_unreachable_goal(b, raw_goal)

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

# --- Supervivencia de bot identica a la del jugador humano -----------------
# Cada bot lleva una instancia real de SurvivalStats (la misma clase que el
# jugador): hambre, sed, energia, sueño, temperatura corporal, lluvia/nieve,
# vadeo, calor de fogata/antorcha, abrigo de la ropa y muerte por inanicion,
# deshidratacion, hipotermia, calor o agotamiento. La IA sigue decidiendo sobre
# b["hunger"]/b["thirst"]/b["health"]; este puente sincroniza ambos lados.

func _bot_weather_observation() -> Dictionary:
	var net = world.get("net") if world != null else null
	if net != null and bool(net.get("is_connected")):
		var aw = net.get("authoritative_weather")
		if aw is Dictionary and not (aw as Dictionary).is_empty():
			return aw
		# Antes de la primera observacion real publicada por un cliente, el
		# servidor usa el mismo estado neutro nublado que para los jugadores.
		return {"weather_code": 3, "temperature": -999.0, "rain": 0.0, "snow": 0.0,
			"cloud_cover": 0.88, "wind_speed": 0.0, "wind_direction": 0.0}
	return {}

# Bajo techo: refugio propio/ajeno construido, o casa con la puerta cerrada.
func _bot_is_sheltered(b: Dictionary, pos: Vector3) -> bool:
	var sh_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
	if sh_pos != Vector3.INF and pos.distance_to(sh_pos) < 3.4:
		return true
	if world.has_method("_is_near_built_shelter") and world._is_near_built_shelter(pos):
		return true
	if world.has_method("_is_player_in_house") and world._is_player_in_house(pos):
		if world.has_method("_is_in_open_house") and world._is_in_open_house(pos):
			return false
		return true
	return false

# Fraccion de lluvia que llega a la piel: mismo modelo cubierta/filtracion
# del jugador (CLOTHING_SLOTS + SLOT_WET_WEIGHT + CLOTHING_WATER_RESIST).
func _bot_skin_wet_factor(b: Dictionary) -> float:
	var worn_slots := {}
	for nm in str(b["clothing"]).split(",", false):
		var cn := nm.strip_edges()
		var slot := str(PlayerController.CLOTHING_SLOTS.get(cn, ""))
		if not slot.is_empty() and not worn_slots.has(slot):
			worn_slots[slot] = cn
	var covered := 0.0
	var covered_leaky := 0.0
	for slot in PlayerController.SLOT_WET_WEIGHT.keys():
		var w_slot := float(PlayerController.SLOT_WET_WEIGHT[slot])
		if worn_slots.has(slot):
			covered += w_slot
			covered_leaky += w_slot * (1.0 - float(PlayerController.CLOTHING_WATER_RESIST.get(worn_slots[slot], 0.0)))
	return clampf((1.0 - covered) + 0.2 * covered_leaky, 0.0, 1.0)

func _bot_is_freezing(b: Dictionary) -> bool:
	var st: SurvivalStats = b.get("vstats")
	return st != null and not st.dead and st.body_temperature < 35.2

func _bot_is_exhausted(b: Dictionary) -> bool:
	var st: SurvivalStats = b.get("vstats")
	return st != null and not st.dead and st.sleep < 14.0

func _bot_survival_tick(b: Dictionary, delta: float) -> void:
	var st: SurvivalStats = b.get("vstats")
	var proxy: Node3D = b["proxy"]
	if st == null or st.dead:
		return
	# Las acciones de la IA (comer, beber, vendas, daño recibido) viven en b y
	# en los metas del proxy: se vuelcan al modelo humano antes de simular.
	st.health = clampf(float(b["health"]), 0.0, st.max_health)
	st.hunger = clampf(float(b["hunger"]), 0.0, st.max_stat)
	st.thirst = clampf(float(b["thirst"]), 0.0, st.max_stat)
	var b_sick_t := float(b.get("sick_timer", 0.0))
	st.sick = b_sick_t > 0.0
	st.sick_timer = maxf(float(st.sick_timer), b_sick_t)
	var pos: Vector3 = proxy.global_position
	var dc = world.get("day_cycle")
	var obs := _bot_weather_observation()
	var is_night := _is_world_night()
	var ambient_temp := float(obs.get("temperature", -999.0))
	if ambient_temp <= -900.0:
		ambient_temp = float(dc.call("get_ambient_temperature")) if dc != null and dc.has_method("get_ambient_temperature") else 15.0
	var sheltered := _bot_is_sheltered(b, pos)
	var shelter_warmth := 0.0
	if world.has_method("_is_near_pelt_lined_shelter") and world._is_near_pelt_lined_shelter(pos):
		ambient_temp += 2.5
		shelter_warmth += 0.45
	if world.has_method("_is_near_camo_covered_shelter") and world._is_near_camo_covered_shelter(pos):
		ambient_temp += 2.0
		shelter_warmth += 0.35
	# Abrigo/proteccion termica de la ropa equipada (mismas tablas que el
	# jugador; la ropa empapada abriga menos, la piel casi nada pierde).
	var wet := clampf(st.wetness, 0.0, 1.0)
	var warmth_sum := 0.0
	var heat_prot := 0.0
	var heat_ret := 0.0
	for nm in str(b["clothing"]).split(",", false):
		var cn := nm.strip_edges()
		if cn.is_empty():
			continue
		var w := float(PlayerController.CLOTHING_WARMTH.get(cn, 0.0))
		if w > 0.0:
			var retain: float = PlayerController.WET_WARMTH_RETAIN_PELT if PlayerController.CLOTHING_WATER_RESIST.has(cn) else PlayerController.WET_WARMTH_RETAIN
			warmth_sum += w * lerpf(1.0, retain, wet)
		heat_prot = maxf(heat_prot, float(PlayerController.CLOTHING_HEAT_PROTECTION.get(cn, 0.0)))
		heat_ret += float(PlayerController.CLOTHING_HEAT_RETENTION.get(cn, 0.0))
	st.warmth_bonus = warmth_sum
	st.heat_protection_bonus = heat_prot
	st.heat_retention_bonus = heat_ret

	# Lluvia y nieve empapan como al jugador; bajo techo no moja. Vadear el
	# rio/lago cala mucho mas rapido.
	if not sheltered:
		var rain_amt := float(obs.get("rain", 0.0))
		var snow_amt := float(obs.get("snow", 0.0))
		if rain_amt > 0.1 or snow_amt > 0.05:
			var wet_gain := delta * 0.20 * clampf(rain_amt * 0.5, 0.1, 1.0)
			if rain_amt <= 0.1:
				wet_gain = delta * 0.05 * clampf(snow_amt, 0.1, 1.0)
			st.wetness = minf(1.0, st.wetness + wet_gain * _bot_skin_wet_factor(b))
	if world.has_method("get_river_depth_at") and float(world.get_river_depth_at(pos)) > 0.30:
		st.wetness = minf(1.0, st.wetness + delta * 0.9)

	# Calor de fogatas y antorchas igual que _apply_campfire_effect /
	# _apply_torch_fire_effect del jugador: calienta, seca y quema al pisar
	# las brasas.
	for fire_pos in (world.get("campfire_positions") if world.get("campfire_positions") != null else []):
		if not (fire_pos is Vector3):
			continue
		var dx: float = fire_pos.x - pos.x
		var dz: float = fire_pos.z - pos.z
		var dist_sq: float = dx * dx + dz * dz
		var dy: float = absf(fire_pos.y - pos.y)
		if dist_sq < 0.36 and dy < 1.2:
			st.health = maxf(0.0, st.health - 5.0 * delta)
		elif dist_sq < 16.0 and dy < 2.5:
			var wf: float = 1.0 - (sqrt(dist_sq) - 0.6) / 3.4
			st.apply_external_heat(wf * 3.0 * delta, 38.0)
			st.wetness = maxf(0.0, st.wetness - wf * 0.05 * delta)
	for fire_pos in (world.get("torch_fire_positions") if world.get("torch_fire_positions") != null else []):
		if not (fire_pos is Vector3):
			continue
		var dx2: float = fire_pos.x - pos.x
		var dz2: float = fire_pos.z - pos.z
		var dist_sq2: float = dx2 * dx2 + dz2 * dz2
		if dist_sq2 < 4.0 and absf(fire_pos.y - pos.y) < 2.5:
			var wf2: float = 1.0 - sqrt(dist_sq2) / 2.0
			st.apply_external_heat(wf2 * 1.5 * delta, 37.5)
			st.wetness = maxf(0.0, st.wetness - wf2 * 0.02 * delta)

	var sleeping := bool(b.get("sleeping", false))
	var anim_now := str(b["anim"])
	var moving: bool = anim_now in ["walk", "run"] and not sleeping
	var sprinting: bool = anim_now == "run" and not sleeping
	var inv_n: int = (proxy.get_meta("saved_inventory", []) as Array).size()
	var carry_ratio := clampf(float(inv_n) / 30.0, 0.0, 1.0)
	var sun := 1.0 - (float(dc.get("weather_darkness")) if dc != null else 0.0)
	var wind := float(obs.get("wind_speed", 0.0))
	st.tick(delta, sprinting, ambient_temp, sheltered, shelter_warmth, is_night, moving, sleeping, carry_ratio, false, false, sun, wind)
	if sleeping:
		st.do_sleep(delta, false)
	if st.dead:
		return
	# Vuelta al estado del bot: la IA decide sobre b/* y el proxy como siempre.
	b["hunger"] = st.hunger
	b["thirst"] = st.thirst
	b["health"] = st.health
	b["energy"] = st.energy
	proxy.set_meta("proxy_health", st.health)
	proxy.set_meta("saved_health", st.health)
	var extra: Dictionary = proxy.get_meta("saved_extra", {})
	var sx: Dictionary = (extra.get("stats_extra", {}) as Dictionary).duplicate()
	sx["energy"] = st.energy
	sx["sleep"] = st.sleep
	sx["body_temperature"] = st.body_temperature
	sx["wetness"] = st.wetness
	sx["survival_seconds"] = st.survival_seconds
	extra["stats_extra"] = sx
	proxy.set_meta("saved_extra", extra)

# Causa de muerte deducida del estado final de sus stats humanos.
func _on_bot_stats_died(b: Dictionary) -> void:
	var st: SurvivalStats = b.get("vstats")
	var kind := "succumbed"
	if st != null:
		if st.body_temperature < 34.5:
			kind = "hypothermia"
		elif st.body_temperature > 39.0:
			kind = "heatstroke"
		elif st.hunger <= 0.0:
			kind = "starved" # hambre a 0 (con o sin sed): inanicion, la etiqueta historica
		elif st.thirst <= 0.0:
			kind = "dehydrated"
		elif st.sleep <= 10.0:
			kind = "exhausted"
	_kill_bot(b, kind)

# Condiciones para tumbarse a dormir en el punto de descanso (llamado desde el
# bloque de refugio de _tick_bot; despertar lo gestiona _bot_should_wake).
func _bot_try_start_sleep(b: Dictionary, is_night: bool) -> bool:
	# Un bot reclutado en tu equipo no se duerme: te sigue dia y noche.
	if bool(b.get("sleeping", false)) or int(b.get("team_leader_id", 0)) > 0 or float(b.get("hide_timer", 0.0)) > 0.0 or b.get("aggro_target") != null:
		return false
	var st: SurvivalStats = b.get("vstats")
	if st == null or st.dead:
		return false
	# Duerme de noche; si esta agotado de verdad cabecea incluso de dia.
	var exhausted := st.sleep < 14.0
	if not is_night and not exhausted:
		return false
	if float(b["hunger"]) < 20.0 or float(b["thirst"]) < 16.0:
		return false
	if st.body_temperature < 34.9 or st.body_temperature > 38.4:
		return false
	if st.sleep >= 99.0 and st.energy >= 98.0 and float(b["health"]) >= 99.0:
		return false # nada que recuperar: queda sentado de vigilancia
	b["sleeping"] = true
	b["sitting"] = false
	b["crouching"] = false
	b["prone"] = false
	b["anim"] = "sleep"
	return true

func _bot_should_wake(b: Dictionary, is_night: bool) -> bool:
	if b.get("aggro_target") != null or b.get("_s_predator") != null or b.get("_s_foe") != null:
		return true
	if not (b.get("_ambush", {}) as Dictionary).is_empty():
		return true # una emboscada activa lo saca de la cama
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		return true
	if float(b["hunger"]) < 14.0 or float(b["thirst"]) < 10.0:
		return true
	var st: SurvivalStats = b.get("vstats")
	if st == null:
		return true
	if st.body_temperature < 34.8 or st.body_temperature > 38.6:
		return true
	if st.health < 25.0:
		return true
	if st.sleep >= 99.5 and st.energy >= 95.0:
		return true # descansado: se sienta de guardia aunque siga de noche
	if not is_night and st.sleep > 55.0:
		return true # amanecio con el deposito medio lleno
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
	return ""

# Armas cuerpo a cuerpo por orden de letalidad (incluye las de crafteo).
func _best_melee_weapon(proxy: Node3D) -> String:
	var order := ["Lanza de hueso", "Lanza", "Hacha de piedra", "Hacha",
		"Cuchillo de hueso", "Cuchillo de piedra", "Cuchillo", "Palo afilado",
		"Pico", "Martillo", "Azada", "Pala", "Azada de piedra"]
	for w in order:
		if _bot_item_count(proxy, w) > 0:
			return w
	return ""

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

func _bot_has_skewered_meat(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Carne ensartada") > 0 or _bot_item_count(proxy, "Pez ensartado") > 0

func _bot_can_cook_raw_meat(proxy: Node3D) -> bool:
	if _bot_has_skewered_meat(proxy):
		return true
	return _bot_has_raw_meat(proxy) and _bot_item_count(proxy, "Palo afilado") > 0

func _bot_skewer_raw_meat(proxy: Node3D) -> bool:
	if _bot_has_skewered_meat(proxy):
		return true
	var raw := _first_raw_meat_name(proxy)
	if raw.is_empty() or _bot_item_count(proxy, "Palo afilado") <= 0:
		return false
	if not _consume_bot_item(proxy, "Palo afilado", 1):
		return false
	if not _consume_bot_item(proxy, raw, 1):
		return false
	var inv: Array = proxy.get_meta("saved_inventory", [])
	if raw == "Pez crudo":
		_bot_add_inventory_item(inv, {"name": "Pez ensartado", "type": "food", "weight": 0.45, "quantity": 1, "use_value": 18.0})
	else:
		_bot_add_inventory_item(inv, {"name": "Carne ensartada", "type": "food", "weight": 0.45, "quantity": 1, "use_value": 20.0})
	proxy.set_meta("saved_inventory", inv)
	return true

func _first_raw_meat_name(proxy: Node3D) -> String:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			if nm.begins_with("Carne cruda") or nm == "Pez crudo":
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

# Ropa suelta en la mochila (lo puesto vive en b["clothing"]): repuestos o
# prendas pendientes de cortar a trapos. Capa anti-acaparreo del loot.
func _bot_spare_clothing_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("type", "")) == "clothing":
			total += int(it.get("quantity", 1))
	return total

# Repuestos de ropa para un slot concreto (p.ej. un segundo pantalon bueno).
func _bot_slot_spare_count(proxy: Node3D, slot: String) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("type", "")) == "clothing":
			if str(PlayerController.CLOTHING_SLOTS.get(str(it.get("name", "")), "")) == slot:
				total += int(it.get("quantity", 1))
	return total

# ============ CAPACIDAD DE CARGA (misma regla que el jugador humano) ============
# Replica de PlayerController._compute_carry_capacity sobre el estado del bot:
# base 3 slots / 5 kg + bonus por ropa puesta (torso/legs/chaleco; extra
# militar/camuflaje en torso y piernas) + mochila equipada (peq 8/10, mil 20/25).
func _bot_carry_capacity(b: Dictionary) -> Dictionary:
	var slots := PlayerController.BASE_CARRY_SLOTS
	var weight := PlayerController.BASE_CARRY_WEIGHT
	for raw in str(b.get("clothing", "")).split(",", false):
		var nm := raw.strip_edges()
		if nm.is_empty() or not PlayerController.CLOTHING_SLOTS.has(nm):
			continue
		var is_military := nm.find("militar") >= 0 or nm.find("camuflaje") >= 0
		match str(PlayerController.CLOTHING_SLOTS[nm]):
			"torso":
				slots += PlayerController.TORSO_CARRY_SLOTS + (3 if is_military else 0)
				weight += PlayerController.TORSO_CARRY_WEIGHT + (3.0 if is_military else 0.0)
			"legs":
				slots += PlayerController.LEGS_CARRY_SLOTS + (2 if is_military else 0)
				weight += PlayerController.LEGS_CARRY_WEIGHT + (2.0 if is_military else 0.0)
			"chaleco":
				slots += PlayerController.VEST_CARRY_SLOTS
				weight += PlayerController.VEST_CARRY_WEIGHT
	var bp := str(b.get("backpack", ""))
	if bp == "Mochila militar":
		slots += PlayerController.MILITARY_BACKPACK_SLOTS
		weight += PlayerController.MILITARY_BACKPACK_WEIGHT
	elif not bp.is_empty():
		slots += PlayerController.SMALL_BACKPACK_SLOTS
		weight += PlayerController.SMALL_BACKPACK_WEIGHT
	return {"slots": slots, "weight": weight}

# Peso y huecos del inventario serializado. Como en Inventory.is_equipment_item,
# las mochilas (equipada o de repuesto) no cuentan ni pesan.
func _bot_inv_total_weight(inv: Array) -> float:
	var w := 0.0
	for it in inv:
		if it is Dictionary and str(it.get("type", "")) != "backpack":
			w += float(it.get("weight", 0.2)) * int(it.get("quantity", 1))
	return w

func _bot_inv_stored_count(inv: Array) -> int:
	var count := 0
	for it in inv:
		if it is Dictionary and str(it.get("type", "")) != "backpack":
			count += 1
	return count

# Ratio de carga, como _get_carry_weight_ratio: se usa para frenar el paso.
func _bot_carry_ratio(b: Dictionary) -> float:
	var cap := _bot_carry_capacity(b)
	var mw := float(cap.get("weight", 0.0))
	if mw <= 0.0:
		return 0.0
	return clampf(_bot_inv_total_weight(b["proxy"].get_meta("saved_inventory", [])) / mw, 0.0, 1.0)

# Misma regla que Inventory.add_item: el peso siempre cuenta (salvo mochilas)
# y un hueco nuevo solo hace falta si no apila sobre un stack existente.
func _bot_would_fit(b: Dictionary, inv: Array, item_dict: Dictionary) -> bool:
	var tp := str(item_dict.get("type", "resource"))
	if tp == "backpack":
		return true
	var cap := _bot_carry_capacity(b)
	if _bot_inv_total_weight(inv) + float(item_dict.get("weight", 0.2)) * int(item_dict.get("quantity", 1)) > float(cap["weight"]) + 0.001:
		return false
	var nm := str(item_dict.get("name", ""))
	if tp in ["food", "resource", "material", "medical", "ammo", "water", "misc"]:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == nm:
				return true # apila sobre un stack: no necesita hueco nuevo
	return _bot_inv_stored_count(inv) < int(cap["slots"])

func _bot_try_add_inventory_item(b: Dictionary, inv: Array, item_dict: Dictionary) -> bool:
	if not _bot_would_fit(b, inv, item_dict):
		return false
	_bot_add_inventory_item(inv, item_dict)
	return true

func _loot_entry_item_dict(entry: Dictionary) -> Dictionary:
	return {
		"name": str(entry.get("name", "")),
		"type": str(entry.get("type", "resource")),
		"weight": float(entry.get("weight", 0.2)),
		"quantity": maxi(1, int(entry.get("quantity", entry.get("qty", 1)))),
		"use_value": float(entry.get("use_value", entry.get("use", 0.0))),
	}

# Lo que no le cabe cae al suelo a sus pies, igual que al jugador: queda
# saqueable por cualquiera como pickup real sincronizado.
func _bot_drop_to_ground(b: Dictionary, item_dict: Dictionary) -> void:
	if world == null:
		return
	var p: Vector3 = (b["proxy"] as Node3D).global_position + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
	if world.has_method("_spawn_ground_pickup"):
		world._spawn_ground_pickup(str(item_dict.get("name", "")), str(item_dict.get("type", "resource")), p, float(item_dict.get("weight", 0.2)), int(item_dict.get("quantity", 1)), float(item_dict.get("use_value", 0.0)))
	elif "_dropped_items" in world:
		var did := "bot_drop_%d_%d" % [int(b["bot_id"]), int(Time.get_ticks_msec()) % 1000000]
		world._dropped_items.append({"id": did, "name": str(item_dict.get("name", "")), "type": str(item_dict.get("type", "resource")), "weight": float(item_dict.get("weight", 0.2)), "qty": int(item_dict.get("quantity", 1)), "use": float(item_dict.get("use_value", 0.0)), "pos": [p.x, p.y, p.z], "action_type": "drop"})

# La entrada de "keep" mas prescindible (para recortar lo que se queda encima
# a la capacidad real): prioridad de loot menor; a empate, la mas pesada.
func _bot_least_essential_index(b: Dictionary, inv: Array) -> int:
	var best_i := -1
	var best_score := INF
	for i in range(inv.size()):
		var it = inv[i]
		if not (it is Dictionary):
			continue
		if str(it.get("type", "")) == "backpack":
			continue
		var sc := _loot_priority(b, str(it.get("name", "")), str(it.get("type", ""))) - float(it.get("weight", 0.0)) * int(it.get("quantity", 1)) * 0.001
		if sc < best_score:
			best_score = sc
			best_i = i
	return best_i

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
	if not _bot_try_add_inventory_item(b, inv, entry):
		_bot_drop_to_ground(b, entry) # mochila llena: la pieza cae a sus pies
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
			if _bot_has_raw_meat(proxy) and _bot_item_count(proxy, "Palo afilado") == 0:
				return 6.7 # indispensable para ensartar y cocinar su carne cruda
			return 4.2 # habilita lanzas, espetones y es un arma floja
		var cur := _weapon_melee_damage(_best_melee_weapon(proxy))
		var nw := _weapon_melee_damage(oname)
		var spear_bonus := 1.2 if oname in ["Lanza", "Lanza de hueso"] and _bot_best_thrown_weapon(proxy).is_empty() else 0.0
		if nw <= cur * 1.03 and spear_bonus == 0.0:
			return -1.0
		return clampf(4.5 + (nw - cur) / 40.0 + spear_bonus, 0.0, 7.0)
	# Azada de piedra crafteable: puerta barata al huerto cuando no ha
	# encontrado una azada/pala de verdad (solo ~2 plantados).
	if oname == "Azada de piedra":
		return 6.1 if _bot_wants_farm_tool(b) else -1.0
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
		if oname in ["Carne ensartada", "Pez ensartado"]:
			return 6.8
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
			var bv := float(def_p[k])
			var lo := maxf(0.05, bv - 0.22)
			var hi := minf(0.98, bv + 0.22)
			var raw_v := float(p_dict.get(k, bv))
			# Si un rasgo venia saturado al tope global (0.05 o 0.98) de sesiones
			# anteriores sin ancla innata, devolverlo al temperamento base del bot.
			if is_equal_approx(raw_v, 0.05) or is_equal_approx(raw_v, 0.98):
				raw_v = lerpf(bv, clampf(raw_v, lo, hi), 0.35)
			p_dict[k] = snappedf(clampf(raw_v, lo, hi), 0.001)
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
	if not mem.has("farm_plots") or not (mem["farm_plots"] is Array):
		mem["farm_plots"] = []
	if not mem.has("milestones") or not (mem["milestones"] is Dictionary):
		mem["milestones"] = {}
	if not mem.has("shelter") or not (mem["shelter"] is Dictionary):
		mem["shelter"] = {}
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

func _adjust_trait(p: Dictionary, trait_name: String, delta_v: float, base_v: float = -1.0) -> void:
	if not AI_PERSONALITY_TRAITS.has(trait_name):
		return
	var lo := maxf(0.05, base_v - 0.22) if base_v >= 0.0 else 0.05
	var hi := minf(0.98, base_v + 0.22) if base_v >= 0.0 else 0.98
	p[trait_name] = snappedf(clampf(float(p.get(trait_name, 0.5)) + delta_v, lo, hi), 0.001)

# Evolución gradual de la personalidad según experiencias verificadas, anclada
# al temperamento innato de cada bot (±0.22) con homeostasis suave para que los
# tres nunca converjan a los topes globales [0.05, 0.98].
func _evolve_personality(b: Dictionary, event_kind: String, intensity: float = 0.25) -> void:
	var p := _get_bot_personality(b)
	var bid := int(b.get("bot_id", 901))
	var base_p := _default_personality_for_bot(bid, b.get("cfg", {}))
	for k in AI_PERSONALITY_TRAITS:
		var bv := float(base_p.get(k, 0.5))
		var cur_v := float(p.get(k, bv))
		p[k] = snappedf(cur_v + (bv - cur_v) * 0.04, 0.001)
	var step := clampf(intensity, 0.05, 1.0) * 0.055
	match event_kind:
		"death":
			_adjust_trait(p, "survival_instinct", step * 1.1, float(base_p["survival_instinct"]))
			_adjust_trait(p, "bravery", -step * 0.8, float(base_p["bravery"]))
			_adjust_trait(p, "distrust", step * 0.6, float(base_p["distrust"]))
		"predator_hit", "zone_hazard":
			_adjust_trait(p, "survival_instinct", step * 0.7, float(base_p["survival_instinct"]))
			_adjust_trait(p, "bravery", -step * 0.45, float(base_p["bravery"]))
		"player_attacked":
			_adjust_trait(p, "distrust", step * 1.2, float(base_p["distrust"]))
			_adjust_trait(p, "aggression", step * 0.65, float(base_p["aggression"]))
			_adjust_trait(p, "sociability", -step * 0.75, float(base_p["sociability"]))
			_adjust_trait(p, "cooperation", -step * 0.75, float(base_p["cooperation"]))
		"player_helped":
			_adjust_trait(p, "sociability", step * 0.95, float(base_p["sociability"]))
			_adjust_trait(p, "cooperation", step * 1.1, float(base_p["cooperation"]))
			_adjust_trait(p, "distrust", -step * 0.95, float(base_p["distrust"]))
			_adjust_trait(p, "aggression", -step * 0.4, float(base_p["aggression"]))
		"hunt_success", "kill_threat":
			_adjust_trait(p, "bravery", step * 0.7, float(base_p["bravery"]))
			_adjust_trait(p, "aggression", step * 0.35, float(base_p["aggression"]))
		"good_loot", "poi_discovered":
			_adjust_trait(p, "curiosity", step * 0.45, float(base_p["curiosity"]))
			_adjust_trait(p, "bravery", step * 0.20, float(base_p["bravery"]))
		"starving":
			_adjust_trait(p, "survival_instinct", step * 0.85, float(base_p["survival_instinct"]))
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

# Prefijos de "zona" (no un edificio concreto): se fusionan en un radio amplio.
# Los canonicos (house/city/military/tower) solo fusionan dentro del mismo
# edificio: la puerta, la primera planta y el tejado son UN sitio, no tres.
const LOC_SOFT_PREFIXES := ["wild", "patrol", "gunshot", "danger", "fight", "death", "heard", "zone", "water", "blood", "camp", "loot", "marked", "taught"]
const LOC_MERGE_POI_DIST := 4.0
const LOC_MERGE_ZONE_DIST := 18.0

func _loc_merge_dist(loc_id: String) -> float:
	return LOC_MERGE_ZONE_DIST if str(loc_id).get_slice(":", 0) in LOC_SOFT_PREFIXES else LOC_MERGE_POI_DIST

# Devuelve el id de una entrada existente del mismo prefijo a < radio de
# fusion, o "" si es un lugar genuinamente nuevo.
func _loc_merge_into(known: Dictionary, loc_id: String, pos: Vector3) -> String:
	var prefix := loc_id.get_slice(":", 0)
	var best_d := _loc_merge_dist(loc_id)
	var best_id := ""
	for oid in known.keys():
		var o := str(oid)
		if o == loc_id or o.get_slice(":", 0) != prefix:
			continue
		var op = known[oid].get("pos", null)
		if not (op is Array) or (op as Array).size() < 3:
			continue
		var d := Vector2(pos.x - float(op[0]), pos.z - float(op[2])).length()
		if d < best_d:
			best_d = d
			best_id = o
	return best_id

func observe_location(bot_id: int, loc_id: String, kind: String, pos: Vector3, source: String = "observed", mark_visit: bool = false) -> void:
	if loc_id.is_empty():
		return
	var mem := _ensure_bot_memory(bot_id)
	var known: Dictionary = mem["known_locations"]
	var is_new := not known.has(loc_id)
	if is_new:
		var merged := _loc_merge_into(known, loc_id, pos)
		if not merged.is_empty():
			loc_id = merged
			is_new = false
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
	_compact_known_locations(mem)

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
		var merged_id := ""
		if not kb.has(loc_id):
			var ep = entry.get("pos", null)
			if ep is Array and (ep as Array).size() >= 3:
				merged_id = _loc_merge_into(kb, str(loc_id), Vector3(float(ep[0]), float(ep[1]), float(ep[2])))
		if merged_id.is_empty() and not kb.has(loc_id):
			var copy := entry.duplicate(true)
			copy["source"] = "shared"
			kb[loc_id] = copy
			shared_count += 1
		else:
			var tid: String = merged_id if not merged_id.is_empty() else loc_id
			kb[tid]["risk"] = maxf(float(kb[tid].get("risk", 0.0)), float(entry.get("risk", 0.0)))
			kb[tid]["visits"] = maxf(float(kb[tid].get("visits", 0)), float(entry.get("visits", 0)))
			shared_count += 1
	for loc_id2 in kb.keys():
		var entry2: Dictionary = kb[loc_id2]
		var merged2 := ""
		if not ka.has(loc_id2):
			var ep2 = entry2.get("pos", null)
			if ep2 is Array and (ep2 as Array).size() >= 3:
				merged2 = _loc_merge_into(ka, str(loc_id2), Vector3(float(ep2[0]), float(ep2[1]), float(ep2[2])))
		if merged2.is_empty() and not ka.has(loc_id2):
			var copy2 := entry2.duplicate(true)
			copy2["source"] = "shared"
			ka[loc_id2] = copy2
			shared_count += 1
		else:
			var tid2: String = merged2 if not merged2.is_empty() else loc_id2
			ka[tid2]["risk"] = maxf(float(ka[tid2].get("risk", 0.0)), float(entry2.get("risk", 0.0)))
			ka[tid2]["visits"] = maxf(float(ka[tid2].get("visits", 0)), float(entry2.get("visits", 0)))
			shared_count += 1
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
# Primera vez que un comportamiento emerge — persiste para el panel de
# evolucion (first_team, first_lead, first_ambush, first_farm,
# first_harvest, first_chat, first_alliance, first_rescue).
func _record_milestone(bot_id: int, key: String) -> void:
	var mem := _ensure_bot_memory(bot_id)
	var ms: Dictionary = mem["milestones"]
	if not ms.has(key):
		ms[key] = int(Time.get_unix_time_from_system())
		mem["milestones"] = ms

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
	st["last"] = int(Time.get_unix_time_from_system())
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
		# El cooperativo busca compañia incluso en paz; y quien ya trabajo con
		# otro bot (vinculo previo) lo busca activamente para reagruparse.
		"seek_ally": (sociability * 0.95 + cooperation * 0.95 - distrust * 0.85 - aggression * 0.50) * (1.15 if threat_present else 0.75 + cooperation * 0.35),
	}
	var bond_bonus := 0.0
	for rk in (mem.get("relationships", {}) as Dictionary).keys():
		var rv: Dictionary = mem["relationships"][rk]
		if str(rk).begins_with("bot_") and (float(rv.get("trust", 0.0)) >= BOT_TEAM_FORM_TRUST or int(rv.get("helped", 0)) >= 2):
			bond_bonus = 0.35
			break
	scores["seek_ally"] = float(scores["seek_ally"]) + bond_bonus
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
		for field in ["identity", "personality", "deaths", "last_death_cause", "gear_learned", "scarcity", "zone_yield", "death_spots", "events", "events_summary", "known_locations", "relationships", "strategies", "pending_goals", "sessions", "stats", "farm_plots", "milestones", "shelter"]:
			if sd.has(field):
				mem[field] = sd[field]
		_compact_known_locations(mem)
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

# Fusiona las ubicaciones duplicadas acumuladas (misma zona/distancia) — la
# memoria vieja se limpia una vez al cargar y luego observe_location ya no vuelve
# a crear duplicados cercanos.
func _compact_known_locations(mem: Dictionary) -> void:
	var known: Dictionary = mem.get("known_locations", {})
	if known.size() < 2:
		return
	var out := {}
	for lid in known.keys():
		var e: Dictionary = known[lid]
		if not (e is Dictionary):
			continue
		var ep = e.get("pos", null)
		if ep is Array and (ep as Array).size() >= 3:
			var merged := _loc_merge_into(out, str(lid), Vector3(float(ep[0]), float(ep[1]), float(ep[2])))
			if not merged.is_empty():
				var tgt: Dictionary = out[merged]
				tgt["visits"] = int(tgt.get("visits", 0)) + int(e.get("visits", 0))
				tgt["risk"] = maxf(float(tgt.get("risk", 0.0)), float(e.get("risk", 0.0)))
				tgt["loot_score"] = maxf(float(tgt.get("loot_score", 0.0)), float(e.get("loot_score", 0.0)))
				out[merged] = tgt
				continue
		out[str(lid)] = e
	mem["known_locations"] = out

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
		for field in ["identity", "personality", "deaths", "last_death_cause", "gear_learned", "scarcity", "zone_yield", "death_spots", "events", "events_summary", "known_locations", "relationships", "strategies", "pending_goals", "sessions", "stats", "farm_plots", "milestones", "shelter"]:
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
		"sleeping": bool(b.get("sleeping", false)),
		"sleep": int(float((b.get("vstats") as SurvivalStats).sleep)) if b.get("vstats") != null else 100,
		"energy": int(float((b.get("vstats") as SurvivalStats).energy)) if b.get("vstats") != null else 100,
		"body_temperature": snappedf(float((b.get("vstats") as SurvivalStats).body_temperature), 0.1) if b.get("vstats") != null else 36.7,
		"wetness": snappedf(float((b.get("vstats") as SurvivalStats).wetness), 0.01) if b.get("vstats") != null else 0.0,
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
		snap["act"] = str(b.get("_act", "?"))
		snap["dead"] = bool(proxy.get_meta("proxy_dead", false)) if proxy != null and is_instance_valid(proxy) else false
		snap["respawn_seconds"] = int(maxf(0.0, 180.0 - float(b.get("respawn_timer", 0.0)))) if bool(snap["dead"]) else 0
		snap["held_item"] = str(b.get("held_item", ""))
		snap["clothing"] = str(b.get("clothing", ""))
		snap["backpack"] = str(b.get("backpack", ""))
		snap["torch_lit"] = bool(b.get("torch_lit", false))
		snap["sick"] = float(b.get("sick_timer", 0.0)) > 0.0
		snap["crouching"] = bool(b.get("crouching", false))
		snap["sitting"] = bool(b.get("sitting", false))
		snap["sleeping"] = bool(b.get("sleeping", false))
		var vst: SurvivalStats = b.get("vstats")
		if vst != null:
			snap["sleep"] = int(vst.sleep)
			snap["energy"] = int(vst.energy)
			snap["body_temperature"] = snappedf(vst.body_temperature, 0.1)
			snap["wetness"] = snappedf(vst.wetness, 0.01)
		snap["in_shelter"] = _is_bot_wolf_protected(b) if proxy != null and is_instance_valid(proxy) else false
		snap["team_leader_id"] = int(b.get("team_leader_id", 0))
		snap["follow_mode"] = str(b.get("follow_mode", "follow"))
		# Equipo bot-bot autonomo: rol, compañeros y emboscada en curso para el
		# panel web (JSON-safe: solo strings, ints y arrays).
		snap["team_role"] = _bot_team_role(b)
		var mates: Array = []
		for tid in _bot_team_ids(b):
			if tid != int(bid):
				mates.append({"id": tid, "name": str((bots.get(tid, {}) as Dictionary).get("name", str(tid)))})
		snap["team_mates"] = mates
		var mtid := int(b.get("_meet_id", 0))
		if mtid > 0 and bots.has(mtid):
			var mp2: Node3D = (bots[mtid] as Dictionary).get("proxy")
			snap["meet"] = {
				"target": str((bots[mtid] as Dictionary).get("name", str(mtid))),
				"target_id": mtid,
				"dist": int(proxy.global_position.distance_to(mp2.global_position)) if mp2 != null and is_instance_valid(mp2) else -1,
			}
		else:
			snap["meet"] = {}
		var amb: Dictionary = b.get("_ambush", {})
		if not amb.is_empty():
			var atgt := _find_actor_by_peer_id(int(amb.get("target_id", 0)))
			snap["ambush"] = {
				"target": str(amb.get("target_name", "")),
				"target_id": int(amb.get("target_id", 0)),
				"dist": int(proxy.global_position.distance_to(atgt.global_position)) if atgt != null and is_instance_valid(atgt) else -1,
				"t": int(amb.get("t", 0.0)),
			}
		else:
			snap["ambush"] = {}
		var fplots: Array = _bot_farm_plots(b)
		var fready := 0
		for fp in fplots:
			var rec := _bot_crop_record(str((fp as Dictionary).get("id", "")))
			if not rec.is_empty() and str(_crop_effective_state(rec).get("state", "")) == "ready":
				fready += 1
		snap["farm"] = {"plots": fplots.size(), "ready": fready}
		snap["camp_spot"] = [snappedf(camp.x, 0.1), snappedf(camp.y, 0.1), snappedf(camp.z, 0.1)] if camp != Vector3.INF else []
		snap["shelter_pos"] = [snappedf(sh.x, 0.1), snappedf(sh.y, 0.1), snappedf(sh.z, 0.1)] if sh != Vector3.INF else []
		snap["explore_target"] = [snappedf(et.x, 0.1), snappedf(et.y, 0.1), snappedf(et.z, 0.1)] if et != Vector3.INF else []
		snap["inventory"] = (proxy.get_meta("saved_inventory", []) as Array) if proxy != null and is_instance_valid(proxy) else []
		snap["shelter_stash"] = _get_shelter_contents(str(b.get("shelter_id", "")))
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
		# Chat del bot: ultimo mensaje emitido + su hilo completo (como emisor
		# y como destinatario) para la seccion de conversaciones de la tarjeta.
		var own_chat: Array = []
		for cm in chat_log:
			if int(cm.get("from_id", 0)) == bid or int(cm.get("to_id", 0)) == bid:
				own_chat.append(cm)
			if int(cm.get("from_id", 0)) == bid:
				snap["chat"] = {"to": str(cm.get("to", "")), "kind": str(cm.get("kind", "")), "text": str(cm.get("text", "")), "ts": int(cm.get("ts", 0))}
		if not own_chat.is_empty():
			snap["chat_log"] = own_chat.slice(-8)
		snap["alive_seconds"] = int(life_sec)
		snap["alive_total_seconds"] = int(alive_total)
		# Media de tiempo de vida: total acumulado entre vidas (muertes + la
		# vida en curso si sigue vivo) — mide cuanto sobrevive de verdad.
		var lives_n: int = int(mem.get("deaths", 0)) + (0 if is_dead else 1)
		snap["avg_life_seconds"] = int(alive_total / maxf(1.0, float(lives_n)))
		snap["score"] = score
		snap["stats"] = st
		# Evolucion: rasgos base (para mostrar el delta) e hitos de conducta nueva
		snap["base_personality"] = _default_personality_for_bot(bid)
		snap["milestones"] = mem.get("milestones", {})
		bots_out.append(snap)
	# Puntos de interes fijos del mundo que no son objetivos de exploracion de
	# los bots (p. ej. la base militar de la cumbre: esta a 56 m de altura y
	# solo se alcanza por la carretera de montana).
	var landmarks_out: Array = []
	if world != null and bool(world.get("_high_mountain_ready")):
		var summit := Vector3(HighMountainZone.SUMMIT_CENTER.x, HighMountainZone.SUMMIT_HEIGHT, HighMountainZone.SUMMIT_CENTER.y)
		landmarks_out.append({"kind": "summit_base", "label": "Base Cima", "pos": [snappedf(summit.x, 0.1), snappedf(summit.y, 0.1), snappedf(summit.z, 0.1)]})
	# Jugadores humanos: el diccionario en Main es server_proxies (conectados)
	# y proxy_by_client_id (desconectados en el mundo), mas net.players.
	var players_out: Array = []
	var s_proxies = world.get("server_proxies") if world != null else null
	var c_proxies = world.get("proxy_by_client_id") if world != null else null
	var seen_pids: Dictionary = {}
	if net != null and "players" in net:
		for pid in net.players.keys():
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)):
				continue
			var pdata: Dictionary = net.players[pid]
			if bool(pdata.get("is_ai_bot", false)):
				continue
			var is_off := bool(pdata.get("offline", false))
			var pr: Node3D = null
			if s_proxies is Dictionary and (s_proxies as Dictionary).has(pid):
				var cand = (s_proxies as Dictionary)[pid]
				if cand != null and is_instance_valid(cand) and cand is Node3D:
					pr = cand as Node3D
			if pr == null and c_proxies is Dictionary:
				var cid := str(pdata.get("client_id", ""))
				if not cid.is_empty() and (c_proxies as Dictionary).has(cid):
					var cand2 = (c_proxies as Dictionary)[cid]
					if cand2 != null and is_instance_valid(cand2) and cand2 is Node3D:
						pr = cand2 as Node3D
				if pr == null:
					for op in (c_proxies as Dictionary).values():
						if op != null and is_instance_valid(op) and op is Node3D and int((op as Node3D).get_meta("peer_id", 0)) == int(pid):
							pr = op as Node3D
							break
			var pp := Vector3.INF
			var h_raw = pdata.get("health", 100.0)
			var hp := float(h_raw) if (h_raw is float or h_raw is int) else 100.0
			var pdead := false
			if pr != null:
				pp = pr.global_position
				var ph_raw = pr.get_meta("proxy_health", hp)
				if ph_raw is float or ph_raw is int:
					hp = float(ph_raw)
				pdead = bool(pr.get_meta("proxy_dead", false))
			elif pdata.get("pos") is Vector3:
				pp = pdata["pos"]
			if pp == Vector3.INF:
				continue
			seen_pids[int(pid)] = true
			players_out.append({
				"id": int(pid),
				"name": str(pdata.get("char_name", pdata.get("name", "Jugador"))),
				"pos": [snappedf(pp.x, 0.1), snappedf(pp.y, 0.1), snappedf(pp.z, 0.1)],
				"health": snappedf(hp, 0.1),
				"dead": pdead,
				"offline": is_off,
			})
	if s_proxies is Dictionary:
		for pid2 in (s_proxies as Dictionary).keys():
			if seen_pids.has(int(pid2)) or is_bot_peer_id(int(pid2)):
				continue
			var pr2 = (s_proxies as Dictionary)[pid2]
			if pr2 != null and is_instance_valid(pr2) and pr2 is Node3D:
				var pp2: Vector3 = (pr2 as Node3D).global_position
				players_out.append({
					"id": int(pid2),
					"name": "Jugador_%d" % int(pid2),
					"pos": [snappedf(pp2.x, 0.1), snappedf(pp2.y, 0.1), snappedf(pp2.z, 0.1)],
					"health": snappedf(float((pr2 as Node3D).get_meta("proxy_health", 100.0)), 0.1),
					"dead": bool((pr2 as Node3D).get_meta("proxy_dead", false)),
					"offline": false,
				})
	# Equipos autonomos bot-bot para el panel: cada lider libre con miembros.
	var teams_out: Array = []
	for tid in ids:
		var tb: Dictionary = bots[tid]
		if int(tb.get("team_leader_id", 0)) != 0:
			continue
		var members: Array = []
		for oid in bots.keys():
			if int(bots[oid].get("team_leader_id", 0)) == int(tid):
				members.append({"id": int(oid), "name": str(bots[oid].get("name", str(oid)))})
		if not members.is_empty():
			teams_out.append({"leader_id": int(tid), "leader": str(tb.get("name", str(tid))), "members": members})
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
		"landmarks": landmarks_out,
		"players": players_out,
		"bots": bots_out,
		"teams": teams_out,
		"chat_log": chat_log.slice(-BOT_CHAT_LOG_MAX),
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
		if (nm.begins_with("Carne cruda") or nm == "Carne ensartada" or nm == "Pez ensartado") and not desperate:
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

# ============================ HUERTO: CULTIVAR VERDURAS ============================
# Mismo flujo que el jugador humano: semillas de arbustos/cosecha + azada o
# pala -> preparar bancal (4 s) -> esperar ~7.5 min (la lluvia/riego acelera)
# -> recolectar Verduras y recuperar semillas. El bancal persiste en memoria
# entre vidas: tras reaparecer el bot vuelve a su huerto.

func _bot_has_farm_tool(proxy: Node3D) -> bool:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) in ["Azada", "Pala", "Azada de piedra"] and float(it.get("durability", 1.0)) > 0.0:
			return true
	return false

func _bot_wants_farm_tool(b: Dictionary) -> bool:
	# No hace falta refugio para cultivar: una azada/pala abre la via a una
	# fuente de comida estable — como mucho una por bot (no acapara).
	return not _bot_has_farm_tool(b["proxy"])

func _bot_wants_seeds(b: Dictionary) -> bool:
	# Las semillas pesan 0.05 y son la puerta del huerto: siempre interesan
	# hasta tener para llenar el cupo de bancales (3).
	return _bot_item_count(b["proxy"], "Semillas") < 3

func _bot_farm_plots(b: Dictionary) -> Array:
	var mem: Dictionary = b.get("_mem", {})
	if not (mem.get("farm_plots") is Array):
		mem["farm_plots"] = []
	return mem["farm_plots"]

# Reproduce el calculo cliente del estado del cultivo (planted->ready->rotten):
# en el servidor dedicado el registro queda "planted" para siempre y el estado
# real se deriva del tiempo transcurrido y la humedad acumulada.
func _crop_effective_state(c: Dictionary) -> Dictionary:
	var state := str(c.get("crop_state", "planted"))
	var ready := float(c.get("ready_unix", 0.0))
	var now := Time.get_unix_time_from_system()
	if state == "planted":
		var updated := float(c.get("updated_unix", now))
		var elapsed := maxf(0.0, now - updated)
		var moist := clampf(float(c.get("watered_until", 0.0)) - updated, 0.0, elapsed)
		var growth := float(c.get("growth", 0.0)) + moist * GameConst.CROP_MOIST_GROWTH + (elapsed - moist)
		if growth >= 450.0:
			state = "ready"
			ready = now - maxf(0.0, growth - 450.0)
	if state == "ready" and ready > 0.0 and now - ready >= GameConst.CROP_ROT_SECONDS:
		state = "rotten"
	return {"state": state, "ready_unix": ready}

func _bot_crop_record(crop_id: String) -> Dictionary:
	if world != null and "_planted_crops" in world:
		for c in world._planted_crops:
			if c is Dictionary and str(c.get("id", "")) == crop_id:
				return c
	return {}

# La posicion de una parcela guardada en memoria (persiste como [x,y,z] en JSON).
func _bot_plot_pos(p: Dictionary) -> Vector3:
	var pv = p.get("pos")
	if pv is Vector3:
		return pv
	if pv is Array and (pv as Array).size() >= 3:
		return Vector3(float(pv[0]), float(pv[1]), float(pv[2]))
	return Vector3.INF

func _bot_crop_broadcast(tag: String, pos: Vector3) -> void:
	if world == null or world.get("net") == null:
		return
	var net = world.net
	if bool(net.get("is_host")) and net.get("peer") != null and net.has_method("world_action_completed"):
		net.world_action_completed.rpc("", [], tag, pos)

# Sitio del nuevo bancal: cerca del refugio como haria un granjero humano;
# sin refugio, un claro seco junto a su campamento.
func _bot_find_farm_spot(b: Dictionary) -> Vector3:
	var proxy: Node3D = b["proxy"]
	var origin: Vector3 = b.get("shelter_pos", Vector3.INF)
	if origin == Vector3.INF:
		# Sin refugio el huerto va junto al campamento (o donde este ahora).
		origin = b.get("camp_spot", proxy.global_position)
	for off in [Vector3(3.0, 0, 1.5), Vector3(-3.0, 0, 1.5), Vector3(1.5, 0, 3.0), Vector3(0, 0, -3.2), Vector3(-1.5, 0, -3.0), Vector3(3.6, 0, -1.8), Vector3(-3.6, 0, -1.8), Vector3(4.5, 0, 0), Vector3(-4.5, 0, 0), Vector3(0, 0, 4.5)]:
		var cand: Vector3 = origin + off
		if world != null and world.has_method("get_river_depth_at") and world.get_river_depth_at(cand) > 0.0:
			continue
		if world != null and world.has_method("_can_place_ground_vegetation") and not world._can_place_ground_vegetation(cand, -1.0):
			continue
		if not _is_flat_dry_pos(cand, str(b.get("shelter_id", ""))):
			continue
		return cand
	return Vector3.INF

func _bot_consume_one_item(proxy: Node3D, item_name: String) -> bool:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for i in range(inv.size()):
		var it = inv[i]
		if it is Dictionary and str(it.get("name", "")) == item_name and int(it.get("quantity", 1)) > 0:
			it["quantity"] = int(it.get("quantity", 1)) - 1
			if int(it.get("quantity", 1)) <= 0:
				inv.remove_at(i)
			proxy.set_meta("saved_inventory", inv)
			return true
	return false

func _bot_wear_farm_tool(proxy: Node3D) -> void:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) in ["Azada", "Pala", "Azada de piedra"]:
			it["durability"] = float(it.get("durability", 100.0)) - 4.0
			proxy.set_meta("saved_inventory", proxy.get_meta("saved_inventory", []))
			return

func _bot_try_farm(b: Dictionary, delta: float) -> bool:
	if world == null or not ("_planted_crops" in world):
		return false
	var proxy: Node3D = b["proxy"]
	# Escondido de una amenaza o durmiendo no sale al huerto; la cosecha madura
	# espera a que pase el peligro (los humanos tampoco cultivan bajo fuego).
	if float(b.get("hide_timer", 0.0)) > 0.0 or bool(b.get("sleeping", false)):
		return false
	var mem: Dictionary = b.get("_mem", {})
	var plots: Array = _bot_farm_plots(b)
	var now := Time.get_unix_time_from_system()
	# Registro mundial de la parcela propia (purge ids desaparecidos)
	for i in range(plots.size() - 1, -1, -1):
		var pid := str(plots[i].get("id", ""))
		if _bot_crop_record(pid).is_empty():
			plots.remove_at(i)
	var st: Dictionary = b.get("_farm", {})
	if not st.is_empty():
		var fpos: Vector3 = st.get("pos", Vector3.INF)
		if fpos == Vector3.INF:
			b["_farm"] = {}
			return false
		var flat := Vector2(proxy.global_position.x - fpos.x, proxy.global_position.z - fpos.z).length()
		if flat > 2.0:
			b["sitting"] = false
			b["crouching"] = false
			_move_bot_towards(b, fpos, 4.4 if flat > 10.0 else 3.6, delta, "run" if flat > 10.0 else "walk")
			return true
		var phase := str(st.get("phase", ""))
		st["t"] = float(st.get("t", 0.0)) + delta
		b["anim"] = "forage"
		b["crouching"] = true
		b["sitting"] = false
		b["held_item"] = str(st.get("tool", ""))
		proxy.set_meta("saved_held_item", str(st.get("tool", "")))
		if float(st["t"]) < float(st.get("t_need", 4.0)):
			return true
		b["_farm"] = {}
		match phase:
			"plant", "replant":
				var consumed := _bot_consume_one_item(proxy, "Semillas")
				if not consumed:
					return true
				_bot_wear_farm_tool(proxy)
				if phase == "replant":
					var rec := _bot_crop_record(str(st.get("crop_id", "")))
					if rec.is_empty():
						return true
					rec["crop_state"] = "planted"
					rec["growth"] = 0.0
					rec["updated_unix"] = now
					rec["watered_until"] = 0.0
					rec["ready_unix"] = 0.0
					_bot_crop_broadcast("crop_replanted", fpos)
				else:
					var cid: String = world._plant_crop(fpos) if world.has_method("_plant_crop") else ""
					if not cid.is_empty():
						plots.append({"id": cid, "pos": [fpos.x, fpos.y, fpos.z]})
					_bot_crop_broadcast("planted_crop", fpos)
				mem["farm_plots"] = plots
				observe_location(int(b["bot_id"]), "farm:%d:%d" % [int(fpos.x), int(fpos.z)], "farm", fpos, "visited")
				record_bot_event(int(b["bot_id"]), "farm_plant", "self", "farm", fpos, "planta un bancal de semillas")
				_record_milestone(int(b["bot_id"]), "first_farm")
				if world.has_method("_save_world_change_silent"):
					world._save_world_change_silent()
			"harvest":
				var rec := _bot_crop_record(str(st.get("crop_id", "")))
				if not rec.is_empty() and _crop_effective_state(rec)["state"] == "ready":
					var veg := {"name": "Verduras", "type": "food", "weight": 0.22, "quantity": 3, "use_value": 16.0}
					var inv: Array = proxy.get_meta("saved_inventory", [])
					if not _bot_try_add_inventory_item(b, inv, veg):
						_bot_drop_to_ground(b, veg)
					if randf() < 0.55:
						var seed_item := {"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 1, "use_value": 0.0}
						if not _bot_try_add_inventory_item(b, inv, seed_item):
							_bot_drop_to_ground(b, seed_item)
					rec["crop_state"] = "empty"
					rec["growth"] = 0.0
					rec["updated_unix"] = now
					rec["watered_until"] = 0.0
					rec["ready_unix"] = 0.0
					_bot_crop_broadcast("crop_harvested", fpos)
					record_strategy_outcome(int(b["bot_id"]), "farming", true)
					_record_milestone(int(b["bot_id"]), "first_harvest")
					var fstats: Dictionary = mem.get("stats", {})
					fstats["harvests"] = int(fstats.get("harvests", 0)) + 1
					mem["stats"] = fstats
					if world.has_method("_save_world_change_silent"):
						world._save_world_change_silent()
			"clean":
				var rec := _bot_crop_record(str(st.get("crop_id", "")))
				if not rec.is_empty():
					rec["crop_state"] = "empty"
					rec["growth"] = 0.0
					rec["updated_unix"] = now
					rec["watered_until"] = 0.0
					rec["ready_unix"] = 0.0
					_bot_crop_broadcast("crop_harvested", fpos)
					if randf() < 0.3:
						var seed_item := {"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 1, "use_value": 0.0}
						var inv: Array = proxy.get_meta("saved_inventory", [])
						if not _bot_try_add_inventory_item(b, inv, seed_item):
							_bot_drop_to_ground(b, seed_item)
					record_strategy_outcome(int(b["bot_id"]), "farming", false, 0.2)
					if world.has_method("_save_world_change_silent"):
						world._save_world_change_silent()
			"water":
				var rec := _bot_crop_record(str(st.get("crop_id", "")))
				if not rec.is_empty() and _bot_consume_one_item(proxy, "Botella de agua llena"):
					_bot_add_inventory_item(proxy.get_meta("saved_inventory", []), {"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0})
					rec["watered_until"] = now + GameConst.CROP_WATER_SECONDS
					_bot_crop_broadcast("crop_watered", fpos)
					if world.has_method("_save_world_change_silent"):
						world._save_world_change_silent()
		return true
	# ---- Decidir la siguiente tarea de huerto ----
	var has_tool := _bot_has_farm_tool(proxy)
	var tool_name := ""
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")) in ["Azada", "Pala", "Azada de piedra"] and float(it.get("durability", 1.0)) > 0.0:
			tool_name = str(it["name"])
			break
	var cur := proxy.global_position
	# 1) Cosechar lo maduro: se pudre en ~10 min y es comida regalada.
	for p in plots:
		var rec := _bot_crop_record(str(p.get("id", "")))
		if rec.is_empty():
			continue
		var eff := _crop_effective_state(rec)
		var pp: Vector3 = rec.get("pos", _bot_plot_pos(p)) if rec.get("pos") is Vector3 else _bot_plot_pos(p)
		if pp == Vector3.INF:
			continue
		if eff["state"] == "ready":
			b["_farm"] = {"phase": "harvest", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 1.25, "tool": ""}
			return true
		if eff["state"] == "rotten":
			b["_farm"] = {"phase": "clean", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 1.25, "tool": ""}
			return true
	# Muerto de hambre/sed: no se pone a sembrar — busca comida ya.
	var starving := float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, true)
	if starving:
		return false
	# 2) Replantar un bancal vacio propio si lleva semillas y herramienta.
	if has_tool and _bot_item_count(proxy, "Semillas") >= 1:
		for p in plots:
			var rec := _bot_crop_record(str(p.get("id", "")))
			if not rec.is_empty() and str(rec.get("crop_state", "")) == "empty":
				var pp: Vector3 = rec.get("pos", _bot_plot_pos(p)) if rec.get("pos") is Vector3 else _bot_plot_pos(p)
				if pp == Vector3.INF:
					continue
				b["_farm"] = {"phase": "replant", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 4.0, "tool": tool_name}
				return true
	# 3) Regar lo plantado si pasa cerca con una botella llena.
	for p in plots:
		var rec := _bot_crop_record(str(p.get("id", "")))
		if rec.is_empty() or str(rec.get("crop_state", "")) != "planted":
			continue
		if float(rec.get("watered_until", 0.0)) > now:
			continue
		var pp: Vector3 = rec.get("pos", _bot_plot_pos(p)) if rec.get("pos") is Vector3 else _bot_plot_pos(p)
		if pp == Vector3.INF:
			continue
		if Vector2(cur.x - pp.x, cur.z - pp.z).length() < 25.0 and _bot_item_count(proxy, "Botella de agua llena") >= 1:
			b["_farm"] = {"phase": "water", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 2.0, "tool": ""}
			return true
	# 4) Sembrar un bancal nuevo: herramienta + semillas + un sitio valido.
	if has_tool and _bot_item_count(proxy, "Semillas") >= 1 and plots.size() < 3:
		var spot := _bot_find_farm_spot(b)
		if spot != Vector3.INF:
			b["_farm"] = {"phase": "plant", "pos": spot, "t": 0.0, "t_need": 4.0, "tool": tool_name}
			return true
	return false

func _bot_try_gather_mats(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var palo_need := 0
	if str(b["shelter_id"]).is_empty():
		palo_need = 4
	elif str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)):
		palo_need = 2
	if _bot_has_raw_meat(proxy) or _bot_has_skewered_meat(proxy):
		var cook_palos := (1 if _bot_item_count(proxy, "Palo afilado") == 0 and not _bot_has_skewered_meat(proxy) else 0) + (2 if str(b["campfire_id"]).is_empty() else 0)
		palo_need = maxi(palo_need, cook_palos)
	var tool := _bot_bush_tool(proxy)
	# Arbustos tambien dan Semillas: quien quiere huerto tala aunque no le
	# falten palos (2 paquetes de semillas bastan para un bancal).
	var seeds_need := _bot_wants_seeds(b) and _bot_item_count(proxy, "Semillas") < 2
	# Escondido o reclutado no sale a talar: las ordenes del lider y la
	# amenaza van primero. El ruido del corte atrae lobos, como al jugador.
	var allowed := ((palo_need > 0 and _bot_item_count(proxy, "Palo") < palo_need) or seeds_need) \
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
