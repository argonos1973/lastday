extends SceneTree

func _init():
	print("=== TEST SIT ANIM HIPS ===")
	var lib = load("res://assets/animations/third_person_animations.res")
	var anim_names = lib.get_animation_list()
	for anim_name in anim_names:
		if anim_name.find("Sit") >= 0 or anim_name.find("Sleep") >= 0:
			var anim = lib.get_animation(anim_name)
			print("Anim: ", anim_name, " length=", anim.length)
			for ti in range(anim.get_track_count()):
				var pt = str(anim.track_get_path(ti))
				if pt.find("Hips") >= 0 and anim.track_get_type(ti) == Animation.TYPE_POSITION_3D:
					var kc = anim.track_get_key_count(ti)
					print("  Hips pos track keys=", kc)
					for ki in range(min(kc, 5)):
						var v = anim.track_get_key_value(ti, ki)
						print("    key", ki, " = ", v)
	quit()
