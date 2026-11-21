extends SceneTree
# Isolated real-character/animation check; never generates a world or saves.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func process_remote(delta: float): super._process(delta)
	func _physics_process(_delta): pass
	func _create_scope_overlay(): pass
	func _has_rifle_equipped() -> bool: return true
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func hand_contact(actor, skeleton: Skeleton3D, side: String) -> Vector3:
	var middle := skeleton.find_bone("mixamorig_" + side + "HandMiddle1")
	var rig: Dictionary = actor._grip_rig_for(skeleton, skeleton.get_bone_parent(middle), side == "Left")
	return skeleton.global_transform * skeleton.get_bone_global_pose(middle) * (rig["middle_pivot"] as Vector3)
func check_contacts(actor, skeleton: Skeleton3D, label: String) -> void:
	for side in ["Right", "Left"]:
		var marker: Vector3 = actor._rg_right_knuckle if side == "Right" else actor._rg_left_knuckle
		check(hand_contact(actor, skeleton, side).distance_to(actor._rifle_weapon_offset.global_transform * marker) < 0.015,
			label + "/" + side)
func check_pivots(actor, skeleton: Skeleton3D) -> void:
	for rig in actor._grip_rig.values():
		for entry in rig["fingers"]:
			var rest := skeleton.get_bone_rest(entry[0])
			var pose := skeleton.get_bone_pose(entry[0])
			var expected := rest.origin + rest.basis * (entry[4] as Vector3) - pose.basis * (entry[4] as Vector3)
			check(pose.origin.distance_to(expected) < 0.001, "Held finger pivots stay compensated without accumulation")
func _initialize(): call_deferred("run")
func run():
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	# Exercise the real remote update before any direct IK calls. Otherwise a
	# test can register the skeleton callback that gameplay forgot to install.
	actor.puppet_apply_visuals("", "Rifle francotirador", "")
	var remote_skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	for aiming in [false, true, false]:
		actor.puppet_set_aiming(aiming)
		var clip: String = actor._rifle_aim_idle_animation if aiming else actor._rifle_idle_animation
		for frame in 12:
			actor.puppet_apply(Vector3(15, 0, 20), frame * 0.15, clip)
			actor.third_person_animation_player.advance(1.0 / 30.0)
			actor.process_remote(1.0 / 30.0)
			remote_skel.force_update_all_bone_transforms()
			check(actor._ik_skeleton_connected, "Remote process installs post-animation rifle alignment")
			check(actor._rifle_aim_pose_active == aiming, "Remote process follows synced aim state")
			if not aiming:
				for side in ["Right", "Left"]:
					var middle := remote_skel.find_bone("mixamorig_" + side + "HandMiddle1")
					var rig := actor._grip_rig_for(remote_skel, remote_skel.get_bone_parent(middle), side == "Left")
					var contact: Vector3 = remote_skel.global_transform * remote_skel.get_bone_global_pose(middle) * rig["middle_pivot"]
					var marker: Vector3 = actor._rg_right_knuckle if side == "Right" else actor._rg_left_knuckle
					check(contact.distance_to(actor._rifle_weapon_offset.global_transform * marker) < 0.015,
						"Remote idle sniper keeps real " + side + " hand contact")
			check(actor._rifle_strap_system != null, "Remote process updates the worn sling")
	actor.puppet_apply_visuals("", "Cuchillo", "")
	actor.process_remote(1.0 / 30.0)
	check(not is_instance_valid(actor._rifle_weapon_offset), "Remote item swap clears held rifle")
	actor.puppet_apply_visuals("", "Rifle francotirador", "")
	actor.process_remote(1.0 / 30.0)
	check(actor._ik_skeleton_connected, "Remote re-equip restores rifle alignment")
	# Ground pickup leaves the supporting arm free and pins only the firing
	# hand to the actual grip, without initializing ammo or giving an item.
	actor.puppet_apply(actor.global_position, actor.rotation.y,
		actor.GroundGesture.packet("pickup", "cancel_gun", actor.M4_NAME, "weapon_rifle"))
	check(not actor.third_person_hand_item_root.visible, "pickup prop stays hidden before contact")
	actor.puppet_apply(actor.global_position, actor.rotation.y, "idle")
	check(actor.third_person_hand_item_root.visible and actor._rifle_root.visible,
		"early cancellation restores the original equipment visibility")
	for weapon_name in [actor.RIFLE_NAME, actor.M4_NAME]:
		actor.puppet_apply(actor.global_position, actor.rotation.y,
			actor.GroundGesture.packet("pickup", "floor_gun", weapon_name, "weapon_rifle"))
		var pickup_player: AnimationPlayer = actor.third_person_animation_player
		for time in [0.0, 0.35, 0.7, 1.05, 1.37]:
			actor._ground_gesture.elapsed = time
			actor._ground_gesture.tick(0.0)
			pickup_player.play(actor._motion("pickup_ground"), 0.0)
			pickup_player.seek(time, true)
			pickup_player.speed_scale = 0.0
			pickup_player.advance(0.0)
			for frame in 3:
				actor.process_remote(1.0 / 30.0)
				await process_frame
			check(hand_contact(actor, remote_skel, "Right").distance_to(
				actor._rifle_weapon_offset.global_transform * actor._rg_right_knuckle) < 0.015,
				weapon_name + " pickup keeps the real right hand on its grip at %.2f" % time)
		actor.puppet_apply(actor.global_position, actor.rotation.y, "idle")
		pickup_player.speed_scale = 1.0
	check(actor.inventory.items.is_empty(), "temporary pickup props create no inventory")
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	actor._update_puppet_held_item("Rifle francotirador")
	actor._is_aiming = true
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	var player: AnimationPlayer = actor.third_person_animation_player
	var arms: MeshInstance3D = skel.get_node("Desnudo_arms")
	check(arms.has_meta("refined_elbows"), "Refined arm mesh is used by the real character")
	check(arms.mesh.surface_get_array_len(0) > 5000, "Refined arm topology is loaded")
	for bind in arms.skin.get_bind_count():
		check(skel.find_bone(arms.skin.get_bind_name(bind)) >= 0, "Refined arm skin binds to the character")
	var worst := 0.0
	for anim in [actor._rifle_aim_idle_animation, actor._rifle_walk_animation, actor._rifle_fire_animation]:
		check(player.has_animation(anim), "Required rifle animation: " + anim)
		player.play(anim, 0.0)
		for frame in 30:
			player.advance(1.0 / 30.0)
			actor.rotation.y = frame * 0.02
			actor._update_rifle_ik(skel, 1.0 / 30.0)
			actor._on_skeleton_updated()
			actor._update_rifle_strap(1.0 / 30.0)
			var sling = actor._rifle_strap_system
			var points: PackedVector3Array = sling._previous
			var model: Node3D = actor.third_person_model
			check(sling._route.size() == sling.BODY_POINTS, "Held sling stays worn on the body")
			check(model.to_global(points[0]).distance_to(actor._strap_barrel_marker.global_position) < 0.001, "Moving barrel swivel stays attached")
			check(model.to_global(points[-1]).distance_to(actor._strap_stock_marker.global_position) < 0.001, "Moving stock swivel stays attached")
			var spine_rest: Vector3 = (model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(skel.find_bone("mixamorig_Spine1"))).origin
			check(sling._rest_body_points[sling.BODY_POINTS / 2].z < spine_rest.z - 0.1, "Held sling crosses the back, not the chest or below the rifle")
			for side in ["Right", "Left"]:
				var idx := skel.find_bone("mixamorig_" + side + "HandMiddle1")
				var point: Vector3 = actor.RIFLE_AIM_RIGHT_KNUCKLE if side == "Right" else actor.RIFLE_AIM_LEFT_KNUCKLE
				var hand_idx := skel.get_bone_parent(idx)
				var rig := actor._grip_rig_for(skel, hand_idx, side == "Left")
				var actual: Vector3 = skel.global_transform * skel.get_bone_global_pose(idx) * rig["middle_pivot"]
				var expected: Vector3 = actor._rifle_weapon_offset.global_transform * point
				worst = maxf(worst, actual.distance_to(expected))
				check(actual.distance_to(expected) < 0.015, "%s hand contact / %s frame %d" % [side, anim, frame])
			for side in ["Left", "Right"]:
				var upper := skel.get_bone_global_pose(skel.find_bone("mixamorig_" + side + "Arm"))
				var fore := skel.get_bone_global_pose(skel.find_bone("mixamorig_" + side + "ForeArm"))
				check(upper.basis.z.normalized().dot(fore.basis.z.normalized()) > 0.99, "Elbow hinge stays aligned without forearm torsion")
			var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
			check(barrel.dot(-actor.global_basis.z) > 0.999, "Puppet barrel follows facing")
			var eye_idx := skel.find_bone("mixamorig_RightEye")
			var eye := (skel.global_transform * skel.get_bone_global_pose(eye_idx)).origin
			var ocular: Vector3 = actor._rifle_weapon_offset.global_transform * actor.RIFLE_AIM_EYE
			check(ocular.distance_to(eye - actor.global_basis.z * 0.10) < 0.002, "Ocular stays on right eye line with 10 cm clearance")
	# Local sight elevation keeps the barrel on the camera ray.
	actor.is_puppet = false
	actor.camera = Camera3D.new()
	actor.add_child(actor.camera)
	var head := skel.find_bone("mixamorig_Head")
	actor.camera.global_position = (skel.global_transform * skel.get_bone_global_pose(head)).origin + Vector3.UP * 0.11
	for pitch in [-0.4, 0.0, 0.4]:
		actor.camera.rotation.x = pitch
		actor._update_rifle_ik(skel, 0.016)
		actor._on_skeleton_updated()
		var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
		check(barrel.dot(-actor.camera.global_basis.z) > 0.999, "Local barrel follows sight elevation")
	actor._is_aiming = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	if DisplayServer.get_name() == "headless":
		actor._toggle_aim() # Headless display cannot capture a mouse.
	else:
		actor._input(rmb)
	var expected_ads_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(actor._camera_fov) * 0.5) / 4.0))
	check(actor._is_aiming and is_equal_approx(actor.camera.fov, expected_ads_fov), "Right button enters ADS through real input path")
	# RMB starts with the camera 6.5 m behind the player; its interpolation
	# must not pull the physical weapon out of the hands.
	for camera_pos in [actor.THIRD_PERSON_CAMERA_POS, Vector3(.1,2.0,3), Vector3(.12,1.65,.15)]:
		actor.camera.position = camera_pos
		actor._update_rifle_ik(skel,.016)
		actor._on_skeleton_updated()
		var eye_idx := skel.find_bone("mixamorig_RightEye")
		var eye := (skel.global_transform * skel.get_bone_global_pose(eye_idx)).origin
		var ocular: Vector3 = actor._rifle_weapon_offset.global_transform * actor.RIFLE_AIM_EYE
		check(ocular.distance_to(eye-actor.camera.global_basis.z.normalized()*.10)<.002, "ADS camera travel cannot displace rifle from eye")
	rmb.pressed = false
	if DisplayServer.get_name() == "headless":
		actor._toggle_aim()
	else:
		actor._input(rmb)
	check(not actor._is_aiming and actor.third_person_model.visible, "Releasing right button restores third person")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Leaving ADS keeps the physical grip; compensation must not accumulate.
	actor._is_aiming = false
	actor._update_rifle_ik(skel, 0.016)
	check_contacts(actor, skel, "Aim exit keeps measured contacts")
	check_pivots(actor, skel)
	actor._is_aiming = true
	actor._update_rifle_ik(skel, 0.016)
	actor._on_skeleton_updated()
	# Third-person turning must retain BOTH grip contacts after animation and
	# yaw updates, including the frame after the ADS top-level transform exits.
	actor._is_aiming = false
	for clip in [actor._rifle_idle_animation,actor._rifle_left_turn_animation,actor._rifle_right_turn_animation,actor._rifle_walk_animation]:
		check(not clip.is_empty() and actor.third_person_animation_player.has_animation(clip), "Rifle turn fixture exists")
		actor.third_person_animation_player.play(clip,0.0)
		for frame in 24:
			actor.rotation.y = frame*.08
			actor.third_person_animation_player.advance(.016)
			skel.force_update_all_bone_transforms()
			actor._on_skeleton_updated()
			check_contacts(actor, skel, "Third-person turn retains measured grip: " + clip)
	actor._is_aiming = true
	# Sitting/prone use the fallback solver: an unreachable grip must not
	# teleport the wrist beyond the physical length of the forearm.
	actor._rifle_aim_pose_active = false
	var before_fa := skel.get_bone_global_pose(actor._ik_forearm_idx).origin
	var before_hand := skel.get_bone_global_pose(actor._ik_lh_idx).origin
	var forearm_length := before_fa.distance_to(before_hand)
	actor._rifle_left_hand_grip.global_position += Vector3(10, 10, 10)
	actor._on_skeleton_updated()
	var after_fa := skel.get_bone_global_pose(actor._ik_forearm_idx).origin
	var after_hand := skel.get_bone_global_pose(actor._ik_lh_idx).origin
	check(absf(after_fa.distance_to(after_hand) - forearm_length) < 0.001, "Unreachable fallback grip cannot stretch forearm")
	# IK must remain finite when the target coincides with the shoulder and
	# both arm segments have equal lengths (law-of-cosines singularity).
	var dummy := Skeleton3D.new()
	root.add_child(dummy)
	for name in ["upper", "forearm", "hand"]: dummy.add_bone(name)
	dummy.set_bone_parent(1, 0)
	dummy.set_bone_parent(2, 1)
	for idx in [1, 2]:
		dummy.set_bone_rest(idx, Transform3D(Basis.IDENTITY, Vector3.RIGHT))
	dummy.reset_bone_poses()
	actor._solve_arm_chain(dummy, 0, 1, 2, Vector3.ZERO)
	for idx in 3:
		check(dummy.get_bone_global_pose(idx).is_finite(), "Finite coincident-target IK")
	check(absf(dummy.get_bone_global_pose(2).origin.distance_to(dummy.get_bone_global_pose(1).origin) - 1.0) < 0.001, "IK preserves forearm length")
	dummy.free()
	# Leaving aim resumes the world-space hand alignment.
	actor._is_aiming = false
	player.play(actor._rifle_idle_animation, 0.0)
	player.advance(0.1)
	actor._update_rifle_ik(skel, 0.016)
	check_contacts(actor, skel, "Un-aim preserves both real contacts")
	check(not actor._rifle_aim_pose_active, "Un-aim disables aim solver")
	check_pivots(actor, skel)
	# --- M4: the same rig path must mount the assault rifle with its own
	# geometry (180° flip, ~x55 scale, separate grip/eye points).
	actor.is_puppet = true
	actor.puppet_apply_visuals("", "Fusil de asalto", "")
	actor.process_remote(1.0 / 30.0)
	check(is_instance_valid(actor._rifle_model), "M4 model builds on the puppet")
	var m4_mesh_found := false
	var stack: Array = [actor._rifle_model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name).findn("Flash_Muzzle") >= 0 or str(n.name).findn("Butt_Stock") >= 0:
			m4_mesh_found = true
		for c in n.get_children():
			stack.append(c)
	check(m4_mesh_found, "Mounted weapon is the M4 model, not the sniper")
	check(is_instance_valid(actor._rifle_muzzle) and is_instance_valid(actor._rifle_stock_ref), "M4 keeps muzzle/stock markers")
	if is_instance_valid(actor._rifle_muzzle) and is_instance_valid(actor._rifle_stock_ref):
		var m4_len := actor._rifle_muzzle.global_position.distance_to(actor._rifle_stock_ref.global_position)
		check(m4_len > 1.0 and m4_len < 1.65, "M4 renders at character-proportioned carbine length (%.2f m)" % m4_len)
	check(actor._rg_eye.y < 0.12, "M4 geometry uses its own measured space")
	# Aiming the M4: the direct-aim solver must place the barrel forward and
	# put both hands on its own grip points (not the sniper's).
	actor._is_aiming = true
	player.play("external/RifleAimIdleExternal", 0.0)
	for frame in 30:
		player.advance(1.0 / 30.0)
		actor._update_rifle_ik(skel, 1.0 / 30.0)
		actor._on_skeleton_updated()
	if is_instance_valid(actor._rifle_muzzle) and is_instance_valid(actor._rifle_stock_ref):
		var m4_aim_barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
		check(m4_aim_barrel.dot(-actor.global_basis.z) > 0.99, "M4 barrel follows facing while aiming")
	var lidx := skel.find_bone("mixamorig_LeftHandMiddle1")
	var lrig := actor._grip_rig_for(skel, skel.get_bone_parent(lidx), true)
	var lactual: Vector3 = skel.global_transform * skel.get_bone_global_pose(lidx) * lrig["middle_pivot"]
	var lexpected: Vector3 = actor._rifle_weapon_offset.global_transform * actor._rg_left_knuckle
	check(lactual.distance_to(lexpected) < 0.02, "M4 left hand lands on its own handguard")
	var ridx := skel.find_bone("mixamorig_RightHandMiddle1")
	var rrig := actor._grip_rig_for(skel, skel.get_bone_parent(ridx), false)
	var ractual: Vector3 = skel.global_transform * skel.get_bone_global_pose(ridx) * rrig["middle_pivot"]
	var rexpected: Vector3 = actor._rifle_weapon_offset.global_transform * actor._rg_right_knuckle
	check(ractual.distance_to(rexpected) < 0.02, "M4 right hand lands on its own grip")
	actor._is_aiming = false
	# Hip-fire (_is_firing without _is_aiming): both rifles must shoulder and
	# grip cleanly during RifleFireExternal instead of firing out of the idle
	# carry pose with detached hands.
	actor._is_firing = true
	player.play(actor._rifle_fire_animation, 0.0)
	for frame in 10:
		player.advance(1.0 / 30.0)
		actor._update_rifle_ik(skel, 1.0 / 30.0)
		actor._on_skeleton_updated()
	var m4_hip_barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
	check(m4_hip_barrel.dot(-actor.global_basis.z) > 0.99, "M4 hip-fire shoulders barrel along facing")
	var m4_hip_l: Vector3 = skel.global_transform * skel.get_bone_global_pose(lidx) * lrig["middle_pivot"]
	check(m4_hip_l.distance_to(actor._rifle_weapon_offset.global_transform * actor._rg_left_knuckle) < 0.02, "M4 hip-fire keeps left hand on handguard")
	actor._is_firing = false
	actor.puppet_apply_visuals("", "Rifle francotirador", "")
	actor.process_remote(1.0 / 30.0)
	check(actor._rg_eye == actor.RIFLE_AIM_EYE, "Swapping back restores sniper geometry")
	actor._is_firing = true
	player.play(actor._rifle_fire_animation, 0.0)
	for frame in 10:
		player.advance(1.0 / 30.0)
		actor._update_rifle_ik(skel, 1.0 / 30.0)
		actor._on_skeleton_updated()
	var sn_hip_barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
	check(sn_hip_barrel.dot(-actor.global_basis.z) > 0.99, "Sniper hip-fire shoulders barrel along facing")
	var sn_hip_l: Vector3 = skel.global_transform * skel.get_bone_global_pose(lidx) * lrig["middle_pivot"]
	check(sn_hip_l.distance_to(actor._rifle_weapon_offset.global_transform * actor._rg_left_knuckle) < 0.02, "Sniper hip-fire keeps left hand on handguard")
	actor._is_firing = false
	# Posture-specific reloads keep the firing hand attached, free the support
	# hand through the action and re-grip without changing the 2.2 s ammo window.
	for weapon in [actor.M4_NAME, "Rifle francotirador"]:
		actor.puppet_apply_visuals("", weapon, "")
		for posture in ["stand", "crouch", "prone"]:
			actor.is_crouching = posture == "crouch"
			actor.is_prone = posture == "prone"
			player.play(actor._rifle_idle_animation, 0.0)
			player.advance(0.1)
			actor._update_rifle_ik(skel, 0.016)
			var reload_clip: String = actor._pick_rifle_reload_animation()
			check(reload_clip == "motion/reload_" + posture, "Reload follows posture: " + posture)
			check(is_equal_approx(actor._rifle_reload_speed(reload_clip) * GameConst.GUN_RELOAD_TIME, player.get_animation(reload_clip).length),
				"Reload matches authoritative duration")
			player.play(reload_clip, 0.0)
			var released := false
			var clip: Animation = player.get_animation(reload_clip)
			for frame in 61:
				player.seek(clip.length * float(frame) / 60.0, true)
				actor._update_rifle_ik(skel, 0.016)
				skel.force_update_all_bone_transforms()
				var right_gap := hand_contact(actor, skel, "Right").distance_to(actor._rifle_weapon_offset.global_transform * actor._rg_right_knuckle)
				check(right_gap < 0.015, "Reload firing hand stays attached: %s/%s frame %d gap %.4f" % [weapon, posture, frame, right_gap])
				var reload_barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
				check(reload_barrel.dot(-actor.global_basis.z) > 0.25, "Reload muzzle stays forward of the body")
				var left_gap := hand_contact(actor, skel, "Left").distance_to(actor._rifle_weapon_offset.global_transform * actor._rg_left_knuckle)
				if frame > 10 and frame < 50 and left_gap > 0.06:
					released = true
				if frame == 0 or frame == 60:
					check(left_gap < 0.02, "Reload support hand returns: %s/%s frame %d gap %.4f" % [weapon, posture, frame, left_gap])
			check(released, "Reload actually releases support hand: " + weapon + "/" + posture)
			player.play(actor._rifle_idle_animation, 0.08)
			player.advance(0.2)
			actor._update_rifle_ik(skel, 0.016)
			check_contacts(actor, skel, "Reload exit restores normal grip")
	actor.is_crouching = false
	actor.is_prone = false
	actor.puppet_apply_visuals("", "", "")
	for rig in actor._grip_rig.values():
		for entry in rig["fingers"]:
			check(skel.get_bone_pose_position(entry[0]).distance_to(skel.get_bone_rest(entry[0]).origin) < 0.001,
				"Unequip restores finger origins")
	# Regression: vestir ropa en un puppet no debe desmontar el rifle. Antes,
	# equip_clothing->_sync_held_item->_clear_rifle_attachment dejaba a los
	# bots con pose de rifle y las manos vacias hasta el siguiente cambio de
	# arma, porque _puppet_held ya coincidia y nunca se reconstruia.
	var bot := Actor.new()
	root.add_child(bot)
	bot.stats = preload("res://scripts/SurvivalStats.gd").new()
	bot.inventory = preload("res://scripts/Inventory.gd").new()
	bot.add_child(bot.inventory)
	bot.setup_as_puppet()
	bot.puppet_set_rifle(true)
	bot.puppet_apply_visuals("Camiseta", "Fusil de asalto", "")
	bot.process_remote(1.0 / 30.0)
	check(is_instance_valid(bot._rifle_root), "Puppet M4 visual existe tras sync inicial")
	bot.equip_clothing("Pantalones")
	check(is_instance_valid(bot._rifle_root), "Puppet M4 sobrevive a equip_clothing")
	check(bot.find_child("RifleMesh", true, false) != null, "Puppet conserva RifleMesh tras equip_clothing")
	bot.puppet_apply_visuals("Camiseta,Pantalones,Zapatillas", "Fusil de asalto", "")
	bot.process_remote(1.0 / 30.0)
	check(is_instance_valid(bot._rifle_root), "Puppet M4 sobrevive al cambio de ropa via puppet_apply_visuals")
	bot.stats.free()
	bot.free()
	actor.stats.free()
	actor.free()
	print("RIFLE_GRIP_ERRORS=", errors, " MAX_CONTACT_ERROR_METRES=", worst)
	quit(1 if errors else 0)
