extends SceneTree

# Determinism check: generate the world twice in separate runs and dump every
# loot action id -> item name. If the lists differ between processes, client
# world gen is not deterministic across sessions (the reported bug).

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
		await _create_map()
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
	var out := FileAccess.open("user://loot_dump.txt", FileAccess.WRITE)
	for k in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[k]
		if a != null and a.has_meta("item_name"):
			out.store_line("%s|%s|%s" % [str(k), str(a.get_meta("item_name")), str(a.global_position)])
	out.close()
	print("[TEST] dumped %d actions to user://loot_dump.txt" % world.world_actions_by_id.size())
	quit(0)
