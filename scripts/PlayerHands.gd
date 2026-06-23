extends Node
class_name PlayerHands

signal hands_changed(item_name: String)

var hands_socket: Node3D
var current_item = null
var current_visual: Node3D
var local_position := Vector3.ZERO
var local_rotation := Vector3.ZERO
var local_scale := Vector3.ONE

func register_socket(socket: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> void:
	hands_socket = socket
	local_position = pos
	local_rotation = rot
	local_scale = scale

func has_item_in_hands() -> bool:
	return current_item != null

func get_current_hand_item():
	return current_item

func clear_hands() -> void:
	current_item = null
	if current_visual != null:
		current_visual.queue_free()
	current_visual = null
	hands_changed.emit("")

func put_item_in_hands(item) -> bool:
	if has_item_in_hands():
		print("Ya tienes un objeto en las manos")
		return false
	if hands_socket == null or item == null:
		return false
	var visual := _build_visual(item)
	if visual == null:
		return false
	for child in hands_socket.get_children():
		child.queue_free()
	current_item = item
	current_visual = visual
	visual.name = "%sHands" % str(item.item_name).replace(" ", "")
	visual.position = local_position
	visual.rotation_degrees = local_rotation
	visual.scale = local_scale
	hands_socket.add_child(visual)
	print("%s en manos" % str(item.item_name))
	hands_changed.emit(str(item.item_name))
	return true

func _build_visual(item) -> Node3D:
	if item.get("hands_scene") is PackedScene:
		var packed := item.get("hands_scene") as PackedScene
		var instance := packed.instantiate()
		if instance is Node3D:
			return instance as Node3D
	var path := str(item.get("world_model")) if item.get("world_model") != null else ""
	if path.is_empty() and item.get("equipped_model") != null:
		path = str(item.get("equipped_model"))
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			var scene_instance = (loaded as PackedScene).instantiate()
			if scene_instance is Node3D:
				return scene_instance as Node3D
	if item is Node3D:
		var copy_root := Node3D.new()
		for child in (item as Node3D).get_children():
			if child is MeshInstance3D:
				copy_root.add_child((child as MeshInstance3D).duplicate())
		if copy_root.get_child_count() > 0:
			return copy_root
	return _fallback_box(str(item.item_name), Color(0.12, 0.22, 0.32))

func _fallback_box(item_name: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.24, 0.14)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	return root
