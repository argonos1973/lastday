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

class TestWorld extends "res://scripts/Main.gd":
	var collected := 0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
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
	var tiny_containers := [{"id": "pockets", "capacity": 1}, {"id": "backpack", "capacity": 1}]
	var blocker = ItemData.create("Piedra", "resource", 0.3)
	blocker.cargo_location = "backpack"
	rags.cargo_location = "pockets"
	player.inventory.items.append(blocker)
	var full_before: Array = player.inventory.to_array()
	check(not Cargo.can_move(rags, "backpack", player.inventory, tiny_containers), "Full cargo rejects drag preview")
	check(not Cargo.move(rags, "backpack", player.inventory, tiny_containers), "Full cargo rejects transfer")
	check(full_before == player.inventory.to_array(), "Rejected drag and drop do not mutate cargo")
	player.inventory.items.erase(blocker)
	var sample := [
		["Cuchillo", "weapon", 0.4], ["Botella de agua", "water", 1.0],
		["Cerillas", "tool_matches", 0.05], ["Caña de pescar", "tool_fishing", 0.8],
		["Chaqueta militar", "clothing", 0.9], ["Pantalones militares", "clothing", 0.8],
		["Mochila pequena", "backpack", 0.7], ["Pez crudo", "food", 0.3]]
	for row in sample:
		player.inventory.add_item(ItemData.create(row[0], row[1], row[2]))
	var axe = ItemData.create("Hacha", "tool_axe", 1.2)
	player.inventory.items.append(axe)
	player._select_held_item(player.inventory.items.find(axe))
	if "--preview" in OS.get_cmdline_user_args():
		player._initializing = true
		player.equip_clothing("Chaqueta militar")
		player.equip_clothing("Pantalones militares")
		player.equip_clothing("Botas survival")
		player.equip_backpack("Mochila pequena")
		player._initializing = false
		player._update_third_person_animation(false, 0.1)
		await process_frame
		player._update_backpack_socket()
		player._update_hand_socket()
	else:
		player.third_person_model = Node3D.new()
		player.add_child(player.third_person_model)
		var skeleton := Skeleton3D.new()
		skeleton.name = "BodySkeleton"
		skeleton.add_bone("Root")
		skeleton.add_bone("Head")
		skeleton.set_bone_pose_position(1, Vector3(0, 1.7, 0))
		player.third_person_model.add_child(skeleton)
		var attachment := BoneAttachment3D.new()
		attachment.name = "BoneAttachment3D_RightHand"
		attachment.bone_name = "Root"
		skeleton.add_child(attachment)
		var weapon := MeshInstance3D.new()
		weapon.name = "WeaponMesh"
		weapon.mesh = BoxMesh.new()
		weapon.scale = Vector3.ONE * 100.0
		attachment.add_child(weapon)
		for socket_name in ["HandsSocket", "BackpackSocket"]:
			var socket := Node3D.new()
			socket.name = socket_name
			player.third_person_model.add_child(socket)
			var prop := MeshInstance3D.new()
			prop.name = "EquipmentMesh"
			prop.mesh = BoxMesh.new()
			socket.add_child(prop)
	var hud = preload("res://scripts/HUD.gd").new()
	world.add_child(hud)
	hud.set_process(false)
	hud.player = player
	hud.main_node = world
	hud.root = Control.new()
	hud.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud.root)
	hud.objective_label = Label.new()
	hud.root.add_child(hud.objective_label)
	hud._build_inventory_panel()
	hud.inventory_visible = true
	hud.inventory_panel.show()
	var screen = hud.survival_inventory
	var jacket = find_item(player, "Chaqueta militar")
	check(screen.can_transfer({"item": jacket}, "equip:torso", {}), "Jacket fits torso")
	check(not screen.can_transfer({"item": jacket}, "equip:feet", {}), "Jacket rejected by feet slot")
	check(not screen.can_transfer({"item": axe}, "equip:torso", {}), "Tools rejected by clothing slots")
	screen.open_split(rags)
	screen.split_amount.value = 2
	screen.split_dialog.confirmed.emit()
	screen.split_dialog.hide()
	check(rags.quantity == 6, "Split dialog separates the requested quantity")
	var separated = player.inventory.items.back()
	check(separated.quantity == 2 and separated.item_name == rags.item_name, "Split dialog preserves the new stack")
	check(player.inventory.combine_stack(separated, rags), "Split dialog stack can merge again")
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
	var portrait_model = screen.portrait._model_root.get_child(0)
	check(portrait_model.get_node_or_null("HandsSocket") != null, "Portrait keeps held-item socket")
	check(portrait_model.get_node_or_null("BackpackSocket") != null, "Portrait keeps backpack socket")
	if not "--preview" in OS.get_cmdline_user_args():
		check(portrait_model.get_node_or_null("BodySkeleton/BoneAttachment3D_RightHand/WeaponMesh") != null, "Portrait keeps bone-attached equipment")
		check(screen.portrait._cam.size < 3.0, "Large accessories do not shrink the body framing")
	var previous_portrait: String = screen.portrait_signature
	player._select_held_item(player.inventory.items.find(find_item(player, "Cuchillo")))
	screen.request_refresh(true)
	await process_frame
	await process_frame
	check(screen.portrait_signature != previous_portrait, "Switching held items refreshes the portrait")
	player._select_held_item(player.inventory.items.find(axe))
	var card = screen.make_card(screen.item_text(axe), {"item": axe, "label": axe.item_name}, "pockets")
	screen.cargo.add_child(card)
	await process_frame
	var thumbnails: Array = card.find_children("*", "SubViewportContainer", true, false)
	check(thumbnails.size() == 1, "Item card uses the actual 3D model")
	if thumbnails.size() == 1:
		check(thumbnails[0]._model_root.get_child_count() == 1, "Thumbnail loads a model, not an empty viewport")
		if thumbnails[0]._model_root.get_child_count() == 1:
			check(thumbnails[0]._model_root.get_child(0).scene_file_path == world._get_drop_model_paths(axe.item_name, axe.item_type)[0], "Thumbnail uses the same asset as world pickups")
	for label in card.find_children("*", "Label", true, false):
		check(not "kg" in label.text and not "EQUIPADO" in label.text and not "EN MANOS" in label.text, "Cards keep detailed text in the tooltip")
	for bar in card.find_children("*", "ProgressBar", true, false):
		check(bar.get_combined_minimum_size().y <= 4.0, "Condition bar stays thin")
	check("kg" in card.tooltip_text, "Item weight remains available in tooltip")
	card.queue_free()
	screen.toggle_compartment("pockets")
	await process_frame
	await process_frame
	check(screen.collapsed_compartments.get("pockets", false), "Compartment keeps collapsed state")
	var collapsed_count: int = screen.cargo.get_child_count()
	screen.toggle_compartment("pockets")
	await process_frame
	await process_frame
	check(screen.cargo.get_child_count() == collapsed_count + 1, "Reopening compartment restores its grid")
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
		var source_hand: Node3D = player.third_person_hand_item_root
		var preview_hand: Node3D = screen.portrait._model_root.get_child(0).get_node("HandsSocket")
		check(source_hand.get_child_count() > 0, "Preview fixture has a real held prop")
		check(preview_hand.get_child_count() == source_hand.get_child_count(), "Portrait retains all held geometry")
		check(source_hand.get_node_or_null("PalmGripVisual/ThirdPersonAxe") != null, "Preview fixture holds the axe, not the previous knife")
		for mesh in source_hand.find_children("*", "MeshInstance3D", true, false):
			var copy = preview_hand.get_node_or_null(source_hand.get_path_to(mesh))
			check(copy != null and copy.mesh == mesh.mesh and copy.visible == mesh.visible, "Portrait matches held mesh: " + str(source_hand.get_path_to(mesh)))
		check(player.third_person_back_item_root.get_child_count() > 0, "Preview fixture wears a real backpack")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lastday_inventory_preview.png")
		screen.portrait_yaw = 2.5
		screen._position_portrait_camera()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lastday_inventory_back_preview.png")
		print("Preview: /tmp/lastday_inventory_preview.png; /tmp/lastday_inventory_back_preview.png")
	print("Inventory regression: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func find_item(player, name: String):
	for item in player.inventory.items:
		if item.item_name == name:
			return item
	return null
