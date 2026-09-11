extends "res://scripts/Main.gd"

func _ready() -> void:
	_world_rng.seed = WORLD_SEED
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 12.0
	day_cycle._update_lighting()
	_create_visual_plane("Ground",Vector3(0,-0.02,0),Vector2(180,180),Color(0.24,0.29,0.19))
	_create_road()
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(16,4,24)
	cam.look_at(Vector3(9,0,-20))
	cam.current = true
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/Volumes/copia/lastday2/work/road-improved.png")
	print("ROAD VISUAL PASS")
	get_tree().quit()

func _process(_delta: float) -> void:
	pass
