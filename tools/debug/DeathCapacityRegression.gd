extends SceneTree

# Death-capacity regression: die() unequips all clothing, and removing the
# fishing hat drops the +1 head carry slot. Before the fix, the capacity
# recalc emitted item_dropped for the "excess" — those drops raced the death
# RPCs and could be rejected by the server (proxy_dead), silently deleting the
# items instead of leaving them as corpse loot. A dead player must keep every
# inventory item so the server record can drop it as loot.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

var _failures: Array = []

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)

func _initialize() -> void:
	await process_frame
	var scene := Node3D.new()
	get_root().add_child(scene)
	var player = TestPlayer.new()
	scene.add_child(player)
	await process_frame
	await process_frame

	# Equip first (grants the +1 head carry slot), then add the item — same order
	# as a real pickup: the hat lives in inventory while worn.
	player.equip_clothing("Sombrero de pescador")
	var hat = load("res://scripts/Item.gd").new()
	hat.item_name = "Sombrero de pescador"
	player.inventory.add_item(hat)
	# Add a non-equipped item too so something still sits in a pocket slot.
	var extra = load("res://scripts/Item.gd").new()
	extra.item_name = "Higo"
	player.inventory.items.append(extra)

	var drops: Array = []
	player.item_dropped.connect(func(item_name: String, _t: String, _w: float, _q: int, _u: float, _pos: Vector3, _c: Color, _b: bool, _s: float) -> void: drops.append(item_name))
	var pre_items: int = player.inventory.items.size()

	player.die()
	await process_frame

	print("=== DeathCapacity ===")
	_check(player.is_dead, "player dead")
	_check(drops.is_empty(), "no item_dropped emitted on death (had %d)" % drops.size())
	_check(player.inventory.items.size() == pre_items, "inventory kept all %d items (has %d)" % [pre_items, player.inventory.items.size()])
	_check(player.inventory.has_item_name("Sombrero de pescador"), "hat still in inventory for server loot")
	_check(player.inventory.has_item_name("Higo"), "extra item still in inventory")
	# Equipped state cleared even though items stay in inventory.
	_check(player.get("_equipped_slots") == null or Dictionary(player.get("_equipped_slots")).is_empty(), "clothing slots unequipped")

	print("=== DeathCapacity: %s ===" % ("ALL PASS" if _failures.is_empty() else "FAILED: %s" % ", ".join(_failures)))
	quit(0 if _failures.is_empty() else 1)
