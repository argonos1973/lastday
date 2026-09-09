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
		var acc := {"aabb": AABB()}
		_collect_aabb(inst, Transform3D.IDENTITY, acc)
		var a: AABB = acc["aabb"]
		print("Combined AABB pos=", a.position, " size=", a.size)
		inst.queue_free()
	else:
		print("Not a PackedScene: ", glb)

func _collect_aabb(node: Node, xform: Transform3D, acc: Dictionary) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
		var world_aabb: AABB = xform * mesh_aabb
		var cur: AABB = acc["aabb"]
		if cur.size == Vector3.ZERO:
			acc["aabb"] = world_aabb
		else:
			acc["aabb"] = cur.merge(world_aabb)
	for c in node.get_children():
		_collect_aabb(c, xform, acc)
