extends MeshInstance3D
class_name RiverWater

var _time := 0.0
var _base_y := 0.0
var _material: Material
var _night_amount := 0.0
var _is_lake := false

func set_is_lake(value: bool) -> void:
	_is_lake = value

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
	_update_mirror()

func set_night_amount(value: float) -> void:
	_night_amount = clamp(value, 0.0, 1.0)
	if _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("night_amount", _night_amount)

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
