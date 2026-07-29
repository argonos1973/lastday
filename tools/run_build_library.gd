extends SceneTree

const SOURCES := {
	"IdleExternal": "res://assets/animations/idle.glb",
	"WalkExternal": "res://assets/animations/walking.glb",
	"RunExternal": "res://assets/animations/correr.glb",
	"SneakExternal": "res://assets/animations/agachado.glb",
	"SneakWalkExternal": "res://assets/animations/andarAgachado.glb",
	"LeftTurnExternal": "res://assets/animations/leftturn.glb",
	"RightTurnExternal": "res://assets/animations/rightturn.glb",
	"PlantExternal": "res://assets/animations/plantar.glb",
	"GatherExternal": "res://assets/animations/recoger.glb",
	"FishExternal": "res://assets/animations/Fishing Cast.glb",
	"InteractExternal": "res://assets/animations/coger.glb",
	"AttackExternal": "res://assets/animations/pegar.glb",
	"LowHealthExternal": "res://assets/animations/malo.glb",
	"DyingExternal": "res://assets/animations/muerto.glb",
	"JumpExternal": "res://assets/animations/saltar.glb",
	"JumpDownExternal": "res://assets/animations/saltarabajo2.GLB",
	"SleepExternal": "res://assets/animations/dormir2.glb",
	"SitExternal": "res://assets/animations/sentarse.glb",
	"DrinkExternal": "res://assets/animations/beber.glb",
	"RifleFireExternal": "res://assets/animations/Firing Rifle.glb",
	"RifleLeftTurnExternal": "res://assets/animations/Turn Left 45 Degrees.glb",
	"RifleRightTurnExternal": "res://assets/animations/Turning Right 45 Degrees.glb",
	"RifleIdleExternal": "res://assets/animations/Rifle Idle.glb",
	"RifleAimIdleExternal": "res://assets/animations/Rifle Aiming Idle.glb",
	"RifleWalkExternal": "res://assets/animations/Walk With Rifle.glb",
	"RifleRunExternal": "res://assets/animations/Rifle Run.glb",
	"RifleSitExternal": "res://assets/animations/Rifle Kneel Idle.fbx",
	"RifleProneExternal": "res://assets/animations/Prone Idle.fbx",
	"RifleGetupExternal": "res://assets/animations/Rifle Prone To Kneel.fbx",
	"RifleSitFireExternal": "res://assets/animations/Fire Rifle.fbx",
	"RifleProneFireExternal": "res://assets/animations/Prone Firing Rifle.fbx",
	"CrouchTurnLeftExternal": "res://assets/animations/Crouching Turn 90 Left.fbx",
	"CrouchTurnRightExternal": "res://assets/animations/Crouching Turn 90 Right.fbx",
	"RifleStandupExternal": "res://assets/animations/Rifle Kneel To Stand.fbx",
}

const OUTPUT := "res://assets/animations/third_person_animations.res"
const REFERENCE_GLB := "res://assets/animations/idle.glb"

func _init():
	_run()
	quit()

func _run() -> void:
	var output_library := AnimationLibrary.new()
	var ref_skeleton := _load_skeleton(REFERENCE_GLB)
	for animation_name in SOURCES:
		var source_path: String = SOURCES[animation_name]
		var packed_scene := load(source_path) as PackedScene
		if packed_scene == null:
			push_error("No se pudo cargar: " + source_path)
			continue
		var instance := packed_scene.instantiate()
		var player := _find_animation_player(instance)
		if player == null:
			instance.free()
			continue
		var animation := _find_main_animation(player)
		if animation == null:
			instance.free()
			continue
		var copied := animation.duplicate(true)
		var source_skeleton := _find_skeleton(instance)
		if source_skeleton != null and ref_skeleton != null:
			_apply_rest_pose_correction(copied, ref_skeleton, source_skeleton)
			_normalize_hips_ground_y(copied, ref_skeleton)
		output_library.add_animation(animation_name, copied)
		instance.free()
	var error := ResourceSaver.save(output_library, OUTPUT)
	if error != OK:
		push_error("Error guardando AnimationLibrary: %s" % error)
	else:
		print("Biblioteca creada: ", OUTPUT, " con ", output_library.get_animation_list().size(), " animaciones")

func _load_skeleton(path: String) -> Skeleton3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var skel := _find_skeleton(instance)
	if skel != null:
		skel = skel.duplicate() as Skeleton3D
	instance.free()
	return skel

func _apply_rest_pose_correction(animation: Animation, ref_skel: Skeleton3D, source_skel: Skeleton3D) -> void:
	var rot_corrections := {}
	var pos_corrections := {}
	var pos_scales := {}
	var ref_hips_idx := ref_skel.find_bone("mixamorig_Hips")
	var src_hips_idx := source_skel.find_bone("mixamorig_Hips")
	var global_scale := 1.0
	if ref_hips_idx >= 0 and src_hips_idx >= 0:
		var ref_hips_pos := ref_skel.get_bone_rest(ref_hips_idx).origin
		var src_hips_pos := source_skel.get_bone_rest(src_hips_idx).origin
		if src_hips_pos.length() > 0.001:
			global_scale = ref_hips_pos.length() / src_hips_pos.length()
	for i in range(source_skel.get_bone_count()):
		var bone_name := source_skel.get_bone_name(i)
		var ref_idx := ref_skel.find_bone(bone_name)
		if ref_idx < 0:
			continue
		var ref_rest := ref_skel.get_bone_rest(ref_idx)
		var src_rest := source_skel.get_bone_rest(i)
		var q_corr := (ref_rest.basis * src_rest.basis.inverse()).get_rotation_quaternion()
		if q_corr.dot(Quaternion.IDENTITY) < 0.9999:
			rot_corrections[bone_name] = q_corr
		var src_pos := src_rest.origin
		var ref_pos := ref_rest.origin
		if src_pos.length() > 0.001 or ref_pos.length() > 0.001:
			pos_corrections[bone_name] = ref_pos
			pos_scales[bone_name] = global_scale
	var tracks_to_remove: Array[int] = []
	for track_index in range(animation.get_track_count()):
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_bone_name(path_text)
		if bone_name.is_empty():
			continue
		if bone_name.find("$AssimpFbx$") >= 0:
			tracks_to_remove.append(track_index)
			continue
		var track_type := animation.track_get_type(track_index)
		if track_type == Animation.TYPE_ROTATION_3D and rot_corrections.has(bone_name):
			var q_corr: Quaternion = rot_corrections[bone_name]
			for key_index in range(animation.track_get_key_count(track_index)):
				var value: Variant = animation.track_get_key_value(track_index, key_index)
				if value is Quaternion:
					animation.track_set_key_value(track_index, key_index, q_corr * (value as Quaternion))
		elif track_type == Animation.TYPE_POSITION_3D and pos_corrections.has(bone_name):
			var q_corr: Quaternion = rot_corrections.get(bone_name, Quaternion.IDENTITY)
			var p_corr: Vector3 = pos_corrections[bone_name]
			var scale: float = pos_scales.get(bone_name, 1.0)
			var src_rest_pos: Vector3 = source_skel.get_bone_rest(source_skel.find_bone(bone_name)).origin
			for key_index in range(animation.track_get_key_count(track_index)):
				var value: Variant = animation.track_get_key_value(track_index, key_index)
				if value is Vector3:
					var corrected: Vector3 = q_corr * ((value as Vector3) - src_rest_pos) * scale + p_corr
					animation.track_set_key_value(track_index, key_index, corrected)
	tracks_to_remove.reverse()
	for idx in tracks_to_remove:
		animation.remove_track(idx)

func _normalize_hips_ground_y(animation: Animation, ref_skel: Skeleton3D) -> void:
	var hips_idx := ref_skel.find_bone("mixamorig_Hips")
	if hips_idx < 0:
		return
	var ref_hips_y := ref_skel.get_bone_rest(hips_idx).origin.y
	var hips_track_idx := -1
	for track_index in range(animation.get_track_count()):
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_bone_name(path_text)
		if bone_name == "mixamorig_Hips" and animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			hips_track_idx = track_index
			break
	if hips_track_idx < 0:
		return
	var min_y := 1000000.0
	for key_index in range(animation.track_get_key_count(hips_track_idx)):
		var value: Variant = animation.track_get_key_value(hips_track_idx, key_index)
		if value is Vector3:
			min_y = min(min_y, (value as Vector3).y)
	if min_y >= 999999.0:
		return
	var y_offset := ref_hips_y - min_y
	if abs(y_offset) < 0.001:
		return
	for key_index in range(animation.track_get_key_count(hips_track_idx)):
		var value: Variant = animation.track_get_key_value(hips_track_idx, key_index)
		if value is Vector3:
			var v: Vector3 = value as Vector3
			v.y += y_offset
			animation.track_set_key_value(hips_track_idx, key_index, v)


func _extract_bone_name(path_text: String) -> String:
	var colon_index := path_text.find(":mixamorig")
	if colon_index >= 0:
		return path_text.substr(colon_index + 1)
	var underscore_index := path_text.find("mixamorig_")
	if underscore_index >= 0:
		return path_text.substr(underscore_index)
	return ""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null

func _find_main_animation(player: AnimationPlayer) -> Animation:
	var best: Animation = null
	var best_score := 0
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			if animation_name == &"RESET":
				continue
			var candidate: Animation = library.get_animation(animation_name)
			if candidate == null or candidate.length < 0.1:
				continue
			var score := candidate.get_track_count() * 1000
			if candidate.get_track_count() > 0:
				score += candidate.track_get_key_count(0)
			if score > best_score:
				best = candidate
				best_score = score
	return best

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null
