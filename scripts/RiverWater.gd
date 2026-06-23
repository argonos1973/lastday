extends MeshInstance3D
class_name RiverWater

var _time := 0.0
var _base_y := 0.0
var _material: Material
var _night_amount := 0.0

func _ready() -> void:
	_base_y = position.y
	if material_override != null:
		_material = material_override.duplicate()
		material_override = _material

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.35 + global_position.x * 0.05) * 0.009
	if _material is StandardMaterial3D:
		var standard := _material as StandardMaterial3D
		standard.uv1_offset.x = fmod(_time * 0.055, 1.0)
		standard.uv1_offset.y = fmod(_time * 0.025, 1.0)
	elif _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)

func set_night_amount(value: float) -> void:
	_night_amount = clamp(value, 0.0, 1.0)
	if _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)
