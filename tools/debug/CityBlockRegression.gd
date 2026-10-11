extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ", label)
 if not ok: failures += 1
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 current_scene = world
 var district := preload("res://scripts/CityBlock.gd").new()
 world.add_child(district)
 for i in range(4): district.load_building(i)
 await physics_frame
 await physics_frame
 check(district.buildings.size()==4,"four enterable buildings loaded")
 var space := world.get_world_3d().direct_space_state
 for i in range(4):
  var b: Node3D = district.buildings[i]
  var door: Door = b.get_node("city_0%d_door"%(i+1))
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(0,1.2,8)),b.to_global(Vector3(0,1.2,4))))
  check(not hit.is_empty() and hit.collider == door,"closed door blocks entry %d"%i)
  door.is_open=true
  door.rotation_degrees.y=door.open_yaw
 await physics_frame
 for i in range(4):
  var b: Node3D = district.buildings[i]
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(0,1.2,8)),b.to_global(Vector3(0,1.2,4))))
  check(hit.is_empty(),"open doorway has no hidden full-wall collider %d"%i)
  # x=-4.1 = centro de una hoja de ventana (el partidor solido va en -3.5)
  hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(b.to_global(Vector3(-4.1,1.8,7)),b.to_global(Vector3(-4.1,1.8,5))))
  check(hit.is_empty(),"window opening is real %d"%i)
 var building: Node3D = district.buildings[0]
 var body := CharacterBody3D.new()
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.height=1.8
 capsule.radius=.3
 shape.shape=capsule
 shape.position.y=.9
 body.add_child(shape)
 body.floor_snap_length=.4
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
 # Exterior roof stair: ramp along the back wall (local z -6.3..-7.2) rises
 # x -5.3 -> 4.5 to a landing at ~8.1, then the capsule steps through the
 # parapet gap onto the roof (slab for flat roofs, slate strip for pitched).
 body.global_position=building.to_global(Vector3(-5.05,.55,-6.75))
 local = building.to_local(body.global_position)
 for frame in range(700):
  await physics_frame
  local = building.to_local(body.global_position)
  body.velocity=Vector3(1.2 if local.x<5.0 else 0.0,-2,2.5) if (local.x>4.3 and local.y>7.8) else Vector3(3.5,-2,0)
  body.move_and_slide()
 check(local.y>7.8 and local.x>4.0,"capsule climbs exterior stair to roof landing: %s"%local)
 check(local.y>7.7 and local.z>-6.4,"capsule stands on pitched roof edge: %s"%local)
 # Flat-roof building: same stair, lands on the concrete slab.
 var flat: Node3D = district.buildings[1]
 body.global_position=flat.to_global(Vector3(-5.05,.55,-6.75))
 local = flat.to_local(body.global_position)
 for frame in range(700):
  await physics_frame
  local = flat.to_local(body.global_position)
  body.velocity=Vector3(1.2 if local.x<5.0 else 0.0,-2,2.5) if (local.x>4.3 and local.y>7.8) else Vector3(3.5,-2,0)
  body.move_and_slide()
 local = flat.to_local(body.global_position)
 check(local.y>7.7 and local.z>-6.4,"capsule stands on flat roof slab: %s"%local)
 body.free()
 district.unload_building(0)
 await process_frame
 check(district.door_states.get("city_01_door",false),"door state retained after sector unload")
 building=district.load_building(0)
 check(building.get_node("city_01_door").is_open,"open door restored on reload")
 district.update_observer(Vector3(300,0,300))
 check(district.buildings.is_empty(),"distant buildings unloaded")
 for i in range(5): district.update_observer(Vector3.ZERO)
 check(district.buildings.size()==4,"buildings stream back on return")
 world.free()
 print("CITY_REGRESSION failures=",failures)
 quit(1 if failures else 0)
