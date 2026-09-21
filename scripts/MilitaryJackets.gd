extends RefCounted

const DIRECTORY := "res://assets/characters/adapted/jackets/"
const VARIANTS := {
	"Chaqueta de campaña verde": "olive",
	"Chaqueta de campaña azul": "navy",
	"Chaqueta de campaña arena": "sand",
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
	var source_mesh := meshes[0] as MeshInstance3D
	if source_mesh.skin == null:
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
