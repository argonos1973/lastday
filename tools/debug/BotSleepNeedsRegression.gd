extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
 func _is_world_night() -> bool: return true
 func _find_forage_target(_b: Dictionary, _radius: float) -> Dictionary:
  return {"id":"food", "pos":Vector3.ZERO,"t":0.0,"t_need":2.0}
var errors := 0
func check(ok: bool, label: String):
 if not ok:
  errors += 1
  push_error(label)
func _initialize(): call_deferred("run")
func run():
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var manager := Manager.new()
 stage.add_child(manager)
 var proxy := Node3D.new()
 stage.add_child(proxy)
 proxy.set_meta("saved_inventory", [{"name":"Antorcha", "quantity":1}])
 var stats := SurvivalStats.new()
 stats.sleep = 35.0
 stats.energy = 60.0
 stats.health = 100.0
 stats.body_temperature = 36.8
 var b := {"proxy":proxy,"bot_id":901,"vstats":stats,"hunger":39.0,"thirst":80.0,"health":100.0,"sleeping":true,"_mem":{}}
 check(manager._bot_should_wake(b,true), "hungry bot wakes with reserves for travel")
 b.sleeping = false
 check(not manager._bot_try_start_sleep(b,true), "hungry bot cannot immediately sleep again")
 check(manager._bot_vital_break(b), "food search takes priority over following leader")
 check(manager._bot_try_forage(b,.1) and b._forage.id == "food", "nighttime hunger starts real forage action")
 b.hunger = 80.0
 b.thirst = 34.0
 check(manager._bot_should_wake(b,true), "thirst wakes bot before critical dehydration")
 check(not manager._bot_try_start_sleep(b,true), "thirst blocks bedtime")
 b.thirst = 80.0
 check(not manager._bot_should_wake(b,true), "fed bot may sleep at night")
 b.hunger = 39.0
 stats.sleep = 3.0
 check(manager._bot_try_start_sleep(b,true), "exhaustion still permits short emergency nap")
 check(not manager._bot_should_wake(b,true), "emergency nap does not oscillate every tick")
 stats.sleep = 9.0
 check(manager._bot_should_wake(b,true), "recovered bot resumes food search promptly")
 stats.sleep = 3.0
 b.sleeping = false
 b.hunger = 8.0
 check(not manager._bot_try_start_sleep(b,true), "starvation cannot enter endless collapse loop")
 stats.free()
 stage.free()
 print("BotSleepNeedsRegression errors=", errors)
 quit(1 if errors else 0)
