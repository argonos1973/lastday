extends SceneTree
const Main = preload("res://scripts/Main.gd")
const WorldAction = preload("res://scripts/WorldAction.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")
class IsolatedWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func run() -> void:
	var world := IsolatedWorld.new()
	root.add_child(world)
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
		check(plant.position.y < 0.08, "roots sit in soil instead of floating above it")
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

	# Interaction prompts cover each state.
	action.set_crop_state("empty", 0.0)
	check(action.get_interaction_text().findn("Plantar") >= 0, "empty plot offers planting")
	action.set_crop_state("planted", 10.0)
	check(action.get_interaction_text().findn("creciendo") >= 0 or action.get_interaction_text().findn("Cultivo") >= 0, "planted plot reports growth")
	action.set_crop_state("ready", 0.0)
	check(action.get_interaction_text().findn("Cosechar") >= 0, "ready plot offers harvest")

	# World serialization keeps state/growth and restores offline growth.
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

	# A seed dropped on the ground becomes a plant-or-pickup action, not food.
	var seed_action := WorldAction.new()
	seed_action.setup("seed_test", "plant_seeds", "Semillas", Vector3.ONE, Color.BLACK, false, false)
	check(seed_action.get_interaction_text().findn("Plantar") >= 0, "dropped seeds offer planting")
	seed_action.free()

	world.queue_free()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
