extends Node
class_name AudioSystem

const AMBIENT_DAY_PATHS := [
	"res://assets/external/audio/ambient_day.ogg",
	"res://assets/external/audio/ambient_day.wav",
	"res://assets/external/audio/forest_wind_day.ogg",
	"res://assets/external/audio/forest_wind_day.wav"
]
const AMBIENT_NIGHT_PATHS := [
	"res://assets/external/audio/ambient_night.ogg",
	"res://assets/external/audio/ambient_night.wav",
	"res://assets/external/audio/night_wind.ogg",
	"res://assets/external/audio/night_wind.wav"
]
const WIND_PATHS := [
	"res://assets/external/audio/wind_loop.ogg",
	"res://assets/external/audio/wind_loop.wav"
]
const RIVER_WATER_PATHS := [
	"res://assets/external/audio/downloaded/babbling_brook_orange.mp3",
	"res://assets/external/audio/river_water_loop.ogg",
	"res://assets/external/audio/river_water_loop.wav",
	"res://assets/external/audio/water_river_loop.ogg",
	"res://assets/external/audio/water_river_loop.wav"
]
const AXE_CHOP_PATHS := [
	"res://assets/external/audio/axe_chop.ogg",
	"res://assets/external/audio/axe_chop.wav",
	"res://assets/external/audio/wood_chop.ogg",
	"res://assets/external/audio/wood_chop.wav"
]
const FOREST_BIRD_PATHS := [
	"res://assets/external/audio/downloaded/forest_birds_loop.mp3",
	"res://assets/external/audio/downloaded/deer_sound_orange.mp3",
	"res://assets/external/audio/animal_deer_call.wav"
]
const ANIMAL_DEER_PATHS := [
	"res://assets/external/audio/downloaded/deer_sound_orange.mp3",
	"res://assets/external/audio/animal_deer_call.ogg",
	"res://assets/external/audio/animal_deer_call.wav",
	"res://assets/external/audio/deer_call.ogg",
	"res://assets/external/audio/deer_call.wav"
]
const ANIMAL_FOX_PATHS := [
	"res://assets/external/audio/downloaded/fox_calls_orange.mp3",
	"res://assets/external/audio/animal_fox_call.ogg",
	"res://assets/external/audio/animal_fox_call.wav",
	"res://assets/external/audio/fox_call.ogg",
	"res://assets/external/audio/fox_call.wav"
]

const FOOTSTEP_GRASS_PATHS := [
	"res://assets/external/audio/footstep_grass_01.ogg",
	"res://assets/external/audio/footstep_grass_02.ogg",
	"res://assets/external/audio/footstep_grass_03.ogg",
	"res://assets/external/audio/footstep_grass_01.wav",
	"res://assets/external/audio/footstep_grass_02.wav",
	"res://assets/external/audio/footstep_grass_03.wav"
]
const FOOTSTEP_ROAD_PATHS := [
	"res://assets/external/audio/footstep_road_01.ogg",
	"res://assets/external/audio/footstep_road_02.ogg",
	"res://assets/external/audio/footstep_road_03.ogg",
	"res://assets/external/audio/footstep_gravel_01.wav",
	"res://assets/external/audio/footstep_gravel_02.wav",
	"res://assets/external/audio/footstep_gravel_03.wav"
]
const FOOTSTEP_WOOD_PATHS := [
	"res://assets/external/audio/footstep_wood_01.ogg",
	"res://assets/external/audio/footstep_wood_02.ogg",
	"res://assets/external/audio/footstep_wood_03.ogg",
	"res://assets/external/audio/footstep_wood_01.wav",
	"res://assets/external/audio/footstep_wood_02.wav",
	"res://assets/external/audio/footstep_wood_03.wav"
]

var player
var day_cycle
var ambient_day_player: AudioStreamPlayer
var ambient_night_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var river_player: AudioStreamPlayer3D
var footstep_player: AudioStreamPlayer3D
var action_player: AudioStreamPlayer3D
var animal_call_player: AudioStreamPlayer3D
var forest_player: AudioStreamPlayer3D
var forest_sounds: Array = []
var _forest_call_timer := 8.0
var _forest_loop_stream: AudioStream = null
var grass_steps: Array = []
var road_steps: Array = []
var wood_steps: Array = []
var chop_sounds: Array = []
var deer_calls: Array = []
var fox_calls: Array = []
var step_timer := 0.0
var step_index := 0
var animal_call_timer := 18.0

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
	_update_ambience()
	_update_river(delta)
	_update_forest_ambience(delta)
	_update_animal_calls(delta)
	_update_footsteps(delta)

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
	wind_player.volume_db = -18.0
	add_child(wind_player)

	river_player = AudioStreamPlayer3D.new()
	river_player.name = "RiverWater"
	river_player.unit_size = 3.5
	river_player.max_distance = 62.0
	river_player.volume_db = -80.0
	add_child(river_player)

	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "Footsteps"
	footstep_player.unit_size = 1.0
	footstep_player.max_distance = 16.0
	footstep_player.volume_db = -2.0
	add_child(footstep_player)

	action_player = AudioStreamPlayer3D.new()
	action_player.name = "ActionSounds"
	action_player.unit_size = 1.0
	action_player.max_distance = 24.0
	action_player.volume_db = -1.0
	add_child(action_player)

	animal_call_player = AudioStreamPlayer3D.new()
	animal_call_player.name = "AnimalCalls"
	animal_call_player.unit_size = 2.5
	animal_call_player.max_distance = 48.0
	animal_call_player.volume_db = -18.0
	add_child(animal_call_player)

	forest_player = AudioStreamPlayer3D.new()
	forest_player.name = "ForestBirds"
	forest_player.unit_size = 4.0
	forest_player.max_distance = 80.0
	forest_player.volume_db = -80.0
	add_child(forest_player)

func _load_audio() -> void:
	_assign_loop(ambient_day_player, _load_first_stream(AMBIENT_DAY_PATHS))
	_assign_loop(ambient_night_player, _load_first_stream(AMBIENT_NIGHT_PATHS))
	_assign_loop(wind_player, _load_first_stream(WIND_PATHS))
	_assign_loop_3d(river_player, _load_first_stream(RIVER_WATER_PATHS))
	grass_steps = _load_streams(FOOTSTEP_GRASS_PATHS)
	road_steps = _load_streams(FOOTSTEP_ROAD_PATHS)
	wood_steps = _load_streams(FOOTSTEP_WOOD_PATHS)
	chop_sounds = _load_streams(AXE_CHOP_PATHS)
	if chop_sounds.is_empty():
		chop_sounds = wood_steps
	deer_calls = _load_streams(ANIMAL_DEER_PATHS)
	fox_calls = _load_streams(ANIMAL_FOX_PATHS)
	forest_sounds = _load_streams(FOREST_BIRD_PATHS)
	if not forest_sounds.is_empty():
		_forest_loop_stream = forest_sounds[0]
		_make_loop(_forest_loop_stream)
		forest_player.stream = _forest_loop_stream
		forest_player.volume_db = -80.0

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

func _load_first_stream(paths: Array) -> AudioStream:
	for path in paths:
		var stream := _load_stream_from_path(str(path))
		if stream != null:
			return stream
	return null

func _load_stream_from_path(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStream:
			return stream
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

func _update_ambience() -> void:
	var night_amount: float = 1.0 if day_cycle.is_night() else 0.0
	if day_cycle.time_of_day >= 18.0 and day_cycle.time_of_day < 20.0:
		night_amount = inverse_lerp(18.0, 20.0, day_cycle.time_of_day)
	elif day_cycle.time_of_day >= 5.0 and day_cycle.time_of_day < 7.0:
		night_amount = 1.0 - inverse_lerp(5.0, 7.0, day_cycle.time_of_day)
	var day_volume: float = lerp(-13.0, -80.0, night_amount)
	var night_volume: float = lerp(-80.0, -15.0, night_amount)
	if ambient_day_player.stream != null:
		ambient_day_player.volume_db = day_volume + 4.0
	if ambient_night_player.stream != null:
		ambient_night_player.volume_db = night_volume + 4.0
	if wind_player.stream != null:
		wind_player.volume_db = -18.0 if player.in_shelter else -10.0

func _update_river(delta: float) -> void:
	if river_player == null or river_player.stream == null:
		return
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_nearest_river_audio_point"):
		river_player.volume_db = lerp(river_player.volume_db, -80.0, delta * 2.0)
		return
	var data = scene.call("get_nearest_river_audio_point", player.global_position)
	if not (data is Dictionary):
		return
	var river_pos: Vector3 = data.get("position", player.global_position)
	var distance: float = float(data.get("distance", 999.0))
	river_player.global_position = river_pos
	var target_volume := -80.0
	if player.is_in_water:
		target_volume = -1.5
	elif distance < 58.0:
		target_volume = lerp(-3.5, -26.0, clamp((distance - 4.0) / 54.0, 0.0, 1.0))
	river_player.volume_db = lerp(river_player.volume_db, target_volume, delta * 3.2)
	if target_volume > -75.0 and not river_player.playing:
		river_player.play()

func _update_forest_ambience(delta: float) -> void:
	if forest_player == null or player == null:
		return
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_forest_audio_point"):
		forest_player.volume_db = lerp(forest_player.volume_db, -80.0, delta * 2.0)
		return
	var data = scene.call("get_forest_audio_point", player.global_position)
	if not (data is Dictionary):
		return
	var forest_pos: Vector3 = data.get("position", player.global_position)
	var distance: float = float(data.get("distance", 999.0))
	forest_player.global_position = forest_pos
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
		if distance > 46.0 or distance < 9.0:
			continue
		if chosen == null or distance < chosen_distance or (distance < 18.0 and randf() < 0.45):
			chosen = animal
			chosen_distance = distance
	if chosen == null:
		animal_call_timer = randf_range(18.0, 34.0)
		return
	var animal_type := "deer"
	if chosen.get("animal_type") != null:
		animal_type = str(chosen.get("animal_type"))
	var calls := fox_calls if animal_type == "fox" else deer_calls
	if calls.is_empty():
		animal_call_timer = randf_range(24.0, 42.0)
		return
	var close := chosen_distance < 18.0
	if close and randf() < 0.78:
		animal_call_timer = randf_range(14.0, 26.0)
		return
	_play_one_shot_at(animal_call_player, calls, chosen.global_position, -20.0 if close else -27.0, randf_range(0.96, 1.03))
	animal_call_timer = randf_range(26.0, 52.0)

func play_chop_at(pos: Vector3) -> void:
	_play_one_shot_at(action_player, chop_sounds, pos, -1.0, randf_range(0.90, 1.06))

func _play_one_shot_at(player_node: AudioStreamPlayer3D, streams: Array, pos: Vector3, volume: float, pitch: float) -> void:
	if player_node == null or streams.is_empty():
		return
	var stream = streams[randi() % streams.size()]
	if not stream is AudioStream:
		return
	player_node.stop()
	player_node.global_position = pos
	player_node.volume_db = volume
	player_node.pitch_scale = pitch
	player_node.stream = stream
	player_node.play()

func _update_footsteps(delta: float) -> void:
	if not player.is_on_floor():
		step_timer = 0.0
		return
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() < 0.1:
		step_timer = 0.0
		return
	var interval: float = 0.58
	if player.is_sprinting:
		interval = 0.34
	elif player.is_crouching:
		interval = 0.82
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = interval
		_play_step()

func _play_step() -> void:
	var pool: Array = _get_surface_steps()
	if pool.is_empty():
		return
	step_index = (step_index + 1) % pool.size()
	var stream = pool[step_index]
	if stream is AudioStream:
		footstep_player.global_position = player.global_position
		footstep_player.pitch_scale = randf_range(0.92, 1.08)
		footstep_player.stream = stream
		footstep_player.play()

func _get_surface_steps() -> Array:
	if _is_inside_building():
		return wood_steps if not wood_steps.is_empty() else grass_steps
	if abs(player.global_position.x - 8.0) < 4.6:
		return road_steps if not road_steps.is_empty() else grass_steps
	return grass_steps

func _is_inside_building() -> bool:
	var p: Vector3 = player.global_position
	if p.distance_to(Vector3.ZERO) < 7.5:
		return true
	var building_positions := [
		Vector3(-25, 0, -18),
		Vector3(-38, 0, 18),
		Vector3(23, 0, 18),
		Vector3(42, 0, 26),
		Vector3(-12, 0, 42),
		Vector3(33, 0, -30),
		Vector3(45, 0, 0),
		Vector3(-42, 0, -42)
	]
	for pos in building_positions:
		if Vector2(p.x - pos.x, p.z - pos.z).length() < 5.5:
			return true
	return false
