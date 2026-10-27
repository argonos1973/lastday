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
	for entry in [["bow","Arco reforzado","weapon_bow"],["spear","Lanza","tool_spear"]]:
		var item = preload("res://scripts/Item.gd").create(entry[1],entry[2],1,1,0)
		actor._held_item_reference = item
		actor._held_item_external = true
		actor._puppet_held = entry[1]
		actor._sync_third_person_equipment(item)
		actor._fit_held_prop_to_palm(item)
		actor._is_aiming = false
		for mode in ["carry","walk"]:
			var clip: String = actor.third_person_walk_animation if mode == "walk" else actor.third_person_idle_animation
			print(entry[0], " ", mode, " clip=",clip)
			ap.play(clip,0)
			ap.pause()
			var folder := "res://build/tmp/%s_%s_frames" % [entry[0],mode]
			DirAccess.make_dir_recursive_absolute(folder)
			for frame in 24:
				ap.seek(frame * ap.get_animation(clip).length/24.0, true)
				ap.advance(0.0)
				skel.force_update_all_bone_transforms()
				actor._update_hand_socket()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder+"/%03d.png"%frame)
	actor.queue_free()
	await process_frame
	print("PRIMITIVE_CARRY_PREVIEW_DONE")
	quit()
