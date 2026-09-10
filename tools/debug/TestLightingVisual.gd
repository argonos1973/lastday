extends "res://scripts/Main.gd"
func _process(_delta: float) -> void: pass
func _ready() -> void:
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 15.0
	day_cycle._update_lighting()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.23, 0.3, 0.13)
	ground.material_override = mat
	add_child(ground)
	for i in range(7):
		var tree = load("res://assets/external/kenney_survival_kit/Models/GLB format/tree.glb").instantiate()
		add_child(tree)
		tree.position = Vector3(-9 + i * 3, 0, -9)
		tree.scale = Vector3.ONE * (3.0 + i * 0.2)
	var lake := preload("res://scripts/RiverWater.gd").new()
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(20, 16)
	lake.mesh = water_plane
	lake.material_override = MaterialFactory.make_river_water_material()
	lake.set_is_lake(true)
	lake.position.y = 0.1
	add_child(lake)
	_create_campfire_fire(Vector3(6, 0.3, 7), "TestFire")
	_create_torch_fire("TestTorch", Vector3(-6, 1.0, 7), 100.0)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 3, 14)
	camera.look_at(Vector3(0, 1, -3))
	camera.current = true
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/Users/sami/Documents/Codex/2026-09-09/re/outputs/luz/dia.png")
	day_cycle.time_of_day = 22.0
	day_cycle._update_lighting()
	lake.set_night_amount(1.0)
	lake._reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/Users/sami/Documents/Codex/2026-09-09/re/outputs/luz/noche.png")
	print("LIGHTING VISUAL: complete")
	get_tree().quit()
