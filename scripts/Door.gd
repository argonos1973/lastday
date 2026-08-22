extends StaticBody3D
class_name Door

const TEX_WOOD_FLOOR_DIFF := "res://assets/external/textures/wood_floor_deck/wood_floor_deck_diff_4k.jpg"

@export var display_name := "Puerta"
@export var is_open := false
@export var closed_yaw := 0.0
@export var open_yaw := -95.0

var _tween: Tween
var _collision: CollisionShape3D

func setup(label: String, size: Vector3, color: Color, open_angle: float, model_path: String = "") -> void:
	display_name = label
	open_yaw = open_angle
	add_to_group("doors")
	add_to_group("interactable")
	var door_loaded := false
	if model_path != "" and ResourceLoader.exists(model_path):
		door_loaded = true
	if not door_loaded and model_path != "":
		var disk_path := ProjectSettings.globalize_path(model_path) if model_path.begins_with("res://") else model_path
		if FileAccess.file_exists(disk_path):
			door_loaded = true
	if door_loaded:
		await _make_door_from_glb(size, model_path)
	else:
		_make_door(size, color)

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
	# Sync door state to other clients via server
	var net = get_node_or_null("/root/NetworkManager")
	if net != null and net.is_connected and not net.is_host:
		net.door_state_changed.rpc(name, is_open)

func get_interaction_text(_player = null) -> String:
	return "[E] Cerrar puerta" if is_open else "[E] Abrir puerta"

func _make_door(size: Vector3, _color: Color) -> void:
	var door_center := Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	var wood_mat := _make_wood_floor_material()

	# Main door slab
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = door_center
	mesh_instance.material_override = wood_mat
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = door_center
	add_child(collision)
	_collision = collision

	# Recessed panel material (slightly darker for depth contrast)
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.42, 0.27, 0.16)
	panel_mat.roughness = 0.85
	if wood_mat.albedo_texture != null:
		panel_mat.albedo_texture = wood_mat.albedo_texture
		panel_mat.uv1_scale = wood_mat.uv1_scale * 0.6

	# Raised panel frame styling: two vertical panels (upper large, lower large)
	# on BOTH faces, giving a classic paneled-door look from inside and outside.
	# Local -Z = interior face, local +Z = exterior face (faces outward from the house).
	var panel_inset_x := size.x * 0.14
	var panel_w := size.x - panel_inset_x * 2.0
	var gap := size.y * 0.045
	var panel_h_top := size.y * 0.42
	var panel_h_bottom := size.y * 0.34
	var panel_depth := 0.018

	var stile_mat := StandardMaterial3D.new()
	stile_mat.albedo_color = Color(0.30, 0.19, 0.11)
	stile_mat.roughness = 0.8

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.72, 0.68, 0.55)
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.3

	var faces: Array[float] = [-1.0, 1.0]
	for face in faces:
		var face_z: float = face * (size.z * 0.5 + panel_depth * 0.5 - 0.002)
		var face_name := "Interior" if face < 0.0 else "Exterior"

		var top_panel := MeshInstance3D.new()
		top_panel.name = "PanelTop" + face_name
		var top_box := BoxMesh.new()
		top_box.size = Vector3(panel_w, panel_h_top, panel_depth)
		top_panel.mesh = top_box
		top_panel.position = Vector3(size.x * 0.5, size.y - gap - panel_h_top * 0.5, face_z)
		top_panel.material_override = panel_mat
		add_child(top_panel)

		var bottom_panel := MeshInstance3D.new()
		bottom_panel.name = "PanelBottom" + face_name
		var bottom_box := BoxMesh.new()
		bottom_box.size = Vector3(panel_w, panel_h_bottom, panel_depth)
		bottom_panel.mesh = bottom_box
		bottom_panel.position = Vector3(size.x * 0.5, gap + panel_h_bottom * 0.5, face_z)
		bottom_panel.material_override = panel_mat
		add_child(bottom_panel)

		# Vertical stiles (raised trim strips) for a carpentered look
		for side in [-1.0, 1.0]:
			var stile := MeshInstance3D.new()
			stile.name = "Stile" + face_name
			var stile_box := BoxMesh.new()
			stile_box.size = Vector3(0.035, size.y * 0.94, 0.012)
			stile.mesh = stile_box
			stile.position = Vector3(size.x * 0.5 + side * (panel_w * 0.5 - 0.02), size.y * 0.5, face_z + face * 0.006)
			stile.material_override = stile_mat
			add_child(stile)

		# Doorknob with backplate on this face
		var backplate := MeshInstance3D.new()
		backplate.name = "HandleBackplate" + face_name
		var backplate_mesh := CylinderMesh.new()
		backplate_mesh.top_radius = 0.045
		backplate_mesh.bottom_radius = 0.045
		backplate_mesh.height = 0.01
		backplate.mesh = backplate_mesh
		backplate.rotation_degrees = Vector3(90, 0, 0)
		backplate.position = Vector3(size.x * 0.88, size.y * 0.5, face_z + face * 0.008)
		backplate.material_override = metal_mat
		add_child(backplate)

		var knob := MeshInstance3D.new()
		knob.name = "Handle" + face_name
		var knob_mesh := SphereMesh.new()
		knob_mesh.radius = 0.045
		knob_mesh.height = 0.09
		knob.mesh = knob_mesh
		knob.position = Vector3(size.x * 0.88, size.y * 0.5, face_z + face * 0.09)
		knob.material_override = metal_mat
		add_child(knob)

	# Classic lock (cerradura) on the exterior face — plate + keyhole below the knob
	var lock_plate_mat := StandardMaterial3D.new()
	lock_plate_mat.albedo_color = Color(0.20, 0.19, 0.17)
	lock_plate_mat.metallic = 0.7
	lock_plate_mat.roughness = 0.4
	var lock_plate := MeshInstance3D.new()
	lock_plate.name = "LockPlate"
	var lock_plate_mesh := BoxMesh.new()
	lock_plate_mesh.size = Vector3(0.07, 0.16, 0.01)
	lock_plate.mesh = lock_plate_mesh
	lock_plate.position = Vector3(size.x * 0.88, size.y * 0.5 - 0.16, size.z * 0.5 + 0.007)
	lock_plate.material_override = lock_plate_mat
	add_child(lock_plate)

	var keyhole_mat := StandardMaterial3D.new()
	keyhole_mat.albedo_color = Color(0.03, 0.03, 0.03)
	keyhole_mat.roughness = 0.9
	var keyhole := MeshInstance3D.new()
	keyhole.name = "Keyhole"
	var keyhole_mesh := CylinderMesh.new()
	keyhole_mesh.top_radius = 0.012
	keyhole_mesh.bottom_radius = 0.012
	keyhole_mesh.height = 0.012
	keyhole.mesh = keyhole_mesh
	keyhole.rotation_degrees = Vector3(90, 0, 0)
	keyhole.position = Vector3(size.x * 0.88, size.y * 0.5 - 0.16, size.z * 0.5 + 0.013)
	keyhole.material_override = keyhole_mat
	add_child(keyhole)

	# Small hinge plates on the hinge side for realism
	var hinge_mat := StandardMaterial3D.new()
	hinge_mat.albedo_color = Color(0.25, 0.24, 0.22)
	hinge_mat.metallic = 0.6
	hinge_mat.roughness = 0.5
	for hy in [0.12, 0.5, 0.88]:
		var hinge := MeshInstance3D.new()
		hinge.name = "Hinge"
		var hinge_box := BoxMesh.new()
		hinge_box.size = Vector3(0.02, 0.16, 0.05)
		hinge.mesh = hinge_box
		hinge.position = Vector3(0.01, size.y * hy, -size.z * 0.5 - 0.03)
		hinge.material_override = hinge_mat
		add_child(hinge)

func _make_door_from_glb(size: Vector3, model_path: String) -> void:
	var model: Node3D = null
	if ResourceLoader.exists(model_path):
		var loaded = load(model_path)
		if loaded is PackedScene:
			model = (loaded as PackedScene).instantiate() as Node3D
	if model == null:
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

	# Collision box matching the door size
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.15)
	collision.shape = shape
	collision.position = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	add_child(collision)
	_collision = collision
	# Apply wood floor texture to all door meshes
	var wood_mat := _make_wood_floor_material()
	_apply_material_to_meshes(model, wood_mat)
	# Add door handle
	_add_door_handle(size)

func _make_wood_floor_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.48, 0.35)
	mat.roughness = 0.85
	mat.uv1_scale = Vector3(1.2, 2.0, 1.0)
	var disk_path := ProjectSettings.globalize_path(TEX_WOOD_FLOOR_DIFF)
	if FileAccess.file_exists(disk_path):
		var image := Image.load_from_file(disk_path)
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			mat.albedo_texture = ImageTexture.create_from_image(image)
	return mat

func _apply_material_to_meshes(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply_material_to_meshes(c, mat)

func _add_door_handle(size: Vector3) -> void:
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.72, 0.68, 0.55)
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.3

	var faces: Array[float] = [-1.0, 1.0]
	for face in faces:
		var face_name := "Interior" if face < 0.0 else "Exterior"
		var backplate := MeshInstance3D.new()
		backplate.name = "HandleBackplate" + face_name
		var backplate_mesh := CylinderMesh.new()
		backplate_mesh.top_radius = 0.045
		backplate_mesh.bottom_radius = 0.045
		backplate_mesh.height = 0.01
		backplate.mesh = backplate_mesh
		backplate.rotation_degrees = Vector3(90, 0, 0)
		backplate.position = Vector3(size.x * 0.88, size.y * 0.5, face * size.z * 0.5 + face * 0.008)
		backplate.material_override = metal_mat
		add_child(backplate)

		var knob := MeshInstance3D.new()
		knob.name = "Handle" + face_name
		var knob_mesh := SphereMesh.new()
		knob_mesh.radius = 0.045
		knob_mesh.height = 0.09
		knob.mesh = knob_mesh
		knob.position = Vector3(size.x * 0.88, size.y * 0.5, face * size.z * 0.5 + face * 0.09)
		knob.material_override = metal_mat
		add_child(knob)

	# Classic lock (cerradura) on the exterior face — plate + keyhole below the knob
	var lock_plate_mat := StandardMaterial3D.new()
	lock_plate_mat.albedo_color = Color(0.20, 0.19, 0.17)
	lock_plate_mat.metallic = 0.7
	lock_plate_mat.roughness = 0.4
	var lock_plate := MeshInstance3D.new()
	lock_plate.name = "LockPlate"
	var lock_plate_mesh := BoxMesh.new()
	lock_plate_mesh.size = Vector3(0.07, 0.16, 0.01)
	lock_plate.mesh = lock_plate_mesh
	lock_plate.position = Vector3(size.x * 0.88, size.y * 0.5 - 0.16, size.z * 0.5 + 0.007)
	lock_plate.material_override = lock_plate_mat
	add_child(lock_plate)

	var keyhole_mat := StandardMaterial3D.new()
	keyhole_mat.albedo_color = Color(0.03, 0.03, 0.03)
	keyhole_mat.roughness = 0.9
	var keyhole := MeshInstance3D.new()
	keyhole.name = "Keyhole"
	var keyhole_mesh := CylinderMesh.new()
	keyhole_mesh.top_radius = 0.012
	keyhole_mesh.bottom_radius = 0.012
	keyhole_mesh.height = 0.012
	keyhole.mesh = keyhole_mesh
	keyhole.rotation_degrees = Vector3(90, 0, 0)
	keyhole.position = Vector3(size.x * 0.88, size.y * 0.5 - 0.16, size.z * 0.5 + 0.013)
	keyhole.material_override = keyhole_mat
	add_child(keyhole)

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
