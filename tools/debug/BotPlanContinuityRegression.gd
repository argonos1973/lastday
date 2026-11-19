extends SceneTree
## Actual manager + existing isolated world. Clock injection accelerates long
## interruptions; no remote calls, full map generation or player save writes.
const Fixtures = preload("res://tools/debug/BotPlanReliabilityRegression.gd")
const Manager = preload("res://scripts/SurvivorBotManager.gd")
const Plans = preload("res://scripts/bot_ai/BotPlanManager.gd")
const Goals = preload("res://scripts/bot_ai/BotGoalValidator.gd")
const Diagnostics = preload("res://scripts/bot_ai/BotPlanDiagnostics.gd")
var failures := 0
var snapshots: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func reset_bot(m, b: Dictionary, pos: Vector3) -> void:
	b["ai_directive"] = {}
	b["proxy"].global_position = pos
	b["proxy"].set_meta("proxy_dead", false)
	b["proxy"].set_meta("proxy_health", 95.0)
	b["proxy"].set_meta("saved_inventory", [])
	b["health"] = 95.0
	b["hunger"] = 85.0
	b["thirst"] = 85.0
	b["energy"] = 90.0
	b["sleeping"] = false
	b["sitting"] = false
	b["hide_timer"] = 0.0
	b["flee_until"] = 0.0
	b["aggro_target"] = null
	b["_s_predator"] = null
	b["_s_foe"] = null
	b["_act"] = "explore"
	b["team_leader_id"] = 0
	b["shelter_pos"] = pos
	b["camp_spot"] = pos
	b["gut_target"] = null
	b["_loot_n"] = 0
	b["_loot_food_n"] = 0
	b["_plan_loot"] = {}
	for key in ["_gather", "_s_loot", "_craft_state", "_forage", "_farm", "_ambush", "_salvage"]:
		b[key] = {}
	var st: SurvivalStats = b["vstats"]
	st.health = 95.0
	st.hunger = 85.0
	st.thirst = 85.0
	st.sleep = 80.0
	st.energy = 90.0
	st.bleeding = 0.0
	st.body_temperature = 36.6
	b["_mem"] = m._ensure_bot_memory(int(b["bot_id"]))
	b["_mem"]["failed_goals"] = {}
	b["_mem"]["known_locations"] = {
		"military:300:200": {"id": "military:300:200", "kind": "military", "pos": [300.0, 0.4, 200.0]},
	}

func capture(m, label: String) -> void:
	var snap: Dictionary = m.get_full_web_status()
	snap["test_label"] = label
	snapshots.append(snap)

func verify_disk_resume(m, actor: Dictionary) -> void:
	m.force_memory_io = true
	m._ai_save_memory()
	m._ai_flush_writes()
	m.force_memory_io = false
	var prompt: Dictionary = JSON.parse_string(m._ai_build_prompt(actor))
	check(not (prompt["pending_steps"][0] as Dictionary).has("_runtime")
			and prompt["pending_steps"].size() == actor["_mem"]["pending_goals"].size(),
		"Advisor receives the remaining decisions without persistence/checkpoint token overhead")
	var restored := Manager.new()
	restored.force_memory_io = true
	restored.memory_path = m.memory_path
	restored._ai_load_memory()
	restored.world = m.world
	restored.bots = m.bots.duplicate(true)
	for bid in restored.bots:
		restored.bots[bid]["_mem"] = restored._ensure_bot_memory(int(bid))
	var next_actor: Dictionary = restored.bots[int(actor["bot_id"])]
	next_actor["ai_directive"] = {}
	restored._ai_resume_pending_plan(int(actor["bot_id"]))
	var expected: Dictionary = actor["ai_directive"]
	var actual: Dictionary = next_actor["ai_directive"]
	check(actual.get("plan_id") == expected["plan_id"] and actual.get("step_index") == expected["step_index"]
			and actual.get("_remaining_steps", []).size() == expected["_remaining_steps"].size(),
		"Fresh manager resumes the saved step from disk without replaying completed steps")
	check(actual.get("_dest_pos") == expected["_dest_pos"] and actual.get("source") == "memory",
		"Fresh manager revalidates and retains the saved destination")
	if expected.has("_ally_id"):
		check(actual.get("_ally_id") == expected["_ally_id"],
			"Restart keeps the intended ally even when another ally is now closer")
	restored.force_memory_io = false
	restored.free()

func run() -> void:
	seed(20261119)
	var world := Fixtures.TestWorld.new()
	root.add_child(world)
	current_scene = world
	var net := Fixtures.FakeNet.new()
	root.add_child(net)
	world.net = net
	var dc := Fixtures.FakeDayCycle.new()
	world.add_child(dc)
	world.day_cycle = dc
	var m := Manager.new()
	world.add_child(m)
	world.survivor_bot_mgr = m
	m.memory_path = "res://build/tmp/phase1-test-memory.json"
	m.setup(world)
	m.set_physics_process(false)
	m.set_process(false)
	for id in m.bots:
		reset_bot(m, m.bots[id], Vector3(int(id) * 0.1, 0.4, 10))
	var b: Dictionary = m.bots[902]
	var trip := {"steps": [
		{"action": "scavenge", "target": "military", "goal": "gear_up_at_military_base", "priority": 4},
		{"action": "return_home", "target": "camp"},
		{"action": "rest", "target": "camp"},
	]}
	check(m._ai_apply_decision(902, JSON.stringify(trip)), "Qwen multi-step plan accepted")
	var d: Dictionary = b["ai_directive"]
	check(d.get("state") == "RUNNING" and int(d.get("total_steps", 0)) == 3, "RUNNING with three steps")
	check(d.get("_dest_pos") == Vector3(300, 0.4, 200), "Gear mission targets a known military location")
	var id: String = d["plan_id"]
	var start := Time.get_ticks_msec()
	d["_clock_ms"] = start
	d["_step_deadline_ms"] = start + 150000
	d["_prog_ref_ms"] = start
	capture(m, "running")
	# The real sleep entry point suspends, while SurvivalStats keeps running.
	dc.time_of_day = 23.5
	b["vstats"].sleep = 35.0
	check(m._bot_try_start_sleep(b, true), "Real nighttime sleep entry")
	check(d.get("state") == "SUSPENDED", "Sleep suspends the strategic plan immediately")
	var active_before := int(d["active_ms"])
	d["_clock_ms"] = start
	d["_suspend_ms"] = start
	var deadline := int(d["_step_deadline_ms"])
	Plans.sync(m, b, start + 8 * 3600000)
	check(int(d["active_ms"]) == active_before, "Eight hours of sleep add no active execution time")
	check(int(d["suspended_ms"]) == 8 * 3600000, "Eight hours counted once as suspension")
	check(int(d["_step_deadline_ms"]) == deadline + 8 * 3600000, "Deadline compensated exactly")
	check(m._ai_step_stalled(b, d, start + 8 * 3600000) == "", "No sleep timeout/no_progress")
	var hunger_before := float(b["hunger"])
	m._bot_survival_tick(b, 1.0)
	check(float(b["hunger"]) < hunger_before and float(b["vstats"].sleep) > 35.0,
		"Sleeping retains hunger consumption and sleep recovery")
	var q_before: int = m._ai_queue.size()
	var calls_before: int = m._ai_calls_total
	m._ai_enqueue_request(902, 5, "attacked_by_wolf", true)
	check(m._ai_queue.size() == q_before and m._ai_calls_total == calls_before, "Suspension makes no combat/sleep API request")
	check(m._ai_apply_decision(902, '{"action":"explore","target":"wild","priority":5}'), "Late remote response handled")
	check(b["ai_directive"]["plan_id"] == id and b["_ai_last_apply"] == "kept", "Late response cannot replace suspended plan")
	capture(m, "sleeping")
	# Wake -> thirst -> combat -> wounds -> safe. The same interval survives.
	var now := start + 8 * 3600000
	b["sleeping"] = false
	b["vstats"].sleep = 85.0
	b["thirst"] = 10.0
	b["_act"] = "drink"
	Plans.sync(m, b, now)
	check((d["interruptions"] as Array).has("thirst"), "Thirst replaces sleep without resuming prematurely")
	var enemy := Node3D.new()
	world.add_child(enemy)
	b["_s_foe"] = enemy
	b["aggro_target"] = enemy
	Plans.sync(m, b, now + 1000)
	check((d["interruptions"] as Array)[0] == "combat", "Combat is the first interruption over thirst")
	capture(m, "combat")
	b["_s_foe"] = null
	b["aggro_target"] = null
	b["vstats"].bleeding = 0.2
	Plans.sync(m, b, now + 2000)
	check((d["interruptions"] as Array).has("bleeding"), "Recovery after combat preserves mission")
	b["vstats"].bleeding = 0.0
	b["thirst"] = 85.0
	b["_act"] = "explore"
	Plans.sync(m, b, now + 3000)
	Plans.sync(m, b, now + 5001)
	check(d["state"] == "RUNNING" and d["plan_id"] == id and d["step_index"] == 0,
		"Wake and recovery resume the original step and identity")
	check(int(d["suspended_ms"]) == 8 * 3600000 + 5001,
		"Stale API/poll observations never double-count a suspended interval")
	check(d["_remaining_steps"].size() == 2 and d["_dest_pos"] == Vector3(300, 0.4, 200),
		"Pending steps and destination survive all interruptions")
	capture(m, "resumed")
	var suspended_before := int(d["suspended_ms"])
	b["sleeping"] = true
	Plans.sync(m, b, now + 6000)
	Plans.sync(m, b, now + 16000)
	b["sleeping"] = false
	Plans.sync(m, b, now + 16000)
	Plans.sync(m, b, now + 18001)
	check(int(d["suspended_ms"]) - suspended_before == 12001, "Second suspension accumulates without double counting")
	check(int(b["_mem"]["plan_metrics"]["suspensions"]) == 2 and int(b["_mem"]["plan_metrics"]["resumptions"]) == 2,
		"Transition metrics agree with the two actual suspensions")
	# Irrelevant loot and unusable weapons never satisfy a gear mission.
	b["proxy"].set_meta("saved_inventory", [{"name": "Piedra", "type": "resource"}])
	m._ai_note_loot(b, "Piedra", "resource")
	check(not m._ai_directive_completed(b, d), "Stone does not complete an equipment mission")
	b["proxy"].set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon", "durability": 100.0}])
	b["proxy"].set_meta("bot_gun_ammo", {"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 0})
	check(not m._ai_directive_completed(b, d), "Dry rifle does not complete equipment")
	b["proxy"].set_meta("saved_inventory", [{"name": "Cuchillo", "type": "weapon", "durability": 0.0}])
	check(not m._ai_directive_completed(b, d), "Broken knife does not complete equipment")
	b["proxy"].set_meta("saved_inventory", [{"name": "Arco reforzado", "type": "weapon", "durability": 0.0}, {"name": "Flecha", "type": "ammo_arrow"}])
	check(not m._ai_directive_completed(b, d), "Broken bow with arrows still fails")
	b["proxy"].set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon", "durability": 100.0}, {"name": "Munición 5.56", "type": "ammo", "quantity": 1}])
	m._ai_note_loot(b, "Fusil de asalto", "weapon")
	check(m._ai_directive_completed(b, d), "Functional rifle with matching ammunition completes equipment")
	check(m._ai_advance_plan(902, b, d), "Equipment success advances to return leg")
	d = b["ai_directive"]
	check(d["plan_id"] == id and d["step_index"] == 1 and d["action"] == "return_home",
		"Return leg keeps identity and step index")
	m._ai_apply_decision(902, JSON.stringify(trip))
	check(b["_ai_last_apply"] == "kept" and b["ai_directive"]["step_index"] == 1 and b["ai_directive"]["plan_id"] == id,
		"A late Qwen reply cannot restart the already completed high-priority first step")
	m._ai_apply_decision(902, '{"steps":[{"action":"return_home","target":"camp","goal":"go_back_safely","reason":"new wording","priority":5},{"action":"rest","target":"camp","goal":"recover_again"}]}')
	check(b["_ai_last_apply"] == "reaffirmed" and b["ai_directive"]["plan_id"] == id,
		"Equivalent steps with rewritten labels/reasons preserve the plan and evidence")
	verify_disk_resume(m, b)
	check(m._ai_directive_completed(b, d), "Return verifies the real home position")
	m._ai_advance_plan(902, b, d)
	d = b["ai_directive"]
	check(d["step_index"] == 2, "Third step does not restart from food/equipment")
	b["vstats"].sleep = 20.0
	check(not m._ai_directive_completed(b, d), "Arrival at home is not enough to finish rest")
	b["vstats"].sleep = 90.0
	b["vstats"].energy = 90.0
	check(m._ai_directive_completed(b, d), "Actual recovery satisfies rest")
	m._ai_advance_plan(902, b, d)
	check(b["_mem"]["last_plan_result"]["state"] == "COMPLETED", "Terminal result retained after active plan ends")
	capture(m, "completed")
	# Live ally validation, controlled relocation, death and invalid friendship.
	b["ai_directive"] = {}
	check(m._ai_apply_decision(902, '{"action":"seek_ally","target":"ally"}'), "Ally mission binds a real living actor")
	d = b["ai_directive"]
	var ally: Dictionary = m.bots[int(d["_ally_id"])]
	var previous_pos: Vector3 = d["pos"]
	ally["proxy"].global_position += Vector3(80, 0, 0)
	b["proxy"].global_position = previous_pos
	check(not m._ai_directive_completed(b, d), "Old ally position cannot complete meeting")
	Goals.viable(m, b, d, Time.get_ticks_msec())
	check(d["pos"] == ally["proxy"].global_position, "Live ally destination refreshed")
	verify_disk_resume(m, b)
	b["proxy"].global_position = ally["proxy"].global_position
	check(m._ai_directive_completed(b, d), "Actual meeting completes seek_ally")
	ally["proxy"].set_meta("proxy_dead", true)
	check(Goals.viable(m, b, d, Time.get_ticks_msec()) == "ally_unavailable", "Dead ally invalidates mission")
	ally["proxy"].set_meta("proxy_dead", false)
	# Real counters are per bot and distinguish food, water and hunt yield.
	b["ai_directive"] = {}
	var food := {"action": "forage", "_ev0": Goals.baseline(b)}
	m._ai_note_loot(b, "Botella de agua", "drink")
	check(not m._ai_directive_completed(b, food), "Water pickup cannot complete a food search")
	m._ai_note_loot(b, "Naranja", "food")
	check(m._ai_directive_completed(b, food), "Fruit pickup completes food search")
	var hunt := {"action": "hunt", "purpose": "meat", "_ev0": Goals.baseline(b)}
	m._ai_note_loot(b, "Carne cruda", "food")
	check(not m._ai_directive_completed(b, hunt), "Someone else's meat cannot prove own hunt")
	b["_mem"]["stats"]["kills_prey"] = int(b["_mem"]["stats"].get("kills_prey", 0)) + 1
	check(m._ai_directive_completed(b, hunt), "Own prey and meat satisfy food hunt")
	check(m._ai_parse_plan('{"steps":[{"action":"forage","purpose":"invented"}]}', b).is_empty(), "Unknown success purposes rejected")
	# Arrival/baseline structures cannot prove success after losing the home.
	var home: Vector3 = b["shelter_pos"]
	b["proxy"].global_position = home
	b["shelter_id"] = "lost_shelter"
	var fortify := {"action": "fortify_camp", "pos": home, "_home_bound": true, "_ev0": Goals.baseline(b)}
	b["shelter_id"] = ""
	b["campfire_id"] = ""
	check(not m._ai_directive_completed(b, fortify), "A destroyed baseline shelter cannot satisfy fortification")
	b["shelter_pos"] = Vector3.INF
	b["camp_spot"] = Vector3.INF
	check(not m._ai_directive_completed(b, {"action": "return_home", "pos": home, "_home_bound": true}),
		"Reaching a lost home cannot bypass prerequisite validation with a false success")
	# Real blockage remains detectable after a suspension; repeated proposals
	# cannot refresh its budget indefinitely.
	reset_bot(m, b, Vector3(80, 0.4, 10))
	m._ai_apply_decision(902, '{"action":"explore","target":"military:300:200"}')
	d = b["ai_directive"]
	d["_prog_ref_m"] = b["proxy"].global_position.distance_to(d["pos"])
	d["_prog_ref_ms"] = Time.get_ticks_msec()
	d["_step_deadline_ms"] = Time.get_ticks_msec() + 200000
	check(m._ai_step_stalled(b, d, Time.get_ticks_msec() + 100000) == "no_progress", "Uninterrupted real blockage is detected")
	var old_deadline := int(d["_step_deadline_ms"])
	m._ai_apply_decision(902, '{"action":"explore","target":"military:300:200"}')
	check(int(d["_step_deadline_ms"]) == old_deadline, "Equivalent Qwen response cannot hide a blockage")
	m._ai_fail_stalled_step(902, b, d, "no_progress")
	check(b["_mem"]["last_plan_result"]["state"] == "FAILED" and not b["ai_directive"].is_empty(), "Failure is recorded and recovered locally")
	capture(m, "failed")
	m._ai_apply_decision(902, '{"action":"explore","target":"tower","priority":5}')
	check(b["_mem"]["last_plan_result"]["state"] == "CANCELLED", "Justified replacement records CANCELLED")
	capture(m, "cancelled")
	# Memory round trip keeps history and statistics; old records remain valid.
	m.force_memory_io = true
	m._ai_save_memory()
	m._ai_flush_writes()
	var loaded := Manager.new()
	loaded.force_memory_io = true
	loaded.memory_path = m.memory_path
	loaded._ai_load_memory()
	var saved: Dictionary = loaded._ensure_bot_memory(902)
	var metrics_match := true
	for key in b["_mem"]["plan_metrics"]:
		metrics_match = metrics_match and is_equal_approx(float(saved.get("plan_metrics", {}).get(key, -1)), float(b["_mem"]["plan_metrics"][key]))
	check(metrics_match, "Planning metrics survive memory round trip")
	check(saved.get("plan_history", []).size() == b["_mem"]["plan_history"].size(), "Terminal history survives memory round trip")
	var checkpoint_id: String = b["ai_directive"]["plan_id"]
	var checkpoint_step := int(b["ai_directive"]["step_index"])
	var started_count := int(b["_mem"]["plan_metrics"]["plans_started"])
	b["ai_directive"] = {}
	m._ai_resume_pending_plan(902)
	check(b["ai_directive"]["plan_id"] == checkpoint_id and int(b["ai_directive"]["step_index"]) == checkpoint_step,
		"Saved execution resumes with the same identity and pending step")
	check(int(b["_mem"]["plan_metrics"]["plans_started"]) == started_count,
		"Session resume does not inflate started-plan statistics")
	# Every roster member completes a day -> sleep -> emergency -> dawn cycle.
	# Only the clock/conditions are controlled; the production sleep rules,
	# survival statistics, plan transitions and goal validator execute.
	for bot_id in m.bots:
		var actor: Dictionary = m.bots[bot_id]
		reset_bot(m, actor, Vector3(float(bot_id), 0.4, 80))
		dc.time_of_day = 14.0
		check(m._ai_apply_decision(int(bot_id), '{"action":"explore","target":"military:300:200"}'),
			"%s starts a daytime mission" % actor["name"])
		var plan: Dictionary = actor["ai_directive"]
		var mission_id: String = plan["plan_id"]
		dc.time_of_day = 23.5
		actor["vstats"].sleep = 35.0
		actor["_velada_done"] = true
		check(m._bot_try_start_sleep(actor, true), "%s sleeps under real night rules" % actor["name"])
		var time := Time.get_ticks_msec()
		for tick in range(60):
			m._bot_survival_tick(actor, 1.0)
			Plans.sync(m, actor, time + tick * 1000)
		check(plan["state"] == "SUSPENDED" and float(actor["health"]) > 0,
			"%s remains alive with suspended mission during sleep" % actor["name"])
		actor["thirst"] = 4.0
		check(m._bot_should_wake(actor, true), "%s wakes to urgent thirst" % actor["name"])
		actor["sleeping"] = false
		actor["_act"] = "drink"
		Plans.sync(m, actor, time + 60000)
		check(plan["state"] == "SUSPENDED" and (plan["interruptions"] as Array).has("thirst"),
			"%s retains mission during emergency" % actor["name"])
		dc.time_of_day = 7.0
		actor["thirst"] = 85.0
		actor["vstats"].sleep = 85.0
		actor["_act"] = "explore"
		Plans.sync(m, actor, time + 61000)
		Plans.sync(m, actor, time + 64000)
		check(plan["state"] == "RUNNING" and plan["plan_id"] == mission_id,
			"%s resumes the same mission at dawn" % actor["name"])
		actor["proxy"].global_position = Vector3(300, 0.4, 200)
		check(m._ai_directive_completed(actor, plan), "%s verifies arrival on correct floor" % actor["name"])
		m._ai_advance_plan(int(bot_id), actor, plan)
	for i in range(100):
		Diagnostics.event(b, {}, "step_started")
	check(b["_mem"]["plan_history"].size() == Diagnostics.HISTORY_LIMIT, "History is bounded to 48 events")
	loaded.free()
	m.force_memory_io = false
	var out := FileAccess.open("res://build/tmp/phase1-monitor-states.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(snapshots))
	out.close()
	check(m._ai_calls_total == calls_before, "Entire lifecycle made zero additional API calls")
	world.queue_free()
	net.queue_free()
	await process_frame
	print("BotPlanContinuityRegression errors=%d" % failures)
	quit(1 if failures else 0)
