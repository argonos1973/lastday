extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2, 2, 4)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-50, -30, 0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	world.add_child(floor_mesh)
	floor_mesh.scale = Vector3(5, 1, 5)
	var bird := preload("res://scripts/BirdController.gd").new()
	world.add_child(bird)
	bird.position = Vector3(-0.6, 0.8, 0)
	bird.set_process(false)
	var fallen := preload("res://scripts/BirdController.gd").new()
	world.add_child(fallen)
	fallen.position = Vector3(0.6, 0.2, 0)
	fallen.take_damage(200, false)
	fallen._land_corpse()
	fallen.set_process(false)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/Users/sami/Documents/Codex/2026-09-09/re/outputs/caza/aves.png")
	world.queue_free()
	await process_frame
	quit()
