extends SceneTree
# Real local/bot/observer damage paths, including missing rigs and lethal hits.
const Fixture = preload("res://tools/debug/WildlifeAudioRegression.gd")
const WEAPONS := ["rifle", "m4", "arco", "arco_head", "lanza", "bola", "melee", "wolf_bite", "bear_bite"]
class Manager extends "res://scripts/SurvivorBotManager.gd":
	func _exit_tree(): pass
class Relay extends "res://scripts/NetworkManager.gd":
	func _ready(): pass
	func _exit_tree(): pass
var errors := 0
var checks := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok: errors += 1; push_error(message)
func _initialize(): call_deferred("run")
func reset(actor):
	actor.is_dead = false; actor.stats.health = 100
	actor._pain_sound_timer = 0
	actor._last_shot_received_audio_msec = -10000
	actor._last_bite_audio_msec = -10000
	for voice in [actor._shot_audio_player,actor._pain_audio_player,actor._bite_audio_player]:
		if is_instance_valid(voice): voice.stop()
func voice_for(actor, weapon: String):
	return actor._shot_audio_player if weapon in ["rifle","m4"] else actor._pain_audio_player
func run():
	var world := Fixture.World.new(); root.add_child(world); current_scene = world
	world.net = Fixture.Net.new(); world.add_child(world.net)
	var actor := Fixture.Actor.new(); world.add_child(actor); world.player = actor
	var observer := Fixture.Actor.new(); observer.is_puppet = true; world.add_child(observer); world.remote_players[901] = observer
	var manager := Manager.new(); world.add_child(manager); manager.set_process(false); manager.world = world
	for weapon in WEAPONS:
		reset(actor)
		world._net_apply_damage(8,weapon)
		check(actor.stats.health == 92,weapon+" applies damage once")
		var voice = voice_for(actor,weapon)
		check(voice is AudioStreamPlayer and voice.playing,weapon+" local pain without animation rig")
		if weapon in ["rifle","m4"]:
			check(actor._pain_audio_player == null or not actor._pain_audio_player.playing,weapon+" uses one pain voice")
		reset(actor)
		manager._apply_bot_damage_to_target({"bot_id":901},actor,8,weapon)
		check(actor.stats.health == 92 and voice_for(actor,weapon).playing,weapon+" direct bot attack has pain feedback")
		reset(observer)
		world._net_player_hit_event(901,weapon,Vector3.UP)
		voice = voice_for(observer,weapon)
		check(voice is AudioStreamPlayer3D and voice.playing,weapon+" observer hears positional pain without rig")
		check(observer.stats.health == 100,weapon+" presentation event never reapplies damage")
		reset(actor); actor.is_dead = true
		world._net_player_hit_event(42,weapon,Vector3.UP)
		check(voice_for(actor,weapon).playing,weapon+" lethal hit feedback survives the death state")
	# The rig exists but its shot clip has not loaded (or was absent in donor).
	reset(actor)
	actor.third_person_animation_player = AnimationPlayer.new(); actor.add_child(actor.third_person_animation_player)
	actor._play_shot_reaction()
	check(actor._shot_audio_player.playing,"missing shot animation does not suppress audio")
	check(actor._impact_audio_player == null or not actor._impact_audio_player.playing,"missing shot animation never substitutes punch sound")
	# Predator bites interrupt the combat stance: an aiming, sprinting victim
	# still shows the flinch, loses the scope and feels a camera impulse.
	var hit_clip := Animation.new(); hit_clip.length = .4
	var hit_lib := AnimationLibrary.new(); hit_lib.add_animation("h",hit_clip)
	actor.third_person_animation_player.add_animation_library("hit",hit_lib)
	actor.third_person_hit_animation = "hit/h"
	for bite in ["wolf_bite","bear_bite"]:
		for state in [{"_is_aiming":true,"is_sprinting":true},{"third_person_action_timer":.4},{"is_moving":true,"is_sprinting":true}]:
			reset(actor)
			actor._is_aiming = false; actor.is_moving = false; actor.is_sprinting = false; actor.third_person_action_timer = 0.0
			for k in (state as Dictionary).keys(): actor.set(k,state[k])
			world._net_apply_damage(12,bite)
			check(not actor._is_aiming,bite+" cancels the victim's aim")
			check(actor.third_person_animation_player.current_animation == "hit/h",bite+" forced flinch plays through "+str(state.keys()))
			check(actor._recoil_pitch != 0.0 or actor._recoil_yaw != 0.0,bite+" gives a first-person camera impulse")
			actor._recoil_pitch = 0.0; actor._recoil_yaw = 0.0
	reset(actor)
	world._net_apply_damage(8,"m4")
	var stamp: int = actor._last_shot_received_audio_msec
	for i in 2: world._net_apply_damage(8,"m4")
	world._net_player_hit_event(42,"m4",Vector3.ZERO)
	check(actor.stats.health == 76,"all burst rounds still apply damage")
	check(actor._last_shot_received_audio_msec == stamp,"burst and duplicate event do not restart the grunt")
	var relay := Relay.new(); world.add_child(relay); relay.is_host=true; relay.peer=OfflineMultiplayerPeer.new()
	reset(observer)
	relay._broadcast_player_hit(901,"m4",Vector3.UP)
	check(observer._shot_audio_player.playing,"listen host also hears another actor's confirmed gunshot injury")
	reset(observer); relay.is_dedicated_server=true
	relay._broadcast_player_hit(901,"m4",Vector3.UP)
	check(not observer._shot_audio_player.playing,"dedicated server does not render local injury audio")
	if DisplayServer.get_name() != "headless": await mix_check(world,actor,observer)
	world.queue_free()
	for i in 4: await process_frame
	print("DAMAGE_FEEDBACK checks=",checks," errors=",errors)
	quit(1 if errors else 0)
func mix_check(world, actor, observer):
	var camera := Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,1,3); camera.make_current()
	root.audio_listener_enable_3d = true
	var bus := AudioServer.bus_count; AudioServer.add_bus(); AudioServer.set_bus_name(bus,"DamageTest")
	var capture := AudioEffectCapture.new(); capture.buffer_length=1.0; AudioServer.add_bus_effect(bus,capture)
	for target in [actor,observer]:
		for weapon in ["rifle","m4","arco","lanza","bola","melee"]:
			reset(target)
			for sound in [target._shot_audio_player,target._pain_audio_player,target._bite_audio_player]:
				if is_instance_valid(sound): sound.bus="DamageTest"
			capture.clear_buffer()
			if target==actor: world._net_apply_damage(8,weapon)
			else: world._net_player_hit_event(901,weapon,Vector3.UP)
			await create_timer(.4).timeout
			var peak := 0.0
			for sample in capture.get_buffer(capture.get_frames_available()): peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
			check(peak>.005 and peak<.95,"mixed pain for "+weapon+" local="+str(target==actor))
			print("DAMAGE_MIX weapon=",weapon," local=",target==actor," peak=",peak)
	for target in [actor,observer]:
		for sound in [target._shot_audio_player,target._pain_audio_player,target._bite_audio_player]:
			if is_instance_valid(sound): sound.stop(); sound.bus="Master"
	AudioServer.remove_bus(bus)
