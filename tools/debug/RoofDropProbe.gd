extends SceneTree
# Rooftop campfire / tower gutting regression probe.

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

func _fail(msg: String) -> void:
	printerr("[FAIL] " + msg)
	quit(1)

func _initialize() -> void:
	var world := TestWorld.new()
	root.add_child(world)

	# 1. House roof (layer 4): sky probe (from_y=500) must ignore the roof so
	# interior loot generation still lands on the floor, while a player-level
	# probe (from_y < 400) must land on the roof.
	var roof_y := 4.0
	world._create_invisible_collision_box("TestHouse RoofCollision", Vector3(20.0, roof_y, 20.0), Vector3(8.0, 0.7, 8.0), 4)
	await physics_frame
	await physics_frame
	var sky_y := world._get_exact_ground_y(20.0, 20.0) # default from_y = 500
	var player_y := world._get_exact_ground_y(20.0, 20.0, roof_y + 1.5)
	print("[TEST] house roof: sky_y=%.2f player_y=%.2f" % [sky_y, player_y])
	if sky_y > 1.0:
		_fail("sky probe hit house roof (expected terrain ~0, got %.2f)" % sky_y)
	if absf(player_y - (roof_y + 0.7)) > 0.15:
		_fail("player-height probe missed house roof (got %.2f)" % player_y)

	# Campfire dropped on house roof stays on the roof.
	world._on_item_dropped("campfire", "campfire", 0.0, 1, 0.0, Vector3(20.0, roof_y + 0.7, 20.0))
	if world._built_campfires.is_empty():
		_fail("house roof campfire was not recorded")
	var house_cf_pos: Vector3 = world._built_campfires[-1]["pos"]
	print("[TEST] house campfire pos=", house_cf_pos)
	if absf(house_cf_pos.y - (roof_y + 0.7)) > 0.2:
		_fail("house roof campfire fell through roof: %s" % str(house_cf_pos))

	# 2. Clock tower deck: campfire + ground-recipe height resolution at deck
	# level (29.4) must stay on the deck instead of snapping to the roof peak
	# (33.85) or terrain (0.0).
	var tower := preload("res://scripts/CityClockTower.gd").new()
	tower.name = "CityClockTower"
	tower.position = tower.WORLD_POSITION
	world.add_child(tower)
	await physics_frame
	await physics_frame
	var deck_pt := Vector3(38.0, 29.4, 754.0)
	var tower_sky_y := world._get_exact_ground_y(deck_pt.x, deck_pt.z) # hits peak ~33.85
	var tower_deck_y := world._get_exact_ground_y(deck_pt.x, deck_pt.z, deck_pt.y + 0.5)
	print("[TEST] tower deck: sky_y=%.2f deck_y=%.2f" % [tower_sky_y, tower_deck_y])
	if absf(tower_deck_y - 29.4) > 0.25:
		_fail("tower deck ray missed 29.4 platform (got %.2f)" % tower_deck_y)

	world._on_item_dropped("campfire", "campfire", 0.0, 1, 0.0, deck_pt)
	var tower_cf_pos: Vector3 = world._built_campfires[-1]["pos"]
	print("[TEST] tower campfire pos=", tower_cf_pos)
	if absf(tower_cf_pos.y - 29.4) > 0.25:
		_fail("tower campfire did not land on deck: %s" % str(tower_cf_pos))

	# 3. Wolf dying on the tower deck must keep its elevation (not snap to y=0.1).
	var wolf := preload("res://scripts/WildlifeController.gd").new()
	wolf.animal_type = "wolf"
	var vis := Node3D.new()
	wolf.add_child(vis)
	wolf._visual_root = vis
	world.add_child(wolf)
	wolf.global_position = deck_pt
	wolf._lie_corpse_flat()
	print("[TEST] dead wolf y=%.2f" % wolf.global_position.y)
	if absf(wolf.global_position.y - 29.4) > 0.25:
		_fail("wolf corpse dropped to ground (y=%.2f)" % wolf.global_position.y)

	# 4. Dropped wolf corpse (WorldAction gut_wolf) must be spatially indexed
	# and discoverable by InteractionRaycast fallback on the tower deck.
	var wa := preload("res://scripts/WorldAction.gd").new()
	wa.action_id = "test_gut_tower"
	wa.action_type = "gut_wolf"
	wa.position = deck_pt + Vector3(0.8, 0.0, 0.0)
	world.add_child(wa)
	var nearby := preload("res://scripts/WorldAction.gd").get_nearby_interactables(deck_pt, 3.0)
	if not nearby.has(wa):
		_fail("gut_wolf WorldAction was not indexed in spatial cells")
	var dummy_player := CharacterBody3D.new()
	world.add_child(dummy_player)
	dummy_player.global_position = deck_pt
	var ray := preload("res://scripts/InteractionRaycast.gd").new()
	world.add_child(ray)
	var found := ray._find_nearest_interactable(dummy_player)
	print("[TEST] nearest interactable on deck=", found)
	if found == null:
		_fail("InteractionRaycast fallback found nothing on tower deck")

	print("[PASS] Rooftop campfire & tower wolf gutting checks passed")
	quit(0)
