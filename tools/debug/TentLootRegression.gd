extends SceneTree
const BotReg = preload("res://tools/debug/SurvivorBotsAndCombatRegression.gd")
class RouteWorld extends BotReg.TestWorld:
 func _get_exact_ground_y(x: float, z: float, _from_y: float = 500.0) -> float:
  return HighMountainZone.ground_height_at(Vector3(x, 0, z)) + .025 if x < -210 and z < -210 else .025
class World extends "res://scripts/Main.gd":
 var generated: Dictionary = {}
 func _ready(): set_process(false)
 func _exit_tree(): pass
 func _create_pickup_item(data: Dictionary) -> void:
  if not _depleted_action_ids.has(str(data.id)):
   generated[data.id] = data.duplicate(true)
 func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
func _initialize(): call_deferred("run")
func run():
 var world := World.new()
 root.add_child(world)
 world._military_tent_pos = Vector3(100, 0, 50)
 world._remote_tent_pos = Vector3(202.9, 0, 435)
 world._city_tent_pos = Vector3(171.7, 0, 675.2)
 world._city_tent2_pos = world._city_tent_pos + Vector3(-13.5, 0, -1).rotated(Vector3.UP, deg_to_rad(world.CITY_TENT_YAW))
 world._world_rng.seed = 12345
 world._create_house_loot()
 var before: Dictionary = world.generated.duplicate(true)
 world.generated.clear()
 world._world_rng.seed = 12345
 world._depleted_action_ids = ["tent_loot_hat", "remote_tent_loot_hat", "city_tent_loot_hat",
  "tent_loot_rifle", "remote_tent_loot_rifle", "city_tent_loot_rifle", "tent_loot_m4"]
 world._create_house_loot()
 var failures := 0
 for id in ["village_house_headlamp", "city_house_headlamp", "tent_loot_headlamp", "remote_tent_loot_headlamp", "city_tent2_loot_headlamp"]:
  var lamp = before.get(id, {})
  if lamp.get("name") != GameConst.HEADLAMP_ITEM_NAME:
   failures += 1
   push_error("Missing headlamp " + id)
  elif absf(float(lamp.get("scale", 0.0)) - GameConst.HEADLAMP_DROP_SCALE) > 0.001:
   failures += 1
   push_error("Wrong headlamp loot scale " + id)
 if absf(world._get_drop_scale(GameConst.HEADLAMP_ITEM_NAME, "clothing") - GameConst.HEADLAMP_DROP_SCALE) > 0.001:
  failures += 1
  push_error("Dropped headlamp uses the wrong scale")
 for id in before:
  if id in world._depleted_action_ids: continue
  if before[id] != world.generated.get(id):
   failures += 1
   push_error("Collected fixed pickups changed loot " + str(id))
 # Each military site must guarantee its own sniper rifle and M4 pickup, plus
 # the towers (clock tower roof and village water tower).
 for rifle_id in ["tent_loot_rifle", "remote_tent_loot_rifle", "city_tent_loot_rifle", "tent_loot_m4", "remote_tent_loot_m4", "city_tent2_loot_m4", "city_tent2_loot_m4mag_0", "city_tent2_loot_m4mag_1", "clock_tower_roof_m4", "water_tower_loot_m4", "clock_tower_roof_m4mag_0", "clock_tower_roof_m4mag_1"]:
  if not before.has(rifle_id):
   failures += 1
   push_error("Missing guaranteed rifle/ammo " + rifle_id)
 # Both city stores together must spawn the full military gear set — the loot
 # is split: tent 1 holds sniper/helmet/basics, tent 2 the M4 and heavy gear.
 var city_ids := ["city_tent_loot_helmet", "city_tent_loot_item_0", "city_tent_loot_item_1", "city_tent_loot_food_0", "city_tent2_loot_vest", "city_tent2_loot_milbackpack", "city_tent2_loot_hat", "city_tent2_loot_item_0", "city_tent2_loot_food_0", "tent_loot_camonet", "remote_tent_loot_camonet", "city_tent_loot_camonet", "city_tent2_loot_camonet"]
 for cid in city_ids:
  if not before.has(cid):
   failures += 1
   push_error("Missing city store loot " + cid)
 # Random military drops must use the same rotated footprint as each tent.
 # The remote rifle used world-axis coordinates and could land outside its
 # wall, causing a gear raid to veto both the rifle and the nearby M4.
 var tents := [
  ["tent_", world._military_tent_pos, 35.0],
  ["remote_tent_", world._remote_tent_pos, 120.0],
  ["city_tent_", world._city_tent_pos, world.CITY_TENT_YAW],
  ["city_tent2_", world._city_tent2_pos, world._city_tent2_yaw],
 ]
 world._depleted_action_ids.clear()
 for loot_seed in [12345, GameConst.WORLD_SEED + 424242]:
  world.generated.clear()
  world._world_rng.seed = loot_seed
  world._create_house_loot()
  for id in world.generated:
   for tent in tents:
    if not str(id).begins_with(tent[0]): continue
    var local: Vector3 = (world.generated[id].pos - tent[1]).rotated(Vector3.UP, -deg_to_rad(tent[2]))
    if absf(local.x) > 4.15 or absf(local.z) > 5.65:
     failures += 1
     push_error("Military pickup outside clear tent floor: %s seed=%s local=%s" % [id, loot_seed, local])
 failures += await check_routes(world)
 world.free()
 print("TENT_LOOT_ERRORS=", failures)
 quit(1 if failures else 0)

func check_routes(source: World) -> int:
 var errors := 0
 var world := RouteWorld.new()
 root.add_child(world)
 var net := BotReg.FakeNet.new()
 root.add_child(net)
 world.net = net
 world.day_cycle = BotReg.FakeDayCycle.new()
 world.add_child(world.day_cycle)
 for spec in [["_military_tent_pos", 35.0], ["_remote_tent_pos", 120.0],
   ["_city_tent_pos", source.CITY_TENT_YAW], ["_city_tent2_pos", source._city_tent2_yaw]]:
  world.set(spec[0], source.get(spec[0]))
  world._create_tent_shell_colliders(world.get(spec[0]), spec[1], spec[0] + "Walls", spec[0] + "Roof")
 await HighMountainZone.create(world, true)
 for i in 2:
  var shell := world.get_node_or_null("SummitMilitaryTent_%d_Col" % i)
  if shell == null or shell.get_child_count() != 5:
   errors += 1
   push_error("Summit tent %d must have the same five wall colliders as the client" % i)
 var manager := SurvivorBotManager.new()
 world.add_child(manager)
 world.survivor_bot_mgr = manager
 manager.setup(world)
 manager.set_process(false)
 manager.set_physics_process(false)
 for bot_id in manager.bots:
  manager.bots[bot_id].proxy.global_position = Vector3(-400, 0, bot_id - 900)
 var template: Dictionary = manager.bots[901].duplicate(true)
 var cases := [
  ["tent_loot_rifle", ["tent_loot_mag_0", "tent_loot_mag_1"], world._military_tent_pos, 35.0],
  ["tent_loot_m4", ["tent_loot_m4mag_0", "tent_loot_m4mag_1"], world._military_tent_pos, 35.0],
  ["remote_tent_loot_m4", ["remote_tent_loot_m4mag_0", "remote_tent_loot_m4mag_1"], world._remote_tent_pos, 120.0],
  ["city_tent_loot_rifle", [], world._city_tent_pos, source.CITY_TENT_YAW],
  ["city_tent2_loot_m4", ["city_tent2_loot_m4mag_0", "city_tent2_loot_m4mag_1"], world._city_tent2_pos, source._city_tent2_yaw],
  # Legacy ground drops still need a route even after correcting generation.
  ["remote_tent_loot_rifle", [], world._remote_tent_pos, 120.0, Vector3(205.69, .06, 438.97)],
 ]
 var summit := Vector3(HighMountainZone.SUMMIT_CENTER.x, HighMountainZone.SUMMIT_HEIGHT, HighMountainZone.SUMMIT_CENTER.y)
 var yaw := deg_to_rad(HighMountainZone.BASE_YAW_DEG)
 # Include the valley on both ends: stopping at ROAD_START missed the
 # return-to-foot oscillation when survival interrupted the expedition.
 var valley := Vector3(-205, .025, -205)
 cases.append(["summit_tentA_loot_rifle", ["summit_tentA_loot_mag"],
  summit + HighMountainZone.TENT_A_OFFSET.rotated(Vector3.UP, yaw), HighMountainZone.BASE_YAW_DEG + 90.0,
  source.generated["summit_tentA_loot_rifle"].pos, valley, valley])
 cases.append(["summit_tentB_loot_m4", ["summit_tentB_loot_m4mag_0", "summit_tentB_loot_m4mag_1"],
  summit + HighMountainZone.TENT_B_OFFSET.rotated(Vector3.UP, yaw), HighMountainZone.BASE_YAW_DEG - 90.0,
  source.generated["summit_tentB_loot_m4"].pos, valley, valley])
 cases.append(["summit_towerfoot_m4", ["summit_towerfoot_m4mag"],
  summit + HighMountainZone.COMMS_TOWER_OFFSET.rotated(Vector3.UP, yaw), HighMountainZone.BASE_YAW_DEG,
  source.generated["summit_towerfoot_m4"].pos, valley, valley])
 if "--only-summit" in OS.get_cmdline_user_args():
  cases = cases.filter(func(c): return str(c[0]).begins_with("summit_"))
 elif "--ground-only" in OS.get_cmdline_user_args():
  cases = cases.filter(func(c): return not str(c[0]).begins_with("summit_"))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--only-loot="):
   cases = cases.filter(func(c): return str(c[0]) == arg.trim_prefix("--only-loot="))
 if "--water-exit-only" in OS.get_cmdline_user_args() or "--slope-food-only" in OS.get_cmdline_user_args():
  cases = []
 await physics_frame
 await physics_frame
 for native_nav in [false, true]:
  world.bot_nav = world._new_nav_pathfinding() if native_nav else NavPathfinding.new()
  world.bot_nav.build([], [])
  world.nav = world.bot_nav
  for test_case in cases:
   var entry: Dictionary = source.generated[test_case[0]].duplicate(true)
   if test_case.size() > 4: entry["pos"] = test_case[4]
   var ids: Array = [test_case[0]] + test_case[1]
   world._dropped_items = [entry]
   for id in test_case[1]: world._dropped_items.append(source.generated[id].duplicate(true))
   world._depleted_action_ids.clear()
   world._pickup_claims.clear()
   world._pickup_claim_until.clear()
   var b: Dictionary = template.duplicate(true)
   var stats := SurvivalStats.new()
   stats.died.connect(manager._on_bot_stats_died.bind(b))
   b["vstats"] = stats
   manager.bots[901] = b
   b["_mem"] = {}
   manager._memory[901] = b["_mem"]
   b["equip_mission"] = true
   b["health"] = 100.0
   b["hunger"] = 100.0
   b["thirst"] = 100.0
   b["energy"] = 100.0
   b["sleep"] = 100.0
   b["vstats"].body_temperature = 37.0
   b["vstats"].wetness = 0.0
   b.proxy.set_meta("saved_inventory", [])
   b.proxy.set_meta("proxy_dead", false)
   b.proxy.set_meta("proxy_health", 100.0)
   b.proxy.set_meta("saved_extra", {})
   b.proxy.set_meta("bot_gun_ammo", {})
   b.proxy.global_position = test_case[2] + Vector3(4.7, .1, .9).rotated(Vector3.UP, deg_to_rad(test_case[3]))
   if test_case.size() > 4: b.proxy.global_position = Vector3(201.5, .1, 430.4)
   var mountain_trip: bool = test_case.size() > 6
   if mountain_trip:
    b.proxy.global_position = test_case[5]
    var poi_id: String = manager._poi_id({"kind":"military", "pos":test_case[2]})
    var pp: Vector3 = test_case[2]
    b["_mem"]["known_locations"] = {poi_id:{"kind":"military", "pos":[pp.x, pp.y, pp.z]}}
    b["ai_directive"] = {}
    if not manager._ai_apply_decision(901, JSON.stringify({"action":"scavenge", "target":"military", "goal":"gear_up_at_military_base", "priority":4})):
     errors += 1
     push_error("Summit gear trip was not adopted")
   b["pos"] = b.proxy.global_position
   var crossed_wall := false
   var jumped := false
   var collected := false
   for tick in (6500 if mountain_trip else 1200):
    if not is_instance_valid(b.proxy) or bool(b.proxy.get_meta("proxy_dead", false)):
     break
    var before: Vector3 = b.proxy.global_position
    manager._tick_bot(b, .05)
    var after: Vector3 = b.proxy.global_position
    if before.distance_to(after) > 1.0: jumped = true
    if before.distance_to(after) > .001:
     var query := PhysicsRayQueryParameters3D.create(before + Vector3.UP * .9, after + Vector3.UP * .9, 1)
     if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): crossed_wall = true
    collected = true
    for id in ids:
     if not world._depleted_action_ids.has(id): collected = false
    if collected: break
    if tick % 3 == 0: await physics_frame
   var exit_goal: Vector3 = test_case[2] + Vector3(-9, .1, -8).rotated(Vector3.UP, deg_to_rad(test_case[3]))
   if mountain_trip: exit_goal = test_case[6]
   var exited := false
   if collected:
    b["_act"] = "explore"
    for tick in (6500 if mountain_trip else 600):
     var before: Vector3 = b.proxy.global_position
     manager._move_bot_towards(b, exit_goal, 4.5, .05, "run")
     var after: Vector3 = b.proxy.global_position
     if before.distance_to(after) > 1.0: jumped = true
     if before.distance_to(after) > .001:
      var query := PhysicsRayQueryParameters3D.create(before + Vector3.UP * .9, after + Vector3.UP * .9, 1)
      if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): crossed_wall = true
     if after.distance_to(exit_goal) < 1.0:
      exited = true
      break
     if tick % 3 == 0: await physics_frame
   if not is_instance_valid(b.proxy):
    push_error("Military route lost its actor: %s" % entry.id)
    world.free()
    net.free()
    return errors + 1
   var armed: bool = b.get("held_item") == entry.name and manager._bot_gun_any_ammo(b.proxy, entry.name)
   var valid: bool = collected and exited and armed and not crossed_wall and not jumped and b.get("_unreachable", []).is_empty()
   print("TENT_ROUTE native=%s id=%s collected=%s exited=%s armed=%s crossed_wall=%s jumped=%s pos=%s" %
    [native_nav, entry.id, collected, exited, armed, crossed_wall, jumped, b.proxy.global_position])
   if not valid:
    errors += 1
    push_error("Military route failed: %s native=%s block=%s" % [entry.id, native_nav, b.get("_last_step_block")])
   b.proxy.global_position = Vector3(-400, 0, 1)
   stats.free()
  if "--water-exit-only" in OS.get_cmdline_user_args() or OS.get_cmdline_user_args().is_empty():
   errors += await check_mountain_supply(world, manager, template, native_nav, false)
  if "--slope-food-only" in OS.get_cmdline_user_args() or OS.get_cmdline_user_args().is_empty():
   errors += await check_mountain_supply(world, manager, template, native_nav, true)
 world.free()
 net.free()
 return errors

func check_mountain_supply(world, manager, template: Dictionary, native_nav: bool, food_case: bool) -> int:
 var b: Dictionary = template.duplicate(true)
 var stats := SurvivalStats.new()
 manager.add_child(stats)
 stats.died.connect(manager._on_bot_stats_died.bind(b))
 b["vstats"] = stats
 b["_mem"] = {}
 manager._memory[901] = b["_mem"]
 manager.bots[901] = b
 b["ai_directive"] = {}
 b["proxy"].global_position = Vector3(-247.6, .6, -268.9)
 if food_case:
  b["proxy"].global_position = Vector3(-265.7, manager._ground_y(-265.7,-270.9), -270.9)
 b["proxy"].set_meta("proxy_dead", false)
 b["proxy"].set_meta("proxy_health", 100.0)
 b["proxy"].set_meta("saved_inventory", [])
 b["proxy"].set_meta("saved_extra", {})
 b["pos"] = b["proxy"].global_position
 b["health"] = 100.0
 b["hunger"] = 22.0 if food_case else 90.0
 b["thirst"] = 90.0 if food_case else 22.0
 var supply_id := ("slope_food_" if food_case else "valley_water_") + str(native_nav)
 var supply
 if food_case:
  var food_pos := Vector3(-294, manager._ground_y(-294,-280), -280)
  supply = world._create_world_action(supply_id, "eat_food", "Manzana",
   food_pos, Vector3.ONE * .2, Color.TRANSPARENT, false, false)
  supply.set_meta("item_name", "Manzana")
  supply.set_meta("item_use_value", 12.0)
 else:
  b["drink_at"] = Vector3(-158, .025, -137)
  supply = world._create_world_action(supply_id, "drink_water", "Agua del valle",
   b["drink_at"] + Vector3.UP * .9, Vector3(4.6, 1.7, 4.6), Color.TRANSPARENT, true, false)
  supply.set_meta("drink_source", "de la fuente")
  supply.set_meta("water_reach", 2.8)
 world._dropped_items.clear()
 await physics_frame
 var supplied := false
 for tick in 2500:
  manager._tick_bot(b, .05)
  supplied = world._depleted_action_ids.has(supply_id) if food_case else float(b["thirst"]) >= 95.0
  if supplied or bool(b["proxy"].get_meta("proxy_dead", false)):
   break
  if tick % 3 == 0: await physics_frame
 var alive := not bool(b["proxy"].get_meta("proxy_dead", false))
 var valid: bool = alive and supplied and b.get("_unreachable", []).is_empty()
 print("MOUNTAIN_SUPPLY food=%s native=%s alive=%s hp=%.1f hunger=%.1f thirst=%.1f pos=%s valid=%s" %
  [food_case, native_nav, alive, b["health"], b["hunger"], b["thirst"], b["proxy"].global_position, valid])
 world.world_actions_by_id.erase(supply_id)
 if is_instance_valid(supply): supply.queue_free()
 stats.free()
 b["proxy"].global_position = Vector3(-400, 0, 1)
 return 0 if valid else 1
