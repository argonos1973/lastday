extends SceneTree
## Same-process comparison against the committed server code. Read-only git
## baselines, real map forage candidates, then a controlled 71-animal workload.
const Manager = preload("res://scripts/SurvivorBotManager.gd")
const Fixtures = preload("res://tools/debug/BotPlanReliabilityRegression.gd")
const Packs = preload("res://scripts/WolfPack.gd")

class Net extends Fixtures.FakeNet:
	var world_ready := false

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void: pass
	func _save_world_change_silent() -> void: pass
	func _save_server_world() -> void: pass
	func _create_wildlife() -> void: pass

var failures := 0
var report := {}

func _initialize() -> void:
	call_deferred("run")

func baseline(path: String, global_name: String) -> GDScript:
	var output: Array = []
	if OS.execute("git", ["show", "HEAD:" + path], output) != 0:
		push_error("Cannot read committed baseline " + path)
		return null
	var script := GDScript.new()
	script.source_code = str(output[0]).replace("class_name " + global_name, "")
	return script if script.reload() == OK else null

func measure_forage(manager, bots: Dictionary) -> float:
	var samples: Array[float] = []
	for trial in 5:
		var start := Time.get_ticks_usec()
		for repeat in 20:
			for bot in bots.values():
				manager._find_forage_target(bot, 28.0)
		samples.append((Time.get_ticks_usec() - start) / float(20 * bots.size()))
	samples.sort()
	return samples[2]

func measure_wolves(wolves: Array) -> Dictionary:
	var samples: Array[float] = []
	var peak_us := 0
	for trial in 5:
		var total := 0
		for frame in 120:
			var start := Time.get_ticks_usec()
			for wolf in wolves:
				wolf._wolf_ai(1.0 / 60.0)
			var elapsed := Time.get_ticks_usec() - start
			total += elapsed
			peak_us = maxi(peak_us, elapsed)
		samples.append(total / 120.0)
	samples.sort()
	return {"median_us_per_23_wolves": samples[2], "peak_us": peak_us}

func run() -> void:
	var previous_manager := baseline("scripts/SurvivorBotManager.gd", "SurvivorBotManager")
	var previous_wildlife := baseline("scripts/WildlifeController.gd", "WildlifeController")
	if previous_manager == null or previous_wildlife == null:
		quit(2)
		return
	seed(20261121)
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var net := Net.new()
	world.add_child(net)
	world.net = net
	net.is_dedicated_server = true
	var clock := Fixtures.FakeDayCycle.new()
	world.add_child(clock)
	world.day_cycle = clock
	var current := Manager.new()
	world.add_child(current)
	world.survivor_bot_mgr = current
	world.nav = world._new_nav_pathfinding()
	world._world_rng.seed = GameConst.WORLD_SEED
	await world._create_map()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	current.setup(world)
	var old = previous_manager.new()
	world.add_child(old)
	old.world = world
	old.bots = current.bots
	old._memory = current._memory
	var checks := 0
	for hour in [14.0, 1.0]:
		clock.time_of_day = hour
		for pos in [Vector3(140, 0.1, 80), Vector3(42, 0, 27), Vector3.ZERO, Vector3(300, 4, 350)]:
			for b in current.bots.values():
				b["proxy"].global_position = pos
				for radius in [8.0, 28.0, 60.0]:
					var a: Dictionary = old._find_forage_target(b, radius)
					var c := current._find_forage_target(b, radius)
					checks += 1
					if a.get("id", "") != c.get("id", "") or a.get("kind", "") != c.get("kind", ""):
						failures += 1
						push_error("Forage choice changed at %s hour=%s radius=%s" % [pos, hour, radius])
		var label := "day" if hour == 14.0 else "night"
		report["forage_" + label] = {"before_us": measure_forage(old, current.bots),
			"after_us": measure_forage(current, current.bots)}
	report["forage_checks"] = checks
	report["world_actions"] = world.world_actions_by_id.size()
	print("FORAGE_PROFILE ", JSON.stringify(report))
	world.free()

	world = World.new()
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var cohorts := {}
	for label in ["before", "after"]:
		var wolves: Array = []
		var animals: Array = []
		for i in 23:
			var wolf = previous_wildlife.new() if label == "before" else WildlifeController.new()
			world.add_child(wolf)
			wolf.animal_type = "wolf"
			wolf._is_dedicated = true
			wolf.health = 240.0
			wolf.max_health = 240.0
			wolf._wolf_hunger = 25.0
			wolf._wolf_hunger_threshold = 75.0
			wolf._howl_timer = 1000.0
			wolf.global_position = Vector3(-200 + int(i / 4) * 75 + (i % 4) * 3, 0, -60)
			wolf.patrol_points = [wolf.global_position, wolf.global_position + Vector3(0, 0, 15)]
			wolves.append(wolf)
			animals.append(wolf)
		for i in 48:
			var prey := WildlifeController.new()
			world.add_child(prey)
			prey.animal_type = "deer" if i % 2 == 0 else "fox"
			prey.global_position = Vector3(-200 + int(i / 8) * 75, 0, -40 + (i % 8) * 3)
			animals.append(prey)
		for wolf in wolves:
			wolf._cached_wildlife = animals
		if label == "after":
			var pack
			for i in wolves.size():
				if i % 4 == 0:
					pack = Packs.new("bench_%d" % int(i / 4))
				wolves[i].join_pack(pack)
		cohorts[label] = wolves
	for label in ["before", "after"]:
		report["wolves_" + label] = measure_wolves(cohorts[label])
	if report.wolves_after.median_us_per_23_wolves > report.wolves_before.median_us_per_23_wolves * 1.10:
		failures += 1
		push_error("Pack decisions exceed the previous wildlife CPU budget")
	print("SERVER_AI_PROFILE ", JSON.stringify(report))
	var file := FileAccess.open("res://build/tmp/server-ai-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	world.free()
	print("ServerAIProfile failures=", failures)
	quit(1 if failures else 0)
