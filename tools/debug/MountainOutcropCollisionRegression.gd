extends SceneTree
const Mountain = preload("res://scripts/HighMountainZone.gd")
func _initialize():call_deferred("run")
func run():
 var world:=Node3D.new()
 root.add_child(world)
 Mountain._build_mountain_rock_outcrops(world,world)
 await physics_frame
 await physics_frame
 var actor:=CharacterBody3D.new()
 actor.collision_layer=2
 actor.collision_mask=1
 var capsule:=CollisionShape3D.new()
 capsule.shape=CapsuleShape3D.new()
 capsule.shape.radius=.3
 capsule.shape.height=1.8
 actor.add_child(capsule)
 world.add_child(actor)
 var checked:=0
 var errors:=0
 for node in world.get_children():
  if not node is MultiMeshInstance3D:continue
  var body:=world.get_node_or_null(str(node.name).replace("MountainRockOutcropsMM_","MountainRockCollision_"))
  if body==null:errors+=1;continue
  var faces:PackedVector3Array=body.get_child(0).shape.get_faces()
  var mesh_faces:PackedVector3Array=node.multimesh.mesh.get_faces()
  if faces.size()!=mesh_faces.size()*node.multimesh.instance_count:errors+=1
  # Read baked collision triangles: valid even with the headless dummy renderer.
  for i in range(node.multimesh.instance_count):
   var offset:int=i*mesh_faces.size()
   var centroid:Vector3=(faces[offset]+faces[offset+1]+faces[offset+2])/3
   actor.position=centroid+Vector3.UP*200
   var contact:=actor.move_and_collide(Vector3.DOWN*400)
   if contact==null:
    errors+=1
    print("MISS ",node.name," instance=",i," point=",centroid)
   checked+=1
 print("MOUNTAIN_COLLISION capsule_sweeps=",checked," errors=",errors)
 if checked==0:errors+=1
 quit(0 if errors==0 else 1)
