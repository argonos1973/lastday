extends SceneTree

const Action = preload("res://scripts/WorldAction.gd")
const Graphics = preload("res://scripts/GraphicsSettings.gd")
var failures := 0
var checks := 0

class World extends "res://scripts/Main.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass

class TickAction extends "res://scripts/WorldAction.gd":
	var ticks := 0
	var elapsed := 0.0
	func tick_growth(delta: float, _moist_rate := 1.0):
		ticks += 1
		elapsed += delta

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize(): call_deferred("run")

func add_action(world, id: String, type: String) -> TickAction:
	var node := TickAction.new()
	node.setup(id, type, id, Vector3(1, 2, 3), Color.BROWN, false, false)
	world.add_child(node)
	world.world_actions_by_id[id] = node
	return node

func legacy_tick(world):
	# Previous exhaustive dispatcher, on exactly the same nodes as the new one.
	for action in world.world_actions_by_id.values():
		if action != null and action.has_method("tick_growth"):
			action.tick_growth(0.5)

func benchmark(callable: Callable) -> float:
	var times: Array[float] = []
	for repeat in range(9):
		var started := Time.get_ticks_usec()
		for i in range(15): callable.call()
		times.append(float(Time.get_ticks_usec() - started) / 15.0)
	times.sort()
	return times[4]

func add_batch(world, position: Vector3, forest := false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = QuadMesh.new()
	world.add_child(node)
	if forest:
		world._forest_multimesh_nodes.append(node)
		world._forest_multimesh_centers.append(position)
		world._forest_multimesh_radii.append(0.0)
	else:
		world._grass_batch_nodes.append(node)
		world._grass_batch_centers.append(position)
		world._grass_batch_radii.append(0.0)
	return node

func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var inert := add_action(world, "inert", "pickup_item")
	check(inert._mesh_instance == null and inert.get_child_count() == 1, "Pickups allocate only their interaction collider")
	check(inert._collision.shape.size == Vector3(1, 2, 3) and inert._collision.position == Vector3(0, 1, 0), "Collider keeps its original dimensions and offset")
	check(inert.is_in_group("interactable") and inert.is_in_group("world_actions"), "Pickup remains registered for interaction")
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 6), Vector3(0, 1, 0))
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider") == inert, "Interaction ray still hits the pickup without its hidden mesh")
	inert._ensure_marker_mesh()
	var marker = inert._mesh_instance
	inert._ensure_marker_mesh()
	check(inert._mesh_instance == marker and inert.get_child_count() == 2, "Fallback marker is allocated once on demand")
	check(marker.mesh.size == Vector3(1, 2, 3) and marker.material_override.albedo_color == Color.BROWN, "Fallback preserves size and color")
	var farm := add_action(world, "farm", "farm_plot")
	var meat := add_action(world, "meat", "wolf_meat_raw")
	check(inert._collision.shape == farm._collision.shape and farm._collision.shape == meat._collision.shape, "Equal interaction boxes share one immutable shape")
	inert._collision.disabled = true
	check(not farm._collision.disabled and not meat._collision.disabled, "Disabling one collider does not disable the others")
	inert._collision.disabled = false
	world._tick_world_actions(0.5)
	check(inert.ticks == 0 and farm.ticks == 1 and meat.ticks == 1, "Only timed actions tick; ordinary loot is untouched")
	farm.action_type = "pickup_item"
	inert.action_type = "farm_plot"
	world._tick_world_actions(0.5)
	check(farm.ticks == 1 and inert.ticks == 1 and meat.ticks == 2, "Changing action type updates scheduler membership")
	check(is_equal_approx(meat.elapsed, 1.0), "Elapsed growth/decay time is preserved")
	inert.action_type = "fell_tree"
	check(inert.is_in_group(Action.TREE_GROUP) and not inert.is_in_group(Action.TICK_GROUP), "Tree fallback lookup uses its dedicated group")
	inert.action_type = "cut_log"
	check(not inert.is_in_group(Action.TREE_GROUP), "Felled tree leaves the tree lookup group")
	world.world_actions_by_id.erase("meat")
	world._tick_world_actions(0.5)
	check(meat.ticks == 2, "Unregistered actions do not keep ticking")
	world.world_actions_by_id["meat"] = meat
	world.remove_child(meat)
	world._tick_world_actions(0.5)
	check(meat.ticks == 2, "Unloaded actions do not tick")
	world.add_child(meat)
	world._tick_world_actions(0.5)
	check(meat.ticks == 3, "Re-entering the tree restores ticking")
	for kind in ["deer_meat_raw", "fox_meat_raw", "bird_meat_raw"]:
		meat.action_type = kind
		check(meat.is_in_group(Action.TICK_GROUP), "Decay remains scheduled for " + kind)
	var foreign := World.new()
	root.add_child(foreign)
	var other := add_action(foreign, "meat", "wolf_meat_raw")
	world._tick_world_actions(0.5)
	check(other.ticks == 0, "A second world's action with the same id is excluded")
	foreign.free()
	# A large loot registry should not add work to the half-second tick.
	for i in range(10000): add_action(world, "loot_%d" % i, "pickup_item")
	var previous_us := benchmark(func(): legacy_tick(world))
	var current_us := benchmark(func(): world._tick_world_actions(0.5))
	print("WORLD_TICK_BENCH registry=", world.world_actions_by_id.size(), " previous_us=", previous_us, " current_us=", current_us)
	check(current_us < previous_us * 0.25, "Timed dispatch avoids the cost of 10000 inactive loot items")
	world.player = Node3D.new()
	world.add_child(world.player)
	var grass := add_batch(world, Vector3.ZERO)
	var tree := add_batch(world, Vector3.ZERO, true)
	world._update_grass_visibility()
	world._update_forest_visibility()
	check(grass.visible and tree.visible, "Nearby vegetation remains visible")
	world.player.position = Vector3(10000, 0, 10000)
	world._update_grass_visibility()
	world._update_forest_visibility()
	check(not grass.visible and not tree.visible and not world._grass_any_visible, "Movement still hides distant batches")
	var new_grass := add_batch(world, world.player.position)
	var new_tree := add_batch(world, world.player.position, true)
	new_grass.visible = false
	new_tree.visible = false
	world._update_grass_visibility()
	world._update_forest_visibility()
	check(new_grass.visible and new_tree.visible, "Batches added during loading update even while stationary")
	var saved_detail = Graphics._config().get_value("graphics", "detail", null)
	# Restore this in-memory setting below; never write the user's config file.
	Graphics._config().set_value("graphics", "detail", 0)
	world._update_grass_visibility()
	world._update_forest_visibility()
	check(world._grass_visibility_detail == Graphics.detail_factor() and world._forest_visibility_detail == Graphics.detail_factor(), "Live graphics changes invalidate cached visibility")
	if saved_detail == null:
		Graphics._config().erase_section_key("graphics", "detail")
	else:
		Graphics._config().set_value("graphics", "detail", saved_detail)
	var saved_shadow: int = world._shadow_quality
	world._shadow_quality = (saved_shadow + 1) % world.ShadowQuality.PRESETS.size()
	world._update_forest_visibility()
	check(world._forest_visibility_quality == world._shadow_quality, "Shadow quality changes apply without moving")
	world._shadow_quality = saved_shadow
	# Check return-to-near, altitude and grass LOD transitions after a cache hit.
	world.player.position = Vector3.ZERO
	world._update_grass_visibility()
	world._update_forest_visibility()
	check(grass.visible and tree.visible, "Returning to a previous location restores vegetation")
	world.player.position.y = 300
	world._update_forest_visibility()
	check(world._forest_visibility_focus.y == 300, "Mountain altitude still updates forest visibility radii")
	var near_mesh := QuadMesh.new()
	var far_mesh := QuadMesh.new()
	world._grass_batch_lod = [[near_mesh, far_mesh, 5.0], null]
	world.player.position.x = 0.1
	world._update_grass_visibility()
	check(grass.multimesh.mesh == near_mesh, "Near grass keeps its detailed mesh")
	world.player.position.x = 30
	world._update_grass_visibility()
	check(grass.multimesh.mesh == far_mesh, "Moving away still switches grass to its distant mesh")
	world.player.position.x = 0
	for i in range(1500): add_batch(world, Vector3(i, 0, i))
	world._update_grass_visibility()
	var forced_us := benchmark(func():
		world._grass_visibility_count = -1
		world._update_grass_visibility())
	var cached_us := benchmark(func(): world._update_grass_visibility())
	print("GRASS_VIS_BENCH batches=", world._grass_batch_nodes.size(), " full_us=", forced_us, " stationary_us=", cached_us)
	check(cached_us < forced_us * 0.25, "Stationary grass avoids traversing all batches")
	world.free()
	await process_frame
	print("ClientWorldWorkRegression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
