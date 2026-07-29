extends SceneTree

func _init():
	print("=== TEST WOLF SCALE ===")
	var wolf: Node3D = load("res://assets/external/wolf/WolfAnimated.glb").instantiate()
	root.add_child(wolf)
	await process_frame
	
	var meshes := []
	_collect_meshes(wolf, meshes)
	var min_y := 1000000.0
	var max_y := -1000000.0
	for m in meshes:
		var mi = m as MeshInstance3D
		var aabb = mi.get_aabb()
		min_y = min(min_y, aabb.position.y)
		max_y = max(max_y, aabb.position.y + aabb.size.y)
		print("Mesh: ", mi.name, " aabb=", aabb)
	
	print("Wolf total height=", max_y - min_y)
	print("Wolf target_height=1.2, scale=", 1.2 / (max_y - min_y))
	print("Wolf scaled height=", 1.2)
	
	wolf.queue_free()
	await process_frame
	quit()

func _collect_meshes(node, result):
	if node is MeshInstance3D:
		result.append(node)
	for c in node.get_children():
		_collect_meshes(c, result)
