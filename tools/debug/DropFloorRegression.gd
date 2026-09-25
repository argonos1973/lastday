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
	# Let the floor collider register in the physics space
	await physics_frame
	await physics_frame

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
		check(bottom >= 0.07, "drop visual rests ON the house floor, not under it")
	# The interactable action must also exist for pickup
	check(world.world_actions_by_id.has("death_loot_1296638_0"), "drop world action registered")
	var floor_action = world.world_actions_by_id.get("death_loot_1296638_0")
	check(floor_action != null and absf(floor_action.position.y - 0.08) < 0.02, "drop action snapped to house floor height")

	# A drop emitted at player height over open terrain must land on the ground
	# — before the fix it kept the player's y and floated in the air.
	var air_pos := Vector3(50.0, 5.0, 50.0)
	world._spawn_dropped_item_visual("drop_air_0", "Palo", "resource", 0.3, 1, 0.0, air_pos)
	var air_action = world.world_actions_by_id.get("drop_air_0")
	check(air_action != null and air_action.position.y < 0.5, "elevated drop snaps down to terrain")
	var air_pickup := world.get_node_or_null("Pickup_drop_air_0")
	if air_pickup != null:
		print("air drop visual bottom=%.4f" % lowest_y(air_pickup))
		check(lowest_y(air_pickup) < 0.5, "elevated drop visual lands near terrain")

	# Ground pickups must follow the same correction (bush sticks, death loot)
	var pickup_pos := Vector3(60.0, 4.0, 60.0)
	world._spawn_ground_pickup("Palo", "resource", pickup_pos, 0.3, 1, 0.0, "pickup_air_0")
	var gp_action = world.world_actions_by_id.get("pickup_air_0")
	check(gp_action != null and gp_action.position.y < 0.5, "ground pickup snaps down to terrain")

	# Tall non-walkable colliders (tree trunks are 6m cylinders in layer 1) must
	# not count as ground — otherwise drops land floating on their invisible top.
	var trunk := StaticBody3D.new()
	trunk.name = "FakeTrunkCol"
	trunk.collision_layer = 1
	trunk.collision_mask = 1
	var trunk_col := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 6.0
	trunk_col.shape = trunk_shape
	trunk_col.position = Vector3(70.0, 3.0, 70.0)
	trunk.add_child(trunk_col)
	trunk.add_to_group("prop_collision")
	world.add_child(trunk)
	var trunk2 := StaticBody3D.new()
	trunk2.name = "FakeTrunkColOldBehaviour"
	trunk2.collision_layer = 1
	trunk2.collision_mask = 1
	var trunk2_col := CollisionShape3D.new()
	trunk2_col.shape = trunk_shape
	trunk2_col.position = Vector3(80.0, 3.0, 80.0)
	trunk2.add_child(trunk2_col)
	world.add_child(trunk2)
	await physics_frame
	await physics_frame
	var grouped_y: float = world._get_exact_ground_y(70.0, 70.0, 10.0)
	var ungrouped_y: float = world._get_exact_ground_y(80.0, 80.0, 10.0)
	print("trunk-top raycast grouped=%.2f ungrouped=%.2f" % [grouped_y, ungrouped_y])
	check(grouped_y < 1.0, "prop_collision trunk top is ignored by ground raycast")
	check(ungrouped_y > 5.0, "control trunk without prop_collision still blocks the ray")

	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
