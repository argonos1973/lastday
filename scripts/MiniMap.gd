extends Control
class_name MiniMap

const MAP_SIZE := 160
const WORLD_RANGE := 72.0

var player
var _update_timer := 0.0

func setup(new_player) -> void:
	player = new_player
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = 0.15
		queue_redraw()

func _world_to_map(pos: Vector3) -> Vector2:
	var fx := (pos.x + WORLD_RANGE) / (WORLD_RANGE * 2.0)
	var fy := (pos.z + WORLD_RANGE) / (WORLD_RANGE * 2.0)
	return Vector2(fx * MAP_SIZE, fy * MAP_SIZE)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), Color(0.04, 0.05, 0.04), true)
	draw_rect(Rect2(Vector2(2, 2), Vector2(MAP_SIZE - 4, MAP_SIZE - 4)), Color(0.08, 0.10, 0.07), true)
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("get_river_segments_for_minimap"):
		var segments = scene.get_river_segments_for_minimap()
		for seg in segments:
			var center: Vector3 = seg["center"]
			var size: Vector2 = seg["size"]
			var yaw: float = float(seg["yaw"])
			var angle := deg_to_rad(yaw)
			var along := Vector2(cos(angle), -sin(angle)) * size.x * 0.5
			var across := Vector2(sin(angle), cos(angle)) * size.y * 0.5
			var c := _world_to_map(center)
			var p1 := c + along + across
			var p2 := c + along - across
			var p3 := c - along - across
			var p4 := c - along + across
			draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(0.12, 0.22, 0.38))
	if scene.has_method("get_structures_for_minimap"):
		var structures = scene.get_structures_for_minimap()
		for s in structures:
			var pos: Vector3 = s["pos"]
			var col: Color = s["color"]
			var mp := _world_to_map(pos)
			draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), col, true)
	for child in scene.get_children():
		if child is Node3D and child.is_in_group("wildlife"):
			var mp := _world_to_map(child.global_position)
			draw_circle(mp, 2.0, Color(0.6, 0.4, 0.2))
	if player != null and is_instance_valid(player):
		var pp := _world_to_map(player.global_position)
		draw_circle(pp, 3.0, Color(1.0, 0.85, 0.2))
		var yaw_rad := deg_to_rad(player.rotation_degrees.y)
		var dir := Vector2(sin(yaw_rad), cos(yaw_rad)) * 6.0
		draw_line(pp, pp + dir, Color(1.0, 0.85, 0.2), 1.5)
