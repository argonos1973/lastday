extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	var saved_world: Dictionary = {}
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		saved_world = SaveHooks.collect_world_data(self)
	func _spawn_dropped_item_visual(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color = Color(0, 0, 0, 0), broken: bool = false, spoilage: float = 0.0, contents: Array = []) -> void:
		var action = _create_world_action(drop_id, "pickup_item", item_name, pos, Vector3.ONE, Color.WHITE, false, false)
		if not contents.is_empty():
			action.set_meta("contents", contents)

class TestNetwork extends Node:
	var is_host := true
	var is_dedicated_server := true
	var is_connected := false

var failures := 0

func _check_network_pickups() -> void:
	var server := TestWorld.new()
	root.add_child(server)
	var network := TestNetwork.new()
	server.add_child(network)
	server.net = network
	var drop := {"id": "regression_drop", "name": "Trapos", "type": "resource", "weight": 0.05, "qty": 1, "use": 0.0, "pos": [10.0, 1.0, 10.0]}
	for attempt in range(2):
		server._net_item_dropped(drop.id, drop.name, drop.type, drop.weight, drop.qty, drop.use, Vector3(10, 1, 10))
	check(server._dropped_items.size() == 1, "Repeated drop notifications store a single item")
	server._dropped_items.append(drop.duplicate(true))
	server._net_item_picked_up(drop.id)
	check(server._dropped_items.is_empty(), "Pickup removes every legacy duplicate")
	check(server._depleted_action_ids.has(drop.id), "Server remembers the consumed item")
	check(server.saved_world.get("dropped_items", []).is_empty() and server.saved_world.get("depleted_action_ids", []).has(drop.id), "Server saves pickup removal immediately")
	var client := TestWorld.new()
	root.add_child(client)
	client._net_sync_world_state(server._depleted_action_ids, server._dropped_items, [], [], [])
	check(not client.world_actions_by_id.has(drop.id), "Joining client cannot respawn collected loot")
	check(client._depleted_action_ids.has(drop.id), "Snapshot remembers depletion even before the item exists")
	client._net_sync_world_state([], [drop], [], [], [])
	check(not client.world_actions_by_id.has(drop.id), "A stale snapshot cannot resurrect a collected item")
	server._net_item_dropped(drop.id, drop.name, drop.type, drop.weight, drop.qty, drop.use, Vector3(10, 1, 10))
	check(server._dropped_items.is_empty() and not server.world_actions_by_id.has(drop.id), "Late drop notification cannot resurrect collected loot")
	var fresh := drop.duplicate(true)
	fresh.id = "regression_fresh_drop"
	client._net_sync_world_state([], [fresh], [], [], [])
	check(client.world_actions_by_id.has(fresh.id), "A genuinely new drop still spawns")
	client._net_item_picked_up(fresh.id)
	client._net_sync_world_state([], [fresh], [], [], [])
	check(not client.world_actions_by_id.has(fresh.id), "Live pickup survives a repeated world snapshot")
	server._net_world_action_completed("regression_cut", [fresh], "", Vector3.ZERO)
	server._net_world_action_completed("regression_cut", [fresh], "", Vector3.ZERO)
	check(server._dropped_items.size() == 1, "Repeated world-action notification does not duplicate its loot")
	server._net_item_picked_up(fresh.id)
	server._net_world_action_completed("regression_cut", [fresh], "", Vector3.ZERO)
	check(server._dropped_items.is_empty(), "World-action replay cannot restore collected loot")
	var local_drop := drop.duplicate(true)
	local_drop.id = "regression_local_drop"
	client._net_sync_world_state([], [local_drop], [], [], [])
	client._dropped_items = [local_drop.duplicate(true), local_drop.duplicate(true)]
	client._net_notify_pickup(client.world_actions_by_id[local_drop.id])
	check(client._depleted_action_ids.has(local_drop.id) and client._dropped_items.is_empty(), "Local pickup removes duplicates and remembers depletion")
	check(client.saved_world.get("dropped_items", []).is_empty(), "Local pickup saves only after removing collected entries")
	client._net_sync_world_state(["regression_initial_axe"], [], [], [], [])
	client._create_world_action("regression_initial_axe", "axe_tool", "Hacha", Vector3.ZERO, Vector3.ONE, Color.WHITE, false, false)
	client._apply_pending_restore()
	check(not client.world_actions_by_id.has("regression_initial_axe"), "Depletion received during map loading applies after generation")
	client.free()
	server.free()

func _check_network_restore(backpack: String = "") -> void:
	var world := TestWorld.new()
	root.add_child(world)
	var restored := TestPlayer.new()
	world.add_child(restored)
	world.player = restored
	var clothing := "Camiseta,Pantalones,Zapatillas"
	for item_name in clothing.split(","):
		restored.equip_clothing(item_name)
	var items: Array = []
	for item_name in ["Trapos", "Palo", "Piedra", "Cuerda", "Leña"]:
		items.append(ItemScript.create(item_name, "resource", 0.05, 1, 0.0).to_dict())
	for item in restored.inventory.items:
		item.durability = 42.0
		items.append(item.to_dict())
	if not backpack.is_empty():
		items.append(ItemScript.create(backpack, "backpack", 0.5, 1, 0.0).to_dict())
	var drops: Array = []
	restored.item_dropped.connect(func(item_name, _type, _weight, _qty, _use, _pos, _color, _broken, _spoilage): drops.append(item_name))
	for attempt in range(2):
		if attempt == 1:
			world.player = null
		world._apply_restored_inventory(items, 80.0, 70.0, 60.0, clothing, backpack, "", -1, false, false, 0.0)
		if attempt == 1:
			world.player = restored
			world._apply_pending_restore()
		check(drops.is_empty(), "Network restore must not drop items (attempt %d): %s" % [attempt, drops])
		check(restored.inventory.items.size() == items.size(), "Network restore preserves every inventory entry")
		for i in range(mini(items.size(), restored.inventory.items.size())):
			check(restored.inventory.items[i].to_dict() == items[i], "Network restore preserves item payload %d" % i)
		check(restored._equipped_slots.size() == 3, "Network restore keeps the saved outfit")
		check(not restored._initializing, "Network restore releases the initialization guard")
	check(not restored.is_dead and restored.stats.health == 80.0, "Network restore keeps the living player alive")
	check(restored.equipped_backpack == backpack, "Network restore keeps the saved backpack")
	check(restored.inventory.max_slots == 8 + (restored.SMALL_BACKPACK_SLOTS if not backpack.is_empty() else 0), "Capacity is recalculated from the complete restored equipment")
	restored._initializing = true
	world._apply_restored_inventory(items, 80.0, 70.0, 60.0, clothing, backpack, "", -1, false, false, 0.0)
	check(restored._initializing and drops.is_empty(), "Nested initialization stays guarded without drops")
	restored._initializing = false
	if backpack.is_empty():
		restored.unequip_clothing("Camiseta")
		check(not drops.is_empty(), "Normal equipment removal still drops excess items")
	world.free()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_check_network_pickups()
	_check_network_restore()
	_check_network_restore("Mochila pequena")
	var player := TestPlayer.new()
	root.add_child(player)
	# Store a rifle on the back — it leaves the inventory
	var rifle = ItemScript.create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	player.inventory.items.append(rifle)  # bypass capacity — we test save/load, not slots
	check(player._store_inventory_rifle_on_back(), "Rifle stores on a shoulder slot")
	check(not _inventory_has_type(player, "weapon_rifle"), "Stored rifle leaves the inventory")
	var data: Dictionary = SaveHooks.collect_player_data(player)
	var back_items: Array = data.get("back_items", [])
	check(back_items.size() == 2 and str(back_items[0].get("name", "")) == "Rifle francotirador", "Back items are serialized")
	var inventory_names := []
	for d in data.get("inventory", []):
		inventory_names.append(str(d.get("name", "")))
	check(not inventory_names.has("Rifle francotirador"), "Saved inventory does not duplicate the stored rifle")
	# Restore onto a fresh player
	var restored := TestPlayer.new()
	root.add_child(restored)
	SaveHooks.apply_saved_player_data(restored, data)
	check(restored._has_stored_back_item_type("weapon_rifle"), "Back rifle survives the load")
	check(not _inventory_has_type(restored, "weapon_rifle"), "Restored back rifle does not duplicate into inventory")
	check(restored.use_back_item(0), "Back item returns to the hands after load")
	var held = restored.get_held_item()
	check(held != null and str(held.item_name) == "Rifle francotirador", "The held item after load is the saved rifle")
	# Held back equipment is external: it leaves the inventory and its saved
	# index is -1. Saving now must keep the full payload so the next load does
	# not lose the rifle — the regression that deleted it on continue.
	var held_data: Dictionary = SaveHooks.collect_player_data(restored)
	check(str(held_data.get("held_item", "")) == "Rifle francotirador", "Held rifle is named in the save")
	check(int(held_data.get("held_index", 0)) == -1, "External held rifle saves index -1")
	var held_payload = held_data.get("held_item_data", {})
	check(held_payload is Dictionary and str(held_payload.get("type", "")) == "weapon_rifle", "Held rifle payload is serialized")
	var held_restored := TestPlayer.new()
	root.add_child(held_restored)
	SaveHooks.apply_saved_player_data(held_restored, held_data)
	var held2 = held_restored.get_held_item()
	check(held2 != null and str(held2.item_name) == "Rifle francotirador", "Externally held rifle survives the load")
	check(not _inventory_has_type(held_restored, "weapon_rifle"), "External held rifle is not duplicated into inventory")
	check(not held_restored._has_stored_back_item_type("weapon_rifle"), "External held rifle is not duplicated onto the back")
	# Legacy saves only kept the held name — the rifle must still come back.
	var legacy_held := TestPlayer.new()
	root.add_child(legacy_held)
	SaveHooks.apply_saved_player_data(legacy_held, {
		"pos": [1.0, 0.0, 2.0], "inventory": [],
		"held_item": "Rifle francotirador", "held_index": -1,
	})
	var legacy_rifle = legacy_held.get_held_item()
	check(legacy_rifle != null and str(legacy_rifle.item_name) == "Rifle francotirador", "Legacy save rebuilds the held rifle by name")
	# Old saves without back_items must not break
	var legacy := TestPlayer.new()
	root.add_child(legacy)
	SaveHooks.apply_saved_player_data(legacy, {"pos": [1.0, 0.0, 2.0], "inventory": []})
	check(not legacy._has_stored_back_item_type("weapon_rifle"), "Legacy saves without back_items load cleanly")
	player.free()
	restored.free()
	held_restored.free()
	legacy_held.free()
	legacy.free()
	if failures == 0:
		print("PASS: collected loot stays removed across syncs; network inventory restore drops no loot; back-stored items survive save and load")
	quit(1 if failures else 0)

func _inventory_has_type(player: Node, item_type: String) -> bool:
	for item in player.inventory.items:
		if item != null and str(item.item_type) == item_type:
			return true
	return false
