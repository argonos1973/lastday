extends Node
class_name SaveSystem

const SAVE_PATH := "user://un_dia_mas_save.json"

# Save/load disabled: the game always starts from a fresh state.
static func save_game(_data: Dictionary) -> bool:
	return true

static func load_game() -> Dictionary:
	return {}

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
