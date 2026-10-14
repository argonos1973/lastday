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
		"Tocado de piel animal": {"Piel de lobo": 3},
	}
	var expected_species := {
		"Chaqueta de piel": "oso",
		"Botas de piel": "zorro",
		"Gorro de piel": "ave",
		"Tocado de piel animal": "lobo",
	}
	for output_name in outputs:
		var inventory = InventoryScript.new()
		for ingredient in outputs[output_name]:
			var type := "resource"
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
		# The garment keeps the species of the hide it was sewn from
		var crafted = null
		for it in inventory.items:
			if str(it.item_name) == output_name:
				crafted = it
				break
		check(crafted != null and str(crafted.get_meta("pelt_species", "")) == expected_species[output_name],
			"%s keeps species %s in pelt_species (got %s)" % [output_name, expected_species[output_name], str(crafted.get_meta("pelt_species", "")) if crafted != null else "none"])
		# Species survives a save/load round-trip
		if crafted != null:
			var restored = ItemScript.from_dict(crafted.to_dict())
			check(str(restored.get_meta("pelt_species", "")) == expected_species[output_name],
				"%s species survives to_dict/from_dict" % output_name)
		inventory.free()
	# Mixed pelts: the dominant species wins the garment's hide
	var mixed = InventoryScript.new()
	mixed.add_item(ItemScript.create("Piel de ciervo", "resource", 0.1, 2, 0.0))
	mixed.add_item(ItemScript.create("Piel de oso", "resource", 0.1, 2, 0.0))
	mixed.add_item(ItemScript.create("Cuchillo", "weapon", 0.2, 1, 0.0))
	var jacket_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Chaqueta de piel":
			jacket_recipe = candidate
			break
	check(Crafting.craft(jacket_recipe, mixed), "mixed pelts craft the jacket")
	var mixed_species := ""
	for it in mixed.items:
		if str(it.item_name) == "Chaqueta de piel":
			mixed_species = str(it.get_meta("pelt_species", ""))
	check(mixed_species in ["ciervo", "oso"], "mixed pelts produce a real species, got '%s'" % mixed_species)
	mixed.free()
	# Bird pelts have no animal-head trophy: the tocado recipe downgrades to
	# the generic fur cap (still tagged "ave" for the feather texture).
	var bird = InventoryScript.new()
	bird.add_item(ItemScript.create("Piel de ave", "resource", 0.1, 3, 0.0))
	bird.add_item(ItemScript.create("Cuchillo", "weapon", 0.2, 1, 0.0))
	var tocado_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Tocado de piel animal":
			tocado_recipe = candidate
			break
	check(Crafting.craft(tocado_recipe, bird), "bird pelts still craft through the tocado recipe")
	check(not bird.has_item_name("Tocado de piel animal"), "bird pelts never produce an animal-head tocado")
	var bird_item = null
	for it in bird.items:
		if str(it.item_name) == "Gorro de piel":
			bird_item = it
	check(bird_item != null, "bird pelts produce Gorro de piel instead")
	if bird_item != null:
		check(str(bird_item.get_meta("pelt_species", "")) == "ave",
			"bird gorro keeps species ave (got %s)" % str(bird_item.get_meta("pelt_species", "")))
	bird.free()
	if failures == 0:
		print("PASS: pelts from all animal types unlock recipes and craft wearable gear")
	quit(1 if failures else 0)
