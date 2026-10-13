extends SceneTree

const Crafting = preload("res://scripts/CraftingSystem.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var pelts := ["Piel de ciervo", "Piel de zorro", "Piel de lobo", "Piel de oso", "Piel de ave"]
	for pelt_name in pelts:
		var recipes := Crafting.get_recipes_for_item(pelt_name, "resource")
		check(not recipes.is_empty(), "%s must unlock pelt recipes" % pelt_name)
	var outputs := {
		"Chaqueta de piel": {"Piel de oso": 4},
		"Botas de piel": {"Piel de zorro": 2},
		"Gorro de piel": {"Piel de ave": 2, "Trapos": 1},
		"Tocado de piel animal": {"Piel de lobo": 3, "Cuerda": 1},
	}
	for output_name in outputs:
		var inventory = InventoryScript.new()
		for ingredient in outputs[output_name]:
			var type := "resource"
			if ingredient == "Cuerda" or ingredient == "Trapos":
				type = "resource"
			inventory.add_item(ItemScript.create(ingredient, type, 0.1, outputs[output_name][ingredient], 0.0))
		inventory.add_item(ItemScript.create("Cuchillo", "weapon", 0.2, 1, 0.0))
		var recipe: Dictionary = {}
		for candidate in Crafting.RECIPES:
			if str(candidate.output.name) == output_name:
				recipe = candidate
				break
		check(not recipe.is_empty(), "Recipe exists for %s" % output_name)
		if recipe.is_empty():
			inventory.free()
			continue
		check(Crafting.craft(recipe, inventory), "%s crafts from animal hides" % output_name)
		check(inventory.has_item_name(output_name), "Crafted %s is usable clothing" % output_name)
		for ingredient in outputs[output_name]:
			if str(ingredient).begins_with("Piel de "):
				check(not inventory.has_item_name(ingredient), "Crafting consumes %s" % ingredient)
		inventory.free()
	if failures == 0:
		print("PASS: pelts from all animal types unlock recipes and craft wearable gear")
	quit(1 if failures else 0)
