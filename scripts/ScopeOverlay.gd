extends Control

# Telescopic scope overlay. Masks the screen corners with black leaving a
# clear circular view in the center, and draws a reticle (crosshair + dot).

var scope_color := Color(0.0, 0.0, 0.0, 1.0)
var reticle_color := Color(0.0, 0.0, 0.0, 0.85)
var center_dot_color := Color(0.85, 0.0, 0.0, 0.95)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)

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
