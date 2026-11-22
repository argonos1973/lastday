extends SceneTree
# Regresion: el servidor dedicado debe crear las mismas acciones cosechables
# (pick_fruit, fell_bush) que el cliente — con los mismos ids, porque los ids
# son el contrato de sincronizacion (depleted_action_ids viaja por red).
# Antes de este cambio el servidor no generaba frutales ni arbustos: los bots
# no podian comer fruta ni conseguir semillas/palos para los huertos.

class FakeNet extends RefCounted:
	var is_dedicated_server := false
	var is_connected := false
	var is_host := false

class StubAnimal extends Node3D:
	var animal_type := "wolf"
	var tamed_to := ""
	var _is_dead := false
	var current_anim_keyword := ""

class HarvestWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
	func _get_ground_height(_pos: Vector3) -> float: return 0.0
	# Terreno plano y sin rios/carreteras: el test solo quiere las acciones.
	func _is_inside_river_band(_pos: Vector3, _margin: float = 0.0) -> bool: return false
	func _is_on_road(_pos: Vector3) -> bool: return false

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1

func _collect_ids(world: HarvestWorld) -> Dictionary:
	var ids := {"pick_fruit": {}, "fell_bush": {}}
	for aid in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[aid]
		var t := str(a.get("action_type"))
		if ids.has(t):
			ids[t][str(aid)] = a
	return ids

func run() -> void:
	var ded := HarvestWorld.new()
	ded.net = FakeNet.new()
	ded.net.is_dedicated_server = true
	root.add_child(ded)
	ded._military_tent_pos = Vector3(200.0, 0.0, 200.0)
	ded.HOUSE_FOOTPRINTS.append({"origin": ded._military_tent_pos, "w": 9.0, "d": 12.0})
	ded._create_fruit_trees()
	ded._create_harvestable_bushes()

	var client := HarvestWorld.new()
	client.net = FakeNet.new()
	root.add_child(client)
	client._military_tent_pos = Vector3(200.0, 0.0, 200.0)
	client.HOUSE_FOOTPRINTS.append({"origin": client._military_tent_pos, "w": 9.0, "d": 12.0})
	client._create_fruit_trees()
	client._create_harvestable_bushes()

	var d := _collect_ids(ded)
	var c := _collect_ids(client)
	print("ded pick_fruit=%d fell_bush=%d | client pick_fruit=%d fell_bush=%d" % [d["pick_fruit"].size(), d["fell_bush"].size(), c["pick_fruit"].size(), c["fell_bush"].size()])

	check(d["pick_fruit"].size() > 0, "dedicated server creates pick_fruit actions")
	check(d["fell_bush"].size() > 0, "dedicated server creates fell_bush actions")
	check(c["pick_fruit"].size() > 0, "client creates pick_fruit actions")
	check(c["fell_bush"].size() > 0, "client creates fell_bush actions")
	check(d["pick_fruit"].size() == c["pick_fruit"].size(), "pick_fruit count matches client/server")
	check(d["fell_bush"].size() == c["fell_bush"].size(), "fell_bush count matches client/server")

	var missing_on_ded := 0
	for aid in c["pick_fruit"].keys():
		if not d["pick_fruit"].has(aid):
			missing_on_ded += 1
	check(missing_on_ded == 0, "every client pick_fruit id exists on the server")
	missing_on_ded = 0
	for aid in c["fell_bush"].keys():
		if not d["fell_bush"].has(aid):
			missing_on_ded += 1
	check(missing_on_ded == 0, "every client fell_bush id exists on the server")

	# Metas que consumen los bots en _find_forage_target/_bot_forage_complete.
	var some_fruit = d["pick_fruit"].values()[0]
	check(str(some_fruit.get("action_type")) == "pick_fruit", "server fruit action has pick_fruit type")
	check(some_fruit.has_meta("fruit_ready_time"), "server fruit action carries fruit_ready_time")
	check(some_fruit.has_meta("fruit_type_name"), "server fruit action carries fruit_type_name")
	check(str(some_fruit.get_meta("fruit_type_name")) in ["Naranja", "Higo"], "fruit type is Naranja or Higo")
	var some_bush = d["fell_bush"].values()[0]
	check(str(some_bush.get("action_type")) == "fell_bush", "server bush action has fell_bush type")

	# Las posiciones tambien deben coincidir (los bots caminan hasta ellas).
	var pos_mismatch := 0
	for aid in d["pick_fruit"].keys():
		if c["pick_fruit"].has(aid):
			var pa: Vector3 = d["pick_fruit"][aid].global_position
			var pb: Vector3 = c["pick_fruit"][aid].global_position
			if pa.distance_to(pb) > 0.01:
				pos_mismatch += 1
	check(pos_mismatch == 0, "pick_fruit positions identical client/server")

	# Real forest generator: the server keeps only indexed data. The client
	# uses the real GLB variants, but rendering is omitted in this layout test.
	var nodes_before := ded.get_child_count()
	var wa_before := ded.world_actions_by_id.size()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var started := Time.get_ticks_usec()
	await ded._create_forest(true)
	print("SERVER_FOREST_MS=", (Time.get_ticks_usec() - started) / 1000.0)
	print("SERVER_FOREST_MEMORY_MB=", (Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before) / 1048576.0)
	check(ded._tree_entries_by_id.size() > 5000, "dedicated map has a real forest index")
	check(ded.get_child_count() == nodes_before and ded.world_actions_by_id.size() == wa_before,
		"server forest allocates zero scene nodes or per-tree WorldActions")
	client._load_forest_tree_pack()
	check(client._forest_tree_meshes.size() >= 2, "client variant selector consumes one RNG draw")
	await client._create_forest(true)
	check(ded._tree_entries_by_id.size() == client._tree_entries_by_id.size(), "forest counts identical with actual client variants")
	var layout_mismatches := 0
	for id in ded._tree_entries_by_id:
		if not client._tree_entries_by_id.has(id) or ded._tree_entries_by_id[id].pos.distance_to(client._tree_entries_by_id[id].pos) > 0.001:
			layout_mismatches += 1
	check(layout_mismatches == 0, "every generated server tree has the same client ID and position")
	var origin: Vector3 = ded._tree_entries_by_id.values()[100].pos
	var target := ded._find_bot_tree_target(origin, 24.0, origin)
	check(not target.is_empty(), "bot finds a generated tree without any manually inserted action")
	ded._pickup_claims[target.id] = 901
	check(ded._find_bot_tree_target(origin, 24.0, origin).get("id", "") != target.id, "spatial query respects another actor's tree reservation")
	ded._pickup_claims.clear()
	ded._create_cut_tree_remains(target.pos)
	check(ded._find_bot_tree_target(origin, 24.0, origin).get("id", "") != target.id, "spatial query never returns a cut tree")
	started = Time.get_ticks_usec()
	for _i in range(200):
		ded._find_bot_tree_target(origin, 80.0, origin)
	print("TREE_QUERY_AVG_USEC=", (Time.get_ticks_usec() - started) / 200.0)
	check(ded.get_child_count() == nodes_before, "queries and server cut remains create no graphical nodes")
	var manager := SurvivorBotManager.new()
	ded.add_child(manager)
	manager.world = ded
	manager.set_process(false)
	var proxy := Node3D.new()
	ded.add_child(proxy)
	proxy.position = origin
	proxy.set_meta("saved_inventory", [{"name":"Hacha","type":"tool_axe","quantity":1,"durability":50.0}])
	var bot := {"proxy":proxy,"bot_id":901,"camp_spot":Vector3.INF}
	var selected := manager._find_mat_target(bot, 24.0, "Hacha", false, false, false, true)
	check(not selected.is_empty(), "real bot selects a generated tree even without a chosen camp")
	if not selected.is_empty():
		var tree_pos: Vector3 = selected.pos
		proxy.position = tree_pos + Vector3(-3.0, 0.0, 0.0)
		var hidden_wolf := StubAnimal.new()
		ded.add_child(hidden_wolf)
		hidden_wolf.add_to_group("wildlife")
		hidden_wolf.position = tree_pos + Vector3(3.0, 0.0, 0.0)
		var eye := proxy.global_position + Vector3(0.0, 1.3, 0.0)
		var target_eye := hidden_wolf.global_position + Vector3(0.0, 1.1, 0.0)
		check(not ded.raycast_distant_props(eye, target_eye).is_empty(), "standing generated tree is an analytical occluder")
		var los_started := Time.get_ticks_usec()
		for _i in range(200):
			ded.raycast_distant_props(eye, target_eye)
		print("TREE_LOS_AVG_USEC=", (Time.get_ticks_usec() - los_started) / 200.0)
		check(not manager._has_clear_shot(proxy.global_position, hidden_wolf.global_position), "standing tree blocks the shared bot shot line")
		check(not manager._bot_within_aim_sight(bot, hidden_wolf, 6.0), "standing tree blocks bot aim recognition")
		check(manager._find_threatening_predator(bot, 30.0) == null, "stationary predator behind a tree is not detected visually")
		hidden_wolf.current_anim_keyword = "run"
		check(manager._find_threatening_predator(bot, 30.0) == hidden_wolf, "running predator can be heard through tree cover")
		check(not manager._bot_within_aim_sight(bot, hidden_wolf, 6.0), "hearing a predator does not unlock aim through a tree")
		proxy.position = selected.pos
		var cold := SurvivalStats.new()
		cold.body_temperature = 34.7
		bot["vstats"] = cold
		bot["_gather"] = selected
		manager._bot_try_gather_mats(bot, 9.9, true)
		check(not ded._legit_cut_trees.has(selected.id), "generated tree cannot complete before ten seconds of chopping")
		manager._bot_try_gather_mats(bot, 0.2, true)
		check(ded._legit_cut_trees.has(selected.id) and ded._dropped_items.filter(func(drop): return str(drop.id).begins_with("pickup_Tronco_" + str(selected.id))).size() == 4,
			"bot cuts an indexed tree with no WorldAction and creates four authoritative drops")
		check(manager._bot_item_count(proxy, "Tronco") == 0 and float(proxy.get_meta("saved_inventory")[0].durability) == 40.0,
			"indexed felling costs axe durability and never grants logs directly")
		check(ded.raycast_distant_props(eye, target_eye).is_empty(), "felled tree no longer blocks the analytical sight line")
		check(manager._has_clear_shot(proxy.global_position, hidden_wolf.global_position), "felled tree reopens the shared bot shot line")
		check(manager._bot_within_aim_sight(bot, hidden_wolf, 6.0), "bot can reacquire aim after the occluding tree falls")
		hidden_wolf.free()
		cold.free()

	ded.queue_free()
	client.queue_free()
	await process_frame
	print("FAILURES=%d" % failures)
	quit(1 if failures > 0 else 0)
