extends SceneTree

class World extends Node3D:
	var surface := "grass"
	func get_river_depth_at(_p: Vector3) -> float: return .2 if surface == "water" else 0.0
	func _is_player_in_house(_p: Vector3) -> bool: return surface == "wood"
	func _is_on_road(_p: Vector3) -> bool: return surface == "road"
class Audio extends AudioSystem:
	var steps: Array = []
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
	for i in 100: audio._remote_actor_steps({},"p:901",actor,"riflerun",.05,Vector3.ZERO,false)
	check(audio.steps.is_empty(),"stale run packets against a wall make no footsteps")
	for i in 80:
		actor.position.x += .15
		audio._remote_actor_steps({},"p:901",actor,"riflewalk",.05,Vector3.ZERO,false)
	check(audio.steps.size() in range(6,10),"walking cadence follows 3 m/s displacement")
	var n := audio.steps.size()
	for i in 80: audio._remote_actor_steps({},"p:901",actor,"riflewalk",.05,Vector3.ZERO,false)
	check(audio.steps.size()==n,"stopping immediately silences footsteps")
	actor.position = Vector3(100,0,0)
	audio._remote_actor_steps({},"p:901",actor,"run",.05,actor.position,false)
	check(audio.steps.size()==n,"teleport is not a footstep")
	actor.position = Vector3.ZERO
	audio._remote_actor_steps({},"p:901",actor,"sneak_walk",.05,Vector3.ZERO,false)
	actor.is_crouching = true
	for i in 60:
		actor.position.x += .1
		audio._remote_actor_steps({},"p:901",actor,"sneak_walk",.05,Vector3.ZERO,false)
	check(audio.steps.size()>n and audio.steps.back()[2]=="sneak","crouched bots make quieter paced footsteps")
	actor.is_dead = true
	n = audio.steps.size()
	for i in 30:
		actor.position.x += .1
		audio._remote_actor_steps({},"p:901",actor,"run",.05,Vector3.ZERO,false)
	check(audio.steps.size()==n,"moving corpses stay silent")
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
		check(not pool.is_empty() and pool[0] is AudioStreamWAV and pool[0].loop_mode==AudioStreamWAV.LOOP_DISABLED,surface+" uses a decodable non-looping step for all survivors")
	world.free()
	print("BotAudio: checks=%d errors=%d" % [checks,errors])
	quit(1 if errors else 0)
