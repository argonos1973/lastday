extends SceneTree

class NetworkStub extends Node:
	var is_connected := true
	var is_host := false

class WorldStub extends Node3D:
	var player := Node3D.new()
	var net := NetworkStub.new()
	func _init() -> void:
		add_child(player)
		add_child(net)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := WorldStub.new()
	root.add_child(world)
	var profiler = preload("res://scripts/ClientFrameProfiler.gd").new()
	root.add_child(profiler)
	profiler.setup(world)
	var started := Time.get_ticks_usec() - 2000
	profiler.record_section("sample.section", started)
	profiler._process(1.0 / 60.0)
	var errors := 0
	if profiler._samples.frame_ms.size() != 1: errors += 1
	if int(profiler._sections.get("sample.section", {}).get("calls", 0)) != 1: errors += 1
	profiler._report_elapsed = profiler.REPORT_INTERVAL - .01
	profiler._process(.02)
	if not profiler._sections.is_empty(): errors += 1
	if profiler._samples.frame_ms.size() != 0: errors += 1
	print("CLIENT_FRAME_PROFILER errors=", errors)
	world.queue_free()
	profiler.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
