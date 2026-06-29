extends SceneTree

func _init() -> void:
	var path := "res://assets/adapted/soldado_parts.glb"
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_file(ProjectSettings.globalize_path(path), state)
	if err != OK:
		print("ERROR loading: ", err)
		quit()
		return
	var scene := gltf.generate_scene(state)
	if scene == null:
		print("ERROR: null scene")
		quit()
		return
	print("=== Scene: ", scene.name, " ===")
	_print_tree(scene, "")
	quit()

func _print_tree(node: Node, indent: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		var skin_str := "none"
		if mi.skin != null:
			skin_str = "yes(" + str(mi.skin.get_bind_count()) + " bones)"
		print(indent, "MESH: ", mi.name, " size=", aabb.size, " skin=", skin_str)
	elif node is Skeleton3D:
		print(indent, "SKELETON: ", node.name, " bones=", node.get_bone_count())
		for i in range(min(5, node.get_bone_count())):
			print(indent, "  bone[", i, "]: ", node.get_bone_name(i))
	elif node is Node3D:
		print(indent, "NODE3D: ", node.name, " pos=", node.position, " scale=", node.scale)
	for c in node.get_children():
		_print_tree(c, indent + "  ")
