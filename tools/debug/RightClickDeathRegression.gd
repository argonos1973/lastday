extends SceneTree

const ItemData = preload("res://scripts/Item.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")
const Wildlife = preload("res://scripts/WildlifeController.gd")
var failures := 0

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class FakeRaycast extends Node:
	var target = null
	func get_interactable(_p, _c, _o = Vector2.ZERO):
		return target
	func get_default_text(t, p = null) -> String:
		if t != null and t.has_method("get_interaction_text"):
			return str(t.call("get_interaction_text", p))
		return ""

class FakeDoor extends Node3D:
	var opened := false
	func get_interaction_text(_p = null) -> String:
		return "[F] Cerrar puerta" if opened else "[F] Abrir puerta"
	func interact(_player) -> void:
		opened = not opened

class FakeNet extends RefCounted:
	var peer = null
	var players := {}
	var is_host := true
	var is_connected := false
	var is_dedicated_server := true
	func peer_alive(_pid: int) -> bool:
		return false

class TestWorld extends "res://scripts/Main.gd":
	var spawned_drops: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _hide_action_visual(_action) -> void:
		pass
	func _spawn_ground_pickup(item_name: String, item_type: String, pos: Vector3, weight: float, qty: int, use_value: float, fixed_id: String = "", action_type_override: String = "", wetness: float = 0.0, color: Color = Color(0, 0, 0, 0)) -> void:
		spawned_drops.append({"name": item_name, "type": item_type, "qty": qty, "pos": pos})
		var wa = WorldActionScript.new()
		wa.action_id = fixed_id
		wa.action_type = action_type_override if not action_type_override.is_empty() else "pickup_item"
		wa.display_name = item_name
		add_child(wa)
		wa.set_meta("item_name", item_name)
		wa.set_meta("item_type", item_type)
		world_actions_by_id[fixed_id] = wa
		_dropped_items.append({"id": fixed_id, "name": item_name, "type": item_type, "weight": weight, "qty": qty, "use": use_value, "pos": [pos.x, pos.y, pos.z], "action_type": wa.action_type})

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _make_corpse_action(world: Node, species: String, item_name: String) -> Node:
	var action = WorldActionScript.new()
	action.action_type = "gut_wolf"
	action.display_name = item_name
	world.add_child(action)
	action.set_meta("animal_type", species)
	action.set_meta("item_name", item_name)
	action.set_meta("gutted", false)
	return action

func _inv_has(player, item_name: String) -> bool:
	for item in player.inventory.items:
		if item != null and item.item_name == item_name:
			return true
	return false

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	world.net = FakeNet.new()
	var player := TestPlayer.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.inventory.items.clear()
	player.equipped_backpack = "Mochila pequena"
	var bp = ItemData.create("Mochila pequena", "backpack", 0.7)
	bp.set_meta("equipped_slot", "backpack")
	player.inventory.items.append(bp)
	player.refresh_carry_capacity()
	var ray := FakeRaycast.new()
	player.add_child(ray)
	player.raycast = ray
	# El que recoge el loot de muerte es otro cliente reconectado: jugador fresco.
	var survivor := TestPlayer.new()
	world.add_child(survivor)
	survivor.set_process(false)
	survivor.set_physics_process(false)
	survivor.inventory.items.clear()
	survivor.equipped_backpack = "Mochila pequena"
	var bp2 = ItemData.create("Mochila pequena", "backpack", 0.7)
	bp2.set_meta("equipped_slot", "backpack")
	survivor.inventory.items.append(bp2)
	survivor.refresh_carry_capacity()
	var ray2 := FakeRaycast.new()
	survivor.add_child(ray2)
	survivor.raycast = ray2
	world.player = player

	# --- Corpse prompt advertises collect without a blade.
	var bear_action = _make_corpse_action(world, "bear", "Oso muerto")
	var text_no_blade: String = bear_action.get_interaction_text(player)
	check(not text_no_blade.is_empty(), "Corpse prompt must not be empty without a blade")
	check(text_no_blade.contains("[C]"), "Corpse prompt offers Coger without blade: " + text_no_blade)
	check(not text_no_blade.contains("[F]"), "Corpse prompt without blade has no F action: " + text_no_blade)
	var knife = ItemData.create("Cuchillo", "weapon", 0.4)
	player.inventory.items.append(knife)
	player._select_held_item(player.inventory.items.find(knife))
	var text_blade: String = bear_action.get_interaction_text(player)
	check(text_blade.contains("[F]") and text_blade.contains("[C]"), "Corpse prompt with blade offers Destripar + Coger: " + text_blade)
	player._store_held_item()

	# --- Right-click on a corpse without blade routes to collect, not gut.
	ray.target = bear_action
	var notices: Array = []
	player.notice.connect(func(m): notices.append(str(m)))
	check(player._right_click_interact(bear_action), "RMB on a corpse executes an advertised action")
	check(_inv_has(player, "Oso muerto"), "RMB collects the dead bear without a knife")
	check(bear_action.depleted, "Corpse action depleted after RMB collect")
	var gut_denied := false
	for n in notices:
		if str(n).find("cuchillo") >= 0 or str(n).find("hacha") >= 0:
			gut_denied = true
	check(not gut_denied, "RMB collect never routes through the blade requirement")
	for item in player.inventory.items:
		if item != null and item.item_name == "Oso muerto":
			check(item.cargo_location == "backpack", "Collected corpse lands in the backpack compartment")
			player.inventory.items.erase(item)
			break
	bear_action.queue_free()

	# --- RMB on a door runs the [F] interact action.
	var door = FakeDoor.new()
	world.add_child(door)
	ray.target = door
	check(player._right_click_interact(door), "RMB accepts an [F] prompt target")
	check(door.opened, "RMB opens the door like F")
	check(player._right_click_interact(door), "RMB accepts the close-door prompt")
	check(not door.opened, "RMB closes the door like F")
	door.queue_free()

	# --- RMB on a ground pickup runs [C] collect.
	var stick_action = WorldActionScript.new()
	stick_action.action_type = "pickup_item"
	stick_action.display_name = "Palo"
	world.add_child(stick_action)
	stick_action.set_meta("item_name", "Palo")
	stick_action.set_meta("item_type", "resource")
	stick_action.set_meta("item_weight", 0.3)
	stick_action.set_meta("item_quantity", 1)
	stick_action.set_meta("item_use_value", 0.0)
	ray.target = stick_action
	check(player._right_click_interact(stick_action), "RMB accepts a [C] Coger prompt")
	check(_inv_has(player, "Palo"), "RMB collects the ground item like C")
	check(stick_action.depleted, "Pickup action depleted after RMB collect")
	stick_action.queue_free()

	# --- RMB on eat_food routes to the eat path (_eat_action / [M]).
	var mushroom = WorldActionScript.new()
	mushroom.action_type = "eat_food"
	mushroom.display_name = "Seta"
	world.add_child(mushroom)
	mushroom.set_meta("item_name", "Seta")
	mushroom.set_meta("item_type", "food")
	mushroom.set_meta("item_weight", 0.05)
	mushroom.set_meta("item_quantity", 1)
	mushroom.set_meta("item_use_value", 12.0)
	ray.target = mushroom
	var hunger_before: float = player.stats.hunger
	player.stats.hunger = 50.0
	check(player._right_click_interact(mushroom), "RMB accepts an [M] Comer prompt")
	check(player._interact_busy, "RMB on food enters the eat action like M")
	await create_timer(1.5).timeout
	check(not player._interact_busy, "Eat action releases the busy flag")
	check(player.stats.hunger > 50.0, "RMB on a mushroom restores hunger like M")
	check(mushroom.depleted, "Mushroom consumed after RMB eat")
	mushroom.queue_free()

	# --- RMB with no advertised action falls back to rifle aiming.
	ray.target = null
	var rifle = ItemData.create("Fusil de caza", "weapon_rifle", 3.5)
	player._held_item_reference = rifle
	player._held_item_external = true
	player.held_index = -1
	player._rifle_in_hands = true
	check(not player._is_aiming, "Not aiming before RMB")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	player._on_game_mouse_button_pressed(rmb)
	check(player._is_aiming, "RMB with no interactive prompt aims the rifle")
	if player._is_aiming:
		player._toggle_aim()

	# --- Death loot: externally held rifle ends up on the ground.
	var extra := world._build_inventory_sync_extra(player.get_held_item())
	check(extra.has("held_item_data"), "Sync extra carries the externally held item payload")
	if extra.has("held_item_data"):
		check(str(extra["held_item_data"].get("name", "")) == "Fusil de caza", "held_item_data serializes the rifle")
		check(str(extra["held_item_data"].get("type", "")) == "weapon_rifle", "held_item_data keeps the rifle type")
	var proxy := Node3D.new()
	world.add_child(proxy)
	proxy.set_meta("saved_inventory", [{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 1, "use_value": 0.0}])
	proxy.set_meta("saved_extra", {"held_item_data": extra.get("held_item_data", {}), "back_items": []})
	proxy.set_meta("saved_backpack", "")
	proxy.set_meta("saved_clothing", "")
	proxy.set_meta("proxy_dead", true)
	world.spawned_drops.clear()
	world._drop_player_loot(42, proxy)
	var names: Array = world.spawned_drops.map(func(d): return str(d.get("name", "")))
	check(names.has("Fusil de caza"), "Death loot includes the rifle held in hand")
	check(names.has("Palo"), "Death loot still includes inventory items")
	var rifle_drop = null
	for wa in world.world_actions_by_id.values():
		if wa is WorldAction and str(wa.get_meta("item_name", "")) == "Fusil de caza":
			rifle_drop = wa
	check(rifle_drop != null, "Rifle death drop registers a world action")
	check(proxy.get_meta("saved_inventory", [1]).is_empty(), "Corpse inventory is cleared after loot drop")

	# Recovering the rifle from the death loot needs no special handling.
	if rifle_drop != null:
		ray2.target = rifle_drop
		check(survivor._right_click_interact(rifle_drop), "RMB loots the rifle from death loot")
		check(_inv_has(survivor, "Fusil de caza"), "Rifle returns to the reconnecting survivor")
	# A corpse from death loot is picked whole, species intact, without a blade.
	var wolf_action = _make_corpse_action(world, "wolf", "Lobo muerto")
	world.handle_world_action_collect(wolf_action, survivor)
	check(_inv_has(survivor, "Lobo muerto"), "Species stays correct after death-loot collect")

	# Gutting still requires a blade in hand (F path unchanged).
	var deer_action = _make_corpse_action(world, "deer", "Ciervo muerto")
	world.handle_world_action(deer_action, player)
	check(not deer_action.depleted and _corpse_meta_gutted(deer_action) == false, "Gutting without blade is still blocked")

	print("RightClickDeathRegression: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _corpse_meta_gutted(action) -> bool:
	return bool(action.get_meta("gutted", false))
