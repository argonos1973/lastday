extends "res://tools/debug/RecentGearRegression.gd"
# Real skeletal poses at several phases, plus front/side visual evidence.
func run():
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	for clothing in ["Camiseta","Pantalones","Zapatillas","Chaqueta de cuadros"]: actor.equip_clothing(clothing)
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	var garment: MeshInstance3D = actor._survival_cloth_nodes["field_jacket_plaid"]
	var player: AnimationPlayer = actor.third_person_animation_player
	var preview := "--preview" in OS.get_cmdline_user_args()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=1.7
	if preview:
		root.size=Vector2i(1000,800)
		root.content_scale_size=Vector2i(1000,800)
		var env := WorldEnvironment.new()
		env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.13,.16,.19);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65
		root.add_child(env)
		var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);root.add_child(sun)
	var poses := {"reposo":actor.third_person_idle_animation,"caminar":actor.third_person_walk_animation,"correr":actor.third_person_run_animation,"agachado":actor.third_person_sneak_animation,"sentado":actor.third_person_sit_animation,"apuntar":actor._rifle_aim_idle_animation}
	DirAccess.make_dir_recursive_absolute("res://outputs/revision_chaqueta")
	for pose in poses:
		var animation: String=poses[pose]
		check(player.has_animation(animation),pose+" animation available")
		if not player.has_animation(animation):continue
		if pose=="apuntar":
			actor._update_puppet_held_item("Rifle francotirador")
			actor._is_aiming=true
		player.play(animation,0.0)
		for phase in [.15,.45,.75]:
			player.seek(player.get_animation(animation).length*phase,true)
			player.advance(0)
			skel.force_update_all_bone_transforms()
			if pose=="apuntar":
				actor._update_rifle_ik(skel,.016)
				actor._on_skeleton_updated()
			actor._update_backpack_socket()
			var bounds:=posed_bounds(garment,skel)
			check(bounds.size.length()<2.8,pose+" preserves jacket dimensions at "+str(phase))
			var torso: Vector3=(skel.global_transform*skel.get_bone_global_pose(skel.find_bone("mixamorig_Spine1"))).origin
			check(bounds.get_center().distance_to(torso)<.45,pose+" follows torso at "+str(phase))
		player.pause()
		actor._update_backpack_socket()
		if preview:
			var center:=posed_bounds(garment,skel).get_center()
			for view in ["frente","lado","espalda"]:
				cam.position=center+(Vector3(.3,.12,-4) if view=="frente" else Vector3(4,.12,-.25))
				if view=="espalda": cam.position=center+Vector3(-.3,.12,4)
				cam.look_at(center)
				await create_timer(.15).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://outputs/revision_chaqueta/"+pose+"_"+view+".png")
	actor.stats.free()
	actor.free()
	print("JACKET_ANIMATION_ERRORS=",errors)
	quit(1 if errors else 0)
