extends SceneTree

# Aprendizaje real, memoria espacial y confianza, sin mapa, red ni saves del jugador.
const Utility = preload("res://scripts/BotUtilityAI.gd")
var errors := 0
var checks := 0

class Manager extends "res://scripts/SurvivorBotManager.gd":
	var test_pois: Array = []
	func _explore_pois() -> Array:
		return test_pois
	# Aislar el watchdog antiguo del seguimiento de progreso más reciente.
	func _ai_step_stalled(_b: Dictionary, _d: Dictionary, _now: int) -> String:
		return ""
	func _ai_directive_completed(_b: Dictionary, _d: Dictionary) -> bool:
		return false
	func _ai_apply_local_fallback_decision(bot_id: int, reason: String = "local_fallback") -> Dictionary:
		bots[bot_id]["test_fallback"] = reason
		return {}
	func _ai_enqueue_request(_id: int, _priority: int = 3, _reason: String = "periodic", _force: bool = false) -> void:
		pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		print("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func learner(m: Manager, id: int) -> Dictionary:
	var proxy := Node3D.new()
	m.add_child(proxy)
	proxy.position = Vector3(id - 901, 0, 0)
	var b := {"bot_id": id, "name": str(id), "faction": "friendly", "proxy": proxy,
		"health": 100.0, "hunger": 90.0, "thirst": 90.0, "energy": 80.0}
	m.bots[id] = b
	m._ensure_bot_memory(id)
	return b

func run() -> void:
	var m := Manager.new()
	root.add_child(m)
	var b := learner(m, 901)
	var mem: Dictionary = b._mem
	# Una segunda agresión cerca debe actualizar la misma zona, con posición válida.
	var spot := Vector3(200, 0, 200)
	m.record_zone_hazard(901, spot, "wild", 0.7, true)
	m.record_zone_hazard(901, spot + Vector3(3, 0, 0), "wild", 0.7, true)
	var known: Dictionary = mem.known_locations
	check(known.size() == 1, "nearby hazards retain one canonical location")
	var loc: Dictionary = known.get("wild:200:200", {})
	check(is_equal_approx(float(loc.get("combat_risk", 0)), 1.4), "repeat combat updates canonical risk")
	m.record_zone_hazard(901, spot + Vector3(4, 0, 0), "wild", 1.0, true)
	check(m._bot_learned_risk_at(spot, 901) != Vector3.INF, "repeated local combat changes tactical caution")
	for value in known.values():
		check(value.get("pos", []).size() == 3, "hazard memory keeps coordinates")

	# El nombre de un POI nunca debe quedar asociado al punto de impacto vecino.
	mem.known_locations = {}
	var poi := {"kind": "city", "pos": Vector3(80, 6, 80)}
	m.test_pois = [poi]
	m.record_zone_hazard(901, Vector3(90, 0, 80), "rifle", 0.8, true)
	loc = mem.known_locations.get(m._poi_id(poi), {})
	check(loc.get("pos", []) == [80.0, 6.0, 80.0], "hazard retains canonical POI coordinates")
	# Ni la altura del ID ni la compactación pueden esconder el peligro al elegir ruta.
	mem.strategies = {}
	check(m._ai_poi_memory_factor(b, poi.pos, "city") < 1.0, "elevated POI risk affects route preference")
	mem.known_locations = {"city:80:6:80": {"pos": [80, 6, 80], "risk": 0.0, "combat_risk": 0.0},
		"city:81:6:80": {"pos": [81, 6, 80], "risk": 1.2, "combat_risk": 2.4}}
	m._compact_known_locations(mem)
	loc = mem.known_locations.get("city:80:6:80", {})
	check(is_equal_approx(float(loc.get("combat_risk", 0)), 2.4), "compaction preserves strongest combat warning")
	check(m._ai_poi_memory_factor(b, Vector3(81, 6, 80), "city") < 1.0, "merged POI risk still affects route choice")
	mem.score_reset_v = 1
	m.force_memory_io = true
	m.memory_path = "res://build/tmp/bot_learning_regression_memory.json"
	m._ai_save_memory()
	m._ai_flush_writes()
	var restored := Manager.new()
	restored.force_memory_io = true
	restored.memory_path = m.memory_path
	restored._ai_load_memory()
	var loaded: Dictionary = restored._ensure_bot_memory(901)
	check(is_equal_approx(float(loaded.known_locations.get("city:80:6:80", {}).get("combat_risk", 0)), 2.4), "combat warning survives save and reload")
	restored.free()
	m.force_memory_io = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.memory_path))

	# Misma facción no equivale a confianza, ni por mapa ni por el plan seek_ally.
	var c := learner(m, 902)
	var d := learner(m, 903)
	for pair in [[901, 902], [902, 901], [901, 903], [903, 901]]:
		var rel := m._chat_touch_rel(pair[0], "bot_%d" % pair[1], str(pair[1]))
		rel.trust = 0.8
		rel.hostility = 0.0
	c._mem.killers = {"bot_901": {"count": 2, "helped_at_death": 0}}
	mem.known_locations = {"secret:20:20": {"pos": [20, 0, 20], "kind": "camp"}}
	c._mem.known_locations = {}
	check(m.share_bot_knowledge(901, 902) == 0 and c._mem.known_locations.is_empty(), "killer and victim cannot trade private knowledge")
	check(m._nearest_friendly_bot_pos(901) == d.proxy.global_position, "seek_ally respects victim distrust")
	check(m._nearest_friendly_bot_pos(902) != b.proxy.global_position, "victim never seeks killer as ally")
	c._mem.killers = {}
	b["_share_cd_902"] = 0.0
	c["_share_cd_901"] = 0.0
	check(m.share_bot_knowledge(901, 902) > 0 and c._mem.known_locations.has("secret:20:20"), "trusted pair still exchanges knowledge")
	var from_mem := {"killers": {"bot_901": {"count": 1}, "bot_902": {"count": 2}, "bot_903": {"count": 3}}, "relationships": {}}
	var to_mem := {"killers": {}, "relationships": {}}
	m._share_enemy_knowledge(from_mem, to_mem, "bot_902", "bot_901")
	check(not to_mem.killers.has("bot_901") and not to_mem.killers.has("bot_902"), "warnings never manufacture killer memories about the interlocutors")
	check(to_mem.killers.get("bot_903", {}).get("count", 0) == 3, "warnings about third parties remain available")

	# Aprender de una muerte no prueba que cazó, recolectó o construyó con éxito.
	mem.strategies = {}
	mem.death_lessons = {}
	for cause in ["dehydrated", "starved", "wolf_bite", "hypothermia", "bled", "rifle", "melee"]:
		m._record_death_lesson(b, mem, cause)
	var false_successes := 0
	for st in mem.strategies.values():
		false_successes += int(st.get("success", 0))
	check(false_successes == 0, "death lessons do not fabricate successful actions")
	check(is_equal_approx(Utility.strat_prob(mem.strategies.get("hunt", {})), 0.5), "starvation cannot falsely raise hunting success probability")
	check(mem.death_lessons.size() == 7 and m._bot_death_adaptations(mem).size() >= 7, "all real survival adaptations remain enabled")
	m.record_strategy_outcome(901, "hunt", true)
	check(Utility.strat_prob(mem.strategies.hunt) > 0.5 and mem.strategies.hunt.success == 1, "a real successful hunt supplies exactly one success")

	# El watchdog evalúa paso y plan por separado, incluso si la raíz coincide.
	m.bots.erase(902)
	m.bots.erase(903)
	for root_action in ["forage", "rest"]:
		mem.strategies = {}
		b.ai_directive = {"goal": "stale", "action": "rest", "_plan_root": root_action, "until": -int(m.AI_PLAN_STALE_GRACE_SEC * 1000.0) - 1000}
		b._stuck_sig = "stale|rest"
		b._stuck_n = 1
		m._ai_sig_poll(Time.get_ticks_msec())
		check(mem.strategies.get("rest", {}).get("fail", 0) == 1, "watchdog credits one failure to actual step")
		check(mem.strategies.get("plan:" + root_action, {}).get("fail", 0) == 1, "watchdog records whole-plan failure separately")
		if root_action != "rest":
			check(mem.strategies.get(root_action, {}).is_empty(), "failed rest cannot poison an earlier forage action")
		check(b.get("test_fallback", "") == "plan_impossible", "watchdog still abandons failed plan")
	m.free()
	test_legacy_evidence()
	print("BOT_LEARNING checks=", checks, " errors=", errors)
	quit(errors)

func test_legacy_evidence() -> void:
	var path := "res://build/tmp/bot_learning_legacy_memory.json"
	var snapshot := {"version": 3, "bots": {"901": {
		"score_reset_v": 1, "death_lessons": {"starved": 3, "dehydrated": 2, "predator": 1},
		"strategies": {"hunt": {"success": 5, "fail": 2, "preference": 1.7},
			"forage": {"success": 7, "fail": 1, "preference": 1.8},
			"fortify_camp": {"success": 1, "preference": 1.2}},
		"relationships": {"bot_902": {"trust": -0.7, "attacked": 4}}
	}}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	var m := Manager.new()
	m.force_memory_io = true
	m.memory_path = path
	m._ai_load_memory()
	var mem := m._ensure_bot_memory(901)
	check(mem.strategies.hunt.success == 2 and mem.strategies.forage.success == 2,
		"legacy deaths are removed from successes while real outcomes remain")
	check(mem.strategies.hunt.fail == 2 and is_equal_approx(mem.strategies.hunt.preference, 1.7),
		"migration keeps real failures and survival preferences")
	check(mem.death_lessons.starved == 3 and is_equal_approx(mem.relationships.bot_902.trust, -0.7),
		"migration preserves survival lessons and betrayal")
	m._ai_save_memory()
	m._ai_flush_writes()
	m.free()
	m = Manager.new()
	m.force_memory_io = true
	m.memory_path = path
	m._ai_load_memory()
	mem = m._ensure_bot_memory(901)
	check(mem.strategies.hunt.success == 2 and mem.strategy_evidence_v == 1,
		"restarting cannot subtract the same legacy evidence twice")
	m.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
