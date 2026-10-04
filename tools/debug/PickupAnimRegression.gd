extends SceneTree

# Pickup-animation regression: every "pickup"/"collect" action must resolve to
# the kneel-and-grab clip (GatherExternal — InteractExternal is a talking
# gesture that read as "no animation"), hold a window long enough to show the
# kneel, and seek to the gesture so the pickup reads. Remote puppets replaying
# the synced clip resolve the same start offset.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _make_player() -> Node:
	var player := TestPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	return player

func _mount_model(player: Node) -> AnimationPlayer:
	var model: Node3D = load("res://assets/animations/inicio.glb").instantiate()
	player.add_child(model)
	player.third_person_model = model
	player._setup_third_person_animation(model)
	return player.third_person_animation_player

func _initialize() -> void:
	print("=== PickupAnimRegression ===")
	await process_frame

	var player: Node = _make_player()
	await process_frame
	var ap: AnimationPlayer = _mount_model(player)
	await process_frame

	var offset: float = player.THIRD_PERSON_GATHER_ANIM_OFFSET
	var gather: String = player.third_person_gather_animation
	var interact: String = player.third_person_interact_animation
	check(not gather.is_empty(), "gather animation resolved")
	check(ap.has_animation(gather), "gather clip exists in player")
	check(not interact.is_empty(), "interact animation resolved")

	# Every pickup action name resolves to the kneel clip with a held window.
	for action in ["pickup", "collect"]:
		player.play_action_animation(action, 0.8)
		check(player.third_person_action_animation == gather,
			"'%s' selects gather clip (got '%s')" % [action, player.third_person_action_animation])
		check(player.third_person_action_timer >= 1.6,
			"'%s' holds a visible window (timer %.2f)" % [action, player.third_person_action_timer])
		check(ap.current_animation == gather,
			"'%s' playing gather clip (got '%s')" % [action, ap.current_animation])
		check(ap.current_animation_position >= offset - 0.01,
			"'%s' seeks to the kneel (pos %.2f)" % [action, ap.current_animation_position])
		player.third_person_action_timer = 0.0
		player.third_person_action_animation = ""
		player.third_person_action_start_offset = 0.0

	# Short caller durations (backpack 0.3s) still get the full gesture window.
	player.play_action_animation("pickup", 0.3)
	check(player.third_person_action_timer >= 1.6,
		"short pickup duration extended (timer %.2f)" % player.third_person_action_timer)
	check(ap.current_animation_position >= offset - 0.01,
		"short pickup still seeks (pos %.2f)" % ap.current_animation_position)

	# If something restarts the clip mid-action (e.g. a jump stole the player),
	# the resume path re-applies the seek instead of replaying the wind-up.
	ap.play(player.third_person_idle_animation, 0.0)
	player._update_third_person_animation(false, 0.016)
	check(ap.current_animation == gather,
		"action resume replays gather clip (got '%s')" % ap.current_animation)
	check(ap.current_animation_position >= offset - 0.01,
		"action resume re-seeks to the kneel (pos %.2f)" % ap.current_animation_position)
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""
	player.third_person_action_start_offset = 0.0

	# Forage resolves the same clip — same offset keeps sender/puppet aligned.
	player.play_action_animation("forage", 3.0)
	check(player.third_person_action_animation == gather,
		"forage selects gather clip (got '%s')" % player.third_person_action_animation)
	check(ap.current_animation_position >= offset - 0.01,
		"forage seeks identically (pos %.2f)" % ap.current_animation_position)
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""
	player.third_person_action_start_offset = 0.0

	# Non-gesture actions keep their own timing (no seek leaks).
	player.play_action_animation("plant", 1.0)
	check(player.third_person_action_start_offset == 0.0,
		"plant action carries no seek offset (got %.2f)" % player.third_person_action_start_offset)
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""

	# A remote puppet receiving the synced gather clip seeks to the kneel too —
	# otherwise remote players only see the standing wind-up.
	var puppet: Node = _make_player()
	await process_frame
	var puppet_ap: AnimationPlayer = _mount_model(puppet)
	await process_frame
	puppet.puppet_apply(Vector3.ZERO, 0.0, "idle")
	puppet.puppet_apply(Vector3.ZERO, 0.0, gather)
	check(puppet_ap.current_animation == gather,
		"puppet plays synced gather clip (got '%s')" % puppet_ap.current_animation)
	check(puppet_ap.current_animation_position >= offset - 0.01,
		"puppet seeks to the kneel (pos %.2f)" % puppet_ap.current_animation_position)
	# InteractExternal (legacy/edge pickups) seeks to its own gesture point.
	puppet.puppet_apply(Vector3.ZERO, 0.0, interact)
	check(puppet_ap.current_animation_position >= player.THIRD_PERSON_INTERACT_ANIM_OFFSET - 0.01,
		"puppet interact clip seeks to its bend (pos %.2f)" % puppet_ap.current_animation_position)
	# A plain locomotion clip still plays from the start.
	puppet.puppet_apply(Vector3.ZERO, 0.0, "external/PlantExternal")
	check(puppet_ap.current_animation_position < 0.5,
		"puppet plant clip is not seeked (pos %.2f)" % puppet_ap.current_animation_position)

	player.queue_free()
	puppet.queue_free()
	print("PickupAnimRegression failures=%d" % failures)
	quit(1 if failures > 0 else 0)
