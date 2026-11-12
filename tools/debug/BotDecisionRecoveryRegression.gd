extends SceneTree
class Arena extends Node3D:
	var world_actions_by_id := {}
	var _pickup_claims := {}
	var _depleted_action_ids := []
class Manager extends "res://scripts/SurvivorBotManager.gd":
	func _ensure_world_action_caches() -> void: pass
class Action extends Node3D:
	var action_type := "eat_food"
class Enemy extends Node3D:
	var is_dead := false
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var world := Arena.new()
	root.add_child(world)
	var manager := Manager.new()
	world.add_child(manager)
	manager.world = world
	var proxy := Node3D.new()
	world.add_child(proxy)
	var blocked := Action.new()
	world.add_child(blocked)
	blocked.position = Vector3(3,0,0)
	var accessible := Action.new()
	world.add_child(accessible)
	accessible.position = Vector3(30,0,0)
	world.world_actions_by_id = {"blocked":blocked,"accessible":accessible}
	manager._cached_eat_ids = ["blocked","accessible"]
	var b := {"proxy":proxy,"_unreachable":[{"pos":blocked.position,"until":Time.get_ticks_msec()/1000.0+100.0}]}
	check(manager._find_forage_target(b,60).get("id") == "accessible", "choose alternative food after a navigation failure")
	blocked.action_type = "pick_fruit"
	accessible.action_type = "pick_fruit"
	manager._cached_eat_ids = []
	manager._cached_fruit_ids = ["blocked","accessible"]
	check(manager._find_forage_target(b,60).get("id") == "accessible", "fruit respects unreachable zones")
	b._unreachable[0].until = -1.0
	check(manager._find_forage_target(b,60).get("id") == "blocked", "resource can be retried after temporary exclusion expires")
	var enemy := Enemy.new()
	world.add_child(enemy)
	b._s_foe = enemy
	check(manager._sensed_node(b,"_s_foe") == enemy,"live opponent remains sensed")
	enemy.is_dead = true
	check(manager._sensed_node(b,"_s_foe") == null,"dead opponent no longer blocks survival decisions")
	b._s_corpse = enemy
	check(manager._sensed_node(b,"_s_corpse") == enemy,"corpse remains available to scavenge")
	enemy.is_dead = false
	b.aggro_target = enemy
	b._ambush = {"target_id":8}
	b.crouching = true
	proxy.set_meta("crouching",true)
	check(not manager._bot_try_ambush(b,.1) and b._ambush.is_empty() and not b.crouching, "actual attacker interrupts stalking posture")
	# --- Saludos del ciclo de sueño: "buenas noches" al dormir, "buenos dias" al despertar ---
	check(manager._chat_classify("buenas noches, que descanses") == "goodnight", "classify buenas noches -> goodnight")
	check(manager._chat_classify("buenos dias, companero") == "goodmorning", "classify buenos dias -> goodmorning")
	check(manager._chat_classify("hola, que tal") == "greet", "classify hola sigue greet")
	check("noches" in manager._chat_fallback_line(b,"goodnight","Carlos"), "goodnight fallback line says noches")
	check("día" in manager._chat_fallback_line(b,"goodmorning","Carlos"), "goodmorning fallback line says dias")
	check("noches" in manager._chat_fallback_reply(b,"goodnight","Carlos"), "goodnight reply devuelve noches")
	check("día" in manager._chat_fallback_reply(b,"goodmorning","Carlos"), "goodmorning reply devuelve dias")
	# Despedida por pareja: una vez por ciclo, y se resetea con el ciclo contrario.
	var p1 := Node3D.new(); world.add_child(p1); p1.position = Vector3(0,0,0)
	var p2 := Node3D.new(); world.add_child(p2); p2.position = Vector3(3,0,0)
	var sender := {"bot_id":901,"name":"Elena","proxy":p1,"_mem":{}}
	manager.bots[901] = sender
	manager.bots[902] = {"bot_id":902,"name":"Carlos","proxy":p2,"_mem":{}}
	var log_n := manager.chat_log.size()
	manager._bot_say_farewell(sender,"goodnight")
	check(manager.chat_log.size() == log_n+1 and str(manager.chat_log.back().get("kind","")) == "goodnight",
		"goodnight llega al bot cercano una vez")
	manager._bot_say_farewell(sender,"goodnight")
	check(manager.chat_log.size() == log_n+1, "goodnight no se repite en el mismo ciclo")
	manager._bot_say_farewell(sender,"goodmorning")
	check(manager.chat_log.size() == log_n+2 and str(manager.chat_log.back().get("kind","")) == "goodmorning",
		"goodmorning tras despertar")
	manager._bot_say_farewell(sender,"goodnight")
	check(manager.chat_log.size() == log_n+3 and str(manager.chat_log.back().get("kind","")) == "goodnight",
		"el ciclo contrario reabra la pareja para la noche siguiente")
	# El bot que recibe la despedida la clasifica y puede responderla.
	manager.on_chat_received(902, 901, "Elena", "buenas noches, Carlos")
	check(not (manager.bots[902].get("_chat_inbox",{}) as Dictionary).is_empty()
		and str((manager.bots[902].get("_chat_inbox",{}) as Dictionary).get("intent","")) == "goodnight",
		"el receptor entiende la despedida como goodnight")
	# Al dormirse de noche el bot despide; el colapso letal no charla.
	var sleeper := {"bot_id":901,"name":"Elena","proxy":p1,"_mem":{},"vstats":SurvivalStats.new(),
		"sleeping":false,"team_leader_id":0,"hide_timer":0.0,"aggro_target":null,
		"hunger":50.0,"thirst":50.0,"sitting":false,"crouching":false,"prone":false,"anim":"idle",
		"_gn_pairs":[],"_gm_pairs":[]}
	sleeper["vstats"].body_temperature = 36.5
	sleeper["vstats"].sleep = 40.0
	sleeper["vstats"].energy = 50.0
	var log_n2 := manager.chat_log.size()
	# Historial reciente del bot limpio: es una instancia nueva y el antirepeat
	# de _bot_chat_send descartaria la misma variante de despedida ya dicha.
	manager._chat_recent[901] = []
	var said_gn := false
	var slept := manager._bot_try_start_sleep(sleeper, true)
	for e in manager.chat_log.slice(log_n2):
		if str(e.get("kind", "")) == "goodnight" and int(e.get("from_id", 0)) == 901:
			said_gn = true
	check(slept and said_gn, "dormirse de noche despide a los cercanos")
	var log_n3 := manager.chat_log.size()
	sleeper["sleeping"] = false
	sleeper["vstats"].sleep = 3.0 # colapso letal
	manager.bots.erase(902) # sin nadie cerca
	var collapse_ok := manager._bot_try_start_sleep(sleeper, true)
	var said_gn2 := false
	for e in manager.chat_log.slice(log_n3):
		if str(e.get("kind", "")) == "goodnight" and int(e.get("from_id", 0)) == 901:
			said_gn2 = true
	check(collapse_ok and not said_gn2, "el colapso letal no despide")
	world.free()
	print("BOT_DECISION_RECOVERY errors=",errors)
	quit(errors)
