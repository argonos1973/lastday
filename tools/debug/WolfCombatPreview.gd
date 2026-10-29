extends SceneTree
# Isolated game models driven by the real animal combat solver; no world/save.
class Animal extends WildlifeController:
 func _process(_delta): pass
 func _play_wolf_sound(_kind): pass
 func _play_pain_sound(): pass
 func _spawn_blood_splatter(): pass
func _initialize(): call_deferred("run")
func run():
 root.size = Vector2i(960, 640)
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(.12,.16,.19)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = .75
 stage.add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-50,-35,0)
 stage.add_child(light)
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(18,18)
 ground.mesh = plane
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(.22,.25,.18)
 ground.material_override = material
 stage.add_child(ground)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 6.0
 stage.add_child(camera)
 camera.position = Vector3(6,3.2,4.5)
 camera.look_at(Vector3(0,.8,0))
 camera.make_current()
 for kind in ["wolf", "bear"]:
  var pet := Animal.new()
  stage.add_child(pet)
  pet.setup("wolf", [Vector3(0,0,-1.05)])
  pet.tamed_to = "local"
  pet._wolf_hunger = 90
  var foe := Animal.new()
  stage.add_child(foe)
  foe.setup(kind, [Vector3(0,0,1.05 if kind == "wolf" else 1.5)])
  foe.rotation.y = PI
  pet._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  foe._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var folder: String = "res://build/tmp/wolf_vs_" + str(kind)
  DirAccess.make_dir_recursive_absolute(folder)
  for frame in 60:
   pet._attack_cooldown = maxf(0, pet._attack_cooldown - 1.0/15)
   foe._attack_cooldown = maxf(0, foe._attack_cooldown - 1.0/15)
   pet._fight_animal(foe, 1.0/15)
   if frame > 5:
    foe._fight_animal(pet, 1.0/15)
   else:
    foe._play_animation_by_name("idle")
   pet._animation_player.advance(1.0/15)
   foe._animation_player.advance(1.0/15)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder + "/%03d.png" % frame)
  print("COMBAT_PREVIEW ", kind, " wolf_hp=", pet.health, " target_hp=", foe.health)
  pet.free()
  foe.free()
 stage.queue_free()
 await process_frame
 quit()
