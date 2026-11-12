extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
	var cover := true
	var blocked := false
	var moves := 0
	var destination := Vector3.INF
	func _ground_y(_x: float, _z: float, _from_y: float = -INF) -> float: return 0.0
	func _is_step_blocked(_a: Vector3, _b: Vector3, _deep: bool = false) -> bool: return blocked
	func _has_clear_shot(_a: Vector3, b: Vector3) -> bool: return not cover or b.x < 3.0
	func _move_bot_towards(_b: Dictionary, goal: Vector3, _speed: float, _delta: float, _anim: String) -> void:
		moves += 1
		destination = goal
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var manager := Manager.new()
	root.add_child(manager)
	var proxy := Node3D.new()
	var foe := Node3D.new()
	root.add_child(proxy)
	root.add_child(foe)
	foe.position = Vector3(-10,0,0)
	var b := {"proxy":proxy,"bot_id":901}
	var goal := manager._find_ballistic_cover(b,foe)
	check(goal != Vector3.INF and goal.x >= 3, "selects point that blocks incoming sight")
	manager._bot_seek_ballistic_cover(b,foe,.1)
	check(manager.moves == 1 and not b.crouching, "runs to cover without crouching in open")
	proxy.position = manager.destination
	manager._bot_seek_ballistic_cover(b,foe,.1)
	check(b.crouching and manager.moves == 1, "crouches only once actual position is protected")
	manager.cover = false
	manager._bot_seek_ballistic_cover(b,foe,2.0)
	check(manager.moves == 2 and not b.crouching, "flanked bot leaves exposed cover")
	proxy.position = Vector3.ZERO
	manager.cover = true
	manager.blocked = true
	check(manager._find_ballistic_cover(b,foe) == Vector3.INF, "rejects inaccessible cover")
	proxy.free()
	foe.free()
	manager.free()
	print("BOT_TACTICS errors=",errors)
	quit(errors)
