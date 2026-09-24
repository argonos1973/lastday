extends SceneTree

# Reproduces the reported bug: a death drop inside a house renders below the
# house floor. The dedicated server never builds houses, so a proxy standing
# "inside" one records terrain height (~0.056), and the synced drop snaps its
# bottom to that y — while the client-side floor top sits at y=0.08.

const MainScript = preload("res://scripts/Main.gd")
const NodeUtils = preload("res://scripts/NodeUtils.gd")

class TestNet extends Node:
	var is_host := false
	var is_connected := true
	var is_dedicated_server := false
	var peer = null
	var client_id := "drop_floor_client"
	var players: Dictionary = {}
	func get_my_id() -> int:
		return 2

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _get_exact_ground_y(_x: float, _z: float, _d: float = 0.0) -> float:
		return 0.0

var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func lowest_y(node: Node) -> float:
	var meshes: Array = []
	NodeUtils.collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.force_update_transform()
		var a := mi.global_transform * mi.get_aabb()
		min_y = minf(min_y, a.position.y)
	return min_y

func highest_y(node: Node) -> float:
	var meshes: Array = []
	NodeUtils.collect_mesh_instances(node, meshes)
	var max_y := -1000000.0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.force_update_transform()
		var a := mi.global_transform * mi.get_aabb()
		max_y = maxf(max_y, a.position.y + a.size.y)
	return max_y

func run() -> void:
	var world: Node = TestWorld.new()
	root.add_child(world)
	var network := TestNet.new()
	world.add_child(network)
	world.net = network

	# Build the real house floor exactly as _create_house does (top at 0.08)
	var origin := Vector3(-20, 0, 30)
	world._create_house_floor(origin, "Casa abandonada 10", 7.5, 6.5)

	# Spawn the real drop visual for the saved death-loot entries
	var drop_pos := Vector3(-16.69, 0.0558, 31.42)
	world._spawn_dropped_item_visual("death_loot_1296638_0", "Camiseta", "clothing", 0.3, 1, 0.05, drop_pos, Color(0.3, 0.4, 0.6))
	var pickup := world.get_node_or_null("Pickup_death_loot_1296638_0")
	check(pickup != null, "drop visual node exists")
	if pickup != null:
		var top := highest_y(pickup)
		var bottom := lowest_y(pickup)
		print("drop visual bottom=%.4f top=%.4f (floor top=0.08)" % [bottom, top])
		check(top > 0.08, "drop visual renders ABOVE house floor top (y=0.08)")
	# The interactable action must also exist for pickup
	check(world.world_actions_by_id.has("death_loot_1296638_0"), "drop world action registered")

	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
