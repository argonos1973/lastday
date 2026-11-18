extends SceneTree

class World extends Node3D:
	var surface := "grass"
	var remote_players: Dictionary = {}
	var puppet_animals: Dictionary = {}
	func get_river_depth_at(_p: Vector3) -> float: return .2 if surface == "water" else 0.0
	func get_river_surface_y_at(_p: Vector3) -> float: return 0.0
	func _is_player_in_house(_p: Vector3) -> bool: return surface == "wood"
	func _is_on_road(_p: Vector3) -> bool: return surface == "road"
class Audio extends AudioSystem:
	var steps: Array = []
	var loop_starts := 0
	func _play_locomotion_loop(voice: AudioStreamPlayer3D, pos: Vector3, kind: String, water: bool, volume: float) -> void:
		if not voice.playing or voice.stream != _locomotion_stream(kind, water): loop_starts += 1
		super._play_locomotion_loop(voice, pos, kind, water, volume)
	func _play_remote_step(key: String, pos: Vector3, kind: String, animal: bool) -> void:
		steps.append([key,pos,kind,animal])
class Actor extends PlayerController:
	var events: Array = []
	func _ready() -> void: set_process(false); set_physics_process(false)
	func _play_consumption_audio(drinking: bool, _duration: float, _serial: int) -> void: events.append("drink" if drinking else "eat")
	func _play_reload_sound() -> void: events.append("reload")
	func _play_puppet_chop_sound() -> void: events.append("chop")
class Manager extends SurvivorBotManager:
	var events: Array = []
	func _emit_bot_condition_audio(b: Dictionary, kind: String) -> void: events.append([b.bot_id,kind])

var errors := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors += 1; push_error(label)
func run() -> void:
	var world := World.new()
	root.add_child(world); current_scene = world
	var audio := Audio.new()
	world.add_child(audio); audio.set_process(false)
	var actor := Actor.new()
	actor.is_puppet = true
	world.add_child(actor)
	audio._create_players()
	audio._load_footstep_audio()
	for pair in [[audio.walk_stream, AudioSystem.WALK_SOUND_PATH], [audio.run_stream, AudioSystem.RUN_SOUND_PATH], [audio.water_footstep_splashes[0], AudioSystem.WATER_FOOTSTEP_SPLASH_PATHS[0]]]:
		var source: AudioStreamMP3 = load(pair[1])
		check(pair[0] is AudioStreamMP3 and pair[0].data == source.data, "original recording: " + pair[1])
		check(pair[0] != source and pair[0].loop and not source.loop, "loop uses private copy: " + pair[1])
	for i in 100: audio._remote_actor_steps({},"p:901",actor,"riflerun",.05,Vector3.ZERO,false)
	check(audio._remote_locomotion.is_empty(),"stale run packets against a wall make no footsteps")
	# Real client cadence: remote movement at 20 Hz, audio at 60 Hz.
	for i in 180:
		if i % 3 == 0: actor.position.x += .15
		audio._remote_actor_steps({},"p:901",actor,"riflewalk",1.0/60,Vector3.ZERO,false)
	check(audio.loop_starts == 1,"walking recording is not restarted between 20 Hz snapshots")
	check(audio._remote_locomotion.has("p:901") and audio._remote_locomotion["p:901"].stream == audio.walk_stream,"remote uses original walk recording")
	check(audio.steps.is_empty(),"human steps are never mixed with generic surface shots")
	for i in 600: audio._remote_actor_steps({},"p:901",actor,"riflewalk",1.0/60,Vector3.ZERO,false)
	check(audio._remote_locomotion.is_empty(),"stationary actor releases its loop despite stale walk packets")
	var n := audio.loop_starts
	actor.position = Vector3(20,0,0)
	audio._remote_actor_steps({},"p:901",actor,"run",.05,actor.position,false)
	check(audio.loop_starts==n,"teleport after a long idle is not a footstep")
	actor.position = Vector3.ZERO
	audio._remote_actor_steps({},"p:901",actor,"sneak_walk",.05,Vector3.ZERO,false)
	actor.is_crouching = true
	for i in 60:
		actor.position.x += .1
		audio._remote_actor_steps({},"p:901",actor,"riflerun",.05,Vector3.ZERO,false)
	check(audio._remote_locomotion["p:901"].stream == audio.walk_stream and audio._remote_locomotion["p:901"].volume_db < 0,"crouch overrides stale run and quiets original walk recording")
	actor.is_dead = true
	n = audio.loop_starts
	for i in 30:
		actor.position.x += .1
		audio._remote_actor_steps({},"p:901",actor,"run",.05,Vector3.ZERO,false)
	check(audio.loop_starts==n and audio._remote_locomotion.is_empty(),"moving corpses stay silent")
	# Local dry/water changes must never overlap, and stop cancels immediately.
	audio._update_local_locomotion(Vector3.ZERO,3,false,false,false)
	check(audio.footstep_player.stream == audio.walk_stream and audio.footstep_player.playing,"local walking uses original MP3")
	audio._update_local_locomotion(Vector3.ZERO,6,true,false,false)
	check(audio.footstep_player.stream == audio.run_stream and audio.footstep_player.playing,"local running switches to original running MP3")
	audio._update_local_locomotion(Vector3.ZERO,2,false,false,true)
	check(not audio.footstep_player.playing and audio.water_footstep_player.playing,"wading stops dry footsteps")
	check(audio.water_footstep_player.stream == audio.water_footstep_splashes[0] and audio.water_footstep_player.get_playback_position() >= 3.9,"water recording skips its four-second intro")
	audio._update_local_locomotion(Vector3.ZERO,3,false,false,false)
	check(audio.footstep_player.playing and not audio.water_footstep_player.playing,"leaving water stops splashes")
	audio._update_local_locomotion(Vector3.ZERO,0,true,false,false)
	check(not audio.footstep_player.playing and not audio.water_footstep_player.playing,"no footsteps when blocked or stopped")
	for surface in ["grass","road","wood","water"]:
		world.surface = surface
		audio._play_remote_locomotion("p:901", Vector3.ZERO,"run")
		check(audio._remote_locomotion["p:901"].stream == (audio.water_footstep_splashes[0] if surface=="water" else audio.run_stream), "remote recording on " + surface)
	audio._play_remote_locomotion("p:901",Vector3(0,3,0),"run")
	check(audio._remote_locomotion["p:901"].stream == audio.run_stream,"bridge above water does not play splashes")
	audio._stop_remote_locomotion("p:901")
	world.surface = "grass"
	for i in 100: audio._play_remote_locomotion("p:%d" % i, Vector3.ZERO,"walk")
	check(audio._remote_locomotion.size() == AudioSystem.REMOTE_LOCOMOTION_POOL,"many nearby actors cannot grow the audio pool")
	for key in audio._remote_locomotion.keys(): audio._stop_remote_locomotion(key)
	check(audio._remote_locomotion_free.size() == AudioSystem.REMOTE_LOCOMOTION_POOL,"voices return to pool on stop")
	audio.player = actor
	audio._play_remote_locomotion("p:901",Vector3.ZERO,"walk")
	audio._update_remote_footsteps(.05)
	check(audio._remote_locomotion.is_empty(),"despawned actor releases its voice")
	actor.is_dead = false
	actor.is_crouching = false
	for kind in ["eat","drink","RifleReload","chop"]:
		actor.puppet_apply(actor.position,0,"idle")
		n = actor.events.size()
		for _packet in 30: actor.puppet_apply(actor.position,0,kind)
		check(actor.events.size()==n+1,"%s sounds once even before model is ready" % kind)
		check(actor._is_consumption_audio_active()==(kind in ["eat","drink"]),kind+" consumption lifetime")
	actor.puppet_apply(actor.position,0,"dead")
	check(actor._puppet_action_audio_kind.is_empty(),"death cancels action audio")
	actor.is_dead = false
	actor._puppet_held = "Hacha"
	n = actor.events.size()
	actor.puppet_apply(actor.position,0,"forage")
	check(actor.events.size()==n,"gathering with an axe in hand is not chopping")
	actor.puppet_apply(actor.position,0,"death/DeathExternal")
	check(actor.events.size()==n,"death clip name cannot be mistaken for eating")
	actor.puppet_apply(actor.position,0,"plant_eat")
	check(actor.events.back()=="eat","human eating retains the correct sound despite reusing the plant clip")
	actor.is_dead = true
	actor.puppet_apply(actor.position,0,"dead")
	check(actor._puppet_action_audio_kind.is_empty(),"already-dead puppet clears outstanding action audio")
	var mgr := Manager.new()
	world.add_child(mgr)
	var motion := {"proxy":actor,"anim":"run","_speed":6.2,"_mdir":Vector3.RIGHT}
	mgr._finish_bot_motion_tick(motion,actor.position,.05)
	check(motion.anim=="idle" and not actor.get_meta("moving") and motion._speed==0.0,"server clears stale run and stamina flags after a stationary decision")
	var b := {"bot_id":901,"health":100.0,"sick_timer":30.0}
	for _tick in 100: mgr._tick_bot_condition_audio(b,.05)
	check(mgr.events.size()==1 and mgr.events[0][1]=="sick","illness starts one shared condition sound")
	b.health = 10.0
	for _tick in 600: mgr._tick_bot_condition_audio(b,.05)
	check(mgr.events.size()==4,"critical health groans every 14 seconds, not every packet")
	b.health = 100.0
	mgr._tick_bot_condition_audio(b,15)
	check(mgr.events.size()==4,"recovery silences critical groans")
	audio.grass_steps = [load(AudioSystem.FOOTSTEP_GRASS_PATHS[0])]
	audio.wood_steps = [load(AudioSystem.FOOTSTEP_WOOD_PATHS[0])]
	audio.road_steps = [load(AudioSystem.FOOTSTEP_ROAD_PATHS[0])]
	audio.water_step_shots = [load("res://assets/external/audio/water/water_footstep_splash.wav")]
	for surface in ["grass","wood","road","water"]:
		world.surface = surface
		var pool := audio._surface_steps_at(Vector3.ZERO)
		check(not pool.is_empty() and pool[0] is AudioStreamWAV and pool[0].loop_mode==AudioStreamWAV.LOOP_DISABLED,surface+" uses a decodable non-looping step for animals")
	if DisplayServer.get_name() != "headless":
		await verify_output(audio, world)
	world.free()
	print("BotAudio: checks=%d errors=%d" % [checks,errors])
	quit(1 if errors else 0)

# Graphical mode exercises actual decoding/mixing (the headless driver does
# not mix audio). No world generation, player save or network connection.
func verify_output(audio: Audio, world: Node3D) -> void:
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.7, 3)
	camera.make_current()
	root.audio_listener_enable_3d = true
	await process_frame
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "FootstepRegression")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	audio.footstep_player.bus = "FootstepRegression"
	audio.water_footstep_player.bus = "FootstepRegression"
	for kind in ["walk", "run", "water"]:
		capture.clear_buffer()
		audio._update_local_locomotion(Vector3.ZERO, 3, kind=="run", false, kind=="water")
		await create_timer(.8).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		check(samples.size() > 0 and peak > .001, kind+" original recording produces audible mixed samples")
		print("FOOTSTEP_OUTPUT ",kind," frames=",samples.size()," peak=",peak)
		audio._update_local_locomotion(Vector3.ZERO, 0, false, false, false)
		await create_timer(.1).timeout
	audio.footstep_player.bus = "Master"
	audio.water_footstep_player.bus = "Master"
	AudioServer.remove_bus(bus)
