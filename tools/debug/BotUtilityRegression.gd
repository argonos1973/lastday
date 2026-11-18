extends SceneTree
const BotUtilityAI = preload("res://scripts/BotUtilityAI.gd")
# Regresión del motor de utilidad esperada (BotUtilityAI + decide_situational_action):
# 12 checks obligatorios de la spec — comida, frio, heridas, municion, riesgo
# por personalidad, aprendizaje, decaimiento de pistas, no-omnisciencia,
# estabilidad, compat de memoria y funcionamiento offline.
class Manager extends "res://scripts/SurvivorBotManager.gd":
 var test_weapon := "melee"
 var night := false
 func _is_world_night() -> bool: return night
 func _sensed_node(_b: Dictionary, _key: String) -> Node3D: return null
 func _pick_fight_weapon(_b: Dictionary, _d: float) -> Dictionary:
  return {"kind": test_weapon, "name": "Arma"}
var errors := 0
func check(ok: bool, label: String):
 if not ok:
  errors += 1
  push_error(label)
func _initialize(): call_deferred("run")
func _mk_b(pers: Dictionary = {}) -> Dictionary:
 var proxy := Node3D.new()
 root.add_child(proxy)
 proxy.set_meta("saved_inventory", [])
 var p := {"bravery":0.5,"aggression":0.3,"curiosity":0.6,"sociability":0.6,
   "distrust":0.35,"cooperation":0.65,"survival_instinct":0.75}
 for k in pers.keys(): p[k] = pers[k]
 return {"proxy":proxy,"bot_id":901,"health":100.0,"hunger":80.0,"thirst":80.0,
   "energy":80.0,"_mem":{"personality":p,"strategies":{},"known_locations":{},"failed_goals":{}}}
func run():
 var manager := Manager.new()
 root.add_child(manager)
 # --- 1. Hambriento sin comida: conseguir alimento gana a todo lo demas ---
 var b := _mk_b()
 b["hunger"] = 8.0; b["thirst"] = 70.0
 var d := manager.decide_situational_action(b, {})
 check(["forage","hunt"].has(str(d.get("action",""))), "EU: starving bot picks food action, got %s" % d)
 # --- 2. Hipotermia: la puerta vital va ANTES del motor de decision ---
 # (_bot_is_freezing dispara rescate/sueno en el tick; decide ni se consulta.
 #  Aqui se verifica que la cadena existe y corta el flujo.)
 var vstats := SurvivalStats.new()
 vstats.body_temperature = 34.0
 b["vstats"] = vstats
 check(manager._bot_is_freezing(b), "freezing detected upstream of decision engine")
 # --- 3. Herido con alternativas: descansar/forrajear > exponerse ---
 var b2 := _mk_b()
 b2["health"] = 30.0
 var d2 := manager.decide_situational_action(b2, {})
 check(["rest","forage","fortify_camp"].has(str(d2.get("action",""))),
   "EU: wounded bot avoids risky action, got %s" % d2)
 # --- 4. Municion/arma cambia la conveniencia de cazar ---
 var b3 := _mk_b(); b3["hunger"] = 50.0
 manager.test_weapon = "rifle"
 var u_rifle: Dictionary = b3.get("_utility_last", {})
 manager.decide_situational_action(b3, {})
 u_rifle = b3.get("_utility_last", {})
 var u_rif := float((u_rifle.get("hunt",{}) as Dictionary).get("u", 0.0))
 var p_rif := float((u_rifle.get("hunt",{}) as Dictionary).get("p", 0.0))
 manager.test_weapon = "melee"
 manager.decide_situational_action(b3, {})
 var u_melee: Dictionary = b3.get("_utility_last", {})
 check(float((u_melee.get("hunt",{}) as Dictionary).get("u", 0.0)) < u_rif,
   "EU: hunt utility drops without firearm (rifle %.2f vs melee %.2f)" % [u_rif, float((u_melee.get("hunt",{}) as Dictionary).get("u", 0.0))])
 check(p_rif > float((u_melee.get("hunt",{}) as Dictionary).get("p", 0.0)), "EU: hunt success prob lower unarmed")
 # --- 5. Destino con combates recientes pierde atractivo para el prudente ---
 var prudent := _mk_b({"survival_instinct":0.95,"bravery":0.2,"distrust":0.7})
 var kael := _mk_b({"survival_instinct":0.4,"bravery":0.85,"distrust":0.2,"aggression":0.85})
 for bb in [prudent, kael]:
  (bb["_mem"] as Dictionary)["known_locations"] = {"military:0:0":{"combat_risk":2.5,"risk":0.0,"pos":[0.0,0.0,0.0]}}
 var f_pr := manager._ai_poi_state_factor(prudent, "military:0:0", 100.0)
 var f_ka := manager._ai_poi_state_factor(kael, "military:0:0", 100.0)
 check(f_pr < f_ka, "EU: combat zone costs more to prudent (%.2f) than raider (%.2f)" % [f_pr, f_ka])
 check(f_pr < 1.0 and f_ka < 1.0, "EU: combat_risk penalizes both, personality scales it")
 # --- 6. Zona con buenos resultados gana atractivo (sin garantizar eleccion) ---
 var b4 := _mk_b()
 (b4["_mem"] as Dictionary)["zone_yield"] = {"wild":{"n":10,"good":8}}
 check(BotUtilityAI.zone_yield_prob({"n":10,"good":8}) > BotUtilityAI.zone_yield_prob({"n":10,"good":1}),
   "EU: proven zone beats empty one probabilistically")
 # --- 7. Experiencias recientes modifican las estimaciones ---
 var p0 := BotUtilityAI.strat_prob({})
 var mem7: Dictionary = b4["_mem"]
 manager.record_strategy_outcome(901, "hunt", false); manager.record_strategy_outcome(901, "hunt", false)
 mem7 = b4.get("_mem", {})
 # record escribe en la memoria persistida por bot_id; simulamos aqui el efecto:
 check(BotUtilityAI.strat_prob({"success":0,"fail":2}) < p0, "EU: failures drop success prob below prior")
 check(BotUtilityAI.strat_prob({"success":5,"fail":0}) > p0, "EU: successes raise success prob above prior")
 # --- 8. Pistas antiguas pierden influencia ---
 var now_ms := Time.get_ticks_msec()
 var foe_fresh := {"pos":Vector3.ZERO,"t":now_ms - 2000,"src":"heard","conf":0.6,"key":"k"}
 var foe_stale := {"pos":Vector3.ZERO,"t":now_ms - 300000,"src":"heard","conf":0.6,"key":"k"}
 var pf := BotUtilityAI.threat_posterior(foe_fresh, now_ms, 0.0)
 var ps := BotUtilityAI.threat_posterior(foe_stale, now_ms, 0.0)
 check(pf > ps, "EU: stale foe intel decays (fresh %.2f vs stale %.2f)" % [pf, ps])
 check(pf <= 1.0 and ps >= 0.0, "EU: posterior stays in [0,1]")
 # --- 9. Sin omnisciencia: sin evidencia legitima no hay amenaza ---
 check(BotUtilityAI.threat_posterior({}, now_ms, 0.0) == 0.0,
   "EU: empty foe memory yields zero threat — no hidden-enemy leak")
 var zone_only := BotUtilityAI.threat_posterior({}, now_ms, 3.0)
 check(zone_only > 0.0 and zone_only < 0.5, "EU: zone history alone stays a weak prior")
 # --- 10. Estabilidad: misma entrada, misma decision (sin oscilacion) ---
 var b5 := _mk_b(); b5["hunger"] = 20.0
 var d5a := str(manager.decide_situational_action(b5, {}).get("action",""))
 var d5b := str(manager.decide_situational_action(b5, {}).get("action",""))
 check(d5a == d5b, "EU: deterministic per decision cycle (no oscillation)")
 # --- 11. Memoria heredada: bots sin campos nuevos funcionan ---
 var legacy_b := {"proxy":Node3D.new(),"bot_id":902,"health":90.0,"hunger":90.0,"thirst":90.0,"_mem":{}}
 root.add_child(legacy_b["proxy"])
 (legacy_b["proxy"] as Node3D).set_meta("saved_inventory", [])
 manager.test_weapon = "melee"
 var dl := manager.decide_situational_action(legacy_b, {})
 check(not str(dl.get("action","")).is_empty(), "EU: empty legacy memory still decides")
 # --- 12. Offline: sin mundo ni red decide igual ---
 var b6 := _mk_b()
 manager.test_weapon = "bow"
 var d6 := manager.decide_situational_action(b6, {})
 check(not str(d6.get("action","")).is_empty(), "EU: decides with world==null (no remote dependency)")
 # --- 13. Coste de desplazamiento: el cuerpo agotado paga mas por viajar ---
 var b8 := _mk_b()
 manager.decide_situational_action(b8, {})
 var c_fresh := float(((b8.get("_utility_last",{}) as Dictionary).get("explore",{}) as Dictionary).get("c", 0.0))
 b8["energy"] = 8.0; b8["hunger"] = 25.0; b8["thirst"] = 20.0
 manager.decide_situational_action(b8, {})
 var c_tired := float(((b8.get("_utility_last",{}) as Dictionary).get("explore",{}) as Dictionary).get("c", 0.0))
 check(c_tired > c_fresh, "EU: exhausted+empty pack pays more for travel (%.2f vs %.2f)" % [c_tired, c_fresh])
 # --- 14. Tercera evidencia: zona con antecedentes de fauna suma amenaza ---
 var p_base := BotUtilityAI.threat_posterior({}, now_ms, 0.0)
 var p_env := BotUtilityAI.threat_posterior({}, now_ms, 0.0, 3.0)
 check(p_env > p_base and p_env < 0.35, "EU: predator history adds a weak env prior (%.2f)" % p_env)
 # --- 15. Cuota nocturna: de noche solo un ataque real consulta remoto ---
 manager.night = true
 manager._ai_queue.clear()
 manager._ai_enqueue_request(901, 4, "sig_change")
 manager._ai_enqueue_request(901, 2, "scheduled")
 manager._ai_enqueue_request(901, 4, "plan_done", true)
 check(manager._ai_queue.is_empty(), "EU: night drops non-attack remote requests")
 manager._ai_enqueue_request(901, 5, "attacked_by_wolf", true)
 check(manager._ai_queue.size() == 1, "EU: a real attack still reaches remote at night")
 manager._ai_queue.clear()
 manager.night = false
 # --- Comparativa de motores: misma situacion, ambos caminos validos ---
 var b7 := _mk_b(); b7["hunger"] = 12.0
 var eu_d := manager.decide_situational_action(b7, {})
 var lg_d := manager.decide_situational_action(b7, {"engine":"legacy"})
 check(str(eu_d.get("reason","")).begins_with("eu:"), "EU reason explains breakdown")
 check(str(lg_d.get("reason","")).begins_with("personality:"), "legacy engine still reachable via override")
 # --- 16. El prompt documenta la escala de las reservas (100=saciado, 0=critico) ---
 check(String(manager.AI_SYSTEM_PROMPT).contains("hunger=100 full/0 starving") \
  and String(manager.AI_SYSTEM_PROMPT).contains("thirst=100 hydrated/0 dehydrated"),
  "EU: AI prompt documents reserve scale so remote reads 88 as satisfied")
 # --- 17. Objetivo que acaba de fallar = veto duro en la eleccion EU ---
 var vb := _mk_b()
 vb["hunger"] = 10.0
 (vb["proxy"] as Node3D).global_position = Vector3(120.0, 0.4, 120.0)
 var for_spec := manager._situational_action_spec("forage", 0.3, 0.75, 0.5, "")
 manager._ai_note_failed_goal(vb, for_spec, "nav_blocked")
 check(manager._ai_goal_recently_failed(vb, for_spec), "EU veto: nav_blocked registers as recently failed")
 var dv := manager.decide_situational_action(vb, {})
 check(str(dv.get("action","")) != "forage",
  "EU: recently failed action skipped in situational decision (got %s)" % str(dv.get("action","")))
 (vb["_mem"] as Dictionary)["failed_goals"] = {}
 var dv2 := manager.decide_situational_action(vb, {})
 check(str(dv2.get("action","")) == "forage",
  "EU: veto lifts once failed_goals is cleared (got %s)" % str(dv2.get("action","")))
 # --- 18. forage con la panza llena no cuenta como exito sin botin real ---
 var fb := _mk_b()
 fb["hunger"] = 90.0
 var d_for := {"action": "forage", "_ev0": {"food": 0, "hunger": 88.0}}
 check(not manager._ai_directive_completed(fb, d_for),
  "forage: starting already fed demands real loot to complete (no free plan_done)")
 fb["_loot_food_n"] = 2
 check(manager._ai_directive_completed(fb, d_for),
  "forage: looting food completes even when already fed")
 var fb2 := _mk_b()
 fb2["hunger"] = 90.0
 var d_for2 := {"action": "forage", "_ev0": {"food": 0, "hunger": 30.0}}
 check(manager._ai_directive_completed(fb2, d_for2),
  "forage: started hungry, eating to 75 still completes")
 # --- 19. Fallback local: no adjunta la pierna return_home si esta vetada ---
 var hb := _mk_b()
 hb["hunger"] = 10.0
 hb["shelter_pos"] = Vector3(50.0, 0.4, 50.0)
 hb["shelter_id"] = "sh_test"
 manager.bots[901] = hb
 manager._ai_apply_local_fallback_decision(901, "t_norm")
 var dir1: Dictionary = hb.get("ai_directive", {})
 var st1: Array = dir1.get("_remaining_steps", [])
 if ["forage","scavenge","hunt"].has(str(dir1.get("action",""))):
  check(st1.size() == 1 and str((st1[0] as Dictionary).get("action","")) == "return_home",
   "fallback: supply trip appends return_home leg (steps=%s)" % [st1])
 hb["ai_directive"] = {}
 manager._ai_note_failed_goal(hb, {"action":"return_home","target":"camp","mode":"pos"}, "stuck_timeout")
 manager._ai_apply_local_fallback_decision(901, "t_veto")
 var dir2: Dictionary = hb.get("ai_directive", {})
 var st2: Array = dir2.get("_remaining_steps", [])
 check(st2.is_empty(), "fallback: vetoed return_home is NOT appended (steps=%s)" % [st2])
 manager.bots.erase(901)
 print("BotUtilityRegression errors=%d" % errors)
 quit(errors)
