extends SceneTree

# Regresion Fase 1 (fiabilidad) del asesor de bots:
#  - Respuestas Qwen vacias/invalidas/imposibles -> decision local inmediata.
#  - Los resultados de los planes ensenyian la estrategia (preference/last_fail).
#  - Un objetivo imposible acumula strikes y se abandona con fallback local.
#  - Los contadores ai_stats (qwen/local/latencia/razones) se registran y salen
#    en el snapshot de estado.
#
# Run:
#   work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/BotPlanReliabilityRegression.gd

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

# Sondea hasta que el bot bid reciba su turno de _ai_sig_poll (round-robin).
func _poll_until(mgr, bid: int, max_calls: int = 6) -> void:
	for i in range(max_calls):
		mgr._ai_sig_poll(Time.get_ticks_msec())
		# Si el sondeo toco a este bot su firma o directiva ya se proceso; el
		# round-robin garantiza su turno dentro de bots.size() llamadas.

func run() -> void:
	var mem_path := "user://test_bot_plan_reliability_mem.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mem_path))
	var w := _make_world()
	var world: TestWorld = w[0]
	var mgr := SurvivorBotManagerScript.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.memory_path = mem_path
	mgr.setup(world)

	check(mgr.bots.size() == 3, "Se crean los 3 bots")
	var carlos: Dictionary = mgr.bots[902]
	var cmem: Dictionary = mgr._ensure_bot_memory(902)

	# --- 1) Validacion de respuestas Qwen ---
	check(mgr._ai_parse_decision("no es json", carlos).is_empty(),
		"Respuesta no-JSON de Qwen se rechaza")
	check(mgr._ai_parse_decision("{\"action\":\"fly_to_moon\"}", carlos).is_empty(),
		"Accion fuera del catalogo se rechaza")
	check(mgr._ai_parse_decision("{\"action\":{\"x\":1}}", carlos).is_empty(),
		"Campo action con tipo erroneo se rechaza")
	check(mgr._ai_parse_decision("{\"action\":\"explore\",\"target\":\"house:999:999\"}", carlos).is_empty(),
		"POI concreto desconocido se rechaza (anti-omnisciencia)")
	var ok_d := mgr._ai_parse_decision("{\"action\":\"explore\",\"target\":\"wild\",\"goal\":\"g\",\"priority\":4,\"reason\":\"r\"}", carlos)
	check(not ok_d.is_empty() and str(ok_d.get("action")) == "explore" and int(ok_d.get("priority")) == 4,
		"Decision valida pasa el catalogo")
	# Plan multi-paso: >4 rechaza, paso anidado rechaza, ubicacion desconocida rechaza
	var steps5: Array = []
	for i in range(5):
		steps5.append({"action": "explore", "target": "wild"})
	check(mgr._ai_parse_plan(JSON.stringify({"steps": steps5}), carlos).is_empty(),
		"Plan de mas de 4 pasos se rechaza")
	check(mgr._ai_parse_plan(JSON.stringify({"steps": [{"action": "explore", "steps": []}]}), carlos).is_empty(),
		"Plan con paso anidado se rechaza")
	check(mgr._ai_parse_plan(JSON.stringify({"steps": [{"action": "explore", "target": "house:5:5"}]}), carlos).is_empty(),
		"Plan con ubicacion desconocida se rechaza")
	check(mgr._ai_parse_plan(JSON.stringify({"steps": [{"action": "forage"}, {"action": "return_home"}]}), carlos).size() == 2,
		"Plan valido de 2 pasos se acepta")

	# --- 2) Respuesta HTTP valida -> directiva aplicada + metricas ---
	carlos["proxy"].global_position = Vector3(50.0, 0.4, 50.0)
	mgr._ai_pending_bot = 902
	mgr._ai_pending_model = "qwen/qwen3.8-27b"
	mgr._ai_last_call_msec[902] = Time.get_ticks_msec() - 1500
	var body_ok := {"choices": [{"message": {"content": "{\"action\":\"explore\",\"target\":\"wild\",\"goal\":\"scout\",\"priority\":3,\"reason\":\"survey\"}"}}], "usage": {"total_tokens": 120}}
	mgr._ai_on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(body_ok).to_utf8_buffer())
	var d_after: Dictionary = carlos.get("ai_directive", {})
	check(str(d_after.get("action", "")) == "explore",
		"Respuesta 200 valida aplica la directiva (action=%s)" % str(d_after.get("action", "")))
	var st0: Dictionary = cmem.get("ai_stats", {})
	check(int(st0.get("qwen_ok", 0)) >= 1, "ai_stats.qwen_ok registra la respuesta buena")
	check(int(st0.get("latency_ms_last", 0)) >= 1400,
		"ai_stats.latency_ms_last mide la llamada real (%.0f ms)" % float(st0.get("latency_ms_last", 0)))
	check(int(st0.get("latency_ms_avg", 0)) > 0, "ai_stats.latency_ms_avg acumula media movil")
	check(int(st0.get("steps_done", 0)) >= 1, "ai_stats.steps_done cuenta el paso aplicado")

	# --- 3a) Respuesta invalida con plan vivo NO lo derriba (inercia) ---
	(carlos["ai_directive"] as Dictionary)["priority"] = 5
	var cur_goal := str(carlos.get("ai_directive", {}).get("goal", ""))
	mgr._ai_pending_bot = 902
	mgr._ai_pending_model = "qwen/qwen3.8-27b"
	mgr._ai_last_call_msec[902] = Time.get_ticks_msec() - 800
	var body_bad := {"choices": [{"message": {"content": "seguro que un buen plan"}}]}
	mgr._ai_on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(body_bad).to_utf8_buffer())
	var st1: Dictionary = cmem.get("ai_stats", {})
	check(int(st1.get("qwen_invalid", 0)) >= 1, "ai_stats.qwen_invalid cuenta la respuesta imposible")
	var fr1: Dictionary = st1.get("fallback_reasons", {})
	check(int(fr1.get("invalid_or_impossible_decision", 0)) >= 1,
		"fallback_reasons guarda el motivo (invalid_or_impossible_decision)")
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == cur_goal,
		"La respuesta basura no derriba el plan vigente")

	# --- 3b) Sin directiva, el mismo fallo aplica el fallback local inmediato ---
	carlos["ai_directive"] = {}
	var ld0 := int(cmem.get("ai_stats", {}).get("local_decisions", 0))
	mgr._ai_pending_bot = 902
	mgr._ai_pending_model = "qwen/qwen3.8-27b"
	mgr._ai_last_call_msec[902] = Time.get_ticks_msec() - 400
	mgr._ai_on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(body_bad).to_utf8_buffer())
	var st1b: Dictionary = cmem.get("ai_stats", {})
	check(int(st1b.get("local_decisions", 0)) == ld0 + 1, "ai_stats.local_decisions cuenta el fallback inmediato")
	check(str(carlos.get("ai_directive", {}).get("source", "")) == "local_fallback",
		"El fallback local queda marcado como source=local_fallback")

	# --- 4) 429 -> backoff + fallback local contado ---
	mgr._ai_pending_bot = 902
	mgr._ai_last_call_msec[902] = Time.get_ticks_msec() - 300
	var c429 := int(mgr._ai_429_count)
	mgr._ai_on_response(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), "rate limited".to_utf8_buffer())
	check(int(mgr._ai_429_count) == c429 + 1, "HTTP 429 incrementa el contador de backoff")
	var st2: Dictionary = cmem.get("ai_stats", {})
	check(int((st2.get("fallback_reasons", {}) as Dictionary).get("http_429_backoff", 0)) >= 1,
		"fallback_reasons registra http_429_backoff")

	# --- 5) Plan completado ensenyia la estrategia ---
	carlos["hunger"] = 100.0
	carlos["health"] = 90.0
	carlos["ai_directive"] = {"goal": "eat", "action": "forage", "mode": "food", "until": Time.get_ticks_msec() + 60000}
	_poll_until(mgr, 902)
	var strats1: Dictionary = cmem.get("strategies", {})
	check(strats1.has("forage") and int((strats1["forage"] as Dictionary).get("success", 0)) >= 1,
		"Plan 'forage' completado suma exito a su estrategia")
	check(str(carlos.get("_plan_last_result", "")) == "plan_completed",
		"_plan_last_result marca plan_completed")
	check(int(cmem.get("ai_stats", {}).get("plans_completed", 0)) >= 1,
		"ai_stats.plans_completed cuenta el plan cerrado")

	# --- 6) Siguiente paso imposible -> precondition_failed + fail aprendido ---
	carlos["hunger"] = 100.0
	carlos["shelter_pos"] = Vector3.INF
	carlos["shelter_id"] = ""
	carlos["camp_spot"] = Vector3.INF
	carlos["ai_directive"] = {"goal": "eat_then_rest", "action": "forage", "mode": "food",
		"until": Time.get_ticks_msec() + 60000,
		"_remaining_steps": [{"action": "rest", "goal": "sleep"}]}
	_poll_until(mgr, 902)
	check(str(carlos.get("_plan_last_result", "")) == "precondition_failed",
		"Paso 'rest' sin hogar -> precondition_failed")
	var strats2: Dictionary = cmem.get("strategies", {})
	check(strats2.has("rest") and int((strats2["rest"] as Dictionary).get("fail", 0)) >= 1
			and str((strats2["rest"] as Dictionary).get("last_fail", "")) == "precondition",
		"Fallo de requisitos aprende causa 'precondition' en la estrategia")
	check(int(cmem.get("ai_stats", {}).get("plans_failed", 0)) >= 1,
		"ai_stats.plans_failed cuenta el plan fallido")

	# --- 7) Objetivo imposible persistente -> abandono tras strikes ---
	carlos["hunger"] = 100.0
	carlos["health"] = 40.0 # 'rest' nunca se completa con hp/sueno bajos
	(carlos["vstats"] as SurvivalStats).sleep = 20.0
	var past := Time.get_ticks_msec() - int(1600.0 * 1000.0)
	carlos["ai_directive"] = {"goal": "impossible_goal", "action": "rest", "mode": "pos",
		"pos": Vector3(999999.0, 0.4, 999999.0), "until": past}
	for i in range(6): # 2 turnos de sondeo para 902 = 2 strikes
		mgr._ai_sig_poll(Time.get_ticks_msec())
	check((carlos.get("ai_directive", {}) as Dictionary).is_empty()
			or str(carlos.get("ai_directive", {}).get("goal", "")) != "impossible_goal",
		"El objetivo imposible se abandona tras los strikes")
	var strats3: Dictionary = cmem.get("strategies", {})
	check(strats3.has("rest") and str((strats3["rest"] as Dictionary).get("last_fail", "")) == "stuck_timeout",
		"El abandono registra causa 'stuck_timeout'")
	check(int(cmem.get("ai_stats", {}).get("blocked_recoveries", 0)) >= 1,
		"ai_stats.blocked_recoveries cuenta la recuperacion")

	# --- 8) Snapshot de diagnostico expone ai_stats y blocked ---
	var snap := mgr.get_bot_debug_snapshot(902)
	check(snap.has("ai_stats") and (snap["ai_stats"] as Dictionary).has("qwen_ok"),
		"El snapshot expone ai_stats")
	check(snap.has("blocked"), "El snapshot expone el flag blocked")
	check(snap.has("last_plan_result"), "El snapshot expone last_plan_result")

	# --- 9) Fallback local decide algo valido (cerebro local siempre responde) ---
	carlos["ai_directive"] = {}
	var local_d := mgr._ai_apply_local_fallback_decision(902, "test_reason")
	check(not local_d.is_empty() and str(local_d.get("action", "")) != "",
		"El fallback local siempre devuelve una accion ejecutable")
	check(str(carlos.get("ai_directive", {}).get("source", "")) == "local_fallback",
		"La decision local queda etiquetada")

	# --- 10) Reanudar objetivo persistido (solo arranque de sesion) ---
	carlos["ai_directive"] = {}
	cmem["pending_goals"] = [{"action": "explore", "target": "wild", "goal": "resume_g", "priority": 3, "reason": "saved"}]
	mgr._ai_resume_pending_plan(902)
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == "resume_g",
		"El plan persistido se reanuda al arrancar")
	check(str(carlos.get("ai_directive", {}).get("source", "")) == "memory",
		"El plan reanudado queda marcado source=memory")
	check(str(carlos.get("_plan_last_result", "")) == "plan_resumed",
		"_plan_last_result marca plan_resumed")
	check(int(cmem.get("ai_stats", {}).get("plans_resumed", 0)) >= 1,
		"ai_stats.plans_resumed cuenta la reanudacion")
	# Pendiente invalido (POI desconocido) no se reanuda
	carlos["ai_directive"] = {}
	cmem["pending_goals"] = [{"action": "explore", "target": "house:1234:5678"}]
	mgr._ai_resume_pending_plan(902)
	check((carlos.get("ai_directive", {}) as Dictionary).is_empty(),
		"Un plan persistido imposible no se reanuda")
	# Pendiente vacio no toca la directiva
	carlos["ai_directive"] = {"goal": "keep", "action": "explore", "mode": "poi", "only_kinds": ["wild"]}
	cmem["pending_goals"] = []
	mgr._ai_resume_pending_plan(902)
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == "keep",
		"Sin pendientes, la directiva vigente no se toca")

	# --- 11) Inercia de objetivo: mismo plan conserva progreso ---
	carlos["ai_directive"] = {}
	var plan1 := {"steps": [{"action": "explore", "target": "wild", "goal": "route_a", "priority": 3}, {"action": "forage", "goal": "tail"}]}
	check(mgr._ai_apply_decision(902, JSON.stringify(plan1)),
		"Plan de 2 pasos se aplica")
	(carlos["ai_directive"] as Dictionary)["_visit_done"] = true
	var until0 := int((carlos["ai_directive"] as Dictionary).get("until", 0))
	await create_timer(0.02).timeout
	check(mgr._ai_apply_decision(902, JSON.stringify(plan1)),
		"Reemitir el plan identico se acepta")
	check(bool((carlos["ai_directive"] as Dictionary).get("_visit_done", false)),
		"El plan reemitido conserva el progreso (_visit_done)")
	check(int((carlos["ai_directive"] as Dictionary).get("until", 0)) >= until0,
		"El plan reemitido extiende su vigencia")
	check((carlos["ai_directive"] as Dictionary).has("_applied_at"),
		"La directiva registra _applied_at")

	# --- 12) Plan joven no se desbanca por prioridad igual o menor ---
	var kept_n0 := int(cmem.get("ai_stats", {}).get("plan_kept", 0))
	var plan_low := {"steps": [{"action": "forage", "goal": "different_goal", "priority": 2}]}
	check(mgr._ai_apply_decision(902, JSON.stringify(plan_low)),
		"Plan distinto devuelve exito aunque no desbanque")
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == "route_a",
		"Un plan joven sobrevive a una revalidacion de menor prioridad")
	check(int(cmem.get("ai_stats", {}).get("plan_kept", 0)) == kept_n0 + 1,
		"ai_stats.plan_kept cuenta el objetivo conservado")
	# Prioridad estricta mayor si desbanca
	var plan_hi := {"steps": [{"action": "forage", "goal": "urgent_goal", "priority": 5}]}
	mgr._ai_apply_decision(902, JSON.stringify(plan_hi))
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == "urgent_goal",
		"Una prioridad estricta mayor si desbanca el plan joven")
	# Y un plan viejo (>= AI_DIRECTIVE_MIN_COMMIT_SEC) siempre cede
	(carlos["ai_directive"] as Dictionary)["_applied_at"] = Time.get_ticks_msec() - 400000
	var plan_old := {"steps": [{"action": "explore", "target": "wild", "goal": "old_replaced", "priority": 1}]}
	mgr._ai_apply_decision(902, JSON.stringify(plan_old))
	check(str(carlos.get("ai_directive", {}).get("goal", "")) == "old_replaced",
		"Un plan viejo cede aunque llegue prioridad menor")

	world.free()
	if failures == 0:
		print("BotPlanReliabilityRegression: ALL PASS")
	else:
		print("BotPlanReliabilityRegression: %d FAILURES" % failures)
	quit(1 if failures else 0)
