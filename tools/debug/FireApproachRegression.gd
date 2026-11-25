extends SceneTree

# Run graphically: a dummy renderer cannot measure resident texture memory.
const CAMP := "res://assets/models/props/realistic_campfire.glb"
const TORCH := "res://assets/animations/torch_stick.glb"
const FX := preload("res://scripts/FireVisuals.gd")
const MIB := 1024.0 * 1024.0

func _initialize() -> void:
	call_deferred("run")

func texture_mib() -> float:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / MIB

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FireApproachRegression requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.5, 3)
	camera.look_at(Vector3.UP * 0.5)
	var torch_holder := Node3D.new()
	world.add_child(torch_holder)
	var failures := 0
	for path: String in [CAMP, TORCH]:
		await process_frame
		await RenderingServer.frame_post_draw
		var before := texture_mib()
		var started := Time.get_ticks_usec()
		var model := (load(path) as PackedScene).instantiate() as Node3D
		var load_ms := (Time.get_ticks_usec() - started) / 1000.0
		var small := path == TORCH
		var parent := torch_holder if small else world
		parent.add_child(model)
		var light := OmniLight3D.new()
		light.omni_range = 22.0 if small else 24.0
		light.light_energy = 5.0 if small else 7.0
		light.position.y = 1.2 if small else 0.15
		parent.add_child(light)
		var fire := FX.new()
		fire.small = small
		fire.flicker = not small
		light.add_child(fire)
		await process_frame
		await RenderingServer.frame_post_draw
		var added := texture_mib() - before
		print("FIRE_ASSET name=%s load_ms=%.1f first_draw_ms=%.1f texture_delta_MiB=%.1f" %
			[path.get_file(), load_ms, (Time.get_ticks_usec() - started) / 1000.0, added])
		if added <= 0.0 or added > (16.0 if small else 64.0):
			failures += 1
			push_error("%s: missing texture measurement or exceeded budget" % path.get_file())
	var frames: Array[float] = []
	for i in 180:
		var distance_along := 0.5 + 6.0 * absf(cos(i * PI / 60.0))
		camera.position.z = distance_along
		torch_holder.position = Vector3(0.5, 0, distance_along * 0.65)
		camera.look_at(Vector3.UP * 0.65)
		var started := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec() - started) / 1000.0)
	frames.sort()
	print("FIRE_APPROACH p95_ms=%.2f max_ms=%.2f failures=%d" % [frames[170], frames.back(), failures])
	world.free()
	quit(1 if failures else 0)
