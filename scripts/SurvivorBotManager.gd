extends Node
class_name SurvivorBotManager

const CityExpansion = preload("res://scripts/CityExpansion.gd")
const CityBlock = preload("res://scripts/CityBlock.gd")
const ElevationRoutes = preload("res://scripts/BotElevationRoutes.gd")
const PlanManager = preload("res://scripts/bot_ai/BotPlanManager.gd")
const GoalValidator = preload("res://scripts/bot_ai/BotGoalValidator.gd")
const PlanDiagnostics = preload("res://scripts/bot_ai/BotPlanDiagnostics.gd")
const InterruptionManager = preload("res://scripts/bot_ai/BotInterruptionManager.gd")

# Gestor de Supervivientes IA (bots con modelo, ropa, inventario y acciones reales):
# - Todos los supervivientes IA nacen HOSTILES hacia los jugadores: los cazan a
#   la vista (melee o a distancia). Solo se vuelven amigables si el jugador los
#   convence de confiar por chat/voz: tregua, regalos, explicaciones y, con la
#   confianza suficiente, la orden "sigueme/unete" los pasa a aliados.
# - Kael, el bandido del rifle, tambien puede ser convencido con esfuerzo.

# Municion de armas de fuego del bot: mismo modelo que PlayerController
# (M4_MAG_SIZE=30 / RIFLE_MAG_SIZE=5, recarga de 2.2 s).
const BOT_M4_MAG_SIZE := 30
const BOT_SNIPER_MAG_SIZE := 5
const BOT_M4_BURST_ROUNDS := 3
const BOT_GUN_RELOAD_TIME := 2.2

const BOT_CONFIGS := [
	{
		"bot_id": 901,
		"client_id": "ai_bot_901",
		"name": "Elena",
		"preview_id": "elena",
		"faction": "hostile",
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
		"faction": "hostile",
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
	{
		"bot_id": 904,
		"client_id": "ai_bot_904",
		"name": "Ataulfo",
		"preview_id": "marc",
		"faction": "hostile",
		"hair_style": "crop",
		"beard_stage": 0,
		"top_color": Color(0.2, 0.25, 0.12),
		"bottom_color": Color(0.3, 0.3, 0.35),
		"shoes_color": Color(0.5, 0.25, 0.15),
		"hair_color": Color(0.02, 0.02, 0.02),
		"skin_color": Color(0.7, 0.58, 0.45),
		"top_camo": true,
		"bottom_camo": false,
		"spawn": Vector3(-52.0, 0.0, -18.0),
		"camp_spot": Vector3(-60.0, 0.0, -26.0),
		"patrol": [
			Vector3(-52.0, 0.0, -18.0),
			Vector3(-120.0, 0.0, 80.0),
			Vector3(30.0, 0.0, 140.0),
			Vector3(140.0, 0.0, -40.0),
			Vector3(-90.0, 0.0, -110.0),
		],
		"starting_clothing": ["Camiseta", "Pantalones", "Zapatillas"],
		"starting_backpack": "",
		"starting_weapon": "Cuchillo",
		"starting_items": [],
		"personality": {
			"bravery": 0.72,
			"aggression": 0.35,
			"curiosity": 0.97,
			"sociability": 0.35,
			"distrust": 0.55,
			"cooperation": 0.50,
			"survival_instinct": 0.80,
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
var _bot_shelter_seq := 0
# Aprendizaje persistente por personaje: sobrevive a la muerte/respawn, asi el
# superviviente "recuerda" donde murio, por que, que zonas ya exploro y que la
# ropa de piel es la mejor equipacion.
var _memory: Dictionary = {} # bot_id -> {deaths, last_death_pos, last_death_cause, visited, gear_learned, scarcity}
var _poi_cache: Array = [] # puntos de interes del mundo (casas, tiendas, ciudad, zonas salvajes)
var _poi_cache_built := false

# --- Asesor estrategico externo (opcional) ---
# Un LLM remoto (p.ej. Groq, endpoint compatible con OpenAI) decide a nivel
# estrategico que hacer: a que zona ir, si volver a casa, si descansar o que
# tipo de zona evitar. NUNCA toca supervivencia, combate, crafteo ni ordenes:
# eso sigue siendo GDScript. Si no hay API key (OS.get_environment("GROQ_API_KEY")),
# la API falla o la respuesta no valida, los bots se comportan igual sin asesor.
# Las peticiones de los bots comparten UNA cola (_ai_queue, una en vuelo) y solo
# salen cuando la situacion cambia o el plan termina — no por temporizador. La
# directiva devuelta se guarda y sigue mandando hasta que el plan se completa
# (llegar, visitar el POI, comer, descansar) o algo relevante lo interrumpe.
const AI_ADVISOR_URL := "https://api.groq.com/openai/v1/chat/completions"
# Dos modelos distintos: las cuotas de Groq son POR MODELO, asi que el chat no
# compite con las decisiones tactica por la misma ventana de tokens. Override
# por env: GROQ_DECISION_MODEL / GROQ_CHAT_MODEL.
const AI_ADVISOR_MODEL := "qwen/qwen3.8-27b"
# Cuota propia por modelo: si la diaria (TPD/RPD) del principal se agota,
# el asesor salta al fallback en vez de quedarse en rate_limited.
const AI_ADVISOR_FALLBACK_MODEL := "openai/gpt-oss-20b"
const AI_CHAT_MODEL := "openai/gpt-oss-120b"
# Proveedor secundario GRATUITO (cadena Groq -> secundario -> cerebro local):
# cuando la cuota diaria de Groq se agota o los 429 se encadenan, el asesor
# salta aqui en vez de quedarse en rate_limited. Endpoint OpenAI-compatible
# (Gemini AI Studio: 15 RPM / 1M TPM / ~1.5K RPD gratis) — overridable por env
# GEMINI_URL / GEMINI_MODEL / GEMINI_CHAT_MODEL; la key va en GEMINI_API_KEY.
const AI_PROVIDER2_URL := "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
const AI_PROVIDER2_MODEL := "gemini-3.5-flash-lite"
const AI_DIRECTIVE_TTL_MSEC := 1500 * 1000 # base temporal del plan (referencia para el watchdog de planes atascados)
const AI_SIG_POLL_SEC := 4.0           # sondeo local de firma por turnos (un bot por ciclo)
const AI_MIN_CALL_GAP_SEC := 150.0     # minimo entre llamadas remotas de un mismo bot
const AI_GLOBAL_MIN_CALL_GAP_SEC := 30.0  # minimo entre CUALQUIER par de llamadas — el TPM gratis del modelo (~6k tok/min) solo admite ~2 consultas/min
const AI_FORCE_GLOBAL_GAP_SEC := 15.0  # suelo global incluso para sucesos forzados
const AI_REVIEW_MAX_SEC := 2400.0      # revision de cortesia aunque nada cambie
const AI_PLAN_STALE_GRACE_SEC := 1500.0 # margen tras el TTL para revalidar un plan que no termina
# Margen de permanencia en destino por tipo de accion: el tiempo que se
# tolera en el punto para que el objetivo produzca su resultado (botin,
# baja, refugio, comida) antes de declarar el paso fracasado.
const AI_STEP_DWELL_SEC := {"explore": 30.0, "scavenge": 75.0, "hunt": 150.0, "forage": 120.0, "seek_ally": 60.0, "rest": 240.0, "avoid_zone": 45.0, "fortify_camp": 90.0, "return_home": 15.0}
const AI_MAX_CALLS_PER_DAY := 380
const AI_MAX_TOKENS_PER_DAY := 120000
# Presupuestos del proveedor secundario: el free tier de Gemini limita por
# RPM/TPM/RPD (sin TPD), asi que el cortafuegos local vigila RPD con margen
# y los tokens solo cortan fugas — no estrangula un pozo mucho mas grande.
const AI_MAX_CALLS_PER_DAY_2 := 600
const AI_MAX_TOKENS_PER_DAY_2 := 900000
const AI_POI_KINDS := ["house", "military", "city", "wild", "tower"]
# Motor de utilidad esperada (BotUtilityAI.gd): la decision local puntua con
# U = p×beneficio − coste − aversion×riesgo. false = heuristica heredada.
# Anulable por llamada con situation["engine"]="legacy" para comparar motores.
const BOT_UTILITY_ENGINE := true
const BotUtilityAI = preload("res://scripts/BotUtilityAI.gd")
const AI_ALLOWED_ACTIONS := ["explore", "scavenge", "hunt", "return_home", "rest", "avoid_zone", "forage", "fortify_camp", "seek_ally"]
const AI_PERSONALITY_TRAITS := ["bravery", "aggression", "curiosity", "sociability", "distrust", "cooperation", "survival_instinct"]
const AI_MEMORY_PATH := "user://survivor_bot_memory.json"
const AI_STATUS_PATH := "user://survivor_bot_status.json"
const AI_STATUS_SAVE_SEC := 2.0
const AI_MEMORY_MAX_SPOTS := 10
const AI_MEMORY_MAX_EVENTS := 28
const AI_OBSERVE_RADIUS := 72.0
const AI_SHARE_RADIUS := 14.0
# El intercambio de mapa entre aliados es gradual, como hablar de verdad:
# hace falta un rato de convivencia para la primera tanda, cada encuentro
# traspasa unas pocas ubicaciones (las que el compañero recomendaria: lo
# visitado y lo peligroso) y hay pausa entre transmisiones. Un recien
# llegado NO hereda el mapa entero — empieza de cero y aprende viviendo.
const SHARE_MIN_CONTACT_SEC := 45.0
const SHARE_COOLDOWN_SEC := 150.0
const SHARE_MAX_LOCS := 4
const SHARE_MAX_RELS := 3
# Minimo de compromiso con un objetivo vivo: una revalidacion remota de igual
# o menor prioridad no desbanca una directiva mas joven que esta ventana.
const AI_DIRECTIVE_MIN_COMMIT_SEC := 300.0
const AI_MEMORY_SAVE_SEC := 90.0
const AI_SYSTEM_PROMPT := "You are the cognitive engine for a survival-game NPC in Last Day. Output ONLY strict JSON, no prose: {\"goal\":\"...\",\"action\":\"...\",\"target\":\"...\",\"priority\":3,\"reason\":\"...\"}. State scales (0..100 reserves, HIGHER IS BETTER): hp=100 healthy/0 dead, hunger=100 full/0 starving, thirst=100 hydrated/0 dehydrated, sleep=100 rested/0 exhausted (<35 urgent, >75 satisfied — NEVER treat 75+ hunger/thirst as hungry or thirsty). Allowed actions: explore, scavenge, hunt, forage, return_home, rest, avoid_zone, fortify_camp, seek_ally. target: one of house, military, city, wild, tower, camp, ally, or a known_locations id from the prompt (NEVER invent unknown coordinates). priority: integer 1..5. Weigh personality traits, survival needs, relationships, and memories. reason: max 8 words. You may instead return {\"steps\":[decision,decision]} with 1 to 4 ordered decisions using the same schema. Each step must be independently achievable; only use return_home/rest/fortify_camp if a camp or shelter exists. Survival emergencies override plans. Do not invent unsupported actions such as fill_container. There is no combat action: aggression or self-defense is expressed only through movement goals — hunt targets wild game, explore/scavenge/avoid_zone position the bot. Never output attack, ambush, raid, steal, kill, chase or similar verbs. recent_failures lists goals that recently failed with their cause and zone, and unreachable lists destinations with no known route for left_min minutes — prefer alternative places/actions over retrying them. observed_players lists spots a seen human used (sleep/fish/campfire/house) with age_min — treat them as human-vetted candidate locations."
var _ai_http: HTTPRequest = null
var _ai_pending_bot := 0
var _ai_next_at: Dictionary = {} # bot_id -> msec epoch del proximo intento
var _ai_calls_day := 0
var _ai_calls_total := 0
var _ai_tokens_day := 0
var _ai_tokens_total := 0
# El limite diario de Groq es POR MODELO: los presupuestos locales van por
# modelo para que agotar el de qwen no bloquee al fallback ni al chat.
var _ai_calls_day_by_model := {}
var _ai_tokens_day_by_model := {}
var _ai_pending_model := "" # modelo de la peticion en vuelo (atribuye sus tokens)
var _ai_cache_hits := 0
# Caché de decisiones por firma de situación: si la misma situación vuelve
# (el bot ya vio "tengo hambre, sin refugio, de día" hace 10 min), la última
# respuesta válida se reaplica sin quemar una llamada del presupuesto diario.
const AI_DECISION_CACHE_TTL_SEC := 900.0
const AI_DECISION_CACHE_MAX := 48
var _ai_decision_cache: Dictionary = {} # "bot_id|sig" -> {t: msec, content: String}
var _ai_429_count := 0
var _ai_latency_ms_last := 0
var _ai_latency_ms_avg := 0
var _ai_day_key := -1
var _ai_rr := 0
var _mem_accum := 0.0
var _status_accum := 0.0
var _ai_queue: Array = [] # cola compartida [{bot_id, priority, reason, t, force}]
var _status_write_task := -1
var _mem_write_task := -1
var _ai_last_sig: Dictionary = {} # bot_id -> String firma de situacion
var _ai_last_call_msec: Dictionary = {} # bot_id -> msec ultima llamada remota
var _ai_last_any_call_msec := 0        # msec de la ultima llamada de cualquier bot (ritmo global)
var _ai_sig_accum := 0.0
var _ai_backoff_until_msec := 0
var _ai_conn_status := "idle"
# Backoff/estado del canal de chat: va aparte porque el limite de tokens es por
# modelo — un 429 de qwen no debe silenciar el chat (otro modelo, otra cuota).
var _chat_backoff_until_msec := 0
var _chat_backoff_sec := 30.0
var _chat_conn_status := "idle"

# Relevo de modelo dentro de cada pozo ("" = modelo base de la cadena). La
# cuota diaria se mide por MODELO (RPD 500 por modelo en Gemini; en Groq la
# TPD es org-wide pero los limites de minuto son por modelo), asi que un
# "per day" encadena al siguiente modelo del mismo proveedor antes de vetarlo.
var _ai_model_override := ["", ""]
# Proveedor activo del asesor: 0 = Groq primario, 1 = secundario (Gemini).
# La cadena es Groq -> modelo fallback de Groq -> secundario -> cerebro local;
# _ai_pending_provider marca el proveedor de la peticion en vuelo y
# _ai_429_streak la racha de 429 que dispara el salto por agotamiento de TPM.
var _ai_provider := 0
var _ai_pending_provider := 0
var _ai_429_streak := 0
# Estado POR proveedor: cada pozo lleva su propio backoff (el 429 de uno no
# silencia al otro), su exponencial y su veto de cuota diaria. El primario
# vuelve a servir en cuanto se libera su ventana — los pozos se turnan solos.
var _ai_provider_blocked_until: Array = [0, 0]
var _ai_provider_backoff_sec: Array = [4.0, 4.0]
var _ai_provider_day_done: Array = [false, false]
# Los vetos diarios son semipermeables: los free tiers liberan cuota antes
# del reset (ventanas deslizantes, pozos por proyecto), asi que cada veto se
# sondea cada AI_PROVIDER_DAY_PROBE_SEC y un 200 lo levanta.
const AI_PROVIDER_DAY_PROBE_SEC := 900.0
var _ai_provider_day_probe_at: Array = [0, 0]

func _ai_provider_name(p: int = -1) -> String:
	var pv := _ai_provider if p < 0 else p
	return "gemini" if pv == 1 else "groq"

func _ai_provider_has_key(p: int) -> bool:
	return not OS.get_environment("GEMINI_API_KEY" if p == 1 else "GROQ_API_KEY").strip_edges().is_empty()

func _ai_provider_key() -> String:
	return OS.get_environment("GEMINI_API_KEY" if _ai_provider == 1 else "GROQ_API_KEY").strip_edges()

func _ai_provider_url() -> String:
	if _ai_provider == 1:
		var u := OS.get_environment("GEMINI_URL").strip_edges()
		return u if not u.is_empty() else AI_PROVIDER2_URL
	return AI_ADVISOR_URL

# Proveedor utilizable ahora mismo: con key, fuera de su backoff propio y sin
# veto diario vigente — o con veto cuyo plazo de sonda ya llego (un pozo
# liberado se redescubre solo; si sigue seco, el 429 renueva el veto).
func _ai_provider_usable(p: int, now: int) -> bool:
	if not _ai_provider_has_key(p) or now < int(_ai_provider_blocked_until[p]):
		return false
	return not bool(_ai_provider_day_done[p]) or now >= int(_ai_provider_day_probe_at[p])

# Salto de proveedor con un backoff breve de asentamiento: el pozo de cuota
# es independiente y el cerebro local cubre esos segundos si tampoco sirve.
func _ai_switch_provider(reason: String, to := 1) -> void:
	_ai_provider = to
	_ai_backoff_until_msec = Time.get_ticks_msec() + 3000
	_ai_conn_status = "provider_switch -> %s (%s)" % [_ai_provider_name(), reason]
	print("[AI-ADV] cambio de proveedor -> %s (%s)" % [_ai_provider_name(), reason])

# Modelo efectivo para decisiones segun el proveedor activo (los presupuestos
# locales van por nombre de modelo, asi cada pozo se mide aparte).
func _ai_active_model() -> String:
	var o: String = _ai_model_override[_ai_provider]
	if not o.is_empty():
		return o
	if _ai_provider == 1:
		var m := OS.get_environment("GEMINI_MODEL").strip_edges()
		return m if not m.is_empty() else AI_PROVIDER2_MODEL
	return _ai_decision_model()

func _ai_active_chat_model() -> String:
	if _ai_provider == 1:
		var m := OS.get_environment("GEMINI_CHAT_MODEL").strip_edges()
		return m if not m.is_empty() else _ai_active_model()
	return _ai_chat_model()

# Presupuesto local por modelo (Groq limita por modelo y por dia):
# agotar el de qwen no silencia al fallback ni al chat. El techo depende del
# proveedor dueno del modelo — el de Gemini es mucho mas holgado que el de
# Groq (su free tier no tiene TPD; solo RPM/TPM/RPD).
func _ai_model_quota_open(model: String, provider := -1) -> bool:
	var p := _ai_provider if provider < 0 else provider
	var max_calls := AI_MAX_CALLS_PER_DAY_2 if p == 1 else ai_max_calls_per_day
	var max_tokens := AI_MAX_TOKENS_PER_DAY_2 if p == 1 else ai_max_tokens_per_day
	return int(_ai_calls_day_by_model.get(model, 0)) < max_calls and int(_ai_tokens_day_by_model.get(model, 0)) < max_tokens

func _ai_count_model_call(model: String) -> void:
	_ai_calls_day_by_model[model] = int(_ai_calls_day_by_model.get(model, 0)) + 1

func _ai_count_model_tokens(model: String, n: int) -> void:
	_ai_tokens_day_by_model[model] = int(_ai_tokens_day_by_model.get(model, 0)) + n

func _ai_decision_model() -> String:
	var m := OS.get_environment("GROQ_DECISION_MODEL").strip_edges()
	if not m.is_empty():
		return m
	var o: String = _ai_model_override[0]
	return o if not o.is_empty() else AI_ADVISOR_MODEL

# Cadena de relevo de modelos por proveedor: el primero es el configurable
# por env; los siguientes son relevos verificados con cuota diaria propia.
func _ai_model_chain(p: int) -> Array:
	var chain: Array = []
	if p == 1:
		var base := OS.get_environment("GEMINI_MODEL").strip_edges()
		chain.append(base if not base.is_empty() else AI_PROVIDER2_MODEL)
		for m in ["gemini-3.1-flash-lite"]:
			if m != chain[0]:
				chain.append(m)
	else:
		var env_m := OS.get_environment("GROQ_DECISION_MODEL").strip_edges()
		chain.append(env_m if not env_m.is_empty() else AI_ADVISOR_MODEL)
		for m in [AI_ADVISOR_FALLBACK_MODEL, AI_CHAT_MODEL]:
			if m != chain[0]:
				chain.append(m)
	return chain

func _ai_chain_current_model(p: int) -> String:
	var o: String = _ai_model_override[p]
	return o if not o.is_empty() else String(_ai_model_chain(p)[0])

# Avanza al siguiente modelo de la cadena del pozo; false si ya se agoto.
func _ai_advance_model_chain(p: int) -> bool:
	var chain := _ai_model_chain(p)
	var i := chain.find(_ai_chain_current_model(p))
	if i < 0 or i >= chain.size() - 1:
		return false
	_ai_model_override[p] = String(chain[i + 1])
	return true

func _ai_chat_model() -> String:
	var m := OS.get_environment("GROQ_CHAT_MODEL").strip_edges()
	return m if not m.is_empty() else AI_CHAT_MODEL
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

# Un campamento ademas necesita estar a >=35 m de cualquier otro campamento IA
# (salvo que el otro bot sea su lider de equipo: las bases compartidas juntan
# refugios a ~14 m). avoid_spots marca solares quemados que nunca se repiten.
func _is_valid_camp_pos(pos: Vector3, ally_id: int = 0, avoid_spots: Array = [], self_id: int = 0) -> bool:
	if not _is_flat_dry_pos(pos):
		return false
	for other_id in bots.keys():
		if int(other_id) == self_id:
			continue # su propio solar no se bloquea a si mismo al re-anclar
		var ob: Dictionary = bots[other_id]
		var min_d := 14.0 if int(other_id) == ally_id or _camps_may_share(self_id, int(other_id)) else 120.0
		if ob.get("shelter_pos", Vector3.INF) != Vector3.INF and pos.distance_to(ob["shelter_pos"]) < min_d:
			return false
		if ob.get("camp_spot", Vector3.INF) != Vector3.INF and pos.distance_to(ob["camp_spot"]) < min_d:
			return false
	for s in avoid_spots:
		if s is Dictionary:
			var dx := pos.x - float(s.get("x", 0.0))
			var dz := pos.z - float(s.get("z", 0.0))
			if dx * dx + dz * dz < 2025.0: # 45 m alrededor del solar quemado
				return false
	return true

# Distancia al POI "caliente" (ciudad/base militar) mas cercano: las bases de
# bots se levantan lejos del saqueo humano habitual.
func _nearest_poi_dist(pos: Vector3, kinds: Array) -> float:
	var best := 10000.0
	for p in _explore_pois():
		if str(p.get("kind", "")) in kinds:
			var pp: Vector3 = p["pos"]
			best = minf(best, Vector2(pos.x - pp.x, pos.z - pp.z).length())
	return best

# Distancia al campamento/refugio de otro bot mas cercano: las bases no se
# apiñan — cada superviviente reclama su propio territorio alejado.
func _nearest_other_camp_dist(pos: Vector3, self_id: int) -> float:
	var best := 10000.0
	for other_id in bots.keys():
		if int(other_id) == self_id:
			continue
		var ob: Dictionary = bots[other_id]
		for k in ["camp_spot", "shelter_pos"]:
			var op: Vector3 = ob.get(k, Vector3.INF)
			if op != Vector3.INF:
				best = minf(best, Vector2(pos.x - op.x, pos.z - op.z).length())
	return best

# Emplazamiento de la base propia en zona alejada: anclada a los POIs "wild"
# del mapa, >=140 m del centro de spawn, lejos de POIs calientes y de los
# puntos donde el bot ya murio o le quemaron la base. Cada bot tira hacia su
# propio sector para que las bases queden repartidas por el mapa.
# Acampar juntos exige tolerancia mutua REGISTRADA: una relacion ya tratada
# sin hostilidad ni miedo en ambos sentidos. Dos bots que jamas se han visto
# no comparten fogata — son extranos y cada cual reclama su propio solar a
# >=120 m (asi las bases nacen repartidas por el mapa). Cuando dos bandidos
# se conocen y no se temen, el llano compartido emerge solo.
func _camp_rel_stored(a_id: int, b_id: int) -> Dictionary:
	var key := "bot_%d" % b_id
	var rels: Dictionary = _ensure_bot_memory(a_id).get("relationships", {})
	if rels.has(key) and rels[key] is Dictionary:
		return rels[key]
	return {}

func _camps_may_share(a_id: int, b_id: int) -> bool:
	if a_id <= 0 or b_id <= 0 or a_id == b_id:
		return false
	var ra := _camp_rel_stored(a_id, b_id)
	var rb := _camp_rel_stored(b_id, a_id)
	if ra.is_empty() or rb.is_empty():
		return false
	for rel in [ra, rb]:
		if float(rel.get("hostility", 0.0)) > 0.4 or float(rel.get("fear", 0.0)) > 0.55:
			return false
	return true

# Ancla de campamento de banda: el campamento del superviviente tolerado mas
# cercano a la posicion dada. Junto a el el nuevo solar queda a 14-26 m — un
# mismo llano de refugios para socorrerse de noche, sin pisarse las fogatas.
func _band_camp_anchor(bot_id: int, near_pos: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for oid in bots.keys():
		if int(oid) == bot_id or not _camps_may_share(bot_id, int(oid)):
			continue
		var ob: Dictionary = bots[oid]
		var oc: Vector3 = ob.get("shelter_pos", Vector3.INF)
		if oc == Vector3.INF:
			oc = ob.get("camp_spot", Vector3.INF)
		if oc == Vector3.INF:
			continue
		var d := near_pos.distance_to(oc)
		if d < best_d:
			best_d = d
			best = oc
	return best

# Eleccion de solar: la banda antes que el territorio propio — si otro
# superviviente tolerado ya tiene campamento, el nuevo solar se reclama junto
# al suyo para pasar las noches en el mismo sitio y ayudarse entre ellos.
func _pick_camp_anchor(bot_id: int, near_pos: Vector3, mem: Dictionary) -> Vector3:
	var band := _band_camp_anchor(bot_id, near_pos)
	return band if band != Vector3.INF else _pick_remote_base_spot(bot_id, near_pos, mem)

func _pick_remote_base_spot(bot_id: int, spawn_pos: Vector3, mem: Dictionary) -> Vector3:
	var bad: Array = []
	bad.append_array(mem.get("bad_camp_spots", []))
	bad.append_array(mem.get("death_spots", []))
	var sector := TAU * float(bot_id % 97) / 7.0
	var anchor := spawn_pos + Vector3(cos(sector), 0.0, sin(sector)) * 230.0
	var best := anchor
	var best_score := -1.0
	var cands: Array = [anchor]
	for p in _explore_pois():
		if str(p.get("kind", "")) == "wild":
			cands.append(p["pos"])
	for c in cands:
		var cp: Vector3 = _sanitize_ground_point(c)
		var d_center := Vector2(cp.x, cp.z).length()
		if d_center < 140.0:
			continue
		var hot_d := _nearest_poi_dist(cp, ["military", "city", "tower"])
		if hot_d < 45.0:
			continue
		var near_bad := false
		for s in bad:
			if s is Dictionary:
				var dx := cp.x - float(s.get("x", 0.0))
				var dz := cp.z - float(s.get("z", 0.0))
				if dx * dx + dz * dz < 3600.0: # 60 m
					near_bad = true
					break
		if near_bad:
			continue
		var score := d_center * 0.5 + clampf(hot_d, 0.0, 120.0) * 0.8 - cp.distance_to(anchor) * 0.6
		score += _base_spot_safety(mem, cp)
		# Territorio propio: las bases de los bots no se apiñan — cada solar
		# puntua mejor cuanto mas lejos quede de los campamentos de los demas.
		score += minf(_nearest_other_camp_dist(cp, bot_id), 300.0) * 0.6
		if score > best_score:
			best_score = score
			best = cp
	return best

# Seguridad aprendida del emplazamiento de base: lo que el bot ya sabe del
# mundo pesa en la eleccion del solar — muertes propias cerca, zonas marcadas
# como peligrosas, acceso a agua a tiro util (ni pegada ni a dias de camino)
# y arboles que oculten el refugio. Con supervivencia alta el miedo pesa mas.
func _base_spot_safety(mem: Dictionary, cp: Vector3) -> float:
	var surv := float((mem.get("personality", {}) as Dictionary).get("survival_instinct", 0.7))
	var fear_w := 0.7 + surv * 0.6
	var score := 0.0
	for s in mem.get("death_spots", []):
		if not (s is Dictionary):
			continue
		var dx := cp.x - float(s.get("x", 0.0))
		var dz := cp.z - float(s.get("z", 0.0))
		var d2 := dx * dx + dz * dz
		if d2 < 22500.0: # 150 m
			var dcnt := clampi(int(s.get("count", 1)), 1, 4)
			score -= (1.0 - sqrt(d2) / 150.0) * 90.0 * dcnt * fear_w
	for loc in (mem.get("known_locations", {}) as Dictionary).values():
		if not (loc is Dictionary):
			continue
		var risk := float((loc as Dictionary).get("risk", 0.0))
		if risk <= 0.0:
			continue
		var lp = (loc as Dictionary).get("pos", null)
		if lp is Array and lp.size() >= 3:
			var ldx := cp.x - float(lp[0])
			var ldz := cp.z - float(lp[2])
			var ld2 := ldx * ldx + ldz * ldz
			if ld2 < 10000.0: # 100 m
				score -= risk * (1.0 - sqrt(ld2) / 100.0) * 35.0 * fear_w
	# Agua a tiro util para las salidas de aprovisionamiento (20-90 m suma,
	# pegada a la orilla resta un poco por fauna, >150 m no puntua).
	var wp := _nearest_water_pos(cp, {})
	if wp != Vector3.INF:
		var wd := Vector2(cp.x - wp.x, cp.z - wp.z).length()
		if wd < 15.0:
			score -= 12.0
		elif wd <= 90.0:
			score += 18.0 * (1.0 - absf(wd - 45.0) / 45.0)
		elif wd > 150.0:
			score -= 8.0
	# Arboles cercanos: camuflaje natural para el refugio.
	var tree_d := _nearest_tree_dist(cp, 30.0)
	score += (1.0 - clampf(tree_d / 30.0, 0.0, 1.0)) * 22.0
	return score

# Busca en espiral alrededor del punto preferido un sitio valido de campamento,
# preferiblemente junto a arboles (oculto) en vez de en mitad del campo.
func _find_valid_camp_spot(preferred: Vector3, _near: Vector3, ally_id: int = 0, avoid_spots: Array = [], self_id: int = 0) -> Vector3:
	var best := preferred
	var best_score := -1.0
	var found := false
	for radius in [0.0, 8.0, 16.0, 26.0, 40.0, 60.0, 90.0, 120.0]:
		var steps := 8 if radius > 0.0 else 1
		for i in range(steps):
			var ang := TAU * float(i) / float(steps)
			var cand := preferred + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
			cand.y = _ground_y(cand.x, cand.z)
			if not _is_valid_camp_pos(cand, ally_id, avoid_spots, self_id):
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

var _cached_wa_size := -1
var _cached_wa_last := ""
var _cached_tree_positions: Array = []
var _cached_drink_ids: Array = []
var _cached_eat_ids: Array = []
var _cached_fruit_ids: Array = []
var _cached_mat_ids: Array = []

func _ensure_world_action_caches() -> void:
	if world == null or not ("world_actions_by_id" in world):
		return
	var wa_dict: Dictionary = world.world_actions_by_id
	var sz := wa_dict.size()
	var lk := str(wa_dict.keys().back()) if sz > 0 else ""
	if sz == _cached_wa_size and lk == _cached_wa_last:
		return
	_cached_wa_size = sz
	_cached_wa_last = lk
	_cached_tree_positions.clear()
	_cached_drink_ids.clear()
	_cached_eat_ids.clear()
	_cached_fruit_ids.clear()
	_cached_mat_ids.clear()
	for aid in wa_dict.keys():
		var a = wa_dict[aid]
		if a == null or not is_instance_valid(a) or not (a is Node3D):
			continue
		var at := str(a.get("action_type"))
		if at == "fell_tree":
			_cached_tree_positions.append((a as Node3D).global_position)
			_cached_mat_ids.append(aid)
		elif at == "fell_bush":
			_cached_tree_positions.append((a as Node3D).global_position)
			_cached_mat_ids.append(aid)
		elif at == "wood" or at == "stone":
			_cached_mat_ids.append(aid)
		elif at == "drink_water":
			_cached_drink_ids.append(aid)
		elif at == "eat_food":
			_cached_eat_ids.append(aid)
		elif at == "pick_fruit":
			_cached_fruit_ids.append(aid)

func _nearest_tree_dist(pos: Vector3, max_dist: float) -> float:
	if world == null or not ("world_actions_by_id" in world):
		return max_dist
	_ensure_world_action_caches()
	var best_sq := max_dist * max_dist
	for tp in _cached_tree_positions:
		var d_sq := pos.distance_squared_to(tp as Vector3)
		if d_sq < best_sq:
			best_sq = d_sq
	return sqrt(best_sq)

# Punto de agua alcanzable mas cercano (segmentos del rio/lago) para que el
# superviviente vaya a beber cuando se quede sin botellas.
func _nearest_water_pos(from: Vector3, b: Dictionary = {}) -> Vector3:
	if world == null or not world.has_method("_default_river_segments"):
		return Vector3.INF
	# Sed critica (<18): la muerte por deshidratacion no se negocia — se salta
	# la puerta de oscuridad nocturna Y la lista negra de puntos vetados: la
	# unica fuente alcanzable se reintenta aunque antes fallara la ruta (la
	# fuente de la plaza de Elena). Ojo: solo la urgencia lo pasa — beber de
	# noche sin urgencia abria caminatas a oscuras condenadas al veto.
	var desperate := not b.is_empty() and float(b.get("thirst", 100.0)) < 18.0
	var cands: Array = []
	var add_cand := func(target_pt: Vector3) -> void:
		var d := Vector2(from.x - target_pt.x, from.z - target_pt.z).length()
		if not b.is_empty() and not desperate and (_is_water_blacklisted(b, target_pt) or not _bot_supply_goal_allowed(b, target_pt)):
			return
		cands.append({"pos": target_pt, "d": d})
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
		add_cand.call(target_pt)
	# Fuentes y otras zonas drink_water en tierra firme (p.ej. la fuente de la
	# plaza de la ciudad): el bot puede beber y rellenar su botella en ellas
	# igual que un jugador con E mantenida. Las acciones drink_N del rio/lago
	# caen dentro del agua y ya las cubren los segmentos de arriba.
	if "world_actions_by_id" in world:
		_ensure_world_action_caches()
		for aid in _cached_drink_ids:
			var a = world.world_actions_by_id.get(aid)
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
			add_cand.call(target_pt)
	if cands.is_empty():
		return Vector3.INF
	# Si los vetos _bad_water se acumulan en un mismo rumbo, el "siguiente mas
	# cercano" cae en la misma orilla bloqueada (la muerte de Elena en la
	# ciudad del sur): preferir el candidato mas cercano con un rumbo a
	# >=45° de TODOS los puntos vetados vigentes.
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var veto_dirs: Array = []
	for e in (b.get("_bad_water", []) as Array):
		if e is Dictionary and float(e.get("until", 0.0)) > now_s and e.get("pos") is Vector3:
			var vd := Vector2((e["pos"] as Vector3).x - from.x, (e["pos"] as Vector3).z - from.z)
			if vd.length() > 1.0:
				veto_dirs.append(vd.angle())
	if not veto_dirs.is_empty():
		var best_dir := Vector3.INF
		var best_dir_d := INF
		for c in cands:
			var cp: Vector3 = c["pos"]
			var cd := Vector2(cp.x - from.x, cp.z - from.z).angle()
			var blocked_dir := false
			for va in veto_dirs:
				if absf(wrapf(cd - float(va), -PI, PI)) < deg_to_rad(45.0):
					blocked_dir = true
					break
			if not blocked_dir and float(c["d"]) < best_dir_d:
				best_dir_d = float(c["d"])
				best_dir = cp
		if best_dir != Vector3.INF:
			return best_dir
	var best := Vector3.INF
	var best_d := 650.0
	for c in cands:
		if float(c["d"]) < best_d:
			best_d = float(c["d"])
			best = c["pos"]
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
		# Los objetivos sobreviven al reinicio: retoma el plan que el bot
		# llevaba cuando se apago el mundo (solo arranque de sesion, no respawn).
		_ai_resume_pending_plan(int(cfg["bot_id"]))
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
	var mem0: Dictionary = _ensure_bot_memory(bot_id, cfg)
	var spawn_pos: Vector3 = _random_bot_spawn(cfg, Vector3(mem0.get("last_death_pos", Vector3.INF)))
	# Todos los bots nacen hostiles; solo respeta la memoria el que un jugador
	# ya convencio antes (identity.allegiance == "friendly" lo grabo _set_bot_faction).
	var eff_faction := str(cfg["faction"])
	if str((mem0.get("identity", {}) as Dictionary).get("allegiance", "")) == "friendly":
		eff_faction = "friendly"
	var patrol: Array = []
	for pt in cfg.get("patrol", []):
		patrol.append(_sanitize_ground_point(pt as Vector3))
	if world.get("_military_tent_pos") is Vector3 and world._military_tent_pos != Vector3.ZERO:
		var mt: Vector3 = world._military_tent_pos
		patrol.append(_sanitize_ground_point(mt))
	# El campamento debe estar en un sitio valido: tierra firme, fuera de
	# carreteras/casas, terreno llano y lejos de otros campamentos. Ademas el
	# bot elige una base propia en zona alejada del centro — salvo que su
	# memoria ya tenga un refugio reclamado, en cuyo caso vuelve a su solar.
	var preferred_camp: Vector3 = _pick_camp_anchor(bot_id, spawn_pos, mem0)
	# El solar solo se hereda si el refugio sigue EN PIE en este mundo: un
	# mem.shelter cuyo edificio ya no existe (destruido o mundo nuevo) no
	# puede anclar el campamento — mas abajo (restauracion) se olvida, y
	# sembrarla aqui mandaba al bot en romeria a un solar vacio.
	var mem_sh0: Dictionary = mem0.get("shelter", {}) if mem0.get("shelter") is Dictionary else {}
	var sh_id0 := str(mem_sh0.get("id", ""))
	if not sh_id0.is_empty() and mem_sh0.get("pos") is Array and (mem_sh0["pos"] as Array).size() >= 3 \
			and not _find_shelter_dict(sh_id0).is_empty():
		preferred_camp = Vector3(float(mem_sh0["pos"][0]), float(mem_sh0["pos"][1]), float(mem_sh0["pos"][2]))
	var camp_spot: Vector3 = _find_valid_camp_spot(preferred_camp, spawn_pos, 0, mem0.get("bad_camp_spots", []), bot_id)

	var proxy := Node3D.new()
	proxy.name = "ServerProxy_%d" % bot_id
	proxy.position = spawn_pos
	proxy.set_meta("peer_id", bot_id)
	proxy.set_meta("client_id", str(cfg["client_id"]))
	proxy.set_meta("is_ai_bot", true)
	proxy.set_meta("bot_name", str(cfg["name"]))
	proxy.set_meta("bot_faction", eff_faction)
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
		"faction": eff_faction, # "friendly" | "hostile"
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
		"_last_foe_pos": Vector3.INF,
		"_lost_foe_pos": Vector3.INF,
		"_lost_foe_until_msec": 0,
		"_lost_sector": Vector3.INF,
		"_lost_sectors": 0,
		"_foe_mem": {},
		"_loot_n": 0,
		"_loot_food_n": 0,
		"_lost_scan_t": 0.0,
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
	# Sin padre en el arbol el Node quedaba huerfano al liberar el bot —
	# ObjectDB lo reportaba como leak en cada respawn.
	add_child(vstats)
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
	var pred_lessons_spawn := int((mem.get("death_lessons", {}) as Dictionary).get("predator", 0))
	var base_caution := 240.0 if str(mem.get("last_death_cause", "")) in ["wolf_bite", "bear_bite", "starved", "dehydrated", "hypothermia"] else 0.0
	bot_state["caution_until"] = base_caution + float(pred_lessons_spawn) * 60.0
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

# Cambio de faccion en caliente (hostil -> aliado tras convencerlo): actualiza
# el estado, los metas del proxy/avatar, la memoria persistente (allegiance) y
# republica el bot para que los clientes vean el nuevo bando.
func _set_bot_faction(b: Dictionary, new_faction: String) -> void:
	if str(b.get("faction", "")) == new_faction:
		return
	b["faction"] = new_faction
	var proxy: Node3D = b.get("proxy")
	if proxy != null and is_instance_valid(proxy):
		proxy.set_meta("bot_faction", new_faction)
		if new_faction == "friendly":
			b["aggro_target"] = null
			b["aggro_timer"] = 0.0
			b["crouching"] = false
	var mem := _ensure_bot_memory(int(b["bot_id"]), b.get("cfg", {}))
	if mem.get("identity") is Dictionary:
		(mem["identity"] as Dictionary)["allegiance"] = new_faction
		(mem["identity"] as Dictionary)["faction"] = new_faction
	_publish_bot_to_net_players(b)
	_apply_local_avatar_metadata(b)

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
		"is_aiming": bool(b.get("is_aiming", false)),
		"has_rifle": bool(b["has_rifle"]),
		"sleeping": bool(b["sleeping"]),
		"sitting": bool(b.get("sitting", false)),
		"prone": bool(b["prone"]),
		"crouching": bool(b.get("crouching", false)),
		"torch_lit": bool(b["torch_lit"]),
		"flashlight_on": bool(b["flashlight_on"]),
		"ready": true,
		"in_world": true,
		"offline": false,
		"is_ai_bot": true,
		"bot_faction": str(b["faction"]),
		"team_leader_id": int(b["team_leader_id"]),
		"bot_follow_mode": str(b["follow_mode"]),
		"health": int(b.get("health", 100)),
		"hunger": int(b.get("hunger", 100)),
		"thirst": int(b.get("thirst", 100)),
		"last_seen": Time.get_ticks_msec(),
	}
	if net.is_host and net.is_connected and net.peer != null and net.has_method("sync_bot_team_state"):
		var team_sig := "%d|%s|%d|%d|%d" % [int(b["team_leader_id"]), str(b["follow_mode"]), int(b.get("health", 100)) / 5, int(b.get("hunger", 100)) / 5, int(b.get("thirst", 100)) / 5]
		if str(b.get("_last_team_sig", "")) != team_sig:
			b["_last_team_sig"] = team_sig
			for pid in net.snapshot_recipients():
				if not is_bot_peer_id(pid):
					net.sync_bot_team_state.rpc_id(pid, bot_id, int(b["team_leader_id"]), str(b["follow_mode"]), int(b.get("health", 100)), int(b.get("hunger", 100)), int(b.get("thirst", 100)))

var perf_seg := {}

func _pbm(seg_name: String, t0: int) -> void:
	perf_seg[seg_name] = int(perf_seg.get(seg_name, 0)) + (Time.get_ticks_usec() - t0)

# --- CombatProf driver (LD_COMBAT_PROF): arms rifle bots on the local player
# and dumps per-segment timings every 10 s. Inert in normal runs.
var _cprof_armed := false
var _cprof_dump_t := 0.0

func _combat_probe_driver(delta: float) -> void:
	_cprof_dump_t += delta
	if _cprof_dump_t >= 10.0:
		_cprof_dump_t = 0.0
		var out := CombatProf.dump_and_reset()
		var wild_parts := ""
		for k in WildlifeController.perf_parts.keys():
			wild_parts += "%s=%dms " % [k, int(WildlifeController.perf_parts[k]) / 10 / 1000]
		WildlifeController.perf_usec = 0
		WildlifeController.perf_parts.clear()
		print("[CPROF] %s%s" % [out, ("  wild: " + wild_parts) if not wild_parts.is_empty() else ""])
	if _cprof_armed:
		return
	_cprof_armed = true
	var player = world.get("player") if world != null else null
	if player == null or not (player is Node3D):
		_cprof_armed = false
		return
	var armed := 0
	for bid in bots.keys():
		if armed >= 3:
			break
		var b: Dictionary = bots[bid]
		var proxy: Node3D = b.get("proxy")
		if proxy == null or not is_instance_valid(proxy):
			continue
		var inv: Array = proxy.get_meta("saved_inventory", [])
		inv.append({"name": "Fusil de asalto", "type": "weapon", "quantity": 1, "durability": 100.0, "max_durability": 100.0})
		inv.append({"name": "Balas 5,56", "type": "ammo", "quantity": 10, "use_value": 30})
		proxy.set_meta("saved_inventory", inv)
		proxy.set_meta("has_rifle", true)
		b["aggro_target"] = player
		b["aggro_timer"] = 120.0
		b["sense_t"] = 0.0
		b["faction"] = "hostile"
		armed += 1
		print("[CPROF] armed bot %d" % int(bid))
	if armed > 0:
		var first_proxy: Node3D = bots[bots.keys()[0]]["proxy"]
		(player as Node3D).global_position = first_proxy.global_position + Vector3(0.0, 0.0, 18.0)
		print("[CPROF] player teleported in front of bots")

func tick(delta: float) -> void:
	if world == null:
		return
	var net = world.get("net")
	# Solo la instancia con autoridad (servidor dedicado, host o singleplayer) simula la IA
	if net != null and net.is_connected and not net.is_host:
		_refresh_client_bot_avatars()
		return
	var _pt := Time.get_ticks_usec()
	if CombatProf.driver:
		_combat_probe_driver(delta)
	_voice_tick(delta)
	_pbm("voice", _pt)
	_pt = Time.get_ticks_usec()
	for bot_id in bots.keys():
		var bot_started := Time.get_ticks_usec()
		var b: Dictionary = bots[bot_id]
		var proxy: Node3D = b.get("proxy")
		var before := proxy.global_position if is_instance_valid(proxy) else Vector3.ZERO
		_tick_bot(b, delta)
		PlanManager.sync(self, b, Time.get_ticks_msec())
		_finish_bot_motion_tick(b,before,delta)
		_pbm("actor_%s" % bot_id, bot_started)
	_pbm("tick_bot", _pt)
	_pt = Time.get_ticks_usec()
	_ai_tick(delta)
	_pbm("ai_tick", _pt)
	_pt = Time.get_ticks_usec()
	_mem_accum += delta
	if _mem_accum >= AI_MEMORY_SAVE_SEC:
		_mem_accum = 0.0
		_ai_save_memory()
	_status_accum += delta
	if _status_accum >= AI_STATUS_SAVE_SEC:
		_status_accum = 0.0
		_ai_save_live_status()
	_pbm("saves", _pt)
	_pt = Time.get_ticks_usec()
	_sync_accum += delta
	if _sync_accum >= 0.05:
		_sync_accum = fmod(_sync_accum, 0.05)
		_broadcast_bots()
	_pbm("bcast_bots", _pt)

func _finish_bot_motion_tick(b: Dictionary, before: Vector3, delta: float) -> void:
	var proxy: Node3D = b.get("proxy")
	if not is_instance_valid(proxy): return
	var displacement := proxy.global_position-before
	var moving := displacement.length_squared() > .000001
	proxy.set_meta("moving",moving)
	proxy.set_meta("sprinting",moving and str(b.get("anim","")) == "run")
	if not moving:
		b["_speed"] = 0.0
		b["_mdir"] = Vector3.ZERO
		if str(b.get("anim","")) in ["walk","run","stairs"]: b["anim"] = "idle"
	else:
		b["_speed"] = Vector2(displacement.x,displacement.z).length()/maxf(delta,.001)

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
				rp.set_meta("bot_faction", str(pdata.get("bot_faction", "hostile")))
				rp.set_meta("team_leader_id", int(pdata.get("team_leader_id", 0)))
				rp.set_meta("bot_follow_mode", str(pdata.get("bot_follow_mode", "follow")))
				if pdata.has("health"):
					rp.set_meta("proxy_health", int(pdata.get("health", 100)))
				if pdata.has("hunger"):
					rp.set_meta("saved_hunger", int(pdata.get("hunger", 100)))
				if pdata.has("thirst"):
					rp.set_meta("saved_thirst", int(pdata.get("thirst", 100)))
				if not rp.is_in_group("interactable"):
					rp.add_to_group("interactable")

func _bot_effective_net_anim(b: Dictionary) -> String:
	var raw := str(b.get("anim", "idle"))
	if raw.begins_with("dead"):
		return raw
	# Recarga de fusil: clip propio de la libreria rifle_motion. De pie se ve;
	# arrodillado/tumbado mantiene la postura (no hay clip de recarga bajo).
	if bool(b.get("gun_reloading", false)) and bool(b.get("has_rifle", false)) \
			and raw == "idle" and not bool(b.get("crouching", false)) \
			and not bool(b.get("sitting", false)) and not bool(b.get("prone", false)):
		return "rifle_motion/" + PlayerController.THIRD_PERSON_EXTERNAL_RIFLE_RELOAD_ANIMATION
	if bool(b.get("sleeping", false)):
		return "sleep"
	if float(b.get("consume_anim_t", 0.0)) > 0.0 and raw == "idle":
		return str(b.get("consume_anim", "eat"))
	# Posturas de tiro con fusil: el nombre exacto resuelve directo en el
	# puppet (la libreria external es la misma en todos los clientes). Sin
	# fusil no hay clip prono: cuclillas es lo mas parecido visualmente.
	if bool(b.get("prone", false)):
		if bool(b.get("has_rifle", false)):
			return "external/" + PlayerController.THIRD_PERSON_EXTERNAL_RIFLE_PRONE_ANIMATION
		return "sneak"
	if bool(b.get("sitting", false)) or raw == "sit":
		if bool(b.get("has_rifle", false)) and bool(b.get("is_aiming", false)):
			return "external/" + PlayerController.THIRD_PERSON_EXTERNAL_RIFLE_SIT_ANIMATION
		return "sit"
	if bool(b.get("crouching", false)):
		if raw in ["walk", "run"]:
			return "sneak_walk"
		if raw == "idle":
			return "sneak"
	# Tensado y suelta de arco: los clips viven en la librería "bow" de cada
	# puppet — el nombre exacto resuelve directo en el cliente. Sin esto el
	# arquero parecía quieto y la flecha salía de la nada. Va tras los estados
	# de cuerpo completo (dormir/sentarse/agacharse): esos ganan si coinciden.
	if raw == "idle" and Time.get_ticks_msec() < int(b.get("_bow_shot_anim_until", 0)):
		return "bow/" + PlayerController.THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION
	if bool(b.get("_bow_drawing", false)) and raw in ["idle", "walk"]:
		return "bow/" + (PlayerController.THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION if raw == "walk" else PlayerController.THIRD_PERSON_EXTERNAL_BOW_AIM_IDLE_ANIMATION)
	if bool(b.get("has_rifle", false)):
		# Paso lateral real (strafe): el clip se elige por la direccion de
		# desplazamiento respecto a donde mira el bot — vale apuntando o no.
		if raw == "walk":
			var sd := _bot_net_strafe_dir(b)
			if sd > 0:
				return "rifle_motion/" + PlayerController.THIRD_PERSON_EXTERNAL_RIFLE_STRAFE_RIGHT_ANIMATION
			if sd < 0:
				return "rifle_motion/" + PlayerController.THIRD_PERSON_EXTERNAL_RIFLE_STRAFE_LEFT_ANIMATION
			return "riflewalk"
		if raw == "run":
			return "riflerun"
		if raw == "idle":
			return "rifleaim" if bool(b.get("is_aiming", false)) else "rifleidle"
	return raw

# +1 strafe a la derecha / -1 a la izquierda / 0 si el desplazamiento no es
# lateral (o no hay rumbo registrado). El facing del bot es (-sin(rot), -cos(rot))
# — el mismo convenio que atan2(-dir.x, -dir.z) usa en _move_bot_towards.
func _bot_net_strafe_dir(b: Dictionary) -> int:
	var mdir = b.get("_mdir", Vector3.ZERO)
	if not (mdir is Vector3) or (mdir as Vector3).length_squared() < 0.01:
		return 0
	var rot := float(b.get("rot", 0.0))
	var fwd := Vector3(-sin(rot), 0.0, -cos(rot))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var d := (mdir as Vector3).normalized()
	if absf(fwd.dot(d)) > 0.766:
		return 0
	return 1 if right.dot(d) > 0.0 else -1

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
					bool(b.get("is_aiming", false)), bool(b["has_rifle"]),
					bool(b["sleeping"]), bool(b.get("sitting", false)), bool(b["prone"]), bool(b.get("crouching", false)),
					bool(b["torch_lit"]), bool(b["flashlight_on"]), b["clothing_colors"]
				)
	if (net == null or not net.is_connected) and world.has_method("_update_remote_players"):
		world._update_remote_players()

func _tick_bot_condition_audio(b: Dictionary, delta: float) -> void:
	var sick := float(b.get("sick_timer",0.0)) > 0.0
	var critical := float(b.get("health",100.0)) > 0.0 and float(b.get("health",100.0)) <= 20.0
	var condition := "sick" if sick and not bool(b.get("_audio_was_sick",false)) else ""
	b["_audio_was_sick"] = sick
	b["_critical_audio_t"] = maxf(0.0,float(b.get("_critical_audio_t",0.0))-delta) if critical else 0.0
	if critical and float(b["_critical_audio_t"]) <= 0.0:
		condition = "critical"
		b["_critical_audio_t"] = 14.0
	if not condition.is_empty(): _emit_bot_condition_audio(b,condition)

func _emit_bot_condition_audio(b: Dictionary, condition: String) -> void:
	if world == null: return
	var net = world.get("net")
	if net != null and net.has_method("_broadcast_player_condition_audio"):
		net._broadcast_player_condition_audio(int(b["bot_id"]),condition)
	if DisplayServer.get_name() != "headless" and world.has_method("_net_player_condition_audio"):
		world._net_player_condition_audio(int(b["bot_id"]),condition)

func _tick_bot(b: Dictionary, delta: float) -> void:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	if bool(proxy.get_meta("proxy_dead", false)):
		if not str(b.get("anim", "")).begins_with("dead"):
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
	_tick_bot_condition_audio(b, delta)

	b["attack_cooldown"] = maxf(0.0, float(b["attack_cooldown"]) - delta)
	b["shoot_cooldown"] = maxf(0.0, float(b["shoot_cooldown"]) - delta)
	if float(b["shoot_cooldown"]) <= 0.0:
		b["gun_reloading"] = false
	b["tame_cooldown"] = maxf(0.0, float(b["tame_cooldown"]) - delta)
	b["_tame_wait_t"] = maxf(0.0, float(b.get("_tame_wait_t", 0.0)) - delta)
	b["eat_cooldown"] = maxf(0.0, float(b["eat_cooldown"]) - delta)
	b["sick_timer"] = maxf(0.0, float(b.get("sick_timer", 0.0)) - delta)
	b["cook_cooldown"] = maxf(0.0, float(b["cook_cooldown"]) - delta)
	b["_soc_t"] = maxf(0.0, float(b.get("_soc_t", 0.0)) - delta)
	b["_meet_ev_t"] = maxf(0.0, float(b.get("_meet_ev_t", 0.0)) - delta)
	b["_chat_cd"] = maxf(0.0, float(b.get("_chat_cd", 0.0)) - delta)
	b["_craft_check"] = maxf(0.0, float(b.get("_craft_check", 0.0)) - delta)
	b["aggro_timer"] = maxf(0.0, float(b["aggro_timer"]) - delta)
	if float(b["aggro_timer"]) <= 0.0:
		b["aggro_target"] = null
	# flee_until/hide_timer decaen aqui, no solo dentro de la rama de
	# combate/descanso: si el enemigo desaparecia con la huida a medio,
	# el flag quedaba clavado >0 para siempre — el bot no volvia a poder
	# dormir (_bot_should_wake lo sacaba cada tick) ni a regular la
	# lumbre, y moria de frio/exhausto huyendo de un fantasma.
	b["flee_until"] = maxf(0.0, float(b.get("flee_until", 0.0)) - delta)
	b["hide_timer"] = maxf(0.0, float(b.get("hide_timer", 0.0)) - delta)
	# La punteria decae igual que la del jugador: retroceso y sacudidas se
	# recuperan con el tiempo aunque el bot no este combatiendo ahora.
	_bot_aim_decay(b, delta)
	b["_truce_t"] = maxf(0.0, float(b.get("_truce_t", 0.0)) - delta)
	if float(b.get("_truce_t", 0.0)) <= 0.0:
		b["_truce_peer"] = 0

	# Supervivencia identica a la del jugador humano: SurvivalStats simula
	# hambre, sed, energia, sueño, temperatura corporal, lluvia, vadeo, calor
	# de fogata/antorcha y muerte por inanicion/hipotermia/calor/agotamiento.
	_bot_survival_tick(b, delta)
	if bool(proxy.get_meta("proxy_dead", false)):
		return
	proxy.set_meta("saved_hunger", float(b["hunger"]))
	proxy.set_meta("saved_thirst", float(b["thirst"]))
	_maintain_bot_needs(b, delta)

	# Herida sangrante sin venda: se detiene a improvisar una (3 Trapos -> Venda;
	# ropa + cuchillo -> Trapos). Se desangrar huyendo era la muerte "succumbed"
	# mas habitual. En combate o huyendo no se para: primero zafarse.
	var vst_med: SurvivalStats = b.get("vstats")
	if vst_med != null and not vst_med.dead and vst_med.bleeding > 0.0 \
			and _bot_item_count(proxy, "Venda") + _bot_item_count(proxy, "Vendaje") == 0 \
			and b.get("aggro_target") == null and b.get("_s_predator") == null \
			and float(b.get("flee_until", 0.0)) <= 0.0:
		if _bot_try_craft_named(b, delta, ["Venda", "Trapos"], false):
			b["_act"] = "firstaid"
			return

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
		var pred_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("predator", 0))
		var pred_bonus := minf(12.0, float(pred_lessons) * 4.0)
		b["_s_predator"] = _find_threatening_predator(b, (30.0 if float(b.get("caution_until", 0.0)) > 0.0 else 22.0) + pred_bonus)
		b["_s_foe"] = _find_combat_foe(b)
		if b["_s_foe"] != null:
			_ai_note_foe_scan(b, b["_s_foe"] as Node3D)
			b["_lost_foe_until_msec"] = 0
			b["_lost_scan_t"] = 0.0
			_bot_warn_team_of_foe(b, b["_s_foe"] as Node3D)
		# Ojo en los techos en ciudad/bases militares: un francotirador apostado
		# en una azotea se ve desde mucho mas lejos que un enemigo a ras — el
		# bot que entra a saquear vigila los puestos elevados antes que nada.
		var roof_foe: Node3D = _find_rooftop_foe(b) if _bot_in_watch_zone(proxy.global_position) else null
		if roof_foe != null:
			if b["_s_foe"] == null or proxy.global_position.distance_to((roof_foe as Node3D).global_position) < proxy.global_position.distance_to((b["_s_foe"] as Node3D).global_position):
				b["_s_foe"] = roof_foe
			if int(b.get("_roof_threat_msec", -999999)) < 0:
				record_zone_hazard(int(b["bot_id"]), (roof_foe as Node3D).global_position, "tower", 0.6, true)
			b["_roof_threat_msec"] = Time.get_ticks_msec()
		b["_s_leader"] = _resolve_team_leader(b)
		var has_wolf := _bot_has_tamed_wolf(b)
		b["_s_has_wolf"] = has_wolf
		b["_s_tame_wolf"] = null if has_wolf else _find_tameable_wolf(b, 20.0)
		_note_bot_wolf_life(b, has_wolf)
		if has_wolf:
			_sync_bot_wolf_orders(b)
		var hunt_dir := str(_ai_active_directive(b).get("action", "")) == "hunt"
		b["_s_prey"] = _find_huntable_prey(b, 44.0 if hunt_dir else 32.0)
		b["_s_corpse"] = _find_guttable_corpse(b, 22.0) if b.get("gut_target") == null else null
		b["_s_loot"] = _find_nearby_valuable_loot(b, 28.0)
		# Preparacion nocturna: al caer la tarde, quien no tiene el fuego ni la
		# luz resueltos sale a por lo que le falta (trapos, palos, piedras) mas
		# alla del radio de saqueo oportunista — antes de que se haga de noche.
		if (b["_s_loot"] as Dictionary).is_empty() and not bool(b.get("equip_mission", false)) \
				and (_is_pre_night() or _is_world_night()) and not _bot_night_fire_ready(b, proxy):
			b["_s_loot"] = _find_fire_prep_loot(b, 60.0)
		b["_s_raid_shelter"] = _find_nearby_raidable_shelter(b, 38.0)
		# Robo dirigido tras una negativa: el refugio de quien le nego ayuda
		# tiene prioridad sobre cualquier otro alijo cercano (caduca en 5 min).
		var steal_t: Dictionary = b.get("_steal_target", {})
		if not steal_t.is_empty():
			var st_sh := _find_shelter_dict(str(steal_t.get("id", ""))) if Time.get_ticks_msec() - int(steal_t.get("t", 0)) <= 300000 else {}
			if st_sh.is_empty():
				b["_steal_target"] = {}
			else:
				b["_s_raid_shelter"] = st_sh
		_observe_nearby_world(b)
		_tick_fauna_hearing(b)
		_try_share_allied_knowledge(b, delta)
		_bot_social_update(b)
		# Orden de equipo "equip" o incursion propia: si no queda equipo suelto
		# a mano, se da por cumplida — salvo que el bot siga desarmado con una
		# base militar conocida y la incursion no este vetada por un fallo
		# reciente: en ese caso la mision persiste hasta conseguir arma.
		if bool(b.get("equip_mission", false)) and (b["_s_loot"] as Dictionary).is_empty():
			var raid_kind := _bot_gear_raid_kind(b)
			if raid_kind == "" or _ai_goal_recently_failed(b,
					{"action": "scavenge", "target": raid_kind, "goal": "gear_up_at_military_base"}):
				b["equip_mission"] = false

	var is_night := _is_world_night()
	if not is_night:
		b.erase("_velada_done") # velada nueva cada noche
	if not _is_pre_night():
		b["_prep_logged"] = false
	_validate_shelter_claim(b)
	_sync_team_base(b)
	var sh_pos: Vector3 = b["shelter_pos"]
	var hiding_in_shelter: bool = float(b["hide_timer"]) > 0.0 and sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 2.6
	# Luz nocturna con antorcha — o antorcha de rescate cuando se esta
	# helando: de dia tambien da calor real (ver _bot_survival_tick).
	var was_torch_lit := bool(b.get("torch_lit", false))
	b["torch_lit"] = (is_night or _bot_is_freezing(b)) and not hiding_in_shelter and not bool(b.get("sleeping", false)) and _bot_has_item(proxy, "Antorcha")
	if bool(b["torch_lit"]) and not was_torch_lit and not _bot_ignite_torch(b):
		b["torch_lit"] = false
	proxy.set_meta("torch_lit", bool(b["torch_lit"]))
	proxy.set_meta("in_built_shelter", _bot_at_own_built_shelter(b, proxy.global_position))
	proxy.set_meta("crouching", bool(b.get("crouching", false)))
	proxy.set_meta("prone", bool(b["prone"]))
	proxy.set_meta("sitting", bool(b.get("sitting", false)))
	proxy.set_meta("sleeping", bool(b["sleeping"]))
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
			# Los buenos dias al despertar de dia — salvo que lo haya despertado
			# una amenaza (dar los buenos dias con un lobo encima no tiene sentido).
			if not is_night and _world_time_of_day() < 12.0 and b.get("aggro_target") == null \
				and b.get("_s_predator") == null and b.get("_s_foe") == null:
				_bot_say_farewell(b, "goodmorning")
		else:
			b["anim"] = "sleep"
			b["sitting"] = false
			b["crouching"] = false
			proxy.set_meta("crouching", false)
			return

	# 0a) Agua por encima de la cabeza (corazon del lago, >2.55 m): solo lo
	# verdaderamente intransitable dispara el escape — el rio entero se
	# vadea como hace el ciervo. Si quedo dentro (empujon, reaparicion,
	# hueco entre nodos del nav), sale a lo somero antes de cualquier otra
	# decision. Va ANTES del termostato: un helado dentro del rio no puede
	# "acercarse a la lumbre" — calentarse empieza por no ahogarse (y el
	# agua fria drena temp mas rapido que el fuego la sube).
	if world != null and world.has_method("get_river_depth_at") and float(world.get_river_depth_at(proxy.global_position)) > FORD_MAX_DEPTH:
		b["drink_at"] = Vector3.INF
		b["drinking_timer"] = 0.0
		b["crouching"] = false
		b["sitting"] = false
		var esc := _bot_shoreward_goal(proxy.global_position)
		if esc != Vector3.INF:
			b["_act"] = "water_escape"
			_move_bot_towards(b, esc, 6.5, delta, "run")
		else:
			b["anim"] = "idle"
		return

	# 0b) Termostato de lumbre: pegado a las brasas te cocinas (la misma curva
	# de calor que al jugador) y en el borde frio te hielas — cualquier tarea
	# junto a una fogata viva regula distancia antes de seguir. El dormido no
	# llega aqui: su puerta propia lo despierta con calor letal.
	if _bot_camp_fire_standoff(b, delta):
		return

	# La postura agachada vale solo para el tick en curso: cada rama que la
	# quiere (acecho, cobertura, escondite, trabajo en cuclillas) la re-afirma
	# dentro de su propio bloque. Si quedara pegada de un tick anterior, las
	# huidas urgentes correrian tapadas a 2 m/s en _move_bot_towards.
	b["crouching"] = false

	# 1) Doma de lobos: va ANTES que predator para que _s_predator (radio 22..34 m)
	# no secuestre al lobo salvaje que el bot pretende domesticar (radio 20 m)
	# ni haga que el bot le dispare o huya mientras el lobo se come el cebo.
	# La defensa manda: bajo ataque (disparos, enemigo a la vista, otra fiera
	# o el propio lobo ya agresivo) la doma se aparca y el tick sigue hacia
	# cobertura/combate/huida. El progreso vive en el lobo (_tame_progress)
	# y no se pierde; se retoma cuando vuelve la calma.
	var wild_wolf := _sensed_node(b, "_s_tame_wolf") if not bool(b.get("_s_has_wolf", false)) else null
	var tame_blocked := wild_wolf != null and _bot_tame_interrupted(b, wild_wolf)
	if wild_wolf != null and not tame_blocked and float(b.get("health", 100.0)) >= 55.0:
		if proxy.global_position.distance_to(wild_wolf.global_position) >= 4.2:
			# El lobo exige TAME_FEEDINGS comidas del mismo alimentador: solo se
			# intenta con el cebo completo preparado, para no quedarse a mitad
			# y perder la confianza ganada. _tame_wait_t solo continua una
			# secuencia ya empezada (el cebo ya esta en el suelo); una
			# secuencia interrumpida se retoma con el cebo que le falte.
			var fed := _bot_tame_progress(b, wild_wolf)
			var bait_needed := maxi(1, WildlifeController.TAME_FEEDINGS - fed)
			if (float(b["tame_cooldown"]) <= 0.0 and _bot_tame_bait_count(proxy) >= bait_needed) or float(b.get("_tame_wait_t", 0.0)) > 0.0:
				b["_act"] = "tame"
				_perform_wolf_taming_step(b, wild_wolf, delta)
				return

	# 2) Detectar amenazas inmediatas: lobos/osos hostiles cercanos
	var predator := _sensed_node(b, "_s_predator")
	# El lobo que estaba domesticando no es "un depredador mas" mientras no
	# se revuelva: interrumpido por OTRA amenaza, no se le dispara ni se
	# huye de el por inercia. Si se vuelve agresivo, cae aqui como cualquiera.
	# Se le reconoce por lo ya invertido en el (tomas acreditadas), no por
	# la ventana de distancia de la doma: al correr a cubrirse el bot puede
	# quedar mas cerca o mas lejos y seguiria siendo "su" lobo.
	if predator != null and not _bot_wolf_is_aggressive(b, predator) \
			and (_bot_tame_progress(b, predator) > 0 or (predator == wild_wolf and float(b.get("_tame_wait_t", 0.0)) > 0.0)):
		predator = null
	if predator != null:
		b["_act"] = "predator"
		_handle_predator_encounter(b, predator, delta)
		return

	# Incoming fire takes priority over an ambush pose or domestic chores.
	var shooter := _sensed_node(b, "_s_foe")
	var under_fire := Time.get_ticks_msec() - int(b.get("_last_attacker_msec", -999999)) < 5000 and str(b.get("_last_hit_weapon", "")) in ["rifle", "m4"]
	var cover_experience := int(b.get("_mem", {}).get("experience", {}).get("cover", 0))
	var anticipates_cover := shooter != null and cover_experience > 0 and _actor_holds_ranged(shooter) and float(b["health"]) < 45.0 + 5.0*cover_experience
	if shooter != null and (under_fire or anticipates_cover) and _bot_seek_ballistic_cover(b, shooter, delta):
		b["_act"] = "cover"
		return

	# 2b) Emboscada: hostiles (solos o en equipo) acechan agachados a una
	#     victima con recursos y golpean a la vez. Cede ante depredadores.
	if _bot_try_ambush(b, delta):
		b["_act"] = "ambush_height" if b.get("_ambush", {}).has("post") else "ambush"
		return

	# 3) Combate contra enemigos humanos / otros bots de facción opuesta
	var human_foe := _sensed_node(b, "_s_foe")
	if human_foe != null:
		b["_act"] = "foe"
		# Herido grave (< 30 HP), SIN ARMA (un superviviente desarmado no se
		# queda a descubrir si el desconocido es hostil: sale huyendo) o ya en
		# huida: repliegue tactico real. Con refugio va a ocultarse; sin refugio
		# escapa en zigzag hasta perder la amenaza o conseguir un arma.
		var fleeing: bool = float(b["flee_until"]) > 0.0
		var unarmed: bool = _best_weapon_name(proxy).is_empty()
		var combat_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("combat", 0))
		var ranged_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("ranged", 0))
		var retreat_hp := 30.0 + minf(15.0, float(combat_lessons) * 5.0) + minf(10.0, float(ranged_lessons) * 4.0)
		# Nemesis: quien ya le mato suma miedo persistente. Si no tiene ventaja
		# clara, aprende a no repetir la muerte y se retira en vez de pelear.
		b["_nemesis_ev_t"] = maxf(0.0, float(b.get("_nemesis_ev_t", 0.0)) - delta)
		var nem := _foe_nemesis(b, human_foe)
		if not nem.is_empty() and not _has_combat_edge(b, human_foe):
			var fear_n := float(get_bot_relationship(int(b["bot_id"]), str(nem.get("key", ""))).get("fear", 0.0))
			var pers_n := _get_bot_personality(b)
			if int(nem.get("count", 1)) >= 2 or fear_n > 0.6 or unarmed or float(pers_n.get("bravery", 0.5)) < 0.42:
				_bot_avoid_nemesis(b, human_foe, str(nem.get("name", "")), delta)
				return
		# Superado en potencia de fuego: el rival lleva un arma a distancia y
		# este bot no tiene con que responder (fusil seco, sin flechas). Herido
		# y asi no hay pelea razonable — se retira antes del umbral normal;
		# el valiente aguanta algo mas, el prudente se va antes.
		var outgunned := _actor_holds_ranged(human_foe) and not _bot_has_ranged_weapon(proxy) \
			and float(b["health"]) < 42.0 + float(_get_bot_personality(b).get("survival_instinct", 0.7)) * 22.0 - float(_get_bot_personality(b).get("bravery", 0.5)) * 14.0
		if (float(b["health"]) < retreat_hp or fleeing or unarmed or outgunned) and not _has_combat_edge(b, human_foe):
			if sh_pos != Vector3.INF:
				b["hide_timer"] = 20.0
				_move_bot_towards(b, sh_pos, 6.0, delta, "run")
				if proxy.global_position.distance_to(sh_pos) < 1.8:
					b["crouching"] = true
					b["sitting"] = true
					b["anim"] = "sit"
				return
			if not fleeing:
				b["flee_until"] = 14.0
			# Huir es de pie y a sprint: un bot que descansaba agachado (los
			# hostiles lo hacen) escaparia a 2 m/s en sneak si no se suelta.
			b["crouching"] = false
			proxy.set_meta("crouching", false)
			var away := proxy.global_position - human_foe.global_position
			away.y = 0.0
			var away_dir := away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 1.2:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var side := Vector3(-away_dir.z, 0.0, away_dir.x)
			_move_bot_towards(b, proxy.global_position + (away_dir + side * float(b["strafe_dir"]) * 0.5).normalized() * 8.0, 6.0, delta, "run")
			return
		# Leccion anti-tirador: si ya murio a tiros y el rival lleva un arma a
		# distancia, no carga en linea recta — se acerca en zigzag hasta el
		# cuerpo a cuerpo. Los bots con arma a distancia ya zigzaguean en
		# _engage_foe; esto cubre a los que solo llevan melee.
		var dist_foe := proxy.global_position.distance_to(human_foe.global_position)
		if ranged_lessons > 0 and _actor_holds_ranged(human_foe) and str(_pick_fight_weapon(b, dist_foe).get("kind", "")) == "melee" and dist_foe > 14.0:
			b["strafe_timer"] = float(b["strafe_timer"]) + delta
			if float(b["strafe_timer"]) > 0.9:
				b["strafe_dir"] = -float(b["strafe_dir"])
				b["strafe_timer"] = 0.0
			var to_fz := human_foe.global_position - proxy.global_position
			to_fz.y = 0.0
			var sidez := Vector3(-to_fz.z, 0.0, to_fz.x).normalized() if to_fz.length_squared() > 0.01 else Vector3.RIGHT
			_move_bot_towards(b, proxy.global_position + (to_fz.normalized() + sidez * float(b["strafe_dir"]) * 0.9).normalized() * 7.0, 6.2, delta, "run")
			b["rot"] = atan2(-to_fz.x, -to_fz.z)
			proxy.rotation.y = float(b["rot"])
			return
		# Francotirador apostado: dispara desde su puesto sin bajar a perseguir.
		if _bot_overwatch_fight(b, human_foe, delta):
			return
		_engage_foe(b, human_foe, delta)
		return

	# 3a) Enemigo perdido: buscar donde se le vio/u oyo por ultima vez durante
	#     la ventana por personalidad, escanear al llegar y abandonar sin
	#     indicios. Solo lo hace un bot armado y en condiciones de buscar.
	var lost_until := int(b.get("_lost_foe_until_msec", 0))
	if lost_until > 0 and float(b.get("flee_until", 0.0)) <= 0.0 \
			and float(b.get("health", 100.0)) > 35.0 and not _best_weapon_name(proxy).is_empty():
		var lpos: Vector3 = b.get("_lost_foe_pos", Vector3.INF)
		if lpos == Vector3.INF or Time.get_ticks_msec() > lost_until:
			b["_lost_foe_until_msec"] = 0
			b["_lost_foe_pos"] = Vector3.INF
			b["_lost_sector"] = Vector3.INF
			b["_lost_sectors"] = 0
		else:
			b["_act"] = "search_foe"
			# Busqueda por sectores alrededor de la pista — no es un radar:
			# recorre la pista y unos puntos del area cercana, con pausas de
			# escucha en cada uno, y abandona si no halla nada.
			var sect: Vector3 = b.get("_lost_sector", Vector3.INF)
			if sect == Vector3.INF:
				var n := int(b.get("_lost_sectors", 0))
				sect = lpos if n == 0 else lpos + Vector3(randf_range(-9.0, 9.0), 0.0, randf_range(-9.0, 9.0))
				b["_lost_sector"] = sect
			if proxy.global_position.distance_to(sect) > 2.4:
				b["crouching"] = proxy.global_position.distance_to(sect) <= 15.0
				_move_bot_towards(b, sect, 4.0 if b["crouching"] else 5.6, delta, "walk" if b["crouching"] else "run")
			else:
				# En el punto sin verlo: pausa de escucha agachado y siguiente sector.
				b["crouching"] = true
				b["anim"] = "idle"
				b["_lost_scan_t"] = float(b.get("_lost_scan_t", 0.0)) + delta
				if float(b["_lost_scan_t"]) > 1.6:
					b["_lost_scan_t"] = 0.0
					b["_lost_sector"] = Vector3.INF
					b["_lost_sectors"] = int(b.get("_lost_sectors", 0)) + 1
					if int(b["_lost_sectors"]) >= 4:
						b["_lost_foe_until_msec"] = 0
						b["_lost_sector"] = Vector3.INF
						b["_lost_sectors"] = 0
						# Recuerda la zona como peligrosa: donde una amenaza se esfumo.
						record_zone_hazard(int(b["bot_id"]), lpos, "lost_foe", 0.25, true)
			return
	elif lost_until <= 0:
		b["_lost_foe_pos"] = Vector3.INF
		b["_lost_sector"] = Vector3.INF
		b["_lost_sectors"] = 0

	b["is_aiming"] = false

	# 3b) Destripado en curso: caminar hasta el cadáver y dedicarle unos
	# segundos agachado. Se abandona si el cadáver desaparece, se aleja
	# demasiado o el bot ya no necesita nada de él.
	# El animal puede desaparecer entre dos ticks (p. ej. otro jugador lo
	# recoge o se limpia el cadáver). No asignar una referencia ya liberada a
	# una variable tipada: en Godot 4 eso genera un error cada tick y puede
	# propagar transforms inválidos al proxy del bot.
	var gut: Node3D = null
	var gut_candidate: Variant = b.get("gut_target")
	if gut_candidate != null:
		if is_instance_valid(gut_candidate) and gut_candidate is Node3D:
			gut = gut_candidate as Node3D
		else:
			b["gut_target"] = null
			b["gut_t"] = 0.0
	if gut != null:
		b["_act"] = "gut"
		var gut_ok: bool = is_instance_valid(gut) and not bool(gut.get("_gutted"))
		var gdist: float = proxy.global_position.distance_to(gut.global_position) if gut_ok else 999.0
		if not gut_ok or gdist > 60.0 or not _bot_wants_animal_loot(b, proxy):
			b["gut_target"] = null
		elif gdist > 2.4:
			_move_bot_towards(b, gut.global_position, 6.2, delta, "run")
			return
		else:
			b["gut_t"] = float(b["gut_t"]) + delta
			b["anim"] = "sit"
			if float(b["gut_t"]) >= 3.5:
				b["gut_target"] = null
				_bot_harvest_dead_animal(b, gut)
			return

	if not is_night or not _bot_night_supply_emergency(b):
		b.erase("_night_emergency_origin")
	# Prepare light before any night-time supply trip, after immediate threats.
	if is_night and _bot_needs_food_or_water(b):
		if _bot_prepare_night_supplies(b, delta):
			return
		if _bot_try_cook_meat(b, delta):
			b["_act"] = "cook"
			return

	# 4) Sed critica sin botellas: ir al rio/lago a beber (solo si no esta
	# siguiendo ordenes de equipo o la sed es critica de verdad)
	if bool(b.get("_consume_from_inventory",false)) and float(b.get("consume_anim_t",0.0)) > 0.0:
		_stop_bot_motion(b)
		b["_act"] = str(b.get("consume_anim","eat"))
		return
	var leader := _sensed_node(b, "_s_leader")
	b["drink_giveup"] = maxf(0.0, float(b.get("drink_giveup", 0.0)) - delta)
	var thirst_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("dehydrated", 0))
	var thirsty_line := 35.0 + (13.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0) + minf(18.0, float(thirst_lessons) * 6.0)
	# Sed preventiva: quien ya se deshidrato una vez no pasa de largo junto
	# a una fuente — con sed moderada y agua a tiro se desvia a beber y a
	# rellenar la botella antes de que la necesidad apriete.
	var prevent_drink := false
	if thirst_lessons > 0 and float(b["thirst"]) < 78.0 and not _bot_has_drink(proxy):
		var wp_pre := _nearest_water_pos(proxy.global_position, b)
		if wp_pre != Vector3.INF and Vector2(proxy.global_position.x - wp_pre.x, proxy.global_position.z - wp_pre.z).length() < 9.0:
			prevent_drink = true
			b["drink_at"] = wp_pre
	if (float(b["thirst"]) < thirsty_line or prevent_drink) and float(b.get("drink_giveup", 0.0)) <= 0.0 and not _bot_has_drink(proxy) and (leader == null or _bot_vital_break(b) or prevent_drink):
		b["_act"] = "drink"
		if b["drink_at"] == Vector3.INF:
			b["drink_scan"] = float(b.get("drink_scan", 0.0)) - delta
			if float(b["drink_scan"]) <= 0.0:
				b["drink_at"] = _nearest_water_pos(proxy.global_position, b)
				if b["drink_at"] == Vector3.INF:
					b["drink_at"] = _known_water_pos(b) # fuente enseñada por chat/voz
				b["drink_walk_t"] = 0.0
				b["_drink_best_d"] = INF
				b["drink_scan"] = 0.0 if b["drink_at"] != Vector3.INF else (4.0 + fmod(float(int(b["bot_id"])) * 0.7, 1.5))
		if b["drink_at"] != Vector3.INF and not _bot_supply_goal_allowed(b, b["drink_at"]):
			# Solo la sed critica retiene una meta de agua no permitida (oscura
			# o vetada): para el resto, reescanear a la espera de la urgencia.
			if float(b["thirst"]) >= 18.0:
				b["drink_at"] = Vector3.INF
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
				# Mientras el bot siga acercandose al agua, el reloj de atasco
				# se reinicia: antes los 12 s fijos abortaban cualquier viaje
				# de >60 m y vetaban rios alcanzables uno tras otro.
				if d_water < float(b.get("_drink_best_d", INF)) - 0.8:
					b["_drink_best_d"] = d_water
					b["drink_walk_t"] = 0.0
				b["drink_walk_t"] = float(b.get("drink_walk_t", 0.0)) + delta
				if float(b["drink_walk_t"]) > 12.0:
					var bw: Array = b.get("_bad_water", [])
					bw.append({"pos": b["drink_at"], "until": float(Time.get_ticks_msec()) / 1000.0 + 120.0})
					b["_bad_water"] = bw
					b["drink_at"] = Vector3.INF
					b["drink_walk_t"] = 0.0
					b["_drink_best_d"] = INF
					b["drink_giveup"] = 12.0
				else:
					_move_bot_towards(b, b["drink_at"], 6.2, delta, "run")
					return
			else:
				# En la orilla: se para a beber unos segundos y repone su sed.
				# consume_anim="drink" (mismo canal que beber de la botella) hace
				# que el puppet remoto reproduzca la animacion real de beber.
				b["drink_walk_t"] = 0.0
				b["_drink_best_d"] = INF
				b["drinking_timer"] = float(b["drinking_timer"]) + delta
				b["crouching"] = false
				b["sitting"] = false
				b["anim"] = "idle"
				b["consume_anim"] = "drink"
				b["consume_anim_t"] = 0.5
				if float(b["drinking_timer"]) >= 2.6:
					b["drinking_timer"] = 0.0
					b["drink_at"] = Vector3.INF
					b["thirst"] = 100.0
					proxy.set_meta("saved_thirst", 100.0)
					# Ya en la orilla, rellena todas sus botellas vacias: quien
					# aprendio de morir de sed lleva hasta 3 reservas.
					var inv_w: Array = proxy.get_meta("saved_inventory", [])
					var refilled_n := 0
					for i in range(inv_w.size() - 1, -1, -1):
						var it_w = inv_w[i]
						if it_w is Dictionary and str(it_w.get("name", "")) == "Botella de plastico" and int(it_w.get("quantity", 1)) > 0:
							refilled_n += int(it_w.get("quantity", 1))
							inv_w.remove_at(i)
					if refilled_n > 0:
						_bot_add_inventory_item(inv_w, {"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": refilled_n, "use_value": 45.0})
						proxy.set_meta("saved_inventory", inv_w)
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

	if is_night and _bot_needs_food_or_water(b) and not _bot_has_item(proxy, "Antorcha"):
		# No accessible supply within the firelight: never fall through to
		# hunting, following or exploring into darkness. La unica caminata
		# a oscuras permitida es volver al refugio propio o a una fogata
		# encendida — ahi hay luz, alijo y quien le ayude.
		if _bot_night_home_walk(b, delta):
			return
		# Sin nada alcanzable a oscuras ni refugio que caminar: dormir gana
		# a vegetar — frena el desgaste x0.3 y despierta si el hambre llega
		# a zona de expedicion letal. El bloque de luz veta salidas, no el
		# descanso (morir agotado esperando el amanecer era el deadlock).
		b["_act"] = "night_supplies"
		if _bot_try_start_sleep(b, is_night):
			return
		b["anim"] = "idle"
		b["sitting"] = false
		return

	# La antorcha es el minimo para salir a explorar de noche: se fabrica en
	# el acto si lleva palo+trapos, corta ropa a trapos si solo le falta la
	# tela, o raja un tronco a palos si solo le falta la madera — antes de
	# cazar, seguir al lider o saquear: ninguna tarea vale quedarse a oscuras.
	# Sin materiales para hacerla se resguarda en wants_camp mas abajo.
	# Oculto, dormido, agotado o helandose: primero eso.
	if (is_night or _is_pre_night()) and not _bot_has_item(proxy, "Antorcha") \
			and float(b.get("hide_timer", 0.0)) <= 0.0 and not bool(b.get("sleeping", false)) \
			and not _bot_is_exhausted(b) and not _bot_is_freezing(b):
		var need_palo_t := _bot_item_count(proxy, "Palo") < 1
		var need_trapos_t := _bot_item_count(proxy, "Trapos") < 1
		if _bot_try_craft_named(b, delta, ["Antorcha"], true) \
				or (need_trapos_t and _bot_try_craft_named(b, delta, ["Trapos"], false)) \
				or (need_palo_t and not need_trapos_t and _bot_item_count(proxy, "Tronco") > 0 and _bot_try_craft_named(b, delta, ["Palo"], false)):
			b["_act"] = "torch"
			return

	# Inanicion desesperada (mismo umbral que starving_or_parched, l.1259):
	# un miembro de equipo muerto de hambre rompe la formacion para buscar
	# comida — seguir al lider no llena el estomago (_bot_try_forage ya hace
	# esta excepcion con su propio 'desperate', pero no llega a setas ni
	# frutales en mitad de la ciudad).
	var desperate_food: bool = float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b))

	# 4c) Caza de presas (ciervos/zorros) y aprovechamiento de cadáveres cuando
	# falta comida o materiales animales (pieles, tendón para cuerda, hueso).
	if (leader == null or desperate_food or _bot_vital_break(b)) and _bot_try_hunt_or_scavenge(b, delta):
		b["_act"] = "hunt"
		return

	# 4d) Pesca en la orilla: el pez cocinado es la comida mas nutritiva del
	# juego — con caña (o materiales para hacerla) y agua a mano se sienta a
	# pescar igual que un jugador humano.
	if (leader == null or desperate_food or _bot_vital_break(b)) and _bot_try_fish(b, delta):
		b["_act"] = "fish"
		return

	# 5) Si está reclutado en un equipo, seguir al líder — salvo emergencia
	# vital (salud/hambre/sed/frío/sueño, en equipos de bots o de humanos: la
	# supervivencia manda sobre la orden) o cuando un miembro bot-bot ya tiene
	# los 11 palos para levantar su refugio junto al campamento del líder).
	var bot_team_member := is_bot_peer_id(int(b.get("team_leader_id", 0)))
	var desperate_team_break: bool = desperate_food or _bot_vital_break(b)
	# Un recado de la IA dentro del radio de escolta gana al seguimiento: el
	# follower cae al pipeline normal (la directiva dirige su exploracion),
	# ejecuta el encargo y reengancha al leader al expirar. El leader sigue
	# decidiendo el destino macro — solo cuentan encargos dentro de su orbita.
	if leader != null and not desperate_team_break and _bot_ai_errand_target(b, leader) == Vector3.INF:
		b["_act"] = "team"
		_tick_teammate_behavior(b, leader, delta)
		return

	# 5) Saqueo oportuno de objetos cercanos (comida, armas, ropa mejor, materiales)
	# Reserve only when actually pursuing loot, not while asleep/in combat.
	_loot_commit_claim(b)
	var loot_action: Dictionary = b.get("_s_loot", {})
	if not loot_action.is_empty():
		b["_act"] = "loot"
		b["sitting"] = false
		# Bajo amenaza de tejado el saqueo es agachado y sin correr: menos
		# silueta para el francotirador mientras cruza la calle hasta la casa.
		var roof_wary := _bot_roof_wary(b)
		b["crouching"] = roof_wary
		var lpos := _loot_entry_pos(loot_action)
		if _bot_can_reach_loot(proxy.global_position, lpos):
			_stop_bot_motion(b)
			_collect_loot_entry(b, loot_action)
		else:
			_move_bot_towards(b, lpos, 4.6 if roof_wary else 6.2, delta, "walk" if roof_wary else "run")
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
				if str(b.get("_steal_target", {}).get("id", "")) == str(raid_sh.get("id", "")):
					b["_steal_target"] = {} # venganza consumada: objetivo cumplido
		else:
			_move_bot_towards(b, rpos, 6.2, delta, "run")
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

	# 6a-bis) Huerto: si ya lleva semillas pero aun no tiene azada/pala, talla
	# primero su Azada de piedra (Palo+Piedra+Cuerda; la Cuerda previa sale
	# de Trapos x2 cuando no hay tendon que la sustituya).
	if _bot_wants_farm_tool(b) and _bot_item_count(proxy, "Semillas") >= 1 \
			and float(b.get("hide_timer", 0.0)) <= 0.0 and not bool(b.get("sleeping", false)) \
			and not _bot_is_exhausted(b) and not _bot_is_freezing(b):
		var can_make_cord_for_hoe := _bot_item_count(proxy, "Cuerda") == 0 \
				and _bot_item_count(proxy, "Tendón") == 0 and _bot_item_count(proxy, "Trapos") >= 2
		if _bot_try_craft_named(b, delta, ["Azada de piedra"], true) \
				or (can_make_cord_for_hoe and _bot_try_craft_named(b, delta, ["Cuerda"], false)):
			b["_act"] = "craft"
			return
	if _bot_try_farm(b, delta):
		b["_act"] = "farm"
		return

	# Si ya reune los 11 palos contando sus Troncos (Tronco+filo -> 2 Palos),
	# rajar los troncos a palos de inmediato para desbloquear la obra del refugio.
	if str(b["shelter_id"]).is_empty() and not _can_bot_build_shelter(proxy) and _bot_palo_supply(proxy) >= 11 and _bot_item_count(proxy, "Tronco") > 0:
		b["_craft_check"] = 0.0
		if _bot_try_craft(b, delta):
			b["_act"] = "craft"
			return

	# Antes de emprender una caminata larga al solar con los 11 palos a cuestas:
	# si va a oscurecer/es de noche sin antorcha (y lleva palo sobrante + trapos)
	# o tiene hambre con latas cerradas, terminar ese crafteo vital primero.
	if str(b["shelter_id"]).is_empty() and _can_bot_build_shelter(proxy):
		var want_pre_build_craft := ((is_night or _is_pre_night()) and _bot_item_count(proxy, "Antorcha") == 0 and _bot_palo_supply(proxy) >= 12 and _bot_item_count(proxy, "Trapos") > 0) \
			or (float(b["hunger"]) < 58.0 and not _bot_has_edible_food(proxy, false))
		if want_pre_build_craft:
			b["_craft_check"] = 0.0
			if _bot_try_craft(b, delta):
				b["_act"] = "craft"
				return

	# 6b) Construir refugio propio si ya reunio los materiales: en su solar
	# reclamado si lo tiene o en su campamento remoto. Quien milita en un
	# equipo no levanta refugio propio — la base del equipo es la del lider.
	if str(b["shelter_id"]).is_empty() and int(b.get("team_leader_id", 0)) == 0 and _can_bot_build_shelter(proxy):
		var build_pos := _bot_build_camp_pos(b)
		var d_camp := Vector2(proxy.global_position.x - build_pos.x, proxy.global_position.z - build_pos.z).length()
		if d_camp > 170.0 and not bool(b.get("_camp_reanchored", false)) and b.get("shelter_pos", Vector3.INF) == Vector3.INF and int(b.get("team_leader_id", 0)) == 0:
			b["_camp_reanchored"] = true
			var mem_re := _ensure_bot_memory(int(b["bot_id"]), b.get("cfg", {}))
			var nearer := _find_valid_camp_spot(_pick_camp_anchor(int(b["bot_id"]), proxy.global_position, mem_re), proxy.global_position, 0, mem_re.get("bad_camp_spots", []), int(b["bot_id"]))
			var d_nearer := Vector2(proxy.global_position.x - nearer.x, proxy.global_position.z - nearer.z).length() if nearer != Vector3.INF else INF
			if d_nearer < d_camp - 30.0:
				b["camp_spot"] = nearer
				build_pos = nearer
				d_camp = d_nearer
		# Si el solar queda lejos (>24 m) y el bot esta agotado o helandose,
		# primero descansa/entra en calor en wants_camp antes de cruzar el monte.
		if d_camp <= 24.0 or (not _bot_is_exhausted(b) and not _bot_is_freezing(b)):
			b["_act"] = "build"
			if d_camp > 2.4:
				_move_bot_towards(b, build_pos, 5.5 if d_camp > 30.0 else 3.8, delta, "run" if d_camp > 30.0 else "walk")
				return
			_bot_build_shelter(b, build_pos)
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
	var starving_or_parched: bool = (float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b))) or (float(b["thirst"]) < 22.0 and not _bot_has_drink(proxy))
	# 6a) Alijo en su propio refugio: si ya está junto a su refugio sincroniza
	# (retira lo que necesite y guarda el sobrante); si necesita comida/agua/arma
	# que tiene guardada allí o acumula >=3 objetos sobrantes, vuelve a su
	# refugio para gestionar el alijo como un jugador humano.
	if sh_pos != Vector3.INF and not str(b["shelter_id"]).is_empty():
		var d_own_sh := Vector2(proxy.global_position.x - sh_pos.x, proxy.global_position.z - sh_pos.z).length()
		# Alijo junto al refugio — desde el borde seguro si una fogata viva
		# cubre el refugio (abrir la caja en las brasas cocinaba al bot).
		var stash_goal := _bot_fire_safe_spot(sh_pos, proxy.global_position.y, b)
		var d_stash := Vector2(proxy.global_position.x - stash_goal.x, proxy.global_position.z - stash_goal.z).length()
		if d_stash <= 0.8 or d_own_sh <= 2.6:
			_bot_sync_own_shelter_stash(b)
			_bot_try_camo_shelter(b)
		var needs_from_stash := _own_shelter_has_needed_item(b) \
				and (d_own_sh < 110.0 or (_bot_night_supply_emergency(b) and d_own_sh <= NIGHT_LETHAL_SUPPLY_RADIUS))
		var storable_n := _bot_count_storable_items(b)
		var wants_stash_run := needs_from_stash or (not starving_or_parched and (storable_n >= 3 or (storable_n >= 1 and d_own_sh < 24.0)))
		if wants_stash_run and d_stash > 0.9:
			b["_act"] = "stash"
			b["sitting"] = false
			b["crouching"] = false
			_move_bot_towards(b, stash_goal, 6.2 if d_stash > 12.0 else 4.0, delta, "run" if d_stash > 12.0 else "walk")
			return
	# Helándose o en mitad de la noche sin refugio: si lleva 2 palos y 2 piedras
	# y no hay fuego encendido al alcance, arma una hoguera aquí mismo.
	if str(b["campfire_id"]).is_empty() and float(b["hide_timer"]) <= 0.0 \
			and not _is_near_any_lit_campfire(proxy.global_position, 8.0) \
			and _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2 \
			and (_bot_is_freezing(b) or (is_night and str(b["shelter_id"]).is_empty() and _nearest_safe_refuge(b, 85.0) == Vector3.INF)):
		_bot_build_and_light_campfire(b, proxy.global_position + Vector3(0.9, 0.0, 0.9))
	# De noche: quien ya tiene refugio propio vuelve a casa salvo que lleve
	# antorcha para salir o sufra hambre/sed desesperada. Quien AUN NO tiene
	# refugio y esta descansado (sleep>=65), sano y sin frio sigue moviendose
	# para saquear, juntar los 11 palos y levantar su base en vez de quedarse
	# clavado sentado en mitad del campo toda la noche — pero solo mientras
	# pueda trabajar la luz: sin antorcha ni fogata propia no sale a explorar.
	var has_night_light := bool(b["torch_lit"]) or _bot_has_item(proxy, "Antorcha")
	var desperate_needs := _bot_needs_food_or_water(b)
	var has_built_sh := not str(b["shelter_id"]).is_empty()
	var vst: SurvivalStats = b.get("vstats")
	var night_needs_sleep: bool = is_night and ((vst != null and vst.sleep < 65.0) or (has_built_sh and (not has_night_light or not _bot_needs_outing(b))))
	# Al caer la tarde quien tiene refugio levantado vuelve a casa ANTES de la
	# noche: llega con luz, enciende la fogata, ordena el alijo y queda a
	# resguardo — en el llano de la banda estan todos a tiro de ayuda.
	var pre_night_home := _is_pre_night() and has_built_sh and not desperate_needs and not starving_or_parched
	# Rescate por frio: antes de caminar a ciegas al refugio mas cercano, el
	# helado intenta hacerse calor donde esta — acercarse a un fuego ya
	# encendido, montar la fogata de emergencia con su material o salir a
	# por los palos/piedras que faltan. Solo si nada sirve cae a la marcha.
	if _bot_try_cold_rescue(b, delta):
		return
	# Sueño letal (<=4, ya drena vida): la siesta de emergencia entra aunque
	# haya hambre/sed — sin despensa que saquear, seguir despierto es morir
	# de pie; dormir recupera sueño y frena tambien el desgaste de hambre.
	var wants_camp: bool = float(b["hide_timer"]) > 0.0 or pre_night_home or (is_night and not has_night_light) \
		or (vst != null and not vst.dead and vst.sleep <= 4.0) \
		or (not desperate_needs and not starving_or_parched and (night_needs_sleep or float(b["health"]) < 65.0 or _bot_is_freezing(b) or _bot_is_exhausted(b) or _bot_wants_day_rest(b)))
	# Con frio o agotamiento extremo busca refugio/fuego bastante mas lejos que
	# el radio normal: sobrevivir pesa mas que la comodidad.
	var refuge_radius := 85.0
	if _bot_is_freezing(b) or _bot_is_exhausted(b):
		refuge_radius = 220.0
	# "Estar en la base" exige refugio levantado: el solar reclamado sin
	# edificio no sirve para acampar — ahi se va a construir, no a dormir.
	var rest_pos: Vector3 = sh_pos if has_built_sh else _nearest_safe_refuge(b, refuge_radius)
	# Acampar al lado del fuego, no encima: si el punto de descanso cae
	# dentro del anillo de calor que cocina (<3.9 m de una fogata viva),
	# se desplaza al borde seguro del calor — dormir pegado a las brasas
	# termina en muerte por calor ("succumbed" sin frio ni hambre).
	if rest_pos != Vector3.INF:
		rest_pos = _bot_fire_safe_spot(rest_pos, rest_pos.y, b)
	# Si el sueño esta ya en zona letal (<=8, perdiendo vida por segundo) y el
	# refugio queda lejos (>6 m), caminar 200 m a paso lento lo mataria por el
	# camino: se desploma a dormir donde esta.
	if vst != null and vst.sleep <= 8.0 and rest_pos != Vector3.INF and Vector2(proxy.global_position.x - rest_pos.x, proxy.global_position.z - rest_pos.z).length() > 6.0:
		rest_pos = Vector3.INF
	# Hipotermia sin refugio alcanzable: la ultima opcion es la marcha de
	# emergencia hacia el calor/refugio mas cercano DEL MAPA — llegar a el o
	# morir en el camino gana a patrullar en el sitio hasta congelarse. Con
	# sueño letal el parapeto sigue mandando (dormir es el mal inminente).
	if rest_pos == Vector3.INF and _bot_is_freezing(b) and (vst == null or vst.sleep > 8.0):
		rest_pos = _nearest_safe_refuge(b, GameConst.BOT_EMERGENCY_REFUGE_RADIUS)
	# Ni refugio en todo el mapa ni fuego posible: la marcha corta es lo
	# ultimo — moverse genera calor corporal y seca la ropa; quedarse de
	# pie o sentado mojado es congelarse seguro.
	if rest_pos == Vector3.INF and _bot_is_freezing(b) and (vst == null or vst.sleep > 8.0):
		if _bot_freeze_march(b, delta):
			return
	if rest_pos != Vector3.INF and wants_camp:
		b["_act"] = "rest"
		var d_sh := Vector2(proxy.global_position.x - rest_pos.x, proxy.global_position.z - rest_pos.z).length()
		if d_sh > 1.8:
			var rush_refuge: bool = _bot_is_freezing(b) and d_sh > 4.0 and (vst == null or vst.sleep > 12.0)
			_move_bot_towards(b, rest_pos, 5.8 if rush_refuge else 3.8, delta, "run" if rush_refuge else "walk")
			return
		# Dentro del refugio: encender fogata si se apagó, asar carne (solo si tiene Palo afilado / Carne ensartada) y descansar/ocultarse
		if has_built_sh:
			_ensure_bot_campfire_lit(b)
		# Sin fogata aun y con material a mano: la monta junto a donde acampa —
		# la lena y las piedras que junto al caer la tarde se vuelven luz y
		# calor para la noche (quien se esconde no enciende un faro).
		if str(b["campfire_id"]).is_empty() and float(b["hide_timer"]) <= 0.0 \
				and (is_night or _is_pre_night() or _bot_is_freezing(b)) \
				and _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2 \
				and not _is_near_any_lit_campfire(proxy.global_position, 8.0):
			_bot_build_and_light_campfire(b, proxy.global_position + Vector3(0.9, 0.0, 0.9))
		if float(b["cook_cooldown"]) <= 0.0 and _bot_can_cook_raw_meat(proxy) and (sh_pos != Vector3.INF or _is_near_any_lit_campfire(proxy.global_position, 6.0)):
			_bot_cook_meat_at_fire(b)
		# Solo craftea en el refugio si esta sano y no se esta ocultando de una
		# amenaza: herido o escondido descansa/aguanta, no se pone a tallar.
		# (De noche la Antorcha puntua alto aqui: la fabrica antes de dormir.)
		if float(b["health"]) >= 70.0 and float(b["hide_timer"]) <= 0.0 and not _bot_is_exhausted(b) and _bot_try_craft(b, delta):
			return
		# Отойти от жара: лумба гонит температуру к 38 °C — спать/сидеть
		# врастяжку у brasas нельзя, отодвигаемся на безопасный ободок.
		if _bot_camp_fire_standoff(b, delta):
			return
		# Dormir de noche igual que un jugador humano: se tumba, recupera
		# sueño/energia/salud y despierta al amanecer, con frio o calor letal,
		# hambre/sed urgente, o al oir/sufrir una amenaza.
		if _bot_try_start_sleep(b, is_night):
			return
		# Sin refugio propio al que acurrucarse no se pasa toda la noche
		# petrificado en mitad de la nada: ronda cerca — el saqueo y la
		# recoleccion cercanos le siguen ganando si algo entra en sentidos.
		if not has_built_sh and _bot_night_sentry_wander(b, delta):
			return
		b["sitting"] = true
		b["crouching"] = str(b["faction"]) == "hostile"
		proxy.set_meta("crouching", bool(b.get("crouching", false)))
		b["anim"] = "sit"
		if float(b["health"]) < 100.0 and float(b.get("sick_timer", 0.0)) <= 0.0:
			var healed := minf(100.0, float(b["health"]) + delta * 1.8)
			b["health"] = healed
			proxy.set_meta("proxy_health", healed)
			proxy.set_meta("saved_health", healed)
		return
	elif wants_camp:
		# Quiere acampar pero no hay refugio alcanzable (de noche sin luz, por
		# ejemplo): se parapeta donde esta — duerme si puede, si no, sentado.
		b["_act"] = "rest"
		if str(b["campfire_id"]).is_empty() and float(b["hide_timer"]) <= 0.0 \
				and (is_night or _is_pre_night() or _bot_is_freezing(b)) \
				and _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2 \
				and not _is_near_any_lit_campfire(proxy.global_position, 8.0):
			_bot_build_and_light_campfire(b, proxy.global_position + Vector3(0.9, 0.0, 0.9))
		if float(b["cook_cooldown"]) <= 0.0 and _bot_can_cook_raw_meat(proxy) and _is_near_any_lit_campfire(proxy.global_position, 6.0):
			_bot_cook_meat_at_fire(b)
		if float(b["health"]) >= 70.0 and float(b["hide_timer"]) <= 0.0 and not _bot_is_exhausted(b) and _bot_try_craft(b, delta):
			return
		if not _bot_camp_fire_standoff(b, delta) and not _bot_try_start_sleep(b, is_night):
			# En vez de quedar petrificado en el campo abierto hasta el
			# amanecer, ronda su zona en paseos cortos; con amenaza, de dia o
			# junto a su fuego se queda quieto como antes.
			if not _bot_night_sentry_wander(b, delta):
				b["sitting"] = true
				b["crouching"] = str(b["faction"]) == "hostile"
				proxy.set_meta("crouching", bool(b.get("crouching", false)))
				b["anim"] = "sit"
		return

	# 6b) Crafteo: sin urgencias, fabrica con los mismos RECIPES que un jugador
	# (herramientas, armas, flechas, cuerda, ropa de piel, antorcha, comida...)
	if _bot_try_craft(b, delta):
		b["_act"] = "craft"
		return

	# 6c) Vida sedentaria: con su refugio ya levantado en la base y sin
	# necesidades ni encargos pendientes, el superviviente se refugia en casa
	# y descansa — no vaga todo el dia arriba y abajo. Sale solo cuando
	# necesita provisiones/loot o la IA tactica le marca un destino.
	if not starving_or_parched and _bot_has_own_base(b) and not _bot_needs_outing(b):
		var home_spot := _bot_fire_safe_spot(sh_pos, proxy.global_position.y, b)
		var d_home := Vector2(proxy.global_position.x - home_spot.x, proxy.global_position.z - home_spot.z).length()
		if d_home > 3.2:
			b["_act"] = "return_home"
			b["sitting"] = false
			b["crouching"] = false
			_move_bot_travel(b, home_spot, d_home, 3.6, 5.5, delta)
			return
		# En casa: sentado junto a su refugio, recuperando algo de vida como
		# en el descanso de wants_camp. El lobo domestico recibe 'stay' por
		# _sync_bot_wolf_orders (resting_home detecta sitting).
		b["_act"] = "rest_home"
		b["sitting"] = true
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		b["anim"] = "sit"
		if float(b["health"]) < 100.0 and float(b.get("sick_timer", 0.0)) <= 0.0:
			var healed_home := minf(100.0, float(b["health"]) + delta * 1.2)
			b["health"] = healed_home
			proxy.set_meta("proxy_health", healed_home)
			proxy.set_meta("saved_health", healed_home)
		return

	# 6d) Asentarse: con el campamento elegido pero el refugio aun sin
	# levantar, el superviviente tira hacia su solar ENTRE VIAJES. Cede a un
	# explore_target en curso (salida a lootear, ruido o encuentro lejano):
	# si el viaje a casa se impone por encima de cualquier objetivo lejano,
	# el bot queda orbitando el solar sin poder salir nunca a buscar.
	# Las urgencias (amenazas, sed, hambre, equipo) van antes.
	if str(b["shelter_id"]).is_empty() and not starving_or_parched \
			and float(b.get("hide_timer", 0.0)) <= 0.0 and not bool(b.get("sleeping", false)) \
			and b.get("explore_target", Vector3.INF) == Vector3.INF:
		var settle_pos := _bot_build_camp_pos(b)
		if settle_pos != Vector3.INF:
			var d_settle := Vector2(proxy.global_position.x - settle_pos.x, proxy.global_position.z - settle_pos.z).length()
			if d_settle > 22.0:
				b["_act"] = "settle"
				b["sitting"] = false
				b["crouching"] = false
				_move_bot_travel(b, settle_pos, d_settle, 3.6, 6.0, delta)
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
	_move_bot_travel(b, cur_target, flat_t, 3.5, 6.2, delta)

# Los tres tipos de viaje conservan el estado de carrera. Antes solo lo
# guardaba explorar: volver a casa alternaba run/walk alrededor de 55 energia.
func _move_bot_travel(b: Dictionary, goal: Vector3, dist: float, walk_speed: float, run_speed: float, delta: float) -> void:
	var previous_goal: Variant = b.get("_travel_gait_goal")
	if not (previous_goal is Vector3) or (previous_goal as Vector3).distance_squared_to(goal) > 25.0:
		b["_expl_run"] = false
	b["_travel_gait_goal"] = goal
	var run_leg := _bot_explore_wants_run(b, dist)
	b["_expl_run"] = run_leg
	_move_bot_towards(b, goal, run_speed if run_leg else walk_speed, delta, "run" if run_leg else "walk")

# Trote como un jugador: destinos lejanos y energia de sobra corren; al
# acercarse, cansado o helado vuelve a caminar. La histeresis por tramo
# (entra a >30 m/55 en., sale a <16 m/32 en.) evita aletear walk/run.
func _bot_explore_wants_run(b: Dictionary, dist: float) -> bool:
	if bool(b.get("_stamina_recover", false)):
		return false
	var en := _bot_energy(b)
	var hunger := float(b.get("hunger", 100.0))
	var thirst := float(b.get("thirst", 100.0))
	if bool(b.get("_expl_run", false)):
		return dist >= 16.0 and en >= 32.0 and hunger >= 28.0 and thirst >= 24.0 and not _bot_is_freezing(b)
	return dist > 30.0 and en >= 55.0 and hunger >= 48.0 and thirst >= 38.0 and not _bot_is_freezing(b)

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
	for b_idx in range(CityBlock.BUILDINGS.size()):
		var definition: Dictionary = CityBlock.BUILDINGS[b_idx]
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
				if b_idx % 4 in [1, 2]:
					_poi_cache.append({"pos": b_pos + Vector3(1.6, 7.86, 4.8).rotated(Vector3.UP, b_yaw), "kind": "tower"})
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
	for route in ElevationRoutes.summit_routes():
		_poi_cache.append({"pos": route["points"].back(), "kind": "tower"})
	# Southern expansion and outer forest: cover the full playable rectangle.
	for p in [Vector3(-400,0,420), Vector3(-240,0,580), Vector3(-300,0,840), Vector3(260,0,840), Vector3(340,0,570), Vector3(420,0,-100), Vector3(360,0,-440), Vector3(-80,0,-440)]:
		p.y = _ground_y(p.x, p.z)
		if not _is_pos_blocked(p):
			_poi_cache.append({"pos": p, "kind": "wild"})
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
				var regions: Dictionary = mem.get("exploration_regions", {})
				var region := _exploration_region(pp)
				regions[region] = int(regions.get(region, 0)) + 1
				mem["exploration_regions"] = regions
			observe_location(bid, id, str(p.get("kind", "wild")), pp, "observed", true)
			record_strategy_outcome(bid, "explore_" + str(p.get("kind", "wild")), true, 0.04)
			# Plan del asesor por tipo de POI: visitarlo marca _visit_done y el
			# sondeo lo cierra pidiendo el siguiente paso (plan_done). Con
			# destino fijado solo cuenta llegar a ESE lugar — pasar por otro
			# POI del mismo tipo no es cumplir el objetivo.
			var dd: Dictionary = b.get("ai_directive", {})
			if str(dd.get("mode", "")) == "poi":
				var did := str(dd.get("_dest_id", ""))
				var dpos: Vector3 = dd.get("_dest_pos", Vector3.INF)
				var matches := false
				if not did.is_empty():
					matches = did == _poi_id(p)
				elif dpos != Vector3.INF:
					matches = Vector2(dpos.x - pp.x, dpos.z - pp.z).length() < 14.0
				else:
					var oks: Array = dd.get("only_kinds", [])
					matches = oks.is_empty() or oks.has(str(p.get("kind", "wild")))
				if matches:
					dd["_visit_done"] = true
	mem["visited"] = visited
	b["_mem"] = mem
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
# Veto persistente de un POI "inalcanzable": exige varias marcas
# nav_blocked — un bot atascado vetaba con UN solo fallo cada destino
# que intento (~20 edificios de ciudad en 2 min) y les cerraba el paso
# durante 6 h, que sobrevivian al wipe del mundo en la memoria. TTL
# corto ademas: inalcanzable desde aqui no es inalcanzable siempre.
const UNREACHABLE_VETO_MIN_FAILS := 3
const UNREACHABLE_VETO_TTL := 300.0

func _is_goal_blacklisted(b: Dictionary, pos: Vector3) -> bool:
	var bl: Array = b.get("_unreachable", [])
	if bl.is_empty():
		return false
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var hit := false
	var kept: Array = []
	for entry in bl:
		if not (entry is Dictionary) or float(entry.get("until", 0.0)) <= now_s:
			continue # caducado: se borra del registro, no solo se ignora
		kept.append(entry)
		var bp = entry.get("pos")
		if bp is Vector3 and Vector2(pos.x - (bp as Vector3).x, pos.z - (bp as Vector3).z).length() < 18.0:
			hit = true
	if kept.size() != bl.size():
		b["_unreachable"] = kept
	return hit

# Un destino al que no se pudo llegar NO es una visita: no marca _visit_done
# ni exito de exploracion. Se recuerda como INALCANZABLE (lista negra corta en
# caliente + veto persistente) para no reelegirlo en las proximas horas.
func _mark_poi_unreachable(b: Dictionary, pos: Vector3, cause: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return
	# Ultimo bloqueo de ruta para el monitor: donde y por que murio el viaje.
	b["_last_nav_block"] = {"pos": pos, "cause": cause, "t": Time.get_unix_time_from_system()}
	var un: Dictionary = mem.get("unreachable_pois", {})
	# Borrado de vetos caducados: un POI marcado hace mas de una hora sale del
	# registro — su contador de fallos vuelve a cero y necesita fallos NUEVOS
	# para revetar (un tropiezo no puede revivir un veto muerto).
	var now_u := Time.get_unix_time_from_system()
	for uk in un.keys():
		var ue: Dictionary = un[uk]
		if now_u - float(ue.get("t", 0.0)) >= UNREACHABLE_VETO_TTL:
			un.erase(uk)
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		if Vector2(pos.x - pp.x, pos.z - pp.z).length() < 14.0 and (pp.y < 2.2 or absf(pos.y - pp.y) < 2.6):
			var id := _poi_id(p)
			var e: Dictionary = un.get(id, {})
			e["n"] = int(e.get("n", 0)) + 1
			e["t"] = Time.get_unix_time_from_system()
			e["cause"] = cause
			un[id] = e
			record_bot_event(int(b.get("bot_id", 0)), "goal_unreachable", "", str(p.get("kind", "wild")), pp, cause)
			break
	while un.size() > 24:
		var oldest := ""
		var old_t := INF
		for k in un.keys():
			if float((un[k] as Dictionary).get("t", 0.0)) < old_t:
				old_t = float((un[k] as Dictionary).get("t", 0.0))
				oldest = str(k)
		if oldest.is_empty():
			break
		un.erase(oldest)
	mem["unreachable_pois"] = un

# Rodeo previo al veto: un find_path vacio prueba que la linea recta no
# navega, no que el destino sea inalcanzable. Antes de quemar el plan se
# prueba UNA alternativa — aproximacion lateral al objetivo (rodear el lago/
# muro por un flanco) o un salto corto en la direccion del viaje. Solo un
# intento por objetivo distinto (_detour_goal lo recuerda el llamador).
func _bot_nav_detour(b: Dictionary, cur: Vector3, goal: Vector3, bot_nav_ref) -> Vector3:
	if bot_nav_ref == null:
		return Vector3.INF
	var dir := Vector3(goal.x - cur.x, 0.0, goal.z - cur.z)
	var dist := dir.length()
	if dist < 0.5:
		return Vector3.INF
	dir = dir.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var cands: Array = []
	# Flancos del objetivo: el muro/rio de la linea recta se rodea por el lado
	for side in [1.0, -1.0]:
		var cg: Vector3 = goal + perp * 30.0 * side
		cg.y = _ground_y(cg.x, cg.z)
		cands.append(cg)
	# Salto corto hacia el objetivo: encadenar tramos navegables
	var hop := cur + dir * minf(35.0, dist)
	hop.y = _ground_y(hop.x, hop.z)
	cands.append(hop)
	# Salto diagonal corto a cada lado del rumbo
	for side2 in [1.0, -1.0]:
		var cd: Vector3 = cur + (dir + perp * side2).normalized() * 25.0
		cd.y = _ground_y(cd.x, cd.z)
		cands.append(cd)
	for cand in cands:
		if not (bot_nav_ref.find_path(cur, cand) as Array).is_empty():
			return cand
	return Vector3.INF

# Salto encadenado para viajes largos: a >140 m el nav rara vez resuelve la
# linea completa; andar POI a POI en la direccion del destino convierte la
# ruta "imposible" en tramos cortos navegables. Al llegar al salto, el mismo
# mecanismo elige el siguiente — la cadena se reencadena sola.
func _bot_route_leg(b: Dictionary, far_pos: Vector3) -> Vector3:
	if far_pos == Vector3.INF:
		return far_pos
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return far_pos
	var cur := proxy.global_position
	var flat := Vector2(far_pos.x - cur.x, far_pos.z - cur.z).length()
	if flat <= 140.0:
		return far_pos
	var dir := Vector2(far_pos.x - cur.x, far_pos.z - cur.z).normalized()
	var best := Vector3.INF
	var best_score := -1e9
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		var to := Vector2(pp.x - cur.x, pp.z - cur.z)
		var d := to.length()
		if d < 20.0 or d > 140.0:
			continue
		# Delante del rumbo (+-40°) y acercando de verdad al destino final
		if to.normalized().dot(dir) < 0.76:
			continue
		var remain := Vector2(far_pos.x - pp.x, far_pos.z - pp.z).length()
		if remain >= flat:
			continue
		if _is_goal_blacklisted(b, pp) or _is_poi_unreachable(b, _poi_id(p)):
			continue
		var score := (flat - remain) - d * 0.15
		if score > best_score:
			best_score = score
			best = pp
	return best if best != Vector3.INF else far_pos

# El veto dura ~6 h reales: el terreno no cambia pero el punto de partida si —
# inalcanzable desde aqui puede serlo alcanzable desde otro angulo.
func _is_poi_unreachable(b: Dictionary, poi_id: String) -> bool:
	var un: Dictionary = b.get("_mem", {}).get("unreachable_pois", {})
	var e = un.get(poi_id)
	if not (e is Dictionary):
		return false
	# Caduco: se BORRA — no solo se ignora. El contador n no sobrevive a la
	# caducidad: un veto viejo no puede revetar con un solo fallo nuevo.
	if Time.get_unix_time_from_system() - float((e as Dictionary).get("t", 0.0)) >= UNREACHABLE_VETO_TTL:
		un.erase(poi_id)
		return false
	# Un solo nav_blocked no prueba que el destino sea inalcanzable — lo
	# habitual es que el ATASCADO sea el bot (origen), no el lugar.
	return int((e as Dictionary).get("n", 1)) >= UNREACHABLE_VETO_MIN_FAILS

func _abandon_unreachable_goal(b: Dictionary, goal: Vector3) -> void:
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var bl: Array = b.get("_unreachable", [])
	var kept: Array = []
	for entry in bl:
		if entry is Dictionary and float(entry.get("until", 0.0)) > now_s:
			kept.append(entry)
	if goal != Vector3.INF:
		kept.append({"pos": goal, "until": now_s + 240.0})
		_mark_poi_unreachable(b, goal, "nav_blocked")
	var et: Vector3 = b.get("explore_target", Vector3.INF)
	if et != Vector3.INF:
		kept.append({"pos": et, "until": now_s + 240.0})
		_mark_poi_unreachable(b, et, "nav_blocked")
		b["explore_target"] = Vector3.INF
		b["explore_dwell"] = 0.0
	var sl: Dictionary = b.get("_s_loot", {})
	if not sl.is_empty():
		var sl_pos := _loot_entry_pos(sl)
		kept.append({"pos": sl_pos, "until": now_s + 240.0})
		_loot_clear(b)
	b["_unreachable"] = kept
	b["path"] = []
	b["path_timer"] = 0.0
	b["climb_route"] = []
	var d0: Dictionary = b.get("ai_directive", {})
	if not d0.is_empty() and str(d0.get("mode", "")) == "pos" \
			and PlanManager.Interruptions.reasons(b, d0).is_empty() \
			and _ai_step_target_pos(b, d0).distance_to(goal) < 6.0:
		var bid0 := int(b.get("bot_id", 0))
		PlanManager.finish(b, d0, "FAILED", "nav_blocked", Time.get_ticks_msec())
		PlanDiagnostics.metric(b, "real_blocks")
		PlanDiagnostics.metric(b, "steps_failed")
		b["ai_directive"] = {}
		b["_plan_last_result"] = "nav_unreachable"
		# La ruta al objetivo no existe: fallo de NAVEGACION, no de recursos.
		# El paso, el plan y el pendiente guardado quedan invalidados — no se
		# reanuda lo que esta demostrado inalcanzable.
		record_strategy_outcome(bid0, str(d0.get("action", "")), false, 0.16, "nav_blocked")
		var root0 := str(d0.get("_plan_root", d0.get("action", "")))
		record_plan_outcome(bid0, root0, false, 0.08, "plan_broken")
		_ai_note_failed_goal(b, d0, "nav_blocked")
		_ensure_bot_memory(bid0, b.get("cfg", {}))["pending_goals"] = []
		_ai_stat_inc(b, "steps_failed")
		_ai_stat_inc(b, "plans_failed")
		_ai_stat_inc(b, "blocked_recoveries")
		_ai_enqueue_request(int(b.get("bot_id", 0)), 4, "plan_blocked", true)
	if str(b.get("_act", "")) == "drink" and b.get("drink_at", Vector3.INF) != Vector3.INF and Vector2(goal.x - b["drink_at"].x, goal.z - b["drink_at"].z).length() < 6.0:
		b["drink_at"] = Vector3.INF
		b["drink_giveup"] = 12.0
	var gst: Dictionary = b.get("_gather", {})
	var gpos = gst.get("pos")
	if not gst.is_empty() and gpos is Vector3 and Vector2(goal.x - (gpos as Vector3).x, goal.z - (gpos as Vector3).z).length() < 6.0:
		_bot_release_gather_claim(b, gst)
		b["_gather"] = {}
	if not (b.get("_forage", {}) as Dictionary).is_empty():
		b["_forage"] = {}
	var cur_aggro: Node3D = b.get("aggro_target")
	if cur_aggro != null and is_instance_valid(cur_aggro) and Vector2(goal.x - cur_aggro.global_position.x, goal.z - cur_aggro.global_position.z).length() < 6.0:
		b["aggro_target"] = null
		b["aggro_timer"] = 0.0
		b["flee_until"] = maxf(float(b.get("flee_until", 0.0)), 6.0)
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
	if not directive.is_empty() and str(directive.get("mode", "")) == "poi":
		# El paso lleva UN destino fijado al adoptarlo: la navegacion va a ese,
		# no al POI del tipo que ahora quede mas cerca. Si el fijado quedo
		# vetado (lista negra/inalcanzable) se repieza otro y se refija.
		var dpin = directive.get("_dest_pos")
		if dpin is Vector3 and (dpin as Vector3) != Vector3.INF:
			if not _is_goal_blacklisted(b, dpin) and (not bool(directive.get("_visit_done", false)) or str(directive.get("goal", "")) == "gear_up_at_military_base"):
				return dpin
			directive.erase("_dest_pos")
			directive.erase("_dest_id")
	var only_kinds: Array = directive.get("only_kinds", []) if not directive.is_empty() else []
	var avoid_kinds: Array = directive.get("avoid_kinds", []) if not directive.is_empty() else []
	var pick := _ai_pick_poi(b, only_kinds, avoid_kinds, true)
	if pick.is_empty():
		return Vector3.INF
	var best: Vector3 = pick["pos"]
	if not directive.is_empty() and str(directive.get("mode", "")) == "poi":
		directive["_dest_pos"] = best
		directive["_dest_id"] = str(pick.get("id", ""))
	return best

# Puntuacion de POIs compartida por la navegacion y el fijado de destino del
# paso: mismo criterio (personalidad, memoria, sector, anti-cluster) para que
# el lugar que el plan registra sea EXACTAMENTE al que el bot camina.
# jitter=false da la eleccion determinista que usa el veto de objetivos.
func _ai_pick_poi(b: Dictionary, only_kinds: Array, avoid_kinds: Array, jitter: bool) -> Dictionary:
	var pois := _explore_pois()
	if pois.is_empty():
		return {}
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return {}
	var mem: Dictionary = b.get("_mem", {})
	var visited: Array = mem.get("visited", [])
	var known: Dictionary = mem.get("known_locations", {})
	var pers: Dictionary = _get_bot_personality(b)
	var death_pos: Vector3 = mem.get("last_death_pos", Vector3.INF)
	var hostile := str(b.get("faction", "")) == "hostile"
	var bravery := float(pers.get("bravery", 0.5))
	var curiosity := float(pers.get("curiosity", 0.5))
	var aggro_t := float(pers.get("aggression", 0.3))
	var surv_t := float(pers.get("survival_instinct", 0.7))
	# El hambre empuja hacia el monte: ahi estan la caza, las setas y la fruta,
	# no en las ruinas que ya se saquearon.
	var expedition := _bot_can_expedition(b)
	var region_counts: Dictionary = mem.get("exploration_regions", {})
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
			if _is_poi_unreachable(b, pid):
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
			var score := w * 100.0 - minf(d, 220.0) * 0.25 + (rng.randf_range(0.0, 30.0) if jitter else 0.0)
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
					break # one occupied sector, not a penalty per squad member
			if expedition:
				score += 600.0 / (1.0 + float(region_counts.get(_exploration_region(pp), 0)))
			score *= _ai_poi_memory_factor(b, pp, kind)
			# Estado actual vs destino: el historial lo pesa memory_factor;
			# esto penaliza lo que el cuerpo no puede pagar ahora (lejos sin
			# energia/reservas) y el historial de combate de ESA zona.
			score *= _ai_poi_state_factor(b, pid, d)
			if score > best_score:
				best_score = score
				best = pp
				best_p = p
		if best != Vector3.INF:
			if pass_i == 1:
				visited.clear()
				mem["visited"] = visited
			break
	if best == Vector3.INF:
		return {}
	return {"pos": best, "id": _poi_id(best_p), "kind": str(best_p.get("kind", "")), "route": best_p.get("route")}

func _maintain_bot_needs(b: Dictionary, delta: float) -> void:
	b["consume_anim_t"] = maxf(0.0, float(b.get("consume_anim_t", 0.0)) - delta)
	if float(b["consume_anim_t"]) <= 0.0: b["_consume_from_inventory"] = false
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	# Vendarse si tiene poca salud o sangrado (si aprendio de muertes en combate, se venda antes)
	var d_lessons: Dictionary = b.get("_mem", {}).get("death_lessons", {})
	var bandage_line := 72.0 + minf(12.0, float(int(d_lessons.get("combat", 0))) * 4.0) + minf(10.0, float(int(d_lessons.get("medical", 0))) * 5.0)
	var vst_b: SurvivalStats = b.get("vstats")
	var is_bleeding: bool = vst_b != null and vst_b.bleeding > 0.0
	# La regeneracion pasiva (misma regla que SurvivalStats.tick) cura sola a
	# quien esta sano por dentro: gastar provisiones en eso es desperdicio.
	var can_regen := _bot_passive_regen_ok(b)
	var hp_now := float(b["health"])
	# Con el enemigo encima no hay manos libres para vendarse ni comer: se
	# pospone (cobertura/huida primero) salvo hemorragia o vida ya critica.
	var pressed := _bot_treatment_pressed(b)
	# Venda: primero cortar la hemorragia. Sin sangrado solo se gasta si la
	# cura se aprovecha entera y el cuerpo no va a reponerse solo a tiempo.
	var want_bandage := is_bleeding
	if not want_bandage and hp_now < bandage_line:
		want_bandage = hp_now < 45.0 or not can_regen or _bot_under_immediate_threat(b)
	if want_bandage and pressed and hp_now >= 25.0 and not (is_bleeding and vst_b.bleeding >= 2.0):
		want_bandage = false
	if want_bandage and float(b["eat_cooldown"]) <= 0.0:
		for i in range(inv.size()):
			var it = inv[i]
			if it is Dictionary and str(it.get("name", "")) in ["Venda", "Vendaje"] and int(it.get("quantity", 1)) > 0:
				# Misma cura que al jugador (Inventory "medical"): el
				# use_value del objeto, no un extra de bot.
				var heal := float(it.get("use_value", 24.0))
				if heal <= 0.0:
					heal = 24.0
				if not is_bleeding and hp_now + heal > 100.0 + heal * 0.35:
					break # se desperdiciaria casi toda: guardarla
				it["quantity"] = int(it.get("quantity", 1)) - 1
				if int(it["quantity"]) <= 0:
					inv.remove_at(i)
				if vst_b != null:
					vst_b.stop_bleeding()
					vst_b.feet_wound = 0.0
				var new_hp := minf(100.0, float(b["health"]) + heal)
				b["health"] = new_hp
				proxy.set_meta("proxy_health", new_hp)
				proxy.set_meta("saved_health", new_hp)
				proxy.set_meta("saved_inventory", inv)
				b["eat_cooldown"] = 8.0
				break
	# Comer si tiene hambre o necesita recuperar vida. Si ya murio de inanicion
	# aprendio a no apurar: come antes de llegar al limite.
	var hunger_line := 60.0 + (16.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0) + minf(16.0, float(int(d_lessons.get("starved", 0))) * 6.0)
	# Orden directa del líder "come": come la mejor comida aunque no tenga hambre
	var force_eat := bool(b.get("forced_eat", false))
	if force_eat:
		b["forced_eat"] = false
	# Comer para curarse solo cuando el bocado se aprovecha (hueco real en
	# el estomago) y la herida no se va a cerrar sola: con el hambre casi
	# llena la racion no se toca — se guarda para cuando haga falta.
	var hunger_now := float(b["hunger"])
	var eat_to_heal := hp_now < 80.0 and hunger_now < 82.0 and (not can_regen or hp_now < 50.0)
	if pressed and hunger_now >= 20.0:
		eat_to_heal = false
	var eat_hungry := hunger_now < hunger_line and not (pressed and hunger_now >= 20.0)
	# Con crudos encima y sin Palo afilado, el superviviente se afana en
	# afilar un palo para ensartar y cocinar en vez de intoxicarse: el craft
	# corre aqui cada tick, tambien durante el cooldown de comida.
	var desperate := float(b["hunger"]) < 28.0
	var can_cook_raw := _bot_can_cook_raw_meat(proxy)
	var can_sharpen := desperate and not can_cook_raw and float(b["hunger"]) > 5.0 and _bot_can_sharpen_for_meat(proxy)
	if can_sharpen:
		_bot_try_craft_named(b, delta, ["Palo afilado"], false)
	# El crudo queda vedado solo mientras la inanicion no sea lo peor: a
	# hambre ~0 su -2/s supera el -1/s del veneno y el bocado crudo gana,
	# aunque haya espeton esperando una fogata que no llega.
	var raw_locked := (can_cook_raw or can_sharpen) and float(b["hunger"]) > 5.0
	if (force_eat or eat_hungry or eat_to_heal) and float(b["eat_cooldown"]) <= 0.0:
		# Leccion 'medical' (se desangro o se enveneno): la carne cruda es
		# ultimo recurso — solo se arriesga si aguanta el drenaje (vida tras
		# el bocado + cura/comida encima) o si la inanicion es ya peor que el
		# veneno (hambre casi a 0: su -2/s supera el -1/s de la enfermedad).
		var med_lessons := int(d_lessons.get("medical", 0))
		if med_lessons > 0 and desperate and float(b.get("sick_timer", 0.0)) <= 0.0 and not raw_locked:
			var margin := 70.0 + minf(10.0, float(med_lessons) * 4.0)
			desperate = float(b["hunger"]) <= 5.0 or float(b["health"]) * 0.5 + _bot_poison_cover(proxy) > margin
		# Elegir el mejor bocado: la comida segura de mas valor gana (Pez
		# cocinado 50 > carne de oso 45 > latas > setas) y el crudo solo se
		# come si no queda otra cosa — un humano no se intoxica teniendo un
		# filete bueno en la mochila.
		var pick_i := -1
		var pick_score := -1e9
		for i in range(inv.size()):
			var it_s = inv[i]
			if not (it_s is Dictionary):
				continue
			var nm_s := str(it_s.get("name", ""))
			# Latas cerradas y pescado crudo no se pueden comer directamente:
			# la lata hay que abrirla antes con cuchillo/hacha (receta de crafteo).
			if str(it_s.get("type", "")) != "food" or nm_s == "Carne humana" or nm_s == "Pez crudo" \
					or (nm_s.begins_with("Lata de ") and not nm_s.ends_with(" abierta")):
				continue
			var is_raw_s: bool = nm_s.begins_with("Carne cruda") or nm_s == "Carne ensartada" or nm_s == "Pez ensartado"
			if is_raw_s and (not desperate or raw_locked or str(b.get("_act", "")) == "tame"):
				continue
			var sc := float(it_s.get("use_value", 18.0))
			if nm_s.begins_with("Lata de ") and nm_s.ends_with(" abierta"):
				var dmax_s := float(it_s.get("max_durability", 100.0))
				if dmax_s <= 0.0 or float(it_s.get("durability", dmax_s)) <= 0.0:
					continue
				sc *= clampf(float(it_s.get("durability", dmax_s)) / dmax_s, 0.0, 0.5)
			elif is_raw_s:
				sc = sc * 0.4 - 1000.0 # el crudo siempre queda ultimo
			if sc > pick_score:
				pick_score = sc
				pick_i = i
		if pick_i >= 0:
			var i := pick_i
			var it = inv[i]
			var nm := str(it.get("name", ""))
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
			b["_consume_from_inventory"] = true
			_bot_log_eaten_food(b, nm)
		else:
			# Hambre con solo latas cerradas encima: abrir una YA con el
			# filo que lleve — el bocado no aparece esperando a que el
			# tick alcance el crafteo general (Kael murio forrajeando
			# con dos latas y un hacha en la mochila). El crafteo comparte
			# _craft_state; si otro urgente esta a media (Palo afilado) le
			# cede el turno hasta 6 s y se retoma despues.
			var closed_cans: Array = []
			for it_c in inv:
				if it_c is Dictionary:
					var nm_c := str(it_c.get("name", ""))
					if nm_c.begins_with("Lata de ") and not nm_c.ends_with(" abierta"):
						closed_cans.append(nm_c + " abierta")
			if not closed_cans.is_empty() and not can_sharpen:
				_bot_try_craft_named(b, delta, closed_cans, false)
	# Beber de botellas/cantimplora que lleve encima
	var bottle_thirst_line := 55.0 + (10.0 if bool(b.get("_mem", {}).get("scarcity", false)) else 0.0) + minf(15.0, float(int(d_lessons.get("dehydrated", 0))) * 5.0)
	if float(b["thirst"]) < bottle_thirst_line and float(b["eat_cooldown"]) <= 0.0:
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
			# Una botella llena deja la vacia reutilizable; quien aprendio de morir
			# de sed conserva hasta su tope de reserva (1..3) para rellenar en el rio.
			var empty_cap := _bot_desired_drink_cap(b)
			if nm == "Botella de agua llena" and _bot_container_count(proxy) < empty_cap and _bot_item_count(proxy, "Botella de plastico") < empty_cap:
				_bot_add_inventory_item(inv, {"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0})
			b["thirst"] = minf(100.0, float(b["thirst"]) + maxf(30.0, float(it.get("use_value", 40.0))))
			proxy.set_meta("saved_inventory", inv)
			proxy.set_meta("saved_thirst", float(b["thirst"]))
			b["eat_cooldown"] = 6.0
			b["consume_anim"] = "drink"
			b["consume_anim_t"] = 1.6
			b["_consume_from_inventory"] = true
			break
	# Auto-equipar mejor ropa o mochila que haya saqueado
	_auto_equip_best_gear(b)

# Misma puerta que la regeneracion pasiva de SurvivalStats.tick: sin
# enfermedad ni hemorragia, con sangre, comida, agua, sueño y temperatura
# en rango, la vida vuelve sola (0.5/s) — no hace falta gastar nada.
func _bot_passive_regen_ok(b: Dictionary) -> bool:
	var st: SurvivalStats = b.get("vstats")
	if st == null:
		return float(b.get("sick_timer", 0.0)) <= 0.0 and float(b.get("hunger", 0.0)) > 0.0 and float(b.get("thirst", 0.0)) > 0.0
	return not st.sick and float(b.get("sick_timer", 0.0)) <= 0.0 and st.bleeding <= 0.0 and st.blood >= 50.0 \
		and float(b.get("hunger", 0.0)) > 0.0 and float(b.get("thirst", 0.0)) > 0.0 \
		and (st.sleep > 20.0 or bool(b.get("sleeping", false))) \
		and st.body_temperature >= 35.4 and st.body_temperature < 37.8

# Enemigo o fiera a quemarropa, o le estan dando ahora mismo: no es momento
# de sentarse a vendarse o comer.
func _bot_treatment_pressed(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if Time.get_ticks_msec() - int(b.get("_last_attacker_msec", -999999)) < 2500:
		return true
	if Time.get_ticks_msec() - int(b.get("_wolf_bite_msec", -999999)) < 2500:
		return true
	for key in ["_s_foe", "_s_predator"]:
		var n := _sensed_node(b, key)
		if n != null and proxy.global_position.distance_to(n.global_position) <= 10.0:
			return true
	return false

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
		# Defender al lider de una fiera exige verla uno mismo: la cercania
		# del depredador al lider solo cuenta si el bot lo tiene a la vista.
		var eff_d := minf(d, d_leader) if d <= 45.0 else d
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

	var weapon := _best_weapon_name(proxy)
	var is_rifle := weapon == "Fusil de asalto" or weapon == "Rifle francotirador"
	var melee_reach := 4.0 if weapon in ["Lanza", "Lanza de hueso", "Palo afilado", "Hacha"] else 3.5

	# Si ya está a salvo en su refugio construido o dentro de una casa (donde
	# lobos/osos no pueden entrar) y el depredador está fuera, un humano NO sale
	# corriendo a sus fauces: dispara desde seguro o aguanta a resguardo.
	if _is_bot_wolf_protected(b) and dist > melee_reach + 0.5:
		if to_pred.length_squared() > 0.001:
			b["rot"] = atan2(-to_pred.x, -to_pred.z)
			proxy.rotation.y = float(b["rot"])
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
				var kind_s := "m4" if _bot_gun_is_m4(sweapon) else ("sniper" if skind == "rifle" else skind)
				if skind == "rifle" and _bot_fire_ready(b, predator, dist, true, delta, kind_s):
					b["shoot_cooldown"] = 0.95 if sweapon == "Fusil de asalto" else 1.65
					_bot_fire_rifle_at(b, predator, 68.0 if sweapon == "Fusil de asalto" else 145.0, sweapon)
				elif skind == "bow" and _bot_fire_ready(b, predator, dist, true, delta, "bow"):
					b["shoot_cooldown"] = 1.55 if sweapon == "Arco reforzado" else 1.9
					_bot_fire_bow(b, predator, sweapon)
				elif skind == "thrown" and _bot_fire_ready(b, predator, dist, true, delta, "throw"):
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
	b["prone"] = false
	proxy.set_meta("crouching", false)
	b["held_item"] = weapon
	b["has_rifle"] = is_rifle
	proxy.set_meta("saved_held_item", weapon)

	# Si lleva fusil y está a > 4 m, dispara al depredador; entre disparos si
	# el depredador está muy cerca (< 8.5 m) corre alejándose de frente (nunca
	# caminando de espaldas) y solo se gira al instante de disparar.
	if is_rifle and dist > 3.6:
		if not _has_clear_shot(proxy.global_position, ppos):
			# Use the normal obstacle/door navigation instead of firing forever
			# from the same blocked position.
			b["is_aiming"] = false
			_move_bot_towards(b, ppos, 6.2, delta, "run")
			return
		var ready_shot := float(b["shoot_cooldown"]) <= 0.15
		if dist < 8.5 and to_pred.length_squared() > 0.01 and not ready_shot:
			b["is_aiming"] = false
			var back_goal := proxy.global_position - to_pred.normalized() * 6.0
			_move_bot_towards(b, back_goal, 6.2, delta, "run")
			return
		b["is_aiming"] = true
		b["anim"] = "idle"
		# Tiro a media/larga distancia: se arrodilla — la misma postura de
		# estabilidad que usaria un jugador humano (0.28 vs 1.0 de dispersion).
		# A corta distancia (< 12 m) se queda de pie para reaccionar rapido.
		b["sitting"] = dist > 12.0
		if to_pred.length_squared() > 0.001:
			b["rot"] = atan2(-to_pred.x, -to_pred.z)
			proxy.rotation.y = float(b["rot"])
		if float(b["shoot_cooldown"]) <= 0.0 \
				and _bot_fire_ready(b, predator, dist, true, delta, "m4" if weapon == "Fusil de asalto" else "sniper"):
			b["shoot_cooldown"] = 0.95 if weapon == "Fusil de asalto" else 1.65
			var dmg := 68.0 if weapon == "Fusil de asalto" else 145.0
			_bot_fire_rifle_at(b, predator, dmg, weapon)
		return

	b["is_aiming"] = false
	# Sin arma de fuego un superviviente no caza lobos ni osos: huye como haría
	# un humano y solo pelea cuerpo a cuerpo cuando el animal ya está encima.
	if dist > melee_reach + 2.2:
		_flee_predator(b, predator, delta)
		return
	if dist <= melee_reach and absf(ppos.y - proxy.global_position.y) <= 1.8 and _has_clear_shot(proxy.global_position, ppos):
		# Paso lateral ágil mientras golpea para no quedarse quieto bajo las fauces
		var side := Vector3(-to_pred.z, 0.0, to_pred.x).normalized() if to_pred.length_squared() > 0.01 else Vector3.RIGHT
		_move_bot_towards(b, proxy.global_position + side * 2.2, 3.4, delta, "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION)
		if to_pred.length_squared() > 0.001:
			b["rot"] = atan2(-to_pred.x, -to_pred.z)
			proxy.rotation.y = float(b["rot"])
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
		_move_bot_towards(b, ppos, 6.2, delta, "run")

# Como un humano, el bot no caza depredadores sin arma de fuego: huye a un
# lugar seguro (su refugio, una fogata encendida o una casa) o en zigzag.
# Si tiene antorcha la enciende para intimidar al lobo (wary_torch), y si tiene
# boleadoras las lanza para frenar al perseguidor mientras escapa.
func _flee_predator(b: Dictionary, predator: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	_command_bot_wolf_against(b, predator)
	b["caution_until"] = maxf(float(b.get("caution_until", 0.0)), 9.0)
	var dist := proxy.global_position.distance_to(predator.global_position)
	var away := proxy.global_position - predator.global_position
	away.y = 0.0
	var away_dir := away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
	# Limpiar inercia previa si apuntaba hacia el depredador para no dar ni un
	# paso hacia atras mientras gira a escapar.
	var cur_mdir: Vector3 = b.get("_mdir", Vector3.ZERO)
	if cur_mdir.dot(away_dir) < 0.15:
		b["_mdir"] = away_dir
	# Antorcha encendida: mantiene a los lobos a raya (wary_torch en WildlifeController)
	if str(predator.get("animal_type")) == "wolf" and _bot_has_item(proxy, "Antorcha") \
			and (bool(b.get("torch_lit", false)) or _bot_ignite_torch(b)):
		b["torch_lit"] = true
		b["held_item"] = "Antorcha"
		b["has_rifle"] = false
		proxy.set_meta("torch_lit", true)
		proxy.set_meta("saved_held_item", "Antorcha")
	# Boleadoras defensivas en huida: frena 6 s al depredador sin detenerse a pelear
	if _bot_item_count(proxy, "Boleadoras") > 0 and float(b["shoot_cooldown"]) <= 0.0 and dist >= 4.5 and dist <= 18.0:
		if float(predator.get_meta("bola_slow_until", 0.0)) < Time.get_unix_time_from_system() and _has_clear_shot(proxy.global_position, predator.global_position) 				and _bot_fire_ready(b, predator, dist, true, delta, "throw"):
			b["shoot_cooldown"] = 2.6
			_bot_fire_thrown(b, predator, "Boleadoras", true)
	var sh_pos: Vector3 = b["shelter_pos"]
	if sh_pos != Vector3.INF and proxy.global_position.distance_to(sh_pos) < 110.0:
		var to_sh := sh_pos - proxy.global_position
		var to_pr := predator.global_position - proxy.global_position
		if to_sh.length() < 3.5 or to_sh.normalized().dot(to_pr.normalized()) < 0.35:
			b["hide_timer"] = 10.0
			_move_bot_towards(b, sh_pos, 6.5, delta, "run")
			return
	var refuge := _nearest_safe_refuge(b, 95.0, predator.global_position)
	if refuge != Vector3.INF:
		if proxy.global_position.distance_to(refuge) < 3.5:
			b["hide_timer"] = 8.0
		_move_bot_towards(b, refuge, 6.5, delta, "run")
		return
	b["strafe_timer"] = float(b["strafe_timer"]) + delta
	if float(b["strafe_timer"]) > 1.1:
		b["strafe_dir"] = -float(b["strafe_dir"])
		b["strafe_timer"] = 0.0
	var side := Vector3(-away_dir.z, 0.0, away_dir.x)
	var flee_dir := (away_dir + side * float(b["strafe_dir"]) * 0.45).normalized()
	_move_bot_towards(b, proxy.global_position + flee_dir * 9.0, 6.5, delta, "run")

func _is_near_any_lit_campfire(pos: Vector3, max_dist: float) -> bool:
	if world == null or not ("_lit_campfires" in world):
		return false
	var r_sq := max_dist * max_dist
	for lc in world._lit_campfires:
		if _campfire_entry_alive(lc) and lc.get("pos") is Vector3:
			if pos.distance_squared_to(lc["pos"] as Vector3) <= r_sq:
				return true
	return false

# Comprueba si el bot ya está dentro de un refugio construido o de una casa
# cerrada/abierta donde lobos y osos tienen prohibido entrar.
# El refugio construido puede desaparecer (demolido/robado por otro
# superviviente): su id ya no existe en el mundo. Se libera solo el id — el
# shelter_pos sigue siendo el solar reclamado donde el bot duerme y puede
# volver a construir, pero ya no cuenta como "a cubierto" ni protege de lobos.
func _validate_shelter_claim(b: Dictionary) -> void:
	var sid := str(b.get("shelter_id", ""))
	if sid.is_empty():
		return
	if _find_shelter_dict(sid).is_empty():
		b["shelter_id"] = ""
		var mm = b.get("_mem", {})
		if mm is Dictionary and mm.has("shelter"):
			(mm as Dictionary)["shelter"] = {}
		# Le tumbaron/desmontaron el refugio: lo aprende — el solar sigue
		# reclamado en shelter_pos y puede reconstruir, pero ya no es casa.
		var lost_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
		record_bot_event(int(b["bot_id"]), "shelter_lost", sid, "shelter", lost_pos, "le destruyeron el refugio")

# "bot_shelter_903_1794..." -> 903 ; 0 si el refugio no es de un bot.
func _shelter_owner_id(sh_id: String) -> int:
	if not sh_id.begins_with("bot_shelter_"):
		return 0
	var tail := sh_id.substr(12)
	var sep := tail.find("_")
	return int(tail.substr(0, sep)) if sep > 0 else 0

# Refugio del lider (bot o humano) mas cercano al bot: la base compartida del
# equipo. Los ids de refugio empiezan por bot_shelter_<id>_ / player_shelter_<id>.
func _team_leader_shelter_id(b: Dictionary) -> String:
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0 or world == null or not ("_built_shelters" in world):
		return ""
	var prefix := ("bot_shelter_%d" if is_bot_peer_id(lid) else "player_shelter_%d") % lid
	var proxy: Node3D = b["proxy"]
	var best := ""
	var best_d := INF
	for sh in world._built_shelters:
		if not (sh is Dictionary):
			continue
		var sid := str(sh.get("id", ""))
		if not sid.begins_with(prefix):
			continue
		var spos := _shelter_entry_pos(sh)
		var d := Vector2(proxy.global_position.x - spos.x, proxy.global_position.z - spos.z).length()
		if d < best_d:
			best_d = d
			best = sid
	return best

# Base unica del equipo: solo el lider tiene refugio. Al incorporarse, el
# miembro desmonta el suyo (recupera alijo y palos), suelta su solar y adopta
# el refugio del lider — descanso, alijo y hogar pasan a la base del equipo.
# Al salir del equipo suelta la referencia adoptada y vuelve a su propio solar.
func _sync_team_base(b: Dictionary) -> void:
	var my_id := int(b.get("bot_id", 0))
	var lid := int(b.get("team_leader_id", 0))
	var sid := str(b.get("shelter_id", ""))
	if lid > 0 and lid != my_id:
		_team_danger_tick(b)
		if _team_check_expulsion(b):
			return
	if lid > 0 and lid != my_id:
		if _shelter_owner_id(sid) == my_id:
			_team_dismantle_own_base(b)
			sid = ""
		var lsid := _team_leader_shelter_id(b)
		if not lsid.is_empty() and lsid != sid:
			b["shelter_id"] = lsid
			b["shelter_pos"] = _shelter_entry_pos(_find_shelter_dict(lsid))
		if is_bot_peer_id(lid) and bots.has(lid):
			var lc: Variant = bots[lid].get("camp_spot", Vector3.INF)
			if lc is Vector3 and lc != Vector3.INF:
				b["camp_spot"] = lc
	elif _shelter_owner_id(sid) != 0 and _shelter_owner_id(sid) != my_id:
		b["shelter_id"] = ""
		b["shelter_pos"] = Vector3.INF
		var back: Variant = b.get("_solo_camp_spot", Vector3.INF)
		if back is Vector3 and back != Vector3.INF:
			b["camp_spot"] = back
		b["_solo_camp_spot"] = null

# El miembro recoge su campamento al entrar en el equipo: salva el alijo a la
# mochila (el sobrante cae a sus pies), desmonta el refugio del mapa (vuelven
# los 11 palos) y libera su fogata y su solar reclamado.
func _team_dismantle_own_base(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var sid := str(b.get("shelter_id", ""))
	b["_solo_camp_spot"] = b.get("camp_spot", Vector3.INF)
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for cd in _get_shelter_contents(sid):
		if cd is Dictionary and not _bot_try_add_inventory_item(b, inv, cd):
			_bot_drop_to_ground(b, cd)
	proxy.set_meta("saved_inventory", inv)
	if not _find_shelter_dict(sid).is_empty():
		_bot_dismantle_shelter_exec(b, sid)
	b["shelter_id"] = ""
	b["shelter_pos"] = Vector3.INF
	b["campfire_id"] = ""
	var mm = b.get("_mem", {})
	if mm is Dictionary and (mm as Dictionary).has("shelter"):
		(mm as Dictionary)["shelter"] = {}
	record_bot_event(int(b["bot_id"]), "team_base_merge", sid, "shelter", proxy.global_position, "desmonta su refugio: la base pasa a ser la del lider")

# Traer una amenaza al grupo cuenta como ponerlo en peligro: el miembro llega
# perseguido (depredador/enemigo), en huida o escondido mientras esta junto al
# lider y el lider no esta amenazado — el peligro es suyo y lo trajo a casa.
# Un incidente cada 60 s como maximo; el contador vive en _mem y persiste.
func _team_danger_tick(b: Dictionary) -> void:
	var my_id := int(b["bot_id"])
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0 or lid == my_id or not bots.has(lid):
		return
	var now_ms := Time.get_ticks_msec()
	# Por defecto -120 s: el primer incidente cuenta aunque el servidor acabe
	# de arrancar (ticks_msec cuenta desde el arranque del motor, no del mundo).
	if now_ms - int(b.get("_team_danger_ms", -120000)) < 60000:
		return
	var lb: Dictionary = bots[lid]
	var lp: Node3D = lb.get("proxy")
	if lp == null or not is_instance_valid(lp):
		return
	var proxy: Node3D = b["proxy"]
	if proxy.global_position.distance_to(lp.global_position) > 40.0:
		return
	var my_threat := b.get("aggro_target") != null or _sensed_node(b, "_s_predator") != null \
		or float(b.get("flee_until", 0.0)) > 0.0 or float(b.get("hide_timer", 0.0)) > 0.0
	if not my_threat:
		return
	# Si el propio grupo ya esta bajo amenaza el peligro no lo trajo el.
	var leader_threat := lb.get("aggro_target") != null or _sensed_node(lb, "_s_predator") != null \
		or float(lb.get("flee_until", 0.0)) > 0.0
	if leader_threat:
		return
	b["_team_danger_ms"] = now_ms
	var mem := _ensure_bot_memory(my_id, b.get("cfg", {}))
	mem["team_danger_n"] = int(mem.get("team_danger_n", 0)) + 1
	record_bot_event(my_id, "team_danger", "bot_%d" % lid, _poi_kind_near(proxy.global_position), proxy.global_position,
		"trae peligro al grupo (%d)" % int(mem["team_danger_n"]))

# Un miembro que pone en peligro al grupo demasiadas veces (3+ agresiones
# registradas por cualquier compañero o 4+ incidentes de peligro traido al
# equipo) es expulsado: sale del equipo, pasa a faccion hostil, vive solo y
# los ex-compañeros le guardan hostilidad maxima — se atacan al cruzarse.
func _team_check_expulsion(b: Dictionary) -> bool:
	var my_id := int(b["bot_id"])
	for oid in _bot_team_ids(b):
		if oid == my_id or not bots.has(oid):
			continue
		var rels: Dictionary = ((bots[oid] as Dictionary).get("_mem", {}) as Dictionary).get("relationships", {})
		var rel = rels.get("bot_%d" % my_id)
		if rel is Dictionary and int((rel as Dictionary).get("attacked", 0)) >= 3:
			_team_expel(b, "traicion")
			return true
		# Negativas constantes de ayuda a compañeros: quien rechaza 3+ veces las
		# peticiones del grupo ya no aporta nada — el equipo tambien le echa.
		if rel is Dictionary and int((rel as Dictionary).get("refused", 0)) >= 3:
			_team_expel(b, "negado ayuda")
			return true
	if int(_ensure_bot_memory(my_id, b.get("cfg", {})).get("team_danger_n", 0)) >= 4:
		_team_expel(b, "peligro")
		return true
	return false

func _team_expel(b: Dictionary, reason: String = "traicion") -> void:
	var my_id := int(b["bot_id"])
	var mate_ids := _bot_team_ids(b) # captura antes de soltar la alianza
	b["team_leader_id"] = 0
	var proxy: Node3D = b["proxy"]
	proxy.set_meta("team_leader_id", 0)
	_set_bot_faction(b, "hostile")
	var now_ms := Time.get_ticks_msec()
	var my_rels: Dictionary = _ensure_bot_memory(my_id, b.get("cfg", {})).get("relationships", {})
	for oid in mate_ids:
		if oid == my_id:
			continue
		# El expulsado odia a su antiguo grupo: los ataca al verlos.
		var k := "bot_%d" % oid
		var r: Dictionary = my_rels.get(k, {"id": k, "name": str((bots.get(oid, {}) as Dictionary).get("name", k)), "trust": 0.0, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0})
		r["trust"] = -1.0
		r["hostility"] = 1.0
		r["fear"] = 0.0
		r["scar_t"] = now_ms
		my_rels[k] = r
		# Y el grupo le devuelve la misma hostilidad: fuera del equipo es un enemigo mas.
		if bots.has(oid):
			var ob: Dictionary = bots[oid]
			var orels: Dictionary = _ensure_bot_memory(oid, ob.get("cfg", {})).get("relationships", {})
			var ok := "bot_%d" % my_id
			var or_: Dictionary = orels.get(ok, {"id": ok, "name": str(b.get("name", ok)), "trust": 0.0, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0})
			or_["trust"] = -1.0
			or_["hostility"] = 1.0
			or_["fear"] = 0.0
			or_["scar_t"] = now_ms
			orels[ok] = or_
			_ensure_bot_memory(oid, ob.get("cfg", {}))["relationships"] = orels
	_ensure_bot_memory(my_id, b.get("cfg", {}))["relationships"] = my_rels
	record_bot_event(my_id, "team_expelled", "bot_%d" % int(mate_ids[0] if mate_ids.size() > 0 else 0), "team", proxy.global_position,
		"expulsado del equipo (%s): hostil" % reason)

# True solo si el bot esta dentro de un refugio REALMENTE construido (el dict
# del edificio sigue existiendo), no solo parado en su solar.
func _bot_at_own_built_shelter(b: Dictionary, pos: Vector3) -> bool:
	var sh_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
	if sh_pos == Vector3.INF or pos.distance_to(sh_pos) >= 3.4:
		return false
	var sid := str(b.get("shelter_id", ""))
	return not sid.is_empty() and not _find_shelter_dict(sid).is_empty()

func _is_bot_wolf_protected(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	var pos := proxy.global_position
	if _bot_at_own_built_shelter(b, pos):
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
	# Solo un refugio de verdad da cobijo: el solar reclamado sin edificio
	# (demolido o aun sin levantar) no es refugio — ahi no se acampa.
	if not str(b.get("shelter_id", "")).is_empty():
		var sh_pos: Vector3 = b.get("shelter_pos", Vector3.INF)
		if sh_pos != Vector3.INF:
			candidates.append(sh_pos)
	if world != null and "_lit_campfires" in world:
		for lc in world._lit_campfires:
			if _campfire_entry_alive(lc) and lc.get("pos") is Vector3:
				var fpos: Vector3 = lc["pos"]
				# Fogata cuyo anillo ya resulto inalcanzable: no atrae como
				# refugio termico hasta que el veto caduque y se reevalué.
				if _bot_fire_vetoed(b, fpos):
					continue
				# La meta es el borde del calor que al bot le toca: con frio
				# el anillo templado (calienta de verdad), si no el exterior
				# seguro — el centro del anillo lo cocinaba y el borde frio
				# no le daba nada.
				var fr := _bot_fire_warm_radius(b) if _bot_fire_band_update(b) == "warm" else 4.15
				var fdir := Vector2(cur.x - fpos.x, cur.z - fpos.z)
				var foff := fdir.normalized() * fr if fdir.length() > 0.05 else Vector2(fr, 0.0)
				candidates.append(Vector3(fpos.x + foff.x, fpos.y, fpos.z + foff.y))
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
		if d > best_d or _is_goal_blacklisted(b, cpos):
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
	if not bool(b.get("_s_has_wolf", false)) and _bot_raw_meat_count(proxy) < 3:
		return true
	if float(b["hunger"]) < 62.0 or not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0):
		return true
	return _bot_wants_pelts(b, proxy)

# Tras una baja se agenda el destripado: el bot camina hasta el cadáver y
# dedica unos segundos agachado, igual que la acción del jugador.
func _bot_start_gutting(b: Dictionary, animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal) or animal.get("_gutted") == true:
		return
	var proxy: Node3D = b["proxy"]
	if not _bot_wants_animal_loot(b, proxy):
		return
	if proxy.global_position.distance_to(animal.global_position) > 55.0:
		return
	b["gut_target"] = animal
	b["gut_t"] = 0.0

func _bot_harvest_dead_animal(b: Dictionary, animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal) or animal.get("_gutted") == true:
		return
	var proxy: Node3D = b["proxy"]
	if not _bot_has_can_opener(proxy):
		return
	var take_meat := float(b["hunger"]) < 62.0 or not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0) or (not bool(b.get("_s_has_wolf", false)) and _bot_raw_meat_count(proxy) < 3)
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
		if _bot_try_add_inventory_item(b, inv, meat):
			_ai_note_loot(b, meat_name, "food")
		else:
			_bot_drop_to_ground(b, meat) # no le cabe: queda junto a la presa
	if take_pelts:
		var hide := {"name": hide_name, "type": "resource", "weight": 0.65, "quantity": hide_qty, "use_value": 0.0}
		if _bot_try_add_inventory_item(b, inv, hide):
			_ai_note_loot(b, hide_name, "resource")
		else:
			_bot_drop_to_ground(b, hide)
	# Hueso y tendón: solo si los necesita ahora para cuerda, refugio, arco o armas de hueso
	if _bot_item_count(proxy, "Tendón") < 4 and (_bot_wants_craft_input(b, "Tendón") or _bot_wants_craft_input(b, "Cuerda") or (str(b["shelter_id"]).is_empty() and _bot_item_count(proxy, "Cuerda") < 1)):
		var tendon := {"name": "Tendón", "type": "resource", "weight": 0.06, "quantity": part_qty, "use_value": 0.0}
		if _bot_try_add_inventory_item(b, inv, tendon):
			_ai_note_loot(b, "Tendón", "resource")
		else:
			_bot_drop_to_ground(b, tendon)
	if _bot_item_count(proxy, "Hueso") < 4 and _bot_wants_craft_input(b, "Hueso"):
		var bone := {"name": "Hueso", "type": "resource", "weight": 0.18, "quantity": part_qty, "use_value": 0.0}
		if _bot_try_add_inventory_item(b, inv, bone):
			_ai_note_loot(b, "Hueso", "resource")
		else:
			_bot_drop_to_ground(b, bone)
	proxy.set_meta("saved_inventory", inv)
	var hg_mem: Dictionary = _ensure_bot_memory(int(b["bot_id"]), b.get("cfg", {}))
	var hg_st: Dictionary = hg_mem.get("stats", {})
	hg_st["animals_gutted"] = int(hg_st.get("animals_gutted", 0)) + 1
	hg_mem["stats"] = hg_st
	# collect_mode = true retira el cadáver y sincroniza animal_gutted sin
	# duplicar otro juego de pieles/carne en el suelo. La marca _gutted la
	# pone la propia _net_gut_animal antes de liberar el cuerpo y emitir el
	# RPC — marcarla aquí primero haría salir a la función por el guard de
	# "ya destazado" y los clientes seguirían viendo el cadáver muerto.
	if world != null and world.has_method("_net_gut_animal"):
		world._net_gut_animal(animal.name, int(b["bot_id"]), true)
	if is_instance_valid(animal) and not bool(animal.get("_gutted")):
		animal.set("_gutted", true)

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

# Baja de superviviente: el killer es un bot y la victima otro bot
# ("kills_bot") o un jugador humano ("kills_player") — lo que puntua el score.
func _credit_survivor_kill(killer_id: int, kind: String) -> void:
	if not is_bot_peer_id(killer_id) or not bots.has(killer_id):
		return
	var kb: Dictionary = bots[killer_id]
	var k_mem: Dictionary = _ensure_bot_memory(killer_id, kb.get("cfg", {}))
	var k_st: Dictionary = k_mem.get("stats", {})
	k_st[kind] = int(k_st.get(kind, 0)) + 1
	k_mem["stats"] = k_st

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
	if (_is_world_night() or _bot_is_exhausted(b) or _bot_is_freezing(b)) and hunger >= 40.0:
		return false
	var starved_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("starved", 0))
	var hunt_hunger_line := 62.0 + minf(15.0, float(starved_lessons) * 5.0)
	if hunger < hunt_hunger_line or not _bot_has_edible_food(proxy, hunger < 28.0):
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
		if _is_goal_blacklisted(b, w.global_position):
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
			_move_bot_towards(b, ppos, 2.8 if stalk_crouch else 6.2, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
		var los_hunt := _has_clear_shot(proxy.global_position, ppos)
		if _bot_fire_ready(b, prey, dist, los_hunt, delta, "m4" if weapon == "Fusil de asalto" else "sniper") 				and dist <= 45.0 and float(b["shoot_cooldown"]) <= 0.0:
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
			b["shoot_cooldown"] = 0.95 if weapon == "Fusil de asalto" else 1.65
			var dmg := 68.0 if weapon == "Fusil de asalto" else 145.0
			_bot_fire_rifle_at(b, prey, dmg, weapon)
		return

	if wkind == "bow" and dist > 4.5:
		b["is_aiming"] = true
		b["crouching"] = stalk_crouch
		proxy.set_meta("crouching", stalk_crouch)
		if dist > 22.0:
			_move_bot_towards(b, ppos, 2.7 if stalk_crouch else 6.2, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
		var los_bow := _has_clear_shot(proxy.global_position, ppos)
		if _bot_fire_ready(b, prey, dist, los_bow, delta, "bow") 				and dist <= 34.0 and float(b["shoot_cooldown"]) <= 0.0:
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
			b["shoot_cooldown"] = 1.55 if weapon == "Arco reforzado" else 1.9
			_bot_fire_bow(b, prey, weapon)
		return

	if wkind in ["thrown", "bola"] and dist > 4.5:
		b["is_aiming"] = true
		b["crouching"] = stalk_crouch
		proxy.set_meta("crouching", stalk_crouch)
		if dist > 16.0:
			_move_bot_towards(b, ppos, 2.7 if stalk_crouch else 6.2, delta, "walk" if stalk_crouch else "run")
		else:
			b["anim"] = "idle"
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
		var los_thr := _has_clear_shot(proxy.global_position, ppos)
		if _bot_fire_ready(b, prey, dist, los_thr, delta, "throw") 				and dist <= 22.0 and float(b["shoot_cooldown"]) <= 0.0:
			if to_prey.length_squared() > 0.001:
				b["rot"] = atan2(-to_prey.x, -to_prey.z)
				proxy.rotation.y = float(b["rot"])
			b["shoot_cooldown"] = 2.6 if wkind == "bola" else 2.1
			_bot_fire_thrown(b, prey, weapon, wkind == "bola")
		return

	b["is_aiming"] = false
	var melee_reach := 4.0 if weapon in ["Lanza", "Lanza de hueso", "Palo afilado", "Hacha"] else 3.5
	if dist <= melee_reach:
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		if to_prey.length_squared() > 0.001:
			b["rot"] = atan2(-to_prey.x, -to_prey.z)
			proxy.rotation.y = float(b["rot"])
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
		_move_bot_towards(b, ppos, 6.5, delta, "run")

# Comidas ya acreditadas por este bot en un lobo salvaje (0 si ninguna).
func _bot_tame_progress(b: Dictionary, wolf: Node3D) -> int:
	if wolf == null or not is_instance_valid(wolf):
		return 0
	var tp = wolf.get("_tame_progress")
	return int((tp as Dictionary).get(str(b["bot_id"]), 0)) if tp is Dictionary else 0

# El lobo ha dejado de tantear y va a por el bot: lo persigue/ataca o le
# acaba de morder. Desde aqui es un depredador como cualquier otro.
func _bot_wolf_is_aggressive(b: Dictionary, wolf: Node3D) -> bool:
	if wolf == null or not is_instance_valid(wolf):
		return false
	if Time.get_ticks_msec() - int(b.get("_wolf_bite_msec", -999999)) < 6000:
		return true
	return str(wolf.get("_state")) in ["chase_player", "attack"] and wolf.get("_player") == b.get("proxy")

# Motivos para aparcar la doma: estan atacando al bot o hay una amenaza
# real encima. Con histeresis (_tame_pause_until) para no alternar entre
# soltar cebo y pelear cada medio segundo.
const BOT_TAME_RESUME_SEC := 8.0

func _bot_tame_interrupted(b: Dictionary, wolf: Node3D) -> bool:
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var threat := false
	var aggro = b.get("aggro_target")
	if aggro != null and is_instance_valid(aggro) and aggro != wolf:
		threat = true
	elif _sensed_node(b, "_s_foe") != null:
		threat = true
	elif Time.get_ticks_msec() - int(b.get("_last_attacker_msec", -999999)) < 6000:
		threat = true # recibio daño de alguien hace nada
	elif float(b.get("flee_until", 0.0)) > 0.0 or float(b.get("hide_timer", 0.0)) > 0.0:
		threat = true
	elif _bot_wolf_is_aggressive(b, wolf):
		threat = true
	else:
		var pred := _sensed_node(b, "_s_predator")
		threat = pred != null and pred != wolf
	if threat:
		if now_s >= float(b.get("_tame_pause_until", 0.0)):
			record_bot_event(int(b["bot_id"]), "tame_interrupted", "wolf", _poi_kind_near(wolf.global_position), wolf.global_position, "amenaza: doma aparcada")
		b["_tame_pause_until"] = now_s + BOT_TAME_RESUME_SEC
		return true
	return now_s < float(b.get("_tame_pause_until", 0.0))

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

func _bot_tamed_wolf(b: Dictionary) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var key := str(b["bot_id"])
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if is_instance_valid(w) and w.get("_is_dead") != true and str(w.get("animal_type")) == "wolf" and str(w.get("tamed_to")) == key:
			return w as Node3D
	return null

func _bot_has_tamed_wolf(b: Dictionary) -> bool:
	return _bot_tamed_wolf(b) != null

# Ordenes al lobo domesticado con el mismo mecanismo que usa el jugador en su
# menu [F]: apply_command("follow"/"stay") — viaja pegado al bot mientras
# trabaja fuera, y guarda el campamento mientras el bot descansa o duerme en
# su base. El ataque/defensa ya lo cubre _command_bot_wolf_against
# (notify_threat) al entrar en combate.
func _sync_bot_wolf_orders(b: Dictionary) -> void:
	var wolf := _bot_tamed_wolf(b)
	if wolf == null or not wolf.has_method("apply_command"):
		return
	var proxy: Node3D = b["proxy"]
	var resting_home := bool(b.get("sleeping", false)) or float(b.get("hide_timer", 0.0)) > 0.0
	if not resting_home:
		var camp: Vector3 = b.get("camp_spot", Vector3.INF)
		var sh: Vector3 = b.get("shelter_pos", Vector3.INF)
		var home: Vector3 = sh if sh != Vector3.INF else camp
		if home != Vector3.INF and proxy.global_position.distance_to(home) <= 14.0:
			var act := str(b.get("_act", ""))
			resting_home = act in ["rest", "shelter", "stash", "camo", "build", "sleep", "idle"] or bool(b.get("sitting", false))
	var want := "stay" if resting_home else "follow"
	if str(b.get("_wolf_last_order", "")) == want:
		return
	b["_wolf_last_order"] = want
	wolf.apply_command(want)
	var mem: Dictionary = b.get("_mem", {})
	record_bot_event(int(b["bot_id"]), "wolf_order", str(wolf.name), _poi_kind_near(proxy.global_position), proxy.global_position,
		"orden: %s" % ("guardar el campamento" if want == "stay" else "seguirme"))
	if mem is Dictionary and not bool(mem.get("milestones", {}).get("wolf_ordered", false)):
		_record_milestone(int(b["bot_id"]), "wolf_ordered")

func _note_bot_wolf_life(b: Dictionary, has_wolf: bool) -> void:
	var had := bool(b.get("_had_wolf", false))
	if has_wolf == had:
		return
	b["_had_wolf"] = has_wolf
	var proxy: Node3D = b["proxy"]
	if has_wolf:
		var wolf := _bot_tamed_wolf(b)
		_record_milestone(int(b["bot_id"]), "wolf_tamed")
		record_bot_event(int(b["bot_id"]), "tame", str(wolf.name) if wolf != null else "lobo", _poi_kind_near(proxy.global_position), proxy.global_position, "domestico un lobo fiel")
	elif not bool(b.get("dead", false)):
		record_bot_event(int(b["bot_id"]), "wolf_lost", "lobo", _poi_kind_near(proxy.global_position), proxy.global_position, "perdio a su lobo")
		b["_wolf_last_order"] = ""

# Vida sedentaria: la base propia cuenta cuando el refugio esta levantado
# (shelter_id + posicion valida). Con solo el solar reclamado aun hay que
# salir a por materiales — eso lo cubren los pasos de mats/build anteriores.
func _bot_has_own_base(b: Dictionary) -> bool:
	return b.get("shelter_pos", Vector3.INF) != Vector3.INF and not str(b.get("shelter_id", "")).is_empty()

# Motivos legitimos para salir de la base: provisiones bajas, encargos de
# equipo, directivas tacticas de la IA, reencuentro social pendiente o la
# necesidad de equipo basico (sin arma ni filo encima ni en el alijo).
func _exploration_region(pos: Vector3) -> String:
	return "%d:%d" % [clampi(int(floor((pos.x+480.0)/320.0)),0,2), clampi(int(floor((pos.z+500.0)/280.0)),0,4)]

func _bot_can_expedition(b: Dictionary) -> bool:
	if _world_day_phase() not in ["dawn", "day"] or _bot_is_freezing(b):
		return false
	if float(b.get("health",100.0)) < 65.0 or _bot_energy(b) < 55.0 or float(b.get("hunger",100.0)) < 65.0 or float(b.get("thirst",100.0)) < 65.0:
		return false
	var directive := _ai_active_directive(b)
	return str(directive.get("action", "")) not in ["rest", "return_home", "fortify_camp", "avoid_zone"]

func _bot_needs_outing(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if float(b["hunger"]) < 55.0 or float(b["thirst"]) < 55.0:
		return true
	if not _bot_has_edible_food(proxy, false) and not _bot_has_drink(proxy):
		return true
	# Leccion de supervivencia: quien se murio de hambre no sale sin comida;
	# quien se murio de sed no sale sin su reserva de agua.
	var dl_out: Dictionary = b.get("_mem", {}).get("death_lessons", {})
	if int(dl_out.get("starved", 0)) > 0 and not _bot_has_edible_food(proxy, false):
		return true
	if int(dl_out.get("dehydrated", 0)) > 0 and not _bot_has_drink(proxy):
		return true
	if _best_weapon_name(proxy).is_empty() and not _own_shelter_has_needed_item(b):
		return true
	if bool(b.get("equip_mission", false)) or int(b.get("_meet_id", 0)) > 0:
		return true
	var dir := _ai_active_directive(b)
	if str(dir.get("action", "")) in ["explore", "scavenge", "hunt", "forage", "seek_ally", "avoid_zone"]:
		return true
	return false

# Memoria tactica del ultimo contacto con un enemigo: posicion, instante,
# fuente (seen = visto/sufrido, heard = oido, told = aviso de aliado) y
# fiabilidad. Nunca guarda la posicion viva del enemigo — solo su ultima
# pista y cuanto vale.
# Registra la ultima pista sobre un enemigo con su procedencia. Solo "seen"
# es posicion exacta: "heard" lleva el error de localizacion del oido (crece
# con la distancia) y "told" el de un relato. La fiabilidad de lo oido baja
# al alejarse; la edad la aplica quien busca despues.
func _ai_note_foe_intel(b: Dictionary, foe: Node3D, pos: Vector3, src: String, told_conf: float = -1.0, age_msec: int = 0) -> void:
	var conf := 1.0
	var err := 0.0
	if src == "heard":
		var proxy = b.get("proxy")
		var hd: float = proxy.global_position.distance_to(pos) if proxy != null and is_instance_valid(proxy) else 20.0
		conf = clampf(0.68 - hd * 0.0025, 0.30, 0.65)
		err = clampf(hd * 0.18, 3.0, 22.0)
	elif src == "told":
		# Un aviso hereda la fiabilidad de quien avisa (rebajada): nadie
		# cuenta mas de lo que sabe. Sin dato, la de un grito generico.
		conf = clampf(told_conf, 0.15, 0.8) if told_conf >= 0.0 else 0.55
		err = 7.0
	var noted := pos
	if err > 0.0:
		noted += Vector3(randf_range(-err, err), 0.0, randf_range(-err, err))
	var key := _actor_persist_key(_peer_id_for_actor(foe)) if foe != null else ""
	# Una pista reciente de mas confianza sobre el mismo enemigo no se rebaja
	# (la victima vio/sintio al agresor: el relevo del equipo no la degrada).
	var prev: Dictionary = b.get("_foe_mem", {})
	if not prev.is_empty() and str(prev.get("key", "")) == key \
			and Time.get_ticks_msec() - int(prev.get("t", 0)) < 4000 \
			and float(prev.get("conf", 0.0)) >= conf:
		return
	b["_last_foe_pos"] = noted
	# age_msec: antiguedad de la pista en origen — un aviso sobre algo visto
	# hace 40 s llega ya con 40 s de viejo, no como recien observado.
	b["_foe_mem"] = {"pos": noted, "t": Time.get_ticks_msec() - maxi(0, age_msec), "src": src, "conf": conf, "key": key}

# Lo que un compañero puede contar de un enemigo: SU ultima posicion
# conocida, con su antiguedad y su fiabilidad — nunca la posicion viva del
# nodo. Sin ficha propia sobre ese enemigo no hay nada que transmitir.
func _bot_foe_report(b: Dictionary, foe: Node3D) -> Dictionary:
	var fm: Dictionary = b.get("_foe_mem", {})
	if fm.is_empty() or foe == null or not is_instance_valid(foe):
		return {}
	if str(fm.get("key", "")) != _actor_persist_key(_peer_id_for_actor(foe)):
		return {}
	var pos: Vector3 = fm.get("pos", Vector3.INF)
	var age := Time.get_ticks_msec() - int(fm.get("t", 0))
	if pos == Vector3.INF or age > 120000:
		return {}
	return {"pos": pos, "age_msec": age, "conf": float(fm.get("conf", 0.5)) * 0.8}

# Aviso real entre compañeros: quien percibe a un enemigo se lo grita a los
# suyos al alcance de la voz. Sustituye a la vieja "telepatia" que media la
# distancia al enemigo desde el lider: ahora cada bot detecta con sus
# sentidos y la defensa del equipo viaja como informacion comunicada.
const BOT_WARN_SHOUT_RANGE := 45.0
const BOT_WARN_CD_MSEC := 2500

func _bot_warn_team_of_foe(b: Dictionary, foe: Node3D) -> int:
	var now := Time.get_ticks_msec()
	if now - int(b.get("_warn_foe_msec", -999999)) < BOT_WARN_CD_MSEC:
		return 0
	var report := _bot_foe_report(b, foe)
	if report.is_empty():
		return 0
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var warned := 0
	for tid in _bot_team_ids(b):
		if int(tid) == my_id or not bots.has(tid):
			continue
		var tb: Dictionary = bots[tid]
		var tp: Node3D = tb.get("proxy")
		if tp == null or not is_instance_valid(tp) or bool(tp.get_meta("proxy_dead", false)):
			continue
		if proxy.global_position.distance_to(tp.global_position) > BOT_WARN_SHOUT_RANGE:
			continue
		if tb.get("_s_foe") == foe:
			continue # ya lo percibe por si mismo
		_ai_note_foe_intel(tb, foe, report["pos"], "told", float(report["conf"]), int(report["age_msec"]))
		var cur_aggro = tb.get("aggro_target")
		if cur_aggro == null or not is_instance_valid(cur_aggro):
			tb["aggro_target"] = foe
			tb["aggro_timer"] = 20.0
			tb["sense_t"] = 0.0
		tb["sitting"] = false
		tb["sleeping"] = false
		warned += 1
	if warned > 0:
		b["_warn_foe_msec"] = now
	return warned

# Refresco del escaneo de sentidos: la posicion exacta solo la fija la VISTA
# (linea de vision real). El oido mantiene el aggro pero NO reescribe la pista
# — eso lo hace el evento sonoro real con su sound_pos. Escanear cada 0.2 s al
# enemigo oido con su posicion viva seria un radar a traves de las paredes.
func _ai_note_foe_scan(b: Dictionary, foe: Node3D) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var proxy: Node3D = b.get("proxy")
	if proxy != null and is_instance_valid(proxy) \
			and _has_clear_shot(proxy.global_position, foe.global_position):
		_ai_note_foe_intel(b, foe, foe.global_position, "seen")

# Version JSON de la pista de enemigo para el panel de diagnostico.
func _foe_intel_snapshot(b: Dictionary) -> Dictionary:
	var fm: Dictionary = b.get("_foe_mem", {})
	if fm.is_empty():
		return {}
	var fp: Vector3 = fm.get("pos", Vector3.INF)
	var age_s := float(Time.get_ticks_msec() - int(fm.get("t", 0))) / 1000.0
	var conf0 := float(fm.get("conf", 1.0))
	return {"pos": [snappedf(fp.x, 0.1), snappedf(fp.y, 0.1), snappedf(fp.z, 0.1)] if fp != Vector3.INF else [],
		"age_s": snappedf(age_s, 0.1),
		"src": str(fm.get("src", "")), "conf": conf0,
		"conf_now": snappedf(conf0 * clampf(1.0 - age_s / 120.0, 0.0, 1.0), 0.01),
		"key": str(fm.get("key", ""))}

# Vetos vigentes legibles para el monitor (max_n entradas, ordenadas por
# antiguedad): objetivo, causa, edad y lo que le queda al veto. label_key
# es el campo legible del registro ("act" en failed_goals; la clave en
# unreachable_pois); fixed_ttl fija la caducidad cuando el registro no la lleva.
func _ai_veto_snapshot(entries: Dictionary, label_key: String, max_n := 6, fixed_ttl := 0.0) -> Array:
	var now_u := Time.get_unix_time_from_system()
	var out: Array = []
	for sig in entries.keys():
		var e = entries[sig]
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		var age := now_u - float(ed.get("t", 0.0))
		var ttl := fixed_ttl if fixed_ttl > 0.0 else _ai_fail_entry_ttl(ed)
		if age >= ttl or age < 0.0:
			continue
		out.append({"goal": str(ed.get(label_key, sig)) if not label_key.is_empty() else str(sig),
			"cause": str(ed.get("cause", "?")), "age_min": int(age / 60.0),
			"left_min": int((ttl - age) / 60.0), "zone": ed.get("zone", ed.get("poi", sig))})
	out.sort_custom(func(a: Dictionary, z: Dictionary) -> bool: return int(a.get("age_min", 0)) < int(z.get("age_min", 0)))
	return out.slice(0, max_n)

# Nemesis: devuelve la ficha del verdugo si el enemigo sensado ya le mato
# antes (memoria persistente 'killers'). Aprender de las muertes es, ante
# todo, reconocer a quien te las causa.
func _foe_nemesis(b: Dictionary, foe: Node3D) -> Dictionary:
	var killers: Dictionary = b.get("_mem", {}).get("killers", {})
	if killers.is_empty() or foe == null:
		return {}
	var pid := _peer_id_for_actor(foe)
	if pid <= 0:
		return {}
	var kkey := _actor_persist_key(pid)
	if not (killers.get(kkey) is Dictionary):
		return {}
	var kr: Dictionary = (killers[kkey] as Dictionary).duplicate()
	kr["key"] = kkey
	return kr

# El rival lleva en mano un arma de fuego/arco — contra eso cargar en
# linea recta es repetir la muerte anterior.
func _actor_holds_ranged(node: Node3D) -> bool:
	var held := str(node.get_meta("saved_held_item", "")) if node != null else ""
	return held.begins_with("Fusil") or held.begins_with("Rifle") or held.begins_with("Pistola") or held.begins_with("Arco") or held.begins_with("Ballesta") or held == "Boleadoras"

# Retirada ante la nemesis: aprendio a no repetir el enfrentamiento. Se
# parapeta en su refugio si existe; si no, huye en zigzag lejos del verdugo.
# Small local search, cached per bot: cover must block the shooter's view
# and be reachable by a clear ground segment, not merely be a named shelter.
func _learn_practical_skill(b: Dictionary, skill: String, reason: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return
	var experience: Dictionary = mem.get("experience", {})
	var level := int(experience.get(skill, 0))
	if level >= 3:
		return
	experience[skill] = level + 1
	mem["experience"] = experience
	var proxy: Node3D = b.get("proxy")
	var pos := proxy.global_position if is_instance_valid(proxy) else Vector3.ZERO
	record_bot_event(int(b["bot_id"]), "learned", skill, _poi_kind_near(pos), pos, reason)

func _cover_learning_tick(b: Dictionary, delta: float, protected: bool) -> void:
	var hit := int(b.get("_last_attacker_msec", -999999))
	if not protected or Time.get_ticks_msec()-hit > 5000:
		b["_cover_training_hold"] = 0.0
		return
	if int(b.get("_cover_training_hit", -1)) != hit:
		b["_cover_training_hit"] = hit
		b["_cover_training_hold"] = 0.0
	b["_cover_training_hold"] = float(b.get("_cover_training_hold", 0.0))+delta
	# Two seconds actually sheltered after a hit, at most once per minute.
	if float(b["_cover_training_hold"]) >= 2.0 and Time.get_ticks_msec()-int(b.get("_cover_learned_at", -60000)) >= 60000:
		b["_cover_learned_at"] = Time.get_ticks_msec()
		_learn_practical_skill(b, "cover", "Sobrevivió a disparos protegido: buscará cobertura antes cuando esté herido")

func _find_ballistic_cover(b: Dictionary, foe: Node3D) -> Vector3:
	var proxy: Node3D = b["proxy"]
	var origin := proxy.global_position
	var away := origin - foe.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > .01 else Vector3.RIGHT
	for radius in [4.0, 8.0, 12.0]:
		for angle in [0.0, .6, -.6, 1.2, -1.2, 1.8, -1.8, PI]:
			var point: Vector3 = origin + away.rotated(Vector3.UP, angle) * radius
			point.y = _ground_y(point.x, point.z, origin.y)
			if absf(point.y-origin.y) > 1.0 or _is_goal_blacklisted(b, point):
				continue
			if world != null and world.has_method("get_river_depth_at") and float(world.get_river_depth_at(point)) > WADE_DEPTH:
				continue
			if _is_step_blocked(origin, point) or _has_clear_shot(foe.global_position, point):
				continue
			return point
	return Vector3.INF

func _bot_seek_ballistic_cover(b: Dictionary, foe: Node3D, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	b["_cover_scan_t"] = maxf(0.0, float(b.get("_cover_scan_t", 0.0))-delta)
	b["sitting"] = false
	b["sleeping"] = false
	b["is_aiming"] = false
	var goal: Vector3 = b.get("_cover_goal", Vector3.INF)
	if int(b.get("_cover_foe", 0)) != foe.get_instance_id() or (goal != Vector3.INF and _is_goal_blacklisted(b, goal)):
		goal = Vector3.INF
		b["_cover_goal"] = goal
		b["_cover_scan_t"] = 0.0
	b["_cover_foe"] = foe.get_instance_id()
	if float(b["_cover_scan_t"]) <= 0.0:
		b["_cover_scan_t"] = 1.5
		if goal == Vector3.INF or _has_clear_shot(foe.global_position, goal) or _is_step_blocked(proxy.global_position, goal):
			goal = _find_ballistic_cover(b, foe)
			b["_cover_goal"] = goal
	if goal != Vector3.INF:
		if proxy.global_position.distance_to(goal) > .8:
			_cover_learning_tick(b, delta, false)
			b["crouching"] = false
			proxy.set_meta("crouching", false)
			_move_bot_towards(b, goal, 6.4, delta, "run")
			return true
		# Check the actual position too: arriving near cover is not enough.
		if not _has_clear_shot(foe.global_position, proxy.global_position):
			_cover_learning_tick(b, delta, true)
			b["crouching"] = true
			proxy.set_meta("crouching", true)
			_stop_bot_motion(b)
			return true
		b["_cover_goal"] = Vector3.INF
	_cover_learning_tick(b, delta, false)
	# No solid cover nearby: keep moving instead of crouching in the open.
	b["crouching"] = false
	proxy.set_meta("crouching", false)
	var away := proxy.global_position - foe.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > .01 else Vector3.RIGHT
	var side := Vector3(-away.z, 0, away.x)
	var sign_side := 1.0 if int(Time.get_ticks_msec()/900 + int(b["bot_id"])) % 2 == 0 else -1.0
	_move_bot_towards(b, proxy.global_position + (away+side*sign_side*.8).normalized()*6.0, 6.4, delta, "run")
	return true

func _bot_avoid_nemesis(b: Dictionary, foe: Node3D, nem_name: String, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["is_aiming"] = false
	var sh: Vector3 = b["shelter_pos"]
	if sh != Vector3.INF:
		b["hide_timer"] = 24.0
		_move_bot_towards(b, sh, 6.0, delta, "run")
		if proxy.global_position.distance_to(sh) < 1.8:
			b["crouching"] = true
			b["sitting"] = true
			b["anim"] = "sit"
	else:
		b["flee_until"] = 14.0
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		var away := proxy.global_position - foe.global_position
		away.y = 0.0
		var away_dir := away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
		b["strafe_timer"] = float(b["strafe_timer"]) + delta
		if float(b["strafe_timer"]) > 1.2:
			b["strafe_dir"] = -float(b["strafe_dir"])
			b["strafe_timer"] = 0.0
		var side := Vector3(-away_dir.z, 0.0, away_dir.x)
		_move_bot_towards(b, proxy.global_position + (away_dir + side * float(b["strafe_dir"]) * 0.6).normalized() * 8.0, 6.0, delta, "run")
	if float(b.get("_nemesis_ev_t", 0.0)) <= 0.0:
		b["_nemesis_ev_t"] = 60.0
		record_bot_event(int(b["bot_id"]), "evade_nemesis", nem_name, _poi_kind_near(proxy.global_position), proxy.global_position,
			"evita a %s, que ya le mato" % nem_name)

func _perform_wolf_taming_step(b: Dictionary, wolf: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var wpos := wolf.global_position
	var d := proxy.global_position.distance_to(wpos)
	var to_wolf := wpos - proxy.global_position
	to_wolf.y = 0.0
	var meat_name := _first_raw_meat_name(proxy)
	if not meat_name.is_empty():
		b["held_item"] = meat_name
		b["has_rifle"] = false
		proxy.set_meta("saved_held_item", meat_name)
	# Mientras espera a que el lobo se coma el cebo soltado, mantenerse a 7..12 m
	# (WildlifeController exige <15 m al alimentador para acreditar la toma).
	if float(b.get("tame_cooldown", 0.0)) > 0.0 or meat_name.is_empty():
		if d < 6.0 and to_wolf.length_squared() > 0.01:
			_move_bot_towards(b, proxy.global_position - to_wolf.normalized() * 3.0, 3.2, delta, "walk")
		elif d > 12.5:
			_move_bot_towards(b, wpos, 3.2, delta, "walk")
		else:
			if to_wolf.length_squared() > 0.001:
				b["rot"] = atan2(-to_wolf.x, -to_wolf.z)
				proxy.rotation.y = float(b["rot"])
			b["anim"] = "idle"
		return
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
		b["_tame_wait_t"] = 11.0
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
	# Fauna: la carrera se oye lejos (una carga de lobo avisa antes de verse),
	# el paso solo cerca y el acecho apenas nada — mismo criterio que con
	# humanos y bots: lo que se mueve hace ruido.
	if target.is_in_group("wildlife"):
		var wanim := str(target.get("current_anim_keyword")).to_lower()
		if wanim.find("run") >= 0 or wanim.find("chase") >= 0 or wanim.find("trot") >= 0 or wanim.find("gallop") >= 0:
			if dist <= 30.0:
				return true
		elif wanim.find("walk") >= 0:
			if dist <= 14.0:
				return true
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
		var heard_actor := int(b.get("last_heard_actor", 0))
		# A known shooter's noise must not reveal a different silent actor.
		if heard_actor > 0 and _peer_id_for_actor(target) != heard_actor:
			return false
		if hpos != Vector3.INF and target.global_position.distance_to(hpos) <= 18.0:
			return true
	return false

func notify_sound_event(actor_id: int, sound_pos: Vector3, kind: String, radius: float = 120.0) -> void:
	if world == null:
		return
	var _cpt := Time.get_ticks_usec()
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
			var my_faction := str(b.get("faction", "hostile"))
			var same_team := actor_id > 0 and (actor_id in _bot_team_ids(b))
			var shooter_faction := str(bots[actor_id].get("faction", "hostile")) if bots.has(actor_id) else "friendly"
			var shooter_hostile := not same_team and (shooter_faction != my_faction or (actor_id <= 0 and my_faction == "hostile"))
			if not shooter_hostile and not same_team and actor_id > 0:
				var rel := get_bot_relationship(int(bid), _actor_persist_key(actor_id))
				var host_thr := 0.58 if shooter_faction == my_faction else 0.25
				shooter_hostile = float(rel.get("hostility", 0.0)) > host_thr and (shooter_faction != my_faction or int(rel.get("attacked", 0)) > 0)
			var has_gun := _best_weapon_name(proxy) in ["Fusil de asalto", "Rifle francotirador"]
			var pers := _get_bot_personality(b)
			var brave := float(pers.get("bravery", 0.5))
			if shooter_hostile:
				if (has_gun or (my_faction == "hostile" and brave >= 0.45)) and float(b.get("health", 100.0)) >= 55.0:
					if actor_node != null and is_instance_valid(actor_node) and d <= 130.0:
						b["aggro_target"] = actor_node
						b["aggro_timer"] = 14.0
						# Localizo al tirador solo por el oido: la pista es
						# donde sono el disparo, no donde esta el ahora.
						_ai_note_foe_intel(b, actor_node, sound_pos, "heard")
					elif b.get("explore_target", Vector3.INF) == Vector3.INF or d <= 140.0:
						b["explore_target"] = sound_pos
				elif d <= 95.0:
					b["flee_until"] = maxf(float(b.get("flee_until", 0.0)), 10.0)
					record_zone_hazard(int(bid), sound_pos, "gunshot", 0.30, true)
	if CombatProf.enabled: CombatProf.mark("bot.notify_sound", _cpt)

# Zonas con puestos elevados (ciudad con azoteas/Torre del Reloj y bases
# militares con torre de vigilancia): alli un superviviente prudente vigila
# los techos — los francotiradores se ven de lejos pero hay que mirar arriba.
func _bot_in_watch_zone(pos: Vector3) -> bool:
	for p in _explore_pois():
		if str((p as Dictionary).get("kind", "")) in ["city", "military", "tower"]:
			var pp: Vector3 = (p as Dictionary)["pos"]
			if Vector2(pos.x - pp.x, pos.z - pp.z).length() <= 80.0:
				return true
	return false

# Hostilidad compartida con _find_combat_foe (misma regla de faccion/tregua):
# quien dispara desde un tejado es enemigo igual que quien lo hace a ras.
func _bot_considers_foe(b: Dictionary, p3: Node3D) -> bool:
	if p3 == b.get("proxy") or not is_instance_valid(p3):
		return false
	if bool(p3.get_meta("proxy_dead", false)) or not bool(p3.get_meta("has_real_pos", false)):
		return false
	var pid := _peer_id_for_actor(p3)
	if pid > 0 and int(b.get("_truce_peer", 0)) == pid and float(b.get("_truce_t", 0.0)) > 0.0:
		return false
	var is_bot := bool(p3.get_meta("is_ai_bot", false)) or is_bot_peer_id(pid)
	if str(b["faction"]) == "hostile":
		# Un hostil no ataca a otro hostil salvo rencor personal maximo.
		if is_bot and str(p3.get_meta("bot_faction", "")) == "hostile":
			return pid > 0 and float(get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid)).get("hostility", 0.0)) >= 0.9
		return true
	# Aliado/cooperativo: solo los bots de faccion hostil son enemigos.
	return is_bot and str(p3.get_meta("bot_faction", "")) == "hostile"

# Ojo en los techos: un tirador apostado en altura se ve desde mucho mas lejos
# que uno a ras de suelo (esta expuesto), asi que el radio de vigilancia es
# mayor que la vista normal — pero exige desnivel real y linea de tiro limpia.
const BOT_ROOF_MIN_ELEV := 5.5
const BOT_ROOF_WATCH_RANGE := 75.0
const BOT_ROOF_WARY_MSEC := 20000

func _find_rooftop_foe(b: Dictionary, radius: float = BOT_ROOF_WATCH_RANGE) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	var best: Node3D = null
	var best_d := radius
	for p in world.get_tree().get_nodes_in_group("net_player_proxy"):
		if not (p is Node3D):
			continue
		var p3 := p as Node3D
		if not _bot_considers_foe(b, p3):
			continue
		var pp := p3.global_position
		if pp.y - cur.y < BOT_ROOF_MIN_ELEV:
			continue
		var d := cur.distance_to(pp)
		if d >= best_d:
			continue
		if not _has_clear_shot(cur, pp):
			continue
		best_d = d
		best = p3
	# En un host no dedicado el jugador local no esta en net_player_proxy.
	var local_p = world.get("player")
	if local_p is Node3D and is_instance_valid(local_p) and _bot_considers_foe(b, local_p as Node3D):
		var lp: Vector3 = (local_p as Node3D).global_position
		var dl := cur.distance_to(lp)
		if lp.y - cur.y >= BOT_ROOF_MIN_ELEV and dl < best_d and _has_clear_shot(cur, lp):
			best_d = dl
			best = local_p as Node3D
	return best

# Cautela aprendida: una muerte violenta propia cerca (o el riesgo acumulado
# de la zona en memoria — los compañeros lo comparten) marca el lugar como
# peligroso. Devuelve el ancla de la amenaza recordada o INF si la zona esta
# tranquila. El botin bueno repetido va apagando la alarma.
func _bot_survivor_combat_cause(cause: String) -> bool:
	return cause in ["rifle", "m4", "melee", "combat", "bola", "arco", "arco_head", "arco_madera", "arrow", "lanza", "spear"]

func _bot_learned_risk_at(pos: Vector3, bot_id: int) -> Vector3:
	var mem: Dictionary = _memory.get(bot_id, {})
	var score := 0.0
	var anchor := Vector3.INF
	for s in mem.get("death_spots", []):
		if not (s is Dictionary):
			continue
		# Solo cuentan muertes a manos de otro superviviente: un lobo o el
		# hambre no implican francotirador.
		if not _bot_survivor_combat_cause(str(s.get("cause", ""))):
			continue
		var sp := Vector3(float(s.get("x", 0.0)), float(s.get("y", 0.0)), float(s.get("z", 0.0)))
		if Vector2(pos.x - sp.x, pos.z - sp.z).length() <= 60.0:
			var w := 0.55 * clampi(int(s.get("count", 1)), 1, 3)
			if w > score:
				score = w
				anchor = sp
	var known: Dictionary = mem.get("known_locations", {})
	var rk_max := 0.0
	var rk_pos := Vector3.INF
	for lid in known.keys():
		var le = known[lid]
		if not (le is Dictionary):
			continue
		var rk := float(le.get("combat_risk", 0.0))
		if rk <= rk_max or rk < 1.1:
			continue
		var lp = le.get("pos", null)
		if not (lp is Array) or (lp as Array).size() < 3:
			continue
		var lpos := Vector3(float((lp as Array)[0]), float((lp as Array)[1]), float((lp as Array)[2]))
		if Vector2(pos.x - lpos.x, pos.z - lpos.z).length() <= 55.0:
			rk_max = rk
			rk_pos = lpos
	if rk_max > 0.0:
		score += rk_max * 0.22
		if anchor == Vector3.INF:
			anchor = rk_pos
	var zy: Dictionary = mem.get("zone_yield", {})
	var zk: Dictionary = zy.get(_poi_kind_near(pos), {})
	score -= float(zk.get("good", 0)) * 0.22
	return anchor if score > 0.5 else Vector3.INF

func _bot_learned_wary(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if not is_instance_valid(proxy):
		return false
	return _bot_learned_risk_at(proxy.global_position, int(b["bot_id"])) != Vector3.INF

func _bot_roof_wary(b: Dictionary) -> bool:
	return Time.get_ticks_msec() - int(b.get("_roof_threat_msec", -999999)) < BOT_ROOF_WARY_MSEC \
		or _bot_learned_wary(b)

func _find_combat_foe(b: Dictionary) -> Node3D:
	if world == null or world.get_tree() == null:
		return null
	var proxy: Node3D = b["proxy"]
	var aggro: Node3D = b.get("aggro_target")
	if aggro != null and is_instance_valid(aggro) and not bool(aggro.get_meta("proxy_dead", false)) and aggro.get("is_dead") != true:
		var d_aggro := proxy.global_position.distance_to(aggro.global_position)
		if d_aggro < 130.0:
			# El aggro no es un radar: sigue al enemigo solo mientras lo ve u
			# oye. Si lo pierde, recuerda DONDE desaparecio y cuanto buscarlo.
			if _can_bot_hear_actor(b, aggro, d_aggro) or _has_clear_shot(proxy.global_position, aggro.global_position):
				return aggro
			if int(b.get("_lost_foe_until_msec", 0)) <= 0:
				var pers_lf := _get_bot_personality(b)
				var persist := clampf(6.0 + float(pers_lf.get("aggression", 0.3)) * 14.0 + float(pers_lf.get("bravery", 0.5)) * 6.0 - float(pers_lf.get("survival_instinct", 0.7)) * 5.0, 4.0, 24.0)
				# La pista manda: fuente y antiguedad pesan mas que el entusiasmo.
				# Un aviso de aliado viejo o un ruido vago no justifican buscar.
				var fm: Dictionary = b.get("_foe_mem", {})
				var foe_key := _actor_persist_key(_peer_id_for_actor(aggro))
				var anchor: Vector3 = Vector3.INF
				var src := "seen"
				var clue_age := 0.0
				if not fm.is_empty() and str(fm.get("key", "")) == foe_key:
					anchor = fm.get("pos", Vector3.INF)
					src = str(fm.get("src", "seen"))
					clue_age = float(Time.get_ticks_msec() - int(fm.get("t", 0))) / 1000.0
					persist *= clampf(float(fm.get("conf", 1.0)) * (1.0 - clue_age / 120.0), 0.0, 1.0)
				elif fm.is_empty():
					# Sin ficha de intel (estado heredado o rutas que solo
					# fijan _last_foe_pos): era el enemigo que seguiamos.
					anchor = b.get("_last_foe_pos", Vector3.INF)
				# Si la ficha es de otro enemigo no ancla a este: el respaldo
				# honesto es su posicion viva en el instante de perderlo.
				if anchor == Vector3.INF and b.get("last_heard_pos", Vector3.INF) != Vector3.INF:
					anchor = b.get("last_heard_pos", Vector3.INF)
					src = "heard"
					persist *= 0.65
				if anchor == Vector3.INF:
					anchor = aggro.global_position
					src = "seen"
				if anchor != Vector3.INF and clue_age <= 120.0 and persist >= 2.5:
					b["_lost_foe_pos"] = anchor
					b["_lost_sector"] = Vector3.INF
					b["_lost_sectors"] = 0
					b["_lost_scan_t"] = 0.0
					b["_lost_foe_until_msec"] = Time.get_ticks_msec() + int(persist * 1000.0)
					record_bot_event(int(b["bot_id"]), "lost_foe", _actor_persist_key(_peer_id_for_actor(aggro)), _poi_kind_near(anchor), anchor, "%s %.0fs (%.0fs)" % [src, persist, clue_age])
			# El rastro termina: el nodo ya no revela su posicion viva.
			b["aggro_target"] = null
			b["aggro_timer"] = 0.0

	var faction := str(b["faction"])
	var sight := 44.0 if faction == "hostile" else 28.0
	var best: Node3D = null
	var best_d := sight

	# Si es hostil ("Kael"), busca jugadores humanos y bots aliados. Un bot sin
	# arma TAMBIEN registra al humano que se acerca como amenaza — no para
	# iniciar un ataque suicida a manos vacias, sino para salir huyendo.
	if faction == "hostile":
		var has_ranged := _bot_has_ranged_weapon(proxy)
		var pers_h := _get_bot_personality(b)
		var cautious_h := not has_ranged and float(pers_h.get("survival_instinct", 0.7)) > float(pers_h.get("bravery", 0.5)) * 0.85
		for p in world.get_tree().get_nodes_in_group("net_player_proxy"):
			if not (p is Node3D) or p == proxy or not is_instance_valid(p):
				continue
			if bool(p.get_meta("proxy_dead", false)) or not bool(p.get_meta("has_real_pos", false)):
				continue
			if bool(p.get_meta("is_ai_bot", false)) and str(p.get_meta("bot_faction", "")) == "hostile":
				# Ex-compañero con rencor maximo (p.ej. expulsado por traicion o el
				# grupo contra el): la hostilidad personal rompe la tregua de faccion.
				var pid_h := _peer_id_for_actor(p as Node3D)
				if pid_h <= 0 or float(get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid_h)).get("hostility", 0.0)) < 0.9:
					continue
			var p3 := p as Node3D
			var pid3 := _peer_id_for_actor(p3)
			# Tregua vigente: el bot no retoma la ofensiva contra quien la acordo.
			if pid3 > 0 and int(b.get("_truce_peer", 0)) == pid3 and float(b.get("_truce_t", 0.0)) > 0.0:
				continue
			if cautious_h:
				if pid3 > 0 and float(get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid3)).get("fear", 0.0)) > 0.68:
					continue
			var heard := _can_bot_hear_actor(b, p3, proxy.global_position.distance_to(p3.global_position))
			var max_r := minf(best_d, maxf(34.0 if heard else 0.0, _effective_human_sight(p3, sight)))
			var d := proxy.global_position.distance_to(p3.global_position)
			if d < max_r and (heard or _has_clear_shot(proxy.global_position, p3.global_position)):
				best_d = d
				best = p3
		var local_p = world.get("player")
		if local_p is Node3D and is_instance_valid(local_p) and local_p.get("is_dead") != true:
			var lp3 := local_p as Node3D
			var pid_l := _peer_id_for_actor(lp3)
			var truce_l := pid_l > 0 and int(b.get("_truce_peer", 0)) == pid_l and float(b.get("_truce_t", 0.0)) > 0.0
			var fear_local := cautious_h and float(get_bot_relationship(int(b["bot_id"]), _actor_persist_key(1)).get("fear", 0.0)) > 0.68
			if not fear_local and not truce_l:
				var heard_l := _can_bot_hear_actor(b, lp3, proxy.global_position.distance_to(lp3.global_position))
				var max_rl := minf(best_d, maxf(34.0 if heard_l else 0.0, _effective_human_sight(lp3, sight)))
				var dl := proxy.global_position.distance_to(lp3.global_position)
				if dl < max_rl and (heard_l or _has_clear_shot(proxy.global_position, lp3.global_position)):
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
			# Sentidos PROPIOS: la distancia se mide siempre desde el bot que
			# mira/escucha. Un bandido pegado al lider pero a 100 m de este
			# bot no se "oye" por delegacion — la defensa del lider llega por
			# aviso real (_bot_warn_team_of_foe / rally / notify_leader).
			var d := proxy.global_position.distance_to(op.global_position)
			var heard_o := _can_bot_hear_actor(b, op, d)
			var max_ro := minf(best_d, maxf(34.0 if heard_o else 0.0, _effective_human_sight(op, sight)))
			if d < max_ro and (heard_o or _has_clear_shot(proxy.global_position, op.global_position)):
				best_d = d
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
	# El fusil solo da ventaja si dispara: con balas en el cargador vale ya;
	# si hay que recargar (BOT_GUN_RELOAD_TIME a pecho descubierto) solo con
	# margen de distancia; seco del todo no es un arma a distancia.
	var gun := _bot_usable_gun(proxy)
	if not gun.is_empty():
		if _bot_gun_ammo_state(proxy, gun) == "loaded":
			return true
		if dist > 12.0 + BOT_GUN_RELOAD_TIME * 6.5:
			return true
	# Arco con flechas o arrojadizas tambien permiten mantener distancia
	if dist > 4.5:
		var bow := _bot_best_bow(proxy)
		if not bow.is_empty() and _bot_arrow_count(proxy) > 0:
			return true
		if not _bot_best_thrown_weapon(proxy).is_empty() or _bot_item_count(proxy, "Boleadoras") > 0:
			return true
	return false

# Pasos con destino fijo y pausa de tiro: evita orbitar eternamente a la
# víctima o invertir el flanco cada frame cuando hay una pared al lado.
func _bot_combat_step(b: Dictionary, foe: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var st: Dictionary = b.get("_combat_step", {})
	var now := Time.get_ticks_msec()
	if int(st.get("target", 0)) != foe.get_instance_id() or now - int(st.get("last", now)) > 1200:
		st = {"target": foe.get_instance_id(), "t": 0.0, "phase": "hold", "side": 1.0 if int(b["bot_id"]) % 2 == 0 else -1.0}
	st["last"] = now
	st["t"] = maxf(0.0, float(st.get("t", 0.0)) - delta)
	if float(st["t"]) <= 0.0:
		if str(st.get("phase", "")) == "move":
			st["phase"] = "hold"
			st["t"] = 0.9 + float(int(b["bot_id"]) % 4) * 0.15
			st["side"] = -float(st["side"])
		else:
			var forward := foe.global_position - proxy.global_position
			forward.y = 0.0
			var distance := forward.length()
			forward = forward.normalized() if distance > 0.01 else Vector3.FORWARD
			var side := Vector3(-forward.z, 0.0, forward.x)
			var goal := Vector3.INF
			for sign_side in [float(st["side"]), -float(st["side"])]:
				var offset: Vector3 = side * float(sign_side) * 2.4
				if distance < 8.0:
					offset = (-forward + side * sign_side * 0.45).normalized() * 2.4
				var point: Vector3 = proxy.global_position + offset
				point.y = _ground_y(point.x, point.z, proxy.global_position.y)
				if absf(point.y - proxy.global_position.y) <= 0.65 and not _is_goal_blacklisted(b, point) and not _is_step_blocked(proxy.global_position, point):
					goal = point
					break
			st["goal"] = goal
			st["phase"] = "move" if goal != Vector3.INF else "hold"
			st["t"] = 0.85 if goal != Vector3.INF else 0.6
	b["_combat_step"] = st
	if str(st["phase"]) == "move" and proxy.global_position.distance_to(st["goal"]) > 0.3:
		var facing := float(b.get("rot", proxy.rotation.y))
		_move_bot_towards(b, st["goal"], 2.6, delta, "walk")
		b["rot"] = facing # el torso sigue al rival, no al paso lateral
	else:
		_stop_bot_motion(b)
	_bot_face_combat_point(b, foe.global_position, delta)

func _bot_face_combat_point(b: Dictionary, point: Vector3, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	var direction := point - proxy.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var yaw := float(b.get("rot", proxy.rotation.y))
	var turn := angle_difference(yaw, atan2(-direction.x, -direction.z))
	b["rot"] = yaw + clampf(turn, -deg_to_rad(220.0) * delta, deg_to_rad(220.0) * delta)
	proxy.rotation.y = float(b["rot"])

func _bot_has_firing_heading(b: Dictionary, point: Vector3) -> bool:
	var direction: Vector3 = point - (b["proxy"] as Node3D).global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return true # objetivo vertical: la inclinación la resuelve la mira 3D
	return absf(angle_difference(float(b.get("rot", 0.0)), atan2(-direction.x, -direction.z))) <= deg_to_rad(10.0)

func _engage_foe(b: Dictionary, foe: Node3D, delta: float) -> void:
	var proxy: Node3D = b["proxy"]
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	# Sale de la postura prona del puesto de overwatch si el combate sigue por
	# la via normal; volvera a tumbarse solo si retoma el puesto.
	b["prone"] = false
	b["is_aiming"] = false

	# Ordenar a su lobo domesticado que ataque también al objetivo
	_command_bot_wolf_against(b, foe)

	var fpos := foe.global_position
	var dist := proxy.global_position.distance_to(fpos)
	var to_foe := fpos - proxy.global_position
	to_foe.y = 0.0

	# Un superviviente usa el mismo arsenal que un jugador: elige el arma
	# segun la distancia — fusil, arco con flechas, arrojadiza o cuerpo a cuerpo.
	var pick := _pick_fight_weapon(b, dist)
	var weapon := str(pick.get("name", "Cuchillo"))
	var wkind := str(pick.get("kind", "melee"))
	# Táctica con boleadoras: si lleva boleadoras y el rival no está trabado,
	# bolearlo primero a media distancia (5..22 m) para frenarlo 6 s.
	if wkind != "rifle" and _bot_item_count(proxy, "Boleadoras") > 0 and dist > 5.0 and dist <= 22.0:
		if float(foe.get_meta("bola_slow_until", 0.0)) < Time.get_unix_time_from_system():
			wkind = "bola"
			weapon = "Boleadoras"
	b["held_item"] = weapon
	b["has_rifle"] = wkind == "rifle"
	proxy.set_meta("saved_held_item", weapon)
	# Sin filtro de desnivel: la raycast 3D ya descubre suelos/paredes reales.
	# Limitar a |dy|<3.2 impedia responder a un francotirador en un tejado y a
	# una vigia disparar desde su puesto elevado.
	var clear_los := _has_clear_shot(proxy.global_position, fpos)
	if wkind == "rifle" and bool(b.get("gun_reloading", false)):
		_bot_seek_ballistic_cover(b, foe, delta)
		return

	if wkind == "rifle" and dist > 3.5 and dist <= 48.0:
		b["is_aiming"] = clear_los
		# Si el objetivo está lejos o tras un muro/puerta/planta sin línea de
		# tiro limpia, avanzar hacia él (abriendo puertas/subiendo escaleras) en
		# lugar de quedarse strafeando enganchado contra la pared exterior.
		if dist > 26.0 or not clear_los:
			# Tiro largo (26-48 m) con linea limpia: se arrodilla en vez de
			# correr a quemarropa — la postura sentada estabiliza la mira
			# (0.28 vs 1.0 de dispersion) como hace un jugador humano.
			if clear_los:
				_stop_bot_motion(b)
				b["sitting"] = true
				_bot_face_combat_point(b, fpos, delta)
			else:
				_move_bot_towards(b, fpos, 6.4, delta, "run")
		else:
			_bot_combat_step(b, foe, delta)
		# Evaluar la mira después del movimiento y la postura de este tick.
		var aim_err := _bot_aim_tick(b, foe, dist, clear_los, delta, "m4" if _bot_gun_is_m4(weapon) else "sniper")
		# El gatillo pide mira asentada (tiempo de adquisicion) y alineada
		# dentro de la tolerancia de su personalidad — el agresivo suelta
		# antes, el prudente espera la mira.
		if float(b["shoot_cooldown"]) <= 0.0 and clear_los and not _bot_is_moving(b) \
				and _bot_has_firing_heading(b, fpos) \
				and aim_err <= _bot_trigger_tolerance_deg(b, dist) \
				and float(_bot_aim_st(b)["settle"]) >= _bot_acquire_sec(b):
			# Cadencia humana, no metronomo: +-0.45 s entre rafagas rompe el
			# ritmo perfecto que volvia los intercambios tan opresivos.
			b["shoot_cooldown"] = (1.15 if weapon == "Fusil de asalto" else 1.85) + randf_range(0.0, 0.45)
			var dmg := 26.0 if weapon == "Fusil de asalto" else 48.0
			_bot_fire_rifle_at(b, foe, dmg, weapon)
		return
	if wkind == "rifle" and dist > 48.0:
		# Demasiado lejos para el fusil: acercarse corriendo en zigzag
		b["strafe_timer"] = float(b["strafe_timer"]) + delta
		if float(b["strafe_timer"]) > 1.8:
			b["strafe_dir"] = -float(b["strafe_dir"])
			b["strafe_timer"] = 0.0
		var side2 := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
		var zig_goal := fpos + side2 * float(b["strafe_dir"]) * 5.0
		_move_bot_towards(b, zig_goal, 6.4, delta, "run")
		return

	# Arco: consume una flecha por disparo, como un jugador. A distancia media
	# se mueve en zigzag; si el rival se cierra (< 9.5 m) retrocede corriendo;
	# de muy cerca cambia a melee porque el arco no sirve.
	if wkind == "bow" and dist > 4.5 and dist <= 46.0:
		b["is_aiming"] = clear_los
		var sideb := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
		if dist > 30.0 or not clear_los:
			b["is_aiming"] = false
			_move_bot_towards(b, fpos, 6.4, delta, "run")
		elif dist < 9.5 and to_foe.length_squared() > 0.01 and float(b["shoot_cooldown"]) > 0.15:
			b["is_aiming"] = false
			var back_dir := -to_foe.normalized()
			if _is_step_blocked(proxy.global_position, proxy.global_position + back_dir * 1.6):
				back_dir = (back_dir + sideb * float(b["strafe_dir"]) * 1.2).normalized()
			_move_bot_towards(b, proxy.global_position + back_dir * 5.0, 6.2, delta, "run")
		elif bool(b.get("_bow_drawing", false)) or Time.get_ticks_msec() < int(b.get("_bow_shot_anim_until", 0)):
			_stop_bot_motion(b)
			_bot_face_combat_point(b, fpos, delta)
		else:
			_bot_combat_step(b, foe, delta)
		var aim_err_b := _bot_aim_tick(b, foe, dist, clear_los, delta, "bow")
		if float(b["shoot_cooldown"]) <= 0.0 and clear_los and bool(b["is_aiming"]) \
				and not _bot_is_moving(b) and _bot_has_firing_heading(b, fpos) \
				and aim_err_b <= _bot_trigger_tolerance_deg(b, dist) \
				and float(_bot_aim_st(b)["settle"]) >= _bot_acquire_sec(b):
			b["shoot_cooldown"] = 1.55 if weapon == "Arco reforzado" else 1.9
			_bot_fire_bow(b, foe, weapon)
		return
	if wkind == "bow" and dist > 46.0:
		_move_bot_towards(b, fpos, 6.4, delta, "run")
		return

	# Arrojadizas (lanzas, palo afilado, boleadoras): un lanzamiento cada pocos
	# segundos; el proyectil vuela de verdad en el servidor y se ve en clientes.
	if wkind in ["thrown", "bola"] and dist > 4.5 and dist <= 38.0:
		b["is_aiming"] = clear_los
		var sidet := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
		if dist > 26.0 or not clear_los:
			b["is_aiming"] = false
			_move_bot_towards(b, fpos, 6.4, delta, "run")
		elif dist < 8.5 and to_foe.length_squared() > 0.01 and float(b["shoot_cooldown"]) > 0.15:
			b["is_aiming"] = false
			var back_t := -to_foe.normalized()
			if _is_step_blocked(proxy.global_position, proxy.global_position + back_t * 1.6):
				back_t = (back_t + sidet * float(b["strafe_dir"]) * 1.2).normalized()
			_move_bot_towards(b, proxy.global_position + back_t * 4.5, 6.2, delta, "run")
		else:
			_bot_combat_step(b, foe, delta)
		var aim_err_t := _bot_aim_tick(b, foe, dist, clear_los, delta, "throw")
		if float(b["shoot_cooldown"]) <= 0.0 and clear_los and bool(b["is_aiming"]) \
				and not _bot_is_moving(b) and _bot_has_firing_heading(b, fpos) \
				and aim_err_t <= _bot_trigger_tolerance_deg(b, dist) \
				and float(_bot_aim_st(b)["settle"]) >= _bot_acquire_sec(b):
			b["shoot_cooldown"] = 2.6 if wkind == "bola" else 2.1
			_bot_fire_thrown(b, foe, weapon, wkind == "bola")
		return
	if wkind in ["thrown", "bola"] and dist > 38.0:
		_move_bot_towards(b, fpos, 6.4, delta, "run")
		return

	b["is_aiming"] = false
	var melee_w := _best_melee_weapon(proxy)
	var reach := _bot_melee_reach(melee_w)
	b["held_item"] = melee_w
	b["has_rifle"] = false
	proxy.set_meta("saved_held_item", melee_w)
	var can_melee_hit: bool = dist <= reach and absf(fpos.y - proxy.global_position.y) <= 1.8 and _has_clear_shot(proxy.global_position, fpos)
	if can_melee_hit:
		_stop_bot_motion(b)
		var side_m := Vector3(-to_foe.z, 0.0, to_foe.x).normalized() if to_foe.length_squared() > 0.01 else Vector3.RIGHT
		# Separate overlapping bodies without backing out of short-arm reach.
		if dist < 0.65 and to_foe.length_squared() > 0.01:
			_move_bot_towards(b, proxy.global_position - to_foe.normalized() * 1.5 + side_m * float(b["strafe_dir"]) * 1.2, 3.4, delta, "walk")
		if to_foe.length_squared() > 0.001:
			b["rot"] = atan2(-to_foe.x, -to_foe.z)
			proxy.rotation.y = float(b["rot"])
		b["anim"] = "punch/" + PlayerController.THIRD_PERSON_EXTERNAL_PUNCH_ANIMATION if melee_w.is_empty() else "external/" + PlayerController.THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION
		if float(b["attack_cooldown"]) <= 0.0:
			b["attack_cooldown"] = 0.68 + randf_range(0.0, 0.35)
			# A quemarropa usa su mejor arma cuerpo a cuerpo (o los punos)
			var melee_dmg := _weapon_melee_damage(melee_w) if _bot_item_count(proxy, melee_w) > 0 else 25.0
			# Un objetivo que se mueve rapido esquiva parte de los tajos: el golpe
			# no es automatico aunque este dentro del alcance.
			var mspd := _bot_target_speed(b, foe)
			if proxy.global_position.distance_to(foe.global_position) <= reach and _has_clear_shot(proxy.global_position, foe.global_position) and randf() >= _bot_melee_dodge_chance(mspd):
				_apply_bot_damage_to_target(b, foe, melee_dmg * 0.45, "melee")
				_reduce_bot_item_durability(proxy, melee_w, 1.5)
	else:
		_move_bot_towards(b, fpos, 6.5, delta, "run")

# Distances between body origins, including the victim's capsule. The old
# universal 3.6 m radius let fists/knives hit across a visible gap.
func _bot_melee_reach(weapon: String) -> float:
	if weapon in ["Lanza", "Lanza de hueso", "Palo afilado"]:
		return 2.2
	if weapon in ["Hacha", "Hacha de piedra", "Pico", "Martillo", "Azada", "Azada de piedra", "Pala"]:
		return 1.8
	return 1.4

# Velocidad reciente del objetivo: cambiar de blanco reinicia la muestra;
# la adquisición de la mira sigue pagando su propio tiempo de asentamiento.
func _bot_target_speed(b: Dictionary, target: Node3D) -> float:
	return _bot_target_velocity(b, target).length()

# Velocidad VECTORIAL medida del objetivo: diferencia entre posiciones
# observadas, nunca un campo interno del nodo. Sirve para el adelanto de la
# mira y para el esquive en melee.
func _bot_target_velocity(b: Dictionary, target: Node3D) -> Vector3:
	var key := int(target.get_instance_id())
	var prev: Dictionary = b.get("_foe_track", {})
	var now := Time.get_ticks_msec()
	var vel := Vector3.ZERO
	var pt = prev.get("tpos", null)
	if pt is Vector3 and int(prev.get("id", 0)) == key:
		var elapsed := now - int(prev.get("msec", 0))
		# No renovar el ancla a cada tick y dividir por 0.2: a 60 Hz eso
		# subestimaba la carrera por un factor de doce. Reutilizar la última
		# muestra hasta reunir un intervalo medible, también dentro de ráfagas.
		if elapsed >= 0 and elapsed < 120:
			return prev.get("vel", Vector3.ZERO)
		if elapsed > 0 and elapsed <= 5000:
			vel = (target.global_position - pt) / (float(elapsed) / 1000.0)
		if vel.length() > 14.0:
			vel = Vector3.ZERO  # salto de objetivo/teleport: no es velocidad real
	b["_foe_track"] = {"id": key, "tpos": target.global_position, "msec": now, "vel": vel}
	return vel

# Lo mismo para el tajo cuerpo a cuerpo: ~10% quieto, ~50% si viene esprintando.
func _bot_melee_dodge_chance(target_speed: float) -> float:
	return clampf(0.10 + minf(target_speed, 8.0) * 0.05, 0.10, 0.5)

# === Punteria fisica del bot: las mismas reglas que el jugador ===============
# La mira es un estado persistente (_aim): direccion real del arma, retroceso
# acumulado (rp/ry), oscilacion de respiracion (breath_t/hold_*), tiempo de
# adquisicion (settle) y sacudida por impactos (shock). El disparo sale de ESA
# orientacion en el instante del gatillo — nunca de un vector perfecto
# calculado hacia el objetivo en el ultimo tick.
const BOT_AIM_SLEW_DEG := 150.0     # velocidad angular base de la mira
const BOT_AIM_ACQUIRE_SEC := 0.4    # tiempo minimo asentando antes de disparar
const BOT_RECOIL_RECOVER := 3.0     # = _recoil_recover_speed del jugador
const BOT_AIM_SHOCK_DECAY := 1.4    # la sacudida por impacto se va a este ritmo
const BOT_BULLET_DRAG := 0.12       # = RifleProjectile.drag_coeff por defecto
const BOT_LEAD_MIN := 0.45
const BOT_LEAD_MAX := 0.92

func _bot_aim_st(b: Dictionary) -> Dictionary:
	var a = b.get("_aim")
	if a is Dictionary:
		return a
	a = {"dir": Vector3.ZERO, "rp": 0.0, "ry": 0.0, "breath_t": randf() * 7.0,
		"hold_on": false, "hold_t": 0.0, "hold_rec": 0.0, "settle": 0.0,
		"tgt": 0, "shock": 0.0, "last_pt": Vector3.INF}
	b["_aim"] = a
	return a

# Decaimiento continuo (retroceso, sacudida, contencion): corre cada tick como
# en el jugador, este apuntando o no.
func _bot_aim_decay(b: Dictionary, delta: float) -> void:
	var a = b.get("_aim")
	if not (a is Dictionary):
		return
	if not bool(b.get("is_aiming", false)):
		a["hold_on"] = false
	var decay := 1.0 - exp(-BOT_RECOIL_RECOVER * delta)
	a["rp"] = lerpf(float(a["rp"]), 0.0, decay)
	a["ry"] = lerpf(float(a["ry"]), 0.0, decay * 0.6)
	a["shock"] = maxf(0.0, float(a["shock"]) - BOT_AIM_SHOCK_DECAY * delta)
	a["hold_rec"] = maxf(0.0, float(a["hold_rec"]) - delta)
	if bool(a["hold_on"]):
		a["hold_t"] = float(a["hold_t"]) + delta
		if float(a["hold_t"]) >= PlayerController.BREATH_HOLD_DURATION:
			a["hold_on"] = false
			a["hold_rec"] = 4.0

func _bot_energy(b: Dictionary) -> float:
	var st: SurvivalStats = b.get("vstats")
	return st.energy if st != null else float(b.get("energy", 100.0))

func _bot_is_moving(b: Dictionary) -> bool:
	return str(b.get("anim", "")) == "walk" or str(b.get("anim", "")) == "run"

# Parametros por familia de arma: velocidad de salida, drag del proyectil,
# aumento de la mira (afecta a la oscilacion) y si es proyectil "primitivo"
# (compensacion de caida 0.5*g*t^2 como el arco del jugador).
func _bot_aim_weapon_params(kind: String) -> Dictionary:
	match kind:
		"m4":
			return {"speed": PlayerController.M4_MUZZLE_SPEED, "drag": BOT_BULLET_DRAG, "mag": 1.35, "primitive": false}
		"sniper":
			return {"speed": PlayerController.RIFLE_MUZZLE_SPEED, "drag": BOT_BULLET_DRAG, "mag": 4.0, "primitive": false}
		"bow":
			return {"speed": 80.0, "drag": 0.30, "mag": 1.45, "primitive": true}
		_:
			return {"speed": 58.0, "drag": 0.28, "mag": 1.25, "primitive": true}

func _bot_projectile_flight_time(dist: float, speed: float, drag: float) -> float:
	# x(t) = v0/k·(1-e^-kt) -> t = -ln(1-x·k/v0)/k (misma forma que el jugador)
	var arg := 1.0 - dist * drag / maxf(speed, 1.0)
	if arg <= 0.05 or drag <= 0.001:
		return dist / speed
	return -log(arg) / drag

# Punto al que la mira DEBERIA ir: pecho del objetivo + adelanto por su
# velocidad medida (nunca posiciones futuras) + compensacion de caida.
func _bot_aim_point(b: Dictionary, target: Node3D, dist: float, kind: String) -> Vector3:
	var params := _bot_aim_weapon_params(kind)
	var pt := target.global_position + Vector3(0.0, 1.02, 0.0)
	var vel := _bot_target_velocity(b, target)
	var ft := _bot_projectile_flight_time(dist, float(params["speed"]), float(params["drag"]))
	# Adelanto imperfecto: mejora con la experiencia (bajas acreditadas),
	# nunca exacto.
	var mstats: Dictionary = (b.get("_mem", {}) as Dictionary).get("stats", {})
	var kills := int(mstats.get("kills_prey", 0)) + int(mstats.get("kills_predator", 0)) + int(mstats.get("kills_bot", 0)) + int(mstats.get("kills_player", 0))
	var lead := clampf(BOT_LEAD_MIN + float(kills) * 0.035, BOT_LEAD_MIN, BOT_LEAD_MAX)
	pt += vel * ft * lead
	if bool(params["primitive"]):
		pt.y += 0.5 * 9.81 * ft * ft
	else:
		var v0 := float(params["speed"])
		var k := float(params["drag"])
		pt.y += 9.81 / maxf(0.02, k) * (ft - dist / v0)
	return pt

# Un tick de punteria: gira la mira hacia el punto deseado con velocidad
# angular limitada y devuelve el error angular actual en grados. Sin linea de
# tiro, el punto deseado es la ULTIMA posicion conocida — la posicion viva del
# nodo no entra.
func _bot_aim_tick(b: Dictionary, foe: Node3D, dist: float, clear_los: bool, delta: float, kind: String) -> float:
	var a := _bot_aim_st(b)
	var proxy: Node3D = b["proxy"]
	var tid := int(foe.get_instance_id())
	if int(a["tgt"]) != tid:
		# Cambio de objetivo: la mira no salta — gira desde donde estaba, con
		# penalizacion extra de re-adquisicion.
		a["tgt"] = tid
		a["settle"] = 0.0
		a["shock"] = minf(1.8, float(a["shock"]) + 0.25)
	var pt := Vector3.INF
	if clear_los:
		pt = _bot_aim_point(b, foe, dist, kind)
	else:
		var fm: Dictionary = b.get("_foe_mem", {})
		var fpos = fm.get("pos", Vector3.INF)
		pt = fpos if fpos is Vector3 and fpos != Vector3.INF else Vector3(a["last_pt"])
	var origin := proxy.global_position + Vector3(0.0, 0.3 if bool(b.get("prone", false)) else (1.0 if (bool(b.get("crouching", false)) or bool(b.get("sitting", false))) else 1.4), 0.0)
	if pt == Vector3.INF:
		pt = origin + Vector3(a["dir"]).normalized() * maxf(dist, 10.0)
	a["last_pt"] = pt
	var desired := (pt - origin).normalized()
	var cur := Vector3(a["dir"]).normalized()
	if cur.length_squared() < 0.5:
		# Primera adquisicion: la mira arranca desviada, no clavada.
		cur = desired.rotated(Vector3.UP, deg_to_rad(randf_range(-14.0, 14.0)))
	var ang := cur.angle_to(desired)
	# Velocidad angular: peor moviendo, agotado o recien impactado; la
	# agresividad acelera algo el giro (no la precision).
	var pers: Dictionary = _get_bot_personality(b)
	var rate := BOT_AIM_SLEW_DEG * (0.85 + float(pers.get("aggression", 0.5)) * 0.35)
	if _bot_is_moving(b):
		rate *= 0.55
	var energy_now := _bot_energy(b)
	if energy_now < 30.0:
		rate *= 0.55 + energy_now * 0.015
	rate *= 1.0 - minf(0.45, float(a["shock"]) * 0.3)
	var t := minf(1.0, deg_to_rad(rate) * delta / maxf(ang, 0.0001))
	cur = cur.slerp(desired, t).normalized()
	a["dir"] = cur
	a["breath_t"] = float(a["breath_t"]) + delta
	a["settle"] = float(a["settle"]) + delta
	# Contencion de respiracion: el prudente la usa en tiros largos con la
	# mira ya asentada — mismos 15 s + 4 s de recuperacion que el jugador.
	if bool(b.get("is_aiming", false)) and not _bot_is_moving(b) and not bool(a["hold_on"]):
		var careful := float(pers.get("survival_instinct", 0.5)) > 0.55 or float(pers.get("aggression", 0.5)) < 0.4
		if careful and dist > 18.0 and float(a["settle"]) > 0.8 and float(a["hold_rec"]) <= 0.0:
			a["hold_on"] = true
			a["hold_t"] = 0.0
	return rad_to_deg(cur.angle_to(desired))

# Oscilacion de respiracion en el instante (misma formula del jugador):
# amplitud por arma y aumento, fatiga, postura; cero bajo contencion.
func _bot_breath_offsets(b: Dictionary, kind: String) -> Vector2:
	var a := _bot_aim_st(b)
	if bool(a["hold_on"]) or not bool(b.get("is_aiming", false)) or _bot_is_moving(b):
		return Vector2.ZERO
	var energy_now := _bot_energy(b)
	var fatigue := 1.0 + (1.0 - clampf(energy_now / 100.0, 0.0, 1.0)) * 1.5
	var p_amp := 0.65
	var y_amp := 0.48
	if kind != "m4":
		var mag_scale := sqrt(4.0 / float(_bot_aim_weapon_params(kind)["mag"]))
		p_amp = 0.35 * mag_scale
		y_amp = 0.25 * mag_scale
	var stance := 0.12 if bool(b.get("prone", false)) else (0.28 if (bool(b.get("crouching", false)) or bool(b.get("sitting", false))) else 1.0)
	var shock := 1.0 + float(a["shock"]) * 1.2
	var tt := float(a["breath_t"])
	return Vector2(deg_to_rad(p_amp * fatigue * stance * shock) * sin(tt * 1.2),
		deg_to_rad(y_amp * fatigue * stance * shock) * sin(tt * 0.8))

# Dispersion del arma — copia exacta de PlayerController._current_spread_deg.
func _bot_current_spread_deg(b: Dictionary, is_m4: bool) -> float:
	var a := _bot_aim_st(b)
	var spread_deg := 0.6
	if bool(b.get("crouching", false)) or bool(b.get("sitting", false)):
		spread_deg = 0.20
	if bool(b.get("prone", false)):
		spread_deg = 0.08
	if bool(b.get("is_aiming", false)):
		spread_deg = 0.006 if bool(b.get("prone", false)) else (0.012 if (bool(b.get("crouching", false)) or bool(b.get("sitting", false))) else 0.025)
		if bool(a["hold_on"]):
			spread_deg *= 0.7
	if is_m4:
		spread_deg *= PlayerController.M4_SPREAD_MULT
	if _bot_is_moving(b):
		spread_deg *= 2.5
	return minf(spread_deg, 12.0)

# Retroceso tras un disparo — copia de PlayerController._apply_rifle_recoil:
# la mira sube (rp) y deriva a un lado (ry), y se recupera con el tiempo.
func _bot_apply_rifle_recoil(b: Dictionary, is_m4: bool) -> void:
	var a := _bot_aim_st(b)
	var recoil_kick := PlayerController.M4_RECOIL if is_m4 else 8.0
	if bool(b.get("prone", false)):
		recoil_kick *= 0.375
	elif bool(b.get("crouching", false)):
		recoil_kick *= 0.625
	if bool(b.get("is_aiming", false)):
		recoil_kick *= 0.7
	a["rp"] = float(a["rp"]) + deg_to_rad(recoil_kick)
	a["ry"] = float(a["ry"]) + deg_to_rad(randf_range(-recoil_kick * 0.4, recoil_kick * 0.4))
	# El propio disparo tambien descompone la mira: el bot necesita un rato
	# para volver a colocar el arma sobre el objetivo.
	a["shock"] = minf(1.8, float(a["shock"]) + 0.12)

# Direccion eficaz del disparo en este instante: orientacion de la mira +
# retroceso + oscilacion de respiracion + disco uniforme de dispersion —
# exactamente la composicion del jugador.
func _bot_aim_fire_dir(b: Dictionary, kind: String, spread_deg: float) -> Vector3:
	var a := _bot_aim_st(b)
	var base := Vector3(a["dir"])
	if base.length_squared() < 0.5:
		# Mira sin adquirir aun (liberacion de arco sin combate previo, tests):
		# el arma va donde mira el cuerpo, nunca instantaneamente al enemigo.
		base = -(b["proxy"] as Node3D).global_transform.basis.z
	base = base.normalized()
	var right := base.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var sway := _bot_breath_offsets(b, kind)
	# rp>0 = arma levantada por el retroceso; sway.x>0 = mira alta ese instante.
	var dir := base.rotated(right, float(a["rp"]) + sway.x).rotated(Vector3.UP, float(a["ry"]) + sway.y).normalized()
	var spr := deg_to_rad(spread_deg)
	var ang := randf() * TAU
	var rad := sqrt(randf()) * tan(spr)
	var up := right.cross(dir).normalized()
	return (dir + right * cos(ang) * rad + up * sin(ang) * rad).normalized()

# Alineacion que exige antes de apretar el gatillo: el tamaño angular del
# blanco pone el techo (a 10 m hay margen, a 50 m hay que estar encima). El
# agresivo dispara antes de asentar; el prudente espera.
func _bot_trigger_tolerance_deg(b: Dictionary, dist: float) -> float:
	var pers: Dictionary = _get_bot_personality(b)
	var base := clampf(rad_to_deg(atan2(0.42, maxf(dist, 2.0))) * 1.9, 0.8, 4.5)
	return base * (0.75 + float(pers.get("aggression", 0.5)) * 0.9)

func _bot_acquire_sec(b: Dictionary) -> float:
	var pers: Dictionary = _get_bot_personality(b)
	return BOT_AIM_ACQUIRE_SEC * (1.35 - float(pers.get("aggression", 0.5)) * 0.9)

# Puerta comun del gatillo: un tick de punteria + mira asentada + alineada
# dentro de la tolerancia. Devuelve true cuando el disparo fisico puede salir.
# Usada por todos los caminos de fuego (combate, depredadores, caza, vigia).
func _bot_fire_ready(b: Dictionary, target: Node3D, dist: float, clear_los: bool, delta: float, kind: String) -> bool:
	var err := _bot_aim_tick(b, target, dist, clear_los, delta, kind)
	if not clear_los:
		return false
	return err <= _bot_trigger_tolerance_deg(b, dist) and float(_bot_aim_st(b)["settle"]) >= _bot_acquire_sec(b)

# Coste de energia del disparo, igual que el jugador (M4 1.2 / franco 3.0 /
# arco 3.5 / arrojadiza 6.0): agotado no se dispara igual que el humano.
func _bot_shot_energy_cost(kind: String) -> float:
	match kind:
		"m4": return PlayerController.M4_ENERGY_COST
		"sniper": return 3.0
		"bow": return 3.5
		_: return 6.0

func _bot_pay_shot_energy(b: Dictionary, kind: String) -> bool:
	var cost := _bot_shot_energy_cost(kind)
	var st: SurvivalStats = b.get("vstats")
	var en := st.energy if st != null else float(b.get("energy", 100.0))
	if en < cost:
		return false
	if st != null:
		st.energy = maxf(0.0, st.energy - cost)
	b["energy"] = maxf(0.0, en - cost)
	return true

# Registro para depuracion/tests: lo ultimo que salio del arma con el estado
# de punteria en ese instante.
func _bot_log_shot(b: Dictionary, weapon: String, origin: Vector3, dir: Vector3, spread: float, foe: Node3D) -> void:
	var a := _bot_aim_st(b)
	var log_arr: Array = b.get("_shot_log", [])
	log_arr.append({"t": Time.get_ticks_msec(), "weapon": weapon, "origin": origin, "dir": dir,
		"aim_dir": Vector3(a["dir"]), "recoil": Vector2(float(a["rp"]), float(a["ry"])),
		"spread": spread, "dist": origin.distance_to(foe.global_position) if foe != null else -1.0,
		"moving": _bot_is_moving(b), "crouch": bool(b.get("crouching", false)), "prone": bool(b.get("prone", false)),
		"energy": _bot_energy(b)})
	if log_arr.size() > 24:
		log_arr.pop_front()
	b["_shot_log"] = log_arr

# Viento de disparo del bot: el que sopla en el mundo (observacion meteo)
# en m/s — equivalente al _wind_dir*_wind_strength local del jugador.
func _bot_shot_wind() -> Vector3:
	if world == null or not world.has_method("_get_weather_observation"):
		return Vector3.ZERO
	# _get_weather_observation lee hud.* en la rama local: sin HUD ni red
	# conectada (mundo de pruebas) no hay observacion — viento cero.
	var wnet = world.get("net")
	if not (wnet != null and bool(wnet.get("is_connected"))) and world.get("hud") == null:
		return Vector3.ZERO
	var obs: Dictionary = world._get_weather_observation()
	var sp := float(obs.get("wind_speed", 0.0)) / 3.6  # km/h -> m/s
	var dir := deg_to_rad(float(obs.get("wind_direction", 0.0)))
	return Vector3(-sin(dir), 0.0, cos(dir)) * sp * 0.35

func _bot_fire_rifle_at(b: Dictionary, target: Node3D, dmg: float, weapon := "") -> void:
	var _cpt := Time.get_ticks_usec()
	var proxy: Node3D = b["proxy"]
	if weapon.is_empty():
		weapon = str(b.get("held_item", "Fusil de asalto"))
	if bool(b.get("gun_reloading", false)):
		return
	# El M4 dispara en rafagas de hasta 3 balas como el jugador
	# (M4_BURST_ROUNDS): una bala real por proyectil, cada 90 ms, y se
	# corta si el bot muere, cambia de arma, entra en recarga o agota el
	# cargador. El francotirador es monotiro.
	var burst_rounds := 1
	if _bot_gun_is_m4(weapon):
		burst_rounds = mini(BOT_M4_BURST_ROUNDS, _bot_gun_loaded(_bot_gun_ammo(proxy), weapon))
	_bot_fire_rifle_round(b, target, dmg, weapon)
	if burst_rounds <= 1:
		return
	for extra_i in range(1, burst_rounds):
		get_tree().create_timer(0.09 * float(extra_i)).timeout.connect(func():
			if not is_instance_valid(self) or not is_instance_valid(proxy) or not is_instance_valid(target) or bool(b.get("dead", false)) or float(b.get("health", 100.0)) <= 0.0 or str(b.get("held_item", "")) != weapon or bool(b.get("gun_reloading", false)):
				return
			_bot_fire_rifle_round(b, target, dmg, weapon)
		)

# Una bala del bot: sale de la orientacion REAL de la mira (adquisicion +
# respiracion + retroceso + dispersion, las reglas del jugador) y vuela como
# proyectil fisico — el daño solo existe si la trayectoria intersecta.
func _bot_fire_rifle_round(b: Dictionary, target: Node3D, dmg: float, weapon: String) -> void:
	var _cpt := Time.get_ticks_usec()
	var proxy: Node3D = b["proxy"]
	# Recheck at release: navigation can move the shooter after perception.
	if not is_instance_valid(proxy) or not is_instance_valid(target) or not _has_clear_shot(proxy.global_position, target.global_position):
		if CombatProf.enabled: CombatProf.mark("bot_fire.recheck_fail", _cpt)
		return
	var is_m4 := _bot_gun_is_m4(weapon)
	var kind := "m4" if is_m4 else "sniper"
	# Coste de energia del disparo — el mismo que el jugador: un bot agotado
	# no puede disparar igual que un jugador agotado no puede. Se comprueba
	# ANTES de consumir la bala para no perderla en un intento abortado.
	if not _bot_pay_shot_energy(b, kind):
		if CombatProf.enabled: CombatProf.mark("bot_fire.tired", _cpt)
		return
	if not _bot_gun_prepare_shot(b, weapon):
		if CombatProf.enabled: CombatProf.mark("bot_fire.no_ammo", _cpt)
		return
	var bot_id := int(b["bot_id"])
	var origin := proxy.global_position + Vector3(0.0, 0.3 if bool(b.get("prone", false)) else (1.0 if (bool(b.get("crouching", false)) or bool(b.get("sitting", false))) else 1.4), 0.0)
	var spread := _bot_current_spread_deg(b, is_m4)
	var dir := _bot_aim_fire_dir(b, kind, spread)
	_bot_log_shot(b, weapon, origin, dir, spread, target)
	var shot_wind := _bot_shot_wind()
	if world.has_method("_net_player_shot_rifle"):
		world._net_player_shot_rifle(bot_id, origin, dir, shot_wind)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.player_shot_rifle.rpc_id(pid, bot_id, origin, dir, shot_wind)
	# Proyectil real en el servidor: gravedad, drag, viento, paredes y
	# capsulas de supervivientes deciden el impacto — la decision de acierto
	# ya no existe.
	var muzzle_speed := PlayerController.M4_MUZZLE_SPEED if is_m4 else PlayerController.RIFLE_MUZZLE_SPEED
	_bot_launch_projectile(b, origin, dir, weapon, muzzle_speed, PlayerController.RIFLE_RANGE, dmg, false, "m4" if is_m4 else "rifle", BOT_BULLET_DRAG, shot_wind)
	# Retroceso DESPUES de capturar la direccion (como el jugador): esta bala
	# sale limpia y la siguiente paga el levantamiento — en rafaga M4 las
	# balas 2 y 3 heredan el retroceso acumulado, sin re-apuntar perfecto.
	_bot_apply_rifle_recoil(b, is_m4)

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

# El bot tensa el arco como un jugador: el disparo no sale en el instante de
# la decision — hay un tiempo de preparacion (BOW_RELEASE_DELAY) durante el
# que la mira sigue moviendose, y la flecha sale con la orientacion REAL en
# el momento de la liberacion. Consume la mejor flecha, gasta durabilidad,
# lanza el proyectil real en el servidor y avisa a los clientes.
func _bot_fire_bow(b: Dictionary, foe: Node3D, bow_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	if bool(b.get("_bow_drawing", false)):
		return  # ya esta tensando: el arco no dispara dos veces
	# Energia para tensar: la misma puerta que el jugador (3.5).
	if _bot_energy(b) < 3.5:
		return
	if _bot_arrow_count(proxy) <= 0:
		return
	b["_bow_drawing"] = true
	var mgr = self
	get_tree().create_timer(PlayerController.BOW_RELEASE_DELAY, false).timeout.connect(func():
		if is_instance_valid(mgr):
			mgr._bot_bow_release(b, foe, bow_name))

# La liberacion: la flecha sale con la mira de ESE momento (la oscilacion ha
# seguido corriendo durante la preparacion) + compensacion de caida real.
func _bot_bow_release(b: Dictionary, foe: Node3D, bow_name: String) -> void:
	b["_bow_drawing"] = false
	b["_bow_shot_anim_until"] = Time.get_ticks_msec() + 900
	var proxy: Node3D = b["proxy"]
	if not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	if not _bot_pay_shot_energy(b, "bow"):
		return
	var arrow_name := _consume_bot_arrow(proxy)
	if arrow_name.is_empty():
		return
	_reduce_bot_item_durability(proxy, bow_name, 2.0)
	var bot_id := int(b["bot_id"])
	var origin := proxy.global_position + Vector3(0.0, 1.0 if bool(b.get("crouching", false)) else 1.5, 0.0)
	var dir := _bot_aim_fire_dir(b, "bow", _bot_current_spread_deg(b, false) * 0.6)
	var speed := 95.0 if bow_name == "Arco reforzado" else 75.0
	if arrow_name == "Flecha improvisada":
		speed *= 0.80  # igual que el jugador: el astil desnudo sale mas lento
	var dmg := _bot_arrow_base_damage(arrow_name) * (1.18 if bow_name == "Arco reforzado" else 1.0)
	_bot_log_shot(b, bow_name, origin, dir, 0.0, foe if is_instance_valid(foe) else null)
	_broadcast_bot_projectile(bot_id, origin, dir, arrow_name, speed)
	# Alerta a la fauna cercana (el RPC devuelve limpio: el proxy no es un jugador)
	if world.has_method("_net_primitive_shot"):
		world._net_primitive_shot(bot_id, origin, dir, arrow_name, speed)
	_bot_launch_projectile(b, origin, dir, arrow_name, speed, 140.0, dmg, false, "arco")

# Lanzas, palo afilado y boleadoras: el arma no se consume (solo durabilidad),
# como al recogerla del suelo tras el lanzamiento. La direccion sale de la
# mira real — preparacion, oscilacion y fatiga como cualquier otro arma.
func _bot_fire_thrown(b: Dictionary, foe: Node3D, item_name: String, is_bola: bool) -> void:
	var proxy: Node3D = b["proxy"]
	var bot_id := int(b["bot_id"])
	# Energia para lanzar: la misma puerta que el jugador (6.0).
	if not _bot_pay_shot_energy(b, "throw"):
		return
	_reduce_bot_item_durability(proxy, item_name, 3.0)
	var origin := proxy.global_position + Vector3(0.0, 1.0 if bool(b.get("crouching", false)) else 1.4, 0.0)
	var dir := _bot_aim_fire_dir(b, "throw", _bot_current_spread_deg(b, false) * 0.6)
	var speed := 55.0 if is_bola else 60.0
	_bot_log_shot(b, item_name, origin, dir, 0.0, foe)
	_broadcast_bot_projectile(bot_id, origin, dir, item_name, speed)
	if world.has_method("_net_primitive_shot"):
		world._net_primitive_shot(bot_id, origin, dir, item_name, speed)
	_bot_launch_projectile(b, origin, dir, item_name, speed, 65.0, 65.0, is_bola, "bola" if is_bola else "lanza")

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
# weapon_kind etiqueta el daño ("rifle"/"bow"/"melee"/"bola"); -1 en drag usa
# la tabla por tipo de proyectil; wind es la velocidad de viento del disparo.
func _bot_launch_projectile(b: Dictionary, origin: Vector3, dir: Vector3, item_name: String, speed: float, max_dist: float, dmg_base: float, is_bola: bool, weapon_kind := "", drag := -1.0, wind := Vector3.ZERO) -> void:
	if world == null or not (world is Node3D):
		return
	var proxy: Node3D = b["proxy"]
	var projectile: Node3D = preload("res://scripts/RifleProjectile.gd").new()
	projectile.velocity = dir.normalized() * speed
	projectile.max_distance = max_dist
	projectile.wind_velocity = wind
	projectile.shooter = proxy
	var excl: Array[RID] = []
	if proxy is CollisionObject3D:
		excl.append(proxy.get_rid())
	projectile.excluded = excl
	projectile.drag_coeff = drag if drag >= 0.0 else _bot_projectile_drag(item_name)
	projectile.launch_speed = speed
	projectile.align_flight = item_name.begins_with("Flecha") or item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]
	projectile.spin_speed = 22.0 if is_bola else 0.0
	(world as Node3D).add_child(projectile)
	projectile.global_position = origin
	projectile.look_at(origin + dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.97 else Vector3.FORWARD)
	var bot_ref: Dictionary = b
	projectile.impact.connect(func(collider, hit_pos: Vector3, _dist: float, _normal: Vector3):
		_on_bot_projectile_impact(bot_ref, projectile, collider, hit_pos, dmg_base, is_bola, weapon_kind))

func _on_bot_projectile_impact(b: Dictionary, projectile: Node3D, collider, hit_pos: Vector3, dmg_base: float, is_bola: bool, weapon_kind := "") -> void:
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
	# Impacto por capsula (proxy sin fisica): cabeza = franja craneal superior.
	var is_wildlife_tgt: bool = target != null and (target is WildlifeController or target.is_in_group("wildlife"))
	var is_human_actor: bool = target != null and not is_wildlife_tgt and (target.is_in_group("net_player_proxy") or target.is_in_group("ai_survivor_bot") or target.is_in_group("remote_player") or target.has_method("apply_damage"))
	if is_human_actor and not is_headshot:
		var prone_now: bool = bool(target.get_meta("prone", false)) or bool(target.get_meta("sleeping", false)) or target.get("is_prone") == true or target.get("is_sleeping") == true
		var low_now: bool = bool(target.get_meta("crouching", false)) or bool(target.get_meta("sitting", false)) or bool(target.get_meta("saved_sitting", false)) or target.get("is_crouching") == true or target.get("is_sitting") == true
		var top := 0.55 if prone_now else (1.25 if low_now else 1.72)
		is_headshot = hit_pos.y - (target as Node3D).global_position.y >= top - 0.30
	if target == null:
		return
	# Energia residual del proyectil: igual que en el impacto del jugador
	var energy := clampf(projectile.velocity.length() / maxf(projectile.launch_speed, 1.0), 0.45, 1.0)
	var dmg := dmg_base * (2.2 if is_headshot else 1.0) * energy
	# Paridad contra personajes humanos (jugador o superviviente): 55 cuerpo /
	# 120 cabeza en arco y lanza, 18 plano en boleadoras. Las flechas fuera de
	# la cabeza llevan "arco" (no letal: deja como minimo 1 HP); solo "arco_head"
	# puede matar por flecha.
	if is_human_actor and weapon_kind in ["arco", "lanza", "bola"]:
		dmg = 18.0 if is_bola or weapon_kind == "bola" else (120.0 if is_headshot else 55.0)
	if is_bola and target is Node3D:
		target.set_meta("bola_slow_until", Time.get_unix_time_from_system() + 6.0)
	if is_wildlife_tgt:
		if target.has_method("take_damage"):
			target.take_damage(dmg, false, proxy)
		if bool(target.get("_is_dead")):
			_bot_credit_kill(b, target)
			_bot_start_gutting(b, target)
	else:
		var wname := weapon_kind if not weapon_kind.is_empty() else ("rifle" if dmg_base > 100.0 else ("bola" if is_bola else "melee"))
		if wname == "arco" and is_human_actor and is_headshot:
			wname = "arco_head"
		_apply_bot_damage_to_target(b, target, dmg, wname)

func _apply_bot_damage_to_target(b: Dictionary, target: Node3D, amount: float, weapon: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	var bot_id := int(b["bot_id"])
	if target.is_in_group("ai_survivor_bot"):
		var target_bot_id := int(target.get_meta("peer_id", 0))
		# Ignorar fuego amigo accidental: si un proyectil lanzado a un lobo o
		# ciervo roza a otro bot de su misma faccion contra el que NO estaba
		# combatiendo, no desatar una guerra fratricida a muerte.
		if bots.has(target_bot_id) and str(bots[target_bot_id].get("faction", "")) == str(b.get("faction", "")) \
				and b.get("aggro_target") != target and b.get("_s_foe") != target:
			return
		on_bot_damaged(target_bot_id, amount, bot_id, weapon)
		return
	if target.is_in_group("net_player_proxy"):
		var target_pid := int(target.get_meta("peer_id", 0))
		if target_pid > 0 and world.has_method("_net_damage_player"):
			world._net_damage_player(target_pid, amount, bot_id, weapon)
		return
	if target.has_method("apply_damage"):
		target.apply_damage(amount, weapon)
		if weapon in ["rifle", "m4"] and target.has_method("_play_shot_reaction"):
			target._play_shot_reaction()
		elif target.has_method("_play_hit_reaction"):
			target._play_hit_reaction(weapon == "melee")

func on_bot_damaged(bot_id: int, amount: float, attacker_id: int, weapon: String = "melee") -> void:
	if not bots.has(bot_id):
		return
	var _cpt := Time.get_ticks_usec()
	var b: Dictionary = bots[bot_id]
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	var prev_hp := float(proxy.get_meta("proxy_health", 100.0))
	var min_hp := minf(1.0, prev_hp) if (weapon in ["arco", "arco_madera", "arrow", "flecha"] and prev_hp > 0.0) else 0.0
	var hp := maxf(min_hp, prev_hp - amount)
	b["health"] = hp
	proxy.set_meta("proxy_health", hp)
	proxy.set_meta("saved_health", hp)
	# Recibir un impacto descompone la punteria (jugador: _recoil_pitch en
	# _net_apply_damage). La sacudida se recupera con el tiempo.
	var aim_hit := _bot_aim_st(b)
	aim_hit["shock"] = minf(1.8, float(aim_hit["shock"]) + amount / 42.0)

	# Aprendizaje conductual por daño real: registrar riesgo en la zona y, si el
	# atacante es un jugador/bot, actualizar relación social (desconfianza/hostilidad/miedo).
	record_zone_hazard(bot_id, proxy.global_position, _poi_kind_near(proxy.global_position), clampf(amount / 45.0, 0.08, 0.65), attacker_id > 0 and _bot_survivor_combat_cause(weapon))
	if attacker_id > 0:
		b["_last_attacker_id"] = attacker_id
		b["_last_attacker_msec"] = Time.get_ticks_msec()
		b["_last_hit_weapon"] = weapon
		var akey := _actor_persist_key(attacker_id)
		var aname := _actor_display_name(attacker_id)
		record_social_event(bot_id, akey, aname, "attack", clampf(amount / 35.0, 0.10, 0.80), "hit_" + weapon)
	elif weapon in ["wolf_bite", "bear_bite"]:
		b["_last_attacker_id"] = 0
		b["_last_hit_weapon"] = weapon
		if weapon == "wolf_bite":
			b["_wolf_bite_msec"] = Time.get_ticks_msec()
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
			# Lo que sabe del agresor depende del contacto: un zarpazo o un
			# tirador a la vista delatan su sitio; un balazo desde cobertura
			# solo orienta (pista aproximada, no certeza).
			var a_dist := proxy.global_position.distance_to(attacker_node.global_position)
			var a_seen := a_dist <= 8.0 or _has_clear_shot(proxy.global_position, attacker_node.global_position)
			_ai_note_foe_intel(b, attacker_node, attacker_node.global_position, "seen" if a_seen else "heard")
			_command_bot_wolf_against(b, attacker_node)
	# Reescanear sentidos ya: reaccionar al agresor en el proximo tick, no en 0.2 s
	b["sense_t"] = 0.0

	# Reaccion visual sincronizada: el kind va directo a _net_player_hit_event,
	# que ya distingue rifle (sangre + reaccion de disparo), melee, wolf_bite
	# y bear_bite (sangre + reaccion + sonido de dolor).
	var hit_kind := weapon if weapon in ["rifle", "m4", "melee", "wolf_bite", "bear_bite", "bola", "arco", "arco_head", "lanza"] else "melee"
	b["sitting"] = false
	b["sleeping"] = false
	b["crouching"] = false
	b["hide_timer"] = 0.0
	b["flinch_anim"] = "shot" if hit_kind in ["rifle", "m4"] else "hit"
	b["flinch_timer"] = 0.48 if hit_kind in ["rifle", "m4"] else 0.30
	b["anim"] = b["flinch_anim"]
	var net = world.get("net")
	if net != null and net.has_method("_broadcast_player_hit"):
		net._broadcast_player_hit(bot_id, hit_kind, proxy.global_position, true)
	elif world.has_method("_net_player_hit_event"):
		world._net_player_hit_event(bot_id, hit_kind, proxy.global_position)

	if hp <= 0.0:
		_kill_bot(b, "melee" if weapon == "melee" else (weapon if not weapon.is_empty() else "combat"))
	if CombatProf.enabled: CombatProf.mark("bot.on_damaged", _cpt)

# Muerte del superviviente por cualquier causa (impacto letal, mordisco,
# inanicion o deshidratacion): marca el proxy, suelta el loot y sincroniza
# la animacion/cuerpo de muerto como con un jugador real.
func _kill_bot(b: Dictionary, death_kind: String) -> void:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	_loot_clear(b)
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
	record_zone_hazard(bot_id, dp, _poi_kind_near(dp), 0.75, _bot_survivor_combat_cause(death_kind))
	var natural_death := death_kind in ["starved", "dehydrated", "hypothermia", "heatstroke", "exhausted"]
	var recent_hit := Time.get_ticks_msec() - int(b.get("_last_attacker_msec", -999999)) <= 60000
	var killer_id := int(b.get("_last_attacker_id", 0)) if (not natural_death and recent_hit) else 0
	var killer_name := ""
	if killer_id > 0:
		_credit_survivor_kill(killer_id, "kills_bot")
		var kkey := _actor_persist_key(killer_id)
		var kname := _actor_display_name(killer_id)
		killer_name = kname
		record_social_event(bot_id, kkey, kname, "attack", 0.75, "killed_by_" + death_kind)
		# Nemesis: cada muerte a manos del mismo actor suma mas miedo que la
		# anterior — el bot aprende quien es su verdugo habitual.
		var killers: Dictionary = mem.get("killers", {})
		var kr: Dictionary = killers.get(kkey, {"name": kname, "count": 0})
		kr["count"] = int(kr.get("count", 0)) + 1
		kr["name"] = kname
		kr["helped_at_death"] = int(get_bot_relationship(bot_id, kkey).get("helped", 0))
		killers[kkey] = kr
		mem["killers"] = killers
		var krel := get_bot_relationship(bot_id, kkey)
		var fear_add := 0.30 * minf(2.0, 1.0 + float(int(kr.get("count", 1)) - 1) * 0.5)
		krel["fear"] = snappedf(clampf(float(krel.get("fear", 0.0)) + fear_add, 0.0, 1.0), 0.001)
		record_strategy_outcome(bot_id, "scavenge", false, 0.16)
	b["_last_attacker_id"] = 0
	b["_last_attacker_msec"] = 0
	# Quien y como: la ficha de la muerte queda en memoria persistente para el
	# monitor y para que el asesor IA razone sobre su verdugo. El arma solo es
	# fiable si hubo atacante (de lo contrario seria la del combate anterior).
	var death_weapon := str(b.get("_last_hit_weapon", "")) if killer_id > 0 else ""
	b["_last_hit_weapon"] = ""
	mem["last_death_killer"] = killer_name
	mem["last_death_weapon"] = death_weapon if not death_weapon.is_empty() else death_kind
	mem["last_death_unix"] = int(Time.get_unix_time_from_system())
	var dlog: Array = mem.get("death_log", [])
	dlog.append({"by": killer_name, "kind": death_kind, "weapon": mem["last_death_weapon"], "t": int(Time.get_unix_time_from_system())})
	while dlog.size() > 8:
		dlog.pop_front()
	mem["death_log"] = dlog
	# Base comprometida: morir en/junto a su propio campamento quema el solar —
	# la proxima vida monta la base en otro sitio (aprende que lo encontraron).
	var own_camp: Vector3 = b.get("shelter_pos", Vector3.INF)
	if own_camp == Vector3.INF:
		own_camp = b.get("camp_spot", Vector3.INF)
	if own_camp != Vector3.INF and dp.distance_to(own_camp) < 30.0:
		var bad: Array = mem.get("bad_camp_spots", [])
		bad.append({"x": own_camp.x, "y": own_camp.y, "z": own_camp.z})
		while bad.size() > 6:
			bad.pop_front()
		mem["bad_camp_spots"] = bad
		mem["base_raided"] = int(mem.get("base_raided", 0)) + 1
		record_strategy_outcome(bot_id, "fortify_camp", false, 0.10)
	_record_death_lesson(b, mem, death_kind)
	record_bot_event(bot_id, "death", death_kind, _poi_kind_near(dp), dp, "died:" + death_kind)
	_evolve_personality(b, "death", 0.6)
	_ai_save_memory()
	proxy.set_meta("proxy_dead", true)
	proxy.remove_from_group("net_player_proxy")
	proxy.add_to_group("interactable")
	b["anim"] = "dead_melee" if death_kind == "melee" else "dead"
	b["_act"] = "dead"
	b["torch_lit"] = false
	b["is_aiming"] = false
	b["crouching"] = false
	b["sitting"] = false
	b["explore_target"] = Vector3.INF
	b["_ambush"] = {}
	b["_meet_id"] = 0
	b["_meet_promise"] = {}
	b["team_leader_id"] = 0
	proxy.set_meta("team_leader_id", 0)
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

# Aprendizaje especifico por causa de muerte: cada muerte deja una adaptacion
# conductual concreta (sed, hambre, depredadores, combate o frio) que modifica
# umbrales de reaccion, radios de alerta, estrategias y rasgos en siguientes vidas.
func _record_death_lesson(b: Dictionary, mem: Dictionary, death_kind: String) -> void:
	var bid := int(b.get("bot_id", 901))
	var lessons: Dictionary = mem.get("death_lessons", {})
	var p := _get_bot_personality(b)
	var base_p := _default_personality_for_bot(bid, b.get("cfg", {}))
	var cat := "combat"
	match death_kind:
		"dehydrated":
			cat = "dehydrated"
			_adjust_trait(p, "survival_instinct", 0.04, float(base_p["survival_instinct"]))
			_adjust_trait(p, "curiosity", 0.03, float(base_p["curiosity"]))
			_reinforce_survival_strategy(bid, "forage", 0.14)
			_record_milestone(bid, "learned_hydration")
		"starved":
			cat = "starved"
			_adjust_trait(p, "survival_instinct", 0.04, float(base_p["survival_instinct"]))
			_adjust_trait(p, "curiosity", 0.03, float(base_p["curiosity"]))
			_reinforce_survival_strategy(bid, "forage", 0.16)
			_reinforce_survival_strategy(bid, "hunt", 0.12)
			_record_milestone(bid, "learned_foraging")
		"wolf_bite", "bear_bite":
			cat = "predator"
			_adjust_trait(p, "survival_instinct", 0.05, float(base_p["survival_instinct"]))
			_adjust_trait(p, "bravery", -0.03, float(base_p["bravery"]))
			_reinforce_survival_strategy(bid, "fortify_camp", 0.14)
			_record_milestone(bid, "learned_predator_evasion")
		"hypothermia", "exhausted":
			cat = "cold"
			_adjust_trait(p, "survival_instinct", 0.04, float(base_p["survival_instinct"]))
			_reinforce_survival_strategy(bid, "fortify_camp", 0.15)
			_record_milestone(bid, "learned_shelter_warmth")
		"bled", "sick":
			# Desangrado/enfermo: aprende a tratar sus heridas a tiempo —
			# el umbral de vendaje sube con lecciones "medical".
			cat = "medical"
			_adjust_trait(p, "survival_instinct", 0.05, float(base_p["survival_instinct"]))
			_reinforce_survival_strategy(bid, "fortify_camp", 0.10)
			_record_milestone(bid, "learned_first_aid")
		"rifle", "bola", "arco", "arco_head", "arco_madera", "arrow", "lanza":
			# Muerte a distancia: aprende a desconfiar, a no cruzar campo
			# abierto de dia y a cubrir/camuflar su campamento.
			cat = "ranged"
			_adjust_trait(p, "distrust", 0.06, float(base_p["distrust"]))
			_adjust_trait(p, "bravery", -0.03, float(base_p["bravery"]))
			_adjust_trait(p, "survival_instinct", 0.04, float(base_p["survival_instinct"]))
			_reinforce_survival_strategy(bid, "avoid_zone", 0.12)
			_reinforce_survival_strategy(bid, "fortify_camp", 0.10)
			_record_milestone(bid, "learned_ranged_threat")
		_:
			cat = "combat"
			_adjust_trait(p, "survival_instinct", 0.04, float(base_p["survival_instinct"]))
			_adjust_trait(p, "distrust", 0.04, float(base_p["distrust"]))
			_reinforce_survival_strategy(bid, "explore_military", 0.12)
			_record_milestone(bid, "learned_combat_tactics")
	lessons[cat] = int(lessons.get(cat, 0)) + 1
	mem["death_lessons"] = lessons
	b["personality"] = p

func _bot_death_adaptations(mem: Dictionary) -> Array:
	var lessons: Dictionary = mem.get("death_lessons", {})
	var out: Array = []
	var deh := int(lessons.get("dehydrated", 0))
	if deh > 0:
		out.append("💧 Hidratación preventiva (+%d%% umbral, reserva ×%d, bebe al pasar por agua)" % [mini(18, deh * 6), 1 + mini(2, deh)])
	var stv := int(lessons.get("starved", 0))
	if stv > 0:
		out.append("🍄 Forrajeo temprano (+%d%% umbral, reserva ×%d comida encima)" % [mini(18, stv * 6), 1 + mini(2, stv)])
	var prd := int(lessons.get("predator", 0))
	if prd > 0:
		out.append("🐺 Alerta anti-depredadores (+%d m radio de detección)" % mini(12, prd * 4))
	var cmb := int(lessons.get("combat", 0))
	if cmb > 0:
		out.append("🛡 Táctica de combate (repliegue a <%d HP)" % (30 + mini(15, cmb * 5)))
	var rng := int(lessons.get("ranged", 0))
	if rng > 0:
		out.append("🎯 Precaución anti-tirador (zigzag al cargar, repliegue antes, desconfía ×%d)" % mini(3, rng + 1))
	var med := int(lessons.get("medical", 0))
	if med > 0:
		out.append("🩸 Autocuidado (venda al <%d%% HP, crudo solo con margen)" % int(72.0 + mini(12, cmb * 4) + mini(10, med * 5)))
	var killers_m: Dictionary = mem.get("killers", {})
	var nem_c := 0
	for k2 in killers_m.values():
		if k2 is Dictionary and int((k2 as Dictionary).get("count", 0)) > 0:
			nem_c += 1
	if nem_c > 0:
		out.append("⚠ Reconoce a sus verdugos (%d) y evita pelear sin ventaja" % nem_c)
	var cld := int(lessons.get("cold", 0))
	if cld > 0:
		out.append("🔥 Prioridad térmica (abrigo y fogata temprana)")
	var experience: Dictionary = mem.get("experience", {})
	var cover_level := int(experience.get("cover", 0))
	if cover_level > 0:
		out.append("Cobertura aprendida %d/3: ante un tirador busca protección por debajo de %d de salud, sin esperar otro impacto" % [cover_level, 45+5*cover_level])
	var forage_level := int(experience.get("forage", 0))
	if forage_level > 0:
		out.append("Recolección aprendida %d/3: busca comida con %d puntos más de reserva" % [forage_level, 4*forage_level])
	var raided := int(mem.get("base_raided", 0))
	if raided > 0:
		out.append("🏚 Base quemada ×%d (se mudó a zona alejada)" % raided)
	return out

func _bot_desired_drink_cap(b: Dictionary) -> int:
	var dl: Dictionary = b.get("_mem", {}).get("death_lessons", {}) if b.get("_mem") is Dictionary else {}
	return 1 + mini(2, int(dl.get("dehydrated", 0)))

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
	PlanManager.finish(b, b.get("ai_directive", {}), "FAILED", "actor_dead", Time.get_ticks_msec())
	b.get("_mem", {})["pending_goals"] = []
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
	# Estado del asesor: el bot reaparecido no hereda firma ni agenda — la
	# primera pasada del sondeo detecta situacion nueva y pide plan fresco.
	_ai_last_sig.erase(bot_id)
	_ai_last_call_msec.erase(bot_id)
	_ai_next_at.erase(bot_id)
	_spawn_bot(cfg)

func _resolve_team_leader(b: Dictionary) -> Node3D:
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0 or lid == int(b.get("bot_id", 0)):
		return null
	# Si el supuesto lider bot sigue a su vez a este mismo bot (ciclo A<->B),
	# el de mayor liderazgo actua como raiz libre en el acto sin esperar al
	# ciclo social de 3.5 s, evitando que ambos se queden mirandose quietos.
	if bots.has(lid):
		var lb: Dictionary = bots[lid]
		var llid := int(lb.get("team_leader_id", 0))
		if llid == int(b.get("bot_id", 0)) and _bot_lead_score(b) >= _bot_lead_score(lb):
			b["team_leader_id"] = 0
			var prx: Node3D = b.get("proxy")
			if prx != null and is_instance_valid(prx):
				prx.set_meta("team_leader_id", 0)
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

	# Reincorporacion tras la siesta de emergencia: aviso una sola vez, al
	# volver a la marcha. team_leader_id nunca se borro — sigue siendo suyo.
	if bool(b.get("_rest_rejoin", false)):
		b["_rest_rejoin"] = false
		var lid_r := int(b.get("team_leader_id", 0))
		if lid_r > 0 and not is_bot_peer_id(lid_r):
			_bot_chat_send(b, lid_r, _actor_display_name(lid_r), "Ya estoy, descanse lo justo. Sigo con vosotros.", "rest")

	b["sitting"] = false
	b["crouching"] = bool(leader.get("is_crouching") == true or leader.get_meta("crouching", false) == true) or _bot_roof_wary(b)
	var lpos := leader.global_position
	var cur := proxy.global_position
	var dist := cur.distance_to(lpos)
	var step_wp := _resolve_building_interior_waypoint(b, cur, lpos)
	var separated_by_structure: bool = step_wp != lpos or absf(cur.y - lpos.y) > 1.3
	# Vigia del equipo: saqueando la ciudad/base militar, el miembro con mejor
	# arma a distancia se apuesta en el puesto elevado de la zona en vez de
	# pegarse al lider ni perseguir botin.
	if _bot_overwatch_tick(b, leader, cur, lpos, delta):
		return
	# Antes de reengancharse a la espalda del líder: con el líder QUIETO el
	# seguidor no vive pegado a él — recoge el botín de la zona de escolta
	# (<=16 m) y hace rondas de vigilancia. Líder en marcha (sprint, su
	# propio anim de paso o desplazamiento real) = seguirle, sin recados.
	var leader_moving := bool(leader.get("is_sprinting") == true or leader.get_meta("sprinting", false) == true) \
		or str(leader.get_meta("anim", "")) in ["walk", "run", "riflewalk", "riflerun", "sneak_walk", "stairs", "climb"]
	if leader_moving:
		var esc0: Dictionary = b.get("_escort", {})
		esc0["pos"] = null
		esc0["idle_t"] = 0.0
		b["_escort"] = esc0
	if not separated_by_structure:
		var nearby_loot: Dictionary = b.get("_s_loot", {})
		if not nearby_loot.is_empty():
			var lp := _loot_entry_pos(nearby_loot)
			var d_nl := Vector2(cur.x - lp.x, cur.z - lp.z).length()
			var loot_reach := _bot_can_reach_loot(cur, lp)
			if loot_reach:
				_stop_bot_motion(b)
				_collect_loot_entry(b, nearby_loot)
				return
			# Botin de camino o de la zona de escolta: desvio corto (<=4 m) si
			# el leader va en marcha, recado completo si esta quieto — el rol
			# marca el radio: el soldado no abandona la guardia por chatarra.
			var idle_grab := 16.0
			var grab_role := _bot_member_role(b)
			if grab_role == "soldier":
				idle_grab = 10.0
			elif grab_role == "scout":
				idle_grab = 20.0
			elif grab_role == "forager":
				idle_grab = 18.0
			var grab_limit := 4.0 if leader_moving else idle_grab
			if d_nl <= grab_limit and absf(cur.y - lp.y) <= 1.8 and dist <= 20.0:
				_move_bot_towards(b, lp, 4.2, delta, "walk")
				return
		if not leader_moving and _bot_escort_patrol(b, leader, delta):
			return
	# Con amenaza a la vista el escolta no se mueve a su puesto de formacion:
	# se queda quieto junto al lider listo para reaccionar.
	if (b.get("aggro_target") != null or float(b.get("hide_timer", 0.0)) > 0.0) and dist <= 6.0 and not separated_by_structure:
		b["anim"] = "idle"
		return
	# En marcha la escolta va en formacion de cuña: cada miembro cubre su slot
	# separado del lider (nada de fila india pegada a su espalda). La cuña es
	# tactica de campo abierto — en interiores (casa, piso compartido) o con
	# muro/escalera de por medio se va directo a la posicion real del lider.
	var in_close := _pos_in_house_bounds(lpos) or _pos_in_house_bounds(cur)
	var fgoal := lpos if (separated_by_structure or in_close) else _bot_formation_slot(b, leader, lpos)
	var d_goal := Vector2(cur.x - fgoal.x, cur.z - fgoal.z).length()
	# Separado del lider por un muro/piso y sin progreso real hacia el: la
	# ruta por puertas/escaleras se sigue intentando, pero si ~25 s no le
	# acercan nada (puerta que no abre, vano inalcanzable), deja de empujar
	# la pared y monta guardia fuera — quieto o en rondas cortas.
	if separated_by_structure and not leader_moving and dist <= 14.0:
		if dist < float(b.get("_follow_sep_d", INF)) - 0.15:
			b["_follow_sep_d"] = dist
			b["_follow_stall"] = 0.0
		else:
			b["_follow_stall"] = float(b.get("_follow_stall", 0.0)) + delta
			if float(b["_follow_stall"]) > 25.0:
				if _bot_escort_patrol(b, leader, delta):
					return
				b["anim"] = "idle"
				return
	else:
		b["_follow_sep_d"] = INF
		b["_follow_stall"] = 0.0
	if d_goal > 1.7 or separated_by_structure:
		var leader_sprinting: bool = bool(leader.get("is_sprinting") == true or leader.get_meta("sprinting", false) == true)
		var should_run: bool = not bool(b.get("crouching", false)) and (d_goal > 7.0 or (d_goal > 3.0 and leader_sprinting))
		var spd := 6.8 if should_run else 4.2
		var clip := "run" if should_run else "walk"
		_move_bot_towards(b, fgoal, spd, delta, clip)
	else:
		b["anim"] = "idle"

# Escolta viva: con el líder parado el seguidor no se apila sobre su
# posición — hace rondas cortas de vigilancia (6-14 m alrededor del líder,
# con pausas) y vuelve. La ronda se corta si el líder se aleja, hay amenaza
# o el escolta va agachado (sigilo compartido). RNG local por bot para no
# tocar el azar global del mundo.
func _bot_escort_patrol(b: Dictionary, leader: Node3D, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	if b.get("aggro_target") != null or float(b.get("hide_timer", 0.0)) > 0.0:
		return false
	if bool(b.get("crouching", false)) or bool(b.get("sleeping", false)):
		return false
	var lpos := leader.global_position
	var dist := proxy.global_position.distance_to(lpos)
	var esc: Dictionary = b.get("_escort", {})
	# Si el líder se fue o el propio bot se movió haciendo otra cosa desde la
	# última llamada (persecución, loot, huida), la calma y el punto mueren.
	var lp: Variant = esc.get("last_pos", null)
	if lp is Vector3 and (lp as Vector3).distance_to(proxy.global_position) > 4.0:
		esc["idle_t"] = 0.0
		esc["pos"] = null
	var llp: Variant = esc.get("last_leader", null)
	if llp is Vector3 and (llp as Vector3).distance_to(lpos) > 8.0:
		esc["pos"] = null
	esc["last_pos"] = proxy.global_position
	esc["last_leader"] = lpos
	if dist > 20.0:
		esc["pos"] = null
		b["_escort"] = esc
		return false
	# El rol marca el radio de la ronda: el explorador barre lejos, el
	# proveedor medio y el soldado cierra la guardia pegado al lider.
	var role_esc := _bot_member_role(b)
	var rmin := 6.0
	var rmax := 14.0
	if role_esc == "soldier":
		rmin = 4.0
		rmax = 9.0
	elif role_esc == "scout":
		rmin = 10.0
		rmax = 22.0
	elif role_esc == "forager":
		rmin = 7.0
		rmax = 16.0
	var tgt: Variant = esc.get("pos", null)
	var has_tgt: bool = tgt is Vector3 and Vector2(proxy.global_position.x - (tgt as Vector3).x, proxy.global_position.z - (tgt as Vector3).z).length() > 1.6 \
		and Vector2(lpos.x - (tgt as Vector3).x, lpos.z - (tgt as Vector3).z).length() <= rmax + 4.0
	if not has_tgt:
		# ~9 s apostado en su puesto de formacion antes de cada ronda: vigia
		# periodica, no paseo continuo — en marcha detras del lider no crece.
		if dist > 9.0:
			esc["idle_t"] = 0.0
			b["_escort"] = esc
			return false
		esc["idle_t"] = float(esc.get("idle_t", 0.0)) + delta
		if float(esc["idle_t"]) < 9.0:
			b["_escort"] = esc
			return false
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b["bot_id"]) * 15485863 + int(esc.get("n", 0)) * 32452843
		for i in range(6):
			var ang := rng.randf() * TAU
			var rr := rng.randf_range(rmin, rmax)
			var cand := lpos + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
			cand.y = proxy.global_position.y
			if _is_step_blocked(proxy.global_position, cand) or _is_goal_blacklisted(b, cand):
				continue
			esc["pos"] = cand
			esc["n"] = int(esc.get("n", 0)) + 1
			esc["idle_t"] = 0.0
			b["_escort"] = esc
			has_tgt = true
			break
		if not has_tgt:
			b["_escort"] = esc
			return false
		tgt = esc["pos"]
	var tp: Vector3 = tgt
	_move_bot_towards(b, tp, 3.2, delta, "walk")
	if Vector2(proxy.global_position.x - tp.x, proxy.global_position.z - tp.z).length() <= 1.6:
		esc["pos"] = null
		esc["idle_t"] = 0.0
		b["_escort"] = esc
	return true

# La directiva de la IA (qwen/cerebro local) tambien manda sobre los
# followers — pero solo dentro de la orbita del leader: un encargo 'pos'
# cercano se devuelve como recado lateral que el pipeline normal ejecuta
# (explore/loot con la directiva como destino), fuera del radio se ignora —
# el leader decide el destino macro del equipo.
const BOT_ESCORT_AI_DIST := 45.0

func _bot_ai_errand_target(b: Dictionary, leader: Node3D) -> Vector3:
	var d := _ai_active_directive(b)
	if d.is_empty() or str(d.get("mode", "")) != "pos":
		return Vector3.INF
	var dp = d.get("pos")
	if not (dp is Vector3) or (dp as Vector3) == Vector3.INF:
		return Vector3.INF
	if _is_goal_blacklisted(b, dp):
		return Vector3.INF
	var lpos := leader.global_position if leader != null and is_instance_valid(leader) else Vector3.INF
	var ai_dist := 62.0 if _bot_member_role(b) == "scout" else BOT_ESCORT_AI_DIST
	if lpos == Vector3.INF or Vector2((dp as Vector3).x - lpos.x, (dp as Vector3).z - lpos.z).length() > ai_dist:
		return Vector3.INF
	return dp

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
const BOT_HELP_PROMISE_MS := 120000   # un auxilio prometido caduca si en 2 min no llego
# Radio del "iman social": dentro de el un bot libre y sociable viaja a
# reunirse con un aliado potencial en vez de dejar el encuentro al azar.
const BOT_TEAM_MEET_DIST := 450.0
const BOT_AMBUSH_STRIKE_RANGED := 12.5
const BOT_AMBUSH_STRIKE_MELEE := 6.0
const BOT_AMBUSH_ABORT_DIST := 90.0
const BOT_AMBUSH_MAX_SECONDS := 24.0
const BOT_AMBUSH_LOST_MSEC := 14000 # sin ver ni oir a la presa: se acabo

func _bot_lead_score(b: Dictionary) -> float:
	var pers: Dictionary = _ensure_bot_memory(int(b["bot_id"])).get("personality", {})
	return float(pers.get("bravery", 0.5)) + float(pers.get("cooperation", 0.5)) - float(int(b.get("bot_id", 0))) * 0.0001

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

# Rol de cada miembro segun sus habilidades (personalidad): scout/explorador
# para el mas curioso, soldier/soldado para el mas agresivo y valiente,
# forager/proveedor para el de mayor instinto y cooperacion. Asignacion
# determinista y unica dentro del equipo — el rol decide cuanto se separa,
# cuanto botin agarra de camino y que puesto ocupa en la formacion.
func _bot_member_role(b: Dictionary) -> String:
	var my_id := int(b.get("bot_id", 0))
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0:
		return "lider" if _bot_team_role(b) == "leader" else ""
	var members: Array = []
	for bid in bots.keys():
		if int(bots[bid].get("team_leader_id", 0)) == lid:
			members.append(bid)
	members.sort()
	var scores := {}
	for bid in members:
		var p: Dictionary = (bots[bid].get("_mem", {}) as Dictionary).get("personality", {})
		scores[bid] = {
			"scout": float(p.get("curiosity", 0.5)) + float(p.get("survival_instinct", 0.5)) * 0.35,
			"soldier": float(p.get("bravery", 0.5)) * 0.6 + float(p.get("aggression", 0.5)) * 0.6 + float(p.get("distrust", 0.5)) * 0.2,
			"forager": float(p.get("survival_instinct", 0.5)) * 0.6 + float(p.get("cooperation", 0.5)) * 0.5,
		}
	var assigned := {}
	var pool := members.duplicate()
	var roles_left := ["scout", "soldier", "forager"]
	while not pool.is_empty() and not roles_left.is_empty():
		var best_s := -INF
		var best_b := -1
		var best_r := ""
		for bid in pool:
			for r in roles_left:
				var s: float = (scores[bid] as Dictionary).get(r, 0.0)
				if s > best_s:
					best_s = s
					best_b = bid
					best_r = r
		assigned[best_b] = best_r
		pool.erase(best_b)
		roles_left.erase(best_r)
	return str(assigned.get(my_id, "member"))

# Punto dentro del rectangulo de una casa registrada (wildlife_blockers) —
# la cuña de escolta no se usa en interiores, solo en campo abierto.
func _pos_in_house_bounds(pos: Vector3) -> bool:
	if world != null and "wildlife_blockers" in world:
		var p2 := Vector2(pos.x, pos.z)
		for blk in world.wildlife_blockers:
			if blk is Dictionary and (blk as Dictionary).has("house_bounds") \
					and ((blk as Dictionary)["house_bounds"] as Rect2).has_point(p2):
				return true
	return world != null and world.has_method("_is_player_in_house") and bool(world._is_player_in_house(pos))

# Orden deterministico del miembro dentro de la escolta del lider (0, 1...).
func _bot_member_index(b: Dictionary) -> int:
	var lid := int(b.get("team_leader_id", 0))
	var my_id := int(b.get("bot_id", 0))
	var idx := 0
	for bid in bots.keys():
		if int(bid) != my_id and int(bots[bid].get("team_leader_id", 0)) == lid and int(bid) < my_id:
			idx += 1
	return idx

# Zona con puestos de vigia elevados donde el grupo puede estar saqueando:
# "city" = bloque urbano (azoteas + Torre del Reloj) y "military" = la base
# de la cima con su torre de vigilancia.
func _bot_leader_watch_zone(lpos: Vector3) -> String:
	if Rect2(CityExpansion.CENTER.x-45.0, CityExpansion.CENTER.z-45.0, 190.0, 190.0).has_point(Vector2(lpos.x,lpos.z)):
		return "city"
	if Vector2(lpos.x,lpos.z).distance_to(HighMountainZone.SUMMIT_CENTER) < 48.0 and lpos.y > 50.0:
		return "summit"
	if world != null:
		var wtc = world.get("_watchtower_climb")
		if wtc is Array and not (wtc as Array).is_empty():
			var foot: Vector3 = (wtc as Array)[0]
			if Vector2(lpos.x - foot.x, lpos.z - foot.z).length() <= 60.0:
				return "military"
	return ""

# El mejor puesto de vigia de la zona: la azotea de la Torre del Reloj domina
# todo el pueblo; en la base militar, la cubierta de su torre de vigilancia.
func _bot_overwatch_post(zone: String) -> Vector3:
	match zone:
		"summit":
			return ElevationRoutes.summit_routes()[0]["points"].back()
		"city":
			return Vector3(39.6, 29.46, 750.8) # azotea de la Torre del Reloj
		"military":
			if world != null:
				var wtc = world.get("_watchtower_climb")
				if wtc is Array and (wtc as Array).size() >= 2:
					return (wtc as Array)[(wtc as Array).size() - 1]
	return Vector3.INF

# Elegible para cubrir al equipo: rol de soldado/explorador (o unico
# miembro), arma a distancia en mano, necesidades cubiertas, sin amenaza
# inmediata y de dia o con luz.
func _bot_watch_eligible(b: Dictionary) -> bool:
	if str(b.get("follow_mode", "follow")) != "follow":
		return false
	var proxy: Node3D = b["proxy"]
	if not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)) or bool(b.get("sleeping", false)):
		return false
	if not _bot_has_ranged_weapon(proxy):
		return false
	if float(b.get("hunger", 100.0)) < 30.0 or float(b.get("thirst", 100.0)) < 26.0 or float(b.get("health", 100.0)) < 42.0:
		return false
	if b.get("aggro_target") != null or float(b.get("flee_until", 0.0)) > 0.0 or float(b.get("hide_timer", 0.0)) > 0.0:
		return false
	if _is_world_night() and not bool(b.get("torch_lit", false)):
		return false
	var role := _bot_member_role(b)
	if _bot_member_index(b) > 0 and role not in ["soldier", "scout"]:
		return false
	return true

# Orden entre los elegibles del equipo: el fusil vigila primero (rango 0 =
# mejor tirador); a igualdad de arma decide el id menor. Reparte los puestos:
# la azotea es del rango 0 y el centinela de tierra del siguiente.
func _bot_watch_rank(b: Dictionary) -> int:
	var lid := int(b.get("team_leader_id", 0))
	var ids: Array = []
	for bid in bots.keys():
		var ob: Dictionary = bots[bid]
		if int(ob.get("team_leader_id", 0)) != lid:
			continue
		if not _bot_watch_eligible(ob):
			continue
		ids.append(int(bid))
	ids.sort_custom(func(x: int, y: int) -> bool:
		var bx: Dictionary = bots.get(x, {})
		var by2: Dictionary = bots.get(y, {})
		if bool(bx.get("has_rifle", false)) != bool(by2.get("has_rifle", false)):
			return bool(bx.get("has_rifle", false))
		return x < y)
	return ids.find(int(b["bot_id"]))

const BOT_OVERWATCH_MAX_POST_DIST := 95.0
const BOT_SENTRY_MAX_POST_DIST := 70.0

# Puesto del centinela de tierra: perimetro a ~11 m del lider por el lado
# opuesto al ancla de la amenaza (centro urbano, pie de torre o punto donde
# se registro el peligro) — cubre la aproximacion mas expuesta mientras el
# resto lootea. El segundo centinela barre otro sector.
func _bot_ground_sentry_post(b: Dictionary, zone: String, rank: int, lpos: Vector3, anchor: Vector3) -> Vector3:
	var base := anchor
	if base == Vector3.INF:
		if zone == "city":
			base = Vector3(CityExpansion.CENTER.x, lpos.y, CityExpansion.CENTER.z)
		elif zone == "military" and world != null:
			var wtc = world.get("_watchtower_climb")
			if wtc is Array and not (wtc as Array).is_empty():
				base = (wtc as Array)[0]
	if base == Vector3.INF:
		base = lpos
	var dir := Vector2(lpos.x - base.x, lpos.z - base.z)
	if dir.length_squared() < 4.0:
		var a0 := float(int(b["bot_id"])) * 2.399963
		dir = Vector2(sin(a0), cos(a0))
	dir = dir.normalized()
	if rank > 0:
		dir = dir.rotated(2.1 * float(rank))
	var post := lpos + Vector3(dir.x, 0.0, dir.y) * 11.0
	post.y = _ground_y(post.x, post.z, lpos.y)
	return post

# Vigia del equipo: cuando el grupo entra a saquear la ciudad o la base
# militar, el mejor tirador sube al puesto elevado de la zona (azotea de la
# Torre del Reloj o torre de vigilancia) y un segundo miembro con arma hace
# de centinela a ras de suelo en el perimetro. Sin azotea, el mejor va a
# tierra. En una zona con riesgo aprendido (muertes violentas previas) el
# centinela se postula aunque el lugar no tenga puestos elevados. Se libera
# cuando el lider sale de la zona, le atacan o aprietan las necesidades.
# Devuelve true si el tick quedo consumido.
func _bot_overwatch_tick(b: Dictionary, leader: Node3D, cur: Vector3, lpos: Vector3, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var ov: Dictionary = b.get("_overwatch", {})
	if not ov.is_empty():
		var zone := str(ov.get("zone", ""))
		var post: Vector3 = ov.get("post", Vector3.INF)
		var release := post == Vector3.INF
		if not release:
			if bool(ov.get("ground", false)) or zone == "ground":
				var anc: Vector3 = ov.get("anchor", Vector3.INF)
				release = Vector2(lpos.x - post.x, lpos.z - post.z).length() > 32.0 \
					or (anc != Vector3.INF and Vector2(lpos.x - anc.x, lpos.z - anc.z).length() > 75.0)
			else:
				release = _bot_leader_watch_zone(lpos) != zone
		release = release or b.get("aggro_target") != null or _bot_vital_break(b) \
				or float(b.get("hunger", 100.0)) < 24.0 or float(b.get("thirst", 100.0)) < 20.0 \
				or (_is_world_night() and not bool(b.get("torch_lit", false)))
		if release:
			b.erase("_overwatch")
			return false
		var d_post := Vector2(cur.x - post.x, cur.z - post.z).length()
		b["_act"] = "overwatch"
		if d_post > 1.5 or absf(cur.y - post.y) > 1.0:
			_move_bot_towards(b, post, 5.0, delta, "walk")
		else:
			# En puesto: barrer la plaza con la mirada y el arma a punto. El
			# centinela de tierra mira hacia fuera, la azotea hacia el centro.
			b["sitting"] = false
			b["anim"] = "idle"
			var ground_post := bool(ov.get("ground", false))
			var look: Vector3
			if ground_post:
				look = cur - lpos
			else:
				var anchor := _bot_leader_watch_zone(lpos)
				look = (Vector3(CityExpansion.CENTER.x, cur.y, CityExpansion.CENTER.z) if anchor == "city" else post) - cur
			look.y = 0.0
			if look.length_squared() > 0.01:
				var want := atan2(-look.x, -look.z) + sin(float(Time.get_ticks_msec()) / 2600.0 + float(int(b["bot_id"]))) * 0.55
				b["rot"] = lerp_angle(float(b["rot"]), want, minf(1.0, delta * 3.0))
				proxy.rotation.y = float(b["rot"])
		return true
	if not _bot_watch_eligible(b):
		return false
	var zone2 := _bot_leader_watch_zone(lpos)
	var anchor2 := Vector3.INF
	if zone2.is_empty():
		# Sin puestos elevados ni zona tactica: el riesgo aprendido cerca del
		# lider (alguien cayo aqui a tiros antes) basta para apostar centinela.
		anchor2 = _bot_learned_risk_at(lpos, int(b["bot_id"]))
		if anchor2 != Vector3.INF:
			zone2 = "ground"
	if zone2.is_empty():
		return false
	var roof := _bot_overwatch_post(zone2)
	if roof != Vector3.INF and Vector2(cur.x - roof.x, cur.z - roof.z).length() > BOT_OVERWATCH_MAX_POST_DIST:
		roof = Vector3.INF # A far roof must not suppress the nearby ground sentry.
	var rank := _bot_watch_rank(b)
	var post_pos := Vector3.INF
	var ground := false
	if rank == 0:
		if roof != Vector3.INF:
			post_pos = roof
		else:
			post_pos = _bot_ground_sentry_post(b, zone2, rank, lpos, anchor2)
			ground = true
	elif rank == 1 and roof != Vector3.INF:
		# Con la azotea ocupada, el segundo tirador hace de centinela de tierra.
		post_pos = _bot_ground_sentry_post(b, zone2, rank, lpos, anchor2)
		ground = true
	if post_pos == Vector3.INF:
		return false
	var max_d: float = BOT_SENTRY_MAX_POST_DIST if ground else BOT_OVERWATCH_MAX_POST_DIST
	if Vector2(cur.x - post_pos.x, cur.z - post_pos.z).length() > max_d:
		return false
	b["_overwatch"] = {"zone": zone2, "post": post_pos, "anchor": anchor2, "ground": ground, "t": Time.get_ticks_msec()}
	b["_act"] = "overwatch"
	record_bot_event(int(b["bot_id"]), "overwatch", str(leader.get_meta("bot_name", leader.name)), _poi_kind_near(post_pos), post_pos,
		("centinela de tierra cubriendo el saqueo" if ground else "sube al puesto de vigia a cubrir el saqueo"))
	_move_bot_towards(b, post_pos, 5.0, delta, "walk")
	return true

# El francotirador apostado no baja de su puesto para perseguir: gira, apunta
# y dispara desde arriba. Si el enemigo le llega a cuerpo a cuerpo o solo
# lleva melee, suelta el puesto y pelea normal. Se llama desde la rama de
# combate DESPUES de los chequeos de retirada (herido grave si huye).
func _bot_overwatch_fight(b: Dictionary, foe: Node3D, delta: float) -> bool:
	var ov: Dictionary = b.get("_overwatch", {})
	if ov.is_empty():
		return false
	var post: Vector3 = ov.get("post", Vector3.INF)
	if post == Vector3.INF:
		return false
	var proxy: Node3D = b["proxy"]
	var cur := proxy.global_position
	if Vector2(cur.x - post.x, cur.z - post.z).length() > 2.2 or absf(cur.y - post.y) > 1.6:
		return false # todavia de camino al puesto: combate normal
	var dist := cur.distance_to(foe.global_position)
	var pick := _pick_fight_weapon(b, dist)
	var wkind := str(pick.get("kind", "melee"))
	if wkind == "melee" or dist < 4.0:
		b.erase("_overwatch")
		return false
	var weapon := str(pick.get("name", "Cuchillo"))
	b["held_item"] = weapon
	b["has_rifle"] = wkind == "rifle"
	proxy.set_meta("saved_held_item", weapon)
	b["sitting"] = false
	b["crouching"] = false
	# Francotirador apostado con fusil: se tumba — postura de maxima
	# estabilidad (0.12 vs 0.28/1.0), la que usaria un jugador humano para
	# el tiro largo desde un puesto. Sin fusil (arco/arrojadizas) no aplica.
	b["prone"] = wkind == "rifle"
	proxy.set_meta("prone", bool(b["prone"]))
	b["_act"] = "overwatch"
	b["anim"] = "idle"
	var to_foe := foe.global_position - cur
	to_foe.y = 0.0
	if to_foe.length_squared() > 0.001:
		b["rot"] = atan2(-to_foe.x, -to_foe.z)
		proxy.rotation.y = float(b["rot"])
	var clear := _has_clear_shot(cur, foe.global_position)
	b["is_aiming"] = clear
	var ow_kind := "m4" if weapon == "Fusil de asalto" else ("sniper" if wkind == "rifle" else wkind)
	var ow_ready := _bot_fire_ready(b, foe, dist, clear, delta, ow_kind)
	if ow_ready and float(b["shoot_cooldown"]) <= 0.0:
		match wkind:
			"rifle":
				b["shoot_cooldown"] = (1.15 if weapon == "Fusil de asalto" else 1.85) + randf_range(0.0, 0.45)
				_bot_fire_rifle_at(b, foe, 26.0 if weapon == "Fusil de asalto" else 48.0, weapon)
			"bow":
				b["shoot_cooldown"] = 1.55 if weapon == "Arco reforzado" else 1.9
				_bot_fire_bow(b, foe, weapon)
			"thrown", "bola":
				b["shoot_cooldown"] = 2.6 if wkind == "bola" else 2.1
				_bot_fire_thrown(b, foe, weapon, wkind == "bola")
	return true

# Formacion tactica de marcha: cada miembro ocupa un slot separado respecto al
# vector de avance del lider — el explorador va adelantado al flanco, el
# soldado cubre la retaguardia derecha y el proveedor la izquierda, a 6-9 m
# entre si. Nada de columna pegada a la espalda del lider. Slot tapado por
# obstaculo -> se prueba el lado espejo -> como ultimo recurso el propio lpos.
func _bot_formation_slot(b: Dictionary, leader: Node3D, lpos: Vector3) -> Vector3:
	var proxy: Node3D = b["proxy"]
	var dir := Vector3(-sin(leader.rotation.y), 0.0, -cos(leader.rotation.y))
	var esc: Dictionary = b.get("_escort", {})
	var lprev: Variant = esc.get("ldir_pos", null)
	if lprev is Vector3:
		var dm := lpos - (lprev as Vector3)
		dm.y = 0.0
		if dm.length() > 0.15:
			dir = dm.normalized()
	esc["ldir_pos"] = lpos
	b["_escort"] = esc
	var right := Vector3(-dir.z, 0.0, dir.x)
	var off := Vector3.ZERO
	match _bot_member_role(b):
		"scout":
			off = dir * 5.2 - right * 3.0
		"soldier":
			off = -dir * 3.8 + right * 3.4
		"forager":
			off = -dir * 4.8 - right * 4.2
		_:
			off = -dir * 4.4 + right * (3.6 if _bot_member_index(b) % 2 == 0 else -3.6)
	var cand := lpos + off
	cand.y = proxy.global_position.y
	if _is_step_blocked(proxy.global_position, cand) or _is_goal_blacklisted(b, cand):
		var side := off.dot(right)
		cand = lpos + (off - right * 2.0 * side)
		cand.y = proxy.global_position.y
		if _is_step_blocked(proxy.global_position, cand) or _is_goal_blacklisted(b, cand):
			cand = lpos
	return cand

# Auxilio prometido por chat (_meet_promise): mientras el _meet_id siga vivo
# y dentro del plazo la promesa esta en marcha. Si se pierde antes de llegar
# (cambio de plan, orden, caducidad), el "ya voy" quedo en palabras — el que
# pedia socorro lo apunta como negativa, igual que un "no" explicito.
func _meet_promise_check(b: Dictionary) -> void:
	var promise: Dictionary = b.get("_meet_promise", {})
	if promise.is_empty():
		return
	var pid := int(promise.get("id", 0))
	if int(b.get("_meet_id", 0)) == pid and Time.get_ticks_msec() - int(promise.get("t", 0)) < BOT_HELP_PROMISE_MS:
		return # promesa viva: sigue en camino
	b["_meet_promise"] = {}
	if pid <= 0:
		return
	var proxy: Node3D = b["proxy"]
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return
	var pb: Dictionary = bots.get(pid, {})
	var pp: Node3D = pb.get("proxy")
	if pb.is_empty() or pp == null or not is_instance_valid(pp) or bool(pp.get_meta("proxy_dead", false)):
		return # ya no habia a quien socorrer
	var d := proxy.global_position.distance_to(pp.global_position)
	if d <= BOT_TEAM_FORM_DIST or d > BOT_TEAM_MEET_DIST:
		return # llego a tiempo, o el grito le llego de demasiado lejos
	record_social_event(pid, "bot_%d" % int(b.get("bot_id", 0)), str(b.get("name", "")), "refused", 0.16, "ignored_help")

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

# El tiempo enfria las heridas: sin agresiones recientes (harm_t lo sella
# cada golpe), hostilidad y miedo decaen, el rencor sube hasta un fondo y
# cada tramo de paz borra una cicatriz de "me ataco" — nunca por debajo de
# 2, el recuerdo del peligro no se borra del todo. Las agresiones recientes
# pausan el olvido: mientras se sigan haciendo dano no enfria.
const REL_PEACE_MS := 45000          # sin dano en ~45 s reales: empieza a enfriar
const REL_DECAY_HOSTILITY := 0.0045  # ~-0.07/min al ciclo social de ~3.7 s
const REL_DECAY_FEAR := 0.0028       # el miedo enfria mas lento que el odio
const REL_DECAY_RENCOR := 0.0022     # trust<0 sube hasta REL_TRUST_FLOOR
const REL_TRUST_FLOOR := -0.25
const REL_SCAR_MS := 75000           # cada 75 s de paz borra una cicatriz

func _rel_time_decay(b: Dictionary) -> void:
	var mem := _ensure_bot_memory(int(b["bot_id"]))
	var rels: Dictionary = mem.get("relationships", {})
	if rels.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	for skey in rels.keys():
		var rel = rels[skey]
		if not (rel is Dictionary):
			continue
		var harm := int(rel.get("harm_t", 0))
		if rel.has("harm_t") and now_ms - harm < REL_PEACE_MS:
			continue # se hicieron dano hace nada: la herida esta fresca
		var host := float(rel.get("hostility", 0.0))
		if host > 0.0:
			rel["hostility"] = snappedf(maxf(0.0, host - REL_DECAY_HOSTILITY), 0.001)
		var fear := float(rel.get("fear", 0.0))
		if fear > 0.0:
			rel["fear"] = snappedf(maxf(0.0, fear - REL_DECAY_FEAR), 0.001)
		var tr := float(rel.get("trust", 0.0))
		if tr < REL_TRUST_FLOOR:
			rel["trust"] = snappedf(minf(REL_TRUST_FLOOR, tr + REL_DECAY_RENCOR), 0.001)
		var scar := int(rel.get("scar_t", harm))
		if int(rel.get("attacked", 0)) > 2 and now_ms - scar >= REL_SCAR_MS:
			rel["attacked"] = int(rel.get("attacked", 0)) - 1
			rel["scar_t"] = now_ms

# Gesto de paz autonomo: con un rival de su faccion cerca, herida abierta
# (miedo/odio/rencor) pero sangre no fresca, el bot puede dejarle comida o
# una venda a sus pies — el equivalente bot de "toma, paz". Rompe el
# circulo vicioso del miedo: quien teme evita el contacto y sin contacto
# nunca llegan los eventos positivos que bajarian el miedo.
const PEACE_GESTURE_DIST := 40.0
const PEACE_GESTURE_CD_MS := 150000

# Select and remove exactly one real item, retaining its type and value.
# Keep a meal for survival even when food is split across several stacks.
func _take_peace_gift(proxy: Node3D) -> Dictionary:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var meals := 0
	for it in inv:
		if it is Dictionary and str(it.get("type", "")) == "food" and float(it.get("use_value", it.get("use", 0.0))) > 0.0:
			meals += maxi(0, int(it.get("quantity", 1)))
	var selected := -1
	for i in range(inv.size()):
		var it = inv[i]
		if not (it is Dictionary) or int(it.get("quantity", 1)) <= 0:
			continue
		if str(it.get("type", "")) == "food" and meals > 1 and float(it.get("use_value", it.get("use", 0.0))) > 0.0:
			selected = i
			break
		if selected < 0 and str(it.get("name", "")) == "Vendaje":
			selected = i
	if selected < 0:
		return {}
	var gift: Dictionary = inv[selected].duplicate(true)
	gift["quantity"] = 1
	gift["use_value"] = float(gift.get("use_value", gift.get("use", 0.0)))
	inv[selected]["quantity"] = int(inv[selected].get("quantity", 1)) - 1
	if int(inv[selected]["quantity"]) <= 0:
		inv.remove_at(selected)
	proxy.set_meta("saved_inventory", inv)
	return gift

func _bot_try_peace_gesture(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	if bool(proxy.get_meta("proxy_dead", false)):
		return
	# Solo en calma: ni peleando, ni escondido, ni durmiendo, ni huyendo
	if b.get("aggro_target") != null or float(b.get("hide_timer", 0.0)) > 0.0 \
			or bool(b.get("sleeping", false)) or float(b.get("flee_until", 0.0)) > 0.0:
		return
	# Un regalo no se hace con la tripa vacia ni sediento
	if float(b.get("hunger", 100.0)) < 40.0 or float(b.get("thirst", 100.0)) < 35.0:
		return
	var my_id := int(b["bot_id"])
	var my_key := "bot_%d" % my_id
	var mem := _ensure_bot_memory(my_id)
	var rels: Dictionary = mem.get("relationships", {})
	var now_ms := Time.get_ticks_msec()
	var cds: Dictionary = b.get("_peace_cd", {})
	for k in cds.keys():
		if int(cds[k]) <= now_ms:
			cds.erase(k)
	var best_id := 0
	var best_key := ""
	var best_score := 0.0
	for oid in bots.keys():
		if oid == my_id:
			continue
		var ob: Dictionary = bots[oid]
		if str(ob.get("faction", "")) != str(b.get("faction", "")):
			continue
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var okey := "bot_%d" % oid
		if int(cds.get(okey, 0)) > now_ms:
			continue
		var rel = rels.get(okey, {})
		if not (rel is Dictionary) or (rel as Dictionary).is_empty():
			continue
		var wounded := float(rel.get("hostility", 0.0)) > 0.45 or float(rel.get("fear", 0.0)) > 0.55 \
				or float(rel.get("trust", 0.0)) < REL_TRUST_FLOOR - 0.05
		if not wounded:
			continue
		var harm := int(rel.get("harm_t", 0))
		if rel.has("harm_t") and now_ms - harm < 60000:
			continue # se hirieron hace nada: aun no es momento
		var oaggro = ob.get("aggro_target")
		if oaggro != null and oaggro == proxy:
			continue # el otro le esta apuntando: no es momento
		var odist := proxy.global_position.distance_to((op as Node3D).global_position)
		if odist > PEACE_GESTURE_DIST or odist < 5.0:
			continue
		var score := float(rel.get("fear", 0.0)) + float(rel.get("hostility", 0.0))
		if score > best_score:
			best_score = score
			best_id = oid
			best_key = okey
	if best_id <= 0:
		b["_peace_cd"] = cds
		return
	# Probabilidad por personalidad: sociables y cooperativos dan el paso;
	# el desconfiado casi nunca ofrece primero
	var pers := _get_bot_personality(b)
	var chance := float(pers.get("sociability", 0.5)) * 0.35 + float(pers.get("cooperation", 0.5)) * 0.45 \
			+ maxf(0.0, 0.5 - float(pers.get("distrust", 0.35))) * 0.4
	if randf() > chance:
		return
	var gift_item := _take_peace_gift(proxy)
	if gift_item.is_empty():
		cds[best_key] = now_ms + PEACE_GESTURE_CD_MS
		b["_peace_cd"] = cds
		return
	var gift := str(gift_item["name"])
	_bot_drop_to_ground(b, gift_item)
	var oname := str((bots.get(best_id, {}) as Dictionary).get("name", best_key))
	var my_name := str(b.get("name", my_key))
	record_social_event(my_id, best_key, oname, "help", 0.30, "peace_offering")
	record_social_event(best_id, my_key, my_name, "help", 0.30, "peace_received")
	cds[best_key] = now_ms + PEACE_GESTURE_CD_MS
	b["_peace_cd"] = cds
	_bot_chat_send(b, best_id, oname, "Oye, %s... te dejo %s aquí. No quiero más guerra, ¿vale?" % [oname, gift], "gift")
	record_bot_event(my_id, "peace_gesture", best_key, _poi_kind_near(proxy.global_position), proxy.global_position, "ofrece paz a " + oname + " (" + gift + ")")

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
	_meet_promise_check(b)
	_rel_time_decay(b)
	_bot_try_peace_gesture(b)
	var lid := int(b.get("team_leader_id", 0))
	if lid > 0:
		b["_meet_id"] = 0 # ya esta en equipo: no busca a nadie

	# 1) Mantener o romper el equipo actual (solo si el lider es otro bot;
	#    los equipos reclutados por un humano se gestionan por ordenes)
	if lid > 0 and is_bot_peer_id(lid):
		var lb: Dictionary = bots.get(lid, {})
		var lp: Node3D = lb.get("proxy")
		var leader_gone: bool = lb.is_empty() or lp == null or not is_instance_valid(lp) or bool(lp.get_meta("proxy_dead", false))
		var llid := int(lb.get("team_leader_id", 0)) if not lb.is_empty() else 0
		# Anti-ciclo: si el supuesto lider sigue a su vez a otro bot (p.ej.
		# 901<->902 mirandose en bucle sin que ninguno lidere), romper el ciclo
		# dejando como unico lider raiz al de mayor _bot_lead_score.
		if not leader_gone and llid > 0:
			if llid == my_id:
				if _bot_lead_score(b) >= _bot_lead_score(lb):
					b["team_leader_id"] = 0
					proxy.set_meta("team_leader_id", 0)
					lid = 0
				else:
					lb["team_leader_id"] = 0
					if lp != null and is_instance_valid(lp):
						lp.set_meta("team_leader_id", 0)
			elif bots.has(llid) and int(bots[llid].get("team_leader_id", 0)) == 0:
				b["team_leader_id"] = llid
				proxy.set_meta("team_leader_id", llid)
				lid = llid
				lb = bots[lid]
				lp = lb.get("proxy")
			else:
				b["team_leader_id"] = 0
				proxy.set_meta("team_leader_id", 0)
				lid = 0
		if lid > 0:
			var rel := get_bot_relationship(my_id, "bot_%d" % lid)
			var too_far := (not leader_gone) and proxy.global_position.distance_to(lp.global_position) > BOT_TEAM_GIVE_UP_DIST
			var snubbed := int(rel.get("refused", 0)) >= 3
			if leader_gone or float(rel.get("trust", 0.0)) < BOT_TEAM_BREAK_TRUST or too_far or snubbed:
				record_bot_event(my_id, "team_leave", "bot_%d" % lid, _poi_kind_near(proxy.global_position), proxy.global_position,
					"lider muerto" if leader_gone else ("dejado tirado" if snubbed else ("desconfianza" if float(rel.get("trust", 0.0)) < BOT_TEAM_BREAK_TRUST else "se perdio")))
				b["team_leader_id"] = 0
				proxy.set_meta("team_leader_id", 0)
				lid = 0
			elif randf() < 0.55:
				# Sobrevivir juntos consolida la confianza (aprendizaje persistente)
				record_social_event(my_id, "bot_%d" % lid, str(lb.get("name", "")), "ally", 0.03, "equipo")

	# 2) Formar equipo: convivir cerca sin agresiones sube la confianza hasta
	#    que alguien se ofrece a seguir al bot con mejor perfil de lider
	if lid <= 0:
		var already_leading := _bot_team_role(b) == "leader"
		var my_faction := str(b.get("faction", ""))
		var my_lead := _bot_lead_score(b)
		var best_target := 0
		var best_trust := -1.0
		var meet_id := 0
		var meet_dist := INF
		# Un lider no sale a "hacer compañia", pero SI acude a un auxilio
		# prometido: sin esta excepcion responde "ya voy" y nunca llega.
		var promised_id := int((b.get("_meet_promise", {}) as Dictionary).get("id", 0))
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
			# Los bandidos se juntan por agresividad, no por cariño: su puerta
			# de convivencia y su confianza de equipo son mas laxas — una
			# banda de conveniencia nace para dar el golpe sin llevarse bien.
			var host_gate := 0.55 if my_faction == "hostile" else 0.05
			var form_trust := 0.18 if my_faction == "hostile" else BOT_TEAM_FORM_TRUST
			var civil := float(rel_out.get("hostility", 0.0)) <= host_gate and float(rel_in.get("hostility", 0.0)) <= host_gate
			if odist > BOT_TEAM_FORM_DIST:
				# Iman social: lejos para convivir pero al alcance — un bot que
				# quiere compañia viaja a reunirse con su aliado potencial.
				if (not already_leading or oid == promised_id) and civil and _bot_wants_company(b, rel_out) and odist < meet_dist:
					meet_dist = odist
					meet_id = oid
				continue
			if civil:
				record_social_event(my_id, okey, str(ob.get("name", okey)), "ally", 0.05, "convive")
				record_social_event(oid, my_key, str(b.get("name", my_key)), "ally", 0.05, "convive")
				rel_out = get_bot_relationship(my_id, okey)
				rel_in = get_bot_relationship(oid, my_key)
			if already_leading:
				continue # quien ya lidera un equipo no se subordina a otro (evita ciclos)
			var mutual := minf(float(rel_out.get("trust", 0.0)), float(rel_in.get("trust", 0.0)))
			if mutual < form_trust:
				continue
			# Si ya milita en un equipo, el candidato es su lider (el equipo crece);
			# si esta libre, solo me uno si lidera mejor que yo — si no, el se
			# unira a mi en su propio ciclo (desempate deterministico).
			var olid := int(ob.get("team_leader_id", 0))
			var target_id: int = olid if (olid > 0 and is_bot_peer_id(olid)) else oid
			if target_id == my_id or not bots.has(target_id):
				continue
			var tb_lead: Dictionary = bots[target_id]
			if int(tb_lead.get("team_leader_id", 0)) != 0 or _bot_lead_score(tb_lead) <= my_lead:
				continue
			if _bot_team_size(target_id) >= BOT_TEAM_MAX_SIZE:
				continue
			if olid > 0:
				var lrel := get_bot_relationship(my_id, "bot_%d" % target_id)
				var lrel_in := get_bot_relationship(target_id, my_key)
				mutual = minf(float(lrel.get("trust", 0.0)), float(lrel_in.get("trust", 0.0)))
				if mutual < form_trust:
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
			_ensure_bot_memory(my_id, b.get("cfg", {}))["team_danger_n"] = 0 # hoja limpia en el nuevo equipo
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
		elif not lamb.is_empty() and int(lamb.get("seen_msec", 0)) > int(am.get("seen_msec", 0)):
			# El lider va cantando la ultima posicion que EL conoce de la
			# presa; el miembro no recibe mas de lo que sabe su compañero.
			am["pos"] = lamb.get("pos", am.get("pos", Vector3.INF))
			am["seen_msec"] = int(lamb.get("seen_msec", 0))
			b["_ambush"] = am

	# 4) Chat: respuestas, gritos de ayuda, alianzas, saludos y susurros
	_bot_chat_tick(b)

# Reune a todo el equipo de la victima (lider + miembros) contra el agresor:
# el equivalente bot de un grito de ayuda. Se llama desde _net_damage_player.
func rally_bot_team(victim_id: int, attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker) or not bots.has(victim_id):
		return
	var _cpt := Time.get_ticks_usec()
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
			# Posicion comunicada por el compañero: SU ultima conocida, con
			# su antiguedad y fiabilidad. La victima no se avisa a si misma
			# (su ficha propia es mejor) y si no sabe nada del agresor el
			# aviso solo orienta hacia donde la estan atacando a ella.
			if bid != victim_id:
				var rep_v := _bot_foe_report(victim_b, attacker)
				var vp: Node3D = victim_b.get("proxy")
				if not rep_v.is_empty():
					_ai_note_foe_intel(tb, attacker, rep_v["pos"], "told", float(rep_v["conf"]), int(rep_v["age_msec"]))
				elif vp != null and is_instance_valid(vp):
					_ai_note_foe_intel(tb, attacker, vp.global_position, "told", 0.3)
			tb["sitting"] = false
			tb["sleeping"] = false
			tb["sense_t"] = 0.0
	if CombatProf.enabled: CombatProf.mark("bot.rally", _cpt)

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
	# Un fusil sin una sola bala (cargador, reserva o cajas) es un garrote.
	if not _bot_usable_gun(proxy).is_empty():
		return true
	return not _bot_best_bow(proxy).is_empty() and _bot_arrow_count(proxy) > 0

# Arma de fuego realmente utilizable: la lleva encima Y le queda municion.
func _bot_usable_gun(proxy: Node3D) -> String:
	for w in ["Fusil de asalto", "Rifle francotirador"]:
		if _bot_item_count(proxy, w) > 0 and _bot_gun_any_ammo(proxy, w):
			return w
	return ""

# Estado de municion de un arma: "loaded" (bala en el cargador), "reserve"
# (hay que recargar antes de disparar: BOT_GUN_RELOAD_TIME) o "empty".
func _bot_gun_ammo_state(proxy: Node3D, weapon: String) -> String:
	var ammo := _bot_gun_ammo(proxy)
	if _bot_gun_loaded(ammo, weapon) > 0:
		return "loaded"
	if _bot_gun_reserve(ammo, weapon) > 0 or _bot_gun_ammo_item_idx(proxy, weapon) >= 0:
		return "reserve"
	return "empty"

# --- Percepcion honesta de otro superviviente -------------------------------
# Lo ve (alcance visual efectivo + linea de vision real) o lo oye (pista
# sonora valida). Sin ninguna de las dos no existe para el bot, este a 8 m
# tras una pared o a 80 m en campo abierto.
func _bot_perceives_actor(b: Dictionary, target: Node3D, sight: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var d := proxy.global_position.distance_to(target.global_position)
	if _can_bot_hear_actor(b, target, d):
		return true
	return d <= _effective_human_sight(target, sight) and _has_clear_shot(proxy.global_position, target.global_position)

# Valor APARENTE de una presa: solo lo que se ve desde fuera — mochila,
# arma en la mano, ropa puesta — mas lo que el bot recuerda de encuentros
# anteriores con ella. Jamas el contenido de su inventario.
func _bot_observed_loot_value(b: Dictionary, target: Node3D, pid: int) -> float:
	var val := 0.0
	if not str(target.get_meta("saved_backpack", "")).is_empty():
		val += 5.0
	var held := str(target.get_meta("saved_held_item", ""))
	if held.begins_with("Fusil") or held.begins_with("Rifle"):
		val += 4.0
	elif not held.is_empty():
		val += 1.5
	val += minf(2.4, float(str(target.get_meta("saved_clothing", "")).split(",", false).size()) * 0.6)
	if pid > 0:
		# Memoria: a quien ya le saco botin lo recuerda como presa rentable.
		var rel := get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid))
		val += minf(4.0, float(int(rel.get("robbed", 0))) * 2.0)
	return val

# Vulnerabilidad APARENTE: postura y heridas que el bot ha presenciado (el
# o su equipo le dieron hace poco), no la barra de vida interna.
func _bot_observed_vulnerable(b: Dictionary, target: Node3D, pid: int) -> bool:
	if bool(target.get_meta("saved_sleeping", false)) or bool(target.get_meta("sleeping", false)) or target.get("is_sleeping") == true:
		return true
	if bool(target.get_meta("saved_sitting", false)) or bool(target.get_meta("sitting", false)):
		return true
	var seen_hit: Dictionary = b.get("_seen_wounded", {})
	return pid > 0 and Time.get_ticks_msec() - int(seen_hit.get(pid, -999999)) < 90000

# Tregua, alianza o vinculo personal: con esa persona no se monta una
# emboscada aunque la faccion lo permita.
func _bot_ambush_forbidden(b: Dictionary, pid: int) -> bool:
	if pid <= 0:
		return false
	if int(b.get("_truce_peer", 0)) == pid and float(b.get("_truce_t", 0.0)) > 0.0:
		return true
	if pid == int(b.get("team_leader_id", 0)) or pid in _bot_team_ids(b):
		return true
	var rel := get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid))
	if float(rel.get("trust", 0.0)) >= 0.55 and float(rel.get("hostility", 0.0)) < 0.5:
		return true
	return int(rel.get("helped", 0)) >= 2 and int(rel.get("attacked", 0)) == 0

# La presa ideal de una emboscada: a la vista, con pinta de llevar algo que
# merezca la pena, sola y sin vinculo con el bandido — roba lo que necesita,
# no mata por matar. Todo se decide con informacion OBSERVABLE: lo que ve u
# oye el propio bot y lo que recuerda, nunca inventario ni salud internos.
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
	# Malherido no se sale a asaltar a nadie: primero recuperarse.
	if float(b["health"]) < 45.0:
		return {}
	var has_ranged := _bot_has_ranged_weapon(proxy)
	var sight := 52.0
	# Candidatos: proxies de red + el jugador local (anfitrion no dedicado,
	# que no figura en net_player_proxy).
	var cands: Array = world.get_tree().get_nodes_in_group("net_player_proxy")
	var local_p = world.get("player")
	if local_p is Node3D and is_instance_valid(local_p) and not (local_p in cands):
		cands.append(local_p)
	# Solo existe para el bot quien el bot percibe (vista con LOS u oido).
	var perceived: Array = []
	for p in cands:
		if not (p is Node3D) or p == proxy or not is_instance_valid(p):
			continue
		if bool(p.get_meta("proxy_dead", false)) or p.get("is_dead") == true:
			continue
		if p != local_p and not bool(p.get_meta("has_real_pos", false)):
			continue
		if _bot_perceives_actor(b, p as Node3D, sight):
			perceived.append(p)
	var best: Dictionary = {}
	var best_score := -1.0
	for p in perceived:
		var p3 := p as Node3D
		if bool(p3.get_meta("is_ai_bot", false)) and str(p3.get_meta("bot_faction", "")) == "hostile":
			continue # no canibalismo entre bandidos
		var pid := _peer_id_for_actor(p3)
		if pid > 0 and pid in my_team:
			continue # nunca contra el propio equipo
		if _bot_ambush_forbidden(b, pid):
			continue # tregua, alianza o vinculo personal
		# Acechar cuchillo en mano a quien lleva un arma de fuego a la vista
		# no es una emboscada, es un suicidio — salvo hambre/sed extremas.
		if _actor_holds_ranged(p3) and not has_ranged and not desperate:
			continue
		var d := proxy.global_position.distance_to(p3.global_position)
		# Un ruido puede advertir de una escolta, pero no permite valorar
		# mochila/arma ni escoger una víctima invisible a través de una pared.
		if d > _effective_human_sight(p3, sight) or not _has_clear_shot(proxy.global_position, p3.global_position):
			continue
		var loot_val := _bot_observed_loot_value(b, p3, pid)
		# Escoltas: solo cuentan los acompañantes que el bot ha detectado.
		var allies := 0
		for q in perceived:
			if q == p3:
				continue
			var qid := _peer_id_for_actor(q as Node3D)
			if qid > 0 and qid in my_team:
				continue
			if bool((q as Node3D).get_meta("is_ai_bot", false)) and str((q as Node3D).get_meta("bot_faction", "")) == "hostile":
				continue
			if p3.global_position.distance_to((q as Node3D).global_position) <= 20.0:
				allies += 1
		if allies >= my_team.size() and not desperate:
			continue
		if loot_val < 4.0 and not desperate:
			continue
		# Recuerdo de encuentros: a quien ya le hizo daño de verdad (miedo)
		# o le mato no se le embosca alegremente.
		var fear := float(get_bot_relationship(int(b["bot_id"]), _actor_persist_key(pid)).get("fear", 0.0)) if pid > 0 else 0.0
		if fear > 0.68 and not desperate:
			continue
		var score := loot_val + (8.0 if allies == 0 else 0.0) + (4.0 if _bot_observed_vulnerable(b, p3, pid) else 0.0) - (3.0 if _actor_holds_ranged(p3) else 0.0) - fear * 6.0 - d * 0.15
		if score > best_score:
			best_score = score
			best = {"target_id": pid, "target_name": _actor_display_name(pid) if pid > 0 else "?", "t": 0.0,
				"pos": p3.global_position, "seen_msec": Time.get_ticks_msec()}
	return best

# Cada bot que PRESENCIA como hieren a alguien lo recuerda un rato: es la
# unica via para saber que una posible presa esta tocada (la vida ajena no
# se consulta). Lo llama Main al aplicar daño a un jugador o bot.
func note_actor_wounded(victim_id: int) -> void:
	var victim := _find_actor_by_peer_id(victim_id)
	if victim == null or not is_instance_valid(victim):
		return
	for bid in bots.keys():
		if int(bid) == victim_id:
			continue
		var wb: Dictionary = bots[bid]
		var wp: Node3D = wb.get("proxy")
		if wp == null or not is_instance_valid(wp) or bool(wp.get_meta("proxy_dead", false)):
			continue
		var wd := wp.global_position.distance_to(victim.global_position)
		if wd <= _effective_human_sight(victim, 52.0) and _has_clear_shot(wp.global_position, victim.global_position):
			var sw: Dictionary = wb.get("_seen_wounded", {})
			sw[victim_id] = Time.get_ticks_msec()
			wb["_seen_wounded"] = sw

# Aproximación estable por flancos alternos. Cada miembro mantiene su propio
# punto aunque comparta el plan del líder; nunca rodea con la posición oculta
# del rival. Si el terreno no permite el flanco, sigue la ruta normal.
func _bot_ambush_approach(b: Dictionary, known: Vector3, strike: float) -> Vector3:
	var proxy: Node3D = b["proxy"]
	var amb: Dictionary = b.get("_ambush", {})
	var route: Dictionary = b.get("_ambush_route", {})
	var anchor: Vector3 = route.get("anchor", Vector3.INF)
	if int(route.get("target", 0)) != int(amb.get("target_id", 0)) or anchor == Vector3.INF or anchor.distance_to(known) > 4.0:
		route = {"target": int(amb.get("target_id", 0)), "anchor": known, "goal": known}
		var forward := known - proxy.global_position
		forward.y = 0.0
		if forward.length() > strike + 2.0 and absf(known.y - proxy.global_position.y) < 1.0:
			var ids := _bot_team_ids(b)
			ids.sort()
			var rank := ids.find(int(b["bot_id"]))
			var flank := 1.0 if (rank if rank >= 0 else int(b["bot_id"])) % 2 == 0 else -1.0
			forward = forward.normalized()
			var side := Vector3(-forward.z, 0.0, forward.x)
			for lane in [flank, -flank]:
				var candidate: Vector3 = known - forward * strike * 0.65 + side * float(lane) * strike * 0.55
				candidate.y = _ground_y(candidate.x, candidate.z, proxy.global_position.y)
				if absf(candidate.y - proxy.global_position.y) <= 0.65 and not _is_goal_blacklisted(b, candidate) and not _is_step_blocked(proxy.global_position, candidate):
					route["goal"] = candidate
					break
		b["_ambush_route"] = route
	var goal: Vector3 = route["goal"]
	if proxy.global_position.distance_to(goal) < 1.0 or _is_goal_blacklisted(b, goal):
		route["goal"] = known
		return known
	return goal

# Ejecuta la emboscada cada tick: acecho agachado hasta el borde del asalto y
# golpe conjunto (el equipo entero recibe aggro sobre la victima a la vez).
func _bot_ambush_height_post(b: Dictionary, known: Vector3) -> Vector3:
	var proxy: Node3D = b["proxy"]
	if not _bot_has_ranged_weapon(proxy) or _bot_vital_break(b):
		return Vector3.INF
	var best := Vector3.INF
	var score := -INF
	var range_limit := 85.0 if not _bot_usable_gun(proxy).is_empty() else 32.0
	for poi in _explore_pois():
		if str(poi.get("kind", "")) != "tower":
			continue
		var post: Vector3 = poi["pos"]
		var gain := post.y-known.y
		var travel := proxy.global_position.distance_to(post)
		var shot_dist := post.distance_to(known)
		if gain < 3.0 or travel > 75.0 or shot_dist < 12.0 or shot_dist > range_limit:
			continue
		if _is_goal_blacklisted(b,post) or _is_poi_unreachable(b,_poi_id(poi)):
			continue
		var occupied := false
		for other in bots.values():
			if int(other.get("bot_id",0)) == int(b.get("bot_id",0)):
				continue
			var op: Vector3 = other.get("_ambush",{}).get("post",other.get("_overwatch",{}).get("post",Vector3.INF))
			if op.is_finite() and op.distance_to(post) < 4.0:
				occupied = true
				break
		if occupied or not _has_clear_shot(post, known):
			continue
		var merit := minf(gain,15.0)*2.0 - travel - maxf(0.0,post.y-proxy.global_position.y)*1.5
		if merit > score:
			score = merit
			best = post
	return best

func _bot_try_ambush(b: Dictionary, delta: float) -> bool:
	var amb: Dictionary = b.get("_ambush", {})
	if amb.is_empty():
		return false
	var proxy: Node3D = b["proxy"]
	var now_s := Time.get_ticks_msec() / 1000.0
	var abort := func(cd: float) -> bool:
		b["_ambush"] = {}
		b.erase("_ambush_route")
		b["_ambush_cd_until"] = now_s + cd
		b["crouching"] = false
		proxy.set_meta("crouching", false)
		return false
	var aggressor = b.get("aggro_target")
	if is_instance_valid(aggressor) and not bool(aggressor.get_meta("proxy_dead", false)) and aggressor.get("is_dead") != true:
		return abort.call(60.0)
	var target := _find_actor_by_peer_id(int(amb.get("target_id", 0)))
	if target == null or not is_instance_valid(target) or bool(target.get_meta("proxy_dead", false)) or target.get("is_dead") == true:
		return abort.call(70.0)
	# Una tregua o un vinculo sellado a mitad del acecho lo cancela.
	if _bot_ambush_forbidden(b, int(amb.get("target_id", 0))):
		return abort.call(90.0)
	if float(b["thirst"]) < 16.0 or float(b["hunger"]) < 10.0 or float(b["health"]) < 30.0:
		return abort.call(60.0)
	amb["t"] = float(amb.get("t", 0.0)) + delta
	# El acecho sigue la ultima posicion CONOCIDA de la presa: se refresca
	# solo mientras este bot la percibe (o su lider se la transmite al
	# copiar el plan). Si desaparece tras una pared no hay radar: se camina
	# a donde se la vio y, sin volver a dar con ella, se abandona.
	var planned_post: Vector3 = amb.get("post", Vector3.INF)
	var at_height := planned_post.is_finite() and proxy.global_position.distance_to(planned_post) < 1.2
	var visible := proxy.global_position.distance_to(target.global_position) <= _effective_human_sight(target, 85.0 if at_height else 52.0) and _has_clear_shot(proxy.global_position, target.global_position)
	if visible:
		amb["pos"] = target.global_position
		amb["seen_msec"] = Time.get_ticks_msec()
	var known: Vector3 = amb.get("pos", Vector3.INF)
	b["_ambush"] = amb
	# Climbing takes longer than stalking on foot; the plan stays anchored to
	# the old sighting and expires, even if the unseen actor has moved.
	var clue_ttl := 150000 if planned_post.is_finite() else BOT_AMBUSH_LOST_MSEC
	if known == Vector3.INF or Time.get_ticks_msec() - int(amb.get("seen_msec", 0)) > clue_ttl:
		return abort.call(45.0)
	var d := proxy.global_position.distance_to(known)
	if d > BOT_AMBUSH_ABORT_DIST:
		return abort.call(50.0)
	if not amb.has("height_checked"):
		amb["height_checked"] = true
		planned_post = _bot_ambush_height_post(b, known)
		if planned_post.is_finite():
			amb["post"] = planned_post
			record_bot_event(int(b["bot_id"]), "ambush_height", "peer_%d" % int(amb.get("target_id",0)), _poi_kind_near(planned_post), planned_post, "prepara emboscada desde altura")
	if planned_post.is_finite():
		if _is_goal_blacklisted(b,planned_post) or _bot_vital_break(b) or float(amb["t"]) > 150.0:
			return abort.call(45.0)
		b["_act"] = "ambush_height"
		b["crouching"] = false
		b["is_aiming"] = false
		var elevated_pick := _pick_fight_weapon(b, d)
		b["held_item"] = str(elevated_pick.get("name", ""))
		b["has_rifle"] = str(elevated_pick.get("kind", "")) == "rifle"
		proxy.set_meta("saved_held_item", b["held_item"])
		if proxy.global_position.distance_to(planned_post) >= .65:
			_move_bot_towards(b, planned_post, 3.0, delta, "walk")
			return true
		_stop_bot_motion(b)
		b["crouching"] = true
		b["is_aiming"] = visible
		var look := known-proxy.global_position
		b["rot"] = atan2(-look.x,-look.z)
		proxy.rotation.y = float(b["rot"])
		amb["settled"] = float(amb.get("settled",0.0))+delta
		if not visible or float(amb["settled"]) < 1.4:
			return true
	var strike := 85.0 if planned_post.is_finite() else (BOT_AMBUSH_STRIKE_RANGED if _bot_has_ranged_weapon(proxy) else BOT_AMBUSH_STRIKE_MELEE)
	if visible and (d <= strike or (float(amb["t"]) > BOT_AMBUSH_MAX_SECONDS and d <= strike + 8.0)):
		# GOLPE: todo el equipo ataca a la vez
		if planned_post.is_finite():
			b["_overwatch"] = {"post":planned_post, "zone":_bot_leader_watch_zone(planned_post), "t":Time.get_ticks_msec()}
		b["_ambush"] = {}
		b.erase("_ambush_route")
		b["_ambush_cd_until"] = now_s + 75.0
		b["aggro_target"] = target
		b["aggro_timer"] = 30.0
		_ai_note_foe_intel(b, target, target.global_position, "seen")
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
	b["is_aiming"] = false
	var pick := _pick_fight_weapon(b, d)
	b["held_item"] = str(pick.get("name", ""))
	b["has_rifle"] = str(pick.get("kind", "")) == "rifle"
	proxy.set_meta("saved_held_item", b["held_item"])
	proxy.set_meta("crouching", true)
	if d > 1.5:
		_move_bot_towards(b, _bot_ambush_approach(b, known, strike) if visible else known, 2.0, delta, "walk")
	else:
		_stop_bot_motion(b) # en el ultimo punto conocido: escucha y espera
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
# Una frase generada por el modelo que llega con mas de 9 s de retraso ya no
# encaja en la escena (el saludo aterriza en mitad de un tiroteo): se descarta.
const BOT_CHAT_STALE_MSEC := 9000
const BOT_CHAT_RECENT_MAX := 4
const BOT_CHAT_SYSTEM_PROMPT := "Eres un superviviente real en un mundo postapocaliptico (Last Day) y hablas EN VOZ ALTA. Habla como una persona espanola real en mitad del campo: natural, coloquial, con pausas breves (comas, puntos suspensivos), muletillas humanas ocasionales (oye, mira, vale, bueno, escucha) y SIEMPRE con ortografia y tildes espanolas correctas (qué, dónde, cómo, está, aquí, ahí, allá, más, tú, mí, sí) para que tu voz suene 100% humana al pronunciarse. Prohibido: sonar robotico o formal, emojis, comillas, roleplay con asteriscos, abreviaturas de chat (q, tb, pq), mencionar que eres IA. Responde SOLO con lo que dices en voz alta, 1 o 2 frases cortas, maximo 130 caracteres."

var _chat_http: HTTPRequest = null
var _chat_pending: Dictionary = {}          # peticion LLM en vuelo {bot_id,to_id,to_name,kind,intent,t}
var chat_log: Array = []                    # [{ts,from_id,from,to_id,to,kind,text}] para el monitor
var _chat_pair_until: Dictionary = {}       # "a:b" -> msec (enfriamiento de iniciados)
var _chat_greet_until: Dictionary = {}      # "a:b" -> msec (saludos, ventana larga)
var _chat_turns: Dictionary = {}            # "a:b" -> int (corta el ping-pong bot-bot)
var _chat_help_until: Dictionary = {}       # bot_id -> msec
var _chat_req_until: Dictionary = {}        # bot_id -> msec (peticiones de recursos)
var _chat_recent: Dictionary = {}           # bot_id -> Array[String] ultimas frases enviadas (anti-repeticion)

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
	var can_cooperate := not sender_is_bot or _bot_pair_can_cooperate(target_id, sender_id)
	var rel := _chat_touch_rel(target_id, skey, sender_name)
	match intent if can_cooperate else ("threat" if intent == "threat" else "talk"):
		"help":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.02, -1.0, 1.0), 0.001)
		"alliance":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.04, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(maxf(0.0, float(rel.get("hostility", 0.0)) - 0.03), 0.001)
		"greet", "goodnight", "goodmorning":
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + 0.02, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(maxf(0.0, float(rel.get("hostility", 0.0)) - 0.02), 0.001)
		"threat":
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) + 0.06, 0.0, 1.0), 0.001)
			rel["fear"] = snappedf(clampf(float(rel.get("fear", 0.0)) + 0.05, 0.0, 1.0), 0.001)
	# Un grito de ayuda o una propuesta de alianza mueve al aliado hacia el
	# emisor: mismo iman social que los reencuentros (26 m -> equipo).
	var hostile_me := str(tb.get("faction", "")) == "hostile"
	var sender_hostile := sender_is_bot and str((bots.get(sender_id, {}) as Dictionary).get("faction", "")) == "hostile"
	if (intent == "help" or intent == "alliance") and sender_is_bot and (not hostile_me or sender_hostile) \
		and can_cooperate and int(tb.get("team_leader_id", 0)) == 0 and int(tb.get("_meet_id", 0)) == 0 \
		and float(rel.get("trust", 0.0)) > 0.10:
		tb["_meet_id"] = sender_id
		tb["_soc_t"] = 0.0
		if intent == "help":
			tb["_meet_promise"] = {"id": sender_id, "kind": "help", "t": Time.get_ticks_msec()}
		_record_milestone(target_id, "first_rescue" if intent == "help" else "first_alliance")
	# Regalo/oferta de objeto ("te doy pan", "toma esto"): solo humanos; exige
	# cercania y retira el item del inventario del que ofrece. Vale para chat
	# escrito y para voz transcrita (ambos entran por aqui).
	if not sender_is_bot:
		var gift := _chat_parse_gift(clean)
		if not gift.is_empty():
			_chat_handle_gift(tb, sender_id, sender_name, skey, str(gift.get("word", "")), clean)
			return
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
			# "vete"/"largate" con una peticion pendiente tambien es una negativa:
			# queda en memoria y el bot reevalua (la orden de irse sigue saliendo).
			if str(order["cmd"]) == "dismiss":
				_chat_maybe_refuse(tb, target_id, sender_id, sender_name, skey)
			_chat_handle_order(tb, sender_id, sender_name, skey, str(order["cmd"]), str(order.get("arg", "")))
			return
	# Peticiones entre cualquiera ("tienes comida?", "necesito vendas",
	# "ayudame"): el receptor decide si da, acude o se niega.
	var req := _chat_parse_request(clean)
	if not req.is_empty():
		_chat_handle_request(tb, sender_id, sender_name, skey, sender_is_bot, str(req["cmd"]), str(req.get("arg", "")))
		return
	# Negativa a una peticion pendiente de este emisor ("no", "ni de cona"):
	# queda en memoria (refused) y el bot reevalua que hacer — volver a rogar,
	# robar, atacar o buscarse la vida — y contesta acorde a la decision.
	if intent == "refuse":
		var refuse_ctx := _chat_maybe_refuse(tb, target_id, sender_id, sender_name, skey)
		if refuse_ctx != "":
			_chat_dispatch(tb, "refused", sender_id, sender_name, refuse_ctx, "refuse")
			return
	# Encolar respuesta (la ultima gana); los turnos cortan el ping-pong.
	# Si el emisor es humano, responder en el siguiente tick sin esperar el
	# ciclo social de ~3.5 s ni descartar por enfriamiento entre bots.
	var pk := _chat_pair_key(target_id, sender_id)
	if not sender_is_bot or int(_chat_turns.get(pk, 0)) < BOT_CHAT_MAX_TURNS:
		tb["_chat_inbox"] = {"from_id": sender_id, "from_name": sender_name, "text": clean, "intent": intent}
		if not sender_is_bot:
			tb["_chat_reply_ready"] = 0
			tb["_soc_t"] = 0.0

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
	for kw in ["buenas noches", "que descanses", "a dormir", "voy a dormir", "me retiro", "me acuesto", "a la cama"]:
		if t.contains(kw):
			return "goodnight"
	for kw in ["buenos dias", "buen dia", "que tengas buen dia", "buen despertar"]:
		if t.contains(kw):
			return "goodmorning"
	for kw in ["hola", "buenas", "saludos", "que tal", "ey ", "ei ", "oye "]:
		if t.contains(kw):
			return "greet"
	# Negativa a una peticion: solo llega a efecto si el bot tiene una peticion
	# pendiente de ese emisor (_asked); si no, cae a la charla generica.
	for kw in [" ni de cona", "largate", "largo ", " vete ", "buscate la vida", "no te doy", "no pienso", "olvidate", "ni lo suenes", "no comparto", "no me pidas", "ni una ", "ni un ", "no puedo", "no tengo", "me falta a mi", "voy justo", "no me queda", "imposible", "jamás", "jamas", "nunca", " no ", " nanai ", " que no "]:
		if t.contains(kw):
			return "refuse"
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
	# Tregua/parley: pacificar a un hostil antes de pedirle nada. Va antes que
	# el resto de ordenes porque "alto/basta/hablemos" no es una orden de equipo.
	for kw in [" alto ahi", " alto el fuego", " basta ", " tregua ", " calma ", " tranquilo ", " tranquila ", "deja de disparar", "dejen de disparar", "para de disparar", "no disparen", "no dispares", "no me dispares", "no me mates", "no disparar", "guarda el arma", "guarden el arma", "guarda las armas", "baja el arma", "bajad el arma", "deja el arma", "dejen las armas", "no hace falta disparar", "no quiero pelea", "no vengo a pegar", "no vengo a disparar", "no soy tu enemigo", "no te hare dano", "no vengo a hacerte dano", "vengo en paz", "vengo en son de paz", "en son de paz", "solo quiero hablar", "podemos hablar", "quiero hablar", "hablemos", "podemos negociar", "negociemos", "hablar contigo", "hablame", "habla conmigo", "confia en mi", "date cuenta", "soy de los tuyos", "no soy enemigo"]:
		if t.contains(kw):
			return {"cmd": "truce"}
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

# Umbral de confianza para que un bot HOSTIL acepte unirse al jugador: depende
# de su personalidad — Elena (cooperativa) se convence facil, Kael (paranoico)
# exige mucho mas. trust en [-1,1]; se gana con chat positivo, regalos y
# no devolver el fuego; se pierde atacandolo.
func _convince_threshold(b: Dictionary) -> float:
	var pers := _get_bot_personality(b)
	return clampf(0.52 - float(pers.get("cooperation", 0.5)) * 0.24 + float(pers.get("distrust", 0.35)) * 0.16 - float(pers.get("sociability", 0.5)) * 0.06, 0.22, 0.85)

# Umbral de obediencia por orden: compromiso mayor exige mas confianza.
func _chat_order_gate(b: Dictionary, sender_id: int, skey: String, cmd: String) -> Dictionary:
	# Bajo fuego nadie acepta compromisos — ni siquiera la orden del propio
	# lider (desacuerdo justificado: primero sobrevivir, luego obedecer).
	# stay/dismiss/attack si pasan: son ordenes coherentes en combate.
	if b.get("aggro_target") != null or _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null:
		if not cmd in ["stay", "dismiss", "attack"]:
			return {"ok": false, "why": "busy"}
	# La historia bilateral manda mas que el cargo: la victima no coopera con
	# quien recuerda como asesino mientras no haya reparaciones reales — ni
	# aunque ese bot sea hoy su lider de equipo (acudir, dar o seguirle si).
	if cmd in ["come", "give", "follow", "assist"] \
		and not _bot_pair_can_cooperate(int(b["bot_id"]), sender_id):
		return {"ok": false, "why": "betrayed"}
	if int(b.get("team_leader_id", 0)) == sender_id:
		return {"ok": true, "why": "team"}
	if str(b.get("faction", "")) == "hostile":
		# Unico camino hostil->aliado: la orden de unirse con confianza suficiente.
		if cmd == "follow":
			var rel_h := get_bot_relationship(int(b["bot_id"]), skey)
			var tr_h := float(rel_h.get("trust", 0.0))
			var ho_h := float(rel_h.get("hostility", 0.0))
			if tr_h >= _convince_threshold(b) and ho_h < 0.80:
				return {"ok": true, "why": "conversion"}
			return {"ok": false, "why": "wary" if tr_h > -0.10 else "hostile"}
		var rel_h2 := get_bot_relationship(int(b["bot_id"]), skey)
		var why_h := "wary" if float(rel_h2.get("trust", 0.0)) > 0.05 else "hostile"
		return {"ok": false, "why": why_h}
	var rel := get_bot_relationship(int(b["bot_id"]), skey)
	if int(rel.get("attacked", 0)) >= 1 and float(rel.get("hostility", 0.0)) >= 0.5:
		return {"ok": false, "why": "betrayed"}
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
				# Conversion: el hostil convencido baja el arma y pasa a aliado.
				if str(b.get("faction", "")) == "hostile":
					_set_bot_faction(b, "friendly")
					var rel_cv := get_bot_relationship(bot_id, skey)
					rel_cv["trust"] = maxf(float(rel_cv.get("trust", 0.0)), 0.62)
					rel_cv["hostility"] = minf(float(rel_cv.get("hostility", 0.0)), 0.12)
					rel_cv["fear"] = minf(float(rel_cv.get("fear", 0.0)), 0.30)
					_record_milestone(bot_id, "converted")
					record_social_event(bot_id, skey, sname, "ally", 0.45, "converted_friendly")
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
			_ai_note_foe_intel(b, foe, foe.global_position, "told")
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
	var fem := int(b.get("bot_id", 0)) == 901
	if ok:
		match cmd:
			"follow":
				return "Vale, voy contigo... tú mandas." if warm else "De acuerdo, te sigo. No me hagas arrepentirme."
			"stay":
				return ("Vale, me quedo aquí vigilando, tranquila." if fem else "Vale, me quedo aquí vigilando, tranquilo.") if warm else "Bien, me quedo quieto aquí."
			"come":
				return "Voy para allá, espérame un segundo." if warm else "Ya voy para allá."
			"dismiss":
				return "Entendido, sigo por mi cuenta. Cuídate ahí fuera." if warm else "De acuerdo, me marcho."
			"eat":
				return "Sí, la verdad es que me vendría bien comer algo." if warm else "Vale, como algo rápido."
			"equip":
				return "Buena idea, voy a ver si encuentro mejor equipo." if warm else "Iré a mirar qué encuentro por ahí."
			"give":
				return "Claro, toma... te lo dejo aquí en el suelo." if warm else "Ahí lo tienes, quédatelo."
			"attack":
				return "¡Voy a por él!" if float(pers.get("aggression", 0.35)) > 0.5 else "Vale, vamos a por él... cúbreme."
	match why:
		"hostile":
			return "¿Órdenes? A mí no me mandas."
		"wary":
			return "Todavía no me fío de ti... pero reconozco que no vienes a por mí." if warm else "No me fío. Demuestra que no eres peligroso."
		"betrayed":
			return "Después de lo que me hiciste, olvídate."
		"scared":
			return "Ni se te ocurra acercarte... déjame en paz."
		"busy":
			return "¡Ahora no, que estoy en medio de una pelea!"
		"other_team":
			return "Ya voy con gente, no les voy a dejar tirados."
		"no_food":
			return "Ojalá, pero no llevo nada de comer encima."
		"nothing":
			return "Lo siento, ahora mismo no llevo nada que darte."
		"no_target":
			return "¿Atacar a quién? No veo ningún peligro por aquí."
	return "Oye, que apenas te conozco... ¿por qué iba a hacerte caso?" if warm else "No me fío de ti lo suficiente."

# Linea especial cuando un HOSTIL acepta unirse: el momento de la conversion.
func _chat_conversion_line(b: Dictionary) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.5
	if warm:
		return "Bajo la guardia: 'De acuerdo... pero si me fallas, no me lo perdono.'"
	return "Te estudia en silencio y escupe al suelo: '...Está bien. Demuestra que puedo fiarme.'"

# Tregua por chat/voz: el hostil deja de disparar al emisor durante un tiempo.
# Exige proximidad (<=90 m) o combate activo contra el emisor; un agresor
# reciente e iracundo (3+ ataques y hostilidad >=0.92) la rechaza.
func _chat_handle_truce(b: Dictionary, sender_id: int, sname: String, skey: String) -> void:
	var bot_id := int(b["bot_id"])
	var proxy: Node3D = b["proxy"]
	var snode := _find_actor_by_peer_id(sender_id)
	var aggro: Node3D = b.get("aggro_target")
	var fighting := aggro != null and is_instance_valid(aggro) and snode != null and is_instance_valid(snode) and aggro == snode
	var near := snode != null and is_instance_valid(snode) and proxy.global_position.distance_to((snode as Node3D).global_position) <= 90.0
	if not fighting and not near:
		_bot_chat_send(b, sender_id, sname, "¿Tregua? Ni te veo ni te oigo desde ahí... acércate.", "order")
		return
	var rel := get_bot_relationship(bot_id, skey)
	if int(rel.get("attacked", 0)) >= 3 and float(rel.get("hostility", 0.0)) >= 0.92:
		_bot_chat_send(b, sender_id, sname, "No. Ya sabes lo que te espera si sigues aquí.", "order")
		return
	if fighting:
		b["aggro_target"] = null
		b["aggro_timer"] = 0.0
	b["_truce_peer"] = sender_id
	b["_truce_t"] = 75.0
	b["sitting"] = false
	b["sleeping"] = false
	record_social_event(bot_id, skey, sname, "ally", 0.06, "truce")
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.5
	var line := "Está bien... bajo el arma, pero no te fíes de que soy de fiar." if warm else "Tregua. Pero si me disparas, no respondo."
	if str(b.get("faction", "")) != "hostile":
		line = "Tranquilo, no te estaba disparando." if warm else "No hacía falta, no te disparo."
	_bot_chat_send(b, sender_id, sname, line, "order")

func _chat_handle_order(b: Dictionary, sender_id: int, sname: String, skey: String, cmd: String, arg: String) -> void:
	if cmd == "truce":
		_chat_handle_truce(b, sender_id, sname, skey)
		return
	var faction_before := str(b.get("faction", ""))
	var gate := _chat_order_gate(b, sender_id, skey, cmd)
	var why := str(gate.get("why", ""))
	var ok := bool(gate.get("ok", false))
	if ok:
		why = _chat_apply_order(b, sender_id, sname, cmd, arg)
		ok = why.is_empty()
	var line := _chat_order_line(b, cmd, ok, why)
	if ok and faction_before == "hostile" and str(b.get("faction", "")) == "friendly":
		line = _chat_conversion_line(b)
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
	if float(b.get("hunger", 100.0)) < 18.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b)):
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
		if oid == my_id or not _bot_pair_can_cooperate(my_id, int(oid)):
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
					b["_meet_promise"] = {"id": sender_id, "kind": "help", "t": Time.get_ticks_msec()}
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
	# Negarse pudiendo (desconfianza/hostilidad/guardarse el arma) queda en la
	# memoria del que pidio — las negativas constantes de ayuda a compañeros
	# de equipo acaban en expulsion. No poder ayudar, o rechazar a un agresor
	# recordado, no enseña egoísmo a la víctima ni genera otra deuda social.
	if not ok and sender_is_bot and why in ["distrust", "hostile", "keep_weapon", "scared"]:
		record_social_event(sender_id, "bot_%d" % bot_id, str(b.get("name", "")), "refused", 0.16, "denied_" + cmd + "_" + why)
		if bots.has(sender_id):
			_bot_evaluate_after_refusal(bots[sender_id], bot_id, cmd)

func _chat_request_line(b: Dictionary, cmd: String, ok: bool, why: String) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.55 and float(pers.get("aggression", 0.35)) < 0.5
	if ok:
		if cmd == "assist":
			return "¡Aguanta ahí, que voy corriendo!" if warm else "Ya voy para allá, no te muevas."
		return "Toma, te lo dejo aquí mismo." if warm else "Vale, ahí te lo dejo en el suelo."
	match why:
		"hostile":
			return "Pídeselo a otro, tú y yo no somos amigos."
		"betrayed":
			return "¿En serio? Me atacaste antes y ahora vienes a pedirme."
		"scared":
			return "No te acerques más... largo de aquí."
		"busy":
			return "¡¿Pero no ves que estoy peleando por mi vida?!"
		"keep_weapon":
			return "Lo siento, pero es la única arma que tengo."
		"nothing", "no_food":
			return "No me queda nada encima, de verdad."
		"no_target":
			return "No veo a nadie cerca a quien atacar."
	return "Lo siento mucho, yo también voy muy justo." if warm else "No tengo nada de sobra para repartir."

# ==================== NEGATIVA A UNA PETICION → DECISION DE SUPERVIVENCIA ====================
# El ciclo conversacion↔supervivencia: el bot pidio algo que necesitaba de
# verdad y se lo negaron. Pesa la urgencia (hambre/sed/vida), la relacion con
# quien le nego (confianza/hostilidad/nº de negativas) y su caracter: rogar
# otra vez, robarle en su refugio, tomarlo por la fuerza o buscarse la vida.
# Peticion pendiente a este emisor que acaba de negar ("no", "largate",
# "ni de cona"): la niega queda en memoria (refused) y el bot reevalua —
# devuelve "decision:necesidad" para la respuesta, o "" si no habia peticion.
func _chat_maybe_refuse(tb: Dictionary, target_id: int, sender_id: int, sender_name: String, skey: String) -> String:
	var asked: Dictionary = tb.get("_asked", {})
	if asked.is_empty() or int(asked.get("id", 0)) != sender_id:
		return ""
	if Time.get_ticks_msec() - int(asked.get("t", 0)) >= 120000:
		tb["_asked"] = {}
		return ""
	var need := str(asked.get("need", "algo"))
	record_social_event(target_id, skey, sender_name, "refused", 0.16, "denied_" + need)
	tb["_asked"] = {}
	return _bot_evaluate_after_refusal(tb, sender_id, need) + ":" + need

func _bot_evaluate_after_refusal(b: Dictionary, refuser_id: int, need: String = "algo") -> String:
	var my_id := int(b["bot_id"])
	var skey := _actor_persist_key(refuser_id)
	var rel := get_bot_relationship(my_id, skey)
	var refused_n := int(rel.get("refused", 0))
	var pers := _get_bot_personality(b)
	var proxy: Node3D = b["proxy"]
	var urgent := float(b.get("hunger", 100.0)) < 30.0 or float(b.get("thirst", 100.0)) < 25.0 or float(b.get("health", 100.0)) < 40.0
	var decision := "forage"
	if urgent:
		var tr := float(rel.get("trust", 0.0))
		var host := float(rel.get("hostility", 0.0))
		var armed := not _best_weapon_name(proxy).is_empty()
		var brave := float(pers.get("bravery", 0.5))
		var aggr := float(pers.get("aggression", 0.35))
		# Primera negativa y aun confia: insiste una vez mas con un ruego.
		if refused_n < 2 and tr > 0.10 and host < 0.35:
			decision = "negotiate"
		# Por la fuerza: armado, agresivo o con rencor, y suficientemente valiente.
		elif armed and brave > 0.45 and (aggr > 0.55 or host > 0.45 or refused_n >= 3):
			decision = "attack"
		# Robarle en su refugio si tiene uno conocido (los cautos prefieren hurtar).
		elif not _find_shelter_by_owner(refuser_id).is_empty() and (brave < 0.6 or not armed):
			decision = "steal"
	b["_survive_decision"] = {"kind": decision, "target_id": refuser_id, "t": Time.get_ticks_msec(), "need": need}
	_bot_apply_refusal_decision(b)
	record_bot_event(my_id, "refused_decide", skey, _poi_kind_near(proxy.global_position), proxy.global_position, "%s por denied %s" % [decision, need])
	return decision

# Refugio construido por ese actor (bot o humano): ids bot_shelter_<id>_ y
# player_shelter_<id>_ — donde guarda su alijo para robarselo.
func _find_shelter_by_owner(actor_id: int) -> Dictionary:
	if world == null or not ("_built_shelters" in world):
		return {}
	var prefix := ("bot_shelter_%d" if is_bot_peer_id(actor_id) else "player_shelter_%d") % actor_id
	for sh in world._built_shelters:
		if sh is Dictionary and str((sh as Dictionary).get("id", "")).begins_with(prefix):
			return sh
	return {}

# Ejecuta la decision tomada tras la negativa: rogar=pedir otra vez pronto,
# robar=marchar a su refugio, atacar=aggro directo, forrajear=la IA normal.
func _bot_apply_refusal_decision(b: Dictionary) -> void:
	var dec: Dictionary = b.get("_survive_decision", {})
	var kind := str(dec.get("kind", ""))
	var tid := int(dec.get("target_id", 0))
	match kind:
		"attack":
			var node := _find_actor_by_peer_id(tid)
			if node != null and is_instance_valid(node):
				b["aggro_target"] = node
				b["aggro_timer"] = 30.0
				_ai_note_foe_intel(b, node, node.global_position, "told")
				_command_bot_wolf_against(b, node)
		"steal":
			var sh := _find_shelter_by_owner(tid)
			if not sh.is_empty():
				b["_steal_target"] = {"id": str(sh.get("id", "")), "t": Time.get_ticks_msec()}
				b["_s_raid_shelter"] = sh
		"negotiate":
			# Ruego otra vez pronto: la proxima peticion llega antes del CD normal.
			_chat_req_until[int(b["bot_id"])] = Time.get_ticks_msec() + 35000
	# "forage": nada que forzar — el hambre manda por la via normal.

# ==================== REGALOS POR CHAT/VOZ ====================
# "te doy pan", "toma esto", "aqui tienes vendas": el jugador ofrece un objeto
# del inventario. El bot lo acepta — o lo rechaza si esta iracundo — y la
# confianza sube. Funciona igual para chat escrito y voz transcrita porque
# ambos llegan por on_chat_received.

const GIFT_OFFER_WORDS := [" te doy ", " te paso ", " te regalo ", " toma ", " aqui tienes ", " para ti ", " aceptas ", " te dejo ", " ten esto ", " tenlo ", " cogelo ", " puedo darte ", " quiero darte ", " te ofrezco ", " te traigo "]
const GIFT_ITEM_WORDS := ["piedra afilada", "piedra", "cantimplora", "botella", "agua", "sed", "bebe", "comida", "pan", "carne", "lata", "verduras", "fruta", "setas", "seta", "vendaje", "venda", "vendas", "botiquin", "medicina", "pastillas", "arma", "pistola", "rifle", "fusil", "escopeta", "cuchillo", "navaja", "hacha", "municion", "balas", "flechas", "arco", "antorcha", "linterna", "mecha", "cerillas", "matches", "ropa", "chaqueta", "abrigo", "botas", "zapatos", "gorra", "guantes", "mochila", "bateria", "pila", "pilas", "cuerda", "alambre", "clavos", "tablones", "tablon", "semillas", "azada", "pico", "pala", "cana", "cebo", "carnada", "manta", "soga", "caja"]
const GIFT_WORD_TYPES := {
	"agua": ["water"], "sed": ["water"], "bebe": ["water"],
	"botella": ["water", "resource"], "cantimplora": ["water", "resource"],
	"comida": ["food"], "pan": ["food"], "carne": ["food"], "lata": ["food"], "verduras": ["food"], "fruta": ["food"], "setas": ["food"], "seta": ["food"],
	"vendaje": ["medical"], "venda": ["medical"], "vendas": ["medical"], "botiquin": ["medical"], "medicina": ["medical"], "pastillas": ["medical"],
	"arma": ["weapon", "weapon_rifle", "weapon_bow", "tool_axe", "axe_tool", "tool_spear"], "pistola": ["weapon"], "rifle": ["weapon_rifle"], "fusil": ["weapon_rifle"], "escopeta": ["weapon"],
	"cuchillo": ["weapon", "tool"], "navaja": ["weapon", "tool"], "hacha": ["weapon", "tool_axe", "axe_tool", "tool"],
	"municion": ["ammo"], "balas": ["ammo"], "flechas": ["ammo_arrow", "ammo"], "arco": ["weapon_bow"],
	"antorcha": ["tool_torch"], "linterna": ["tool_torch", "tool"], "mecha": ["tool_matches", "resource"], "cerillas": ["tool_matches", "resource"], "matches": ["tool_matches", "resource"],
	"ropa": ["clothing"], "chaqueta": ["clothing"], "abrigo": ["clothing"], "botas": ["clothing"], "zapatos": ["clothing"], "gorra": ["clothing"], "guantes": ["clothing"],
	"mochila": ["backpack"], "bateria": ["battery", "resource"], "pila": ["battery", "resource"], "pilas": ["battery", "resource"],
	"cuerda": ["resource", "tool"], "alambre": ["resource"], "clavos": ["resource"], "tablones": ["resource"], "tablon": ["resource"], "semillas": ["resource", "tool_hoe"],
	"azada": ["tool_hoe"], "pico": ["tool_pickaxe"], "pala": ["tool_shovel"], "cana": ["tool_fishing"], "cebo": ["resource"], "carnada": ["resource"],
	"piedra": ["resource"], "piedra afilada": ["resource"],
}

func _chat_parse_gift(text: String) -> Dictionary:
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("?", " ").replace("¿", " ").replace("!", " ").replace("¡", " ").replace(",", " ").replace(".", " ") + " "
	var offer := false
	for kw in GIFT_OFFER_WORDS:
		if t.contains(kw):
			offer = true
			break
	if not offer:
		return {}
	for w in GIFT_ITEM_WORDS:
		if t.contains(" " + w + " "):
			return {"word": w}
	# Sin item nombrado no es regalo: "te dejo en paz" sigue siendo una orden.
	return {}

# Match por nombre con limite de palabra ("pan" no casa con "pantalones") y,
# en segunda pasada, por categoria de tipo.
func _gift_name_match(word: String, item_name: String) -> bool:
	var wl := word.to_lower()
	if wl.is_empty():
		return false
	return (" " + item_name.to_lower() + " ").contains(" " + wl + " ")

func _gift_word_match(word: String, item_name: String, item_type: String) -> bool:
	if _gift_name_match(word, item_name):
		return true
	var types: Array = GIFT_WORD_TYPES.get(word.to_lower(), [])
	return not types.is_empty() and types.has(item_type)

# Busca el objeto ofrecido en el inventario del que habla: proxies de jugadores
# remotos (saved_inventory del servidor) o el inventario local del host.
func _find_gift_in_inventory(sender_id: int, word: String) -> Dictionary:
	var cands: Array = []
	var sp = null
	if world != null and "server_proxies" in world and world.server_proxies.has(sender_id):
		sp = world.server_proxies[sender_id]
	var lp = world.get("player") if world != null else null
	var net = world.get("net") if world != null else null
	var my_id: int = net.get_my_id() if (net != null and net.has_method("get_my_id")) else 1
	if sp != null and sp.has_meta("saved_inventory"):
		var sinv: Array = sp.get_meta("saved_inventory", [])
		for i in range(sinv.size()):
			var d = sinv[i]
			if d is Dictionary:
				cands.append({"name": str(d.get("name", "")), "type": str(d.get("type", "")), "weight": float(d.get("weight", 0.5)), "use_value": float(d.get("use_value", 0.0)), "qty": int(d.get("quantity", 1)), "remote": true, "idx": i})
	elif lp != null and sender_id == my_id and lp.get("inventory") != null:
		var litems: Array = lp.inventory.items
		for i in range(litems.size()):
			var it = litems[i]
			if it == null:
				continue
			cands.append({"name": str(it.item_name), "type": str(it.item_type), "weight": float(it.weight), "use_value": float(it.use_value), "qty": int(it.quantity), "remote": false, "idx": i})
	# Primera pasada: solo coincidencia por nombre; segunda: nombre o categoria.
	for want_name in [true, false]:
		for c in cands:
			var hit := _gift_name_match(word, str(c["name"])) if want_name else _gift_word_match(word, str(c["name"]), str(c["type"]))
			if hit:
				return c
	return {}

func _gift_remove_from_sender(sender_id: int, found: Dictionary) -> void:
	if bool(found.get("remote", false)):
		if world != null and world.has_method("_saved_inventory_remove"):
			world._saved_inventory_remove(sender_id, str(found["name"]), str(found["type"]), 1)
		var net = world.get("net") if world != null else null
		if net != null and net.is_connected and net.is_host and net.peer != null and net.peer_alive(sender_id) and net.has_method("bot_gift_taken"):
			net.bot_gift_taken.rpc_id(sender_id, str(found["name"]), str(found["type"]))
	else:
		var lp = world.get("player") if world != null else null
		if lp != null and lp.get("inventory") != null:
			var litems: Array = lp.inventory.items
			lp.inventory.remove_index(int(found["idx"]), 1)
			var held_ref = lp.get("_held_item_reference")
			if held_ref != null and not bool(lp.get("_held_item_external")) and not litems.has(held_ref):
				lp._held_item_reference = null
				lp.held_index = -1
			if lp.has_method("_sync_held_item"):
				lp._sync_held_item()
			if world.has_method("_sync_local_player_inventory"):
				world._sync_local_player_inventory()

func _deliver_notice_to_sender(sender_id: int, msg: String) -> void:
	if msg.is_empty() or world == null:
		return
	var net = world.get("net")
	if net != null and net.is_connected and net.is_host and sender_id != net.get_my_id() and net.peer != null and net.peer_alive(sender_id) and net.has_method("notice_to_client"):
		net.notice_to_client.rpc_id(sender_id, msg)
	elif world.get("player") is Node and is_instance_valid(world.player):
		world.player.notice.emit(msg)

func _chat_handle_gift(b: Dictionary, sender_id: int, sname: String, skey: String, word: String, clean_text: String) -> void:
	var bot_id := int(b["bot_id"])
	var proxy: Node3D = b["proxy"]
	var snode := _find_actor_by_peer_id(sender_id)
	if snode == null or not is_instance_valid(snode) or proxy.global_position.distance_to((snode as Node3D).global_position) > 16.0:
		_bot_chat_send(b, sender_id, sname, "¿Que me lo das desde ahí? Acércate primero.", "order")
		return
	if word.is_empty():
		_bot_chat_send(b, sender_id, sname, "¿Qué es? Dime qué llevas encima.", "order")
		return
	var rel := get_bot_relationship(bot_id, skey)
	if str(b.get("faction", "")) == "hostile" and float(rel.get("hostility", 0.0)) >= 0.95 and int(rel.get("attacked", 0)) >= 3:
		_bot_chat_send(b, sender_id, sname, "¡Quita eso de ahí! ¡Te dije que no!", "order")
		return
	var found := _find_gift_in_inventory(sender_id, word)
	if found.is_empty():
		_bot_chat_send(b, sender_id, sname, "No veo que lleves nada de eso encima.", "order")
		return
	_gift_remove_from_sender(sender_id, found)
	var msg := interact_with_bot(bot_id, sender_id, "give:%s|%s|%s|%s" % [str(found["name"]), str(found["type"]), str(found["weight"]), str(found["use_value"])])
	_deliver_notice_to_sender(sender_id, msg)
	if int(b.get("_asked", {}).get("id", 0)) == sender_id:
		b["_asked"] = {} # la peticion pendiente quedo respondida con ayuda
	# El bot reacciona en voz al regalo como a un mensaje de chat normal.
	b["_chat_inbox"] = {"from_id": sender_id, "from_name": sname, "text": clean_text, "intent": "gift"}
	b["_chat_reply_ready"] = 0
	b["_soc_t"] = 0.0

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
	_evolve_personality(b, "voice_taught", 0.25)
	record_strategy_outcome(bid, "forage" if kind == "water" else "explore", true, 0.08)
	# Y se lo cuenta al resto: un aliado cercano tambien aprende el dato
	for oid in bots.keys():
		if oid != bid:
			observe_location(oid, "taught:%d:%d" % [int(pos.x / 30.0), int(pos.z / 30.0)], kind if kind != "danger" else "wild", pos, "shared")

func _chat_teach_line(b: Dictionary, kind: String) -> String:
	var pers := _get_bot_personality(b)
	var warm := float(pers.get("sociability", 0.5)) > 0.55 and float(pers.get("aggression", 0.35)) < 0.5
	match kind:
		"water":
			return "Genial, así ya sé dónde venir a beber. Muchas gracias." if warm else "Vale, me quedo con que aquí hay agua."
		"danger":
			return "Vale, gracias por avisar... tendré cuidado por esta zona." if warm else "Entendido, andaré con ojo por aquí."
		"loot":
			return "Perfecto, luego me acerco a echar un vistazo." if warm else "Vale, me lo apunto para registrarlo."
		"camp":
			return "Sí, parece buen sitio para descansar... gracias." if warm else "Vale, buen sitio para acampar."
	return "Me quedo con el sitio, gracias por avisar." if warm else "Vale, me acuerdo del lugar."

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

# ==================== VOZ HUMANO <-> BOT (STT + TTS local/Groq) ====================
# El jugador habla con [V]: el PCM 8-bit u8 12 kHz se acumula, un silencio
# corto (0.85 s) cierra la frase, se escribe un WAV en user://voice_jobs/ y el
# demonio transcribe a <base>.txt. Solo se oye a quemarropa (BOT_VOICE_RANGE);
# si el bot seleccionado esta lejos pero otro bot esta cerca, escucha el
# cercano, y si la frase nombra a un bot ("Elena", "Carlos", "Kael"), contesta
# ese bot siempre que este al alcance de la voz.
# La respuesta del bot al humano sale HABLADA (no por chat de texto): se
# encola <base>.json, el demonio sintetiza <base>.pcm con la voz del personaje
# y el servidor emite paquetes de 600 muestras por relay_actor_voice.

const BOT_VOICE_RANGE := 55.0
const BOT_VOICE_GAP_MSEC := 850
const BOT_VOICE_MAX_BYTES := 240000 # ~20 s a 12 kHz u8
const VOICE_JOBS_DIR := "user://voice_jobs/"
const TTS_PACKET_SAMPLES := 600
const TTS_STREAM_RATE := 12400.0 # ligeramente >12 kHz para mantener buffer sin underrun

var _voice_bufs: Dictionary = {}       # "sid_bid" -> {pcm, last, sid, bid, sname}
var _voice_jobs: Dictionary = {}       # basename -> {bot_id, sender_id, sender_name, born}
var _voice_far_notice: Dictionary = {} # sid -> msec
var _tts_jobs: Dictionary = {}         # basename -> {bot_id, bot_name, to_id, to_name, text, born}
var _tts_streams: Array = []           # [{bot_id, bot_name, to_id, to_name, pcm, offset, budget}]
var _tts_seq: int = 0

func _nearest_hearing_bot_id(from_pos: Vector3, preferred_id: int = 0) -> int:
	if preferred_id > 0 and bots.has(preferred_id):
		var pb: Dictionary = bots[preferred_id]
		var pp: Node3D = pb.get("proxy")
		if pp != null and is_instance_valid(pp) and not bool(pp.get_meta("proxy_dead", false)):
			var max_pref := 90.0 if pb.get("aggro_target") != null else BOT_VOICE_RANGE
			if pp.global_position.distance_to(from_pos) <= max_pref:
				return preferred_id
	var best_id := 0
	var best_d := 90.0
	for bid in bots.keys():
		var b: Dictionary = bots[bid]
		var pr: Node3D = b.get("proxy")
		if pr == null or not is_instance_valid(pr) or bool(pr.get_meta("proxy_dead", false)):
			continue
		var max_r := 90.0 if b.get("aggro_target") != null else BOT_VOICE_RANGE
		var d := pr.global_position.distance_to(from_pos)
		if d <= max_r and d <= best_d:
			best_d = d
			best_id = int(bid)
	return best_id

# Si la frase nombra explicitamente a un bot ("elena", "carlos", "kael"),
# enruta a ese bot SOLO si esta dentro de BOT_VOICE_RANGE; si esta lejos no
# puede oirlo y nadie mas responde en su nombre.
func _voice_resolve_named_bot(text: String, sender_id: int, default_bot_id: int) -> int:
	var snode := _find_actor_by_peer_id(sender_id)
	var spos := Vector3.INF
	if snode != null and is_instance_valid(snode):
		spos = snode.global_position
	var t := " " + text.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace(",", " ").replace(".", " ").replace("?", " ").replace("¿", " ").replace("!", " ").replace("¡", " ") + " "
	var named_id := 0
	for bid in bots.keys():
		var bname := str((bots[bid] as Dictionary).get("name", "")).to_lower()
		if not bname.is_empty() and t.contains(" " + bname + " "):
			named_id = int(bid)
			break
	if named_id > 0:
		if spos == Vector3.INF:
			return named_id
		var nb: Dictionary = bots.get(named_id, {})
		var np: Node3D = nb.get("proxy")
		if np != null and is_instance_valid(np) and not bool(np.get_meta("proxy_dead", false)) and np.global_position.distance_to(spos) <= BOT_VOICE_RANGE:
			return named_id
		return 0 # preguntaron por un bot que no esta cerca -> no oye
	if spos != Vector3.INF:
		return _nearest_hearing_bot_id(spos, default_bot_id)
	return default_bot_id if bots.has(default_bot_id) else 0

func on_voice_received(target_id: int, sender_id: int, sender_name: String, pcm: PackedByteArray) -> void:
	if pcm.is_empty():
		return
	var snode := _find_actor_by_peer_id(sender_id)
	if snode == null or not is_instance_valid(snode):
		return
	var listener_id := _nearest_hearing_bot_id(snode.global_position, target_id)
	if listener_id <= 0:
		var nowm0 := Time.get_ticks_msec()
		var last_notice := int(_voice_far_notice.get(sender_id, -1))
		if last_notice < 0 or nowm0 - last_notice > 10000:
			_voice_far_notice[sender_id] = nowm0
		return
	var key := "%d_%d" % [sender_id, listener_id]
	var entry: Dictionary = _voice_bufs.get(key, {"pcm": PackedByteArray(), "last": 0, "sid": sender_id, "bid": listener_id, "sname": sender_name})
	var buf: PackedByteArray = entry["pcm"]
	buf.append_array(pcm)
	if buf.size() > BOT_VOICE_MAX_BYTES:
		buf = buf.slice(buf.size() - BOT_VOICE_MAX_BYTES)
	entry["pcm"] = buf
	entry["last"] = Time.get_ticks_msec()
	_voice_bufs[key] = entry

# En tick(): cierra frases por silencio, recoge transcripciones STT y emite el
# audio TTS sintetizado de las respuestas de los bots.
func _voice_tick(delta: float) -> void:
	var nowm := Time.get_ticks_msec()
	for k in _voice_bufs.keys():
		var e: Dictionary = _voice_bufs[k]
		if nowm - int(e.get("last", 0)) > BOT_VOICE_GAP_MSEC:
			_voice_bufs.erase(k)
			_voice_enqueue_job(e)
	if not _voice_jobs.is_empty():
		_voice_poll_jobs()
	if not _tts_jobs.is_empty():
		_tts_poll_jobs()
	if not _tts_streams.is_empty():
		_tts_stream_tick(delta)

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
		var sid := int(job["sender_id"])
		var sname := str(job.get("sender_name", "?"))
		var bid := _voice_resolve_named_bot(text, sid, int(job["bot_id"]))
		if bid <= 0 or not bots.has(bid):
			continue
		chat_log.append({"ts": int(Time.get_unix_time_from_system()), "from_id": sid, "from": sname,
			"to_id": bid, "to": _actor_display_name(bid), "kind": "voice", "text": text})
		while chat_log.size() > BOT_CHAT_LOG_MAX:
			chat_log.pop_front()
		on_chat_received(bid, sid, sname, text)

func _tts_enqueue_job(bot_id: int, bot_name: String, to_id: int, to_name: String, text: String) -> void:
	if text.is_empty() or to_id <= 0:
		return
	_tts_seq += 1
	var base := "tts_%d_%d_%d_%d" % [bot_id, to_id, Time.get_ticks_msec() % 10000000, _tts_seq]
	var dir := ProjectSettings.globalize_path(VOICE_JOBS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var jpath: String = dir + base + ".json"
	var f := FileAccess.open(jpath, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"bot_id": bot_id,
		"bot_name": bot_name,
		"to_id": to_id,
		"to_name": to_name,
		"text": text,
	}))
	f.close()
	_tts_jobs[base] = {
		"bot_id": bot_id,
		"bot_name": bot_name,
		"to_id": to_id,
		"to_name": to_name,
		"text": text,
		"born": Time.get_ticks_msec(),
	}

func _tts_poll_jobs() -> void:
	var dir := ProjectSettings.globalize_path(VOICE_JOBS_DIR)
	var nowm := Time.get_ticks_msec()
	var net = world.get("net") if world != null else null
	for base in _tts_jobs.keys():
		var job: Dictionary = _tts_jobs[base]
		var mp3_path: String = dir + str(base) + ".mp3"
		var pcm_path: String = dir + str(base) + ".pcm"
		var json_path: String = dir + str(base) + ".json"
		var has_mp3 := FileAccess.file_exists(mp3_path)
		var has_pcm := FileAccess.file_exists(pcm_path)
		var done := has_mp3 or has_pcm
		var mp3 := PackedByteArray()
		var pcm := PackedByteArray()
		if has_mp3:
			mp3 = FileAccess.get_file_as_bytes(mp3_path)
		if has_pcm:
			pcm = FileAccess.get_file_as_bytes(pcm_path)
		elif not done and nowm - int(job.get("born", 0)) > 8000:
			done = true
		if not done:
			continue
		_tts_jobs.erase(base)
		DirAccess.remove_absolute(mp3_path)
		DirAccess.remove_absolute(pcm_path)
		DirAccess.remove_absolute(json_path)
		var bid := int(job["bot_id"])
		var bname := str(job.get("bot_name", "Bot"))
		var tid := int(job["to_id"])
		var tname := str(job.get("to_name", ""))
		# Prioridad: MP3 24 kHz 16-bit wideband en un unico RPC fiable
		if not mp3.is_empty() and net != null and net.has_method("relay_actor_voice_mp3"):
			net.relay_actor_voice_mp3(bid, bname, mp3, tid, tname)
			continue
		if pcm.is_empty():
			continue
		for i in range(_tts_streams.size() - 1, -1, -1):
			var s0: Dictionary = _tts_streams[i]
			if int(s0.get("bot_id", 0)) == bid and int(s0.get("to_id", 0)) == tid:
				_tts_streams.remove_at(i)
		_tts_streams.append({
			"bot_id": bid,
			"bot_name": bname,
			"to_id": tid,
			"to_name": tname,
			"pcm": pcm,
			"offset": 0,
			"budget": float(TTS_PACKET_SAMPLES * 3),
		})

func _tts_stream_tick(delta: float) -> void:
	var net = world.get("net") if world != null else null
	for i in range(_tts_streams.size() - 1, -1, -1):
		var st: Dictionary = _tts_streams[i]
		var pcm: PackedByteArray = st["pcm"]
		var off := int(st.get("offset", 0))
		var budget := float(st.get("budget", 0.0)) + maxf(delta, 0.016) * TTS_STREAM_RATE
		while budget >= float(TTS_PACKET_SAMPLES) and off < pcm.size():
			var end_idx := mini(off + TTS_PACKET_SAMPLES, pcm.size())
			var chunk := pcm.slice(off, end_idx)
			off = end_idx
			budget -= float(TTS_PACKET_SAMPLES)
			if net != null and net.has_method("relay_actor_voice"):
				net.relay_actor_voice(int(st["bot_id"]), str(st["bot_name"]), chunk, int(st["to_id"]), str(st.get("to_name", "")))
		if off >= pcm.size():
			_tts_streams.remove_at(i)
		else:
			st["offset"] = off
			st["budget"] = budget
			_tts_streams[i] = st

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
# por el mismo canal interno, a un humano HABLADO por voz sintetizada (TTS ->
# relay_actor_voice), nunca por texto en el panel del jugador.
func _bot_chat_send(b: Dictionary, to_id: int, to_name: String, text: String, kind: String) -> void:
	var clean := _chat_sanitize(text)
	if clean.is_empty():
		clean = _chat_fallback_line(b, kind, to_name, "")
	if clean.is_empty():
		return
	var my_id := int(b["bot_id"])
	# Anti-repeticion: el mismo bot no encadena dos veces la misma frase. Las
	# respuestas salen igual (el jugador espera contestacion); el resto se cae.
	var recent: Array = _chat_recent.get(my_id, [])
	# Confirmar otra enseñanza humana también es una respuesta solicitada,
	# aunque coincida la plantilla (p. ej. dos fuentes de agua distintas).
	var requested_reply := kind == "reply" or (kind == "teach" and to_id > 0 and not bots.has(to_id))
	if not requested_reply and not recent.is_empty() and String(recent.back()) == clean:
		return
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
	recent = _chat_recent.get(my_id, [])
	recent.append(clean)
	while recent.size() > BOT_CHAT_RECENT_MAX:
		recent.pop_front()
	_chat_recent[my_id] = recent
	_record_milestone(my_id, "first_chat")
	if bots.has(to_id):
		on_chat_received(to_id, my_id, sname, clean)
	else:
		# Ademas de la voz, el texto queda en el panel de chat del jugador.
		var net = world.get("net") if world != null else null
		if net != null and net.has_method("relay_actor_chat"):
			net.relay_actor_chat(my_id, sname, clean, to_id, to_name)
		_tts_enqueue_job(my_id, sname, to_id, to_name, clean)

# Decide canal (Qwen si hay clave+cola libre; si no, plantilla) y aplica los
# enfriamientos. kind: reply|greet|help|alliance|whisper|taunt.
func _chat_dispatch(b: Dictionary, kind: String, to_id: int, to_name: String, ctx: String = "", intent: String = "") -> void:
	if to_id <= 0:
		return
	var my_id := int(b["bot_id"])
	if kind in ["help", "request", "alliance"] and not _bot_pair_can_cooperate(my_id, to_id):
		return
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
	if _chat_attempt_llm(b, kind, to_id, to_name, ctx, intent):
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
		var from_id_in := int(inbox.get("from_id", 0))
		var from_human := not bots.has(from_id_in)
		if from_human or now >= int(b.get("_chat_reply_ready", 0)):
			b["_chat_inbox"] = {}
			b["_chat_reply_ready"] = now + int((1.5 if from_human else BOT_CHAT_REPLY_CD) * 1000.0)
			_chat_dispatch(b, "reply", from_id_in, str(inbox.get("from_name", "?")), str(inbox.get("text", "")), str(inbox.get("intent", "talk")))
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
				# Peticion pendiente: una negativa de este actor dentro de 2 min
				# cuenta como "refused" y dispara la reevaluacion de supervivencia.
				b["_asked"] = {"id": int(rec["id"]), "need": need, "t": now}
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

# Cooperation is bilateral: the aggressor must not assume the victim will
# rescue them. Persistent killer history survives respawns and friendly chat.
func _bot_pair_can_cooperate(a: int, other: int) -> bool:
	if not is_bot_peer_id(a) or not is_bot_peer_id(other):
		return true
	for pair in [[a, other], [other, a]]:
		var owner := int(pair[0])
		var key := "bot_%d" % int(pair[1])
		var rel := get_bot_relationship(owner, key)
		if float(rel.get("hostility", 0.0)) > 0.5 or float(rel.get("trust", 0.0)) < -0.2:
			return false
		if rel.has("harm_t") and Time.get_ticks_msec() - int(rel.harm_t) < REL_PEACE_MS:
			return false
		var mem := _ensure_bot_memory(owner)
		var killer: Dictionary = (mem.get("killers", {}) as Dictionary).get(key, {})
		var kills := int(killer.get("count", 0))
		if kills > 0:
			# Old memories lack a baseline: conservatively require new help.
			if not killer.has("helped_at_death"):
				killer["helped_at_death"] = int(rel.get("helped", 0))
			var reparations := int(rel.get("helped", 0)) - int(killer.helped_at_death)
			if reparations < mini(6, kills * 3) or float(rel.get("trust", 0.0)) < 0.6 or float(rel.get("hostility", 0.0)) > 0.2:
				return false
	return true

func _chat_best_ally(b: Dictionary) -> Dictionary:
	var proxy: Node3D = b["proxy"]
	var my_id := int(b["bot_id"])
	var my_team := _bot_team_ids(b)
	var best := {}
	var best_s := -1.0
	for oid in bots.keys():
		if oid == my_id or not _bot_pair_can_cooperate(my_id, int(oid)):
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
	var nm := to_name if not to_name.is_empty() else "tú"
	var pers := _get_bot_personality(b)
	match kind:
		"greet":
			if float(pers.get("sociability", 0.5)) > 0.7:
				return str(["Oye %s, ¿qué tal todo por ahí?" % nm, "Buenas %s, me alegro de ver a alguien con vida." % nm][randi() % 2])
			return "Ey, %s." % nm
		"goodnight":
			return str(["Buenas noches, %s. Que descanses." % nm,
				"Me retiro ya, %s. Buenas noches." % nm,
				"Voy a dormir, %s. Buenas noches." % nm][randi() % 3])
		"goodmorning":
			return str(["Buenos días, %s." % nm,
				"Ey, buenos días %s. ¿Dormiste bien?" % nm,
				"Buen día, %s. Otro más que seguimos aquí." % nm][randi() % 3])
		"help":
			var threat := ctx if not ctx.is_empty() else "algo"
			return str(["¡Tengo %s encima! ¡%s, ven rápido, estoy en %s!" % [threat, nm, _chat_zone_name(proxy.global_position)],
				"¡Ayuda! ¡Me ataca %s aquí en %s!" % [threat, _chat_zone_name(proxy.global_position)]][randi() % 2])
		"alliance":
			return str(["Oye %s, ¿vamos juntos? Dos pares de ojos ven más que uno." % nm,
				"¿Hacemos equipo, %s? Solo no se llega muy lejos por aquí." % nm][randi() % 2])
		"whisper":
			return str(["Quieto... espera a que se acerque un poco más.",
				"No hagas ruido, ya casi lo tenemos."][randi() % 2])
		"taunt":
			return str(["Mala suerte, %s... suelta todo lo que llevas." % nm,
				"Te he visto, %s. Esa mochila me viene de perlas." % nm][randi() % 2])
		"request":
			match ctx:
				"comida":
					return str(["Oye %s, ¿tienes algo de comida? Me estoy muriendo de hambre." % nm,
						"Pásame algo de comer, %s, por favor." % nm][randi() % 2])
				"agua":
					return str(["%s, necesito agua... me muero de sed." % nm,
						"¿Tienes algo de beber, %s? Estoy seco." % nm][randi() % 2])
				"vendas":
					return "Estoy herido, %s... ¿llevas vendas o un botiquín encima?" % nm
				"arma":
					return "Voy desarmado, %s. ¿Te sobra un arma, un cuchillo o lo que sea?" % nm
			return "%s, me hace falta %s. ¿Tienes algo por ahí?" % [nm, ctx]
		"refused":
			var dkind := ctx.split(":")[0] if not ctx.is_empty() else "forage"
			match dkind:
				"negotiate":
					return str(["Por favor, %s... llevo horas así. Solo un poco." % nm,
						"Anda %s, que me hace mucha falta de verdad." % nm][randi() % 2])
				"attack":
					return "Pues lo siento, %s, pero me lo vas a dar por las malas." % nm
				"steal":
					return "Vale, %s. Sin problemas." % nm
			return str(["Vale, %s. Me buscaré la vida por mi cuenta." % nm,
				"De acuerdo. Me las apañaré, %s." % nm][randi() % 2])
		"reply":
			return _chat_fallback_reply(b, intent, nm)
	return ""

func _chat_fallback_reply(b: Dictionary, intent: String, nm: String) -> String:
	var hostile := str(b.get("faction", "")) == "hostile"
	match intent:
		"help":
			if hostile:
				return "Eso es problema tuyo."
			return "¡Aguanta ahí, que voy para allá!"
		"alliance":
			return "Prefiero ir por mi cuenta." if (hostile or float(_get_bot_personality(b).get("distrust", 0.3)) > 0.6) else "Por mí vale, vamos juntos."
		"greet":
			return "Buenas, %s. ¿Todo bien?" % nm
		"goodnight":
			return "Buenas noches, %s. Descansa." % nm
		"goodmorning":
			return "Buenos días, %s." % nm
		"threat":
			return "Vale, tranquilo..." if float(_get_bot_personality(b).get("bravery", 0.5)) < 0.4 else "No me busques las cosquillas."
	return "Dime, %s, te escucho." % nm

func _chat_ensure_http() -> void:
	if _chat_http != null and is_instance_valid(_chat_http):
		return
	_chat_http = HTTPRequest.new()
	_chat_http.timeout = 10.0
	_chat_http.request_completed.connect(_chat_on_response)
	add_child(_chat_http)

# Redacta el mensaje con el modelo de chat (una peticion en vuelo, su propia
# cuota de tokens por ser otro modelo). Devuelve false y el llamador usa la
# plantilla local.
func _chat_attempt_llm(b: Dictionary, kind: String, to_id: int, to_name: String, ctx: String, intent: String) -> bool:
	if not _chat_pending.is_empty() or not _ai_can_query_remote():
		return false
	if Time.get_ticks_msec() < _chat_backoff_until_msec:
		return false
	if _chat_conn_status.begins_with("rate_limited") or _chat_conn_status.begins_with("pacing"):
		_chat_conn_status = "ready (post-backoff)"
	# El chat sigue al proveedor activo del asesor: si la cadena ya salto al
	# secundario por cuota, el modelo de chat de alli (GEMINI_CHAT_MODEL o el
	# mismo de decisiones) responde — la cuota de chat del primario no bloquea.
	var key := _ai_provider_key()
	var chat_model := _ai_active_chat_model()
	if key.is_empty() or not _ai_model_quota_open(chat_model):
		return false
	_chat_ensure_http()
	_chat_pending = {"bot_id": int(b["bot_id"]), "to_id": to_id, "to_name": to_name, "kind": kind, "intent": intent, "t": Time.get_ticks_msec(), "model": chat_model}
	_ai_calls_day += 1
	_ai_calls_total += 1
	_ai_count_model_call(chat_model)
	var payload := {
		"model": chat_model,
		"temperature": 0.85,
		"max_tokens": 120,
		"messages": [
			{"role": "system", "content": BOT_CHAT_SYSTEM_PROMPT},
			{"role": "user", "content": _chat_build_prompt(b, kind, to_id, to_name, ctx, intent)},
		],
	}
	# gpt-oss quema tokens razonando: a low para que el presupuesto de
	# completado llegue a la frase y no a la cadena de pensamiento.
	if "gpt-oss" in chat_model:
		payload["reasoning_effort"] = "low"
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key])
	if _chat_http.request(_ai_provider_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
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
	# La hostilidad manda sobre la confianza: un estado contradictorio
	# (confianza alta + hostilidad alta, p.ej. por un rumor) se describe como
	# enemigo, igual que las puertas de cooperacion ya bloquean por hostilidad.
	var refused_n := int(rel.get("refused", 0))
	var rel_desc := "un desconocido"
	if ho > 0.5:
		rel_desc = "tu enemigo"
	elif refused_n >= 2:
		rel_desc = "alguien que te ha fallado"
	elif ho > 0.2:
		rel_desc = "alguien que te cae mal"
	elif tr > 0.5:
		rel_desc = "aliado de confianza"
	elif tr > 0.15:
		rel_desc = "conocido amistoso"
	var rel_rule := ""
	if ho > 0.5:
		rel_rule = " Es tu enemigo: responde hostil o cortante, nada de cordialidad."
	elif refused_n >= 2:
		rel_rule = " Te ha negado ayuda %d veces cuando la necesitabas: estas resentido, tratalo con frialdad, nada de alegria." % refused_n
	elif tr > 0.5:
		rel_rule = " Es tu aliado: se cordial con el; nunca lo amenaces salvo que te ataque."
	elif tr > 0.15:
		rel_rule = " Te cae bien: se cordial."
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
		"refused":
			var parts := ctx.split(":")
			var dkind := parts[0] if parts.size() > 0 else "forage"
			var dneed := parts[1] if parts.size() > 1 else "algo"
			var plan: String = {"negotiate": "Vas a rogarle otra vez: lo necesitas de verdad", "steal": "Piensas quitarselo de su refugio sin que te vea", "attack": "Vas a obligarle a dartelo por la fuerza", "forage": "Te buscaras la vida por tu cuenta"}.get(dkind, "")
			sit = "%s acaba de negarte %s que necesitabas. %s. Reacciona en una frase segun tu caracter y ese plan." % [to_name, dneed, plan]
		"reply":
			var intent_txt: String = {"help": "te pide ayuda", "alliance": "te propone hacer equipo", "greet": "te saluda", "goodnight": "te da las buenas noches", "goodmorning": "te da los buenos días", "threat": "te amenaza"}.get(intent, "te habla")
			sit = "%s %s. Dice: \"%s\". Responde hablando en voz alta, breve (1 frase), segun tu caracter y tu relacion con el." % [to_name, intent_txt, ctx]
	var faction_desc := "bandido hostil y peligroso" if str(b.get("faction", "friendly")) == "hostile" else "superviviente pacifico, cooperativo y amable (nunca amenaces ni busques pelea salvo que te ataquen; si algo no se entiende, pregunta con naturalidad)"
	var anti_repeat := ""
	var past: Array = _chat_recent.get(int(b["bot_id"]), [])
	if not past.is_empty():
		anti_repeat = "\nYa dijiste recientemente (no lo repitas ni uses las mismas palabras): " + " | ".join(past.slice(-2))
	return "Eres %s, %s en Last Day. Caracter: valentia %.2f, agresividad %.2f, sociable %.2f, desconfianza %.2f.\nEstado: vida %d, hambre %d, sed %d. Zona: %s. Llevas: %s.\n%s es %s (confianza %.2f, hostilidad %.2f).%s\n%s%s" % [
		str(b.get("name", "Bot")), faction_desc,
		float(pers.get("bravery", 0.5)), float(pers.get("aggression", 0.5)),
		float(pers.get("sociability", 0.5)), float(pers.get("distrust", 0.3)),
		int(float(b.get("health", 100))), int(float(b.get("hunger", 80))), int(float(b.get("thirst", 80))),
		_chat_zone_name(proxy.global_position), str(b.get("held_item", "las manos")),
		to_name, rel_desc, tr, ho, rel_rule, sit, anti_repeat]

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
	if response_code == 429:
		_ai_register_429(_headers, true)
	elif result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_chat_backoff_sec = 30.0
		_chat_conn_status = "online (200)"
		_ai_note_rate_headers(_headers, true)
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var usage = parsed.get("usage", {})
			var tok := int((usage as Dictionary).get("total_tokens", 140)) if usage is Dictionary else 140
			_ai_tokens_day += maxi(tok, 60)
			_ai_tokens_total += maxi(tok, 60)
			_ai_count_model_tokens(str(req.get("model", _ai_active_chat_model())), maxi(tok, 60))
			var ch = parsed.get("choices", [])
			if ch is Array and not (ch as Array).is_empty():
				var msg = (ch[0] as Dictionary).get("message", {})
				if msg is Dictionary:
					text = str((msg as Dictionary).get("content", ""))
	else:
		_chat_conn_status = "offline_fallback (%d)" % response_code
		_ai_tokens_day += 60
		_ai_tokens_total += 60
		_ai_count_model_tokens(str(req.get("model", _ai_active_chat_model())), 60)
	text = _chat_sanitize(text)
	if text.is_empty():
		text = _chat_fallback_line(b, kind, to_name, "", intent)
	# Frescura: la respuesta llego tan tarde que la escena ya es otra — fuera.
	if Time.get_ticks_msec() - int(req.get("t", 0)) > BOT_CHAT_STALE_MSEC:
		return
	var cproxy: Node3D = b.get("proxy")
	if cproxy == null or not is_instance_valid(cproxy) or bool(cproxy.get_meta("proxy_dead", false)):
		return
	# Mensajes iniciados (saludo, bravuconada, alianza) suenan a destiempo si el
	# bot entro en pelea/huida/escondite/sueno mientras el modelo pensaba.
	if kind != "reply" and (bool(b.get("sleeping", false)) or float(b.get("flee_until", 0.0)) > 0.0 or float(b.get("hide_timer", 0.0)) > 0.0):
		return
	_bot_chat_send(b, to_id, to_name, text, kind)

func interact_with_bot(bot_id: int, sender_id: int, mode: String = "toggle") -> String:
	if not bots.has(bot_id):
		return ""
	var b: Dictionary = bots[bot_id]
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return ""
	var cur_leader := int(b.get("team_leader_id", 0))
	var bname := str(b["name"])
	var sender_key := _actor_persist_key(sender_id)
	var sender_name := _actor_display_name(sender_id)
	# Si el jugador le entrega un objeto, eso siempre suma confianza (incluso si
	# antes había desconfianza), permitiendo reconciliarse con el bot. Vale
	# tambien para hostiles: es la via de conversión (un bandido iracundo la
	# rechaza, pero un hostil neutral si la acepta).
	if mode.begins_with("give:"):
		var gparts := mode.substr(5).split("|")
		var gname := gparts[0] if gparts.size() > 0 else ""
		var gtype := gparts[1] if gparts.size() > 1 else "resource"
		if gname.is_empty():
			return ""
		if str(b["faction"]) == "hostile":
			var rel_g := get_bot_relationship(bot_id, sender_key)
			if float(rel_g.get("hostility", 0.0)) >= 0.95 and int(rel_g.get("attacked", 0)) >= 3:
				return "%s aparta el objeto: '¡Quita eso de ahí! ¡Te dije que no!'." % bname
		var gweight := float(gparts[2]) if gparts.size() > 2 else 0.5
		var guse := float(gparts[3]) if gparts.size() > 3 else 0.0
		var inv_give: Array = proxy.get_meta("saved_inventory", [])
		var gitem := {"name": gname, "type": gtype, "quantity": 1, "weight": gweight, "use_value": guse}
		if not _bot_try_add_inventory_item(b, inv_give, gitem):
			# Mochila llena: el objeto no se pierde — cae a los pies del bot
			_bot_drop_to_ground(b, gitem)
			return "%s no puede cargar %s — lo deja en el suelo." % [bname, gname]
		proxy.set_meta("saved_inventory", inv_give)
		_auto_equip_best_gear(b)
		var best_w2 := _best_weapon_name(proxy)
		if not best_w2.is_empty() and not bool(b["torch_lit"]):
			b["held_item"] = best_w2
			b["has_rifle"] = best_w2 == "Fusil de asalto" or best_w2 == "Rifle francotirador"
			proxy.set_meta("saved_held_item", best_w2)
		record_social_event(bot_id, sender_key, sender_name, "help", 0.35, "gave_" + gname)
		_publish_bot_to_net_players(b)
		_apply_local_avatar_metadata(b)
		return "Le das %s a %s." % [gname, bname]

	if str(b["faction"]) == "hostile":
		return "%s es hostil y no quiere formar equipo." % bname

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
	var _cpt := Time.get_ticks_usec()
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
			# Posicion que el lider comunico: es su ultima conocida.
			_ai_note_foe_intel(b, target_node, target_node.global_position, "told")
			b["follow_mode"] = "follow"
			b["sitting"] = false
			b["sense_t"] = 0.0
	if CombatProf.enabled: CombatProf.mark("bot.notify_leader", _cpt)

func _command_bot_wolf_against(b: Dictionary, target: Node3D) -> void:
	if world == null or world.get_tree() == null or target == null or not is_instance_valid(target):
		return
	var key := str(b["bot_id"])
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if is_instance_valid(w) and w.get("_is_dead") != true and str(w.get("animal_type")) == "wolf" and str(w.get("tamed_to")) == key:
			if w.has_method("notify_threat"):
				w.notify_threat(target, 20.0)

# Lee un nodo cacheado por el sentido escalonado descartando referencias muertas.
func _sensed_node(b: Dictionary, key: String) -> Node3D:
	var n = b.get(key, null)
	if n != null and is_instance_valid(n):
		if n.is_queued_for_deletion():
			return null
		if key in ["_s_foe", "_s_predator", "_s_prey", "_s_tame_wolf"] and (n.get("is_dead") == true or n.get("_is_dead") == true or bool(n.get_meta("proxy_dead", false))):
			b[key] = null
			return null
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
	var claims: Dictionary = world.get("_pickup_claims") if "_pickup_claims" in world else {}
	var claims_until: Dictionary = world.get("_pickup_claim_until") if "_pickup_claim_until" in world else {}
	var now_ms := Time.get_ticks_msec()
	for entry in world._dropped_items:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		if id.is_empty() or depleted.has(id):
			continue
		# Pieza fichada por un compañero: elegir otra en vez de amontonarse
		# todos sobre el mismo drop.
		var cowner := int(claims.get(id, 0))
		if cowner != 0 and cowner != int(b["bot_id"]) and int(claims_until.get(id, 0)) > now_ms:
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
	if tp == "tool_matches" or nm == "Cerillas":
		return _bot_item_count(b["proxy"], "Cerillas") < 1
	if tp == "tool_torch" or nm == "Antorcha":
		return _bot_item_count(b["proxy"], "Antorcha") < 1
	if tp == "weapon_bola" or nm == "Boleadoras":
		return _bot_item_count(b["proxy"], "Boleadoras") < 1
	if tp == "weapon_bow":
		if _bot_item_count(b["proxy"], nm) >= 1:
			return false
		if nm == "Arco de madera" and _bot_item_count(b["proxy"], "Arco reforzado") > 0:
			return false
		return true
	if tp == "weapon_rifle":
		return _bot_item_count(b["proxy"], nm) < 1
	if tp == "ammo_arrow":
		return _bot_arrow_count(b["proxy"]) < 20
	if tp == "ammo":
		return _bot_item_count(b["proxy"], nm) < 4
	if tp == "medical":
		return _bot_item_count(b["proxy"], nm) < 4
	if tp in ["weapon", "tool_axe", "tool_spear"]:
		if _bot_item_count(b["proxy"], nm) >= 1:
			return false
		var cur_melee := _best_melee_weapon(b["proxy"])
		if cur_melee.is_empty():
			return true
		if nm in BUSH_TOOLS and not _bot_has_can_opener(b["proxy"]):
			return true
		if nm in ["Lanza", "Lanza de hueso"] and _bot_best_thrown_weapon(b["proxy"]).is_empty():
			return true
		return _weapon_melee_damage(nm) > _weapon_melee_damage(cur_melee)
	# Azada/Pala: herramienta de huerto — interesa siempre (una por bot);
	# no hace falta refugio para cultivar un bancal.
	if tp in ["tool_hoe", "tool_shovel"]:
		return _bot_wants_farm_tool(b)
	# Semillas de arbusto o de cosecha: solo sirven si puede cultivarlas.
	if nm == "Semillas":
		return _bot_wants_seeds(b)
	# Bebida: reserva escalada por lecciones de deshidratacion (1..3). Si ya
	# lleva recipientes vacios, solo coge llena si le falta reserva o tiene sed.
	var drink_cap := _bot_desired_drink_cap(b)
	if tp == "water" or nm.contains("agua") or nm.contains("Cantimplora"):
		if _bot_drink_count(b["proxy"]) >= drink_cap:
			return false
		return _bot_container_count(b["proxy"]) < drink_cap or float(b["thirst"]) < 55.0
	# Botella vacia = recipiente para rellenar en el rio; hasta cubrir su reserva
	if nm == "Botella de plastico":
		return _bot_container_count(b["proxy"]) < drink_cap
	# Materiales base de campamento: stock modesto, no acaparar "por si acaso".
	# Palo: el refugio cuesta 11 igual que al jugador — hasta levantarlo no
	# se pasa de largo junto a un palo suelto.
	if nm in ["Palo", "Piedra", "Cuerda", "Tela de camuflaje"]:
		var palo_cap := 13 if str(b.get("shelter_id", "")).is_empty() else 8
		var caps := {"Palo": palo_cap, "Piedra": 6, "Cuerda": 4, "Tela de camuflaje": 2}
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
	if tp in ["weapon", "weapon_rifle", "tool_axe", "tool_spear", "backpack", "clothing",
			"ammo", "ammo_arrow"]:
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
	b["anim"] = "stairs" if (np.y - pos.y > delta * 0.04 and not bool(b.get("has_rifle", false))) else "walk"
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

# Reclamo de botin: quien ficha una pieza la reserva (~30 s, la misma tabla
# autoritativa que los nodos de recoleccion) para que sus compañeros repartan
# el saqueo en vez de ir todos a por el mismo rifle.
func _loot_claimed_by_other(b: Dictionary, id: String) -> bool:
	if world == null or not ("_pickup_claims" in world):
		return false
	var owner := int(world._pickup_claims.get(id, 0))
	var until: Dictionary = world.get("_pickup_claim_until") if "_pickup_claim_until" in world else {}
	return owner != 0 and owner != int(b["bot_id"]) and int(until.get(id, 0)) > Time.get_ticks_msec()

func _loot_commit_claim(b: Dictionary) -> void:
	var entry: Dictionary = b.get("_s_loot", {})
	var id := str(entry.get("id", ""))
	if id != str(b.get("_loot_claim", "")):
		_loot_clear(b)
	if id.is_empty():
		return
	# Selection and arrival are separate ticks: another actor may have
	# reserved the drop meanwhile. Never overwrite an unexpired claim.
	if _loot_claimed_by_other(b, id):
		_loot_clear(b)
		return
	b["_s_loot"] = entry
	b["_loot_claim"] = id
	if world != null and "_pickup_claims" in world:
		world._pickup_claims[id] = int(b["bot_id"])
		if "_pickup_claim_until" in world:
			world._pickup_claim_until[id] = Time.get_ticks_msec() + 30000

func _loot_clear(b: Dictionary) -> void:
	var prev := str(b.get("_loot_claim", ""))
	if not prev.is_empty() and world != null and "_pickup_claims" in world:
		if int((world._pickup_claims as Dictionary).get(prev, -1)) == int(b["bot_id"]):
			(world._pickup_claims as Dictionary).erase(prev)
			if "_pickup_claim_until" in world:
				(world._pickup_claim_until as Dictionary).erase(prev)
	b["_loot_claim"] = ""
	b["_s_loot"] = {}

func _collect_loot_entry(b: Dictionary, entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id.is_empty() or world == null:
		return
	if not _bot_can_reach_loot((b["proxy"] as Node3D).global_position, _loot_entry_pos(entry)):
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
		_loot_clear(b)
		return
	if _loot_claimed_by_other(b, id):
		_loot_clear(b)
		return
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	# Capacidad como el jugador humano (slots/peso por ropa y mochila). Si no
	# le cabe, el objeto se queda en el mundo — ira a descargar a su refugio.
	var enm := str(entry.get("name", ""))
	var etp := str(entry.get("type", "resource"))
	if inv.size() >= 60 and not _is_gear_item(enm, etp):
		_loot_clear(b)
		return
	var item_dict := _loot_entry_item_dict(entry)
	if not _bot_try_add_inventory_item(b, inv, item_dict):
		# Mochila llena de noche sin luz: por material de fuego critico suelta
		# lo menos esencial — mejor un hueso en el suelo que una noche a oscuras.
		if not _bot_can_drop_for_fire(b, inv, item_dict):
			_loot_clear(b)
			return
		var junk_i := _bot_least_essential_index(b, inv)
		var junk: Dictionary = inv[junk_i]
		inv.remove_at(junk_i)
		_bot_drop_to_ground(b, junk)
		if not _bot_try_add_inventory_item(b, inv, item_dict):
			_loot_clear(b)
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
	_loot_clear(b)
	b["sense_t"] = 0.0

# Mismo coste que el refugio del jugador (ShelterPlacement): 11 palos —
# nada de atajo con cuerda. Con el material en la mano construye igual.
func _bot_can_reach_loot(from: Vector3, pos: Vector3) -> bool:
	if Vector2(from.x-pos.x,from.z-pos.z).length() > 2.1 or absf(from.y-pos.y) > 1.8:
		return false
	if _wall_between(from,pos):
		return false
	# Check the hand-to-item segment too: a closed door or a floor between
	# actor and item is not an interaction, even at less than two metres.
	if world is Node3D and (world as Node3D).get_world_3d() != null:
		var q := PhysicsRayQueryParameters3D.create(from+Vector3.UP*1.2,pos+Vector3.UP*.15,5)
		return (world as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	return true

func _can_bot_build_shelter(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 11

# Donde levantar el refugio: el solar propio reclamado si ya lo tiene (reobrar
# sobre su base), junto al refugio del lider de equipo si milita en uno (base
# compartida a ~15-30 m) o su campamento remoto. El sitio de equipo se cachea
# para no recalcularlo cada tick.
func _bot_build_camp_pos(b: Dictionary) -> Vector3:
	var shp: Vector3 = b.get("shelter_pos", Vector3.INF)
	if shp != Vector3.INF:
		return shp
	var lid := int(b.get("team_leader_id", 0))
	if lid > 0 and bots.has(lid):
		if not (b.get("_team_camp") is Vector3):
			var lb: Dictionary = bots[lid]
			var lsp: Vector3 = lb.get("shelter_pos", lb.get("camp_spot", Vector3.INF))
			if lsp != Vector3.INF:
				b["_team_camp"] = _find_valid_camp_spot(lsp, (b["proxy"] as Node3D).global_position, lid, [], int(b["bot_id"]))
		if b.get("_team_camp") is Vector3:
			return b["_team_camp"]
	return b.get("camp_spot", Vector3.INF)

func _can_bot_build_campfire(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2

func _bot_build_shelter(b: Dictionary, pos: Vector3) -> void:
	var proxy: Node3D = b["proxy"]
	_consume_bot_item(proxy, "Palo", 11)
	var has_pelts := _bot_pelt_count(proxy) >= 4
	if has_pelts:
		var used := 0
		for pelt_nm in ["Piel de lobo", "Piel de ciervo", "Piel de oso", "Piel de zorro"]:
			while used < 4 and _bot_item_count(proxy, pelt_nm) > 0:
				_consume_bot_item(proxy, pelt_nm, 1)
				used += 1
	var has_camo := _consume_bot_item(proxy, "Tela de camuflaje", 1)
	# Id unico por construccion: el refugio viejo queda en pie (huerfano
	# saqueable) si el bot levanta otro lejos tras reaparecer. El contador
	# evita colisiones cuando el mismo bot reconstruye dentro del mismo
	# segundo (desmontar+levantar seguidos): un id repetido haria early
	# return en _spawn_player_shelter_with_id y el refugio quedaria fantasma.
	var sh_id := "bot_shelter_%d_%d_%d" % [int(b["bot_id"]), int(Time.get_unix_time_from_system()), _bot_shelter_seq]
	_bot_shelter_seq += 1
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
	# Quien ya se murio de hambre/sed revisa su alijo antes de que la
	# necesidad apriete: las lecciones suben el umbral de "lo necesito".
	var dl_need: Dictionary = b.get("_mem", {}).get("death_lessons", {})
	var need_food: bool = float(b["hunger"]) < 60.0 + minf(16.0, float(int(dl_need.get("starved", 0))) * 8.0) and not _bot_has_edible_food(proxy, float(b["hunger"]) < 28.0)
	var need_water: bool = float(b["thirst"]) < 60.0 + minf(16.0, float(int(dl_need.get("dehydrated", 0))) * 8.0) and not _bot_has_drink(proxy)
	var need_weapon: bool = _best_weapon_name(proxy).is_empty()
	var need_med: bool = float(b["health"]) < 78.0 and _bot_item_count(proxy, "Venda") == 0
	var need_farm_kit: bool = _bot_needs_farm_kit_now(b)
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
		if need_farm_kit and ((tp in ["tool_hoe", "tool_shovel"] and not _bot_has_farm_tool(proxy)) or (nm == "Semillas" and _bot_item_count(proxy, "Semillas") < 3)):
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
	var want_farm_kit := _bot_needs_farm_kit_now(b)
	var kept_farm_tool := false
	var seeds_kept := 0
	var food_kept := 0
	var drink_kept := 0
	var container_kept := 0
	var med_kept := 0
	var has_cf := not str(b.get("campfire_id", "")).is_empty() or bool(b.get("no_fire_spot", false))
	var stick_cap := 2 if has_cf else 4
	var stone_cap := 1 if has_cf else 2
	var stick_kept := 0
	var stone_kept := 0
	# La tela no se almacena mientras su refugio siga sin camuflar: la necesita
	# encima para cubrirlo la proxima vez que pase por casa.
	var own_sh := _find_shelter_dict(str(b.get("shelter_id", "")))
	var needs_camo_net := not own_sh.is_empty() and not bool(own_sh.get("camo_covered", false))
	var kept_camo := false
	var keep: Array = []
	var store: Array = []
	# Reservas aprendidas: quien se murio de hambre o de sed no vuelve a salir
	# de casa con una sola provision — cada muerte sube el minimo que lleva.
	var dl_res: Dictionary = b.get("_mem", {}).get("death_lessons", {})
	var food_cap := 1 + mini(2, int(dl_res.get("starved", 0)))
	var drink_cap := 1 + mini(2, int(dl_res.get("dehydrated", 0)))
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
		if nm == "Tela de camuflaje" and needs_camo_net and not kept_camo:
			kept_camo = true
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
			elif want_farm_kit and not kept_farm_tool and (tp in ["tool_hoe", "tool_shovel"] or nm in ["Azada", "Pala", "Azada de piedra"]) and float(it.get("durability", 100.0)) > 0.0:
				kept_farm_tool = true
				if qty > 1:
					var kh := it.duplicate(true); kh["quantity"] = 1; keep.append(kh)
					var sh_e := it.duplicate(true); sh_e["quantity"] = qty - 1; store.append(sh_e)
				else:
					keep.append(it)
			else:
				store.append(it)
			continue
		if nm == "Semillas":
			if want_farm_kit and seeds_kept < 3:
				var take_sd := mini(3 - seeds_kept, qty)
				seeds_kept += take_sd
				var ksd := it.duplicate(true); ksd["quantity"] = take_sd; keep.append(ksd)
				if qty - take_sd > 0:
					var ssd := it.duplicate(true); ssd["quantity"] = qty - take_sd; store.append(ssd)
			else:
				store.append(it)
			continue
		if tp == "food":
			if nm == "Carne ensartada" or nm == "Pez ensartado" or (nm.begins_with("Carne cruda") and (_bot_item_count(proxy, "Palo afilado") > 0 or not bool(b.get("_s_has_wolf", false)))):
				keep.append(it)
				continue
			if food_kept < food_cap:
				var take_k := mini(food_cap - food_kept, qty)
				food_kept += take_k
				var kf := it.duplicate(true); kf["quantity"] = take_k; keep.append(kf)
				if qty - take_k > 0:
					var sf := it.duplicate(true); sf["quantity"] = qty - take_k; store.append(sf)
			else:
				store.append(it)
			continue
		if tp == "water" or nm.contains("agua") or nm.contains("Cantimplora"):
			if drink_kept < drink_cap:
				drink_kept += 1
				var kd := it.duplicate(true); kd["quantity"] = 1; keep.append(kd)
				if qty > 1:
					var sd := it.duplicate(true); sd["quantity"] = qty - 1; store.append(sd)
			else:
				store.append(it)
			continue
		# La botella vacia es recipiente para rellenar en el rio, no bebida:
		# si contara como "drink" desplazaria la botella llena que el alijo
		# acaba de soltar (retirada + reguardado en el mismo tick: ping-pong
		# infinito y muerte por sed sobre la propia despensa).
		if nm == "Botella de plastico":
			if container_kept < drink_cap:
				container_kept += 1
				var kp := it.duplicate(true); kp["quantity"] = 1; keep.append(kp)
				if qty > 1:
					var sp := it.duplicate(true); sp["quantity"] = qty - 1; store.append(sp)
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
# Camufla el refugio propio con una Tela de camuflaje si aun no la lleva —
# igual que el jugador humano sobre su refugio (meta + visual via RPC).
func _bot_try_camo_shelter(b: Dictionary) -> void:
	var sid := str(b.get("shelter_id", ""))
	if sid.is_empty() or world == null:
		return
	var sh := _find_shelter_dict(sid)
	if sh.is_empty() or bool(sh.get("camo_covered", false)):
		return
	var proxy: Node3D = b["proxy"]
	if not _consume_bot_item(proxy, "Tela de camuflaje", 1):
		return
	if not (world.has_method("_apply_shelter_camo_state") and world._apply_shelter_camo_state(sid, true)):
		return
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.shelter_camo_changed.rpc_id(pid, sid, true)
	var mm = b.get("_mem", {})
	if mm is Dictionary:
		var sm: Dictionary = (mm as Dictionary).get("shelter", {}) if (mm as Dictionary).get("shelter") is Dictionary else {}
		sm["camo"] = true
		(mm as Dictionary)["shelter"] = sm
	_record_milestone(int(b["bot_id"]), "camouflaged_shelter")

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
		elif tp == "ammo" and _bot_gun_wants_ammo_item(proxy, nm):
			want_withdraw = true
		elif nm == "Venda" and _bot_item_count(proxy, "Venda") == 0:
			want_withdraw = true
		elif _bot_needs_farm_kit_now(b) and (tp in ["tool_hoe", "tool_shovel"] or nm in ["Azada", "Pala", "Azada de piedra"]) and float(cd.get("durability", 100.0)) > 0.0 and not _bot_has_farm_tool(proxy):
			want_withdraw = true
		elif _bot_needs_farm_kit_now(b) and nm == "Semillas" and _bot_item_count(proxy, "Semillas") < 3:
			want_withdraw = true
		if want_withdraw:
			var take_qty := 1
			if nm == "Semillas":
				take_qty = mini(maxi(1, 3 - _bot_item_count(proxy, "Semillas")), int(cd.get("quantity", 1)))
			var one: Dictionary = (cd as Dictionary).duplicate(true)
			one["quantity"] = take_qty
			if not _bot_try_add_inventory_item(b, inv, one):
				continue # no le cabe: se queda guardado en su refugio
			proxy.set_meta("saved_inventory", inv)
			var rem := int(cd.get("quantity", 1)) - take_qty
			if rem <= 0:
				contents.remove_at(i)
			else:
				contents[i]["quantity"] = rem
			changed = true
			moved += take_qty
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

# Una hoguera nunca se planta dentro del agua: si el punto pedido cae en un
# rio/charco se prueba un anillo de alternativas secas alrededor (un bot
# helandose dentro de un vado intentaria encenderla bajo el agua).
func _is_water_fire_pos(pos: Vector3) -> bool:
	if world == null:
		return false
	if world.has_method("_is_water_drop_position"):
		return bool(world._is_water_drop_position(pos))
	return world.has_method("get_river_depth_at") and float(world.get_river_depth_at(pos)) > 0.02

func _bot_build_and_light_campfire(b: Dictionary, pos: Vector3) -> bool:
	var proxy: Node3D = b["proxy"]
	if _is_water_fire_pos(pos):
		var dry := Vector3.INF
		for off in [Vector3(1.8,0,0), Vector3(-1.8,0,0), Vector3(0,0,1.8), Vector3(0,0,-1.8), Vector3(2.6,0,2.6), Vector3(-2.6,0,2.6), Vector3(2.6,0,-2.6), Vector3(-2.6,0,-2.6)]:
			var cand: Vector3 = pos + off
			cand.y = _ground_y(cand.x, cand.z)
			if not _is_water_fire_pos(cand):
				dry = cand
				break
		if dry == Vector3.INF:
			return false
		pos = dry
	_consume_bot_item(proxy, "Palo", 2)
	_consume_bot_item(proxy, "Piedra", 2)
	var cf_id := "bot_campfire_%d" % int(b["bot_id"])
	# A remote/invalid old camp must not be moved or overwritten by a new one.
	if not str(b.get("campfire_id", "")).is_empty():
		cf_id += "_%d" % Time.get_ticks_usec()
	b["campfire_id"] = cf_id
	b["campfire_pos"] = pos
	if world.has_method("_net_campfire_built"):
		# Si el mundo rechaza el punto (agua u otra validacion) no queda
		# ninguna estructura: limpiar la marca para no registrar una fogata
		# fantasma que atraiga al bot y a sus companeros.
		if world._net_campfire_built(cf_id, pos, 0) == false:
			b["campfire_id"] = ""
			b["campfire_pos"] = Vector3.INF
			return false
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.campfire_built.rpc_id(pid, cf_id, pos)
	_ensure_bot_campfire_lit(b)
	return true

# Una fogata encendida tiene objeto real (world_actions_by_id) — figurar en
# _lit_campfires no basta: la entrada puede quedar obsoleta tras expirar el
# fuego (5 min) y entonces atrae bots hacia calor/luz inexistentes.
func _campfire_entry_alive(lc) -> bool:
	if not (lc is Dictionary):
		return false
	if "world_actions_by_id" in world:
		var action = (world.world_actions_by_id as Dictionary).get(str(lc.get("id", "")))
		# El objeto debe existir, ser valido y ARDER de verdad: la lluvia
		# apaga el fuego pero deja la estructura en pie (lit=false) — una
		# fogata apagada no da luz, ni calor, ni vale de refugio.
		if action == null:
			return false
		if action is Object:
			if not is_instance_valid(action):
				return false
			if not bool(action.get_meta("lit", false)):
				return false
	return true

func _ensure_bot_campfire_lit(b: Dictionary) -> void:
	var cf_id := str(b.get("campfire_id", ""))
	if cf_id.is_empty() or world == null:
		return
	# La fogata expiro o la quitaron: el id ya no es un objeto real —
	# limpiar la referencia en vez de reencender una fogata fantasma.
	if "world_actions_by_id" in world and not (world.world_actions_by_id as Dictionary).has(cf_id):
		b["campfire_id"] = ""
		b["campfire_pos"] = Vector3.INF
		return
	for lc in world.get("_lit_campfires") if "_lit_campfires" in world else []:
		if lc is Dictionary and str(lc.get("id", "")) == cf_id and _campfire_entry_alive(lc):
			return
	var fire_name := "CampfireFire_Bot_%d_%d" % [int(b["bot_id"]), Time.get_ticks_msec()]
	var pos: Vector3 = b["campfire_pos"]
	if world.has_method("_net_campfire_lit") and world._net_campfire_lit(cf_id, fire_name, pos, 0) == false:
		# Rechazo explicito: la fogata ya no existe — referencia muerta.
		b["campfire_id"] = ""
		b["campfire_pos"] = Vector3.INF
		return
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

func _nearest_lit_campfire_pos(from_pos: Vector3, max_dist: float, b = null) -> Vector3:
	if world == null or not ("_lit_campfires" in world):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := max_dist
	var dead := []
	for lc in world._lit_campfires:
		if not (lc is Dictionary) or not (lc.get("pos") is Vector3):
			continue
		if not _campfire_entry_alive(lc):
			dead.append(lc)
			continue
		var cp: Vector3 = lc["pos"]
		if b != null and _bot_fire_vetoed(b, cp):
			continue
		var d := Vector2(from_pos.x - cp.x, from_pos.z - cp.z).length()
		if d < best_d:
			best_d = d
			best = cp
	for lc in dead:
		world._lit_campfires.erase(lc)
	return best

# Veto temporal por bot sobre una fuente de calor cuyo anillo resulto
# inalcanzable (rodeada de muros/obstaculos): sin el, el buscador de
# calor volvia a elegir la misma fogata imposible cada tick y el bot se
# quedaba empujando contra la pared toda la noche. A los 60 s caduca y
# se reevalua (las condiciones cambian: puertas, fogatas nuevas).
const FIRE_VETO_MSEC := 60000

func _fire_key(fp: Vector3) -> String:
	return "%d,%d" % [int(round(fp.x)), int(round(fp.z))]

func _bot_fire_vetoed(b: Dictionary, fp: Vector3) -> bool:
	var veto: Dictionary = b.get("_fire_veto", {})
	if veto.is_empty():
		return false
	var key := _fire_key(fp)
	var until := int(veto.get(key, 0))
	if until <= Time.get_ticks_msec():
		veto.erase(key)
		return false
	# Si ya estas DENTRO del anillo de calor, el veto es historia vieja:
	# alcanzaste la fogata por otro camino (puerta abierta, otro angulo).
	var proxy: Node3D = b.get("proxy")
	if proxy != null and Vector2(proxy.global_position.x - fp.x, proxy.global_position.z - fp.z).length() <= 4.5:
		veto.erase(key)
		return false
	return true

func _bot_veto_fire(b: Dictionary, fp: Vector3) -> void:
	var veto: Dictionary = b.get("_fire_veto", {})
	veto[_fire_key(fp)] = Time.get_ticks_msec() + FIRE_VETO_MSEC
	b["_fire_veto"] = veto

# Punto libre del anillo a `radius` m del fuego, barriendo angulos desde la
# direccion dada. Devuelve INF si TODOS caen bloqueados (muros, agua
# profunda, obstaculos) — un borde inalcanzable no es destino seguro.
func _bot_fire_ring_spot(b: Dictionary, fp: Vector3, dir: Vector2, radius: float, y: float) -> Vector3:
	var from := (b["proxy"] as Node3D).global_position
	var dn := dir.normalized() if dir.length() > 0.05 else Vector2(1.0, 0.0)
	for i in range(8):
		var ang := dn.rotated(PI * 0.25 * i)
		var cand := Vector3(fp.x + ang.x * radius, y, fp.z + ang.y * radius)
		if not _is_step_blocked(from, cand):
			return cand
	return Vector3.INF

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
	# Si aun no tiene lobo domesticado y no pasa hambre, reserva hasta 3 piezas
	# de carne cruda como cebo para cuando se cruce con un lobo salvaje.
	if not bool(b.get("_s_has_wolf", false)) and float(b.get("hunger", 100.0)) >= 52.0 and not _bot_has_skewered_meat(proxy) and _bot_tame_bait_count(proxy) <= WildlifeController.TAME_FEEDINGS:
		return false
	var cur := proxy.global_position
	var fire_pos := _nearest_lit_campfire_pos(cur, 12.0 if _is_world_night() and not _bot_has_item(proxy, "Antorcha") else 85.0)
	var cf_pos: Vector3 = b.get("campfire_pos", Vector3.INF)
	if fire_pos == Vector3.INF and cf_pos != Vector3.INF and _bot_supply_goal_lit(b, cf_pos) and Vector2(cur.x - cf_pos.x, cur.z - cf_pos.z).length() < 110.0:
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
		if not _bot_build_and_light_campfire(b, spot):
			return false
		# La fogata pudo reubicarse a suelo seco junto al punto pedido: usar la
		# posicion real registrada, no el candidato original.
		fire_pos = b["campfire_pos"]
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
	var species := ""
	var inv_pre: Array = proxy.get_meta("saved_inventory", [])
	for it in inv_pre:
		if it is Dictionary and str(it.get("name", "")) == skewered:
			species = str(it.get("species", ""))
			break
	if _consume_bot_item(proxy, skewered, 1):
		var inv: Array = proxy.get_meta("saved_inventory", [])
		if is_fish:
			_bot_add_inventory_item(inv, {"name": str(GameConst.COOKED_FISH[0]), "type": "food", "weight": float(GameConst.COOKED_FISH[2]), "quantity": 1, "use_value": float(GameConst.COOKED_FISH[1])})
		elif not species.is_empty() and GameConst.COOKED_MEAT.has(species):
			var row = GameConst.COOKED_MEAT[species]
			_bot_add_inventory_item(inv, {"name": str(row[0]), "type": "food", "weight": float(row[2]), "quantity": 1, "use_value": float(row[1])})
		else:
			_bot_add_inventory_item(inv, {"name": "Carne asada en palo", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 28.0})
		proxy.set_meta("saved_inventory", inv)
		b["cook_cooldown"] = 12.0
		return true
	return false

# ==================== PESCA ====================
# El pez cocinado es la comida mas nutritiva del juego (50): con caña en la
# mochila (la fabrica el crafteo general o la encuentra loteando) y agua a
# mano, el bot camina a la orilla, lanza el hilo y espera el picado igual
# que un jugador humano (~7 s, 72% de picada, -3 de caña por lance).
const BOT_FISH_WAIT_SEC := 7.0
const BOT_FISH_COOLDOWN_SEC := 55.0
const BOT_FISH_CHANCE := 0.72
const BOT_FISH_MAX_RAW := 4

func _bot_rod_name(proxy: Node3D) -> String:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("type", "")) == "tool_fishing" and float(it.get("durability", 1.0)) > 0.0:
			return str(it.get("name", "Caña de pescar"))
	return ""

func _bot_has_fishing_rod(proxy: Node3D) -> bool:
	return not _bot_rod_name(proxy).is_empty()

# Un lance gasta 3 puntos de la caña (la receta da 3.0 = un uso, igual que
# para el jugador); rota se tira.
func _bot_wear_fishing_rod(proxy: Node3D) -> void:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for it in inv.duplicate():
		if it is Dictionary and str(it.get("type", "")) == "tool_fishing":
			it["durability"] = float(it.get("durability", 3.0)) - 3.0
			if float(it["durability"]) <= 0.0:
				inv.erase(it)
			break
	proxy.set_meta("saved_inventory", inv)

func _bot_fish_resolve(b: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	if randf() < BOT_FISH_CHANCE:
		var inv: Array = proxy.get_meta("saved_inventory", [])
		var entry := {"name": "Pez crudo", "type": "food", "weight": 0.55, "quantity": 1, "use_value": 24.0}
		# Sin hueco el pez cae a sus pies, igual que al jugador en la orilla.
		if not _bot_try_add_inventory_item(b, inv, entry):
			_bot_drop_to_ground(b, entry)
		else:
			proxy.set_meta("saved_inventory", inv)
		_evolve_personality(b, "forage", 0.10)
	_bot_wear_fishing_rod(proxy)
	_publish_bot_to_net_players(b)

func _bot_try_fish(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	b["fish_cd"] = maxf(0.0, float(b.get("fish_cd", 0.0)) - delta)
	var st: Dictionary = b.get("_fish_state", {})
	if not st.is_empty():
		# Si otra rama (combate, huida, emergencia) desplazo la pesca, el
		# lance quedo abandonado: el estado caduca y hay que lanzar de nuevo.
		var now_ms := Time.get_ticks_msec()
		if now_ms - int(st.get("at", 0)) > 2500:
			b["_fish_state"] = {}
			return false
		st["at"] = now_ms
		# Hilo lanzado: sentado en la orilla con la caña esperando el picado.
		st["t"] = float(st.get("t", 0.0)) + delta
		b["_fish_state"] = st
		b["sitting"] = true
		b["crouching"] = false
		b["anim"] = "sit"
		var rod_wait := _bot_rod_name(proxy)
		if rod_wait.is_empty():
			rod_wait = "Caña de pescar"
		b["held_item"] = rod_wait
		proxy.set_meta("saved_held_item", rod_wait)
		if float(st["t"]) >= BOT_FISH_WAIT_SEC:
			b["_fish_state"] = {}
			b["fish_cd"] = BOT_FISH_COOLDOWN_SEC
			_bot_fish_resolve(b)
		return true
	if float(b["fish_cd"]) > 0.0:
		return false
	# Pesca de dia: de noche y al caer la tarde un superviviente vuelve al
	# fuego — caminar al rio a oscuras no es plan. La caña la hace el crafteo
	# general (_bot_recipe_score) o la encuentra loteando; sin caña no hay
	# lance y la rama cede el tick.
	if _is_world_night() or _is_pre_night():
		return false
	# Solo pesca con despensa flaca o hambre: el pez es comida premium pero
	# lenta — forrajear y lootear siguen ganando si hay de sobra.
	if float(b["hunger"]) >= 55.0 and _bot_has_edible_food(proxy, false):
		return false
	if _bot_item_count(proxy, "Pez crudo") >= BOT_FISH_MAX_RAW:
		return false
	if not _bot_has_fishing_rod(proxy):
		return false
	var wp := _nearest_water_pos(proxy.global_position, b)
	if wp == Vector3.INF:
		return false
	var cur := proxy.global_position
	var d := Vector2(cur.x - wp.x, cur.z - wp.z).length()
	if d > 160.0:
		return false
	if d > 3.6:
		b["sitting"] = false
		b["crouching"] = false
		b["held_item"] = _bot_rod_name(proxy)
		proxy.set_meta("saved_held_item", str(b["held_item"]))
		_move_bot_towards(b, wp, 5.0, delta, "walk")
		return true
	b["_fish_state"] = {"t": 0.0, "pos": wp, "at": Time.get_ticks_msec()}
	return true

# Agua vadeable: un humano cruza rios someros (~hasta la cintura); solo el agua
# profunda bloquea el paso.
const WADE_DEPTH := 0.55
# Cruce como los ciervos: el bot atraviesa el rio entero (su canal toca
# 2.5 m de fondo — el bot camina sumergido, muy lento, empapado y perdiendo
# calor, igual que el jugador humano). Solo el agua por encima de eso — el
# corazon del lago (hasta 4 m) — queda fuera: ahi no llega ni el ciervo.
const FORD_MAX_DEPTH := 2.55

# Punto cercano con agua vadeable o seca para salir de una zona profunda donde
# _is_pos_blocked no dejaria dar ni un paso. Sondea en anillos y devuelve la
# primera orilla alcanzable o la posicion menos profunda hallada.
func _bot_shoreward_goal(pos: Vector3) -> Vector3:
	if world == null or not world.has_method("get_river_depth_at"):
		return Vector3.INF
	var depth0 := float(world.get_river_depth_at(pos))
	var best := Vector3.INF
	var best_depth := depth0
	for r in [1.8, 3.6, 6.0]:
		for i in range(16):
			var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * float(i) / 16.0)
			var cand: Vector3 = pos + dir * r
			var dc := float(world.get_river_depth_at(cand))
			if dc <= WADE_DEPTH and not _is_pos_blocked(cand):
				return cand
			if dc < best_depth - 0.02:
				best_depth = dc
				best = cand
	return best

func _is_pos_blocked(pos: Vector3, margin: float = 0.45, allow_deep: bool = false) -> bool:
	if world == null:
		return false
	if not allow_deep and world.has_method("get_river_depth_at") and float(world.get_river_depth_at(pos)) > FORD_MAX_DEPTH:
		return true
	# The wildlife exclusion disk is deliberately wider than the real tower.
	# Only the verified stair/ladder corridor overrides it; physical wall rays
	# below still apply, and arbitrary shortcuts through the shaft stay blocked.
	var tower := _bot_tower_at(pos)
	if not tower.is_empty() and ElevationRoutes.on_corridor(pos,tower["points"]):
		return false
	if world.has_method("is_bot_blocked_at"):
		return world.is_bot_blocked_at(pos, margin)
	if world.has_method("_is_near_wildlife_blocker") and world._is_near_wildlife_blocker(pos, margin):
		return true
	return false

func _can_leave_building_margin(from_pos: Vector3, to_pos: Vector3) -> bool:
	if world == null or not ("wildlife_blockers" in world) or not world.has_method("is_bot_blocked_at"):
		return false
	# A bot may already be in the conservative nav halo after a door closes
	# or after fleeing. Permit parallel/outward movement, never deeper into
	# the building. Real collision rays still run below.
	if world.is_bot_blocked_at(to_pos,-.45): return false
	var a := Vector2(from_pos.x,from_pos.z)
	var z := Vector2(to_pos.x,to_pos.z)
	for blk in world.wildlife_blockers:
		if not (blk is Dictionary) or not blk.has("house_bounds"): continue
		var wall: Rect2 = blk.house_bounds
		if wall.has_point(a) or not wall.grow(.9).has_point(a): continue
		var near_a := Vector2(clampf(a.x,wall.position.x,wall.end.x),clampf(a.y,wall.position.y,wall.end.y))
		var near_z := Vector2(clampf(z.x,wall.position.x,wall.end.x),clampf(z.y,wall.position.y,wall.end.y))
		if z.distance_to(near_z) >= a.distance_to(near_a)-.001: return true
	return false

func _is_step_blocked(from_pos: Vector3, to_pos: Vector3, allow_deep: bool = false) -> bool:
	if _is_pos_blocked(to_pos, 0.42, allow_deep):
		if _is_pos_blocked(to_pos,-.45,allow_deep) or not _can_leave_building_margin(from_pos,to_pos):
			return true
	elif _is_pos_blocked(from_pos,0.42,allow_deep) and _wall_between(from_pos,to_pos):
		# A free interior must not turn a step out of the facade margin into
		# a shortcut through a window (the chest ray can see through one).
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

func _bot_tower_routes() -> Array:
	var routes: Array = ElevationRoutes.summit_routes().duplicate()
	if world != null and "_watchtower_climb" in world:
		var legacy = world.get("_watchtower_climb")
		if legacy is Array and legacy.size() >= 2:
			routes.append({"id":"military", "points":legacy, "radius":7.5})
	return routes

func _bot_tower_at(pos: Vector3, elevated_only: bool = false) -> Dictionary:
	for route in _bot_tower_routes():
		if ElevationRoutes.contains(route, pos, elevated_only):
			return route
	return {}

func _is_in_any_building_3d(pos: Vector3) -> bool:
	if not _bot_tower_at(pos).is_empty():
		return true
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
	if _wall_between(cur,door_world):
		return false
	if world.bot_try_open_door_at(cur):
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
	# Finish crossing the doorway before returning to outdoor steering. The
	# inside test stops at the wall, while the actor still overlaps the jamb.
	var exit_wp: Vector3 = b.get("_building_exit_wp", Vector3.INF)
	if exit_wp.is_finite():
		var distance := Vector2(cur.x - exit_wp.x, cur.z - exit_wp.z).length()
		if distance > 0.2 and distance < 6.0 and Time.get_ticks_msec() < int(b.get("_building_exit_until", 0)):
			return exit_wp
		b.erase("_building_exit_wp")
		b.erase("_building_exit_until")
	var waypoint := _resolve_building_interior_waypoint_uncached(b, cur, goal)
	if waypoint != goal and _is_in_any_building_3d(cur) and not _is_in_any_building_3d(waypoint) and cur.distance_to(waypoint) < 6.0:
		b["_building_exit_wp"] = waypoint
		b["_building_exit_until"] = Time.get_ticks_msec() + 8000
	return waypoint

func _resolve_building_interior_waypoint_uncached(b: Dictionary, cur: Vector3, goal: Vector3) -> Vector3:
	# 1) Torre del Reloj (41, 0, 750)
	var cur_ct := _is_in_clock_tower(cur, 0.25)
	var goal_ct := _is_in_clock_tower(goal, 0.8)
	if cur_ct or goal_ct:
		return _resolve_clock_tower_waypoint(b, cur, goal, cur_ct, goal_ct)

	# 2) Edificios de la ciudad (city_01..city_17, 2 y 4 plantas con escaleras)
	var cur_cb := _find_city_building_for_pos(cur, 0.25)
	var goal_cb := _find_city_building_for_pos(goal, 0.85)
	if cur_cb >= 0 or goal_cb >= 0:
		var target_cb := cur_cb if (cur_cb >= 0 and (goal_cb < 0 or cur_cb != goal_cb)) else goal_cb
		return _resolve_city_building_waypoint(b, cur, goal, target_cb, cur_cb == target_cb, goal_cb == target_cb)

	# Tower traversal also applies to combat/follow/retreat, not just exploration.
	var cur_tower := _bot_tower_at(cur, true)
	var goal_tower := _bot_tower_at(goal, true)
	if not cur_tower.is_empty() or not goal_tower.is_empty():
		var route: Dictionary = cur_tower if not cur_tower.is_empty() else goal_tower
		var points: Array = route["points"]
		var same_tower := str(goal_tower.get("id", "")) == str(route["id"])
		if _bot_tower_at(cur).is_empty() and cur.distance_to(points[0]) > .25:
			return points[0]
		return ElevationRoutes.waypoint(cur, goal, points, same_tower)

	# 4) Casas del pueblo y resto de bloqueadores con puerta (house_bounds)
	return _resolve_door_approach_goal(b, cur, goal)

func _resolve_clock_tower_waypoint(b: Dictionary, cur: Vector3, goal: Vector3, cur_in: bool, goal_in: bool) -> Vector3:
	var lc := cur - CT_ORIGIN
	if not cur_in and goal_in:
		# Entrada norte frente a la plaza (x=0, z=-8.0)
		var qw := _bot_door_queue_wait(b, cur, CT_ORIGIN + Vector3(0.0, 0.06, -8.0), Vector2(0.0, -1.0))
		if qw != Vector3.INF:
			return qw
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
		var out3 := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, yaw)
		var qw := _bot_door_queue_wait(b, cur, door_world, Vector2(out3.x, out3.z))
		if qw != Vector3.INF:
			return qw
		if not is_open or lc.z < 5.75 or absf(lc.x - 0.15) > 0.65 or lc.z > 8.8:
			return b_origin + Vector3(0.15, 0.12, 8.3).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(0.15, 0.12, 4.6).rotated(Vector3.UP, yaw)
	var lg := (goal - b_origin).rotated(Vector3.UP, -yaw) if goal_in else Vector3(0.15, 0.12, 4.6)
	# Bloque de 4 plantas (city_17, b_idx == 16)
	if int(def.get("floors", 2)) > 2:
		if lc.x <= -1.85 and absf(lc.z) < 4.3:
			var fl_h := clampi(int(floor((lc.y - 0.16 + 0.02) / 3.9)), 0, 2)
			if lg.y > lc.y + 0.1:
				return b_origin + Vector3(-3.0, 0.16 + float(fl_h + 1) * 3.9, -5.0).rotated(Vector3.UP, yaw)
			var lower_h := clampi(int(ceil((lc.y - 0.16 - 0.02) / 3.9)) - 1, 0, 2)
			return b_origin + Vector3(-3.0, 0.16 + float(lower_h) * 3.9, 5.0).rotated(Vector3.UP, yaw)
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
	if lc.x >= (4.58 if flat_roof else 3.5) and lc.z > -3.0 and lc.z < 4.2 and lc.y < 4.1:
		if lg.y > 2.0:
			return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(stair_x, 0.12, 4.7).rotated(Vector3.UP, yaw)
	if flat_roof and lc.x >= 3.1 and lc.x <= 4.45 and lc.z > -3.0 and lc.z < 4.95 and lc.y >= 3.6:
		if lg.y > 6.0:
			return b_origin + Vector3(3.85, 7.86, 5.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
	var cur_lvl_c := 0 if lc.y < 2.2 else (1 if lc.y < 6.0 else 2)
	var goal_lvl_c := 0 if lg.y < 2.2 else (1 if (lg.y < 6.0 or not flat_roof) else 2)
	if cur_lvl_c == 0 and goal_lvl_c >= 1:
		if lc.x < stair_x - .12:
			if lc.z < 3.8:
				return b_origin + Vector3(-0.2, 0.12, 4.7).rotated(Vector3.UP, yaw)
			return b_origin + Vector3(stair_x, 0.12, 4.7).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 1 and goal_lvl_c == 0:
		if flat_roof and lc.x < 4.9:
			if lc.z > -3.0:
				return b_origin + Vector3(3.85 if lc.x > 3.2 else 1.6, 3.92, -3.2).rotated(Vector3.UP,yaw)
			return b_origin + Vector3(stair_x, 3.92, -3.2).rotated(Vector3.UP,yaw)
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
		if absf(lc.x - 3.85) > .12 and lc.z <= -2.2:
			return b_origin + Vector3(3.85, 3.92, -3.2).rotated(Vector3.UP, yaw)
		return b_origin + Vector3(3.85, 7.86, 5.2).rotated(Vector3.UP, yaw)
	if cur_lvl_c == 2 and goal_lvl_c < 2:
		if absf(lc.x - 3.85) > 0.55 or lc.z < 4.95:
			return b_origin + Vector3(3.85, 7.86, 5.2).rotated(Vector3.UP, yaw)
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

# El vano solo pasa uno cada vez: si otro bot lo ocupa (cruzando la puerta o
# apostado en el punto de aproximacion), el que llega despues espera en un
# puesto lateral en vez de apilar los dos sobre el mismo waypoint — asi no se
# atascan empujandose en la entrada. Devuelve Vector3.INF si puede pasar.
func _bot_door_queue_wait(b: Dictionary, cur: Vector3, dc: Vector3, out_dir: Vector2) -> Vector3:
	var side_dir := Vector2(-out_dir.y, out_dir.x)
	var rel := Vector2(cur.x - dc.x, cur.z - dc.z)
	var along := rel.dot(out_dir)
	var across := absf(rel.dot(side_dir))
	# Quien ya esta dentro del vano sigue: no retrocede para ceder el paso.
	if across <= 0.95 and along >= -1.8 and along <= 2.6:
		return Vector3.INF
	var approach := Vector2(dc.x, dc.z) + out_dir * 2.4
	for bid in bots.keys():
		if int(bid) == int(b.get("bot_id", 0)):
			continue
		var op: Node3D = (bots[bid] as Dictionary).get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var po := Vector2(op.global_position.x, op.global_position.z)
		var rel_o := po - Vector2(dc.x, dc.z)
		var in_vano: bool = absf(rel_o.dot(side_dir)) <= 0.95 and rel_o.dot(out_dir) >= -1.8 and rel_o.dot(out_dir) <= 2.6
		if in_vano or po.distance_to(approach) <= 1.15:
			# Puesto de espera lateral determinista: cada bot se aparta a un
			# lado distinto segun su id, sin apelotonarse en el umbral.
			var offs: Array = [1.7, -1.7, 3.0, -3.0]
			var off: float = float(offs[int(b.get("bot_id", 0)) % 4])
			var qp: Vector2 = Vector2(dc.x, dc.z) + out_dir * 2.7 + side_dir * off
			return Vector3(qp.x, cur.y, qp.y)
	return Vector3.INF

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
		var hb: Rect2 = dblk["house_bounds"]
		var cur_in := hb.grow(-0.25).has_point(p_cur)
		var goal_in := hb.grow(0.8).has_point(p_goal)
		if cur_in == goal_in:
			continue
		var bpos: Vector3 = dblk.get("pos", Vector3.ZERO)
		if bool(dblk.get("barn_door_always_open", false)):
			# Both barn gates are open. Choose the entrance on the actor's side
			# (or the exit nearest the destination) rather than aiming at a wall.
			var side_z := cur.z if goal_in else goal.z
			var north := side_z < hb.get_center().y
			var gate := Vector3(float(dblk.get("front_door_x" if north else "back_door_x",bpos.x)),cur.y,hb.position.y if north else hb.end.y)
			var out := Vector3(0,0,-1 if north else 1)
			var along_gate := (cur-gate).dot(out)
			if goal_in:
				return gate+out*3.0 if absf(cur.x-gate.x)>.65 or along_gate>3.5 or along_gate<-.25 else gate-out*1.5
			if absf(cur.x-gate.x)>.65 or along_gate < -1.8: return gate-out*1.5
			b["_building_exit_wp"] = gate+out*4.2
			b["_building_exit_until"] = Time.get_ticks_msec()+8000
			return gate+out*4.2
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
		if not is_open and d_door <= 4.8 and not _wall_between(cur,dc):
			if world.bot_try_open_door_at(cur):
				b["path"] = []
				b["path_timer"] = 0.0
				is_open = true
		if goal_in:
			var qw := _bot_door_queue_wait(b, cur, dc, out_dir)
			if qw != Vector3.INF:
				return qw
			if not is_open or along < -0.25 or across > 0.65 or along > 3.0:
				return Vector3(dc.x + out_dir.x * 2.4, cur.y, dc.z + out_dir.y * 2.4)
			if along > -0.8:
				return Vector3(dc.x - out_dir.x * 1.4, cur.y, dc.z - out_dir.y * 1.4)
			return goal
		# Saliendo de la casa al exterior: alinearse primero con el vano interior
		# y cruzar recto hacia fuera.
		if not is_open or across > 0.65 or along < -1.8:
			return Vector3(dc.x - out_dir.x * 1.2, cur.y, dc.z - out_dir.y * 1.2)
		# Clear the coarse outdoor nav cell as well as the physical jamb.
		var exit_point := Vector3(dc.x + out_dir.x * 4.2, cur.y, dc.z + out_dir.y * 4.2)
		b["_building_exit_wp"] = exit_point
		b["_building_exit_until"] = Time.get_ticks_msec() + 8000
		return exit_point
	return goal

# Short visibility graph around a facade. Outdoor navigation uses 2 m cells;
# its nearest-free-cell fallback can point back inside an open doorway. Keep
# the doorway and the first facade corners precise, then hand off to the map.
func _building_exterior_waypoint(b: Dictionary, cur: Vector3, goal: Vector3) -> Vector3:
	var cached: Array = b.get("_facade_path",[])
	if b.get("_facade_goal") == goal:
		while not cached.is_empty() and Vector2(cur.x-cached[0].x,cur.z-cached[0].z).length() < .35:
			cached.pop_front()
		if not cached.is_empty() and cur.distance_to(cached[0]) < 35.0:
			return cached[0]
	b["_facade_path"] = []
	if not _wall_between(cur,goal): return goal
	var shapes: Array = []
	if world != null and "wildlife_blockers" in world:
		for blk in world.wildlife_blockers:
			if blk is Dictionary and blk.has("house_bounds") and int(blk.get("city_building_index",-1)) < 0:
				shapes.append({"origin":Vector3.ZERO,"yaw":0.0,"bounds":blk.house_bounds})
	for def in CityBlock.BUILDINGS:
		var fp: Vector2 = def.get("footprint",Vector2(6,6))
		shapes.append({"origin":CityExpansion.CENTER+def.position,"yaw":float(def.get("yaw",0.0)),"bounds":Rect2(-fp,fp*2.0)})
	shapes.append({"origin":CT_ORIGIN,"yaw":0.0,"bounds":Rect2(-9,-8,18,16)})
	var nearby: Array = []
	var nodes: Array[Vector3] = [cur,goal]
	var blocked := false
	for shape in shapes:
		var origin: Vector3 = shape.origin
		var yaw: float = shape.yaw
		var lc := (cur-origin).rotated(Vector3.UP,-yaw)
		var lg := (goal-origin).rotated(Vector3.UP,-yaw)
		var a := Vector2(lc.x,lc.z)
		var z := Vector2(lg.x,lg.z)
		var wall: Rect2 = shape.bounds
		if wall.has_point(a) or wall.has_point(z) or not wall.grow(25.0).has_point(a): continue
		nearby.append(shape)
		blocked = blocked or _seg2d_crosses_rect_wall(a,z,wall,[])
		var r := wall.grow(1.5)
		for corner in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
			nodes.append(origin+Vector3(corner.x,lc.y,corner.y).rotated(Vector3.UP,yaw))
	if not blocked: return goal
	var cost: Array[float] = []
	var prev: Array[int] = []
	cost.resize(nodes.size()); cost.fill(INF); cost[0] = 0.0
	prev.resize(nodes.size()); prev.fill(-1)
	var used := {}
	for _iteration in nodes.size():
		var at := -1
		for j in nodes.size():
			if not used.has(j) and (at < 0 or cost[j] < cost[at]): at = j
		if at < 0 or is_inf(cost[at]) or at == 1: break
		used[at] = true
		for j in range(1,nodes.size()):
			if used.has(j): continue
			var clear := true
			for shape in nearby:
				var la := (nodes[at]-(shape.origin as Vector3)).rotated(Vector3.UP,-float(shape.yaw))
				var lb := (nodes[j]-(shape.origin as Vector3)).rotated(Vector3.UP,-float(shape.yaw))
				var wall: Rect2 = (shape.bounds as Rect2).grow(.8)
				# The first point can already overlap the safety margin. It may
				# leave it, but the physical footprint stays solid.
				if at == 0 and wall.has_point(Vector2(la.x,la.z)): wall = shape.bounds
				if wall.has_point(Vector2(lb.x,lb.z)) or _seg2d_crosses_rect_wall(Vector2(la.x,la.z),Vector2(lb.x,lb.z),wall,[]):
					clear = false
					break
			if not clear: continue
			var c: float = cost[at]+nodes[at].distance_to(nodes[j])
			if c < cost[j]: cost[j] = c; prev[j] = at
	if prev[1] < 0: return goal
	var route: Array = []
	var at := 1
	while prev[at] >= 0:
		route.push_front(nodes[at])
		at = prev[at]
	b["_facade_path"] = route
	b["_facade_goal"] = goal
	return route[0]

# La aproximacion a puerta solo justifica soltar la malla nav (in_building_3d)
# cuando la linea recta al waypoint NO atraviesa ningun muro: desde el muro
# trasero o un lateral la recta choca con la pared y el bot debe seguir
# bordeando con bot_nav hasta asomar al frente del vano. Los vanos de puerta
# no cuentan como muro — abrir la hoja cerrada ya lo gestiona
# _resolve_door_approach_goal / bot_try_open_door_at al llegar.
func _wall_between(a: Vector3, bpt: Vector3) -> bool:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(bpt.x, bpt.z)
	if (pb - pa).length() < 0.05:
		return false
	var seg_rect := Rect2(pa, Vector2.ZERO).expand(pb)
	if world != null and ("wildlife_blockers" in world):
		for blk in world.wildlife_blockers:
			if not (blk is Dictionary) or not (blk as Dictionary).has("house_bounds"):
				continue
			var dblk: Dictionary = blk
			# Los edificios de ciudad los evalua el bucle CityBlock de abajo,
			# que conoce footprint/yaw/puerta reales (city_17 desplaza la suya).
			if int(dblk.get("city_building_index", -1)) >= 0:
				continue
			var hb: Rect2 = dblk["house_bounds"]
			if not hb.grow(0.6).intersects(seg_rect):
				continue
			if _seg2d_crosses_rect_wall(pa, pb, hb, _house_wall_gaps(dblk, hb)):
				return true
	for i in range(CityBlock.BUILDINGS.size()):
		var def: Dictionary = CityBlock.BUILDINGS[i]
		if not (def.get("position") is Vector3):
			continue
		var origin: Vector3 = CityExpansion.CENTER + (def["position"] as Vector3)
		var fp: Vector2 = def.get("footprint", Vector2(6.0, 6.0))
		if not seg_rect.grow(fp.length() + 0.5).has_point(Vector2(origin.x, origin.z)):
			continue
		var yaw := float(def.get("yaw", 0.0))
		var la := (Vector3(pa.x, 0.0, pa.y) - origin).rotated(Vector3.UP, -yaw)
		var lb := (Vector3(pb.x, 0.0, pb.y) - origin).rotated(Vector3.UP, -yaw)
		var rect := Rect2(-fp.x - 0.3, -fp.y - 0.3, fp.x * 2.0 + 0.6, fp.y * 2.0 + 0.6)
		# Door.position es la BISAGRA; la hoja se extiende hacia +x local.
		# Usar la bisagra como centro bloqueaba el vano del bloque alto y
		# consideraba transitable parte del muro contiguo.
		var hinge: Vector3 = def.get("door_position", Vector3(-0.85, 0.12, 6.08))
		var door_size: Vector3 = def.get("door_size", Vector3(1.7, 2.8, 0.12))
		var gap := {"edge": 2, "at": hinge.x + door_size.x * 0.5, "half": door_size.x * 0.5}
		if _seg2d_crosses_rect_wall(Vector2(la.x, la.z), Vector2(lb.x, lb.z), rect, [gap]):
			return true
	return false

# Vanos practicables en el perimetro de un bloqueador (arista + coordenada a
# lo largo de ella): el vano de la puerta en casas, los dos portones siempre
# abiertos en graneros. edge: 0=N(z min), 1=E(x max), 2=S(z max), 3=W(x min).
func _house_wall_gaps(dblk: Dictionary, hb: Rect2) -> Array:
	if bool(dblk.get("barn_door_always_open", false)) and dblk.has("back_door_x"):
		var bx := hb.get_center().x
		return [
			{"edge": 0, "at": float(dblk.get("front_door_x", bx)), "half": float(dblk.get("front_door_w", 2.8)) * 0.5 + 0.45},
			{"edge": 2, "at": float(dblk.get("back_door_x", bx)), "half": float(dblk.get("back_door_w", 2.8)) * 0.5 + 0.45},
		]
	var bpos: Vector3 = dblk.get("pos", Vector3(hb.get_center().x, 0.0, hb.get_center().y))
	var dc: Vector3 = world._blocker_door_center(dblk, bpos, hb) if world != null and world.has_method("_blocker_door_center") else dblk.get("door_center", dblk.get("door_pos", Vector3.INF))
	if not dc.is_finite():
		return []
	var gap_half := float(dblk.get("front_door_w", 2.0)) * 0.5 + 0.45
	var dp := Vector2(dc.x, dc.z)
	var dn := absf(dp.y - hb.position.y)
	var ds := absf(dp.y - hb.end.y)
	var dw := absf(dp.x - hb.position.x)
	var de := absf(dp.x - hb.end.x)
	var edge := 0
	var m := dn
	if ds < m:
		edge = 2
		m = ds
	if dw < m:
		edge = 3
		m = dw
	if de < m:
		edge = 1
	return [{"edge": edge, "at": dp.x if (edge == 0 or edge == 2) else dp.y, "half": gap_half}]

func _seg2d_crosses_rect_wall(pa: Vector2, pb: Vector2, r: Rect2, gaps: Array) -> bool:
	var c0 := r.position
	var c1 := Vector2(r.end.x, r.position.y)
	var c2 := r.end
	var c3 := Vector2(r.position.x, r.end.y)
	var edges := [[c0, c1], [c1, c2], [c2, c3], [c3, c0]]
	for e in range(4):
		var hit = Geometry2D.segment_intersects_segment(pa, pb, edges[e][0], edges[e][1])
		if hit == null:
			continue
		var p: Vector2 = hit
		var at := p.x if (e == 0 or e == 2) else p.y
		var in_gap := false
		for g in gaps:
			if int(g["edge"]) == e and absf(at - float(g["at"])) <= float(g["half"]):
				in_gap = true
				break
		if not in_gap:
			return true
	return false

# Guia de ascenso y descenso por la carretera asfaltada en espiral hacia la
# Base Militar de la Cima (HighMountainZone, cota +56 m): un humano no escala
# el acantilado en linea recta ni se tira desde 56 m; sube y baja siguiendo los
# puntos de get_road_polyline_3d() desde el pie (-252, 0.8, -268) hasta la
# entrada sureste de la base (-356, 56, -356).
func _resolve_mountain_road_waypoint(cur: Vector3, goal: Vector3) -> Vector3:
	var on_summit_cur: bool = Vector2(cur.x, cur.z).distance_to(HighMountainZone.SUMMIT_CENTER) < 38.0 and cur.y >= 55.0
	var goal_is_summit: bool = goal.x < -290.0 and goal.z < -290.0 and goal.y >= 20.0
	var on_road_slope: bool = not on_summit_cur and cur.x < -210.0 and cur.z < -210.0 and ((cur.x < -235.0 and cur.z < -235.0) or cur.y > 4.0)
	if not goal_is_summit and not on_summit_cur and not on_road_slope:
		return goal
	if on_summit_cur and goal_is_summit:
		return goal
	var pts := HighMountainZone.get_road_polyline_3d()
	if pts.size() < 70:
		return goal
	var foot_idx := 0
	var foot_d := INF
	for i in range(pts.size()):
		var d := Vector2(pts[i].x, pts[i].z).distance_squared_to(HighMountainZone.ROAD_START)
		if d < foot_d:
			foot_d = d
			foot_idx = i
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
	var best_i2 := top_idx
	var best_d2 := 1e9
	for i in range(foot_idx, pts.size()):
		var p2: Vector3 = pts[i]
		var d2 := Vector2(cur.x - p2.x, cur.z - p2.z).length() + absf(cur.y - p2.y) * 2.5
		if d2 < best_d2:
			best_d2 = d2
			best_i2 = i
	if on_summit_cur and best_d2 > 8.0:
		return pts[top_idx]
	if best_i2 <= foot_idx + 1 and Vector2(cur.x - pts[foot_idx].x, cur.z - pts[foot_idx].z).length() < 10.0:
		return goal
	return pts[maxi(foot_idx, best_i2 - 3)]

func _stop_bot_motion(b: Dictionary) -> void:
	b["_speed"] = 0.0
	b["_mdir"] = Vector3.ZERO
	b["anim"] = "idle"
	var proxy: Node3D = b.get("proxy")
	if is_instance_valid(proxy):
		proxy.set_meta("moving", false)
		proxy.set_meta("sprinting", false)

func _move_bot_towards(b: Dictionary, raw_goal: Vector3, speed: float, delta: float, anim_name: String) -> void:
	var proxy: Node3D = b["proxy"]
	# Moverse implica estar de pie: si una rama de decision pone a correr a un
	# bot sentado/dormido/tumbado sin levantarlo (la huida lo hacia), en los
	# clientes se deslizaba manteniendo la pose de descanso. Todas las rutas
	# de descanso legitimas ponen el flag y retornan sin llamar aqui.
	b["sitting"] = false
	b["sleeping"] = false
	b["prone"] = false
	# El sprint no es gratis: agotada la energia el bot no corre, trota
	# (histeresis _tired 16->45 para no aletear walk/run cada segundo).
	if anim_name == "run":
		var en := _bot_energy(b)
		if bool(b.get("_tired", false)):
			if en >= 45.0:
				b["_tired"] = false
			else:
				anim_name = "walk"
				speed *= 0.75
		elif en < 16.0:
			b["_tired"] = true
			anim_name = "walk"
			speed *= 0.75
	var cur := proxy.global_position
	var road_goal := raw_goal if not _bot_tower_at(cur, true).is_empty() else _resolve_mountain_road_waypoint(cur, raw_goal)
	var goal := _resolve_building_interior_waypoint(b, cur, road_goal)
	var exterior_goal := _building_exterior_waypoint(b,cur,goal)
	var facade_route := exterior_goal != goal
	goal = exterior_goal
	var previous_waypoint: Vector3 = b.get("_interior_last_waypoint", Vector3.INF)
	if goal != previous_waypoint and previous_waypoint.is_finite() and cur.distance_to(previous_waypoint) < .45:
		b["macro_timer"] = 0.0
		b["macro_pos"] = cur
		b["stuck_count"] = 0
	b["_interior_last_waypoint"] = goal
	var on_mountain_3d: bool = road_goal != raw_goal or (cur.x < -235.0 and cur.z < -235.0 and cur.y > 2.0)
	var flat_dist := Vector2(goal.x - cur.x, goal.z - cur.z).length()
	var in_building_3d: bool = _is_in_any_building_3d(cur) or (goal != road_goal and flat_dist <= 8.5 and not _wall_between(cur, goal))
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
	if facade_route or in_building_3d or (on_mountain_3d and (cur.x < -235.0 and cur.z < -235.0)):
		nav_guided = true
	elif (flat_dist > 3.5 or direct_blocked) and bot_nav_ref != null:
		var path: Array = b["path"]
		var prev_pgoal: Vector3 = b.get("_path_goal", Vector3.INF) if b.get("_path_goal") is Vector3 else Vector3.INF
		var goal_shifted: bool = prev_pgoal == Vector3.INF or Vector2(goal.x - prev_pgoal.x, goal.z - prev_pgoal.z).length() > 2.5
		if float(b["path_timer"]) <= 0.0 or (goal_shifted and float(b["path_timer"]) <= 1.2):
			var _npt := Time.get_ticks_usec()
			b["path"] = bot_nav_ref.find_path(cur, goal)
			if CombatProf.enabled: CombatProf.mark("bot.find_path", _npt)
			b["_path_goal"] = goal
			b["path_idx"] = 0
			b["path_timer"] = 1.8
			path = b["path"]
			if path.is_empty() and flat_dist > 8.0:
				# Antes de quemar el plan, un rodeo: el fallo es de la linea
				# recta, no necesariamente del destino (lago, muro, hueco de
				# la malla). Un intento por objetivo; si tampoco navega,
				# entonces si es inalcanzable.
				var last_det: Vector3 = b.get("_detour_goal", Vector3.INF)
				if not in_building_3d and (last_det == Vector3.INF or Vector2(raw_goal.x - last_det.x, raw_goal.z - last_det.z).length() > 4.0):
					b["_detour_goal"] = raw_goal
					var detour := _bot_nav_detour(b, cur, goal, bot_nav_ref)
					if detour != Vector3.INF:
						b["path"] = bot_nav_ref.find_path(cur, detour)
						b["_path_goal"] = detour
						b["path_idx"] = 0
						b["path_timer"] = 1.8
						path = b["path"]
				if path.is_empty():
					_abandon_unreachable_goal(b, raw_goal)
					_stop_bot_motion(b)
					return
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
	var deep_now: bool = depth_cur > FORD_MAX_DEPTH
	if not in_building_3d and (depth_next > FORD_MAX_DEPTH or (not nav_guided and depth_ahead > FORD_MAX_DEPTH)) and depth_cur <= FORD_MAX_DEPTH:
		var surf_y := _ground_y(ahead_xz.x, ahead_xz.z, cur.y)
		var ty := 0.375
		if world.has_method("_get_exact_ground_y"):
			ty = world._get_exact_ground_y(ahead_xz.x, ahead_xz.z) - 0.025
		if surf_y - ty < 0.5:
			_stop_bot_motion(b)
			b["path"] = []
			b["stuck_count"] = int(b["stuck_count"]) + 1
			if int(b["stuck_count"]) >= 2:
				# Orilla equivocada != destino inalcanzable: un rodeo por el
				# flanco (puente/vado) antes de vetar el sitio para siempre.
				var last_det2: Vector3 = b.get("_detour_goal", Vector3.INF)
				if not in_building_3d and (last_det2 == Vector3.INF or Vector2(raw_goal.x - last_det2.x, raw_goal.z - last_det2.z).length() > 4.0):
					b["_detour_goal"] = raw_goal
					var detour2 := _bot_nav_detour(b, cur, goal, bot_nav_ref)
					if detour2 != Vector3.INF:
						b["path"] = bot_nav_ref.find_path(cur, detour2)
						b["_path_goal"] = detour2
						b["path_idx"] = 0
						b["path_timer"] = 1.8
						b["stuck_count"] = 0
						return
				b["stuck_count"] = 0
				_abandon_unreachable_goal(b, raw_goal)
			return
	var to_next := Vector3(next_goal.x - cur.x, 0.0, next_goal.z - cur.z)
	var d := to_next.length()
	var vertical_ladder := in_building_3d and d < .25 and absf(next_goal.y-cur.y) > .3 and not _bot_tower_at(cur).is_empty()
	if d < 0.05 or vertical_ladder:
		_stop_bot_motion(b)
		if in_building_3d and absf(next_goal.y-cur.y) > .05 and not _bot_tower_at(cur).is_empty():
			cur.x = move_toward(cur.x, next_goal.x, delta*3.2)
			cur.z = move_toward(cur.z, next_goal.z, delta*3.2)
			cur.y = move_toward(cur.y, next_goal.y, delta*3.2)
			proxy.global_position = cur
			proxy.set_meta("saved_pos", cur)
			proxy.set_meta("moving", true)
			b["pos"] = cur
			b["anim"] = preload("res://scripts/LadderClimbAnimation.gd").NAME
			b["crouching"] = false
			b["is_aiming"] = false
			var tower := _bot_tower_at(cur)
			var center: Vector3 = tower.get("center",cur)
			var inward := center-cur
			if Vector2(inward.x,inward.z).length() > .01:
				b["rot"] = atan2(-inward.x,-inward.z)
				proxy.rotation.y = float(b["rot"])
			b["last_move_pos"] = cur
			b["stuck_timer"] = 0.0
		return
	var dir := to_next / d
	# Sumar repulsion suave de bloqueadores cercanos solo en exterior libre:
	# dentro de edificios, escaleras o umbrales de puerta empujaria contra el marco.
	if not in_building_3d and not facade_route and world != null and world.has_method("get_wildlife_avoidance_vector_at"):
		b["avoid_t"] = float(b.get("avoid_t", 0.0)) - delta
		if float(b["avoid_t"]) <= 0.0:
			b["avoid_t"] = 0.15
			b["_avoid"] = world.get_wildlife_avoidance_vector_at(cur)
		var av: Vector3 = b.get("_avoid", Vector3.ZERO)
		av.y = 0.0
		if av.length_squared() > 0.001:
			dir = (dir + av.normalized() * 0.55).normalized()
	# Suavizado de rumbo y aceleracion: en giros > ~75° (p.ej. darse la vuelta
	# para huir de un animal) asentar el rumbo directo evita que sm + (dir - sm)
	# se anule o siga apuntando hacia la amenaza al normalizarse.
	var sm: Vector3 = b.get("_mdir", Vector3.ZERO)
	if sm.length_squared() < 0.001 or sm.dot(dir) < 0.25:
		sm = dir
	else:
		var turn_rate := 18.0 if in_building_3d else 10.0
		sm = (sm + (dir - sm) * minf(1.0, delta * turn_rate)).normalized()
	b["_mdir"] = sm
	var on_stair_segment: bool = in_building_3d and absf(next_goal.y - cur.y) > 0.25
	# Gestion de estamina como en PlayerController: fuera de combate/huida,
	# cuando la energia cae a <=12 pasa a caminar hasta recuperar >=45, evitando
	# que corran con energia 0 (lo que multiplicaba x1.875 el desgaste de sueno).
	var in_urgent_chase: bool = b.get("aggro_target") != null or _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null or float(b.get("flee_until", 0.0)) > 0.0
	var cur_energy := float(b.get("energy", 100.0))
	if cur_energy <= 12.0 and not in_urgent_chase:
		b["_stamina_recover"] = true
	elif cur_energy >= 45.0 or in_urgent_chase:
		b["_stamina_recover"] = false
	if anim_name == "run" and bool(b.get("_stamina_recover", false)):
		anim_name = "walk"
		speed = minf(speed, 3.8)
	# Match the player's crouched gait (2 m/s). Tactical callers may still
	# request run/4-6.5 m/s while keeping crouching set; never sprint in that pose.
	var crouched_move := bool(b.get("crouching", false))
	if crouched_move:
		speed = minf(speed, 2.0)
		anim_name = "walk"
	var base_spd := maxf(speed, 6.2) if (anim_name == "run" and not on_stair_segment) else speed
	var eff_speed := minf(base_spd, 3.2) if on_stair_segment else base_spd
	# Sobrepeso: frena igual que al jugador humano (walk * (1 - carry * 0.2))
	var carry_ratio := _bot_carry_ratio(b)
	if carry_ratio > 0.0:
		eff_speed *= 1.0 - carry_ratio * 0.2
	var cur_spd := float(b.get("_speed", 0.0))
	if crouched_move:
		cur_spd = minf(cur_spd, eff_speed)
	if anim_name == "run" and not on_stair_segment and cur_spd < 3.8:
		cur_spd = 3.8
	# Vadear frena como al jugador (speed *= lerp(0.72,0.48,profundidad)): a la
	# orilla casi nada, con agua al pecho es un tercio de la marcha normal.
	var water_factor := lerpf(0.72, 0.38, clampf(depth_cur / FORD_MAX_DEPTH, 0.0, 1.0)) if depth_cur > 0.02 else 1.0
	var spd := move_toward(cur_spd, eff_speed * water_factor, delta * 15.0)
	b["_speed"] = spd
	var step := minf(spd * delta, d)
	var chosen_dir := dir if in_building_3d else (sm if sm.length_squared() > 0.001 else dir)
	var new_pos := cur + chosen_dir * step
	var front_blocked := false if on_stair_segment else _is_step_blocked(cur, new_pos, deep_now)
	# Una puerta cerrada no es un muro: si el paso choca y hay una puerta
	# cerrada al alcance, el bot la abre como un jugador y repatha ya libre.
	if front_blocked and world != null and world.has_method("bot_try_open_door_at") and world.bot_try_open_door_at(cur):
		b["path"] = []
		b["path_timer"] = 0.0
		_stop_bot_motion(b)
		return
	# Si el paso frontal choca contra un obstaculo/agua, tantear angulos libres
	if front_blocked and not _is_pos_blocked(cur, 0.25, deep_now):
		var sign_pref := float(b.get("avoid_sign", 1.0))
		var steered := false
		for deg in [28.0, -28.0, 56.0, -56.0, 88.0, -88.0, 125.0, -125.0]:
			var ang := deg_to_rad(deg * sign_pref)
			var cand_dir := dir.rotated(Vector3.UP, ang)
			var cand_pos := cur + cand_dir * step
			if not _is_step_blocked(cur, cand_pos, deep_now):
				chosen_dir = cand_dir
				new_pos = cand_pos
				steered = true
				front_blocked = false
				break
		if not steered:
			# Bloqueado en todas direcciones: invertir sentido de rodeo y recalcular ruta tras enfriamiento
			b["avoid_sign"] = -sign_pref
			b["path"] = []
			b["path_timer"] = maxf(float(b["path_timer"]), 0.8)
	# Si todos los tanteos fallan, no aplicar el paso frontal que ya sabemos
	# bloqueado. Conservar el detector de atasco para que busque otra ruta.
	if front_blocked:
		new_pos = cur
	var gy := _ground_y(new_pos.x, new_pos.z, cur.y)
	if front_blocked:
		new_pos.y = cur.y
	elif on_stair_segment or (in_building_3d and absf(next_goal.y - cur.y) > 0.01):
		var t_ramp := clampf(step / maxf(d, 0.01), 0.0, 1.0)
		var ramp_y := lerpf(cur.y, next_goal.y, t_ramp)
		new_pos.y = ramp_y if absf(gy - ramp_y) > 0.4 else (maxf(gy, ramp_y) if next_goal.y > cur.y else minf(gy, ramp_y))
	elif in_building_3d and cur.y > 1.8 and gy < cur.y - .4:
		new_pos.y = cur.y
	else:
		new_pos.y = gy
	proxy.global_position = new_pos
	proxy.set_meta("saved_pos", new_pos)
	b["pos"] = new_pos
	# La animación lateral y la velocidad reflejan el paso REAL, incluyendo
	# desvíos por obstáculos y la frenada al llegar al objetivo.
	var displacement := new_pos - cur
	var moved := displacement.length_squared() > 0.000001
	var flat_displacement := Vector3(displacement.x, 0.0, displacement.z)
	# La aceleración controla X/Z: un ajuste vertical al suelo o una escalera
	# no puede convertirse en velocidad horizontal extra en el siguiente tick.
	b["_speed"] = flat_displacement.length() / maxf(delta, 0.001)
	b["_mdir"] = flat_displacement.normalized()
	var target_yaw := atan2(-chosen_dir.x, -chosen_dir.z)
	if not moved:
		target_yaw = float(b["rot"])
	if absf(angle_difference(float(b["rot"]), target_yaw)) > 1.2:
		b["rot"] = target_yaw
	else:
		b["rot"] = lerp_angle(float(b["rot"]), target_yaw, minf(1.0, delta * 15.0))
	proxy.rotation.y = float(b["rot"])
	var climbing_stairs_now: bool = on_stair_segment or (in_building_3d and absf(new_pos.y - cur.y) > delta * 0.16)
	# Same selection as PlayerController: stairs clip ascending; normal
	# locomotion descending, with the existing armed/torch/rod walk variants.
	var stair_clip := new_pos.y-cur.y > delta*.04 and not bool(b.get("has_rifle",false)) and str(b.get("held_item","")) not in ["Antorcha","Caña de pescar"]
	b["anim"] = ("stairs" if stair_clip else "walk") if climbing_stairs_now else anim_name
	if not moved:
		_stop_bot_motion(b)
	proxy.set_meta("crouching", bool(b.get("crouching", false)))
	proxy.set_meta("prone", bool(b.get("prone", false)))
	proxy.set_meta("sprinting", moved and anim_name == "run" and not climbing_stairs_now)
	proxy.set_meta("moving", moved)
	# Ledger de acercamiento por objetivo: "best" es la menor distancia lograda
	# y "grace" cuenta ventanas seguidas sin mejorarla. Un tropiezo de 2-6 s en
	# un viaje de 500 m no prueba que el destino sea inalcanzable — el veto solo
	# procede tras DOS ventanas sin nuevo acercamiento.
	var gp: Dictionary = b.get("_goal_prog", {})
	if gp.get("g") != raw_goal:
		gp = {"g": raw_goal, "best": INF, "grace": 0}
	var _goal_dist_now := cur.distance_to(raw_goal)
	if _goal_dist_now < float(gp.get("best", INF)) - 6.0:
		gp["best"] = _goal_dist_now
		gp["grace"] = 0
	b["_goal_prog"] = gp
	# Deteccion real de atasco: mide el avance 3D acumulado durante la ventana
	# completa de 2.0 s (incluyendo ascenso vertical en escaleras).
	b["stuck_timer"] = float(b["stuck_timer"]) + delta
	if float(b["stuck_timer"]) >= 2.0:
		var last_pos: Vector3 = b.get("last_move_pos", cur)
		var window_moved: float = new_pos.distance_to(last_pos)
		b["last_move_pos"] = new_pos
		b["stuck_timer"] = 0.0
		if window_moved < 0.75:
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
				gp["grace"] = int(gp.get("grace", 0)) + 1
				if int(gp["grace"]) >= 2:
					gp["grace"] = 0
					_abandon_unreachable_goal(b, raw_goal)
				else:
					b["path"] = []
					b["path_timer"] = 0.0
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
			gp["grace"] = int(gp.get("grace", 0)) + 1
			if int(gp["grace"]) >= 2:
				gp["grace"] = 0
				_abandon_unreachable_goal(b, raw_goal)
			else:
				b["path"] = []
				b["path_timer"] = 0.0

func _has_clear_shot(from_pos: Vector3, to_pos: Vector3) -> bool:
	var _cpt := Time.get_ticks_usec()
	if world == null or not (world is Node3D) or (world as Node3D).get_world_3d() == null:
		return true
	var space: PhysicsDirectSpaceState3D = (world as Node3D).get_world_3d().direct_space_state
	if space == null:
		return true
	# Misma cobertura que RifleProjectile (mascara 5): muros y tambien los
	# techos/muros en la capa de superficie (4) — si no, un tirador elevado
	# atravesaba el tejado con el hitscan aunque la flecha real si parara ahi.
	var query := PhysicsRayQueryParameters3D.create(from_pos + Vector3(0, 1.3, 0), to_pos + Vector3(0, 1.1, 0), 5)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		if CombatProf.enabled: CombatProf.mark("bot.clear_shot", _cpt)
		return false
	# Distant trees/rocks may use analytical collisions rather than bodies.
	if world.has_method("raycast_distant_props"):
		var distant: Dictionary = world.raycast_distant_props(query.from, query.to)
		if not distant.is_empty():
			if CombatProf.enabled: CombatProf.mark("bot.clear_shot", _cpt)
			return false
	if CombatProf.enabled: CombatProf.mark("bot.clear_shot", _cpt)
	return true

# Horario unico: los bots leen el mismo ciclo que el resto del mundo
# (DayNightCycle + GameConst), sin umbrales propios.
# "Noche" para la conducta = oscuridad real: noche de reloj o luz ambiente
# insuficiente (final del crepusculo, primera luz, tormenta al atardecer).
# Mientras quede luz util el bot sigue con su jornada.
func _is_world_night() -> bool:
	var dc = world.get("day_cycle") if world != null else null
	if dc == null:
		return false
	if dc.has_method("is_dark"):
		return bool(dc.is_dark())
	if dc.has_method("is_night"):
		return bool(dc.is_night())
	var wd = dc.get("weather_darkness")
	return DayNightCycle.is_dark_at(float(dc.get("time_of_day")), float(wd) if wd != null else 0.0)

# Noche de reloj: la que usa SurvivalStats para el jugador (frio/desgaste).
func _is_clock_night() -> bool:
	var dc = world.get("day_cycle") if world != null else null
	if dc == null:
		return false
	if dc.has_method("is_night"):
		return bool(dc.is_night())
	return DayNightCycle.is_night_at(float(dc.get("time_of_day")))

# Fase del dia para diagnostico y decisiones: night|dawn|day|prep|dusk.
func _world_day_phase() -> String:
	if _is_world_night():
		return "night"
	return DayNightCycle.phase_at(_world_time_of_day())

func _world_time_of_day() -> float:
	if world != null and world.get("day_cycle") != null:
		return float(world.day_cycle.get("time_of_day"))
	return 12.0

# Despedida ritual del ciclo de sueño: al acostarse de noche ("goodnight") o al
# despertar de dia ("goodmorning") el bot saluda por chat a cada bot o jugador
# cercano con el que no tiene mala relacion — una vez por pareja y por ciclo
# (_gn_pairs/_gm_pairs), reseteadas al cerrarse el ciclo contrario.
func _bot_say_farewell(b: Dictionary, kind: String) -> void:
	var proxy: Node3D = b["proxy"]
	if proxy == null:
		return
	var pairs_key := "_gn_pairs" if kind == "goodnight" else "_gm_pairs"
	b["_gm_pairs" if kind == "goodnight" else "_gn_pairs"] = []
	var done: Array = b.get(pairs_key, [])
	var my_id := int(b["bot_id"])
	for oid in bots.keys():
		if int(oid) == my_id or int(oid) in done:
			continue
		var ob: Dictionary = bots[oid]
		var op: Node3D = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var rel := get_bot_relationship(my_id, "bot_%d" % oid)
		if float(rel.get("hostility", 0.0)) > 0.4 or float(rel.get("fear", 0.0)) > 0.55:
			continue
		if proxy.global_position.distance_to(op.global_position) > BOT_CHAT_GREET_RANGE:
			continue
		var oname := str(ob.get("name", str(oid)))
		_bot_chat_send(b, int(oid), oname, _chat_fallback_line(b, kind, oname), kind)
		done.append(int(oid))
	var net = world.get("net") if world != null else null
	if net != null and "players" in net:
		for pid in net.players.keys():
			if int(pid) == int(net.get_my_id()) or is_bot_peer_id(int(pid)) or int(pid) in done:
				continue
			var pdata: Dictionary = net.players[pid]
			if bool(pdata.get("is_ai_bot", false)) or bool(pdata.get("offline", false)):
				continue
			var rel := get_bot_relationship(my_id, _actor_persist_key(int(pid)))
			if float(rel.get("hostility", 0.0)) > 0.4 or float(rel.get("fear", 0.0)) > 0.55:
				continue
			var pp := _find_actor_by_peer_id(int(pid))
			if pp == null or not is_instance_valid(pp):
				continue
			if proxy.global_position.distance_to(pp.global_position) > BOT_CHAT_GREET_RANGE:
				continue
			var pname := str(pdata.get("char_name", pdata.get("name", "Jugador")))
			_bot_chat_send(b, int(pid), pname, _chat_fallback_line(b, kind, pname), kind)
			done.append(int(pid))
	b[pairs_key] = done

# Las ultimas horas de luz (GameConst.PREP_START hasta que oscurece de
# verdad, crepusculo incluido): ventana en la que un superviviente precavido
# ya junta el fuego y la luz que va a necesitar de noche.
func _is_pre_night() -> bool:
	if world != null and world.get("day_cycle") != null:
		var tod := float(world.day_cycle.get("time_of_day"))
		return tod >= GameConst.PREP_START and tod < GameConst.NIGHT_START and not _is_world_night()
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

# Bajo techo: refugio propio/ajeno construido, o casa/edificio (si descansa o
# duerme dentro, el techo le resguarda del frio nocturno y la lluvia aunque la
# puerta hubiera quedado abierta al entrar).
func _bot_is_sheltered(b: Dictionary, pos: Vector3) -> bool:
	if _bot_at_own_built_shelter(b, pos):
		return true
	if world.has_method("_is_near_built_shelter") and world._is_near_built_shelter(pos):
		return true
	var resting_inside: bool = bool(b.get("sleeping", false)) or bool(b.get("sitting", false)) or str(b.get("_act", "")) in ["rest", "rest_home"]
	if world.has_method("_is_player_in_house") and world._is_player_in_house(pos):
		if not resting_inside and world.has_method("_is_in_open_house") and world._is_in_open_house(pos):
			return false
		return true
	if resting_inside and (_find_city_building_for_pos(pos) >= 0 or _is_in_clock_tower(pos)):
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
	var cold_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("cold", 0))
	# "Helandose" empieza donde empieza el daño (SurvivalStats: <35.4 ya
	# resta vida). Con el umbral viejo (35.2) quedaba una banda en la que
	# el bot perdia vida sin sentirse en peligro ni buscar calor — antes la
	# tapaba comer sin hambre para curarse; ya no se desperdicia comida asi.
	# La cascada letal es frio->hambre: a <36 C el cuerpo quema comida x1.6
	# y la hipotermia e inanicion llegan juntas. Quien ya murio de frio
	# empieza a buscar calor antes (cap 0.45: a 3 muertes actua a 35.9 C —
	# justo sobre la banda del multiplicador de hambre). El cap no puede
	# subir mas: bajo techo el cuerpo equilibra ~36.1-36.4 C (SurvivalStats
	# lerea el target hacia 36.6 max), asi que un umbral 36.35 nunca se
	# satisface sentado y el bot quedaba acampado en casa para siempre —
	# moverse al sol calienta mas (+0.4/+0.8) que el propio techo.
	var thresh := 35.45 + minf(0.45, float(cold_lessons) * 0.15)
	return st != null and not st.dead and st.body_temperature < thresh

func _bot_is_exhausted(b: Dictionary) -> bool:
	var st: SurvivalStats = b.get("vstats")
	var cold_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("cold", 0))
	var thresh := 14.0 + minf(9.0, float(cold_lessons) * 3.0)
	return st != null and not st.dead and st.sleep < thresh

# Hora de acostarse del bot (horas despues de NIGHT_START). Una persona no
# se mete en el saco al caer el sol: hace vida junto al fuego — come,
# craftea, charla — hasta una hora personal. La valentia y la curiosidad
# alargan la velada, el instinto de supervivencia la acorta; un jitter
# fijo por bot evita que todos colapsen a la vez. Cacheada por estacion.
func _bot_bedtime_hour(b: Dictionary) -> float:
	var cached: Dictionary = b.get("_bedtime", {})
	if not cached.is_empty() and absf(float(cached.get("base", -999.0)) - GameConst.NIGHT_START) < 0.01:
		return float(cached.get("hour", GameConst.NIGHT_START))
	var p: Dictionary = b.get("personality", {})
	var jitter := float(int(b.get("bot_id", 0)) * 2654435761 % 1000) / 1000.0
	var delay := 0.35 \
		+ (1.0 - float(p.get("survival_instinct", 0.5))) * 0.55 \
		+ float(p.get("bravery", 0.5)) * 0.45 \
		+ float(p.get("curiosity", 0.5)) * 0.35 \
		+ jitter * 0.30
	var hour := GameConst.NIGHT_START + clampf(delay, 0.3, 1.9)
	b["_bedtime"] = {"base": GameConst.NIGHT_START, "hour": hour}
	return hour

# La IA asesora mando "descansa/vuelve a casa" y el deposito no esta lleno:
# de dia eso habilita la siesta donde acampa (se despierta al llegar a 55
# via _bot_should_wake). Sin esto el bot marchaba al campamento por la
# directiva y se pasaba horas de pie sin poder dormir — cansado pero no
# "letalmente agotado", orbitando su solar en explore_dwell infinito.
func _bot_wants_day_rest(b: Dictionary) -> bool:
	var st: SurvivalStats = b.get("vstats")
	if st == null or st.dead or st.sleep >= 55.0:
		return false
	var d := _ai_active_directive(b)
	return str(d.get("action", "")) in ["rest", "return_home"]

# Necesidades que rompen CUALQUIER formacion — la prioridad real es:
# amenaza > salud/hambre/sed/frio/sueño > orden humana > marcha del lider >
# loot de camino > recado de la IA > comportamiento independiente. Vendar,
# comer y beber del inventario ya ocurren en _maintain_bot_needs antes que
# todo; esto cubre lo que exige moverse: rio, forrajeo, refugio, descanso.
func _bot_vital_break(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if _bot_is_freezing(b) or _bot_is_exhausted(b):
		return true
	if float(b["thirst"]) < 35.0 and not _bot_has_drink(proxy):
		return true
	if float(b["hunger"]) < 40.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b)):
		return true
	if float(b["health"]) < 45.0:
		return true
	return false

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
	# La fisica usa la noche de reloj, igual que el tick del jugador en Main.
	var is_night := _is_clock_night()
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
	# Contato com agua = mesmo preco do jogador: empapa proporcional a
	# profundidade, gasta energia vadeando e rouba calor do corpo.
	var w_depth := 0.0
	if world.has_method("get_river_depth_at"):
		w_depth = float(world.get_river_depth_at(pos))
	if w_depth > 0.02:
		st.wetness = minf(1.0, st.wetness + delta * (0.38 + w_depth * 0.55))
		st.energy = maxf(0.0, st.energy - delta * 0.018 * (0.8 + w_depth))
		st.body_temperature = maxf(32.0, st.body_temperature - delta * 0.013 * (0.5 + st.wetness + w_depth))

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
	# La antorcha en la mano calienta y seca igual que la del jugador
	# (PlayerController: delta*1.5 a techo 37.5 y wetness -0.03/s) — para el
	# bot torch_lit ES la llama; sin esto una antorcha encendida era solo luz.
	if bool(b.get("torch_lit", false)) and _bot_has_item(proxy, "Antorcha"):
		var torch_pct := _burn_bot_torch(proxy, 0.0 if (bool(b.get("sitting", false)) and _is_near_any_lit_campfire(pos, 5.0)) else delta * 2.0)
		if torch_pct <= 0.0:
			b["torch_lit"] = false
			proxy.set_meta("torch_lit", false)
		else:
			st.apply_external_heat(1.5 * torch_pct * delta, 37.5)
			st.wetness = maxf(0.0, st.wetness - 0.03 * torch_pct * delta)

	var sleeping := bool(b.get("sleeping", false))
	var anim_now := str(b["anim"])
	var moving: bool = anim_now in ["walk", "run"] and not sleeping
	var sprinting: bool = anim_now == "run" and not sleeping
	var carry_ratio := _bot_carry_ratio(b)
	var sun := 1.0 - (float(dc.get("weather_darkness")) if dc != null else 0.0)
	var wind := float(obs.get("wind_speed", 0.0))
	var resting := bool(b.get("sitting", false)) or str(b.get("_act", "")) == "rest"
	st.tick(delta, sprinting, ambient_temp, sheltered, shelter_warmth, is_night, moving, sleeping, carry_ratio, false, false, sun, wind, resting)
	# Recuperacion de energia al caminar o descansar despierto (misma curva que
	# PlayerController._physics_process: sin esto st.energy caia a 0 para siempre
	# y multiplicaba x1.5 el desgaste de sueno hasta matar al bot de agotamiento).
	if not sprinting and not sleeping and not st.dead:
		var eff_max_en := st.max_stat * (1.0 - carry_ratio * 0.5)
		st.energy = minf(eff_max_en, st.energy + maxf(2.5, 8.0 - carry_ratio * 5.0) * st.get_thermal_recovery_multiplier() * delta)
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
		if st.body_temperature < 35.4:
			kind = "hypothermia"
		elif st.body_temperature > 39.0:
			kind = "heatstroke"
		elif st.hunger <= 0.0:
			kind = "starved" # hambre a 0 (con o sin sed): inanicion, la etiqueta historica
		elif st.thirst <= 0.0:
			kind = "dehydrated"
		elif st.bleeding > 0.0 or st.blood <= 0.0:
			kind = "bled"
		elif st.sick:
			kind = "sick"
		elif st.sleep <= 10.0:
			kind = "exhausted"
	_kill_bot(b, kind)

# Anillo templado de la lumbre: el calor de fogata llega hasta 4 m con
# wf = 1-(d-0.6)/3.4 — a 3.5 m da ~+0.44 °C/s (calienta y seca sin cocinar);
# a 4.1 m wf=0 (cero calor: el "punto seguro" fijo dejaba al helado sin
# calor junto a su propia fogata). El muy mojado se pega un poco mas.
func _bot_fire_warm_radius(b: Dictionary) -> float:
	var st: SurvivalStats = b.get("vstats")
	return 3.3 if st != null and st.wetness > 0.5 else 3.5

# Modo termico con histeresis (b["_fire_band"]): el calor es instantaneo y
# monotono hasta el cap de 38 °C, asi que la regulacion es un ciclo — pero
# sin histeresis el bot penduleaba cada pocos ticks entre rest_pos y el
# anillo. Solo se cambia de modo al cruzar los bordes: dentro de
# 36.3-36.9 °C se conserva el estado actual.
func _bot_fire_band_update(b: Dictionary) -> String:
	var st: SurvivalStats = b.get("vstats")
	if st == null or st.dead:
		return ""
	var band := str(b.get("_fire_band", ""))
	if st.body_temperature >= 36.9:
		band = "cool"
	elif st.body_temperature <= 36.3 or (st.wetness > 0.35 and st.body_temperature <= 36.6):
		band = "warm"
	b["_fire_band"] = band
	return band

# Amenaza inmediata: combate, depredador, huida, escondite, emboscada,
# busqueda de enemigo o fuego enemigo reciente. Regular la distancia al
# fuego no puede interrumpir ninguna de estas maniobras — el fuego quema
# lento, el lobo no.
func _bot_under_immediate_threat(b: Dictionary) -> bool:
	if b.get("aggro_target") != null:
		return true
	if _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null:
		return true
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		return true
	if not (b.get("_ambush", {}) as Dictionary).is_empty():
		return true
	if int(b.get("_lost_foe_until_msec", 0)) > Time.get_ticks_msec():
		return true
	return Time.get_ticks_msec() - int(b.get("_last_attacker_msec", -999999)) < 5000

# Punto junto a una fogata viva pero fuera del anillo que cocina: el calor
# real llega hasta 4 m — gestionar el alijo o sentarse en el refugio
# pegado a las brasas era la muerte "succumbed" del campamento resuelto.
# Con b informado, el borde depende de su modo termico: con frio proyecta
# al anillo templado (calienta de verdad), si no al borde exterior seguro.
func _bot_fire_safe_spot(pos: Vector3, y: float, b = null) -> Vector3:
	var fp := _nearest_lit_campfire_pos(pos, 4.3, b)
	if fp == Vector3.INF:
		return pos
	var radius := 4.15
	if b != null:
		radius = _bot_fire_warm_radius(b) if _bot_fire_band_update(b) == "warm" else 4.15
	var dn := Vector2(pos.x - fp.x, pos.z - fp.z)
	if b == null:
		dn = dn.normalized() if dn.length() > 0.05 else Vector2(1.0, 0.0)
		return Vector3(fp.x + dn.x * radius, y, fp.z + dn.y * radius)
	# El borde elegido debe ser alcanzable: pegado a una pared u obstaculo
	# se barre el anillo por angulos hasta un punto libre. Si no hay NINGUNO
	# no devolvemos un punto bloqueado — el destino queda sin proyectar y
	# la fogata queda vetada para el resto de busquedas de calor.
	var cand := _bot_fire_ring_spot(b, fp, dn, radius, y)
	if cand == Vector3.INF:
		_bot_veto_fire(b, fp)
		return pos
	return cand

# Termostato de campamento: la lumbre empuja la temperatura hacia 38 °C
# con la misma curva que al jugador — pegado a las brasas te cocinas
# ("succumbed" invisible), en el borde frio te hielas. Regula la distancia
# con histeresis; las amenazas inmediatas le ganan salvo que el peligro
# termico ya sea letal (pisar brasas o temp en zona de dano).
func _bot_camp_fire_standoff(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var st: SurvivalStats = b.get("vstats")
	if st == null or st.dead:
		return false
	# Su propia fogata es conocida: la posicion queda en campfire_pos y la
	# validacion fisica confirma que sigue encendida — no hace falta "verla"
	# a 5 m; un bot desplazado unos metros mas alla (cambio de meta, empujon
	# de colision) se helaba en su sitio con el fuego vivo a 7 m.
	# Cooling responds to the fire heating this body, even when its own known
	# campfire is elsewhere. Otherwise it can wake and fall asleep beside a
	# different fire forever without ever taking the escape step.
	var fp := _nearest_lit_campfire_pos(proxy.global_position, 4.15 if st.body_temperature >= 36.9 else 0.85)
	var own_fp: Vector3 = b.get("campfire_pos", Vector3.INF)
	if fp == Vector3.INF and not str(b.get("campfire_id", "")).is_empty() and own_fp != Vector3.INF \
		and _nearest_lit_campfire_pos(own_fp, 4.5) != Vector3.INF:
		fp = own_fp
	# Alcance del termostato = alcance del gate de despertar por frio: un
	# bot desplazado tras una pelea (lobo, empujon) y dormido a >5 m del
	# fuego entraba en un ciclo despertar/dormir en zona sin calor hasta
	# morir — el gate le despertaba porque habia fuego alcanzable y el
	# standoff no lo veia. Con frio, caminar hacia la lumbre conocida ES
	# la respuesta humana (la rama warm_up le lleva hasta el anillo).
	if fp == Vector3.INF:
		fp = _nearest_lit_campfire_pos(proxy.global_position, 30.0, b)
	if fp == Vector3.INF:
		b.erase("_fire_band")
		return false
	var d := Vector2(proxy.global_position.x - fp.x, proxy.global_position.z - fp.z).length()
	var dir2 := Vector2(proxy.global_position.x - fp.x, proxy.global_position.z - fp.z)
	var dir := dir2.normalized() if dir2.length() > 0.05 else Vector2(1.0, 0.0)
	# Pisar las brasas (-5 hp/s): salir siempre, incluso en combate — medio
	# metro de paso es supervivencia, no desatender la amenaza. Aunque el
	# punto de salida este tapado se intenta: salir del fuego es urgente.
	if d < 0.85:
		var esc := _bot_fire_ring_spot(b, fp, dir, 4.25, proxy.global_position.y)
		if esc == Vector3.INF:
			esc = Vector3(fp.x + dir.x * 4.25, proxy.global_position.y, fp.z + dir.y * 4.25)
		b["_act"] = "cool_off"
		_move_bot_towards(b, esc, 4.5, delta, "walk")
		return true
	# Amenaza inmediata manda sobre el confort termico — salvo dano letal ya
	# en curso: cocinarse vivo mientras se pelea tampoco es defenderse.
	var lethal_thermal := st.body_temperature >= 37.8 or st.body_temperature <= 34.5
	if not lethal_thermal and _bot_under_immediate_threat(b):
		return false
	# Una bebida en marcha (caminata a la orilla o el trago de 2.6 s) no se
	# interrumpe por confort termico: el standoff a 30 m tiraba del bot hacia
	# el anillo cada tick, la caminata no progresaba y a los 12 s la fuente
	# quedaba vetada 120 s — el bot moria de sed junto a un rio alcanzable
	# y a una fogata encendida. El daño termico letal sigue mandando igual.
	if not lethal_thermal and str(b.get("_act", "")) == "drink":
		return false
	var band := _bot_fire_band_update(b)
	if band == "cool" and d < 4.15:
		var spot := _bot_fire_ring_spot(b, fp, dir, 4.25, proxy.global_position.y)
		if spot == Vector3.INF:
			_bot_veto_fire(b, fp)
			return false
		b["_act"] = "cool_off"
		_move_bot_towards(b, spot, 3.8, delta, "walk")
		return true
	if band == "cool" and st.body_temperature > GameConst.BOT_HEAT_RECOVERY_TEMP and d >= 4.15 and d < 6.0 \
			and not _bot_under_immediate_threat(b):
		# Finish cooling before a stash/camp chore pulls the bot straight back
		# into the hot ring. This is recovery, not a permanent strategic veto.
		b["_act"] = "cool_off"
		b["anim"] = "idle"
		b["sitting"] = true
		return true
	if band == "warm":
		var plan: Dictionary = b.get("ai_directive", {})
		if str(plan.get("state", "RUNNING")) == "RUNNING" \
				and str(plan.get("action", "")) in ["explore", "scavenge", "hunt", "forage", "seek_ally", "avoid_zone"] \
				and not _is_world_night() and not _bot_is_freezing(b):
			# Comfort must not pull an otherwise healthy expedition back to
			# a remembered fire. Actual cold still takes priority above it.
			return false
		var warm_r := _bot_fire_warm_radius(b)
		if d > warm_r + 0.3 or d < warm_r - 0.6:
			var spot_in := _bot_fire_ring_spot(b, fp, dir, warm_r, proxy.global_position.y)
			if spot_in == Vector3.INF:
				_bot_veto_fire(b, fp)
				return false
			b["_act"] = "warm_up"
			_move_bot_towards(b, spot_in, 3.8, delta, "walk")
			return true
	return false

# Condiciones para tumbarse a dormir en el punto de descanso (llamado desde el
# bloque de refugio de _tick_bot; despertar lo gestiona _bot_should_wake).
func _bot_try_start_sleep(b: Dictionary, is_night: bool) -> bool:
	var st: SurvivalStats = b.get("vstats")
	var proxy: Node3D = b.get("proxy")
	# Colapso por agotamiento letal: el cuerpo se apaga aunque este escondido
	# — dormir en el escondite gana a morir de pie por agotamiento (Kael
	# murio asi: amenaza activa + sueño 0 y ni el colapso podia tumbarlo).
	# El aggro en plena pelea sigue bloqueando: no se duerme peleando.
	# Reservas para sobrevivir la siesta — o nada que ganar quedandose
	# despierto: sin comida ni agua a mano, dormir con hambre mata lento
	# pero quedarse de pie con sueño~0 mata ya (la muerte de Carlos en el
	# pueblo: agotado y hambriento no podia ni dormir ni rescatarse). El
	# margen >5 evita la siesta que el hambre romperia al instante
	# (el despertar letal es <4 — ver _bot_should_wake).
	var collapse := st != null and not st.dead and st.sleep <= 4.0 \
		and (float(b.get("hunger", 100.0)) >= 14.0 and float(b.get("thirst", 100.0)) >= 10.0 \
			or (proxy != null and not _bot_has_edible_food(proxy, true) and not _bot_has_drink(proxy) \
				and float(b.get("hunger", 100.0)) > 5.0 and float(b.get("thirst", 100.0)) > 5.0))
	# Reclutado por un jugador humano: le sigue dia y noche — pero agotado
	# de verdad se aparta a dormir y se reincorpora al despertar (el
	# vital_break ya lo saco de la formacion antes de llegar aqui). Morir
	# de agotamiento siguiendo la marcha no ayuda a nadie.
	var human_leader := int(b.get("team_leader_id", 0)) > 0 and not is_bot_peer_id(int(b.get("team_leader_id", 0)))
	var recruited_rest := human_leader and (collapse or _bot_is_exhausted(b))
	if bool(b.get("sleeping", false)) or (human_leader and not recruited_rest) or (float(b.get("hide_timer", 0.0)) > 0.0 and not collapse) or b.get("aggro_target") != null:
		return false
	if st == null or st.dead:
		return false
	# Duerme de noche; si esta agotado de verdad cabecea incluso de dia. El
	# umbral es el mismo que fuerza el acampada (_bot_is_exhausted, sube con
	# las lecciones de frio) — si difieren, el bot queda "cansado para
	# acampar pero no para dormir" y se pasa el dia sentado sin recuperar.
	var exhausted := _bot_is_exhausted(b)
	if not is_night and not exhausted and not _bot_wants_day_rest(b):
		return false
	# La velada: anochecio pero aun no es su hora de acostarse — como una
	# persona, sigue haciendo vida de campamento (fuego, comida, crafteo,
	# charla) en vez de tumbarse al caer el sol. Agotamiento, colapso o
	# necesidades urgentes acuestan antes; sin luz propia, fuego cercano
	# ni techo no hay velada posible — dormir a oscuras sigue ganando. Y
	# solo velan los descansados: con el deposito por debajo de ~58 el
	# cansado se acuesta al anochecer, que amanecer sin dormir mata.
	if is_night and not collapse and not exhausted \
			and world != null and world.get("day_cycle") != null \
			and not bool(b.get("_velada_done", false)) \
			and not _bot_needs_food_or_water(b) and st.sleep > 58.0 \
			and _world_time_of_day() < _bot_bedtime_hour(b) \
			and (_bot_has_item(proxy, "Antorcha") \
				or _is_near_any_lit_campfire(proxy.global_position, 14.0) \
				or _bot_is_sheltered(b, proxy.global_position)):
		b["_sleep_veto"] = "velada"
		return false
	# Colapso por agotamiento letal: con el sueno al borde de la muerte el
	# cuerpo se apaga — se desploma donde este si conserva reservas para
	# una siesta breve, incluso con frio. Mejor inconsciente que muerto de pie: un bot al que
	# estas puertas le niegan el suelo no recupera sleep NUNCA (sentado solo
	# deja de gastar) y acaba muerto de agotamiento pese a estar descansando.
	if not collapse:
		# Necesidades sin despensa ni luz no bloquean — DE NOCHE: con la
		# mochila vacia despierto no hay nada que hacer a oscuras, y dormir
		# frena ambos desgastes x0.3 hasta el borde de inanicion
		# (_bot_should_wake). Con comida/bebida/antorcha hay un plan real:
		# comer, beber o forrajear — dormir seria procrastinar. De dia el
		# veto de la luz no existe: el hambriento trabaja, no duerme. Y en
		# el filo de la inanicion (<=5) tampoco: la ultima expedicion se
		# hace despierto, dormido solo se muere sin intentarlo.
		# El "plan real" tiene que servir a la necesidad concreta: comida
		# para el hambre, bebida para la sed. Con sed y solo comida en la
		# mochila no hay nada que hacer a oscuras — antes ese caso lo tapaba
		# comer sin hambre (cada bocado daba algo de agua) y sin ese apaño
		# el bot quedaba en vela hasta morir agotado con el rio a 30 m.
		var hungry_s := float(b.get("hunger", 100.0)) < 40.0
		var thirsty_s := float(b.get("thirst", 100.0)) < 35.0
		if _bot_needs_food_or_water(b) \
				and (not is_night or (hungry_s and _bot_has_edible_food(proxy, true)) or (thirsty_s and _bot_has_drink(proxy)) or _bot_has_item(proxy, "Antorcha") \
					or float(b.get("hunger", 100.0)) <= 5.0 or float(b.get("thirst", 100.0)) <= 5.0):
			b["_sleep_veto"] = "needs"
			return false
		# A la intemperie con frio peligroso no se duerme; bajo techo si —
		# dentro se calienta durmiendo. El colapso pasa siempre (mejor
		# inconsciente que muerto de pie).
		if (st.body_temperature < 35.4 and not _bot_is_sheltered(b, proxy.global_position)) \
				or st.body_temperature > GameConst.BOT_HEAT_ALERT_TEMP:
			b["_sleep_veto"] = "temp"
			return false
	if st.sleep >= 99.0 and st.energy >= 98.0:
		b["_sleep_veto"] = "full"
		return false # sueño y energia al tope: queda sentado (donde recupera vida)
	b.erase("_sleep_veto")
	b["sleeping"] = true
	PlanManager.sync(self, b, Time.get_ticks_msec())
	b["sitting"] = false
	b["crouching"] = false
	b["prone"] = false
	b["anim"] = "sleep"
	# Ya durmio esta noche: la velada cumplio — si despierta de guardia o
	# por una necesidad puede volver a la cama sin nueva sobremesa.
	if is_night:
		b["_velada_done"] = true
	# Las buenas noches a quienes hay cerca — un superviviente se despide al
	# acostarse. El colapso letal no charla: el cuerpo se apaga, no se despide.
	if is_night and not collapse:
		_bot_say_farewell(b, "goodnight")
	if recruited_rest:
		_bot_notify_leader_rest(b)
	return true

# Enfriamiento del aviso "me aparto a dormir" al lider humano — una siesta
# no spamea el chat aunque duerma y despierte varias veces seguidas.
const BOT_REST_NOTICE_SEC := 240.0

# El reclutado que se aparta a dormir avisa a su lider humano y arma la
# reincorporacion (saludo al volver en _tick_teammate_behavior). Sin aviso
# el jugador solo veria a su escolta quedarse quieto sin explicacion.
func _bot_notify_leader_rest(b: Dictionary) -> void:
	var lid := int(b.get("team_leader_id", 0))
	if lid <= 0 or is_bot_peer_id(lid):
		return
	b["_rest_rejoin"] = true
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < float(b.get("_rest_notice_t", 0.0)):
		return
	b["_rest_notice_t"] = now + BOT_REST_NOTICE_SEC
	var st: SurvivalStats = b.get("vstats")
	var lname := _actor_display_name(lid)
	var line := "Estoy agotado, %s... paro a dormir un rato. Os alcanzo luego." % lname
	if st != null and st.sleep <= 4.0:
		line = "No puedo mas, %s... me desplomo aqui. Nos vemos al despertar." % lname
	_bot_chat_send(b, lid, lname, line, "rest")

# Leave enough reserves for the trip to food/water, not just to stand up.
# Shared by wake-up, bedtime and camp selection so a hungry bot cannot
# wake and immediately return to sleep while resources are out of reach.
const NIGHT_SUPPLY_FIRE_RADIUS := 12.0
# Con hambre/sed letales de noche y sin luz, una meta concreta (fuente de
# agua conocida, seta del escaneo) puede exigir una caminata real a
# oscuras: quedarse quieto esperando es morir seguro.
const NIGHT_LETHAL_SUPPLY_RADIUS := 150.0

func _bot_supply_goal_lit(b: Dictionary, goal: Vector3) -> bool:
	if not _is_world_night() or b.is_empty():
		return true
	var proxy: Node3D = b.get("proxy")
	if proxy == null:
		return false
	if _bot_has_item(proxy, "Antorcha"):
		return true
	# Both ends must share the same lit fire; no hopping between distant fires.
	if world != null and "_lit_campfires" in world:
		for fire in world._lit_campfires:
			if fire is Dictionary and fire.get("pos") is Vector3 and _campfire_entry_alive(fire):
				var center: Vector3 = fire["pos"]
				if proxy.global_position.distance_to(center) <= NIGHT_SUPPLY_FIRE_RADIUS and goal.distance_to(center) <= NIGHT_SUPPLY_FIRE_RADIUS:
					return true
	return false

func _bot_night_supply_emergency(b: Dictionary) -> bool:
	return float(b.get("hunger", 100.0)) < 14.0 or float(b.get("thirst", 100.0)) < 10.0

func _bot_supply_goal_allowed(b: Dictionary, goal: Vector3) -> bool:
	if _bot_supply_goal_lit(b, goal):
		return true
	var proxy: Node3D = b.get("proxy")
	# Urgencia letal (hambre<14, sed<10) sin luz: una meta concreta al
	# alcance gana a la oscuridad — el bot conoce el rio o el escaneo vio
	# la seta; quedarse quieto es morir seguro. No reabre el vagar a
	# ciegas: solo pasan destinos dirigidos dentro del alcance.
	# La expedicion se abandona cuando el riesgo supera sus posibilidades:
	# escondido de una amenaza no se cruza el campo a la vista, y con
	# sueño letal solo vale un trago a tiro — una caminata larga muriendo
	# de agotamiento no llega; el colapso frena el desgaste y despierta
	# al borde de la inanicion.
	if (_bot_night_supply_emergency(b) or bool(b.get("_night_eat_chain", false))) and proxy != null and float(b.get("hide_timer", 0.0)) <= 0.0:
		var vst_sup: SurvivalStats = b.get("vstats")
		# En cadena de recuperacion solo vale la despensa local — la
		# caminata de 150 m es para la urgencia, no para rematar la comida.
		var reach := NIGHT_LETHAL_SUPPLY_RADIUS if _bot_night_supply_emergency(b) else 45.0
		var lethal_radius := 25.0 if vst_sup != null and vst_sup.sleep <= 8.0 else reach
		if proxy.global_position.distance_to(goal) <= lethal_radius:
			return true
	# Last resort only after failing to prepare light. Anchor the six-metre
	# search at its starting point so repeated decisions cannot wander away.
	# La meta cercana al bot tambien vale para reingresar: empujado un palmo
	# fuera de la burbuja por una colision, podria volver a un objetivo
	# interno en vez de quedarse parado en el borde para siempre.
	var origin: Vector3 = b.get("_night_emergency_origin", Vector3.INF)
	return _bot_night_supply_emergency(b) and origin != Vector3.INF and proxy != null \
		and goal.distance_to(origin) <= 6.0 \
		and (proxy.global_position.distance_to(origin) <= 6.0 or proxy.global_position.distance_to(goal) <= 6.0)

# Returns true while preparing light or unable to leave safely.
func _bot_prepare_night_supplies(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	if _bot_has_item(proxy, "Antorcha") and (bool(b.get("torch_lit", false)) or _bot_ignite_torch(b)):
		b.erase("_night_emergency_origin")
		b["torch_lit"] = true
		b["held_item"] = "Antorcha"
		proxy.set_meta("torch_lit", true)
		proxy.set_meta("saved_held_item", "Antorcha")
		return false
	# Sin antorcha la fabrica; con antorcha pero sin yesca lo que falta es la
	# ignicion (2 Palos frotados sirven), no otra antorcha.
	var no_torch := _bot_item_count(proxy, "Antorcha") == 0
	if (no_torch and _bot_try_craft_named(b, delta, ["Antorcha"], true)) \
			or (_bot_item_count(proxy, "Trapos") < 1 and _bot_try_craft_named(b, delta, ["Trapos"], false)) \
			or (_bot_item_count(proxy, "Palo") < 2 and _bot_item_count(proxy, "Tronco") > 0 and _bot_try_craft_named(b, delta, ["Palo"], false)):
		b["_act"] = "torch"
		return true
	if not _bot_supply_goal_lit(b, proxy.global_position):
		var own_fire: Vector3 = b.get("campfire_pos", Vector3.INF)
		if own_fire != Vector3.INF and proxy.global_position.distance_to(own_fire) <= NIGHT_SUPPLY_FIRE_RADIUS:
			_ensure_bot_campfire_lit(b)
		if not _bot_supply_goal_lit(b, proxy.global_position) and _can_bot_build_campfire(proxy):
			var spot := _find_nearby_campfire_spot(b, proxy.global_position)
			if spot != Vector3.INF:
				_bot_build_and_light_campfire(b, spot)
	if _bot_supply_goal_lit(b, proxy.global_position):
		# El bot iluminado que pasa a hambre/sed letal tambien ancla su
		# burbuja aqui: la seta a 5 m fuera de la luz es alcanzable igual
		# que para quien esta a oscuras (fijada donde empezo la urgencia).
		if _bot_night_supply_emergency(b) and not b.has("_night_emergency_origin"):
			b["_night_emergency_origin"] = proxy.global_position
		return false
	if _bot_night_supply_emergency(b):
		if not b.has("_night_emergency_origin"):
			b["_night_emergency_origin"] = proxy.global_position
		return false
	b.erase("_night_emergency_origin")
	# Un helado sin luz no se conforma con dormir a la intemperie ni con la
	# caminata a casa: primero el rescate — fogata encendida al alcance,
	# fuego de emergencia con su material o la salida por lena/piedras.
	if _bot_try_cold_rescue(b, delta):
		return true
	# Sin luz ni material para hacerla: la unica caminata a oscuras
	# permitida es volver a casa — el refugio propio o la fogata encendida
	# mas cercana. Peor que estar sin luz es estar sin luz en mitad del
	# campo; en casa hay fogata, alijo y quien le ayude.
	if _bot_night_home_walk(b, delta):
		return true
	# No light must not trap a freezing bot in idle. Use the same final
	# emergency movement as the ordinary refuge branch, after heat/refuge
	# options fail; lethal exhaustion still takes the sleep path.
	var cold_stats: SurvivalStats = b.get("vstats")
	if (cold_stats == null or cold_stats.sleep > 8.0) and _bot_freeze_march(b, delta):
		return true
	# Sin refugio ni luz ni nada alcanzable: dormir en el sitio gana a
	# quedarse de pie hasta el amanecer — el desgaste dormido es x0.3 y
	# el despertar de _bot_should_wake cubre hambre/sed letales y frio.
	b["_act"] = "need_light"
	if _bot_try_start_sleep(b, true):
		return true
	b["anim"] = "idle"
	b["sleeping"] = false
	b["sitting"] = false
	return true

# La unica caminata a oscuras permitida: volver al refugio propio o a la
# fogata encendida mas cercana (mismo criterio que el acampada nocturna de
# wants_camp). Devuelve false si no hay refugio alcanzable.
func _bot_night_home_walk(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var shp_n: Vector3 = b.get("shelter_pos", Vector3.INF)
	var refuge_radius := GameConst.BOT_EMERGENCY_REFUGE_RADIUS if _bot_is_freezing(b) else 85.0
	var refuge_n: Vector3 = shp_n if not str(b.get("shelter_id", "")).is_empty() and shp_n != Vector3.INF else _nearest_safe_refuge(b, refuge_radius)
	if refuge_n == Vector3.INF:
		return false
	# El hogar puede tener la fogata pegada: el punto donde se sienta es el
	# borde seguro del calor, no el centro del anillo que cocina.
	refuge_n = _bot_fire_safe_spot(refuge_n, proxy.global_position.y, b)
	b["_act"] = "rest"
	var d_home := Vector2(proxy.global_position.x - refuge_n.x, proxy.global_position.z - refuge_n.z).length()
	if d_home > 1.8:
		_move_bot_towards(b, refuge_n, 3.8, delta, "walk")
	else:
		# Ya en el refugio: quedarse sentado toda la noche con necesidades
		# sin resolver era la muerte por agotamiento en casa — el callejon
		# sin salida cortaba el alijo guardado y el sueño. Aqui si puede:
		# primero lo que el alijo le de (comida/agua sin salir a oscuras),
		# luego tumbarse; solo si nada de eso aplica se queda de guardia.
		if not str(b.get("shelter_id", "")).is_empty():
			_bot_sync_own_shelter_stash(b)
			if _bot_try_start_sleep(b, true):
				return true
		else:
			# Refugio ajeno (casa/fogata cercana): sin alijo propio, al menos
			# descansar — el colapso/dormir viven en _bot_try_start_sleep.
			_bot_try_start_sleep(b, true)
		b["sitting"] = not bool(b.get("sleeping", false))
		b["anim"] = "sleep" if bool(b.get("sleeping", false)) else "sit"
	return true

func _bot_needs_food_or_water(b: Dictionary) -> bool:
	return float(b.get("hunger", 100.0)) < 40.0 or float(b.get("thirst", 100.0)) < 35.0

func _bot_should_wake(b: Dictionary, is_night: bool) -> bool:
	if b.get("aggro_target") != null or b.get("_s_predator") != null or b.get("_s_foe") != null:
		return true
	# Dormir dentro del rio no es descanso: si el agua pasa de vadeable
	# (empujon, deriva de nav, respawn dentro) despierta al instante — el
	# escape a lo somero va por encima de recuperar sueño.
	var proxy_sw: Node3D = b.get("proxy")
	if proxy_sw != null and world != null and world.has_method("get_river_depth_at") \
			and float(world.get_river_depth_at(proxy_sw.global_position)) > WADE_DEPTH:
		return true
	if not (b.get("_ambush", {}) as Dictionary).is_empty():
		return true # una emboscada activa lo saca de la cama
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		# El colapso por agotamiento letal no obedece ni a esconderse ni a
		# huir: el cuerpo apagado sigue dormido en el escondite (Kael).
		var st_w: SurvivalStats = b.get("vstats")
		if st_w == null or st_w.sleep > 4.0:
			return true
	if _bot_needs_food_or_water(b):
		var nap: SurvivalStats = b.get("vstats")
		# A short exhaustion nap is allowed, but never until starvation.
		# Siesta letal sin despensa (colapso con sueño~0 y mochila vacia):
		# el hambre/sed solo despiertan al borde real de la inanicion —
		# despertarle con hambre 13 y las manos vacias no le da nada que
		# comer, solo lo deja de pie muriendo otra vez (bucle de colapso).
		# Con algo comestible en la mochila vuelven los umbrales normales
		# y despierta para comer.
		var proxy_nap: Node3D = b.get("proxy")
		var lethal_nap := nap != null and proxy_nap != null \
			and not _bot_has_edible_food(proxy_nap, true) and not _bot_has_drink(proxy_nap) \
			and not _bot_has_item(proxy_nap, "Antorcha")
		if lethal_nap:
			# Mochila vacia: despertar solo si despierto hay algo que hacer —
			# la expedicion letal se desbloquea a hambre<14/sed<10 (rio,
			# alijo, seta dirigida); entre medias la siesta frena el desgaste
			# x0.3 y despertar con las manos vacias solo lo deja de pie
			# muriendo (el tope "siesta a 8" tiene sentido CON despensa:
			# despierta pronto para comer — sin ella, a vacio).
			if float(b["hunger"]) < 14.0 or float(b["thirst"]) < 10.0:
				return true
		elif nap == null or nap.sleep > 8.0 \
				or float(b["hunger"]) < 14.0 or float(b["thirst"]) < 10.0:
			return true
	var st: SurvivalStats = b.get("vstats")
	if st == null:
		return true
	# Despertar al borde del dano termico, no dentro de el: el dano empieza
	# a <35.4 y >37.8 — un umbral mas profundo dejaba al bot dormido
	# sangrando hp en la banda ciega 34.8-35.4 sin despertar jamas.
	if st.body_temperature > GameConst.BOT_HEAT_ALERT_TEMP:
		return true
	if st.body_temperature < 35.45:
		if st.body_temperature <= 34.5:
			return true # dano letal: siempre despierta
		# Banda templada 34.5-35.45 (-0.5 hp/s): despertar solo tiene
		# sentido si hay una fuente de calor alcanzable o materiales para
		# encenderla — sin ninguna, dormir aguanta la banda mucho mejor
		# que vagar despierto helandose igual (ciclo despertar/dormir que
		# terminaba en "exhausted" sin que nada pudiera calentarle).
		var proxy_w: Node3D = b.get("proxy")
		if proxy_w != null:
			if _nearest_lit_campfire_pos(proxy_w.global_position, 30.0, b) != Vector3.INF:
				return true
			if _can_bot_build_campfire(proxy_w):
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
	var arrows := -1
	for w in order:
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == w and int(it.get("quantity", 1)) > 0:
				if it.has("durability") and float(it.get("durability", 100.0)) <= 0.0:
					continue
				if (w == "Fusil de asalto" or w == "Rifle francotirador") and not _bot_gun_any_ammo(proxy, w):
					break
				if w == "Arco reforzado" or w == "Arco de madera":
					if arrows < 0:
						arrows = _bot_arrow_count(proxy)
					if arrows <= 0:
						break
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

# --- Municion de armas de fuego del bot: mismo modelo que el jugador ---
# (cargador + reserva por calibre, recarga de ~2.2 s, items de municion que
# alimentan la reserva). Vive en la meta del proxy para que sobreviva a los
# cambios de estado del bot y se repliegue en saved_extra.rifle_ammo.
func _bot_gun_ammo(proxy: Node3D) -> Dictionary:
	var ammo: Dictionary = proxy.get_meta("bot_gun_ammo", {})
	if ammo.is_empty():
		var extra: Dictionary = proxy.get_meta("saved_extra", {})
		ammo = (extra.get("rifle_ammo", {}) as Dictionary).duplicate()
		if ammo.is_empty():
			ammo = {
				"m4_magazine": BOT_M4_MAG_SIZE,
				"m4_reserve": BOT_M4_MAG_SIZE * 3,
				"magazine": BOT_SNIPER_MAG_SIZE,
				"reserve": BOT_SNIPER_MAG_SIZE * 4
			}
		proxy.set_meta("bot_gun_ammo", ammo)
	return ammo

func _bot_gun_ammo_save(proxy: Node3D, ammo: Dictionary) -> void:
	proxy.set_meta("bot_gun_ammo", ammo)
	var extra: Dictionary = proxy.get_meta("saved_extra", {})
	extra["rifle_ammo"] = ammo.duplicate()
	proxy.set_meta("saved_extra", extra)

func _bot_gun_is_m4(weapon: String) -> bool:
	return weapon == "Fusil de asalto"

func _bot_gun_loaded_key(weapon: String) -> String:
	return "m4_magazine" if _bot_gun_is_m4(weapon) else "magazine"

func _bot_gun_reserve_key(weapon: String) -> String:
	return "m4_reserve" if _bot_gun_is_m4(weapon) else "reserve"

func _bot_gun_mag_size(weapon: String) -> int:
	return BOT_M4_MAG_SIZE if _bot_gun_is_m4(weapon) else BOT_SNIPER_MAG_SIZE

func _bot_gun_loaded(ammo: Dictionary, weapon: String) -> int:
	return int(ammo.get(_bot_gun_loaded_key(weapon), 0))

func _bot_gun_reserve(ammo: Dictionary, weapon: String) -> int:
	return int(ammo.get(_bot_gun_reserve_key(weapon), 0))

# Indice del primer item de municion del calibre del arma (5.56/M4 vs el
# resto, igual que PlayerController._load_ammo_item), o -1.
func _bot_gun_ammo_item_idx(proxy: Node3D, weapon: String) -> int:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var want_m4 := _bot_gun_is_m4(weapon)
	for i in inv.size():
		var it = inv[i]
		if not (it is Dictionary) or str(it.get("type", "")) != "ammo" or int(it.get("quantity", 1)) <= 0:
			continue
		var n := str(it.get("name", ""))
		var is_556 := n.findn("5.56") >= 0 or n.findn("5,56") >= 0 or n.findn("m4") >= 0 or n.findn("asalto") >= 0
		if is_556 == want_m4:
			return i
	return -1

# Consume un item de municion y vuelca sus balas a la reserva, como hace el
# jugador con _load_ammo_item (use_value rondas, o un cargador si es 0).
func _bot_gun_load_ammo_item(proxy: Node3D, ammo: Dictionary, weapon: String) -> bool:
	var idx := _bot_gun_ammo_item_idx(proxy, weapon)
	if idx < 0:
		return false
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var it: Dictionary = inv[idx]
	var rounds := int(it.get("use_value", 0))
	if rounds <= 0:
		rounds = _bot_gun_mag_size(weapon)
	it["quantity"] = int(it.get("quantity", 1)) - 1
	if int(it["quantity"]) <= 0:
		inv.remove_at(idx)
	proxy.set_meta("saved_inventory", inv)
	var rkey := _bot_gun_reserve_key(weapon)
	ammo[rkey] = int(ammo.get(rkey, 0)) + rounds
	_bot_gun_ammo_save(proxy, ammo)
	return true

# True si el bot posee un arma de fuego del calibre de este item de
# municion (para retirarla del refugio, como haria el jugador).
func _bot_gun_wants_ammo_item(proxy: Node3D, item_name: String) -> bool:
	var is_556 := item_name.findn("5.56") >= 0 or item_name.findn("5,56") >= 0 or item_name.findn("m4") >= 0 or item_name.findn("asalto") >= 0
	return _bot_item_count(proxy, "Fusil de asalto" if is_556 else "Rifle francotirador") > 0

# El arma solo es usable si queda algo cargado, en reserva o en items.
func _bot_gun_any_ammo(proxy: Node3D, weapon: String) -> bool:
	var ammo := _bot_gun_ammo(proxy)
	return _bot_gun_loaded(ammo, weapon) > 0 or _bot_gun_reserve(ammo, weapon) > 0 or _bot_gun_ammo_item_idx(proxy, weapon) >= 0

# Un disparo del bot: devuelve true si sale (y consume una bala del
# cargador). Con cargador vacio intenta recargar desde la reserva o desde
# un item de municion del inventario; la recarga cuesta el mismo tiempo
# que al jugador (shoot_cooldown = BOT_GUN_RELOAD_TIME) y no dispara en
# ese tick. Sin reserva ni items devuelve false con el arma seca.
func _bot_gun_prepare_shot(b: Dictionary, weapon: String) -> bool:
	var proxy: Node3D = b["proxy"]
	var ammo := _bot_gun_ammo(proxy)
	var lkey := _bot_gun_loaded_key(weapon)
	if _bot_gun_loaded(ammo, weapon) > 0:
		ammo[lkey] = int(ammo.get(lkey, 0)) - 1
		_bot_gun_ammo_save(proxy, ammo)
		return true
	if _bot_gun_reserve(ammo, weapon) <= 0:
		_bot_gun_load_ammo_item(proxy, ammo, weapon)
	var rkey := _bot_gun_reserve_key(weapon)
	if int(ammo.get(rkey, 0)) <= 0:
		return false
	var rounds: int = mini(_bot_gun_mag_size(weapon) - int(ammo.get(lkey, 0)), int(ammo.get(rkey, 0)))
	ammo[lkey] = int(ammo.get(lkey, 0)) + rounds
	ammo[rkey] = int(ammo.get(rkey, 0)) - rounds
	_bot_gun_ammo_save(proxy, ammo)
	b["shoot_cooldown"] = BOT_GUN_RELOAD_TIME
	b["gun_reloading"] = true
	# Reloading also makes noise while crouched/prone, where no standing
	# reload clip is sent to clients. The receiver deduplicates clip + event.
	_emit_bot_condition_audio(b,"reload")
	return false

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
		if _bot_item_count(proxy, w) > 0 and _bot_gun_any_ammo(proxy, w):
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
	for i in range(inv.size() - 1, -1, -1):
		var it = inv[i]
		if it is Dictionary and str(it.get("name", "")) == item_name and float(it.get("durability", 100.0)) > 0.0:
			var cur_d := float(it.get("durability", _default_item_max_durability(item_name, str(it.get("type", "")))))
			if not it.has("max_durability"):
				it["max_durability"] = maxf(cur_d, _default_item_max_durability(item_name, str(it.get("type", ""))))
			var new_d := maxf(0.0, cur_d - amount)
			it["durability"] = new_d
			if new_d <= 0.0:
				var qty := int(it.get("quantity", 1)) - 1
				if qty <= 0:
					inv.remove_at(i)
				else:
					it["quantity"] = qty
					it["durability"] = float(it.get("max_durability", 100.0))
			break
	proxy.set_meta("saved_inventory", inv)

# Encendido con la misma regla del jugador (PlayerController._toggle_flashlight):
# una carga de Cerillas, 2 Palos frotados — o gratis junto a una fogata viva.
# Devuelve false si no tiene con que prenderla.
func _bot_ignite_torch(b: Dictionary) -> bool:
	var proxy: Node3D = b["proxy"]
	if not _bot_has_item(proxy, "Antorcha"):
		return false
	if _is_near_any_lit_campfire(proxy.global_position, 5.0):
		return true
	if _bot_item_count(proxy, "Cerillas") >= 1:
		_reduce_bot_item_durability(proxy, "Cerillas", 1.0)
		return true
	if _bot_item_count(proxy, "Palo") >= 2:
		_bot_consume_one_item(proxy, "Palo")
		_bot_consume_one_item(proxy, "Palo")
		return true
	return false

# Quema la Antorcha igual que PlayerController (2.0/s) y al agotarse devuelve
# el Palo base para no evaporar madera. Retorna el porcentaje restante (0..1).
func _burn_bot_torch(proxy: Node3D, amount: float) -> float:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for i in range(inv.size()):
		var it = inv[i]
		if it is Dictionary and str(it.get("name", "")) == "Antorcha" and float(it.get("durability", 600.0)) > 0.0:
			var dmax := float(it.get("max_durability", 600.0))
			if dmax <= 0.0:
				dmax = 600.0
			var dcur := maxf(0.0, float(it.get("durability", dmax)) - amount)
			if dcur <= 0.0:
				var qty := int(it.get("quantity", 1)) - 1
				if qty <= 0:
					inv.remove_at(i)
				else:
					it["quantity"] = qty
					it["durability"] = dmax
				_bot_add_inventory_item(inv, {"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0})
				proxy.set_meta("saved_inventory", inv)
				return 0.0
			it["durability"] = dcur
			it["max_durability"] = dmax
			proxy.set_meta("saved_inventory", inv)
			return clampf(dcur / dmax, 0.0, 1.0)
	return 0.0

func _default_item_max_durability(nm: String, tp: String) -> float:
	if nm == "Cerillas" or tp == "tool_matches":
		return 10.0
	if nm == "Antorcha" or tp == "tool_torch":
		return 600.0
	for r in CraftingSystem.RECIPES:
		var out: Dictionary = r.get("output", {})
		if str(out.get("name", "")) == nm and out.has("max_durability"):
			return float(out["max_durability"])
	if tp in ["weapon", "weapon_bow", "weapon_bola", "tool_axe", "tool_spear", "tool_hoe", "tool_shovel", "tool_fishing", "tool_hammer", "tool_pickaxe"] \
			or nm in BUSH_TOOLS or nm in ["Azada", "Pala", "Pico", "Martillo"]:
		return 100.0
	return 0.0

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
			if it.has("durability") and float(it.get("durability", 100.0)) <= 0.0:
				continue
			total += int(it.get("quantity", 1))
	return total

func _bot_has_raw_meat(proxy: Node3D) -> bool:
	return not _first_raw_meat_name(proxy).is_empty()

func _bot_raw_meat_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and str(it.get("name", "")).begins_with("Carne cruda"):
			total += int(it.get("quantity", 1))
	return total

# Piezas utilizables como cebo de doma: las mismas que _first_raw_meat_name
# (carne cruda y Pez crudo). La doma exige TAME_FEEDINGS comidas.
func _bot_tame_bait_count(proxy: Node3D) -> int:
	var total := 0
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			if nm.begins_with("Carne cruda") or nm == "Pez crudo":
				total += int(it.get("quantity", 1))
	return total

func _bot_has_skewered_meat(proxy: Node3D) -> bool:
	return _bot_item_count(proxy, "Carne ensartada") > 0 or _bot_item_count(proxy, "Pez ensartado") > 0

func _bot_can_cook_raw_meat(proxy: Node3D) -> bool:
	if _bot_has_skewered_meat(proxy):
		return true
	return _bot_has_raw_meat(proxy) and _bot_item_count(proxy, "Palo afilado") > 0

# Puede cocinar en cuanto afile un palo: lleva carne/pescado crudo + Palo +
# filo (Cuchillo o cualquier sustituto de receta). Desesperado, afilar un
# palo (2.4 s) es mejor que comer crudo y enfermar.
func _bot_can_sharpen_for_meat(proxy: Node3D) -> bool:
	if not _bot_has_raw_meat(proxy):
		return false
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for recipe in CraftingSystem.RECIPES:
		if str((recipe.get("output", {}) as Dictionary).get("name", "")) == "Palo afilado" \
				and _bot_can_craft(recipe, inv):
			return true
	return false

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
		_bot_add_inventory_item(inv, {"name": "Pez ensartado", "type": "food", "weight": 0.45, "quantity": 1, "use_value": 18.0, "species": "pez"})
	else:
		_bot_add_inventory_item(inv, {"name": "Carne ensartada", "type": "food", "weight": 0.45, "quantity": 1, "use_value": 20.0, "species": _meat_species(raw)})
	proxy.set_meta("saved_inventory", inv)
	return true

# "Carne cruda de oso" -> "oso"; "Carne cruda" generica -> "".
func _meat_species(raw_name: String) -> String:
	return raw_name.trim_prefix("Carne cruda de ") if raw_name.begins_with("Carne cruda de ") else ""

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
	if tp in ["food", "resource", "material", "medical", "ammo", "ammo_arrow", "water", "misc"]:
		var sp := str(item_dict.get("species", ""))
		for it in inv:
			if it is Dictionary and str(it.get("name", "")) == nm and str(it.get("species", "")) == sp:
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
	if tp in ["food", "resource", "material", "medical", "ammo", "ammo_arrow", "water", "misc"]:
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
	var nm := str(entry.get("name", ""))
	var tp := str(entry.get("type", "resource"))
	var out := {
		"name": nm,
		"type": tp,
		"weight": float(entry.get("weight", 0.2)),
		"quantity": maxi(1, int(entry.get("quantity", entry.get("qty", 1)))),
		"use_value": float(entry.get("use_value", entry.get("use", 0.0))),
	}
	var def_max := _default_item_max_durability(nm, tp)
	if entry.has("max_durability") or entry.has("durability") or def_max > 0.0:
		var dmax := float(entry.get("max_durability", def_max if def_max > 0.0 else 100.0))
		if dmax <= 0.0:
			dmax = def_max if def_max > 0.0 else 100.0
		var dcur := float(entry.get("durability", dmax))
		out["durability"] = clampf(dcur, 0.0, maxf(dmax, dcur))
		out["max_durability"] = maxf(dmax, dcur)
	if entry.has("spoilage"):
		out["spoilage"] = float(entry["spoilage"])
	return out

# Lo que no le cabe cae al suelo a sus pies, igual que al jugador: queda
# saqueable por cualquiera como pickup real sincronizado.
func _bot_drop_to_ground(b: Dictionary, item_dict: Dictionary) -> void:
	if world == null:
		return
	var p: Vector3 = (b["proxy"] as Node3D).global_position + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
	if world.has_method("_spawn_ground_pickup"):
		var pre_n: int = (world._dropped_items as Array).size() if "_dropped_items" in world else -1
		world._spawn_ground_pickup(str(item_dict.get("name", "")), str(item_dict.get("type", "resource")), p, float(item_dict.get("weight", 0.2)), int(item_dict.get("quantity", 1)), float(item_dict.get("use_value", 0.0)))
		if pre_n >= 0 and (world._dropped_items as Array).size() > pre_n:
			var dropped: Dictionary = (world._dropped_items as Array)[-1]
			if item_dict.has("durability"):
				dropped["durability"] = float(item_dict["durability"])
			if item_dict.has("max_durability"):
				dropped["max_durability"] = float(item_dict["max_durability"])
			if item_dict.has("spoilage"):
				dropped["spoilage"] = float(item_dict["spoilage"])
	elif "_dropped_items" in world:
		var did := "bot_drop_%d_%d" % [int(b["bot_id"]), int(Time.get_ticks_msec()) % 1000000]
		var rec := {"id": did, "name": str(item_dict.get("name", "")), "type": str(item_dict.get("type", "resource")), "weight": float(item_dict.get("weight", 0.2)), "qty": int(item_dict.get("quantity", 1)), "use": float(item_dict.get("use_value", 0.0)), "pos": [p.x, p.y, p.z], "action_type": "drop"}
		if item_dict.has("durability"):
			rec["durability"] = float(item_dict["durability"])
		if item_dict.has("max_durability"):
			rec["max_durability"] = float(item_dict["max_durability"])
		if item_dict.has("spoilage"):
			rec["spoilage"] = float(item_dict["spoilage"])
		world._dropped_items.append(rec)

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
			if CraftingSystem._is_recipe_tool(recipe, input_name):
				var cur_td := float(it.get("durability", _default_item_max_durability(str(it.get("name", "")), str(it.get("type", "")))))
				if cur_td <= 0.0:
					cur_td = 100.0
				var next_td := maxf(0.0, cur_td - 3.0)
				it["durability"] = next_td
				needed -= int(it.get("quantity", 1))
				if next_td <= 0.0:
					var q_left := int(it.get("quantity", 1)) - 1
					if q_left <= 0:
						inv.erase(it)
					else:
						it["quantity"] = q_left
						it["durability"] = float(it.get("max_durability", 100.0))
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
	if out.has("species"):
		entry["species"] = str(out["species"])
	if not pelt_species.is_empty():
		entry["pelt_species"] = pelt_species
	if not _bot_try_add_inventory_item(b, inv, entry):
		_bot_drop_to_ground(b, entry) # mochila llena: la pieza cae a sus pies
	proxy.set_meta("saved_inventory", inv)
	_auto_equip_best_gear(b)
	_evolve_personality(b, "craft_success", 0.22)
	record_strategy_outcome(int(b["bot_id"]), "forage" if str(entry.get("type", "")) in ["food", "tool_hoe"] else "explore", true, 0.06)
	_publish_bot_to_net_players(b)

# Prioridad de cada receta para el bot: -1 = no le interesa / no puede usarla.
func _bot_recipe_score(b: Dictionary, recipe: Dictionary) -> float:
	var proxy: Node3D = b["proxy"]
	var out: Dictionary = recipe.get("output", {})
	var oname := str(out.get("name", ""))
	var otype := str(out.get("type", ""))
	# Fogata y refugio tienen su logica propia
	if otype in ["campfire", "shelter"]:
		return -1.0
	# Caña de pescar: la fabrica cuando le aprieta la despensa y hay agua a
	# mano — el pez cocinado es la comida mas valiosa. Nunca duplica cañas.
	if otype == "tool_fishing":
		if _bot_has_fishing_rod(proxy) or _bot_item_count(proxy, "Pez crudo") >= BOT_FISH_MAX_RAW:
			return -1.0
		if float(b["hunger"]) >= 62.0 and _bot_has_edible_food(proxy, false):
			return -1.0
		var wp_rod := _nearest_water_pos(proxy.global_position, b)
		if wp_rod == Vector3.INF or Vector2(proxy.global_position.x - wp_rod.x, proxy.global_position.z - wp_rod.z).length() > 160.0:
			return -1.0
		return 6.6
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
	# Flechas: solo si tiene arco — y con tope para no fundir en flechas todos
	# los Palos que necesita para levantar su refugio (11 palos).
	if otype == "ammo_arrow" or oname.begins_with("Flecha"):
		if _bot_best_bow(proxy).is_empty():
			return -1.0
		var cur_arrows := _bot_arrow_count(proxy)
		if cur_arrows >= 15:
			return -1.0
		if str(b.get("shelter_id", "")).is_empty() and _bot_item_count(proxy, "Palo") < 12 and cur_arrows >= 5:
			return -1.0
		match oname:
			"Flecha de hueso": return 6.6
			"Flecha de piedra": return 6.4
			"Flecha de madera": return 6.2
			_: return 6.0
	# Arcos: solo sin fusil y sin fabricar un arco inferior si ya tiene uno
	var has_rifle := _bot_item_count(proxy, "Fusil de asalto") + _bot_item_count(proxy, "Rifle francotirador") > 0
	if otype == "weapon_bow":
		if has_rifle or _bot_item_count(proxy, "Arco reforzado") > 0:
			return -1.0
		if oname == "Arco de madera" and not _bot_best_bow(proxy).is_empty():
			return -1.0
		return 5.6 if oname == "Arco reforzado" else 5.0
	if oname == "Boleadoras":
		return 3.0 if has_rifle or not _bot_best_bow(proxy).is_empty() else 5.0
	# Mientras junta los 11 palos del refugio (ya lleva >=6 en camino y aun no
	# sobran >=13), blindar los palos contra recetas secundarias (azada, lanza,
	# palo afilado sin carne) para que no le roben los 11 del refugio.
	var r_inputs: Dictionary = recipe.get("inputs", {})
	if str(b.get("shelter_id", "")).is_empty() and (r_inputs.has("Palo") or r_inputs.has("Palo afilado")):
		var supply_now := _bot_palo_supply(proxy)
		var essential_stick := oname in ["Antorcha", "Carne ensartada", "Pez ensartado"] \
				or (oname == "Palo afilado" and _bot_has_raw_meat(proxy) and _bot_item_count(proxy, "Palo afilado") == 0) \
				or (oname == "Azada de piedra" and _bot_wants_farm_tool(b) and _bot_item_count(proxy, "Semillas") >= 1 and supply_now != 11)
		if not essential_stick and supply_now >= 6 and supply_now < 13:
			return -1.0
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
		if not _bot_wants_farm_tool(b):
			return -1.0
		return 6.75 if _bot_item_count(proxy, "Semillas") >= 1 else 6.1
	if oname == "Cuerda":
		# Si aun no tiene antorcha, no gastar los primeros Trapos en cuerda
		# (la cuerda de Tendon sigue puntuando 6.8).
		if r_inputs.has("Trapos") and _bot_item_count(proxy, "Antorcha") == 0 and _bot_item_count(proxy, "Trapos") <= 2:
			return 3.2
		return 6.8 if _bot_item_count(proxy, "Cuerda") < 1 else 2.0
	if oname == "Trapos":
		# Cortar ropa a tiras solo cuando hacen falta: venda, cuerda,
		# boleadoras, antorcha o ropa de piel — nunca por acumular
		if _bot_item_count(proxy, "Antorcha") == 0 and _bot_item_count(proxy, "Trapos") == 0:
			return 6.85
		return 5.5 if _bot_wants_craft_input(b, "Trapos") else 1.5
	if oname == "Palo":
		# Tronco -> 2 palos: prioridad maxima mientras le falten los 11 palos
		# del refugio para no quedarse con troncos sin rajar en la mochila.
		return 6.9 if _bot_item_count(proxy, "Palo") < 11 else 1.5
	if oname == "Piedra afilada":
		if _bot_item_count(proxy, "Piedra afilada") > 0 or _bot_has_can_opener(proxy):
			return -1.0
		return 4.3
	if oname == "Antorcha":
		if _bot_item_count(proxy, "Antorcha") > 0:
			return 2.2
		# Quiere una antorcha siempre: por encima de Cuerda (6.8) de tarde/noche
		# para que los primeros Trapos + Palo den luz y ahuyenten lobos.
		return 6.95 if (_is_world_night() or _is_pre_night()) else 5.8
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
		st["at"] = Time.get_ticks_msec()
		b["anim"] = "idle"
		b["crouching"] = true
		b["sitting"] = false
		if float(st["t"]) <= 0.0:
			b["_craft_state"] = {}
			b["_craft_check"] = 0.4
			_bot_apply_craft(b, st.get("recipe", {}))
		return true
	b["_craft_check"] = float(b.get("_craft_check", 0.0)) - delta
	if float(b["_craft_check"]) > 0.0:
		return false
	b["_craft_check"] = 3.5 + fmod(float(int(b["bot_id"])) * 1.1, 2.0)
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
	b["_craft_state"] = {"recipe": best, "t": 2.4, "at": Time.get_ticks_msec()}
	b["anim"] = "idle"
	b["crouching"] = true
	return true

# Fabrica YA una receta concreta por nombre de salida, saltandose la cola por
# puntos de _bot_try_craft: la antorcha nocturna es supervivencia, no un capricho
# que deba ganar el sorteo. Comparte _craft_state con el crafteo normal.
func _bot_try_craft_named(b: Dictionary, delta: float, wanted: Array, protect_sticks: bool) -> bool:
	var st: Dictionary = b.get("_craft_state", {})
	if not st.is_empty():
		var cur := str(((st.get("recipe", {}) as Dictionary).get("output", {}) as Dictionary).get("name", ""))
		if not wanted.has(cur):
			# Un craft de otra rama abandonado a medias (la urgencia paso y
			# nadie lo retoma) no puede bloquear esta para siempre: si lleva
			# ~6 s sin tick caduca y cede el torno.
			if Time.get_ticks_msec() - int(st.get("at", 0)) <= 6000:
				return false
			b["_craft_state"] = {}
		else:
			st["at"] = Time.get_ticks_msec()
			st["t"] = float(st.get("t", 0.0)) - delta
			b["anim"] = "idle"
			b["crouching"] = true
			b["sitting"] = false
			if float(st["t"]) <= 0.0:
				b["_craft_state"] = {}
				b["_craft_check"] = 0.4
				_bot_apply_craft(b, st.get("recipe", {}))
			return true
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for recipe in CraftingSystem.RECIPES:
		var out := recipe.get("output", {}) as Dictionary
		var oname := str(out.get("name", ""))
		if not wanted.has(oname) or not _bot_can_craft(recipe, inv):
			continue
		if protect_sticks and (oname == "Antorcha" or oname == "Azada de piedra") and not _bot_can_spare_torch_stick(b, proxy):
			continue
		b["_craft_state"] = {"recipe": recipe, "t": 2.4, "at": Time.get_ticks_msec()}
		b["anim"] = "idle"
		b["crouching"] = true
		b["sitting"] = false
		return true
	return false

# La antorcha solo cede cuando el bot tiene los 11 palos EXACTOS que necesita
# para levantar su refugio ahora mismo: gastar uno desharia la obra que ya
# puede pagar. Con cualquier otro suministro se fabrica libre — la fogata
# siempre puede esperar un par de palos mas.
func _bot_can_spare_torch_stick(b: Dictionary, proxy: Node3D) -> bool:
	return not (str(b.get("shelter_id", "")).is_empty() and _bot_item_count(proxy, "Palo") == 11)

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
	if bots.has(bot_id) and not str(bots[bot_id].get("faction", "")).is_empty():
		bfaction = str(bots[bot_id]["faction"])
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
		mem["stats"] = {"alive_total_sec": 0.0, "kills_prey": 0, "kills_predator": 0, "animals_gutted": 0, "kills_bot": 0, "kills_player": 0}
	if not mem.has("ai_stats") or not (mem["ai_stats"] is Dictionary):
		mem["ai_stats"] = {"qwen_ok": 0, "qwen_invalid": 0, "http_errors": 0, "local_decisions": 0, "plans_completed": 0, "plans_resumed": 0, "plan_kept": 0, "plans_failed": 0, "steps_started": 0, "steps_completed": 0, "steps_failed": 0, "blocked_recoveries": 0, "latency_ms_last": 0, "latency_ms_avg": 0, "fallback_reasons": {}}
	if not mem.has("last_death_pos"):
		mem["last_death_pos"] = Vector3.INF
	if not mem.has("last_death_cause"):
		mem["last_death_cause"] = ""
	if not mem.has("last_death_killer"):
		mem["last_death_killer"] = ""
	if not mem.has("last_death_weapon"):
		mem["last_death_weapon"] = ""
	if not mem.has("last_death_unix"):
		mem["last_death_unix"] = 0
	if not mem.has("death_log") or not (mem["death_log"] is Array):
		mem["death_log"] = []
	if not mem.has("killers") or not (mem["killers"] is Dictionary):
		mem["killers"] = {}
	if not mem.has("bad_camp_spots") or not (mem["bad_camp_spots"] is Array):
		mem["bad_camp_spots"] = []
	if not mem.has("base_raided"):
		mem["base_raided"] = 0
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
	if not mem.has("death_lessons") or not (mem["death_lessons"] is Dictionary):
		mem["death_lessons"] = {}
	if not mem.has("events") or not (mem["events"] is Array):
		mem["events"] = []
	if not mem.has("events_summary") or not (mem["events_summary"] is Dictionary):
		mem["events_summary"] = {}
	if not mem.has("known_locations") or not (mem["known_locations"] is Dictionary):
		mem["known_locations"] = {}
	if not mem.has("observed_players") or not (mem["observed_players"] is Array):
		mem["observed_players"] = []
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
	if not mem.has("failed_goals") or not (mem["failed_goals"] is Dictionary):
		mem["failed_goals"] = {}
	if not mem.has("unreachable_pois") or not (mem["unreachable_pois"] is Dictionary):
		mem["unreachable_pois"] = {}
	if not mem.has("sessions"):
		mem["sessions"] = 1
	_migrate_strategy_evidence(mem)
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
		"refused_help":
			_adjust_trait(p, "sociability", -step * 0.75, float(base_p["sociability"]))
			_adjust_trait(p, "cooperation", -step * 0.40, float(base_p["cooperation"]))
		"hunt_success", "kill_threat":
			_adjust_trait(p, "bravery", step * 0.7, float(base_p["bravery"]))
			_adjust_trait(p, "aggression", step * 0.35, float(base_p["aggression"]))
		"good_loot", "poi_discovered":
			_adjust_trait(p, "curiosity", step * 0.45, float(base_p["curiosity"]))
			_adjust_trait(p, "bravery", step * 0.20, float(base_p["bravery"]))
		"craft_success":
			_adjust_trait(p, "survival_instinct", step * 0.55, float(base_p["survival_instinct"]))
			_adjust_trait(p, "curiosity", step * 0.35, float(base_p["curiosity"]))
			_adjust_trait(p, "bravery", step * 0.25, float(base_p["bravery"]))
		"forage_success", "farm_harvest":
			_adjust_trait(p, "survival_instinct", step * 0.65, float(base_p["survival_instinct"]))
			_adjust_trait(p, "cooperation", step * 0.30, float(base_p["cooperation"]))
			_adjust_trait(p, "aggression", -step * 0.25, float(base_p["aggression"]))
		"voice_taught", "team_formed":
			_adjust_trait(p, "sociability", step * 0.80, float(base_p["sociability"]))
			_adjust_trait(p, "cooperation", step * 0.85, float(base_p["cooperation"]))
			_adjust_trait(p, "distrust", -step * 0.70, float(base_p["distrust"]))
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
	_observe_players(b)

# Los bots aprenden de los humanos: si ven a un jugador hacer algo con valor
# de supervivencia (dormir, pescar, acampar junto a la lumbre, guarecerse en
# una casa), el sitio entra en su memoria como lugar "enseniado" — candidato
# real para el asesor y sus propios planes. Cada ~3.5 s por bot.
const OBSERVE_PLAYER_RADIUS := 30.0
const OBSERVE_PLAYER_FRESH_SEC := 1800.0

func _player_near_lit_fire(pos: Vector3) -> bool:
	if world == null or not ("_lit_campfires" in world):
		return false
	for lc in world.get("_lit_campfires"):
		var fp: Vector3 = (lc as Dictionary).get("pos", Vector3.INF)
		if fp != Vector3.INF and Vector2(pos.x - fp.x, pos.z - fp.z).length() < 4.0:
			return true
	return false

func _observe_players(b: Dictionary) -> void:
	var bid := int(b.get("bot_id", 0))
	var now_ms := Time.get_ticks_msec()
	if int(b.get("_obs_pt", 0)) > now_ms:
		return
	b["_obs_pt"] = now_ms + 3500 + (bid * 421 % 900)
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy) or world == null or world.get("net") == null:
		return
	var net = world.net
	var bpos: Vector3 = (proxy as Node3D).global_position
	var mem := _ensure_bot_memory(bid)
	var obs: Array = mem.get("observed_players", [])
	var now_u := Time.get_unix_time_from_system()
	for pid in net.players.keys():
		if pid == net.get_my_id() or int(pid) == bid:
			continue
		var pdata: Dictionary = net.players[pid]
		if pdata.get("offline", false):
			continue
		if is_bot_peer_id(int(pid)):
			# Los bots tambien ensenan: otro superviviente a la vista vale tanto
			# como un humano (vivo solo si esta en la simulacion y no ha caido).
			var ob: Dictionary = bots.get(int(pid), {})
			if ob.is_empty() or float(ob.get("health", 0.0)) <= 0.0:
				continue
		elif not net.peer_alive(pid):
			continue
		if str(pdata.get("anim", "")).begins_with("dead"):
			continue
		var ppos: Vector3 = pdata.get("pos", Vector3.INF)
		if ppos == Vector3.INF:
			continue
		if Vector2(bpos.x - ppos.x, bpos.z - ppos.z).length() > OBSERVE_PLAYER_RADIUS:
			continue
		# Tiene que verlo de verdad: una pared o un desnivel no ensenan nada.
		if not _has_clear_shot(bpos, ppos):
			continue
		var what := ""
		var kind := "wild"
		if bool(pdata.get("sleeping", false)):
			what = "sleep"
			kind = "camp"
		elif str(pdata.get("held_item", "")).findn("caña") >= 0:
			what = "fish"
			kind = "fish"
		elif _player_near_lit_fire(ppos):
			what = "campfire"
			kind = "camp"
		elif world.has_method("_is_player_in_house") and world._is_player_in_house(ppos):
			what = "house"
			kind = "house"
		if what.is_empty():
			continue
		var key := "%d|%s|%d:%d" % [int(pid), what, int(ppos.x / 12.0), int(ppos.z / 12.0)]
		var found := false
		for e in obs:
			if str(e.get("key", "")) == key:
				e["t"] = now_u
				e["pos"] = [snappedf(ppos.x, 0.1), snappedf(ppos.z, 0.1)]
				found = true
				break
		if not found:
			obs.append({"key": key, "player": str(pdata.get("name", "Jugador")),
				"what": what, "kind": kind,
				"pos": [snappedf(ppos.x, 0.1), snappedf(ppos.z, 0.1)], "t": now_u})
			observe_location(bid, "taught:%s:%d:%d" % [what, int(ppos.x), int(ppos.z)], kind, ppos, "taught")
	var fresh: Array = []
	for e in obs:
		if now_u - float(e.get("t", 0.0)) < OBSERVE_PLAYER_FRESH_SEC:
			fresh.append(e)
	mem["observed_players"] = fresh.slice(0, 8)

# Pasos de fauna en el canal de oido: lo que corre se oye lejos (la carga de
# un lobo avisa antes de verse), lo que camina solo cerca. Alimenta el mismo
# last_heard_* que usan disparos/gritos — un lobo oido pasa a ser detectable
# y el asesor ve "heard_footsteps" en sus eventos. No despierta al dormido:
# los pasos no son una alarma, son contexto.
func _tick_fauna_hearing(b: Dictionary) -> void:
	if world == null or world.get_tree() == null:
		return
	var proxy: Node3D = b["proxy"]
	var best: Node3D = null
	var best_d := 9999.0
	for w in world.get_tree().get_nodes_in_group("wildlife"):
		if not (w is Node3D) or not is_instance_valid(w) or bool(w.get("_is_dead")):
			continue
		var wanim := str(w.get("current_anim_keyword")).to_lower()
		var hear_r := 0.0
		if wanim.find("run") >= 0 or wanim.find("chase") >= 0 or wanim.find("trot") >= 0 or wanim.find("gallop") >= 0:
			hear_r = 30.0
		elif wanim.find("walk") >= 0:
			hear_r = 14.0
		if hear_r <= 0.0:
			continue
		var d := proxy.global_position.distance_to((w as Node3D).global_position)
		if d <= hear_r and d < best_d:
			best_d = d
			best = w as Node3D
	if best == null:
		return
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var first := float(b.get("last_heard_until", 0.0)) <= now_s
	# Un disparo reciente pesa mas que unos pasos: no lo pisa el ruido menor.
	if not first and str(b.get("last_heard_kind", "")) == "gunshot":
		return
	var hpos: Vector3 = b.get("last_heard_pos", Vector3.INF)
	if first or hpos == Vector3.INF or best.global_position.distance_to(hpos) > 6.0:
		b["last_heard_pos"] = best.global_position
		b["last_heard_kind"] = "footsteps"
		b["last_heard_actor"] = 0
		b["last_heard_until"] = now_s + 2.5
		if first:
			var at := str(best.get("animal_type"))
			record_bot_event(int(b["bot_id"]), "heard_footsteps", at, _poi_kind_near(best.global_position), best.global_position, "%s:%.0fm" % [at, best_d])

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

func observe_location(bot_id: int, loc_id: String, kind: String, pos: Vector3, source: String = "observed", mark_visit: bool = false) -> String:
	if loc_id.is_empty():
		return ""
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
	return loc_id

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
func _try_share_allied_knowledge(b: Dictionary, dt: float) -> void:
	var my_faction := str(b.get("faction", ""))
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return
	var bid := int(b["bot_id"])
	var my_team := _bot_team_ids(b)
	var pos: Vector3 = (proxy as Node3D).global_position
	for other_id in bots.keys():
		var oid := int(other_id)
		if oid == bid:
			continue
		var ob: Dictionary = bots[oid]
		var same_friendly := my_faction == "friendly" and str(ob.get("faction", "")) == "friendly"
		var same_band := oid in my_team
		if not same_friendly and not same_band:
			continue
		var op = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		if pos.distance_to((op as Node3D).global_position) <= AI_SHARE_RADIUS:
			# Compartir mapa exige convivencia real: el contacto cercano se
			# acumula y la primera transmision tarda SHARE_MIN_CONTACT_SEC —
			# un recien llegado no recibe nada por saludar.
			var seen: Dictionary = b.get("_ally_seen", {})
			var ct := float(seen.get(oid, 0.0)) + dt
			seen[oid] = ct
			b["_ally_seen"] = seen
			if ct >= SHARE_MIN_CONTACT_SEC:
				share_bot_knowledge(bid, oid)

func share_bot_knowledge(bot_id_a: int, bot_id_b: int) -> int:
	if bot_id_a == bot_id_b or not _bot_pair_can_cooperate(bot_id_a, bot_id_b):
		return 0
	# Pausa por pareja: aunque sigan juntos, la conversacion es lenta —
	# cada transmision (SHARE_MAX_LOCS sitios) separada SHARE_COOLDOWN_SEC.
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var ba_rt: Dictionary = bots.get(bot_id_a, {})
	var cd_key := "_share_cd_%d" % bot_id_b
	if float(ba_rt.get(cd_key, 0.0)) > now_s:
		return 0
	var mem_a := _ensure_bot_memory(bot_id_a)
	var mem_b := _ensure_bot_memory(bot_id_b)
	var fa := str(mem_a.get("identity", {}).get("faction", ""))
	var fb := str(mem_b.get("identity", {}).get("faction", ""))
	var in_same_team := bots.has(bot_id_a) and (bot_id_b in _bot_team_ids(bots[bot_id_a]))
	if (fa != "friendly" or fb != "friendly") and not in_same_team:
		return 0
	ba_rt[cd_key] = now_s + SHARE_COOLDOWN_SEC
	var bb_rt: Dictionary = bots.get(bot_id_b, {})
	bb_rt["_share_cd_%d" % bot_id_a] = now_s + SHARE_COOLDOWN_SEC
	var shared_count := 0
	var ka: Dictionary = mem_a.get("known_locations", {})
	var kb: Dictionary = mem_b.get("known_locations", {})
	# Lo ya compartido solo se afina (riesgo/visitas de la interseccion);
	# las ubicaciones nuevas traspasan SHARE_MAX_LOCS por transmision,
	# elegidas por utilidad real: lo que el compañero piso, lo peligroso
	# y lo cercano al receptor.
	shared_count += _share_refine_intersection(ka, kb)
	shared_count += _share_refine_intersection(kb, ka)
	shared_count += _share_new_locations(ka, kb, _bot_pos_v(bot_id_b))
	shared_count += _share_new_locations(kb, ka, _bot_pos_v(bot_id_a))
	mem_a["known_locations"] = ka
	mem_b["known_locations"] = kb
	# Las advertencias tambien viajan: los aliados comparten quien mato a
	# supervivientes y a quien temen/odian — un verdugo conocido por uno es
	# sospechoso para todos ("Kael mato a dos; no te fies").
	_share_enemy_knowledge(mem_a, mem_b, _actor_persist_key(bot_id_b), _actor_persist_key(bot_id_a))
	_share_enemy_knowledge(mem_b, mem_a, _actor_persist_key(bot_id_a), _actor_persist_key(bot_id_b))
	return shared_count

func _bot_pos_v(bot_id: int) -> Vector3:
	var b: Dictionary = bots.get(bot_id, {})
	var proxy = b.get("proxy")
	if proxy != null and is_instance_valid(proxy):
		return (proxy as Node3D).global_position
	return b.get("pos", Vector3.INF)

func _share_refine_intersection(ka: Dictionary, kb: Dictionary) -> int:
	var n := 0
	for loc_id in ka.keys():
		if not kb.has(loc_id):
			continue
		var entry: Dictionary = ka[loc_id]
		kb[loc_id]["risk"] = maxf(float(kb[loc_id].get("risk", 0.0)), float(entry.get("risk", 0.0)))
		kb[loc_id]["combat_risk"] = maxf(float(kb[loc_id].get("combat_risk", 0.0)), float(entry.get("combat_risk", 0.0)))
		kb[loc_id]["visits"] = maxf(float(kb[loc_id].get("visits", 0)), float(entry.get("visits", 0)))
		n += 1
	return n

# Traspasa como mucho SHARE_MAX_LOCS ubicaciones nuevas por llamada, elegidas
# por lo que el compañero contaria primero: sitios que el mismo piso (visits),
# avisos de peligro (risk/combat_risk) y lo cercano al receptor.
func _share_new_locations(ka: Dictionary, kb: Dictionary, recv_pos: Vector3) -> int:
	var cands: Array = []
	for loc_id in ka.keys():
		if kb.has(loc_id):
			continue
		var entry: Dictionary = ka[loc_id]
		var s := float(entry.get("visits", 0)) * 3.0 + (float(entry.get("risk", 0.0)) + float(entry.get("combat_risk", 0.0))) * 2.0
		var ep = entry.get("pos", null)
		if ep is Array and (ep as Array).size() >= 3 and recv_pos != Vector3.INF:
			s -= Vector2(float(ep[0]) - recv_pos.x, float(ep[2]) - recv_pos.z).length() * 0.01
		cands.append({"id": loc_id, "e": entry, "s": s})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	var moved := 0
	for c in cands:
		if moved >= SHARE_MAX_LOCS:
			break
		var loc_id := str(c["id"])
		var entry: Dictionary = c["e"]
		var merged_id := ""
		var ep2 = entry.get("pos", null)
		if ep2 is Array and (ep2 as Array).size() >= 3:
			merged_id = _loc_merge_into(kb, loc_id, Vector3(float(ep2[0]), float(ep2[1]), float(ep2[2])))
		if merged_id.is_empty() and not kb.has(loc_id):
			var copy := entry.duplicate(true)
			copy["source"] = "shared"
			kb[loc_id] = copy
			moved += 1
		elif not merged_id.is_empty():
			kb[merged_id]["risk"] = maxf(float(kb[merged_id].get("risk", 0.0)), float(entry.get("risk", 0.0)))
			kb[merged_id]["combat_risk"] = maxf(float(kb[merged_id].get("combat_risk", 0.0)), float(entry.get("combat_risk", 0.0)))
			kb[merged_id]["visits"] = maxf(float(kb[merged_id].get("visits", 0)), float(entry.get("visits", 0)))
			moved += 1
	return moved

func _share_enemy_knowledge(mem_from: Dictionary, mem_to: Dictionary, to_key: String, from_key: String) -> void:
	var killers_from: Dictionary = mem_from.get("killers", {})
	var killers_to: Dictionary = mem_to.get("killers", {})
	for k in killers_from.keys():
		if str(k) == to_key or str(k) == from_key:
			continue
		var src: Dictionary = killers_from[k]
		var dst: Dictionary = killers_to.get(k, {"name": "", "count": 0})
		dst["name"] = str(src.get("name", dst.get("name", "")))
		dst["count"] = maxi(int(dst.get("count", 0)), int(src.get("count", 0)))
		killers_to[k] = dst
	mem_to["killers"] = killers_to
	var rels_from: Dictionary = mem_from.get("relationships", {})
	var rels_to: Dictionary = mem_to.get("relationships", {})
	var warns: Array = []
	for k2 in rels_from.keys():
		# Solo advertencias de TERCEROS: ni uno mismo ni el interlocutor —
		# "temo a bot_903" no se le cuenta a bot_903 como rumor.
		if str(k2) == to_key or str(k2) == from_key:
			continue
		var rf: Dictionary = rels_from[k2]
		# Solo viaja mala reputacion demostrada (ataco o da miedo/odio real).
		var warn := int(rf.get("attacked", 0)) > 0 or float(rf.get("hostility", 0.0)) >= 0.4 or float(rf.get("fear", 0.0)) >= 0.5
		if not warn:
			continue
		warns.append({"k": k2, "rf": rf, "s": int(rf.get("attacked", 0)) * 10.0 + float(rf.get("hostility", 0.0)) + float(rf.get("fear", 0.0))})
	# Las advertencias tambien salen cuentagotas: SHARE_MAX_RELS por
	# transmision, las mas graves primero.
	warns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) > float(b["s"]))
	for c in warns.slice(0, SHARE_MAX_RELS):
		var k2: String = str(c["k"])
		var rf: Dictionary = c["rf"]
		var rt: Dictionary = rels_to.get(k2, {})
		# El rumor levanta desconfianza sin inventar la agresion: nunca supera
		# la hostilidad que el receptor ya sufrio en carne propia. Y la propia
		# experiencia pesa mas que el chisme: si el receptor confia en ese
		# tercero, la advertencia entra atenuada (un amigo de toda la vida no se
		# convierte en enemigo porque el compañero de equipo lo odie).
		var trust_rt := clampf(float(rt.get("trust", 0.0)), 0.0, 1.0)
		var warn_mul := 0.8 * (1.0 - trust_rt * 0.7)
		rt["hostility"] = snappedf(maxf(float(rt.get("hostility", 0.0)), float(rf.get("hostility", 0.0)) * warn_mul), 0.01)
		rt["fear"] = snappedf(maxf(float(rt.get("fear", 0.0)), float(rf.get("fear", 0.0)) * warn_mul), 0.01)
		rt["heard_about"] = true
		rels_to[k2] = rt
	mem_to["relationships"] = rels_to

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

# Hostilidad inicial de una relacion nueva: el hostil desconfia de los humanos
# (0.65), pero entre bandidos solo hay recelo (0.30) — por encima de la puerta
# de convivencia de _bot_social_update (0.40) ninguna banda llegaria a fraguar.
func _rel_initial_hostility(bot_id: int, actor_key: String) -> float:
	if str((_ensure_bot_memory(bot_id).get("identity", {}) as Dictionary).get("faction", "")) != "hostile":
		return 0.0
	if actor_key.begins_with("bot_"):
		var oid := int(actor_key.get_slice("_", 1))
		if str((_ensure_bot_memory(oid).get("identity", {}) as Dictionary).get("faction", "")) == "hostile":
			return 0.30
	return 0.65

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
		"hostility": _rel_initial_hostility(bot_id, actor_key),
		"fear": 0.0,
		"helped": 0,
		"attacked": 0,
	})
	if not actor_name.is_empty():
		rel["name"] = actor_name
	var step := clampf(intensity, 0.05, 1.0)
	if kind == "ally":
		# Both bots observe the same meeting: credit shared time at most once
		# per interval, without counting it as a gift or rescue.
		var now := Time.get_ticks_msec()
		if rel.has("bond_t") and now - int(rel["bond_t"]) < 20000:
			return
		if rel.has("harm_t") and now - int(rel["harm_t"]) < REL_PEACE_MS:
			return
		rel["bond_t"] = now
		rel["shared_experiences"] = int(rel.get("shared_experiences", 0)) + 1
		step = clampf(intensity, 0.0, 0.05)
	match kind:
		"help", "ally":
			if kind == "help":
				rel["helped"] = int(rel.get("helped", 0)) + 1
			var coop_mul := 0.75 + float(pers.get("cooperation", 0.6)) * 0.6
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) + step * 0.75 * coop_mul, -1.0, 1.0), 0.001)
			var host_decay := step * 0.55
			if bool(rel.get("heard_about", false)) and int(rel.get("attacked", 0)) == 0:
				# La hostilidad de oidas (rumor de un aliado) se desgasta mas
				# rapido que la ganada en carne propia: convivir en paz desmiente
				# el chisme. Cuando queda residual, la marca se limpia.
				host_decay += step * 0.5
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) - host_decay, 0.0, 1.0), 0.001)
			if float(rel.get("hostility", 0.0)) <= 0.05 and int(rel.get("attacked", 0)) == 0:
				rel.erase("heard_about")
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
			rel["harm_t"] = Time.get_ticks_msec()
			rel["scar_t"] = Time.get_ticks_msec()
			if not b.is_empty():
				_evolve_personality(b, "player_attacked", step)
				if Time.get_ticks_msec() - int(_ai_last_call_msec.get(bot_id, -999999)) > 120000:
					_ai_enqueue_request(bot_id, 5, "attacked_by_" + actor_key, true)
		"refused":
			# Le nego ayuda que el bot pedia de verdad: confianza abajo, rencor
			# arriba. El contador alimenta la reevaluacion (negociar/robar/
			# atacar/forrajear) y la expulsion del equipo por negarse a ayudar.
			# Es daño social: harm_t sella el momento para que convivir despues
			# no siga sumando vinculo (credito "ally" en pausa) ni el olvido
			# enfrie el agravio recien hecho.
			rel["refused"] = int(rel.get("refused", 0)) + 1
			rel["harm_t"] = Time.get_ticks_msec()
			var dist_mul2 := 0.8 + float(pers.get("distrust", 0.4)) * 0.6
			rel["trust"] = snappedf(clampf(float(rel.get("trust", 0.0)) - step * 0.55 * dist_mul2, -1.0, 1.0), 0.001)
			rel["hostility"] = snappedf(clampf(float(rel.get("hostility", 0.0)) + step * 0.55, 0.0, 1.0), 0.001)
			# Y quien niega (o elude) la ayuda tambien cambia: cada negativa
			# erosiona su sociabilidad — a la larga se queda solo.
			if actor_key.begins_with("bot_"):
				var rid := int(actor_key.get_slice("_", 1))
				if bots.has(rid):
					_evolve_personality(bots[rid], "refused_help", step)
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
func record_zone_hazard(bot_id: int, pos: Vector3, kind: String, severity: float = 0.3, survivor_combat: bool = false) -> void:
	var mem := _ensure_bot_memory(bot_id)
	var known: Dictionary = mem["known_locations"]
	var best_id := ""
	var best_d := 65.0
	var anchor := pos
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		if d < best_d:
			best_d = d
			best_id = _poi_id(p)
			kind = str(p.get("kind", kind))
			anchor = pp
	if best_id.is_empty():
		best_id = "%s:%d:%d" % [kind if not kind.is_empty() else "wild", int(pos.x), int(pos.z)]
	# observe_location puede fusionar el aviso con una zona cercana: actualizar
	# su ID real, no crear una segunda entrada sin coordenadas. Un POI conserva
	# su posición canónica aunque la agresión ocurriera junto al edificio.
	best_id = observe_location(bot_id, best_id, kind if not kind.is_empty() else "wild", anchor, "observed")
	var loc: Dictionary = known.get(best_id, {})
	loc["risk"] = snappedf(clampf(float(loc.get("risk", 0.0)) + clampf(severity, 0.05, 1.0), 0.0, 3.0), 0.01)
	if survivor_combat:
		loc["combat_risk"] = snappedf(clampf(float(loc.get("combat_risk", 0.0)) + clampf(severity, 0.05, 1.0), 0.0, 3.0), 0.01)
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

# Una lección indica qué conviene intentar en la próxima vida; no demuestra
# que esa acción haya funcionado. Mantenerla fuera de los éxitos que estima EU.
func _migrate_strategy_evidence(mem: Dictionary) -> void:
	if int(mem.get("strategy_evidence_v", 0)) >= 1:
		return
	# La versión anterior sumaba un éxito ficticio por cada una de estas
	# lecciones. Sus contadores permiten retirarlo sin borrar éxitos reales,
	# preferencias, relaciones ni adaptaciones. Migrar una sola vez.
	var dl: Dictionary = mem.get("death_lessons", {})
	var inferred := {
		"forage": int(dl.get("dehydrated", 0)) + int(dl.get("starved", 0)),
		"hunt": int(dl.get("starved", 0)),
		"fortify_camp": int(dl.get("predator", 0)) + int(dl.get("cold", 0)) + int(dl.get("medical", 0)) + int(dl.get("ranged", 0)),
		"avoid_zone": int(dl.get("ranged", 0)),
		"explore_military": int(dl.get("combat", 0)),
	}
	var strats: Dictionary = mem.get("strategies", {})
	for strategy in inferred:
		if not (strats.get(strategy) is Dictionary):
			continue
		var st: Dictionary = strats[strategy]
		var old_credit := mini(maxi(0, int(inferred[strategy])), maxi(0, int(st.get("success", 0))))
		st["success"] = maxi(0, int(st.get("success", 0)) - old_credit)
		st["lessons"] = int(st.get("lessons", 0)) + old_credit
	mem["strategy_evidence_v"] = 1

func _reinforce_survival_strategy(bot_id: int, strategy: String, weight_delta: float) -> void:
	var mem := _ensure_bot_memory(bot_id)
	var strats: Dictionary = mem["strategies"]
	var st: Dictionary = strats.get(strategy, {"success": 0, "fail": 0, "preference": 1.0})
	st["lessons"] = int(st.get("lessons", 0)) + 1
	st["preference"] = snappedf(clampf(float(st.get("preference", 1.0)) + clampf(weight_delta, 0.03, 0.5), 0.15, 2.0), 0.01)
	strats[strategy] = st

func record_strategy_outcome(bot_id: int, strategy: String, success: bool, weight_delta: float = 0.12, cause: String = "") -> void:
	if strategy.is_empty():
		return
	var mem := _ensure_bot_memory(bot_id)
	var strats: Dictionary = mem["strategies"]
	var st: Dictionary = strats.get(strategy, {"success": 0, "fail": 0, "preference": 1.0})
	var step := clampf(weight_delta, 0.03, 0.5)
	if success:
		st["success"] = int(st.get("success", 0)) + 1
		st["preference"] = snappedf(clampf(float(st.get("preference", 1.0)) + step, 0.15, 2.0), 0.01)
		st.erase("last_fail")
	else:
		st["fail"] = int(st.get("fail", 0)) + 1
		st["preference"] = snappedf(clampf(float(st.get("preference", 1.0)) - step * 1.25, 0.15, 2.0), 0.01)
		# Por que fallo: nav_blocked / precondition / stuck_timeout — asi el bot
		# distingue "me falto recurso" de "no hay ruta" de "el plan era imposible".
		if not cause.is_empty():
			st["last_fail"] = cause
	st["last"] = int(Time.get_unix_time_from_system())
	strats[strategy] = st
	mem["strategies"] = strats

# Resultado GLOBAL del plan, en namespace propio ("plan:<raiz>"): un plan de
# tres pasos registra tres resultados de accion + UN resultado de plan — la
# raiz no recibe un segundo exito de accion por completar el conjunto.
func record_plan_outcome(bot_id: int, plan_root: String, success: bool, weight_delta: float = 0.08, cause: String = "") -> void:
	if plan_root.is_empty():
		return
	record_strategy_outcome(bot_id, "plan:" + plan_root, success, weight_delta, cause)

# Contadores de diagnostico por bot (monitor: que decide Qwen y que Godot, cuantos
# planes se cumplen/fallan, latencias de la IA remota, razones de fallback).
func _ai_stat_inc(b: Dictionary, key: String, n: int = 1) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return
	var st: Dictionary = mem.get("ai_stats", {})
	st[key] = int(st.get(key, 0)) + n
	mem["ai_stats"] = st

func _ai_stat_set(b: Dictionary, key: String, v: Variant) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return
	var st: Dictionary = mem.get("ai_stats", {})
	st[key] = v
	mem["ai_stats"] = st

func _ai_stat_reason(b: Dictionary, reason: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty():
		return
	var st: Dictionary = mem.get("ai_stats", {})
	var fr: Dictionary = st.get("fallback_reasons", {})
	var key := reason.substr(0, 40)
	fr[key] = int(fr.get(key, 0)) + 1
	st["fallback_reasons"] = fr
	mem["ai_stats"] = st

# Motor conductual local diferenciado por personalidad, memoria y relaciones:
# ante una situación idéntica, Elena (supervivencia/curiosidad), Carlos
# (valentía/cooperación/fortificación) y Kael (agresividad/desconfianza/saqueo)
# producen decisiones distintas y sirven también como fallback cuando Groq no está.
# Incursion de equipo autonoma ("equip_mission" sin jugador): el bot sin un
# arma decente — fusil con municion, arco con flechas o acero de verdad
# (Hacha, Cuchillo; los palos afilados y el hueso/piedra tallados no
# cuentan) — que ya conoce una base militar (o, en su defecto, la ciudad)
# monta su propia expedicion a por equipo. Devuelve el kind a saquear o "".
func _bot_gear_raid_kind(b: Dictionary) -> String:
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return ""
	if not GoalValidator.decent_weapon(self, proxy).is_empty():
		return ""
	var known: Dictionary = (b.get("_mem", {}) as Dictionary).get("known_locations", {})
	for kid in known.keys():
		var k = known[kid]
		if k is Dictionary and str(k.get("kind", "")) == "military":
			return "military"
	for kid in known.keys():
		var k = known[kid]
		if k is Dictionary and str(k.get("kind", "")) == "city":
			return "city"
	return ""

func decide_situational_action(b: Dictionary, situation: Dictionary = {}) -> Dictionary:
	var use_eu := BOT_UTILITY_ENGINE and str(situation.get("engine", "")) != "legacy"
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

	# Incursion de equipo autonoma: sin arma decente y con una base militar
	# (o la ciudad) conocida, ir a por equipo manda sobre la rutina. La
	# directiva queda fijada a su POI: en ruta el bot sigue comiendo,
	# bebiendo, forrajeando o sembrando si se queda sin recursos — las
	# necesidades son actos del tick, el plan no se rompe por ellas.
	var raid_kind := _bot_gear_raid_kind(b)
	if raid_kind != "" and not threat_present and hunger >= 45.0 and thirst >= 40.0 and hp >= 40.0:
		var raid_spec := {"action": "scavenge", "target": raid_kind, "goal": "gear_up_at_military_base"}
		if not _ai_goal_recently_failed(b, raid_spec):
			return {"action": "scavenge", "target": raid_kind, "poi_kind": raid_kind,
				"goal": "gear_up_at_military_base", "priority": 4, "reason": "gear_raid:unarmed"}

	# Beneficios brutos (sin preference): el modo legacy los multiplica por la
	# preferencia aprendida; el modo EU los multiplica por P(éxito) beta-binomial
	# — nunca los dos a la vez, seria doble penalizacion del mismo aprendizaje.
	var proxy_d: Node3D = b.get("proxy")
	var forage_base := need_food * 1.35 + need_water * 0.4 + survival * 1.15 + curiosity * 0.55 - bravery * 0.25 - aggression * 0.35
	if need_food <= 0.01 and need_water <= 0.01 and proxy_d != null and is_instance_valid(proxy_d) and _bot_has_edible_food(proxy_d, false):
		forage_base *= 0.45
	var benefits := {
		"forage": forage_base,
		"hunt": need_food * 1.25 + bravery * 0.55 + aggression * 0.45 - distrust * 0.25,
		"fortify_camp": (0.45 if not has_shelter else 0.15) + bravery * 1.05 + cooperation * 0.85 - curiosity * 0.55 - aggression * 0.35,
		"scavenge": aggression * 1.25 + distrust * 1.05 + bravery * 0.40 - cooperation * 0.55,
		"explore": curiosity * 1.10 + sociability * 0.35 - need_heal * 0.6 - distrust * 0.25,
		"rest": need_heal * 1.55 + survival * 0.70 - bravery * 0.35,
		# El cooperativo busca compañia incluso en paz; y quien ya trabajo con
		# otro bot (vinculo previo) lo busca activamente para reagruparse.
		"seek_ally": (sociability * 0.95 + cooperation * 0.95 - distrust * 0.85 - aggression * 0.50) * (1.15 if threat_present else 0.75 + cooperation * 0.35),
	}
	var scores := {}
	if use_eu:
		scores = _eu_scores(b, pers, benefits, threat_present)
	else:
		for act in benefits.keys():
			scores[act] = float(benefits[act]) * float((strats.get(act, {}) as Dictionary).get("preference", 1.0))
	var bond_bonus := 0.0
	for rk in (mem.get("relationships", {}) as Dictionary).keys():
		var rv: Dictionary = mem["relationships"][rk]
		if str(rk).begins_with("bot_") and (float(rv.get("trust", 0.0)) >= BOT_TEAM_FORM_TRUST or int(rv.get("helped", 0)) >= 2):
			bond_bonus = 0.35
			break
	if scores.has("seek_ally"):
		scores["seek_ally"] = float(scores["seek_ally"]) + bond_bonus
	if scores.has("rest") and threat_present and hp < 55.0 and survival > bravery:
		scores["rest"] = float(scores["rest"]) + 0.9
	if not risky_zone.is_empty():
		if use_eu:
			var aversion := BotUtilityAI.risk_aversion(pers)
			scores["avoid_zone"] = BotUtilityAI.expected_utility(
				survival * 1.1 + distrust * 0.5 + need_heal * 0.6,
				BotUtilityAI.strat_prob(strats.get("avoid_zone", {})), 0.30, 0.05, aversion)
		else:
			scores["avoid_zone"] = survival * 1.1 + distrust * 0.5 + need_heal * 0.6

	# El cerebro local también aprende de planes imposibles: cada fallo
	# reciente de una acción (stuck_timeout, nav_blocked, plan_broken — no
	# "precondition", que solo registra un requisito perdido ya resuelto por
	# el parse) multiplica su score por 0.4 — con tres fracasos queda casi
	# vetada y el bot propone otra cosa en vez de encadenar el mismo plan.
	var now_u := Time.get_unix_time_from_system()
	var fail_n := {}
	for k in ([] if use_eu else (mem.get("failed_goals", {}) as Dictionary).keys()):
		var e: Dictionary = (mem["failed_goals"] as Dictionary)[k]
		if not (e is Dictionary):
			continue
		if now_u - float(e.get("t", 0.0)) >= _ai_fail_entry_ttl(e):
			continue
		if str(e.get("cause", "")) == "precondition":
			continue
		var fact := str(e.get("act", "")).split(":")[0]
		fail_n[fact] = int(fail_n.get(fact, 0)) + 1
	for act in fail_n.keys():
		if scores.has(act):
			scores[act] = float(scores[act]) * pow(0.4, float(fail_n[act]))

	var best_act := "explore"
	var best_sc := -999.0
	var has_unvetoed := false
	for act in scores.keys():
		if not _ai_goal_recently_failed(b, _situational_action_spec(str(act), aggression, survival, bravery, risky_zone)):
			has_unvetoed = true
			break
	for act in scores.keys():
		if has_unvetoed and _ai_goal_recently_failed(b, _situational_action_spec(str(act), aggression, survival, bravery, risky_zone)):
			continue
		var sc := float(scores[act])
		if sc > best_sc:
			best_sc = sc
			best_act = str(act)

	var spec := _situational_action_spec(best_act, aggression, survival, bravery, risky_zone)
	var target := str(spec["target"])
	var goal := str(spec["goal"])
	var prio := clampi(int(round(best_sc * 2.0)), 1, 5)
	var reason := "personality:%s(%.2f)" % [best_act, best_sc]
	if use_eu:
		var det: Dictionary = (b.get("_utility_last", {}) as Dictionary).get(best_act, {})
		# La prioridad mide la urgencia del beneficio ganador (misma escala que
		# el score legacy), no U — U ya descuenta el riesgo segun personalidad
		# y bajaria la prioridad de decisiones urgentes en bots prudentes.
		prio = clampi(int(round(float(det.get("b", 0.5)) * 2.0)), 1, 5)
		reason = "eu:%s B%.2f p%.2f c%.2f r%.2f U%.2f" % [best_act,
			float(det.get("b", 0.0)), float(det.get("p", 0.0)),
			float(det.get("c", 0.0)), float(det.get("r", 0.0)), best_sc]

	return {
		"goal": goal,
		"action": best_act,
		"target": target,
		"poi_kind": target if AI_POI_KINDS.has(target) else "",
		"priority": prio,
		"reason": reason,
	}

func _situational_action_spec(act: String, aggression: float, survival: float, bravery: float, risky_zone: String) -> Dictionary:
	match act:
		"forage":
			return {"action": "forage", "target": "wild", "goal": "secure_food_safely", "mode": "food"}
		"hunt":
			return {"action": "hunt", "target": "wild", "goal": "hunt_prey_for_meat_and_pelts", "mode": "poi", "only_kinds": ["wild"]}
		"fortify_camp":
			return {"action": "fortify_camp", "target": "camp", "goal": "build_and_defend_camp", "mode": "pos"}
		"scavenge":
			var tk := "military" if aggression >= 0.6 else "house"
			return {"action": "scavenge", "target": tk, "goal": "dominate_high_tier_loot", "mode": "poi", "only_kinds": [tk]}
		"rest":
			return {"action": "rest", "target": "camp", "goal": "recover_health_in_refuge", "mode": "pos"}
		"seek_ally":
			return {"action": "seek_ally", "target": "ally", "goal": "regroup_with_trusted_ally", "mode": "ally"}
		"avoid_zone":
			var az := risky_zone if AI_POI_KINDS.has(risky_zone) else "city"
			return {"action": "avoid_zone", "target": az, "goal": "evade_known_danger_zone", "mode": "avoid", "avoid_kinds": [az]}
		_:
			var ek := "house" if survival >= bravery else "city"
			return {"action": "explore", "target": ek, "goal": "explore_new_locations", "mode": "poi", "only_kinds": [ek]}

# Motor de utilidad esperada local (BotUtilityAI.gd): U = p×beneficio − coste
# − aversión×riesgo. Corre solo en los ciclos de decisión — nunca por tick —
# y deja en b["_utility_last"] el desglose por acción para diagnóstico.
func _eu_scores(b: Dictionary, pers: Dictionary, benefits: Dictionary, threat_present: bool) -> Dictionary:
	var mem: Dictionary = b.get("_mem", {})
	var strats: Dictionary = mem.get("strategies", {})
	var aversion := BotUtilityAI.risk_aversion(pers)
	var energy := float(b.get("energy", 80.0))
	# Amenaza estimada con evidencias legítimas: ultima posicion conocida del
	# enemigo (decae con el tiempo) + antecedentes de la zona (combate y fauna).
	var zr := _eu_zone_risks(b)
	var threat_p := BotUtilityAI.threat_posterior(b.get("_foe_mem", {}), Time.get_ticks_msec(),
		float(zr.get("combat", 0.0)), float(zr.get("env", 0.0)))
	# Perfil de caza segun el arma REAL utilizable (los secos no cuentan): sin
	# municion ni arco cazar es casi siempre perdida — baja p, sube riesgo.
	var hunt_prof := {"p": 0.35, "risk": 0.45}
	var proxy: Node3D = b.get("proxy")
	if proxy != null and is_instance_valid(proxy):
		var pick := _pick_fight_weapon(b, 16.0)
		var kind := str(pick.get("kind", "melee"))
		# thrown/bola: armas arrojadizas de caza — perfil de arco (alcance, no fuego)
		hunt_prof = BotUtilityAI.hunt_weapon_profile("bow" if kind in ["bow", "thrown", "bola"] else kind)
	# Coste = esfuerzo base + desplazamiento real estimado al destino de cada
	# accion (POIs conocidos, hogar, aliado), encarecido si el cuerpo no puede
	# o la mochila va vacia — un destino lejano sin provisiones no se paga.
	var hunger := float(b.get("hunger", 90.0))
	var thirst := float(b.get("thirst", 90.0))
	var has_sup := proxy != null and is_instance_valid(proxy) \
		and (_bot_has_drink(proxy) or _bot_has_edible_food(proxy, false))
	var ally_pos := _nearest_friendly_bot_pos(int(b.get("bot_id", 0)))
	var home: Vector3 = b.get("shelter_pos", Vector3.INF)
	if home == Vector3.INF:
		home = b.get("camp_spot", Vector3.INF)
	var kd := _eu_kind_dists(b)
	var act_dist := {
		"forage": float(kd.get("wild", 60.0)),
		"hunt": float(kd.get("wild", 80.0)) + 30.0,
		"fortify_camp": _eu_home_dist(proxy, home),
		"scavenge": minf(float(kd.get("military", 1e9)), minf(float(kd.get("city", 1e9)), float(kd.get("house", 1e9)))) if kd.has("military") or kd.has("city") or kd.has("house") else 120.0,
		"explore": float(kd.get("_unvisited", 150.0)),
		"rest": _eu_home_dist(proxy, home),
		"seek_ally": (proxy as Node3D).global_position.distance_to(ally_pos) if ally_pos != Vector3.INF and proxy != null and is_instance_valid(proxy) else 0.0,
	}
	var act_effort := {"forage": 0.10, "hunt": 0.15, "fortify_camp": 0.15, "scavenge": 0.10,
		"explore": 0.10, "rest": 0.05, "seek_ally": 0.10}
	var act_risk := {"forage": 0.12 + threat_p * 0.20, "hunt": float(hunt_prof["risk"]),
		"fortify_camp": 0.05, "scavenge": 0.30 + threat_p * 0.30,
		"explore": 0.20 + threat_p * 0.35, "rest": 0.35 if threat_present else 0.05,
		"seek_ally": 0.12 + threat_p * 0.15}
	# Los fracasos recientes de objetivo (nav_blocked/stuck — no precondition)
	# entran como fracasos extra en la beta de ESA accion: misma estimacion,
	# mas evidencia — nunca un segundo multiplicador como en el legacy.
	var now_u := Time.get_unix_time_from_system()
	var fail_n := {}
	for k in (mem.get("failed_goals", {}) as Dictionary).keys():
		var e: Dictionary = (mem["failed_goals"] as Dictionary)[k]
		if not (e is Dictionary):
			continue
		if now_u - float(e.get("t", 0.0)) >= _ai_fail_entry_ttl(e):
			continue
		if str(e.get("cause", "")) == "precondition":
			continue
		var fact := str(e.get("act", "")).split(":")[0]
		fail_n[fact] = int(fail_n.get(fact, 0)) + 1
	# Requisitos antes de la utilidad: una accion sin destino ejecutable no
	# compite. Descansar/fortificar necesita refugio o campamento; buscar
	# aliado necesita un aliado real al que ir — la directiva iria a ninguna
	# parte y el rescate la convertiria en explore de todos modos.
	var has_home: bool = home != Vector3.INF
	var has_ally: bool = ally_pos != Vector3.INF
	var scores := {}
	var detail := {}
	for act in benefits.keys():
		if act in ["rest", "fortify_camp"] and not has_home:
			continue
		if act == "seek_ally" and not has_ally:
			continue
		var st: Dictionary = strats.get(act, {})
		var p := BotUtilityAI.success_prob(int(st.get("success", 0)),
			int(st.get("fail", 0)) + int(fail_n.get(act, 0)))
		if act == "hunt":
			p = minf(p, float(hunt_prof["p"]))
		var c := float(act_effort.get(act, 0.10)) + BotUtilityAI.travel_cost(
			float(act_dist.get(act, 80.0)), energy, hunger, thirst, has_sup)
		var r := float(act_risk.get(act, 0.1))
		var u := BotUtilityAI.expected_utility(float(benefits[act]), p, c, r, aversion)
		scores[act] = u
		detail[act] = {"b": snappedf(float(benefits[act]), 0.01), "p": snappedf(p, 0.01),
			"c": snappedf(c, 0.01), "r": snappedf(r, 0.01), "u": snappedf(u, 0.01)}
	b["_utility_last"] = detail
	return scores

# Antecedentes en la zona actual del bot (known_locations): combate contra
# supervivientes + riesgo ambiental (depredadores/terreno) — priors del
# posterior de amenaza. Memoria propia, no omnisciencia.
func _eu_zone_risks(b: Dictionary) -> Dictionary:
	var out := {"combat": 0.0, "env": 0.0}
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return out
	var mem: Dictionary = b.get("_mem", {})
	var known: Dictionary = mem.get("known_locations", {})
	var pos := proxy.global_position
	var best_d := 65.0
	for pid in known.keys():
		var loc: Dictionary = known[pid]
		if not (loc is Dictionary):
			continue
		var lp = loc.get("pos")
		if not (lp is Array) or (lp as Array).size() < 3:
			continue
		var d := Vector2(float((lp as Array)[0]) - pos.x, float((lp as Array)[2]) - pos.z).length()
		if d < best_d:
			best_d = d
			out["combat"] = float(loc.get("combat_risk", 0.0))
			out["env"] = float(loc.get("risk", 0.0))
	return out

# Distancia al hogar del bot (refugio o campamento) para costear descansar/
# fortificar: 0 si esta ahi, INF si no tiene — la mascara lo filtra antes.
func _eu_home_dist(proxy: Node3D, home: Vector3) -> float:
	if home == Vector3.INF or proxy == null or not is_instance_valid(proxy):
		return 0.0
	return (proxy as Node3D).global_position.distance_to(home)

# Una pasada sobre los POIs: distancia minima por tipo y al no-visitado mas
# cercano — estimaciones de desplazamiento por accion para travel_cost.
func _eu_kind_dists(b: Dictionary) -> Dictionary:
	var proxy: Node3D = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return {}
	var pos := proxy.global_position
	var visited: Array = (b.get("_mem", {}) as Dictionary).get("visited", [])
	var out := {}
	for p in _explore_pois():
		var pp: Vector3 = p["pos"]
		var d := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		var kind := str(p.get("kind", "wild"))
		if d < float(out.get(kind, 1e9)):
			out[kind] = d
		if not visited.has(_poi_id(p)) and d < float(out.get("_unvisited", 1e9)):
			out["_unvisited"] = d
	return out

# Autoridad exclusiva del servidor: un cliente conectado jamás consulta Groq.
func _ai_can_query_remote() -> bool:
	if world == null:
		return true
	var net = world.get("net")
	if net != null and net.is_connected and not net.is_host:
		return false
	return true

# force=true es para sucesos relevantes (ataque, plan terminado/bloqueado,
# plan atascado): salta el hueco mínimo entre llamadas y la deduplicacion por
# firma. Las revisiones periodicas y los cambios de firma van sin forzar.
# De noche el asesor remoto descansa: los bots duermen o aguantan junto al
# fuego y la firma apenas cambia — quemar cuota de API en revisiones y
# replanteamientos no mejora ninguna decision. Lo unico que la justifica es
# un ataque real; todo lo demas lo cubre el motor local hasta el alba (los
# motivos periodicos/sig_change se reencolan solos al amanecer).
func _ai_night_allows_remote(reason: String) -> bool:
	if not _is_world_night():
		return true
	return reason.begins_with("attacked_by_")

func _ai_enqueue_request(bot_id: int, priority: int = 3, reason: String = "periodic", force: bool = false) -> void:
	if bots.has(bot_id):
		var b: Dictionary = bots[bot_id]
		PlanManager.sync(self, b, Time.get_ticks_msec())
		if bool(b.get("sleeping", false)) or str(b.get("ai_directive", {}).get("state", "")) == "SUSPENDED":
			# Reactive actions do not require a new strategic API request.
			PlanDiagnostics.metric(b, "suspended_queries_skipped")
			if _is_world_night():
				_ai_stat_inc(b, "night_skipped")
			return
	if not _ai_night_allows_remote(reason):
		if bots.has(bot_id):
			_ai_stat_inc(bots[bot_id], "night_skipped")
		return
	var p := clampi(priority, 1, 5)
	var merged := false
	for item in _ai_queue:
		if int((item as Dictionary).get("bot_id", 0)) == bot_id:
			if p > int((item as Dictionary).get("priority", 1)):
				item["priority"] = p
				item["reason"] = reason
			item["force"] = bool(item.get("force", false)) or force
			merged = true
			break
	if not merged:
		_ai_queue.append({"bot_id": bot_id, "priority": p, "reason": reason, "t": Time.get_ticks_msec(), "force": force})
	_ai_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 1)) != int(b.get("priority", 1)):
			return int(a.get("priority", 1)) > int(b.get("priority", 1))
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)

func _ai_pop_next_request(now: int) -> Dictionary:
	# while, no for: remove_at acorta la cola y un range() fijado al inicio
	# desbordaria el indice.
	var i := 0
	while i < _ai_queue.size():
		var item: Dictionary = _ai_queue[i]
		var bid := int(item.get("bot_id", 0))
		if not bots.has(bid) or not _ai_bot_eligible(bots[bid]):
			_ai_queue.remove_at(i)
			continue
		# Encolado antes del anochecer: de noche solo sale lo de ataque real.
		if not _ai_night_allows_remote(str(item.get("reason", ""))):
			_ai_queue.remove_at(i)
			continue
		var forced := bool(item.get("force", false))
		# Ritmo global: ni los sucesos forzados pueden encadenar llamadas que
		# revienten el TPM del modelo — el forzado solo acorta el suelo.
		var glob_gap := int((AI_FORCE_GLOBAL_GAP_SEC if forced else AI_GLOBAL_MIN_CALL_GAP_SEC) * 1000.0)
		if _ai_last_any_call_msec > 0 and now - _ai_last_any_call_msec < glob_gap:
			i += 1
			continue
		if not forced:
			var last_call := int(_ai_last_call_msec.get(bid, 0))
			if last_call > 0 and now - last_call < int(AI_MIN_CALL_GAP_SEC * 1000.0):
				i += 1 # cambio reciente: espera al hueco mínimo por bot
				continue
		_ai_queue.remove_at(i)
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
	# 1 lo ve/oye ahora; 2 sabe donde se esfumo o le avisaron (amenaza oculta
	# reciente que exige decision); 0 nada.
	var threat := 0
	if _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null:
		threat = 1
	elif b.get("aggro_target") != null or int(b.get("_lost_foe_until_msec", 0)) > Time.get_ticks_msec():
		threat = 2
	var zone := _poi_kind_near(pos)
	# Municion util por bandas: 0 seca, 1 escasa (<15), 2 suficiente.
	var ammo_n := 0
	if proxy != null and is_instance_valid(proxy):
		var am: Dictionary = _bot_gun_ammo(proxy)
		ammo_n = int(am.get("m4_magazine", 0)) + int(am.get("m4_reserve", 0)) + int(am.get("magazine", 0)) + int(am.get("reserve", 0))
		for it in proxy.get_meta("saved_inventory", []):
			if it is Dictionary and str((it as Dictionary).get("type", "")).begins_with("ammo"):
				ammo_n += int((it as Dictionary).get("quantity", 1))
	var ammo_band := 0 if ammo_n <= 0 else (1 if ammo_n < 15 else 2)
	# Aliados vivos de su faccion (perder o ganar compania cambia el panorama).
	var my_faction := str(b.get("faction", ""))
	var allies := 0
	for oid in bots.keys():
		if int(oid) == int(b.get("bot_id", 0)):
			continue
		var ob: Dictionary = bots[oid]
		if str(ob.get("faction", "")) != my_faction:
			continue
		var op = ob.get("proxy")
		if op != null and is_instance_valid(op) and not bool(op.get_meta("proxy_dead", false)):
			allies += 1
	var allies_band := mini(allies, 2)
	# Objetivo bloqueado recientemente (lista negra de inalcanzables fresca).
	var now_s := float(Time.get_ticks_msec()) / 1000.0
	var blocked := 0
	for entry in (b.get("_unreachable", []) as Array):
		if entry is Dictionary and float((entry as Dictionary).get("until", 0.0)) > now_s:
			blocked = 1
			break
	# Recursos vitales agotados: necesidad sin provision en el inventario.
	var vital := 0
	if proxy != null and is_instance_valid(proxy):
		var starving_b := float(b.get("hunger", 100.0)) < 45.0 and not _bot_has_edible_food(proxy, false)
		var parched_b := float(b.get("thirst", 100.0)) < 40.0 and not _bot_has_drink(proxy)
		vital = 1 if (starving_b or parched_b) else 0
	# Inventario significativo por bandas de cantidad de pilas.
	var inv_band := 0
	if proxy != null and is_instance_valid(proxy):
		var n_items: int = (proxy.get_meta("saved_inventory", []) as Array).size()
		inv_band = 0 if n_items <= 0 else (1 if n_items <= 4 else (2 if n_items <= 12 else 3))
	return "%d|%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d" % [hp_band, h_band, t_band, threat, 1 if _is_world_night() else 0, str(b.get("held_item", "")), zone, ammo_band, allies_band, blocked, vital, inv_band]

func _ai_review_local_goal(bot_id: int, now: int) -> void:
	if not bots.has(bot_id) or now < int(_ai_next_at.get(bot_id, 0)):
		return
	_ai_next_at[bot_id] = now + 10000
	var b: Dictionary = bots[bot_id]
	PlanManager.sync(self, b, now)
	if str(b.get("ai_directive", {}).get("state", "")) == "SUSPENDED":
		return
	if not _ai_bot_eligible(b):
		return
	var d := _ai_active_directive(b)
	var reason := ""
	if d.is_empty():
		reason = "no_api_key"
	elif _ai_directive_completed(b, d):
		if _ai_advance_plan(bot_id, b, d):
			return
		reason = "local_plan_done"
	else:
		var stall := _ai_step_stalled(b, d, now)
		if not stall.is_empty():
			_ai_fail_stalled_step(bot_id, b, d, stall)
			return
		if now > int(d.get("until", 0)) + int(AI_PLAN_STALE_GRACE_SEC * 1000.0):
			reason = "local_plan_stuck"
	if not reason.is_empty():
		_ai_apply_local_fallback_decision(bot_id, reason)

func _ai_ensure_http() -> void:
	if _ai_http != null and is_instance_valid(_ai_http):
		return
	_ai_http = HTTPRequest.new()
	_ai_http.timeout = 12.0
	_ai_http.request_completed.connect(_ai_on_response)
	add_child(_ai_http)

func _ai_tick(delta: float) -> void:
	if bots.is_empty() or not _ai_can_query_remote():
		return
	var now := Time.get_ticks_msec()
	# Cadena de proveedores: Groq primario gana siempre que este usable (con
	# key, sin veto diario y fuera de SU backoff); el relevo cubre sus ventanas
	# y el primario vuelve al liberarse — el 429 de un pozo no silencia al otro.
	if _ai_provider_usable(0, now):
		_ai_provider = 0
	elif _ai_provider_usable(1, now):
		_ai_provider = 1
	elif _ai_provider_has_key(0):
		_ai_provider = 0
	elif _ai_provider_has_key(1):
		_ai_provider = 1
	var key := _ai_provider_key()
	if key.is_empty():
		_ai_conn_status = "no_api_key (local_brain)"
		# Review local objectives at bounded intervals, including completed/stuck
		# directives. Offline operation must not pin a goal forever.
		for bid in bots.keys():
			_ai_review_local_goal(int(bid), now)
		return
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	if day != _ai_day_key:
		_ai_day_key = day
		_ai_calls_day = 0
		_ai_tokens_day = 0
		_ai_calls_day_by_model.clear()
		_ai_tokens_day_by_model.clear()
		# La cuota se resetea cada dia: reintenta el modelo y proveedor primarios.
		_ai_model_override = ["", ""]
		_ai_provider = 0
		_ai_429_streak = 0
		_ai_provider_day_done = [false, false]
		_ai_provider_day_probe_at = [0, 0]
		_ai_provider_blocked_until = [0, 0]
		_ai_provider_backoff_sec = [4.0, 4.0]
	# Sondeo local y barato por turnos (~AI_SIG_POLL_SEC por bot): cambios de
	# firma, planes terminados/atascados y la revision maxima de cortesia solo
	# ENCOLAN — la dedup por firma y el hueco minimo filtran al despachar.
	_ai_sig_accum += delta
	if _ai_sig_accum >= AI_SIG_POLL_SEC:
		_ai_sig_accum = 0.0
		_ai_sig_poll(now)
	if now < _ai_backoff_until_msec:
		return
	# El proveedor elegido debe poder servir ya: si los dos pozos estan en
	# enfriamiento por minuto o vetados por cuota diaria queda el cerebro
	# local con su revision de objetivos, igual que en modo sin key; el
	# primario vuelve a ganar en cuanto se abre cualquier ventana.
	if not _ai_provider_usable(_ai_provider, now):
		_ai_conn_status = "providers_daily_exhausted (local_brain)" if (bool(_ai_provider_day_done[0]) and bool(_ai_provider_day_done[1])) else "providers_cooling (local_brain)"
		for bid in bots.keys():
			_ai_review_local_goal(int(bid), now)
		return
	# El backoff ya paso: el cartel de rate_limited/pacing se quedaba viejo
	# en el monitor mucho despues de recuperar el servicio — se limpia aqui.
	if _ai_conn_status.begins_with("rate_limited") or _ai_conn_status.begins_with("pacing"):
		_ai_conn_status = "ready (post-backoff)"
	if not _ai_model_quota_open(_ai_active_model()):
		# Presupuesto local del modelo actual agotado: como la cuota real es
		# por modelo, se encadena al siguiente del pozo si le queda — la misma
		# idea que el 429 "per day" pero sin quemar el ultimo token del pozo.
		if _ai_advance_model_chain(_ai_provider):
			_ai_conn_status = "fallback_model (presupuesto -> %s)" % _ai_active_model()
		else:
			# Todos los modelos del proveedor activo sin presupuesto local: veto
			# diario propio hasta el reset y el otro pozo sirve si esta libre.
			_ai_provider_day_done[_ai_provider] = true
			_ai_provider_day_probe_at[_ai_provider] = now + int(AI_PROVIDER_DAY_PROBE_SEC * 1000.0)
			if _ai_provider_usable(1 - _ai_provider, now):
				_ai_switch_provider("presupuesto %s" % _ai_active_model(), 1 - _ai_provider)
			else:
				_ai_conn_status = "quota_reached (local_brain)"
				return
	if _ai_pending_bot != 0:
		return
	_ai_ensure_http()
	var req := _ai_pop_next_request(now)
	if req.is_empty():
		return
	var target_bot := int(req["bot_id"])
	var tb: Dictionary = bots[target_bot]
	var sig := _ai_situation_signature(tb)
	tb["_ai_req_sig"] = sig
	if _ai_try_decision_cache(target_bot, sig, str(req.get("reason", ""))):
		return
	if not bool(req.get("force", false)) and _ai_last_sig.get(target_bot, "") == sig and not _ai_active_directive(tb).is_empty():
		_ai_cache_hits += 1
		_ai_next_at[target_bot] = now + int(AI_REVIEW_MAX_SEC * 1000.0)
		return
	_ai_last_sig[target_bot] = sig
	_ai_request_decision(target_bot, tb)

# Las revalidaciones de planes rotos/ataques jamás pasan por el caché:
# reaplicar la directiva que acaba de atascarse sería el bucle exacto que
# el sondeo rompe pidiendo una decisión fresca al modelo.
func _ai_try_decision_cache(bot_id: int, sig: String, reason: String) -> bool:
	if not reason in ["sig_change", "scheduled", "periodic", "plan_done"]:
		return false
	var ck := str(bot_id) + "|" + sig
	var cent: Dictionary = _ai_decision_cache.get(ck, {})
	if cent.is_empty() or Time.get_ticks_msec() - int(cent.get("t", 0)) >= int(AI_DECISION_CACHE_TTL_SEC * 1000.0):
		return false
	if _ai_apply_decision(bot_id, str(cent.get("content", "")), "qwen_cache"):
		_ai_cache_hits += 1
		if bots.has(bot_id):
			_ai_stat_inc(bots[bot_id], "cache_hits")
		return true
	_ai_decision_cache.erase(ck)
	return false

func _ai_note_decision_cache(bot_id: int, content: String) -> void:
	var lb: Dictionary = bots.get(bot_id, {})
	var req_sig := str(lb.get("_ai_req_sig", ""))
	if req_sig.is_empty():
		return
	_ai_decision_cache[str(bot_id) + "|" + req_sig] = {"t": Time.get_ticks_msec(), "content": content}
	_ai_prune_decision_cache()

# Sondeo por turnos de un bot por ciclo: encola una peticion a la cola
# compartida solo cuando hay motivo — plan cumplido, plan atascado, firma de
# situacion distinta o revision maxima vencida.
func _ai_sig_poll(now: int) -> void:
	var ids: Array = bots.keys()
	ids.sort()
	_ai_rr = (_ai_rr + 1) % ids.size()
	var bot_id: int = ids[_ai_rr]
	var b: Dictionary = bots[bot_id]
	PlanManager.sync(self, b, now)
	if str(b.get("ai_directive", {}).get("state", "")) == "SUSPENDED":
		return
	if not _ai_bot_eligible(b):
		return
	var d := _ai_active_directive(b)
	if not d.is_empty():
		if _ai_directive_completed(b, d):
			if _ai_advance_plan(bot_id, b, d):
				return
			_ai_apply_local_fallback_decision(bot_id, "plan_done")
			_ai_enqueue_request(bot_id, 4, "plan_done", true)
			return
		var stall := _ai_step_stalled(b, d, now)
		if not stall.is_empty():
			_ai_fail_stalled_step(bot_id, b, d, stall)
			return
		if now > int(d.get("until", 0)) + int(AI_PLAN_STALE_GRACE_SEC * 1000.0):
			# El MISMO objetivo que vuelve a atascarse tras revalidar (firma
			# goal|action identica) suma strikes: al segundo se declara
			# imposible — se aprende, se abandona y se decide en local.
			var stuck_key := str(d.get("goal", "")) + "|" + str(d.get("action", ""))
			if str(b.get("_stuck_sig", "")) != stuck_key:
				b["_stuck_sig"] = stuck_key
				b["_stuck_n"] = 0
			b["_stuck_n"] = int(b.get("_stuck_n", 0)) + 1
			if int(b["_stuck_n"]) >= 2:
				b["_stuck_n"] = 0
				b["_stuck_sig"] = ""
				PlanManager.finish(b, d, "FAILED", "stuck_timeout", now)
				PlanDiagnostics.metric(b, "real_blocks")
				PlanDiagnostics.metric(b, "steps_failed")
				b["ai_directive"] = {}
				b["_plan_last_result"] = "plan_impossible"
				record_strategy_outcome(bot_id, str(d.get("action", "")), false, 0.15, "stuck_timeout")
				var root_st := str(d.get("_plan_root", d.get("action", "")))
				record_plan_outcome(bot_id, root_st, false, 0.08, "plan_broken")
				_ai_note_failed_goal(b, d, "stuck_timeout")
				_ensure_bot_memory(bot_id, b.get("cfg", {}))["pending_goals"] = []
				_ai_stat_inc(b, "steps_failed")
				_ai_stat_inc(b, "plans_failed")
				_ai_stat_inc(b, "blocked_recoveries")
				_ai_apply_local_fallback_decision(bot_id, "plan_impossible")
				return
			_ai_enqueue_request(bot_id, 3, "plan_stuck", true)
			return
	elif _ai_situation_signature(b) != str(_ai_last_sig.get(bot_id, "")):
		var urgency := 4 if (float(b["hunger"]) < 45.0 or float(b["health"]) < 60.0) else 3
		_ai_enqueue_request(bot_id, urgency, "sig_change")
	var next_at := int(_ai_next_at.get(bot_id, 0))
	if next_at == 0:
		_ai_next_at[bot_id] = now + (90 + _ai_rr * 150 + randi() % 120) * 1000
	elif now >= next_at:
		_ai_next_at[bot_id] = now + int(AI_REVIEW_MAX_SEC * 1000.0)
		_ai_enqueue_request(bot_id, 2, "scheduled")

# Un plan del asesor termina cuando su objetivo se cumple: llegar al punto,
# visitar el tipo de POI pedido (_visit_done lo marca _mark_poi_visited),
# comer lo suficiente o recuperarse. Mientras no ocurra, la directiva sigue
# viva aunque pase su "until" — el watchdog del sondeo la revalida si se
# atasca, no la borra.
func _ai_directive_completed(b: Dictionary, d: Dictionary) -> bool:
	return PlanManager.completed(self, b, d)

# Destino estimado del paso para presupuestar tiempo y medir progreso real.
func _ai_step_target_pos(b: Dictionary, d: Dictionary) -> Vector3:
	var dp = d.get("pos")
	if dp is Vector3 and (dp as Vector3) != Vector3.INF:
		return dp
	# Destino fijado al adoptar el paso: navegacion, progreso y vetos hablan
	# del mismo lugar — no se recalcula al POI que ahora quede mas cerca.
	var pin = d.get("_dest_pos")
	if pin is Vector3 and (pin as Vector3) != Vector3.INF:
		return pin
	match str(d.get("mode", "")):
		"ally":
			return _nearest_friendly_bot_pos(int(b.get("bot_id", 0)))
		"poi":
			var proxy = b.get("proxy")
			if proxy == null or not is_instance_valid(proxy):
				return Vector3.INF
			var kinds: Array = d.get("only_kinds", [])
			var pos: Vector3 = (proxy as Node3D).global_position
			var best := Vector3.INF
			var best_d := INF
			for p in _explore_pois():
				if not kinds.is_empty() and not kinds.has(str(p.get("kind", ""))):
					continue
				var pp: Vector3 = p["pos"]
				var dist := Vector2(pos.x - pp.x, pos.z - pp.z).length()
				if dist < best_d:
					best_d = dist
					best = pp
			return best
	return Vector3.INF

func _ai_step_target_dist(b: Dictionary, d: Dictionary) -> float:
	var proxy = b.get("proxy")
	var tp := _ai_step_target_pos(b, d)
	if proxy == null or not is_instance_valid(proxy) or tp == Vector3.INF:
		return INF
	return (proxy as Node3D).global_position.distance_to(tp)

# Presupuesto del paso: viaje estimado (a 2.6 m/s efectivos) + permanencia
# propia de la accion. Sin destino conocido solo cuenta la permanencia.
func _ai_step_budget_msec(b: Dictionary, d: Dictionary) -> int:
	var dist := _ai_step_target_dist(b, d)
	var travel := clampf((dist if dist != INF else 160.0) / 2.6, 20.0, 420.0) * 1000.0
	var dwell := float(AI_STEP_DWELL_SEC.get(str(d.get("action", "")), 60.0)) * 1000.0
	return int(travel + dwell)

# Un paso esta parado si no gana distancia a su destino en ~50 s o si agota su
# presupuesto sin completarse. Devuelve la causa o "" si progresa.
func _ai_step_stalled(b: Dictionary, d: Dictionary, now_ms: int) -> String:
	return PlanManager.stalled(self, b, d, now_ms)

# Evidencia material de que la ACTIVIDAD del paso rinde (mayor = mejor),
# distinta de la distancia al destino: saquear produce botin, cazar produce
# bajas o carne, descansar recupera, alejarse de una zona vetada gana metros
# de seguridad. INF = accion sin metrica propia (viaje, visita).
func _ai_step_evidence(b: Dictionary, d: Dictionary) -> float:
	var purpose := GoalValidator.purpose(d)
	if purpose == "gear" or purpose == "weapons":
		return 1.0 if not GoalValidator.decent_weapon(self, b.get("proxy")).is_empty() else 0.0
	if purpose != "general" and str(d.get("action", "")) in ["scavenge", "forage", "hunt"]:
		return float(b.get("_plan_loot", {}).get(purpose, 0))
	match str(d.get("action", "")):
		"scavenge", "explore":
			return float(b.get("_loot_n", 0))
		"hunt":
			var st: Dictionary = (b.get("_mem", {}) as Dictionary).get("stats", {})
			return float(int(st.get("kills_prey", 0)) + int(st.get("kills_predator", 0))) * 3.0 + float(b.get("_loot_food_n", 0))
		"forage":
			return float(b.get("_loot_food_n", 0)) * 10.0 + float(b.get("hunger", 100.0))
		"rest":
			var st2: SurvivalStats = b.get("vstats")
			return (float(st2.sleep) if st2 != null else 0.0) + float(b.get("health", 100.0))
		"fortify_camp":
			var n := 0.0
			if not str(b.get("shelter_id", "")).is_empty():
				n += 1.0
			if not str(b.get("campfire_id", "")).is_empty():
				n += 1.0
			return n
		"avoid_zone":
			# Metros de seguridad: distancia al POI vetado mas cercano.
			var proxy = b.get("proxy")
			if proxy == null or not is_instance_valid(proxy):
				return INF
			var av: Array = d.get("avoid_kinds", [])
			if av.is_empty():
				return INF
			var pos: Vector3 = (proxy as Node3D).global_position
			var best := INF
			for p in _explore_pois():
				if av.has(str(p.get("kind", ""))):
					best = minf(best, Vector2(pos.x - (p["pos"] as Vector3).x, pos.z - (p["pos"] as Vector3).z).length())
			return best
	return INF

# El bot esta parado de camino pero trabajando: saqueo, huida, combate,
# recoleccion, sueno o despiece cuentan como actividad, no como bloqueo.
func _ai_step_busy(b: Dictionary) -> bool:
	if b.get("aggro_target") != null or float(b.get("flee_until", 0.0)) > 0.0 \
			or float(b.get("hide_timer", 0.0)) > 0.0 or bool(b.get("sitting", false)) \
			or bool(b.get("sleeping", false)) or is_instance_valid(b.get("gut_target")):
		return true
	for k in ["_gather", "_s_loot", "_craft_state", "_ambush", "_forage", "_salvage", "_farm"]:
		var v = b.get(k)
		if v is Dictionary and not (v as Dictionary).is_empty():
			return true
	return false

# El paso parado fracasa con causa: se aprende, se vetea la reemision, se
# intenta el siguiente paso del plan como alternativa y, si no hay, cae al
# cerebro local y se pide una nueva decision remota.
func _ai_fail_stalled_step(bot_id: int, b: Dictionary, d: Dictionary, cause: String) -> void:
	PlanManager.fail_step(self, bot_id, b, d, cause)

func _ai_bot_eligible(b: Dictionary) -> bool:
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return false
	if proxy.get_meta("proxy_dead", false):
		return false
	if bool(b.get("sleeping", false)) or str(b.get("ai_directive", {}).get("state", "")) == "SUSPENDED":
		return false
	var lid := int(b.get("team_leader_id", 0))
	if lid != 0 and not is_bot_peer_id(lid):
		return false # bajo ordenes del jugador: el asesor no interfiere
	if float(b.get("hide_timer", 0.0)) > 0.0 or float(b.get("flee_until", 0.0)) > 0.0:
		return false
	var craft = b.get("_craft_state", {})
	if craft is Dictionary and not (craft as Dictionary).is_empty():
		return false
	return true

func _ai_request_decision(bot_id: int, b: Dictionary) -> void:
	_ai_pending_bot = bot_id
	_ai_calls_day += 1
	_ai_calls_total += 1
	_ai_last_call_msec[bot_id] = Time.get_ticks_msec()
	_ai_last_any_call_msec = Time.get_ticks_msec()
	_ai_conn_status = "requesting (%s)" % _ai_provider_name()
	_ai_next_at[bot_id] = Time.get_ticks_msec() + int(AI_REVIEW_MAX_SEC * 1000.0)
	var model := _ai_active_model()
	_ai_count_model_call(model)
	_ai_pending_model = model
	_ai_pending_provider = _ai_provider
	var payload := {
		"model": model,
		"temperature": 0.4,
		# gpt-oss y gemini-3 razonan antes de responder: 160 solo alcanza para
		# la cadena de pensamiento y el JSON salia vacio (json_validate_failed).
		"max_tokens": 600 if ("gpt-oss" in model or model.begins_with("gemini-3")) else 360,
		"response_format": {"type": "json_object"},
		"messages": [
			{"role": "system", "content": AI_SYSTEM_PROMPT + " Optional purpose: general, gear, food, water, ammo, clothing, tools, weapons, meat. Use forage with purpose water for drinking; rest requires actual recovery. Temporary emergencies suspend the current plan locally; do not restart completed steps."},
			{"role": "user", "content": _ai_build_prompt(b)},
		],
	}
	if "gpt-oss" in model:
		payload["reasoning_effort"] = "low"
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _ai_provider_key()])
	if _ai_http.request(_ai_provider_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		_ai_pending_bot = 0
		# Fallo al enviar: el proveedor queda en enfriamiento breve y el otro
		# pozo merece un intento antes del cerebro local; la recursion queda
		# acotada porque el que falla entra en su propio backoff.
		_ai_provider_blocked_until[_ai_provider] = Time.get_ticks_msec() + 15000
		var other := 1 - _ai_provider
		if _ai_provider_usable(other, Time.get_ticks_msec()):
			_ai_switch_provider("send_error", other)
			_ai_request_decision(bot_id, b)
			return
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
	# Contexto de fracasos para el asesor: que no proponga lo que Godot ya
	# sabe imposible — objetivos vigentes que fallaron (con causa y zona) y
	# destinos temporalmente inaccesibles. Acotado: los 5/4 mas recientes.
	var now_u := Time.get_unix_time_from_system()
	var fail_recs: Array = []
	var fgd: Dictionary = mem.get("failed_goals", {})
	for k in fgd.keys():
		var e = fgd[k]
		if e is Dictionary and now_u - float((e as Dictionary).get("t", 0.0)) < _ai_fail_entry_ttl(e):
			var parts := str(k).split("|")
			fail_recs.append({"goal": str((e as Dictionary).get("act", parts[0] + ":" + (parts[1] if parts.size() > 1 else ""))),
				"cause": str((e as Dictionary).get("cause", "")), "zone": (e as Dictionary).get("zone", []),
				"age_min": int((now_u - float((e as Dictionary).get("t", 0.0))) / 60.0), "_t": float((e as Dictionary).get("t", 0.0))})
	fail_recs.sort_custom(func(a, b2): return float(a.get("_t", 0.0)) > float(b2.get("_t", 0.0)))
	var fails: Array = []
	for e in fail_recs.slice(0, 5):
		e.erase("_t")
		fails.append(e)
	var unreach: Array = []
	var unm: Dictionary = mem.get("unreachable_pois", {})
	for k in unm.keys():
		var e = unm[k]
		# Solo vetos vigentes de verdad (varios fracasos, no una marca suelta).
		if e is Dictionary and int((e as Dictionary).get("n", 1)) >= UNREACHABLE_VETO_MIN_FAILS \
				and now_u - float((e as Dictionary).get("t", 0.0)) < UNREACHABLE_VETO_TTL:
			unreach.append({"poi": str(k), "cause": str((e as Dictionary).get("cause", "nav")),
				"left_min": int((UNREACHABLE_VETO_TTL - (now_u - float((e as Dictionary).get("t", 0.0)))) / 60.0)})
			if unreach.size() >= 4:
				break
	# Lo que el bot ha visto hacer a jugadores humanos cerca: sitios
	# "vetados" por un superviviente real (dormir, pescar, lumbre, casa).
	var obs_p: Array = []
	for e in mem.get("observed_players", []):
		var age_min := int((now_u - float((e as Dictionary).get("t", 0.0))) / 60.0)
		if age_min > int(OBSERVE_PLAYER_FRESH_SEC / 60.0):
			continue
		obs_p.append({"player": str((e as Dictionary).get("player", "")), "did": str((e as Dictionary).get("what", "")),
			"pos": (e as Dictionary).get("pos", []), "age_min": age_min})
		if obs_p.size() >= 4:
			break
	var vst_p: SurvivalStats = b.get("vstats")
	var state := {
		"name": str(b["name"]),
		"faction": str(b["faction"]),
		"personality": _get_bot_personality(b),
		"hp": int(float(b["health"])),
		"hunger": int(float(b["hunger"])),
		"thirst": int(float(b["thirst"])),
		"sleep": int(vst_p.sleep) if vst_p != null else 100,
		"temp": snappedf(vst_p.body_temperature, 0.1) if vst_p != null else 36.6,
		"weapon": str(b.get("held_item", "")),
		"night": _is_world_night(),
		"threat": _sensed_node(b, "_s_predator") != null or _sensed_node(b, "_s_foe") != null,
		"pos": [int(pos.x), int(pos.z)],
		"visited_pois": visited.size(),
		"deaths": int(mem.get("deaths", 0)),
		"items": (proxy.get_meta("saved_inventory", []) as Array).size(),
		"sticks": _bot_palo_supply(proxy),
		"has_shelter": not str(b.get("shelter_id", "")).is_empty(),
		"has_camp": b.get("camp_spot", Vector3.INF) != Vector3.INF,
		"known_locations": known_list,
		"relationships": rel_list,
		"recent_events": recent_events,
		"allowed_actions": AI_ALLOWED_ACTIONS,
		"last_plan": cur,
		"pending_steps": PlanManager.prompt_steps(mem.get("pending_goals", [])),
		"last_plan_result": str(b.get("_plan_last_result", "")),
		"recent_failures": fails,
		"unreachable": unreach,
		"observed_players": obs_p,
		"memory": _ai_memory_summary(mem),
	}
	return JSON.stringify(state)

# Groq devuelve "retry-after" (segundos) en los 429: si llega lo respetamos tal
# cual en vez de duplicar a ciegas — el tier gratis castiga rachas cortas y la
# espera real suele ser mucho menor que el backoff exponencial de 60..600 s.
# Pista de reintento del CUERPO del 429: Groq ("try again in 16.416s") y
# Google ("retryDelay": "30s" / "retry in 30 s") la llevan ahi cuando no hay
# cabecera Retry-After — en los bordes de ventana deslizante es el momento
# exacto en que el pozo vuelve a admitir la peticion.
func _ai_parse_retry_seconds(body_text: String) -> float:
	for pat in ["try again in ", "retry in "]:
		var i: int = body_text.find(pat)
		if i >= 0:
			var j: int = i + pat.length()
			var end := j
			while end < body_text.length() and (body_text.substr(end, 1).is_valid_float() or body_text.substr(end, 1) == "."):
				end += 1
			if end > j:
				return float(body_text.substr(j, end - j))
	var rd := body_text.find("\"retryDelay\"")
	if rd >= 0:
		var q1 := body_text.find("\"", rd + 12)
		var q2 := body_text.find("\"", q1 + 1)
		if q1 > 0 and q2 > q1:
			return float(body_text.substr(q1 + 1, q2 - q1 - 1).trim_suffix("s"))
	return -1.0

func _ai_register_429(headers: PackedStringArray, for_chat := false, body_text := "") -> void:
	_ai_429_count += 1
	var wait := -1.0
	for h in headers:
		var hl := str(h).to_lower()
		if hl.begins_with("retry-after:"):
			wait = float(hl.get_slice(":", 1).strip_edges())
			break
	if wait < 0.0:
		wait = _ai_parse_retry_seconds(body_text)
	var now := Time.get_ticks_msec()
	var pending := _ai_pending_provider
	# Cuota DIARIA agotada (TPD/RPD, "on tokens/requests per day") en el modelo
	# primario de Groq: el wait solo libera hueco para una llamada y el cartel
	# de rate_limited se repite todo el dia. Como la cuota es por modelo, se
	# cambia al fallback del mismo pozo y se reintenta pronto.
	# "per day" en cualquier pozo: la cuota diaria es por modelo — se encadena
	# al siguiente de la misma cadena y solo se veta al proveedor cuando la
	# cadena se agota (Gemini: cada modelo tiene RPD propia; Groq: la TPD es
	# org-wide, encadenar solo cuesta una llamada rechazada).
	if not for_chat and body_text.contains("per day") and _ai_advance_model_chain(pending):
		var used := _ai_parse_groq_used_limit(body_text)
		_ai_backoff_until_msec = now + 3000
		_ai_conn_status = "fallback_model (quota diaria %s -> %s)" % [used, _ai_chain_current_model(pending)]
		return
	if for_chat:
		if body_text.contains("per day"):
			_ai_advance_model_chain(pending)
		if wait < 0.0:
			wait = _chat_backoff_sec
			_chat_backoff_sec = minf(_chat_backoff_sec * 2.0, 600.0)
		_chat_backoff_until_msec = now + int(maxf(wait, 2.0) * 1000.0)
		_chat_conn_status = "rate_limited (429, retry_in=%ds)" % int(maxf(wait, 2.0))
		return
	# Backoff PROPIO del proveedor que respondio 429 (Retry-After o exponencial
	# propio): un pozo limitado no silencia al otro — se turnan por ventanas.
	if wait < 0.0:
		wait = float(_ai_provider_backoff_sec[pending])
		_ai_provider_backoff_sec[pending] = minf(wait * 2.0, 600.0)
	_ai_provider_blocked_until[pending] = now + int(maxf(wait, 2.0) * 1000.0)
	var daily := body_text.contains("per day") or body_text.contains("per_day")
	if daily:
		_ai_provider_day_done[pending] = true
		# La sonda respeta la pista del proveedor (ventana deslizante): entre
		# 45 s para no martillear el borde y el tope general de 15 min.
		var probe_sec := clampf(maxf(wait, 45.0), 45.0, AI_PROVIDER_DAY_PROBE_SEC)
		_ai_provider_day_probe_at[pending] = now + int(probe_sec * 1000.0)
	# El pozo del otro proveedor es independiente: si esta libre (sin veto y
	# fuera de su backoff) el relevo va alli — funciona en ambos sentidos.
	var other := 1 - pending
	if _ai_provider_usable(other, now) and (daily or _ai_429_streak >= 2):
		var reason := "quota diaria" if daily else "racha_429 x%d" % (_ai_429_streak + 1)
		_ai_429_streak = 0
		_ai_switch_provider(reason, other)
		return
	_ai_429_streak += 1
	_ai_conn_status = "rate_limited (%s 429, retry_in=%ds)" % [_ai_provider_name(pending), int(maxf(wait, 2.0))]

# Groq publica la cuota en cada respuesta 200: x-ratelimit-remaining-tokens +
# x-ratelimit-reset-tokens (formato Go "4m19.2s", "172ms", "1h30m"). El tier
# gratis limita a ~8000 tokens/minuto POR MODELO y cada decision consume ~2-3k
# (el chat ~300), asi que cuando queda poco margen paramos proactivamente
# hasta el reset en vez de comernos el 429 — cada canal con su propio umbral.
const AI_RATELIMIT_HEADROOM_TOKENS := 4200
const AI_CHAT_RATELIMIT_HEADROOM_TOKENS := 900

# Extrae "Used 199501, Limit 200000" del mensaje de un 429 (orden real en el
# body: "TPD): Limit 200000, Used 199501, Requested 2537") -> "199501/200000".
func _ai_parse_groq_used_limit(msg: String) -> String:
	var lim := ""
	var used := ""
	var li := msg.find("Limit ")
	var ui := msg.find("Used ")
	if li >= 0:
		var end := li + 6
		while end < msg.length() and msg[end].is_valid_int():
			end += 1
		lim = msg.substr(li + 6, end - li - 6)
	if ui >= 0:
		var end := ui + 5
		while end < msg.length() and msg[end].is_valid_int():
			end += 1
		used = msg.substr(ui + 5, end - ui - 5)
	return ("%s/%s" % [used, lim]) if not used.is_empty() else ""

func _ai_parse_groq_reset_seconds(raw: String) -> float:
	var s := raw.strip_edges()
	var total := 0.0
	var pos := 0
	while pos < s.length():
		var end := pos
		while end < s.length() and (s[end].is_valid_int() or s[end] == "."):
			end += 1
		if end == pos:
			return -1.0
		var num := float(s.substr(pos, end - pos))
		var unit := ""
		while end < s.length() and not s[end].is_valid_int():
			unit += s[end]
			end += 1
		match unit:
			"h": total += num * 3600.0
			"m": total += num * 60.0
			"ms": total += num / 1000.0
			"s": total += num
			"us": total += num / 1000000.0
			"ns": total += num / 1000000000.0
			_: return -1.0
		pos = end
	return total if total > 0.0 else -1.0

func _ai_note_rate_headers(headers: PackedStringArray, for_chat := false) -> void:
	var remaining := -1
	var reset_sec := -1.0
	for h in headers:
		var hl := str(h).to_lower()
		if hl.begins_with("x-ratelimit-remaining-tokens:"):
			remaining = int(hl.get_slice(":", 1).strip_edges())
		elif hl.begins_with("x-ratelimit-reset-tokens:"):
			reset_sec = _ai_parse_groq_reset_seconds(hl.get_slice(":", 1).strip_edges())
	var headroom := AI_CHAT_RATELIMIT_HEADROOM_TOKENS if for_chat else AI_RATELIMIT_HEADROOM_TOKENS
	if remaining >= 0 and remaining < headroom and reset_sec > 0.0:
		var until := Time.get_ticks_msec() + int((reset_sec + 0.5) * 1000.0)
		var status := "pacing (tokens<=%d, reset=%ds)" % [remaining, int(reset_sec)]
		if for_chat:
			if until > _chat_backoff_until_msec:
				_chat_backoff_until_msec = until
				_chat_conn_status = status
		elif until > _ai_backoff_until_msec:
			_ai_backoff_until_msec = until
			_ai_conn_status = status

func _ai_on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var bot_id := _ai_pending_bot
	_ai_pending_bot = 0
	if bot_id == 0 or not bots.has(bot_id):
		return
	var lb: Dictionary = bots[bot_id]
	# Latencia real de la consulta (incluye errores): diagnostico del monitor.
	var lat := Time.get_ticks_msec() - int(_ai_last_call_msec.get(bot_id, 0))
	_ai_stat_set(lb, "latency_ms_last", lat)
	var prev_avg := int((lb.get("_mem", {}) as Dictionary).get("ai_stats", {}).get("latency_ms_avg", 0))
	_ai_stat_set(lb, "latency_ms_avg", lat if prev_avg <= 0 else int(prev_avg * 0.8 + lat * 0.2))
	_ai_latency_ms_last = lat
	_ai_latency_ms_avg = lat if _ai_latency_ms_avg <= 0 else int(_ai_latency_ms_avg * 0.8 + lat * 0.2)
	if response_code == 429:
		_ai_register_429(_headers, false, body.get_string_from_utf8())
		_ai_apply_local_fallback_decision(bot_id, "http_429_backoff")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_ai_conn_status = "offline_fallback (%d)" % response_code
		var snippet := body.get_string_from_utf8().strip_edges().substr(0, 160)
		if not snippet.is_empty():
			print("[AI-ADV] HTTP %d: %s" % [response_code, snippet])
		_ai_stat_inc(lb, "http_errors")
		_ai_apply_local_fallback_decision(bot_id, "http_error_%d" % response_code)
		return
	_ai_provider_backoff_sec[_ai_pending_provider] = 4.0
	_ai_provider_day_done[_ai_pending_provider] = false
	_ai_429_streak = 0
	_ai_conn_status = "online (%s 200)" % _ai_provider_name(_ai_pending_provider)
	_ai_note_rate_headers(_headers)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_ai_stat_inc(lb, "qwen_invalid")
		_ai_apply_local_fallback_decision(bot_id, "invalid_json")
		return
	var usage = parsed.get("usage", {})
	if usage is Dictionary:
		var tok := int((usage as Dictionary).get("total_tokens", int((usage as Dictionary).get("prompt_tokens", 0)) + int((usage as Dictionary).get("completion_tokens", 0))))
		if tok <= 0:
			tok = 220
		_ai_tokens_day += tok
		_ai_tokens_total += tok
		_ai_count_model_tokens(_ai_pending_model if not _ai_pending_model.is_empty() else _ai_decision_model(), tok)
	else:
		_ai_tokens_day += 220
		_ai_tokens_total += 220
		_ai_count_model_tokens(_ai_pending_model if not _ai_pending_model.is_empty() else _ai_decision_model(), 220)
	var choices = parsed.get("choices", [])
	if not (choices is Array) or choices.is_empty():
		_ai_stat_inc(lb, "qwen_invalid")
		_ai_apply_local_fallback_decision(bot_id, "missing_choices")
		return
	var ch = choices[0]
	if not (ch is Dictionary):
		_ai_stat_inc(lb, "qwen_invalid")
		_ai_apply_local_fallback_decision(bot_id, "invalid_choice")
		return
	var msg = ch.get("message", {})
	if not (msg is Dictionary):
		_ai_stat_inc(lb, "qwen_invalid")
		_ai_apply_local_fallback_decision(bot_id, "invalid_message")
		return
	var content = msg.get("content", "")
	if not (content is String) or (content as String).strip_edges().is_empty():
		_ai_stat_inc(lb, "qwen_invalid")
		_ai_apply_local_fallback_decision(bot_id, "empty_content")
	elif not _ai_apply_decision(bot_id, content):
		_ai_stat_inc(lb, "qwen_invalid")
		# Muestra que propuso el modelo: depura por que un bot invalida
		# (acciones fuera de catalogo, sitios inventados, requisitos rotos).
		print("[AI-ADV] %s rechazada: %s" % [str(bots.get(bot_id, {}).get("name", bot_id)), (content as String).strip_edges().substr(0, 120)])
		_ai_apply_local_fallback_decision(bot_id, "invalid_or_impossible_decision")
	else:
		_ai_stat_inc(lb, "qwen_ok")
		_ai_note_decision_cache(bot_id, content)

func _ai_prune_decision_cache() -> void:
	if _ai_decision_cache.size() <= AI_DECISION_CACHE_MAX:
		return
	var now := Time.get_ticks_msec()
	for k in _ai_decision_cache.keys():
		var e = _ai_decision_cache[k]
		if not (e is Dictionary) or now - int((e as Dictionary).get("t", 0)) >= int(AI_DECISION_CACHE_TTL_SEC * 1000.0):
			_ai_decision_cache.erase(k)
	while _ai_decision_cache.size() > AI_DECISION_CACHE_MAX:
		var oldest_k := ""
		var oldest_t := INF
		for k in _ai_decision_cache.keys():
			var t := int((_ai_decision_cache[k] as Dictionary).get("t", 0))
			if t < oldest_t:
				oldest_t = t
				oldest_k = str(k)
		if oldest_k.is_empty():
			break
		_ai_decision_cache.erase(oldest_k)

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
	# Reject malformed field types before conversion (int(Dictionary) errors).
	for field in ["action", "target", "poi_kind", "goal", "reason", "purpose"]:
		if parsed.has(field) and not (parsed[field] is String):
			return {}
	var priority_value = parsed.get("priority", 3)
	if not (priority_value is int or priority_value is float):
		return {}
	if not is_finite(float(priority_value)):
		return {}
	var action := str(parsed.get("action", "")).to_lower().strip_edges()
	if not AI_ALLOWED_ACTIONS.has(action):
		return {}
	var raw_target := str(parsed.get("target", parsed.get("poi_kind", ""))).strip_edges()
	var kind := raw_target.to_lower()
	var goal := str(parsed.get("goal", action)).substr(0, 64)
	var prio := clampi(int(parsed.get("priority", 3)), 1, 5)
	var reason := str(parsed.get("reason", "")).substr(0, 80)
	if parsed.has("purpose") and not GoalValidator.PURPOSES.has(str(parsed["purpose"])):
		return {}

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
	if parsed.has("purpose"):
		out["purpose"] = str(parsed["purpose"])
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

# Legacy single decisions remain valid. Validate the whole bounded plan before
# replacing any active state; never partially accept an invented action/location.
func _ai_parse_plan(content: String, b: Dictionary) -> Array:
	var text := content.strip_edges()
	if text.begins_with("```"):
		var first_nl := text.find("\n")
		var last_fence := text.rfind("```")
		if first_nl > 0 and last_fence > first_nl:
			text = text.substr(first_nl + 1, last_fence - first_nl - 1).strip_edges()
	var raw = JSON.parse_string(text)
	if not (raw is Dictionary):
		return []
	var steps = raw.get("steps", [raw])
	if not (steps is Array) or steps.is_empty() or steps.size() > 4:
		return []
	for step in steps:
		if not (step is Dictionary) or step.has("steps"):
			return []
		var sd := _ai_parse_decision(JSON.stringify(step), b)
		if sd.is_empty() or (not b.is_empty() and _ai_goal_recently_failed(b, sd)):
			return []
	return steps.duplicate(true)

# Firma de un objetivo para recordar que fracaso: accion+destino y, si es un
# punto concreto, su zona aproximada (~60 m) — el mismo "vuelve a casa" no se
# vetaria en otro refugio.
# Vigencia del veto de un objetivo fallado: 5 min para cualquier causa —
# el castigo largo (hasta 4 h) congelaba la rutina entera del bot; reintentar
# pronto con otro plan es lo que hace un humano. AI_FAIL_TTL_MAX capea en
# lectura los registros antiguos escritos con TTL largos, sin borrar memoria.
const AI_FAIL_TTL_MAX := 300.0
const AI_FAIL_TTL := {
	"nav_blocked": 300.0,
	"stuck_timeout": 300.0,
	"timeout": 300.0,
	"no_progress": 300.0,
	"precondition": 300.0,
}

func _ai_fail_ttl(cause: String) -> float:
	return float(AI_FAIL_TTL.get(cause, AI_FAIL_TTL_MAX))

# Vigencia efectiva de una entrada de failed_goals: la suya si cabe en el
# cap de 5 min; las escritas con el regimen largo anterior caducan al cap.
func _ai_fail_entry_ttl(e: Dictionary) -> float:
	return minf(float(e.get("ttl", AI_FAIL_TTL_MAX)), AI_FAIL_TTL_MAX)

# Donde pretende ir el paso aunque aun no lleve pos resuelto: la misma
# resolucion que hace _ai_apply_decision (casa/campamento para el modo pos,
# aliado para el modo ally, POI cercano para el modo poi).
func _ai_goal_intended_pos(b: Dictionary, d: Dictionary) -> Vector3:
	# El fijado ya decide por los pasos adoptados; para candidatos aun sin
	# destino se reproduce la eleccion determinista que hara _ai_pin_* —
	# el veto se anota sobre el lugar al que iria de verdad.
	var pin = d.get("_dest_pos")
	if pin is Vector3 and (pin as Vector3) != Vector3.INF:
		return pin
	if str(d.get("mode", "")) == "poi":
		var pick := _ai_pick_poi(b, d.get("only_kinds", []), [], false)
		if not pick.is_empty():
			return pick["pos"]
		return Vector3.INF
	var tp := _ai_step_target_pos(b, d)
	if tp != Vector3.INF:
		return tp
	if str(d.get("mode", "")) == "pos":
		var home: Vector3 = b.get("shelter_pos", Vector3.INF)
		if str(d.get("action", "")) in ["rest", "fortify_camp"]:
			var camp: Vector3 = b.get("camp_spot", Vector3.INF)
			if camp != Vector3.INF:
				home = camp
		elif home == Vector3.INF:
			home = b.get("camp_spot", Vector3.INF)
		return home
	return Vector3.INF

# Firma de un objetivo para recordar que fracaso: accion + destino + zona
# concreta (~60 m). La zona sale del pos resuelto o del destino pretendido;
# para pasos sin lugar (forage, avoid) es donde estaba el bot al fracasar —
# asi el veto es de LUGAR, no de categoria: fallar saqueando esta ciudad no
# prohibe saquear otra.
func _ai_failed_goal_sig(d: Dictionary, b: Dictionary = {}) -> String:
	var sig := str(d.get("action", "")) + "|" + str(d.get("target", d.get("goal", "")))
	var zp := _ai_goal_intended_pos(b, d)
	if zp == Vector3.INF:
		var proxy = b.get("proxy")
		if proxy != null and is_instance_valid(proxy):
			zp = (proxy as Node3D).global_position
	if zp != Vector3.INF:
		sig += "|%d:%d" % [int(zp.x / 60.0), int(zp.z / 60.0)]
	return sig

# Persiste el objetivo fallido con la vigencia de su causa para que ni la
# reanudacion ni una reemision remota/local lo repitan en caliente — solo
# cerca de donde fracaso.
func _ai_note_failed_goal(b: Dictionary, d: Dictionary, cause: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	if mem.is_empty() or d.is_empty() or str(d.get("action", "")).is_empty():
		return
	var fg: Dictionary = mem.get("failed_goals", {})
	var zp := _ai_goal_intended_pos(b, d)
	var rec := {"t": Time.get_unix_time_from_system(), "cause": cause, "ttl": _ai_fail_ttl(cause),
		"act": str(d.get("action", "")) + ":" + str(d.get("target", d.get("goal", "")))}
	if zp != Vector3.INF:
		rec["zone"] = [int(zp.x), int(zp.z)]
	fg[_ai_failed_goal_sig(d, b)] = rec
	while fg.size() > 16:
		var oldest := ""
		var old_t := INF
		for k in fg.keys():
			if float((fg[k] as Dictionary).get("t", 0.0)) < old_t:
				old_t = float((fg[k] as Dictionary).get("t", 0.0))
				oldest = str(k)
		if oldest.is_empty():
			break
		fg.erase(oldest)
	mem["failed_goals"] = fg

func _ai_goal_recently_failed(b: Dictionary, d: Dictionary) -> bool:
	var fg: Dictionary = b.get("_mem", {}).get("failed_goals", {})
	if fg.is_empty():
		return false
	var e = fg.get(_ai_failed_goal_sig(d, b))
	if not (e is Dictionary):
		return false
	# Un fallo de requisitos nunca veta: el parse ya valida las condiciones
	# fresco — si el paso se ha parseado es que el mundo ya lo permite (el
	# refugio existe, el aliado reaparecio). El registro queda a modo de
	# aprendizaje/diagnostico.
	if str((e as Dictionary).get("cause", "")) == "precondition":
		return false
	var age := Time.get_unix_time_from_system() - float((e as Dictionary).get("t", 0.0))
	return age < _ai_fail_entry_ttl(e)

# Los recuerdos de fracaso caducan: al cargar una memoria vieja se podan las
# entradas fuera de vigencia (cada registro lleva su propia ttl; las memorias
# anteriores al campo usan la vigencia por defecto).
func _ai_prune_expired_memory(mem: Dictionary) -> void:
	var now_u := Time.get_unix_time_from_system()
	var fg: Dictionary = mem.get("failed_goals", {})
	for k in fg.keys():
		var e = fg[k]
		if not (e is Dictionary) or now_u - float((e as Dictionary).get("t", 0.0)) >= _ai_fail_entry_ttl(e):
			fg.erase(k)
	var un: Dictionary = mem.get("unreachable_pois", {})
	for k in un.keys():
		var e = un[k]
		if not (e is Dictionary) or now_u - float((e as Dictionary).get("t", 0.0)) >= UNREACHABLE_VETO_TTL:
			un.erase(k)

# Run the next subgoal locally, with fresh preconditions (home/ally can vanish).
# False means the plan ended or became impossible: the caller chooses a new plan.
func _ai_advance_plan(bot_id: int, b: Dictionary, d: Dictionary) -> bool:
	return PlanManager.advance(self, bot_id, b, d)

# Fija el destino UNICO del paso al adoptarlo (_dest_pos/_dest_id): navega-
# cion, progreso, aprendizaje y vetos trabajan desde entonces sobre el mismo
# lugar elegido, no sobre "el POI del tipo que ahora quede mas cerca".
# false = el paso no tiene destino real posible (requisito imposible).
func _ai_pin_step_destination(bot_id: int, b: Dictionary, d: Dictionary) -> bool:
	match str(d.get("mode", "")):
		"pos":
			if not (d.get("pos") is Vector3):
				var home: Vector3 = b.get("shelter_pos", Vector3.INF)
				if str(d.get("action", "")) in ["rest", "fortify_camp"]:
					var camp: Vector3 = b.get("camp_spot", Vector3.INF)
					if camp != Vector3.INF:
						home = camp
				elif home == Vector3.INF:
					home = b.get("camp_spot", Vector3.INF)
				if home == Vector3.INF:
					return false
				d["pos"] = home
			d["_dest_pos"] = d["pos"]
			d["_dest_id"] = "pos"
		"ally":
			return GoalValidator.bind_ally(self, b, d)
		"poi":
			return _ai_pin_poi_destination(b, d)
	return true

# Destino poi = el POI que la navegacion habria elegido con el mismo criterio
# (determinista: sin jitter, para que la firma del veto y el destino real sean
# el mismo lugar). Solo se rechaza cuando HAY POIs pero ninguno sirve — un
# mundo sin tabla de POIs no convierte el paso en imposible.
func _ai_pin_poi_destination(b: Dictionary, d: Dictionary) -> bool:
	var pick := _ai_pick_poi(b, d.get("only_kinds", []), [], false)
	if pick.is_empty():
		return _explore_pois().is_empty()
	d["_dest_pos"] = pick["pos"]
	d["_dest_id"] = str(pick.get("id", ""))
	return true

func _ai_apply_decision(bot_id: int, content: String, source: String = "qwen") -> bool:
	return PlanManager.apply(self, bot_id, content, source)

func _ai_apply_local_fallback_decision(bot_id: int, reason: String = "local_fallback") -> Dictionary:
	if not bots.has(bot_id):
		return {}
	var b: Dictionary = bots[bot_id]
	var local_d := decide_situational_action(b)
	local_d["reason"] = "%s (%s)" % [str(local_d.get("reason", "local")), reason]
	var local_steps: Array = [local_d]
	# A supply expedition has a return leg even without a remote advisor.
	if str(local_d.get("action", "")) in ["forage", "scavenge", "hunt"] and (b.get("shelter_pos", Vector3.INF) != Vector3.INF or b.get("camp_spot", Vector3.INF) != Vector3.INF):
		var ret_probe := {"action": "return_home", "target": "camp", "mode": "pos"}
		if not _ai_goal_recently_failed(b, ret_probe):
			local_steps.append({"action": "return_home", "target": "camp", "goal": "return_after_supplies", "reason": "supplies_trip_complete"})
	var json_str := JSON.stringify({"steps": local_steps})
	if not _ai_apply_decision(bot_id, json_str, "local_fallback"):
		# A local rest/home proposal may also lack a usable destination.
		# Replace the rejected goal without recursive fallback or remote work.
		_ai_apply_decision(bot_id, JSON.stringify({"action": "explore", "target": "wild", "reason": "local_unavailable: " + reason}), "local_fallback")
	# Solo se etiqueta cuando la decision local realmente sustituyo la directiva:
	# si la inercia conservo el plan vigente no se falsea su origen.
	if str(b.get("_ai_last_apply", "")) == "applied" and b.get("ai_directive") is Dictionary:
		b["ai_directive"]["source"] = "local_fallback"
		_ai_stat_inc(b, "local_decisions")
	_ai_stat_reason(b, reason)
	return b.get("ai_directive", {})

# Reanuda el plan guardado al arrancar la sesion (los objetivos sobreviven al
# reinicio del servidor). Cada paso se revalida contra la memoria viva — un
# destino que ya no conoce o un requisito perdido no se reanuda: queda en
# pending_steps como contexto para la proxima decision. NO se llama en respawn:
# volver automaticamente al plan que te mato no es supervivencia.
func _ai_resume_pending_plan(bot_id: int) -> void:
	if not bots.has(bot_id):
		return
	var b: Dictionary = bots[bot_id]
	var mem: Dictionary = b.get("_mem", {})
	var pending: Array = mem.get("pending_goals", [])
	if pending.is_empty():
		return
	var steps := _ai_parse_plan(JSON.stringify({"steps": pending}), b)
	if steps.is_empty():
		# El plan guardado ya no es ejecutable (requisitos perdidos o pasos
		# vetados por fallos previos): no se conserva para otro reinicio.
		mem["pending_goals"] = []
		return
	if _ai_apply_decision(bot_id, JSON.stringify({"steps": steps}), "memory") \
			and str(b.get("_ai_last_apply", "")) == "applied":
		b["ai_directive"]["source"] = "memory"
		b["_plan_last_result"] = "plan_resumed"
		_ai_stat_inc(b, "plans_resumed")

func _nearest_friendly_bot_pos(bot_id: int) -> Vector3:
	if not bots.has(bot_id):
		return Vector3.INF
	var b: Dictionary = bots[bot_id]
	var proxy = b.get("proxy")
	if proxy == null or not is_instance_valid(proxy):
		return Vector3.INF
	var my_faction := str(b.get("faction", "hostile"))
	var host_gate := 0.55 if my_faction == "hostile" else 0.05
	var pos := (proxy as Node3D).global_position
	var best := Vector3.INF
	var best_d := INF
	for oid in bots.keys():
		if int(oid) == bot_id or not _bot_pair_can_cooperate(bot_id, int(oid)):
			continue
		var ob: Dictionary = bots[oid]
		if str(ob.get("faction", "")) != my_faction:
			continue
		var rel_o := get_bot_relationship(bot_id, "bot_%d" % int(oid))
		if float(rel_o.get("hostility", 0.0)) > host_gate:
			continue
		var op = ob.get("proxy")
		if op == null or not is_instance_valid(op) or bool(op.get_meta("proxy_dead", false)):
			continue
		var d := pos.distance_to((op as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (op as Node3D).global_position
	return best

# El plan NO caduca por reloj: sigue mandando hasta que _ai_directive_completed
# lo cierra, otro plan lo sustituye, o el watchdog del sondeo fuerza una
# revalidacion si pasa demasiado tiempo sin cumplirse (until + grace).
func _ai_active_directive(b: Dictionary) -> Dictionary:
	var d = b.get("ai_directive", {})
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return {}
	if str(d.get("state", "")) in ["SUSPENDED", "COMPLETED", "FAILED", "CANCELLED"]:
		return {}
	return d

# ==================== MEMORIA PERSISTENTE ENTRE SESIONES (V2) ====================
# Persiste por separado para cada bot: identidad, personalidad evolutiva,
# eventos (y su resumen histórico), ubicaciones conocidas (con riesgo y score),
# relaciones con jugadores/bots, estrategias (éxito/fracaso/preferencia) y
# objetivos pendientes. Sobrevive al reinicio del servidor.

func _ai_memory_enabled() -> bool:
	return force_memory_io or OS.has_feature("dedicated_server")

# Runtime clocks reset each launch. Rebase saved ages, including time offline,
# while keeping trust, grudges and learned personality intact.
func _restore_relationship_clocks(rels: Dictionary, snapshot: Dictionary, now_ms: int, now_unix: float) -> void:
	var has_clock := snapshot.has("saved_tick_msec")
	var saved_tick := int(snapshot.get("saved_tick_msec", 0))
	var offline_ms := int(clampf(now_unix - float(snapshot.get("saved_unix", now_unix)), 0.0, 31536000.0) * 1000.0)
	for value in rels.values():
		if not (value is Dictionary):
			continue
		for key in ["harm_t", "scar_t", "bond_t"]:
			if not value.has(key):
				continue
			if has_clock:
				value[key] = now_ms - maxi(0, saved_tick - int(value[key])) - offline_ms
			else:
				# Legacy uptimes have no portable age; retain the relationship,
				# but do not invent a fresh injury after every restart.
				value.erase(key)

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
		for field in PlanDiagnostics.MEMORY_FIELDS:
			if sd.has(field):
				mem[field] = sd[field]
		for field in ["identity", "personality", "deaths", "last_death_cause", "last_death_killer", "last_death_weapon", "last_death_unix", "death_log", "killers", "bad_camp_spots", "base_raided", "gear_learned", "scarcity", "zone_yield", "death_spots", "death_lessons", "experience", "events", "events_summary", "known_locations", "observed_players", "relationships", "strategies", "pending_goals", "sessions", "stats", "ai_stats", "farm_plots", "milestones", "shelter", "score_reset_v", "failed_goals", "unreachable_pois", "exploration_regions"]:
			if sd.has(field):
				mem[field] = sd[field]
		mem["strategy_evidence_v"] = int(sd.get("strategy_evidence_v", 0))
		_migrate_strategy_evidence(mem)
		_ai_prune_expired_memory(mem)
		_restore_relationship_clocks(mem.get("relationships", {}), parsed, Time.get_ticks_msec(), Time.get_unix_time_from_system())
		# Migracion: las relaciones bot<->bot creadas sin agresion arrastran la
		# hostilidad 0.65 del init viejo (pensado para humanos) y eso bloquea la
		# puerta de convivencia de _bot_social_update. Los rencores de verdad
		# (attacked>0) se respetan; el resto baja al recelo de bandido.
		for akey in (mem.get("relationships", {}) as Dictionary).keys():
			var rel2 = mem["relationships"][akey]
			if int(parsed.get("version", 0)) < 3 and rel2 is Dictionary and str(akey).begins_with("bot_"):
				if int(rel2.get("attacked", 0)) == 0:
					rel2["hostility"] = minf(float(rel2.get("hostility", 0.0)), 0.30)
				elif int(rel2.get("attacked", 0)) > 6:
					# Tope de cicatrices heredadas del antiguo bug de disparos:
					# permite que el enfriamiento temporal las erosione en minutos.
					rel2["attacked"] = 6
		_compact_known_locations(mem)
		_bot_apply_score_reset(mem)
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

# Reset de marcador una sola vez por bot: las estadisticas que alimentan la
# puntuacion del monitor (vidas acumuladas, bajas, lugares conocidos) vuelven
# a cero. Se conserva el resto de la memoria: personalidad, relaciones,
# lecciones de muerte, nemesis e historial de caidas.
func _bot_apply_score_reset(mem: Dictionary) -> void:
	if int(mem.get("score_reset_v", 0)) >= 1:
		return
	mem["score_reset_v"] = 1
	mem["stats"] = {"alive_total_sec": 0.0, "kills_prey": 0, "kills_predator": 0, "animals_gutted": 0, "kills_bot": 0, "kills_player": 0}
	mem["deaths"] = 0
	mem["known_locations"] = {}

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
				tgt["combat_risk"] = maxf(float(tgt.get("combat_risk", 0.0)), float(e.get("combat_risk", 0.0)))
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
			PlanManager.checkpoint(b, Time.get_ticks_msec())
	var out := {"version": 3, "saved_tick_msec": Time.get_ticks_msec(), "saved_unix": Time.get_unix_time_from_system(), "bots": {}}
	for bid in _memory.keys():
		var mem: Dictionary = _ensure_bot_memory(int(bid))
		_ai_prune_and_summarize_memories(mem)
		var sd := {}
		sd["strategy_evidence_v"] = int(mem.get("strategy_evidence_v", 1))
		for field in PlanDiagnostics.MEMORY_FIELDS:
			if mem.has(field):
				sd[field] = mem[field]
		for field in ["identity", "personality", "deaths", "last_death_cause", "last_death_killer", "last_death_weapon", "last_death_unix", "death_log", "killers", "bad_camp_spots", "base_raided", "gear_learned", "scarcity", "zone_yield", "death_spots", "death_lessons", "experience", "events", "events_summary", "known_locations", "observed_players", "relationships", "strategies", "pending_goals", "sessions", "stats", "ai_stats", "farm_plots", "milestones", "shelter", "score_reset_v", "failed_goals", "unreachable_pois", "exploration_regions"]:
			if mem.has(field):
				sd[field] = mem[field]
		var lp = mem.get("last_death_pos", Vector3.INF)
		sd["last_death_pos"] = [lp.x, lp.y, lp.z] if lp is Vector3 and lp != Vector3.INF else []
		out["bots"][str(bid)] = sd
	# Serializar y escribir en worker: el deep-duplicate aísla el snapshot del
	# estado vivo para que el JSON pueda generarse sin pisar el hilo principal.
	if _mem_write_task >= 0:
		if not WorkerThreadPool.is_task_completed(_mem_write_task):
			return
		# Already completed: reap its resources without waiting for live work.
		WorkerThreadPool.wait_for_task_completion(_mem_write_task)
		_mem_write_task = -1
	_mem_write_task = WorkerThreadPool.add_task(_memory_write_worker.bind(out.duplicate(true)))

# Atomic JSON write: a crash mid-write would truncate the file and lose all bot
# memory; write to .tmp and rename so the file is always whole.
func _memory_write_worker(snapshot: Dictionary) -> void:
	var tmp := memory_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(snapshot))
	f.close()
	DirAccess.rename_absolute(tmp, memory_path)

func _ai_flush_writes() -> void:
	if _status_write_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_status_write_task)
		_status_write_task = -1
	if _mem_write_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_mem_write_task)
		_mem_write_task = -1

func _exit_tree() -> void:
	_ai_flush_writes()

# Registra qué botín dio la zona donde se recogió y actualiza la estrategia y ubicación.
func _ai_note_loot(b: Dictionary, item_name: String, item_type: String) -> void:
	var mem: Dictionary = b.get("_mem", {})
	var proxy = b.get("proxy")
	if mem.is_empty() or proxy == null or not is_instance_valid(proxy):
		return
	var bid := int(b.get("bot_id", 0))
	var pos := (proxy as Node3D).global_position
	var kind := _poi_kind_near(pos)
	# Evidencia material para el cierre real de objetivos (scavenge/hunt):
	# cuenta objetos recogidos y, aparte, los comestibles.
	GoalValidator.note_acquisition(self, b, item_name, item_type)
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
				var dcnt := clampi(int(s.get("count", 1)), 1, 3)
				factor *= pow(0.55, float(dcnt))
				break
	var known: Dictionary = mem.get("known_locations", {})
	var pid := _poi_id({"kind": kind, "pos": pos})
	if not known.has(pid):
		pid = _loc_merge_into(known, pid, pos)
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

# Factor 0.35-1.15 por estado ACTUAL del bot contra este destino concreto:
# complementa (no duplica) a memory_factor, que solo mira al pasado.
# · Un bot sin energia/comida/agua no se puede permitir una expedicion lejana.
# · combat_risk de known_locations (combates contra supervivientes, que
#   memory_factor no cubre) pesa segun la aversion al riesgo de cada uno —
#   Kael tolera lo que Elena evita.
func _ai_poi_state_factor(b: Dictionary, pid: String, dist: float) -> float:
	if not BOT_UTILITY_ENGINE:
		return 1.0
	var f := 1.0
	var energy := float(b.get("energy", 80.0))
	var hunger := float(b.get("hunger", 90.0))
	var thirst := float(b.get("thirst", 90.0))
	var weak := energy < 30.0 or hunger < 30.0 or thirst < 25.0
	if weak and dist > 220.0:
		f -= minf((dist - 220.0) / 220.0, 1.0) * 0.45
	var mem: Dictionary = b.get("_mem", {})
	var loc: Dictionary = (mem.get("known_locations", {}) as Dictionary).get(pid, {})
	var cr := float(loc.get("combat_risk", 0.0)) if loc is Dictionary else 0.0
	if cr > 0.0:
		var aversion := BotUtilityAI.risk_aversion(_get_bot_personality(b))
		f -= minf(cr / 3.0, 1.0) * aversion * 0.30
	return clampf(f, 0.35, 1.15)

func _ai_memory_summary(mem: Dictionary) -> Dictionary:
	var out := {"deaths": int(mem.get("deaths", 0))}
	var ldc := str(mem.get("last_death_cause", ""))
	if not ldc.is_empty():
		out["last_death_cause"] = ldc
	var ldk := str(mem.get("last_death_killer", ""))
	if not ldk.is_empty():
		out["last_death_killer"] = ldk
	var dl: Dictionary = mem.get("death_lessons", {})
	if not dl.is_empty():
		out["death_lessons"] = dl
	var kl: Dictionary = mem.get("killers", {})
	if not kl.is_empty():
		out["nemesis_count"] = kl.size()
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
		"death_lessons": (mem.get("death_lessons", {}) as Dictionary).duplicate(true),
		# Dieta: contador por tipo (setas/fruta/latas/carne/pescado/verduras/
		# crudos/otros) + ultimo plato — el monitor muestra de que vive.
		"food_eaten": (mem.get("food_eaten", {}) as Dictionary).duplicate(true),
		"last_meal": str(b.get("last_meal", "")),
		"adaptations": _bot_death_adaptations(mem),
		"pending_goals": (mem.get("pending_goals", []) as Array).duplicate(true),
		"last_plan_result": str(b.get("_plan_last_result", "")),
		"ai_stats": (mem.get("ai_stats", {}) as Dictionary).duplicate(true),
		"planning": PlanDiagnostics.snapshot(b, Time.get_ticks_msec()),
		"blocked": int(b.get("stuck_count", 0)) > 0 or not (b.get("_unreachable", []) as Array).is_empty(),
		"failed_goals": (mem.get("failed_goals", {}) as Dictionary).size(),
		"unreachable_pois": (mem.get("unreachable_pois", {}) as Dictionary).size(),
		# Detalle acotado de los vetos vigentes para el monitor — los mismos
		# que viajan en el prompt del asesor (goal, causa, edad, caducidad).
		"failed_goals_list": _ai_veto_snapshot(mem.get("failed_goals", {}), "act", 6),
		"unreachable_list": _ai_veto_snapshot(mem.get("unreachable_pois", {}), "", 6, UNREACHABLE_VETO_TTL),
		"foe_intel": _foe_intel_snapshot(b),
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
		var adapts: Array = snap.get("adaptations", [])
		if not adapts.is_empty():
			lines.append("  Evolución por muertes: %s" % " · ".join(adapts))
		var fe: Dictionary = snap.get("food_eaten", {})
		if not fe.is_empty():
			var f_parts: Array[String] = []
			for fk in fe.keys():
				if str(fk) != "last":
					f_parts.append("%s×%d" % [str(fk), int(fe[fk])])
			lines.append("  Dieta: %s (última: %s)" % [", ".join(f_parts), str(fe.get("last", snap.get("last_meal", "-")))])
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
		var is_b_dead: bool = (proxy != null and is_instance_valid(proxy) and bool(proxy.get_meta("proxy_dead", false))) or str(b.get("anim", "")).begins_with("dead") or float(b.get("health", 100.0)) <= 0.0
		snap["dead"] = is_b_dead
		snap["respawn_seconds"] = int(maxf(0.0, 180.0 - float(b.get("respawn_timer", 0.0)))) if is_b_dead else 0
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
			snap["blood"] = int(vst.blood)
			snap["bleeding"] = snappedf(vst.bleeding, 0.01)
			snap["body_temperature"] = snappedf(vst.body_temperature, 0.1)
			snap["wetness"] = snappedf(vst.wetness, 0.01)
		snap["in_shelter"] = proxy != null and is_instance_valid(proxy) and _bot_at_own_built_shelter(b, proxy.global_position)
		snap["in_house"] = (_is_bot_wolf_protected(b) and not bool(snap["in_shelter"])) if proxy != null and is_instance_valid(proxy) else false
		snap["team_leader_id"] = int(b.get("team_leader_id", 0))
		snap["follow_mode"] = str(b.get("follow_mode", "follow"))
		# Equipo bot-bot autonomo: rol, compañeros y emboscada en curso para el
		# panel web (JSON-safe: solo strings, ints y arrays).
		snap["team_role"] = _bot_team_role(b)
		snap["member_role"] = _bot_member_role(b)
		snap["team_danger"] = int(_ensure_bot_memory(int(bid), b.get("cfg", {})).get("team_danger_n", 0))
		# Ayuda negada a compañeros: max de negativas que cualquier compañero le
		# apunta (a 3 lo echan) — mismo calculo que _team_check_expulsion.
		var refused_max := 0
		var my_skey2 := "bot_%d" % int(bid)
		for tid2 in _bot_team_ids(b):
			if tid2 != int(bid) and bots.has(tid2):
				refused_max = maxi(refused_max, int(get_bot_relationship(tid2, my_skey2).get("refused", 0)))
		snap["team_refused"] = refused_max
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
				"promise": str((b.get("_meet_promise", {}) as Dictionary).get("kind", "")),
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
		var fgrowing := 0
		var fpct := 0
		var fempty := 0
		var frot := 0
		for fp in fplots:
			var rec := _bot_crop_record(str((fp as Dictionary).get("id", "")))
			if rec.is_empty():
				continue
			var eff := _crop_effective_state(rec)
			match str(eff.get("state", "")):
				"ready": fready += 1
				"rotten": frot += 1
				"empty": fempty += 1
				_:
					fgrowing += 1
					fpct = maxi(fpct, int(clampf(float(eff.get("growth", 0.0)) / 450.0, 0.0, 1.0) * 100.0))
		snap["farm"] = {"plots": fplots.size(), "ready": fready, "growing": fgrowing, "empty": fempty, "rotten": frot, "pct": fpct}
		var nb: Dictionary = b.get("_last_nav_block", {})
		if not nb.is_empty() and nb.get("pos") is Vector3:
			var nbp: Vector3 = nb["pos"]
			snap["last_nav_block"] = {"pos": [int(nbp.x), int(nbp.z)], "cause": str(nb.get("cause", "")), "age_min": int((Time.get_unix_time_from_system() - float(nb.get("t", 0.0))) / 60.0)}
		snap["camp_spot"] = [snappedf(camp.x, 0.1), snappedf(camp.y, 0.1), snappedf(camp.z, 0.1)] if camp != Vector3.INF else []
		snap["shelter_pos"] = [snappedf(sh.x, 0.1), snappedf(sh.y, 0.1), snappedf(sh.z, 0.1)] if sh != Vector3.INF else []
		snap["explore_target"] = [snappedf(et.x, 0.1), snappedf(et.y, 0.1), snappedf(et.z, 0.1)] if et != Vector3.INF else []
		snap["inventory"] = (proxy.get_meta("saved_inventory", []) as Array) if proxy != null and is_instance_valid(proxy) else []
		snap["shelter_stash"] = _get_shelter_contents(str(b.get("shelter_id", "")))
		var own_sh_d := _find_shelter_dict(str(b.get("shelter_id", "")))
		snap["shelter_camo"] = bool(own_sh_d.get("camo_covered", false)) if not own_sh_d.is_empty() else false
		snap["shelter_pelts"] = bool(own_sh_d.get("pelt_lined", false)) if not own_sh_d.is_empty() else false
		# Lobo domesticado: nombre, orden vigente, modo y vitales; o progreso de
		# doma si esta ganando la confianza de un lobo salvaje con cebo.
		var wolf_node := _bot_tamed_wolf(b)
		if wolf_node != null:
			var wpos := (wolf_node as Node3D).global_position
			snap["wolf"] = {
				"name": str(wolf_node.name),
				"mode": str(wolf_node.get("_follow_mode")),
				"order": str(b.get("_wolf_last_order", "follow")),
				"hp": int(wolf_node.get("health")),
				"hunger": int(wolf_node.get("_wolf_hunger")),
				"pos": [snappedf(wpos.x, 0.1), snappedf(wpos.y, 0.1), snappedf(wpos.z, 0.1)],
				"tamed": true,
			}
		else:
			var tame_key := str(bid)
			var tame_wolf: Node3D = null
			var tame_n := 0
			if world != null and world.get_tree() != null:
				for tw in world.get_tree().get_nodes_in_group("wildlife"):
					if not is_instance_valid(tw) or bool(tw.get("_is_dead")) or str(tw.get("animal_type")) != "wolf":
						continue
					var tp: Dictionary = tw.get("_tame_progress") if tw.get("_tame_progress") is Dictionary else {}
					var n := int(tp.get(tame_key, 0))
					if n > tame_n:
						tame_n = n
						tame_wolf = tw as Node3D
			if tame_wolf != null:
				var tp2 := tame_wolf.global_position
				snap["wolf"] = {"name": str(tame_wolf.name), "progress": tame_n, "need": 3, "pos": [snappedf(tp2.x, 0.1), snappedf(tp2.y, 0.1), snappedf(tp2.z, 0.1)], "taming": true}
			else:
				snap["wolf"] = {}
		snap["known_locations"] = (mem.get("known_locations", {}) as Dictionary).values()
		snap["deaths"] = int(mem.get("deaths", 0))
		snap["last_death_cause"] = str(mem.get("last_death_cause", ""))
		# Quien lo mato y como: asesino (jugador/bot) + arma/causa + hace cuanto.
		var killer_nm := str(mem.get("last_death_killer", ""))
		snap["last_death_killer"] = killer_nm
		snap["last_death_weapon"] = str(mem.get("last_death_weapon", mem.get("last_death_cause", "")))
		snap["last_death_unix"] = int(mem.get("last_death_unix", 0))
		var ldp = mem.get("last_death_pos", Vector3.INF)
		snap["last_death_pos"] = [snappedf((ldp as Vector3).x, 0.1), snappedf((ldp as Vector3).y, 0.1), snappedf((ldp as Vector3).z, 0.1)] if ldp is Vector3 and ldp != Vector3.INF else []
		var dlog: Array = mem.get("death_log", [])
		snap["death_log"] = (dlog.duplicate(true) if dlog is Array else [])
		# Nemesis: verdugo que ya lo mato >=2 veces.
		var nem := {}
		var nem_n := 0
		for kk in (mem.get("killers", {}) as Dictionary).values():
			if kk is Dictionary and int(kk.get("count", 0)) > nem_n:
				nem_n = int(kk.get("count", 0))
				nem = kk
		snap["nemesis"] = {"name": str(nem.get("name", "")), "count": nem_n} if nem_n >= 2 else {}
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
			+ float(st.get("kills_bot", 0)) * 50.0
			+ float(st.get("kills_player", 0)) * 75.0
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
		# Evolucion: rasgos base (para mostrar el delta), hitos y adaptaciones por muertes
		snap["base_personality"] = _default_personality_for_bot(bid)
		snap["milestones"] = mem.get("milestones", {})
		snap["death_lessons"] = mem.get("death_lessons", {})
		snap["adaptations"] = _bot_death_adaptations(mem)
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
	# Equipos autonomos bot-bot para el panel: cada lider libre con miembros (solo vivos).
	var teams_out: Array = []
	for tid in ids:
		var tb: Dictionary = bots[tid]
		var tpr: Node3D = tb.get("proxy")
		if tpr != null and is_instance_valid(tpr) and bool(tpr.get_meta("proxy_dead", false)):
			continue
		if int(tb.get("team_leader_id", 0)) != 0:
			continue
		var members: Array = []
		for oid in bots.keys():
			var ob_m: Dictionary = bots[oid]
			var opr_m: Node3D = ob_m.get("proxy")
			if opr_m != null and is_instance_valid(opr_m) and bool(opr_m.get_meta("proxy_dead", false)):
				continue
			if int(ob_m.get("team_leader_id", 0)) == int(tid):
				members.append({"id": int(oid), "name": str(ob_m.get("name", str(oid)))})
		if not members.is_empty():
			teams_out.append({"leader_id": int(tid), "leader": str(tb.get("name", str(tid))), "members": members})
	return {
		"timestamp": int(Time.get_unix_time_from_system()),
		"server": {
			"fps": Engine.get_frames_per_second(),
			"time_of_day": snappedf(tod, 0.05),
			"is_night": _is_world_night(),
			"day_phase": _world_day_phase(),
			"wildlife_count": wild_n,
			"players_online": online_p,
		},
		"groq": {
			"provider": _ai_provider_name(),
			"model": _ai_active_model(),
			"chat_model": _ai_active_chat_model(),
			"status": _ai_conn_status,
			"chat_status": _chat_conn_status,
			"calls_day": _ai_calls_day,
			"calls_day_by_model": _ai_calls_day_by_model.duplicate(),
			"max_calls_day": AI_MAX_CALLS_PER_DAY_2 if _ai_provider == 1 else ai_max_calls_per_day,
			"calls_total": _ai_calls_total,
			"tokens_day": _ai_tokens_day,
			"tokens_day_by_model": _ai_tokens_day_by_model.duplicate(),
			"max_tokens_day": AI_MAX_TOKENS_PER_DAY_2 if _ai_provider == 1 else ai_max_tokens_per_day,
			"providers": {
				"groq": {"max_calls": ai_max_calls_per_day, "max_tokens": ai_max_tokens_per_day,
					"blocked_s": maxi(0, int((int(_ai_provider_blocked_until[0]) - Time.get_ticks_msec()) / 1000)),
					"day_done": bool(_ai_provider_day_done[0])},
				"gemini": {"max_calls": AI_MAX_CALLS_PER_DAY_2, "max_tokens": AI_MAX_TOKENS_PER_DAY_2,
					"blocked_s": maxi(0, int((int(_ai_provider_blocked_until[1]) - Time.get_ticks_msec()) / 1000)),
					"day_done": bool(_ai_provider_day_done[1])},
			},
			"tokens_total": _ai_tokens_total,
			"cache_hits": _ai_cache_hits,
			"http_429_count": _ai_429_count,
			"latency_ms_last": _ai_latency_ms_last,
			"latency_ms_avg": _ai_latency_ms_avg,
			"queue_size": _ai_queue.size(),
			"queue": _ai_queue.map(func(it: Dictionary) -> Dictionary:
				return {"bot": int(it.get("bot_id", 0)), "prio": int(it.get("priority", 1)), \
					"reason": str(it.get("reason", "")), "force": bool(it.get("force", false))}),
		},
		"pois": pois_out,
		"landmarks": landmarks_out,
		"players": players_out,
		"bots": bots_out,
		"teams": teams_out,
		"chat_log": chat_log.slice(-BOT_CHAT_LOG_MAX),
	}

# El status del monitor (~140 KB) se construye en el hilo principal porque lee
# el estado vivo de los bots, pero stringify+write van a un worker para no
# clavar el frame cada AI_STATUS_SAVE_SEC. Si la escritura anterior sigue en
# vuelo se omite: el monitor se refresca en el siguiente ciclo de todos modos.
func _ai_save_live_status() -> void:
	if not _ai_memory_enabled():
		return
	if _status_write_task >= 0:
		if not WorkerThreadPool.is_task_completed(_status_write_task):
			return
		# Already completed: reap its resources without waiting for live work.
		WorkerThreadPool.wait_for_task_completion(_status_write_task)
		_status_write_task = -1
	var build_started := Time.get_ticks_usec()
	var snapshot := get_full_web_status()
	_pbm("web_status_build", build_started)
	var copy_started := Time.get_ticks_usec()
	var isolated := snapshot.duplicate(true)
	_pbm("web_status_copy", copy_started)
	_status_write_task = WorkerThreadPool.add_task(_status_write_worker.bind(isolated))

func _status_write_worker(snapshot: Dictionary) -> void:
	var tmp := AI_STATUS_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(snapshot))
	f.close()
	DirAccess.rename_absolute(tmp, AI_STATUS_PATH)

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

# Quien ya se desangro o se enveneno (leccion 'medical') aprende que la
# carne cruda no es comida de verdad: no cuenta para calmar la urgencia
# de buscar alimento — forrajea en vez de esperar a la desesperacion.
func _bot_raw_meat_is_food(b: Dictionary) -> bool:
	return int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("medical", 0)) == 0

# Cura estimada para capear una intoxicacion (~60 s, ~6 bocados por el
# cooldown de comida): cada pieza de comida segura cura use*0.35 (min 3)
# y cada Venda/Vendaje 32. Carne cruda/ensartada no cuenta — envenena.
func _bot_poison_cover(proxy: Node3D) -> float:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var cover := 0.0
	var bites := 0
	for it in inv:
		if not (it is Dictionary):
			continue
		var nm := str(it.get("name", ""))
		var qty := int(it.get("quantity", 1))
		if nm in ["Venda", "Vendaje"]:
			cover += 32.0 * qty
		elif bites < 6 and str(it.get("type", "")) == "food" and nm != "Carne humana" \
				and not nm.begins_with("Carne cruda") and not nm.ends_with("ensartada") \
				and nm != "Pez crudo" and (not nm.begins_with("Lata de ") or nm.ends_with(" abierta")):
			var use_qty := mini(qty, 6 - bites)
			cover += maxf(3.0, float(it.get("use_value", 18.0)) * 0.35) * float(use_qty)
			bites += use_qty
	return cover

func _bot_try_forage(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	var hunger := float(b["hunger"])
	var desperate := hunger < 24.0
	var scarcity := bool(b.get("_mem", {}).get("scarcity", false))
	var starved_lessons := int((b.get("_mem", {}).get("death_lessons", {}) as Dictionary).get("starved", 0))
	var foraging_experience := int(b.get("_mem", {}).get("experience", {}).get("forage", 0))
	var line := minf(90.0, 58.0 + (14.0 if scarcity else 0.0) + minf(18.0, float(starved_lessons) * 6.0) + 4.0*foraging_experience)
	var leader := _sensed_node(b, "_s_leader")
	var allowed := hunger < line and (leader == null or desperate or _bot_vital_break(b))
	# Cadena de recuperacion letal: quien forrajeo en urgencia (<14) sigue
	# comiendo hasta llegar a la linea segura — cortar a 40 lo devolvia al
	# ciclo inanicion->forrajeo->inanicion hasta morir con comida al lado.
	if not _is_world_night() or hunger >= line:
		b["_night_eat_chain"] = false
	# A threat can still keep it hidden, but darkness alone must not stop
	# a hungry survivor from finding food after waking up.
	if allowed and not desperate and (float(b.get("hide_timer", 0.0)) > 0.0 or (_is_world_night() and hunger >= 40.0 and not bool(b.get("_night_eat_chain", false)))):
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
		if not (apos is Vector3) or (apos as Vector3) == Vector3.INF or not _bot_supply_goal_allowed(b, apos):
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
	# Hambre sin comida encima (<40, no esperar al limite 26): el escaneo
	# local ya no basta — viajar de verdad hacia la comida en vez de
	# orbitar el parche agotado hasta caerse. Con 200 m de radio el bot
	# alcanza setas/frutales/latas que el escaneo normal nunca ve.
	if float(b["hunger"]) < 40.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b)):
		radius = maxf(radius, 200.0)
	# Hambre/sed letales: el escaneo crece al alcance de la urgencia — la
	# seta a 60 m salva igual que la de al lado, y morir buscando a 30 m
	# con comida a 40 m era la muerte tonta de siempre. Vale tambien de
	# dia: con luz la caminata es aun mas segura que la nocturna que ya
	# se permitia.
	if _bot_night_supply_emergency(b):
		radius = maxf(radius, NIGHT_LETHAL_SUPPLY_RADIUS)
	var target := _find_forage_target(b, radius)
	if target.is_empty():
		# Nada comestible ni en 200 m: no orbitar el parche agotado — viajar
		# al POI con comida mas prometedor (monte = setas/fruta/caza, casa/
		# ciudad = latas). En el camino el escaneo sigue activo y la primera
		# seta o frutal que entre en radio lo desvia del viaje.
		# El viaje lejano solo de dia pleno y sin helarse: de noche el radio
		# de emergencia (150 m) ya cubre lo alcanzable con luz propia; al
		# atardecer toca volver al refugio, no empezar una caminata de 200 m;
		# y un bot aterido debe calentarse antes de buscar comida.
		if hunger < 40.0 and ["dawn", "day"].has(_world_day_phase()) and not _bot_is_freezing(b):
			var fpoi := _ai_pick_poi(b, ["wild", "house", "city"], ["military", "tower"], false)
			if not fpoi.is_empty():
				# A >140 m el viaje se trocea en saltos POI a POI navegables —
				# la linea recta larga es la que terminaba vetada.
				var fpos: Vector3 = _bot_route_leg(b, fpoi["pos"])
				b["explore_target"] = fpos
				b["sitting"] = false
				b["crouching"] = false
				b["sleeping"] = false
				_move_bot_towards(b, fpos, 4.8, delta, "run" if hunger < 26.0 else "walk")
				return true
		return false
	b["_forage"] = target
	if _is_world_night() and _bot_night_supply_emergency(b):
		b["_night_eat_chain"] = true
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
	_ensure_world_action_caches()
	for aid in _cached_eat_ids:
		var a = world.world_actions_by_id.get(aid)
		if a == null or not is_instance_valid(a):
			continue
		if str(a.get("action_type")) != "eat_food" or claims.has(aid) or depleted.has(aid):
			continue
		if (_is_goal_blacklisted(b, a.global_position) or not _bot_supply_goal_allowed(b, a.global_position)):
			continue
		var d := proxy.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = {"kind": "eat", "id": str(aid), "pos": a.global_position, "t": 0.0, "t_need": 1.2,
				"use": float(a.get_meta("item_use_value", 12.0)), "name": str(a.get_meta("item_name", "comida"))}
	# Frutales: solo si no hay setas al alcance (la fruta cae al suelo y hay que recogerla)
	if best.is_empty():
		for aid in _cached_fruit_ids:
			var a = world.world_actions_by_id.get(aid)
			if a == null or not is_instance_valid(a):
				continue
			if str(a.get("action_type")) != "pick_fruit" or claims.has(aid) or depleted.has(aid):
				continue
			if now < float(a.get_meta("fruit_ready_time", 0.0)):
				continue
			if (_is_goal_blacklisted(b, a.global_position) or not _bot_supply_goal_allowed(b, a.global_position)):
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
		GoalValidator.note_acquisition(self, b, ename, "food")
		_bot_log_eaten_food(b, ename)
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
		if now < float(action.get_meta("fruit_ready_time", 0.0)):
			return
		action.set_meta("fruit_ready_time", now + 300.0)
		if "_pending_fruit_cooldowns" in world:
			(world._pending_fruit_cooldowns as Dictionary)[aid] = now + 300.0
		var fruit_name := str(st.get("fruit", "Higo"))
		var fruit_use := 20.0 if fruit_name == "Naranja" else 12.0
		var fruit_w := 0.20 if fruit_name == "Naranja" else 0.10
		var net2 = world.get("net")
		var produced_fruit := false
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
				produced_fruit = true
				world._net_item_dropped(drop_id, fruit_name, "food", fruit_w, 1, fruit_use, fpos, Color(0, 0, 0, 0), 0)
			if net2 != null and net2.is_host and net2.peer != null:
				for pid in net2.players.keys():
					if pid != net2.get_my_id() and not is_bot_peer_id(pid) and not net2.players[pid].get("offline", false) and net2.peer_alive(pid):
						net2.item_dropped.rpc_id(pid, drop_id, fruit_name, "food", fruit_w, 1, fruit_use, fpos, Color(0, 0, 0, 0))
		if produced_fruit:
			_learn_practical_skill(b, "forage", "Recolectó fruta: buscará alimento antes de quedarse sin reservas")
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

# Talar arboles grandes exige hacha de verdad, igual que al jugador
# (has_axe_in_hand): un cuchillo o piedra afilada no vale para un tronco.
func _bot_axe_tool(proxy: Node3D) -> String:
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and (str(it.get("name", "")) in ["Hacha", "Hacha de piedra"] or str(it.get("type", "")) == "tool_axe") \
				and float(it.get("durability", 1.0)) > 0.0:
			return str(it.get("name", ""))
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
	var growth := float(c.get("growth", 0.0))
	if state == "planted":
		var updated := float(c.get("updated_unix", now))
		var elapsed := maxf(0.0, now - updated)
		var moist := clampf(float(c.get("watered_until", 0.0)) - updated, 0.0, elapsed)
		growth += moist * GameConst.CROP_MOIST_GROWTH + (elapsed - moist)
		if growth >= 450.0:
			state = "ready"
			ready = now - maxf(0.0, growth - 450.0)
	if state == "ready" and ready > 0.0 and now - ready >= GameConst.CROP_ROT_SECONDS:
		state = "rotten"
	return {"state": state, "ready_unix": ready, "growth": growth}

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

# Registro de dieta para el monitor: contador por tipo en memoria (persiste
# entre muertes) y ultima comida en el estado vivo del bot.
func _bot_log_eaten_food(b: Dictionary, item_name: String) -> void:
	var cat := "otros"
	if item_name.begins_with("Seta"):
		cat = "setas"
	elif item_name in ["Naranja", "Higo"]:
		cat = "fruta"
	elif item_name.begins_with("Lata"):
		cat = "latas"
	elif item_name == "Verduras":
		cat = "verduras"
	elif item_name.begins_with("Carne cruda") or item_name in ["Pez crudo", "Carne ensartada", "Pez ensartado"]:
		cat = "crudos"
	elif item_name.begins_with("Pez") or item_name.begins_with("Pescado"):
		cat = "pescado"
	elif item_name.begins_with("Carne"):
		cat = "carne"
	b["last_meal"] = item_name
	var mem := _ensure_bot_memory(int(b.get("bot_id", 0)), b.get("cfg", {}))
	var fe: Dictionary = mem.get("food_eaten", {})
	fe[cat] = int(fe.get(cat, 0)) + 1
	fe["last"] = item_name
	mem["food_eaten"] = fe

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

func _bot_needs_farm_kit_now(b: Dictionary) -> bool:
	var plots := _bot_farm_plots(b)
	var active_n := 0
	for p in plots:
		var rec := _bot_crop_record(str((p as Dictionary).get("id", ""))) if p is Dictionary else {}
		if rec.is_empty():
			continue
		active_n += 1
		if str(_crop_effective_state(rec).get("state", "")) == "empty":
			return true
	return active_n < 3

func _bot_wear_farm_tool(proxy: Node3D) -> void:
	var inv: Array = proxy.get_meta("saved_inventory", [])
	for i in range(inv.size() - 1, -1, -1):
		var it = inv[i]
		if it is Dictionary and str(it.get("name", "")) in ["Azada", "Pala", "Azada de piedra"] and float(it.get("durability", 100.0)) > 0.0:
			var next_d := maxf(0.0, float(it.get("durability", 100.0)) - 4.0)
			it["durability"] = next_d
			if next_d <= 0.0:
				var q_left := int(it.get("quantity", 1)) - 1
				if q_left <= 0:
					inv.remove_at(i)
				else:
					it["quantity"] = q_left
					it["durability"] = float(it.get("max_durability", 100.0))
			proxy.set_meta("saved_inventory", inv)
			return

func _bot_try_farm(b: Dictionary, delta: float) -> bool:
	if world == null or not ("_planted_crops" in world):
		return false
	var proxy: Node3D = b["proxy"]
	# Escondido de una amenaza, durmiendo, agotado o helandose no sale al huerto;
	# la cosecha madura espera a que pase el peligro o recupere fuerzas.
	if float(b.get("hide_timer", 0.0)) > 0.0 or bool(b.get("sleeping", false)) or _bot_is_exhausted(b) or _bot_is_freezing(b):
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
				if _bot_item_count(proxy, "Semillas") <= 0 or not _bot_has_farm_tool(proxy):
					return true
				if phase == "replant":
					var rec := _bot_crop_record(str(st.get("crop_id", "")))
					if rec.is_empty() or str(_crop_effective_state(rec).get("state", "")) != "empty":
						return true
					_bot_consume_one_item(proxy, "Semillas")
					_bot_wear_farm_tool(proxy)
					rec["crop_state"] = "planted"
					rec["growth"] = 0.0
					rec["updated_unix"] = now
					rec["watered_until"] = 0.0
					rec["ready_unix"] = 0.0
					_bot_crop_broadcast("crop_replanted", fpos)
				else:
					var count_before: int = world._planted_crops.size()
					var cid: String = world._plant_crop(fpos) if world.has_method("_plant_crop") else ""
					if cid.is_empty() or world._planted_crops.size() == count_before:
						return true
					_bot_consume_one_item(proxy, "Semillas")
					_bot_wear_farm_tool(proxy)
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
					var inv_w: Array = proxy.get_meta("saved_inventory", [])
					var empty_b := {"name": "Botella de plastico", "type": "misc", "weight": 0.1, "quantity": 1, "use_value": 0.0}
					if not _bot_try_add_inventory_item(b, inv_w, empty_b):
						_bot_drop_to_ground(b, empty_b)
					proxy.set_meta("saved_inventory", inv_w)
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
	# 1) Cosechar lo maduro: se pudre en ~10 min y es comida regalada. El
	# arrastre es regional — no se cruza el mapa por un cultivo (a 120 m se
	# llega dentro de la ventana de pudricion cuando ya estaba por la zona).
	for p in plots:
		var rec := _bot_crop_record(str(p.get("id", "")))
		if rec.is_empty():
			continue
		var eff := _crop_effective_state(rec)
		var pp: Vector3 = rec.get("pos", _bot_plot_pos(p)) if rec.get("pos") is Vector3 else _bot_plot_pos(p)
		if pp == Vector3.INF:
			continue
		if Vector2(cur.x - pp.x, cur.z - pp.z).length() > 120.0:
			continue
		if eff["state"] == "ready":
			b["_farm"] = {"phase": "harvest", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 1.25, "tool": ""}
			return true
		if eff["state"] == "rotten":
			b["_farm"] = {"phase": "clean", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 1.25, "tool": ""}
			return true
	# Muerto de hambre/sed: no se pone a sembrar — busca comida ya.
	var starving := float(b["hunger"]) < 26.0 and not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b))
	if starving:
		return false
	# 2) Replantar un bancal vacio propio si lleva semillas y herramienta —
	# solo de paso (tras cosechar ya esta encima); un bancal vacio lejano no
	# llama de vuelta, espera a la proxima visita.
	if has_tool and _bot_item_count(proxy, "Semillas") >= 1:
		for p in plots:
			var rec := _bot_crop_record(str(p.get("id", "")))
			if not rec.is_empty() and str(rec.get("crop_state", "")) == "empty":
				var pp: Vector3 = rec.get("pos", _bot_plot_pos(p)) if rec.get("pos") is Vector3 else _bot_plot_pos(p)
				if pp == Vector3.INF:
					continue
				if Vector2(cur.x - pp.x, cur.z - pp.z).length() > 40.0:
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
		var bottles_n := _bot_item_count(proxy, "Botella de agua llena")
		var can_spare_water := bottles_n >= 2 or (bottles_n == 1 and float(b.get("thirst", 100.0)) >= 45.0)
		if Vector2(cur.x - pp.x, cur.z - pp.z).length() < 25.0 and can_spare_water:
			b["_farm"] = {"phase": "water", "crop_id": str(rec.get("id", "")), "pos": pp, "t": 0.0, "t_need": 2.0, "tool": ""}
			return true
	# 4) Sembrar un bancal nuevo — mejora de asentado o jugada desesperada,
	# nunca rutina: con refugio, hambre/sed cubiertos y semillas de sobra es
	# una inversion de quien esta comodo; pero quien se queda sin nada que
	# comer puede sembrar hasta la ultima semilla aunque no tenga casa.
	var seeds := _bot_item_count(proxy, "Semillas")
	var desperate := not _bot_has_edible_food(proxy, _bot_raw_meat_is_food(b))
	var surplus := not str(b["shelter_id"]).is_empty() \
			and seeds >= 2 \
			and float(b["hunger"]) >= 55.0 \
			and float(b["thirst"]) >= 45.0 \
			and not _bot_is_exhausted(b) and not _bot_is_freezing(b)
	if has_tool and plots.size() < 2 and seeds >= 1 and (desperate or surplus):
		var spot := _bot_find_farm_spot(b)
		if spot != Vector3.INF and Vector2(cur.x - spot.x, cur.z - spot.z).length() < 60.0:
			b["_farm"] = {"phase": "plant", "pos": spot, "t": 0.0, "t_need": 4.0, "tool": tool_name}
			return true
	return false

# Rescate por frio — el helado se salva con lo que tiene a mano, igual que
# el jugador que enciende una fogata de emergencia en vez de morir caminando
# a casa. Cadena: fuego ya encendido al alcance -> correr a su anillo;
# material en la mochila -> montar la fogata aqui mismo (no en el campamento
# a medio mapa); sin material -> salida acotada por los 2 palos/2 piedras.
# Devuelve false cuando nada de eso sirve y entonces el bloque de refugio
# manda la marcha al calor/refugio mas cercano del mapa.
func _bot_try_cold_rescue(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	if not _bot_is_freezing(b) or bool(b.get("sleeping", false)):
		return false
	# Calor real al alcance: correr al anillo caliente, no inventar otro fuego.
	var lit_pos := _nearest_lit_campfire_pos(proxy.global_position, 40.0, b)
	if lit_pos != Vector3.INF:
		var spot := _bot_fire_safe_spot(lit_pos, lit_pos.y, b)
		b["sitting"] = false
		b["crouching"] = false
		_move_bot_towards(b, spot, 5.8, delta, "run")
		b["_act"] = "fire_rescue"
		return true
	# Material a mano: la fogata se monta donde esta — ni en el agua ni donde
	# ya arde otra (eso lo cubre la rama de arriba).
	if _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2:
		var depth := 0.0
		if world != null and world.has_method("get_river_depth_at"):
			depth = float(world.get_river_depth_at(proxy.global_position))
		if depth <= 0.05:
			_bot_build_and_light_campfire(b, proxy.global_position + Vector3(0.9, 0.0, 0.9))
			b["_act"] = "fire_rescue"
			return true
	# Sin material: recoger la lena y las piedras del fuego ES el rescate —
	# el veto a recoger helandose queda para expediciones, no para salvarse.
	if _bot_try_gather_mats(b, delta, true):
		b["_act"] = "fire_rescue"
		return true
	return false

func _bot_try_gather_mats(b: Dictionary, delta: float, fire_rescue := false) -> bool:
	var proxy: Node3D = b["proxy"]
	var palo_need := 0
	if str(b["shelter_id"]).is_empty():
		palo_need = 11 # refugio: mismo coste exacto que el del jugador (11 palos)
	elif str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)):
		palo_need = 2
	# La antorcha de la noche tambien pide su palo: uno de repuesto siempre
	# que no lleve ya una antorcha, mas los 2 de la fogata si esta aun sin
	# fuego propio ni litio al alcance — no quedarse sin palo para ninguna.
	if _bot_item_count(proxy, "Antorcha") == 0:
		var torch_palos := 1
		if str(b["campfire_id"]).is_empty() and not _is_near_any_lit_campfire(proxy.global_position, 8.0):
			torch_palos += 2
		palo_need = maxi(palo_need, torch_palos)
	if _bot_has_raw_meat(proxy) or _bot_has_skewered_meat(proxy):
		var cook_palos := (1 if _bot_item_count(proxy, "Palo afilado") == 0 and not _bot_has_skewered_meat(proxy) else 0) + (2 if str(b["campfire_id"]).is_empty() else 0)
		palo_need = maxi(palo_need, cook_palos)
	# Piedras de la fogata: con refugio propio las junta al ir a montarla; sin
	# el solo le importan al caer la tarde, para la fogata de emergencia.
	var piedra_need := 0
	if not str(b["shelter_id"]).is_empty() and str(b["campfire_id"]).is_empty() and not bool(b.get("no_fire_spot", false)):
		piedra_need = 2
	elif _is_pre_night() and not _bot_night_fire_ready(b, proxy):
		piedra_need = 2
		palo_need = maxi(palo_need, 2)
	elif _bot_wants_farm_tool(b) and _bot_item_count(proxy, "Semillas") >= 1:
		piedra_need = 1
	var tool := _bot_bush_tool(proxy)
	# Arbustos tambien dan Semillas: quien quiere huerto tala aunque no le
	# falten palos (2 paquetes de semillas bastan para un bancal).
	var seeds_need := _bot_wants_seeds(b) and _bot_item_count(proxy, "Semillas") < 2
	# De noche sin luz propia no se emprende la campana de los 11 palos ni el
	# huerto: solo lo que falta para la antorcha/fogata, y cerca — el monte a
	# oscuras no es sitio para recoger lena de obra.
	var night_no_light := _is_world_night() and _bot_item_count(proxy, "Antorcha") == 0 \
			and not _is_near_any_lit_campfire(proxy.global_position, 8.0)
	if night_no_light:
		palo_need = 1 + (2 if str(b["campfire_id"]).is_empty() else 0)
		piedra_need = 2 if str(b["campfire_id"]).is_empty() else 0
		seeds_need = false
	# Rescate por frio: el helado SOLO sale por lo que falta para la fogata
	# de emergencia — ni los 11 palos del refugio ni el huerto. Recoger la
	# lena del fuego que le salva la vida ES el rescate, no una expedicion.
	var freezing_rescue := fire_rescue and _bot_is_freezing(b)
	if freezing_rescue:
		palo_need = 2
		piedra_need = 2
		seeds_need = false
	var palo_short := _bot_palo_supply(proxy, tool) < palo_need
	var piedra_short := _bot_item_count(proxy, "Piedra") < piedra_need
	# Escondido, agotado, helandose o reclutado no sale a recoger: descansar,
	# calentarse, las ordenes del lider y la amenaza van primero. El seguidor
	# solo se exime cuando su salida es el punado de palos/piedras del fuego —
	# y el helado solo cuando esa salida es su fogata de rescate.
	var allowed := (((palo_short or seeds_need) and not tool.is_empty()) or piedra_short) \
			and float(b.get("hide_timer", 0.0)) <= 0.0 \
			and not _bot_is_exhausted(b) \
			and (not _bot_is_freezing(b) or freezing_rescue) \
			and (_sensed_node(b, "_s_leader") == null or (palo_need <= 3 and piedra_need <= 2))
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
		var kind_g := str(st.get("kind", "fell_bush"))
		var is_tree := kind_g == "fell_tree"
		var held_g := _bot_axe_tool(proxy) if is_tree else tool
		if not (apos is Vector3) or act == null or not is_instance_valid(act) or taken \
				or (world != null and "_depleted_action_ids" in world and (world._depleted_action_ids as Array).has(aid)) \
				or (kind_g in ["fell_bush", "wood"] and tool.is_empty()) or (is_tree and held_g.is_empty()):
			_bot_release_gather_claim(b, st)
			b["_gather"] = {}
			return false
		var flat := Vector2(proxy.global_position.x - (apos as Vector3).x, proxy.global_position.z - (apos as Vector3).z).length()
		var cutting := kind_g in ["fell_bush", "fell_tree"]
		if flat > (2.6 if is_tree else 2.2):
			b["sitting"] = false
			b["crouching"] = false
			if cutting:
				b["held_item"] = held_g
				proxy.set_meta("saved_held_item", held_g)
			_move_bot_towards(b, apos, 4.8 if flat > 9.0 else 3.8, delta, "run" if flat > 9.0 else "walk")
			return true
		st["t"] = float(st.get("t", 0.0)) + delta
		b["anim"] = "chop" if is_tree else "forage"
		b["crouching"] = not is_tree
		b["sitting"] = false
		if cutting:
			b["held_item"] = held_g
			proxy.set_meta("saved_held_item", held_g)
		if float(st["t"]) >= float(st.get("t_need", 5.0)):
			b["_gather"] = {}
			if is_tree:
				_bot_fell_tree_complete(b, st)
			elif cutting:
				_bot_fell_bush_complete(b, st)
			else:
				_bot_node_collect_complete(b, st)
		return true
	# Escaneo con cadencia, como el forrajeo
	b["_gather_scan"] = float(b.get("_gather_scan", 0.0)) - delta
	if float(b["_gather_scan"]) > 0.0:
		return false
	b["_gather_scan"] = 1.4 + fmod(float(int(b["bot_id"])) * 0.29, 0.6)
	var scan_radius := 24.0 if night_no_light else 80.0
	if freezing_rescue:
		scan_radius = 120.0
	var target := _find_mat_target(b, scan_radius, tool, palo_short, piedra_short, seeds_need)
	if target.is_empty():
		return false
	if world != null and "_pickup_claims" in world:
		(world._pickup_claims as Dictionary)[target["id"]] = int(b["bot_id"])
		if "_pickup_claim_until" in world:
			(world._pickup_claim_until as Dictionary)[target["id"]] = Time.get_ticks_msec() + 30000
	# Aprende la rutina: una salida de material al caer la tarde queda en su
	# memoria como preparacion para la noche (una sola anotacion por tarde).
	if _is_pre_night() and not _bot_night_fire_ready(b, proxy) and not bool(b.get("_prep_logged", false)):
		b["_prep_logged"] = true
		record_bot_event(int(b["bot_id"]), "night_prep", "self", _poi_kind_near(proxy.global_position), proxy.global_position,
			"junta fuego/luz: " + str(target.get("kind", "fell_bush")))
	b["_gather"] = target
	return _bot_try_gather_mats(b, 0.0, fire_rescue)

# Nodo de recoleccion mas conveniente segun lo que falta: arbustos a talar
# (filo, 5 s, 3 palos + semillas), troncos aprovechables (filo para luego
# rajarlos, 2 Troncos -> 4 palos) o piedras sueltas (a mano, ~3 piedras).
func _find_mat_target(b: Dictionary, radius: float, tool: String, need_palo: bool, need_piedra: bool, need_seeds: bool) -> Dictionary:
	if world == null or not ("world_actions_by_id" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var can_fit_palo := _bot_would_fit(b, inv, {"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1})
	var can_fit_semillas := _bot_would_fit(b, inv, {"name": "Semillas", "type": "resource", "weight": 0.05, "quantity": 1})
	var can_fit_wood := _bot_would_fit(b, inv, {"name": "Tronco", "type": "resource", "weight": 1.2, "quantity": 2})
	var can_fit_log := _bot_would_fit(b, inv, {"name": "Tronco", "type": "resource", "weight": 1.2, "quantity": 1})
	var can_fit_stone := _bot_would_fit(b, inv, {"name": "Piedra", "type": "resource", "weight": 0.45, "quantity": 1})
	var axe := _bot_axe_tool(proxy)
	var camp: Vector3 = b.get("camp_spot", proxy.global_position)
	var claims: Dictionary = world.get("_pickup_claims") if "_pickup_claims" in world else {}
	var depleted: Array = world.get("_depleted_action_ids") if "_depleted_action_ids" in world else []
	var best := {}
	var best_score := INF
	_ensure_world_action_caches()
	for aid in _cached_mat_ids:
		var a = world.world_actions_by_id.get(aid)
		if a == null or not is_instance_valid(a):
			continue
		if _is_goal_blacklisted(b, a.global_position):
			continue
		var atype := str(a.get("action_type"))
		var serves := false
		if atype == "fell_bush":
			# Palos Y semillas salen del mismo arbusto: sirve si cabe lo que
			# busca — la semilla (0.05) cabe en una mochila donde el palo
			# (0.3) ya no entra; los palos sobrantes quedan en el suelo.
			serves = not tool.is_empty() and ((need_palo and can_fit_palo) or (need_seeds and can_fit_semillas))
		elif atype == "fell_tree":
			# Arbol de verdad: solo con hacha y si le cabe al menos un tronco
			# de 1.2 kg (el resto queda en el suelo para la vuelta).
			serves = not axe.is_empty() and need_palo and can_fit_log
		elif atype == "wood":
			# Troncos solo valen con filo y si le caben los 2.4 kg en la mochila.
			serves = not tool.is_empty() and need_palo and can_fit_wood
		elif atype == "stone":
			serves = need_piedra and can_fit_stone
		if not serves or claims.has(aid) or depleted.has(aid):
			continue
		var d := proxy.global_position.distance_to((a as Node3D).global_position)
		if d > radius:
			continue
		# Prefiere nodos entre el bot y su campamento: el humano recoge cerca
		# de donde va a construir, no en la punta opuesta del mapa.
		var d_camp := (a as Node3D).global_position.distance_to(camp)
		var score := d + d_camp * 0.5
		if score < best_score:
			best_score = score
			# Arbol: 10 s de tala como el jugador; arbusto 5 s; piedra/tronco
			# sueltos 1.4 s a mano.
			var t_need := 10.0 if atype == "fell_tree" else (5.0 if atype == "fell_bush" else 1.4)
			best = {"id": str(aid), "pos": (a as Node3D).global_position, "t": 0.0, "t_need": t_need, "kind": atype}
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
	# Los palos caen al suelo: forzar refresco inmediato de sentidos para que
	# los recoja en el proximo tick antes de marcharse a otro arbusto.
	_loot_clear(b)
	b["sense_t"] = 0.0

# Tala de arbol completa (fell_tree): mismos numeros que el jugador — hacha
# -10 de durabilidad, ruido que atrae lobos a 45 m y 4 Troncos al suelo junto
# a los restos del tronco cortado.
func _bot_fell_tree_complete(b: Dictionary, st: Dictionary) -> void:
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
	var axe := _bot_axe_tool(proxy)
	if axe.is_empty():
		return
	_reduce_bot_item_durability(proxy, axe, 10.0)
	if world.has_method("_attract_wolves_to_noise"):
		world._attract_wolves_to_noise(pos, 45.0)
	if "_legit_cut_trees" in world and not (world._legit_cut_trees as Array).has(aid):
		(world._legit_cut_trees as Array).append(aid)
	var base := Time.get_ticks_msec()
	var offsets: Array = [Vector3(1.0, 0.06, 0.3), Vector3(1.5, 0.06, -0.2), Vector3(0.5, 0.06, 0.8), Vector3(2.0, 0.06, 0.1)]
	var spawns: Array = []
	for off in offsets:
		spawns.append({"id": "pickup_Tronco_%d" % (base + randi() % 1000), "name": "Tronco", "type": "resource", "pos": pos + off, "weight": 1.2, "qty": 1, "use": 0.0})
	if world.has_method("_net_world_action_completed"):
		world._net_world_action_completed(aid, spawns, "tree_remains", pos, 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.world_action_completed.rpc_id(pid, aid, spawns, "tree_remains", pos)
	# Troncos al suelo: refresco de sentidos para recogerlos al tick siguiente.
	_loot_clear(b)
	b["sense_t"] = 0.0

# Recogida a mano de nodos "wood"/"stone": igual que el jugador, el material
# entra directo a la mochila (sin drops), sin filo ni desgaste de herramienta.
func _bot_node_collect_complete(b: Dictionary, st: Dictionary) -> void:
	var proxy: Node3D = b["proxy"]
	var aid := str(st.get("id", ""))
	var pos: Vector3 = st.get("pos", Vector3.INF)
	_bot_release_gather_claim(b, st)
	if world == null or aid.is_empty() or pos == Vector3.INF:
		return
	var act = world.world_actions_by_id.get(aid) if "world_actions_by_id" in world else null
	if act == null or not is_instance_valid(act):
		return
	if "_depleted_action_ids" in world and (world._depleted_action_ids as Array).has(aid):
		return
	var inv: Array = proxy.get_meta("saved_inventory", [])
	var got := ""
	if str(st.get("kind", "")) == "wood":
		if _bot_try_add_inventory_item(b, inv, {"name": "Tronco", "type": "resource", "weight": 1.2, "quantity": 2, "use_value": 0.0}):
			got = "Tronco"
	else:
		var qty := maxi(1, int(act.get_meta("item_quantity", 3)))
		if _bot_try_add_inventory_item(b, inv, {"name": "Piedra", "type": "resource", "weight": 0.45, "quantity": qty, "use_value": 0.0}):
			got = "Piedra"
	if got.is_empty():
		# No le cabe: el nodo sigue en pie para cuando vuelva con hueco.
		return
	proxy.set_meta("saved_inventory", inv)
	_ai_note_loot(b, got, "resource")
	record_strategy_outcome(int(b["bot_id"]), "forage", true, 0.06)
	if world.has_method("_net_world_action_completed"):
		world._net_world_action_completed(aid, [], "", pos, 0)
	var net = world.get("net")
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not is_bot_peer_id(pid) and not net.players[pid].get("offline", false) and net.peer_alive(pid):
				net.world_action_completed.rpc_id(pid, aid, [], "", pos)

# ¿Tiene la noche resuelta? Antorcha propia o fabricable al momento (palo +
# trapos), una fogata ya levantada o — con refugio propio — los 2+2 con los
# que la monta al volver a casa.
func _bot_night_fire_ready(b: Dictionary, proxy: Node3D) -> bool:
	if _bot_item_count(proxy, "Antorcha") > 0:
		return true
	if _bot_item_count(proxy, "Palo") >= 1 and _bot_item_count(proxy, "Trapos") >= 1:
		return true
	if not str(b.get("campfire_id", "")).is_empty():
		return true
	return not str(b.get("shelter_id", "")).is_empty() \
		and _bot_item_count(proxy, "Palo") >= 2 and _bot_item_count(proxy, "Piedra") >= 2

# Palos de los que dispone en la practica: los que lleva mas los que puede
# rajar de sus troncos (Tronco + filo -> 2 palos). Sin filo el tronco es lastre.
func _bot_palo_supply(proxy: Node3D, tool: String = "") -> int:
	var total := _bot_item_count(proxy, "Palo")
	var blade := tool if not tool.is_empty() else _bot_bush_tool(proxy)
	if not blade.is_empty():
		total += _bot_item_count(proxy, "Tronco") * 2
	return total

# Busqueda dirigida de material de fuego al anochecer: va solo a por lo que
# le falta para la antorcha (trapos/ropa cortable, palo) o la fogata
# (piedras, palos), ignorando el resto del botin.
func _find_fire_prep_loot(b: Dictionary, radius: float) -> Dictionary:
	if world == null or not ("_dropped_items" in world):
		return {}
	var proxy: Node3D = b["proxy"]
	var need_palo := _bot_palo_supply(proxy) < 2
	var need_piedra := _bot_item_count(proxy, "Piedra") < 2
	var need_trapos := _bot_item_count(proxy, "Trapos") < 1
	var need_torch := _bot_item_count(proxy, "Antorcha") < 1
	var best := {}
	var best_d := radius
	var depleted: Array = world.get("_depleted_action_ids") if "_depleted_action_ids" in world else []
	var claims: Dictionary = world.get("_pickup_claims") if "_pickup_claims" in world else {}
	var claims_until: Dictionary = world.get("_pickup_claim_until") if "_pickup_claim_until" in world else {}
	var now_ms := Time.get_ticks_msec()
	for entry in world._dropped_items:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		if id.is_empty() or depleted.has(id) or id.begins_with("bot_tame_meat_"):
			continue
		var cowner := int(claims.get(id, 0))
		if cowner != 0 and cowner != int(b["bot_id"]) and int(claims_until.get(id, 0)) > now_ms:
			continue
		if "world_actions_by_id" in world and world.world_actions_by_id.has(id):
			var wa = world.world_actions_by_id[id]
			if wa != null and is_instance_valid(wa) and wa.has_meta("dropped_by"):
				continue
		var nm := str(entry.get("name", ""))
		var useful := (need_torch and nm == "Antorcha") \
			or (need_palo and nm in ["Palo", "Tronco"]) \
			or (need_piedra and nm == "Piedra") \
			or (need_trapos and (nm == "Trapos" or _bot_cuts_into_trapos(nm)))
		if not useful:
			continue
		var item_d: Dictionary = _loot_entry_item_dict(entry)
		if not _bot_would_fit(b, proxy.get_meta("saved_inventory", []), item_d) \
				and not _bot_can_drop_for_fire(b, proxy.get_meta("saved_inventory", []), item_d):
			continue
		var pos := _loot_entry_pos(entry)
		if absf(pos.y - proxy.global_position.y) > 2.4 or _is_goal_blacklisted(b, pos):
			continue
		var d := Vector2(pos.x - proxy.global_position.x, pos.z - proxy.global_position.z).length()
		if d < best_d:
			best_d = d
			best = entry
	return best

# ¿Esta prenda se corta a trapos? Cierto si alguna receta con salida "Trapos"
# la acepta como insumo. Las herramientas ("Cuchillo" esta en TODAS esas
# recetas) no son prendas: sin este filtro el bot recolectaba cuchillos como
# si fueran ropa para cortar.
func _bot_cuts_into_trapos(nm: String) -> bool:
	if CraftingSystem._is_tool(nm):
		return false
	for r in CraftingSystem.RECIPES:
		if str((r.get("output", {}) as Dictionary).get("name", "")) == "Trapos" \
				and (r.get("inputs", {}) as Dictionary).has(nm):
			return true
	return false

# Mochila llena sin luz: por un objeto critico de fuego (antorcha, palo,
# tronco, trapos, ropa para cortar o piedra de fogata) vale soltar lo menos
# esencial — el resto de la noche pesa mas que el lastre. Solo cede lo que
# priorice por debajo o igual de lo que entra: nunca un rifle por un palo.
func _bot_can_drop_for_fire(b: Dictionary, inv: Array, item_dict: Dictionary) -> bool:
	var nm_i := str(item_dict.get("name", ""))
	if not (nm_i in ["Palo", "Tronco", "Trapos", "Antorcha", "Piedra"] or _bot_cuts_into_trapos(nm_i)):
		return false
	if not (_is_world_night() or _is_pre_night()) or _bot_item_count(b["proxy"], "Antorcha") > 0:
		return false
	var idx := _bot_least_essential_index(b, inv)
	if idx < 0:
		return false
	var junk: Dictionary = inv[idx]
	if _loot_priority(b, str(junk.get("name", "")), str(junk.get("type", ""))) \
			> _loot_priority(b, nm_i, str(item_dict.get("type", ""))):
		return false
	var inv2 := inv.duplicate()
	inv2.remove_at(idx)
	return _bot_would_fit(b, inv2, item_dict)

# De noche sin luz propia ni nada que hacer no se queda petrificado hasta el
# amanecer: ronda su zona en paseos cortos (8-16 m desde donde acampa), a
# paso lento y con pausas largas entre tramos — un superviviente ojea sus
# alrededores aunque no salga a explorar lejos. El saqueo y la recoleccion
# cercanos le siguen ganando si algo aparece en los sentidos, y cualquier
# amenaza corta el paseo. De dia, con antorcha o junto a un fuego encendido
# no aplica: el descanso sentado es lo correcto ahi.
func _bot_night_sentry_wander(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	if b.get("aggro_target") != null or float(b.get("hide_timer", 0.0)) > 0.0:
		return false
	if not _is_world_night() or _bot_item_count(proxy, "Antorcha") > 0 \
			or _is_near_any_lit_campfire(proxy.global_position, 8.0) or _bot_is_freezing(b):
		return false
	var wander: Dictionary = b.get("_night_wander", {})
	# Si se movio haciendo otra cosa desde la ultima vez (loot, huida,
	# recoleccion), la calma empieza de cero — solo cuenta el rato sentado.
	var lp: Variant = wander.get("last_pos", null)
	if lp is Vector3 and (lp as Vector3).distance_to(proxy.global_position) > 4.0:
		wander["idle_t"] = 0.0
		wander["pos"] = null
	wander["last_pos"] = proxy.global_position
	var anchor_v: Variant = wander.get("anchor", proxy.global_position)
	var anchor: Vector3 = anchor_v if anchor_v is Vector3 else proxy.global_position
	if Vector2(proxy.global_position.x - anchor.x, proxy.global_position.z - anchor.z).length() > 25.0:
		anchor = proxy.global_position
	var camp_v: Variant = b.get("camp_spot", null)
	if camp_v is Vector3 and Vector2(proxy.global_position.x - (camp_v as Vector3).x, proxy.global_position.z - (camp_v as Vector3).z).length() < 20.0:
		anchor = camp_v
	wander["anchor"] = anchor
	var tgt: Variant = wander.get("pos", null)
	var has_tgt: bool = tgt is Vector3 and Vector2(proxy.global_position.x - (tgt as Vector3).x, proxy.global_position.z - (tgt as Vector3).z).length() > 1.6
	if not has_tgt:
		# Primero se sienta un rato (~18 s de calma acumulada) antes de cada
		# paseo: la ronda sale del aburrimiento, no de forma inmediata — es
		# patrulla periodica, no paseo continuo ni deriva por la noche.
		wander["idle_t"] = float(wander.get("idle_t", 0.0)) + delta
		if float(wander["idle_t"]) < 18.0:
			b["_night_wander"] = wander
			return false
		# RNG local por bot y por tramo: no consume el stream global — la ronda
		# nocturna no altera el azar del resto del mundo (spawns, fauna, IA).
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b["bot_id"]) * 7919 + int(wander.get("n", 0)) * 104729
		for i in range(6):
			var ang := rng.randf() * TAU
			var rr := rng.randf_range(8.0, 16.0)
			var cand := anchor + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
			cand.y = proxy.global_position.y
			if _is_step_blocked(proxy.global_position, cand) or _is_goal_blacklisted(b, cand):
				continue
			wander["pos"] = cand
			wander["n"] = int(wander.get("n", 0)) + 1
			wander["idle_t"] = 0.0
			b["_night_wander"] = wander
			has_tgt = true
			break
		if not has_tgt:
			b["_night_wander"] = wander
			return false
		tgt = wander["pos"]
	b["sitting"] = false
	b["crouching"] = false
	proxy.set_meta("crouching", false)
	var tp: Vector3 = tgt
	_move_bot_towards(b, tp, 2.6, delta, "walk")
	b["_act"] = "wander"
	b["anim"] = "walk"
	if Vector2(proxy.global_position.x - tp.x, proxy.global_position.z - tp.z).length() <= 1.6:
		wander["pos"] = null
		wander["idle_t"] = 0.0
		wander["n"] = int(wander.get("n", 0)) + 1
		b["_night_wander"] = wander
	return true

# Ultimo recurso del helado sin fuego ni refugio ni lena alcanzable: un
# humano aterido no se tumba a congelarse — se mueve. Marcha continua en
# paseos cortos alrededor del sitio: el movimiento suma +0.4 C al objetivo
# termico y el tiempo en marcha seca la ropa; es supervivencia, no deriva.
# Solo sale al paso de _bot_try_cold_rescue cuando ya no queda nada real.
func _bot_freeze_march(b: Dictionary, delta: float) -> bool:
	var proxy: Node3D = b["proxy"]
	if not _bot_is_freezing(b) or bool(b.get("sleeping", false)):
		return false
	if b.get("aggro_target") != null or float(b.get("hide_timer", 0.0)) > 0.0:
		return false
	var fm: Dictionary = b.get("_freeze_march", {})
	var anchor_v: Variant = fm.get("anchor", proxy.global_position)
	var anchor: Vector3 = anchor_v if anchor_v is Vector3 else proxy.global_position
	if not anchor.is_finite() or Vector2(proxy.global_position.x - anchor.x, proxy.global_position.z - anchor.z).length() > 22.0:
		anchor = proxy.global_position
		fm["pos"] = null
	fm["anchor"] = anchor
	var tgt: Variant = fm.get("pos", null)
	# Un tramo vetado por el navegador deja de ser candidato inmediatamente.
	# Conservarlo hacia repetir el mismo destino bloqueado indefinidamente.
	var has_tgt: bool = tgt is Vector3 and (tgt as Vector3).is_finite() and not _is_goal_blacklisted(b, tgt) and Vector2(proxy.global_position.x - (tgt as Vector3).x, proxy.global_position.z - (tgt as Vector3).z).length() > 1.4
	if not has_tgt:
		fm["pos"] = null
		fm["stalled"] = 0.0
		# RNG local por bot y tramo: no consume el stream global, igual que
		# la ronda de _bot_night_sentry_wander. Marchar al agua moja mas —
		# la charca se descarta como destino de calentamiento.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b["bot_id"]) * 3571 + int(fm.get("n", 0)) * 104729
		# Avanzar tambien si fallan los seis sondeos: el proximo intento debe
		# probar otras direcciones, sin repetir para siempre la misma muestra.
		fm["n"] = int(fm.get("n", 0)) + 1
		for i in range(6):
			var ang := rng.randf() * TAU
			var rr := rng.randf_range(7.0, 13.0)
			var cand := anchor + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
			cand.y = proxy.global_position.y
			if _is_step_blocked(proxy.global_position, cand) or _is_goal_blacklisted(b, cand):
				continue
			if not InterruptionManager.dry_recovery_leg(world, proxy.global_position, cand):
				continue
			fm["pos"] = cand
			b["_freeze_march"] = fm
			has_tgt = true
			tgt = cand
			break
		if not has_tgt:
			b["_freeze_march"] = fm
			return false
	b["sitting"] = false
	b["crouching"] = false
	proxy.set_meta("crouching", false)
	var tp: Vector3 = tgt
	var before := proxy.global_position
	_move_bot_towards(b, tp, 3.6, delta, "walk")
	b["_act"] = "freeze_march"
	# El navegador decide la animacion; si una puerta u obstaculo detiene el
	# paso, no publicar walk mientras el cuerpo sigue quieto.
	var advanced := Vector2(proxy.global_position.x - before.x, proxy.global_position.z - before.z).length()
	fm["stalled"] = float(fm.get("stalled", 0.0)) + delta if advanced < 0.01 else 0.0
	if float(fm["stalled"]) >= 3.0:
		fm["pos"] = null
		fm["stalled"] = 0.0
	if Vector2(proxy.global_position.x - tp.x, proxy.global_position.z - tp.z).length() <= 1.4:
		fm["pos"] = null
		fm["n"] = int(fm.get("n", 0)) + 1
	b["_freeze_march"] = fm
	return true
