extends SceneTree
# Loads player_with_clothes.glb exactly like PlayerController._load_external_node3d
# (GLTFDocument runtime import) and reports skeleton + cloth/body mesh node names,
# so we can confirm the in-game survival-clothing path will find them.

func _init() -> void:
	var path := "res://assets/characters/adapted/player_with_clothes.glb"
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var err := doc.append_from_buffer(bytes, "", state)
	if err != OK:
		print("FAIL load err=", err)
		quit()
		return
	var root := doc.generate_scene(state)
	if root == null:
		print("FAIL generate_scene null")
		quit()
		return
	var skel := _find_skel(root)
	print("OK  skeleton=", skel.name if skel else "NONE", " bones=", skel.get_bone_count() if skel else -1)
	var meshes := []
	_collect(root, meshes)
	print("OK  MeshInstance3D nodes (", meshes.size(), "):")
	for m in meshes:
		print("    - '", m.name, "' visible=", m.visible)
	var wanted := ["cloth_torso", "cloth_legs", "cloth_hands", "cloth_feet", "Tops", "Bottoms", "Shoes", "Body"]
	for w in wanted:
		var found := false
		for m in meshes:
			if m.name == w:
				found = true
				break
		print(("OK  " if found else "FAIL") + "  expected node '" + w + "' present=" + str(found))
	quit()

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null

func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
