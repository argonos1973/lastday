extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := TestPlayer.new()
	root.add_child(player)
	var inv = load("res://scripts/Inventory.gd").new()
	player.inventory = inv
	player.add_child(inv)
	player.set_meta("test_drop_count", 0)
	player.item_dropped.connect(func(_name, _type, _weight, _qty, _use, _pos, _color, _broken, _spoil): player.set_meta("test_drop_count", int(player.get_meta("test_drop_count", 0)) + 1))
	var rifle = load("res://scripts/Item.gd").create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	assert(inv.add_item(rifle))
	player._held_item_reference = inv.items[0]
	player.held_index = 0
	assert(player.can_store_held_on_back())
	player.store_held_on_back()
	assert(player.get_held_item() == null)
	assert(not inv.items.has(rifle))
	var rod = load("res://scripts/Item.gd").create("Caña simple", "tool_fishing", 1.0, 1, 0.0)
	assert(inv.add_item(rod))
	rod = inv.items[0]
	player._held_item_reference = rod
	player.held_index = 0
	assert(player.can_store_held_on_back())
	player.store_held_on_back()
	assert(not inv.items.has(rod))
	assert(player._back_slot_count() == 2)
	var third = load("res://scripts/Item.gd").create("Caña de pescar", "tool_fishing", 1.0, 1, 0.0)
	assert(inv.add_item(third))
	third = inv.items[0]
	player._held_item_reference = third
	player.held_index = 0
	assert(not player.can_store_held_on_back())
	player._held_item_reference = null
	player._drop_held_item()
	assert(int(player.get_meta("test_drop_count", 0)) == 1)
	assert(player._back_slot_count() == 1)
	player._held_item_reference = third
	player.held_index = 0
	assert(player.can_store_held_on_back())
	player.store_held_on_back()
	assert(player._back_slot_count() == 2)
	player._drop_held_item()
	assert(int(player.get_meta("test_drop_count", 0)) == 2)
	player._drop_held_item()
	assert(int(player.get_meta("test_drop_count", 0)) == 3)
	var auto_rifle = load("res://scripts/Item.gd").create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	assert(inv.add_item(auto_rifle))
	auto_rifle = inv.items[0]
	assert(player._store_inventory_rifle_on_back())
	assert(not inv.items.has(auto_rifle))
	assert(player._back_slot_count() == 1)
	var migrated = load("res://scripts/Item.gd").from_dict({"name": "Hacha", "type": "tool", "quantity": 1})
	assert(migrated.item_type == "tool_axe")
	# A shoulder item can be taken into the hand without appearing in the
	# inventory, then stored explicitly as one physical unit.
	var use_player := TestPlayer.new()
	root.add_child(use_player)
	var use_inv = load("res://scripts/Inventory.gd").new()
	use_player.inventory = use_inv
	use_player.add_child(use_inv)
	var use_rod = load("res://scripts/Item.gd").create("Caña simple", "tool_fishing", 1.0, 1, 0.0)
	assert(use_inv.add_item(use_rod))
	use_rod = use_inv.items[0]
	use_player._held_item_reference = use_rod
	use_player.held_index = 0
	use_player.store_held_on_back()
	assert(use_player._back_slot_count() == 1)
	assert(use_player.use_back_item(0))
	var used_back_item = use_player.get_held_item()
	assert(used_back_item != null and use_player._held_item_external)
	assert(not use_inv.items.has(used_back_item))
	use_player._store_held_item()
	assert(use_player.get_held_item() == null)
	assert(not use_inv.has_item_name("Caña simple"))
	assert(use_player._back_slot_count() == 1)
	# Switching from a rifle to a rod detaches the rod from the inventory and
	# mounts the rifle on the free shoulder automatically.
	var swap_player := TestPlayer.new()
	root.add_child(swap_player)
	var swap_inv = load("res://scripts/Inventory.gd").new()
	swap_player.inventory = swap_inv
	swap_player.add_child(swap_inv)
	var swap_rifle = load("res://scripts/Item.gd").create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	var swap_rod = load("res://scripts/Item.gd").create("Caña simple", "tool_fishing", 1.0, 1, 0.0)
	assert(swap_inv.add_item(swap_rifle))
	assert(swap_inv.add_item(swap_rod))
	swap_rifle = swap_inv.items[0]
	swap_rod = swap_inv.items[1]
	swap_player._select_held_item(0)
	assert(swap_player._held_item_external and swap_player.get_held_item().item_type == "weapon_rifle")
	swap_player._select_held_item(swap_inv.items.find(swap_rod))
	assert(swap_player._held_item_external and swap_player.get_held_item().item_name == "Caña simple")
	assert(swap_player._back_slot_count() == 1)
	assert(not swap_inv.has_item_name("Rifle francotirador"))
	swap_player._store_held_item()
	assert(swap_player._back_slot_count() == 2)
	assert(swap_player.use_back_item(0))
	assert(swap_player.get_held_item().item_type == "weapon_rifle")
	assert(swap_player._back_slot_count() == 1)
	assert(swap_player.use_back_item(1))
	assert(swap_player.get_held_item().item_name == "Caña simple")
	assert(swap_player.get_back_item_data(1).get("type", "") == "weapon_rifle")
	swap_player.free()
	use_player.free()
	print("PASS: back item leaves inventory, drops once, and old axe type migrates")
	player.free()
	quit()
