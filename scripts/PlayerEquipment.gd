extends Node
class_name PlayerEquipment

signal equipped(slot: String, item_name: String)
signal equip_failed(slot: String, reason: String)

var equipped_slots := {}
var sockets := {}
var socket_offsets := {}
var socket_rotations := {}
var socket_scales := {}

func register_socket(slot: String, socket: Node3D, local_position := Vector3.ZERO, local_rotation := Vector3.ZERO, local_scale := Vector3.ONE) -> void:
	sockets[slot] = socket
	socket_offsets[slot] = local_position
	socket_rotations[slot] = local_rotation
	socket_scales[slot] = local_scale

func has_equipped(slot: String) -> bool:
	return equipped_slots.has(slot)

func is_slot_free(slot: String) -> bool:
	return not equipped_slots.has(slot)

func get_equipped_item(slot: String):
	return equipped_slots.get(slot, null)

func unequip_item(slot: String) -> bool:
	if not equipped_slots.has(slot):
		return false
	var data: Dictionary = equipped_slots[slot]
	var visual = data.get("visual", null)
	if visual is Node:
		(visual as Node).queue_free()
	equipped_slots.erase(slot)
	return true

func equip_item(item) -> bool:
	if item == null:
		return false
	var item_name := str(item.item_name)
	var slot := str(item.equipment_slot)
	if slot.is_empty():
		return false
	if equipped_slots.has(slot):
		print("Ya tienes una mochila equipada" if slot == "backpack" else "Slot ocupado: %s" % slot)
		equip_failed.emit(slot, "slot_ocupado")
		return false
	var equipped_model := str(item.equipped_model)
	if equipped_model.is_empty():
		equipped_model = str(item.world_model)
	var visual := _build_visual(equipped_model, item)
	return _attach_visual(slot, item_name, visual)

func equip_model(slot: String, item_name: String, model_path: String, fallback_color := Color(0.08, 0.12, 0.07)) -> bool:
	if equipped_slots.has(slot):
		return true if str(equipped_slots[slot].get("name", "")) == item_name else false
	var visual := _build_visual_from_path(model_path)
	if visual == null:
		visual = _build_fallback_visual(item_name, fallback_color)
	return _attach_visual(slot, item_name, visual)

func _attach_visual(slot: String, item_name: String, visual: Node3D) -> bool:
	if visual == null or not sockets.has(slot):
		equip_failed.emit(slot, "sin_socket_o_modelo")
		return false
	var socket := sockets[slot] as Node3D
	for child in socket.get_children():
		child.queue_free()
	visual.name = "%sEquipped" % item_name.replace(" ", "")
	visual.position = socket_offsets.get(slot, Vector3.ZERO)
	visual.rotation_degrees = socket_rotations.get(slot, Vector3.ZERO)
	visual.scale = socket_scales.get(slot, Vector3.ONE)
	socket.add_child(visual)
	equipped_slots[slot] = {"name": item_name, "visual": visual}
	print("%s equipada en slot %s" % [item_name, slot])
	equipped.emit(slot, item_name)
	return true

func _build_visual(model_path: String, item) -> Node3D:
	if item != null and item.get("equipped_scene") is PackedScene:
		var packed := item.get("equipped_scene") as PackedScene
		var scene_instance := packed.instantiate()
		if scene_instance is Node3D:
			return scene_instance as Node3D
	var visual := _build_visual_from_path(model_path)
	if visual != null:
		return visual
	if item is Node3D:
		return _duplicate_visual_children(item as Node3D)
	return _build_fallback_visual(str(item.item_name), Color(0.08, 0.12, 0.07))

func _build_visual_from_path(model_path: String) -> Node3D:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return null
	var loaded = load(model_path)
	if loaded is PackedScene:
		var instance = (loaded as PackedScene).instantiate()
		if instance is Node3D:
			return instance as Node3D
	return null

func _duplicate_visual_children(source: Node3D) -> Node3D:
	var root := Node3D.new()
	for child in source.get_children():
		if child is MeshInstance3D:
			root.add_child((child as MeshInstance3D).duplicate())
	return root if root.get_child_count() > 0 else null

func _build_fallback_visual(item_name: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.38, 0.52, 0.18)
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	body.material_override = material
	root.add_child(body)
	return root
