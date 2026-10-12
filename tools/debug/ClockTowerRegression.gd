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
 body.position=Vector3(4.5,.05,-5.5)
 await physics_frame
 for level in range(7):
  check(await walk(body,Vector3(4.5,0,5.5)),"tower ascent flight %d"%level)
  check(absf(body.position.y-(level+1)*4.2)<.18,"tower landing height %d: %s"%[level,body.position])
  for frame in range(10):
   await physics_frame;body.velocity=Vector3(0,-2,0);body.move_and_slide()
  check(absf(body.position.y-(level+1)*4.2)<.18,"stable floor %d"%level)
  if level<6:
   check(await walk(body,Vector3(1.5,0,5.5)),"landing to corridor")
   check(await walk(body,Vector3(1.5,0,-5.5)),"return corridor")
   check(await walk(body,Vector3(4.5,0,-5.5)),"next stair entry")
 for level in range(6,-1,-1):
  check(await walk(body,Vector3(4.5,0,-5.5)),"tower descent %d"%level)
  check(absf(body.position.y-level*4.2)<.18,"descent landing %d"%level)
  if level>0:
   await walk(body,Vector3(1.5,0,-5.5));await walk(body,Vector3(1.5,0,5.5));await walk(body,Vector3(4.5,0,5.5))
 world.free()
 print("CLOCK_TOWER failures=",failures)
 quit(1 if failures else 0)
