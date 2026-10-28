extends SceneTree
# Sample camera aiming without ADS while turning; both skinned knuckles must
# stay on the weapon contacts. Uses an isolated actor without world/saves.

const ItemData = preload("res://scripts/Item.gd")

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var aiming := false
	var use_m4 := true
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	if use_m4 and not aiming:
		actor.equip_clothing("Chaqueta militar digital")
		actor.equip_clothing("Chaleco táctico")
		actor.equip_clothing("Pantalones cargo con rodilleras")
		actor.equip_clothing("Guantes militares")
	else:
		actor.equip_clothing("Camiseta")
	var w_name: String = actor.M4_NAME if use_m4 else "Rifle francotirador"
	actor._puppet_held = w_name
	actor._update_puppet_held_item(w_name)
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
		else:
			actor._on_skeleton_updated()
		skel.force_update_all_bone_transforms()
	# Settle the sling too — with the rifle held it drapes from the gun back to
	# the body guides and must be updated to render its true shape.
	for i in 8:
		actor._update_rifle_strap(1.0 / 30.0)
		await process_frame
	await process_frame
	var errors := 0
	var worst := 0.0
	player.play(anim, 0.0)
	var length := player.get_animation(anim).length
	for frame in 90:
		player.advance(length / 90.0)
		actor.rotation.y = frame * 0.07
		actor._pitch = deg_to_rad(55.0 * sin(frame * TAU / 90.0))
		actor._update_rifle_ik(skel, 1.0 / 30.0)
		actor._on_skeleton_updated()
		skel.force_update_all_bone_transforms()
		for side in ["Right", "Left"]:
			var idx := skel.find_bone("mixamorig_" + side + "HandMiddle1")
			var rig := actor._grip_rig_for(skel, skel.get_bone_parent(idx), side == "Left")
			var actual: Vector3 = skel.global_transform * skel.get_bone_global_pose(idx) * rig["middle_pivot"]
			var marker: Vector3 = actor._rg_right_knuckle if side == "Right" else actor._rg_left_knuckle
			var gap := actual.distance_to(actor._rifle_weapon_offset.global_transform * marker)
			worst = maxf(worst, gap)
			if gap > 0.015:
				errors += 1
				push_error("%s idle grip frame %d gap %.4f" % [side, frame, gap])
		var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
		var sight := (-actor.global_basis.z).rotated(actor.global_basis.x, actor._pitch).normalized()
		if not barrel.is_finite() or barrel.dot(sight) < 0.999:
			errors += 1
			push_error("M4 must follow camera direction without ADS")
		var sh := skel.find_bone("mixamorig_RightShoulder")
		var shoulder: Vector3 = skel.global_transform * skel.get_bone_global_pose(sh).origin
		var up := (-sight).cross(actor.global_basis.x).normalized()
		var pocket := shoulder + actor.global_basis.x * 0.02 - up * 0.08 - sight * 0.04
		if actor._rifle_stock_ref.global_position.distance_to(pocket) > 0.002:
			errors += 1
			push_error("M4 stock detached from shoulder")
		if actor._is_aiming:
			errors += 1
			push_error("Camera posture must not enable ADS")
	actor.queue_free()
	await process_frame
	print("M4_IDLE_GRIP errors=%d worst_gap=%.6fm" % [errors, worst])
	quit(1 if errors else 0)
