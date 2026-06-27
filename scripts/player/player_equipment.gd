extends Node3D
class_name ClothingEquipment

## Runtime equipment controller for the adapted survival character.
##
## Loads player_with_clothes.glb (Mixamo rig + adapted clothing all sharing one
## Skeleton3D), then lets you:
##   * show/hide deformable clothing (toggles MeshInstance3D.visible) -- the
##     clothing deforms with every Mixamo animation because it is skinned to the
##     same skeleton. No BoneAttachment3D is used for clothing.
##   * attach/detach rigid gear (e.g. backpack) via a BoneAttachment3D bound to a
##     single bone.
##
## Follows the project convention of loading .glb at runtime with GLTFDocument
## (see PlayerController._load_external_node3d), so no editor (re)import needed.

signal cloth_changed(slot: String, equipped: bool)
signal gear_changed(slot: String, equipped: bool)

@export var model_path: String = ClothingEquipmentData.PLAYER_MODEL_PATH
## Auto-load + build on _ready. Disable if a parent controller drives setup().
@export var auto_setup: bool = true
## Equip every garment as soon as the model is ready (handy for testing).
@export var equip_all_on_start: bool = true

var character_model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer

var _cloth_nodes: Dictionary = {}          # slot -> MeshInstance3D
var _body_nodes: Dictionary = {}           # body mesh name -> MeshInstance3D
var _gear_attachments: Dictionary = {}     # slot -> BoneAttachment3D
var _equipped_cloth: Dictionary = {}       # slot -> bool


func _ready() -> void:
	if auto_setup:
		setup()


## Load the model (if not already provided) and cache the skeleton, animation
## player and clothing/body meshes. Safe to call once.
func setup(existing_model: Node3D = null) -> bool:
	character_model = existing_model if existing_model != null else _load_glb(model_path)
	if character_model == null:
		push_error("PlayerEquipment: could not load model '%s'" % model_path)
		return false
	if character_model.get_parent() == null:
		add_child(character_model)
	character_model.name = "CharacterModel"

	skeleton = _find_skeleton(character_model)
	animation_player = _find_animation_player(character_model)
	if skeleton == null:
		push_error("PlayerEquipment: no Skeleton3D inside the model")
		return false

	_cache_meshes()
	_hide_helpers(character_model)

	# start fully unequipped; default Mixamo clothes visible
	for slot in ClothingEquipmentData.clothing_slots():
		_equipped_cloth[slot] = false
		var mi: MeshInstance3D = _cloth_nodes.get(slot)
		if mi != null:
			mi.visible = false

	if equip_all_on_start:
		for slot in ClothingEquipmentData.clothing_slots():
			equip_cloth(slot)
		for slot in ClothingEquipmentData.gear_slots():
			equip_gear(slot)
	return true


# ---------------------------------------------------------------------------
# clothing (deformable) -- visibility toggle only
# ---------------------------------------------------------------------------
func equip_cloth(slot: String) -> void:
	var mi: MeshInstance3D = _cloth_nodes.get(slot)
	if mi == null:
		push_warning("PlayerEquipment: no clothing mesh for slot '%s'" % slot)
		return
	mi.visible = true
	_equipped_cloth[slot] = true
	_apply_body_hiding(slot, true)
	cloth_changed.emit(slot, true)


func unequip_cloth(slot: String) -> void:
	var mi: MeshInstance3D = _cloth_nodes.get(slot)
	if mi != null:
		mi.visible = false
	_equipped_cloth[slot] = false
	_apply_body_hiding(slot, false)
	cloth_changed.emit(slot, false)


func toggle_cloth(slot: String) -> void:
	if _equipped_cloth.get(slot, false):
		unequip_cloth(slot)
	else:
		equip_cloth(slot)


func is_cloth_equipped(slot: String) -> bool:
	return _equipped_cloth.get(slot, false)


func _apply_body_hiding(slot: String, equipped: bool) -> void:
	var hides: Array = ClothingEquipmentData.CLOTHING.get(slot, {}).get("hides_body", [])
	for body_name in hides:
		var bn: MeshInstance3D = _body_nodes.get(String(body_name))
		if bn != null:
			# hide the Mixamo default garment while the survival one is on
			bn.visible = not equipped


# ---------------------------------------------------------------------------
# rigid gear -- BoneAttachment3D
# ---------------------------------------------------------------------------
func equip_gear(slot: String) -> void:
	if skeleton == null:
		return
	if _gear_attachments.has(slot):
		_gear_attachments[slot].visible = true
		gear_changed.emit(slot, true)
		return

	var def: Dictionary = ClothingEquipmentData.GEAR.get(slot, {})
	if def.is_empty():
		push_warning("PlayerEquipment: unknown gear slot '%s'" % slot)
		return

	# resolve the attach bone (manifest override -> constant), tolerating the
	# ':' vs '_' naming difference between glTF importers.
	var manifest := ClothingEquipmentData.load_gear_manifest()
	var bone_name := String(def.get("attach_bone", "mixamorig:Spine2"))
	if manifest.has(slot) and manifest[slot] is Dictionary:
		bone_name = String(manifest[slot].get("attach_bone", bone_name))
	bone_name = _resolve_bone_name(bone_name)
	if bone_name.is_empty():
		push_error("PlayerEquipment: attach bone for '%s' not found in skeleton" % slot)
		return

	var attach := BoneAttachment3D.new()
	attach.name = "Attach_" + slot
	attach.bone_name = bone_name
	skeleton.add_child(attach)

	var gear_scene := _load_glb(String(def.get("scene", "")))
	if gear_scene == null:
		push_error("PlayerEquipment: could not load gear '%s'" % def.get("scene", ""))
		attach.queue_free()
		return
	_hide_helpers(gear_scene)
	attach.add_child(gear_scene)
	gear_scene.position = def.get("position", Vector3.ZERO)
	gear_scene.rotation_degrees = def.get("rotation_degrees", Vector3.ZERO)
	gear_scene.scale = def.get("scale", Vector3.ONE)

	_gear_attachments[slot] = attach
	gear_changed.emit(slot, true)


func unequip_gear(slot: String) -> void:
	var attach: BoneAttachment3D = _gear_attachments.get(slot)
	if attach != null:
		attach.queue_free()
		_gear_attachments.erase(slot)
	gear_changed.emit(slot, false)


func is_gear_equipped(slot: String) -> bool:
	return _gear_attachments.has(slot)


# ---------------------------------------------------------------------------
# internals
# ---------------------------------------------------------------------------
func _cache_meshes() -> void:
	_cloth_nodes.clear()
	_body_nodes.clear()
	var name_to_slot := {}
	for slot in ClothingEquipmentData.clothing_slots():
		name_to_slot[ClothingEquipmentData.cloth_mesh_name(slot)] = slot
	for mi in _all_mesh_instances(skeleton):
		if name_to_slot.has(mi.name):
			_cloth_nodes[name_to_slot[mi.name]] = mi
		elif ClothingEquipmentData.BODY_MESHES.has(String(mi.name)):
			_body_nodes[String(mi.name)] = mi


func _all_mesh_instances(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_all_mesh_instances(c))
	return out


func _resolve_bone_name(name: String) -> String:
	var candidates := [name]
	if name.begins_with("mixamorig:"):
		candidates.append("mixamorig_" + name.substr("mixamorig:".length()))
	elif name.begins_with("mixamorig_"):
		candidates.append("mixamorig:" + name.substr("mixamorig_".length()))
	for c in candidates:
		if skeleton.find_bone(c) != -1:
			return c
	return ""


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for c in root.get_children():
		var f := _find_skeleton(c)
		if f != null:
			return f
	return null


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var f := _find_animation_player(c)
		if f != null:
			return f
	return null


func _hide_helpers(root: Node) -> void:
	var lower := root.name.to_lower()
	if lower.begins_with("icosphere") or lower == "cube" or lower.find("placeholder") >= 0:
		if root is Node3D:
			(root as Node3D).visible = false
	for c in root.get_children():
		_hide_helpers(c)


## Runtime .glb loader (mirrors PlayerController._load_external_node3d).
func _load_glb(path: String) -> Node3D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			var inst = res.instantiate()
			if inst is Node3D:
				return inst
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(disk_path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	return scene if scene is Node3D else null
