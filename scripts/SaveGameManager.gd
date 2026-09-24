extends Node

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "savegame.json"
const SAVE_PATH := SAVE_DIR + SAVE_FILE
const BACKUP_PATH := SAVE_DIR + "savegame.bak.json"
const TEMP_PATH := SAVE_DIR + "savegame.tmp.json"
const SERVER_SAVE_PATH := SAVE_DIR + "server_savegame.json"
const SERVER_BACKUP_PATH := SAVE_DIR + "server_savegame.bak.json"
const SERVER_TEMP_PATH := SAVE_DIR + "server_savegame.tmp.json"
const SAVE_VERSION := 2

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
	_saved_on_quit = false

func _do_save(main: Node) -> void:
	_saved_on_quit = true
	if "net" in main and main.net != null and main.net.is_connected:
		# Connected modes save through the server-save path, never the single-player file
		if main.has_method("_save_world_change_silent"):
			main._save_world_change_silent()
		return
	if "game_over" in main and main.game_over:
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
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player": player_data,
		"world": world_data,
	}
	if not _write_save_atomic(TEMP_PATH, SAVE_PATH, BACKUP_PATH, data):
		return false
	_current_save = data
	return true

# Server world persistence — separate file, never touches the single-player save
func save_server_game(world_data: Dictionary, players_data: Dictionary) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"world": world_data,
		"players": players_data,
	}
	return _write_save_atomic(SERVER_TEMP_PATH, SERVER_SAVE_PATH, SERVER_BACKUP_PATH, data)

func has_server_save() -> bool:
	return FileAccess.file_exists(SERVER_SAVE_PATH)

func load_server_game() -> Dictionary:
	return _read_save(SERVER_SAVE_PATH, SERVER_BACKUP_PATH)

func delete_server_save() -> void:
	if has_server_save():
		DirAccess.remove_absolute(SERVER_SAVE_PATH)
	if FileAccess.file_exists(SERVER_BACKUP_PATH):
		DirAccess.remove_absolute(SERVER_BACKUP_PATH)

func _write_save_atomic(temp_path: String, save_path: String, backup_path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var json_str := JSON.stringify(data, "  ")
	# Escritura atomica: escribir a temp, renombrar a destino. Si existe un
	# save previo, copiarlo a backup antes de sobrescribir.
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveGameManager: No se pudo abrir %s para escribir" % temp_path)
		return false
	f.store_string(json_str)
	f.close()
	f = null
	# Validar que el temporal se escribio correctamente
	var verify := FileAccess.open(temp_path, FileAccess.READ)
	if verify == null:
		push_error("SaveGameManager: No se pudo verificar el temporal")
		return false
	var verify_text := verify.get_as_text()
	verify.close()
	var verify_parsed = JSON.parse_string(verify_text)
	if not verify_parsed is Dictionary:
		push_error("SaveGameManager: Temporal corrupto, abortando")
		DirAccess.remove_absolute(temp_path)
		return false
	# Backup del save anterior si existe
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, backup_path)
	# Renombrar temporal -> destino (atomico en la mayoria de filesystems)
	var err := DirAccess.rename_absolute(temp_path, save_path)
	if err != OK:
		push_error("SaveGameManager: No se pudo renombrar el temporal: %d" % err)
		return false
	return true

func load_game() -> Dictionary:
	var parsed := _read_save(SAVE_PATH, BACKUP_PATH)
	if parsed.is_empty():
		return {}
	# Migracion de version
	parsed = _migrate_save(parsed)
	_current_save = parsed
	save_loaded.emit(parsed)
	return parsed

func _read_save(save_path: String, backup_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var text := ""
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		push_error("SaveGameManager: No se pudo abrir %s para leer" % save_path)
		return {}
	text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveGameManager: JSON invalido en %s, intentando backup" % save_path)
		if FileAccess.file_exists(backup_path):
			f = FileAccess.open(backup_path, FileAccess.READ)
			if f != null:
				text = f.get_as_text()
				f.close()
				parsed = JSON.parse_string(text)
				if parsed is Dictionary:
					# Restaurar backup como save principal
					DirAccess.copy_absolute(backup_path, save_path)
				else:
					push_error("SaveGameManager: Backup tambien corrupto")
					return {}
			else:
				return {}
		else:
			return {}
	return parsed

func _migrate_save(data: Dictionary) -> Dictionary:
	var ver: int = int(data.get("version", 1))
	# v1 -> v2: campfire_fire_timers pasan de timestamp absoluto a ms relativos
	if ver < 2:
		var cft = data.get("world", {}).get("campfire_fire_timers", {})
		if cft is Dictionary:
			var now := Time.get_ticks_msec()
			var migrated := {}
			for fire_name in cft.keys():
				var ts: int = int(cft[fire_name])
				var remaining: int = ts - int(now)
				if remaining > 0:
					migrated[fire_name] = remaining
			(data["world"] as Dictionary)["campfire_fire_timers"] = migrated
		data["version"] = SAVE_VERSION
	return data

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
