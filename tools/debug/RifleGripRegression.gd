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
				var actual := (skel.global_transform * skel.get_bone_global_pose(idx)).origin
				var expected: Vector3 = actor._rifle_weapon_offset.global_transform * point
				worst = maxf(worst, actual.distance_to(expected))
				check(actual.distance_to(expected) < 0.015, "%s hand contact / %s frame %d" % [side, anim, frame])
			var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
			check(barrel.dot(-actor.global_basis.z) > 0.999, "Puppet barrel follows facing")
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
	actor.stats.free()
	actor.free()
	print("RIFLE_GRIP_ERRORS=", errors, " MAX_CONTACT_ERROR_METRES=", worst)
	quit(1 if errors else 0)
