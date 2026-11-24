extends SceneTree
class HouseWorld extends Node3D:
	var wildlife_blockers := [{"house_bounds": Rect2(-5, -5, 15, 10)}]
	var server_proxies := {}

class Manager extends "res://scripts/SurvivorBotManager.gd":
	var cover := true
	var blocked := false
	var moves := 0
	var destination := Vector3.INF
	var night := false
	func _is_world_night() -> bool: return night
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
	var world_stub := HouseWorld.new()
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
	var night_b := b2.duplicate(true)
	manager.night = true
	check(manager._find_combat_foe(night_b) == null and night_b["aggro_target"] == null,
		"existing aggro cannot track a quiet distant actor in darkness merely because no wall blocks it")
	check(night_b["_lost_foe_pos"] == last_seen,
		"losing night visibility searches the remembered location, not the hidden actor's current position")
	manager.night = false
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
	var no_clue := b5.duplicate(true)
	no_clue["aggro_target"] = foe
	no_clue["_foe_mem"] = {}
	no_clue["_last_foe_pos"] = Vector3.INF
	no_clue["last_heard_pos"] = Vector3(-5,0,2)
	no_clue["last_heard_actor"] = 72 # unrelated sound
	no_clue["last_heard_until"] = Time.get_ticks_msec() / 1000.0 + 8.0
	manager._find_combat_foe(no_clue)
	check(no_clue["_lost_foe_pos"] == Vector3.INF and no_clue["aggro_target"] == null,
		"a hidden actor cannot borrow someone else's noise as a search location")
	no_clue["aggro_target"] = foe
	no_clue["last_heard_pos"] = Vector3.INF
	no_clue["_lost_foe_until_msec"] = 0
	no_clue["_lost_foe_pos"] = Vector3.INF
	manager._find_combat_foe(no_clue)
	check(no_clue["_lost_foe_until_msec"] == 0, "no clue means no search at a hidden actor's live coordinates")
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

	# El escaneo de sentidos NO refresca la pista auditiva con la posicion
	# viva: sin LOS, _ai_note_foe_scan no toca _foe_mem aunque el enemigo se
	# haya movido; con LOS si actualiza a la posicion exacta vista.
	var b9 := b2.duplicate(true)
	(b9["proxy"] as Node3D).position = Vector3.ZERO
	manager._ai_note_foe_intel(b9, foe, Vector3(50, 0, 50), "heard")
	var heard_pos9: Vector3 = (b9["_foe_mem"] as Dictionary).get("pos")
	foe.position = Vector3(70, 0, 0) # se mueve en silencio, sin LOS (x>=3)
	manager.cover = true
	manager._ai_note_foe_scan(b9, foe)
	check((b9["_foe_mem"] as Dictionary).get("pos") == heard_pos9
			and str((b9["_foe_mem"] as Dictionary).get("src")) == "heard",
		"hidden foe's live position never overwrites the heard clue")
	manager.cover = false
	manager._ai_note_foe_scan(b9, foe)
	check(str((b9["_foe_mem"] as Dictionary).get("src")) == "heard",
		"geometric LOS outside recognition range cannot turn a heard clue into a sighting")
	foe.position = Vector3(40, 0, 0) # entra en alcance visual con LOS libre
	manager._ai_note_foe_scan(b9, foe)
	check(str((b9["_foe_mem"] as Dictionary).get("src")) == "seen"
			and (b9["_foe_mem"] as Dictionary).get("pos") == Vector3(40, 0, 0),
		"direct sight updates the clue to the exact live position")
	# ------------------------------------------------------------------
	# Sentidos propios: un bandido a 5 m del lider pero a 100 m del miembro
	# NO es detectado por el miembro (antes min(d, d_lider) lo "oia").
	# ------------------------------------------------------------------
	manager.cover = false
	var lead_p := Node3D.new()
	var memb_p := Node3D.new()
	var band_p := Node3D.new()
	for n in [lead_p, memb_p, band_p]:
		root.add_child(n)
	lead_p.position = Vector3(0, 0, 0)
	memb_p.position = Vector3(0, 0, 100)
	band_p.position = Vector3(0, 0, 5)
	var mk := func(id: int, p: Node3D, faction: String, lid: int) -> Dictionary:
		return {"proxy": p, "bot_id": id, "faction": faction, "team_leader_id": lid, "name": "B%d" % id,
			"aggro_target": null, "aggro_timer": 0.0, "_mem": {"personality": {}},
			"_lost_foe_pos": Vector3.INF, "_lost_foe_until_msec": 0, "_lost_scan_t": 0.0,
			"last_heard_pos": Vector3.INF, "last_heard_until": 0.0, "last_heard_actor": 0,
			"hunger": 80.0, "thirst": 80.0, "health": 100.0, "sitting": false, "sleeping": false}
	var lead_b: Dictionary = mk.call(904, lead_p, "friendly", 0)
	var memb_b: Dictionary = mk.call(905, memb_p, "friendly", 904)
	var band_b: Dictionary = mk.call(906, band_p, "hostile", 0)
	manager.bots[904] = lead_b
	manager.bots[905] = memb_b
	manager.bots[906] = band_b
	check(manager._find_combat_foe(lead_b) == band_p, "leader detects the bandit 5 m away with its own senses")
	check(manager._find_combat_foe(memb_b) == null, "member 100 m away does NOT detect a foe that is only near its leader")
	check(memb_b["aggro_target"] == null, "no aggro leaks to the far member")
	# Aviso real: fuera del alcance de la voz no llega nada
	manager._ai_note_foe_scan(lead_b, band_p)
	(lead_b["_foe_mem"] as Dictionary)["t"] = Time.get_ticks_msec() - 30000 # lo vio hace 30 s
	check(manager._bot_warn_team_of_foe(lead_b, band_p) == 0, "a shout does not reach a teammate 100 m away")
	check(memb_b.get("_foe_mem", {}).is_empty(), "unwarned member holds no intel about the foe")
	# Dentro del alcance: llega la ultima posicion CONOCIDA con su antiguedad y fiabilidad
	memb_p.position = Vector3(0, 0, 30)
	var known_pos: Vector3 = (lead_b["_foe_mem"] as Dictionary)["pos"]
	band_p.position = Vector3(40, 0, 60) # el bandido ya se movio, en silencio y sin LOS
	manager.cover = true
	check(manager._bot_warn_team_of_foe(lead_b, band_p) == 1, "teammate within shouting range is warned")
	var fm_m: Dictionary = memb_b.get("_foe_mem", {})
	check(str(fm_m.get("src", "")) == "told", "warning is stored as 'told' intel (source = communication)")
	check(float(fm_m.get("conf", 1.0)) < float((lead_b["_foe_mem"] as Dictionary).get("conf", 0.0)), "warning carries reduced reliability")
	check(Time.get_ticks_msec() - int(fm_m.get("t", 0)) >= 30000, "warning carries the age of the original sighting")
	check((fm_m.get("pos", Vector3.INF) as Vector3).distance_to(known_pos) <= 10.5
			and (fm_m.get("pos", Vector3.INF) as Vector3).distance_to(band_p.position) > 30.0,
		"warning shares the last KNOWN position, never the foe's live one")
	check(manager._bot_warn_team_of_foe(lead_b, band_p) == 0, "warnings are rate limited")
	# El avisado no ve ni oye al enemigo: busca en la pista, no rastrea el nodo
	check(memb_b["aggro_target"] == band_p, "warned member reacts (aggro armed by the warning)")
	check(manager._find_combat_foe(memb_b) == null and memb_b["aggro_target"] == null,
		"warned member still cannot track the unseen foe")
	check((memb_b["_lost_foe_pos"] as Vector3).distance_to(band_p.position) > 30.0 and int(memb_b["_lost_foe_until_msec"]) > 0,
		"warned member searches the communicated last-known position")
	# Sin ficha propia no hay nada que contar
	lead_b["_foe_mem"] = {}
	lead_b["_warn_foe_msec"] = -999999
	check(manager._bot_warn_team_of_foe(lead_b, band_p) == 0, "a bot with no intel has nothing to report")

	# ------------------------------------------------------------------
	# Emboscadas sin informacion oculta
	# ------------------------------------------------------------------
	manager.bots.clear()
	var hunter_p := Node3D.new()
	var victim_p := Node3D.new()
	var escort_p := Node3D.new()
	for n in [hunter_p, victim_p, escort_p]:
		root.add_child(n)
	hunter_p.position = Vector3(0, 0, 0)
	hunter_p.set_meta("saved_inventory", [{"name": "Cuchillo", "type": "weapon", "quantity": 1}])
	var hunter_b: Dictionary = mk.call(907, hunter_p, "hostile", 0)
	manager.bots[907] = hunter_b
	var victim_b: Dictionary = mk.call(908, victim_p, "friendly", 0)
	manager.bots[908] = victim_b
	victim_p.add_to_group("net_player_proxy")
	victim_p.set_meta("has_real_pos", true)
	victim_p.set_meta("saved_backpack", "Mochila")
	escort_p.set_meta("has_real_pos", true)
	# Victima inmovil a 8 m tras una pared (x>=3 = sin LOS en este mock)
	victim_p.position = Vector3(8, 0, 0)
	manager.cover = true
	check(manager._find_ambush_target(hunter_b).is_empty(), "motionless victim 8 m behind a wall is NOT picked as a target")
	check(not manager._bot_perceives_actor(hunter_b, victim_p, 52.0), "silent actor behind a wall is not perceived")
	victim_p.set_meta("moving", true)
	check(manager._bot_perceives_actor(hunter_b, victim_p, 52.0), "audible footsteps are a valid sound cue through the wall")
	victim_p.set_meta("moving", false)
	# A la vista si es candidata
	victim_p.position = Vector3(2, 0, 8)
	var amb_t := manager._find_ambush_target(hunter_b)
	check(int(amb_t.get("target_id", 0)) == 908, "visible lone victim with a backpack is a valid target")
	check(amb_t.get("pos") == victim_p.position, "the plan stores the position where the victim was perceived")
	# El inventario y la salud internos no influyen
	victim_p.set_meta("saved_backpack", "")
	victim_p.set_meta("saved_inventory", [{"name": "Lingote", "quantity": 50}, {"name": "a"}, {"name": "b"}, {"name": "c"}, {"name": "d"}, {"name": "e"}])
	victim_p.set_meta("proxy_health", 5.0)
	check(manager._find_ambush_target(hunter_b).is_empty(), "a hidden full inventory / low internal health does not make someone a target")
	check(is_equal_approx(manager._bot_observed_loot_value(hunter_b, victim_p, 908), 0.0), "observed loot value ignores saved_inventory")
	victim_p.set_meta("saved_backpack", "Mochila")
	# Escolta: solo cuenta la que el bandido ha detectado
	escort_p.add_to_group("net_player_proxy")
	escort_p.position = Vector3(2, 0, 12)
	check(manager._find_ambush_target(hunter_b).is_empty(), "an accompanied victim (visible escort) is left alone by a lone bandit")
	escort_p.position = Vector3(5, 0, 8) # escondida tras la pared: no detectada
	check(int(manager._find_ambush_target(hunter_b).get("target_id", 0)) == 908, "an undetected escort is not magically counted")
	escort_p.remove_from_group("net_player_proxy")
	# Tregua valida: no hay emboscada, y una tregua a mitad del acecho la cancela
	hunter_b["_truce_peer"] = 908
	hunter_b["_truce_t"] = 60.0
	check(manager._find_ambush_target(hunter_b).is_empty(), "no ambush against someone under a valid truce")
	hunter_b["_ambush"] = amb_t.duplicate()
	check(not manager._bot_try_ambush(hunter_b, 0.1) and (hunter_b["_ambush"] as Dictionary).is_empty(), "a truce agreed mid-stalk cancels the ambush")
	hunter_b["_truce_peer"] = 0
	hunter_b["_truce_t"] = 0.0
	hunter_b["_ambush_cd_until"] = 0.0
	# Vinculo personal: confianza alta = no se le embosca
	manager._ensure_bot_memory(907)["relationships"] = {"bot_908": {"id": "bot_908", "name": "V", "trust": 0.7, "hostility": 0.0, "fear": 0.0, "helped": 0, "attacked": 0}}
	check(manager._find_ambush_target(hunter_b).is_empty(), "no ambush against a trusted acquaintance")
	manager._ensure_bot_memory(907)["relationships"] = {}
	# Acecho: sigue la ultima posicion conocida, no la viva
	victim_p.position = Vector3(2, 0, 30)
	amb_t = manager._find_ambush_target(hunter_b)
	hunter_b["_ambush"] = amb_t
	var p_known := victim_p.position
	victim_p.position = Vector3(40, 0, 30) # se esconde en silencio
	manager.moves = 0
	check(manager._bot_try_ambush(hunter_b, 0.1) and manager.destination == p_known,
		"stalking heads to the last known position while the victim is hidden")
	(hunter_b["_ambush"] as Dictionary)["seen_msec"] = Time.get_ticks_msec() - 20000
	check(not manager._bot_try_ambush(hunter_b, 0.1) and (hunter_b["_ambush"] as Dictionary).is_empty(),
		"a victim lost for too long ends the ambush (no radar)")
	for n in [lead_p, memb_p, band_p, hunter_p, victim_p, escort_p]:
		n.free()
	manager.bots.clear()
	var human := Node3D.new()
	world_stub.add_child(human)
	human.add_to_group("net_player_proxy")
	human.set_meta("has_real_pos", true)
	world_stub.server_proxies[42] = human
	human.position = Vector3(4, 0, 0)
	proxy.position = Vector3.ZERO
	var resting := {"proxy":proxy, "bot_id":901, "faction":"hostile", "_s_foe":null,
		"_mem":{"personality":{"survival_instinct":0.9, "bravery":0.3}}}
	manager._ensure_bot_memory(901)["relationships"] = {"player_42":{"fear":0.8}}
	manager.cover = true
	check(not manager._bot_interrupt_indoor_rest(resting), "silent hidden occupant does not reveal the room")
	human.set_meta("moving", true)
	check(manager._bot_interrupt_indoor_rest(resting), "audible footsteps interrupt settling indoors")
	human.set_meta("moving", false)
	manager.cover = false
	resting["_s_foe"] = null
	resting["flee_until"] = 0.0
	proxy.position = Vector3(2.5, 0, 0) # Arrived at the house centre after the previous scan.
	manager.night = true
	check(manager._bot_night_home_walk(resting, 0.1) and resting["_s_foe"] == human and resting["flee_until"] > 0
		and not resting.get("sitting", false) and not resting.get("sleeping", false),
		"night refuge arrival detects a feared human and prompts retreat rather than sitting or sleeping")
	check(not manager._bot_can_hide_from(proxy.position, human), "cannot retreat to a seat beside a detected enemy")
	resting["_truce_peer"] = 42
	resting["_truce_t"] = 30.0
	check(not manager._bot_interrupt_indoor_rest(resting), "a truce allows a peaceful rest")
	manager.bots[901] = resting
	resting["sitting"] = true
	resting["anim"] = "sit"
	resting["_act"] = "rest"
	manager.cover = true
	human.position = Vector3(300, 0, 0)
	manager.notify_sound_event(42, human.position, "gunshot", 220.0)
	check(resting.sitting, "out-of-range gunfire does not disturb the seated bot")
	human.position = Vector3(26, 0, 0)
	resting["_s_foe"] = null
	resting["flee_until"] = 0.0
	manager.notify_sound_event(42, human.position, "gunshot", 220.0)
	check(not resting.sitting and manager._bot_effective_net_anim(resting) == "sneak"
		and resting.get("aggro_target") == null and resting.flee_until == 0.0,
		"a shot under truce interrupts rest without creating hostility")
	resting["_truce_t"] = 0.0
	manager.notify_sound_event(42, human.position, "gunshot", 220.0)
	human.position += Vector3(6, 0, 0)
	check(manager._find_combat_foe(resting) == null and manager._bot_interrupt_indoor_rest(resting),
		"a heard shot leaves the room alert without tracking a silent shooter through its wall")
	manager.bots.clear()
	world_stub.free()
	proxy.free()
	foe.free()
	manager.free()
	print("BOT_TACTICS errors=",errors)
	quit(errors)
