extends SceneTree
var errors := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mgr := preload("res://scripts/SurvivorBotManager.gd").new()
	root.add_child(mgr)
	for id in [901, 902, 903]:
		var proxy := Node3D.new()
		root.add_child(proxy)
		mgr.bots[id] = {"bot_id": id, "name": str(id), "proxy": proxy, "faction": "friendly"}
	for pair in [[901,902], [902,901], [901,903], [903,901]]:
		var rel := mgr._chat_touch_rel(pair[0], "bot_%d" % pair[1], str(pair[1]))
		rel.trust = 0.8
		rel.hostility = 0.0
	var victim := mgr._ensure_bot_memory(902)
	victim["killers"] = {"bot_901": {"count": 2, "name": "Elena", "helped_at_death": 0}}
	check(not mgr._bot_pair_can_cooperate(901,902), "Killer cannot assume victim will help")
	check(not mgr._bot_pair_can_cooperate(902,901), "Victim cannot treat repeat killer as ally")
	check(mgr._chat_best_ally(mgr.bots[901]).get("id") == 903, "Select another trusted ally")
	mgr.bots[902].team_leader_id = 901
	check(mgr._chat_best_ally(mgr.bots[901]).get("id") == 903, "Team membership cannot bypass murder history")
	var rel := mgr.get_bot_relationship(902,"bot_901")
	var before := float(rel.trust)
	for i in range(10):
		mgr.on_chat_received(902,901,"Elena","hola")
	check(rel.trust == before, "Greetings cannot repair murder history")
	mgr.on_chat_received(902,901,"Elena","ayuda")
	check(int(mgr.bots[902].get("_meet_id",0)) == 0, "Victim makes no rescue promise to killer")
	rel.helped = 5
	check(not mgr._bot_pair_can_cooperate(901,902), "Two killings require more than five reparations")
	rel.helped = 6
	check(mgr._bot_pair_can_cooperate(901,902), "Real reparations and mutual trust permit eventual cooperation")
	rel.harm_t = Time.get_ticks_msec()
	check(not mgr._bot_pair_can_cooperate(901,902), "Fresh violence cancels reconciliation")
	for b in mgr.bots.values(): b.proxy.free()
	mgr.free()
	print("BOT_BILATERAL_TRUST errors=",errors)
	quit(errors)
