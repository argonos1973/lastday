extends SubViewportContainer
class_name ItemThumbnail3D

var _viewport: SubViewport
var _cam: Camera3D
var _model_root: Node3D

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(96, 96)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	add_child(_viewport)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	light.light_energy = 1.3
	_viewport.add_child(light)

	var light2 := DirectionalLight3D.new()
	light2.rotation_degrees = Vector3(-25, -150, 0)
	light2.light_energy = 0.55
	_viewport.add_child(light2)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.0
	_viewport.add_child(_cam)

	_model_root = Node3D.new()
	_viewport.add_child(_model_root)

func set_model(paths: Array, scale_value: float = 1.0, extra_rotation_deg: Vector3 = Vector3.ZERO) -> void:
	for child in _model_root.get_children():
		child.queue_free()
	if _model_root == null:
		return
	var inst: Node3D = null
	for path in paths:
		if typeof(path) != TYPE_STRING or path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		var node = scene.instantiate()
		if node is Node3D:
			inst = node
			break
		elif node != null:
			node.queue_free()
	if inst == null:
		return
	_model_root.add_child(inst)
	inst.scale = Vector3.ONE * scale_value
	inst.rotation_degrees = extra_rotation_deg
	_frame_camera(inst)

func _frame_camera(inst: Node3D) -> void:
	var meshes: Array = []
	_collect_meshes(inst, meshes)
	if meshes.is_empty():
		return
	var box := AABB()
	var first := true
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var local_box: AABB = mesh_inst.mesh.get_aabb()
		var world_box: AABB = mesh_inst.global_transform * local_box
		if first:
			box = world_box
			first = false
		else:
			box = box.merge(world_box)
	if first:
		return
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	if radius < 0.001:
		radius = 0.5
	_cam.size = radius * 2.05
	var dir := Vector3(1.0, 0.85, 1.0).normalized()
	_cam.global_position = center + dir * (radius * 4.0 + 2.0)
	_cam.look_at(center, Vector3.UP)
	_cam.near = 0.01
	_cam.far = radius * 12.0 + 10.0

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)
