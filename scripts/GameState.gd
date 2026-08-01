extends Node

const DEFAULT_CHARACTERS := [
	{"name": "Remy", "model": "res://assets/characters/adapted/player_with_clothes.glb", "type": "default"},
	{"name": "Personaje 2", "model": "res://assets/characters/personaje2.glb", "type": "default"},
]

var characters: Array = []
var selected_character_index := 0

func _ready() -> void:
	_load_characters()
	_select_first_default_character()

func _select_first_default_character() -> void:
	for i in range(characters.size()):
		if characters[i].get("type", "custom") == "default":
			select_character(i)
			return
	select_character(0)

func _load_characters() -> void:
	characters = []
	var json_path := "res://assets/characters/characters.json"
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Array and parsed.size() > 0:
				characters = parsed
	if characters.is_empty():
		characters = DEFAULT_CHARACTERS

func get_available_characters() -> Array:
	return characters

func get_selected_character() -> Dictionary:
	if characters.is_empty():
		return {}
	return characters[clampi(selected_character_index, 0, characters.size() - 1)]

func get_selected_model_path() -> String:
	var sel := get_selected_character()
	if sel.has("model"):
		return String(sel.model)
	return ""

func get_selected_name() -> String:
	var sel := get_selected_character()
	if sel.has("name"):
		return String(sel.name)
	return ""

func select_character(index: int) -> void:
	if characters.is_empty():
		selected_character_index = 0
		return
	selected_character_index = clampi(index, 0, characters.size() - 1)
