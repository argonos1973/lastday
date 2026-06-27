extends SceneTree
# Prints the baked AABB (size + min.y) of each survival clothing pickup glb so we
# can confirm they are laid flat (small Y height) and pick sensible world scales.

func _init() -> void:
	for n in ["pickup_cloth_torso", "pickup_cloth_legs", "pickup_cloth_feet"]:
		var path := "res://assets/characters/adapted/%s.glb" % n
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_buffer(FileAccess.get_file_as_bytes(path), "", state) != OK:
			print("FAIL ", n); continue
		var root := doc.generate_scene(state)
		var aabb := AABB()
		var first := true
		var stack: Array = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var a := (node as MeshInstance3D).get_aabb()
				if first:
					aabb = a; first = false
				else:
					aabb = aabb.merge(a)
			for c in node.get_children():
				stack.append(c)
		print("OK ", n, " size=", aabb.size, " min.y=", aabb.position.y)
	quit()
