extends SceneTree
## Crowded-world fallback selection: distant props must not affect reach,
## tree-order ties, facing, height or the line-of-sight check.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func target(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = at
	node.add_to_group("interactable")
	return node
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var ray := InteractionRaycast.new()
	player.add_child(ray)
	# Nested distant doors/beds, like the persistent city interior anchors.
	for i in 1200:
		var branch := Node3D.new()
		world.add_child(branch)
		target(branch, Vector3(80 + i % 40, 0, -80 - i / 40))
	var first := target(world, Vector3(0, 0, -.4))
	var last := target(world, Vector3(0, 0, -.4))
	target(world, Vector3(0, 3.9, -.1))
	target(world, Vector3(0, 0, .2))
	check(ray._find_nearest_interactable(player) == first, "equal-distance tie keeps tree order")
	first.free()
	check(ray._find_nearest_interactable(player) == last, "cached freed target is safely skipped")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, .1)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(0, 1, -.2)
	await physics_frame
	await physics_frame
	check(ray._find_nearest_interactable(player) == null, "wall blocks nearby fallback interaction")
	wall.free()
	last.free()
	var wide := Area3D.new()
	var wide_shape := CollisionShape3D.new()
	var wide_box := BoxShape3D.new()
	wide_box.size = Vector3(6, 1, 6)
	wide_shape.shape = wide_box
	wide.add_child(wide_shape)
	world.add_child(wide)
	wide.position = Vector3(0, 0, -3)
	wide.add_to_group("interactable")
	ray._interactable_cache_timer = -1
	await physics_frame
	check(ray._find_nearest_interactable(player) == wide, "large furniture keeps its padded reach")
	var started := Time.get_ticks_usec()
	for i in 100:
		check(ray._find_nearest_interactable(player) == wide, "stable selection with 1200 distant props")
	var shelter := WorldAction.new()
	world.add_child(shelter)
	shelter.setup("shelter_fallback", "shelter", "Refugio", Vector3(2.0, 1.5, 3.0), Color.WHITE, true, false)
	shelter.global_position = Vector3(0, 0, -1.4)
	await physics_frame
	check(ray._find_nearest_interactable(player) == shelter, "nearby shelter enters fallback selection")
	print("INTERACTION_RAYCAST failures=", failures, " mean_query_ms=", (Time.get_ticks_usec() - started) / 100000.0)
	world.free()
	quit(1 if failures else 0)
