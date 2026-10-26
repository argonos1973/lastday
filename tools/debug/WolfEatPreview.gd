extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size = Vector2i(800,600)
 var stage := Node3D.new()
 root.add_child(stage)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(.13,.16,.18)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = .8
 stage.add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45,-35,0)
 stage.add_child(light)
 var model: Node3D = load(GameConst.WOLF_MODEL).instantiate()
 stage.add_child(model)
 var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
 var clip := ""
 for anim in ap.get_animation_list():
  if str(anim).ends_with("eat"):clip = anim
 assert(not clip.is_empty())
 ap.play(clip)
 ap.pause()
 var meat: Node3D = load("res://assets/models/props/cc0_-_raw_meat_4.glb").instantiate()
 stage.add_child(meat)
 var box := preload("res://scripts/NodeUtils.gd").compute_node_world_aabb(meat)
 var factor := .3 / maxf(box.size.x,maxf(box.size.y,box.size.z))
 meat.scale = Vector3.ONE * factor
 meat.position = Vector3(0,.04,1.02) - Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 1.8
 stage.add_child(camera)
 camera.position = Vector3(3,1.7,3)
 camera.look_at(Vector3(0,.45,.25))
 camera.make_current()
 DirAccess.make_dir_recursive_absolute("res://build/tmp/wolf_eat_frames")
 for frame in range(48):
  ap.seek(frame / 12.0,true)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tmp/wolf_eat_frames/%03d.png" % frame)
 stage.queue_free()
 await process_frame
 print("WOLF_EAT_PREVIEW_DONE")
 quit()
