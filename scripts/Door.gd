extends StaticBody3D
class_name Door

@export var display_name := "Puerta"
@export var is_open := false
@export var closed_yaw := 0.0
@export var open_yaw := -95.0

var _tween: Tween
var _collision: CollisionShape3D

func setup(label: String, size: Vector3, color: Color, open_angle: float, model_path: String = "") -> void:
	display_name = label
	open_yaw = open_angle
	var disk_path := ProjectSettings.globalize_path(model_path) if model_path.begins_with("res://") else model_path
	if model_path != "" and FileAccess.file_exists(disk_path):
		await _make_door_from_glb(size, model_path)
	else:
		_make_door(size, color)
	add_to_group("doors")
	add_to_group("interactable")

func interact(player) -> void:
	is_open = not is_open
	var target_yaw := open_yaw if is_open else closed_yaw
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees:y", target_yaw, 0.28)
	player.notice.emit("Puerta abierta." if is_open else "Puerta cerrada.")

func get_interaction_text(_player = null) -> String:
	return "Cerrar puerta" if is_open else "Abrir puerta"

func _make_door(size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = mesh_instance.position
	add_child(collision)
	_collision = collision

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.08, 0.10, 0.08)
	handle.mesh = handle_mesh
	handle.position = Vector3(size.x * 0.84, size.y * 0.52, -size.z * 0.58)
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.42, 0.31, 0.16)
	handle_material.roughness = 0.75
	handle.material_override = handle_material
	add_child(handle)

func _make_door_from_glb(size: Vector3, model_path: String) -> void:
	var model: Node3D = null
	var disk_path := ProjectSettings.globalize_path(model_path) if model_path.begins_with("res://") else model_path
	if FileAccess.file_exists(disk_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(disk_path, state)
		if err == OK:
			model = doc.generate_scene(state)
	if model == null:
		push_warning("Door GLB failed to load: %s, falling back to procedural" % model_path)
		_make_door(size, Color(0.13, 0.075, 0.04))
		return

	_strip_display_props(model)
	_strip_non_door_panels(model)

	# Add to tree, wait for transforms to update
	model.transform = Transform3D.IDENTITY
	add_child(model)
	await get_tree().process_frame

	# Reset ALL transforms to identity so mesh AABB is in raw Blender space
	_reset_all_transforms(model)

	# Find the largest mesh (door panel) by local AABB area
	var panel_mi := _find_door_panel_mesh(model)
	if panel_mi == null:
		push_warning("Door GLB has no meshes: %s" % model_path)
		_make_door(size, Color(0.13, 0.075, 0.04))
		model.queue_free()
		return

	# Use the mesh's local AABB (in Blender space: X=width, Y=depth, Z=height)
	var mesh_aabb := panel_mi.get_aabb()
	print("[Door] model_path=", model_path, " mesh=", panel_mi.name, " AABB=", mesh_aabb)

	# Blender Z-up → Godot Y-up: rotate model -90° around X so Z→Y
	model.rotation_degrees = Vector3(-90, 0, 0)
	# Scale is applied in LOCAL space (Blender) BEFORE rotation:
	# Blender X = width → Godot X = width
	# Blender Y = depth → Godot Z = depth (after -90° X rotation)
	# Blender Z = height → Godot Y = height (after -90° X rotation)
	var dx := mesh_aabb.size.x
	var dy := mesh_aabb.size.y  # Blender Y = depth
	var dz := mesh_aabb.size.z  # Blender Z = height
	var sx := size.x / dx   # width
	var sy := size.z / dy   # depth (Blender Y → Godot Z)
	var sz := size.y / dz   # height (Blender Z → Godot Y)
	model.scale = Vector3(sx, sy, sz)

	# Position: scale in local space first, then rotate
	# Local AABB min scaled: mesh_aabb.position * scale
	var scaled_local_min := mesh_aabb.position * model.scale
	# After -90° X rotation: (x,y,z) → (x, z, -y)
	var rotated_min := Vector3(scaled_local_min.x, scaled_local_min.z, -scaled_local_min.y)
	model.position = Vector3(-rotated_min.x, -rotated_min.y, 0.0)
	print("[Door] scale=", model.scale, " pos=", model.position, " dims=", Vector3(dx, dy, dz))

	# Collision box matching the door size
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.15)
	collision.shape = shape
	collision.position = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	add_child(collision)
	_collision = collision

func _strip_non_door_panels(root: Node) -> void:
	var door_node: Node = _find_first_door_node(root)
	if door_node == null or door_node == root:
		return
	var current: Node = door_node
	while current != root and current != null:
		var parent: Node = current.get_parent()
		if parent == null:
			break
		var to_remove: Array = []
		for c in parent.get_children():
			if c != current:
				to_remove.append(c)
		for c in to_remove:
			parent.remove_child(c)
			c.free()
		current = parent
	_remove_outlier_meshes(door_node)

func _find_first_door_node(node: Node) -> Node:
	if node.name.to_lower() == "door":
		return node
	for c in node.get_children():
		var result: Node = _find_first_door_node(c)
		if result != null:
			return result
	return null

func _remove_outlier_meshes(root: Node) -> void:
	var to_remove: Array = []
	_collect_outlier_meshes(root, to_remove)
	for n in to_remove:
		if is_instance_valid(n):
			var p: Node = n.get_parent()
			if p != null:
				p.remove_child(n)
			n.free()

func _collect_outlier_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		if aabb.size.x > 5.0 or aabb.position.x < -5.0:
			result.append(node)
			return
	for c in node.get_children():
		_collect_outlier_meshes(c, result)

func _reset_all_transforms(node: Node3D) -> void:
	node.transform = Transform3D.IDENTITY
	for c in node.get_children():
		if c is Node3D:
			_reset_all_transforms(c)

func _find_door_panel_mesh(root: Node3D) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_area := 0.0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.visible:
			var mi := n as MeshInstance3D
			var aabb := mi.get_aabb()
			var dims := [aabb.size.x, aabb.size.y, aabb.size.z]
			dims.sort()
			var area: float = dims[1] * dims[2]
			if area > best_area:
				best_area = area
				best = mi
		for c in n.get_children():
			stack.append(c)
	return best

func _strip_display_props(node: Node) -> void:
	var to_remove: Array = []
	_collect_display_props(node, to_remove)
	for n in to_remove:
		if is_instance_valid(n):
			var p: Node = n.get_parent()
			if p != null:
				p.remove_child(n)
			n.queue_free()

func _collect_display_props(node: Node, result: Array) -> void:
	if node is Light3D:
		result.append(node)
		return
	var lower := node.name.to_lower()
	if lower.begins_with("circle") or lower == "sun" or lower.begins_with("turntable") or lower.begins_with("ground_plane"):
		result.append(node)
		return
	for child in node.get_children():
		_collect_display_props(child, result)
