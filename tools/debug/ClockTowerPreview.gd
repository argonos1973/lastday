extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var tower:=preload("res://scripts/CityClockTower.gd").new();world.add_child(tower);tower.set_process(false);tower.set_clock_time(10.1666667)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,145,0);sun.shadow_enabled=true;world.add_child(sun)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.37,.43,.48);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.8,.86);env.environment.ambient_light_energy=.8;world.add_child(env)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(90,90);ground.mesh=plane;world.add_child(ground)
 var camera:=Camera3D.new();camera.fov=55;camera.far=200;world.add_child(camera)
 var lamp:=OmniLight3D.new();lamp.omni_range=14;lamp.light_energy=1.6;world.add_child(lamp)
 var shots:={"exterior":[Vector3(43,24,-48),Vector3(0,18,0)],"hall":[Vector3(-3,2.5,-6.5),Vector3(2,1.6,3)],"stairs":[Vector3(1.6,6.0,5.6),Vector3(3.6,5.6,-2.5)]}
 shots["entrance"]=[Vector3(5,2.7,-14),Vector3(0,1.8,-8.3)]
 shots["counter"]=[Vector3(-3.5,2.0,-5.3),Vector3(-4.0,.75,-2.2)]
 shots["stair_detail"]=[Vector3(4.75,1.8,-5.9),Vector3(4.7,2.2,0)]
 for shot in shots:
  camera.position=shots[shot][0];lamp.position=camera.position+Vector3(0,.8,0)
  camera.look_at(shots[shot][1])
  for frame in range(20):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://outputs/clock_tower_%s.png"%shot)
 world.queue_free()
 for frame in range(5):await process_frame
 quit()
