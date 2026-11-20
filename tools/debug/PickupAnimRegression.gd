extends SceneTree

# Pickups remain instant. Timed interactions retain their own clips and
# offsets, with the same shared motion library on local and remote actors.

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

	ap.play(player.third_person_idle_animation, 0.0)
	for action in ["pickup", "collect"]:
		player.play_action_animation(action, 0.8)
		check(player.third_person_action_timer == 0.0, action + " adds no action delay")
		check(player.third_person_action_animation.is_empty(), action + " adds no blocking gesture")
		check(ap.current_animation == player.third_person_idle_animation, action + " preserves locomotion")

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

	player.play_action_animation("pick_fruit", 3.0)
	check(ap.current_animation == player._motion("pick_fruit"), "tree fruit uses the branch-reaching clip")
	check(player.third_person_action_timer == 3.0, "fruit timing remains three seconds")
	player.third_person_action_timer = 0.0
	player._held_item_external = true
	player._held_item_reference = preload("res://scripts/Item.gd").create("Pala", "tool_shovel", 1.0)
	player.play_action_animation("dig", 4.0)
	check(ap.current_animation == player._motion("dig"), "shovel work uses digging")
	check(player.third_person_action_timer == 4.0, "digging does not change the action window")
	player.play_action_animation("eat", 2.0)
	check(ap.current_animation == player.third_person_eat_animation, "eating uses the mouth gesture")
	check(player.third_person_action_timer == 2.0, "eating retains its two-second window")
	check(ap.current_animation_position == 0.0 and ap.speed_scale == player.EAT_GESTURE_SPEED,
		"eating plays its own short take from the start at natural speed")
	check(ap.get_animation(player.third_person_eat_animation) != ap.get_animation(player.third_person_drink_animation),
		"food and bottle do not alias the same animation")
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""
	player._held_item_reference = preload("res://scripts/Item.gd").create("Fusil de asalto", "weapon_rifle", 3.0)
	player._rifle_in_hands = true
	player._motion_posture = ""
	player._tick_cosmetic_rifle_motion(false, 0.0)
	player.is_crouching = true
	check(player._tick_cosmetic_rifle_motion(false, 0.016) == player._motion("stand_to_crouch"), "crouching selects its transition")
	check(player.third_person_action_timer == 0.0, "posture motion does not block gameplay")
	check(player._tick_cosmetic_rifle_motion(true, 0.016).is_empty(), "movement interrupts the cosmetic transition")
	player.is_crouching = false
	player._tick_cosmetic_rifle_motion(true, 0.0)
	player.is_jumping = true
	player._jump_animation_timer = 1.2
	player._update_third_person_animation(false, 0.016)
	check(ap.current_animation == player._motion("jump_up"), "rifle jump starts with takeoff")
	player._update_third_person_animation(false, 0.25)
	check(ap.current_animation == player._motion("jump_air"), "rifle jump continues in the air")
	player.is_jumping = false
	player._max_fall_height = player.position.y + 0.5
	player._land_after_fall()
	player._update_third_person_animation(false, 0.016)
	check(ap.current_animation == player._motion("jump_land"), "rifle jump lands without changing gravity")

	# A remote puppet receiving the synced gather clip seeks to the kneel too —
	# otherwise remote players only see the standing wind-up.
	var puppet: Node = _make_player()
	await process_frame
	var puppet_ap: AnimationPlayer = _mount_model(puppet)
	await process_frame
	check(ap.get_animation_library("motion") == puppet_ap.get_animation_library("motion"), "compatible actors share one motion library")
	for clip_name in ap.get_animation_library("motion").get_animation_list():
		var motion: Animation = ap.get_animation("motion/" + clip_name)
		for track in motion.get_track_count():
			check(motion.track_get_type(track) == Animation.TYPE_ROTATION_3D, "motions never move or scale the controller")
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
