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

func set_model(paths: Array, scale_value: float = 1.0, extra_rotation_deg: Vector3 = Vector3.ZERO, frame_zoom: float = 1.0, only_mesh_name: String = "", tint: Color = Color(0, 0, 0, 0), camo: Color = Color(0, 0, 0, 0)) -> void:
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
	if not only_mesh_name.is_empty():
		var all_meshes: Array = []
		_collect_meshes(inst, all_meshes)
		for mi in all_meshes:
			var m := mi as MeshInstance3D
			if m == null:
				continue
			if m.name.to_lower() == only_mesh_name.to_lower():
				if tint.a > 0.0:
					var mat := StandardMaterial3D.new()
					mat.albedo_color = tint
					mat.roughness = 0.9
					m.material_override = mat
			else:
				m.visible = false
	elif camo.a > 0.0:
		# Camouflage garments show the same generated camo cloth the character
		# wears when no loot color overrides it.
		var camo_meshes: Array = []
		_collect_meshes(inst, camo_meshes)
		for mi in camo_meshes:
			var m := mi as MeshInstance3D
			if m == null:
				continue
			var cmat := StandardMaterial3D.new()
			cmat.albedo_texture = MaterialFactory.make_camo_texture(camo)
			cmat.albedo_color = Color.WHITE
			MaterialFactory.cloth_detail(cmat, "soldier", 0.01)
			m.material_override = cmat
	elif tint.a > 0.0:
		# Clothing thumbnails tint every mesh with the same cloth material the
		# character wears so the inventory color matches the equipped garment.
		var all_meshes2: Array = []
		_collect_meshes(inst, all_meshes2)
		for mi in all_meshes2:
			var m := mi as MeshInstance3D
			if m == null:
				continue
			var kind := MaterialFactory.clothing_kind_for_mesh(m.name)
			if kind.is_empty():
				var mat := StandardMaterial3D.new()
				mat.albedo_color = tint
				mat.roughness = 0.9
				m.material_override = mat
			else:
				# Pickup models are meter-space: unit_scale 0.01 keeps the
				# garment grow offsets in the centimeter range.
				m.material_override = MaterialFactory.make_clothing_material(kind, tint, -999.0, 0.01)
	inst.scale = Vector3.ONE * scale_value
	inst.rotation_degrees = extra_rotation_deg
	_frame_camera(inst, frame_zoom)

func _frame_camera(inst: Node3D, frame_zoom: float = 1.0) -> void:
	var meshes: Array = []
	_collect_meshes(inst, meshes)
	if meshes.is_empty():
		return
	var box := AABB()
	var first := true
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null or not mesh_inst.visible:
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
	# frame_zoom < 1.0 zooms in (smaller cam.size = more zoom)
	_cam.size = radius * 2.05 * frame_zoom
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
