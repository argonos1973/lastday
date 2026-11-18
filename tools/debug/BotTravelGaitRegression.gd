extends SceneTree

class TravelManager extends SurvivorBotManager:
	func _move_bot_towards(b: Dictionary, _goal: Vector3, speed: float, _delta: float, anim: String) -> void:
		b["anim"] = anim
		b["requested_speed"] = speed

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var manager := TravelManager.new()
	root.add_child(manager)
	var stats := SurvivalStats.new()
	stats.body_temperature = 36.6
	var b := {"vstats": stats, "hunger": 90.0, "thirst": 90.0}
	var goal := Vector3(200,0,200)
	for pace in [[3.5,6.2], [3.6,5.5], [3.6,6.0]]:
		b.erase("_travel_gait_goal")
		b["hunger"] = 90.0
		b["thirst"] = 90.0
		stats.energy = 60.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "run", "healthy bot starts travel running")
		stats.energy = 50.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "run", "same trip does not oscillate at 55 energy")
		manager._move_bot_travel(b,goal,20.0,pace[0],pace[1],0.1)
		check(b.anim == "run", "active travel keeps gait until arrival band")
		stats.energy = 31.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "walk", "low energy ends running")
		stats.energy = 50.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "walk", "must recover enough before starting again")
		stats.energy = 70.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		b["hunger"] = 20.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "walk", "hunger interrupts an active run even while warm")
		b["hunger"] = 90.0
		b["thirst"] = 20.0
		manager._move_bot_travel(b,goal,100.0,pace[0],pace[1],0.1)
		check(b.anim == "walk", "thirst prevents running while warm")
	b["_expl_run"] = true
	b["thirst"] = 90.0
	b["_stamina_recover"] = true
	check(not manager._bot_explore_wants_run(b,100.0), "stamina recovery also interrupts an active run")
	b["_stamina_recover"] = false
	b["_expl_run"] = true
	stats.energy = 40.0
	manager._move_bot_travel(b,goal + Vector3(30,0,0),100.0,3.5,6.2,0.1)
	check(b.anim == "walk", "a new destination cannot inherit a tired run")
	stats.free()
	manager.free()
	print("BotTravelGaitRegression failures=", failures)
	quit(1 if failures else 0)
