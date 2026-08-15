extends Node

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "savegame.json"
const SAVE_PATH := SAVE_DIR + SAVE_FILE

signal save_loaded(data: Dictionary)

var _current_save: Dictionary = {}
var _auto_save_enabled: bool = false
var _saved_on_quit: bool = false

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if not _auto_save_enabled or _saved_on_quit:
		return
	var main = get_tree().current_scene
	if main == null or not is_instance_valid(main):
		return
	if not ("_quit_active" in main):
		return
	if main._quit_active:
		_do_save(main)

func enable_auto_save() -> void:
	_auto_save_enabled = true

func _do_save(main: Node) -> void:
	_saved_on_quit = true
	if "net" in main and main.net != null and main.net.is_connected:
		return
	if not main.has_method("get") or main.get("player") == null:
		return
	var player = main.get("player")
	if player == null or not is_instance_valid(player):
		return
	if not player.is_inside_tree():
		return
	var SaveGameHooksScript = load("res://scripts/SaveGameHooks.gd")
	if SaveGameHooksScript == null:
		return
	print("[SAVE] Saving on quit at pos=", player.global_position)
	save_game(SaveGameHooksScript.collect_player_data(player), SaveGameHooksScript.collect_world_data(main))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var main = get_tree().current_scene
		if main != null and is_instance_valid(main) and not _saved_on_quit:
			_do_save(main)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func get_save_path() -> String:
	return SAVE_PATH

func save_game(player_data: Dictionary, world_data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"player": player_data,
		"world": world_data,
	}
	var json_str := JSON.stringify(data, "  ")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGameManager: No se pudo abrir %s para escribir" % SAVE_PATH)
		return false
	f.store_string(json_str)
	f.close()
	_current_save = data
	return true

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveGameManager: No se pudo abrir %s para leer" % SAVE_PATH)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveGameManager: JSON invalido en %s" % SAVE_PATH)
		return {}
	_current_save = parsed
	save_loaded.emit(parsed)
	return parsed

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
	_current_save = {}

func get_saved_player() -> Dictionary:
	if _current_save.is_empty() and has_save():
		load_game()
	return _current_save.get("player", {})

func get_saved_world() -> Dictionary:
	if _current_save.is_empty() and has_save():
		load_game()
	return _current_save.get("world", {})

func get_saved_character_config() -> Dictionary:
	var p := get_saved_player()
	if p.is_empty():
		return {}
	return {
		"id": "saved",
		"name": p.get("char_name", "Superviviente"),
		"top": _str_to_color(p.get("top_color", "0.5,0.5,0.5")),
		"bottom": _str_to_color(p.get("bottom_color", "0.3,0.3,0.3")),
		"shoes": _str_to_color(p.get("shoes_color", "0.15,0.15,0.15")),
		"hair": _str_to_color(p.get("hair_color", "0.2,0.15,0.1")),
		"skin": _str_to_color(p.get("skin_color", "0.8,0.7,0.6")),
		"top_camo": p.get("top_camo", false),
		"bottom_camo": p.get("bottom_camo", false),
		"is_saved": true,
	}

func _str_to_color(s: String) -> Color:
	var parts := s.split(",")
	if parts.size() >= 3:
		return Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return Color(0.5, 0.5, 0.5)

func _color_to_string(c: Color) -> String:
	return "%.4f,%.4f,%.4f" % [c.r, c.g, c.b]
