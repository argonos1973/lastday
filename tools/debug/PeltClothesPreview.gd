extends SceneTree
## Visual review of the animal-pelt clothing set (head slot shown with both
## its variants: fur cap vs animal-pelt headdress).
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
func _initialize(): call_deferred("run")
func run():
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1500,1000)
	var outfits := [
		["Chaqueta de piel", "Pantalones", "Botas de piel", "Gorro de piel"],
		["Chaqueta de piel", "Pantalones", "Botas de piel", "Tocado de piel animal"],
		["Chaqueta de piel", "Pantalones", "Botas de piel", "Gorro de piel"],
	]
	var actors: Array = []
	for i in 3:
		var actor := Actor.new()
		stage.add_child(actor)
		actor.position.x = (i-1)*1.5
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.inventory = preload("res://scripts/Inventory.gd").new()
		actor.add_child(actor.inventory)
		actor.setup_as_puppet()
		for item in outfits[i]:
			actor.equip_clothing(item)
		var anim: String = [actor.third_person_idle_animation, actor.third_person_walk_animation, actor._rifle_aim_idle_animation][i]
		actor.third_person_animation_player.play(anim, 0.0)
		actor.third_person_animation_player.advance(.4)
		actor.third_person_animation_player.pause()
		actors.append(actor)
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
	cam.size=5.0
	for view in ["front","back"]:
		cam.position = Vector3(0,2.1,-7) if view=="front" else Vector3(0,2.1,7)
		cam.look_at(Vector3(0,1.1,0))
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pelt_clothes_"+view+".png")
	cam.size=2.2
	for view in ["face_front","face_back"]:
		cam.position = Vector3(0,1.75,-4) if view=="face_front" else Vector3(0,1.75,4)
		cam.look_at(Vector3(0,1.62,0))
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pelt_clothes_"+view+".png")
	for actor in actors: actor.stats.free()
	stage.free()
	quit()
