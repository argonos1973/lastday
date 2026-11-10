extends SceneTree

# Regression: crafting a Venda (3 Trapos) must only consume real cargo slots.
# Worn clothing/backpack are equipment, not cargo — the staged craft
# transaction must not count them or it rejects crafts with phantom
# "no space" errors while shirt/pants pockets still have room.

const ItemData = preload("res://scripts/Item.gd")
const Cargo = preload("res://scripts/InventoryCargo.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")
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

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _worn(player, item_name: String, slot: String):
	var item = ItemData.create(item_name, "clothing", 0.3, 1, 0.05)
	item.set_meta("equipped_slot", slot)
	player.inventory.items.append(item)
	player._equipped_slots[slot] = item_name
	return item

func _stored(player, item_name: String, item_type: String, weight: float, qty: int = 1, cargo: String = ""):
	var item = ItemData.create(item_name, item_type, weight, qty, 0.0)
	item.cargo_location = cargo
	player.inventory.items.append(item)
	return item

func _venda_recipe() -> Dictionary:
	for recipe in Crafting.RECIPES:
		if recipe["output"]["name"] == "Venda":
			return recipe
	return {}

func _reset_player(player) -> void:
	player.inventory.items.clear()
	player._equipped_slots.clear()
	player.equipped_backpack = ""
	player.refresh_carry_capacity()

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var player := TestPlayer.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)

	# --- Crafting prefers the spare garment over the one being worn.
	_reset_player(player)
	var worn_shirt = _worn(player, "Camiseta", "torso")
	var spare_shirt = _stored(player, "Camiseta", "clothing", 0.3)
	var knife = _stored(player, "Cuchillo", "weapon", 0.4)
	player.refresh_carry_capacity()
	var rag_recipe := {}
	for recipe in Crafting.RECIPES:
		if recipe["inputs"].has("Camiseta") and recipe["output"]["name"] == "Trapos":
			rag_recipe = recipe
			break
	check(not rag_recipe.is_empty(), "Shirt-to-rags recipe exists")
	check(Crafting.craft(rag_recipe, player.inventory), "Cutting rags from a shirt succeeds: " + Crafting.craft_error)
	check(worn_shirt.quantity == 1 and str(worn_shirt.get_meta("equipped_slot", "")) == "torso",
		"Worn shirt is not consumed while a spare exists")
	check(not player.inventory.items.has(spare_shirt), "Spare shirt is the one turned into rags")
	var rag_count := 0
	for item in player.inventory.items:
		if item.item_name == "Trapos":
			rag_count += item.quantity
	check(rag_count == 2, "Shirt recipe yields 2 rags")
	check(knife.durability < 100.0, "Knife loses durability crafting rags")

	# --- Venda fits in clothing pockets even with the outfit on and pockets full.
	_reset_player(player)
	var torso_item = _worn(player, "Camiseta", "torso")
	var legs_item = _worn(player, "Pantalones", "legs")
	var feet_item = _worn(player, "Zapatillas", "feet")
	# Fill the trouser pockets exactly; the shirt/legs compartments stay free.
	for i in range(3):
		_stored(player, "Piedra", "resource", 0.2, 1, "pockets")
	var trapos = _stored(player, "Trapos", "resource", 0.05, 3)
	player.refresh_carry_capacity()
	check(player.inventory.max_slots == player.BASE_CARRY_SLOTS + player.TORSO_CARRY_SLOTS + player.LEGS_CARRY_SLOTS,
		"Capacity comes from base + torso + legs clothing")
	check(player.inventory.get_stored_count() == 4, "Worn clothes do not count as stored cargo")
	var venda_recipe := _venda_recipe()
	check(not venda_recipe.is_empty(), "Venda recipe exists")
	check(Crafting.craft(venda_recipe, player.inventory), "Venda crafts with free clothing pockets: " + Crafting.craft_error)
	var venda = null
	for item in player.inventory.items:
		if item.item_name == "Venda":
			venda = item
	check(venda != null and venda.quantity == 1, "Venda output lands in the inventory")
	check(not player.inventory.items.has(trapos), "3 Trapos are consumed by the recipe")
	check(torso_item.quantity == 1 and legs_item.quantity == 1 and feet_item.quantity == 1,
		"Worn outfit survives crafting untouched")
	check(str(torso_item.get_meta("equipped_slot", "")) == "torso" and str(legs_item.get_meta("equipped_slot", "")) == "legs"
		and str(feet_item.get_meta("equipped_slot", "")) == "feet", "Equipped metas stay intact after craft")
	var containers := Cargo.compartments(player)
	var groups := Cargo.arrange(player.inventory.items, containers)
	check(venda != null and venda.cargo_location == "torso",
		"Venda overflows pockets into the shirt compartment, not SIN ESPACIO")

	# --- A genuinely full inventory still rejects the craft.
	venda.stack_separated = true  # force a new slot instead of merging
	_stored(player, "Trapos", "resource", 0.05, 5)
	for i in range(2):
		_stored(player, "Piedra", "resource", 0.2, 1, "pockets")
	player.refresh_carry_capacity()
	check(player.inventory.get_stored_count() == player.inventory.max_slots,
		"Inventory reaches real capacity before the rejection check")
	check(not Crafting.craft(venda_recipe, player.inventory), "Full inventory rejects the Venda craft")
	check(Crafting.craft_error.contains("espacio") or Crafting.craft_error.contains("peso"),
		"Rejection reports space or weight: " + Crafting.craft_error)
	var trapos_left := 0
	for item in player.inventory.items:
		if item.item_name == "Trapos":
			trapos_left += item.quantity
	check(trapos_left == 5, "Rejected craft consumes no materials")

	print("CraftingCapacityRegression: %d failures" % failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
