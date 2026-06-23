extends RefCounted
class_name SimpleObjLoader

func load_node3d(path: String, color := Color(0.8, 0.78, 0.68)) -> Node3D:
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var file := FileAccess.open(disk_path, FileAccess.READ)
	if file == null:
		return null
	var positions: Array[Vector3] = []
	var vertices := PackedVector3Array()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		if parts[0] == "v" and parts.size() >= 4:
			positions.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
		elif parts[0] == "f" and parts.size() >= 4:
			var face_indices: Array[int] = []
			for i in range(1, parts.size()):
				var token := str(parts[i])
				var raw_index := int(token.split("/")[0])
				if raw_index < 0:
					raw_index = positions.size() + raw_index + 1
				face_indices.append(raw_index - 1)
			for i in range(1, face_indices.size() - 1):
				_add_face_vertex(vertices, positions, face_indices[0])
				_add_face_vertex(vertices, positions, face_indices[i])
				_add_face_vertex(vertices, positions, face_indices[i + 1])
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = path.get_file().get_basename()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color)
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	root.add_child(mesh_instance)
	return root

func _add_face_vertex(vertices: PackedVector3Array, positions: Array[Vector3], index: int) -> void:
	if index >= 0 and index < positions.size():
		vertices.append(positions[index])

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material
