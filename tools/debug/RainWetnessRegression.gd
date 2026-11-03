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
	func _wear_survival_clothing(_n: String, _w: bool, _c: Color = Color(0, 0, 0, 0)) -> void:
		pass
	func _wear_clothing_visual(_n: String, _c: Color = Color(0, 0, 0, 0)) -> void:
		pass

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
	jacket.wetness = maxf(jacket.wetness, maxf(0.0, player.wetness - 0.5) * 0.4)
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

	# ---- Wet clothing insulates less; pack items dry too ----
	jacket.wetness = 0.0
	player._recalculate_warmth(false)
	var dry_warmth: float = player.stats.warmth_bonus
	jacket.wetness = 1.0
	player._recalculate_warmth(false)
	check(player.stats.warmth_bonus < dry_warmth, "Soaked jacket insulates less than dry")
	check(player.stats.warmth_bonus > 0.0, "Soaked jacket keeps some residual warmth")
	var pack_item = ItemScript.create("Camiseta", "clothing", 0.3)
	pack_item.wetness = 0.9
	player.inventory.items.append(pack_item)
	var pack_w0: float = pack_item.wetness
	player.apply_warmth_drying(0.2)
	check(pack_item.wetness < pack_w0, "Wet clothes in the backpack dry near fire")

	# The dry-player early return must not strand wet clothes in the backpack.
	player.wetness = 0.0
	jacket.wetness = 0.0
	shoes.wetness = 0.0
	spare.wetness = 0.8
	player._rain_wetting = true
	player._update_water_state(1.0)
	check(spare.wetness < 0.8, "Stored wet clothing dries even with dry skin during rain")
	# ---- Same-name swap (wet -> dry): the dry garment takes over the slot ----
	player._equipped_slots.erase("torso")
	for it in player.inventory.items:
		if it != null and it.has_meta("equipped_slot"):
			it.remove_meta("equipped_slot")
	player.wetness = 0.0
	var dropped_log: Array = []
	player.item_dropped.connect(func(n, _t, _w, _q, _uv, _pos, _c, _b, _sp): dropped_log.append([n, float(player.get_meta("last_dropped_wetness", 0.0))]))
	var wet_jacket = ItemScript.create("Chaqueta militar", "clothing", 1.0)
	wet_jacket.wetness = 0.9
	player.inventory.items.append(wet_jacket)
	player.equip_clothing("Chaqueta militar", Color(0, 0, 0, 0), wet_jacket)
	check(player._equipped_item_for_slot("torso") == wet_jacket, "Wet jacket owns the torso slot")
	check(player._effective_wetness() > 0.3, "Wet jacket drives effective wetness")
	var dry_jacket = ItemScript.create("Chaqueta militar", "clothing", 1.0)
	player.inventory.items.append(dry_jacket)
	player.equip_clothing("Chaqueta militar", Color(0, 0, 0, 0), dry_jacket)
	check(not player.inventory.items.has(wet_jacket), "Same-name swap drops the wet jacket")
	check(dropped_log.size() == 1, "Same-name swap emits exactly one drop")
	if dropped_log.size() == 1:
		check(absf(dropped_log[0][1] - 0.9) < 0.01, "Dropped jacket keeps its own wetness")
	check(player._equipped_item_for_slot("torso") == dry_jacket, "Dry jacket owns the torso slot")
	check(str(wet_jacket.get_meta("equipped_slot", "")) == "", "Wet jacket loses the slot claim")
	check(player._effective_wetness() < 0.01, "Dry garment reads dry effective wetness")
	var stale = ItemScript.create("Chaqueta militar", "clothing", 1.0)
	stale.wetness = 1.0
	stale.set_meta("equipped_slot", "torso")
	player.inventory.items.append(stale)
	check(player._equipped_item_for_slot("torso") == dry_jacket, "Stale slot meta on a spare cannot hijack wetness")
	check(player._effective_wetness() < 0.01, "Stale meta does not leak wetness")
	stale.remove_meta("equipped_slot")

	# Skin transfer only dampens fresh clothing when the skin is truly soaked.
	player.wetness = 0.4
	var damp_shoes = ItemScript.create("Zapatillas", "clothing", 0.4)
	player.inventory.items.append(damp_shoes)
	player.equip_clothing("Zapatillas", Color(0, 0, 0, 0), damp_shoes)
	check(damp_shoes.wetness < 0.02, "Lightly wet skin does not dampen fresh shoes")
	player.wetness = 1.0
	var soaked_shoes = ItemScript.create("Zapatillas", "clothing", 0.4)
	player.inventory.items.append(soaked_shoes)
	player.equip_clothing("Zapatillas", Color(0, 0, 0, 0), soaked_shoes)
	check(soaked_shoes.wetness > 0.15 and soaked_shoes.wetness < 0.25, "Soaked skin leaves fresh shoes only damp")
	player.wetness = 0.0

	# ---- Pelt clothing: much warmer and water repellent ----
	# Clear stale equipped_slot metas so each slot resolves to the pelt item.
	jacket.set_meta("equipped_slot", "")
	shoes.set_meta("equipped_slot", "")
	var fur = ItemScript.create("Chaqueta de piel", "clothing", 1.8)
	player.inventory.items.append(fur)
	fur.set_meta("equipped_slot", "torso")
	player._equipped_slots["torso"] = "Chaqueta de piel"
	fur.wetness = 0.0
	jacket.wetness = 0.0
	player.wetness = 0.0
	player.apply_precipitation_wetness(0.5)
	check(fur.wetness < 0.25, "Pelt jacket repels most rain")
	check(player.wetness < 0.32, "Skin under pelt stays drier in rain")
	fur.wetness = 0.0
	player._equipped_pelt["Chaqueta de piel"] = "oso"
	player.apply_precipitation_wetness(0.5)
	check(fur.wetness < 0.18, "Bear pelt is even more waterproof")
	player._equipped_pelt.erase("Chaqueta de piel")

	# Full pelt set exceeds the old 1.5 protection cap — it needed the raise.
	fur.wetness = 0.0
	var fw_parts := {"legs": "Pantalones de piel", "feet": "Botas de piel", "hands": "Guantes de piel", "head": "Gorro de piel"}
	for fslot in fw_parts:
		var fi = ItemScript.create(fw_parts[fslot], "clothing", 1.0)
		player.inventory.items.append(fi)
		fi.set_meta("equipped_slot", fslot)
		player._equipped_slots[fslot] = fw_parts[fslot]
	player._recalculate_warmth(false)
	check(player.stats.warmth_bonus > 3.5, "Full pelt set insulates far beyond the old cap")
	var pelt_warmth: float = player.stats.warmth_bonus
	player._equipped_pelt["Chaqueta de piel"] = "oso"
	player._recalculate_warmth(false)
	check(player.stats.warmth_bonus > pelt_warmth, "Bear pelt adds extra warmth")
	player._equipped_pelt.erase("Chaqueta de piel")
	for fslot in fw_parts:
		player._equipped_item_for_slot(fslot).wetness = 1.0
	fur.wetness = 1.0
	player._recalculate_warmth(false)
	check(player.stats.warmth_bonus > 1.5, "Soaked pelt keeps more warmth than soaked cloth")

	# Higher protection keeps the body warmer in the cold (clamp raised 1.5 -> 3.0).
	var cold_fur := StatsScript.new()
	world.add_child(cold_fur)
	cold_fur.warmth_bonus = 3.0
	for i in range(120):
		cold_fur.tick(0.5, false, -5.0, false)
	var cold_cloth := StatsScript.new()
	world.add_child(cold_cloth)
	cold_cloth.warmth_bonus = 1.5
	for i in range(120):
		cold_cloth.tick(0.5, false, -5.0, false)
	check(cold_fur.body_temperature > cold_cloth.body_temperature + 0.2, "Pelt-grade protection keeps you warmer in the cold")

	for temperature in [32.0, 36.6, 39.0]:
		player.stats.body_temperature = temperature
		player.stats.warmth_bonus = 9.0
		player._recalculate_warmth()
		check(is_equal_approx(player.stats.body_temperature, temperature), "Changing insulation cannot teleport body temperature")
	print("RAIN_WETNESS_ERRORS=", errors)
	quit(1 if errors > 0 else 0)
