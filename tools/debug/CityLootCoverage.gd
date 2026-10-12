extends SceneTree
const CITY := preload("res://scripts/CityExpansion.gd")
class World extends "res://scripts/Main.gd":
 var generated: Dictionary = {}
 func _ready(): set_process(false)
 func _exit_tree(): pass
 func _create_pickup_item(data: Dictionary) -> void:
  generated[str(data.id)] = {"name": data.name, "pos": data.pos, "floor_y": float(data.get("floor_y", 0.0))}
func _initialize(): call_deferred("run")
func _building_at(pos: Vector3) -> String:
 for d in CITY.BLOCK.BUILDINGS:
  var o: Vector3 = pos - CITY.CENTER - d["position"]
  if absf(o.x) < 6.2 and absf(o.z) < 6.2: return d["id"]
 return ""
func run():
 var world := World.new(); root.add_child(world)
 world._world_rng.seed = 777
 world._create_house_loot()
 var covered: Dictionary = {}
 var stray := 0
 var upstairs := 0
 var total := 0
 for id in world.generated:
  if not id.begins_with("city_loot_"): continue
  total += 1
  var e: Dictionary = world.generated[id]
  var bid := _building_at(e["pos"])
  if bid.is_empty(): stray += 1; push_error("loot fuera de vivienda: %s en %s" % [id, e["pos"]])
  else: covered[bid] = covered.get(bid, 0) + 1
  if e["floor_y"] > 1.0: upstairs += 1
 var failures := stray
 if covered.size() != 16:
  failures += 1
  push_error("viviendas cubiertas: %d/16" % covered.size())
 for d in CITY.BLOCK.BUILDINGS:
  if not covered.has(d["id"]): push_error("sin loot: " + d["id"])
 print("CITY_LOOT total=%d covered=%d upstairs=%d stray=%d failures=%d" % [total, covered.size(), upstairs, stray, failures])
 world.free()
 quit(1 if failures else 0)
