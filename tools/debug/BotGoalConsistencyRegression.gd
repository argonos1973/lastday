extends SceneTree

var errors := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manager := preload("res://scripts/SurvivorBotManager.gd").new()
	var proxy := Node3D.new()
	root.add_child(proxy)
	var stats := SurvivalStats.new()
	var b := {"proxy": proxy, "health": 100.0, "vstats": stats}
	var rest := {"action": "rest", "pos": Vector3.ZERO}
	stats.sleep = 20.0
	check(not manager._ai_directive_completed(b, rest), "Healthy but exhausted bot must finish sleeping")
	stats.sleep = 90.0
	b.health = 40.0
	check(not manager._ai_directive_completed(b, rest), "Rested but injured bot must still recover")
	b.health = 100.0
	check(manager._ai_directive_completed(b, rest), "Recovered bot completes rest")
	for action in ["return_home", "seek_ally", "fortify_camp", "explore", "rest"]:
		var goal := {"action": action, "pos": Vector3(0, 4, 0)}
		check(not manager._ai_directive_completed(b, goal), "Cannot complete %s from the floor below" % action)
		proxy.position.y = 4.0
		check(manager._ai_directive_completed(b, goal), "Can complete %s on the correct floor" % action)
		proxy.position.y = 0.0
	var seen := Vector3(8, 0, 8)
	manager._ai_note_foe_intel(b, null, seen, "seen")
	manager._ai_note_foe_intel(b, null, Vector3(80, 0, 80), "heard")
	check(b._last_foe_pos == seen and b._foe_mem.pos == seen,
		"Weak recent clue cannot overwrite either stored visual position")
	b._foe_mem.t = Time.get_ticks_msec() - 5000
	manager._ai_note_foe_intel(b, null, Vector3(80, 0, 80), "heard")
	check(b._last_foe_pos == b._foe_mem.pos and b._foe_mem.src == "heard",
		"Accepted newer clue updates both representations consistently")
	proxy.free()
	manager.free()
	print("BOT_GOAL_CONSISTENCY errors=", errors)
	quit(0 if errors == 0 else 1)
