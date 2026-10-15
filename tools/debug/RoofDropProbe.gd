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

	# 5. Gutting a dropped corpse on the tower deck must spawn meat & hide visuals
	# AT the tower deck height (~29.4), NOT at 2x height (58.8) or ground (0).
	var mvis_pos := deck_pt + Vector3(0.5, 0.06, 0.0)
	world._spawn_raw_meat_visual("tower_meat_test", "Carne cruda de lobo", mvis_pos)
	var meat_vis := world.get_node_or_null("Pickup_tower_meat_test") as Node3D
	if meat_vis == null:
		_fail("tower meat visual was not spawned")
	print("[TEST] tower meat visual y=%.2f" % meat_vis.global_position.y)
	if absf(meat_vis.global_position.y - 29.4) > 0.6:
		_fail("tower meat visual spawned at wrong y=%.2f (expected ~29.4)" % meat_vis.global_position.y)

	# 5b. Drops/crafting next to the tower stairwell opening or past the parapet
	# must be pulled back onto the deck — otherwise they land on inner floors
	# (y=25.3/4.2) and are invisible from the roof. Cells from the deck grid
	# scan: standing at (45, 745) facing +z the 0.8 m drop fell into the stair
	# flight; standing at x=35 facing -x the drop flew over the parapet onto
	# the wing roof at y=4.2.
	var cap_y := 29.4 + 0.95
	var hole_drop: Vector3 = world._settle_drop_pos(Vector3(45.0, cap_y, 745.8))
	print("[TEST] stairwell-hole drop resolved=", hole_drop)
	if hole_drop.y < 28.5:
		_fail("drop over stairwell hole sank inside tower: %s" % str(hole_drop))
	var edge_drop: Vector3 = world._settle_drop_pos(Vector3(34.2, cap_y, 750.0))
	print("[TEST] parapet-edge drop resolved=", edge_drop)
	if edge_drop.y < 28.5:
		_fail("drop past parapet fell inside tower: %s" % str(edge_drop))

	# Real drops through _on_item_dropped at the same bad spots: the recorded
	# position AND the spawned visual must both stay at deck level.
	var drop_count := world._dropped_items.size()
	world._on_item_dropped("Tronco", "resource", 1.2, 1, 0.0, Vector3(45.0, cap_y, 745.8))
	if world._dropped_items.size() <= drop_count:
		_fail("tower Tronco drop was not recorded")
	var trunk_entry: Dictionary = world._dropped_items[-1]
	var trunk_pos: Vector3 = trunk_entry["pos"]
	print("[TEST] tower Tronco drop pos=", trunk_pos)
	if trunk_pos.y < 28.5:
		_fail("Tronco drop sank inside tower: %s" % str(trunk_pos))
	var trunk_vis := world.get_node_or_null("Pickup_" + str(trunk_entry["id"])) as Node3D
	if trunk_vis == null:
		_fail("Tronco visual missing on tower deck")
	elif trunk_vis.global_position.y < 28.0:
		_fail("Tronco visual inside tower y=%.2f" % trunk_vis.global_position.y)

	world._on_item_dropped("Palo", "material", 0.3, 2, 0.0, Vector3(34.2, cap_y, 750.0))
	var stick_entry: Dictionary = world._dropped_items[-1]
	var stick_pos: Vector3 = stick_entry["pos"]
	print("[TEST] tower Palo drop pos=", stick_pos)
	if stick_pos.y < 28.5:
		_fail("Palo drop fell past parapet inside tower: %s" % str(stick_pos))
	var stick_vis := world.get_node_or_null("Pickup_" + str(stick_entry["id"])) as Node3D
	if stick_vis == null:
		_fail("Palo visual missing on tower deck")
	elif stick_vis.global_position.y < 28.0:
		_fail("Palo visual inside tower y=%.2f" % stick_vis.global_position.y)

	world._on_item_dropped("campfire", "campfire", 0.0, 1, 0.0, Vector3(45.0, cap_y, 745.8))
	var hole_cf_pos: Vector3 = world._built_campfires[-1]["pos"]
	print("[TEST] stairwell campfire pos=", hole_cf_pos)
	if hole_cf_pos.y < 28.5:
		_fail("campfire over stairwell hole sank inside tower: %s" % str(hole_cf_pos))

	# 5c. Tower roof deck (y=29.46) must count as sheltered inside the tower,
	# repeated drops at the center of the roof must spread out instead of
	# stacking on the exact same coordinate, and _update_loot_wear must never
	# free a Pickup_* visual while leaving its WorldAction prompt active.
	if not preload("res://scripts/CityClockTower.gd").contains(Vector3(41.0, 29.46, 750.0)):
		_fail("CityClockTower.contains rejected roof deck y=29.46")
	world._on_item_dropped("Tronco", "resource", 1.2, 1, 0.0, Vector3(41.0, cap_y, 748.8))
	var first_center_pos: Vector3 = world._dropped_items[-1]["pos"]
	world._on_item_dropped("Tronco", "resource", 1.2, 1, 0.0, Vector3(41.0, cap_y, 748.8))
	var second_center_pos: Vector3 = world._dropped_items[-1]["pos"]
	if first_center_pos.distance_to(second_center_pos) < 0.15:
		_fail("repeated Tronco drops stacked on the exact same spot: %s vs %s" % [str(first_center_pos), str(second_center_pos)])
	# Unsheltered drop outside buildings: when wear reaches 100, its WorldAction
	# must be depleted alongside the visual (no ghost interaction prompt).
	world._on_item_dropped("Palo", "material", 0.3, 1, 0.0, Vector3(0.0, 0.5, 0.0))
	var exp_id := str(world._dropped_items[-1]["id"])
	for _t in range(310):
		world._update_loot_wear()
	if world.world_actions_by_id.has(exp_id):
		_fail("_update_loot_wear left ghost WorldAction after freeing visual: " + exp_id)

	# 6. Shelter placement on house roof and tower deck must be valid (no false
	# obstacle or slope error).
	dummy_player.global_position = Vector3(20.0, roof_y + 0.7, 20.0)
	var house_sh_err := world.shelter_placement_error(Vector3(20.0, roof_y + 0.7, 20.0), 0.0, dummy_player)
	if not house_sh_err.is_empty():
		_fail("house roof shelter placement rejected: " + house_sh_err)
	dummy_player.global_position = deck_pt
	var tower_sh_err := world.shelter_placement_error(deck_pt, 0.0, dummy_player)
	if not tower_sh_err.is_empty():
		_fail("tower deck shelter placement rejected: " + tower_sh_err)

	# 7. Camo net material must have a valid albedo texture (never plain white).
	var net_test := Node3D.new()
	var net_mi := MeshInstance3D.new()
	net_mi.mesh = BoxMesh.new()
	net_test.add_child(net_mi)
	world.add_child(net_test)
	world._apply_camo_net_material(net_test)
	if net_mi.material_override == null or (net_mi.material_override as StandardMaterial3D).albedo_texture == null:
		_fail("camo net material is missing albedo_texture (would render white)")

	# 8. Wildlife gunshot flee works at long range (100 m) even when _player is null
	# (like on the dedicated server).
	var flee_wolf := preload("res://scripts/WildlifeController.gd").new()
	flee_wolf.animal_type = "wolf"
	flee_wolf.patrol_points = [Vector3(0, 0, 0), Vector3(10, 0, 0)]
	world.add_child(flee_wolf)
	flee_wolf.global_position = Vector3(95.0, 0.0, 0.0)
	flee_wolf.flee_from_gunshot(Vector3.ZERO, 120.0)
	var ai_res := flee_wolf._wolf_ai(0.1)
	if float(ai_res["speed"]) <= flee_wolf.move_speed * 2.0 or Vector3(ai_res["target"]).x <= 95.0:
		_fail("wolf did not flee running from distant gunshot: " + str(ai_res))

	print("[PASS] Rooftop campfire, shelter, tower wolf gutting, camo net & gunshot flee checks passed")
	quit(0)
