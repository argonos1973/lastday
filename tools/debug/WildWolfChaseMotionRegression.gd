extends SceneTree

class World extends Node3D:
	var player: Node3D
	func find_path_wildlife(_from: Vector3, goal: Vector3) -> Array: return [goal]
	func _get_exact_ground_y(_x: float, _z: float) -> float: return 0.0

const DT := 1.0 / 60.0
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func bone_pos(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)

func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("net_player_proxy")
	player.set_meta("has_real_pos", true)
	world.add_child(player)
	world.player = player
	player.position.z = 12.0
	var wolf := WildlifeController.new()
	world.add_child(wolf)
	wolf.setup("wolf", [Vector3.ZERO, Vector3.BACK * 20])
	wolf.set_process(false)
	wolf._player = player
	wolf._chase_cooldown = 0
	wolf._speed_jitter = 1
	wolf._flank_sign = 1
	var ap := wolf._animation_player
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for frame in 90:
		player.position.z += 7 * DT
		wolf._process_body(DT)
		ap.advance(DT)
	check(wolf._state == "chase_player" and wolf.position.z > 11 and "runfast" in ap.current_animation.to_lower(),
		"a wild wolf runs after a moving player (state=%s z=%.2f clip=%s)" % [wolf._state, wolf.position.z, ap.current_animation])

	# Between bites the wolf circles the player. Measure the head of the real
	# rig, not the requested steering direction or the AI's animation label.
	player.position = wolf.position + Vector3.BACK * 2.8
	wolf._attack_cooldown = 3
	var skeleton := wolf._find_skeleton(wolf._visual_root)
	var min_alignment := 1.0
	for frame in 90:
		var before := wolf.position
		wolf._process_body(DT)
		ap.advance(DT)
		if frame < 40: continue
		var head := bone_pos(skeleton, "Head") - bone_pos(skeleton, "Pelvis")
		head.y = 0
		min_alignment = minf(min_alignment, head.normalized().dot(before.direction_to(wolf.position)))
	check(min_alignment > 0.9 and wolf.current_anim_keyword == "trot",
		"circling wolf trots nose-first along the flank (min dot %.2f)" % min_alignment)
	wolf.free()

	# Two remote wolves run side by side. An HP update for one is not an
	# attack event for the other, even inside melee range of its packmate.
	var pack: Array[WildlifeController] = []
	for i in 2:
		var pup := WildlifeController.new()
		world.add_child(pup)
		pup.setup_puppet("wolf")
		pup.pack_id = "pack"
		pup.set_process(false)
		pup._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		pack.append(pup)
	var run_frames := 0
	var ankle_min := INF
	var ankle_max := -INF
	var yaw_error := 0.0
	for frame in 150:
		for i in pack.size():
			var pup := pack[i]
			if frame % 6 == 0:
				pup.puppet_apply(Vector3(frame * DT * 8, 0, i * 2), PI/2, "run", false, false)
			if frame == 42 and i == 0:
				pup.notify_puppet_damaged()
			pup._process_body(DT)
			pup._animation_player.advance(DT)
			if frame >= 48 and i == 1:
				if "runfast" in pup._animation_player.current_animation.to_lower():
					run_frames += 1
				yaw_error = maxf(yaw_error, absf(angle_difference(PI/2, pup.rotation.y)))
				var paw := pup.to_local(bone_pos(pup._find_skeleton(pup._visual_root), "LegFLAnkle"))
				ankle_min = minf(ankle_min, paw.z)
				ankle_max = maxf(ankle_max, paw.z)
	check(run_frames == 102 and ankle_max - ankle_min > 0.8,
		"moving packmate keeps striding (%d/102 run frames, %.2f m paw travel)" % [run_frames, ankle_max - ankle_min])
	check(yaw_error < 0.01 and pack[1].position.x > 17,
		"puppet advances at the replicated heading (max error %.1f deg)" % rad_to_deg(yaw_error))
	print("Chase: flank alignment=%.3f, remote run=%d/102 frames, paw travel=%.2f m, yaw error=%.1f deg"
		% [min_alignment, run_frames, ankle_max - ankle_min, rad_to_deg(yaw_error)])
	for frame in 45: pack[1]._process_body(DT)
	check(pack[1].current_anim_keyword == "idle", "stale chase samples stop the remote legs")
	var attacker := pack[0]
	attacker.puppet_apply(attacker.position, PI/2, "attack", false, false)
	attacker._process_body(DT)
	check(attacker._animation_player.current_animation == "Wolf_attack", "the attacker's own strike still plays")
	world.free()
	print("WildWolfChaseMotionRegression failures=", failures)
	quit(1 if failures else 0)
