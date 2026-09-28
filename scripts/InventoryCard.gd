extends PanelContainer

var screen
var payload: Dictionary = {}
var destination := ""

func _get_drag_data(_position: Vector2):
	if payload.is_empty():
		return null
	var label := Label.new()
	label.text = str(payload.get("label", "Objeto"))
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	set_drag_preview(label)
	return payload

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and screen != null and screen.can_transfer(data, destination, payload)

func _drop_data(_position: Vector2, data) -> void:
	screen.transfer(data, destination, payload)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not payload.is_empty():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			screen.open_actions(payload, get_global_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			screen.activate(payload)
			accept_event()
