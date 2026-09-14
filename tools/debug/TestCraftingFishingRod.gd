extends SceneTree

const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")

func _initialize() -> void:
	call_deferred("run")

func _add(inv, name: String, type: String, quantity: int = 1) -> void:
	assert(inv.add_item(ItemScript.create(name, type, 0.1, quantity, 0.0)))

func run() -> void:
	var inv = InventoryScript.new()
	_add(inv, "Trapos", "resource", 2)
	var rope_recipe: Dictionary
	for recipe in Crafting.RECIPES:
		if recipe.inputs == {"Trapos": 2}:
			rope_recipe = recipe
	assert(not rope_recipe.is_empty())
	assert(Crafting.craft(rope_recipe, inv))
	assert(inv.has_item_name("Cuerda") and not inv.has_item_name("Trapos"))
	_add(inv, "Palo afilado", "tool_spear")
	var rod_recipe: Dictionary
	for recipe in Crafting.RECIPES:
		if recipe.inputs == {"Palo afilado": 1, "Cuerda": 1}:
			rod_recipe = recipe
	assert(Crafting.craft(rod_recipe, inv))
	var rod = inv.items[0]
	assert(rod.item_name == "Caña de pescar")
	assert(is_equal_approx(rod.durability, 3.0) and is_equal_approx(rod.max_durability, 3.0))
	var simple_recipe: Dictionary
	for recipe in Crafting.RECIPES:
		if recipe.inputs == {"Palo": 1, "Cuerda": 1}:
			simple_recipe = recipe
	assert(not simple_recipe.is_empty())
	var simple_inv = InventoryScript.new()
	_add(simple_inv, "Palo", "resource")
	_add(simple_inv, "Cuerda", "resource")
	assert(Crafting.craft(simple_recipe, simple_inv))
	var simple = simple_inv.items[0]
	assert(simple.item_name == "Caña simple" and is_equal_approx(simple.max_durability, 100.0))
	for uses in [2, 1, 0]:
		rod.reduce_durability(1.0)
		assert(is_equal_approx(rod.durability, float(uses)))
	print("PASS: 2 trapos -> cuerda; cuerda + palo afilado -> caña de 3 usos")
	inv.free()
	simple_inv.free()
	quit()
