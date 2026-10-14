extends SceneTree
## Visual review of the animal-pelt clothing set: one actor per species wearing
## jacket + pelt boots + animal-head tocado, plus a sixth with the fur gorro.
## The species is passed to equip_clothing like the game does via pelt_species.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
func _initialize(): call_deferred("run")
func run():
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1600,1000)
	var species_list := ["lobo", "ciervo", "zorro", "oso", "ave"]
	var head_items := ["Tocado de piel animal","Tocado de piel animal","Tocado de piel animal","Tocado de piel animal","Gorro de piel"]
	var actors: Array = []
	for i in species_list.size():
		var sp: String = species_list[i]
		var actor := Actor.new()
		stage.add_child(actor)
		actor.position.x = (i-2)*1.35
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.inventory = preload("res://scripts/Inventory.gd").new()
		actor.add_child(actor.inventory)
		actor.setup_as_puppet()
		for item in ["Chaqueta de piel", "Pantalones", "Botas de piel", head_items[i]]:
			actor.equip_clothing(item, Color(0,0,0,0), null, sp)
		var anims := [actor.third_person_idle_animation, actor.third_person_walk_animation, actor._rifle_aim_idle_animation]
		actor.third_person_animation_player.play(anims[i % 3], 0.0)
		actor.third_person_animation_player.advance(.4)
		actor.third_person_animation_player.pause()
		actors.append(actor)
	# _process is a no-op here, so refresh the head-bone-followed worn items
	# once after posing — matches what the live game does every frame. The
	# skeleton needs a frame before get_bone_global_pose reflects the pose.
	await create_timer(0.2).timeout
	for actor in actors:
		actor._update_head_worn_items()
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.18,.21,.24)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_energy=1.2
	stage.add_child(sun)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=4.6
	for view in ["front","back"]:
		cam.position = Vector3(0,2.1,-7.5) if view=="front" else Vector3(0,2.1,7.5)
		cam.look_at(Vector3(0,1.1,0))
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pelt_clothes_"+view+".png")
	cam.size=2.6
	for view in ["face_front","face_back"]:
		cam.position = Vector3(0,3.3,-5.5) if view=="face_front" else Vector3(0,3.3,5.5)
		cam.look_at(Vector3(0,3.15,0))
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pelt_clothes_"+view+".png")
	# Individual closeups reveal face clearance and the rear drape.
	cam.size = 1.3
	for i in [0, 3]:
		var actor = actors[i]
		for other in actors: other.visible = other == actor
		var focus := Vector3(actor.position.x, 2.85, 0)
		for view in ["front", "side", "back"]:
			var offset := Vector3(0, 0.05, -5) if view == "front" else (Vector3(5, 0.05, 0) if view == "side" else Vector3(0, 0.05, 5))
			cam.position = focus + offset
			cam.look_at(focus)
			await create_timer(.25).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pelt_" + species_list[i] + "_" + view + ".png")
	for actor in actors: actor.stats.free()
	stage.free()
	quit()
