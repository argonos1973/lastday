extends SceneTree

func _init():
	print("=== TEST REMY MESH CONTENT ===")
	var remy: Node3D = load("res://assets/characters/Remy.glb").instantiate()
	root.add_child(remy)
	await process_frame
	
	var meshes := []
	_collect_meshes(remy, meshes)
	for m in meshes:
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		var mesh_res := mi.mesh
		var vert_count := 0
		var bone_names := []
		if mesh_res != null and mesh_res.get_surface_count() > 0:
			var arrays := mesh_res.surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				vert_count = arrays[Mesh.ARRAY_VERTEX].size()
			if arrays.size() > Mesh.ARRAY_BONES:
				var bones_arr = arrays[Mesh.ARRAY_BONES]
				var unique_bones := {}
				for b in bones_arr:
					unique_bones[b] = true
				var skel := _find_skeleton(remy)
				if skel != null:
					for bone_id in unique_bones.keys():
						if bone_id >= 0 and bone_id < skel.get_bone_count():
							bone_names.append(skel.get_bone_name(bone_id))
		print("Mesh: ", mi.name, " aabb=", aabb, " verts=", vert_count)
		if bone_names.size() > 0:
			print("  bones: ", bone_names)
	
	remy.queue_free()
	await process_frame
	quit()

func _collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for c in node.get_children():
		_collect_meshes(c, result)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null
