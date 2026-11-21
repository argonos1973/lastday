extends SceneTree
# Isolated rendered preview/check. -- --rifle or --sniper samples a picked-up
# gun; --check-only validates its GPU hand contact without writing PNG frames.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
func _initialize(): call_deferred("run")
func run():
	var args := OS.get_cmdline_user_args()
	var gun := "--rifle" in args or "--sniper" in args
	var capture := not "--check-only" in args
	var errors := 0
	var worst_grip := 0.0
	root.size = Vector2i(960, 720)
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var actor := Actor.new()
	world.add_child(actor)
	actor.stats = SurvivalStats.new()
	actor.add_child(actor.stats)
	actor.stats.set_process(false)
	actor.setup_as_puppet()
	var clothing := "Camiseta,Pantalones cargo con rodilleras,Botas militares"
	actor.puppet_apply_visuals(clothing, "", "")
	var item_name: String = (actor.RIFLE_NAME if "--sniper" in args else actor.M4_NAME) if gun else "Seta amanita"
	var item_type := "weapon_rifle" if gun else "food"
	var ap: AnimationPlayer = actor.third_person_animation_player
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#17212b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#eef4ff")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#364651")
	material.roughness = 0.95
	floor_mesh.material_override = material
	floor_mesh.position.y = -0.025
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.3
	world.add_child(camera)
	camera.position = Vector3(3.2, 2.2, -4.4)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.make_current()
	if gun:
		world._spawn_ground_pickup(item_name, item_type, Vector3(0.03,0.03,-0.76), 3.5, 1, 0.0, "preview_meal")
	else:
		world._create_mushroom_pickup("preview_meal", Vector3(0.03,0.03,-0.76))
	var directory := "res://build/tmp/ground_pickup_preview" + ("_sniper" if "--sniper" in args else "_m4" if gun else "")
	if capture:
		DirAccess.make_dir_recursive_absolute(directory)
	var skeleton: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	var hand_index: int = skeleton.find_bone(actor._resolve_mixamo_bone_name(skeleton, "mixamorig:RightHand"))
	var lowest := Vector3.INF
	var lowest_t := 0.0
	var mesh: MeshInstance3D = actor._find_mesh_in_third_person("Desnudo_hands")
	var skin := skeleton.register_skin(mesh.skin)
	var middle := skeleton.find_bone(actor._resolve_mixamo_bone_name(skeleton, "mixamorig:RightHandMiddle1"))
	var middle_bind := -1
	for bind in mesh.skin.get_bind_count():
		if mesh.skin.get_bind_name(bind) == skeleton.get_bone_name(middle):
			middle_bind = bind
	var end_time: float = actor.GroundGesture.DURATION + (0.0 if gun else 1.2)
	for frame in 123:
		var t := frame / 30.0
		var phase := "pickup" if t < actor.GroundGesture.DURATION else "eat"
		var phase_time := t if phase == "pickup" else t - actor.GroundGesture.DURATION
		if t < end_time:
			actor.puppet_apply(Vector3.ZERO, 0.0, actor.GroundGesture.packet(phase, "preview_meal", item_name, item_type, phase_time))
			actor._ground_gesture.elapsed = phase_time
			actor._ground_gesture.tick(0.0)
		else:
			if not world.world_actions_by_id["preview_meal"].depleted:
				world._hide_action_visual(world.world_actions_by_id["preview_meal"])
				world.world_actions_by_id["preview_meal"].mark_depleted()
				if gun:
					actor.puppet_apply_visuals(clothing, item_name, "")
					actor.puppet_set_rifle(true)
			actor.puppet_apply(Vector3.ZERO, 0.0, "idle")
		# Freeze individual poses after removing the network crossfade; a paused
		# AnimationPlayer otherwise keeps the previous pose at zero blend weight.
		ap.play(ap.current_animation, 0.0)
		ap.speed_scale = 0.0
		if t < end_time:
			ap.seek(phase_time, true)
			ap.advance(0.0)
		actor._update_puppet_ground_alignment(1.0)
		await process_frame
		actor._update_puppet_ground_alignment(1.0)
		await RenderingServer.frame_post_draw
		if gun and t >= actor.GroundGesture.GRAB_TIME and t < end_time:
			var rig: Dictionary = actor._grip_rig_for(skeleton, hand_index, false)
			var pose := RenderingServer.skeleton_bone_get_transform(skin.get_skeleton(), middle_bind) \
				* mesh.skin.get_bind_pose(middle_bind).affine_inverse()
			var contact: Vector3 = skeleton.global_transform * pose * rig["middle_pivot"]
			var gap := contact.distance_to(actor._rifle_weapon_offset.global_transform * actor._rg_right_knuckle)
			var animated_contact: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(middle) * rig["middle_pivot"]
			if contact.distance_to(animated_contact) > 0.03:
				errors += 1
				push_error("Pickup must preserve the reaching arm instead of pulling it back to aim")
			worst_grip = maxf(worst_grip, gap)
			if gap > 0.015 or not actor._rifle_root.is_visible_in_tree():
				errors += 1
				push_error("Pickup GPU grip %.4fm at %.2fs" % [gap, t])
		if frame % 30 == 0:
			print("PREVIEW_FRAME ", frame, " anim=", ap.current_animation, " time=", ap.current_animation_position, " timer=", actor.third_person_action_timer)
		var hand := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
		if phase == "pickup" and hand.y < lowest.y:
			lowest = hand
			lowest_t = t
		if capture:
			root.get_texture().get_image().save_png("%s/%03d.png" % [directory, frame])
	if actor._rifle_ammo_initialized or actor._m4_ammo_initialized:
		errors += 1
		push_error("Cosmetic pickup must not initialize ammunition")
	print("GROUND_PICKUP_CAPTURE min_hand=", lowest, " time=", lowest_t, " GPU_GRIP=", worst_grip, " errors=", errors)
	world.free()
	await process_frame
	quit(1 if errors else 0)
