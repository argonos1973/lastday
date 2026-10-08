extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene := Node3D.new()
	root.add_child(scene)
	var bed := preload("res://scripts/WorldAction.gd").new()
	scene.add_child(bed)
	bed.setup("preview_bed", "farm_plot", "Huerto", Vector3(1.9, 0.16, 1.9), Color.BROWN, true, false)
	bed.set_crop_state("ready", 450.0)
	var rotten := preload("res://scripts/WorldAction.gd").new()
	scene.add_child(rotten)
	rotten.setup("preview_rotten", "farm_plot", "Huerto", Vector3(1.9, 0.16, 1.9), Color.BROWN, true, false)
	rotten.position = Vector3(2.6, 0, 0)
	rotten.set_crop_state("rotten", 0.0)
	var bag: Node3D = load("res://assets/models/props/farming/farm_seed_pouch.glb").instantiate()
	scene.add_child(bag)
	bag.position = Vector3(.9,0,.5)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(200,200)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.12,.15,.08)
	ground.material_override = material
	ground.position.y = -.015
	scene.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.18,.21,.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .5
	scene.add_child(env)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.position = Vector3(1.3,1.9,3.1)
	cam.look_at(Vector3(1.3,.2,0))
	cam.fov = 42
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/farming/cultivo_godot.png")
	scene.free()
	quit()
