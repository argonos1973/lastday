@tool
extends SceneTree

const OUT_PATH := "res://rifle_anim_debug.txt"

func _init() -> void:
	var packed := load("res://scenes/player/Player.tscn")
	if packed == null:
		_write("ERROR: no se pudo cargar Player.tscn")
		quit()
		return
	var player: Node = packed.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	await process_frame

	var anim_player := _find_anim_player(player)
	var skeleton := _find_skeleton(player)

	var out := "=== Player tree ===\n"
	out += _dump_tree(player, 0)
	out += "\n\n=== AnimationPlayer ===\n"
	out += "found=" + str(anim_player != null) + "\n"
	if anim_player != null:
		out += "current_animation=" + anim_player.current_animation + "\n"
		out += "animations:\n"
		for anim_name in anim_player.get_animation_list():
			out += "  - " + anim_name + "\n"
		var anim_name := "external/RifleIdleExternal"
		if anim_player.has_animation(anim_name):
			var anim := anim_player.get_animation(anim_name)
			out += "\n=== Animation: " + anim_name + " ===\n"
			out += "length=" + str(anim.length) + " loop=" + str(anim.loop_mode) + " tracks=" + str(anim.get_track_count()) + "\n"
			for i in range(anim.get_track_count()):
				var path := anim.track_get_path(i)
				var type := anim.track_get_type(i)
				out += "  track " + str(i) + " type=" + str(type) + " path=" + str(path) + "\n"
		else:
			out += "\nERROR: no tiene animation " + anim_name + "\n"

	out += "\n=== Skeleton3D ===\n"
	out += "found=" + str(skeleton != null) + "\n"
	if skeleton != null:
		out += "bones:\n"
		for i in range(skeleton.get_bone_count()):
			out += "  " + str(i) + ": " + skeleton.get_bone_name(i) + "\n"

	_write(out)
	print("Escrito ", OUT_PATH)
	quit()

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result != null:
			return result
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _dump_tree(node: Node, depth: int) -> String:
	var s := "  ".repeat(depth) + node.name + " (" + node.get_class() + ")\n"
	for child in node.get_children():
		s += _dump_tree(child, depth + 1)
	return s

func _write(text: String) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	else:
		print("ERROR escribiendo ", OUT_PATH, ": ", FileAccess.get_open_error())
