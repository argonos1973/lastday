extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	var forced_target = null
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _get_interaction_target():
		return forced_target

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

class TestNet extends Node:
	var is_connected := true
	var is_host := false
	var is_dedicated_server := false
	var peer = ENetMultiplayerPeer.new()
	var client_id := 77
	func get_my_id() -> int:
		return 77

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _count_name(player: Node, name: String) -> int:
	var total := 0
	for it in player.inventory.items:
		if str(it.item_name) == name:
			total += it.quantity
	return total

func _slots_of(player: Node, name: String) -> Array:
	var out: Array = []
	for i in range(player.inventory.items.size()):
		if str(player.inventory.items[i].item_name) == name:
			out.append(i)
	return out

func _add_raw_stack(player: Node, name: String, weight: float, qty: int, use_value: float) -> void:
	var item = ItemScript.create(name, "food", weight, qty, use_value)
	player.inventory.items.append(item)

func _eat_fig_via_player(player: Node, idx: int) -> void:
	# HUD "Comer" path: select into the hand, then start consumption.
	var was_in_hand: bool = player.held_index == idx and player.hands != null and player.hands.has_item_in_hands()
	player._use_inventory_index(idx)
	if not was_in_hand and player.held_index == idx:
		player._eat_held_item()

func _initialize() -> void:
	print("=== EatStackRegression ===")
	await process_frame  # root enters the tree after _initialize
	var player := TestPlayer.new()
	root.add_child(player)
	player.stats.hunger = 50.0
	player.stats.thirst = 50.0

	# Case 1: one stack of 2 figs — eating must leave exactly 1.
	_add_raw_stack(player, "Higo", 0.10, 2, 12.0)
	var fig_idx: int = _slots_of(player, "Higo")[0]
	_eat_fig_via_player(player, fig_idx)
	check(player._consumption_pending, "Eat starts the consumption timer")

	# A second eat press during the animation must be ignored.
	player._eat_held_item()
	await create_timer(2.2).timeout
	check(_count_name(player, "Higo") == 1, "Stack of 2 figs leaves 1 after one eat (got %d)" % _count_name(player, "Higo"))

	# Case 2: two separate fig slots — eating one leaves the other intact.
	_add_raw_stack(player, "Higo", 0.10, 1, 12.0)
	_add_raw_stack(player, "Higo", 0.10, 1, 12.0)
	player.inventory.items[-2].set_meta("mark", "a")  # keep the two stacks distinct
	var fig_slots: Array = _slots_of(player, "Higo")
	check(fig_slots.size() == 3, "Separate fig slots stay unmerged (got %d slots)" % fig_slots.size())
	_eat_fig_via_player(player, fig_slots[0])
	await create_timer(2.2).timeout
	check(_count_name(player, "Higo") == 2, "Eating one fig of three total leaves 2 (got %d)" % _count_name(player, "Higo"))

	# Case 3: stack of 3 oranges — one eat leaves 2.
	_add_raw_stack(player, "Naranja", 0.20, 3, 20.0)
	var orange_idx: int = _slots_of(player, "Naranja")[0]
	_eat_fig_via_player(player, orange_idx)
	await create_timer(2.2).timeout
	check(_count_name(player, "Naranja") == 2, "Stack of 3 oranges leaves 2 after one eat (got %d)" % _count_name(player, "Naranja"))

	# Case 4: eating again only consumes another single unit.
	orange_idx = _slots_of(player, "Naranja")[0]
	player._use_inventory_index(orange_idx)  # already in hand → eats
	await create_timer(2.2).timeout
	check(_count_name(player, "Naranja") == 1, "Second eat of the held stack leaves 1 (got %d)" % _count_name(player, "Naranja"))

	# Case 5: a food pile on the ground with item_quantity > 1 loses ONE
	# unit per eat, and depletes only at zero.
	var world := TestWorld.new()
	root.add_child(world)
	player.reparent(world)
	world.player = player
	var pile = world._create_world_action("regression_fig_pile", "eat_food", "Higo", Vector3(5, 0, 5), Vector3.ONE, Color.WHITE, false, false)
	pile.set_meta("item_name", "Higo")
	pile.set_meta("item_type", "food")
	pile.set_meta("item_weight", 0.10)
	pile.set_meta("item_quantity", 3)
	pile.set_meta("item_use_value", 12.0)
	pile.set_meta("item_spoilage", 0.0)
	world.handle_world_action_eat(pile, player)
	await create_timer(1.4).timeout
	check(not pile.depleted and int(pile.get_meta("item_quantity", 0)) == 2, "Eating from a 3-fig pile leaves qty 2 (got %d, depleted=%s)" % [int(pile.get_meta("item_quantity", 0)), pile.depleted])
	world.handle_world_action_eat(pile, player)
	await create_timer(1.4).timeout
	check(not pile.depleted and int(pile.get_meta("item_quantity", 0)) == 1, "Second eat leaves qty 1 (got %d, depleted=%s)" % [int(pile.get_meta("item_quantity", 0)), pile.depleted])
	world.handle_world_action_eat(pile, player)
	await create_timer(1.4).timeout
	check(pile.depleted, "Third eat depletes the pile")
	# Drop tracking stays consistent: partial eats keep the entry, the last one removes it.
	check(world._dropped_items.is_empty(), "Depleted pile leaves no drop record")

	# Case 6: multiplayer client — a stale restore_player_inventory landing
	# during the 2s eat animation must cancel the pending eat rather than
	# consume an item the authoritative snapshot still contains.
	var mp_world := TestWorld.new()
	root.add_child(mp_world)
	var mp_net := TestNet.new()
	mp_world.add_child(mp_net)
	mp_world.net = mp_net
	var mp_player := TestPlayer.new()
	mp_world.add_child(mp_player)
	mp_world.player = mp_player
	_add_raw_stack(mp_player, "Higo", 0.10, 2, 12.0)
	var mp_idx: int = _slots_of(mp_player, "Higo")[0]
	_eat_fig_via_player(mp_player, mp_idx)
	# The eat is animating; a late restore with the server's pre-eat snapshot
	# (still 2 figs) replaces the inventory before the timer fires.
	var stale_inv: Array = [ItemScript.create("Higo", "food", 0.10, 2, 12.0).to_dict()]
	mp_world._apply_restored_inventory(stale_inv, 100.0, 60.0, 60.0, "", "", "", 0, false, false, 0.0, false, false, {})
	await create_timer(2.2).timeout
	check(_count_name(mp_player, "Higo") == 2, "Stale restore mid-eat cancels the eat, no item lost or duplicated (got %d)" % _count_name(mp_player, "Higo"))

	# Case 7: fish held in hand + M while looking at a ground mushroom must eat
	# the mushroom, not the held fish.
	var eat_world := TestWorld.new()
	root.add_child(eat_world)
	current_scene = eat_world  # _eat_action routes through get_tree().current_scene
	var eat_player := TestPlayer.new()
	eat_world.add_child(eat_player)
	eat_world.player = eat_player
	eat_player.stats.hunger = 50.0
	eat_player.stats.thirst = 50.0
	_add_raw_stack(eat_player, "Pez crudo", 0.55, 1, 24.0)
	_add_raw_stack(eat_player, "Seta", 0.05, 1, 8.0)
	var fish_idx: int = _slots_of(eat_player, "Pez crudo")[0]
	eat_player._select_held_item(fish_idx)
	check(eat_player.get_held_item() != null and str(eat_player.get_held_item().item_name) == "Pez crudo", "Fish is in hand")
	var seta = eat_world._create_world_action("regression_seta", "eat_food", "Seta", Vector3(1, 0, 1), Vector3.ONE, Color.WHITE, false, false)
	seta.set_meta("item_name", "Seta")
	seta.set_meta("item_type", "food")
	seta.set_meta("item_use_value", 8.0)
	seta.set_meta("item_spoilage", 0.0)
	eat_player.forced_target = seta
	eat_player._eat_action()
	await create_timer(1.5).timeout
	check(_count_name(eat_player, "Pez crudo") == 1, "M on a targeted mushroom keeps the held fish (got %d)" % _count_name(eat_player, "Pez crudo"))
	check(seta.depleted, "M on a targeted mushroom eats the mushroom")

	# Case 8: M with food in hand and no eatable target still eats the held item.
	eat_player.forced_target = null
	eat_player._consumption_pending = false
	eat_player._eat_action()
	await create_timer(2.2).timeout
	check(_count_name(eat_player, "Pez crudo") == 0, "M with no target eats the held fish (got %d)" % _count_name(eat_player, "Pez crudo"))

	# Case 9: M with EMPTY hands must never pull food straight from inventory.
	_add_raw_stack(eat_player, "Higo", 0.10, 2, 12.0)
	eat_player.clear_hands()
	eat_player._consumption_pending = false
	eat_player._eat_action()
	await create_timer(2.2).timeout
	check(_count_name(eat_player, "Higo") == 2, "M with empty hands eats nothing from inventory (got %d)" % _count_name(eat_player, "Higo"))

	player.free()
	world.free()
	eat_player.free()
	eat_world.free()
	mp_player.free()
	mp_world.free()
	if failures == 0:
		print("EatStackRegression: ALL PASS")
	else:
		print("EatStackRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
