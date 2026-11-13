extends SceneTree
class Arena extends Node3D:
 var _lit_campfires: Array = []
 var net = null
 func _net_campfire_built(_id, _pos, _pid): pass
 func _net_campfire_lit(id, _name, pos, _pid): _lit_campfires.append({"id":id,"pos":pos})
class Manager extends "res://scripts/SurvivorBotManager.gd":
 func _is_world_night() -> bool: return true
 func _bot_try_craft_named(_b: Dictionary, _delta: float, _wanted: Array, _protect: bool) -> bool: return false
 func _find_nearby_campfire_spot(_b: Dictionary, origin: Vector3) -> Vector3: return origin + Vector3(1,0,0)
var errors := 0
func check(ok: bool, label: String):
 if not ok:
  errors += 1
  push_error(label)
func _initialize(): call_deferred("run")
func run():
 var world := Arena.new()
 root.add_child(world)
 current_scene = world
 var manager := Manager.new()
 world.add_child(manager)
 manager.world = world
 var proxy := Node3D.new()
 world.add_child(proxy)
 proxy.set_meta("saved_inventory", [])
 var b := {"proxy":proxy,"bot_id":901,"hunger":30.0,"thirst":30.0,"campfire_id":"","campfire_pos":Vector3.INF}
 check(manager._bot_prepare_night_supplies(b,.1), "cannot leave without light or materials")
 check(not manager._bot_supply_goal_lit(b,Vector3(3,0,0)), "dark goal rejected even nearby")
 proxy.set_meta("saved_inventory", [{"name":"Palo","quantity":2},{"name":"Piedra","quantity":2}])
 check(not manager._bot_prepare_night_supplies(b,.1), "build and light a fire using inventory")
 check(world._lit_campfires.size() == 1 and manager._bot_item_count(proxy,"Palo") == 0 and manager._bot_item_count(proxy,"Piedra") == 0, "fire consumes actual materials once")
 check(manager._bot_supply_goal_lit(b,Vector3(8,0,0)), "nearby food/water within firelight allowed")
 check(not manager._bot_supply_goal_lit(b,Vector3(25,0,0)), "distant supplies without torch rejected")
 manager._bot_prepare_night_supplies(b,.1)
 check(world._lit_campfires.size() == 1, "reuse existing fire")
 proxy.set_meta("saved_inventory", [{"name":"Carne ensartada","quantity":1}])
 check(manager._bot_try_cook_meat(b,.1), "hungry bot cooks carried meat at nearby fire")
 check(manager._bot_item_count(proxy,"Carne asada en palo") == 1, "cooking yields edible meat")
 world._lit_campfires.clear()
 check(not manager._bot_supply_goal_lit(b,Vector3(8,0,0)), "extinguished fire grants no light")
 proxy.set_meta("saved_inventory", [{"name":"Antorcha","quantity":1}])
 check(not manager._bot_prepare_night_supplies(b,.1) and b.torch_lit and b.held_item == "Antorcha", "torch equipped and lit before departure")
 check(manager._bot_supply_goal_lit(b,Vector3(100,0,0)), "torch allows distant supplies")
 # --- Emergencia letal: burbuja de 6 m anclada como ultimo recurso ---
 proxy.set_meta("saved_inventory", [])
 proxy.global_position = Vector3(50,0,50)
 var b2 := {"proxy":proxy,"bot_id":902,"hunger":13.0,"thirst":30.0,"campfire_id":"","campfire_pos":Vector3.INF}
 check(not manager._bot_prepare_night_supplies(b2,.1) and b2.has("_night_emergency_origin"),
   "emergency anchors the six-metre bubble instead of freezing")
 check(b2["_night_emergency_origin"] == Vector3(50,0,50), "anchor fixed where the emergency began")
 check(manager._bot_supply_goal_allowed(b2,Vector3(54,0,50)), "emergency allows supplies inside the bubble")
 check(not manager._bot_supply_goal_allowed(b2,Vector3(60,0,50)), "emergency cannot wander past the bubble")
 proxy.global_position = Vector3(55,0,50)
 manager._bot_prepare_night_supplies(b2,.1)
 check(b2["_night_emergency_origin"] == Vector3(50,0,50), "anchor does not drift with the bot")
 proxy.global_position = Vector3(56.4,0,50)
 check(manager._bot_supply_goal_allowed(b2,Vector3(55.9,0,50)), "nudged bot can re-enter via a nearby in-bubble goal")
 proxy.global_position = Vector3(70,0,50)
 check(not manager._bot_supply_goal_allowed(b2,Vector3(55.9,0,50)), "far-nudged bot cannot reach the bubble")
 # Antorcha: libera el ancla.
 proxy.global_position = Vector3(50,0,50)
 proxy.set_meta("saved_inventory", [{"name":"Antorcha","quantity":1}])
 check(not manager._bot_prepare_night_supplies(b2,.1) and not b2.has("_night_emergency_origin"),
   "torch clears the emergency anchor")
 # Bot iluminado tambien ancla su burbuja de emergencia (sin asimetria lit/unlit).
 proxy.set_meta("saved_inventory", [])
 proxy.global_position = Vector3(0,0,0)
 world._lit_campfires = [{"id":"f1","pos":Vector3(10,0,0)}]
 var b3 := {"proxy":proxy,"bot_id":903,"hunger":12.0,"thirst":30.0,"campfire_id":"","campfire_pos":Vector3.INF}
 manager._bot_prepare_night_supplies(b3,.1)
 check(b3.has("_night_emergency_origin"), "lit-position emergency also anchors a bubble")
 check(manager._bot_supply_goal_allowed(b3,Vector3(-5,0,0)), "lit bot may grab the 5m-out supply when starving")
 # La vuelta a casa: refugio propio o fogata encendida sin necesidad de luz propia.
 world._lit_campfires = []
 proxy.global_position = Vector3(0,0,0)
 var b4 := {"proxy":proxy,"bot_id":904,"hunger":30.0,"thirst":30.0,"campfire_id":"","campfire_pos":Vector3.INF,
   "shelter_id":"","shelter_pos":Vector3.INF,"sitting":false,"anim":"idle","path_timer":0.0,"rot":0.0,"path":[],"_path_goal":Vector3.INF,
   "path_idx":0,"stuck_count":0,"stuck_timer":0.0}
 check(not manager._bot_night_home_walk(b4,.1), "no refuge means no home walk")
 world._lit_campfires = [{"id":"f2","pos":Vector3(25,0,0)}]
 check(manager._bot_night_home_walk(b4,.1) and str(b4.get("_act","")) == "rest", "lit campfire pulls the home walk")
 proxy.set_meta("saved_inventory", [])
 world.free()
 print("BotNightSuppliesRegression errors=",errors)
 quit(1 if errors else 0)
