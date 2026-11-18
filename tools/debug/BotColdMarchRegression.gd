extends SceneTree

var failures := 0

class MarchManager extends SurvivorBotManager:
	var block_steps := false
	var probes: Array[Vector3] = []
	var move_targets: Array[Vector3] = []
	func _is_step_blocked(_from: Vector3, to: Vector3, _allow_deep := false) -> bool:
		probes.append(to)
		return block_steps
	func _move_bot_towards(b: Dictionary, goal: Vector3, _speed: float, _delta: float, _anim: String) -> void:
		move_targets.append(goal)
		b["anim"] = "idle" # Reproduce a blocked doorway without moving the actor.

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mgr := MarchManager.new()
	root.add_child(mgr)
	var proxy := Node3D.new()
	root.add_child(proxy)
	proxy.position = Vector3(200, 0.4, 200)
	var stats := SurvivalStats.new()
	stats.body_temperature = 34.0
	var b := {"bot_id": 901, "proxy": proxy, "vstats": stats, "sleeping": false}

	# A failed search must advance the local RNG without touching global RNG.
	mgr.block_steps = true
	seed(123)
	var expected := randf()
	seed(123)
	check(not mgr._bot_freeze_march(b, 0.1), "blocked search cannot start walking")
	var first := mgr.probes.duplicate()
	mgr.probes.clear()
	check(not mgr._bot_freeze_march(b, 0.1), "second blocked search also yields")
	check(mgr.probes != first, "failed search must try different destinations")
	check(is_equal_approx(randf(), expected), "march does not consume gameplay RNG")

	# A destination rejected by navigation must never be reused.
	mgr.block_steps = false
	var old_target := proxy.position + Vector3(8, 0, 0)
	b["_freeze_march"] = {"anchor": proxy.position, "pos": old_target, "n": 0}
	b["_unreachable"] = [{"pos": old_target, "until": Time.get_ticks_msec() / 1000.0 + 60.0}]
	mgr._bot_freeze_march(b, 0.1)
	check(not mgr.move_targets.has(old_target), "blacklisted march destination is released")
	b["_unreachable"] = []
	b.erase("_freeze_march")
	mgr.move_targets.clear()
	check(mgr._bot_freeze_march(b, 0.1), "cold bot can plan a short march")
	check(str(b.get("anim", "")) == "idle", "march preserves the navigator's stopped animation")
	for i in range(32):
		mgr._bot_freeze_march(b, 0.1)
	var tried_other := false
	for target in mgr.move_targets:
		if target != mgr.move_targets[0]:
			tried_other = true
	check(tried_other, "a stalled march releases its target after three seconds")

	# Relocation (e.g. retreat) must not retain a target at the previous anchor.
	b["_freeze_march"] = {"anchor": Vector3.ZERO, "pos": Vector3(8, 0, 0)}
	mgr.move_targets.clear()
	mgr._bot_freeze_march(b, 0.1)
	check(not mgr.move_targets.is_empty() and mgr.move_targets[0].distance_to(proxy.position) <= 13.1,
		"relocated bot chooses a march near its new position")
	stats.body_temperature = 36.6
	check(not mgr._bot_freeze_march(b, 0.1), "warm bot stops the emergency march")
	stats.free()
	proxy.free()
	mgr.free()
	print("BotColdMarchRegression failures=", failures)
	quit(1 if failures else 0)
