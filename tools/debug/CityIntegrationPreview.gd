extends SceneTree
class World extends "res://scripts/Main.gd":
 func _ready():set_process(false)
 func _exit_tree():pass
 func _save_world_change_silent():pass
 func _create_grass_clump(_pos:Vector3,_height:float,_color:Color,_rng:RandomNumberGenerator=null)->void:pass
func _initialize():call_deferred("run")
func run():
 var world:=World.new();root.add_child(world);current_scene=world
 world._terrain_rng.seed=world.TERRAIN_SEED
 world._world_rng.seed=GameConst.WORLD_SEED
 world._road_segments=world._generate_road_segments()
 world.river_segments_data=world._default_river_segments()
 world._create_invisible_collision_box("GroundCollision",Vector3(0,-.2,200),Vector3(1000,.2,1400))
 world._create_leafy_floor_ground()
 world._create_mountain_backdrop()
 await physics_frame
 world._create_road()
 preload("res://scripts/CityExpansion.gd").create(world,false)
 print("ROAD_END ",world._road_segments.back().center)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.shadow_enabled=true;world.add_child(light)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.36,.43,.48);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;world.add_child(env)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(145,160,800);camera.far=1500;camera.near=.5;camera.look_at(Vector3(9,0,530))
 for i in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://outputs/city_connected.png")
 world.queue_free()
 for i in range(10):await process_frame
 quit()
