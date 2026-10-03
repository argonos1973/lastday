extends RefCounted

# These character meshes contain baked bind-pose coordinates. Use only the
# scalp, never whole-body bounds (arms, footwear and export helpers vary).
static func fit(model: Node3D, hat: Node3D) -> bool:
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return false
	var parent := hat.get_parent() as Node3D
	if parent == null:
		return false
	var head_bounds := head.get_aabb()
	var scalp := upper_bounds(head, Transform3D.IDENTITY, head_bounds.end.y - head_bounds.size.y * 0.34)
	if scalp.size.x <= 0.001 or scalp.size.z <= 0.001:
		return false
	hat.transform = Transform3D.IDENTITY
	var raw := AABB()
	var first := true
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		var frame: Transform3D = hat.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = frame * mesh.get_aabb()
		raw = bounds if first else raw.merge(bounds)
		first = false
	if first or raw.size.y <= 0.001:
		return false
	# Measure the crown above the brim, so brim width cannot determine head fit.
	var crown := AABB()
	first = true
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		var frame: Transform3D = hat.global_transform.affine_inverse() * mesh.global_transform
		var bounds := upper_bounds(mesh, frame, raw.position.y + raw.size.y * 0.45)
		if bounds.size.length_squared() == 0.0:
			continue
		crown = bounds if first else crown.merge(bounds)
		first = false
	if first or crown.size.x <= 0.001 or crown.size.z <= 0.001:
		return false
	var padding := head_bounds.size.y * 0.035
	var scale_x := (scalp.size.x + padding) / crown.size.x
	var scale_z := (scalp.size.z + padding) / crown.size.z
	var hat_scale := Vector3(scale_x, sqrt(scale_x * scale_z), scale_z)
	var center := scalp.get_center()
	var crown_center := crown.get_center() * hat_scale
	# La posicion sale en espacio del HeadMesh (bind, +Y = up): hay que
	# componerla con el frame correcto, no escribirla directa en el padre.
	var origin_in_head := Vector3(center.x - crown_center.x,
		head_bounds.end.y + head_bounds.size.y * 0.10 - raw.end.y * hat_scale.y,
		center.z - crown_center.z)
	var in_head := Transform3D(Basis.from_scale(hat_scale), origin_in_head)
	# La composicion mesh->padre debe seguir la ruta del skinning
	# (bone_rest * bind_pose), no la cadena de nodos: el Armature lleva
	# escala 0.01 y rotacion -90°X que los vertices skinneados no heredan
	# — anclar via head.global_transform dejaba el sombrero ~100x desplazado
	# o girado 90° respecto a la cabeza renderizada.
	hat.transform = _head_frame(model, head, parent) * in_head
	_tuck_hair(model, origin_in_head.y + raw.position.y * hat_scale.y + head_bounds.size.y * 0.02)
	return true

static func restore_hair(model: Node3D) -> void:
	for hair in model.find_children("Hair", "MeshInstance3D", true, false):
		if hair.has_meta("headwear_original_mesh"):
			hair.mesh = hair.get_meta("headwear_original_mesh")
			hair.remove_meta("headwear_original_mesh")

static func _tuck_hair(model: Node3D, brim_height: float) -> void:
	for hair in model.find_children("Hair", "MeshInstance3D", true, false):
		if hair.mesh == null:
			continue
		# Preserve skinning, materials and the original shared asset. Only this
		# character's upper hair is compressed under the brim while wearing it.
		if not hair.has_meta("headwear_original_mesh"):
			hair.set_meta("headwear_original_mesh", hair.mesh)
		var original: Mesh = hair.get_meta("headwear_original_mesh")
		var tucked := ArrayMesh.new()
		for surface in range(original.get_surface_count()):
			var arrays := original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			for index in range(vertices.size()):
				if vertices[index].y > brim_height:
					vertices[index].y = brim_height + (vertices[index].y - brim_height) * 0.02
			arrays[Mesh.ARRAY_VERTEX] = vertices
			tucked.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
			tucked.surface_set_material(surface, original.surface_get_material(surface))
		hair.mesh = tucked

static func _head_frame(model: Node3D, head_mi: MeshInstance3D, parent: Node3D) -> Transform3D:
	var fallback: Transform3D = parent.global_transform.affine_inverse() * head_mi.global_transform
	var skeleton := _find_skeleton(model)
	if skeleton == null or head_mi.skin == null:
		return fallback
	var bone_idx := -1
	for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head", "head", "Cabeza"]:
		bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			break
	if bone_idx < 0:
		return fallback
	var skin := head_mi.skin
	var bind := Transform3D.IDENTITY
	var found := false
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == bone_idx or String(skin.get_bind_name(i)) == skeleton.get_bone_name(bone_idx):
			bind = skin.get_bind_pose(i)
			found = true
			break
	if not found:
		return fallback
	return parent.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone_idx) * bind

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func upper_bounds(mesh: MeshInstance3D, frame: Transform3D, cutoff: float) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in range(mesh.mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := frame * vertex
			if point.y < cutoff:
				continue
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	return bounds
