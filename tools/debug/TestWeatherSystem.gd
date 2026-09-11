extends "res://scripts/Main.gd"
## Isolated weather regression scene: never loads/saves a game or fetches weather.
## Run with -- --full-world to render the actual map as well.

class WeatherPlayer extends Node3D:
	signal notice(message: String)
	var in_shelter := false
	var wetness := 0.0
	var stats := {"wetness": 0.0}

var failures := 0
var assertions := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("WEATHER TEST: " + message)

func _ready() -> void:
	seed(WORLD_SEED)
	_world_rng.seed = WORLD_SEED
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 12.0
	day_cycle._update_lighting()
	if "--full-world" in OS.get_cmdline_user_args():
		nav = NavPathfindingScript.new()
		world_streaming_mgr = WorldStreamingManager.new()
		add_child(world_streaming_mgr)
		world_streaming_mgr.setup(self)
		sector_persistence_mgr = SectorPersistenceManager.new()
		add_child(sector_persistence_mgr)
		await _create_map()
	else:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(100, 100)
		ground.mesh = plane
		ground.position = Vector3(252, 0, -254)
		add_child(ground)
	player = WeatherPlayer.new()
	player.position = Vector3(252, 0.4, -254)
	add_child(player)
	hud = HUDScript.new()
	add_child(hud)
	hud.set_process(false)
	audio_system = AudioSystemScript.new()
	add_child(audio_system)
	audio_system._create_players()
	_create_weather_particles()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(252, 3, -248)
	camera.look_at(Vector3(252, 3.5, -260))
	camera.far = 1800
	camera.current = true
	check(day_cycle.world_environment.environment.background_mode == Environment.BG_SKY, "Sky background is enabled")
	for code in [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]:
		hud._real_weather_code = code
		_update_weather_effects(2.0)
		check(_rain_particles.emitting == (code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]), "Rain code %d" % code)
		check(_snow_particles.emitting == (code in [71, 73, 75, 77, 85, 86]), "Snow code %d" % code)
		check(_storm_active == (code in [95, 96, 99]), "Storm code %d" % code)
	check(audio_system._rain_stream_cache.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Rain loops")
	check(audio_system._rain_stream_cache.loop_end > 0, "Rain loop has samples")
	audio_system.play_thunder()
	check(audio_system._thunder_stream_cache.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Thunder plays once")
	check(_lightning_bolt != null and _lightning_bolt.get_child_count() == 10, "Visible lightning geometry")
	check(_thunder_timer.wait_time > 0.5 and _thunder_timer.wait_time < 1.7, "Thunder distance delay")
	hud._real_weather_code = 95
	player.in_shelter = true
	var wetness_before: float = player.wetness
	_update_weather_effects(2.0)
	check(not _rain_particles.visible and not _rain_splash_particles.visible, "Shelter excludes rain and splashes")
	check(player.wetness == wetness_before, "Shelter excludes wetness")
	player.in_shelter = false
	_update_weather_effects(2.0)
	check(_rain_particles.visible, "Rain returns outside")
	var splash_material: StandardMaterial3D = _rain_splash_particles.draw_pass_1.material
	check(not splash_material.no_depth_test, "Splashes respect geometry depth")
	_apply_lightning_flash(1.0)
	day_cycle._update_lighting()
	var flash_energy: float = day_cycle.world_environment.environment.ambient_light_energy
	_apply_lightning_flash(0.0)
	day_cycle._update_lighting()
	check(flash_energy > day_cycle.world_environment.environment.ambient_light_energy + 0.8, "Lightning survives day/night update and restores")
	var valid_body := JSON.stringify({"current": {"temperature_2m": 22.0, "weather_code": 3, "rain": 0.0, "snowfall": 0.0, "wind_speed_10m": 18.0, "wind_direction_10m": 90.0}}).to_utf8_buffer()
	hud._on_weather_received(HTTPRequest.RESULT_SUCCESS, 200, [], valid_body)
	check(hud._real_temp_parsed == 22.0 and hud._real_weather_desc == "Cubierto" and hud._real_wind_speed == 18.0 and hud._real_wind_direction == 90.0, "Complete observation including wind")
	_update_weather_visuals(8.0)
	var sky_material := day_cycle.world_environment.environment.sky.sky_material as ShaderMaterial
	check(float(sky_material.get_shader_parameter("wind_strength")) >= 1.5 and absf(float(sky_material.get_shader_parameter("wind_direction")) - deg_to_rad(90.0)) < 0.8, "Clouds receive live wind")
	for bad_body in ["null", "[]", "{}", '{"current":{"temperature_2m":null}}']:
		hud._on_weather_received(HTTPRequest.RESULT_SUCCESS, 200, [], bad_body.to_utf8_buffer())
		check(hud._real_temp_parsed == 22.0 and hud._real_weather_code == 3, "Bad data preserves previous observation")
	hud._on_weather_received(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	check(hud._real_temp == "22°C" and hud._weather_retry_timer > 0.0, "Network failure preserves temperature and retries")
	hud._on_weather_received(HTTPRequest.RESULT_SUCCESS, 500, [], valid_body)
	check(hud._weather_retry_timer > 0.0, "HTTP errors retry")
	DirAccess.make_dir_recursive_absolute("res://work/weather_review")
	for sample in [[0, "clear"], [2, "partly_cloudy"], [3, "overcast"], [65, "rain"], [75, "snow"], [45, "fog"], [95, "storm"]]:
		hud._real_weather_code = sample[0]
		_update_weather_effects(2.0)
		_update_weather_visuals(60.0)
		_lightning_flash = 0.0
		_apply_lightning_flash(0.0)
		if _lightning_bolt != null: _lightning_bolt.visible = false
		day_cycle._update_lighting()
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/weather_review/%s.png" % sample[1])
	# Inspect the actual bolt and flash from a camera pointed at the strike.
	var original_camera_transform := camera.transform
	_create_lightning_bolt()
	camera.look_at(_lightning_bolt.get_child(4).global_position)
	_apply_lightning_flash(1.0)
	day_cycle._update_lighting()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/weather_review/lightning.png")
	camera.transform = original_camera_transform
	_lightning_bolt.visible = false
	_apply_lightning_flash(0.0)
	day_cycle.time_of_day = 0.0
	day_cycle._update_lighting()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/weather_review/night_storm.png")
	hud._real_weather_code = 0
	_update_weather_effects(2.0)
	_update_weather_visuals(60.0)
	day_cycle._update_lighting()
	check(not _rain_particles.emitting and not _snow_particles.emitting and not _rain_splash_particles.emitting, "Clear weather stops precipitation")
	check(not day_cycle.world_environment.environment.fog_enabled, "Fog clears after transition")
	check(not audio_system.rain_player.playing, "Clear weather stops rain sound")
	print("WEATHER TESTS COMPLETE: ", assertions, " assertions, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _process(_delta: float) -> void:
	pass
