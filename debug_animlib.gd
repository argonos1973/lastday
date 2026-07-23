@tool
extends SceneTree

const OUT_PATH := "res://rifle_animlib_debug.txt"
const LIB_PATH := "res://assets/animations/third_person_animations.res"

func _init() -> void:
	var lib := load(LIB_PATH) as AnimationLibrary
	var out := "=== AnimationLibrary: " + LIB_PATH + " ===\n"
	if lib == null:
		out += "ERROR: no se pudo cargar\n"
		_write(out)
		print("Escrito ", OUT_PATH)
		quit()
		return

	out += "animations: " + str(lib.get_animation_list()) + "\n\n"
	var anim_name := "RifleIdleExternal"
	if lib.has_animation(anim_name):
		var anim := lib.get_animation(anim_name)
		out += "=== " + anim_name + " ===\n"
		out += "length=" + str(anim.length) + " loop=" + str(anim.loop_mode) + " tracks=" + str(anim.get_track_count()) + "\n"
		for i in range(anim.get_track_count()):
			var path := anim.track_get_path(i)
			var type := anim.track_get_type(i)
			var key_count := anim.track_get_key_count(i)
			out += "  track " + str(i) + " type=" + str(type) + " keys=" + str(key_count) + " path=" + str(path) + "\n"
	else:
		out += "ERROR: no tiene " + anim_name + "\n"

	_write(out)
	print("Escrito ", OUT_PATH)
	quit()

func _write(text: String) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	else:
		print("ERROR escribiendo ", OUT_PATH, ": ", FileAccess.get_open_error())
