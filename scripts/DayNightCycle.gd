extends Node
class_name DayNightCycle

signal time_changed
signal night_started

@export var day_length_seconds := 86400.0
@export var fixed_time := false
var time_of_day := 12.0
var last_was_night := false
var sun: DirectionalLight3D
var weather_darkness := 0.0
var weather_cloud_cover := 0.0
var weather_fog_density := 0.0
var lightning_intensity := 0.0
var world_environment: WorldEnvironment
var star_field: Node3D
var moon_field: Node3D
# Real moon illumination fraction (0=new .. 1=full), refreshed by Main.
var moon_illumination := 1.0

var _real_time_initialized := false
var _lighting_update_accum := 999.0
# Sol estacional: amanecer/atardecer de la fecha real del sistema, con suelo
# de 12.5 h de luz para jugabilidad. En noviembre sale ~6:45 y se pone ~19:15
# (el real ~8:10/~17:55 quedaria demasiado pronto); en junio ~6:40/~21:20.
var _sunrise := 6.0
var _sunset := 21.0
var _solar_noon := 13.5
var _peak_elevation := 68.0
var _season_day := -1

const _MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

func _ready() -> void:
	_apply_seasonal_sun()

func _day_of_year(y: int, m: int, d: int) -> int:
	var n := d
	for i in m - 1:
		n += _MONTH_DAYS[i]
	if m > 2 and ((y % 4 == 0 and y % 100 != 0) or y % 400 == 0):
		n += 1
	return n

# Amanecer/atardecer de verdad para la fecha de hoy: declinacion solar por
# dia del año, horas de luz por latitud, mediodia solar corregido por huso
# horario local, longitud y ecuacion del tiempo. Escribe los umbrales unicos
# de GameConst para que bots, supervivencia y cielo sigan el mismo sol.
func _apply_seasonal_sun() -> void:
	var date := Time.get_date_dict_from_system()
	var n := _day_of_year(int(date.year), int(date.month), int(date.day))
	var decl := deg_to_rad(-23.44) * cos(TAU * float(n + 10) / 365.0)
	var cos_h := clampf(-tan(deg_to_rad(GameConst.WORLD_LATITUDE)) * tan(decl), -0.98, 0.98)
	# Suelo de jornada jugable: la astronomia real daria ~9.7 h de luz en
	# noviembre (anochecer ~17:55, noche cerrada a las 18:30 — demasiado
	# pronto para jugar). Minimo 12.5 h: el invierno oscurece ~19:15 y los
	# bots no se acuestan a la hora de la merienda. El verano (~14.9 h)
	# sigue siendo el real.
	var daylight := maxf(2.0 * rad_to_deg(acos(cos_h)) / 15.0, 12.5)
	var b_ang := TAU * float(n - 81) / 364.0
	var eot := 9.87 * sin(2.0 * b_ang) - 7.53 * cos(b_ang) - 1.5 * sin(b_ang)
	var tz_bias := float(Time.get_time_zone_from_system().get("bias", 60)) / 60.0
	_solar_noon = 12.0 + tz_bias - GameConst.WORLD_LONGITUDE / 15.0 - eot / 60.0
	_sunrise = _solar_noon - daylight * 0.5
	_sunset = _solar_noon + daylight * 0.5
	_peak_elevation = 90.0 - absf(GameConst.WORLD_LATITUDE - rad_to_deg(decl))
	GameConst.DAWN_START = _sunrise - 0.55
	GameConst.NIGHT_END = _sunrise - 0.25
	GameConst.SUNRISE_END = _sunrise + 0.55
	GameConst.PREP_START = _sunset - 2.0
	GameConst.DUSK_START = _sunset - 0.85
	GameConst.NIGHT_START = _sunset + 0.65
	_season_day = int(Time.get_unix_time_from_system() / 86400.0)

func _process(delta: float) -> void:
	_lighting_update_accum += delta
	if _lighting_update_accum < GameConst.LIGHTING_UPDATE_INTERVAL:
		return
	_lighting_update_accum = 0.0
	if not _real_time_initialized:
		if fixed_time:
			time_of_day = 12.0
			_real_time_initialized = true
		else:
			var dt := Time.get_time_dict_from_system(false)
			time_of_day = float(dt.hour) + float(dt.minute) / 60.0 + float(dt.second) / 3600.0
			_real_time_initialized = true
	elif not fixed_time:
		var dt := Time.get_time_dict_from_system(false)
		time_of_day = float(dt.hour) + float(dt.minute) / 60.0 + float(dt.second) / 3600.0
		if int(Time.get_unix_time_from_system() / 86400.0) != _season_day:
			_apply_seasonal_sun()
	var night := is_night()
	if night and not last_was_night:
		night_started.emit()
	last_was_night = night
	_update_lighting()
	time_changed.emit()

func is_night() -> bool:
	return is_night_at(time_of_day)

static func is_night_at(t: float) -> bool:
	return t < GameConst.NIGHT_END or t >= GameConst.NIGHT_START

func get_day_amount() -> float:
	return get_day_amount_at(time_of_day)

static func get_day_amount_at(t: float) -> float:
	var sunrise_start := GameConst.DAWN_START
	var sunrise_end := GameConst.SUNRISE_END
	var sunset_start := GameConst.DUSK_START
	var sunset_end := GameConst.NIGHT_START
	if t < sunrise_start or t >= sunset_end:
		return 0.0
	elif t < sunrise_end:
		return smoothstep(sunrise_start, sunrise_end, t)
	elif t < sunset_start:
		return 1.0
	else:
		return 1.0 - smoothstep(sunset_start, sunset_end, t)

# Luz ambiente real (0..1): la curva solar atenuada por la meteorologia. Una
# tormenta adelanta la oscuridad del crepusculo pero no convierte el mediodia
# en noche.
static func light_amount_at(t: float, darkness: float = 0.0) -> float:
	return get_day_amount_at(t) * (1.0 - clampf(darkness, 0.0, 1.0) * 0.5)

func get_light_amount() -> float:
	return light_amount_at(time_of_day, weather_darkness)

# Oscuro de verdad: noche de reloj o luz insuficiente para moverse sin
# antorcha (final del crepusculo, primera luz del alba, tormenta al atardecer).
static func is_dark_at(t: float, darkness: float = 0.0) -> bool:
	return is_night_at(t) or light_amount_at(t, darkness) < GameConst.DARK_LIGHT

func is_dark() -> bool:
	return is_dark_at(time_of_day, weather_darkness)

# Fase del dia: "night" | "dawn" | "day" | "prep" | "dusk".
static func phase_at(t: float) -> String:
	if is_night_at(t):
		return "night"
	if t < GameConst.SUNRISE_END:
		return "dawn"
	if t >= GameConst.DUSK_START:
		return "dusk"
	if t >= GameConst.PREP_START:
		return "prep"
	return "day"

func get_phase() -> String:
	return phase_at(time_of_day)

func get_cold_factor() -> float:
	return get_ambient_temperature()

func get_ambient_temperature() -> float:
	var day_amount: float = get_day_amount()
	# Curva térmica templada realista (6 °C de noche .. 18-19 °C al mediodía),
	# evitando el antiguo tope de 35 °C cuando Open-Meteo no está disponible.
	var noon_warmth := maxf(0.0, cos((time_of_day - _solar_noon) * PI / 12.0))
	return lerpf(6.0, 16.0, day_amount) + 3.0 * day_amount * noon_warmth

func get_hour_text() -> String:
	var hour := int(floor(time_of_day))
	var minute := int(floor((time_of_day - hour) * 60.0))
	return "%02d:%02d" % [hour, minute]

func skip_to_morning() -> void:
	if fixed_time:
		time_of_day = 12.0
	else:
		time_of_day = GameConst.SUNRISE_END + 0.3
	last_was_night = false
	_update_lighting()
	time_changed.emit()

func _update_lighting() -> void:
	if sun == null:
		return
	var day_amount: float = get_day_amount()
	var night_amount: float = 1.0 - day_amount
	# Solar position follows the hour, not the daylight fade (which stays at
	# 1 for most of the day). Dawn and dusk now cast opposite, long shadows.
	var solar_phase := clampf((time_of_day - _sunrise) / maxf(_sunset - _sunrise, 0.5), 0.0, 1.0)
	var elevation := sin(solar_phase * PI) * _peak_elevation - 4.0
	var sun_height := smoothstep(0.0, 48.0, elevation)
	var cloud := clampf(weather_cloud_cover, 0.0, 1.0)
	var darkness := clampf(weather_darkness, 0.0, 1.0)
	var golden_hour := (1.0 - smoothstep(4.0, 26.0, elevation)) * day_amount
	sun.rotation_degrees = Vector3(-elevation, lerpf(-105.0, 75.0, solar_phase), 0.0)
	sun.light_color = Color(1.0, 0.66, 0.39).lerp(Color(1.0, 0.96, 0.90), sun_height)
	sun.light_energy = day_amount * lerpf(.30, 1.45, sun_height) * (1.0 - darkness)
	sun.shadow_enabled = elevation > 0.0 and day_amount > 0.05
	if star_field != null:
		star_field.visible = night_amount > 0.85 and weather_cloud_cover < 0.75
	if moon_field != null:
		# The moon shines through broken cloud — hide it only on nearly
		# covered or storm skies.
		moon_field.visible = night_amount > 0.35 and weather_cloud_cover < 0.92
	# Moon illumination factor: if moon is up, provide a little light —
	# a full moon lights noticeably more than a thin crescent.
	var moon_illum := 0.0
	if moon_field != null and moon_field.visible:
		moon_illum = 0.03 + 0.09 * moon_illumination
	if world_environment != null and world_environment.environment != null:
		var night_bg := Color(0.001, 0.001, 0.002)
		world_environment.environment.background_color = night_bg.lerp(Color(0.56, 0.76, 0.96), day_amount)
		var night_ambient := Color(0.24, 0.30, 0.42)
		world_environment.environment.ambient_light_color = night_ambient.lerp(Color(.72,.81,.94).lerp(Color(.88,.89,.91),cloud), day_amount)
		# Noche jugable: ~4x mas oscuro que el dia pero con formas legibles —
		# una noche cerrada sin luna sigue siendo noche, no un pozo negro.
		world_environment.environment.ambient_light_energy = lerp(0.32 + moon_illum, lerpf(.40,.53,cloud), day_amount) * (1.0 - darkness * 0.6) + lightning_intensity * 1.0
		var night_fog := Color(0.006, 0.008, 0.012)
		world_environment.environment.fog_light_color = night_fog.lerp(Color(0.62, 0.70, 0.74).lerp(Color(.78,.61,.47), golden_hour*.35), day_amount)
		# Weak aerial perspective in clear weather; storm/fog values still dominate.
		var aerial_density := lerpf(.00004,.00025,day_amount)
		world_environment.environment.fog_density = maxf(weather_fog_density,aerial_density)
		world_environment.environment.fog_enabled = true
		world_environment.environment.volumetric_fog_enabled = false
		var sky := world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			var sm := sky.sky_material as ShaderMaterial
			var day_norm := day_amount
			sm.set_shader_parameter("day_cycle", day_norm)
			sm.set_shader_parameter("lightning_intensity", lightning_intensity)
			var sun_dir := sun.global_transform.basis.z.normalized()
			sm.set_shader_parameter("sun_direction", sun_dir)
			sm.set_shader_parameter("sun_intensity", day_amount)
			sm.set_shader_parameter("night_sky_brightness", 0.15)
			sm.set_shader_parameter("sky_top_color", Color(0.002, 0.003, 0.006, 1).lerp(Color(0.34, 0.62, 0.95, 1), day_amount))
			sm.set_shader_parameter("sky_mid_color", Color(0.004, 0.007, 0.014, 1).lerp(Color(0.55, 0.75, 0.98, 1), day_amount))
			sm.set_shader_parameter("sky_horizon_color", Color(0.012, 0.016, 0.026, 1).lerp(Color(0.78, 0.90, 1.0, 1).lerp(Color(1.0,.69,.43),golden_hour*.45), day_amount))
			sm.set_shader_parameter("sky_energy", lerp(0.10, 1.0, day_amount))
			sm.set_shader_parameter("ground_bottom_color", Color(0.003, 0.004, 0.006, 1).lerp(Color(0.17, 0.19, 0.14, 1), day_amount))
			sm.set_shader_parameter("ground_horizon_color", Color(0.010, 0.012, 0.018, 1).lerp(Color(0.30, 0.36, 0.30, 1), day_amount))
			sm.set_shader_parameter("ground_energy", lerp(0.10, 1.0, day_amount))

func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day}

func from_dict(data: Dictionary) -> void:
	last_was_night = is_night()
	_update_lighting()
