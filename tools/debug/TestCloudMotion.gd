extends "res://scripts/Main.gd"

var frames := 0
var elapsed := 0.0
var first: Image

func _ready() -> void:
	_create_environment()
	_create_day_night()
	day_cycle.set_process(false)
	day_cycle.time_of_day = 12.0
	day_cycle._update_lighting()
	hud = HUDScript.new()
	hud._real_wind_speed = 18.0
	hud._real_wind_direction = 270.0
	_weather_visual.cloud = 0.65
	_weather_target.cloud = 0.65
	var cam := Camera3D.new()
	cam.rotation_degrees.x = 25.0
	add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute("user://cloud_motion")

func _process(delta: float) -> void:
	_update_weather_visuals(delta)
	elapsed += delta
	frames += 1
	if frames == 10:
		await RenderingServer.frame_post_draw
		first = get_viewport().get_texture().get_image()
		first.save_png("user://cloud_motion/start.png")
	if elapsed > 12.0 and first != null:
		set_process(false)
		await RenderingServer.frame_post_draw
		var last := get_viewport().get_texture().get_image()
		last.save_png("user://cloud_motion/end.png")
		var difference := 0.0
		for y in range(0, last.get_height(), 8):
			for x in range(0, last.get_width(), 8):
				var a := first.get_pixel(x, y)
				var b := last.get_pixel(x, y)
				difference += absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b)
		print("CLOUD MOTION pixels difference=", difference, " displacement=", _cloud_displacement)
		hud.free()
		get_tree().quit(0 if difference > 10.0 else 1)
