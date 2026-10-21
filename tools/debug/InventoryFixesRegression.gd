extends SceneTree

const ItemData = preload("res://scripts/Item.gd")
const Cargo = preload("res://scripts/InventoryCargo.gd")
const Wildlife = preload("res://scripts/WildlifeController.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")
var failures := 0

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _hide_action_visual(_action) -> void:
		pass

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

func _corpse_item(player, item_name: String):
	for item in player.inventory.items:
		if item.item_name == item_name:
			return item
	return null

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
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

	# --- Whole-corpse pickup keeps the real species, never falls back to wolf.
	var corpse_total := {"bear": 0, "deer": 0, "fox": 0, "wolf": 0}
	var expected_corpse := {"bear": "Oso muerto", "deer": "Ciervo muerto", "fox": "Zorro muerto", "wolf": "Lobo muerto"}
	for row in [["bear", "Oso muerto"], ["deer", "Ciervo muerto"], ["fox", "Zorro muerto"], ["wolf", "Lobo muerto"]]:
		var action = _make_corpse_action(world, row[0], row[1])
		world.handle_world_action_collect(action, player)
		var found = _corpse_item(player, row[1])
		check(found != null, "Collecting %s adds %s to inventory" % [row[0], row[1]])
		check(action.depleted, "Corpse action is consumed after pickup: " + row[1])
		if found != null:
			check(found.cargo_location == "backpack", row[1] + " lands in the backpack compartment")
			corpse_total[row[0]] += found.quantity
			# 8 kg per corpse — remove it so the small backpack keeps fitting.
			player.inventory.items.erase(found)
	for sp in corpse_total:
		check(corpse_total[sp] == 1, "Exactly one %s corpse was collected, named %s" % [sp, expected_corpse[sp]])
	check(_corpse_item(player, "Lobo muerto") == null, "Corpse list is clean after the round trip")

	# animal_type meta alone resolves the species when item_name is missing.
	var meta_only = WorldActionScript.new()
	meta_only.action_type = "gut_wolf"
	meta_only.display_name = "Ciervo muerto"
	world.add_child(meta_only)
	meta_only.set_meta("animal_type", "deer")
	meta_only.set_meta("gutted", false)
	world.handle_world_action_collect(meta_only, player)
	var deer_found = _corpse_item(player, "Ciervo muerto")
	check(deer_found != null, "animal_type meta alone resolves the deer corpse name")
	if deer_found != null:
		player.inventory.items.erase(deer_found)
	meta_only.queue_free()

	# A gutted corpse yields nothing.
	var gutted = _make_corpse_action(world, "bear", "Oso muerto")
	gutted.set_meta("gutted", true)
	world.handle_world_action_collect(gutted, player)
	check(_corpse_item(player, "Oso muerto") == null, "Gutted corpse adds nothing")
	gutted.queue_free()

	# Dropping the corpse spawns the right model and a species-tagged action.
	var bear_paths: Array = world._get_drop_model_paths("Oso muerto", "material")
	check(not bear_paths.is_empty() and bear_paths[0] == GameConst.BEAR_MODEL, "Oso muerto drop resolves to the bear model")
	check(world._get_drop_model_paths("Ciervo muerto", "material")[0] == GameConst.DEER_MODEL, "Ciervo muerto drop resolves to the deer model")
	check(world._get_drop_model_paths("Zorro muerto", "material")[0] == GameConst.FOX_MODEL, "Zorro muerto drop resolves to the fox model")
	check(Wildlife.corpse_species("Oso muerto") == "bear", "corpse_species maps Oso muerto to bear")

	# --- Hands hold one unit of a stack; the remainder stays in its compartment.
	var meat = ItemData.create("Carne cruda de lobo", "food", 0.3, 5, 15.0)
	meat.cargo_location = "pockets"
	player.inventory.items.append(meat)
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
	screen.transfer({"item": meat}, "hands", {})
	check(player.get_held_item() == meat, "Dragging a stack to hands selects it")
	check(player.inventory.items.has(meat) and meat.quantity == 5, "Held stack keeps its units inside the inventory")
	check(screen.item_text(meat, 1, true).contains("x1"), "Hands card shows exactly one unit")
	check(screen.item_text(meat, meat.quantity - 1, false).contains("x%d" % (meat.quantity - 1)), "Remainder card shows quantity - 1")

	# Dropping the held unit drops exactly one piece.
	var drop_log: Array = []
	player.item_dropped.connect(func(n, _t, _w, q, _u, _p, _c, _b, _s): drop_log.append([n, q]))
	player._drop_held_item()
	check(drop_log.size() == 1 and drop_log[0][1] == 1, "Dropping held stack drops a single unit")
	check(meat.quantity == 4, "Remainder keeps quantity - 1 after held drop")
	check(player.get_held_item() == meat, "Stack remainder stays held after dropping one")
	drop_log.clear()

	# Dragging the held unit to another compartment moves only that unit.
	player._select_held_item(player.inventory.items.find(meat))
	screen.transfer({"item": meat, "from_hands": true}, "backpack", {})
	check(player.get_held_item() == null, "Moving the held unit to a compartment clears hands")
	var moved_unit = null
	for item in player.inventory.items:
		if item.item_name == "Carne cruda de lobo" and item != meat:
			moved_unit = item
	check(moved_unit != null and moved_unit.quantity == 1 and moved_unit.cargo_location == "backpack", "Held drag to a compartment moves exactly one unit")
	check(meat.quantity == 3 and meat.cargo_location == "pockets", "Source stack keeps the remaining units in place")

	# Dragging the remainder (not the held unit) moves quantity - 1.
	player._select_held_item(player.inventory.items.find(meat))
	screen.transfer({"item": meat, "held_remainder": true}, "backpack", {})
	var backpack_meat := 0
	for item in player.inventory.items:
		if item.item_name == "Carne cruda de lobo" and item.cargo_location == "backpack":
			backpack_meat += item.quantity
	check(backpack_meat == 3, "Remainder drag moves quantity - 1 to the target compartment")
	check(meat.quantity == 1 and player.get_held_item() == meat, "Held unit stays in hand after remainder move")

	# Storing the held unit returns it to the stack without duplicating.
	player._store_held_item()
	check(player.get_held_item() == null, "Storing the held unit clears hands")
	var total_meat := 0
	for item in player.inventory.items:
		if item.item_name == "Carne cruda de lobo":
			total_meat += item.quantity
	check(total_meat == 4, "No units are lost or duplicated across hands/compartment moves")

	# --- Headwear carries no storage.
	for hat in ["Sombrero de pescador", "Casco militar", "Gorra militar", "Gorro de piel", "Gorro de otoño", "Tocado de piel animal"]:
		var hat_item = ItemData.create(hat, "clothing", 0.3)
		check(hat_item.storage_capacity == 0, hat + " has zero storage capacity")
	var slots_before: int = player.inventory.max_slots
	var weight_before: float = player.inventory.max_weight
	player._equipped_slots["head"] = "Sombrero de pescador"
	player.refresh_carry_capacity()
	check(player.inventory.max_slots == slots_before and player.inventory.max_weight == weight_before, "Equipped hat adds no carry capacity")
	var comp_ids: Array = Cargo.compartments(player).map(func(c): return c.id)
	check(not comp_ids.has("head"), "No head compartment exists for rigid headwear")
	var cargo_items: Array = player.inventory.items.duplicate()
	var groups: Dictionary = Cargo.arrange(cargo_items, Cargo.compartments(player))
	check(not groups.has("head"), "Cargo arrangement never assigns a head compartment")
	player._equipped_slots["head"] = "Casco militar"
	player.refresh_carry_capacity()
	check(player.inventory.max_slots == slots_before, "Military helmet adds no carry capacity either")
	player._equipped_slots.erase("head")
	player.refresh_carry_capacity()

	# --- Headwear is never cut into rags.
	for garment in ["Sombrero de pescador", "Casco militar", "Gorro de piel", "Tocado de piel animal", "Zapatillas", "Botas militares"]:
		check(Crafting.is_rag_exempt(garment), garment + " is rag-exempt")
	check(not Crafting.is_rag_exempt("Chaqueta militar") and not Crafting.is_rag_exempt("Camiseta"), "Ordinary garments stay cuttable")
	for garment in ["Sombrero de pescador", "Casco militar", "Gorro de piel"]:
		var has_rag := false
		for recipe in Crafting.get_recipes_for_item(garment, "clothing"):
			if recipe["output"]["name"] == "Trapos":
				has_rag = true
		check(not has_rag, "No rag recipe exists for " + garment)
	var knife = ItemData.create("Cuchillo", "weapon", 0.4)
	player.inventory.items.append(knife)
	player._select_held_item(player.inventory.items.find(knife))
	var helmet_action = WorldActionScript.new()
	helmet_action.action_type = "pickup_item"
	helmet_action.display_name = "Casco militar"
	world.add_child(helmet_action)
	helmet_action.set_meta("item_name", "Casco militar")
	helmet_action.set_meta("item_type", "clothing")
	var helmet_text: String = helmet_action.get_interaction_text(player)
	check(not helmet_text.contains("Cortar"), "Helmet on the ground offers no rag cutting")
	check(helmet_text.contains("Equipar"), "Helmet on the ground still offers equip")
	var jacket_action = WorldActionScript.new()
	jacket_action.action_type = "pickup_item"
	jacket_action.display_name = "Chaqueta militar"
	world.add_child(jacket_action)
	jacket_action.set_meta("item_name", "Chaqueta militar")
	jacket_action.set_meta("item_type", "clothing")
	check(jacket_action.get_interaction_text(player).contains("Cortar"), "Knife + normal garment still offers rag cutting")
	jacket_action.queue_free()
	helmet_action.queue_free()
	player._store_held_item()

	# --- Context menus no longer offer Mover a…/Guardar options.
	var rag_item = ItemData.create("Trapos", "material", 0.05, 4)
	player.inventory.items.append(rag_item)
	screen.open_actions({"item": rag_item}, Vector2.ZERO)
	var labels: Array = []
	for i in range(screen.menu.get_item_count()):
		labels.append(screen.menu.get_item_text(i))
	screen.menu.hide()
	for label in labels:
		check(not label.begins_with("Mover a"), "Menu has no Mover a… entry: " + label)
	check(not labels.has("Guardar en inventario"), "Guardar en inventario stays hidden while the item is not held")
	check(labels.has("Soltar una unidad"), "Menu keeps Soltar una unidad")
	check(labels.has("Llevar a las manos"), "Menu keeps Llevar a las manos")
	check(labels.has("Separar unidades…"), "Menu keeps stack splitting")

	# Guardar en inventario must stay available for the held item.
	player._select_held_item(player.inventory.items.find(rag_item))
	screen.open_actions({"item": rag_item}, Vector2.ZERO)
	var held_stack_labels: Array = []
	for i in range(screen.menu.get_item_count()):
		held_stack_labels.append(screen.menu.get_item_text(i))
	screen.menu.hide()
	check(held_stack_labels.has("Guardar en inventario"), "Held item keeps Guardar en inventario")
	for label in held_stack_labels:
		check(not label.begins_with("Mover a"), "Held item menu has no Mover a… entry: " + label)
	player._store_held_item()

	# Held external item (back equipment) shows Soltar but no Guardar.
	var rifle = ItemData.create("Fusil de caza", "weapon_rifle", 3.5)
	player.inventory.items.append(rifle)
	player._select_held_item(player.inventory.items.find(rifle))
	var held_rifle = player.get_held_item()
	if held_rifle != null and player._held_item_external:
		screen.open_actions({"item": held_rifle}, Vector2.ZERO)
		var held_labels: Array = []
		for i in range(screen.menu.get_item_count()):
			held_labels.append(screen.menu.get_item_text(i))
		screen.menu.hide()
		check(held_labels.has("Soltar"), "Held equipment menu keeps Soltar")
		check(held_labels.has("Guardar en inventario"), "Held equipment menu keeps Guardar en inventario")
	player._store_held_item()

	print("InventoryFixesRegression: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
