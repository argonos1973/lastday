extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var tower:=preload("res://scripts/CityClockTower.gd").new();world.add_child(tower);tower.set_process(false);tower.set_clock_time(10.1666667)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,145,0);sun.shadow_enabled=true;world.add_child(sun)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.37,.43,.48);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.8,.86);env.environment.ambient_light_energy=.8;world.add_child(env)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(90,90);ground.mesh=plane;world.add_child(ground)
 var camera:=Camera3D.new();camera.fov=55;camera.far=200;world.add_child(camera)
 for shot in ["exterior","hall"]:
  camera.position=Vector3(43,24,-48) if shot=="exterior" else Vector3(0,2.5,-6.5)
  camera.look_at(Vector3(0,18,0) if shot=="exterior" else Vector3(0,1.6,3))
  for frame in range(20):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://outputs/clock_tower_%s.png"%shot)
 world.queue_free()
 for frame in range(5):await process_frame
 quit()
