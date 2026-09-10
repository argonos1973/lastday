extends SceneTree

const Inv = preload("res://scripts/Inventory.gd")
const ItemData = preload("res://scripts/Item.gd")
const Craft = preload("res://scripts/CraftingSystem.gd")
const Stats = preload("res://scripts/SurvivalStats.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _process(_delta: float) -> void: pass
	func play_action_animation(_action_name: String, _duration := 1.1) -> void: pass
	func _sync_third_person_equipment(_held_item) -> void: pass
	func _update_crosshair(_is_rifle: bool) -> void: pass
	func _clear_third_person_drink_bottle_left_hand() -> void: pass
	func _build_third_person_drink_bottle_left_hand() -> void: pass

class TestAnimal extends "res://scripts/WildlifeController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _find_nearest_meat_pickup() -> Node3D: return null

var checks := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var animal := TestAnimal.new()
	root.add_child(animal)
	var stale := TestAnimal.new()
	animal._cached_wildlife = [stale]
	stale.free()
	check(animal._get_separation_vector() == Vector3.ZERO, "Freed animal separation")
	check(animal._find_nearest_prey() == null, "Freed prey ignored")
	check(animal._find_nearest_corpse() == null, "Freed corpse ignored")
	var pending := TestAnimal.new()
	root.add_child(pending)
	animal._cached_wildlife = [pending]
	pending.queue_free()
	check(animal._get_separation_vector() == Vector3.ZERO, "Queued animal ignored")
	animal.queue_free()

	var inv := Inv.new()
	root.add_child(inv)
	var worn = ItemData.create("Guantes", "clothing", 0.2, 2)
	worn.durability = 23
	worn.spoilage = 50
	worn.set_meta("clothing_color", Color.RED)
	inv.add_item(worn)
	var removed = inv.remove_index(0)
	check(removed.quantity == 1 and removed.durability == 23 and removed.spoilage == 50, "Removal preserves state")
	check(removed.get_meta("clothing_color") == Color.RED, "Removal preserves color")
	check(inv.remove_index(0, -2) == null and inv.items[0].quantity == 1, "Negative removal cannot duplicate")
	check(not inv.consume_item_name("Guantes", -1), "Negative consumption rejected")
	var other = worn.duplicate_stack()
	other.durability = 100
	check(not worn.can_stack_with(other), "Different durability stays separate")
	other.durability = worn.durability
	other.set_meta("clothing_color", Color.BLUE)
	check(not worn.can_stack_with(other), "Different colors stay separate")

	inv.items.clear()
	inv.add_item(ItemData.create("Palo", "material", 0.1, 2))
	inv.add_item(ItemData.create("Cuchillo", "tool", 0.1))
	var recipe := {"inputs": {"Palo": 2, "Cuchillo": 1}, "output": {"name": "Test", "type": "misc", "weight": 100.0, "use_value": 0.0}}
	var before := inv.to_array()
	var original = inv.items[0]
	check(not Craft.craft(recipe, inv), "Overweight craft rejected")
	check(inv.to_array() == before and inv.items[0] == original, "Failed craft preserves materials, tools and identities")
	recipe.output.weight = 0.1
	check(Craft.craft(recipe, inv), "Craft succeeds")
	check(inv.get_item_count("Palo") == 0 and inv.get_item_count("Test") == 1, "Craft consumes exact quantities")
	check(inv.items[0].durability == 97, "Successful craft wears tool once")
	inv.items[0].durability = 0
	inv.add_item(ItemData.create("Palo", "material", 0.1, 2))
	check(not Craft.craft(recipe, inv), "Broken tool rejected")
	inv.items.clear()
	inv.add_item(worn)
	other.quantity = 1
	inv.add_item(other)
	var clothing_recipe := {"inputs": {"ANY_CLOTHING": 3}, "output": {"name": "Tela", "type": "material", "weight": 100.0, "use_value": 0.0}}
	before = inv.to_array()
	check(not Craft.craft(clothing_recipe, inv) and before == inv.to_array(), "Failed clothing craft preserves all stacks and metadata")
	clothing_recipe.output.weight = 0.1
	check(Craft.craft(clothing_recipe, inv) and inv.items.size() == 1, "Clothing consumption traverses all stacks")

	var player := TestPlayer.new()
	root.add_child(player)
	player.inventory = inv
	player.stats = Stats.new()
	player.add_child(player.stats)
	inv.items.clear()
	inv.add_item(ItemData.create("Palo", "material", 0.1))
	inv.add_item(ItemData.create("Cuchillo", "weapon", 0.1))
	player._select_held_item(1)
	var selected = player.get_held_item()
	inv.changed.connect(player._on_inventory_changed)
	inv.swap_items(0, 1)
	check(player.get_held_item() == selected and player.held_index == 0, "Held object survives reordering")
	inv.swap_items(0, 1)
	inv.remove_index(0)
	check(player.get_held_item() == selected, "Held object survives removing earlier slot")
	selected.durability = 0
	check(not player._inventory_has_blade(), "Broken knife cannot open cans")
	selected.durability = 10
	check(player._inventory_has_blade(), "Usable knife can open cans")
	player.stats.thirst = 0
	player.stats.hunger = 0
	inv.items.clear()
	inv.add_item(ItemData.create("Botella de agua", "water", 0.5, 1, 20))
	var bottle = inv.items[0]
	inv.add_item(ItemData.create("Palo", "material", 0.1))
	player._start_consumption(bottle, "drink", 0.05)
	player._start_consumption(bottle, "drink", 0.05)
	inv.swap_items(0, 1)
	player.held_index = 0
	await create_timer(0.1).timeout
	check(bottle.durability == 75 and player.stats.thirst == 5, "Animated drink consumes one quarter once despite reorder/repeated input")
	check(inv.get_item_count("Palo") == 1 and not player._consumption_pending, "Unrelated held item untouched and action unlocks")
	player._start_consumption(bottle, "drink", 0.05)
	inv.remove_index(inv.items.find(bottle))
	var old_thirst: float = player.stats.thirst
	await create_timer(0.1).timeout
	check(player.stats.thirst == old_thirst and inv.get_item_count("Palo") == 1, "Dropped drink cannot give benefits or delete another item")
	inv.items.clear()
	inv.add_item(ItemData.create("Naranja", "food", 0.1, 1, 20))
	player._start_consumption(inv.items[0], "plant", 0.05)
	player.is_dead = true
	await create_timer(0.1).timeout
	check(inv.get_item_count("Naranja") == 1 and player.stats.hunger == 0, "Death cancels consumption")
	player.is_dead = false
	inv.items.clear()
	inv.add_item(ItemData.create("Lata de comida abierta", "food", 0.2, 1, 20))
	check(inv.use_index(0, player.stats), "Opened can can be eaten")
	check(inv.items[0].durability == 50 and player.stats.hunger == 10, "Can restores half portion")
	inv.items.clear()
	inv.add_item(ItemData.create("Botella de agua", "water", 0.5, 2, 20))
	check(inv.use_index(0, player.stats), "Bottle stack use")
	check(inv.items.size() == 2 and inv.items[0].durability == 100 and inv.items[1].durability == 75, "Only one bottle loses water")
	player.stats.thirst = player.stats.max_stat
	var partial = inv.items[1]
	inv.use_index(1, player.stats)
	check(partial.durability == 50 and player.stats.overdrink_count == 1, "Drinking while full still uses water")
	await process_frame
	check(player.find_children("*", "Timer", false, false).is_empty(), "Action timers freed")
	player.queue_free()
	inv.queue_free()
	await process_frame
	print("GAMEPLAY TESTS: ", checks, " checks, ", failed, " failures")
	quit(1 if failed else 0)
