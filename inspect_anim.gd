extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("Usage: -- <model_path>")
		quit()
		return
	var path = args[0]
	var res = load(path)
	if res == null:
		print("Failed to load")
		quit()
		return
	var scene = res.instantiate()
	if scene == null:
		print("Failed to instantiate")
		quit()
		return
	print("Scene root: ", scene.name)
	var stack = [scene]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is AnimationPlayer:
			print("ANIMPLAYER: ", n.name, " parent=", n.get_parent().name)
			for lib_name in n.get_animation_library_list():
				print("  LIB: ", lib_name)
				var lib = n.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					var anim = lib.get_animation(anim_name)
					print("    ANIM: ", anim_name, " tracks=", anim.get_track_count())
					for t in range(mini(3, anim.get_track_count())):
						print("      track[", t, "] path=", anim.track_get_path(t), " type=", anim.track_get_type(t))
		if n is Skeleton3D:
			print("SKELETON: ", n.name, " parent=", n.get_parent().name, " bones=", n.get_bone_count())
		for c in n.get_children():
			stack.append(c)
	scene.free()
	quit()
