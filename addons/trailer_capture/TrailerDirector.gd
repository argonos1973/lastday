extends Node

const CONFIG_PATH := "res://addons/trailer_capture/trailer_shots.json"
const CAPTURE_ARGUMENT := "--trailer-capture"

var _config: Dictionary = {}
var _world: Node = null
var _player: Node3D = null
var _hud: CanvasLayer = null
var _day_cycle: Node = null
var _camera: Camera3D = null
var _flashlight: Node3D = null
var _featured_wolf: Node3D = null
var _fire_nodes: Array[Node] = []
var _saved_files: Array[String] = []
var _output_directory := ""
var _stamp := ""

func _ready() -> void:
	if CAPTURE_ARGUMENT not in OS.get_cmdline_user_args():
		return
	call_deferred("_begin_capture")

func _begin_capture() -> void:
	_config = _load_config()
	if _config.is_empty():
		await _fail_and_quit("No se pudo leer %s" % CONFIG_PATH)
		return

	var game_scene: String = String(_config.get("game_scene", "res://scenes/Main.tscn"))
	if not ResourceLoader.exists(game_scene):
		await _fail_and_quit("No existe la escena del juego: %s" % game_scene)
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != game_scene:
		var scene_error: Error = get_tree().change_scene_to_file(game_scene)
		if scene_error != OK:
			await _fail_and_quit("Godot no pudo abrir: %s" % game_scene)
			return

	var nodes_ready: bool = await _wait_for_game_nodes(1200)
	if not nodes_ready:
		await _fail_and_quit("No se encontraron Main, Player, HUD o DayNightCycle.")
		return

	_prepare_capture_window()
	_prepare_game_state()
	_prepare_camera()
	_prepare_featured_wolf()
	_prepare_campfire()
	var directory_ready: bool = _create_output_directory()
	if not directory_ready:
		await _fail_and_quit("No se pudo crear la carpeta de capturas.")
		return

	var shots_value: Variant = _config.get("shots", [])
	if not shots_value is Array or (shots_value as Array).is_empty():
		await _fail_and_quit("El archivo de configuración no contiene tomas.")
		return
	var shots: Array = shots_value as Array
	for index in range(shots.size()):
		var shot_value: Variant = shots[index]
		if shot_value is Dictionary:
			await _capture_shot(shot_value as Dictionary, index, shots.size())

	var list_path: String = _write_shot_list(shots)
	if not list_path.is_empty():
		_saved_files.append(list_path)
	var zip_path: String = _create_zip()
	DisplayServer.window_set_title("Captura completada")
	print("[TRÁILER] CAPTURA COMPLETADA")
	print("[TRÁILER] Carpeta: ", _output_directory)
	print("[TRÁILER] ZIP: ", zip_path)
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var json_text: String = FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

func _wait_for_game_nodes(max_frames: int) -> bool:
	for frame_index in range(max_frames):
		await get_tree().process_frame
		_world = get_tree().current_scene
		if _world == null:
			continue
		var player_node: Node = _world.find_child("Player", true, false)
		var cycle_node: Node = _world.find_child("DayNightCycle", true, false)
		var hud_node: Node = get_tree().get_first_node_in_group("hud")
		if player_node is Node3D and cycle_node != null and hud_node is CanvasLayer:
			_player = player_node as Node3D
			_day_cycle = cycle_node
			_hud = hud_node as CanvasLayer
			print("[TRÁILER] Mundo preparado tras ", frame_index + 1, " fotogramas.")
			return true
	return false

func _prepare_capture_window() -> void:
	var resolution: Vector2i = _vector2i_from(_config.get("resolution", [1280, 720]), Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_title("Capturando tráiler automáticamente")

func _prepare_game_state() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.set_physics_process(false)
	_player.set("velocity", Vector3.ZERO)
	_day_cycle.set_process(false)
	_clear_hud_messages()

func _prepare_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "TrailerCaptureCamera"
	_camera.fov = 62.0
	_camera.near = 0.05
	_world.add_child(_camera)
	_camera.current = true
	var flashlight_node: Node = _player.find_child("Flashlight", true, false)
	if flashlight_node is Node3D:
		_flashlight = flashlight_node as Node3D

func _prepare_featured_wolf() -> void:
	var animals: Array[Node] = get_tree().get_nodes_in_group("wildlife")
	for animal in animals:
		if animal is Node3D and String(animal.get("animal_type")) == "wolf":
			_featured_wolf = animal as Node3D
			_featured_wolf.set_process(false)
			_featured_wolf.set_physics_process(false)
			_featured_wolf.visible = false
			break

func _prepare_campfire() -> void:
	var fire_position: Vector3 = _vector3_from(_config.get("campfire_position", [-55.1, 0.23, 27.2]), Vector3(-55.1, 0.23, 27.2))
	if _world.has_method("_create_campfire_fire"):
		_world.call("_create_campfire_fire", fire_position, "TrailerAutomaticCampfire")
	for node_name in ["TrailerAutomaticCampfireLight", "TrailerAutomaticCampfireParticles", "TrailerAutomaticCampfireSmoke"]:
		var fire_node: Node = _world.get_node_or_null(NodePath(node_name))
		if fire_node != null:
			_fire_nodes.append(fire_node)
			fire_node.set("visible", false)

func _create_output_directory() -> bool:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_stamp = "%04d%02d%02d_%02d%02d%02d" % [
		int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0)),
		int(now.get("hour", 0)), int(now.get("minute", 0)), int(now.get("second", 0))
	]
	var root_directory: String = ProjectSettings.globalize_path("res://trailer_captures")
	var root_error: Error = DirAccess.make_dir_recursive_absolute(root_directory)
	if root_error != OK:
		push_error("[TRÁILER] No se pudo crear: %s" % root_directory)
		return false
	var ignore_path: String = root_directory.path_join(".gdignore")
	if not FileAccess.file_exists(ignore_path):
		var ignore_file: FileAccess = FileAccess.open(ignore_path, FileAccess.WRITE)
		if ignore_file != null:
			ignore_file.store_string("")
			ignore_file.close()
	_output_directory = root_directory.path_join(_stamp)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(_output_directory)
	if directory_error != OK:
		push_error("[TRÁILER] No se pudo crear: %s" % _output_directory)
		return false
	return true

func _capture_shot(shot: Dictionary, index: int, total: int) -> void:
	var shot_name: String = _safe_filename(String(shot.get("name", "toma_%02d" % (index + 1))))
	DisplayServer.window_set_title("Capturando toma %d de %d — %s" % [index + 1, total, shot_name])

	_player.global_position = _vector3_from(shot.get("player", [0, 0.4, 0]), _player.global_position)
	var player_rotation: Vector3 = _player.rotation_degrees
	player_rotation.y = float(shot.get("player_yaw", 0.0))
	_player.rotation_degrees = player_rotation
	_player.set("velocity", Vector3.ZERO)

	_camera.global_position = _vector3_from(shot.get("camera", [0, 3, 6]), Vector3(0, 3, 6))
	var camera_target: Vector3 = _vector3_from(shot.get("target", [0, 1, 0]), Vector3(0, 1, 0))
	_camera.fov = float(shot.get("fov", 62.0))
	_camera.look_at(camera_target, Vector3.UP)

	_set_day_time(float(shot.get("time", 12.0)))
	_set_hud_visible(bool(shot.get("hud", false)))
	_set_flashlight_visible(bool(shot.get("flashlight", false)))
	_set_fire_visible(bool(shot.get("fire", false)))
	_set_wolf_for_shot(shot)
	_set_player_visible(not bool(shot.get("hide_player", false)))

	for settle_frame in range(6):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	_clear_hud_messages()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var output_path: String = _output_directory.path_join(shot_name + ".png")
	var save_error: Error = image.save_png(output_path)
	if save_error == OK:
		_saved_files.append(output_path)
		print("[TRÁILER] Guardada ", index + 1, "/", total, ": ", output_path)
	else:
		push_error("No se pudo guardar %s" % output_path)

func _set_day_time(hour: float) -> void:
	_day_cycle.set("time_of_day", hour)
	if _day_cycle.has_method("_update_lighting"):
		_day_cycle.call("_update_lighting")
	if _day_cycle.has_signal("time_changed"):
		_day_cycle.emit_signal("time_changed")

func _set_hud_visible(is_visible: bool) -> void:
	_hud.visible = is_visible
	_clear_hud_messages()

func _clear_hud_messages() -> void:
	if _hud == null:
		return
	var prompt_value: Variant = _hud.get("prompt_label")
	if prompt_value is Label:
		(prompt_value as Label).text = ""
	var notice_value: Variant = _hud.get("notice_label")
	if notice_value is Label:
		(notice_value as Label).text = ""
	if _hud.get("notice_timer") != null:
		_hud.set("notice_timer", 0.0)

func _set_flashlight_visible(is_visible: bool) -> void:
	if _flashlight != null:
		_flashlight.visible = is_visible

func _set_player_visible(is_visible: bool) -> void:
	if _player != null:
		_player.visible = is_visible

func _set_fire_visible(is_visible: bool) -> void:
	for fire_node in _fire_nodes:
		if is_instance_valid(fire_node):
			fire_node.set("visible", is_visible)

func _set_wolf_for_shot(shot: Dictionary) -> void:
	if _featured_wolf == null:
		return
	var show_wolf: bool = bool(shot.get("show_wolf", false))
	_featured_wolf.visible = show_wolf
	if not show_wolf:
		return
	_featured_wolf.global_position = _vector3_from(shot.get("wolf", [30, 0, -12]), Vector3(30, 0, -12))
	var wolf_rotation: Vector3 = _featured_wolf.rotation_degrees
	wolf_rotation.y = float(shot.get("wolf_yaw", 0.0))
	_featured_wolf.rotation_degrees = wolf_rotation

func _write_shot_list(shots: Array) -> String:
	var output_path: String = _output_directory.path_join("lista_de_tomas.txt")
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_line("CAPTURAS AUTOMÁTICAS PARA EL TRÁILER")
	file.store_line("Generadas: %s" % _stamp)
	file.store_line("")
	for index in range(shots.size()):
		var shot_value: Variant = shots[index]
		if shot_value is Dictionary:
			var shot: Dictionary = shot_value as Dictionary
			file.store_line("%02d. %s — hora %.2f — HUD %s" % [
				index + 1,
				String(shot.get("name", "Toma")),
				float(shot.get("time", 12.0)),
				"sí" if bool(shot.get("hud", false)) else "no"
			])
	file.store_line("")
	file.store_line("Envía el ZIP de esta carpeta para montar el vídeo final.")
	file.close()
	return output_path

func _create_zip() -> String:
	var zip_path: String = _output_directory.path_join("capturas_trailer_%s.zip" % _stamp)
	var packer := ZIPPacker.new()
	var open_error: Error = packer.open(zip_path)
	if open_error != OK:
		push_error("No se pudo crear el ZIP final.")
		return ""
	for file_path in _saved_files:
		var start_error: Error = packer.start_file(file_path.get_file())
		if start_error != OK:
			continue
		packer.write_file(FileAccess.get_file_as_bytes(file_path))
		packer.close_file()
	packer.close()
	return zip_path

func _vector3_from(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array:
		var numbers: Array = value as Array
		if numbers.size() >= 3:
			return Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2]))
	return fallback

func _vector2i_from(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array:
		var numbers: Array = value as Array
		if numbers.size() >= 2:
			return Vector2i(int(numbers[0]), int(numbers[1]))
	return fallback

func _safe_filename(value: String) -> String:
	var result: String = value.strip_edges().to_lower()
	for character in [" ", "á", "é", "í", "ó", "ú", "ñ", "/", "\\", ":", ";"]:
		var replacement: String = "_"
		match character:
			"á": replacement = "a"
			"é": replacement = "e"
			"í": replacement = "i"
			"ó": replacement = "o"
			"ú": replacement = "u"
			"ñ": replacement = "n"
		result = result.replace(character, replacement)
	return result

func _fail_and_quit(message: String) -> void:
	push_error("[TRÁILER] " + message)
	DisplayServer.window_set_title("Error en la captura del tráiler")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(1)
