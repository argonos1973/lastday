extends SceneTree

class World extends Node3D:
	var player: Node3D
	var depth := 0.0
	var blocked := false
	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array:
		return [] if blocked else [goal]
	func is_wildlife_allowed_at(_pos: Vector3) -> bool: return not blocked
	func _get_exact_ground_y(_x: float, _z: float) -> float: return 0.0
	func get_river_depth_at(_pos: Vector3) -> float: return depth

class Owner extends Node3D:
	var is_dead := false

class Animal extends WildlifeController:
	func _process(_delta: float) -> void: pass
	func _update_tracks() -> void: pass
	func _update_wolf_sounds(_delta: float) -> void: pass
	func _play_wolf_sound(_kind: String) -> void: pass
	func _update_tamed_visuals() -> void: pass
	func _escape_if_trapped(_delta: float) -> bool: return false

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var owner := Owner.new()
	owner.name = "Player"
	world.add_child(owner)
	world.player = owner
	var wolf := Animal.new()
	world.add_child(wolf)
	wolf.setup("wolf", [Vector3(0,0,-5), Vector3(5,0,-5)])
	wolf.tamed_to = "local"
	wolf._owner_node = owner
	wolf._wolf_hunger = 100.0
	wolf._orders_cease = true
	wolf._speed_jitter = 0.85 # Slowest random variant must still follow a sprint.
	var ap: AnimationPlayer = wolf._animation_player
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var dt := 1.0 / 60.0
	for pace in [4.0, 7.0, 0.0]:
		var max_step := 0.0
		for frame in range(600):
			owner.position.z += pace * dt
			var before := wolf.position
			wolf._process_body(dt)
			ap.advance(dt)
			max_step = maxf(max_step, wolf.position.distance_to(before))
		var gap := wolf.position.distance_to(owner.position)
		print("FOLLOW pace=", pace, " gap=", gap, " clip=", ap.current_animation, " cadence=", ap.speed_scale, " max_step=", max_step)
		check(gap < 6.0, "companion keeps up at %.1f m/s (gap %.2f)" % [pace, gap])
		check(max_step <= 8.4 * dt + 0.005, "follow has no position snaps")
		if pace == 0.0:
			check(wolf.current_anim_keyword == "sit", "companion sits after owner stops")
		else:
			check(wolf.current_anim_keyword == ("run" if pace > 5.0 else "trot"), "actual speed selects correct gait")
			check(ap.speed_scale >= 0.649 and ap.speed_scale <= 1.351, "locomotion retains natural cadence")
	wolf.apply_command("stay")
	for frame in range(800):
		wolf._process_body(dt)
		ap.advance(dt)
	check(wolf.current_anim_keyword == "lie" and "lie" in ap.current_animation.to_lower(), "stay transitions into the real lying clip")
	wolf.apply_command("follow")
	owner.position.z += 8.0
	for frame in range(90):
		wolf._process_body(dt)
		ap.advance(dt)
	check(wolf.position.distance_to(owner.position) < 9.0 and wolf.current_anim_keyword in ["walk", "trot", "run"], "lying wolf gets up and follows")
	# Blocking movement stops the gait rather than pedalling against the wall.
	world.blocked = true
	var before_block := wolf.position
	wolf._process_body(dt)
	check(wolf.position.is_equal_approx(before_block) and wolf.current_anim_keyword == "idle", "blocked companion stands still")
	world.blocked = false
	# Water slows travel; cadence and gait must use the actual, reduced speed.
	world.depth = 1.0
	wolf._water_query_timer = 0.0
	owner.position.z += 12.0
	for frame in range(60):
		wolf._process_body(dt)
		ap.advance(dt)
	check(wolf.current_anim_keyword in ["walk", "trot"], "wading companion does not gallop in slow motion")
	world.depth = 0.0
	wolf.rotation.y = 0.0
	wolf._face_towards(wolf.position + Vector3.RIGHT * 5.0, 1.0)
	check(absf(angle_difference(wolf.rotation.y, PI * 0.5)) < 0.001, "slow AI ticks cannot overshoot the facing direction")
	var local_owner := CharacterBody3D.new()
	world.add_child(local_owner)
	local_owner.velocity = Vector3(0,0,7)
	wolf._update_follow_owner_speed(local_owner, dt)
	check(is_equal_approx(wolf._follow_owner_speed, 7.0), "local player uses actual sprint velocity")
	local_owner.free()
	wolf.free()

	var puppet := Animal.new()
	world.add_child(puppet)
	puppet.setup_puppet("wolf")
	puppet.tamed_to = "local"
	check(is_equal_approx(puppet.move_speed, 2.0), "client and server share wolf base speed")
	puppet.puppet_apply(Vector3.ZERO, 0.0, "run", false, false)
	for frame in range(120):
		if frame % 6 == 0:
			puppet.puppet_apply(Vector3(0,0,frame * dt * 7.0), 0.0, "run", false, false)
		puppet._process_body(dt)
	check(puppet.current_anim_keyword == "run" and puppet._animation_player.speed_scale < 1.2, "remote sprint runs at authored cadence")
	for frame in range(120): puppet._process_body(dt)
	check(puppet.current_anim_keyword == "idle", "lost network samples stop the remote leg cycle")
	puppet.puppet_apply(puppet.position, 0.0, "sit", false, false)
	for frame in range(20): puppet._process_body(dt)
	check(puppet.current_anim_keyword == "sit", "remote rest snapshot preserves sitting")
	world.free()
	print("TamedWolfMotionRegression failures=", failures)
	quit(1 if failures else 0)
