extends SceneTree

const CityBlock = preload("res://scripts/CityBlock.gd")
const CityExpansion = preload("res://scripts/CityExpansion.gd")

class Village extends "res://scripts/Main.gd":
	func _ready() -> void: pass
	func _exit_tree() -> void: pass
	func _save_world_change_silent() -> void: pass

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var manager := SurvivorBotManager.new()
	root.add_child(manager)
	for i in range(CityBlock.BUILDINGS.size()):
		var building: Dictionary = CityBlock.BUILDINGS[i]
		var origin: Vector3 = CityExpansion.CENTER + building.position
		var yaw := float(building.yaw)
		var hinge: Vector3 = building.get("door_position", Vector3(-0.85,0.12,6.08))
		var size: Vector3 = building.get("door_size", Vector3(1.7,2.8,0.12))
		var center_x := hinge.x + size.x * 0.5
		# Use the actual entrance waypoint followed by bots, with rotated houses
		# and the high-rise's wider door included. Door.position is its hinge.
		var outside := origin + Vector3(0.15, 0.12, 8.3).rotated(Vector3.UP, yaw)
		var inside := origin + Vector3(0.15, 0.12, 4.6).rotated(Vector3.UP, yaw)
		check(not manager._wall_between(outside, inside), building.id + " entrance is a clear passage")
		for side in [-1.0, 1.0]:
			var wall_x: float = center_x + side * (size.x * 0.5 + 0.3)
			outside = origin + Vector3(wall_x,0.12,8.3).rotated(Vector3.UP,yaw)
			inside = origin + Vector3(wall_x,0.12,4.6).rotated(Vector3.UP,yaw)
			check(manager._wall_between(outside, inside), building.id + " adjacent facade stays blocked (side %s)" % side)
	var village := Village.new()
	root.add_child(village)
	village.nav = NavPathfinding.new()
	village._register_server_house_blockers()
	manager.world = village
	var door := Vector3(42.15, 0, 31)
	var inside := Vector3(42, 0, 26)
	var outside := door + Vector3(0, 0, 0.95)
	var actor := Node3D.new()
	village.add_child(actor)
	actor.position = inside
	var crossings := 0
	var state := {"bot_id": 904, "proxy": actor, "path": [], "path_timer": 0.0, "path_idx": 0,
		"rot": 0.0, "stuck_timer": 0.0, "stuck_count": 0}
	for i in 160:
		var was_inside := village._is_player_in_house(actor.position)
		manager._move_bot_towards(state, outside, 3.8, 0.1, "walk")
		if was_inside != village._is_player_in_house(actor.position):
			crossings += 1
	check(Vector2(actor.position.x-outside.x, actor.position.z-outside.z).length() < 0.4 and crossings == 1,
		"bot reaches the outdoor destination beside the door without re-entering (at %s; crossings=%d)" % [actor.position, crossings])
	village.free()
	manager.free()
	print("BotDoorGeometryRegression failures=", failures)
	quit(1 if failures else 0)
