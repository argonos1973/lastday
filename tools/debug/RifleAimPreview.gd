extends SceneTree
# Non-headless capture of the third-person rifle pose with the real
# animations (what other players see; the local view switches to the scope):
#   Godot --path . --script tools/debug/RifleAimPreview.gd [-- --idle]
# Writes /tmp/rifle_aim_{front,side,back,three_quarter,over_shoulder}.png

const ItemData = preload("res://scripts/Item.gd")

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var aiming := not ("--idle" in OS.get_cmdline_user_args())
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	actor.equip_clothing("Camiseta")
	actor._update_puppet_held_item("Rifle francotirador")
	actor._rifle_in_hands = true
	actor._has_rifle = true
	actor._is_aiming = aiming
	var player: AnimationPlayer = actor.third_person_animation_player
	var anim: String = actor._rifle_aim_idle_animation if aiming else actor._rifle_idle_animation
	if "--walk" in OS.get_cmdline_user_args():
		anim = actor._rifle_walk_animation
	if "--turn-left" in OS.get_cmdline_user_args():
		anim = actor._rifle_left_turn_animation
	if "--turn-right" in OS.get_cmdline_user_args():
		anim = actor._rifle_right_turn_animation
	print("ANIM=", anim, " has=", player != null and player.has_animation(anim))
	if player != null and player.has_animation(anim):
		player.play(anim, 0.0)
		player.advance(0.4)
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	for i in 10:
		player.advance(0.016)
		skel.force_update_all_bone_transforms()
		actor._update_rifle_ik(skel, 1.0 / 60.0)
		await process_frame
	# Freeze the animation and converge manually so the measurements reflect the
	# steady pose, not per-frame anim drift. _solve_aim_arms only runs when
	# aiming — calling it in idle drags the hands to the aim markers.
	player.pause()
	for i in 6:
		actor._update_rifle_ik(skel, 1.0 / 60.0)
		skel.force_update_all_bone_transforms()
		if aiming:
			actor._solve_aim_arms()
		skel.force_update_all_bone_transforms()
	await process_frame
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -20, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.14, 0.16, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	root.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	root.add_child(camera)
	var sh_center := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Neck"))).origin
	var center := sh_center + (actor.global_basis * Vector3.FORWARD) * 0.25 - Vector3.UP * 0.12
	var front := (actor.global_basis * Vector3.FORWARD).normalized()
	var right := front.cross(Vector3.UP).normalized()
	var views := {
		"front": front * 3.0 + Vector3.UP * 0.1,
		"side": right * 3.0,
		"left": -right * 3.0,
		"top": Vector3.UP * 3.0 + front * 0.01,
		"three_quarter": (front + right).normalized() * 3.0 + Vector3.UP * 0.3,
		"over_shoulder": -front * 3.0 + right * 1.2 + Vector3.UP * 0.6,
	}
	var muzzle: Vector3 = actor._rifle_muzzle.global_position
	var stock: Vector3 = actor._rifle_stock_ref.global_position
	var barrel := (muzzle - stock).normalized()
	print("barrel_dir=", barrel, " forward_dot=%.3f up=%.3f right=%.3f" % [barrel.dot(front), barrel.y, barrel.dot(right)])
	var sh_idx := skel.find_bone("mixamorig_RightShoulder")
	var head_idx := skel.find_bone("mixamorig_Head")
	var sh := (skel.global_transform * skel.get_bone_global_pose(sh_idx)).origin
	var head := (skel.global_transform * skel.get_bone_global_pose(head_idx)).origin
	print("stock_to_shoulder=%.3f stock=%s shoulder=%s head=%s" % [stock.distance_to(sh), stock, sh, head])
	# Post-IK fit: wrist bones vs their rifle targets, and where the butt lands
	var wo_xf := actor._rifle_weapon_offset.global_transform
	var rh_idx2 := skel.find_bone("mixamorig_RightHandMiddle1")
	var lh_idx2 := skel.find_bone("mixamorig_LeftHandMiddle1")
	var right_rig := actor._grip_rig_for(skel, skel.get_bone_parent(rh_idx2), false)
	var left_rig := actor._grip_rig_for(skel, skel.get_bone_parent(lh_idx2), true)
	var rh_w: Vector3 = skel.global_transform * skel.get_bone_global_pose(rh_idx2) * right_rig["middle_pivot"]
	var lh_w: Vector3 = skel.global_transform * skel.get_bone_global_pose(lh_idx2) * left_rig["middle_pivot"]
	print("right_knuckle_err=%.3f left_knuckle_err=%.3f" % [
		rh_w.distance_to(wo_xf * actor.RIFLE_AIM_RIGHT_KNUCKLE),
		lh_w.distance_to(wo_xf * actor.RIFLE_AIM_LEFT_KNUCKLE)])
	# Manual re-solve to check the IK converges when run back-to-back
	if aiming:
		for i in 3:
			actor._solve_aim_arms()
		var rh_w2: Vector3 = skel.global_transform * skel.get_bone_global_pose(rh_idx2) * right_rig["middle_pivot"]
		var lh_w2: Vector3 = skel.global_transform * skel.get_bone_global_pose(lh_idx2) * left_rig["middle_pivot"]
		print("after_manual: right_err=%.3f left_err=%.3f" % [
			rh_w2.distance_to(wo_xf * actor.RIFLE_AIM_RIGHT_KNUCKLE),
			lh_w2.distance_to(wo_xf * actor.RIFLE_AIM_LEFT_KNUCKLE)])
	print("ik_idx: lh=%d ua=%d fa=%d rh=%d rua=%d rfa=%d" % [
		actor._ik_lh_idx, actor._ik_upper_arm_idx, actor._ik_forearm_idx,
		actor._ik_rh_idx, actor._ik_right_upper_arm_idx, actor._ik_right_forearm_idx])
	var butt_w := wo_xf * actor.RIFLE_AIM_BUTT
	var eye_w := wo_xf * actor.RIFLE_AIM_EYE
	print("butt=%s eye_marker=%s aim_pose=%s" % [butt_w, eye_w, actor._rifle_aim_pose_active])
	if aiming:
		# Scope view: what the local player sees — the body model is hidden while
		# aiming, only the rifle (reparented out) renders in front of the eye
		var sight := -actor.global_basis.z.normalized()
		actor.third_person_model.visible = false
		# Hide scope glass: the lens mesh is opaque — through the open tube the
		# world shows like a real scope view
		var hidden_glass: Array = []
		var st: Array = [actor._rifle_model]
		while not st.is_empty():
			var n: Node = st.pop_back()
			for c in n.get_children():
				st.append(c)
			if n is MeshInstance3D and (n.name.find("Glass") >= 0 or n.name.find("Bubble") >= 0):
				n.visible = false
				hidden_glass.append(n)
		var scope_cam := Camera3D.new()
		scope_cam.fov = 25.0
		scope_cam.near = 0.02
		root.add_child(scope_cam)
		scope_cam.global_position = eye_w - sight * 0.22
		scope_cam.look_at(eye_w + sight * 3.0)
		camera.current = false
		scope_cam.current = true
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rifle_aim_scope.png")
		actor.third_person_model.visible = true
		scope_cam.current = false
		camera.current = true
		scope_cam.queue_free()
	for view in views:
		camera.position = center + views[view]
		camera.look_at(center)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rifle_aim_%s%s.png" % [view, "" if aiming else "_idle"])
	# Close-up of the left hand on the handguard
	var lh2 := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_LeftHand"))).origin
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	camera.position = lh2 + right * 0.55 + Vector3.UP * 0.15 + front * 0.25
	camera.look_at(lh2)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rifle_aim_leftclose%s.png" % ("" if aiming else "_idle"))
	# Close-up of the right hand on the grip
	var rh2 := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand"))).origin
	camera.position = rh2 + right * 0.55 + Vector3.UP * 0.2 - front * 0.15
	camera.look_at(rh2)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rifle_aim_rightclose%s.png" % ("" if aiming else "_idle"))
	print("RIFLE_AIM_PREVIEW_DONE")
	actor.stats.free()
	actor.free()
	quit(0)
