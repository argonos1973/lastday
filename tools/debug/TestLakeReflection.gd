extends SceneTree
const Water = preload("res://scripts/RiverWater.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var lake := Water.new()
	lake.position = Vector3(5, 0.1, 0)
	lake.rotation.y = 0.4
	lake.mesh = PlaneMesh.new()
	lake.set_is_lake(true)
	world.add_child(lake)
	lake.set_process(false)
	var capture := lake._reflection.global_transform
	var start_y := lake.position.y
	for i in range(1200):
		lake._process(1.0 / 60.0)
	check(not is_equal_approx(start_y, lake.position.y), "Water still animates")
	check(capture.is_equal_approx(lake._reflection.global_transform), "Animated water never invalidates cached reflection")
	check(lake._reflection.global_position.distance_to(Vector3(5, 1.6, 0)) < 0.01, "Capture retains world placement after detaching transform")
	check((lake._reflection.cull_mask & (1 << 18)) == 0 and (lake._reflection.cull_mask & 1) == 1, "Capture excludes grass but retains trees and scenery")
	check(lake._reflection.reflection_mask == 1 << 19, "Lake reflection is applied only to the water")
	lake._reflection_timer = 60.0
	lake.set_night_amount(0.01)
	lake._process(0.1)
	check(capture.is_equal_approx(lake._reflection.global_transform), "Small lighting variations reuse capture")
	Water._next_capture_msec = 0
	lake.set_night_amount(0.5)
	lake._process(0.1)
	check(not capture.is_equal_approx(lake._reflection.global_transform), "Significant day/night changes refresh reflection")
	capture = lake._reflection.global_transform
	lake._reflection_timer = 60.0
	Water._next_capture_msec = 0
	lake.set_night_amount(0.5, 0.6)
	lake._process(0.1)
	check(not capture.is_equal_approx(lake._reflection.global_transform), "Storm lighting refreshes reflection")
	capture = lake._reflection.global_transform
	lake.request_reflection_refresh()
	lake._process(0.1)
	check(capture.is_equal_approx(lake._reflection.global_transform), "Shared budget spaces capture work")
	Water._next_capture_msec = 0
	camera.position = Vector3(1000, 0, 0)
	lake._process(0.1)
	check(lake._reflection_dirty, "Far lakes defer geometry refresh")
	camera.position = Vector3.ZERO
	lake._process(0.1)
	check(not lake._reflection_dirty, "Approaching lake captures completed world once")
	world.queue_free()
	await process_frame
	print("LAKE REFLECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
