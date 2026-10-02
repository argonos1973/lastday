extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _is_on_walkable_ground() -> bool:
		return true

class StubDayCycle extends Node:
	var temp := 20.0
	func get_ambient_temperature() -> float:
		return temp

class TestScene extends Node:
	var hud = null
	var day_cycle := StubDayCycle.new()
	func get_day_cycle() -> Node:
		return day_cycle
	func get_hud() -> Node:
		return null
	func _ready() -> void:
		add_child(day_cycle)

var failures := 0
const FWD := Vector2(0.0, -1.0)  # forward input

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _forward_event(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _double_tap() -> void:
	_forward_event(true)
	await process_frame
	_forward_event(false)
	await process_frame
	_forward_event(true)
	await process_frame

func _initialize() -> void:
	print("=== SprintStaminaRegression ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := TestPlayer.new()
	root.add_child(player)
	await process_frame
	player.stats.health = 100.0
	player.stats.body_temperature = 36.6

	# Case 1: double-tap forward with energy arms sprint, held W sprints.
	player.stats.energy = 50.0
	await _double_tap()
	player._update_sprint_state(FWD)
	check(player._sprint_double_tap and player.is_sprinting, "double-tap arms sprint")

	# Case 2: stamina exhausted -> latch drops, sprint ends, walk gait.
	await process_frame  # clear input edges
	player.stats.energy = 3.0
	player._update_sprint_state(FWD)
	check(not player.is_sprinting, "exhaustion ends sprint (walk speed applies)")
	check(not player._sprint_double_tap, "exhaustion drops the sprint latch")

	# Case 3: energy recovering does NOT re-engage sprint — no run/walk flicker.
	player.stats.energy = 30.0
	for i in range(30):
		player._update_sprint_state(FWD)
		check(not player.is_sprinting, "sprint stays off on recovery (tick %d)" % i)
		await process_frame

	# Case 4: double-tap while reserve is drained does NOT arm (no micro-burst).
	player.stats.energy = 6.0  # above the 4.0 cut-off, below the 10.0 arming threshold
	_forward_event(false)
	await process_frame
	await _double_tap()
	player._update_sprint_state(FWD)
	check(not player._sprint_double_tap and not player.is_sprinting, "double-tap on drained reserve does not arm sprint")
	# Recovery alone must not retro-activate that denied tap.
	player.stats.energy = 50.0
	await process_frame
	player._update_sprint_state(FWD)
	check(not player.is_sprinting, "denied tap does not retro-activate on recovery")

	# Case 5: after recovering, a new double-tap sprints again.
	await _double_tap()
	player._update_sprint_state(FWD)
	check(player.is_sprinting, "new double-tap sprints again after recovery")

	# Case 6: releasing forward drops the latch (existing behaviour preserved).
	_forward_event(false)
	await process_frame
	player._update_sprint_state(FWD)
	check(not player.is_sprinting and not player._sprint_double_tap, "releasing forward drops the latch")

	player.free()
	scene.free()
	if failures == 0:
		print("SprintStaminaRegression: ALL PASS")
	else:
		print("SprintStaminaRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
