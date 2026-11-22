extends SceneTree
class World extends Node3D:
	var hud = null
class Actor extends "res://scripts/PlayerController.gd":
	var test_item
	var shots := 0
	var flashes := 0
	var sounds := 0
	var real_sound := false
	var shot_origins: Array[Vector3] = []
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func get_held_item(): return test_item
	func _update_rifle_visuals(_d): pass
	func _on_skeleton_updated(): pass
	func _play_shoot_sound(_m4 := false):
		sounds += 1
		if real_sound: super(_m4)
	func _spawn_muzzle_flash(_p, _d): flashes += 1
	func _launch_rifle_projectile(_o, _d, _w, _e, _damage, _m4 := false):
		shots += 1
		shot_origins.append(_o)
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var scene:=World.new();root.add_child(scene);current_scene=scene
	var actor:=Actor.new();scene.add_child(actor)
	actor.camera=Camera3D.new();actor.add_child(actor.camera)
	actor.stats=preload("res://scripts/SurvivalStats.gd").new()
	actor.is_puppet=true;actor._puppet_held=actor.M4_NAME
	for i in 3: actor.play_rifle_shot_remote(Vector3.ZERO, Vector3.FORWARD)
	await create_timer(.3).timeout
	check(actor.shots==3 and actor.flashes==3,"Three received bullets must produce exactly three projectiles and flashes")
	actor.is_puppet=false;actor._puppet_held=""
	actor.camera.position = Vector3(0, 2, 6.5)
	actor._rifle_muzzle = Marker3D.new()
	actor.add_child(actor._rifle_muzzle)
	actor._rifle_muzzle.position = Vector3(0, 1.4, -0.8)
	var item_script=preload("res://scripts/Item.gd")
	actor.test_item=item_script.create(actor.M4_NAME,"weapon_rifle",3.0,1,0.0)
	for mode in ["complete", "reload", "swap", "reequip", "death", "last_round"]:
		actor.shot_origins.clear()
		actor.shots=0;actor.sounds=0;actor._shoot_cooldown=0;actor._is_reloading=false;actor.is_dead=false
		actor.stats.energy=100;actor._m4_magazine=1 if mode=="last_round" else 30
		actor._m4_reserve_ammo=60
		actor._shoot_rifle()
		check(actor.shots==1,"First round fires immediately: "+mode)
		if mode=="reload": actor._reload_rifle()
		elif mode=="swap": actor.test_item=item_script.create(actor.M4_NAME,"weapon_rifle",3.0,1,0.0)
		elif mode=="reequip": actor._held_selection_revision+=1
		elif mode=="death": actor.is_dead=true
		await create_timer(.3).timeout
		var expected:=3 if mode=="complete" else 1
		check(actor.shots==expected,"Pending shots follow cancellation rules: "+mode)
		check(actor._m4_magazine==(0 if mode=="last_round" else 30-expected),"Only fired rounds consume ammunition: "+mode)
		check(actor.sounds==actor.shots,"Every real M4 round plays exactly one shot sound: "+mode)
		for origin in actor.shot_origins:
			check(origin.distance_to(actor._rifle_muzzle.global_position) < 0.001, "Third-person bullets start at muzzle with distant camera: " + mode)
		if mode=="reload": await create_timer(2.0).timeout
	# Sustained fire: the held trigger re-fires as soon as the cooldown expires,
	# so the weapon keeps the same cadence until the magazine runs dry.
	actor.test_item=item_script.create(actor.M4_NAME,"weapon_rifle",3.0,1,0.0)
	actor.shots=0;actor.sounds=0;actor._shoot_cooldown=0;actor._is_reloading=false;actor.is_dead=false
	actor.stats.energy=100;actor._m4_magazine=30;actor._m4_reserve_ammo=0
	var held_started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-held_started < 1300:
		actor._shoot_cooldown=maxf(0.0,actor._shoot_cooldown-1.0/60.0)
		if actor._shoot_cooldown<=0.0: actor._shoot_rifle()
		await physics_frame
	await create_timer(.3).timeout
	check(actor.shots>=12,"Held trigger keeps firing bursts back to back (%d rounds in 1.3 s)" % actor.shots)
	check(actor.sounds==actor.shots and actor._m4_magazine==30-actor.shots,"Sustained fire: one sound and one cartridge per round (%d/%d)" % [actor.sounds, actor.shots])
	# Real player: voices overlap and the last echo is not cut on release.
	actor.real_sound=true
	actor._play_shoot_sound(true)
	actor._play_shoot_sound(true)
	var shot_player = actor._shoot_audio_player
	check(shot_player != null and shot_player.max_polyphony == actor.M4_SHOT_VOICES,"M4 shots overlap instead of restarting one voice")
	check(shot_player != null and shot_player.stream != null and shot_player.stream.get_length() < 1.1,"M4 clip is a single shot with its tail")
	await create_timer(.35).timeout
	check(shot_player != null and shot_player.playing,"Echo tail keeps ringing after the trigger is released")
	actor.test_item=item_script.create("Rifle francotirador","weapon_rifle",4.0,1,0.0)
	actor._play_shoot_sound(false)
	check(shot_player.max_polyphony == 1,"Sniper shot keeps a single voice")
	shot_player.stop();shot_player.stream=null
	actor.stats.free();scene.free()
	print("RIFLE_BURST_ERRORS=",errors);quit(1 if errors else 0)
