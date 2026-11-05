# Isolated art benchmark: no world startup, saves, networking or gameplay RNG.
# Run without --headless to write build/tmp/forest_natural_preview.png.
extends SceneTree

class PreviewWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void: pass
	func _get_exact_ground_y(x: float, z: float, _fallback: float = 0.0) -> float:
		return 0.10 * (x - 180.0) + 1.3 * sin(z * 0.075) + 0.4 * sin(x * 0.17 + z * 0.09)
	func _can_place_ground_vegetation(_pos: Vector3, _margin := 0.8, _short_grass := false) -> bool:
		return true

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := PreviewWorld.new()
	root.add_child(world)
	current_scene = world
	world._world_rng.seed = GameConst.WORLD_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(145, 226):
		for z in range(140, 226):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var px: float = float(x) + corner.x
				var pz: float = float(z) + corner.y
				st.set_uv(Vector2(px,pz))
				st.add_vertex(Vector3(px,world._get_exact_ground_y(px,pz),pz))
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	ground.material_override = MaterialFactory.make_forest_ground_material()
	world.add_child(ground)
	world._load_forest_tree_pack()
	var batches: Array = []
	for entry in world._forest_tree_meshes: batches.append([])
	var trees: Array = []
	for x in range(150,222,6):
		for z in range(145,220,6):
			var pos := Vector3(x+rng.randf_range(-2,2),0,z+rng.randf_range(-2,2))
			# Broken clearing with an irregular treeline, not uniform spacing.
			if absf(pos.x - 186.0 - 4.0*sin(pos.z*.12)) < 7.0: continue
			pos.y = world._get_exact_ground_y(pos.x,pos.z)
			trees.append(pos)
			var variant := world._pick_forest_tree_variant(rng)
			var basis := Basis.from_euler(Vector3(-PI*.5,0,rng.randf_range(0,TAU))).scaled(Vector3.ONE*rng.randf_range(.75,1.35))
			batches[variant].append(Transform3D(basis,pos))
	world._flush_forest_multimeshes(batches)
	preload("res://scripts/ForestFloorCover.gd").apply(world,trees)
	var patches := FastNoiseLite.new()
	patches.seed = 291
	patches.frequency = .09
	var tufts := 0
	for i in range(14000):
		var x := rng.randf_range(155,215)
		var z := rng.randf_range(150,220)
		var density := smoothstep(-.35,.4,patches.get_noise_2d(x,z))
		if rng.randf() > lerpf(.12,.92,density): continue
		var pos := Vector3(x,world._get_exact_ground_y(x,z)+.006,z)
		var height := rng.randf_range(.13,.34) * lerpf(.7,1.35,density)
		world._queue_grass_instance(pos,height,rng.randf_range(.20,.46),Color(.20,.29,.105).lerp(Color(.32,.35,.17),rng.randf()))
		tufts += 1
	await world._flush_grass_batches()
	var state := world._world_rng.state
	# Many samples exercise variant selection and placement on the slope.
	var rock_candidates: Array = []
	for i in range(1800):
		var x := rng.randf_range(155,215)
		var z := rng.randf_range(150,215)
		rock_candidates.append(Vector3(x,world._get_exact_ground_y(x,z),z))
	await world._build_forest_understory_multimeshes(rock_candidates)
	for plant_batch in world.get_children():
		if str(plant_batch.name).begins_with("ForestUnderstory_") or str(plant_batch.name).begins_with("ForestDeadwood_"):
			plant_batch.free()
	await preload("res://scripts/ForestUnderstory.gd").build(world,trees)
	preload("res://scripts/ForestDeadwood.gd").build(world,trees)
	var errors := 0
	var rocks := 0
	var variants: Dictionary = {}
	for node in world.get_children():
		if not str(node.name).begins_with("ForestMossRocksMM"): continue
		var mm: MultiMesh = node.multimesh
		variants[mm.mesh] = true
		for i in range(mm.instance_count):
			var t := mm.get_instance_transform(i)
			var expected := world._get_exact_ground_y(t.origin.x,t.origin.z) + .06*pow(absf(t.basis.determinant()) / (1.15*.78), 1.0/3.0)
			if absf(t.origin.y-expected) > .001: errors += 1
			rocks += 1
	if variants.size() < 2 or world._world_rng.state != state: errors += 1
	# Exposed granite ledge at the edge of the clearing, partly buried.
	for i in range(7):
		var pos := Vector3(197.0 + float(i)*1.7, 0, 189.0 - float(i)*2.0)
		pos.y = world._get_exact_ground_y(pos.x,pos.z)
		var rock := MeshInstance3D.new()
		rock.mesh = world._get_forest_rock_mesh(pos)
		rock.material_override = MaterialFactory.make_forest_rock_material()
		rock.transform = Transform3D(Basis.from_euler(Vector3(.1,float(i)*.7,.2)).scaled(Vector3(2.4,1.5,2.0)),pos)
		world.add_child(rock)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43,-28,0)
	sun.light_color = Color(1,.94,.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.45,.58,.67)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.65,.75,.85)
	env.environment.ambient_light_energy = .65
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(188,world._get_exact_ground_y(188,213)+1.7,213)
	camera.look_at(Vector3(185,world._get_exact_ground_y(185,180)+1.5,180))
	camera.fov = 72
	camera.current = true
	var near_cover := preload("res://scripts/NearGroundCover.gd").new()
	world.add_child(near_cover)
	near_cover.setup(world)
	for i in range(500):
		near_cover.update_focus(camera.global_position,1.0)
		await process_frame
		if near_cover.pending.is_empty(): break
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/forest_natural_preview.png")
	var nearest := Vector3.ZERO
	var nearest_distance := INF
	var plant_count := 0
	for batch in world.get_children():
		if not str(batch.name).begins_with("ForestUnderstory_"): continue
		for i in range(batch.multimesh.instance_count):
			var pos: Vector3 = batch.position + batch.multimesh.get_instance_transform(i).origin
			plant_count += 1
			if not world._can_place_ground_vegetation(pos) or absf(pos.y-world._get_exact_ground_y(pos.x,pos.z)-.005) > .001: errors += 1
			if pos.distance_to(camera.position) < nearest_distance:
				nearest_distance = pos.distance_to(camera.position)
				nearest = pos
	if plant_count == 0: errors += 1
	print("UNDERSTORY plants=",plant_count)
	# Asset inspection in the clearing, using the same meshes and material.
	nearest = Vector3(185,world._get_exact_ground_y(185,210),210)
	for variant in range(3):
		var plant := MeshInstance3D.new()
		plant.mesh = preload("res://scripts/ForestUnderstory.gd").bramble_mesh() if variant == 2 else preload("res://scripts/ForestUnderstory.gd").mesh_for(variant == 1)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/forest_understory.gdshader")
		plant.material_override = mat
		plant.position = nearest + Vector3((float(variant)-1.0)*1.0,0,0)
		plant.position.y = world._get_exact_ground_y(plant.position.x,plant.position.z)+.005
		world.add_child(plant)
	var wood := MeshInstance3D.new()
	wood.mesh = preload("res://scripts/ForestDeadwood.gd").mesh()
	wood.position = nearest + Vector3(0,.03,.7)
	world.add_child(wood)
	camera.position = nearest + Vector3(0,1.7,3.1)
	camera.look_at(nearest+Vector3.UP*.2)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/forest_understory_detail.png")
	print("FOREST_NATURAL errors=",errors," trees=",trees.size()," tufts=",tufts," rocks=",rocks," rock_variants=",variants.size()," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	world.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
