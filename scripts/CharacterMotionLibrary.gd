extends RefCounted
## Animation-only clips, retargeted once for each compatible skeleton.
## A single AnimationPlayer still evaluates the chosen motion; no extra layers.

const SOURCE := "res://assets/animations/mixamo/character_motions.glb"
const SOURCES := [SOURCE, "res://assets/animations/eat_fruit.glb"]
const PREFIX := "motion/"
const DIRECTIONS := ["forward", "forward_right", "right", "backward_right",
	"backward", "backward_left", "left", "forward_left"]
static var _libraries: Dictionary = {}

static func is_locomotion(role: String) -> bool:
	return role.begins_with("walk_") or role.begins_with("run_") or role.begins_with("crouch_walk_") \
		or role in ["stand_idle", "stand_aim_idle", "crouch_idle", "crouch_aim_idle", "kneel_idle", "prone_idle",
			"turn_left", "turn_right", "crouch_turn_left", "crouch_turn_right", "prone_turn_left", "prone_turn_right"]

static func is_loop(role: String) -> bool:
	return role.ends_with("_idle") or role in ["crouch_aim_idle", "jump_air", "injured_walk", "dig", "eat_fruit"] \
		or role.begins_with("walk_") or role.begins_with("run_") or role.begins_with("crouch_walk_")

static func direction(local_motion: Vector3) -> String:
	if local_motion.x * local_motion.x + local_motion.z * local_motion.z < 0.00000001:
		return "forward"
	var angle := atan2(local_motion.x, -local_motion.z)
	return DIRECTIONS[posmod(int(floor((angle + PI / 8.0) / (PI / 4.0))), 8)]

static func install(actor) -> Dictionary:
	var player: AnimationPlayer = actor.third_person_animation_player
	var target: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	if player == null or target == null or not ResourceLoader.exists(SOURCE):
		return {}
	var animation_root := player.get_node(player.root_node)
	# Rest transforms and the track path matter, not just the number of bones.
	var signature: Array = [str(animation_root.get_path_to(target))]
	for bone in target.get_bone_count():
		signature.append(target.get_bone_name(bone))
		signature.append(target.get_bone_parent(bone))
		signature.append(target.get_bone_rest(bone))
	var key := signature.hash()
	var library: AnimationLibrary = _libraries.get(key)
	if library == null:
		library = AnimationLibrary.new()
		for source_path in SOURCES:
			var packed := load(source_path) as PackedScene
			if packed == null:
				continue
			var source := packed.instantiate()
			var skeleton: Skeleton3D = actor._find_skeleton(source)
			var animations: AnimationPlayer = actor._find_animation_player(source)
			if skeleton == null or animations == null:
				source.free()
				continue
			for name in animations.get_animation_list():
				var role := String(name)
				if role == "RESET":
					continue
				var clip: Animation = animations.get_animation(name).duplicate(true)
				# Keep the controller's translation, scale and collision authority.
				# Unmapped donor bones must not become unresolved AnimationPlayer tracks.
				for track in range(clip.get_track_count() - 1, -1, -1):
					var bone: String = actor._extract_mixamo_bone_name(str(clip.track_get_path(track)))
					if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D \
							or actor._resolve_mixamo_bone_name(target, bone).is_empty():
						clip.remove_track(track)
				actor._retarget_animation_to_character_skeleton(clip)
				actor._retarget_rotation_tracks_with_source(clip, target, skeleton)
				clip.loop_mode = Animation.LOOP_LINEAR if is_loop(role) else Animation.LOOP_NONE
				clip.step = 1.0 / 30.0
				if role in ["turn_left", "turn_right", "crouch_turn_left", "crouch_turn_right", "prone_turn_left", "prone_turn_right"]:
					_remove_turn_yaw(clip, target, actor)
				if is_loop(role):
					actor._smooth_loop_boundary(clip)
				library.add_animation(role, clip)
			source.free()
		_libraries[key] = library
	if not player.has_animation_library("motion"):
		player.add_animation_library("motion", library)
	var result := {}
	for role in library.get_animation_list():
		result[String(role)] = PREFIX + String(role)
	return result

static func _remove_turn_yaw(clip: Animation, skeleton: Skeleton3D, actor) -> void:
	for track in clip.get_track_count():
		var bone: String = actor._extract_mixamo_bone_name(str(clip.track_get_path(track)))
		if not (bone.ends_with("Hips") or bone.ends_with("Spine") or bone.ends_with("Spine1") or bone.ends_with("Spine2")):
			continue
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var parent := skeleton.get_bone_parent(index)
		var parent_basis := skeleton.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		var rest_global := skeleton.get_bone_global_rest(index).basis.orthonormalized()
		# The imported armature is rotated 90 degrees: skeleton Y is not
		# world up. Remove only twist around the real up axis, preserving
		# the crouch/prone lean and letting the controller supply the turn.
		var up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
		for key in clip.track_get_key_count(track):
			var rotation: Quaternion = clip.track_get_key_value(track, key)
			var animated := parent_basis * Basis(rotation)
			var delta := (animated * rest_global.inverse()).get_rotation_quaternion()
			var yaw := 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).dot(up), delta.w)
			var corrected := parent_basis.inverse() * Basis(up, -yaw) * animated
			clip.track_set_key_value(track, key, corrected.get_rotation_quaternion().normalized())
