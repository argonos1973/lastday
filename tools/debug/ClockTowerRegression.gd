extends SceneTree
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func walk(body:CharacterBody3D,target:Vector3)->bool:
 for frame in range(500):
  await physics_frame
  var direction:=Vector3(target.x-body.position.x,0,target.z-body.position.z)
  if direction.length()<.14:return true
  body.velocity=direction.normalized()*4.0+Vector3(0,-2,0)
  body.move_and_slide()
 return false
func run():
 Engine.time_scale=4.0
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var tower:=preload("res://scripts/CityClockTower.gd").new();world.add_child(tower);tower.set_process(false)
 check(tower._hands.size()==8,"four hour hands and four minute hands")
 tower.set_clock_time(0)
 for i in range(8):check(tower._hands[i].basis.is_equal_approx(tower._bases[i]),"midnight resets clock hand")
 tower.set_clock_time(3.25)
 for i in range(8):
  var turns:=3.25/12 if i<4 else .25
  check(tower._hands[i].basis.is_equal_approx(tower._bases[i]*Basis(Vector3(0,0,1),TAU*turns)),"03:15 hand angle")
 var body:=CharacterBody3D.new();var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.75;collider.shape=capsule;collider.position.y=.9;body.add_child(collider);body.floor_snap_length=.4;world.add_child(body)
 # The dressed entrance and flush apron must remain clear in both directions.
 body.position=Vector3(0,.08,-9.4)
 await physics_frame
 check(await walk(body,Vector3(0,0,-5.2)),"enter through dressed portico")
 check(body.position.y>-.1,"entrance supports capsule")
 check(await walk(body,Vector3(0,0,-9.4)),"leave through dressed portico")
 # Switchback: flight L climbs lane A (x 4.7) towards +z when even, lane B
 # (x 2.35) towards -z when odd; each starts on the landing where the last ended.
 var lane_x:=func(level:int)->float:return 4.7 if level%2==0 else 2.35
 var dir:=func(level:int)->float:return 1.0 if level%2==0 else -1.0
 body.position=Vector3(4.7,.05,-5.0)
 await physics_frame
 for level in range(7):
  var x:float=lane_x.call(level);var d:float=dir.call(level)
  check(await walk(body,Vector3(x,0,-5.0*d)),"stair entry %d"%level)
  check(await walk(body,Vector3(x,0,5.0*d)),"tower ascent flight %d"%level)
  check(absf(body.position.y-(level+1)*4.2)<.18,"tower landing height %d: %s"%[level,body.position])
  for frame in range(10):
   await physics_frame;body.velocity=Vector3(0,-2,0);body.move_and_slide()
  check(absf(body.position.y-(level+1)*4.2)<.18,"stable floor %d"%level)
 for level in range(6,-1,-1):
  var x:float=lane_x.call(level);var d:float=dir.call(level)
  check(await walk(body,Vector3(x,0,5.0*d)),"descent entry %d"%level)
  check(await walk(body,Vector3(x,0,-5.0*d)),"tower descent %d"%level)
  check(absf(body.position.y-level*4.2)<.18,"descent landing %d: %s"%[level,body.position])
 # The open stairwell of an arriving flight cannot be walked into from the far
 # landing: floor 1, lane A, stepping south from the z=-5 landing stays at 4.2.
 body.position=Vector3(4.7,4.25,-5.0)
 await physics_frame
 for frame in range(90):
  await physics_frame;body.velocity=Vector3(0,-2,3.0);body.move_and_slide()
 check(body.position.y>4.0,"stairwell stop holds: %s"%body.position)
 world.free()
 print("CLOCK_TOWER failures=",failures)
 quit(1 if failures else 0)
