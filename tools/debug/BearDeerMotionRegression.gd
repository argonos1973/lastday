extends SceneTree

# Actual imported models + production movement/interpolation, without world
# generation, audio, saves or wall-clock waits. AI requests a steady pace;
# navigation can slow/block it, as in a river or at a closed passage.
class World extends Node3D:
	var depth := 0.0
	var blocked := false
	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array:
		return [] if blocked else [goal]
	func is_wildlife_allowed_at(_pos: Vector3) -> bool: return not blocked
	func _get_exact_ground_y(_x: float, _z: float) -> float: return 0.0
	func get_river_depth_at(_pos: Vector3) -> float: return depth

class Animal extends WildlifeController:
	var present_sound_events := false
	func _process(_delta: float) -> void: pass
	func _update_tracks() -> void: pass
	func _update_wolf_sounds(_delta: float) -> void: pass
	func _play_wolf_sound(kind: String) -> void:
		if present_sound_events: super._play_wolf_sound(kind)
	func _escape_if_trapped(_delta: float) -> bool: return false

class MovingAnimal extends Animal:
	var requested_speed := 1.0
	var requested_gait := "walk"
	func _prey_ai(_delta: float) -> Dictionary: return _motion_request()
	func _wolf_ai(_delta: float) -> Dictionary: return _motion_request()
	func _motion_request() -> Dictionary:
		_state = "flee"
		_play_animation_by_name(requested_gait)
		return {"target": position + Vector3(0, 0, 40), "speed": requested_speed}

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
	var dt := 1.0 / 60.0
	for kind in ["bear", "deer"]:
		var animal := MovingAnimal.new()
		world.add_child(animal)
		animal.setup(kind, [Vector3.ZERO, Vector3(0,0,40)])
		animal._speed_jitter = 1.0
		animal._wolf_hunger = 100.0
		var ap := animal._animation_player
		check(ap != null, kind + " real GLB has an AnimationPlayer")
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for gait in ["walk", "trot", "run"]:
			animal.requested_gait = gait
			animal.requested_speed = animal.move_speed * (3.2 if gait == "run" else (1.65 if gait == "trot" else 1.0))
			for frame in range(90):
				animal._process_body(dt)
				ap.advance(dt)
			check(animal.current_anim_keyword == gait, kind + " selects " + gait)
			check(absf(ap.speed_scale - 1.0) < 0.01, kind + " " + gait + " keeps authored cadence")
			check(animal._visual_root.rotation.z == 0.0 and animal._visual_root.position.y == 0.0, kind + " imported gait has no extra procedural bob/roll")
		# Fast flight request, but wading only achieves walking speed. The cycle
		# must progress, not restart run -> walk on every simulation frame.
		world.depth = 1.0
		animal._water_query_timer = 0.3
		animal.requested_gait = "gallop" if kind == "deer" else "run"
		for frame in range(50):
			animal._process_body(dt)
			ap.advance(dt)
		check(animal.current_anim_keyword == "walk", kind + " wades instead of running in place")
		check(ap.current_animation_position > 0.6, kind + " wading cycle advances without per-tick restarts")
		check(absf(ap.speed_scale - 1.024) < 0.02, kind + " wading cadence matches real displacement")
		world.blocked = true
		var stopped := animal.position
		animal._process_body(dt)
		check(stopped.is_equal_approx(animal.position) and animal.current_anim_keyword == "idle", kind + " blocked legs stop")
		world.blocked = false
		world.depth = 0.0
		animal.free()

		var puppet := Animal.new()
		world.add_child(puppet)
		puppet.setup_puppet(kind)
		ap = puppet._animation_player
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var pace := puppet.move_speed * 3.2
		for frame in range(120):
			if frame % 6 == 0:
				puppet.puppet_apply(Vector3(0,0,frame * dt * pace), 0.0, "run", false, false)
			puppet._process_body(dt)
			ap.advance(dt)
		check(puppet.current_anim_keyword == "run" and absf(ap.speed_scale - 1.0) < 0.02, kind + " remote run cadence matches server")
		for frame in range(120):
			puppet._process_body(dt)
			ap.advance(dt)
		check(puppet.current_anim_keyword == "idle", kind + " stale movement packets stop leg animation")
		if kind == "bear":
			puppet.puppet_apply(puppet.position, 0.0, "attack", false, false)
			for frame in range(180):
				puppet._process_body(dt)
				ap.advance(dt)
			check(not ap.is_playing(), "stale remote attack snapshot cannot repeat a finished strike")
			var nearby_wolf := Animal.new()
			world.add_child(nearby_wolf)
			nearby_wolf.setup_puppet("wolf")
			nearby_wolf.tamed_to = "remote-owner"
			nearby_wolf.position = puppet.position + Vector3(1,0,0)
			puppet.puppet_apply(puppet.position, 0.0, "eat", false, false)
			nearby_wolf.notify_puppet_damaged()
			# Observe a full feeding cycle after its buffered presentation starts.
			for frame in range(90):
				puppet._process_body(dt)
				ap.advance(dt)
			check(puppet.current_anim_keyword == "eat" and "eat" in ap.current_animation, "remote bear uses exported feeding clip")
			check(ap.speed_scale == 1.0 and ap.current_animation_position > 0.8, "remote feeding plays continuously at authored speed")
			check(not puppet._puppet_combat_active, "nearby wolf cannot invent remote bear attacks while feeding")
			nearby_wolf.free()
		puppet.free()

	# Real bear AI must show its strike, check contact once and stop its body.
	var bear := Animal.new()
	var deer := Animal.new()
	world.add_child(bear)
	world.add_child(deer)
	bear.setup("bear", [Vector3.ZERO, Vector3(0,0,40)])
	deer.setup("deer", [Vector3(0,0,1.8), Vector3(0,0,40)])
	bear._cached_wildlife = [bear, deer]
	bear._wolf_hunger = 20.0
	var hp := deer.health
	var decision := bear._wolf_ai(0.1)
	check(bear.current_anim_keyword == "attack" and decision.speed == 0.0, "bear stops to strike its prey")
	check(deer.health == hp, "prey not damaged before paw contact")
	bear._wolf_ai(0.21)
	check(deer.health == hp - 60.0, "bear hit lands at contact")
	bear._wolf_ai(0.4)
	check(deer.health == hp - 60.0 and bear.current_anim_keyword == "attack", "single damage event and full strike recovery")
	bear._wolf_ai(0.6)
	bear._attack_cooldown = 0.0
	bear._wolf_ai(0.1)
	deer.position.z = 7.0
	bear._wolf_ai(0.21)
	check(deer.health == hp - 60.0, "escaping the strike before contact prevents damage")
	bear._wolf_ai(1.0)
	decision = bear._wolf_ai(dt)
	check(is_equal_approx(decision.speed, bear.move_speed * 2.8), "strike fix preserves bear hunting speed")
	# Feeding state works on the authoritative animal too.
	bear._wolf_eating_timer = 8.0
	bear._wolf_eating_target = deer
	bear._state = "eating"
	bear._play_animation_by_name("idle")
	check(bear.current_anim_keyword == "eat", "bear eating overrides idle")
	bear._process_body(dt)
	check("eat" in bear._animation_player.current_animation, "authoritative eating uses real GLB clip")
	test_bear_presentation(world)
	world.free()
	print("BearDeerMotionRegression failures=", failures)
	quit(1 if failures else 0)

func test_bear_presentation(world: Node3D) -> void:
	var dt := 1.0 / 60.0
	# A strike RPC can precede the next periodic position snapshot.
	for scenario in [[false, 60], [true, 60], [true, 63]]:
		var sound_events: bool = scenario[0]
		var attack_frame: int = scenario[1]
		var resume_frame := attack_frame + 78
		var bear := Animal.new()
		world.add_child(bear)
		bear.setup_puppet("bear")
		bear.present_sound_events = sound_events
		var ap := bear._animation_player
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var pace := bear.move_speed * 4.2
		var strike_travel := 0.0
		var strike_frames := 0
		var movement_with_gait := 0
		# The server stops exactly when it strikes. Position interpolation and
		# the attack pose must reach that stop together, including the earlier
		# animal_sound RPC, rather than sliding through 220 ms of queued running.
		for frame in 240:
			var was_striking := bear.current_anim_keyword == "attack" and ap.is_playing()
			if sound_events and frame in [attack_frame, attack_frame + 27]:
				bear._play_wolf_sound("attack" if frame == attack_frame else "bite")
			if frame % 6 == 0:
				var distance := (minf(frame, attack_frame) + maxf(0, frame - resume_frame)) * dt * pace
				bear.puppet_apply(Vector3(0, 0, distance), 0.0,
					"attack" if frame >= attack_frame and frame < resume_frame else "run", false, false)
			var before := bear.position
			bear._process_body(dt)
			ap.advance(dt)
			var travelled := before.distance_to(bear.position)
			if bear.current_anim_keyword == "attack" and ap.is_playing():
				strike_frames += 1
				if was_striking: strike_travel += travelled
			elif travelled > .01 and bear.current_anim_keyword in ["walk", "trot", "run"]:
				movement_with_gait += 1
		print("BEAR_STRIKE sound=%s event_frame=%d sliding=%.3fm visible_frames=%d moving_frames=%d" %
			[sound_events, attack_frame, strike_travel, strike_frames, movement_with_gait])
		check(strike_travel < .03, "remote bear plants its feet before attacking (sound=%s travel=%.3f)" % [sound_events, strike_travel])
		check(strike_frames >= 65 and strike_frames <= 85, "remote bear shows one complete strike without a bite-event restart")
		check(movement_with_gait > 110, "remote bear runs before and after its strike")
		# The opaque body texture must occlude the far teeth, eyes and skin.
		# BLEND + double-sided export rendered the back of the face on top.
		var meshes: Array = []
		WildlifeController._collect_mesh_instances(bear._visual_root, meshes)
		for mesh in meshes:
			for surface in mesh.mesh.get_surface_count():
				var material: BaseMaterial3D = mesh.get_active_material(surface)
				check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
					"bear skin writes opaque depth instead of showing the inside of the face")
				check(material.cull_mode == BaseMaterial3D.CULL_BACK, "bear skin hides its back faces")
		var skeleton := bear._find_skeleton(bear._visual_root)
		bear._play_animation_by_name("idle")
		bear._play_animation_by_name("attack")
		ap.play(ap.current_animation, 0.0)
		var planted: Dictionary = {}
		for time in [0.0, .15, .3, .45, .75, 1.2]:
			ap.seek(time, true)
			ap.advance(0.0)
			skeleton.force_update_all_bone_transforms()
			var nose := bear.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Nose")).origin))
			var head := bear.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin))
			var jaw := bear.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Jaw")).origin))
			check(nose.z > head.z and jaw.y < head.y, "bear muzzle stays forward and jaw below its head at %.2fs" % time)
			for foot in ["LegBLAnkle", "LegBRAnkle"]:
				var pos := bear.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(foot)).origin))
				if time == 0.0: planted[foot] = pos
				check(pos.distance_to(planted[foot]) < .01, "bear keeps its supporting hind paw planted during the strike")
		bear.free()
