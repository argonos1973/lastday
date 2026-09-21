extends SceneTree

# Renders the real start screen (scenes/Inicio.tscn) including its character
# preview viewport, then saves a screenshot.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var sgm = load("res://scripts/SaveGameManager.gd").new()
	sgm.name = "SaveGameManager"
	root.add_child(sgm)
	var gs = load("res://scripts/GameSession.gd").new()
	gs.name = "GameSession"
	root.add_child(gs)
	var packed = load("res://scenes/Inicio.tscn")
	if packed == null:
		push_error("no scene")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	for frame in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "/tmp/lastday_inicio.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("Shot saved: ", output)
	quit()
