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

	# ---- Per-garment wetness: dry clothes are reflected immediately ----
	const ItemScript = preload("res://scripts/Item.gd")

	# Soaked naked-equivalent player; equip a dry jacket -> effective wetness drops.
	player.wetness = 0.8
	player._rain_wetting = false
	var jacket = ItemScript.create("Chaqueta militar", "clothing", 1.0)
	player.inventory.items.append(jacket)
	player._equipped_slots["torso"] = "Chaqueta militar"
	jacket.set_meta("equipped_slot", "torso")
	# equip path traspasa algo de humedad de la piel a la prenda
	jacket.wetness = maxf(jacket.wetness, player.wetness * 0.35)
	player.stats.wetness = player._effective_wetness()
	check(player.stats.wetness < 0.8, "Equipping a dry jacket lowers effective wetness")
	check(player.stats.wetness > 0.3, "Wet skin under clothes still counts")

	# Rain wets the worn garment, not a stored spare.
	var spare = ItemScript.create("Camiseta", "clothing", 0.3)
	player.inventory.items.append(spare)
	player.apply_precipitation_wetness(0.3)
	check(jacket.wetness > spare.wetness, "Rain soaks the worn garment first")
	check(spare.wetness <= 0.001, "Spare clothes in the pack stay dry")

	# Warmth drying reaches equipped garments too.
	var jw0: float = jacket.wetness
	player.apply_warmth_drying(0.1)
	check(jacket.wetness < jw0, "Fire dries the worn garment, not just the skin")
	check(player.stats.wetness < 0.8, "Fire updates effective wetness")

	# Wet garment keeps drying on the per-frame path when rain stops.
	jacket.wetness = 0.6
	player.wetness = 0.0
	for i in range(40):
		player._update_water_state(0.1)
	check(jacket.wetness < 0.6, "Worn garment dries once rain stops")

	# Wetness round-trips through item serialization (saves + MP restore).
	var packed: Dictionary = jacket.to_dict()
	var unpacked = ItemScript.from_dict(packed)
	check(absf(unpacked.wetness - jacket.wetness) < 0.001, "Item wetness survives save/load")
	var wet_a = ItemScript.create("Camiseta", "clothing", 0.3)
	var wet_b = ItemScript.create("Camiseta", "clothing", 0.3)
	wet_b.wetness = 0.9
	check(not wet_a.can_stack_with(wet_b), "Wet and dry garments do not merge")

	# ---- Footwear: shoes get wet in rain and carry the wet indicator ----
	var shoes = ItemScript.create("Zapatillas", "clothing", 0.4)
	player.inventory.items.append(shoes)
	shoes.set_meta("equipped_slot", "feet")
	player._equipped_slots["feet"] = "Zapatillas"
	player.apply_precipitation_wetness(0.5)
	check(shoes.wetness > 0.0, "Shoes get wet in the rain")
	check(shoes.is_wet() and shoes.wet_state() == 2, "Wet shoes report MOJADO")
	check(shoes.wet_state_label() == "MOJADO", "Wet state label is MOJADO")
	jacket.wetness = 0.9
	check(jacket.wet_state_label() == "EMPAPADO", "Soaked garment reports EMPAPADO")
	var dry = ItemScript.create("Camiseta", "clothing", 0.3)
	check(not dry.is_wet() and dry.wet_state_label() == "SECO", "Dry garment reports SECO")

	# A soaked shoe feeds the effective wetness through the feet slot weight.
	player.wetness = 0.0
	jacket.wetness = 0.0
	shoes.wetness = 0.0
	check(player._effective_wetness() < 0.001, "Dry feet slot adds no wetness")
	shoes.wetness = 1.0
	check(absf(player._effective_wetness() - 0.1) < 0.01, "Soaked shoes add the feet weight")

	print("RAIN_WETNESS_ERRORS=", errors)
	quit(1 if errors > 0 else 0)
