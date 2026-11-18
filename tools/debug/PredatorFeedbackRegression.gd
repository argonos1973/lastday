extends SceneTree
# Exercise frames after a confirmed hit, not just AnimationPlayer.play().
const Fixture = preload("res://tools/debug/WildlifeAudioRegression.gd")
var checks := 0
var errors := 0

class NetworkWorld extends Fixture.World:
	var damage_events: Array = []
	var animal_events: Array = []
	func _net_apply_damage(amount: float, weapon: String = "") -> void:
		damage_events.append([amount, weapon])
		super(amount, weapon)
	func _net_animal_sound(animal_name: String, sound_type: String) -> void:
		animal_events.append([animal_name, sound_type])
		super(animal_name, sound_type)
	func _get_ground_height(_pos: Vector3) -> float: return 0.0
	func _get_exact_ground_y(_x: float, _z: float, _fallback: float = 500.0) -> float: return 0.0
	func is_wildlife_allowed_at(_pos: Vector3) -> bool: return true
	func is_wolf_allowed_at(_pos: Vector3) -> bool: return true
	func find_path_wolf(start: Vector3, goal: Vector3) -> Array: return [start, goal]
	func _is_pos_wolf_protected(_pos: Vector3) -> bool: return false

class ClientNet extends "res://scripts/NetworkManager.gd":
	func _ready() -> void: set_process(false)
	func _exit_tree() -> void: pass

class RealPlayer extends "res://scripts/PlayerController.gd":
	func _capture_mouse() -> void: pass

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: errors += 1; push_error(label)

func actor_with_rig(world, puppet: bool):
	var actor := Fixture.Actor.new()
	actor.is_puppet = puppet
	world.add_child(actor)
	actor.third_person_model = Node3D.new(); actor.add_child(actor.third_person_model)
	actor.camera = Camera3D.new(); actor.add_child(actor.camera)
	actor.third_person_animation_player = AnimationPlayer.new(); actor.add_child(actor.third_person_animation_player)
	var library := AnimationLibrary.new()
	for name in ["hit", "run", "attack", "idle", "shot"]:
		var clip := Animation.new(); clip.length = .5
		library.add_animation(name, clip)
	actor.third_person_animation_player.add_animation_library("test", library)
	actor.third_person_hit_animation = "test/hit"
	actor.third_person_run_animation = "test/run"
	actor.third_person_idle_animation = "test/idle"
	actor.third_person_attack_animation = "test/attack"
	actor.third_person_shot_animation = "test/shot"
	return actor

func run():
	var world := Fixture.World.new(); root.add_child(world); current_scene = world
	world.net = Fixture.Net.new(); world.add_child(world.net)
	for bite in ["wolf_bite", "bear_bite"]:
		var actor = actor_with_rig(world, false); world.player = actor
		actor.is_moving = true; actor.is_sprinting = true; actor._is_aiming = true
		actor.velocity = Vector3(0, 0, -6)
		actor.third_person_action_start_offset = .45
		world._net_apply_damage(12, bite)
		actor._update_third_person_animation(true, 1.0 / 60.0)
		check(actor.third_person_action_timer > .15, bite+" flinch survives the next moving frame")
		check(actor.third_person_animation_player.current_animation == "test/hit", bite+" flinch is not replaced by run")
		check(actor.third_person_action_start_offset == 0.0, bite+" cannot inherit a previous action's seek offset")
		check(actor.velocity == Vector3(0, 0, -6), bite+" does not freeze escape movement")
		check(not actor._is_aiming, bite+" breaks ADS")
		actor._mounted_rifle_is_m4 = true
		actor.is_sprinting = false
		check(not actor._m4_camera_ready(), bite+" cannot be masked by automatic M4 camera aiming")
		actor._mounted_rifle_is_m4 = false; actor.is_sprinting = true
		actor._recoil_yaw = .04 # deterministic side impulse, no probabilistic assertion
		actor._update_walk_motion(1.0 / 60.0, 0)
		check(is_equal_approx(actor.camera.rotation.x, actor._pitch+actor._recoil_pitch), bite+" reaches the camera pitch")
		check(is_equal_approx(actor.camera.rotation.y, .04), bite+" reaches the camera yaw")
		for i in 40: actor._update_third_person_animation(true, 1.0 / 60.0)
		check(actor.third_person_animation_player.current_animation == "test/run", bite+" returns to running after the short flinch")
		actor._recoil_pitch = 0; actor._recoil_yaw = 0
		actor._update_walk_motion(1.0 / 60.0, 0)
		check(is_zero_approx(actor.camera.rotation.y), bite+" camera recovers without a mouse event")
		world.player = null; actor.free()
		var observer = actor_with_rig(world, true); world.remote_players[901] = observer
		observer.puppet_set_aiming(true)
		observer._throw_aim_hold = true; observer._throw_aim_frozen = true
		world._net_player_hit_event(901, bite, Vector3.ZERO)
		observer.puppet_set_aiming(true) # stale state snapshot after the reliable impact
		observer.puppet_apply(Vector3.ZERO, 0, "test/attack")
		observer._process(1.0 / 60.0)
		check(observer.third_person_animation_player.current_animation == "test/hit", bite+" survives an old attack snapshot")
		check(not observer._is_aiming and not observer._throw_aim_hold, bite+" observer cannot reapply aiming over the flinch")
		check(observer.stats.health == 100 and observer._recoil_pitch == 0, bite+" observer remains presentation-only")
		for i in 40:
			observer.puppet_apply(Vector3.ZERO, 0, "test/run")
			observer._process(1.0 / 60.0)
		observer.puppet_apply(Vector3.ZERO, 0, "test/run")
		observer.puppet_set_aiming(true)
		check(observer.third_person_animation_player.current_animation == "test/run" and observer._is_aiming, bite+" observer resumes current state after impact")
		world._net_player_hit_event(901, bite, Vector3.ZERO)
		observer.puppet_apply(Vector3.ZERO, 0, "dead")
		check(observer.is_dead and observer.third_person_action_timer == 0, bite+" does not hide an authoritative death snapshot")
		world.remote_players.erase(901); observer.free()
	world.queue_free()
	for i in 4: await process_frame
	await network_attack()
	print("PREDATOR_FEEDBACK checks=", checks, " errors=", errors)
	quit(1 if errors else 0)

func network_attack() -> void:
	# Real WebSocket RPCs and imported rigs. The earlier checks start at the
	# receiving method and cannot catch missing/untagged attacks on the server.
	var host = root.get_node("NetworkManager")
	host.set_process(false)
	var server_peer := WebSocketMultiplayerPeer.new()
	var port := 18500 + OS.get_process_id() % 1000
	check(server_peer.create_server(port, "127.0.0.1") == OK, "isolated WebSocket server binds")
	host.peer = server_peer
	host.multiplayer.multiplayer_peer = server_peer
	host.is_host = true; host.is_connected = true
	var scope := Node.new(); scope.name = "VictimClient"; root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	set_multiplayer(api, scope.get_path())
	var client := ClientNet.new(); client.name = "NetworkManager"; scope.add_child(client)
	var client_peer := WebSocketMultiplayerPeer.new()
	check(client_peer.create_client("ws://127.0.0.1:%d" % port) == OK, "victim connects by WebSocket")
	api.multiplayer_peer = client_peer
	client.peer = client_peer
	for i in 120:
		if client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and api.get_unique_id() > 1:
			break
		await create_timer(.01).timeout
	check(client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "WebSocket handshake completes")
	if client_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		client.close_connection(); host.close_connection(); scope.queue_free()
		return
	var pid := api.get_unique_id()
	host.players[pid] = {"name": "Victim", "ready": true}
	client.is_connected = true
	var world := NetworkWorld.new(); root.add_child(world); current_scene = world; world.net = client
	var actor := RealPlayer.new(); actor.name = "Player"; world.add_child(actor); world.player = actor
	actor.set_process(false); actor.set_physics_process(false); actor.set_process_input(false)
	# Both network branches share this test's physics space. The client body
	# must not act as a second server-side wall in front of its own proxy.
	actor.collision_layer = 2
	actor.stats.set_process(false); actor.stats.set_physics_process(false)
	actor.position = Vector3(0, 0, 2.2)
	var proxy := Node3D.new(); world.add_child(proxy); proxy.position = actor.position
	proxy.add_to_group("net_player_proxy"); proxy.set_meta("peer_id", pid)
	proxy.set_meta("has_real_pos", true)
	var wolf := WildlifeController.new(); wolf.name = "AttackingWolf"; world.add_child(wolf)
	wolf.setup("wolf", [Vector3.ZERO, Vector3(0, 0, -5)])
	wolf.set_process(false); wolf._wolf_hunger = 100; wolf._player = proxy; wolf._chase_cooldown = 0
	wolf.remove_from_group("wildlife")
	var puppet := WildlifeController.new(); puppet.name = "Puppet_AttackingWolf"; puppet.is_puppet = true; world.add_child(puppet)
	puppet.setup_puppet("wolf"); puppet.set_process(false)
	world.puppet_animals[str(wolf.name)] = puppet
	check(not actor.third_person_hit_animation.is_empty(), "real player loads the hurt clip")
	check(puppet._animation_player != null, "real wolf loads its animation rig")
	# Inspect each audio source separately through the real output mixer.
	var captures: Array = []
	for label in ["VictimPain", "VictimBite", "WolfVoice"]:
		var bus := AudioServer.bus_count
		AudioServer.add_bus(); AudioServer.set_bus_name(bus, label)
		var capture := AudioEffectCapture.new(); capture.buffer_length = 2.0
		AudioServer.add_bus_effect(bus, capture); captures.append(capture)
	actor._play_damage_audio("wolf_bite")
	actor._pain_audio_player.stop(); actor._bite_audio_player.stop()
	actor._pain_sound_timer = 1.5; actor._last_bite_audio_msec = -10000
	actor._pain_audio_player.bus = "VictimPain"; actor._bite_audio_player.bus = "VictimBite"
	puppet._prepare_animal_voice(); puppet._wolf_audio_player.bus = "WolfVoice"
	root.audio_listener_enable_3d = true
	actor.camera.make_current()
	await create_timer(.1).timeout
	for capture in captures: capture.clear_buffer()
	wolf._process(1.0/60)
	await create_timer(.08).timeout
	check(actor.stats.health == 100, "wind-up has no instant invisible damage")
	check(puppet.current_anim_keyword == "attack", "wolf wind-up reaches client before damage")
	for i in 28:
		wolf._process(1.0/60)
		puppet._process(1.0/60)
		await process_frame
	await create_timer(.08).timeout
	print("WIRE_ATTACK events=", world.damage_events, " hp=", actor.stats.health,
		" sound=", world.animal_events, " hurt=", actor.third_person_animation_player.current_animation,
		" wolf=", puppet._animation_player.current_animation)
	check(world.damage_events.size() == 1 and world.damage_events[0] == [25.0, "wolf_bite"], "real wolf delivers one tagged damage RPC")
	check(actor.stats.health == 75.0, "network bite removes health once")
	check(actor._pain_audio_player.playing and actor._bite_audio_player.playing, "network bite plays both victim sounds")
	check(actor._forced_hit_reaction_active(), "network bite starts the player's forced reaction")
	check(puppet.current_anim_keyword == "attack", "reliable attack event animates the wolf")
	for i in 5: wolf._process(1.0/60)
	await create_timer(.03).timeout
	check(world.damage_events.size() == 1, "one jaw snap cannot apply damage twice")
	var ap := actor.third_person_animation_player
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.seek(0, true)
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	var head := skel.find_bone(actor._resolve_mixamo_bone_name(skel, "mixamorig:Head"))
	var head_before := skel.get_bone_pose_rotation(head)
	for i in 21:
		actor._update_third_person_animation(true, 1.0/60)
		ap.advance(1.0/60)
	check(ap.current_animation == actor.third_person_hit_animation, "moving real player reaches the actual flinch peak")
	check(head_before.angle_to(skel.get_bone_pose_rotation(head)) > .4, "real hurt animation moves the head visibly")
	puppet._process(.15)
	check(puppet.current_anim_keyword == "attack", "wolf completes the jaw snap instead of returning to locomotion at 0.34 seconds")
	await create_timer(.65).timeout
	if DisplayServer.get_name() != "headless":
		for i in captures.size():
			var capture: AudioEffectCapture = captures[i]
			var peak := 0.0
			for sample in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			print("WIRE_AUDIO source=", i, " peak=", peak)
			check(peak > .005, "network attack audio source %d reaches the mixer" % i)
	# Damage at four metres currently happens without an attacking server pose.
	actor.stats.health = 100; proxy.position.z = 3.8
	wolf._player_bite_target = null; wolf._bite_anim_timer = 0
	wolf._attack_cooldown = 0; wolf._process(1.0/60)
	await create_timer(.08).timeout
	check(actor.stats.health == 100, "wolf cannot damage a player outside physical bite reach")
	# Escaping during wind-up and a physical wall both invalidate contact.
	for scenario in ["escape", "wall", "cease"]:
		proxy.position.z = 2.2; wolf._attack_cooldown = 0
		wolf._player_bite_target = null; wolf._bite_anim_timer = 0
		wolf._process(1.0/60)
		var wall: StaticBody3D = null
		if scenario == "wall":
			wall = StaticBody3D.new(); world.add_child(wall); wall.position = Vector3(0,.7,1)
			var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(4,2,.2); wall.add_child(shape)
			await physics_frame
		elif scenario == "cease":
			wolf.tamed_to = "local"
			wolf.apply_command("cease")
		else:
			proxy.position.z = 5
		for i in 90:
			wolf._process(1.0/60)
		await create_timer(.08).timeout
		check(actor.stats.health == 100, scenario + " prevents the pending bite")
		if wall != null: wall.free()
	world.queue_free()
	client.close_connection(); host.close_connection(); scope.queue_free()
	for i in 4: await process_frame
	for label in ["VictimPain", "VictimBite", "WolfVoice"]:
		AudioServer.remove_bus(AudioServer.get_bus_index(label))
