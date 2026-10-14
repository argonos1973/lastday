extends RefCounted
## Skinned autumn civilian clothing adapted from Ren Viro Store's CC-BY FBX.

const DIRECTORY := "res://assets/characters/adapted/civil/"
const VARIANTS := {
	"Chaqueta de otoño": "autumn_jacket",
	"Chaqueta militar digital": "digital_field_jacket",
	"Pantalones de senderismo": "autumn_pants",
	"Pantalones cargo con rodilleras": "cargo_kneepad_pants",
	"Botas de montaña": "autumn_boots",
	"Gorro de otoño": "autumn_hat",
}

static func pickup_path(item_name: String) -> String:
	var variant: String = VARIANTS.get(item_name, "")
	return DIRECTORY + "pickup_" + variant + ".glb" if not variant.is_empty() else ""

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func attach(character: Node3D, item_name: String) -> MeshInstance3D:
	var asset: String = VARIANTS.get(item_name, "")
	if character == null or asset.is_empty():
		return null
	var destination := _find_skeleton(character)
	var packed := load(DIRECTORY + asset + ".glb") as PackedScene
	if destination == null or packed == null:
		return null
	var source := packed.instantiate()
	var source_skeleton := _find_skeleton(source)
	var source_mesh: MeshInstance3D
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var candidate := node as MeshInstance3D
		if candidate.skin != null:
			source_mesh = candidate
			break
	if source_skeleton == null or source_mesh == null:
		source.free()
		return null
	var skin := source_mesh.skin.duplicate() as Skin
	for bind in range(skin.get_bind_count()):
		var bone_name := skin.get_bind_name(bind)
		if bone_name.is_empty() and skin.get_bind_bone(bind) >= 0:
			bone_name = source_skeleton.get_bone_name(skin.get_bind_bone(bind))
		var destination_bone := destination.find_bone(bone_name)
		if destination_bone < 0:
			push_error("Autumn clothing bone missing: " + bone_name)
			source.free()
			return null
		skin.set_bind_bone(bind, destination_bone)
		skin.set_bind_name(bind, bone_name)
	var garment := MeshInstance3D.new()
	garment.name = asset
	garment.mesh = source_mesh.mesh
	garment.skin = skin
	garment.transform = source_mesh.transform
	garment.visible = false
	destination.add_child(garment)
	garment.skeleton = garment.get_path_to(destination)
	source.free()
	return garment

## HeadMesh also contains upper-shoulder faces from inicio.glb. Occlude those
## under the coat instead of inflating its shoulders. Resources remain per-node
## and the original head is restored exactly on unequip.
static func set_jacket_mask(character: Node3D, enabled: bool) -> void:
	if character == null:
		return
	var head := character.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return
	if not enabled:
		if head.has_meta("autumn_original_head"):
			head.mesh = head.get_meta("autumn_original_head") as Mesh
		return
	if not head.has_meta("autumn_original_head"):
		head.set_meta("autumn_original_head", head.mesh)
	if not head.has_meta("autumn_masked_head"):
		var source := head.get_meta("autumn_original_head") as Mesh
		var masked := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex in vertices.size(): indices.append(vertex)
			var kept := PackedInt32Array()
			for offset in range(0, indices.size(), 3):
				var center := (vertices[indices[offset]] + vertices[indices[offset+1]] + vertices[indices[offset+2]])/3.0
				# Keep the face and central neck; only mask covered shoulders.
				if center.y < 3.19 or (center.y < 3.24 and absf(center.x) > .14):
					continue
				kept.append(indices[offset])
				kept.append(indices[offset+1])
				kept.append(indices[offset+2])
			if kept.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = kept
			masked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			masked.surface_set_material(masked.get_surface_count()-1, source.surface_get_material(surface))
		head.set_meta("autumn_masked_head", masked)
	head.mesh = head.get_meta("autumn_masked_head") as Mesh
