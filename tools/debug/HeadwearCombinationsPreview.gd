extends SceneTree
## Real equipped character, isolated from world generation and saves.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
func _initialize(): call_deferred("run")
func run():
	var stage := Node3D.new()
	root.add_child(stage); current_scene=stage
	root.size=Vector2i(1200,900)
	var actor:=Actor.new(); stage.add_child(actor)
	actor.stats=preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory=preload("res://scripts/Inventory.gd").new();actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	for item in ["Chaqueta militar digital", "Pantalones cargo con rodilleras", "Botas de montaña", "Pasamontañas"]:
		actor.equip_clothing(item)
	actor.third_person_animation_player.play(actor.third_person_idle_animation,0.0)
	actor.third_person_animation_player.advance(.4)
	actor.third_person_animation_player.pause()
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.18,.21,.24)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.65
	stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;stage.add_child(sun)
	var cam:=Camera3D.new();stage.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=.82
	var sk:Skeleton3D=actor._head_skeleton
	var focus:Vector3=sk.global_transform*sk.get_bone_global_pose(actor._head_bone_idx).origin
	focus.y-=.05
	var names:=["Casco militar", "Sombrero de pescador", "Gorra militar"]
	var files:=["casco", "sombrero", "gorra"]
	DirAccess.make_dir_recursive_absolute("/tmp/headwear_previews")
	for i in names.size():
		actor.equip_clothing(names[i])
		actor._update_head_worn_items()
		for view in ["front", "side"]:
			cam.position=focus+(Vector3(.6,.10,-4) if view=="front" else Vector3(3,.10,-2.5))
			cam.look_at(focus)
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/headwear_previews/%s_%s.png" % [files[i],view])
		actor.unequip_clothing(names[i])
	actor.stats.free();stage.free();quit()
