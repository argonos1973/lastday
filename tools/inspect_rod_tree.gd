extends SceneTree

func _init():
	_inspect("res://assets/models/props/cana_de_pescar.glb")
	quit()

func _inspect(path: String) -> void:
	print("\n=== Inspecting: ", path, " ===")
	if not ResourceLoader.exists(path):
		print("File not found: ", path)
		return
	var glb = load(path)
	if glb is PackedScene:
		var inst = glb.instantiate()
		_dump(inst, 0)
		inst.queue_free()
	else:
		print("Not a PackedScene: ", glb)

func _dump(node: Node, depth: int) -> void:
	var indent := ""
	for i in range(depth):
		indent += "  "
	var extra := ""
	if node is Node3D:
		var n3d := node as Node3D
		extra += " pos=%s rot_deg=%s scale=%s visible=%s" % [n3d.position, n3d.rotation_degrees, n3d.scale, n3d.visible]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			extra += " AABB=%s" % [mi.get_aabb()]
			extra += " skeleton_path=%s" % [mi.skeleton]
	if node is Skeleton3D:
		var sk := node as Skeleton3D
		extra += " bone_count=%d" % [sk.get_bone_count()]
	print(indent, node.name, " [", node.get_class(), "]", extra)
	for c in node.get_children():
		_dump(c, depth + 1)
