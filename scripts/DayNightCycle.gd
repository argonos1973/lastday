extends Node
class_name DayNightCycle

signal time_changed
signal night_started

@export var day_length_seconds := 86400.0
@export var fixed_time := false
var time_of_day := 8.0
var last_was_night := false
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var star_field: Node3D
var moon_field: Node3D

var _real_time_initialized := false

func _process(delta: float) -> void:
	if not _real_time_initialized:
		if fixed_time:
			time_of_day = 12.0
			_real_time_initialized = true
		else:
			var dt := Time.get_time_dict_from_system()
			time_of_day = float(dt.hour) + float(dt.minute) / 60.0 + float(dt.second) / 3600.0
			_real_time_initialized = true
	elif not fixed_time:
		var hours_per_second := 24.0 / day_length_seconds
		time_of_day += delta * hours_per_second
		if time_of_day >= 24.0:
			time_of_day -= 24.0
	var night := is_night()
	if night and not last_was_night:
		night_started.emit()
	last_was_night = night
	_update_lighting()
	time_changed.emit()

func is_night() -> bool:
	return time_of_day < 6.0 or time_of_day >= 21.5

func get_cold_factor() -> float:
	return get_ambient_temperature()

func get_ambient_temperature() -> float:
	var day_amount: float = clamp(sin((time_of_day - 6.0) / 18.0 * PI), 0.0, 1.0)
	return lerp(2.0, 35.0, day_amount)

func get_hour_text() -> String:
	var hour := int(floor(time_of_day))
	var minute := int(floor((time_of_day - hour) * 60.0))
	return "%02d:%02d" % [hour, minute]

func skip_to_morning() -> void:
	if fixed_time:
		time_of_day = 12.0
	else:
		time_of_day = 7.0
	last_was_night = false
	_update_lighting()
	time_changed.emit()

func _update_lighting() -> void:
	if sun == null:
		return
	var day_amount: float = clamp(sin((time_of_day - 6.0) / 18.0 * PI), 0.0, 1.0)
	var night_amount: float = 1.0 - day_amount
	sun.rotation_degrees.x = lerp(-15.0, -72.0, day_amount)
	sun.light_energy = lerp(0.01, 1.5, day_amount)
	sun.shadow_enabled = day_amount > 0.05
	if star_field != null:
		star_field.visible = night_amount > 0.42
	if moon_field != null:
		moon_field.visible = night_amount > 0.36
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.background_color = Color(0.008, 0.009, 0.014).lerp(Color(0.56, 0.76, 0.96), day_amount)
		world_environment.environment.ambient_light_color = Color(0.12, 0.14, 0.20).lerp(Color(0.86, 0.90, 0.92), day_amount)
		world_environment.environment.ambient_light_energy = lerp(0.05, 0.95, day_amount)
		world_environment.environment.fog_light_color = Color(0.02, 0.022, 0.03).lerp(Color(0.62, 0.70, 0.74), day_amount)
		world_environment.environment.fog_density = lerp(0.002, 0.0008, day_amount)
		var sky := world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			var sm := sky.sky_material as ShaderMaterial
			var day_norm := time_of_day / 24.0
			sm.set_shader_parameter("day_cycle", day_norm)
			var sun_dir := sun.global_transform.basis.z.normalized()
			sm.set_shader_parameter("sun_direction", sun_dir)
			sm.set_shader_parameter("sun_intensity", day_amount)
			sm.set_shader_parameter("sky_top_color", Color(0.002, 0.003, 0.008, 1).lerp(Color(0.34, 0.62, 0.95, 1), day_amount))
			sm.set_shader_parameter("sky_horizon_color", Color(0.015, 0.018, 0.025, 1).lerp(Color(0.78, 0.90, 1.0, 1), day_amount))
			sm.set_shader_parameter("ground_bottom_color", Color(0.005, 0.005, 0.008, 1).lerp(Color(0.17, 0.19, 0.14, 1), day_amount))
			sm.set_shader_parameter("ground_horizon_color", Color(0.015, 0.016, 0.02, 1).lerp(Color(0.30, 0.36, 0.30, 1), day_amount))

func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day}

func from_dict(data: Dictionary) -> void:
	last_was_night = is_night()
	_update_lighting()
