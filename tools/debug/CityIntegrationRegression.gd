extends SceneTree
class FakeServer extends RefCounted:
 var is_dedicated_server:=true
 var is_host:=true
 func get_my_id():return 1
class World extends "res://scripts/Main.gd":
 func _ready():set_process(false)
 func _exit_tree():pass
 func _save_world_change_silent():pass
var errors:=0
func check(ok:bool,msg:String):
 print("PASS " if ok else "FAIL ",msg)
 if not ok:errors+=1
func _initialize():call_deferred("run")
func run():
 var world:=World.new();root.add_child(world);current_scene=world
 world.net=FakeServer.new()
 world._terrain_rng.seed=world.TERRAIN_SEED
 world._world_rng.seed=GameConst.WORLD_SEED
 world._road_segments=world._generate_road_segments()
 world.river_segments_data=world._default_river_segments()
 world._create_mountain_backdrop()
 await world._create_rocky_foothills()
 var expansion=preload("res://scripts/CityExpansion.gd")
 for z in range(440,741,5):
  check(world._get_ground_height(Vector3(9,0,z))<.01,"clear road pass at z=%d"%z)
  check(not world._is_near_river(Vector3(9,0,z),5),"new route avoids water at z=%d"%z)
 for z in range(0,501,10):
  check(world._get_ground_height(Vector3(9,0,z))<3.0,"road slope filter reaches old map edge z=%d"%z)
 var district:Node3D=expansion.create(world,true)
 check(world.get_river_depth_at(Vector3(9,0.0,385))>0.0,"road crosses the river as a wading ford")
 check(district.position==Vector3(9,0,680),"city positioned beyond old southern boundary")
 check(district.buildings.size()==expansion.BLOCK.BUILDINGS.size(),"all buildings loaded on dedicated server")
 check(not district.is_processing(),"main-world doors/collisions stay resident")
 check(world._is_player_in_house(Vector3(-7,1,663)),"city interiors recognized as shelter")
 check(not world._is_player_in_house(Vector3(9,1,680)),"city street is outdoors")
 check(world._is_on_road(Vector3(9,0,610)),"extension participates in road placement queries")
 for i in range(district.buildings.size()):
  var door:Door=district.buildings[i].get_node("city_%02d_door"%(i+1))
  check(world._net_door_state_changed(str(door.name),true),"server applies city door state")
  check(door.is_open and world._server_door_states[str(door.name)],"door state recorded for world sync")
 check(expansion.SOUTH_LIMIT>expansion.CENTER.z+40,"expanded ground contains city and roads")
 world.free()
 print("CITY_INTEGRATION failures=",errors)
 quit(1 if errors else 0)
