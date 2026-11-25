extends SceneTree
## Regresion del marcador de supervivencia y de la cautela por inversion.
## Sobrevivir el maximo tiempo posible es el objetivo maximo del bot: un
## minuto vivo suma 2 pts, una muerte resta 200 — la vida media no puede
## pagar su propia muerte. Lo que esta en juego (stake) madura con la vida
## actual y amplia la deteccion de depredadores, el umbral de repliegue y
## el descuento de destinos con riesgo de combate recordado.

class Manager extends "res://scripts/SurvivorBotManager.gd":
	var stake_override := -1.0
	var night := false
	var pre_night := false
	func _bot_stake(b: Dictionary) -> float:
		if stake_override >= 0.0:
			return stake_override
		return super._bot_stake(b)
	func _is_world_night() -> bool: return night
	func _is_pre_night() -> bool: return pre_night
	func _sensed_node(_b: Dictionary, _key: String) -> Node3D: return null
	func _pick_fight_weapon(_b: Dictionary, _d: float) -> Dictionary:
		return {"kind": "melee", "name": "Arma"}

var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var manager := Manager.new()
	root.add_child(manager)
	var now := Time.get_ticks_msec()

	# Marcador: supervivencia dominante, muerte a -200.
	var mem := {"deaths": 2, "stats": {"kills_bot": 1, "kills_player": 0}}
	var sc: int = manager.bot_score_value(mem, 3600.0, 5)
	# 60 min*2=120, 5 loc*10=50, 1 baja bot=50, 2 muertes*-200=-400 => -180
	check(sc == -180, "score sums survival, locations, kills and -200 per death (got %d)" % sc)
	check(manager.bot_score_value({"deaths": 1, "stats": {}}, 2580.0, 0) < 0,
		"an average 43-minute life cannot pay its own death")
	check(manager.bot_score_value({"deaths": 0, "stats": {}}, 3600.0, 0) == 120,
		"pure survival without deaths stays positive")
	check(manager.bot_score_value({"deaths": 3, "stats": {}}, 3600.0, 0) < manager.bot_score_value({"deaths": 1, "stats": {}}, 3600.0, 0),
		"more deaths always score lower at equal survival time")

	# Stake: madura linealmente hasta saturar en 45 minutos.
	check(manager.bot_stake_from_life(0.0) == 0.0, "a newborn life has nothing invested")
	check(absf(manager.bot_stake_from_life(1350.0) - 0.5) < 0.01, "a half-mature life sits at half stake")
	check(manager.bot_stake_from_life(5400.0) == 1.0, "a mature life saturates its stake")
	var fresh := {"dead": false, "anim": "idle", "spawned_at_msec": now}
	check(manager._bot_stake(fresh) < 0.05, "a fresh spawn has nothing invested yet")
	var dead := {"dead": true, "anim": "dead", "spawned_at_msec": now}
	check(manager._bot_stake(dead) == 0.0, "a dead bot has nothing at stake")

	# Cautela sensorial: la inversion amplia el radio de depredadores.
	var fresh_bot := {"_mem": {}, "dead": false, "anim": "idle", "spawned_at_msec": now, "caution_until": 0.0}
	check(absf(manager._bot_predator_sense_radius(fresh_bot) - 22.0) < 0.2,
		"fresh spawn keeps the base predator radius")
	var invested := {"_mem": {}, "dead": false, "anim": "idle", "spawned_at_msec": now, "caution_until": 0.0}
	manager.stake_override = 1.0
	check(absf(manager._bot_predator_sense_radius(invested) - 28.0) < 0.2,
		"an invested bot senses predators farther out")
	var cautious := {"_mem": {}, "dead": false, "anim": "idle", "spawned_at_msec": now, "caution_until": 100.0}
	check(absf(manager._bot_predator_sense_radius(cautious) - 36.0) < 0.2,
		"caution memory and stake accumulate")
	manager.stake_override = -1.0

	# Repliegue tactico: la inversion adelanta la retirada, las lecciones suman.
	check(absf(manager._bot_retreat_hp(fresh_bot) - 30.0) < 0.2, "fresh spawn keeps the base retreat threshold")
	manager.stake_override = 1.0
	check(absf(manager._bot_retreat_hp(invested) - 42.0) < 0.2, "an invested bot retreats with more health left")
	var scarred := {"_mem": {"death_lessons": {"combat": 3, "ranged": 0}}, "dead": false, "anim": "idle", "spawned_at_msec": now, "caution_until": 0.0}
	check(absf(manager._bot_retreat_hp(scarred) - 57.0) < 0.2, "combat lessons and stake accumulate")
	manager.stake_override = -1.0

	# Destinos de riesgo recordado: la inversion los descuenta mas fuerte.
	var pos := Vector3(100, 0, 100)
	var pid: String = manager._poi_id({"kind": "house", "pos": pos})
	var mem2 := {"known_locations": {pid: {"kind": "house", "pos": [100, 0, 100], "risk": 1.1}},
		"zone_yield": {}, "death_spots": [], "strategies": {}, "personality": {"survival_instinct": 0.7}}
	var probe := {"_mem": mem2, "bot_id": 901, "dead": false, "anim": "idle", "spawned_at_msec": now}
	var f_fresh: float = manager._ai_poi_memory_factor(probe, pos, "house")
	manager.stake_override = 1.0
	var f_inv: float = manager._ai_poi_memory_factor(probe, pos, "house")
	manager.stake_override = -1.0
	check(f_inv < f_fresh - 0.05, "an invested bot discounts remembered-risk destinations deeper (%.2f vs %.2f)" % [f_inv, f_fresh])
	check(f_inv >= 0.2, "the discount never erases a destination completely")

	# Cautela proporcional a la evidencia: en zona tranquila un bot maduro
	# explora igual que uno nuevo; con pista de enemigo real si se encarece.
	var dpers := {"bravery": 0.5, "aggression": 0.3, "curiosity": 0.6, "sociability": 0.6,
		"distrust": 0.35, "cooperation": 0.65, "survival_instinct": 0.75}
	var calm := {"proxy": Node3D.new(), "bot_id": 901, "health": 100.0, "hunger": 80.0, "thirst": 80.0,
		"energy": 80.0, "anim": "idle", "dead": false, "spawned_at_msec": now,
		"_mem": {"personality": dpers, "strategies": {}, "known_locations": {}, "failed_goals": {}}}
	root.add_child(calm["proxy"])
	(calm["proxy"] as Node3D).set_meta("saved_inventory", [])
	manager.stake_override = 0.0
	manager.decide_situational_action(calm, {})
	var u_calm_new: float = float((calm.get("_utility_last", {}).get("explore", {}) as Dictionary).get("u", 0.0))
	manager.stake_override = 1.0
	manager.decide_situational_action(calm, {})
	var u_calm_old: float = float((calm.get("_utility_last", {}).get("explore", {}) as Dictionary).get("u", 0.0))
	check(absf(u_calm_old - u_calm_new) < 0.05,
		"in a calm zone a mature bot explores like a fresh one (%.2f vs %.2f)" % [u_calm_old, u_calm_new])
	# La misma vida madura, pero con pista reciente de enemigo: si se encarece.
	calm["_foe_mem"] = {"t": Time.get_ticks_msec(), "conf": 0.9}
	manager.decide_situational_action(calm, {})
	var u_danger_old: float = float((calm.get("_utility_last", {}).get("explore", {}) as Dictionary).get("u", 0.0))
	check(u_danger_old < u_calm_old - 0.05,
		"with real enemy evidence the mature bot does pay for risk (%.2f vs %.2f)" % [u_danger_old, u_calm_old])
	calm.erase("_foe_mem")
	manager.stake_override = -1.0

	# Inquietud por sedentarismo: crece con el tiempo quieto, la apagan la
	# noche, el peligro vital y las necesidades criticas.
	var settler := {"dead": false, "anim": "idle", "health": 100.0, "hunger": 80.0, "thirst": 80.0, "_roam_still_sec": 0.0}
	check(manager._bot_restlessness(settler) == 0.0, "a bot that just moved feels no restlessness")
	settler["_roam_still_sec"] = 480.0 + 210.0
	check(absf(manager._bot_restlessness(settler) - 0.5) < 0.02, "halfway through the ramp the urge is half")
	settler["_roam_still_sec"] = 480.0 + 420.0
	check(manager._bot_restlessness(settler) == 1.0, "a long-sedentary bot is fully restless")
	manager.night = true
	check(manager._bot_restlessness(settler) == 0.0, "night suppresses restlessness — nobody strolls in the dark")
	manager.night = false
	settler["health"] = 40.0
	check(manager._bot_restlessness(settler) == 0.0, "a badly wounded bot stays put regardless")
	settler["health"] = 100.0
	# Efecto en la decision: la inquietud empuja fuera y desinfla el descanso.
	settler["proxy"] = Node3D.new()
	root.add_child(settler["proxy"])
	(settler["proxy"] as Node3D).set_meta("saved_inventory", [])
	settler["bot_id"] = 901
	settler["energy"] = 80.0
	settler["spawned_at_msec"] = now
	settler["_mem"] = {"personality": dpers, "strategies": {}, "known_locations": {}, "failed_goals": {}}
	settler["shelter_pos"] = Vector3(5, 0, 5)
	settler["shelter_id"] = "test_shelter"
	settler["_roam_still_sec"] = 0.0
	manager.decide_situational_action(settler, {})
	var rest_calm: float = float((settler.get("_utility_last", {}).get("rest", {}) as Dictionary).get("b", 0.0))
	var exp_calm: float = float((settler.get("_utility_last", {}).get("explore", {}) as Dictionary).get("b", 0.0))
	settler["_roam_still_sec"] = 480.0 + 420.0
	manager.decide_situational_action(settler, {})
	var rest_still: float = float((settler.get("_utility_last", {}).get("rest", {}) as Dictionary).get("b", 0.0))
	var exp_still: float = float((settler.get("_utility_last", {}).get("explore", {}) as Dictionary).get("b", 0.0))
	check(exp_still > exp_calm + 0.3, "restlessness boosts exploration (%.2f vs %.2f)" % [exp_still, exp_calm])
	check(rest_still < rest_calm * 0.45, "restlessness deflates home rest (%.2f vs %.2f)" % [rest_still, rest_calm])
	(calm["proxy"] as Node3D).free()
	(settler["proxy"] as Node3D).free()

	# Motor de utilidad: la inversion encarece todo riesgo medio punto.
	var UtilAI = load("res://scripts/BotUtilityAI.gd")
	var pers := {"survival_instinct": 0.7, "distrust": 0.35, "bravery": 0.5, "aggression": 0.3}
	var a0: float = UtilAI.risk_aversion(pers, 0.0)
	var a1: float = UtilAI.risk_aversion(pers, 1.0)
	check(absf(a1 - a0 - 0.5) < 0.001, "a mature life raises risk aversion by half a point")
	check(UtilAI.risk_aversion(pers) == a0, "the stake parameter is optional and backwards compatible")

	manager.free()
	print("BOT_SCORE_STAKE errors=", errors)
	quit(errors)
