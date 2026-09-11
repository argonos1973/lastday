extends "res://scripts/Main.gd"

signal notice(text: String)

func _ready() -> void:
	_world_rng.seed = WORLD_SEED
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 12.0
	day_cycle._update_lighting()
	_create_visual_plane("Ground", Vector3(0,-0.02,0), Vector2(100,100), Color(0.24,0.29,0.19))
	_create_house(Vector3.ZERO, "VillageHouse", "house_1", 11.4, 9.4, 4.35)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(12, 7, 16)
	cam.fov = 50.0
	cam.look_at(Vector3(0,2.6,0))
	cam.current = true
	if "--interior" in OS.get_cmdline_user_args():
		cam.position = Vector3(0,1.7,3.8)
		cam.fov = 85.0
		cam.look_at(Vector3(-1,1.5,-3))
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	get_viewport().get_texture().get_image().save_png("/Volumes/copia/lastday2/work/village_" + suffix + ".png")
	print("VILLAGE RENDER ", suffix)
	var door = get_node("VillageHouse Door")
	door.interact(self)
	await get_tree().create_timer(0.4).timeout
	assert(door.is_open and absf(door.rotation_degrees.y + 96.0) < 0.1)
	door.interact(self)
	await get_tree().create_timer(0.4).timeout
	assert(not door.is_open and absf(door.rotation_degrees.y) < 0.1)
	assert(door._collision != null and not door._collision.disabled)
	print("DOOR OPEN/CLOSE AND COLLISION PASS")
	if "--interior" in OS.get_cmdline_user_args():
		cam.position = Vector3(0,12,100)
		cam.look_at(Vector3(0,2,0))
		await get_tree().create_timer(1).timeout
		print("CULLED draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		for child in get_children():
			if str(child.name).begins_with("VillageHouse"):
				_reset_ranges(child)
		await get_tree().create_timer(1).timeout
		print("UNLIMITED draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()

func _create_house_interior(_o: Vector3, _l: String, _i: String, _w: float, _d: float, _h: float) -> void:
	if "--interior" in OS.get_cmdline_user_args():
		super._create_house_interior(_o,_l,_i,_w,_d,_h)

func _reset_ranges(node: Node) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = 0.0
	for child in node.get_children():
		_reset_ranges(child)

func _process(_delta: float) -> void:
	pass
