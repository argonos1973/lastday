extends Node
class_name DayNightCycle

signal time_changed
signal night_started

@export var day_length_seconds := 600.0
var time_of_day := 7.0
var last_was_night := false
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var star_field: Node3D
var moon_field: Node3D

func _process(delta: float) -> void:
	var now := Time.get_time_dict_from_system()
	time_of_day = float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
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
	var day_amount: float = clamp(sin((time_of_day - 6.0) / 15.5 * PI), 0.0, 1.0)
	return lerp(2.0, 35.0, day_amount)

func get_hour_text() -> String:
	var hour := int(floor(time_of_day))
	var minute := int(floor((time_of_day - hour) * 60.0))
	return "%02d:%02d" % [hour, minute]

func skip_to_morning() -> void:
	time_of_day = 7.0
	last_was_night = false
	_update_lighting()
	time_changed.emit()

func _update_lighting() -> void:
	if sun == null:
		return
	var day_amount: float = clamp(sin((time_of_day - 6.0) / 15.5 * PI), 0.0, 1.0)
	var night_amount: float = 1.0 - day_amount
	sun.rotation_degrees.x = lerp(-15.0, -72.0, day_amount)
	sun.light_energy = lerp(0.01, 1.15, day_amount)
	sun.shadow_enabled = day_amount > 0.05
	if star_field != null:
		star_field.visible = night_amount > 0.42
	if moon_field != null:
		moon_field.visible = night_amount > 0.36
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.background_color = Color(0.008, 0.009, 0.014).lerp(Color(0.36, 0.58, 0.82), day_amount)
		world_environment.environment.ambient_light_color = Color(0.12, 0.14, 0.20).lerp(Color(0.68, 0.76, 0.84), day_amount)
		world_environment.environment.ambient_light_energy = lerp(0.008, 0.55, day_amount)
		world_environment.environment.fog_light_color = Color(0.02, 0.022, 0.03).lerp(Color(0.62, 0.70, 0.74), day_amount)
		world_environment.environment.fog_density = lerp(0.018, 0.010, day_amount)
		var sky := world_environment.environment.sky
		if sky != null and sky.sky_material is ProceduralSkyMaterial:
			var sky_material := sky.sky_material as ProceduralSkyMaterial
			sky_material.sky_top_color = Color(0.002, 0.003, 0.008).lerp(Color(0.18, 0.45, 0.82), day_amount)
			sky_material.sky_horizon_color = Color(0.015, 0.018, 0.025).lerp(Color(0.62, 0.78, 0.94), day_amount)
			sky_material.ground_bottom_color = Color(0.005, 0.005, 0.008).lerp(Color(0.17, 0.19, 0.14), day_amount)
			sky_material.ground_horizon_color = Color(0.015, 0.016, 0.02).lerp(Color(0.30, 0.36, 0.30), day_amount)
		elif sky != null and sky.sky_material is ShaderMaterial:
			# +Z of the sun node points toward the sun (light travels along -Z).
			var sun_dir := sun.global_transform.basis.z.normalized()
			(sky.sky_material as ShaderMaterial).set_shader_parameter("sun_direction", sun_dir)

func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day}

func from_dict(data: Dictionary) -> void:
	last_was_night = is_night()
	_update_lighting()
