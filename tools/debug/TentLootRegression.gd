extends SceneTree
class World extends "res://scripts/Main.gd":
 var generated: Dictionary = {}
 func _ready(): set_process(false)
 func _exit_tree(): pass
 func _create_pickup_item(data: Dictionary) -> void:
  if not _depleted_action_ids.has(str(data.id)):
   generated[data.id] = {"name": data.name, "pos": data.pos}
 func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
func _initialize(): call_deferred("run")
func run():
 var world := World.new()
 root.add_child(world)
 world._world_rng.seed = 12345
 world._create_house_loot()
 var before: Dictionary = world.generated.duplicate(true)
 world.generated.clear()
 world._world_rng.seed = 12345
 world._depleted_action_ids = ["tent_loot_hat", "remote_tent_loot_hat", "city_tent_loot_hat"]
 world._create_house_loot()
 var failures := 0
 for id in before:
  if id in world._depleted_action_ids: continue
  if before[id] != world.generated.get(id):
   failures += 1
   push_error("Collected hats changed loot " + str(id))
 # Each military site must guarantee its own sniper rifle and M4 pickup, plus
 # the towers (clock tower roof and village water tower).
 for rifle_id in ["tent_loot_rifle", "remote_tent_loot_rifle", "city_tent_loot_rifle", "tent_loot_m4", "remote_tent_loot_m4", "city_tent_loot_m4", "clock_tower_roof_m4", "water_tower_loot_m4", "clock_tower_roof_m4mag_0", "clock_tower_roof_m4mag_1"]:
  if not before.has(rifle_id):
   failures += 1
   push_error("Missing guaranteed rifle/ammo " + rifle_id)
 # The city store must spawn military gear from the shared pool
 var city_ids := ["city_tent_loot_helmet", "city_tent_loot_vest", "city_tent_loot_milbackpack", "city_tent_loot_item_0", "city_tent_loot_item_1", "city_tent_loot_item_2", "city_tent_loot_food_0", "city_tent_loot_food_1"]
 for cid in city_ids:
  if not before.has(cid):
   failures += 1
   push_error("Missing city store loot " + cid)
 world.free()
 print("TENT_LOOT_ERRORS=", failures)
 quit(1 if failures else 0)
