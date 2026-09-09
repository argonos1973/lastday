extends SceneTree

func _init():
	_inspect("res://assets/models/props/cana_de_pescar.glb")
	quit()

func _inspect(path: String) -> void:
	print("\n=== Inspecting parts world AABB: ", path, " ===")
	if not ResourceLoader.exists(path):
		print("File not found: ", path)
		return
	var glb = load(path)
	if glb is PackedScene:
		var inst = glb.instantiate()
		_walk(inst, Transform3D.IDENTITY)
		inst.queue_free()
	else:
		print("Not a PackedScene: ", glb)

func _walk(node: Node, xform: Transform3D) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
		var world_aabb: AABB = xform * mesh_aabb
		var center := world_aabb.position + world_aabb.size * 0.5
		print(node.name, " world_center=", center, " world_aabb_pos=", world_aabb.position, " size=", world_aabb.size)
	for c in node.get_children():
		_walk(c, xform)
