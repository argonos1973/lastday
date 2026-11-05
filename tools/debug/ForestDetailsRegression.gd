extends SceneTree
const WorldTest = preload("res://tools/debug/NaturalGroundCoverRegression.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var errors := 0
	for mesh in [preload("res://scripts/ForestUnderstory.gd").bramble_mesh(),preload("res://scripts/ForestDeadwood.gd").mesh()]:
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if not vertex.is_finite(): errors += 1
	var world := WorldTest.TestWorld.new()
	root.add_child(world)
	world._world_rng.seed = 173
	var state := world._world_rng.state
	var trees: Array = []
	for x in range(100,250,3):
		for z in range(100,200,3): trees.append(Vector3(x,world._get_exact_ground_y(x,z),z))
	preload("res://scripts/ForestDeadwood.gd").build(world,trees)
	var count := 0
	for node in world.get_children():
		if not str(node.name).begins_with("ForestDeadwood_"): continue
		count += node.multimesh.instance_count
		for i in range(node.multimesh.instance_count):
			var transform: Transform3D = node.multimesh.get_instance_transform(i)
			var pos: Vector3 = node.position+transform.origin
			for t in [-1.2,0.0,1.2]:
				var point: Vector3 = pos+transform.basis.x*t
				if not world._can_place_ground_vegetation(point) or world._road_verge_growth(point)<.9: errors += 1
				if absf(point.y-world._get_exact_ground_y(point.x,point.z))>.09: errors += 1
	if count == 0 or world._world_rng.state != state: errors += 1
	print("FOREST_DETAILS errors=",errors," deadwood=",count)
	world.queue_free()
	await process_frame
	quit(0 if errors==0 else 1)
