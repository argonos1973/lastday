extends SceneTree

# Reproduces the reported multiplayer bug: sync_world_state arrives ~2s after
# connect while the client is still generating the map. Drops spawned mid-gen
# must survive the remaining generation (houses/floors are built later).

const MainScript = preload("res://scripts/Main.gd")

class FakeNet extends Node:
	signal player_connected(id)
	signal player_disconnected(id)
	signal connection_failed()
	var is_host := false
	var is_connected := true
	var is_dedicated_server := false
	var peer = null
	var client_id := "midgen_client"
	var players: Dictionary = {}
	var _has_buffered_world_state := false
	var _buffered_world_state: Array = []
	var _has_buffered_spawn_pos := false
	var _has_buffered_restore := false
	var _buffered_restore: Array = []
	var _has_buffered_appearance := false
	var _buffered_appearance: Array = []
	var _buffered_spawn_pos := Vector3.ZERO
	var _buffered_spawn_died := false
	func get_my_id() -> int:
		return 2

class TestWorld extends MainScript:
	var _gen_done := false
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
		_create_environment()
		_create_day_night()
		await _create_map()
		_gen_done = true
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

var failures := 0
var world: TestWorld

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func inject_sync() -> void:
	print("[TEST] injecting sync_world_state mid-gen")
	var depleted: Array = ["house_loot_43", "house_loot_45", "house_loot_46", "house_loot_6", "house_loot_7", "house_loot_8"]
	var drops: Array = [
		{"id": "death_loot_1296638_0", "name": "Camiseta", "type": "clothing", "weight": 0.3, "qty": 1, "use": 0.05, "pos": [-16.6934, 0.0558, 31.4227], "color": [0.3, 0.4, 0.6, 1.0]},
		{"id": "death_loot_1296640_1", "name": "Pantalones", "type": "clothing", "weight": 0.5, "qty": 1, "use": 0.10, "pos": [-17.2499, 0.0558, 32.6096], "color": [0.15, 0.12, 0.1, 1.0]},
	]
	world._net_sync_world_state(depleted, drops, [], [], [], [])

func run() -> void:
	var fake_net := FakeNet.new()
	fake_net.name = "NetworkManager"
	root.add_child(fake_net)

	world = TestWorld.new()
	root.add_child(world)
	current_scene = world
	# Simulate the server's sync arriving ~2s after connect, mid-generation
	create_timer(2.0).timeout.connect(inject_sync)

	# Wait for map generation to finish (bounded)
	var waited := 0.0
	while not world._gen_done and waited < 900.0:
		await create_timer(1.0).timeout
		waited += 1.0
	print("[TEST] gen done after ~%.0fs" % waited)

	check(world._gen_done, "map generation completed")
	var d0 := "death_loot_1296638_0"
	var d1 := "death_loot_1296640_1"
	check(world.world_actions_by_id.has(d0), "death drop action 0 registered")
	check(world.world_actions_by_id.has(d1), "death drop action 1 registered")
	var p0 := world.get_node_or_null("Pickup_" + d0)
	var p1 := world.get_node_or_null("Pickup_" + d1)
	check(p0 != null, "death drop visual 0 exists")
	check(p1 != null, "death drop visual 1 exists")
	if p0 != null:
		print("  pickup0 visible=%s pos=%s" % [str(p0.visible), str(p0.global_position)])
		check(p0.visible, "death drop visual 0 visible")
	for hid in ["house_loot_43", "house_loot_45", "house_loot_46"]:
		check(not world.world_actions_by_id.has(hid), "depleted %s not spawned" % hid)
	var spawned_loot := 0
	for k in world.world_actions_by_id.keys():
		if str(k).begins_with("house_loot_"):
			spawned_loot += 1
	print("[TEST] house_loot actions spawned: %d" % spawned_loot)
	check(spawned_loot > 0, "some house loot spawned")

	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
