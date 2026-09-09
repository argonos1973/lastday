extends SceneTree

func _init():
	_inspect("res://assets/animations/inicio_pesca.glb")
	quit()

func _inspect(path: String) -> void:
	var glb = load(path)
	var inst = glb.instantiate()
	_find_and_print(inst)
	inst.queue_free()

func _find_and_print(node) -> void:
	for c in node.get_children():
		if c is AnimationPlayer:
			for lib_name in c.get_animation_library_list():
				var lib = c.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					var anim: Animation = lib.get_animation(anim_name)
					for t in range(anim.get_track_count()):
						var p := str(anim.track_get_path(t))
						if p.find("mixamorig_Hips") >= 0 and anim.track_get_type(t) == 1:
							print("Hips position track, keys=", anim.track_get_key_count(t))
							var kc := anim.track_get_key_count(t)
							var step = max(1, kc / 20)
							for k in range(0, kc, step):
								var time = anim.track_get_key_time(t, k)
								var val = anim.track_get_key_value(t, k)
								print("  t=", time, " pos=", val)
		_find_and_print(c)
