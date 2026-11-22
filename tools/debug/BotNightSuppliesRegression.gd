extends SceneTree
class Arena extends Node3D:
 var _lit_campfires: Array = []
 var world_actions_by_id: Dictionary = {}
 var net = null
 # Franja de rio simulada: x en [100,110] es agua sombreada para las pruebas
 # de fogata en el agua (igual que get_river_depth_at del mundo real).
 func get_river_depth_at(pos): return 1.0 if pos.x >= 100.0 and pos.x <= 110.0 else 0.0
 func _net_campfire_built(id, pos, _pid): world_actions_by_id[id] = {"position": pos}
 func _net_campfire_lit(id, name, pos, _pid):
  if not world_actions_by_id.has(id): return false
  for lc in _lit_campfires:
   if str(lc.get("id","")) == id:
    lc["fire_name"] = name; lc["pos"] = pos; return true
  _lit_campfires.append({"id":id,"fire_name":name,"pos":pos})
  return true
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
 var equipped := b.duplicate()
 equipped.clothing = "Casco militar,Linterna frontal"
 equipped.held_item = "Cuchillo"
 check(not manager._bot_prepare_night_supplies(equipped,.1) and equipped.flashlight_on and equipped.held_item == "Cuchillo", "worn headlamp lights night travel without using hands")
 check(not manager._bot_supply_goal_allowed(b,Vector3(30,0,0)), "non-lethal hunger keeps the dark travel ban")
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
 proxy.set_meta("saved_inventory", [{"name":"Antorcha","quantity":1},{"name":"Cerillas","quantity":1}])
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
 # Urgencia letal: la meta dirigida a 10 m (rio conocido, seta del escaneo)
 # ya no esta vetada por la oscuridad — quedarse quieto es morir seguro.
 check(manager._bot_supply_goal_allowed(b2,Vector3(60,0,50)), "lethal emergency reaches the directed supply 10m out")
 check(manager._bot_supply_goal_allowed(b2,Vector3(180,0,50)), "lethal emergency reaches a far known source")
 check(not manager._bot_supply_goal_allowed(b2,Vector3(240,0,50)), "but not a 190m odyssey beyond reach")
 proxy.global_position = Vector3(55,0,50)
 manager._bot_prepare_night_supplies(b2,.1)
 check(b2["_night_emergency_origin"] == Vector3(50,0,50), "anchor does not drift with the bot")
 proxy.global_position = Vector3(56.4,0,50)
 check(manager._bot_supply_goal_allowed(b2,Vector3(55.9,0,50)), "nudged bot can re-enter via a nearby in-bubble goal")
 proxy.global_position = Vector3(70,0,50)
 check(manager._bot_supply_goal_allowed(b2,Vector3(55.9,0,50)), "far-nudged lethal bot still reaches the directed goal")
 check(not manager._bot_supply_goal_allowed(b2,Vector3(240,0,50)), "far-nudged lethal bot still cannot reach beyond radius")
 # La expedicion se abandona cuando el riesgo supera sus posibilidades:
 # escondido de una amenaza no cruza el campo a la vista (la burbuja si).
 proxy.global_position = Vector3(50,0,50)
 b2["hide_timer"] = 5.0
 check(not manager._bot_supply_goal_allowed(b2,Vector3(180,0,50)), "hiding aborts the far lethal expedition")
 check(manager._bot_supply_goal_allowed(b2,Vector3(54,0,50)), "but the 6m bubble still works while hiding")
 b2["hide_timer"] = 0.0
 # Sueño letal: solo un trago a tiro — caminar 150 m muriendo de
 # agotamiento no llega; el colapso frena el desgaste y despierta al borde.
 var st_nap := SurvivalStats.new()
 st_nap.sleep = 6.0
 b2["vstats"] = st_nap
 check(manager._bot_supply_goal_allowed(b2,Vector3(70,0,50)), "lethal-sleep bot still reaches a 20m drink")
 check(not manager._bot_supply_goal_allowed(b2,Vector3(180,0,50)), "lethal-sleep bot abandons the 130m odyssey")
 st_nap.sleep = 30.0
 check(manager._bot_supply_goal_allowed(b2,Vector3(180,0,50)), "rested lethal bot reaches the far source again")
 b2.erase("vstats")
 st_nap.free()
 # Antorcha: libera el ancla.
 proxy.global_position = Vector3(50,0,50)
 proxy.set_meta("saved_inventory", [{"name":"Antorcha","quantity":1},{"name":"Cerillas","quantity":1}])
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
 world.world_actions_by_id["f2"] = {"position":Vector3(25,0,0)}
 check(manager._bot_night_home_walk(b4,.1) and str(b4.get("_act","")) == "rest", "lit campfire pulls the home walk")
 proxy.set_meta("saved_inventory", [])
 # Old camp references must not prevent a new local fire or overwrite it.
 for invalid_pos in [Vector3.INF, Vector3(200,0,200)]:
  proxy.global_position = Vector3(100,0,100)
  world._lit_campfires = [{"id":"old_camp","pos":Vector3(200,0,200)}]
  proxy.set_meta("saved_inventory", [{"name":"Palo","quantity":2},{"name":"Piedra","quantity":2}])
  var replacement := {"proxy":proxy,"bot_id":905,"hunger":30.0,"thirst":30.0,"campfire_id":"old_camp","campfire_pos":invalid_pos}
  check(not manager._bot_prepare_night_supplies(replacement,.1), "invalid or distant camp permits a new local fire")
  check(replacement.campfire_id != "old_camp" and world._lit_campfires.size() == 2 and world._lit_campfires[0].pos == Vector3(200,0,200), "new camp has distinct identity and preserves old fire")
 # Fogata fantasma: el fuego expira (5 min) y su objeto desaparece, pero la
 # entrada de _lit_campfires sobrevive — el bot debe invalidarla, limpiar
 # su referencia y, con materiales, levantar otra de verdad.
 proxy.global_position = Vector3(0,0,0)
 world._lit_campfires = []
 world.world_actions_by_id = {}
 proxy.set_meta("saved_inventory", [{"name":"Palo","quantity":4},{"name":"Piedra","quantity":4}])
 var b5 := {"proxy":proxy,"bot_id":906,"hunger":30.0,"thirst":30.0,"campfire_id":"","campfire_pos":Vector3.INF}
 check(not manager._bot_prepare_night_supplies(b5,.1), "builds and lights a real campfire")
 check(world._lit_campfires.size() == 1, "campfire registered as lit")
 var dead_id: String = b5["campfire_id"]
 world.world_actions_by_id.erase(dead_id)  # el fuego expira: el objeto ya no existe
 check(not manager._bot_supply_goal_lit(b5, Vector3(3,0,0)), "ghost campfire gives no light")
 check(not manager._bot_prepare_night_supplies(b5,.1), "ghost reference cleared and a new fire is built")
 check(b5["campfire_id"] != "" and world.world_actions_by_id.has(b5["campfire_id"]) and world._lit_campfires.size() == 1,
  "new real campfire lit; the ghost is gone")
 # Sin materiales: la referencia muerta se limpia igual y no levanta otra.
 world._lit_campfires = []
 proxy.set_meta("saved_inventory", [])
 var b6 := {"proxy":proxy,"bot_id":907,"hunger":30.0,"thirst":30.0,"campfire_id":"cf_dead","campfire_pos":Vector3(2,0,0),
  "shelter_id":"","shelter_pos":Vector3.INF,"sitting":false,"anim":"idle","path_timer":0.0,"rot":0.0,"path":[],"_path_goal":Vector3.INF,
  "path_idx":0,"stuck_count":0,"stuck_timer":0.0}
 check(manager._bot_prepare_night_supplies(b6,.1), "no materials -> holds position (need_light)")
 check(b6["campfire_id"] == "" and b6["campfire_pos"] == Vector3.INF, "dead campfire reference is cleaned")
 # Hipotermia sin refugio ni luz: la ronda nocturna queda cancelada —
 # patrullar a la intemperie muriendo de frio es pura exposicion.
 proxy.set_meta("saved_inventory", [])
 var st_cold := SurvivalStats.new()
 st_cold.body_temperature = 34.9
 var b7 := {"proxy":proxy,"bot_id":908,"vstats":st_cold,"hunger":80.0,"thirst":80.0,
  "aggro_target":null,"hide_timer":0.0,"_night_wander":{"idle_t":25.0},"camp_spot":Vector3.INF}
 check(not manager._bot_night_sentry_wander(b7,.2), "freezing bot does not patrol in the dark")
 st_cold.body_temperature = 36.6
 check(manager._bot_is_freezing(b7) == false, "sanity: 36.6 is not freezing")
 st_cold.free()
 # --- Veto temporal de fogata inalcanzable: no atrae al buscador de
 # calor, pero caduca y no aplica si ya estas dentro del anillo ---
 world._lit_campfires = [{"id":"fv1","pos":Vector3(6,0,0)},{"id":"fv2","pos":Vector3(60,0,0)}]
 world.world_actions_by_id = {"fv1":{"position":Vector3(6,0,0)},"fv2":{"position":Vector3(60,0,0)}}
 proxy.global_position = Vector3(0,0,0)
 var b8 := {"proxy":proxy,"bot_id":909}
 check(manager._nearest_lit_campfire_pos(proxy.global_position, 80.0) == Vector3(6,0,0), "unvetoed call sees the near fire")
 manager._bot_veto_fire(b8, Vector3(6,0,0))
 check(manager._nearest_lit_campfire_pos(proxy.global_position, 80.0, b8) == Vector3(60,0,0), "vetoed fire skipped, alternative found")
 check(manager._bot_fire_vetoed(b8, Vector3(6,0,0)), "veto holds at distance")
 proxy.global_position = Vector3(5,0,0)
 check(not manager._bot_fire_vetoed(b8, Vector3(6,0,0)), "veto ignored when already inside the ring")
 proxy.global_position = Vector3(0,0,0)
 # --- Nunca una fogata dentro del agua: punto en el rio se reubica a suelo
 # seco si el anillo lo permite, y rodeado de agua no gasta material ---
 proxy.set_meta("saved_inventory", [{"name":"Palo","quantity":2},{"name":"Piedra","quantity":2}])
 var b9 := {"proxy":proxy,"bot_id":910,"campfire_id":"","campfire_pos":Vector3.INF}
 check(manager._bot_build_and_light_campfire(b9, Vector3(100.5,0,0)), "fire next to the river relocates to dry land")
 check(b9["campfire_pos"].x < 100.0, "relocated fire lands outside the water band")
 check(world.world_actions_by_id.has(b9["campfire_id"]), "relocated fire actually exists in the world")
 proxy.set_meta("saved_inventory", [{"name":"Palo","quantity":2},{"name":"Piedra","quantity":2}])
 var b10 := {"proxy":proxy,"bot_id":911,"campfire_id":"","campfire_pos":Vector3.INF}
 check(not manager._bot_build_and_light_campfire(b10, Vector3(105.0,0,0)), "fully surrounded by water -> build refused")
 check(b10["campfire_id"] == "", "refused build leaves no phantom campfire id")
 check(manager._bot_item_count(proxy,"Palo") == 2 and manager._bot_item_count(proxy,"Piedra") == 2,
   "refused build does not consume materials")
 world.free()
 print("BotNightSuppliesRegression errors=",errors)
 quit(1 if errors else 0)
