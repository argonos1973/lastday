extends SceneTree

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
	var packed = load("res://scenes/CharacterSelect.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	for frame in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/lastday_charselect.png")
	print("Shot saved")
	quit()
