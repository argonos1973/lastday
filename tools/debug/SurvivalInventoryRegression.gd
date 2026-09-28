extends SceneTree

const ItemData = preload("res://scripts/Item.gd")
const Cargo = preload("res://scripts/InventoryCargo.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")
var failures := 0

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		if "--preview" in OS.get_cmdline_user_args():
			super._create_body()
	func _capture_mouse() -> void:
		pass

class TestWorld extends Node3D:
	var hud = null
	var collected := 0
	func handle_world_action_collect(action, _player) -> void:
		collected += 1
		action.mark_depleted()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var player := TestPlayer.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.inventory.items.clear()
	player._equipped_slots = {"torso": "Chaqueta militar", "legs": "Pantalones militares", "feet": "Botas survival"}
	player.equipped_backpack = "Mochila pequena"
	player.refresh_carry_capacity()
	var capacity := Cargo.compartments(player)
	var sum := 0
	for container in capacity:
		sum += container.capacity
	check(sum == player.inventory.max_slots, "Compartments must equal actual equipment capacity")
	var rags = ItemData.create("Trapos", "material", 0.05, 8)
	player.inventory.items.append(rags)
	check(player.inventory.split_stack(rags, 3), "Can split a stack")
	check(rags.quantity == 5 and player.inventory.items[1].quantity == 3, "Split conserves quantities")
	player.inventory.merge_stacks()
	check(player.inventory.items.size() == 2, "Autosave does not undo explicit split")
	var split = player.inventory.items[1]
	Cargo.arrange(player.inventory.items, capacity)
	check(Cargo.move(split, "backpack", player.inventory, capacity), "Can move to backpack")
	var restored = ItemData.from_dict(split.to_dict())
	check(restored.cargo_location == "backpack" and restored.stack_separated, "Save preserves compartment and split state")
	var packed: Array = player._pack_backpack_drop_contents()
	check(packed.size() == 1 and packed[0].quantity == 3, "Dropping backpack carries its assigned contents even without overflow")
	check(player.inventory.items.has(rags), "Other pockets remain intact")
	player.inventory.items.append(restored)
	check(player.inventory.combine_stack(restored, rags), "Explicit merge accepts manually separated stacks")
	check(rags.quantity == 8, "Merge conserves quantity")
	var before: Array = player.inventory.to_array()
	check(not Cargo.move(rags, "missing", player.inventory, capacity), "Reject nonexistent compartment")
	check(before == player.inventory.to_array(), "Rejected transfer preserves items")
	var sample := [
		["Cuchillo", "weapon", 0.4], ["Botella de agua", "water", 1.0],
		["Cerillas", "tool_matches", 0.05], ["Caña de pescar", "tool_fishing", 0.8],
		["Chaqueta militar", "clothing", 0.9], ["Pantalones militares", "clothing", 0.8],
		["Mochila pequena", "backpack", 0.7], ["Pez crudo", "food", 0.3]]
	for row in sample:
		player.inventory.add_item(ItemData.create(row[0], row[1], row[2]))
	var hud = preload("res://scripts/HUD.gd").new()
	world.add_child(hud)
	hud.set_process(false)
	hud.player = player
	hud.root = Control.new()
	hud.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud.root)
	hud.objective_label = Label.new()
	hud.root.add_child(hud.objective_label)
	hud._build_inventory_panel()
	hud.inventory_visible = true
	hud.inventory_panel.show()
	var screen = hud.survival_inventory
	var action = preload("res://scripts/WorldAction.gd").new()
	action.action_type = "pickup_item"
	action.display_name = "Palo"
	world.add_child(action)
	action.position = Vector3(0, 0, -1)
	await physics_frame
	check(screen.reachable(action), "Nearby pickup is reachable")
	screen.collect(action)
	screen.collect(action)
	check(world.collected == 1, "Repeated pickup cannot collect depleted object twice")
	action.depleted = false
	action.position = Vector3(0, 0, -5)
	screen.collect(action)
	check(world.collected == 1, "Out-of-reach pickup rejected")
	action.position = Vector3(0, 0, -1)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(0, 1, -0.5)
	await physics_frame
	check(not screen.reachable(action), "Cannot loot through walls")
	wall.queue_free()
	action.queue_free()
	var saved: Dictionary = SaveHooks.collect_player_data(player)
	check(saved.inventory.size() == player.inventory.items.size(), "Full player save preserves inventory")
	for frame in range(4):
		await process_frame
	check(screen.cargo.get_child_count() > 0, "Inventory screen renders compartments")
	screen.search.text = "cuchillo"
	screen.request_refresh(true)
	await process_frame
	await process_frame
	check(screen.matches_filter(find_item(player, "Cuchillo")), "Search finds matching item")
	check(not screen.matches_filter(rags), "Search hides unrelated items")
	screen.search.text = ""
	screen.request_refresh(true)
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 800)
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lastday_inventory_preview.png")
		print("Preview: /tmp/lastday_inventory_preview.png")
	print("Inventory regression: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func find_item(player, name: String):
	for item in player.inventory.items:
		if item.item_name == name:
			return item
	return null
