extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_d): pass
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(800,800)
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Pantalones")
	actor.is_puppet = false
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.13,.16,.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .7
	root.add_child(env)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	camera.position = Vector3(3,2.6,-4)
	camera.look_at(Vector3(0,1.3,0))
	camera.make_current()
	var ap := actor.third_person_animation_player
	var skel := actor._find_skeleton(actor.third_person_model)
	var head := actor.third_person_model.find_child("HeadMesh",true,false) as MeshInstance3D
	var head_idx := skel.find_bone("mixamorig_Head")
	ap.play(actor.third_person_idle_animation,0)
	ap.advance(.4)
	ap.pause()
	var center := skel.global_transform * skel.get_bone_global_pose(head_idx).origin + Vector3(0,.11,0)
	camera.size = .62
	camera.position = center+Vector3(.35,.08,-1)
	camera.look_at(center)
	print("HEAD BOUNDS ",head.get_aabb())
	for style in ["crop","short","medium","long"]:
		for stage in [0,1,2,3,4]:
			preload("res://scripts/CharacterGrooming.gd").apply(actor.third_person_model,style,Color(.18,.10,.045),stage)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/tmp/groom_%s_%d.png"%[style,stage])
	actor.queue_free()
	await process_frame
	quit()
