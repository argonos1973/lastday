extends SceneTree
## Reproducible same-process comparison against the pre-phase manager.
## The baseline is compiled in memory; the checkout and production are untouched.
const Manager = preload("res://scripts/SurvivorBotManager.gd")
const Fixtures = preload("res://tools/debug/BotPlanReliabilityRegression.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output: Array = []
	if OS.execute("git", ["show", "f1e1748:scripts/SurvivorBotManager.gd"], output) != 0:
		push_error("Cannot load required baseline f1e1748")
		quit(2)
		return
	var baseline_script := GDScript.new()
	baseline_script.source_code = str(output[0]).replace("class_name SurvivorBotManager", "")
	if baseline_script.reload() != OK:
		quit(3)
		return
	var world := Fixtures.TestWorld.new()
	root.add_child(world)
	current_scene = world
	var net := Fixtures.FakeNet.new()
	root.add_child(net)
	world.net = net
	var dc := Fixtures.FakeDayCycle.new()
	world.add_child(dc)
	world.day_cycle = dc
	seed(20261119)
	var current := Manager.new()
	world.add_child(current)
	current.setup(world)
	current.set_physics_process(false)
	current.set_process(false)
	var baseline = baseline_script.new()
	baseline.world = world
	baseline.bots = current.bots
	baseline._memory = current._memory
	var now := Time.get_ticks_msec()
	for id in current.bots:
		var b: Dictionary = current.bots[id]
		b["health"] = 90.0
		b["hunger"] = 90.0
		b["thirst"] = 90.0
		b["vstats"].sleep = 90.0
		b["vstats"].body_temperature = 36.6
		b["vstats"].bleeding = 0.0
		b["ai_directive"] = {"action": "scavenge", "target": "military", "mode": "pos",
			"pos": Vector3(300, 0.4, 200), "_prog_ref_ms": now, "_step_deadline_ms": now + 600000,
			"_prog_ref_m": b["proxy"].global_position.distance_to(Vector3(300, 0.4, 200)),
			"_ev0": {"loot": 0}, "source": "local_fallback"}
		current.PlanManager.sync(current, b, now)
	var measurements := {}
	for label in ["before", "after"]:
		var m = baseline if label == "before" else current
		var times: Array = []
		for trial in range(5):
			var t0 := Time.get_ticks_usec()
			for i in range(2000):
				for b in current.bots.values():
					m._ai_step_stalled(b, b["ai_directive"], now)
			times.append((Time.get_ticks_usec() - t0) / 8000.0)
		times.sort()
		var t1 := Time.get_ticks_usec()
		var snap: Dictionary = {}
		for i in range(25):
			snap = m.get_full_web_status()
		var status_ms := (Time.get_ticks_usec() - t1) / 25000.0
		measurements[label] = {"watchdog_us_per_bot": times[2], "status_ms": status_ms,
			"status_bytes": JSON.stringify(snap).to_utf8_buffer().size()}
		print("PLAN_PERF ", label, " ", JSON.stringify(measurements[label]))
	var extra_tick_us: float = maxf(0.0, measurements.after.watchdog_us_per_bot - measurements.before.watchdog_us_per_bot) * 4.0
	# Four bots have <1ms total overhead even if the full watchdog were called
	# every tick (actual watchdog polling is much less frequent).
	if extra_tick_us >= 1000.0:
		failures += 1
		push_error("Planning adds >=1ms for four bots")
	if measurements.after.status_bytes - measurements.before.status_bytes > 60000:
		failures += 1
		push_error("Unexpected telemetry growth")
	var out := FileAccess.open("res://build/tmp/phase1-performance.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(measurements))
	out.close()
	baseline.free()
	world.queue_free()
	net.queue_free()
	await process_frame
	print("BotPlanPerformanceRegression errors=", failures)
	quit(1 if failures else 0)
