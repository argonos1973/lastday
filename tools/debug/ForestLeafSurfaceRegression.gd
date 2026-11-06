# Real renderer required: reads MultiMesh transforms and captures terrain.
extends SceneTree
class World extends "res://scripts/Main.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
func _initialize(): call_deferred("run")
func run():
	var w := World.new()
	root.add_child(w)
	current_scene=w
	w._world_rng.seed=GameConst.WORLD_SEED
	w._create_mountain_peak("RollingHill",Vector3(150,0,150),22,18,8,0,Color(.3,.3,.2))
	var floor_mesh:=MeshInstance3D.new()
	floor_mesh.mesh=PlaneMesh.new()
	floor_mesh.mesh.size=Vector2(100,100)
	floor_mesh.position=Vector3(150,0,150)
	floor_mesh.material_override=MaterialFactory.make_forest_ground_material()
	w.add_child(floor_mesh)
	floor_mesh.create_trimesh_collision()
	await physics_frame
	await physics_frame
	var trees:Array=[]
	for x in range(140,165,4):
		for z in range(140,165,4): trees.append(Vector3(x,0,z))
	var started:=Time.get_ticks_msec()
	await preload("res://scripts/ForestLeafLitter.gd").build(w,trees)
	var build_ms:=Time.get_ticks_msec()-started
	await process_frame
	var checked:=0
	var errors:=0
	var old_buried:=0
	var focus:=Vector3.ZERO
	var query:=PhysicsRayQueryParameters3D.new()
	query.collision_mask=1
	for node in w.get_children():
		if not str(node.name).begins_with("ForestLeafLitter_"): continue
		for i in range(node.multimesh.instance_count):
			var t:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
			query.from=Vector3(t.origin.x,500,t.origin.z)
			query.to=Vector3(t.origin.x,-50,t.origin.z)
			var hit:=w.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): errors+=1;continue
			if absf(t.origin.y-hit.position.y-.018)>.002:errors+=1
			if t.basis.y.normalized().dot(hit.normal)<.999:errors+=1
			if hit.position.y>w._get_ground_height(t.origin)+.03:old_buried+=1
			if focus==Vector3.ZERO:focus=t.origin
			checked+=1
	if checked<100 or old_buried==0:errors+=1
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.19,.23,.27)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.8,.85,1)
	env.environment.ambient_light_energy=.7
	w.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	w.add_child(sun)
	var camera:=Camera3D.new()
	w.add_child(camera)
	camera.position=focus+Vector3(0,1.7,2)
	camera.look_at(focus)
	root.size=Vector2i(1100,750)
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/leaf_real_surface.png")
	print("LEAF_SURFACE checked=",checked," previously_buried=",old_buried," build_ms=",build_ms," errors=",errors)
	quit(0 if errors==0 else 1)
