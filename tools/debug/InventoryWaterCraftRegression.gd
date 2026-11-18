extends SceneTree

const ItemData = preload("res://scripts/Item.gd")
const InventoryData = preload("res://scripts/Inventory.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")
var failures := 0
var checks := 0

class TestWorld extends "res://scripts/Main.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass

class Actor extends "res://scripts/PlayerController.gd":
	var crafted_count := 0
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _sync_held_item():
		if hands != null:
			hands.current_item = get_held_item()
	func play_action_animation(_action: String, _duration := 1.1): pass
	func _play_consumption_audio(_drink: bool, _duration: float, _serial: int): pass
	func _play_bottle_fill_audio(_duration: float, _serial: int): pass
	func _stop_consumption_audio(): pass
	func _post_craft_success(_recipe: Dictionary, _out: Dictionary):
		crafted_count += 1

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func recipe_named(name: String) -> Dictionary:
	for recipe in Crafting.RECIPES:
		if recipe.output.name == name:
			return recipe
	return {}

func _initialize(): call_deferred("run")

func run():
	var inv := InventoryData.new()
	# Refill the actual selected bottle, keeping its identity and payload.
	var spare = ItemData.create("Botella de plastico", "resource", 0.05)
	var held = ItemData.create("Botella de plastico", "resource", 0.05)
	held.cargo_location = "backpack"
	held.wetness = 0.6
	inv.items = [spare, held]
	inv.max_slots = 2
	var changed := [0]
	inv.changed.connect(func(): changed[0] += 1)
	check(inv.refill_water_bottle(held) == held, "Refilling a single bottle preserves its reference")
	check(spare.item_name == "Botella de plastico", "Earlier spare bottle remains empty")
	check(held.item_name == "Botella de agua llena" and held.durability == 100.0, "Selected bottle fills with no free slot")
	check(held.cargo_location == "backpack" and held.wetness == 0.6, "Refill preserves compartment and wetness")
	check(changed[0] == 1, "Refill emits a single committed change")
	check(inv.refill_water_bottle(ItemData.create("Botella de plastico", "resource", 0.05)) == null, "A removed bottle cannot be refilled")
	inv.items = [spare]
	inv.max_weight = 0.2
	check(inv.refill_water_bottle(spare) == null, "Overweight refill is rejected")
	check(spare.item_name == "Botella de plastico" and spare.quantity == 1 and inv.items.size() == 1, "Rejected refill loses no bottle")
	inv.max_weight = 18.0
	spare.quantity = 3
	inv.max_slots = 1
	check(inv.refill_water_bottle(spare) == null and spare.quantity == 3, "Full cargo rejects a split without consuming a bottle")
	inv.max_slots = 2
	var filled = inv.refill_water_bottle(spare)
	check(filled != null and filled.quantity == 1 and spare.quantity == 2, "Only one bottle from a stack fills")
	check(spare.item_name == "Botella de plastico", "Remaining stacked bottles stay empty")
	filled.durability = 0.0
	check(inv.refill_water_bottle(filled) == filled and filled.durability == 100.0, "An exhausted water bottle can be refilled")
	inv.free()

	# Sharp stones become knife blades; substitutes still work as reusable tools.
	inv = InventoryData.new()
	var sharp = ItemData.create("Piedra afilada", "resource", 0.25)
	var stick = ItemData.create("Palo", "resource", 0.15)
	var sinew = ItemData.create("Tendón", "resource", 0.1)
	inv.items = [stick, sharp, sinew]
	check(Crafting.craft(recipe_named("Cuchillo de piedra"), inv), "Knife crafts with sinew instead of rope")
	check(not inv.items.has(sharp) and not inv.items.has(sinew) and not inv.items.has(stick), "Knife consumes blade, stick and binding")
	check(inv.get_item_count("Cuchillo de piedra") == 1, "One knife is produced")
	var ground := []
	for item in [stick, sharp, sinew]:
		var entry: Dictionary = item.to_dict()
		entry["action"] = null
		ground.append(entry)
	var plan := Crafting.plan_ground_craft(recipe_named("Cuchillo de piedra"), [], ground)
	check(not plan.is_empty(), "Same knife recipe plans from ground ingredients")
	for source in plan.sources:
		check(source.quantity == 0, "Ground knife consumes every ingredient: " + source.item.item_name)
	var tool = ItemData.create("Piedra afilada", "resource", 0.25)
	var wood = ItemData.create("Palo", "resource", 0.15)
	var entry: Dictionary = wood.to_dict()
	entry["action"] = null
	plan = Crafting.plan_ground_craft(recipe_named("Palo afilado"), [tool], [entry])
	var ground_wear := -1.0
	for source in plan.sources:
		if source.item == tool:
			ground_wear = source.durability
	check(tool.durability == 100.0, "Planning never wears the live tool")
	inv.items = [wood, tool]
	check(Crafting.craft(recipe_named("Palo afilado"), inv), "Sharp stone still substitutes for a knife")
	check(inv.items.has(tool) and tool.quantity == 1, "Cutting tool remains reusable")
	check(is_equal_approx(tool.durability, ground_wear), "Ground and inventory crafting apply identical tool wear")
	check(not Crafting.get_recipe_inputs_text(recipe_named("Cuchillo de piedra")).contains("no se gasta"), "Recipe describes the blade as a consumed ingredient")
	inv.free()

	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var actor := Actor.new()
	world.add_child(actor)
	actor.inventory = InventoryData.new()
	actor.add_child(actor.inventory)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.stats.set_process(false)
	actor.hands = preload("res://scripts/PlayerHands.gd").new()
	actor.add_child(actor.hands)
	var fountain = world._create_world_action("test_fountain", "drink_water", "Fuente", Vector3(0, 0.9, 0), Vector3(4.6, 1.7, 4.6), Color.TRANSPARENT, true, false)
	fountain.set_meta("water_requires_facing", true)
	fountain.set_meta("water_reach", 2.8)
	actor.position = Vector3(0, 0, 2.3)
	actor.rotation.y = PI
	actor.stats.thirst = 20.0
	await world.handle_world_action(fountain, actor)
	check(world._drink_hold_actor == null, "Cannot start drinking with back to fountain")
	check(fountain.get_interaction_text(actor).contains("Mira"), "Prompt explains the facing requirement")
	actor.rotation.y = 0.0
	await world.handle_world_action(fountain, actor)
	check(world._drink_hold_actor == actor, "Drinking starts facing fountain")
	world._tick_drink_hold(1.0)
	check(actor.stats.thirst == 25.0, "Valid sip restores thirst")
	actor.rotation.y = PI
	world._tick_drink_hold(1.0)
	check(world._drink_hold_actor == null and actor.stats.thirst == 25.0, "Turning away stops drinking before another sip")
	actor.rotation.y = 0.0
	actor.position.z = 4.0
	await world.handle_world_action(fountain, actor)
	check(world._drink_hold_actor == null, "Cannot drink from beyond the basin's reach")
	actor.position.z = 2.3
	await world.handle_world_action(fountain, actor)
	actor.position.z = 4.0
	world._tick_drink_hold(1.0)
	check(world._drink_hold_actor == null and actor.stats.thirst == 25.0, "Moving out of reach cancels the channel")
	actor.position.z = 2.3
	await world.handle_world_action(fountain, actor)
	fountain.free()
	world._tick_drink_hold(1.0)
	check(world._drink_hold_actor == null, "Unloading the source cancels safely")
	fountain = world._create_world_action("fill_fountain", "drink_water", "Fuente", Vector3(0, 0.9, 0), Vector3(4.6, 1.7, 4.6), Color.TRANSPARENT, true, false)
	fountain.set_meta("water_requires_facing", true)
	fountain.set_meta("water_reach", 2.8)
	spare = ItemData.create("Botella de plastico", "resource", 0.05)
	actor.inventory.items = [spare]
	actor._select_held_item(0)
	world.handle_world_action(fountain, actor)
	await create_timer(0.15).timeout
	actor.rotation.y = PI
	await create_timer(0.2).timeout
	check(not actor._interact_busy and spare.item_name == "Botella de plastico", "Turning away cancels refill without consuming the bottle")
	actor.rotation.y = 0.0
	world.handle_world_action(fountain, actor)
	await create_timer(0.15).timeout
	actor.inventory.items.clear()
	await create_timer(0.2).timeout
	check(not actor._interact_busy and actor.inventory.items.is_empty(), "Removing the held bottle prevents refill duplication")
	var second = ItemData.create("Botella de plastico", "resource", 0.05)
	actor.inventory.items = [spare, second]
	actor.inventory.max_slots = 2
	actor._select_held_item(1)
	await world.handle_world_action(fountain, actor)
	check(actor.get_held_item() == second and second.item_name == "Botella de agua llena", "Completed refill keeps the correct bottle in the hand")
	check(spare.item_name == "Botella de plastico" and actor.inventory.items.size() == 2, "Refill leaves other bottles untouched without extra slots")
	second.durability = 0.0
	check(fountain.get_interaction_text(actor).contains("Llenar"), "An exhausted bottle still offers the refill prompt")
	actor.inventory.max_slots = 10
	var river = world._create_world_action("test_river", "drink_water", "Rio", Vector3.ZERO, Vector3(3, 0.5, 30), Color.TRANSPARENT, true, false)
	actor.position = Vector3(0, 0, 13)
	check(river.water_interaction_error(actor).is_empty(), "Long river regions use the bank bounds, not distance to center")
	actor.position = Vector3(9, 0, 13)
	check(not river.water_interaction_error(actor).is_empty(), "Cannot drink far outside a river's bounds")

	# Exercise the real delayed crafting entry point and cancellation.
	var knife = ItemData.create("Cuchillo", "weapon", 0.4)
	wood = ItemData.create("Palo", "resource", 0.15, 2)
	actor.inventory.items = [wood, knife]
	actor._held_item_reference = null
	actor.craft_recipe(recipe_named("Palo afilado"))
	check(wood.quantity == 2 and knife.durability == 100.0, "Starting craft neither consumes nor wears materials")
	actor.craft_recipe(recipe_named("Palo afilado"))
	actor.cancel_active_action()
	await create_timer(0.15).timeout
	check(wood.quantity == 2 and actor.crafted_count == 0, "Cancelled/repeated craft produces nothing")
	actor.craft_recipe(recipe_named("Palo afilado"))
	actor.inventory.items.erase(wood)
	await create_timer(2.2).timeout
	check(actor.crafted_count == 0 and knife.durability == 100.0, "Missing ingredients at completion cause no partial consumption")
	actor.inventory.items = [wood, knife]
	actor.craft_recipe(recipe_named("Palo afilado"))
	actor.craft_recipe(recipe_named("Palo afilado"))
	await create_timer(2.2).timeout
	check(actor.crafted_count == 1 and actor.inventory.get_item_count("Palo afilado") == 1, "Repeated craft request commits exactly one output")
	check(wood.quantity == 1 and knife.durability < 100.0, "Successful completion consumes and wears once")
	actor.is_dead = true
	actor.craft_recipe(recipe_named("Palo afilado"))
	check(not actor._local_action_pending, "Dead characters cannot start crafting")
	actor.is_dead = false
	var logs = ItemData.create("Tronco", "resource", 1.0, 2)
	wood = ItemData.create("Palo", "resource", 0.15)
	actor.inventory.items = [logs, wood]
	var drops := [0]
	actor.item_dropped.connect(func(_n, _t, _w, _q, _u, _p, _c, _b, _s): drops[0] += 1)
	actor._craft_campfire()
	actor._craft_campfire()
	actor.cancel_active_action()
	await create_timer(0.15).timeout
	check(logs.quantity == 2 and wood.quantity == 1 and drops[0] == 0, "Cancelled/repeated campfire keeps materials and creates nothing")
	await actor._craft_campfire()
	check(drops[0] == 1 and actor.inventory.items.is_empty(), "Completed campfire consumes exactly two logs and a stick")
	world.queue_free()
	await process_frame
	print("InventoryWaterCraftRegression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
