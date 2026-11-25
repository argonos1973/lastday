extends SceneTree

const Crafting = preload("res://scripts/CraftingSystem.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")
const BotFixtures = preload("res://tools/debug/BotPlanReliabilityRegression.gd")
const Bots = preload("res://scripts/SurvivorBotManager.gd")

class PeltPuppet extends PlayerController:
	func _create_body() -> void: pass
	func _capture_mouse() -> void: pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var pelts := ["Piel de ciervo", "Piel de zorro", "Piel de lobo", "Piel de lobo negro", "Piel de oso", "Piel de ave"]
	for pelt_name in pelts:
		var recipes := Crafting.get_recipes_for_item(pelt_name, "resource")
		check(not recipes.is_empty(), "%s must unlock pelt recipes" % pelt_name)
	var outputs := {
		"Chaqueta de piel": {"Piel de oso": 4},
		"Pantalones de piel": {"Piel de ciervo": 3},
		"Botas de piel": {"Piel de zorro": 2},
		"Guantes de piel": {"Piel de lobo negro": 1},
		"Gorro de piel": {"Piel de ave": 2, "Trapos": 1},
		"Tocado de piel animal": {"Piel de lobo negro": 3},
	}
	var expected_species := {
		"Chaqueta de piel": "oso",
		"Pantalones de piel": "ciervo",
		"Botas de piel": "zorro",
		"Guantes de piel": "lobo negro",
		"Gorro de piel": "ave",
		"Tocado de piel animal": "lobo negro",
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
	# --- Supervivencia primitiva de largo plazo (sin balas ni cuchillos industriales) ---
	var prim_inv = InventoryScript.new()
	prim_inv.max_slots = 30
	prim_inv.max_weight = 50.0
	prim_inv.add_item(ItemScript.create("Piedra", "resource", 0.45, 2, 0.0))
	var flake_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Piedra afilada":
			flake_recipe = candidate
			break
	check(Crafting.craft(flake_recipe, prim_inv) and prim_inv.has_item_name("Piedra afilada"), "2 Piedras craft Piedra afilada without any metal knife")
	# Piedra afilada substitutes for Cuchillo in pelt/bow/arrow recipes
	prim_inv.add_item(ItemScript.create("Piel de lobo", "resource", 0.65, 1, 0.0))
	var gloves_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Guantes de piel":
			gloves_recipe = candidate
			break
	check(Crafting.craft(gloves_recipe, prim_inv) and prim_inv.has_item_name("Guantes de piel"), "Piedra afilada substitutes for Cuchillo in pelt recipes")
	# Tendón crafts into Cuerda, then Arco reforzado + Flecha de hueso
	prim_inv.add_item(ItemScript.create("Tendón", "resource", 0.06, 3, 0.0))
	var sinew_cord_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Cuerda" and candidate.inputs.has("Tendón"):
			sinew_cord_recipe = candidate
			break
	check(Crafting.craft(sinew_cord_recipe, prim_inv) and prim_inv.has_item_name("Cuerda"), "Tendón crafts into Cuerda")
	prim_inv.add_item(ItemScript.create("Palo", "resource", 0.15, 3, 0.0))
	prim_inv.add_item(ItemScript.create("Hueso", "resource", 0.18, 2, 0.0))
	prim_inv.add_item(ItemScript.create("Pluma", "resource", 0.02, 2, 0.0))
	var bow_recipe: Dictionary = {}
	var arrow_recipe: Dictionary = {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Arco reforzado":
			bow_recipe = candidate
		elif str(candidate.output.name) == "Flecha de hueso":
			arrow_recipe = candidate
	check(Crafting.craft(bow_recipe, prim_inv) and prim_inv.has_item_name("Arco reforzado"), "Arco reforzado crafts from Palo + Tendón + Hueso")
	check(Crafting.craft(arrow_recipe, prim_inv) and prim_inv.has_item_name("Flecha de hueso", 3), "Flecha de hueso crafts x3 from Palo + Hueso + Pluma")
	prim_inv.free()
	# Blender-authored GLBs for bows, arrows and bow shoot/aim animations load cleanly
	for glb_p in [
		"res://assets/models/weapons/wooden_bow.glb",
		"res://assets/models/weapons/reinforced_bow.glb",
		"res://assets/models/weapons/arrow_wood.glb",
		"res://assets/models/weapons/arrow_stone.glb",
		"res://assets/models/weapons/arrow_bone.glb",
		"res://assets/animations/BowShoot.glb",
		"res://assets/animations/BowAimIdle.glb",
	]:
		var sc = load(glb_p)
		check(sc is PackedScene, "%s loads as PackedScene" % glb_p)
		if sc is PackedScene and glb_p.contains("Bow"):
			var inst: Node = (sc as PackedScene).instantiate()
			var ap_list := inst.find_children("*", "AnimationPlayer", true, false)
			check(not ap_list.is_empty() and (ap_list[0] as AnimationPlayer).get_animation_list().size() > 0, "%s contains an exported animation clip" % glb_p)
			inst.free()
	test_bot_pelts()
	if failures == 0:
		print("PASS: pelts from all animal types unlock recipes and craft wearable gear")
	quit(1 if failures else 0)

func reset_bot(b: Dictionary, clothing: String, materials: Array) -> void:
	b["clothing"] = clothing
	b["backpack"] = "Mochila militar"
	b["shelter_id"] = "pelt_test_camp"
	b["_craft_state"] = {}
	b["_craft_check"] = 0.0
	b["_want_cache"] = {}
	var proxy: Node3D = b["proxy"]
	proxy.set_meta("saved_inventory", materials.duplicate(true))
	proxy.set_meta("saved_extra", {})
	proxy.set_meta("saved_clothing", clothing)
	proxy.set_meta("loot_dropped", false)

func materials_for(species: String, count: int, tool: String = "Cuchillo", durability: float = 80.0) -> Array:
	return [{"name": "Piel de " + species, "type": "resource", "weight": .65, "quantity": count},
		{"name": tool, "type": "weapon", "weight": .2, "quantity": 1, "durability": durability, "max_durability": 80.0}]

func test_dry_change(manager: Bots, world: BotFixtures.TestWorld) -> void:
	var a: Dictionary = manager.bots[901]
	var control: Dictionary = manager.bots[902]
	var jacket := "Chaqueta militar"
	world.water_rect = Rect2(20, 20, 4, 4)
	for actor in [a, control]:
		reset_bot(actor, jacket, [])
		actor.proxy.global_position = Vector3(22, 0.4, 22)
		manager._bot_survival_tick(actor, 2.0)
		check(actor.proxy.get_meta("saved_extra").worn_clothing[jacket].wetness > 0.95, "Immersion soaks the worn jacket")
		actor.proxy.global_position = Vector3(28, 0.4, 22)
		actor.vstats.body_temperature = 36.0
	var dry := {"id":"dry_change", "name":jacket, "type":"clothing", "weight":0.6, "qty":1, "pos":[28,0.4,22]}
	var soaked := dry.duplicate(true)
	soaked.merge({"id":"wet_change", "wetness":1.0}, true)
	world._dropped_items.append(soaked)
	world._dropped_items.append(dry)
	check(manager._find_nearby_valuable_loot(a, 10.0).get("id") == "dry_change", "A soaked bot seeks the dry copy, not the soaked one")
	manager._tick_loot_pickup(a, dry, 0.1)
	check(a.proxy.get_meta("saved_extra").worn_clothing[jacket].wetness > 0.95, "No change before pickup completes")
	manager._tick_loot_pickup(a, dry, 1.4)
	manager._auto_equip_best_gear(a)
	var spares: Array = a.proxy.get_meta("saved_inventory")
	check(spares.size() == 1 and spares[0].get("wetness", 0.0) > 0.95, "The replaced jacket stays soaked in inventory without swapping back")
	for actor in [a, control]:
		manager._bot_survival_tick(actor, 1.0)
	check(a.vstats.wetness < control.vstats.wetness and a.vstats.wetness > 0.5, "Only the covered torso dries on changing")
	check(a.vstats.warmth_bonus > control.vstats.warmth_bonus and a.vstats.body_temperature > control.vstats.body_temperature, "Dry jacket provides more insulation and reduces actual cooling")
	world.campfire_positions.append(control.proxy.global_position + Vector3.RIGHT * 1.2)
	var before: float = control.proxy.get_meta("saved_extra").worn_clothing[jacket].wetness
	manager._bot_survival_tick(control, 4.0)
	check(control.proxy.get_meta("saved_extra").worn_clothing[jacket].wetness < before - 0.12, "A nearby fire dries the actual garment")
	world.campfire_positions.clear()
	world._built_shelters.append({"id":"dry_stash", "pos":[28,0.4,22], "contents":[{"name":jacket, "type":"clothing", "quantity":1, "weight":0.6}]})
	control.shelter_id = "dry_stash"
	check(manager._own_shelter_has_needed_item(control), "A dry replacement in the bot's own stash is needed")
	manager._bot_sync_own_shelter_stash(control)
	check(float(control.proxy.get_meta("saved_extra").worn_clothing[jacket].get("wetness", 0.0)) < 0.1, "The bot wears the withdrawn jacket rather than immediately re-stashing it")
	world._built_shelters.pop_back()
	world._dropped_items.clear()
	world.water_rect = Rect2(100000, 100000, 4, 4)

func test_bot_pelts() -> void:
	var world := BotFixtures.TestWorld.new()
	root.add_child(world)
	current_scene = world
	var net := BotFixtures.FakeNet.new()
	net.is_dedicated_server = true
	world.add_child(net)
	world.net = net
	world.day_cycle = BotFixtures.FakeDayCycle.new()
	world.add_child(world.day_cycle)
	var manager := Bots.new()
	world.add_child(manager)
	manager.world = world
	world.survivor_bot_mgr = manager
	# Spawn real bot state without loading/saving the user's AI memory.
	manager.spawn_all_bots()
	test_dry_change(manager, world)
	var outfit := ["Chaqueta de piel", "Pantalones de piel", "Botas de piel", "Guantes de piel"]
	var recipes := {}
	for recipe in Crafting.RECIPES:
		if recipe.inputs.has("ANY_PELT"):
			recipes[str(recipe.output.name)] = recipe
	var species_list := ["lobo", "lobo negro", "ciervo", "zorro", "oso", "ave"]
	for i in species_list.size():
		var species: String = species_list[i]
		var b: Dictionary = manager.bots[901 + i % 4]
		reset_bot(b, "Camiseta,Pantalones,Zapatillas", materials_for(species, 13))
		var head := "Gorro de piel" if species == "ave" else "Tocado de piel animal"
		var expected: Array = outfit + [head]
		for tick in 100:
			if expected.all(func(nm): return nm in str(b["clothing"]).split(",")):
				break
			manager._bot_try_craft(b, 3.0)
		var worn: Dictionary = b["proxy"].get_meta("saved_extra", {}).get("worn_clothing", {})
		for nm in expected:
			check(nm in str(b["clothing"]).split(","), "%s autonomously crafts and wears %s from %s" % [b.name, nm, species])
			var entry: Dictionary = worn.get(nm, {})
			check(str(entry.get("pelt_species", "")) == species, "%s worn %s keeps %s" % [b.name, nm, species])
			check(float(entry.get("durability", 0.0)) == 300.0, "worn %s retains crafted durability" % nm)
			var saved: Dictionary = JSON.parse_string(JSON.stringify(entry))
			var item = ItemScript.from_dict(saved)
			check(str(item.get_meta("pelt_species", "")) == species, "serialized worn %s retains species" % nm)
		var payload := str(net.players[int(b.bot_id)].equipped_clothing)
		check(payload == str(b["proxy"].get_meta("saved_clothing", "")), "network and saved outfit agree")
		check(payload.contains(head + "|" + species), "remote headdress receives actual species")
		if species != "ave":
			check(not manager._bot_wants_pelts(b, b.proxy), "complete %s outfit stops gathering pelts" % species)
			check(manager._bot_pelt_count(b.proxy) == 0, "full mammal outfit consumes exactly thirteen hides")
		else:
			check(manager._bot_recipe_score(b, recipes["Tocado de piel animal"]) <= 0.0 \
				or manager._bot_pelt_count(b.proxy) == 0, "bird cap is not endlessly recrafted")
			check(not manager._bot_wants_pelts(b, b.proxy, "Piel de ave"), "finished bird outfit does not hoard more bird skins")
			check(manager._bot_wants_pelts(b, b.proxy, "Piel de lobo negro"), "animal hides can still upgrade a bird cap")
		if species == "lobo negro":
			var avatar := PeltPuppet.new()
			avatar.is_puppet = true
			world.add_child(avatar)
			avatar.setup_as_puppet()
			avatar.set_process(false)
			avatar.set_physics_process(false)
			avatar.puppet_apply_visuals(payload, "", "")
			for nm in expected:
				check(str(avatar._equipped_pelt.get(nm, "")) == species, "puppet equips black " + nm)
			avatar.free()
	var bot: Dictionary = manager.bots[901]
	var rest := "Chaqueta de piel,Pantalones de piel,Botas de piel,Tocado de piel animal"
	reset_bot(bot, rest, materials_for("lobo negro", 1, "Piedra afilada"))
	check(manager._bot_try_craft(bot, .1), "one hide and primitive blade start glove crafting")
	manager._bot_try_craft(bot, 3.0)
	check("Guantes de piel" in str(bot.clothing).split(","), "one-hide gloves are actually worn")
	check(manager._bot_pelt_count(bot.proxy) == 0, "gloves consume only one hide")
	var headless_outfit := ",".join(outfit)
	reset_bot(bot, headless_outfit, materials_for("lobo", 3, "Cuchillo", 0.0))
	check(not manager._bot_try_craft(bot, .1), "broken knife cannot craft a headdress")
	check(manager._bot_pelt_count(bot.proxy) == 3, "rejected craft preserves hides")
	reset_bot(bot, headless_outfit, materials_for("lobo", 3))
	check(manager._bot_try_craft(bot, .1), "headdress work starts with valid materials")
	var remaining := materials_for("lobo", 2)
	bot.proxy.set_meta("saved_inventory", remaining)
	manager._bot_try_craft(bot, 3.0)
	check(not str(bot.clothing).contains("Tocado") and manager._bot_pelt_count(bot.proxy) == 2 \
		and float(remaining[1].durability) == 80.0, "lost input during interruption aborts without consuming/creating items")
	reset_bot(bot, headless_outfit + ",Casco militar", materials_for("lobo", 3))
	check(manager._bot_recipe_score(bot, recipes["Tocado de piel animal"]) > 0.0, "animal trophy outranks the military helmet")
	check(manager._bot_try_craft(bot, 0.5), "trophy craft starts over the helmet")
	manager._bot_try_craft(bot, 3.0)
	check(str(bot.clothing).contains("Tocado de piel animal") and not str(bot.clothing).contains("Casco militar"),
		"the sewn trophy actually replaces the helmet on the head")
	# A bird cap must not burn three hides on another downgraded cap.
	reset_bot(bot, headless_outfit + ",Gorro de piel", materials_for("ave", 3))
	check(not manager._bot_try_craft(bot, .1), "bird skins cannot repeatedly downgrade the headdress recipe")
	var inventory: Array = bot.proxy.get_meta("saved_inventory", [])
	inventory.append({"name": "Piel de lobo negro", "type": "resource", "weight": .65, "quantity": 3})
	bot["_craft_check"] = 0.0
	bot.proxy.set_meta("saved_extra", {"worn_clothing": {"Gorro de piel": {"name": "Gorro de piel", "type": "clothing", "quantity": 1, "weight": .35, "durability": 177.0, "max_durability": 300.0, "pelt_species": "ave"}}})
	check(manager._bot_try_craft(bot, .1), "available animal hides upgrade bird cap")
	manager._bot_try_craft(bot, 3.0)
	check(str(bot.proxy.get_meta("saved_clothing", "")).contains("Tocado de piel animal|lobo negro"), "trophy crafting selects mammal hides before stored bird hides")
	var old_cap: Dictionary = {}
	for it in bot.proxy.get_meta("saved_inventory", []):
		if str(it.get("name", "")) == "Gorro de piel": old_cap = it
	check(str(old_cap.get("pelt_species", "")) == "ave" and float(old_cap.get("durability", 0.0)) == 177.0, "replaced cap retains original species and condition")
	# Overflow/dropped crafted gear remains the same item through pickup.
	manager._bot_drop_to_ground(bot, old_cap)
	var dropped: Dictionary = world._dropped_items.back()
	check(str(dropped.get("pelt", "")) == "ave", "bot's dropped garment preserves hide in world record")
	var action = world.world_actions_by_id.get(str(dropped.get("id", "")))
	check(is_instance_valid(action) and str(action.get_meta("item_pelt", "")) == "ave", "dropped garment exposes species to human pickup")
	var picked := manager._loot_entry_item_dict(dropped)
	check(str(picked.get("pelt_species", "")) == "ave" and float(picked.get("durability", 0.0)) == 177.0, "bot re-pickup keeps species and condition")
	# Death drops both the worn trophy and a separate same-name spare.
	var spare := {"name": "Tocado de piel animal", "type": "clothing", "weight": .7, "quantity": 1, "pelt_species": "zorro", "durability": 111.0, "max_durability": 300.0}
	bot["clothing"] = "Tocado de piel animal"
	bot.proxy.set_meta("saved_clothing", manager._bot_clothing_sync(bot))
	bot.proxy.set_meta("saved_inventory", [spare])
	bot.proxy.set_meta("saved_backpack", "")
	net.players[int(bot.bot_id)]["equipped_backpack"] = ""
	var before := world._dropped_items.size()
	world._drop_player_loot(int(bot.bot_id), bot.proxy)
	var trophies := {}
	for entry in world._dropped_items.slice(before):
		check(not str(entry.get("name", "")).contains("|"), "death labels never become invalid item names")
		if str(entry.get("name", "")) == "Tocado de piel animal":
			trophies[str(entry.get("pelt", ""))] = float(entry.get("durability", 0.0))
	check(trophies.get("lobo negro", 0.0) == 300.0 and trophies.get("zorro", 0.0) == 111.0 \
		and trophies.size() == 2, "death preserves worn and spare trophies without loss or duplication")
	world._drop_player_loot(int(bot.bot_id), bot.proxy)
	check(world._dropped_items.size() == before + 2, "repeated death callback cannot duplicate equipment")
	# No temporary backpack slot is needed when the result goes onto the body.
	reset_bot(bot, headless_outfit, materials_for("lobo negro", 4))
	bot["backpack"] = ""
	var full: Array = bot.proxy.get_meta("saved_inventory", [])
	var capacity := manager._bot_carry_capacity(bot)
	for i in range(int(capacity.slots) - full.size()):
		full.append({"name": "Fixture_%d" % i, "type": "misc", "weight": .01, "quantity": 1})
	check(not manager._bot_would_fit(bot, full, recipes["Tocado de piel animal"].output), "fixture backpack really has no free slot")
	check(manager._bot_try_craft(bot, .1), "full backpack still allows sewing wearable upgrade")
	manager._bot_try_craft(bot, 3.0)
	check(str(bot.clothing).contains("Tocado de piel animal") and manager._bot_pelt_count(bot.proxy) == 1, "full-pack headdress equips and consumes three of four hides")
	check(manager._bot_inv_stored_count(bot.proxy.get_meta("saved_inventory", [])) <= int(capacity.slots), "directly worn craft does not overfill inventory")
	# Frío: la piel cosida es equipo de supervivencia — con el cuerpo frío o
	# de noche el abrigo gana a las faenas rutinarias, y sin filo la lasca
	# de piedra es el paso que falta para poder coserla.
	reset_bot(bot, "Camiseta,Pantalones,Zapatillas", materials_for("lobo", 13))
	bot.vstats.body_temperature = 35.9
	check(manager._bot_feels_cold(bot), "cuerpo frío se lee como frío")
	check(manager._bot_recipe_score(bot, recipes["Chaqueta de piel"]) >= 6.9,
		"un bot helado cose la chaqueta por encima de las faenas rutinarias")
	bot.vstats.body_temperature = 37.2
	check(manager._bot_recipe_score(bot, recipes["Chaqueta de piel"]) < 5.0,
		"el mismo abrigo vuelve a ser faena ordinaria con el cuerpo templado")
	check(not manager._bot_feels_cold(bot), "un día cálido no es frío")
	world.day_cycle.time_of_day = 17.0
	check(manager._bot_feels_cold(bot), "el ocaso frío se anticipa aunque el cuerpo siga templado")
	world.day_cycle.time_of_day = 14.0
	# Pieles sin filo: primero la lasca que habilita el cosido, luego el abrigo.
	reset_bot(bot, "Camiseta,Pantalones,Zapatillas",
		[{"name": "Piel de lobo", "type": "resource", "weight": .65, "quantity": 4},
			{"name": "Piedra", "type": "resource", "weight": .45, "quantity": 2}])
	bot.vstats.body_temperature = 35.9
	var flake_recipe := {}
	for candidate in Crafting.RECIPES:
		if str(candidate.output.name) == "Piedra afilada":
			flake_recipe = candidate
	check(manager._bot_recipe_score(bot, flake_recipe) > 6.0, "pieles sin filo y frío potencian la lasca")
	check(manager._bot_try_craft(bot, 0.5), "el bot frío empieza a tallar la lasca")
	manager._bot_try_craft(bot, 3.0)
	check(manager._bot_has_can_opener(bot.proxy), "la lasca da el filo que faltaba")
	check(manager._bot_try_craft(bot, 0.5), "con filo empieza a coser la chaqueta")
	manager._bot_try_craft(bot, 3.0)
	check("Chaqueta de piel" in str(bot.clothing).split(","), "las pieles frías terminan vestidas")
	# Helado pero vivo: una piel a los pies se recoge aunque no sea comida.
	reset_bot(bot, "Camiseta,Pantalones,Zapatillas", materials_for("lobo", 5))
	bot.vstats.body_temperature = 35.5
	var pelt_drop := {"name": "Piel de ciervo", "type": "resource",
		"pos": [bot.proxy.global_position.x, bot.proxy.global_position.y, bot.proxy.global_position.z + 3.0]}
	check(manager._bot_loot_allowed_while_freezing(bot, pelt_drop, false),
		"un bot que se congela recoge la piel que tiene a los pies")
	bot.vstats.body_temperature = 37.2
	world.free()
	print("BOT_PELT_CRAFT failures=", failures)
