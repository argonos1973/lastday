extends SceneTree
# Isolated real-character/animation check; never generates a world or saves.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
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
	# No animation advance is needed to undo corrected finger pivots.
	actor._is_aiming = false
	actor._update_rifle_ik(skel, 0.016)
	for rig in actor._grip_rig.values():
		for entry in rig["fingers"]:
			check(skel.get_bone_pose_position(entry[0]).distance_to(skel.get_bone_rest(entry[0]).origin) < 0.001, "Aim exit restores pivots immediately")
	actor._is_aiming = true
	actor._update_rifle_ik(skel, 0.016)
	actor._on_skeleton_updated()
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
	# Leaving aim returns the weapon to its hand attachment.
	actor._is_aiming = false
	player.play(actor._rifle_idle_animation, 0.0)
	player.advance(0.1)
	actor._update_rifle_ik(skel, 0.016)
	check(not actor._rifle_weapon_offset.top_level, "Un-aim restores hand parenting")
	check(not actor._rifle_aim_pose_active, "Un-aim disables aim solver")
	for rig in actor._grip_rig.values():
		for entry in rig["fingers"]:
			check(skel.get_bone_pose_position(entry[0]).distance_to(skel.get_bone_rest(entry[0]).origin) < 0.001, "Un-aim restores finger origins")
	actor.stats.free()
	actor.free()
	print("RIFLE_GRIP_ERRORS=", errors, " MAX_CONTACT_ERROR_METRES=", worst)
	quit(1 if errors else 0)
