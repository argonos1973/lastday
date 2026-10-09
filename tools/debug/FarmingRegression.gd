extends SceneTree
const Main = preload("res://scripts/Main.gd")
const WorldAction = preload("res://scripts/WorldAction.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")
class IsolatedWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	var slope := 0.0
	func _get_exact_ground_y(x: float, _z: float, _from_y: float = 500.0) -> float: return x*slope
class FakeActor extends Node:
	signal notice(_msg)
	var inventory = preload("res://scripts/Inventory.gd").new()
	var held = null
	func get_held_item(): return held
	func play_action_animation(_a, _d): pass
	func _sync_held_item(): pass
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func run() -> void:
	var world := IsolatedWorld.new()
	root.add_child(world)
	current_scene = world
	var pos := Vector3(37.0, 0.0, -41.0)

	# Planting a dropped seed creates a farm_plot world action in "planted" state.
	var crop_id := world._plant_crop(pos)
	check(not crop_id.is_empty(), "planting seeds registers a crop")
	check(world._planted_crops.size() == 1, "crop tracked for persistence")
	var action = world.world_actions_by_id.get(crop_id)
	check(action != null and action.action_type == "farm_plot", "crop is a farm_plot world action")
	check(action != null and action.action_state == "planted", "fresh crop starts planted")
	check(action != null and action.grow_time >= 300.0, "growth takes several minutes like DayZ")
	check(action != null and action.get_meta("crop_id", "") == crop_id, "action carries its crop id")

	# The same bed follows a hillside and keeps plants rooted through growth.
	world.slope = .16
	var sloped := WorldAction.new()
	world.add_child(sloped)
	sloped.setup("slope_probe", "farm_plot", "Huerto", Vector3(1.9,.16,1.9), Color.BROWN, true, false)
	sloped.set_crop_state("planted", 0)
	check(absf(sloped._farm_ground_offset(.8, 0)-.128)<.001, "soil follows sampled terrain slope")
	for child in sloped.get_children():
		if str(child.name).begins_with("CropPlant"):
			check(absf(child.position.y-(.030+child.position.x*.16))<.001, "plant root follows the same soil slope")
	sloped.free()
	world.slope = 0.0

	# Duplicate planting at the same spot does not create a second plot.
	var same_id := world._plant_crop(pos)
	check(same_id == crop_id and world._planted_crops.size() == 1, "replanting same spot is idempotent")

	# The plot is a Blender tilled bed, not the procedural marker box.
	var live_bed := func() -> Node:
		for c in action.get_children():
			if String(c.scene_file_path).ends_with("farm_plot.glb") and not c.is_queued_for_deletion():
				return c
		return null
	var live_plants := func() -> Array:
		var found: Array = []
		for c in action.get_children():
			if String(c.scene_file_path).begins_with("res://assets/models/props/farming/crop_stage_") and not c.is_queued_for_deletion():
				found.append(c)
		return found
	action.growth = 0.0
	action._update_crop_visual()
	check(live_bed.call() != null, "plot shows the Blender tilled bed")
	check(action._mesh_instance != null and not action._mesh_instance.visible, "procedural marker box stays hidden")
	var early_plants: Array = live_plants.call()
	check(early_plants.size() == 9 and String(early_plants[0].scene_file_path).ends_with("crop_stage_0.glb"), "early growth shows a sprout row on each ridge")
	var planting_transforms: Array[Transform3D] = []
	for plant in early_plants:
		planting_transforms.append(plant.transform)
		check(plant.position.y < 0.12, "roots sit in soil instead of floating above it")
	check(not early_plants[0].scale.is_equal_approx(early_plants[1].scale), "plants vary in size")
	action.tick_growth(200.0)
	check(action.action_state == "planted" and action.growth > 0.0, "crop keeps growing over time")
	action._update_crop_visual()
	var mid_plants: Array = live_plants.call()
	check(mid_plants.size() == 9 and mid_plants[0] != early_plants[0] and String(mid_plants[0].scene_file_path).ends_with("crop_stage_1.glb"), "growth stage swaps the visual model")
	for i in mid_plants.size():
		check(mid_plants[i].transform.is_equal_approx(planting_transforms[i]), "plant placement persists across growth stages")
	action.tick_growth(500.0)
	check(action.action_state == "ready", "crop matures to ready after grow_time")
	var ready_plants: Array = live_plants.call()
	check(ready_plants.size() == 9 and String(ready_plants[0].scene_file_path).ends_with("crop_stage_3.glb"), "ready crop shows the mature model")

	# Moist soil — rain or manual watering — speeds growth, without stacking.
	action.set_crop_state("planted", 0.0)
	action.tick_growth(10.0)
	check(is_equal_approx(action.growth, 10.0), "dry crop grows at base rate")
	action.water_crop()
	check(action.is_crop_watered(), "watering marks the soil moist")
	action.tick_growth(10.0)
	check(action.growth > 30.0, "watered crop grows faster")
	check(action.get_interaction_text().findn("humeda") >= 0, "prompt shows the moist tag")
	action.remove_meta("watered_until")
	action.tick_growth(10.0, GameConst.CROP_MOIST_GROWTH)
	check(action.growth > 55.0, "rain moistens the soil too")
	action.water_crop()
	var growth_before: float = action.growth
	action.tick_growth(10.0, GameConst.CROP_MOIST_GROWTH)
	check(action.growth - growth_before <= GameConst.CROP_MOIST_GROWTH * 10.0 + 0.01, "rain and watering do not stack")
	action.remove_meta("watered_until")
	action.set_crop_state("planted", 0.0)

	# Interaction prompts cover each state.
	action.set_crop_state("empty", 0.0)
	check(action.get_interaction_text().findn("Plantar") >= 0, "empty plot offers planting")
	action.set_crop_state("planted", 10.0)
	check(action.get_interaction_text().findn("creciendo") >= 0 or action.get_interaction_text().findn("Cultivo") >= 0, "planted plot reports growth")
	action.set_crop_state("ready", 0.0)
	check(action.get_interaction_text().findn("Recolectar") >= 0, "ready plot offers harvest")

	# A ripe bed left too long rots; the timestamp meta drives the window.
	check(action.has_meta("ready_unix"), "ready transition stamps ready_unix")
	action.set_meta("ready_unix", Time.get_unix_time_from_system() - GameConst.CROP_ROT_SECONDS - 1.0)
	action.tick_growth(0.1)
	check(action.action_state == "rotten", "ripe crop rots after the rot window")
	check(action.get_interaction_text().findn("podrido") >= 0, "rotten plot offers cleaning")
	var rotten_plants: Array = live_plants.call()
	check(rotten_plants.size() == 9, "rotten crop keeps withered plants")

	# World serialization keeps state/growth and restores offline growth.
	action.remove_meta("ready_unix")
	action.set_crop_state("ready", 0.0)
	var data: Dictionary = SaveHooks.collect_world_data(world)
	var saved_crops: Array = data.get("planted_crops", [])
	check(saved_crops.size() == 1, "crops serialized into world data")
	var entry: Dictionary = saved_crops[0]
	check(str(entry.get("crop_state", "")) == "ready" and entry.has("saved_unix"), "saved crop keeps state and timestamp")
	check(entry.get("pos") is Array, "crop position serializes for JSON")

	# Dropped seed/berry pickups resolve to the farming GLBs.
	check(str(world._get_drop_model_paths("Semillas", "resource")[0]).ends_with("farm_seed_pouch.glb"), "resource seeds drop as a seed pouch")
	check(str(world._get_drop_model_paths("Semillas", "seed")[0]).ends_with("farm_seed_pouch.glb"), "harvested seeds drop as a seed pouch")
	check(str(world._get_drop_model_paths("Bayas", "food")[0]).ends_with("farm_berries.glb"), "harvest berries use the berry model")
	check(str(world._get_drop_model_paths("Verduras", "food")[0]).ends_with("farm_berries.glb"), "harvested vegetables drop as produce, not a giant can")

	# Hand tools come from the Blender set and spawn through the loot pipeline.
	for t in [["Azada", "tool_hoe", "tool_hoe.glb"], ["Pala", "tool_shovel", "tool_shovel.glb"]]:
		check(ResourceLoader.exists("res://assets/models/props/tools/" + t[2]), t[2] + " exists")
		check(str(world._get_drop_model_paths(t[0], t[1])[0]).ends_with(t[2]), t[0] + " drops as the Blender tool")
	world._create_pickup_item({
		"id": "test_hoe_loot", "name": "Azada", "type": "tool_hoe",
		"weight": 0.9, "qty": 1, "use": 0.0,
		"paths": ["res://assets/models/props/tools/tool_hoe.glb"],
		"scale": 1.0, "rot": Vector3(0, 45, 0),
		"pos": Vector3(11.0, 0.0, 7.0), "color": Color(0.28, 0.18, 0.08)
	})
	var hoe_action = world.world_actions_by_id.get("test_hoe_loot")
	check(hoe_action != null and str(hoe_action.get_meta("item_type", "")) == "tool_hoe", "tool loot registers a hoe pickup")
	check(world.get_node_or_null("Pickup_test_hoe_loot") != null, "tool loot spawns its model")
	var src := FileAccess.get_file_as_string("res://scripts/Main.gd")
	check(src.count('"name": "Azada", "type": "tool_hoe"') >= 3 and src.count('"name": "Pala", "type": "tool_shovel"') >= 2, "hoe and shovel appear in barn and house loot pools")
	check(not '"type": "tool_pickaxe"' in src, "pickaxe removed from loot pools")

	# Blender-adapted military/civilian gear: skinned worn GLBs, flat pickups,
	# item wiring and loot pools.
	var MJ := load("res://scripts/MilitaryJackets.gd")
	check(str(MJ.VARIANTS.get("Chaqueta de cuadros", "")) == "plaid", "plaid jacket is a military-jacket variant")
	check(str(MJ.VARIANTS.get("Chaleco táctico", "")) == "plate_carrier", "plate carrier is a military-jacket variant")
	check(str(MJ.pickup_path("Chaqueta de cuadros")).ends_with("pickup_jacket_plaid.glb"), "plaid pickup path resolves")
	for p in ["military_jacket_plaid.glb", "military_jacket_plate_carrier.glb",
			"pickup_jacket_plaid.glb", "pickup_jacket_plate_carrier.glb"]:
		check(ResourceLoader.exists("res://assets/characters/adapted/jackets/" + p), p + " exists")
	check(ResourceLoader.exists(GameConst.MILITARY_BACKPACK_MODEL), "military backpack GLB exists")
	check(str(world._get_drop_model_paths("Mochila militar", "backpack")[0]).ends_with("military_backpack.glb"), "military backpack drops as its own model")
	var pc := load("res://scripts/PlayerController.gd")
	check(str(pc.CLOTHING_SLOTS.get("Chaqueta de cuadros", "")) == "torso", "plaid jacket equips on torso")
	check(str(pc.CLOTHING_SLOTS.get("Chaleco táctico", "")) == "chaleco", "plate carrier gets the vest slot")
	check(pc.SURVIVAL_CLOTHING.has("Chaqueta de cuadros") and pc.SURVIVAL_CLOTHING.has("Chaleco táctico"), "new gear registered as survival clothing")
	check(src.count('"name": "Chaleco táctico"') >= 1 and src.count('"name": "Mochila militar"') >= 1, "military gear sits in the tent loot pool")
	check(src.count('"name": "Chaqueta de cuadros"') >= 3, "plaid jacket sits in house and barn pools")

	# A seed dropped on the ground becomes a plant-or-pickup action, not food.
	var seed_action := WorldAction.new()
	seed_action.setup("seed_test", "plant_seeds", "Semillas", Vector3.ONE, Color.BLACK, false, false)
	check(seed_action.get_interaction_text().findn("Plantar") >= 0, "dropped seeds offer planting")
	seed_action.free()

	# Interaction guards: one in-flight job per bed, seeds only consumed on
	# completion, watering charges a single bottle from a shared stack.
	var actor := FakeActor.new()
	root.add_child(actor)
	actor.inventory.max_slots = 40
	actor.inventory.max_weight = 500.0
	actor.add_child(actor.inventory)
	var ItemScript := load("res://scripts/Item.gd")

	# Double F presses cannot double a harvest.
	action.set_crop_state("ready", 0.0)
	world._handle_farm_plot(action, actor)
	world._handle_farm_plot(action, actor)
	check(action.has_meta("farm_busy"), "harvest marks the bed busy")
	await create_timer(1.5).timeout
	var veg_qty := 0
	for it in actor.inventory.items:
		if it.item_name == "Verduras": veg_qty += it.quantity
	check(veg_qty == 3, "one harvest grants one portion, not two")

	# Seeds survive an aborted attempt and are only consumed on completion.
	action.set_crop_state("empty", 0.0)
	actor.inventory.add_item(ItemScript.create("Azada", "tool_hoe", 0.9, 1, 0.0))
	actor.inventory.add_item(ItemScript.create("Semillas", "seed", 0.02, 2, 0.0))
	world._handle_farm_plot(action, actor)
	check(actor.inventory.has_item_name("Semillas", 2), "seeds are not consumed before the work finishes")
	await create_timer(1.6).timeout
	check(action.action_state == "planted" and actor.inventory.has_item_name("Semillas", 1), "planting consumes one seed on completion")

	# Watering drains one bottle's worth from the shared stack durability.
	action.set_crop_state("planted", 10.0)
	var bottles = ItemScript.create("Botella de agua", "water", 0.5, 3, 0.0)
	bottles.durability = 100.0
	bottles.max_durability = 100.0
	actor.held = bottles
	world._handle_farm_plot(action, actor)
	await create_timer(2.2).timeout
	var expected := 100.0 - GameConst.CROP_WATER_USE / 3.0
	check(absf(float(bottles.durability) - expected) < 0.5, "watering drains one bottle, not the whole stack")
	actor.inventory.free()
	actor.free()

	# The world tick pings the local player once when a bed turns harvestable.
	var notice_count := {"ready": 0, "rotten": 0}
	var listener := FakeActor.new()
	listener.notice.connect(func(msg):
		if str(msg).findn("recolectar") >= 0: notice_count["ready"] += 1
		if str(msg).findn("podrido") >= 0: notice_count["rotten"] += 1)
	world.player = listener
	action.set_crop_state("planted", 0.0)
	world._tick_world_actions(float(action.grow_time) + 1.0)
	check(action.action_state == "ready", "world tick ripens a full-grown crop")
	check(notice_count["ready"] == 1, "ready transition notifies the player once")
	world._tick_world_actions(1.0)
	check(notice_count["ready"] == 1, "later ticks do not repeat the ready notice")
	action.set_meta("ready_unix", Time.get_unix_time_from_system() - GameConst.CROP_ROT_SECONDS - 1.0)
	world._tick_world_actions(1.0)
	check(action.action_state == "rotten" and notice_count["rotten"] == 1, "rotting also warns the player")
	listener.inventory.free()
	listener.free()
	world.player = null

	world.free()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
