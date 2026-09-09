extends SceneTree

func _init():
	_inspect("res://assets/animations/inicio_pesca_godot.glb")
	quit()

func _inspect(path: String) -> void:
	print("\n=== Inspecting: ", path, " ===")
	if not ResourceLoader.exists(path):
		print("File not found: ", path)
		return
	var glb = load(path)
	if glb is PackedScene:
		var inst = glb.instantiate()
		_print_tree(inst, 0)
		_print_anims(inst)
		inst.queue_free()
	else:
		print("Not a PackedScene: ", glb)

func _print_tree(node, depth = 0):
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")")
	if node is Skeleton3D:
		var count = node.get_bone_count()
		print("  ".repeat(depth + 1), "Bones: ", count)
		for i in range(count):
			print("  ".repeat(depth + 2), "Bone ", i, ": ", node.get_bone_name(i), " parent=", node.get_bone_parent(i))
	for c in node.get_children():
		_print_tree(c, depth + 1)

func _print_anims(node) -> void:
	for c in node.get_children():
		if c is AnimationPlayer:
			print("AnimationPlayer found: ", c.name)
			for lib_name in c.get_animation_library_list():
				var lib = c.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					var anim: Animation = lib.get_animation(anim_name)
					print("  Anim: ", anim_name, " length=", anim.length, " tracks=", anim.get_track_count())
					for t in range(anim.get_track_count()):
						print("    Track ", t, ": type=", anim.track_get_type(t), " path=", anim.track_get_path(t))
		_print_anims_recursive(c)

func _print_anims_recursive(node) -> void:
	for c in node.get_children():
		if c is AnimationPlayer:
			for lib_name in c.get_animation_library_list():
				var lib = c.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					var anim: Animation = lib.get_animation(anim_name)
					print("  [nested] Anim: ", anim_name, " length=", anim.length, " tracks=", anim.get_track_count())
		_print_anims_recursive(c)
