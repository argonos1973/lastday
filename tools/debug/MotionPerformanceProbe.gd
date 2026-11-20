extends SceneTree
## Four imported actors, no map or saves. Run graphically and in isolation.
## --player-script=res://... selects an archived controller for comparison.
## --output=res://build/tmp/motion_profile_after.json selects the report.

class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_delta): pass

class World extends Node3D:
	var hud = null

func _initialize(): call_deferred("run")

func sample_stats(samples: Array) -> Dictionary:
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += float(sample)
	return {"mean": total / samples.size(), "p50": samples[int(samples.size() * 0.5)],
		"p95": samples[int(samples.size() * 0.95)], "max": samples.back()}

func run():
	var actor_type: Script = Actor
	var output_path := "res://build/tmp/motion_profile_after.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player-script="):
			var inherited := arg.trim_prefix("--player-script=")
			var comparison := GDScript.new()
			comparison.source_code = "extends %s\nfunc _ready(): pass\nfunc _physics_process(_delta): pass\n" % JSON.stringify(inherited)
			if comparison.reload() != OK:
				quit(1)
				return
			actor_type = comparison
		elif arg.begins_with("--output="):
			output_path = arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless":
		push_error("MotionPerformanceProbe requires a real renderer")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	root.always_on_top = true
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.14, 0.16, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -20, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.3
	camera.position = Vector3(0, 1.65, -8)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.make_current()
	var actors: Array = []
	for i in 4:
		var actor = actor_type.new()
		world.add_child(actor)
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.add_child(actor.stats)
		actor.stats.set_process(false)
		actor.setup_as_puppet()
		actor.position.x = (i - 1.5) * 1.6
		actor.puppet_set_rifle(true)
		actor.puppet_apply_visuals("Camiseta,Pantalones,Zapatillas", actor.M4_NAME if i % 2 == 0 else actor.RIFLE_NAME, "")
		actors.append(actor)
	var results := {}
	for role in ["idle", "walk", "aim", "reload"]:
		for actor in actors:
			actor._is_aiming = role == "aim"
			actor.third_person_action_timer = 0.0
			actor.third_person_action_animation = ""
			var clip: String = actor._rifle_idle_animation
			if role == "walk": clip = actor._rifle_walk_animation
			if role == "aim": clip = actor._rifle_aim_idle_animation
			if role == "reload":
				clip = actor._rifle_reload_animation
				actor.third_person_action_animation = clip
				actor.third_person_action_timer = 100.0
			actor.third_person_animation_player.play(clip, 0.0)
			actor._puppet_anim = clip
		for frame in 120: await process_frame
		var frames: Array = []
		var draws: Array = []
		var primitives: Array = []
		var last := Time.get_ticks_usec()
		for frame in 600:
			if role == "reload":
				for actor in actors:
					var ap: AnimationPlayer = actor.third_person_animation_player
					var clip: String = actor._rifle_reload_animation
					ap.play(clip)
					ap.seek(ap.get_animation(clip).length * float(frame % 120) / 120.0, true)
					ap.speed_scale = 0.0
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		results[role] = {"frame_ms": sample_stats(frames), "draw_calls": sample_stats(draws), "primitives": sample_stats(primitives)}
	results["memory"] = {"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write motion report: " + output_path)
		quit(1)
		return
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	world.free()
	await process_frame
	print("MOTION_PROFILE_DONE ", output_path)
	quit()
