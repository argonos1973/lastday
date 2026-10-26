extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size = Vector2i(1000,700)
 var stage := Node3D.new()
 root.add_child(stage)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(.12,.15,.18)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = .7
 stage.add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45,-35,0)
 stage.add_child(light)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 3.2
 stage.add_child(camera)
 camera.make_current()
 var model: Node3D = load(GameConst.WOLF_MODEL).instantiate()
 stage.add_child(model)
 var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
 camera.position = Vector3(2,1.4,3)
 camera.look_at(Vector3(0,.5,.3))
 for kind in ["sit","lie"]:
  var clip := ""
  for anim in ap.get_animation_list():
   if str(anim).ends_with(kind):clip = anim
  assert(not clip.is_empty())
  ap.play(clip)
  ap.seek(1.0,true)
  ap.pause()
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tmp/wolf_godot_"+kind+".png")
 model.queue_free()
 await process_frame
 var door := Door.new()
 stage.add_child(door)
 door.setup("Puerta",Vector3(1.2,2.3,.12),Color.SADDLE_BROWN,-95)
 camera.size = 3.1
 camera.position = Vector3(3,2,4)
 camera.look_at(Vector3(.6,1.15,0))
 for value in [false,true,false]:
  door.set_open(value)
  var before: AudioStreamPlayer3D = door._door_audio
  door.set_open(value)
  assert(door._door_audio == before)
  await create_timer(.75).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tmp/door_"+("open" if value else "closed")+".png")
 stage.queue_free()
 await process_frame
 print("COMPANION_DOOR_PREVIEW_PASS")
 quit()
