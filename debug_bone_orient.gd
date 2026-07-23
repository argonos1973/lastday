@tool
extends SceneTree

const OUT_PATH := "res://bone_orient_debug.txt"

func _init() -> void:
	var packed := load("res://scenes/player/Player.tscn")
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	await process_frame

	var skeleton := _find_skeleton(player)
	var out := ""
	if skeleton == null:
		out = "no skeleton"
		_write(out)
		quit()
		return

	for bn in ["mixamorig_RightHand", "mixamorig_LeftHand", "mixamorig_RightForeArm"]:
		var idx := skeleton.find_bone(bn)
		if idx < 0:
			out += bn + " NOT FOUND\n"
			continue
		var gp := skeleton.get_bone_global_pose(idx)
		out += bn + " idx=" + str(idx) + "\n"
		out += "  pos=" + str(gp.origin) + "\n"
		out += "  basis X=" + str(gp.basis.x) + "\n"
		out += "  basis Y=" + str(gp.basis.y) + "\n"
		out += "  basis Z=" + str(gp.basis.z) + "\n"
		var parent_idx := skeleton.get_bone_parent(idx)
		if parent_idx >= 0:
			var pp := skeleton.get_bone_global_pose(parent_idx)
			out += "  parent=" + skeleton.get_bone_name(parent_idx) + " pos=" + str(pp.origin) + "\n"

	_write(out)
	print("Escrito ", OUT_PATH)
	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children():
		var r := _find_skeleton(c)
		if r: return r
	return null

func _write(t: String) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f: f.store_string(t); f.close()
