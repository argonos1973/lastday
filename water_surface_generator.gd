@tool
extends Node
class_name WaterSurfaceGenerator

@export var river_material: ShaderMaterial

@export var path: Path3D:
	set(value):
		_path = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _path

@export var width: float = 5.0:
	set(value):
		_width = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _width

@export var steps: int = 30:
	set(value):
		_steps = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _steps

@export var smoothness: float = 0.5:
	set(value):
		_smoothness = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _smoothness

@export var path_rotation_accurate: bool = true:
	set(value):
		_path_rotation_accurate = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _path_rotation_accurate

@export var double_sided: bool = false:
	set(value):
		_double_sided = value
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _double_sided

@export var width_subdivisions: int = 0:
	set(value):
		_width_subdivisions = max(0, value)
		if Engine.is_editor_hint():
			_update_mesh()
	get:
		return _width_subdivisions

var _path: Path3D
var _width: float = 5.0
var _steps: int = 30
var _smoothness: float = 0.5
var _path_rotation_accurate: bool = true
var _double_sided: bool = true
var _width_subdivisions: int = 0
var _mesh_instance: MeshInstance3D
var _curve: Curve3D


func _ready():
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.visible = true
	add_child(_mesh_instance)
	_mesh_instance.owner = owner if owner else self
	
	call_deferred("_update_mesh")
 
func _process(_delta):
	if Engine.is_editor_hint():
		_check_curve_changes()
 
func _check_curve_changes():
	if not _path:
		return
	
	var new_curve = _path.curve
	if new_curve != _curve:
		_curve = new_curve
		_update_mesh()
 
func _update_mesh():
	if not _mesh_instance:
			return
	
	if not _path:
		return

	if not _path.curve:
		return

	if _path.curve.point_count < 2:
		return

	var mesh = _generate_river_mesh(_path.curve, _width, _steps, _smoothness, _path_rotation_accurate, _width_subdivisions)

	if mesh:

		_post_process_tangents(mesh, _path.curve, _path_rotation_accurate, _width_subdivisions)
		
		_mesh_instance.mesh = mesh 
		if river_material:
			river_material.set_shader_parameter("double_sided", _double_sided)
			_mesh_instance.material_override = river_material
		else:
			var material = StandardMaterial3D.new()
			material.cull_mode = BaseMaterial3D.CULL_DISABLED if _double_sided else BaseMaterial3D.CULL_BACK
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.5, 0.7, 1.0, 0.5)
			_mesh_instance.material_override = material
	else:
		_mesh_instance.mesh = null

func _post_process_tangents(mesh: ArrayMesh, curve: Curve3D, path_rotation_accurate: bool, width_subdivisions: int):
	if not mesh or mesh.get_surface_count() == 0:
		return

	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[ArrayMesh.ARRAY_VERTEX]
	var tangents = arrays[ArrayMesh.ARRAY_TANGENT]

	var curve_length = curve.get_baked_length()
	var closed_loop = curve.closed
	var vertices_per_segment = width_subdivisions + 2
	var vertex_count = vertices.size() / vertices_per_segment
	var actual_steps = vertex_count - 1 if not closed_loop else vertex_count
	
	var curve_tangents = []
	for i in range(vertex_count):
		var t = float(i) / float(actual_steps)
		var offset = t * curve_length
		
		var forward_vector: Vector3
		if path_rotation_accurate:
			if curve.has_method("sample_baked_tangent"):
				forward_vector = curve.sample_baked_tangent(offset).normalized()
			else:
				var t_forward = min(t + 0.01, 1.0)
				var t_backward = max(t - 0.01, 0.0)
				var pos_forward = curve.sample_baked(t_forward * curve_length)
				var pos_backward = curve.sample_baked(t_backward * curve_length)
				forward_vector = (pos_forward - pos_backward).normalized()
		else:
			var t_forward = min(t + 0.01, 1.0)
			var t_backward = max(t - 0.01, 0.0)
			var pos_forward = curve.sample_baked(t_forward * curve_length)
			var pos_backward = curve.sample_baked(t_backward * curve_length)
			forward_vector = (pos_forward - pos_backward).normalized()

		curve_tangents.append(forward_vector)
	
	for i in range(vertex_count):
		var tangent = curve_tangents[i]

		for j in range(vertices_per_segment):
			var vertex_idx = i * vertices_per_segment + j
			var t_idx = vertex_idx * 4
			tangents[t_idx] = tangent.x
			tangents[t_idx + 1] = tangent.y
			tangents[t_idx + 2] = tangent.z
			tangents[t_idx + 3] = 1.0
	
	arrays[ArrayMesh.ARRAY_TANGENT] = tangents
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func _generate_river_mesh(curve: Curve3D, width: float, steps: int, smoothness: float, path_rotation_accurate: bool, width_subdivisions: int = 0) -> ArrayMesh:
	if not curve or curve.point_count < 2:
		return null

	if curve.bake_interval == 0:
		curve.bake_interval = 0.1

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var curve_length = curve.get_baked_length()

	var subdivisions = int(smoothness * 4.0)
	var actual_steps = steps * (subdivisions + 1)
	var vertex_count = actual_steps + 1

	var first_tangent: Vector3
	var closed_loop = curve.closed

	for i in range(vertex_count):
		var t = float(i) / float(actual_steps)
		var offset = t * curve_length
		var position = curve.sample_baked(offset)


		var forward_vector: Vector3
		if path_rotation_accurate:
			if curve.has_method("sample_baked_tangent"):
				forward_vector = curve.sample_baked_tangent(offset).normalized()
			else:
				var t_forward = min(t + 0.01, 1.0)
				var t_backward = max(t - 0.01, 0.0)
				var pos_forward = curve.sample_baked(t_forward * curve_length)
				var pos_backward = curve.sample_baked(t_backward * curve_length)
				forward_vector = (pos_forward - pos_backward).normalized()
		else:
			var t_forward = min(t + 0.01, 1.0)
			var t_backward = max(t - 0.01, 0.0)
			var pos_forward = curve.sample_baked(t_forward * curve_length)
			var pos_backward = curve.sample_baked(t_backward * curve_length)
			forward_vector = (pos_forward - pos_backward).normalized()

		if i == 0:
			first_tangent = forward_vector
		elif closed_loop and i == vertex_count - 1:
			forward_vector = first_tangent

		var right_vector = forward_vector.cross(Vector3.UP).normalized()

		var uv_t = offset / curve_length
		var vertices_per_segment = width_subdivisions + 2
		for j in range(vertices_per_segment):
			var width_t = float(j) / float(width_subdivisions + 1)
			var vertex_pos = position - right_vector * width * 0.5 + right_vector * width * width_t

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(uv_t, width_t))
			st.add_vertex(vertex_pos)


	var triangle_count = vertex_count - 1
	var vertices_per_segment = width_subdivisions + 2
	for i in range(triangle_count):
		var base_idx = i * vertices_per_segment

		for j in range(width_subdivisions + 1):
			var v0 = base_idx + j
			var v1 = base_idx + j + 1
			var v2 = base_idx + vertices_per_segment + j
			var v3 = base_idx + vertices_per_segment + j + 1

			st.add_index(v0)
			st.add_index(v2)
			st.add_index(v1)

			st.add_index(v1)
			st.add_index(v2)
			st.add_index(v3)


	st.generate_tangents()

	return st.commit()
