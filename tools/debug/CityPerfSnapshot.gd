extends SceneTree
class World extends "res://scripts/Main.gd":
 func _ready():set_process(false)
 func _exit_tree():pass
 func _save_world_change_silent():pass
func _initialize():call_deferred("run")
func _count(node:Node,acc:Dictionary)->void:
 acc["nodes"]=acc.get("nodes",0)+1
 if node is MultiMeshInstance3D:
  acc["mmis"]=acc.get("mmis",0)+1
  var mm:MultiMesh=node.multimesh
  if mm!=null:acc["mmi_instances"]=acc.get("mmi_instances",0)+mm.instance_count
 if node is MeshInstance3D:acc["meshes"]=acc.get("meshes",0)+1
 for c in node.get_children():_count(c,acc)
func _snap(world:World,camera:Camera3D,pos:Vector3,look:Vector3,label:String)->void:
 camera.position=pos;camera.look_at(look,Vector3.UP)
 for i in range(60):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://outputs/level1_%s.png"%label)
 var P:=Performance
 print("PERF %s fps=%.1f objs=%d draws=%d prims=%d proc_ms=%.2f vram_mb=%.1f"%[
  label,P.get_monitor(P.TIME_FPS),
  int(P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME)),
  int(P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
  int(P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
  P.get_monitor(P.TIME_PROCESS)*1000.0,
  P.get_monitor(P.RENDER_VIDEO_MEM_USED)/1048576.0])
func run():
 var world:=World.new();root.add_child(world);current_scene=world
 world._terrain_rng.seed=world.TERRAIN_SEED
 world._world_rng.seed=GameConst.WORLD_SEED
 world._road_segments=world._generate_road_segments()
 world.river_segments_data=world._default_river_segments()
 world._create_invisible_collision_box("GroundCollision",Vector3(0,-.1,200),Vector3(1000,.2,1400))
 world._create_leafy_floor_ground()
 world._create_road()
 var t0:=Time.get_ticks_msec()
 preload("res://scripts/CityExpansion.gd").create(world,false)
 await world._flush_grass_batches()
 print("PERF city_create_ms=%d"%(Time.get_ticks_msec()-t0))
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.shadow_enabled=true;world.add_child(light)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.38,.46,.52);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;world.add_child(env)
 world._load_forest_tree_pack()
 t0=Time.get_ticks_msec()
 await world._create_forest()
 print("PERF forest_ms=%d"%(Time.get_ticks_msec()-t0))
 var acc:Dictionary={}
 _count(world,acc)
 print("PERF nodes=%d mesh_instances=%d multimeshes=%d mmi_instances=%d"%[acc["nodes"],acc["meshes"],acc.get("mmis",0),acc.get("mmi_instances",0)])
 var camera:=Camera3D.new();world.add_child(camera);camera.far=1200;camera.near=.5
 await _snap(world,camera,Vector3(9,2.0,560),Vector3(9,2,700),"city_street")
 await _snap(world,camera,Vector3(125,100,855),Vector3(41,0,728),"city_aerial")
 await _snap(world,camera,Vector3(9,2.2,700),Vector3(9,2,500),"forest_south")
 world.queue_free()
 for i in range(8):await process_frame
 quit()
