extends SceneTree
const Cases = preload("res://tools/debug/TestGameplayBugs.gd")
const Inv = preload("res://scripts/Inventory.gd")
const ItemData = preload("res://scripts/Item.gd")
const Hands = preload("res://scripts/PlayerHands.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")

class PickupWorld extends "res://scripts/Main.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _play_actor_action(_actor, _action_name: String, _duration: float) -> void: pass
	func _save_world_change_silent() -> void: pass
	func _net_notify_pickup(_action) -> void: pass

class Pickup extends Node:
	var depleted := false
	func mark_depleted() -> void: depleted = true

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var player := Cases.TestPlayer.new()
	root.add_child(player)
	var inv := Inv.new()
	player.inventory = inv
	player.add_child(inv)
	player.hands = Hands.new()
	player.add_child(player.hands)
	inv.changed.connect(player._on_inventory_changed)
	inv.add_item(ItemData.create("Palo", "material", 0.1))
	inv.add_item(ItemData.create("Cuchillo", "weapon", 0.1))
	check(player.get_held_item() == null and not player.hands.has_item_in_hands(), "Adding inventory does not equip")
	player._sync_held_item()
	check(player.get_held_item() == null, "Passive visual sync leaves hands empty")
	player._select_held_item(1)
	var knife = inv.items[1]
	check(player.get_held_item() == knife and player.hands.current_item == knife, "Explicit selection equips")
	inv.swap_items(0, 1)
	check(player.get_held_item() == knife and player.held_index == 0, "Sorting retains selected object")
	player._store_held_item()
	inv.add_item(ItemData.create("Piedra", "material", 0.2))
	inv.changed.emit()
	player._sync_held_item()
	check(player.get_held_item() == null and not player.hands.has_item_in_hands(), "Stored object does not return after inventory changes")
	player._select_held_item(0)
	inv.remove_index(0)
	check(player.get_held_item() == null and not player.hands.has_item_in_hands(), "Removing selection does not select next slot")
	player._sync_held_item()
	check(player.get_held_item() == null, "Later refresh does not select replacement")
	player._cycle_held_item()
	check(player.get_held_item() == inv.items[0], "Explicit cycle from empty hands selects first")
	player.clear_hands()
	player._select_held_item(-1)
	player._select_held_item(999)
	check(player.get_held_item() == null, "Invalid selection does not fall back to first slot")
	player.equip_item_by_name("Piedra")
	check(player.get_held_item().item_name == "Piedra", "Explicit equip by name works")
	player.clear_hands()
	var world := PickupWorld.new()
	root.add_child(world)
	var action := Pickup.new()
	root.add_child(action)
	world._finish_pickup_action(action, player, ItemData.create("Higo", "food", 0.1), "Recogido", "pickup", 0.1, false)
	check(action.depleted and inv.has_item_name("Higo"), "World pickup adds item")
	check(player.get_held_item() == null, "World pickup leaves empty hands empty")
	player.equip_item_by_name("Piedra")
	world._finish_pickup_action(action, player, ItemData.create("Naranja", "food", 0.1), "Recogido", "pickup", 0.1, false)
	check(player.get_held_item().item_name == "Piedra", "Pickup does not replace selected resource")
	player.clear_hands()
	var saved := SaveHooks.collect_player_data(player)
	check(saved.held_item == "" and saved.held_index == -1, "Save records empty hands, not inventory cursor")
	player.restore_held_item(saved.held_item, saved.held_index)
	check(player.get_held_item() == null, "Restoring empty hands leaves no equipped object")
	player.equip_item_by_name("Piedra")
	saved = SaveHooks.collect_player_data(player)
	player.clear_hands()
	player.restore_held_item(saved.held_item, saved.held_index)
	check(player.get_held_item().item_name == "Piedra", "Selected item survives saved state restore")
	player._use_inventory_index(inv.items.find(inv.items.filter(func(it): return it.item_name == "Higo")[0]))
	check(player.get_held_item().item_name == "Higo" and not player._consumption_pending, "Switching food explicitly equips it without consuming previous item")
	player._store_held_item()
	player.is_sleeping = true
	player._sync_held_item()
	inv.changed.emit()
	check(player.get_held_item() == null, "Updates while sleeping do not re-equip stored item")
	player.is_sleeping = false
	player.restore_held_item("Missing", 0)
	check(player.get_held_item() == null, "Mismatched saved slot cannot equip unrelated object")
	world.queue_free()
	action.queue_free()
	player.queue_free()
	await process_frame
	print("HAND SELECTION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
