extends RefCounted

const DIRECTORY := "res://assets/characters/adapted/jackets/"
const VARIANTS := {
	"Chaqueta de campaña verde": "olive",
	"Chaqueta de campaña azul": "navy",
	"Chaqueta de campaña arena": "sand",
	"Chaqueta de cuadros": "plaid",
	"Chaleco táctico": "plate_carrier",
}

static func pickup_path(item_name: String) -> String:
	var variant: String = VARIANTS.get(item_name, "")
	return DIRECTORY + "pickup_jacket_" + variant + ".glb" if not variant.is_empty() else ""

static func skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := skeleton_in(child)
		if result != null:
			return result
	return null

static func attach(character: Node3D, item_name: String) -> MeshInstance3D:
	var variant: String = VARIANTS.get(item_name, "")
	if character == null or variant.is_empty():
		return null
	var destination := skeleton_in(character)
	if destination == null:
		return null
	var scene: PackedScene = load(DIRECTORY + "military_jacket_" + variant + ".glb")
	if scene == null:
		return null
	var source := scene.instantiate()
	var source_skeleton := skeleton_in(source)
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	if source_skeleton == null or meshes.is_empty():
		source.free()
		return null
	# The exported GLBs carry helper meshes (e.g. the character's icosphere
	# bounds marker) that have no skin — only a skinned mesh can be attached.
	var source_mesh: MeshInstance3D = null
	for candidate in meshes:
		if (candidate as MeshInstance3D).skin != null:
			source_mesh = candidate
			break
	if source_mesh == null:
		source.free()
		return null
	var skin := source_mesh.skin.duplicate() as Skin
	for bind in range(skin.get_bind_count()):
		var bone_name := skin.get_bind_name(bind)
		if bone_name.is_empty() and skin.get_bind_bone(bind) >= 0:
			bone_name = source_skeleton.get_bone_name(skin.get_bind_bone(bind))
		var destination_bone := destination.find_bone(bone_name)
		if destination_bone < 0:
			push_error("Jacket bone missing: " + str(bone_name))
			source.free()
			return null
		skin.set_bind_bone(bind, destination_bone)
		skin.set_bind_name(bind, bone_name)
	var jacket := MeshInstance3D.new()
	jacket.name = "field_jacket_" + variant
	jacket.mesh = source_mesh.mesh
	jacket.skin = skin
	jacket.transform = source_mesh.transform
	jacket.visible = false
	destination.add_child(jacket)
	jacket.skeleton = jacket.get_path_to(destination)
	source.free()
	return jacket

static func fit_legacy_hem(mesh: MeshInstance3D) -> void:
	if mesh == null or mesh.mesh == null or mesh.has_meta("hem_fitted"):
		return
	# Source torso ends above the default trousers; extend only the lower
	# 40 cm of its bind-space hem, retaining all skin weights and UVs.
	var source := mesh.mesh
	var bottom := source.get_aabb().position.y
	var fitted := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for index in range(vertices.size()):
			var blend := 1.0 - smoothstep(bottom, bottom + 0.4, vertices[index].y)
			vertices[index].y -= 0.20 * blend
		arrays[Mesh.ARRAY_VERTEX] = vertices
		fitted.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, source.surface_get_format(surface))
		fitted.surface_set_material(surface, source.surface_get_material(surface))
	mesh.mesh = fitted
	mesh.set_meta("hem_fitted", true)
