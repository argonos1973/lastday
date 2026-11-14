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
	check(int(st0.get("steps_started", 0)) >= 1, "ai_stats.steps_started cuenta el paso iniciado")

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

	# === CORRECCIONES (revision posterior a las 5 fases) ===

	# --- 13) Un POI inalcanzable NO se registra como visitado ---
	var pois: Array = mgr._explore_pois()
	var poi0: Dictionary = pois[0]
	var poi0_id := mgr._poi_id(poi0)
	var poi0_pos: Vector3 = poi0["pos"]
	var vis_arr: Array = cmem.get("visited", [])
	vis_arr.erase(poi0_id)
	carlos["_visited"] = vis_arr
	carlos["explore_target"] = poi0_pos
	carlos["ai_directive"] = {"goal": "unreach", "action": "explore", "target": str(poi0.get("kind", "wild")), "mode": "pos", "pos": poi0_pos}
	mgr._abandon_unreachable_goal(carlos, poi0_pos)
	var vis1: Array = cmem.get("visited", [])
	check(not vis1.has(poi0_id),
		"El POI inalcanzable NO queda en visited (nunca llego)")
	var un: Dictionary = cmem.get("unreachable_pois", {})
	check(un.has(poi0_id),
		"El POI queda vetado como inalcanzable en la memoria")
	check((carlos.get("ai_directive", {}) as Dictionary).is_empty()
			or not bool((carlos["ai_directive"] as Dictionary).get("_visit_done", false)),
		"La directiva no gano _visit_done por un sitio no alcanzado")
	check(str(carlos.get("_plan_last_result", "")) == "nav_unreachable",
		"El abandono distingue la causa nav_unreachable")
	check(int(cmem.get("ai_stats", {}).get("steps_failed", 0)) >= 1,
		"ai_stats.steps_failed cuenta el paso no ejecutado")
	check(mgr._is_poi_unreachable(carlos, poi0_id),
		"_is_poi_unreachable veta el punto en futuras elecciones")
	# La estrategia explore_<kind> NO recibio un exito falso
	var strats_u: Dictionary = cmem.get("strategies", {})
	var ek := "explore_" + str(poi0.get("kind", "wild"))
	var suc_u := int((strats_u.get(ek, {}) as Dictionary).get("success", 0)) if strats_u.has(ek) else 0
	check(suc_u == 0 or not un.has(poi0_id),
		"El fallo de navegacion no suma exito de exploracion falso")

	# --- 14) Llegar no es cumplir: scavenge exige botin real ---
	carlos["ai_directive"] = {}
	carlos["_loot_n"] = 0
	mgr._ai_apply_decision(902, JSON.stringify({"action": "scavenge", "target": "city", "goal": "loot_trip", "priority": 4}))
	var sc_d: Dictionary = carlos["ai_directive"]
	check(str(sc_d.get("action", "")) == "scavenge", "Directiva scavenge aplicada")
	carlos["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	check(not mgr._ai_directive_completed(carlos, sc_d),
		"Estar en la ciudad sin botin NO completa el scavenge")
	mgr._ai_note_loot(carlos, "Vendaje", "medical")
	check(mgr._ai_directive_completed(carlos, sc_d),
		"Recoger un objeto SI completa el scavenge")

	# --- 15) Cada subobjetivo registra su resultado ---
	cmem["strategies"] = {}
	cmem["pending_goals"] = []
	carlos["ai_directive"] = {}
	var steps0 := int(cmem.get("ai_stats", {}).get("steps_started", 0))
	var plan_sc := {"steps": [
		{"action": "scavenge", "target": "city", "goal": "gear_up", "priority": 3},
		{"action": "forage", "goal": "eat_after", "priority": 3}]}
	mgr._ai_apply_decision(902, JSON.stringify(plan_sc))
	check(int(cmem.get("ai_stats", {}).get("steps_started", 0)) == steps0 + 1,
		"El paso 1 quedo registrado como iniciado")
	# Paso 1 cumple de verdad (botin recogido) -> avanza al paso 2
	mgr._ai_note_loot(carlos, "Chaleco", "gear")
	mgr._ai_sig_poll(Time.get_ticks_msec())
	mgr._ai_sig_poll(Time.get_ticks_msec())
	mgr._ai_sig_poll(Time.get_ticks_msec())
	var strats_sc: Dictionary = cmem.get("strategies", {})
	check(strats_sc.has("scavenge") and int((strats_sc["scavenge"] as Dictionary).get("success", 0)) >= 1,
		"El paso scavenge registro su propio exito")
	check(int(cmem.get("ai_stats", {}).get("steps_completed", 0)) >= 1,
		"ai_stats.steps_completed cuenta el paso cumplido")
	check(str(carlos.get("ai_directive", {}).get("action", "")) == "forage",
		"El plan avanzo al siguiente subobjetivo")
	check(str(carlos.get("ai_directive", {}).get("_plan_root", "")) == "scavenge",
		"La raiz del plan sobrevive al avance de paso")

	# --- 16) Paso parado: sin progreso -> fallo rapido + alternativa ---
	carlos["ai_directive"] = {}
	carlos["hunger"] = 100.0
	var plan_stall := {"steps": [
		{"action": "return_home", "goal": "back", "priority": 3},
		{"action": "forage", "goal": "then_eat", "priority": 3}]}
	carlos["shelter_pos"] = Vector3(999999.0, 0.4, 999999.0)
	mgr._ai_apply_decision(902, JSON.stringify(plan_stall))
	carlos["proxy"].global_position = Vector3(10.0, 0.4, 10.0)
	# Quieto y sin trabajo legitimo en el camino (saqueo/huida/combate eximen).
	carlos["aggro_target"] = null
	carlos["flee_until"] = 0.0
	carlos["hide_timer"] = 0.0
	for bk in ["_gather", "_s_loot", "_craft_state", "_ambush", "_forage", "_salvage"]:
		carlos[bk] = {}
	carlos["sitting"] = false
	# Baseline fijada hace "2 min" (el reloj del test arranca en ~3 s: se
	# simula llamando al watchdog con un now_ms adelantado).
	(carlos["ai_directive"] as Dictionary)["_prog_ref_ms"] = 1
	(carlos["ai_directive"] as Dictionary)["_prog_ref_m"] = 100.0
	var stall_res := mgr._ai_step_stalled(carlos, carlos["ai_directive"], Time.get_ticks_msec() + 200000)
	check(stall_res == "no_progress",
		"Un paso sin ganancia de distancia se declara no_progress (=%s)" % stall_res)
	mgr._ai_fail_stalled_step(902, carlos, carlos["ai_directive"], stall_res)
	var fg: Dictionary = cmem.get("failed_goals", {})
	check(not fg.is_empty(), "El objetivo parado queda en failed_goals")
	check(int(cmem.get("ai_stats", {}).get("steps_failed", 0)) >= 1
			and int(cmem.get("ai_stats", {}).get("blocked_recoveries", 0)) >= 1,
		"El paso parado cuenta steps_failed + blocked_recoveries")
	var act_now := str(carlos.get("ai_directive", {}).get("action", ""))
	check(act_now == "forage" or not (carlos.get("ai_directive", {}) as Dictionary).is_empty(),
		"Tras el fallo intenta alternativa (siguiente paso o decision local)")

	# --- 17) Un objetivo fallido no se reemite ni se reanuda ---
	carlos["ai_directive"] = {}
	cmem["pending_goals"] = [{"action": "return_home", "goal": "back", "priority": 3}]
	mgr._ai_resume_pending_plan(902)
	check(str(carlos.get("ai_directive", {}).get("goal", "")) != "back",
		"El plan que ya fracaso no reaparece al reanudar")
	var reem := mgr._ai_parse_plan(JSON.stringify({"steps": [{"action": "return_home", "goal": "back"}]}), carlos)
	check(reem.is_empty(),
		"Un paso con firma recien fallida se rechaza en _ai_parse_plan")

	# --- 18) La firma de situacion incluye los factores nuevos ---
	carlos["ai_directive"] = {}
	carlos["_unreachable"] = []
	var sig_a := mgr._ai_situation_signature(carlos)
	carlos["_unreachable"] = [{"pos": Vector3(1, 0, 1), "until": float(Time.get_ticks_msec()) / 1000.0 + 60.0}]
	var sig_b := mgr._ai_situation_signature(carlos)
	check(sig_a != sig_b, "La firma cambia cuando aparece un objetivo bloqueado")
	carlos["_unreachable"] = []
	check(sig_a == mgr._ai_situation_signature(carlos),
		"La firma vuelve a su valor al resolverse el bloqueo")

	# --- 19) Una emergencia interrumpe el plan sin destruirlo ---
	carlos["ai_directive"] = {"goal": "resupply", "action": "scavenge", "mode": "pos",
		"pos": Vector3(300.0, 0.4, 300.0), "until": Time.get_ticks_msec() + 600000,
		"priority": 3, "source": "qwen"}
	carlos["flee_until"] = 9.0
	check(not mgr._ai_bot_eligible(carlos),
		"Bajo huida el asesor no reevalua: la emergencia tiene prioridad")
	check(mgr._ai_step_busy(carlos),
		"La huida cuenta como actividad legitima (no es quedarse parado)")
	var stall_flee := mgr._ai_step_stalled(carlos, carlos["ai_directive"], Time.get_ticks_msec() + 95000)
	check(stall_flee == "" or stall_flee == "timeout",
		"Huyendo no se declara no_progress (=%s)" % stall_flee)
	check(not (carlos.get("ai_directive", {}) as Dictionary).is_empty(),
		"El plan sobrevive a la emergencia y se reanuda despues")
	carlos["flee_until"] = 0.0
	check(mgr._ai_bot_eligible(carlos),
		"Pasada la emergencia el asesor vuelve a evaluar al bot")

	# --- 20) El veto de objetivo fallido es de LUGAR, no de categoria ---
	carlos["ai_directive"] = {}
	cmem["failed_goals"] = {}
	var zone_a := Vector3(500.0, 0.4, 500.0)
	mgr._ai_note_failed_goal(carlos, {"action": "scavenge", "target": "city", "pos": zone_a}, "no_progress")
	check(mgr._ai_goal_recently_failed(carlos, {"action": "scavenge", "target": "city", "pos": zone_a}),
		"El fracaso veta el mismo objetivo en la misma zona")
	check(not mgr._ai_goal_recently_failed(carlos, {"action": "scavenge", "target": "city", "pos": zone_a + Vector3(400.0, 0, 0)}),
		"Saquear OTRA zona de ciudad no queda vetado")
	check(not mgr._ai_goal_recently_failed(carlos, {"action": "forage", "target": "wild", "pos": zone_a}),
		"Otra actividad en la misma zona no queda vetada")
	# El veto respeta la vigencia de su causa (no_progress ~3 h aqui).
	var fg_z: Dictionary = cmem.get("failed_goals", {})
	var sig_z := mgr._ai_failed_goal_sig({"action": "scavenge", "target": "city", "pos": zone_a}, carlos)
	(fg_z[sig_z] as Dictionary)["t"] = Time.get_unix_time_from_system() - 40000.0
	check(not mgr._ai_goal_recently_failed(carlos, {"action": "scavenge", "target": "city", "pos": zone_a}),
		"El veto caduca pasada la vigencia de su causa")

	# --- 21) Un plan de un paso registra exactamente UN exito ---
	cmem["strategies"] = {}
	carlos["ai_directive"] = {}
	mgr._ai_apply_decision(902, JSON.stringify({"steps": [{"action": "explore", "target": "wild"}]}))
	mgr._ai_advance_plan(902, carlos, carlos["ai_directive"])
	var suc_e: int = int((cmem.get("strategies", {}).get("explore", {}) as Dictionary).get("success", 0))
	var suc_pe: int = int((cmem.get("strategies", {}).get("plan:explore", {}) as Dictionary).get("success", 0))
	check(suc_e == 1 and suc_pe == 1,
		"Plan de un paso: 1 exito de accion + 1 de plan en namespaces distintos (=%d/%d)" % [suc_e, suc_pe])
	# Plan de dos pasos: cada accion registra su paso y el global va a plan:<raiz>.
	cmem["strategies"] = {}
	carlos["ai_directive"] = {}
	carlos["shelter_pos"] = Vector3(600.0, 0.4, 600.0)
	mgr._ai_apply_decision(902, JSON.stringify({"steps": [
		{"action": "explore", "target": "wild"},
		{"action": "return_home", "goal": "back"}]}))
	var d_two: Dictionary = carlos["ai_directive"]
	mgr._ai_advance_plan(902, carlos, d_two) # completa paso 1 -> aplica paso 2
	mgr._ai_advance_plan(902, carlos, carlos["ai_directive"]) # completa paso 2 -> plan
	var strats_two: Dictionary = cmem.get("strategies", {})
	check(int((strats_two.get("explore", {}) as Dictionary).get("success", 0)) == 1
			and int((strats_two.get("return_home", {}) as Dictionary).get("success", 0)) == 1
			and int((strats_two.get("plan:explore", {}) as Dictionary).get("success", 0)) == 1,
		"Plan de dos pasos: 2 resultados de accion + 1 global de plan (explore=%d, return_home=%d, plan:explore=%d)"
		% [int((strats_two.get("explore", {}) as Dictionary).get("success", 0)),
			int((strats_two.get("return_home", {}) as Dictionary).get("success", 0)),
			int((strats_two.get("plan:explore", {}) as Dictionary).get("success", 0))])

	# --- 22) Los fracasos y vetos sobreviven al reinicio (memoria persistida) ---
	mgr._ai_note_failed_goal(carlos, {"action": "return_home", "goal": "back", "pos": Vector3(900.0, 0.4, 900.0)}, "nav_blocked")
	cmem["unreachable_pois"] = {"house:900:900": {"n": 2, "t": Time.get_unix_time_from_system(), "cause": "nav_blocked"}}
	(cmem["failed_goals"] as Dictionary)["explore|stale|0:0"] = {"t": Time.get_unix_time_from_system() - 99999.0, "cause": "nav_blocked", "ttl": 21600.0}
	mgr.force_memory_io = true
	mgr._ai_save_memory()
	mgr._ai_flush_writes()
	var mgr3 := SurvivorBotManagerScript.new()
	mgr3.name = "SurvivorBotManagerMem"
	world.add_child(mgr3)
	mgr3.memory_path = mem_path
	mgr3.force_memory_io = true
	mgr3.setup(world)
	var cmem3: Dictionary = mgr3._ensure_bot_memory(902)
	var fg3: Dictionary = cmem3.get("failed_goals", {})
	check(not fg3.is_empty(), "failed_goals sobrevive al reinicio del servidor")
	check(mgr3._ai_goal_recently_failed(mgr3.bots[902], {"action": "return_home", "goal": "back", "pos": Vector3(900.0, 0.4, 900.0)}),
		"El bot recuerda el objetivo inalcanzable tras reiniciar")
	check(not fg3.has("explore|stale|0:0"),
		"Los registros caducados se podan al cargar la memoria")
	check((cmem3.get("unreachable_pois", {}) as Dictionary).has("house:900:900"),
		"unreachable_pois sobrevive al reinicio del servidor")

	# --- 23) Progreso medido por la actividad, no solo por el viaje ---
	carlos["ai_directive"] = {}
	for bk2 in ["_gather", "_s_loot", "_craft_state", "_ambush", "_forage", "_salvage"]:
		carlos[bk2] = {}
	carlos["aggro_target"] = null
	carlos["sitting"] = false
	carlos["sleeping"] = false
	carlos["gut_target"] = null
	var fdir := {"action": "forage", "goal": "eat", "mode": "food",
		"until": Time.get_ticks_msec() + 600000}
	carlos["ai_directive"] = fdir
	# Baseline en el pasado, reloj adelantado: sin evidencia seria no_progress.
	fdir["_prog_ref_ms"] = 1
	var t_probe := Time.get_ticks_msec() + 95000
	check(mgr._ai_step_stalled(carlos, fdir, t_probe) == "no_progress",
		"Forrajear sin recoger nada en 90 s es no_progress")
	# La misma ventana con botin nuevo: la evidencia renueva el progreso.
	fdir["_prog_ref_ms"] = 1
	carlos["_loot_food_n"] = int(carlos.get("_loot_food_n", 0)) + 1
	check(mgr._ai_step_stalled(carlos, fdir, t_probe) != "no_progress",
		"Forrajear con comida recogida cuenta como progreso real")
	# Y durmiendo en el paso de descanso el bot esta ocupado, no atascado.
	var rdir := {"action": "rest", "goal": "sleep", "mode": "pos",
		"pos": Vector3(50.0, 0.4, 50.0), "until": Time.get_ticks_msec() + 600000,
		"_prog_ref_ms": 1, "_prog_ref_m": 0.0}
	carlos["proxy"].global_position = Vector3(50.0, 0.4, 50.0)
	carlos["sleeping"] = true
	carlos["vstats"].sleep = 30.0
	var t_probe2 := Time.get_ticks_msec() + 95000
	check(mgr._ai_step_stalled(carlos, rdir, t_probe2) != "no_progress",
		"Dormido descansando no se declara atascado")
	carlos["sleeping"] = false
	# avoid_zone: alejarse de la zona vetada es progreso aunque no haya destino.
	# POI cache controlado (una sola "city") para que la medida sea determinista.
	var poi_save: Array = mgr._poi_cache
	var built_save: bool = mgr._poi_cache_built
	mgr._poi_cache = [{"pos": Vector3(1000.0, 0.4, 1000.0), "kind": "city"}]
	mgr._poi_cache_built = true
	var adir := {"action": "avoid_zone", "goal": "flee", "mode": "avoid",
		"avoid_kinds": ["city"], "until": Time.get_ticks_msec() + 600000,
		"_prog_ref_ms": 1}
	carlos["proxy"].global_position = Vector3(1030.0, 0.4, 1000.0) # ~30 m de la ciudad
	var ev_a := mgr._ai_step_evidence(carlos, adir)
	carlos["proxy"].global_position = Vector3(1150.0, 0.4, 1000.0) # ~150 m
	var ev_b := mgr._ai_step_evidence(carlos, adir)
	check(ev_b > ev_a, "Alejarse de la zona vetada sube la evidencia de progreso")
	mgr._poi_cache = poi_save
	mgr._poi_cache_built = built_save

	# === CICLO 3: destino unico, pista honesta, namespaces, contexto a Qwen ===

	# --- 24) El paso fija UN destino: plan, navegacion, visita y veto coinciden ---
	var built_save2: bool = mgr._poi_cache_built
	var poi_save2: Array = mgr._poi_cache
	mgr._poi_cache = [
		{"pos": Vector3(120.0, 0.4, 0.0), "kind": "city"},
		{"pos": Vector3(240.0, 0.4, 0.0), "kind": "city"},
		{"pos": Vector3(60.0, 0.4, 900.0), "kind": "wild"}]
	mgr._poi_cache_built = true
	cmem["visited"] = []
	carlos["_visited"] = []
	cmem["failed_goals"] = {}
	cmem["unreachable_pois"] = {}
	carlos["_unreachable"] = []
	cmem.erase("last_death_pos")
	carlos["ai_directive"] = {}
	carlos["proxy"].global_position = Vector3(0.0, 0.4, 0.0)
	check(mgr._ai_apply_decision(902, JSON.stringify({"steps": [{"action": "explore", "target": "city"}]})),
		"El paso poi se aplica habiendo POIs validos")
	var d_pin: Dictionary = carlos["ai_directive"]
	var dp_pos: Vector3 = d_pin.get("_dest_pos", Vector3.INF)
	var dp_id := str(d_pin.get("_dest_id", ""))
	check(dp_pos != Vector3.INF and not dp_id.is_empty(),
		"La directiva fija un destino unico (_dest_pos/_dest_id)")
	var expected_pick := (mgr._ai_pick_poi(carlos, ["city"], [], false) as Dictionary).get("pos", Vector3.INF)
	check(dp_pos == expected_pick,
		"El destino fijado es el que elige el criterio de navegacion")
	check(mgr._ai_step_target_pos(carlos, d_pin) == dp_pos,
		"El progreso mide contra el destino fijado")
	check(mgr._choose_explore_target(carlos) == dp_pos,
		"La navegacion va al destino fijado, no al poi mas cercano")
	# Pasar por el otro POI del mismo tipo NO cumple la visita del plan.
	var other_p: Dictionary = {}
	for p in mgr._poi_cache:
		if str(p.get("kind", "")) == "city" and mgr._poi_id(p) != dp_id:
			other_p = p
	check(not other_p.is_empty(), "Hay un segundo POI city para el caso")
	carlos["proxy"].global_position = other_p["pos"]
	mgr._mark_poi_visited(carlos, other_p["pos"])
	check(not bool(d_pin.get("_visit_done", false)),
		"Otro POI del mismo tipo no marca la visita del plan")
	carlos["proxy"].global_position = dp_pos
	mgr._mark_poi_visited(carlos, dp_pos)
	check(bool(d_pin.get("_visit_done", false)),
		"El POI fijado si marca la visita")
	# Si el destino queda vetado, se repieza OTRO lugar valido y se refija.
	var pin_a: Vector3 = (mgr._poi_cache[0] as Dictionary)["pos"]
	var pin_b: Vector3 = (mgr._poi_cache[1] as Dictionary)["pos"]
	cmem["visited"] = []
	carlos["_visited"] = []
	carlos["ai_directive"] = {"action": "explore", "mode": "poi", "only_kinds": ["city"],
		"_dest_pos": pin_a, "_dest_id": mgr._poi_id(mgr._poi_cache[0])}
	carlos["_unreachable"] = [{"pos": pin_a, "until": float(Time.get_ticks_msec()) / 1000.0 + 60.0}]
	var new_tgt := mgr._choose_explore_target(carlos)
	check(new_tgt == pin_b,
		"Destino vetado: la navegacion repieza el otro POI valido")
	check(str((carlos["ai_directive"] as Dictionary).get("_dest_id", "")) == mgr._poi_id(mgr._poi_cache[1]),
		"El refijado actualiza _dest_id coherentemente")
	carlos["_unreachable"] = []
	carlos["ai_directive"] = {}
	mgr._poi_cache = poi_save2
	mgr._poi_cache_built = built_save2

	# --- 25) El asesor recibe fracasos vigentes e inalcanzables, no caducados ---
	var fg2: Dictionary = cmem.get("failed_goals", {})
	fg2["scavenge|city|3:3"] = {"t": Time.get_unix_time_from_system(), "cause": "nav_blocked",
		"ttl": 21600.0, "act": "scavenge:city", "zone": [200, 200]}
	fg2["hunt|wild|0:0"] = {"t": Time.get_unix_time_from_system() - 99999.0, "cause": "no_progress", "ttl": 10800.0}
	cmem["failed_goals"] = fg2
	var unm2: Dictionary = cmem.get("unreachable_pois", {})
	unm2["city:120:0"] = {"n": 1, "t": Time.get_unix_time_from_system(), "cause": "nav_blocked"}
	cmem["unreachable_pois"] = unm2
	var prompt_parsed = JSON.parse_string(mgr._ai_build_prompt(carlos))
	check(prompt_parsed is Dictionary, "El prompt del asesor es JSON valido")
	var rf: Array = prompt_parsed.get("recent_failures", [])
	check(rf.any(func(e): return str(e.get("goal", "")) == "scavenge:city" and str(e.get("cause", "")) == "nav_blocked"),
		"El prompt informa del fracaso vigente con su causa")
	check(not rf.any(func(e): return str(e.get("goal", "")).begins_with("hunt")),
		"El prompt omite fracasos caducados")
	var unr: Array = prompt_parsed.get("unreachable", [])
	check(unr.any(func(e): return str(e.get("poi", "")) == "city:120:0" and int(e.get("left_min", 0)) > 0),
		"El prompt informa del destino inaccesible con tiempo restante")
	cmem["failed_goals"] = {}
	cmem["unreachable_pois"] = {}

	# --- 26) Cadena de proveedores: Groq -> secundario (Gemini) -> local ---
	var prev_gem := OS.get_environment("GEMINI_API_KEY")
	var prev_groq := OS.get_environment("GROQ_API_KEY")
	OS.set_environment("GEMINI_API_KEY", "test-gem-key")
	OS.set_environment("GROQ_API_KEY", "test-groq-key")
	mgr._ai_provider = 0
	check(mgr._ai_provider_url().contains("groq.com") and mgr._ai_provider_key() == "test-groq-key",
		"Proveedor 0 resuelve URL y key de Groq")
	mgr._ai_provider = 1
	check(mgr._ai_provider_url().contains("googleapis.com") and mgr._ai_provider_key() == "test-gem-key",
		"Proveedor 1 resuelve URL y key de Gemini")
	check(mgr._ai_active_model() == "gemini-3.5-flash-lite",
		"Proveedor 1 usa gemini-3.5-flash-lite por defecto")
	# Cuota DIARIA por modelo: un 429 "per day" encadena al siguiente modelo
	# del mismo pozo (Gemini RPD es por modelo; Groq TPD es org-wide pero la
	# cadena cubre los limites de minuto). Solo cuando la cadena se agota el
	# veto diario salta al otro proveedor.
	mgr._ai_provider = 0
	mgr._ai_pending_provider = 0
	mgr._ai_model_override = ["", ""]
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "Rate limit reached: tokens per day (TPD): Limit 200000")
	check(mgr._ai_provider == 0 and mgr._ai_active_model() == mgr.AI_ADVISOR_FALLBACK_MODEL,
		"429 diario de qwen encadena a gpt-oss-20b del mismo pozo")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "Rate limit reached: tokens per day (TPD): Limit 200000")
	check(mgr._ai_provider == 0 and mgr._ai_active_model() == "openai/gpt-oss-120b",
		"429 diario de 20b encadena a gpt-oss-120b, ultimo del pozo Groq")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "Rate limit reached: tokens per day (TPD): Limit 200000")
	check(mgr._ai_provider == 1 and mgr._ai_conn_status.contains("provider_switch"),
		"429 diario con cadena Groq agotada salta al proveedor secundario")
	# La cadena del secundario tambien encadena por modelo: el "per day" del
	# modelo base de Gemini pasa a gemini-3.1-flash-lite sin vetar el pozo.
	mgr._ai_model_override = ["", ""]
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_provider = 1
	mgr._ai_pending_provider = 1
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "generate_content_free_tier_requests, limit: 500 per day")
	check(mgr._ai_provider == 1 and mgr._ai_active_model() == "gemini-3.1-flash-lite"
		and not bool(mgr._ai_provider_day_done[1]),
		"429 diario del modelo base Gemini encadena a 3.1-flash-lite sin vetar el pozo")
	# Racha de 429 por minuto: el tercero consecutivo tambien salta.
	mgr._ai_provider = 0
	mgr._ai_pending_provider = 0
	mgr._ai_429_streak = 0
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_day_probe_at = [0, 0]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	check(mgr._ai_provider == 0 and mgr._ai_429_streak == 2,
		"Dos 429 seguidos solo hacen backoff")
	mgr._ai_backoff_until_msec = 0
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	check(mgr._ai_provider == 1 and mgr._ai_429_streak == 0,
		"El tercer 429 seguido salta al proveedor secundario")
	# Sin key del secundario no hay salto: backoff normal y cerebro local.
	# (override al ultimo de la cadena para que el "per day" vete el pozo)
	OS.set_environment("GEMINI_API_KEY", "")
	mgr._ai_provider = 0
	mgr._ai_pending_provider = 0
	mgr._ai_model_override[0] = "openai/gpt-oss-120b"
	mgr._ai_backoff_until_msec = 0
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_register_429(PackedStringArray(), false, "Rate limit reached: requests per day (RPD)")
	check(mgr._ai_provider == 0 and mgr._ai_conn_status.contains("rate_limited"),
		"Sin key del secundario el 429 diario solo hace backoff")
	OS.set_environment("GEMINI_API_KEY", "test-gem-key")
	# El 429 del SECUNDARIO vuelve al primario cuando su ventana esta libre:
	# los pozos se turnan por proveedor, no hay relevo de un solo sentido.
	mgr._ai_provider = 1
	mgr._ai_pending_provider = 1
	mgr._ai_429_streak = 0
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_provider_backoff_sec = [4.0, 4.0]
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	mgr._ai_register_429(PackedStringArray(), false, "rate limit")
	check(mgr._ai_provider == 0 and mgr._ai_429_streak == 0,
		"Racha de 429 en el secundario devuelve el servicio al primario")
	# "per day" en el ULTIMO modelo de la cadena del secundario = veto diario
	# propio: si el primario tambien esta vetado (sonda aun pendiente) no hay
	# relevo — backoff y cerebro local.
	mgr._ai_model_override = ["", "gemini-3.1-flash-lite"]
	mgr._ai_provider = 1
	mgr._ai_pending_provider = 1
	mgr._ai_provider_day_done = [true, false]
	mgr._ai_provider_day_probe_at = [Time.get_ticks_msec() + 999999, 0]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_register_429(PackedStringArray(), false, "generate_requests_per_model_per_day quota exceeded")
	check(mgr._ai_provider == 1 and bool(mgr._ai_provider_day_done[1]) and mgr._ai_conn_status.contains("rate_limited"),
		"429 diario del secundario con primario vetado solo hace backoff")
	# Con el primario libre, el "per day" del ultimo modelo vuelve a Groq.
	mgr._ai_provider = 1
	mgr._ai_pending_provider = 1
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_day_probe_at = [0, 0]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_register_429(PackedStringArray(), false, "generate_requests_per_model_per_day quota exceeded")
	check(mgr._ai_provider == 0 and bool(mgr._ai_provider_day_done[1]),
		"429 diario del secundario con primario libre vuelve a Groq")
	# Veto diario semipermeable: sonda vencida lo hace usable (se reprobea),
	# sonda pendiente no. El free tier libera cuota antes del reset UTC.
	var now_probe: int = Time.get_ticks_msec()
	mgr._ai_provider_day_done = [true, false]
	mgr._ai_provider_day_probe_at = [0, 0]
	mgr._ai_provider_blocked_until = [0, 0]
	check(mgr._ai_provider_usable(0, now_probe), "Veto diario con sonda vencida vuelve a ser usable")
	mgr._ai_provider_day_probe_at = [now_probe + 600000, 0]
	check(not mgr._ai_provider_usable(0, now_probe), "Veto diario con sonda pendiente no es usable")
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_blocked_until = [now_probe + 30000, 0]
	check(not mgr._ai_provider_usable(0, now_probe), "Backoff por minuto bloquea aunque no haya veto diario")
	# Pista de reintento del cuerpo: "try again in N s" de Groq se usa cuando
	# no hay cabecera Retry-After, y acota la sonda del veto diario al borde
	# de la ventana deslizante (suelo 45 s, techo 15 min).
	mgr._ai_provider = 0
	mgr._ai_pending_provider = 0
	mgr._ai_429_streak = 0
	mgr._ai_provider_day_done = [false, false]
	mgr._ai_provider_day_probe_at = [0, 0]
	mgr._ai_provider_blocked_until = [0, 0]
	mgr._ai_register_429(PackedStringArray(), false, "tokens per minute (TPM): Limit 8000, Used 8100. Please try again in 16.4s")
	var blk: int = int(mgr._ai_provider_blocked_until[0]) - Time.get_ticks_msec()
	check(blk > 12000 and blk < 20000, "Pista 'try again in 16.4s' fija backoff ~16 s (got %d)" % blk)
	mgr._ai_429_streak = 0
	mgr._ai_provider_blocked_until = [0, 0]
	# El veto diario solo se marca agotada la cadena del pozo: se fuerza el
	# override al ultimo modelo de Groq para probar la sonda, no el relevo.
	mgr._ai_model_override[0] = "openai/gpt-oss-120b"
	mgr._ai_register_429(PackedStringArray(), false, "tokens per day (TPD): Limit 200000, Used 199501. Please try again in 16.4s")
	var prb: int = int(mgr._ai_provider_day_probe_at[0]) - Time.get_ticks_msec()
	check(bool(mgr._ai_provider_day_done[0]) and prb >= 40000 and prb <= 50000,
		"Veto diario con pista de 16 s sondea en el suelo de 45 s (got %d)" % prb)
	OS.set_environment("GEMINI_API_KEY", prev_gem)
	OS.set_environment("GROQ_API_KEY", prev_groq)

	world.free()
	if failures == 0:
		print("BotPlanReliabilityRegression: ALL PASS")
	else:
		print("BotPlanReliabilityRegression: %d FAILURES" % failures)
	quit(1 if failures else 0)
