extends SceneTree

func _init() -> void:
	for path in ["res://assets/animations/fishing_idle_rod_line.glb", "res://assets/animations/fishing_end_catch.glb"]:
		var scene: Node = load(path).instantiate()
		var player: AnimationPlayer = null
		for node in scene.find_children("*", "AnimationPlayer", true, false):
			player = node
			break
		print("\nFILE ", path)
		if player == null:
			print("NO ANIMATION PLAYER")
			continue
		for animation_name in player.get_animation_list():
			var animation: Animation = player.get_animation(animation_name)
			print("ANIMATION ", animation_name, " length=", animation.length, " tracks=", animation.get_track_count())
			for track_index in range(animation.get_track_count()):
				var track_path := str(animation.track_get_path(track_index))
				var lower := track_path.to_lower()
				if lower.contains("hilo") or lower.contains("rod") or lower.contains("fish") or lower.contains("pez"):
					var times: Array = []
					for key_index in range(animation.track_get_key_count(track_index)):
						times.append(animation.track_get_key_time(track_index, key_index))
					print("  TRACK ", track_path, " type=", animation.track_get_type(track_index), " keys=", times)
		scene.free()
	quit()
