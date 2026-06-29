extends SceneTree

func _ready() -> void:
	var path := "res://assets/characters/adapted/player_with_clothes.glb"
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
	_print_meshes(scene, "")
	quit()

func _print_meshes(node: Node, indent: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		print(indent, "MESH: ", mi.name, " visible=", mi.visible, " size=", aabb.size, " pos=", mi.position)
	elif node is Skeleton3D:
		print(indent, "SKELETON: ", node.name, " bones=", node.get_bone_count())
	elif node is Node3D:
		print(indent, "NODE3D: ", node.name, " pos=", node.position, " scale=", node.scale)
	for c in node.get_children():
		_print_meshes(c, indent + "  ")
