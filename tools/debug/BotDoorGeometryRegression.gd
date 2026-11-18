extends SceneTree

const CityBlock = preload("res://scripts/CityBlock.gd")
const CityExpansion = preload("res://scripts/CityExpansion.gd")

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
	manager.free()
	print("BotDoorGeometryRegression failures=", failures)
	quit(1 if failures else 0)
