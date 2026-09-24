extends SceneTree

# Bisects _world_rng divergence: replicates the exact client-side phase order of
# Main._create_map and dumps _world_rng.state after each phase. Run twice and
# diff the output files; the first differing checkpoint names the culprit phase.

const MainScript = preload("res://scripts/Main.gd")

class FakeNet extends Node:
	signal player_connected(id)
	signal player_disconnected(id)
	signal connection_failed()
	var is_host := false
	var is_connected := true
	var is_dedicated_server := false
	var peer = null
	var client_id := "det_client"
	var players: Dictionary = {}
	func get_my_id() -> int:
		return 2

class TestWorld extends MainScript:
	var _gen_done := false
	var _ck := FileAccess.open("user://rng_ckpt.txt", FileAccess.WRITE)
	func ck(name: String) -> void:
		_ck.store_line("%s|%d" % [name, _world_rng.state])
		_ck.flush()
	func _ready() -> void:
		net = get_node("/root/NetworkManager")
		seed(WORLD_SEED)
		_world_rng.seed = WORLD_SEED
		_terrain_rng.seed = TERRAIN_SEED
		nav = NavPathfindingScript.new()
		world_streaming_mgr = WorldStreamingManager.new()
		add_child(world_streaming_mgr)
		world_streaming_mgr.setup(self)
		sector_persistence_mgr = SectorPersistenceManager.new()
		add_child(sector_persistence_mgr)
		# Exact client path of _create_map()
		_generated_hills.clear()
		river_segments_data = _default_river_segments()
		_create_invisible_collision_box("GroundCollision", Vector3(0, -0.2, 0), Vector3(MAP_EXTENT * 2.0, 0.2, MAP_EXTENT * 2.0))
		ck("init")
		_create_leafy_floor_ground()
		await get_tree().process_frame
		ck("leafy_floor")
		_create_mountain_backdrop()
		await get_tree().physics_frame
		await get_tree().physics_frame
		await _create_rocky_foothills()
		await get_tree().physics_frame
		await get_tree().physics_frame
		ck("mountains")
		await _create_grass_ground_cover()
		ck("grass_cover")
		await _create_mountain_river()
		await get_tree().process_frame
		ck("river")
		_create_road()
		await get_tree().process_frame
		ck("road")
		_create_house(Vector3(-25, 0, -18), "Casa abandonada 1", "house_1", 11.4, 9.4, 4.35)
		await get_tree().process_frame
		ck("house_1")
		_create_house(Vector3(-38, 0, 18), "Casa abandonada 2", "house_2", 14.0, 11.0, 4.9)
		await get_tree().process_frame
		ck("house_2")
		_create_house(Vector3(23, 0, 18), "Casa abandonada 3", "house_3", 9.0, 7.5, 3.9)
		await get_tree().process_frame
		ck("house_3")
		_create_house(Vector3(42, 0, 26), "Casa abandonada 4", "house_4", 12.5, 10.0, 4.5)
		await get_tree().process_frame
		ck("house_4")
		_create_house(Vector3(-12, 0, 42), "Casa abandonada 5", "house_5", 8.0, 7.0, 3.7)
		await get_tree().process_frame
		ck("house_5")
		_create_house(Vector3(-35, 0, -40), "Casa abandonada 6", "house_6", 10.5, 8.5, 4.1)
		await get_tree().process_frame
		ck("house_6")
		_create_house(Vector3(30, 0, -35), "Casa abandonada 7", "house_7", 13.0, 10.0, 4.7)
		await get_tree().process_frame
		ck("house_7")
		_create_house(Vector3(-45, 0, -5), "Casa abandonada 8", "house_8", 9.5, 8.0, 3.9)
		await get_tree().process_frame
		ck("house_8")
		_create_house(Vector3(35, 0, -8), "Casa abandonada 9", "house_9", 11.0, 9.0, 4.3)
		await get_tree().process_frame
		ck("house_9")
		_create_house(Vector3(-20, 0, 30), "Casa abandonada 10", "house_10", 7.5, 6.5, 3.6)
		await get_tree().process_frame
		ck("house_10")
		await _create_barn(Vector3(45, 0, 120))
		await get_tree().process_frame
		await _create_barn(Vector3(-340, 0, 280), "_Remote")
		await get_tree().process_frame
		ck("barns")
		_create_world_details()
		await get_tree().process_frame
		ck("world_details")
		_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightA", Vector3(3.0, 0, -22), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
		_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightB", Vector3(3.0, 0, 14), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
		_add_collision_to_prop_group(get_node_or_null("QStreetLightA"))
		_add_collision_to_prop_group(get_node_or_null("QStreetLightB"))
		_create_power_line(Vector3(15, 0, -40), Vector3(15, 0, 40))
		ck("streetlights")
		await _create_ground_clutter()
		await get_tree().process_frame
		ck("clutter")
		await _create_tall_grass_fields()
		await get_tree().process_frame
		ck("tall_grass")
		await _create_grass_carpet()
		await get_tree().process_frame
		ck("grass_carpet")
		await _create_dense_vegetation_zones()
		await get_tree().process_frame
		ck("dense_veg")
		await _create_forest()
		await get_tree().process_frame
		ck("forest")
		_create_survival_objectives()
		await get_tree().process_frame
		ck("survival")
		_create_river_drink_zones()
		ck("drink_zones")
		await _flush_grass_batches()
		await get_tree().process_frame
		ck("done")
		_ck.close()
		_gen_done = true
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

var world: TestWorld

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fake_net := FakeNet.new()
	fake_net.name = "NetworkManager"
	root.add_child(fake_net)
	world = TestWorld.new()
	root.add_child(world)
	current_scene = world
	var waited := 0.0
	while not world._gen_done and waited < 900.0:
		await create_timer(1.0).timeout
		waited += 1.0
	print("[TEST] gen done after ~%.0fs" % waited)
	quit(0)
