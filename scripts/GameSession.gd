extends Node

var selected_character_id: String = ""
var selected_character_scene: PackedScene
var selected_clothing_color: Color = Color(0.5, 0.5, 0.5)
var selected_top_color: Color = Color(0.5, 0.5, 0.5)
var selected_bottom_color: Color = Color(0.3, 0.3, 0.3)
var selected_shoes_color: Color = Color(0.15, 0.15, 0.15)
var selected_hair_color: Color = Color(0.2, 0.15, 0.1)
var selected_skin_color: Color = Color(0.8, 0.7, 0.6)

func select_character(definition: CharacterDefinition) -> void:
	if definition == null:
		selected_character_id = ""
		selected_character_scene = null
		return
	selected_character_id = definition.character_id
	selected_character_scene = definition.character_scene
	selected_clothing_color = definition.top_color
	selected_top_color = definition.top_color
	selected_bottom_color = definition.bottom_color
	selected_shoes_color = definition.shoes_color
	selected_hair_color = definition.hair_color
	selected_skin_color = definition.skin_color

func has_selection() -> bool:
	return not selected_character_id.is_empty()
