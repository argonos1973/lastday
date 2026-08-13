extends SceneTree

func _init():
	_inspect("res://exported-model.glb", true)
	_inspect("res://torch_stick.glb", false)
	quit()

func _inspect(path: String, show_all_bones: bool) -> void:
	print("\n=== Inspecting: ", path, " ===")
	if not ResourceLoader.exists(path):
		print("File not found: ", path)
		return
	var glb = load(path)
	if glb is PackedScene:
		var inst = glb.instantiate()
		_print_tree(inst, 0, show_all_bones)
		inst.queue_free()
	else:
		print("Not a PackedScene: ", glb)

func _print_tree(node, depth = 0, show_all_bones = false):
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")")
	if node is MeshInstance3D:
		var aabb = node.get_aabb()
		print("  ".repeat(depth + 1), "AABB pos=", aabb.position, " size=", aabb.size)
	if node is Skeleton3D:
		var count = node.get_bone_count()
		print("  ".repeat(depth + 1), "Bones: ", count)
		var limit = count if show_all_bones else mini(count, 10)
		for i in range(limit):
			print("  ".repeat(depth + 2), "Bone ", i, ": ", node.get_bone_name(i))
	for c in node.get_children():
		_print_tree(c, depth + 1, show_all_bones)
