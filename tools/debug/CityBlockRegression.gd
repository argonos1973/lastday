extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ", label)
 if not ok: failures += 1
func run() -> void:
 Engine.time_scale=4.0
 var world := Node3D.new()
 root.add_child(world)
 current_scene = world
 var district := preload("res://scripts/CityBlock.gd").new()
 world.add_child(district)
 var NB := district.BUILDINGS.size()
 for i in range(NB): district.load_building(i)
 await physics_frame
 await physics_frame
 check(district.buildings.size()==NB,"all buildings loaded")
 var space := world.get_world_3d().direct_space_state
 for i in range(NB):
  if i % 4 == 1 or i % 4 == 2:
   var flat:Node3D=district.buildings[i]
   var flat_stairs := flat.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.is_in_group("stair_surface"))
   check(flat_stairs.size() >= 2, "flat-roof house %d has both interior stair flights" % i)
 for i in range(NB):
  var b: Node3D = district.buildings[i]
  var door: Door = b.get_node("city_%02d_door"%(i+1))
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(0,1.2,8)),b.to_global(Vector3(0,1.2,4))))
  check(not hit.is_empty() and hit.collider == door,"closed door blocks entry %d"%i)
  door.is_open=true
  door.rotation_degrees.y=door.open_yaw
 await physics_frame
 for i in range(NB):
  var b: Node3D = district.buildings[i]
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(0,1.2,8)),b.to_global(Vector3(0,1.2,4))))
  check(hit.is_empty(),"open doorway has no hidden full-wall collider %d"%i)
  if district.BUILDINGS[i].has("asset"): continue # highrise has its own window layout
  # x=-4.1 = centro de una hoja de ventana (el partidor solido va en -3.5)
  hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(-4.1,1.8,7)),b.to_global(Vector3(-4.1,1.8,5))))
  check(hit.is_empty(),"window opening is real %d"%i)
 var highrise_building:Node3D=district.buildings[16]
 var tower_window := space.intersect_ray(PhysicsRayQueryParameters3D.create(highrise_building.to_global(Vector3(-3.35,1.8,7)),highrise_building.to_global(Vector3(-3.35,1.8,5.3))))
 check(tower_window.is_empty(),"highrise shop window is visibly open, not paneled over")
 var tower_entry := space.intersect_ray(PhysicsRayQueryParameters3D.create(highrise_building.to_global(Vector3(0,1.5,7.8)),highrise_building.to_global(Vector3(0,1.5,-1.0))))
 check(tower_entry.is_empty(),"highrise entrance and central aisle remain clear")
 var building: Node3D = district.buildings[0]
 var body := CharacterBody3D.new()
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 # Match PlayerController._create_body exactly; a smaller capsule and longer
 # floor snap could conceal clearances that snag the real avatar.
 capsule.height=1.75
 capsule.radius=.35
 shape.shape=capsule
 shape.position.y=.9
 body.add_child(shape)
 world.add_child(body)
 body.global_position=building.to_global(Vector3(4.5,.15,4.7))
 # ~4.5 m/s horizontal como el paseo del jugador; la pendiente de 26 deg
 # reduce el avance efectivo a ~2.5 m/s -> la rampa de 6.4 m toma ~160 frames.
 for frame in range(240):
  await physics_frame
  body.velocity=Vector3(0,-2,-4.5)
  body.move_and_slide()
 var local := building.to_local(body.global_position)
 check(local.y>3.1 and local.z< -2.0,"capsule walks up staircase to upper landing: %s"%local)
 # Pitched slate roofs (building_1/4) have no roof access: walking the same
 # line from the upper-front landing stays on the upper floor, and a ray up
 # through the stairwell hits the closed ceiling slab.
 for index in [0,3]:
  var house:Node3D=district.buildings[index]
  body.global_position=house.to_global(Vector3(4.5,3.96,4.7))
  for frame in range(160):
   await physics_frame
   body.velocity=house.global_basis*Vector3(0,-2,-4.0);body.move_and_slide()
  local=house.to_local(body.global_position)
  check(local.y<5.0,"pitched roof house %d has no roof stair: %s"%[index,local])
  var ray := PhysicsRayQueryParameters3D.create(house.to_global(Vector3(4.5,5.0,1.0)),house.to_global(Vector3(4.5,9.0,1.0)))
  ray.exclude=[body.get_rid()]
  var ceiling := space.intersect_ray(ray)
  check(not ceiling.is_empty() and house.to_local(ceiling.position).y<8.2,"pitched roof house %d ceiling is closed"%index)
 # Flat roofs (building_2/3) switch back: first flight on the east lane up to
 # the back landing, turn west, roof flight climbs back towards the front.
 # Exercise every placed house, not just one copy of each GLB: position and
 # yaw must not break roof access.
 for index in [1,2,5,6,9,10,13,14]:
  var house:Node3D=district.buildings[index]
  check(house.get_node_or_null("UpperLandingSupport")!=null,"flat house %d has collision support for the upper landing"%index)
  check(house.get_node_or_null("LandingBridgeSupport")!=null,"flat house %d has collision support for the stair bridge"%index)
  check(house.get_node_or_null("UpperStairBaseSupport")!=null,"flat house %d has collision support under the roof flight"%index)
  body.global_position=house.to_global(Vector3(5.21,.2,4.8))
  for frame in range(260):
   await physics_frame
   body.velocity=house.global_basis*Vector3(0,-1,-4.0);body.move_and_slide()
   local=house.to_local(body.global_position)
   if local.z< -2.3 and local.y>3.8:break
  check(local.y>3.8 and local.z< -2.0,"flat house %d first flight to back landing: %s"%[index,local])
  for frame in range(80):
   await physics_frame
   body.velocity=house.global_basis*Vector3(-3.0,-1,0);body.move_and_slide()
   local=house.to_local(body.global_position)
   if local.x<3.9:break
  for frame in range(260):
   await physics_frame
   body.velocity=house.global_basis*Vector3(0,-1,4.0);body.move_and_slide()
   local=house.to_local(body.global_position)
   if local.z>4.8 and local.y>7.8:break
  check(local.y>7.8 and local.z>4.5,"roof flight returns towards the front %d: %s"%[index,local])
  for frame in range(20):
   await physics_frame
   body.velocity=Vector3(0,-1,0);body.move_and_slide()
  check(house.to_local(body.global_position).y>7.8,"stable roof landing")
  # Use normal speed for the transition back onto the narrow landing; speeding
  # physics up can tunnel through it and does not represent the shipped game.
  Engine.time_scale=1.0
  for frame in range(260):
   await physics_frame
   body.velocity=house.global_basis*Vector3(0,-1,-4.0);body.move_and_slide()
   local=house.to_local(body.global_position)
   # Stop inside the upper back landing before walking past its front edge.
   if local.z< -2.65 and local.y<4.2:break
  check(local.y>3.7 and local.y<4.2,"roof descent returns to back landing %d: %s"%[index,local])
  Engine.time_scale=4.0
 body.free()
 # Highrise (city_17): the stair collision must be a thin slab — a fat wedge
 # underside once ate the headroom over the lower flight and blocked the stairs.
 for index in range(NB):
  var def: Dictionary = district.BUILDINGS[index]
  if not def.has("asset"): continue
  var tower: Node3D = district.buildings[index]
  var floors: Array = def.get("loot_floor_values", [])
  var room_min := 99.0
  for lvl in range(floors.size() - 1):
   var y0: float = float(floors[lvl])
   for z in range(43, -45, -4):
    var zz: float = z / 10.0
    var surf: float = y0 + (4.65 - zz) * 3.9 / 9.3
    var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(
     tower.to_global(Vector3(-3.0, surf + 1.0, zz)), tower.to_global(Vector3(-3.0, 20.0, zz))))
    if not up.is_empty():
     room_min = minf(room_min, tower.to_local(up.position).y - surf)
  check(room_min > 2.6, "highrise stair headroom %.2f m" % room_min)
  var stair_bodies := tower.find_children("*", "StaticBody3D", true, false).filter(
   func(n): return n.is_in_group("stair_surface"))
  check(stair_bodies.size() >= 3, "highrise stair surfaces (%d)" % stair_bodies.size())
 district.unload_building(0)
 await process_frame
 check(district.door_states.get("city_01_door",false),"door state retained after sector unload")
 building=district.load_building(0)
 check(building.get_node("city_01_door").is_open,"open door restored on reload")
 district.update_observer(Vector3(300,0,300))
 check(district.buildings.is_empty(),"distant buildings unloaded")
 for i in range(17): district.update_observer(Vector3(32,0,48))
 check(district.buildings.size()==NB,"buildings stream back on return")
 world.free()
 print("CITY_REGRESSION failures=",failures)
 quit(1 if failures else 0)
