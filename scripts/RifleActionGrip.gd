extends RefCounted
## Reuses the existing arm solver during reload. The weapon follows the animated
## firing hand; the support hand works the actual magazine and charging handle.

var _clip := ""
var _weapon_id := 0
var _last_position := -1.0
var _gun_basis_local := Basis.IDENTITY
var _gun_scale := Vector3.ONE
var _right_reference := Vector3.ZERO
var _parts_id := 0
var _magazine: Array[Dictionary] = []
var _bolt: Dictionary = {}
var _mag_contact := Vector3.ZERO
var _bolt_contact := Vector3.ZERO
var _pull_distance := 0.15

static func restore_copy(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("reload_part_rest"):
			node.set_as_top_level(false)
			node.transform = node.get_meta("reload_part_rest")
			node.remove_meta("reload_part_rest")

func clear() -> void:
	if _clip.is_empty():
		return
	_restore_magazine()
	_restore_bolt()
	_clip = ""
	_weapon_id = 0
	_last_position = -1.0

func _restore_magazine() -> void:
	for part in _magazine:
		if is_instance_valid(part.node) and part.detached:
			part.node.set_as_top_level(false)
			part.node.transform = part.rest
			part.detached = false
			part.node.remove_meta("reload_part_rest")

func _restore_bolt() -> void:
	if not _bolt.is_empty() and is_instance_valid(_bolt.node) and _bolt.detached:
		_bolt.node.set_as_top_level(false)
		_bolt.node.transform = _bolt.rest
		_bolt.detached = false
		_bolt.node.remove_meta("reload_part_rest")

func _prepare_parts(actor, weapon: Node3D, root: Node3D) -> bool:
	if _parts_id == weapon.get_instance_id():
		return not _magazine.is_empty()
	_restore_magazine()
	_restore_bolt()
	_magazine.clear()
	_bolt.clear()
	_parts_id = weapon.get_instance_id()
	var model: Node3D = actor._rifle_model
	var magazine := model.find_child("Magazine_defaultPolygonShader_0" if actor._mounted_rifle_is_m4 else "Cube_054_Mat2_0", true, false) as MeshInstance3D
	var bolt := model.find_child("Reloader_defaultPolygonShader_0" if actor._mounted_rifle_is_m4 else "Cube_050_Mat1_0", true, false) as MeshInstance3D
	if magazine == null or bolt == null:
		return false
	var inverse := root.global_transform.affine_inverse()
	var scale := root.global_basis.get_scale().x
	var bounds: AABB = inverse * magazine.global_transform * magazine.get_aabb()
	_mag_contact = Vector3(bounds.end.x + 0.015 / scale, bounds.position.y + 0.02 / scale, bounds.get_center().z)
	_pull_distance = clampf(bounds.size.y * scale * 0.85, 0.10, 0.24)
	var latch: AABB = inverse * bolt.global_transform * bolt.get_aabb()
	_bolt_contact = Vector3(latch.position.x, latch.end.y + 0.015 / scale, latch.position.z)
	_bolt = {"node": bolt, "rest": bolt.transform, "root": inverse * bolt.global_transform, "detached": false}
	_magazine.append({"node": magazine, "rest": magazine.transform, "root": inverse * magazine.global_transform, "detached": false})
	if actor._mounted_rifle_is_m4:
		var bullets := model.find_child("Bullets_defaultPolygonShader_0", true, false) as Node3D
		if bullets != null:
			_magazine.append({"node": bullets, "rest": bullets.transform, "root": inverse * bullets.global_transform, "detached": false})
	return true

func _support_target(phase: float, guard: Vector3, magazine: Vector3, below: Vector3, pouch: Vector3, bolt: Vector3, pulled_bolt: Vector3) -> Vector3:
	var times := [0.0, 0.08, 0.16, 0.30, 0.42, 0.55, 0.64, 0.70, 0.76, 0.94, 1.0]
	var points := [guard, magazine, below, pouch, below, magazine, bolt, pulled_bolt, bolt, guard, guard]
	for i in range(1, times.size()):
		if phase <= times[i]:
			return (points[i - 1] as Vector3).lerp(points[i], smoothstep(times[i - 1], times[i], phase))
	return guard

func apply(actor, skeleton: Skeleton3D) -> bool:
	var player: AnimationPlayer = actor.third_person_animation_player
	var weapon: Node3D = actor._rifle_weapon_offset
	var root: Node3D = actor._rifle_root
	if player == null or actor._mounted_rifle_item.is_empty():
		return false
	if not _prepare_parts(actor, weapon, root):
		return false
	var right: Dictionary = actor._grip_rig_for(skeleton, actor._ik_rh_idx, false)
	var left: Dictionary = actor._grip_rig_for(skeleton, actor._ik_lh_idx, true)
	if not right.has("middle") or not left.has("middle"):
		return false
	var right_contact: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(right.middle) * right.middle_pivot
	# Wrist rotation includes the clip's finger/regrip gesture. Using it as
	# the weapon frame can swing the muzzle backwards through the actor.
	var body_basis: Basis = actor.global_basis.orthonormalized()
	var shoulder_index := skeleton.get_bone_parent(actor._ik_right_upper_arm_idx)
	var shoulder := skeleton.global_transform * skeleton.get_bone_global_pose(shoulder_index).origin
	var relative_right := body_basis.inverse() * (right_contact - shoulder)
	var position := player.current_animation_position
	var animation: Animation = player.get_animation(player.current_animation)
	if _clip != player.current_animation or _weapon_id != weapon.get_instance_id() or position < _last_position - 0.05:
		_clip = player.current_animation
		_weapon_id = weapon.get_instance_id()
		_gun_basis_local = body_basis.inverse() * root.global_basis.orthonormalized()
		_gun_scale = root.global_basis.get_scale()
		_right_reference = relative_right
	_last_position = position
	if not weapon.top_level:
		weapon.set_as_top_level(true)
	root.transform = Transform3D.IDENTITY
	var phase := clampf(position / maxf(animation.length, 0.001), 0.0, 1.0)
	var released := smoothstep(0.04, 0.14, phase) * (1.0 - smoothstep(0.82, 0.98, phase))
	var working_basis := Basis.from_euler(Vector3(-0.20, -0.12, 0.26))
	var local_basis := _gun_basis_local.slerp(working_basis, released)
	var gun_basis := (body_basis * local_basis).scaled_local(_gun_scale)
	var sway := (relative_right - _right_reference).limit_length(0.06)
	var grip_height := -0.04 if actor.is_prone else -0.30
	var supported := shoulder + body_basis * (Vector3(0.10, grip_height, -0.35) + sway)
	weapon.global_transform = Transform3D(gun_basis, supported - gun_basis * (actor._rg_right_knuckle as Vector3))
	weapon.force_update_transform()
	root.force_update_transform()
	var transform := weapon.global_transform
	var inverse := skeleton.global_transform.affine_inverse()
	var w2s := inverse.basis * transform.basis
	var hips: int = skeleton.find_bone(actor._resolve_bone_name_safe("mixamorig:Hips", skeleton))
	var chest := (skeleton.get_bone_global_pose(actor._ik_upper_arm_idx).origin + skeleton.get_bone_global_pose(actor._ik_right_upper_arm_idx).origin) * 0.5
	var pouch := skeleton.global_transform * chest.lerp(skeleton.get_bone_global_pose(hips).origin, 0.45) - body_basis.x * 0.28 - body_basis.z * 0.12
	var magazine := transform * _mag_contact
	var bolt := transform * _bolt_contact
	var support_target := _support_target(phase, transform * (actor._rg_left_knuckle as Vector3), magazine,
		magazine - gun_basis.y.normalized() * _pull_distance, pouch, bolt, bolt + gun_basis.z.normalized() * 0.04)
	var latch_grip := smoothstep(0.55, 0.64, phase) * (1.0 - smoothstep(0.76, 0.94, phase))
	var hold_frame: Basis = actor._anatomical_frame(actor.RIFLE_AIM_LEFT_FINGERS, actor.RIFLE_AIM_LEFT_PALM)
	var latch_frame: Basis = actor._anatomical_frame(Vector3.FORWARD, Vector3.DOWN)
	var hand_basis := hold_frame.slerp(latch_frame, latch_grip)
	var fingers: Vector3 = w2s * hand_basis.x
	var palm: Vector3 = w2s * hand_basis.y
	var elbow: Vector3 = w2s * (actor.RIFLE_AIM_LEFT_ELBOW as Vector3).lerp(Vector3(-0.8, 0.2, 0.15), latch_grip)
	# Save the unmodified arms for the headless/manual update path. In graphical
	# playback SkeletonModifier3D restores this input pose automatically.
	actor._m4_saved_left_arm_poses.clear()
	for bone in [actor._ik_upper_arm_idx, actor._ik_forearm_idx, actor._ik_lh_idx,
			actor._ik_right_upper_arm_idx, actor._ik_right_forearm_idx, actor._ik_rh_idx]:
		actor._m4_saved_left_arm_poses.append([bone, skeleton.get_bone_pose(bone)])
	actor._grip_hand(skeleton, actor._ik_right_upper_arm_idx, actor._ik_right_forearm_idx, actor._ik_rh_idx, false,
		inverse * (transform * (actor._rg_right_knuckle as Vector3)),
		w2s * (actor.RIFLE_AIM_RIGHT_FINGERS as Vector3), w2s * (actor.RIFLE_AIM_RIGHT_PALM as Vector3),
		w2s * (actor.RIFLE_AIM_RIGHT_ELBOW as Vector3))
	actor._grip_hand(skeleton, actor._ik_upper_arm_idx, actor._ik_forearm_idx, actor._ik_lh_idx, true,
		inverse * support_target, fingers, palm, elbow)
	if phase >= 0.08 and phase <= 0.55:
		var contact: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(left.middle) * left.middle_pivot
		for part in _magazine:
			if not part.detached:
				part.node.set_meta("reload_part_rest", part.rest)
				part.node.set_as_top_level(true)
				part.detached = true
			var part_transform: Transform3D = transform * (part.root as Transform3D)
			part_transform.origin += contact - magazine
			part.node.global_transform = part_transform
	else:
		_restore_magazine()
	if phase >= 0.64 and phase <= 0.76:
		if not _bolt.detached:
			_bolt.node.set_meta("reload_part_rest", _bolt.rest)
			_bolt.node.set_as_top_level(true)
			_bolt.detached = true
		var pull := smoothstep(0.64, 0.70, phase) if phase <= 0.70 else 1.0 - smoothstep(0.70, 0.76, phase)
		var bolt_transform: Transform3D = transform * (_bolt.root as Transform3D)
		bolt_transform.origin += gun_basis.z.normalized() * 0.04 * pull
		_bolt.node.global_transform = bolt_transform
	else:
		_restore_bolt()
	return true
