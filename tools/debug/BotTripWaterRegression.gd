extends SceneTree

const Fixtures = preload("res://tools/debug/BotPlanReliabilityRegression.gd")
const Plans = preload("res://scripts/bot_ai/BotPlanManager.gd")
var errors := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: errors += 1

func _initialize() -> void:
	call_deferred("run")

func scenario(mode: String) -> void:
	var world := Fixtures.TestWorld.new()
	root.add_child(world)
	current_scene = world
	world.net = Fixtures.FakeNet.new()
	world.add_child(world.net)
	world.day_cycle = Fixtures.FakeDayCycle.new()
	world.add_child(world.day_cycle)
	var m := SurvivorBotManager.new()
	world.add_child(m)
	world.survivor_bot_mgr = m
	m.setup(world)
	m.set_physics_process(false)
	m.set_process(false)
	var start := Vector3(390, 0.4, 390)
	var bank := start + Vector3(0, 0, 18)
	var dest := start - Vector3(20 if mode == "short" else 260, 0, 0)
	var lead: Dictionary = m.bots[901]
	var kael: Dictionary = m.bots[903]
	for b: Dictionary in [lead, kael]:
		m._set_bot_faction(b, "friendly")
		b._mem.known_locations = {}
		b.pos = start
		b.proxy.global_position = start
		b.sense_t = 10000.0
		b.hunger = 90.0
		b.thirst = 90.0
		b.proxy.set_meta("saved_inventory", [])
		b["camp_spot"] = start
		b["explore_target"] = start
	kael.proxy.position.x += 65.0 if mode == "far" else 2.0
	kael.team_leader_id = 902 if mode == "other_team" else 901
	kael.follow_mode = "stay" if mode == "stay" else "follow"
	kael._s_leader = lead.proxy
	kael.thirst = 40.0
	kael.eat_cooldown = 9.0
	kael.proxy.set_meta("saved_inventory", [{"name":"Botella de plastico","type":"misc","quantity":1}])
	if mode == "supplied":
		kael.proxy.set_meta("saved_inventory", [{"name":"Botella de agua llena","type":"water","quantity":1,"use_value":45.0}])
	m.observe_location(901, "wild:trip", "wild", dest)
	if mode != "unknown":
		m.observe_location(903 if mode == "member_source" else 901, "water:local", "water", bank)
	if mode != "dry":
		var fountain := WorldAction.new()
		fountain.action_type = "drink_water"
		fountain.action_id = "fountain_local"
		world.add_child(fountain)
		fountain.global_position = bank
		world.world_actions_by_id[fountain.action_id] = fountain
	var trip := '{"steps":[{"action":"explore","target":"wild:trip"},{"action":"return_home","target":"camp"}]}'
	for tick in 2:
			m._tick_bot(lead, 0.1)
			m._tick_bot(kael, 0.1)
	for tick in 3:
			m._tick_bot(lead, 0.1)
			m._tick_bot(kael, 0.1)
	check(m._ai_apply_decision(901, trip), mode + ": proposal handled")
	var messages: Array = m.chat_log.filter(func(msg): return msg.get("kind") == "trip_water")
	var expected := mode not in ["short", "far", "other_team", "stay", "supplied"]
	check((not messages.is_empty()) == expected, mode + ": only an eligible recruit reports their own shortage")
	if not expected:
		check(lead.ai_directive.get("state") == "RUNNING" and not lead.has("_trip_water"), mode + ": travel unchanged")
	elif mode == "unknown":
		check(lead.ai_directive.is_empty() and absf(lead.explore_target.x-start.x)<.1 and absf(lead.explore_target.z-start.z)<.1,
			"no known source: shorten the outgoing trip, do not select unseen map water")
	elif not messages.is_empty():
		var original: Dictionary = lead.ai_directive
		check(original.get("_dest_pos") == dest and original.get("state") == "SUSPENDED", mode + ": pause before departing")
		var reached_both := false
		for i in 220:
			m._tick_bot(lead, 0.1)
			m._tick_bot(kael, 0.1)
			if absf(lead.proxy.global_position.x-bank.x)<3.3 and absf(lead.proxy.global_position.z-bank.z)<3.3 and absf(kael.proxy.global_position.x-bank.x)<3.3 and absf(kael.proxy.global_position.z-bank.z)<3.3:
				reached_both = true
			if not lead.has("_trip_water"): break
		if mode == "dry":
			check(kael.thirst < 41.0 and m._bot_item_count(kael.proxy, "Botella de agua llena") == 0
				and not lead.has("_trip_water") and lead.ai_directive.is_empty(), "a dry tip cannot hydrate the follower or release the original trip as ready")
		else:
			Plans.sync(m, lead, Time.get_ticks_msec())
			Plans.sync(m, lead, Time.get_ticks_msec() + 2100)
			check(reached_both and kael.thirst >= 99.0 and m._bot_item_count(kael.proxy, "Botella de agua llena") == 1,
				mode + ": both walk to the fountain; the follower drinks and fills the actual empty bottle")
			check(not lead.has("_trip_water") and original.state == "RUNNING" and lead.ai_directive.get("plan_id") == original.plan_id
				and original._dest_pos == dest and original._remaining_steps.size() == 1, mode + ": confirmed ready; resume the same destination and return leg")
	current_scene = null
	world.free()

func run() -> void:
	for mode in ["short", "far", "stay", "other_team", "supplied", "unknown", "dry", "leader_source", "member_source"]:
		scenario(mode)
	print("BotTripWaterRegression errors=", errors)
	quit(1 if errors else 0)
