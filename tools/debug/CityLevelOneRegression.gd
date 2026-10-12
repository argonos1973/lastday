extends SceneTree
class World extends "res://scripts/Main.gd":
 func _ready():set_process(false);set_physics_process(false)
 func _exit_tree():pass
 func _save_world_change_silent():pass
var failures:=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var world:=World.new();root.add_child(world);current_scene=world
 world.river_segments_data=world._default_river_segments()
 var district:=preload("res://scripts/CityExpansion.gd").create(world,true)
 check(district.buildings.size()==16,"16 resident houses")
 var ids:Dictionary={}
 for i in range(16):
  var b:Node3D=district.buildings[i]
  check(not ids.has(b.name),"unique persistent building id")
  ids[b.name]=true
  check(world.get_river_depth_at(b.global_position)<=0,"building on dry land")
  check(world.CityExpansion.inside_building(b.global_position+Vector3(0,1,0)),"indoor protection")
  check(world.CityExpansion.near_building(b.global_position,4),"vegetation exclusion")
  check(b.has_node(str(b.name)+"_door"),"persistent door")
 check(str(district.buildings[0].name)=="city_01","original id retained")
 check(district.buildings[0].position==Vector3(-16,0,-17),"original location retained")
 for pos in [Vector3(73,0,720),Vector3(41,0,776),Vector3(9,0,810)]:
  check(world.CityExpansion.on_road(pos),"secondary road query")
  check(world.get_river_depth_at(pos)<=0,"new street is dry")
 for i in range(8):
  check(world.has_node("DistrictParkedCar%dCollision"%i),"server parked car collision")
  var car_pos:Vector3=preload("res://scripts/CityStreetscape.gd").CAR_POSITIONS[i]
  var nearest_lane:=minf(absf(car_pos.x),absf(car_pos.x-64))
  check(nearest_lane-1.0>6.0,"parked car leaves pavement clear")
 var pavement: MultiMeshInstance3D=world.get_node("DistrictPavements")
 check(absf(pavement.multimesh.mesh.get_aabb().size.y-.12)<.01,"pavement module is 12 cm high")
 check(world.has_node("DistrictPavementCollision"),"server pavement collider")
 check(world.has_node("DistrictPlaza"),"Blender plaza loaded")
 world._create_invisible_collision_box("TestGround",Vector3(0,-.1,700),Vector3(300,.2,300))
 var walker:=CharacterBody3D.new();var cs:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
 capsule.radius=.35;capsule.height=1.75;cs.shape=capsule;cs.position.y=.9;walker.add_child(cs);walker.floor_snap_length=.4
 world.add_child(walker);walker.position=Vector3(1,.03,660)
 for frame in range(180):
  await physics_frame
  walker.velocity=Vector3(3,-2,0);walker.move_and_slide()
 check(walker.position.x>8.5,"capsule crosses raised pavement onto road")
 walker.free()
 print("CITY_LEVEL_ONE failures=",failures," houses=",district.buildings.size()," nodes=",get_node_count())
 world.free()
 quit(1 if failures else 0)
