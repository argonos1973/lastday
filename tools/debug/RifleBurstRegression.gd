extends SceneTree
class World extends Node3D:
	var hud = null
class Actor extends "res://scripts/PlayerController.gd":
	var test_item
	var shots := 0
	var flashes := 0
	var shot_origins: Array[Vector3] = []
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func get_held_item(): return test_item
	func _update_rifle_visuals(_d): pass
	func _on_skeleton_updated(): pass
	func _play_shoot_sound(_m4 := false): pass
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
		actor.shots=0;actor._shoot_cooldown=0;actor._is_reloading=false;actor.is_dead=false
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
		for origin in actor.shot_origins:
			check(origin.distance_to(actor._rifle_muzzle.global_position) < 0.001, "Third-person bullets start at muzzle with distant camera: " + mode)
		if mode=="reload": await create_timer(2.0).timeout
	actor.stats.free();scene.free()
	print("RIFLE_BURST_ERRORS=",errors);quit(1 if errors else 0)
