extends MeshInstance3D
class_name RiverWater

var _time := 0.0
var _base_y := 0.0
var _material: Material
var _night_amount := 0.0
var _heat_mist: FogVolume = null
var _heat_mist_mat: FogMaterial = null
var _day_cycle_ref: Node = null
var _mist_target_density := 0.0

func _ready() -> void:
	_base_y = position.y
	if material_override != null:
		_material = material_override.duplicate()
		material_override = _material
	# Create heat mist fog volume above the water surface
	_heat_mist = FogVolume.new()
	_heat_mist.name = "HeatMist"
	_heat_mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_heat_mist.size = Vector3(60.0, 2.5, 60.0)
	_heat_mist.position = Vector3(0.0, 1.2, 0.0)
	_heat_mist_mat = FogMaterial.new()
	_heat_mist_mat.density = 0.0
	_heat_mist_mat.albedo = Color(0.85, 0.88, 0.92, 0.6)
	_heat_mist_mat.emission = Color(0.0, 0.0, 0.0)
	_heat_mist.material = _heat_mist_mat
	_heat_mist.visible = false
	add_child(_heat_mist)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.35 + global_position.x * 0.05) * 0.009
	if _material is StandardMaterial3D:
		var standard := _material as StandardMaterial3D
		standard.uv1_offset.x = fmod(_time * 0.055, 1.0)
		standard.uv1_offset.y = fmod(_time * 0.025, 1.0)
	elif _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)
	_update_heat_mist(delta)

func _update_heat_mist(delta: float) -> void:
	if _heat_mist == null or _heat_mist_mat == null:
		return
	if _day_cycle_ref == null:
		var tree := get_tree()
		if tree != null:
			_day_cycle_ref = tree.get_first_node_in_group("day_night_cycle")
		if _day_cycle_ref == null:
			# Try finding by name as fallback
			var root := get_tree().current_scene
			if root != null:
				_day_cycle_ref = root.get_node_or_null("DayNightCycle")
		if _day_cycle_ref == null:
			return
	if not _day_cycle_ref.has_method("get_ambient_temperature"):
		return
	var temp: float = _day_cycle_ref.get_ambient_temperature()
	# Mist appears when temperature > 22°C, peaks at 35°C
	if temp > 22.0:
		_mist_target_density = clamp((temp - 22.0) / 13.0, 0.0, 1.0) * 0.08
	else:
		_mist_target_density = 0.0
	# Smoothly interpolate density
	var current_density: float = _heat_mist_mat.density
	_heat_mist_mat.density = lerp(current_density, _mist_target_density, delta * 0.5)
	_heat_mist.visible = _heat_mist_mat.density > 0.001
	# Subtle drifting motion for the mist
	if _heat_mist.visible:
		_heat_mist.position.x = sin(_time * 0.3) * 0.5
		_heat_mist.position.z = cos(_time * 0.25) * 0.5

func set_night_amount(value: float) -> void:
	_night_amount = clamp(value, 0.0, 1.0)
	if _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)

func set_mist_size(width: float, depth: float) -> void:
	if _heat_mist == null:
		return
	_heat_mist.size = Vector3(width, 2.5, depth)
