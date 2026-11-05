extends SceneTree
class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _save_world_change_silent() -> void: pass
	func _is_near_road(pos: Vector3, margin: float) -> bool:
		return absf(pos.x) <= 3.5 + margin
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	var errors := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	world._world_rng.seed = 173
	var state := world._world_rng.state
	for i in range(12000):
		world._queue_grass_instance(Vector3(rng.randf_range(-16,16),0,rng.randf_range(-25,25)),.4,.4,Color(.24,.34,.14))
	var short_count := 0
	var full_count := 0
	for variant in world.grass_batch_transforms:
		for t: Transform3D in variant:
			if absf(t.origin.x) < 5.0: errors += 1
			if absf(t.origin.x) < 6.0:
				short_count += 1
				if t.basis.y.length() > .24: errors += 1
			if absf(t.origin.x) > 11.0:
				full_count += 1
				if absf(t.basis.y.length()-.4) > .001: errors += 1
	if short_count == 0 or full_count == 0 or world._world_rng.state != state: errors += 1
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,60)
	ground.mesh = plane
	ground.position.y = -.01
	ground.material_override = MaterialFactory.make_forest_ground_material()
	world.add_child(ground)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-5,0,-30),Vector3(5,0,-30),Vector3(-5,0,30),Vector3(5,0,-30),Vector3(5,0,30),Vector3(-5,0,30)]:
		st.set_normal(Vector3.UP)
		st.set_color(Color(0,0,0))
		st.set_uv(Vector2(p.x,p.z)*.2)
		st.set_uv2(Vector2(p.x/5.0,p.z))
		st.add_vertex(p+Vector3.UP*.01)
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/road_surface.gdshader")
	material.set_shader_parameter("aggregate",load("res://assets/textures/dirt_road/Ground038_1K-JPG_Color.jpg"))
	road.material_override = material
	world.add_child(road)
	await world._flush_grass_batches()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.45,.58,.67)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .6
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2,2,14)
	camera.look_at(Vector3(5,0,-8))
	camera.current = true
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/tmp/road_verge_preview.png")
	print("ROAD_VERGE errors=",errors," short=",short_count," full=",full_count)
	world.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
