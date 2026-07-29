extends SceneTree

func _init():
	print("=== TEST REMY SCALE ===")
	var remy: Node3D = load("res://assets/characters/Remy.glb").instantiate()
	root.add_child(remy)
	await process_frame
	
	var skel: Skeleton3D = _find_skeleton(remy)
	if skel != null:
		var min_y := 1000000.0
		var max_y := -1000000.0
		for i in range(skel.get_bone_count()):
			var bn = skel.get_bone_name(i)
			var gp = skel.get_bone_global_pose(i)
			if bn.find("Foot") >= 0 or bn.find("Head") >= 0 or bn.find("Toe") >= 0:
				print("Bone ", bn, " global_y=", gp.origin.y)
				min_y = min(min_y, gp.origin.y)
				max_y = max(max_y, gp.origin.y)
		print("min_y=", min_y, " max_y=", max_y, " height=", max_y - min_y)
		print("scale for 1.75m=", 1.75 / (max_y - min_y))
		print("scale for 1.8m=", 1.8 / (max_y - min_y))
	
	# Also check AABB
	var meshes := []
	_collect_meshes(remy, meshes)
	var aabb_min_y := 1000000.0
	var aabb_max_y := -1000000.0
	for m in meshes:
		var mi = m as MeshInstance3D
		if mi.name == "Body":
			continue
		var aabb = mi.get_aabb()
		aabb_min_y = min(aabb_min_y, aabb.position.y)
		aabb_max_y = max(aabb_max_y, aabb.position.y + aabb.size.y)
	print("AABB (no Body) min_y=", aabb_min_y, " max_y=", aabb_max_y, " height=", aabb_max_y - aabb_min_y)
	print("AABB scale for 1.75m=", 1.75 / (aabb_max_y - aabb_min_y))
	
	remy.queue_free()
	await process_frame
	quit()

func _collect_meshes(node, result):
	if node is MeshInstance3D:
		result.append(node)
	for c in node.get_children():
		_collect_meshes(c, result)

func _find_skeleton(node):
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var s = _find_skeleton(c)
		if s != null:
			return s
	return null
