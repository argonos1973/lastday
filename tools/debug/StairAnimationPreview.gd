extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
 func _ready():pass
 func _process(_d):pass
 func _physics_process(_d):pass
func _initialize():call_deferred("run")
func run():
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var actor:=Actor.new();world.add_child(actor)
 actor.stats=preload("res://scripts/SurvivalStats.gd").new();actor.add_child(actor.stats)
 actor.inventory=preload("res://scripts/Inventory.gd").new();actor.add_child(actor.inventory)
 actor.setup_as_puppet();actor.equip_clothing("Camiseta")
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);world.add_child(light)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(.17,.19,.21);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;world.add_child(env)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(3.4,1.7,3.4);camera.look_at(Vector3(0,.95,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6
 var ap:AnimationPlayer=actor.third_person_animation_player
 ap.play("stairs/ascending");ap.advance(.3);ap.pause()
 var skeleton: Skeleton3D=actor._find_skeleton(actor.third_person_model)
 skeleton.force_update_all_bone_transforms()
 var low:=100.0
 var high:=-100.0
 for b in skeleton.get_bone_count():
  var point:=skeleton.global_transform*skeleton.get_bone_global_pose(b).origin
  low=minf(low,point.y);high=maxf(high,point.y)
 camera.look_at(Vector3(0,(low+high)*.5,0));camera.size=(high-low)*1.6
 print("STAIR_VISUAL_BOUNDS ",low," ",high)
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://outputs/stair_character.png")
 world.free();quit()
