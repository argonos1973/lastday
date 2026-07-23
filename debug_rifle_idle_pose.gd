@tool
extends SceneTree

const OUT_PATH := "res://rifle_idle_pose_debug.txt"
const GLB_PATH := "res://assets/animations/Rifle Idle.glb"

func _init() -> void:
	var packed := load(GLB_PATH)
	if packed == null:
		_write("ERROR: no se pudo cargar " + GLB_PATH)
		quit()
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var skeleton := _find_skeleton(scene)
	var anim_player := _find_anim_player(scene)
	var out := "=== Rifle Idle.glb ===\n"
	out += "skeleton found=" + str(skeleton != null) + "\n"
	out += "anim_player found=" + str(anim_player != null) + "\n"

	if anim_player != null:
		out += "animations: " + str(anim_player.get_animation_list()) + "\n"
		var anim_list := anim_player.get_animation_list()
		if anim_list.size() > 0:
			anim_player.play(anim_list[0])
			anim_player.seek(0.0, true)
			await process_frame
			await process_frame

	if skeleton != null:
		out += "\n=== Skeleton global transform ===\n"
		out += "global_transform=" + str(skeleton.global_transform) + "\n"
		out += "scale=" + str(skeleton.global_transform.basis.get_scale()) + "\n"
		out += "\n=== Bone positions at t=0 ===\n"
		for bone_name in ["mixamorig_RightHand", "mixamorig_LeftHand", "mixamorig_RightShoulder", "mixamorig_LeftShoulder"]:
			var idx := skeleton.find_bone(bone_name)
			if idx >= 0:
				var pose := skeleton.get_bone_global_pose(idx)
				out += bone_name + " idx=" + str(idx) + " pos=" + str(pose.origin) + "\n"
			else:
				out += bone_name + " NOT FOUND\n"

		var rh_idx := skeleton.find_bone("mixamorig_RightHand")
		var lh_idx := skeleton.find_bone("mixamorig_LeftHand")
		if rh_idx >= 0 and lh_idx >= 0:
			var rh_pos := skeleton.get_bone_global_pose(rh_idx).origin
			var lh_pos := skeleton.get_bone_global_pose(lh_idx).origin
			out += "\nDistance between hands: " + str(rh_pos.distance_to(lh_pos)) + "\n"

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

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result != null:
			return result
	return null

func _write(text: String) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	else:
		print("ERROR escribiendo ", OUT_PATH, ": ", FileAccess.get_open_error())
