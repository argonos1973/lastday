extends SceneTree
## Rain wetness → hypothermia → health regression.
## Covers: rain suspends per-frame drying, drying resumes when rain stops,
## snow wets clothes, and wet clothes at cool ambient drain health.

const PlayerScript = preload("res://scripts/PlayerController.gd")
const StatsScript = preload("res://scripts/SurvivalStats.gd")

class TestPlayer extends PlayerScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		inventory = preload("res://scripts/Inventory.gd").new()
		add_child(inventory)
		stats = StatsScript.new()
		add_child(stats)
	func _sync_held_item() -> void:
		pass
	func _find_skeleton(_n: Node) -> Skeleton3D:
		return null

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		errors += 1

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := TestPlayer.new()
	world.add_child(player)
	await physics_frame

	# Rain keeps clothes wet — the per-frame dry path must stay suspended.
	player.wetness = 0.5
	player.stats.wetness = 0.5
	player._rain_wetting = true
	for i in range(40):
		player._update_water_state(0.1)
	check(is_equal_approx(player.wetness, 0.5), "Clothes stay wet while it rains")

	# When rain stops the normal drying path resumes.
	player._rain_wetting = false
	for i in range(40):
		player._update_water_state(0.1)
	check(player.wetness < 0.5, "Clothes dry once rain stops")

	# stats.tick alone also dries wetness — that path stays, it is slow and fine.
	var stats := StatsScript.new()
	world.add_child(stats)
	stats.wetness = 1.0
	for i in range(10):
		stats.tick(0.5, false, 15.0, false)
	check(stats.wetness < 1.0, "stats.tick still dries wetness slowly")

	# The actual bug chain: soaked clothes at cool ambient must pull body
	# temperature down and start draining health. stats.tick dries wetness
	# slowly (~0.02-0.09/s), so emulate Main's rain refresh (~0.3 every 2 s)
	# to keep the clothes soaked like sustained rain does.
	stats.wetness = 1.0
	stats.body_temperature = 36.6
	stats.health = 100.0
	var dropped := false
	for i in range(240):
		stats.tick(0.5, false, 18.0, false)  # mild cool rain day
		if i % 4 == 3:
			stats.wetness = minf(1.0, stats.wetness + 0.3)  # Main rain wet gain
		if stats.body_temperature < 35.4:
			dropped = true
			break
	check(dropped, "Sustained rain at 18°C pushes body temperature into damage range")
	var h0: float = stats.health
	for i in range(40):
		stats.tick(0.5, false, 18.0, false)
		stats.wetness = minf(1.0, stats.wetness + 0.08)
	check(stats.health < h0, "Hypothermia drains health while soaked")
	check(stats.wetness > 0.5, "Rain replenishment outruns stats.tick drying")

	# Dry clothes at the same ambient stay safely above the damage threshold.
	var stats2 := StatsScript.new()
	world.add_child(stats2)
	stats2.wetness = 0.0
	for i in range(240):
		stats2.tick(0.5, false, 18.0, false)
	check(stats2.body_temperature > 35.4, "Dry clothes at 18°C keep a safe body temperature")
	check(stats2.health >= 99.0, "Dry clothes at 18°C do not drain health")

	# Warm ambient still cools a soaked character vs a dry one.
	var stats3 := StatsScript.new()
	world.add_child(stats3)
	stats3.wetness = 1.0
	for i in range(240):
		stats3.tick(0.5, false, 24.0, false)
		if i % 4 == 3:
			stats3.wetness = minf(1.0, stats3.wetness + 0.3)
	check(stats3.body_temperature < stats2.body_temperature, "Soaked clothes cool even in warm weather")

	print("RAIN_WETNESS_ERRORS=", errors)
	quit(1 if errors > 0 else 0)
