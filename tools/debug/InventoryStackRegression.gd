extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Fresh axes stack into one slot.
	var inv = InventoryScript.new()
	inv.max_weight = 1000.0
	inv.add_item(ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0))
	inv.add_item(ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0))
	check(inv.items.size() == 1 and inv.items[0].quantity == 2, "two fresh axes stack into one slot")
	# A used axe still stacks; durability merges by weighted average.
	var used = ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0)
	used.durability = 50.0
	inv.add_item(used)
	check(inv.items.size() == 1 and inv.items[0].quantity == 3, "used axe stacks with fresh axes")
	check(absf(inv.items[0].durability - 83.3333) < 0.01, "merged stack keeps average durability, got %f" % inv.items[0].durability)
	# Different items still occupy separate slots.
	inv.add_item(ItemScript.create("Palo", "resource", 0.3, 1, 0.0))
	check(inv.items.size() == 2, "different item uses its own slot")
	# Matchboxes never stack (each keeps its own charge count).
	var inv2 = InventoryScript.new()
	inv2.max_weight = 1000.0
	var m1 = ItemScript.create("Cerillas", "tool_matches", 0.05, 1, 0.0)
	var m2 = ItemScript.create("Cerillas", "tool_matches", 0.05, 1, 0.0)
	inv2.add_item(m1)
	inv2.add_item(m2)
	check(inv2.items.size() == 2, "matchboxes keep separate charge state")
	# merge_stacks applies the same averaged durability.
	var inv3 = InventoryScript.new()
	inv3.max_weight = 1000.0
	var k1 = ItemScript.create("Cuchillo", "weapon", 0.4, 1, 0.0)
	k1.durability = 40.0
	var k2 = ItemScript.create("Cuchillo", "weapon", 0.4, 1, 0.0)
	inv3.items.append(k1)
	inv3.items.append(k2)
	inv3.merge_stacks()
	check(inv3.items.size() == 1 and inv3.items[0].quantity == 2, "merge_stacks combines used+fresh knife")
	check(absf(inv3.items[0].durability - 70.0) < 0.01, "merge_stacks averages durability, got %f" % inv3.items[0].durability)
	if failures == 0:
		print("PASS: tools stack, durability merges by average, matchboxes stay separate")
	quit(1 if failures else 0)
