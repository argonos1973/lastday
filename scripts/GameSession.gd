extends Node

var selected_character_id: String = ""
var selected_character_scene: PackedScene

func select_character(definition: CharacterDefinition) -> void:
	if definition == null:
		selected_character_id = ""
		selected_character_scene = null
		return
	selected_character_id = definition.character_id
	selected_character_scene = definition.character_scene

func has_selection() -> bool:
	return not selected_character_id.is_empty()
