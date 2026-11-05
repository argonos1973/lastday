extends SceneTree
class Animal extends "res://scripts/WildlifeController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
class World extends Node3D:
	var hud = null
class Shooter extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _spawn_blood_splatter(_pos := Vector3.ZERO, _strength := 1.0) -> void: pass
	func _hit_marker(_dead: bool) -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene=world
	var shooter := Shooter.new()
	world.add_child(shooter)
	var failures := 0
	for distance in [200.0,400.0,550.0]:
		var deer := Animal.new()
		deer.animal_type="deer"
		deer.health=10000
		world.add_child(deer)
		deer.add_to_group("wildlife")
		deer.position=Vector3(0,0,-distance)
		deer._create_hitbox()
		await physics_frame
		await physics_frame
		var bullet := preload("res://scripts/RifleProjectile.gd").new()
		world.add_child(bullet)
		bullet.set_physics_process(false)
		bullet.position=Vector3(0,.7,0)
		bullet.max_distance=600
		var flight := -log(1.0-distance*.12/750.0)/.12
		# Compensated elevation: preserve real gravity rather than bypassing cover.
		var lift: float = 9.81/.12*(flight-distance/750.0)
		bullet.velocity=Vector3(0,lift,-distance).normalized()*750
		var hits: Array=[]
		bullet.impact.connect(func(c,p,d,n):
			hits.append(c)
			shooter._apply_rifle_damage(c,p,d,n))
		for frame in range(120):
			if bullet.is_queued_for_deletion(): break
			bullet._physics_process(1.0/60.0)
		var ok := hits.size()==1 and deer.health<10000
		if not ok: failures+=1
		print("LONG_RANGE ",distance,"m hit=",ok," damage=",10000-deer.health)
		deer.queue_free()
		if not bullet.is_queued_for_deletion(): bullet.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	print("LONG_RANGE failures=",failures)
	quit(1 if failures else 0)
