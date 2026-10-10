extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
 func _ready(): pass
 func _process(_delta): pass
 func _physics_process(_delta): pass
var failures := 0
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures+=1
func _initialize():call_deferred("run")
func run():
 var world := Node3D.new()
 root.add_child(world)
 current_scene=world
 var actor := Actor.new()
 world.add_child(actor)
 actor.stats=preload("res://scripts/SurvivalStats.gd").new();actor.add_child(actor.stats)
 actor.inventory=preload("res://scripts/Inventory.gd").new()
 actor.add_child(actor.inventory)
 actor.setup_as_puppet()
 var player: AnimationPlayer=actor.third_person_animation_player
 check(player.has_animation("stairs/ascending"),"stair clip installed on real game character")
 if not player.has_animation("stairs/ascending"):
  world.free();quit(1);return
 var animation:=player.get_animation("stairs/ascending")
 check(animation.length>1.0 and animation.length<1.5,"original 1.2 second cycle retained")
 check(animation.get_track_count()>40,"body and finger rotation tracks retargeted")
 var skel: Skeleton3D=actor._find_skeleton(actor.third_person_model)
 for t in animation.get_track_count():
  check(animation.track_get_type(t)==Animation.TYPE_ROTATION_3D,"no source root translation or scale track")
  var path:=animation.track_get_path(t)
  check(skel.find_bone(str(path.get_subname(0)))>=0,"track targets a real character bone")
 var hip:=skel.find_bone("mixamorig_Hips")
 var initial:=skel.get_bone_pose_position(hip)
 var leg:=skel.find_bone("mixamorig_LeftUpLeg")
 player.play("stairs/ascending")
 player.advance(.01)
 var q:=skel.get_bone_pose_rotation(leg)
 var changed:=false
 for i in range(80):
  player.advance(.03)
  changed=changed or q.angle_to(skel.get_bone_pose_rotation(leg))>.1
  check(skel.get_bone_pose_position(hip).distance_to(initial)<.001,"no accumulating root climb")
  for b in skel.get_bone_count():
   if not skel.get_bone_global_pose(b).origin.is_finite(): failures+=1
 check(changed,"knees and thighs animate through the cycle")
 var floor:=StaticBody3D.new()
 floor.add_to_group("stair_surface")
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new();shape.size=Vector3(8,.1,8)
 collision.shape=shape;floor.add_child(collision);world.add_child(floor)
 await physics_frame
 await physics_frame
 actor.position=Vector3(0,.08,0)
 actor._update_stair_motion(true,.1)
 actor.position+=Vector3(.1,.02,0)
 check(actor._update_stair_motion(true,.1),"ascending marked stair selects clip")
 check(not actor._update_stair_motion(false,.1),"stopping exits stair clip")
 floor.remove_from_group("stair_surface")
 actor.position+=Vector3(.1,.02,0)
 check(not actor._update_stair_motion(true,.1),"ordinary slope does not select stair clip")
 world.free()
 print("STAIRS failures=",failures)
 quit(1 if failures else 0)
