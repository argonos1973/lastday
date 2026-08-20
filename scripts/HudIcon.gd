extends Control
class_name HudIcon

var shape: String = "heart"
var icon_color: Color = Color(0.92, 0.94, 0.88)

func set_shape(s: String) -> void:
	shape = s
	queue_redraw()

func set_icon_color(c: Color) -> void:
	icon_color = c
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	var c: Vector2 = s * 0.5
	match shape:
		"heart":
			_draw_heart(c, s)
		"apple":
			_draw_apple(c, s)
		"drop":
			_draw_drop(c, s)
		"thermometer":
			_draw_thermometer(c, s)
		"bolt":
			_draw_bolt(c, s)
		"bed":
			_draw_bed(c, s)
		"warning":
			_draw_warning(c, s)
		"cross":
			_draw_cross(c, s)
		"gun":
			_draw_gun(c, s)
		"axe":
			_draw_axe(c, s)
		"hammer":
			_draw_hammer(c, s)
		"pickaxe":
			_draw_pickaxe(c, s)
		"shovel":
			_draw_shovel(c, s)
		"spear":
			_draw_spear(c, s)
		"fishing":
			_draw_fishing(c, s)
		"match":
			_draw_flame(c, s, 0.55)
		"torch":
			_draw_torch(c, s)
		"shirt":
			_draw_shirt(c, s)
		"backpack":
			_draw_backpack(c, s)
		"log":
			_draw_log(c, s)
		"seed":
			_draw_seed(c, s)
		"battery":
			_draw_battery(c, s)
		"box":
			_draw_box(c, s)
		"tent":
			_draw_tent(c, s)
		"flame":
			_draw_flame(c, s, 1.0)
		"circle":
			_draw_circle_icon(c, s)
		"pear":
			_draw_pear(c, s)

func _draw_circle_icon(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.28
	draw_circle(c, r, icon_color)

func _draw_pear(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.24
	var body := Vector2(c.x, c.y + r * 0.2)
	draw_circle(body, r * 0.7, icon_color)
	draw_circle(body + Vector2(0, -r * 0.5), r * 0.5, icon_color)
	draw_rect(Rect2(c.x - r * 0.05, c.y - r * 0.9, r * 0.1, r * 0.3), icon_color, true)

func _draw_heart(c: Vector2, s: Vector2) -> void:
	var scale_f: float = min(s.x, s.y) * 0.032
	var pts := PackedVector2Array()
	for i in range(0, 33):
		var t: float = deg_to_rad(i * 360.0 / 32.0)
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * scale_f)
	draw_colored_polygon(pts, icon_color)

func _draw_apple(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.26
	var body_center := Vector2(c.x, c.y + r * 0.15)
	draw_circle(body_center + Vector2(-r * 0.42, 0), r * 0.62, icon_color)
	draw_circle(body_center + Vector2(r * 0.42, 0), r * 0.62, icon_color)
	draw_circle(body_center, r * 0.68, icon_color)
	# stem
	draw_rect(Rect2(c.x - r * 0.06, c.y - r * 1.05, r * 0.12, r * 0.5), icon_color, true)
	# leaf
	var leaf := PackedVector2Array([
		Vector2(c.x, c.y - r * 0.75),
		Vector2(c.x + r * 0.55, c.y - r * 0.95),
		Vector2(c.x + r * 0.15, c.y - r * 0.55)
	])
	draw_colored_polygon(leaf, icon_color)

func _draw_drop(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.24
	if r < 1.0:
		return
	var drop_center := Vector2(c.x, c.y + r * 0.25)
	draw_circle(drop_center, r, icon_color)
	var tip := Vector2(c.x, c.y - r * 1.2)
	var left := drop_center + Vector2(-r * 0.92, -r * 0.38)
	var right := drop_center + Vector2(r * 0.92, -r * 0.38)
	var tri := PackedVector2Array([tip, left, right])
	draw_colored_polygon(tri, icon_color)

func _draw_thermometer(c: Vector2, s: Vector2) -> void:
	var w: float = s.x * 0.16
	var h: float = s.y * 0.46
	var top := Vector2(c.x, c.y - h * 0.55)
	draw_rect(Rect2(top.x - w * 0.5, top.y, w, h), icon_color, true)
	draw_circle(Vector2(c.x, c.y + h * 0.42), w * 0.95, icon_color)
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	draw_circle(Vector2(c.x, c.y + h * 0.42), w * 0.45, bg)
	draw_rect(Rect2(top.x - w * 0.18, top.y + h * 0.1, w * 0.36, h * 0.55), bg, true)

func _draw_bolt(c: Vector2, s: Vector2) -> void:
	var sc: float = min(s.x, s.y) * 0.048
	var raw := PackedVector2Array([
		Vector2(3, -11), Vector2(-6, 2), Vector2(-1, 2),
		Vector2(-3, 11), Vector2(6, -2), Vector2(1, -2)
	])
	var poly := PackedVector2Array()
	for p in raw:
		poly.append(c + p * sc)
	draw_colored_polygon(poly, icon_color)

func _draw_bed(c: Vector2, s: Vector2) -> void:
	var w: float = s.x * 0.56
	var h: float = s.y * 0.30
	var base := Vector2(c.x - w * 0.5, c.y + h * 0.05)
	draw_rect(Rect2(base, Vector2(w, h * 0.55)), icon_color, true)
	draw_rect(Rect2(base + Vector2(0, -h * 0.55), Vector2(w * 0.32, h * 0.55)), icon_color, true)
	draw_rect(Rect2(base.x - w * 0.06, base.y + h * 0.5, w * 0.06, h * 0.5), icon_color, true)
	draw_rect(Rect2(base.x + w - w * 0.0, base.y + h * 0.5, w * 0.06, h * 0.5), icon_color, true)

func _draw_cross(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	draw_rect(Rect2(c.x - r * 0.18, c.y - r, r * 0.36, r * 2.0), icon_color, true)
	draw_rect(Rect2(c.x - r, c.y - r * 0.18, r * 2.0, r * 0.36), icon_color, true)

func _draw_gun(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_rect(Rect2(c.x - r * 1.05, c.y - r * 0.16, r * 1.9, r * 0.32), icon_color, true)
	draw_rect(Rect2(c.x - r * 1.05, c.y - r * 0.32, r * 0.4, r * 0.24), icon_color, true)
	var grip := PackedVector2Array([
		Vector2(c.x + r * 0.35, c.y + r * 0.16),
		Vector2(c.x + r * 0.68, c.y + r * 0.16),
		Vector2(c.x + r * 0.55, c.y + r * 0.95)
	])
	draw_colored_polygon(grip, icon_color)

func _draw_axe(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_rect(Rect2(c.x - r * 0.09, c.y - r * 0.9, r * 0.18, r * 1.9), icon_color, true)
	var head := PackedVector2Array([
		Vector2(c.x - r * 0.09, c.y - r * 0.9),
		Vector2(c.x - r * 0.95, c.y - r * 1.05),
		Vector2(c.x - r * 1.0, c.y - r * 0.55),
		Vector2(c.x - r * 0.09, c.y - r * 0.5)
	])
	draw_colored_polygon(head, icon_color)

func _draw_hammer(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	var handle_from: Vector2 = c + Vector2(r * 0.6, r * 0.95)
	var handle_to: Vector2 = c + Vector2(-r * 0.45, -r * 0.25)
	draw_line(handle_from, handle_to, icon_color, r * 0.22, true)
	var head_center: Vector2 = c + Vector2(-r * 0.55, -r * 0.45)
	draw_rect(Rect2(head_center.x - r * 0.45, head_center.y - r * 0.28, r * 0.9, r * 0.56), icon_color, true)

func _draw_pickaxe(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_rect(Rect2(c.x - r * 0.08, c.y - r * 0.3, r * 0.16, r * 1.6), icon_color, true)
	var left := PackedVector2Array([
		Vector2(c.x - r * 0.08, c.y - r * 0.35),
		Vector2(c.x - r * 1.0, c.y - r * 0.75),
		Vector2(c.x - r * 0.08, c.y - r * 0.15)
	])
	var right := PackedVector2Array([
		Vector2(c.x + r * 0.08, c.y - r * 0.35),
		Vector2(c.x + r * 1.0, c.y - r * 0.75),
		Vector2(c.x + r * 0.08, c.y - r * 0.15)
	])
	draw_colored_polygon(left, icon_color)
	draw_colored_polygon(right, icon_color)

func _draw_shovel(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_rect(Rect2(c.x - r * 0.08, c.y - r * 1.0, r * 0.16, r * 1.5), icon_color, true)
	var blade := PackedVector2Array([
		Vector2(c.x - r * 0.4, c.y + r * 0.4),
		Vector2(c.x + r * 0.4, c.y + r * 0.4),
		Vector2(c.x + r * 0.3, c.y + r * 1.0),
		Vector2(c.x - r * 0.3, c.y + r * 1.0)
	])
	draw_colored_polygon(blade, icon_color)

func _draw_spear(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_line(c + Vector2(0, r * 1.0), c + Vector2(0, -r * 0.6), icon_color, r * 0.14, true)
	var tip := PackedVector2Array([
		c + Vector2(0, -r * 1.2),
		c + Vector2(-r * 0.28, -r * 0.55),
		c + Vector2(r * 0.28, -r * 0.55)
	])
	draw_colored_polygon(tip, icon_color)

func _draw_fishing(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.34
	draw_line(c + Vector2(-r * 0.9, -r * 0.9), c + Vector2(r * 0.6, r * 0.5), icon_color, r * 0.1, true)
	draw_line(c + Vector2(r * 0.6, r * 0.5), c + Vector2(r * 0.6, r * 1.05), icon_color, r * 0.05, true)
	draw_arc(c + Vector2(r * 0.6, r * 1.1), r * 0.18, 0.0, PI * 1.5, 12, icon_color, r * 0.05, true)

func _draw_torch(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.3
	draw_rect(Rect2(c.x - r * 0.09, c.y - r * 0.1, r * 0.18, r * 1.3), icon_color, true)
	_draw_flame(c + Vector2(0, -r * 0.55), s, 0.55)

func _draw_flame(c: Vector2, s: Vector2, scale_mul: float) -> void:
	var r: float = min(s.x, s.y) * 0.30 * scale_mul
	var outer := PackedVector2Array([
		c + Vector2(0, -r * 1.3),
		c + Vector2(r * 0.55, -r * 0.3),
		c + Vector2(r * 0.35, r * 0.6),
		c + Vector2(0, r * 1.0),
		c + Vector2(-r * 0.35, r * 0.6),
		c + Vector2(-r * 0.55, -r * 0.3)
	])
	draw_colored_polygon(outer, Color(0.95, 0.55, 0.12))
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(c + (p - c) * 0.55)
	draw_colored_polygon(inner, Color(1.0, 0.85, 0.35))

func _draw_shirt(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.2, r * 1.0, r * 1.3), icon_color, true)
	var left_sleeve := PackedVector2Array([
		Vector2(c.x - r * 0.5, c.y - r * 0.2),
		Vector2(c.x - r * 1.0, c.y - r * 0.5),
		Vector2(c.x - r * 0.85, c.y + r * 0.15),
		Vector2(c.x - r * 0.5, c.y + r * 0.05)
	])
	var right_sleeve := PackedVector2Array([
		Vector2(c.x + r * 0.5, c.y - r * 0.2),
		Vector2(c.x + r * 1.0, c.y - r * 0.5),
		Vector2(c.x + r * 0.85, c.y + r * 0.15),
		Vector2(c.x + r * 0.5, c.y + r * 0.05)
	])
	draw_colored_polygon(left_sleeve, icon_color)
	draw_colored_polygon(right_sleeve, icon_color)

func _draw_backpack(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	draw_rect(Rect2(c.x - r * 0.45, c.y - r * 0.3, r * 0.9, r * 1.2), icon_color, true)
	draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.65, r * 0.7, r * 0.4), icon_color, true)
	draw_rect(Rect2(c.x - r * 0.25, c.y + r * 0.1, r * 0.5, r * 0.5), bg, true)

func _draw_log(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.28
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	draw_rect(Rect2(c.x - r * 1.0, c.y - r * 0.35, r * 2.0, r * 0.7), icon_color, true)
	draw_circle(c + Vector2(-r * 1.0, 0), r * 0.35, icon_color)
	draw_circle(c + Vector2(r * 1.0, 0), r * 0.35, icon_color)
	draw_circle(c + Vector2(-r * 1.0, 0), r * 0.18, bg)
	draw_circle(c + Vector2(r * 1.0, 0), r * 0.18, bg)

func _draw_seed(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	var seed_center: Vector2 = c + Vector2(0, r * 0.3)
	draw_circle(seed_center, r * 0.35, icon_color)
	draw_line(seed_center + Vector2(0, -r * 0.3), seed_center + Vector2(0, -r * 0.9), icon_color, r * 0.08, true)
	var leaf := PackedVector2Array([
		seed_center + Vector2(0, -r * 0.9),
		seed_center + Vector2(r * 0.4, -r * 1.1),
		seed_center + Vector2(r * 0.05, -r * 0.65)
	])
	draw_colored_polygon(leaf, icon_color)

func _draw_battery(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.7, r * 0.7, r * 1.4), icon_color, true)
	draw_rect(Rect2(c.x - r * 0.12, c.y - r * 0.9, r * 0.24, r * 0.2), icon_color, true)
	draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.25, r * 0.7, r * 0.08), bg, true)
	draw_rect(Rect2(c.x - r * 0.35, c.y + r * 0.05, r * 0.7, r * 0.08), bg, true)

func _draw_box(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.30
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.5, r * 1.0, r * 1.0), icon_color, true)
	draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), bg, r * 0.08)
	draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), bg, r * 0.08)

func _draw_tent(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.32
	var bg := Color(0.04, 0.045, 0.04, 0.9)
	var pts := PackedVector2Array([
		c + Vector2(0, -r * 0.9),
		c + Vector2(r * 0.9, r * 0.7),
		c + Vector2(-r * 0.9, r * 0.7)
	])
	draw_colored_polygon(pts, icon_color)
	var entrance := PackedVector2Array([
		c + Vector2(0, -r * 0.15),
		c + Vector2(r * 0.28, r * 0.7),
		c + Vector2(-r * 0.28, r * 0.7)
	])
	draw_colored_polygon(entrance, bg)

func _draw_warning(c: Vector2, s: Vector2) -> void:
	var r: float = min(s.x, s.y) * 0.32
	var pts := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r * 0.9, r * 0.62), c + Vector2(-r * 0.9, r * 0.62)
	])
	draw_colored_polygon(pts, icon_color)
	var mark := Color(0.06, 0.06, 0.05)
	draw_rect(Rect2(c.x - r * 0.09, c.y - r * 0.15, r * 0.18, r * 0.5), mark, true)
	draw_circle(Vector2(c.x, c.y + r * 0.5), r * 0.09, mark)
