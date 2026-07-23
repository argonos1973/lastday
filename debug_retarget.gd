@tool
extends SceneTree

const OUT_PATH := "res://rifle_retarget_debug.txt"
const LIB_PATH := "res://assets/animations/third_person_animations.res"
const ANIM_NAME := "RifleIdleExternal"

func _init() -> void:
	var out := ""
	var player_packed := load("res://scenes/player/Player.tscn")
	if player_packed == null:
		out += "ERROR: no se pudo cargar Player.tscn\n"
		_write(out)
		print("Escrito ", OUT_PATH)
		quit()
		return

	var player: Node = player_packed.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	await process_frame

	var skeleton := _find_skeleton(player)
	out += "=== Skeleton3D ===\n"
	out += "found=" + str(skeleton != null) + "\n"
	if skeleton == null:
		_write(out)
		print("Escrito ", OUT_PATH)
		quit()
		return

	out += "bone_count=" + str(skeleton.get_bone_count()) + "\n"
	for i in range(skeleton.get_bone_count()):
		out += "  " + str(i) + ": " + skeleton.get_bone_name(i) + "\n"

	var anim_player := AnimationPlayer.new()
	anim_player.name = "DebugAnimPlayer"
	player.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(player)

	var lib: AnimationLibrary = load(LIB_PATH) as AnimationLibrary
	if lib == null:
		out += "\nERROR: no se pudo cargar AnimationLibrary\n"
		_write(out)
		print("Escrito ", OUT_PATH)
		quit()
		return

	if not lib.has_animation(ANIM_NAME):
		out += "\nERROR: no tiene animation " + ANIM_NAME + "\n"
		_write(out)
		print("Escrito ", OUT_PATH)
		quit()
		return

	var src_anim: Animation = lib.get_animation(ANIM_NAME)
	var copied := src_anim.duplicate(true)
	_retarget_animation_to_character_skeleton(copied, anim_player, skeleton)

	out += "\n=== Retargeted " + ANIM_NAME + " tracks ===\n"
	out += "tracks=" + str(copied.get_track_count()) + "\n"
	for i in range(copied.get_track_count()):
		var path := str(copied.track_get_path(i))
		var type: int = copied.track_get_type(i)
		var key_count: int = copied.track_get_key_count(i)
		var valid := false
		var bone_name := ""
		var colon := path.find(":")
		if colon >= 0:
			bone_name = path.substr(colon + 1)
			valid = skeleton.find_bone(bone_name) >= 0
		out += "  track " + str(i) + " type=" + str(type) + " keys=" + str(key_count) + " path=" + path + " valid=" + str(valid) + "\n"

	anim_player.add_animation_library("external", lib.duplicate(true))
	anim_player.add_animation_library("retarget", AnimationLibrary.new())
	var retarget_lib := AnimationLibrary.new()
	retarget_lib.add_animation(ANIM_NAME, copied)
	anim_player.add_animation_library("retarget", retarget_lib)

	out += "\n=== AnimationPlayer after retarget ===\n"
	for anim_name in anim_player.get_animation_list():
		out += "  - " + anim_name + "\n"

	_write(out)
	print("Escrito ", OUT_PATH)
	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _retarget_animation_to_character_skeleton(animation: Animation, anim_player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if skeleton == null or anim_player == null:
		return
	var animation_root := anim_player.get_node_or_null(anim_player.root_node)
	if animation_root == null:
		animation_root = anim_player
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for track_index in range(animation.get_track_count()):
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_mixamo_bone_name(path_text)
		if bone_name.is_empty():
			continue
		bone_name = _resolve_mixamo_bone_name(skeleton, bone_name)
		if bone_name.is_empty():
			continue
		animation.track_set_path(track_index, NodePath(skeleton_path + ":" + bone_name))

func _extract_mixamo_bone_name(path_text: String) -> String:
	var slash_index := path_text.rfind("/")
	var colon_index := path_text.find(":mixamorig", max(0, slash_index))
	if colon_index >= 0:
		return path_text.substr(colon_index + 1)
	var underscore_index := path_text.find("mixamorig_", max(0, slash_index))
	if underscore_index >= 0:
		return path_text.substr(underscore_index)
	return ""

func _resolve_mixamo_bone_name(skeleton: Skeleton3D, imported_bone_name: String) -> String:
	var candidates: Array[String] = [imported_bone_name]
	if imported_bone_name.begins_with("mixamorig:"):
		candidates.append("mixamorig_" + imported_bone_name.substr("mixamorig:".length()))
	elif imported_bone_name.begins_with("mixamorig_"):
		candidates.append("mixamorig:" + imported_bone_name.substr("mixamorig_".length()))
	for candidate in candidates:
		if skeleton.find_bone(candidate) == -1:
			continue
		return candidate
	return ""

func _write(text: String) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	else:
		print("ERROR escribiendo ", OUT_PATH, ": ", FileAccess.get_open_error())
