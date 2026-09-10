extends MeshInstance3D
class_name RiverWater

var _time := 0.0
var _base_y := 0.0
var _material: Material
var _night_amount := 0.0
var _is_lake := false
var _reflection: ReflectionProbe
var _reflection_timer := 0.0
var _captured_night_amount := 0.0
var _cloud_darkness := 0.0
var _captured_cloud_darkness := 0.0
var _reflection_dirty := false
static var _next_capture_msec := 0

func set_is_lake(value: bool) -> void:
	_is_lake = value

func _ready() -> void:
	_base_y = position.y
	if material_override != null:
		_material = material_override.duplicate()
		material_override = _material
	if _is_lake:
		layers = 1 << 19
		_reflection = ReflectionProbe.new()
		_reflection.name = "LakeReflection"
		var bounds := mesh.get_aabb().size
		_reflection.size = Vector3(bounds.x + 100.0, 100.0, bounds.z + 100.0)
		_reflection.position.y = 1.5
		_reflection.max_distance = maxf(bounds.x, bounds.z) + 100.0
		# Grass blades don't contribute useful detail to a lake cubemap.
		_reflection.cull_mask = 0xFFFFF & ~((1 << 19) | (1 << 18))
		_reflection.reflection_mask = 1 << 19
		_reflection.mesh_lod_threshold = 8.0
		_reflection.box_projection = true
		_reflection.enable_shadows = false
		_reflection.intensity = 1.0
		_reflection.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		_reflection.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(_reflection)
		# UPDATE_ONCE is invalidated by transform changes. The water bobs every
		# frame; the capture must stay fixed in world space to remain cached.
		var capture_transform := _reflection.global_transform
		_reflection.top_level = true
		_reflection.global_transform = capture_transform
		_captured_night_amount = _night_amount
		_captured_cloud_darkness = _cloud_darkness
		if _material is ShaderMaterial:
			_material.set_shader_parameter("use_foam", false)
			_material.set_shader_parameter("normal_scale", 0.10)
			_material.set_shader_parameter("roughness_scale", 0.06)
			_material.set_shader_parameter("water_color", Color(0.045, 0.12, 0.14))
	if _material is ShaderMaterial:
		_material.set_shader_parameter("night_amount", _night_amount)
	_update_mirror()

func _process(delta: float) -> void:
	_time += delta
	if _reflection != null:
		_reflection_timer += delta
		var camera := get_viewport().get_camera_3d()
		var lighting_changed := absf(_night_amount - _captured_night_amount) >= 0.1 or absf(_cloud_darkness - _captured_cloud_darkness) >= 0.1
		if (_reflection_dirty or (_reflection_timer > 30.0 and lighting_changed)) and Time.get_ticks_msec() >= _next_capture_msec and camera != null and global_position.distance_to(camera.global_position) < _reflection.max_distance:
			_reflection_timer = 0.0
			_reflection_dirty = false
			_captured_night_amount = _night_amount
			_captured_cloud_darkness = _cloud_darkness
			_next_capture_msec = Time.get_ticks_msec() + 2000
			# A tiny alternating movement explicitly invalidates a cached probe.
			_reflection.global_position.y += 0.001 if _reflection.get_meta("raised", false) == false else -0.001
			_reflection.set_meta("raised", not _reflection.get_meta("raised", false))
	position.y = _base_y + sin(_time * 1.35 + global_position.x * 0.05) * 0.009
	if _material is StandardMaterial3D:
		var standard := _material as StandardMaterial3D
		standard.uv1_offset.x = fmod(_time * 0.055, 1.0)
		standard.uv1_offset.y = fmod(_time * 0.025, 1.0)

func request_reflection_refresh() -> void:
	# World generation completes after the water exists. Capture the completed
	# forest once, when a camera approaches; don't poll geometry every frame.
	_reflection_dirty = true

func set_night_amount(value: float, cloud_darkness := 0.0) -> void:
	_cloud_darkness = clampf(cloud_darkness, 0.0, 1.0)
	var next_amount := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_amount, _night_amount):
		return
	_night_amount = next_amount
	if _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)
	_update_mirror()

# Reflejo tipo espejo: el color reflejado sigue el ciclo dia/noche, y en el lago
# (agua mas calma) el efecto es mas intenso que en los rios (mas turbulentos)
func _update_mirror() -> void:
	if not (_material is ShaderMaterial):
		return
	var mat := _material as ShaderMaterial
	var day_amount: float = 1.0 - _night_amount
	var mirror_col: Color = Color(0.02, 0.03, 0.05).lerp(Color(0.62, 0.78, 0.97), day_amount)
	mat.set_shader_parameter("mirror_color", mirror_col)
	mat.set_shader_parameter("mirror_strength", 0.5 if _is_lake else 0.2)
