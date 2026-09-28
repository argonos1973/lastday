extends PanelContainer

var screen
var payload: Dictionary = {}
var destination := ""
var drop_feedback := 0

func _process(_delta: float) -> void:
	var feedback := 0
	if screen != null and get_viewport().gui_is_dragging() and get_global_rect().has_point(get_global_mouse_position()):
		feedback = 1 if _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data()) else -1
	if feedback != drop_feedback:
		drop_feedback = feedback
		queue_redraw()

func _draw() -> void:
	if drop_feedback != 0:
		var color := Color(0.6, 0.8, 0.4) if drop_feedback > 0 else Color(0.9, 0.3, 0.25)
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), color, false, 2.0)


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and has_meta("compartment_header"):
		screen.toggle_compartment(str(get_meta("compartment_header")))
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and not payload.is_empty():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			screen.open_actions(payload, get_global_mouse_position())
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			screen.activate(payload)
			accept_event()
