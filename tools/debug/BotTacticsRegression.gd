extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
	var cover := true
	var blocked := false
	var moves := 0
	var destination := Vector3.INF
	func _ground_y(_x: float, _z: float, _from_y: float = -INF) -> float: return 0.0
	func _is_step_blocked(_a: Vector3, _b: Vector3, _deep: bool = false) -> bool: return blocked
	func _has_clear_shot(_a: Vector3, b: Vector3) -> bool: return not cover or b.x < 3.0
	func _move_bot_towards(_b: Dictionary, goal: Vector3, _speed: float, _delta: float, _anim: String) -> void:
		moves += 1
		destination = goal
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var manager := Manager.new()
	root.add_child(manager)
	var proxy := Node3D.new()
	var foe := Node3D.new()
	root.add_child(proxy)
	root.add_child(foe)
	foe.position = Vector3(-10,0,0)
	var b := {"proxy":proxy,"bot_id":901}
	var goal := manager._find_ballistic_cover(b,foe)
	check(goal != Vector3.INF and goal.x >= 3, "selects point that blocks incoming sight")
	manager._bot_seek_ballistic_cover(b,foe,.1)
	check(manager.moves == 1 and not b.crouching, "runs to cover without crouching in open")
	proxy.position = manager.destination
	manager._bot_seek_ballistic_cover(b,foe,.1)
	check(b.crouching and manager.moves == 1, "crouches only once actual position is protected")
	manager.cover = false
	manager._bot_seek_ballistic_cover(b,foe,2.0)
	check(manager.moves == 2 and not b.crouching, "flanked bot leaves exposed cover")
	proxy.position = Vector3.ZERO
	manager.cover = true
	manager.blocked = true
	check(manager._find_ballistic_cover(b,foe) == Vector3.INF, "rejects inaccessible cover")

	# Enemigo perdido: el aggro ya no es un radar — exige LOS u oido; al
	# perderlo arma una busqueda acotada sobre la ultima posicion conocida.
	manager.blocked = false
	var world_stub := Node3D.new()
	root.add_child(world_stub)
	manager.world = world_stub
	var last_seen := Vector3(20, 0, 20)
	var b2 := {"proxy": proxy, "bot_id": 901, "faction": "hostile",
		"aggro_target": foe, "aggro_timer": 20.0, "_mem": {"personality": {}},
		"_last_foe_pos": last_seen, "_lost_foe_pos": Vector3.INF,
		"_lost_foe_until_msec": 0, "_lost_scan_t": 0.0,
		"last_heard_pos": Vector3.INF, "last_heard_until": 0.0, "last_heard_actor": 0}
	foe.position = Vector3(40, 0, 0)
	manager.cover = false
	check(manager._find_combat_foe(b2) == foe, "aggro with clear LOS keeps tracking the foe")
	manager.cover = true # LOS cortada, el enemigo no corre ni se oye
	check(manager._find_combat_foe(b2) == null, "aggro behind cover is NOT tracked (no wallhack)")
	check(b2["aggro_target"] == null, "lost aggro drops the live target handle")
	check(b2["_lost_foe_pos"] == last_seen, "remembers last SEEN position, not the live one")
	check(int(b2["_lost_foe_until_msec"]) > Time.get_ticks_msec(), "search window armed")
	var evs: Array = (manager._ensure_bot_memory(901) as Dictionary).get("events", [])
	check(evs.any(func(e): return str(e.get("type", "")) == "lost_foe"), "lost foe recorded in memory")
	# Mientras dura la busqueda el mismo aggro no rearma nada (ya fue anulado)
	check(manager._find_combat_foe(b2) == null and int(b2["_lost_foe_until_msec"]) > 0,
		"no rearm during the search window")
	# Oido sin LOS: un enemigo corriendo cerca sigue siendo rastreable
	var b3 := b2.duplicate(true)
	b3["aggro_target"] = foe
	foe.position = Vector3(30, 0, 0) # dentro del radio de sprint (34 m)
	foe.set_meta("sprinting", true)
	check(manager._find_combat_foe(b3) == foe, "heard (sprinting) foe behind cover still tracked")
	foe.set_meta("sprinting", false)

	# Fuente de la pista: visto/oído/aviso de aliado con fiabilidad distinta
	var b4 := b2.duplicate(true)
	manager._ai_note_foe_intel(b4, foe, Vector3(9, 0, 9), "told")
	check(str((b4["_foe_mem"] as Dictionary).get("src", "")) == "told"
			and float((b4["_foe_mem"] as Dictionary).get("conf", 1.0)) < 1.0,
		"allied warning is stored as lower-confidence intel")
	manager._ai_note_foe_intel(b4, foe, Vector3(8, 0, 8), "seen")
	check(str((b4["_foe_mem"] as Dictionary).get("src", "")) == "seen"
			and float((b4["_foe_mem"] as Dictionary).get("conf", 0.0)) == 1.0
			and (b4["_foe_mem"] as Dictionary).get("pos") == Vector3(8, 0, 8),
		"direct sight is stored as full-confidence intel at the exact spot")
	# Oir un disparo lejano NO da la posicion exacta: confianza baja y
	# posicion con incertidumbre (a ~22 m max). A ~60 m la confianza baja mas.
	var b7 := b2.duplicate(true)
	(b7["proxy"] as Node3D).position = Vector3(0, 0, 0)
	manager._ai_note_foe_intel(b7, foe, Vector3(100, 0, 0), "heard")
	var fm_h: Dictionary = b7["_foe_mem"]
	check(str(fm_h.get("src", "")) == "heard"
			and float(fm_h.get("conf", 1.0)) < 0.7,
		"a far heard clue stores reduced confidence")
	var hp: Vector3 = fm_h.get("pos", Vector3.INF)
	check(hp != Vector3.INF and (hp - Vector3(100, 0, 0)).length() <= 26.0,
		"the heard position is approximate, within localization error")
	# Una pista vieja (>120 s) no arma búsqueda: el rastro ya no vale nada
	var b5 := b2.duplicate(true)
	b5["aggro_target"] = foe
	b5["aggro_timer"] = 20.0
	manager._ai_note_foe_intel(b5, foe, Vector3(5, 0, 5), "seen")
	(b5["_foe_mem"] as Dictionary)["t"] = Time.get_ticks_msec() - 150000
	b5["_lost_foe_until_msec"] = 0
	b5["_lost_foe_pos"] = Vector3.INF
	foe.position = Vector3(40, 0, 0) # sin LOS ni oido
	check(manager._find_combat_foe(b5) == null, "stale clue drops the live target")
	check(int(b5["_lost_foe_until_msec"]) == 0,
		"a clue older than 120s does NOT arm a search")
	# Un aviso reciente de aliado sí arma búsqueda, pero más corta que una vista
	var b6 := b2.duplicate(true)
	b6["aggro_target"] = foe
	b6["aggro_timer"] = 20.0
	manager._ai_note_foe_intel(b6, foe, Vector3(5, 0, 5), "told")
	(b6["_foe_mem"] as Dictionary)["t"] = Time.get_ticks_msec() - 10000
	b6["_lost_foe_until_msec"] = 0
	b6["_lost_foe_pos"] = Vector3.INF
	manager._find_combat_foe(b6)
	var seen_win := int(b2.get("_lost_foe_until_msec", 0))
	var told_win := int(b6.get("_lost_foe_until_msec", 0))
	check(told_win > 0, "fresh allied warning still arms a bounded search")
	check(told_win < seen_win or seen_win <= 0,
		"the told clue searches less time than a directly seen one")
	# Un tirador OIDO tras cobertura que se reubica en silencio: la busqueda
	# va a donde sono el disparo, nunca a su posicion real nueva.
	var b8 := b2.duplicate(true)
	b8["aggro_target"] = foe
	b8["aggro_timer"] = 20.0
	b8["last_heard_until"] = 0.0
	(b8["proxy"] as Node3D).position = Vector3.ZERO
	manager._ai_note_foe_intel(b8, foe, Vector3(60, 0, 0), "heard")
	b8["_lost_foe_until_msec"] = 0
	b8["_lost_foe_pos"] = Vector3.INF
	foe.position = Vector3(90, 0, 90) # se fue en silencio y sin LOS (x>=3)
	manager.cover = true
	check(manager._find_combat_foe(b8) == null,
		"relocated hidden shooter drops the live target")
	var anchor8: Vector3 = b8["_lost_foe_pos"]
	check(anchor8 != Vector3.INF and (anchor8 - Vector3(90, 0, 90)).length() > 40.0,
		"the search anchors near the heard spot, never the new real position")
	world_stub.free()
	proxy.free()
	foe.free()
	manager.free()
	print("BOT_TACTICS errors=",errors)
	quit(errors)
