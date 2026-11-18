extends Node
class_name AudioSystem

const AMBIENT_DAY_PATHS := []
const AMBIENT_NIGHT_PATHS := [
	"res://assets/external/audio/ambient_night.wav"
]
const WIND_PATHS := [
	"res://assets/external/audio/wind_loop.wav"
]
const RIVER_WATER_PATHS := [
	"res://assets/external/audio/downloaded/rio.mp3",
	"res://assets/external/audio/river_water_loop.wav"
]
const AXE_CHOP_PATHS := [
	"res://cortarArbol.mp3"
]
const FOREST_BIRD_PATHS := [
	"res://assets/external/audio/downloaded/pajaros.mp3"
]
const ANIMAL_DEER_PATHS := [
	"res://assets/external/audio/animal_deer_call.wav"
]
const ANIMAL_FOX_PATHS := [
	"res://assets/external/audio/animal_fox_call.wav"
]
const ANIMAL_WOLF_PATHS := [
	"res://assets/external/audio/downloaded/aullidos.mp3",
	"res://assets/external/audio/downloaded/wolf_howl.wav",
	"res://assets/external/audio/downloaded/wolf_growl.wav"
]

const FOOTSTEP_GRASS_PATHS := [
	"res://assets/external/audio/footstep_grass_01.wav",
	"res://assets/external/audio/footstep_grass_02.wav",
	"res://assets/external/audio/footstep_grass_03.wav"
]
const FOOTSTEP_ROAD_PATHS := [
	"res://assets/external/audio/footstep_gravel_01.wav",
	"res://assets/external/audio/footstep_gravel_02.wav",
	"res://assets/external/audio/footstep_gravel_03.wav"
]
const FOOTSTEP_WOOD_PATHS := [
	"res://assets/external/audio/footstep_wood_01.wav",
	"res://assets/external/audio/footstep_wood_02.wav",
	"res://assets/external/audio/footstep_wood_03.wav"
]
const WATER_OBJECT_SPLASH_PATHS := [
	"res://objetocaeagua.mp3"
]
const WATER_FOOTSTEP_SPLASH_PATHS := [
	"res://andarporagua.mp3"
]
const DOOR_OPEN_PATHS := [
	"res://abrirpuerta.mp3"
]
const DOOR_CLOSE_PATHS := [
	"res://cerrarpuerta.mp3"
]
const DOOR_OPEN_START_SECONDS := 2.45
const DOOR_CLOSE_START_SECONDS := 1.95
const WATER_FOOTSTEP_START_SECONDS := 4.0
const WATER_OBJECT_START_SECONDS := 2.0
const WATER_OBJECT_END_SECONDS := 5.0

var player
var day_cycle
# Pasos de actores remotos: metronomo propio por actor (pid/aid), fase de
# variacion de sample y pool round-robin de players 3D.
const REMOTE_STEP_POOL := 10
const REMOTE_STEP_MAX_DIST := 34.0
var _remote_step_players: Array = []
var _remote_step_index := 0
var _remote_step_t: Dictionary = {}     # "p:3"/"a:wolf_4" -> s al proximo paso
var _remote_step_phase: Dictionary = {} # misma clave -> indice de variacion
var _remote_step_pos: Dictionary = {}
var water_step_shots: Array = []
var ambient_day_player: AudioStreamPlayer
var ambient_night_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var thunder_player: AudioStreamPlayer
var river_player: AudioStreamPlayer3D
var campfire_player: AudioStreamPlayer3D
var footstep_player: AudioStreamPlayer3D
var water_object_splash_player: AudioStreamPlayer3D
var water_footstep_player: AudioStreamPlayer3D
var door_player: AudioStreamPlayer3D
var action_player: AudioStreamPlayer3D
var animal_call_player: AudioStreamPlayer3D
var forest_player: AudioStreamPlayer
var forest_sounds: Array = []
var _forest_call_timer := 8.0
var _forest_loop_stream: AudioStream = null
var grass_steps: Array = []
var road_steps: Array = []
var wood_steps: Array = []
var water_object_splashes: Array = []
var water_footstep_splashes: Array = []
var door_open_sounds: Array = []
var door_close_sounds: Array = []
var _water_object_sound_token := 0
var chop_sounds: Array = []
var deer_calls: Array = []
var fox_calls: Array = []
var wolf_calls: Array = []
var step_timer := 0.0
var step_index := 0
var animal_call_timer := 18.0
var _spatial_audio_refresh_accum := 0.10
var _cached_river_audio: Dictionary = {}
var _cached_forest_audio: Dictionary = {}
var _cached_campfire_audio: Dictionary = {}

func setup(new_player, new_day_cycle) -> void:
	player = new_player
	day_cycle = new_day_cycle
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, false)
		AudioServer.set_bus_volume_db(master_index, 0.0)
	_create_players()
	_load_audio()

func _process(delta: float) -> void:
	if player == null or day_cycle == null:
		return
	_spatial_audio_refresh_accum += delta
	var refresh_spatial := _spatial_audio_refresh_accum >= 0.10
	if refresh_spatial:
		_spatial_audio_refresh_accum = 0.0
	if refresh_spatial:
		_update_ambience()
	_update_river(delta, refresh_spatial)
	_update_campfire(delta, refresh_spatial)
	_update_forest_ambience(delta, refresh_spatial)
	_update_animal_calls(delta)
	_update_footsteps(delta)
	_update_remote_footsteps(delta)

func _create_players() -> void:
	ambient_day_player = AudioStreamPlayer.new()
	ambient_day_player.name = "AmbientDay"
	ambient_day_player.volume_db = -80.0
	add_child(ambient_day_player)

	ambient_night_player = AudioStreamPlayer.new()
	ambient_night_player.name = "AmbientNight"
	ambient_night_player.volume_db = -80.0
	add_child(ambient_night_player)

	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindLoop"
	wind_player.volume_db = -8.0
	add_child(wind_player)

	rain_player = AudioStreamPlayer.new()
	rain_player.name = "RainLoop"
	rain_player.volume_db = -80.0
	add_child(rain_player)

	thunder_player = AudioStreamPlayer.new()
	thunder_player.name = "Thunder"
	thunder_player.volume_db = -6.0
	add_child(thunder_player)

	river_player = AudioStreamPlayer3D.new()
	river_player.name = "RiverWater"
	river_player.unit_size = 3.5
	river_player.max_distance = 62.0
	river_player.volume_db = -80.0
	add_child(river_player)

	campfire_player = AudioStreamPlayer3D.new()
	campfire_player.name = "CampfireCrackle"
	campfire_player.unit_size = 2.4
	campfire_player.max_distance = 26.0
	campfire_player.volume_db = -80.0
	add_child(campfire_player)

	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "Footsteps"
	footstep_player.unit_size = 6.0
	footstep_player.max_distance = 40.0
	footstep_player.volume_db = 8.0
	add_child(footstep_player)

	water_object_splash_player = AudioStreamPlayer3D.new()
	water_object_splash_player.name = "WaterObjectSplash"
	water_object_splash_player.unit_size = 8.0
	water_object_splash_player.max_distance = 80.0
	water_object_splash_player.volume_db = 12.0
	water_object_splash_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(water_object_splash_player)

	water_footstep_player = AudioStreamPlayer3D.new()
	water_footstep_player.name = "WaterFootsteps"
	water_footstep_player.unit_size = 8.0
	water_footstep_player.max_distance = 60.0
	water_footstep_player.volume_db = 10.0
	water_footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(water_footstep_player)

	door_player = AudioStreamPlayer3D.new()
	door_player.name = "DoorSounds"
	door_player.unit_size = 9.0
	door_player.max_distance = 35.0
	door_player.volume_db = 10.0
	door_player.max_db = 6.0
	add_child(door_player)

	# Pool para pasos de actores remotos (jugadores, bots y fauna): el cliente
	# ya recibe posicion+anim en cada sync — el sonido se genera local, sin
	# trafico nuevo. Round-robin evita que dos actores se corten el paso.
	for i in range(REMOTE_STEP_POOL):
		var rsp := AudioStreamPlayer3D.new()
		rsp.name = "RemoteStep%d" % i
		rsp.unit_size = 5.0
		rsp.max_distance = 38.0
		rsp.volume_db = 5.0
		add_child(rsp)
		_remote_step_players.append(rsp)



	action_player = AudioStreamPlayer3D.new()
	action_player.name = "ActionSounds"
	action_player.unit_size = 2.0
	action_player.max_distance = 30.0
	action_player.volume_db = 4.0
	add_child(action_player)

	animal_call_player = AudioStreamPlayer3D.new()
	animal_call_player.name = "AnimalCalls"
	animal_call_player.unit_size = 0.5
	animal_call_player.max_distance = 14.0
	animal_call_player.volume_db = -24.0
	animal_call_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(animal_call_player)

	forest_player = AudioStreamPlayer.new()
	forest_player.name = "ForestBirds"
	forest_player.volume_db = -80.0
	add_child(forest_player)

func _load_audio() -> void:
	_assign_loop(ambient_day_player, _load_first_stream(AMBIENT_DAY_PATHS))
	_assign_loop(ambient_night_player, _load_first_stream(AMBIENT_NIGHT_PATHS))
	_assign_loop(wind_player, _load_first_stream(WIND_PATHS))
	_assign_loop_3d(river_player, _load_first_stream(RIVER_WATER_PATHS))
	campfire_player.stream = _generate_campfire_stream()
	grass_steps = _load_streams(FOOTSTEP_GRASS_PATHS)
	road_steps = _load_streams(FOOTSTEP_ROAD_PATHS)
	wood_steps = _load_streams(FOOTSTEP_WOOD_PATHS)
	water_object_splashes = _load_streams(WATER_OBJECT_SPLASH_PATHS)
	water_footstep_splashes = _load_streams(WATER_FOOTSTEP_SPLASH_PATHS)
	# This recording is a single splash. The MP3 above is a long loop and
	# must never be assigned to the shared remote one-shot pool.
	water_step_shots = _load_streams(["res://assets/external/audio/water/water_footstep_splash.wav"])
	door_open_sounds = _load_streams(DOOR_OPEN_PATHS)
	door_close_sounds = _load_streams(DOOR_CLOSE_PATHS)
	for stream in water_footstep_splashes:
		if stream is AudioStreamMP3:
			# The water-walking recording has an intro before the useful loop.
			(stream as AudioStreamMP3).loop = true
			(stream as AudioStreamMP3).loop_offset = WATER_FOOTSTEP_START_SECONDS
	chop_sounds = _load_streams(AXE_CHOP_PATHS)
	if chop_sounds.is_empty():
		chop_sounds = wood_steps
	deer_calls = _load_streams(ANIMAL_DEER_PATHS)
	fox_calls = _load_streams(ANIMAL_FOX_PATHS)
	wolf_calls = _load_streams(ANIMAL_WOLF_PATHS)
	forest_sounds = _load_streams(FOREST_BIRD_PATHS)
	if not forest_sounds.is_empty():
		_forest_loop_stream = forest_sounds[0]
		_make_loop(_forest_loop_stream)
		forest_player.stream = _forest_loop_stream
		forest_player.volume_db = -80.0
		forest_player.play()

func _assign_loop(player_node: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	_make_loop(stream)
	player_node.stream = stream
	player_node.play()

func _assign_loop_3d(player_node: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if stream == null:
		return
	_make_loop(stream)
	player_node.stream = stream
	player_node.play()

func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

func _load_first_stream(paths: Array) -> AudioStream:
	for path in paths:
		var stream := _load_stream_from_path(str(path))
		if stream != null:
			return stream
	return null

func _load_stream_from_path(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		# load() cachea: sin ella cada reproducción leía y decodificaba de disco.
		# Duplicar evita que _make_loop mute la instancia compartida en ResourceLoader.
		var loaded = load(path)
		if loaded is AudioStream:
			return (loaded as AudioStream).duplicate()
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if path.get_extension().to_lower() == "wav" and FileAccess.file_exists(disk_path):
		var wav_stream := AudioStreamWAV.load_from_file(disk_path)
		if wav_stream is AudioStream:
			return wav_stream
	if path.get_extension().to_lower() == "mp3" and FileAccess.file_exists(disk_path):
		var mp3_stream := AudioStreamMP3.load_from_file(disk_path)
		if mp3_stream is AudioStream:
			return mp3_stream
	return null

func _load_streams(paths: Array) -> Array:
	var streams := []
	for path in paths:
		var stream := _load_stream_from_path(str(path))
		if stream != null:
			streams.append(stream)
	return streams

var _rain_stream_cache: AudioStream = null
var _thunder_stream_cache: AudioStream = null

func set_rain_volume(rain_intensity: float, storm: bool) -> void:
	# rain_intensity: 0.0 to 1.0
	if rain_player == null:
		return
	if rain_intensity <= 0.01:
		rain_player.volume_db = -80.0
		rain_player.stop()
		return
	# Generate rain stream once and cache it
	if _rain_stream_cache == null:
		_rain_stream_cache = _generate_rain_stream()
	if rain_player.stream == null:
		rain_player.stream = _rain_stream_cache
	# Volume: louder during storms
	var vol: float = lerp(-30.0, -10.0, rain_intensity)
	if storm:
		vol += 4.0
	rain_player.volume_db = vol
	if not rain_player.playing:
		rain_player.play()

func play_thunder() -> void:
	if thunder_player == null:
		return
	# Generate thunder stream once and cache it
	if _thunder_stream_cache == null:
		_thunder_stream_cache = _generate_thunder_stream()
	if thunder_player.stream == null:
		thunder_player.stream = _thunder_stream_cache
	thunder_player.volume_db = randf_range(-8.0, -2.0)
	thunder_player.play()

func _generate_rain_stream() -> AudioStream:
	# Generate a looping rain sound using white noise
	var sample_rate := 22050
	var duration := 2.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		# Filtered white noise for rain sound
		var noise_val := randf_range(-0.15, 0.15)
		# Add some low-frequency variation
		noise_val += sin(i * 0.001) * 0.05
		var sample := int(clamp(noise_val, -1.0, 1.0) * 32767)
		# Encode as 16-bit little-endian
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream

func _generate_thunder_stream() -> AudioStream:
	# Generate a thunder rumble sound (low-frequency noise burst)
	var sample_rate := 22050
	var duration := 3.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var low_pass := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Envelope: quick attack, long decay
		var env: float
		if t < 0.05:
			env = t / 0.05
		else:
			env = exp(-(t - 0.05) * 3.0)
		# Low-frequency rumble
		low_pass = lerp(low_pass, randf_range(-1.0, 1.0), 0.05)
		var sample_val := low_pass * env * 0.6
		var sample := int(clamp(sample_val, -1.0, 1.0) * 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream

func _update_ambience() -> void:
	var night_amount: float = 1.0 if day_cycle.is_night() else 0.0
	if day_cycle.time_of_day >= 20.5 and day_cycle.time_of_day < 21.5:
		night_amount = inverse_lerp(20.5, 21.5, day_cycle.time_of_day)
	elif day_cycle.time_of_day >= 5.0 and day_cycle.time_of_day < 7.0:
		night_amount = 1.0 - inverse_lerp(5.0, 7.0, day_cycle.time_of_day)
	var day_volume: float = lerp(-13.0, -80.0, night_amount)
	var night_volume: float = lerp(-80.0, -15.0, night_amount)
	if ambient_day_player.stream != null:
		ambient_day_player.volume_db = day_volume + 4.0
	if ambient_night_player.stream != null:
		ambient_night_player.volume_db = night_volume + 4.0
	if wind_player.stream != null:
		wind_player.volume_db = -8.0 if player.in_shelter else -3.0

func _update_river(delta: float, refresh_spatial := true) -> void:
	if river_player == null or river_player.stream == null:
		return
	if refresh_spatial or _cached_river_audio.is_empty():
		var scene := get_tree().current_scene
		if scene == null or not scene.has_method("get_nearest_river_audio_point"):
			_cached_river_audio.clear()
		else:
			var sampled = scene.call("get_nearest_river_audio_point", player.global_position)
			_cached_river_audio = sampled if sampled is Dictionary else {}
	if _cached_river_audio.is_empty():
		river_player.volume_db = lerp(river_player.volume_db, -80.0, delta * 2.0)
		return
	var river_pos: Vector3 = _cached_river_audio.get("position", player.global_position)
	var distance: float = float(_cached_river_audio.get("distance", 999.0))
	river_player.global_position = river_pos
	var target_volume := -80.0
	if player.is_in_water:
		target_volume = -1.5
	elif distance < 58.0:
		target_volume = lerp(-3.5, -26.0, clamp((distance - 4.0) / 54.0, 0.0, 1.0))
	river_player.volume_db = lerp(river_player.volume_db, target_volume, delta * 3.2)
	if target_volume > -75.0 and not river_player.playing:
		river_player.play()

func _update_campfire(delta: float, refresh_spatial := true) -> void:
	if campfire_player == null or campfire_player.stream == null or player == null:
		return
	if refresh_spatial or _cached_campfire_audio.is_empty():
		_cached_campfire_audio.clear()
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("get_lit_campfire_positions"):
			var best := INF
			var best_pos := Vector3.ZERO
			for fp in scene.call("get_lit_campfire_positions"):
				var d: float = player.global_position.distance_to(fp)
				if d < best:
					best = d
					best_pos = fp
			if best < 30.0:
				_cached_campfire_audio = {"position": best_pos, "distance": best}
	if _cached_campfire_audio.is_empty():
		campfire_player.volume_db = lerp(campfire_player.volume_db, -80.0, delta * 3.0)
		return
	campfire_player.global_position = _cached_campfire_audio["position"]
	var distance: float = _cached_campfire_audio["distance"]
	var target := -80.0
	if distance < 16.0:
		target = lerp(-2.5, -30.0, clamp((distance - 1.2) / 14.8, 0.0, 1.0))
	campfire_player.volume_db = lerp(campfire_player.volume_db, target, delta * 4.0)
	if target > -75.0 and not campfire_player.playing:
		campfire_player.play()

func _generate_campfire_stream() -> AudioStream:
	# Crepitado procedural: siseo grave continuo (el fuego) + chasquidos
	# cortos aleatorios con decaimiento exponencial (la lena). Bucle de 4 s.
	var sample_rate := 22050
	var duration := 4.0
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240917
	var pops: Array = []
	var pt := rng.randf_range(0.02, 0.10)
	while pt < duration - 0.04:
		pops.append([int(pt * sample_rate), sample_rate * rng.randf_range(0.002, 0.011), rng.randf_range(0.16, 0.5)])
		pt += rng.randf_range(0.012, 0.16)
	var next_pop := 0
	var low1 := 0.0
	var low2 := 0.0
	for i in range(num_samples):
		low1 = lerp(low1, rng.randf_range(-1.0, 1.0), 0.06)
		low2 = lerp(low2, low1, 0.3)
		var s: float = low2 * (0.14 + 0.05 * sin(i * 0.00017) * sin(i * 0.000037))
		while next_pop < pops.size() and int(pops[next_pop][0]) + int(pops[next_pop][1] * 3.0) <= i:
			next_pop += 1
		for lookahead in range(2):
			var pi := next_pop + lookahead
			if pi >= pops.size():
				break
			var start := int(pops[pi][0])
			if i >= start:
				var age := float(i - start)
				s += rng.randf_range(-1.0, 1.0) * float(pops[pi][2]) * exp(-age / float(pops[pi][1]))
		var sample := int(clamp(s, -1.0, 1.0) * 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream

func _update_forest_ambience(delta: float, refresh_spatial := true) -> void:
	if forest_player == null or player == null:
		return
	if refresh_spatial or _cached_forest_audio.is_empty():
		var scene := get_tree().current_scene
		if scene == null or not scene.has_method("get_forest_audio_point"):
			_cached_forest_audio.clear()
		else:
			var sampled = scene.call("get_forest_audio_point", player.global_position)
			_cached_forest_audio = sampled if sampled is Dictionary else {}
	if _cached_forest_audio.is_empty():
		forest_player.volume_db = lerp(forest_player.volume_db, -80.0, delta * 2.0)
		return
	var distance: float = float(_cached_forest_audio.get("distance", 999.0))
	var target_vol := -80.0
	if distance < 75.0:
		target_vol = lerp(-5.0, -28.0, clamp((distance - 8.0) / 67.0, 0.0, 1.0))
	forest_player.volume_db = lerp(forest_player.volume_db, target_vol, delta * 2.5)
	if target_vol > -75.0 and not forest_player.playing:
		forest_player.play()

func _update_animal_calls(delta: float) -> void:
	animal_call_timer -= delta
	if animal_call_timer > 0.0 or player == null:
		return
	var chosen = null
	var chosen_distance := 9999.0
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not node is Node3D:
			continue
		var animal := node as Node3D
		var distance := animal.global_position.distance_to(player.global_position)
		if distance > 14.0 or distance < 6.0:
			continue
		if chosen == null or distance < chosen_distance or (distance < 10.0 and randf() < 0.45):
			chosen = animal
			chosen_distance = distance
	if chosen == null:
		animal_call_timer = randf_range(18.0, 34.0)
		return
	var animal_type := "deer"
	if chosen.get("animal_type") != null:
		animal_type = str(chosen.get("animal_type"))
	var calls: Array
	if animal_type == "wolf":
		calls = wolf_calls
	elif animal_type == "fox":
		calls = fox_calls
	else:
		calls = deer_calls
	if calls.is_empty():
		animal_call_timer = randf_range(24.0, 42.0)
		return
	var close := chosen_distance < 10.0
	if close and randf() < 0.78:
		animal_call_timer = randf_range(14.0, 26.0)
		return
	_play_one_shot_at(animal_call_player, calls, chosen.global_position, -28.0 if close else -36.0, randf_range(0.96, 1.03))
	animal_call_timer = randf_range(26.0, 52.0)

func play_chop_at(pos: Vector3) -> void:
	_play_one_shot_at(action_player, chop_sounds, pos, 4.0, randf_range(0.90, 1.06))

## Splash when an object hits the water. Kept separate from footsteps so a
## dropped item does not cut off the character's movement sound.
func play_water_splash(pos: Vector3, _is_object := true) -> void:
	if water_object_splashes.is_empty() or water_object_splash_player == null:
		return
	var stream = water_object_splashes[0]
	if not stream is AudioStream:
		return
	_water_object_sound_token += 1
	var token := _water_object_sound_token
	water_object_splash_player.stop()
	water_object_splash_player.global_position = pos
	water_object_splash_player.volume_db = randf_range(8.0, 14.0)
	water_object_splash_player.pitch_scale = randf_range(0.90, 1.08)
	water_object_splash_player.stream = stream
	water_object_splash_player.play(WATER_OBJECT_START_SECONDS)
	# Stop at five seconds, even if the source recording is longer.
	get_tree().create_timer(WATER_OBJECT_END_SECONDS - WATER_OBJECT_START_SECONDS).timeout.connect(func():
		if token == _water_object_sound_token and water_object_splash_player != null:
			water_object_splash_player.stop())

## Short, low-volume splash for a foot entering shallow water.
func play_water_step(pos: Vector3, running := false) -> void:
	if water_footstep_splashes.is_empty() or water_footstep_player == null:
		return
	var stream = water_footstep_splashes[0]
	if not stream is AudioStream:
		return
	water_footstep_player.global_position = pos
	water_footstep_player.volume_db = 6.0 if not running else 10.0
	if water_footstep_player.stream != stream:
		water_footstep_player.stream = stream
	if not water_footstep_player.playing:
		# Start after the four-second intro; loop_offset keeps the loop there.
		water_footstep_player.pitch_scale = randf_range(0.97, 1.03)
		water_footstep_player.play(WATER_FOOTSTEP_START_SECONDS)

func stop_water_step() -> void:
	if water_footstep_player != null:
		water_footstep_player.stop()

func play_door(pos: Vector3, opening: bool) -> void:
	var streams: Array = door_open_sounds if opening else door_close_sounds
	var offset := DOOR_OPEN_START_SECONDS if opening else DOOR_CLOSE_START_SECONDS
	var vol := 12.0 if opening else 9.0
	_play_one_shot_at(door_player, streams, pos, vol, randf_range(0.95, 1.05), offset)

## Compatibility entry point used by older water ripple code.
func play_sfx(effect: String, pos: Vector3 = Vector3.ZERO) -> void:
	if effect == "water_splash":
		play_water_splash(pos)
	elif effect == "water_step":
		play_water_step(pos)

var _chop_token := 0

func stop_chop() -> void:
	_chop_token += 1
	if action_player != null:
		action_player.stop()

func play_chop_loop_at(pos: Vector3, duration: float) -> void:
	var my_token := _chop_token + 1
	_chop_token = my_token
	if action_player == null or chop_sounds.is_empty():
		return
	# Play the chop sound once (the clip is ~10s, enough for the action duration)
	_play_one_shot_at(action_player, chop_sounds, pos, 4.0, randf_range(0.90, 1.06))
	# Poll for cancellation or duration expiry
	var elapsed := 0.0
	while elapsed < duration and _chop_token == my_token:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	# Stop the sound when done or cancelled
	if _chop_token == my_token and action_player != null:
		action_player.stop()

func _play_one_shot_at(player_node: AudioStreamPlayer3D, streams: Array, pos: Vector3, volume: float, pitch: float, start_seconds := 0.0) -> void:
	if player_node == null:
		print("[AUDIO] _play_one_shot_at: player_node is null")
		return
	if streams.is_empty():
		print("[AUDIO] _play_one_shot_at: streams is EMPTY for player ", player_node.name)
		return
	var stream = streams[randi() % streams.size()]
	if not stream is AudioStream:
		print("[AUDIO] _play_one_shot_at: stream is not AudioStream")
		return
	player_node.stop()
	player_node.global_position = pos
	player_node.volume_db = volume
	player_node.pitch_scale = pitch
	player_node.stream = stream
	player_node.play(start_seconds)

func _update_footsteps(delta: float) -> void:
	# One surface/cadence system for the local survivor and remote survivors.
	# Input and an animation can remain active while a wall stops the body.
	stop_water_step()
	if not is_instance_valid(player): return
	var moving := Vector2(player.velocity.x, player.velocity.z).length()
	if is_instance_valid(player.get("rowing_boat")) or player.is_dead or player.is_sleeping or player.is_sitting or player.is_prone or (not player.is_on_floor() and not player.is_in_water):
		moving = 0.0
	if moving < .15:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = _step_interval(moving, player.is_crouching)
		_play_surface_step()

static func _step_interval(speed: float, crouched: bool) -> float:
	return clampf(1.05 / maxf(speed,.1), .62, .95) if crouched else clampf(1.65 / maxf(speed,.1), .29, .65)

func _play_surface_step() -> void:
	var pool: Array = _get_surface_steps()
	if pool.is_empty():
		return
	step_index = (step_index + 1) % pool.size()
	var stream = pool[step_index]
	if stream is AudioStream:
		footstep_player.global_position = player.global_position
		footstep_player.pitch_scale = randf_range(0.92, 1.08)
		footstep_player.volume_db = -9.0 if player.is_crouching else (2.5 if player.is_sprinting else 0.0)
		footstep_player.stream = stream
		footstep_player.play()

func _get_surface_steps() -> Array:
	return _surface_steps_at(player.global_position)

func _surface_steps_at(pos: Vector3) -> Array:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_river_depth_at") and float(scene.get_river_depth_at(pos)) > .05:
		return water_step_shots if not water_step_shots.is_empty() else grass_steps
	if _pos_inside_building(pos):
		return wood_steps if not wood_steps.is_empty() else grass_steps
	if scene != null and scene.has_method("_is_on_road") and scene._is_on_road(pos):
		return road_steps if not road_steps.is_empty() else grass_steps
	return grass_steps

# --- Pasos de actores remotos -------------------------------------------------
# El cliente ya recibe posicion+anim de jugadores remotos (humanos y bots) y de
# la fauna en cada sync: los pasos se sintetizan localmente — ningun RPC nuevo.
# Superficie por posicion del actor, igual que para el jugador local.

func _update_remote_footsteps(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or player == null or not is_instance_valid(player):
		return
	var ear: Vector3 = player.global_position
	var seen := {}
	var rp = scene.get("remote_players")
	if rp is Dictionary:
		for pid in (rp as Dictionary).keys():
			var p = (rp as Dictionary)[pid]
			if p != null and is_instance_valid(p) and p != player:
				_remote_actor_steps(seen, "p:%s" % str(pid), p, str(p.get("_puppet_anim")), delta, ear, false)
	var pa = scene.get("puppet_animals")
	if pa is Dictionary:
		for aid in (pa as Dictionary).keys():
			var a = (pa as Dictionary)[aid]
			if a != null and is_instance_valid(a) and not bool(a.get("_is_dead")):
				_remote_actor_steps(seen, "a:%s" % str(aid), a, str(a.get("current_anim_keyword")), delta, ear, true)
	for k in _remote_step_pos.keys():
		if not seen.has(k):
			_remote_step_t.erase(k)
			_remote_step_phase.erase(k)
			_remote_step_pos.erase(k)

func _remote_actor_steps(seen: Dictionary, key: String, node: Node3D, anim: String, delta: float, ear: Vector3, is_animal: bool) -> void:
	seen[key] = true
	var pos := node.global_position
	var previous: Vector3 = _remote_step_pos.get(key,pos)
	_remote_step_pos[key] = pos
	var displacement := pos-previous
	var speed := Vector2(displacement.x,displacement.z).length()/maxf(delta,.001)
	var anim_l := anim.to_lower()
	var kind := ""
	if anim_l.find("run") >= 0 or anim_l.find("chase") >= 0 or anim_l.find("trot") >= 0 or anim_l.find("gallop") >= 0 or anim_l.find("charge") >= 0:
		kind = "run"
	elif anim_l.find("sneak") >= 0 or node.get("is_crouching") == true:
		kind = "sneak"
	elif anim_l.find("walk") >= 0 or anim_l.find("strafe") >= 0 or anim_l.contains("stair"):
		kind = "walk"
	elif anim_l.contains("ladder") or anim_l.contains("climbing"):
		kind = "walk"
		speed = displacement.length()/maxf(delta,.001)
	if node.get("is_dead") == true or node.get("is_sleeping") == true or node.get("is_sitting") == true or node.get("is_prone") == true:
		kind = ""
	var d: float = Vector3(node.global_position.x - ear.x, 0.0, node.global_position.z - ear.z).length()
	if kind.is_empty() or d > REMOTE_STEP_MAX_DIST or speed < .15 or displacement.length() > maxf(1.0,delta*18.0):
		_remote_step_t.erase(key)
		_remote_step_phase.erase(key)
		return
	var interval := _step_interval(speed,kind == "sneak")
	if is_animal:
		interval *= 0.85 # cuatro patas: pasos algo mas frecuentes
	_remote_step_t[key] = float(_remote_step_t.get(key, interval)) - delta
	if float(_remote_step_t[key]) > 0.0:
		return
	_remote_step_t[key] = interval
	_play_remote_step(key, node.global_position, kind, is_animal)

func _play_remote_step(key: String, pos: Vector3, kind: String, is_animal: bool) -> void:
	var scene := get_tree().current_scene
	var in_water: bool = scene != null and scene.has_method("get_river_depth_at") and float(scene.get_river_depth_at(pos)) > .05
	var pool := _surface_steps_at(pos)
	if pool.is_empty() or _remote_step_players.is_empty():
		return
	var idx := int(_remote_step_phase.get(key, 0))
	_remote_step_phase[key] = idx + 1
	var ap: AudioStreamPlayer3D = _remote_step_players[_remote_step_index]
	_remote_step_index = (_remote_step_index + 1) % _remote_step_players.size()
	ap.global_position = pos
	ap.pitch_scale = randf_range(0.92, 1.08) * (0.85 if is_animal else 1.0)
	var db := 0.0
	if kind == "run":
		db += 2.5
	elif kind == "sneak":
		db -= 9.0
	if is_animal and not in_water:
		db -= 2.0 # patas/pesado: distinto timbre, no un zapato
	ap.volume_db = db
	ap.stream = pool[idx % pool.size()]
	ap.play()

func _pos_inside_building(p: Vector3) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.has_method("_is_player_in_house") and scene._is_player_in_house(p)
