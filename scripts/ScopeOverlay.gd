extends Control

# Telescopic scope overlay. Masks the screen corners with black leaving a
# clear circular view in the center, and draws a reticle (crosshair + dot).
# Also shows wind direction/strength and breath hold status.

var scope_color := Color(0.0, 0.0, 0.0, 1.0)
var reticle_color := Color(0.0, 0.0, 0.0, 0.85)
var center_dot_color := Color(0.85, 0.0, 0.0, 0.95)
var _wind_label: Label = null
var _breath_label: Label = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	# Wind indicator label
	_wind_label = Label.new()
	_wind_label.name = "WindIndicator"
	_wind_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wind_label.offset_left = -120.0
	_wind_label.offset_top = 20.0
	_wind_label.offset_right = -10.0
	_wind_label.offset_bottom = 60.0
	_wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wind_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 0.9))
	_wind_label.add_theme_font_size_override("font_size", 14)
	add_child(_wind_label)
	# Breath hold status label
	_breath_label = Label.new()
	_breath_label.name = "BreathStatus"
	_breath_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_breath_label.offset_left = -120.0
	_breath_label.offset_top = -40.0
	_breath_label.offset_right = -10.0
	_breath_label.offset_bottom = -10.0
	_breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_breath_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 0.9))
	_breath_label.add_theme_font_size_override("font_size", 13)
	add_child(_breath_label)

func _process(_delta: float) -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("get_wind_info"):
		return
	var wind: Dictionary = player.get_wind_info()
	var strength: float = wind.get("strength", 0.0)
	var dir: Vector3 = wind.get("direction", Vector3.ZERO)
	# Convert wind direction to compass bearing
	var bearing := rad_to_deg(atan2(dir.x, dir.z))
	if bearing < 0.0:
		bearing += 360.0
	var compass: String = "N"
	if bearing < 22.5 or bearing >= 337.5:
		compass = "N"
	elif bearing < 67.5:
		compass = "NE"
	elif bearing < 112.5:
		compass = "E"
	elif bearing < 157.5:
		compass = "SE"
	elif bearing < 202.5:
		compass = "S"
	elif bearing < 247.5:
		compass = "SW"
	elif bearing < 292.5:
		compass = "W"
	else:
		compass = "NW"
	var wind_text := "Viento: %.1f m/s %s" % [strength, compass]
	if _wind_label != null:
		_wind_label.text = wind_text
	# Breath hold status
	if player.has_method("_is_breath_held"):
		pass
	if player.get("_breath_hold_active") == true:
		var hold_t: float = player.get("_breath_hold_timer")
		var remaining := 5.0 - hold_t
		_breath_label.text = "Aguantando: %.1fs" % remaining
		_breath_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 0.9))
	elif player.get("_breath_hold_recover") > 0.0:
		_breath_label.text = "Recuperando..."
		_breath_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6, 0.9))
	else:
		_breath_label.text = "Shift: aguantar"

func _draw() -> void:
	var vp_size := get_viewport_rect().size
	var center := vp_size * 0.5
	var radius: float = min(vp_size.x, vp_size.y) * 0.4
	# Mask the area outside the circle by drawing a very thick ring that
	# reaches beyond the screen corners. The inside of the ring stays clear.
	var screen_diag: float = vp_size.length()
	var ring_width: float = screen_diag
	draw_arc(center, radius + ring_width * 0.5, 0.0, TAU, 128, scope_color, ring_width, true)
	# Thin dark rim just inside the clear circle to suggest the scope tube.
	draw_arc(center, radius, 0.0, TAU, 128, Color(0.0, 0.0, 0.0, 0.9), 4.0, true)
	# Crosshair lines (clipped to the circle radius).
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), reticle_color, 1.5, true)
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), reticle_color, 1.5, true)
	# Center aim dot.
	draw_circle(center, 3.0, center_dot_color)
	# Mildot marks on vertical crosshair for range estimation
	for i in range(1, 5):
		var dot_y: float = center.y + i * radius * 0.15
		if dot_y < center.y + radius:
			draw_circle(Vector2(center.x, dot_y), 2.0, reticle_color)
		dot_y = center.y - i * radius * 0.15
		if dot_y > center.y - radius:
			draw_circle(Vector2(center.x, dot_y), 2.0, reticle_color)
