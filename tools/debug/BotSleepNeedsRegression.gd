extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
 func _is_world_night() -> bool: return true
 func _find_forage_target(_b: Dictionary, _radius: float) -> Dictionary:
  return {"id":"food", "pos":Vector3.ZERO,"t":0.0,"t_need":2.0}
class FakeDayCycle extends Node:
 var time_of_day := 20.0
class FakeWorld extends Node:
 var day_cycle: Node = null
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
 b.hunger = 15.0
 check(manager._bot_try_start_sleep(b,true), "lethal sleep naps without supplies — buys time before the edge")
 check(not manager._bot_should_wake(b,true), "lethal nap holds while above the expedition edge")
 b.hunger = 8.0
 check(manager._bot_should_wake(b,true), "expedition edge (hunger<14) wakes for the directed try")
 b.hunger = 3.0
 check(manager._bot_should_wake(b,true), "edge of starvation wakes for the last forage try")
 b.sleeping = false
 check(not manager._bot_try_start_sleep(b,true), "starvation edge cannot enter the collapse loop")
 # Bot reclutado por un jugador humano (peer 77; los bots son 901-909):
 # seguirle no puede matarle de agotamiento — agotado de verdad duerme y
 # se reincorpora despues; con energia sigue la marcha sin dormir.
 b.hunger = 80.0
 b.thirst = 80.0
 stats.sleep = 80.0
 b["team_leader_id"] = 77
 check(not manager._bot_try_start_sleep(b,true), "recruited rested bot keeps following, no nap")
 stats.sleep = 12.0
 check(manager._bot_try_start_sleep(b,true) and bool(b.get("sleeping",false)),
   "recruited exhausted bot takes the nap despite the human leader")
 check(bool(b.get("_rest_rejoin",false)), "rejoin notice armed for after the nap")
 b.sleeping = false
 stats.sleep = 3.0
 check(manager._bot_try_start_sleep(b,true), "recruited bot at lethal sleep collapses too")
 b.sleeping = false
 b["aggro_target"] = proxy
 check(not manager._bot_try_start_sleep(b,true), "recruited bot never sleeps mid-fight")
 b["aggro_target"] = null
 b["team_leader_id"] = 0
 # La velada: anochecido pero antes de su hora de acostarse, un bot
 # descansado y con luz sigue en pie haciendo vida de campamento; pasada
 # su hora duerme — y sin luz ni techo duerme al anochecer como antes.
 var fdc := FakeDayCycle.new()
 var fworld := FakeWorld.new()
 fworld.day_cycle = fdc
 stage.add_child(fworld)
 stage.add_child(fdc)
 manager.world = fworld
 var prev_night := GameConst.NIGHT_START
 GameConst.NIGHT_START = 19.9
 b.sleeping = false
 b.hunger = 80.0
 b.thirst = 80.0
 stats.sleep = 80.0
 stats.energy = 80.0
 stats.body_temperature = 36.8
 fdc.time_of_day = 20.1 # 12 min tras el inicio de la noche
 check(not manager._bot_try_start_sleep(b,true), "bot descansado con luz aguanta la velada tras el anochecer")
 fdc.time_of_day = 22.5 # ya paso su hora de acostarse (+1.9 h max)
 check(manager._bot_try_start_sleep(b,true) and bool(b.get("sleeping",false)), "pasada su hora de acostarse el bot duerme")
 b.sleeping = false
 proxy.set_meta("saved_inventory", []) # sin antorcha, fuego ni techo
 fdc.time_of_day = 20.1
 check(manager._bot_try_start_sleep(b,true), "sin luz ni techo el bot duerme al anochecer como antes")
 b.sleeping = false
 proxy.set_meta("saved_inventory", [{"name":"Antorcha", "quantity":1}])
 stats.sleep = 20.0 # cansado de verdad: la velada no le retiene
 fdc.time_of_day = 20.1
 check(manager._bot_try_start_sleep(b,true), "bot cansado duerme aunque tenga luz — la velada es para descansados")
 stats.sleep = 80.0
 stats.energy = 80.0
 GameConst.NIGHT_START = prev_night
 manager.world = null
 stats.free()
 stage.free()
 print("BotSleepNeedsRegression errors=", errors)
 quit(1 if errors else 0)
