extends SceneTree

func bounds_of(node: Node, frame := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var stack: Array = [[node, frame]]
	var first := true
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var current: Node = entry[0]
		var transform: Transform3D = entry[1]
		if current is Node3D:
			transform *= current.transform
		if current is MeshInstance3D and current.mesh != null:
			var box: AABB = transform * current.get_aabb()
			result = box if first else result.merge(box)
			first = false
		for child in current.get_children():
			stack.append([child, transform])
	return result

func _initialize() -> void:
	var factory = load("res://scripts/MaterialFactory.gd")
	for kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots"]:
		var material = factory.make_clothing_material(kind, Color(0.3, 0.4, 0.5))
		for texture in [material.albedo_texture, material.normal_texture, material.roughness_texture, material.ao_texture, material.heightmap_texture]:
			if texture == null or texture.get_width() != 2048:
				push_error("Missing 2K map for " + kind)
				quit(1)
				return
	var original = load("res://assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb").instantiate()
	var detailed = load("res://assets/characters/adapted/backpack_detailed.glb").instantiate()
	var old_bounds := bounds_of(original)
	var new_bounds := bounds_of(detailed)
	var tolerance: float = old_bounds.size.length() * 0.001
	var valid := old_bounds.size.distance_to(new_bounds.size) < tolerance and old_bounds.position.distance_to(new_bounds.position) < tolerance
	original.free()
	detailed.free()
	if not valid:
		push_error("Backpack bounds changed: %s -> %s" % [old_bounds, new_bounds])
		quit(1)
		return
	print("PASS: six complete 2K garment materials; backpack dimensions and origin preserved")
	quit()
